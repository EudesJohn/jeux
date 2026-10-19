extends Node
## Test fonctionnel de la PHASE 8 (DESIGN.md § 17, § 24, § 25, § 28) :
##   godot --headless --path . res://tests/Phase8Test.tscn
##
## Validation de la phase :
##   * audio : banque de bruitages chargée, 3 couches de musique alignées,
##     crossfade d'intensité, sons 3D, voix + sous-titres ;
##   * traductions : fr / en / fon, bascule sans redémarrage, texte inconnu
##     laissé en français ;
##   * succès : fiches, compteurs, déblocage, bandeau, écran ;
##   * objectifs journaliers : 3 buts du jour, progression, récompense unique ;
##   * optimisation : qualités Faible/Moyenne/Haute, auto-adaptation sous
##     24 images/s, décor en MultiMesh, pooling des effets, filtres d'export.
##
## Sortie : « PHASE 8 : OK » (code 0) ou la liste des échecs (code 1).

const LEVEL_SCENE: String = "res://scenes/levels/LevelBase3D.tscn"
const LEVEL_DATA: String = "res://data/levels/arena_01.tres"
const ACHIEVEMENTS_DIR: String = "res://data/achievements"
const EXPORT_PRESET: String = "res://export_presets.cfg"
## Clé du bandeau de vie du HUD (texte dynamique, traduit puis formaté).
const HEALTH_KEY: String = "VIE %d / %d      ÉNERGIE %d / %d"

var failures: int = 0
var checks: int = 0
var level: LevelBase3D = null
var save_data: Dictionary = {}
var settings_backup: Dictionary = {}


