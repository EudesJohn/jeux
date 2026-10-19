extends Node
## Test automatique sur téléphone — **débogage uniquement**.
##
## Deux verrous, et il faut les deux pour que quelque chose se passe :
##   1. la balise d'export `autotest` (`custom_features` du preset Android) ;
##   2. le fichier `user://auto_test.flag`, poussé par `tools/tester_telephone.sh`.
## Le preset de release n'a PAS la balise : ce script ne peut donc jamais
## démarrer un test dans un build publié, même si le fichier traîne.
##
## Ce qu'il fait : enchaîne menu, combat à 5 ennemis, arène en qualité Faible /
## Moyenne / Haute, Sauvetage et boss, en mesurant les images par seconde
## (moyenne, minimum, 1 % bas), les appels de dessin, les triangles et la
## mémoire. Il écrit tout dans `user://rapport_perf.json`, que
## `tools/tester_telephone.sh` récupère avec `adb exec-out run-as`.
##
## La coop n'est pas simulée : elle demande deux appareils. L'étape est notée
## « ignorée » dans le rapport plutôt que de fausser la moyenne.

const FLAG: String = "user://auto_test.flag"
const RAPPORT: String = "user://rapport_perf.json"

## Durées en secondes. En local (headless), AUTOTEST_RAPIDE=1 les divise par 10.
const DUREES: Dictionary = {
	"menu": 5.0,
	"combat_5": 45.0,
	"arene_faible": 30.0,
	"arene_moyenne": 30.0,
	"arene_haute": 30.0,
	"sauvetage": 45.0,
	"boss": 45.0,
}

var _etapes: Array[Dictionary] = []
var _facteur: float = 1.0
var _actif: bool = false


func _ready() -> void:
	# Hors debug : aucun déclencheur, même avec le fichier-drapeau.
	# `autotest` vient du preset Android ; l'environnement ne sert qu'à valider
	# en local (`AUTOTEST_FORCE=1`), et un build release n'est jamais « debug ».
	var autorise := OS.has_feature("autotest") or (
		OS.is_debug_build() and OS.get_environment("AUTOTEST_FORCE") == "1"
	)
	if not autorise:
		return
	if not FileAccess.file_exists(FLAG):
		return
	_actif = true
	_facteur = 0.1 if OS.get_environment("AUTOTEST_RAPIDE") == "1" else 1.0
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	var debut := Time.get_ticks_msec()

	# 1. Menu : le premier écran que voit le joueur.
	await _etape_menu()
	# 2. Combat contre 5 ennemis (arène, vagues finies).
	await _etape_niveau("combat_5", _donnees_combat("Combat (5 ennemis)", 5, 1))
	# 3. La même arène dans les trois qualités : c'est là que l'écart se voit.
	for qualite in ["low", "medium", "high"]:
		await _etape_qualite("arene_%s" % _nom_qualite(qualite), qualite)
	# 4. Sauvetage : cages, villageois, plus d'objets à l'écran.
	await _etape_niveau("sauvetage", load("res://data/levels/rescue/rescue_02.tres") as LevelData)
	# 5. Boss : la charge la plus lourde du jeu.
	await _etape_niveau("boss", load("res://data/levels/adventure/ch1_l5.tres") as LevelData)
	# 6. Coop : non simulable sur un seul appareil.
	_etapes.append({
		"nom": "coop",
		"statut": "ignoree",
		"raison": "deux téléphones requis ; à tester à la main",
	})

	var rapport := {
		"date": Time.get_datetime_string_from_system(),
		"appareil": OS.get_model_name(),
		"systeme": OS.get_version(),
		"version_jeu": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"duree_totale_s": roundi((Time.get_ticks_msec() - debut) / 1000.0),
		"etapes": _etapes,
	}
	_ecrire(rapport)

	# Le fichier-drapeau est consommé : un prochain lancement ne rejoue pas.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


# ---------------------------------------------------------------------------
# Étapes
# ---------------------------------------------------------------------------

func _etape_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await _mesurer("menu", DUREES["menu"])


