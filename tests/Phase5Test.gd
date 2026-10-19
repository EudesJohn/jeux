extends Node
## Test fonctionnel de la PHASE 5 (DESIGN.md § 16, § 14.4, § 28) :
##   godot --headless --path . res://tests/Phase5Test.tscn
##
## Validation de la phase : la BOUCLE COMPLÈTE
##   menu → mode → carte → avant-niveau → niveau → résultat → boutique → carte
## et les réglages du § 16. Le test vérifie :
##   * les 25 fiches de campagne et la carte du royaume (étoiles, verrous) ;
##   * l'avant-niveau (objectif, ennemis, temps, récompense) ;
##   * la pause réelle (le temps se fige), Recommencer et Quitter ;
##   * l'armurerie : achat avec cauris, plafond, persistance, effet en jeu ;
##   * les réglages : difficulté, volumes, taille des boutons, qualité ;
##   * le menu principal et le choix du mode (les modes des phases suivantes
##     sont verrouillés, pas cassés).
##
## Sortie : « PHASE 5 : OK » (code 0) ou la liste des échecs (code 1).

const LEVEL_SCENE: String = "res://scenes/levels/LevelBase3D.tscn"
const ADVENTURE_DIR: String = "res://data/levels/adventure"
const FROZEN_WAVES: float = 1000.0

var failures: int = 0
var checks: int = 0
var skipped: int = 0

var level: LevelBase3D = null
var save_data: Dictionary = {}
var save_cauris_db: float = 0.8
var emulated_clicks: int = 0


## Compte les clics que le moteur fabrique à partir d'un doigt : c'est eux qui
## font réagir les Button (§ 7). Sans eux, tout le menu est mort au doigt.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).device == InputEvent.DEVICE_ID_EMULATION:
		emulated_clicks += 1