func _ready() -> void:
	print("=== Test fonctionnel PHASE 8 ===")
	save_data = SaveManager.data.duplicate(true)
	settings_backup = {
		"quality": Settings.quality,
		"language": Settings.language,
	}
	# Les Tween ne sont pas avancés pendant la toute première image du moteur :
	# on laisse la boucle démarrer avant de tester les fondus (0,5 s).
	await _ui_frames(2)
	await _frames(1)
	var only := OS.get_environment("PHASE8_ONLY")
	var sections: Dictionary = {
		"audio": _test_audio,
		"traductions": _test_translations,
		"succes": _test_achievements,
		"quotidien": _test_daily_goals,
		"optimisation": _test_optimisation,
	}
	for section_name in sections.keys():
		if only != "" and not only.split(",").has(section_name):
			continue
		await (sections[section_name] as Callable).call()

	# Ni la sauvegarde du joueur ni ses réglages ne doivent sortir modifiés.
	Settings.set_language(String(settings_backup["language"]))
	Settings.set_quality(String(settings_backup["quality"]))
	SaveManager.data = save_data
	SaveManager.save_game()
	await _unload()
	Engine.time_scale = 1.0
	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d" % [checks, failures])
	print("PHASE 8 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
	get_tree().quit(1 if failures > 0 else 0)


# -----------------------------------------------------------------#
#                        OUTILS DE TEST                            #
# -----------------------------------------------------------------#

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  ÉCHEC ", label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _ui_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _reset_save(cauris: int = 0) -> void:
	var fresh := SaveManager.DEFAULT_DATA.duplicate(true)
	fresh["cauris"] = cauris
	SaveManager.data = fresh


func _unload() -> void:
	if level == null or not is_instance_valid(level):
		level = null
		return
	if level.spawner != null:
		level.spawner.finished = true
	level.queue_free()
	level = null
	await _frames(4)


func _load(path: String = LEVEL_DATA) -> LevelBase3D:
	await _unload()
	var data := load(path) as LevelData
	var scene := load(LEVEL_SCENE).instantiate() as LevelBase3D
	scene.level_data = data
	scene.wave_delay_multiplier = 1000.0
	scene.boss_slowmo = false
	add_child(scene)
	await _frames(10)
	level = scene
	return level


# -----------------------------------------------------------------#
#                    § 17 : AUDIO                                   #
# -----------------------------------------------------------------#

func _test_audio() -> void:
	print("[audio] banque, 3 couches, intensité, 3D, voix")
	_check(AudioManager._sfx_names().size() == 18,
		"18 bruitages attendus (%d)" % AudioManager._sfx_names().size())
	var missing := 0
	for sfx_name in AudioManager._sfx_names():
		if not AudioManager.has_sfx(sfx_name):
			missing += 1
	_check(missing == 0, "toute la banque est chargée (%d manquant)" % missing)
	_check(AudioManager.missing_sounds.is_empty(),
		"aucun son signalé introuvable")

	# § 17 : les couches doivent être alignées, sinon le fondu « saute ».
	var loop_length := AudioManager.layer_loop_length()
	_check(loop_length > 0.5, "boucle de musique de %.2f s" % loop_length)

	AudioManager.play_music_set(&"level")
	_check(AudioManager.current_set == &"level", "morceau de niveau demandé")
	_check(AudioManager.layer_playing(&"calm"), "couche calme lancée")
	_check(is_equal_approx(AudioManager.intensity, 0.0),
		"intensité à zéro au départ")

	# Intensité 0 → combat : les couches 2 et 3 montent en 0,5 s (§ 17).
	AudioManager.set_intensity(1.0)
	await _wait(0.75)
	_check(AudioManager.layer_gain(&"combat") > 0.7,
		"couche combat audible (%.2f)" % AudioManager.layer_gain(&"combat"))
	AudioManager.set_intensity(0.2)
	await _wait(0.75)
	_check(AudioManager.layer_gain(&"combat") < 0.05,
		"couche combat éteinte après retour au calme")
	_check(AudioManager.layer_gain(&"calm") > 0.7, "couche calme toujours là")

	var player := AudioManager.play_sfx(&"hit", 1.1, -3.0)
	_check(player != null and player.playing, "bruitage « hit » joué par le pool")
	_check(AudioManager.play_sfx(&"son_qui_nexiste_pas") == null,
		"un son inconnu ne joue rien (pas de plantage)")
	_check(AudioManager.missing_sounds.has(&"son_qui_nexiste_pas"),
		"le son manquant est noté pour le diagnostic")

	# § 17 et § 25 : 8 voix positionnelles, portée courte.
	var placed := AudioManager.play_sfx_3d(&"boss_roar", Vector3(3.0, 0.0, 2.0))
	_check(placed != null and placed.max_distance <= 20.0,
		"son 3D placé, portée courte (%.1f m)" % (placed.max_distance if placed else 0.0))
	var pool_3d := 0
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer3D:
			pool_3d += 1
	_check(pool_3d == AudioManager.VOICES_3D,
		"%d voix 3D au maximum (%d)" % [AudioManager.VOICES_3D, pool_3d])

	# § 17 : « voix en fon avec sous-titres ». Sans enregistrement, le
	# sous-titre sort quand même — c'est ce qui est vérifié ici.
	var subtitles: Array[StringName] = []
	var handler := func(line_id: StringName) -> void: subtitles.append(line_id)
	AudioManager.voice_line.connect(handler)
	AudioManager.play_voice(&"level_start")
	AudioManager.voice_line.disconnect(handler)
	_check(subtitles.has(&"level_start"), "le sous-titre accompagne la voix")
	_check(not AudioManager.has_voice(&"level_start"),
		"pas encore de fichier de voix (emplacements du § 17)")

	AudioManager.stop_music()
	AudioManager.stop_all()
	await _frames(2)


# -----------------------------------------------------------------#
#                    § 24 : TRADUCTIONS                             #
# -----------------------------------------------------------------#

func _test_translations() -> void:
	print("[traductions] fr / en / fon, bascule à chaud")
	_check(TranslationServer.get_loaded_locales().has("en"),
		"le .po anglais est chargé")
	_check(TranslationServer.get_loaded_locales().has("fon"),
		"le .po fon est chargé")

	Localizer.apply("en", false)
	_check(Localizer.current_locale() == "en", "locale passée en anglais")
	_check(tr("Jouer") == "Play", "« Jouer » devient « Play »")
	_check(tr("GARDE PARFAITE !") == "PERFECT GUARD!",
		"le HUD se traduit aussi")
	_check(tr("Ce texte n'est pas dans le .po") == "Ce texte n'est pas dans le .po",
		"un texte inconnu reste en français")

	# Un libellé posé par un écran est traduit automatiquement (§ 24 : « tout
	# texte via tr() » sans réécrire chaque écran).
	var label := Label.new()
	label.text = "Réglages"
	add_child(label)
	await _ui_frames(3)
	_check(label.text == "Settings", "libellé d'écran traduit (%s)" % label.text)

	# Bascule à chaud : le même libellé revient en français.
	Localizer.apply("fr", false)
	await _ui_frames(3)
	_check(label.text == "Réglages", "retour au français sans recharger")

	# Saisie de texte dynamique : traduire AVANT de formater (clé du HUD).
	_check(Localizer.format_tr(HEALTH_KEY, [7, 10, 5, 10]) == "VIE 7 / 10      ÉNERGIE 5 / 10",
		"format traduit puis formaté (fr)")
	Localizer.apply("en", false)
	_check(Localizer.format_tr(HEALTH_KEY, [7, 10, 5, 10]) == "HEALTH 7 / 10      ENERGY 5 / 10",
		"format traduit puis formaté (en)")

	# Le réglage de langue pilote Localizer, et le fon est bien une locale à part.
	Settings.set_language("fon")
	_check(Localizer.current_locale() == "fon", "les Réglages changent la langue")
	_check(tr("Jouer") == "Da wǔ", "le fon traduit ce qu'il connaît déjà")
	Settings.set_language("fr")
	_check(Localizer.current_locale() == "fr", "retour au français par les Réglages")

	# Les textes des buts du jour et des succès existent aussi en anglais.
	Localizer.apply("en", false)
	var keys := 0
	for source in ["BUTS DU JOUR", "SUCCÈS : %s", "Récompense : %d cauris",
			"Le jeu ralentit (%d images/s). Passer en qualité %s ?"]:
		if TranslationServer.translate(source) != source:
			keys += 1
	_check(keys == 4, "les nouveaux textes sont traduits (%d/4)" % keys)
	Localizer.apply("fr", false)

	label.queue_free()
	await _frames(2)


# -----------------------------------------------------------------#
#                      SUCCÈS (PHASE 8)                            #
# -----------------------------------------------------------------#

func _test_achievements() -> void:
	print("[succes] fiches, compteurs, déblocage, écran")
	_reset_save()
	_check(Achievements.all().size() >= 12,
		"au moins 12 succès (%d)" % Achievements.all().size())
	_check(Achievements.unlocked_count() == 0, "aucun succès au départ")

	var files := 0
	var dir := DirAccess.open(ACHIEVEMENTS_DIR)
	if dir != null:
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				files += 1
	_check(files == Achievements.all().size(),
		"une fiche .tres par succès (%d)" % files)

	var unlocked_ids: Array[String] = []
	var handler := func(card: AchievementData) -> void: unlocked_ids.append(card.id)
	Achievements.unlocked.connect(handler)

	# § 25 / succès : les compteurs viennent des signaux d'Events.
	Achievements.report("kills", 50)
	_check(not Achievements.is_unlocked("chasseuse"),
		"50 ennemis ne suffisent pas encore (100 demandés)")
	Achievements.report("kills", 50)
	_check(Achievements.is_unlocked("chasseuse"), "100 ennemis : succès débloqué")
	_check(unlocked_ids.has("chasseuse"), "le signal de déblocage est parti")
	_check(SaveManager.data["achievements"].has("chasseuse"),
		"le succès est écrit dans la sauvegarde")

	var card := Achievements.find("chasseuse")
	_check(card != null and card.stat == "kills" and card.target == 100,
		"fiche cohérente (compteur et seuil)")
	_check(card.progress_ratio(50) == 0.5, "avancement à mi-chemin")

	# Un succès déjà débloqué ne se re-débloque pas.
	Achievements.report("kills", 1)
	var occurrences := 0
	for id in unlocked_ids:
		if id == "chasseuse":
			occurrences += 1
	_check(occurrences == 1, "pas de double déblocage")

	# Le bandeau de déblocage existe (créé à la première récompense).
	var toast := Achievements.get_node_or_null("AchievementToast")
	_check(toast != null, "bandeau de déblocage affiché")
	await _frames(2)
	Achievements.unlocked.disconnect(handler)

	# Les autres compteurs suivent les signaux du gameplay.
	Events.perfect_guard.emit(self)
	Events.perfect_guard.emit(self)
	_check(Achievements.stat("perfect_guards") == 2,
		"les gardes parfaites comptent (2)")
	Events.prisoner_freed.emit(self)
	_check(Achievements.stat("rescued") == 1, "les prisonniers libérés comptent")

	# Écran des succès : une ligne par fiche, compteur en tête.
	var screen := load("res://scenes/ui/AchievementsScreen.tscn").instantiate() as AchievementsScreen
	add_child(screen)
	await _ui_frames(3)
	var rows := screen.get_node("Layout/Scroll/Rows")
	_check(rows.get_child_count() == Achievements.all().size(),
		"%d lignes à l'écran (%d)" % [Achievements.all().size(), rows.get_child_count()])
	var count_label := screen.get_node("Layout/Header/Count") as Label
	_check(count_label.text.contains("/"),
		"compteur affiché (%s)" % count_label.text)
	screen.queue_free()
	await _frames(2)


# -----------------------------------------------------------------#
#                 OBJECTIFS JOURNALIERS (PHASE 8)                  #
# -----------------------------------------------------------------#

func _test_daily_goals() -> void:
	print("[quotidien] 3 buts du jour, progression, récompense")
	_reset_save()
	var goals := DailySeed.goals()
	_check(goals.size() == DailySeed.GOAL_COUNT,
		"%d buts du jour (%d)" % [DailySeed.GOAL_COUNT, goals.size()])
	var stats: Array[String] = []
	for goal in goals:
		stats.append(String(goal["stat"]))
		_check(int(goal["target"]) > 0, "but « %s » a un seuil" % goal["stat"])
	var unique := {}
	for stat_name in stats:
		unique[stat_name] = true
	_check(unique.size() == goals.size(), "aucun but en double")
	_check(not DailySeed.reward_claimed(), "récompense non versée au départ")

	# Deux appels donnent les mêmes buts : c'est la date qui décide (§ 12.5).
	var again := DailySeed.goals()
	var same := true
	for i in goals.size():
		if String(goals[i]["stat"]) != String(again[i]["stat"]) \
				or int(goals[i]["target"]) != int(again[i]["target"]):
			same = false
	_check(same, "même jour = mêmes buts")

	# Progression : un compteur hors des buts du jour est ignoré.
	var first: Dictionary = goals[0]
	var other_stat := "bosses"
	var outside := true
	for goal in goals:
		if String(goal["stat"]) == other_stat:
			outside = false
	DailySeed.add_progress(other_stat)
	if outside:
		_check(DailySeed.progress(other_stat) == 0,
			"un compteur hors des buts du jour n'est pas suivi")

	DailySeed.add_progress(String(first["stat"]))
	_check(DailySeed.progress(String(first["stat"])) == 1,
		"la progression du jour monte (1)")

	# Terminer les trois buts verse la récompense UNE seule fois.
	var cauris_before := int(SaveManager.data["cauris"])
	for goal in DailySeed.goals():
		var stat_name := String(goal["stat"])
		var needed := int(goal["target"]) - DailySeed.progress(stat_name)
		if needed > 0:
			DailySeed.add_progress(stat_name, needed)
	_check(DailySeed.goals_done() == DailySeed.GOAL_COUNT, "les trois buts sont atteints")
	_check(int(SaveManager.data["cauris"]) == cauris_before + DailySeed.REWARD_CAURIS,
		"récompense versée (%d cauris)" % DailySeed.REWARD_CAURIS)
	var after := int(SaveManager.data["cauris"])
	for goal in DailySeed.goals():
		DailySeed.add_progress(String(goal["stat"]), 5)
	_check(int(SaveManager.data["cauris"]) == after,
		"pas de deuxième récompense le même jour")
	_check(DailySeed.reward_claimed(), "le versement est marqué dans la sauvegarde")

	# Les écrans lisent ces buts : la ligne est lisible et traduite.
	var line := DailySeed.goal_line(DailySeed.goals()[0])
	_check(line.contains("/") and not line.contains("%"),
		"ligne de but lisible (%s)" % line)

	# L'écran de choix du mode affiche les trois buts sans pousser le bouton
	# Retour hors de l'écran (§ 16, téléphone en 2:1).
	var modes := load("res://scenes/ui/ModeSelect.tscn").instantiate() as ModeSelect
	add_child(modes)
	await _ui_frames(4)
	var goals_box := modes.get_node_or_null("Modes/DailyGoals")
	_check(goals_box != null and goals_box.get_child_count() >= DailySeed.GOAL_COUNT,
		"les buts du jour sont affichés sur l'écran des modes")
	var back := modes.get_node("Modes/Back") as Button
	_check(back.get_global_rect().end.y <= modes.get_viewport_rect().size.y,
		"le bouton Retour tient toujours dans l'écran")
	modes.queue_free()
	await _frames(2)


# -----------------------------------------------------------------#
#              § 25 : PERFORMANCE ET QUALITÉ                       #
# -----------------------------------------------------------------#

func _test_optimisation() -> void:
	print("[qualite] Faible / Moyenne / Haute, ombre, contour")
	Settings.set_quality("low")
	_check(is_equal_approx(Settings.scale_3d, 0.6), "Faible : échelle 3D 0,6")
	_check(is_equal_approx(Quality.particle_scale(), 0.5),
		"Faible : particules réduites")
	_check(not Quality.outline_enabled(), "Faible : pas de contour")
	Settings.set_quality("high")
	_check(is_equal_approx(Settings.scale_3d, 1.0), "Haute : échelle 3D 1,0")
	_check(not is_equal_approx(Quality.particle_scale(), 0.5),
		"Haute : particules pleines")
	Settings.set_quality("medium")
	_check(is_equal_approx(Settings.scale_3d, 0.8), "Moyenne : échelle 3D 0,8")

	print("[qualite] auto-adaptation sous 24 images/s")
	Quality.reset()
	Settings.set_quality("high")
	# 5 s de mesures sous le seuil : la proposition arrive (§ 25).
	for _i in 12:
		Quality.push_sample(18.0)
	_check(Quality.window_filled(), "fenêtre de mesure remplie")
	_check(Quality.suggested_quality() == "medium",
		"qualité inférieure proposée (%s)" % Quality.suggested_quality())
	Quality.apply_suggestion()
	_check(Settings.quality == "medium", "la qualité proposée s'applique")
	Quality.reset()
	_check(Quality.suggested_quality() == "", "plus de proposition après acceptation")

	# Un refus ne harcèle pas le joueur : on ne repropose pas la même qualité.
	Settings.set_quality("high")
	for _i in 12:
		Quality.push_sample(15.0)
	Quality.dismiss_suggestion()
	for _i in 12:
		Quality.push_sample(15.0)
	_check(Quality.suggested_quality() == "",
		"une qualité refusée n'est plus proposée")
	Quality.reset()

	# Un jeu qui tourne bien ne propose rien.
	Settings.set_quality("medium")
	for _i in 12:
		Quality.push_sample(58.0)
	_check(Quality.suggested_quality() == "",
		"au-dessus de 24 images/s, aucune proposition")

	# § 25 : mode headless = pas de culling d'IA (sinon les tests deviendraient
	# faux) ; sur téléphone, le culling s'active en qualité Faible et Moyenne.
	_check(not Quality.culling_enabled(), "pas de culling en mode headless")

	print("[qualite] décor en MultiMesh, ombre, contour")
	Settings.set_quality("medium")
	await _load()
	_check(level.decor_instance_count() > 0,
		"décor en un seul MultiMesh (%d blocs)" % level.decor_instance_count())
	var decor := level.get_node_or_null("Level/Decor") as MultiMeshInstance3D
	_check(decor != null, "le décor est bien un MultiMeshInstance3D")
	_check(decor != null and decor.visibility_range_end > 0.0,
		"le décor disparaît au loin (visibility_range)")
	_check(level.player.get_node_or_null("BlobShadow") != null,
		"ombre « blob » sous la joueuse")
	_check(level.player.get_node_or_null("Visual/Outline") == null,
		"Moyenne : pas de contour")
	_check(level.get_node_or_null("Level/SunLight") == null,
		"Moyenne : pas de lampe directionnelle")

	Settings.set_quality("high")
	await _ui_frames(3)
	_check(level.player.get_node_or_null("Visual/Outline") != null,
		"Haute : contour de la joueuse ajouté à chaud")
	_check(level.get_node_or_null("Level/SunLight") != null,
		"Haute : lampe directionnelle avec ombre")
	Settings.set_quality("low")
	await _ui_frames(3)
	_check(level.player.get_node_or_null("Visual/Outline") == null,
		"retour en Faible : contour retiré")
	await _unload()

	print("[qualite] pooling des effets")
	# Un effet rendu au pool est réutilisé : plus d'allocation par coup (§ 25).
	DamageNumber.spawn(self, Vector3.ZERO, 12.0)
	var created := DamageNumber.pool_size()
	await _wait(1.2)
	_check(DamageNumber.pool_size() == created + 1,
		"nombre de dégâts rendu au pool (%d)" % DamageNumber.pool_size())
	var before := DamageNumber.pool_size()
	DamageNumber.spawn(self, Vector3.ZERO, 5.0)
	_check(DamageNumber.pool_size() == before - 1,
		"deuxième nombre : l'étiquette du pool est réutilisée")
	await _wait(1.2)

	ImpactFX.spawn(self, Vector3(0.0, 1.0, 0.0), "hit")
	await _wait(1.4)
	_check(ImpactFX.pool_size() >= 1,
		"particules d'impact rendues au pool (%d)" % ImpactFX.pool_size())

	print("[qualite] taille de l'APK : sources exclues de l'export")
	var preset := FileAccess.open(EXPORT_PRESET, FileAccess.READ)
	_check(preset != null, "preset d'export Android trouvé")
	if preset != null:
		var text := preset.get_as_text()
		preset.close()
		# On lit la ligne `exclude_filter`, pas le fichier entier : un
		# `contains("tools/*")` global passait alors que les scripts compilés
		# (`scripts/tests/`, `scripts/tools/`) partaient quand même dans l'APK.
		var filter := ""
		for line in text.split("\n"):
			if line.begins_with("exclude_filter="):
				filter = line
		_check(filter.contains("tests/*") and filter.contains("scenes/tests/*"),
			"les scènes de test ne sont pas exportées")
		_check(filter.contains("scripts/tests/*"),
			"les scripts de test ne sont pas exportés")
		_check(filter.contains("tools/*") and filter.contains("scripts/tools/*"),
			"les outils ne sont pas exportés")
		_check(filter.contains("assets/ui/source/*"),
			"la planche d'assets source reste hors de l'APK")
		_check(text.contains("*.blend") and text.contains("*.psd"),
			"les sources de modélisation ne sont pas exportées")
		_check(text.contains("architectures/arm64-v8a=true"),
			"arm64-v8a activé (§ 26)")
		_check(text.contains("permissions/vibrate=true") and text.contains("permissions/internet=true"),
			"permissions VIBRATE et INTERNET déclarées (§ 26)")
