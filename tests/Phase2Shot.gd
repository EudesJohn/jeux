extends Node
## Sonde VISUELLE de la PHASE 2 (à lancer à la main, PC ou téléphone) : elle
## charge l'arène ARENA réelle, imprime la géométrie du HUD, puis enregistre
## trois captures dans `user://` :
##   shot_p2_arena.png   arène ARENA : anneau de cible 3D + anneau du HUD ;
##   shot_p2_guard.png   garde parfaite : message, vignette, contre-attaque ;
##   shot_p2_special.png tourbillon du sabre : particules, tour complet.
##   godot --path . res://tests/Phase2Shot.tscn

var arena: Node3D
var player: Player3D
var camera_rig: CameraRig
var hud: HUD
var dummy: Dummy3D


func _ready() -> void:
	arena = load("res://scenes/tests/ArenaTest.tscn").instantiate() as Node3D
	add_child(arena)
	await get_tree().create_timer(2.0).timeout
	player = arena.get_node("Player3D") as Player3D
	camera_rig = arena.get_node("CameraRig") as CameraRig
	hud = arena.get_node("HUD") as HUD
	dummy = arena.get_node("Dummy3D") as Dummy3D

	print("[shot2] viewport = ", get_viewport().get_visible_rect().size)
	print("[shot2] HUD vie = ", hud.life.get_global_rect(), " valeur ", hud.life.value)
	print("[shot2] HUD énergie = ", hud.energy.get_global_rect(), " valeur ", hud.energy.value)
	print("[shot2] HUD garde = ", hud.stability.get_global_rect(), " valeur ", hud.stability.value)
	print("[shot2] vignette = ", hud.vignette.get_global_rect(), " intensité ", hud.vignette_intensity())
	print("[shot2] cible verrouillée = ", camera_rig.lock_target,
		"  anneau 3D visible = ", camera_rig.ring.visible if camera_rig.ring else false)
	print("[shot2] anneau du HUD = ", hud.lock_on.get_global_rect(),
		" visible = ", hud.lock_on.visible)
	await _shot("user://shot_p2_arena.png")

	# Le mannequin doit être À PORTÉE : l'arène ARENA commence à 3,2 m, hors de
	# portée du tourbillon. On le rapproche pour la démonstration.
	dummy.global_position = player.global_position + Vector3(1.5, 0.0, 0.0)
	dummy.cooldown_left = 9999.0        ## aucune riposte parasite pendant les captures
	# Le mannequin fait face à la joueuse (sinon sa Hitbox, portée devant lui, ne
	# la touche pas : elle tourne à 6 rad/s après un déplacement).
	dummy.visual.rotation.y = PI * 0.5
	await get_tree().create_timer(0.5).timeout
	# Garde parfaite : message au centre, vignette allumée, contre-attaque.
	Events.touch_action.emit("guard", true)
	await get_tree().process_frame
	dummy.hitbox.damage = 12.0
	dummy.hitbox.crit_chance = 0.0
	dummy.hitbox.activate()
	await get_tree().create_timer(0.05).timeout
	await _shot("user://shot_p2_guard.png")
	print("[shot2] garde parfaite : message « ", hud.popup_text(),
		" » vie = ", player.health, " énergie = ", player.energy,
		" vignette = ", hud.vignette_intensity(),
		" mannequin étourdi = ", dummy.stun_left)
	dummy.hitbox.deactivate()
	Events.touch_action.emit("guard", false)

	# Spécial : tourbillon 360°, particules et tremblement.
	await get_tree().create_timer(0.9).timeout
	player.set_energy(player.balance.max_energy)
	Events.touch_action.emit("special", true)
	Events.touch_action.emit("special", false)
	await get_tree().create_timer(0.35).timeout
	await _shot("user://shot_p2_special.png")
	print("[shot2] spécial : état = ", Player3D.State.keys()[player.state],
		" énergie = ", player.energy,
		" effets à l'écran = ", _effects(),
		" mannequin à ", dummy.health, " vie")
	get_tree().quit(0)


func _effects() -> int:
	var count := 0
	for child in arena.get_children():
		var name := String(child.name).to_lower()
		if name.contains("impactfx") or name.contains("damagenumber"):
			count += 1
	return count


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("[shot2] capture ", path, " err=", image.save_png(path), " taille=", image.get_size())
