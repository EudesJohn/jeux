extends Node
## Test fonctionnel de la PHASE 4 (DESIGN.md § 12.2 et § 28) :
##   godot --headless --path . res://tests/Phase4Test.tscn
##
## Validation de la phase : les objectifs Sauvetage et Escorte marchent sur la
## VRAIE scène `scenes/levels/LevelBase3D.tscn`, avec les VRAIES fiches
## `data/levels/rescue/*.tres`. Le test vérifie :
##   * la table du § 12.2 (prisonniers, ennemis, pièges, temps, nuit) ;
##   * la cage et l'interaction de 2 s (maintenir libère, lâcher fait
##     redescendre la jauge, un prisonnier mort = échec) ;
##   * l'indicateur « PRISONNIERS x/y » et la jauge du HUD ;
##   * l'escorte : le villageois suit, sa mort fait échouer le niveau, l'amener
##     à la sortie le termine ;
##   * la nuit (brouillard sombre + lumière autour de la joueuse) ;
##   * l'écran de résultat (victoire ★★★, défaite et sa raison, REJOUER) ;
##   * l'objectif « boss » en squelette (PHASE 6).
##
## Sortie : « PHASE 4 : OK » (code 0) ou la liste des échecs (code 1).

const LEVEL_SCENE: String = "res://scenes/levels/LevelBase3D.tscn"
const RESCUE_DIR: String = "res://data/levels/rescue"
const FROZEN_WAVES: float = 1000.0
## En dessous de cette largeur, le bouton « Interaction » n'est pas à sa place
## à l'écran : la chaîne doigt -> bouton -> jeu n'a pas de sens.
const MIN_VIEWPORT_FOR_TOUCH: float = 1000.0

var failures: int = 0
var checks: int = 0
var skipped: int = 0

var level: LevelBase3D = null
var save_cauris: int = 0
var save_levels: Dictionary = {}