func _etape_niveau(nom: String, data: LevelData) -> void:
	if data == null:
		_etapes.append({"nom": nom, "statut": "erreur", "raison": "LevelData introuvable"})
		return
	GameState.current_level_data = data
	GameState.mode = GameState.GameMode.ADVENTURE if nom != "sauvetage" else GameState.GameMode.RESCUE
	get_tree().change_scene_to_file("res://scenes/levels/LevelBase3D.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await _mesurer(nom, DUREES.get(nom, 30.0))


func _etape_qualite(nom: String, qualite: String) -> void:
	Settings.set_quality(qualite)
	await _etape_niveau(nom, _donnees_arene(qualite))


func _nom_qualite(qualite: String) -> String:
	match qualite:
		"low":
			return "faible"
		"high":
			return "haute"
		_:
			return "moyenne"


# ---------------------------------------------------------------------------
# Mesure
# ---------------------------------------------------------------------------

func _mesurer(nom: String, duree: float) -> void:
	"""Échantillonne chaque image pendant `duree` et enregistre une étape."""
	var deltas: Array[float] = []
	var memoire_max := 0
	var appels := 0
	var triangles := 0
	var seconde := 0.0

	# Deux images d'amorçage : la première contient le chargement de la scène.
	await get_tree().process_frame
	await get_tree().process_frame

	while seconde < duree * _facteur:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		deltas.append(delta)
		seconde += delta
		# La joueuse ne doit pas mourir pendant la mesure : sinon on mesure
		# l'écran de défaite et non le niveau.
		var niveau := get_tree().current_scene
		if niveau is LevelBase3D and niveau.player != null:
			niveau.player.health = 99999.0
		memoire_max = maxi(memoire_max, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		appels = maxi(appels, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		triangles = maxi(triangles, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))

	if deltas.is_empty():
		_etapes.append({"nom": nom, "statut": "erreur", "raison": "aucune image mesurée"})
		return

	var moyenne := 0.0
	for d in deltas:
		moyenne += d
	moyenne /= float(deltas.size())

	# 1 % bas : on trie les durées d'image décroissantes et on lit la 99e
	# centile — c'est le « pire 1 % » que ressent le joueur sur un ralentissement.
	var durees: Array = deltas.duplicate()
	durees.sort()
	durees.reverse()
	var index := clampi(int(float(durees.size()) * 0.01), 0, durees.size() - 1)
	var pire: float = float(durees[0])
	var pire_1pct: float = float(durees[index])

	_etapes.append({
		"nom": nom,
		"statut": "mesuree",
		"qualite": Settings.quality,
		"secondes": snappedf(seconde, 0.1),
		"images": deltas.size(),
		"fps_moyen": snappedf(1.0 / maxf(moyenne, 0.00001), 0.1),
		"fps_min": snappedf(1.0 / maxf(pire, 0.00001), 0.1),
		"fps_1pct_bas": snappedf(1.0 / maxf(pire_1pct, 0.00001), 0.1),
		"draw_calls": appels,
		"triangles": triangles,
		"memoire_max_mo": snappedf(memoire_max / 1048576.0, 0.1),
	})
	print("[autotest] %s : %.1f fps (min %.1f, 1%% bas %.1f)" % [
		nom, 1.0 / maxf(moyenne, 0.00001),
		1.0 / maxf(pire, 0.00001), 1.0 / maxf(pire_1pct, 0.00001),
	])


# ---------------------------------------------------------------------------
# Fiches de niveau fabriquées
# ---------------------------------------------------------------------------

func _donnees_arene(qualite: String) -> LevelData:
	"""Arène chargée : 3 vagues de 8, pour que la foule pèse sur le rendu."""
	return _donnees_combat("Arène (%s)" % _nom_qualite(qualite), 8, 3)


func _donnees_combat(nom: String, par_vague: int, vagues: int) -> LevelData:
	"""Part de `arena_01.tres` (décor, pièges, ramassages) et remplace les vagues."""
	var base := load("res://data/levels/arena_01.tres") as LevelData
	if base == null:
		return null
	var data := base.duplicate(true) as LevelData
	data.id = "autotest_%s" % nom.to_lower().replace(" ", "_")
	data.display_name = nom
	data.layout = "arena"
	data.objective = "clear"
	data.time_limit = 0
	data.endless = false
	data.prisoners = 0
	data.escorts = 0
	data.boss_id = ""
	var liste: Array[WaveData] = []
	for i in vagues:
		var vague := WaveData.new()
		var entree := SpawnEntry.new()
		entree.type = "soldier"
		entree.count = par_vague
		vague.enemies = [entree] as Array[SpawnEntry]
		vague.delay = 2.0
		vague.start_delay = 0.5
		liste.append(vague)
	data.enemy_waves = liste
	return data


# ---------------------------------------------------------------------------

func _ecrire(rapport: Dictionary) -> void:
	var fichier := FileAccess.open(RAPPORT, FileAccess.WRITE)
	if fichier == null:
		print("[autotest] impossible d'écrire %s" % RAPPORT)
		return
	fichier.store_string(JSON.stringify(rapport, "  "))
	fichier.close()
	print("[autotest] rapport écrit : %s" % ProjectSettings.globalize_path(RAPPORT))
