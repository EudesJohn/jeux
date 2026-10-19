extends Node
## Captures pour la fiche Google Play (à lancer sur PC, PAS en headless) :
##
##   godot --path . --resolution 1280x720 res://tests/StoreShots.tscn
##
## Quatre PNG 1280×720 dans `export/shots/play/` : menu, arène, boss, victoire.
## Les scènes sont les vraies (MainMenu, Arena3D, LevelBase3D + fiche de niveau),
## donc les captures montrent le jeu, pas une maquette.

const OUT_DIR := "res://export/shots/play/"
const LEVEL_SCENE := "res://scenes/levels/LevelBase3D.tscn"
const ARENA_LEVEL := "res://data/levels/arena_01.tres"
const BOSS_LEVEL := "res://data/levels/adventure/ch1_l5.tres"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("[store] viewport = ", get_viewport().get_visible_rect().size)

	await _menu_shot()
	await _arena_shot()
	await _boss_shot()

	print("[store] terminé")
	get_tree().quit(0)


func _menu_shot() -> void:
	var menu: Node = load("res://scenes/main/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(1.4).timeout
	await _shot("01_menu.png")
	menu.queue_free()
	await get_tree().process_frame


func _arena_shot() -> void:
	# `Arena3D.tscn` ne contient que la foule (ni caméra ni HUD) : on passe par
	# une vraie fiche de niveau d'arène, comme le jeu.
	var arena := _spawn_level(ARENA_LEVEL)
	await get_tree().create_timer(2.5).timeout
	await _shot("02_arene.png")
	arena.queue_free()
	await get_tree().process_frame
	GameState.current_level_data = null


func _boss_shot() -> void:
	var level: LevelBase3D = _spawn_level(BOSS_LEVEL)
	await get_tree().create_timer(3.2).timeout
	await _shot("03_boss.png")
	await _victory_shot_from(level)



func _victory_shot_from(level: LevelBase3D) -> void:
	if level.result_screen == null:
		print("[store] ResultScreen absent")
		return
	level.result_screen.show_win(3, 42.0, 250)
	await get_tree().create_timer(0.4).timeout
	await _shot("04_victoire.png")


func _spawn_level(data_path: String) -> LevelBase3D:
	GameState.current_level_data = load(data_path)
	var level := load(LEVEL_SCENE).instantiate() as LevelBase3D
	add_child(level)
	return level


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR + file_name
	var err := image.save_png(path)
	print("[store] ", path, " err=", err, " taille=", image.get_size())