func _ready() -> void:
	print("=== Test fonctionnel PHASE 4 ===")
	var only := OS.get_environment("PHASE4_ONLY")
	var sections: Dictionary = {
		"select": _test_rescue_select,
		"data": _test_level_data,
		"cage": _test_prisoner_cage,
		"escort": _test_escort,
		"hud": _test_hud,
		"night": _test_night,
		"touch": _test_touch_interaction,
		"result": _test_result_screen,
		"boss": _test_boss_skeleton,
	}
	EnemyRegistry.preload_all()
	save_cauris = int(SaveManager.data["cauris"])
	save_levels = (SaveManager.data["levels"] as Dictionary).duplicate(true)

	for name in sections.keys():
		if only != "" and not only.split(",").has(name):
			continue
		await (sections[name] as Callable).call()

	SaveManager.data["cauris"] = save_cauris
	SaveManager.data["levels"] = save_levels
	SaveManager.save_game()

	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d   Ignorées : %d" % [checks, failures, skipped])
	print("PHASE 4 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
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


## Attente en TEMPS RÉEL : insensible aux hit-stops et aux ralentis.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Charge un niveau RÉEL depuis un .tres (et libère le précédent).
func _load_level(path: String) -> LevelBase3D:
	if level != null and is_instance_valid(level):
		if level.spawner != null:
			level.spawner.finished = true
		level.queue_free()
		level = null
		await _frames(4)
	var scene := load(LEVEL_SCENE).instantiate() as LevelBase3D
	scene.level_data = load(path) as LevelData
	scene.wave_delay_multiplier = FROZEN_WAVES
	add_child(scene)
	await _frames(10)
	level = scene
	return level


func _rescue_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(RESCUE_DIR)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			out.append("%s/%s" % [RESCUE_DIR, file_name])
	out.sort()
	return out


## Place la joueuse juste devant la cage et attend que la zone la détecte.
func _approach(prisoner: Prisoner3D) -> void:
	level.player.global_position = prisoner.global_position + Vector3(-1.2, 0.1, 0.0)
	level.player.velocity = Vector3.ZERO
	await _frames(6)


## Maintenir l'interaction pendant `seconds` (le Prisoner3D lit
## `player.interact_held` à chaque frame physique).
func _hold(seconds: float) -> void:
	level.player.interact_held = true
	await _wait(seconds)
	level.player.interact_held = false


# -----------------------------------------------------------------#
#                    ÉCRAN DE CHOIX (RescueSelect)                 #
# -----------------------------------------------------------------#

func _test_rescue_select() -> void:
	print("[select] écran de choix du Sauvetage")
	# Sauvegarde vierge : le déblocage séquentiel doit être observable.
	var saved: Dictionary = (SaveManager.data["levels"] as Dictionary).duplicate(true)
	SaveManager.data["levels"] = {}
	var packed := load("res://scenes/ui/RescueSelect.tscn") as PackedScene
	var select := packed.instantiate() as RescueSelect
	add_child(select)
	await _frames(4)
	_check(select.levels.size() == 18, "les 18 fiches sont listées (%d)" % select.levels.size())
	var rows := select.get_node("Panel/Root/Scroll/Rows") as VBoxContainer
	_check(rows.get_child_count() == 18, "18 boutons (%d)" % rows.get_child_count())
	if rows.get_child_count() >= 3:
		var first := rows.get_child(0) as Button
		_check(first.name == "rescue_01", "le premier bouton est rescue_01")
		_check(not first.disabled, "le niveau 1 est ouvert")
		_check(first.text.contains("1 prisonnier"), "le bouton annonce 1 prisonnier")
		_check(not first.text.contains("★"), "aucune étoile sur une sauvegarde vierge")
		var second := rows.get_child(1) as Button
		_check(second.disabled, "le niveau 2 reste verrouillé")
		# Une fiche escort est listée avec son mode.
		var escort_button: Button = null
		for child in rows.get_children():
			if (child as Button).name == "escort_01":
				escort_button = child as Button
		_check(escort_button != null, "l'Escorte figure dans la liste")
		if escort_button != null:
			_check(escort_button.text.contains("ESCORTE"), "mode ESCORTE annoncé")
			_check(escort_button.text.contains("2 villageois"), "2 villageois annoncés")
	# Terminer rescue_01 ouvre rescue_02.
	SaveManager.data["levels"] = {"rescue_01": {"stars": 2}}
	select.queue_free()
	await _frames(2)
	var again := (load("res://scenes/ui/RescueSelect.tscn") as PackedScene).instantiate() as RescueSelect
	add_child(again)
	await _frames(4)
	var rows_again := again.get_node("Panel/Root/Scroll/Rows") as VBoxContainer
	_check(not (rows_again.get_child(1) as Button).disabled, "terminer rescue_01 ouvre rescue_02")
	_check(again.stars_for("rescue_01") == 2, "les étoiles enregistrées sont affichées")
	_check((rows_again.get_child(0) as Button).text.contains("★★"), "★★ sur le bouton")
	again.queue_free()
	await _frames(2)
	SaveManager.data["levels"] = saved


# -----------------------------------------------------------------#
#                     TABLE DU § 12.2                              #
# -----------------------------------------------------------------#

func _test_level_data() -> void:
	print("[data] fiches de Sauvetage")
	var files := _rescue_files()
	_check(files.size() == 18, "18 fiches dans data/levels/rescue (%d trouvées)" % files.size())
	var rescue_count := 0
	var escort_count := 0
	var night_count := 0
	var ids: Dictionary = {}
	for path in files:
		var data := load(path) as LevelData
		_check(data != null, "charge %s" % path.get_file())
		if data == null:
			continue
		_check(not ids.has(data.id), "id unique : %s" % data.id)
		ids[data.id] = true
		_check(data.is_lane(), "%s est un couloir (§ 12.2)" % data.id)
		_check(data.time_limit >= 90 and data.time_limit <= 150,
			"%s : %d s de limite (§ 12.2)" % [data.id, data.time_limit])
		_check(not data.enemy_waves.is_empty(), "%s a des vagues" % data.id)
		_check(data.ally_life == 40.0, "%s : allié à 40 vie" % data.id)
		_check(data.checkpoint_at > 0.0, "%s a un checkpoint" % data.id)
		if data.objective == "rescue":
			rescue_count += 1
			_check(data.prisoners >= 1, "%s : au moins un prisonnier" % data.id)
			_check(data.escorts == 0, "%s : pas de villageois" % data.id)
		elif data.objective == "escort":
			escort_count += 1
			_check(data.escorts >= 1, "%s : au moins un villageois" % data.id)
			_check(data.prisoners == 0, "%s : pas de cage" % data.id)
			_check(data.needs_exit(), "%s demande une sortie" % data.id)
		else:
			_check(false, "%s : objectif rescue ou escort (%s)" % [data.id, data.objective])
		if data.night:
			night_count += 1
	_check(rescue_count == 17, "17 niveaux de Sauvetage (%d)" % rescue_count)
	_check(escort_count == 1, "1 niveau d'Escorte (%d)" % escort_count)
	_check(night_count == 5, "5 niveaux de nuit 13-17 (%d)" % night_count)

	# La table du § 12.2, bloc par bloc.
	_check(_prisoners_of("rescue_01") == 1, "1-3 : 1 prisonnier (rescue_01)")
	_check(_prisoners_of("rescue_03") == 1, "1-3 : 1 prisonnier (rescue_03)")
	_check(_hazards_of("rescue_01").is_empty(), "1-3 : aucun piège")
	_check(_prisoners_of("rescue_04") == 2, "4-7 : 2 prisonniers (rescue_04)")
	_check(_prisonners_between(4, 7, 2, 3), "4-7 : 2 à 3 prisonniers")
	_check(_hazards_of("rescue_05").has("pit") and _hazards_of("rescue_05").has("arrows"),
		"4-7 : fosses et flèches")
	_check(_prisoners_of("rescue_08") == 3, "8-12 : 3 prisonniers (rescue_08)")
	_check(_prisonners_between(8, 12, 3, 4), "8-12 : 3 à 4 prisonniers dispersés")
	_check(_type_present("rescue_09", "archer"), "8-12 : archers")
	_check(_type_present("rescue_09", "guard"), "8-12 : gardes d'alerte")
	_check(_hazards_of("rescue_10").has("fire"), "8-12 : le feu apparaît")
	_check(_prisoners_of("rescue_13") == 4 and _prisoners_of("rescue_17") == 4,
		"13-17 : 4 prisonniers")
	_check(_type_present("rescue_13", "brute"), "13-17 : brutes")
	var night_data := load("%s/rescue_13.tres" % RESCUE_DIR) as LevelData
	_check(night_data != null and night_data.night, "13-17 : la nuit tombe")
	var escort := load("%s/escort_01.tres" % RESCUE_DIR) as LevelData
	_check(escort != null and escort.escorts == 2, "escorte : 2 villageois")
	_check(escort != null and escort.time_limit == 130, "escorte : 130 s")


func _prisoners_of(id: String) -> int:
	var data := load("%s/%s.tres" % [RESCUE_DIR, id]) as LevelData
	return data.prisoners if data != null else -1


func _hazards_of(id: String) -> Array[String]:
	var data := load("%s/%s.tres" % [RESCUE_DIR, id]) as LevelData
	return data.hazards if data != null else [] as Array[String]


func _type_present(id: String, type_name: String) -> bool:
	var data := load("%s/%s.tres" % [RESCUE_DIR, id]) as LevelData
	return data != null and data.enemy_types().has(type_name)


## Vérifie que les niveaux `from`..`to` ont tous entre `low` et `high`
## prisonniers (les fiches `rescue_NN`).
func _prisonners_between(from: int, to: int, low: int, high: int) -> bool:
	for number in range(from, to + 1):
		var count := _prisoners_of("rescue_%02d" % number)
		if count < low or count > high:
			return false
	return true


# -----------------------------------------------------------------#
#                 CAGE ET INTERACTION DE 2 s                       #
# -----------------------------------------------------------------#

func _test_prisoner_cage() -> void:
	print("[cage] prisonnier, interaction de 2 s, échec si mort")
	await _load_level("%s/rescue_01.tres" % RESCUE_DIR)
	var prisoners := level.prisoner_nodes()
	_check(prisoners.size() == 1, "rescue_01 pose une cage (%d)" % prisoners.size())
	if prisoners.is_empty():
		return
	var prisoner := prisoners[0] as Prisoner3D
	_check(prisoner != null, "la cage est un Prisoner3D")
	var cage := prisoner.get_node_or_null("Cage")
	_check(cage != null and cage.visible, "la cage est visible")
	_check(prisoner.global_position.x > level.level_data.length_m * 0.4,
		"le prisonnier attend dans la 2e moitié du parcours")
	_check(prisoner.player == level.player, "le prisonnier connaît la joueuse")
	_check(level.prisoner_status() == Vector2i(0, 1), "compteur 0/1 au départ")
	_check(not level.interact_available(), "pas d'interaction à distance")
	_check(level.hud.prisoner_text() == "PRISONNIERS 0/1",
		"HUD : « %s »" % level.hud.prisoner_text())

	# Lâcher avant 2 s ne libère pas et la jauge redescend.
	await _approach(prisoner)
	_check(level.interact_available(), "l'interaction se propose près de la cage")
	_check(level.hud.hold_visible(), "la jauge du HUD apparaît")
	await _hold(0.8)
	var partial := prisoner.hold_ratio()
	_check(partial > 0.2 and partial < 0.9, "jauge partielle après 0,8 s (%.2f)" % partial)
	_check(not prisoner.freed_flag, "lâcher avant 2 s ne libère pas")
	await _wait(0.9)
	_check(prisoner.hold_ratio() < partial, "la jauge redescend quand on lâche")

	# Tenir 2 s libère : cage masquée, prisonnier allié, HUD à jour.
	await _hold(2.4)
	_check(prisoner.freed_flag, "2 s d'interaction libèrent le prisonnier")
	_check(not cage.visible, "la cage disparaît")
	_check(prisoner.follow, "le prisonnier libéré suit la joueuse")
	_check(level.prisoner_status() == Vector2i(1, 1), "compteur 1/1")
	await _frames(4)
	_check(level.completed, "libérer tous les prisonniers termine le niveau")
	_check(level.stars_earned == 3, "★★★ sans prisonnier blessé (%d)" % level.stars_earned)
	_check(level.result_screen.shown and level.result_screen.victory,
		"l'écran de victoire s'affiche")
	_check(level.hud.result_text().begins_with("NIVEAU TERMINÉ"), "HUD : fin de niveau")

	# Un prisonnier tué rend l'objectif impossible (§ 12.2).
	await _load_level("%s/rescue_04.tres" % RESCUE_DIR)
	var victims := level.prisoner_nodes()
	_check(victims.size() == 2, "rescue_04 pose deux cages (%d)" % victims.size())
	if victims.size() >= 2:
		var victim := victims[0] as Prisoner3D
		victim.on_hit_received(_lethal())
		await _frames(4)
		_check(victim.dead, "le prisonnier peut mourir")
		_check(level.failed, "un prisonnier mort fait échouer le niveau")
		_check(level.result_screen.shown and not level.result_screen.victory,
			"l'écran de défaite s'affiche")
		_check(level.result_screen.detail_text().contains("prisonnier"),
			"raison lisible : « %s »" % level.result_screen.detail_text())


func _lethal() -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = 999.0
	info.is_heavy = true
	return info


# -----------------------------------------------------------------#
#                          ESCORTE                                 #
# -----------------------------------------------------------------#

func _test_escort() -> void:
	print("[escort] villageois, échec si mort, réussite à la sortie")
	await _load_level("%s/escort_01.tres" % RESCUE_DIR)
	var villagers := level.escort_nodes()
	_check(villagers.size() == 2, "escort_01 pose deux villageois (%d)" % villagers.size())
	if villagers.size() < 2:
		return
	for node in villagers:
		var villager := node as Villager3D
		_check(villager != null and villager.follow, "le villageois suit la joueuse")
		_check(villager.max_health == 40.0, "40 vie (§ 12.2)")
	_check(level.exit_area != null, "l'escorte a une sortie")
	_check(level.objective is EscortObjective, "objectif EscortObjective")
	_check(not level.completed, "rien n'est gagné au départ")

	# Suivi réel : la joueuse avance, le villageois se rapproche.
	var before := (villagers[0] as Node3D).global_position
	level.player.global_position += Vector3(6.0, 0.0, 0.0)
	await _wait(1.0)
	var after := (villagers[0] as Node3D).global_position
	_check(after.distance_to(before) > 0.5,
		"le villageois avance derrière la joueuse (%.1f m)" % after.distance_to(before))

	# La mort d'un villageois arrête le niveau, sans attendre la fin du temps.
	(villagers[0] as Ally3D).on_hit_received(_lethal())
	await _frames(4)
	_check(level.failed, "un villageois mort fait échouer l'escorte")
	_check(level.result_screen.detail_text().contains("villageois"),
		"raison lisible : « %s »" % level.result_screen.detail_text())
	_check(not level.completed, "pas de victoire malgré la sortie")

	# Réussite : tous les villageois vivants à portée de la sortie.
	await _load_level("%s/escort_01.tres" % RESCUE_DIR)
	var live := level.escort_nodes()
	var exit_position := level.exit_area.global_position
	for node in live:
		(node as Node3D).global_position = exit_position + Vector3(-1.0, 0.0, 0.0)
	await _frames(6)
	_check(level.completed, "amener les villageois à la sortie termine le niveau")
	_check(level.stars_earned == 3, "★★★ sans blessé (%d)" % level.stars_earned)


# -----------------------------------------------------------------#
#                             HUD                                  #
# -----------------------------------------------------------------#

func _test_hud() -> void:
	print("[hud] jauge de 2 s et compteur de prisonniers")
	await _load_level("%s/rescue_05.tres" % RESCUE_DIR)
	var prisoners := level.prisoner_nodes()
	if prisoners.is_empty():
		_skip("rescue_05 sans prisonnier")
		return
	var prisoner := prisoners[0] as Prisoner3D
	_check(level.hud.prisoner_text() == "PRISONNIERS 0/2",
		"HUD : « %s »" % level.hud.prisoner_text())
	await _approach(prisoner)
	_check(level.hud.hold_visible(), "jauge visible à portée")
	level.player.interact_held = true
	await _wait(0.7)
	_check(level.hud.hold_bar.value > 0.1, "la jauge du HUD se remplit")
	level.player.interact_held = false
	await _frames(2)
	prisoner.free_prisoner()
	await _frames(4)
	_check(level.hud.prisoner_text() == "PRISONNIERS 1/2",
		"HUD après libération : « %s »" % level.hud.prisoner_text())
	_check(not level.completed, "il reste un prisonnier : le niveau continue")


# -----------------------------------------------------------------#
#                            NUIT                                  #
# -----------------------------------------------------------------#

func _test_night() -> void:
	print("[night] brouillard sombre et lumière autour de la joueuse")
	await _load_level("%s/rescue_13.tres" % RESCUE_DIR)
	var environment := level.environment_node.environment
	_check(environment.fog_enabled, "brouillard activé la nuit")
	_check(environment.ambient_light_energy < 0.8, "ambiance sombre")
	var light := level.player.get_node_or_null("NightLight")
	_check(light != null and light is OmniLight3D, "OmniLight autour de la joueuse")
	if light != null:
		_check((light as OmniLight3D).omni_range >= 8.0, "la lumière porte à 8 m et plus")
	await _load_level("%s/rescue_12.tres" % RESCUE_DIR)
	_check(not level.environment_node.environment.fog_enabled, "pas de brouillard de jour")
	_check(level.player.get_node_or_null("NightLight") == null, "pas de lumière de nuit")


# -----------------------------------------------------------------#
#                      ÉCRAN DE RÉSULTAT                           #
# -----------------------------------------------------------------#

func _test_result_screen() -> void:
	print("[result] victoire, défaite, REJOUER")
	await _load_level("%s/rescue_02.tres" % RESCUE_DIR)
	var screen := level.result_screen
	_check(screen != null and not screen.shown, "l'écran est masqué au départ")
	level._fail("temps")
	await _frames(2)
	_check(screen.shown and not screen.victory, "l'écran de défaite s'affiche")
	_check(screen.title_text() == "ÉCHEC", "titre « ÉCHEC »")
	_check(screen.detail_text().contains("temps"), "détail : « %s »" % screen.detail_text())
	_check(not level.completed, "une défaite n'est pas une victoire")

	# REJOUER reconstruit le niveau à partir de la même fiche.
	var before := level
	screen.press_replay()
	await _frames(12)
	# `restart()` reconstruit le contenu SUR la même instance (§ 20.9).
	_check(is_instance_valid(level) and level == before, "REJOUER reconstruit le niveau en place")
	_check(not level.failed and not level.completed, "le niveau repart à zéro")
	_check(level.objective != null and not level.objective.success(), "l'objectif est réarmé")
	_check(level.prisoner_nodes().size() == 1, "le prisonnier est de retour dans sa cage")
	_check(level.time_left > 0.0, "le temps est réarmé")
	_check(not level.result_screen.shown, "l'écran est de nouveau masqué")


# -----------------------------------------------------------------#
#              CHAÎNE TACTILE RÉELLE (§ 7 et § 12.2)               #
# -----------------------------------------------------------------#

## Le vrai chemin du doigt : bouton « Interaction » maintenu ->
## `Events.touch_action` -> `Player3D.interact_held` -> jauge -> libération.
## Ignoré sans écran : en `--headless` il n'y a pas de bouton à toucher.
func _test_touch_interaction() -> void:
	print("[touch] bouton « Interaction » maintenu 2 s")
	await _load_level("%s/rescue_01.tres" % RESCUE_DIR)
	var controls := level.get_node_or_null("TouchControls") as TouchControls
	_check(controls != null, "la scène de niveau porte les contrôles tactiles (§ 7)")
	if controls == null or controls.interact_button == null:
		_check(false, "le bouton « Interaction » existe")
		return
	_check(not controls.interact_button.visible, "le bouton est caché loin des cages")
	if DisplayServer.get_name() == "headless" \
			or get_viewport().get_visible_rect().size.x < MIN_VIEWPORT_FOR_TOUCH:
		_skip("chaîne tactile réelle : relancer sans --headless (fenêtre ≥ %.0f px)"
			% MIN_VIEWPORT_FOR_TOUCH)
		return
	_isolate_pointer(controls)

	var prisoners := level.prisoner_nodes()
	if prisoners.is_empty():
		_skip("rescue_01 sans prisonnier")
		return
	var prisoner := prisoners[0] as Prisoner3D
	await _approach(prisoner)
	await _frames(3)
	_check(controls.interact_button.visible, "le bouton apparaît près de la cage")

	var center := controls.interact_button.get_global_rect().get_center()
	_push_touch(5, center, true)
	await _frames(3)
	_check(level.player.interact_held, "doigt posé -> interaction maintenue")
	await _wait(0.8)
	_check(prisoner.hold_ratio() > 0.2 and not prisoner.freed_flag,
		"la jauge monte sous le doigt (%.2f)" % prisoner.hold_ratio())
	await _wait(1.6)
	_push_touch(5, center, false)
	await _frames(3)
	_check(prisoner.freed_flag, "2 s de doigt libèrent le prisonnier")
	_check(not level.player.interact_held, "doigt levé -> interaction relâchée")
	_check(not controls.interact_button.visible,
		"le bouton disparaît : plus rien à libérer")


## Sans écran il n'y a pas de souris ; avec une fenêtre, celle du bureau
## piloterait les contrôles pendant la mesure. Le test coupe le pilotage à la
## souris : les événements tactiles qu'il pousse lui-même passent toujours.
func _isolate_pointer(controls: TouchControls) -> void:
	var joystick := controls.get_node_or_null("Joystick") as VirtualJoystick
	if joystick != null:
		joystick.mouse_control = false
	for child in controls.get_children():
		if child is TouchButton:
			(child as TouchButton).mouse_control = false


func _push_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	get_viewport().push_input(event)


# -----------------------------------------------------------------#
#                    BOSS (SQUELETTE, PHASE 6)                     #
# -----------------------------------------------------------------#
func _test_boss_skeleton() -> void:
	print("[boss] objectif KillBoss en squelette")
	await _load_level("%s/rescue_01.tres" % RESCUE_DIR)
	var data := (level.level_data as LevelData).duplicate() as LevelData
	data.objective = "boss"
	data.id = "test_phase4_boss"
	level.load_level(data)
	await _frames(6)
	_check(level.objective is KillBossObjective, "objectif KillBossObjective")
	_check(not level.objective.success(), "pas gagné tant que le gardien vit")
	level.boss_defeated = true
	await _frames(3)
	_check(level.objective.success(), "le gardien tombé valide l'objectif")
	_check(level.completed, "le niveau se termine")
	_check(level.stars_earned == 3, "★★★ au-dessus de 50 % de vie")