func _ready() -> void:
	# La pause arrête l'arbre : le test doit continuer à tourner pour la lever.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== Test fonctionnel PHASE 5 ===")
	save_data = SaveManager.data.duplicate(true)
	save_cauris_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var only := OS.get_environment("PHASE5_ONLY")
	var sections: Dictionary = {
		"campaign": _test_campaign_data,
		"map": _test_map,
		"menu": _test_menu,
		"modes": _test_modes,
		"shop": _test_shop,
		"settings": _test_settings,
		"pause": _test_pause,
		"loop": _test_full_loop,
	}
	for name in sections.keys():
		if only != "" and not only.split(",").has(name):
			continue
		await (sections[name] as Callable).call()

	# Restauration de la sauvegarde et des réglages.
	SaveManager.data = save_data
	SaveManager.save_game()
	Settings._load()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), save_cauris_db)
	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d   Ignorées : %d" % [checks, failures, skipped])
	print("PHASE 5 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
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


func _skip(label: String) -> void:
	skipped += 1
	print("  ignoré ", label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Sauvegarde vierge et cauris imposés : rend le déblocage et les achats
## déterministes.
func _reset_save(cauris: int = 0) -> void:
	var fresh := SaveManager.DEFAULT_DATA.duplicate(true)
	fresh["cauris"] = cauris
	SaveManager.data = fresh


func _load_level(path: String) -> LevelBase3D:
	if level != null and is_instance_valid(level):
		if level.spawner != null:
			level.spawner.finished = true
		level.queue_free()
		level = null
		await _frames(4)
	var scene := load(LEVEL_SCENE).instantiate() as LevelBase3D
	# Le test tourne en PROCESS_MODE_ALWAYS (pour lever la pause) ; un vrai
	# niveau, lui, doit se figer : on le rend explicitement pausable.
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	scene.level_data = load(path) as LevelData
	scene.wave_delay_multiplier = FROZEN_WAVES
	add_child(scene)
	await _frames(10)
	level = scene
	return level


func _adventure_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(ADVENTURE_DIR)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			out.append("%s/%s" % [ADVENTURE_DIR, file_name])
	out.sort()
	return out


func _level(id: String) -> LevelData:
	return load("%s/%s.tres" % [ADVENTURE_DIR, id]) as LevelData


# -----------------------------------------------------------------#
#                       CAMPAGNE ET CARTE                          #
# -----------------------------------------------------------------#

func _test_campaign_data() -> void:
	print("[campaign] 25 fiches, 5 chapitres, progression")
	var files := _adventure_files()
	_check(files.size() == 25, "25 fiches de campagne (%d)" % files.size())
	var chapters: Dictionary = {}
	var bosses := 0
	var nights := 0
	for path in files:
		var data := load(path) as LevelData
		_check(data != null, "charge %s" % path.get_file())
		if data == null:
			continue
		chapters[data.chapter] = int(chapters.get(data.chapter, 0)) + 1
		_check(data.number >= 1 and data.number <= 5, "%s : numéro 1-5" % data.id)
		_check(data.id == "ch%d_l%d" % [data.chapter, data.number],
			"%s : identifiant cohérent" % data.id)
		_check(not data.enemy_waves.is_empty(), "%s a des vagues" % data.id)
		_check(data.time_limit >= 90 and data.time_limit <= 160,
			"%s : %d s" % [data.id, data.time_limit])
		_check(data.reward_cauris >= 25, "%s : récompense ≥ 25" % data.id)
		if data.objective == "boss":
			bosses += 1
			# PHASE 6 : chaque chapitre se referme sur son gardien (§ 10).
			_check(data.number == 5, "%s : le boss ferme le chapitre" % data.id)
			_check(data.boss_id == BossRegistry.ORDER[data.chapter - 1],
				"%s : boss %s" % [data.id, data.boss_id])
			_check(not data.is_lane(), "le boss se bat en arène")
		if data.night:
			nights += 1
			_check(data.chapter >= 4, "%s : la nuit commence au chapitre 4" % data.id)
	_check(chapters.size() == 5, "5 chapitres (%d)" % chapters.size())
	_check(int(chapters.get(1, 0)) == 5 and int(chapters.get(5, 0)) == 5,
		"5 niveaux par chapitre")
	_check(bosses == 5, "un boss par chapitre (%d)" % bosses)
	_check(nights >= 5, "au moins 5 niveaux de nuit (%d)" % nights)
	var first := _level("ch1_l1")
	_check(first != null and first.enemy_types().size() == 1
		and first.enemy_types().has("soldier"), "ch1_l1 n'enseigne que le soldat")
	var arena := _level("ch1_l5")
	_check(arena != null and not arena.is_lane(), "le 5e niveau de chaque chapitre est une arène")
	_check(_level("ch5_l5") != null and _level("ch5_l5").objective == "boss"
		and _level("ch5_l5").boss_id == "rival_general",
		"ch5_l5 : le général rival ferme la campagne")


func _test_map() -> void:
	print("[map] carte, étoiles et verrous")
	_reset_save(0)
	var packed := load("res://scenes/ui/AdventureMap.tscn") as PackedScene
	var map := packed.instantiate() as AdventureMap
	add_child(map)
	await _frames(4)
	_check(map.levels.size() == 25, "la carte liste 25 niveaux (%d)" % map.levels.size())
	_check(map.level_buttons.size() == 25, "25 nœuds cliquables")
	_check(map.can_play("ch1_l1"), "le premier niveau est ouvert")
	_check(not map.can_play("ch1_l2"), "le deuxième est verrouillé")
	_check((map.level_buttons["ch1_l2"] as Button).disabled, "le bouton verrouillé est grisé")
	_check((map.level_buttons["ch1_l1"] as Button).text.contains("☆"),
		"une sauvegarde vierge affiche ☆☆☆")
	map.select_level("ch1_l1")
	await _frames(2)
	_check(map.selected != null and map.selected.id == "ch1_l1", "sélectionner ch1_l1")
	_check(not map.play_button.disabled, "JOUER s'active")
	_check(map.info_label.text.contains("La piste rouge"), "l'avant-niveau nomme le niveau")
	_check(map.info_label.text.contains("Vaincre toutes les vagues"), "objectif lisible")
	_check(map.info_label.text.contains("cauris"), "récompense affichée")
	_check(map.info_label.text.contains("Temps"), "temps affiché")
	map.select_level("ch1_l2")
	_check(map.selected.id == "ch1_l1", "un niveau verrouillé ne se sélectionne pas")
	map.queue_free()
	await _frames(2)

	# Une étoile sur ch1_l1 ouvre ch1_l2 et s'affiche.
	_reset_save(0)
	SaveManager.data["levels"]["ch1_l1"] = {"stars": 2}
	var second := packed.instantiate() as AdventureMap
	add_child(second)
	await _frames(4)
	_check(second.can_play("ch1_l2"), "1 étoile sur ch1_l1 ouvre ch1_l2")
	_check((second.level_buttons["ch1_l1"] as Button).text.contains("★★"),
		"la carte affiche ★★ sur ch1_l1")
	_check(second.can_play("ch2_l1") == false, "le chapitre 2 reste fermé")
	second.queue_free()
	await _frames(2)


# -----------------------------------------------------------------#
#                    MENU ET CHOIX DU MODE                         #
# -----------------------------------------------------------------#

func _test_menu() -> void:
	print("[menu] menu principal")
	var packed := load("res://scenes/main/MainMenu.tscn") as PackedScene
	var menu := packed.instantiate() as Node3D
	add_child(menu)
	await _frames(4)
	var root := menu.get_node_or_null("UI/Root")
	_check(root != null, "le menu construit son interface")
	if root == null:
		menu.queue_free()
		return
	for path in ["Menu/Play", "Menu/Coop", "Menu/Armory", "Menu/Settings", "Menu/Quit"]:
		_check(root.get_node_or_null(path) != null, "bouton %s" % path)
	_check(not (root.get_node("Menu/Coop") as Button).disabled, "bouton Coop actif (PHASE 7)")
	_check((root.get_node("Menu/Play") as Button).text == "Jouer", "bouton Jouer")
	var tests := root.get_node_or_null("Tests")
	_check(tests != null and tests.get_child_count() == 6,
		"6 accès aux scènes de test (%d)" % (tests.get_child_count() if tests else 0))

	# § 7 : le doigt doit atteindre les Button du menu.
	_check(bool(ProjectSettings.get_setting(
		"input_devices/pointing/emulate_mouse_from_touch", false)),
		"le doigt produit un clic (emulate_mouse_from_touch)")
	emulated_clicks = 0
	_push_touch((root.get_node("Menu/Settings") as Button).get_global_rect().get_center())
	await _frames(2)
	_check(emulated_clicks > 0, "un appui du doigt génère un clic émulé")
	menu.queue_free()
	await _frames(2)


## Pousse un appui puis un relâchement du doigt par l'Input, comme le système
## Android : c'est le seul chemin qui passe par l'émulation du moteur.
func _push_touch(position: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = position
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()


func _test_modes() -> void:
	print("[modes] choix du mode")
	var packed := load("res://scenes/ui/ModeSelect.tscn") as PackedScene
	var screen := packed.instantiate() as ModeSelect
	add_child(screen)
	await _frames(4)
	_check(screen.mode_buttons.size() == 6, "6 modes listés (%d)" % screen.mode_buttons.size())
	for id in ["aventure", "sauvetage", "arene", "survie", "boss_rush", "defi"]:
		_check(screen.mode_buttons.has(id), "carte de mode « %s »" % id)
	_check(not (screen.mode_buttons["aventure"] as Button).disabled, "Aventure jouable")
	_check(not (screen.mode_buttons["sauvetage"] as Button).disabled, "Sauvetage jouable")
	_check(not (screen.mode_buttons["arene"] as Button).disabled, "Arène jouable")
	# PHASE 6 : les trois modes hors campagne sont désormais jouables.
	_check(not (screen.mode_buttons["survie"] as Button).disabled, "Survie jouable")
	_check(not (screen.mode_buttons["boss_rush"] as Button).disabled, "Boss rush jouable")
	_check(not (screen.mode_buttons["defi"] as Button).disabled, "Défi du jour jouable")
	# § 16 : le bas de l'écran est précieux sur un téléphone en 2:1.
	var back := screen.get_node("Modes/Back") as Button
	_check(back.get_global_rect().end.y <= screen.get_viewport_rect().size.y,
		"le bouton Retour tient dans l'écran")
	screen.queue_free()
	await _frames(2)


# -----------------------------------------------------------------#
#                         ARMURERIE                                #
# -----------------------------------------------------------------#

func _test_shop() -> void:
	print("[shop] achats, plafond et effet en jeu")
	_reset_save(0)
	var packed := load("res://scenes/ui/Shop.tscn") as PackedScene
	var shop := packed.instantiate() as Shop
	add_child(shop)
	await _frames(4)
	_check(shop.buy_buttons.size() == 3, "3 améliorations (%d)" % shop.buy_buttons.size())
	_check(shop.cauris_label.text == "CAURIS 0", "cauris affichés")
	_check((shop.buy_buttons["vitalite"] as Button).disabled, "achat impossible sans cauris")
	shop.buy("vitalite")
	_check(SaveManager.upgrade_level("vitalite") == 0, "aucun achat sans cauris")
	_check(shop.feedback_label.text.contains("Pas assez"), "message « pas assez de cauris »")

	SaveManager.data["cauris"] = 1000
	shop.refresh()
	_check(not (shop.buy_buttons["vitalite"] as Button).disabled, "avec 1000 cauris, on peut acheter")
	var price := SaveManager.upgrade_cost("vitalite")
	shop.buy("vitalite")
	_check(SaveManager.upgrade_level("vitalite") == 1, "Vitalité niveau 1")
	_check(int(SaveManager.data["cauris"]) == 1000 - price,
		"les cauris sont débités (%d)" % int(SaveManager.data["cauris"]))
	_check(shop.level_labels["vitalite"].text.contains("1 / 3"), "niveau affiché 1/3")
	_check(shop.feedback_label.text.contains("Vitalité"), "retour d'achat lisible")
	_check(shop.preview_label.text.contains("110"), "l'aperçu montre 110 de vie")

	SaveManager.data["cauris"] = 10000
	shop.refresh()
	shop.buy("vitalite")
	shop.buy("vitalite")
	_check(SaveManager.upgrade_level("vitalite") == 3, "Vitalité au maximum")
	_check(SaveManager.upgrade_cost("vitalite") == -1, "plus de prix au maximum")
	shop.buy("vitalite")
	_check(SaveManager.upgrade_level("vitalite") == 3, "impossible de dépasser 3")
	_check((shop.buy_buttons["vitalite"] as Button).text == "MAX", "bouton MAX")
	shop.queue_free()
	await _frames(2)

	# Les améliorations s'appliquent réellement à la joueuse.
	SaveManager.data["upgrades"] = {"vitalite": 2, "force": 1, "souffle": 1}
	GameState.mode = GameState.GameMode.ADVENTURE
	await _load_level("%s/ch1_l1.tres" % ADVENTURE_DIR)
	_check(is_equal_approx(level.player.max_health_value(), 120.0),
		"vie max 100 + 2×10 = %.0f" % level.player.max_health_value())
	_check(is_equal_approx(level.player.health, 120.0), "la joueuse commence à 120 vie")
	_check(is_equal_approx(level.player.energy, 20.0), "Souffle donne 20 énergie au départ")
	_check(is_equal_approx(level.player._attack_damage(1.0), 10.8),
		"Force : 10 × 1,08 = %.1f" % level.player._attack_damage(1.0))
	level.queue_free()
	level = null
	await _frames(4)
	SaveManager.data["upgrades"] = {}


# -----------------------------------------------------------------#
#                          RÉGLAGES                                #
# -----------------------------------------------------------------#

func _test_settings() -> void:
	print("[settings] difficulté, volumes, boutons, qualité")
	var panel := SettingsPanel.new()
	add_child(panel)
	await _frames(3)
	_check(panel.find_child("Musique", true, false) is HSlider, "curseur Musique")
	_check(panel.find_child("Effets", true, false) is HSlider, "curseur Effets")
	_check(panel.find_child("Voix", true, false) is HSlider, "curseur Voix")
	_check(panel.find_child("Taille des boutons", true, false) is HSlider,
		"curseur taille des boutons")
	_check(panel.find_child("Difficulté", true, false) is OptionButton, "choix de difficulté")
	_check(panel.find_child("Qualité graphique", true, false) is OptionButton,
		"choix de qualité")
	_check(panel.find_child("Vibration", true, false) is CheckButton, "vibration")

	Settings.set_difficulty("hard")
	_check(GameState.difficulty == "hard", "Difficile s'applique immédiatement")
	_check(SaveManager.data["settings"]["difficulty"] == "hard", "difficulté sauvegardée")
	Settings.set_difficulty("easy")
	_check(is_equal_approx(GameState.time_mult(), 1.2), "Facile : +20 % de temps (§ 13)")

	Settings.set_music_volume(0.25)
	_check(is_equal_approx(Settings.music_volume, 0.25), "volume musique réglé")
	_check(absf(db_to_linear(AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index("Music"))) - 0.25) <= 0.02, "bus Music appliqué")

	Settings.set_button_scale(1.2)
	_check(is_equal_approx(Settings.button_scale, 1.2), "taille des boutons réglée")
	Settings.set_scale_3d(1.0)
	_check(is_equal_approx(Settings.scale_3d, 1.0), "échelle 3D réglée")
	Settings.set_quality("low")
	_check(Settings.quality == "low" and is_equal_approx(Settings.scale_3d, 0.6),
		"qualité Faible -> échelle 0,6")

	# Les valeurs survivent à un rechargement depuis la sauvegarde.
	Settings.music_volume = 0.8
	Settings._load()
	_check(is_equal_approx(Settings.music_volume, 0.25), "volume relu depuis la sauvegarde")
	_check(Settings.difficulty == "easy", "difficulté relue depuis la sauvegarde")
	panel.queue_free()
	await _frames(2)


# -----------------------------------------------------------------#
#                            PAUSE                                 #
# -----------------------------------------------------------------#

func _test_pause() -> void:
	print("[pause] temps figé, Recommencer, Quitter")
	GameState.mode = GameState.GameMode.ADVENTURE
	await _load_level("%s/ch1_l1.tres" % ADVENTURE_DIR)
	var pause := level.pause_menu
	_check(pause != null, "le niveau a un menu de pause")
	if pause == null:
		return
	_check(not pause.is_open and not get_tree().paused, "pas de pause au départ")
	level._on_pause_pressed()
	await _frames(2)
	_check(pause.is_open, "le bouton Pause ouvre le menu")
	_check(get_tree().paused and level.paused, "l'arbre et le niveau sont figés")
	var frozen_time := level.time_left
	await _wait(0.3)
	_check(is_equal_approx(level.time_left, frozen_time), "le timer ne descend plus en pause")
	_check(pause.find_child("Resume", true, false) is Button, "bouton Reprendre construit")
	pause.close()
	await _frames(2)
	_check(not pause.is_open and not get_tree().paused, "Reprendre relance le jeu")
	await _wait(0.2)
	_check(level.time_left < frozen_time, "le timer repart")

	# Recommencer depuis la pause repart à zéro, sans laisser le jeu figé.
	level._on_pause_pressed()
	await _frames(2)
	level.player.health = 5.0
	pause._on_restart()
	await _frames(12)
	_check(not get_tree().paused, "Recommencer lève la pause")
	_check(not level.completed and not level.failed, "le niveau est réarmé")
	_check(is_equal_approx(level.player.health, level.player.max_health_value()),
		"la vie est restaurée")
	_check(level.time_left > frozen_time - 1.0, "le temps est réarmé")


# -----------------------------------------------------------------#
#                        BOUCLE COMPLÈTE                           #
# -----------------------------------------------------------------#

func _test_full_loop() -> void:
	print("[loop] carte → niveau → résultat → boutique → carte")
	_reset_save(0)
	GameState.mode = GameState.GameMode.ADVENTURE
	await _load_level("%s/ch1_l1.tres" % ADVENTURE_DIR)
	_check(level.level_data.id == "ch1_l1", "le niveau chargé est ch1_l1")
	# Fin de niveau : la sauvegarde enregistre étoiles et cauris.
	level._win()
	await _frames(4)
	_check(level.completed, "le niveau se termine")
	_check(level.result_screen.shown and level.result_screen.victory,
		"l'écran de résultat s'affiche")
	_check(level.result_screen.menu_button.text == "CONTINUER",
		"le bouton de sortie dit CONTINUER en campagne")
	_check(SaveManager.stars_for("ch1_l1") >= 1, "les étoiles sont enregistrées")
	_check(int(SaveManager.data["cauris"]) > 0, "les cauris sont crédités")
	var earned := int(SaveManager.data["cauris"])
	_check(level.result_screen.detail_text().contains("cauris"), "le résultat annonce les cauris")
	var panel := level.result_screen.get_node("View/Panel") as Control
	_check(is_equal_approx(panel.get_global_rect().get_center().x,
		level.get_viewport().get_visible_rect().size.x * 0.5),
		"l'écran de résultat est centré")

	# Retour à la carte : le niveau suivant est ouvert et les étoiles visibles.
	level.queue_free()
	level = null
	await _frames(4)
	var packed := load("res://scenes/ui/AdventureMap.tscn") as PackedScene
	var map := packed.instantiate() as AdventureMap
	add_child(map)
	await _frames(4)
	_check(map.can_play("ch1_l2"), "ch1_l2 s'ouvre après la victoire")
	_check((map.level_buttons["ch1_l1"] as Button).text.contains("★"),
		"la carte montre l'étoile gagnée")
	_check(map.get_node("Layout/Header/Cauris").text == "CAURIS %d" % earned,
		"la carte affiche les cauris gagnés")
	map.queue_free()
	await _frames(2)

	# Boutique : dépenser les cauris gagnés, puis revenir à la carte.
	SaveManager.data["cauris"] = 500
	var shop := (load("res://scenes/ui/Shop.tscn") as PackedScene).instantiate() as Shop
	add_child(shop)
	await _frames(4)
	var before := int(SaveManager.data["cauris"])
	shop.buy("souffle")
	_check(SaveManager.upgrade_level("souffle") == 1, "achat depuis la boucle")
	_check(int(SaveManager.data["cauris"]) < before, "les cauris baissent")
	shop.queue_free()
	await _frames(2)
	SaveManager.data["upgrades"] = {}
