extends Node
## Sonde VISUELLE (à lancer à la main, PC ou téléphone) : elle charge l'arène
## RÉELLE, imprime la géométrie du HUD et des boutons tactiles, puis enregistre
## deux captures dans `user://` : au repos et pendant un coup.
## Les deux sont nécessaires : un fondu d'animation raté n'effondre le buste
## qu'après un changement d'état (voir TestPuppet._clip).
##   godot --path . res://tests/ShotProbe.tscn

func _ready() -> void:
	var combat: Node3D = load("res://scenes/tests/CombatTest.tscn").instantiate() as Node3D
	add_child(combat)
	await get_tree().create_timer(2.0).timeout
	var player := combat.get_node("Player3D") as Player3D
	var dummy := combat.get_node("Dummy3D") as Dummy3D
	var hud := combat.get_node("HUD") as HUD
	var touches := combat.get_node("TouchControls") as TouchControls
	print("[shot] viewport = ", get_viewport().get_visible_rect().size)
	print("[shot] échelle 3D = ", get_viewport().scaling_3d_scale)
	print("[shot] HUD vie rect = ", hud.life.get_global_rect(), " valeur = ", hud.life.value)
	print("[shot] HUD énergie rect = ", hud.energy.get_global_rect(), " valeur = ", hud.energy.value)
	for name in ["Attack", "Guard", "Dodge", "Special", "Pause"]:
		var button := touches.get_node_or_null(name) as TouchButton
		print("[shot] bouton ", name, " rect = ", button.get_global_rect())
	print("[shot] joueuse ", player.global_position, "  mannequin ", dummy.global_position,
		" vie = ", dummy.health)
	await _shot("user://shot_idle.png")
	Events.touch_action.emit("attack", true)
	Events.touch_action.emit("attack", false)
	await get_tree().create_timer(0.25).timeout
	print("[shot] pendant le coup : torse de la poupée à ",
		(player.get_node("Visual/Puppet/Pivot/Torso") as Node3D).position.y, " m (repos 1,05)")
	await _shot("user://shot_attack.png")
	get_tree().quit(0)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("[shot] capture ", path, " err=", image.save_png(path), " taille=", image.get_size())
