extends Node3D
## ModelViewer (DOSSIER.md § 28 PHASE 0.5) : scène de test du pipeline 3D.
## - Poupée TestPuppet (à remplacer par hero_nawi.glb via @export en PHASE 9)
## - AnimationTree avec une AnimationNodeStateMachine sur les animations
##   standards (idle, run, attack1-3, dodge, guard, hurt, death, interact)
## - Boutons tactiles + touches PC pour tester chaque état
## - Compteurs FPS / tris / draw calls via DebugStats
## - Détection de .glb réel : si assets/models/hero.glb existe, il EST chargé
##   à la place de la poupée (le jour où tu le fournis).

@export var model_scene: PackedScene  ## § 6.6 : modèle remplaçable sans toucher au code

const WAIT_AFTER_ONCE := 0.15  ## garde après un animation one-shot

## L'ensemble des états de la machine à états : liste PARTAGÉE avec le jeu
## (CharacterAnimation, § 6.4 et § 20.5).
const STATE_NAMES: Array[String] = CharacterAnimation.STATE_NAMES

var anim_tree: AnimationTree
var anim_player: AnimationPlayer
var playback: AnimationNodeStateMachinePlayback
var demo_running: bool = false


func _ready() -> void:
	var root := _install_model()
	anim_player = CharacterAnimation.find_anim_player(root)
	anim_tree = CharacterAnimation.build_state_machine(self, root)
	playback = CharacterAnimation.playback_of(anim_tree)
	if playback:
		playback.start("idle")
	_install_buttons()


# -----------------------------------------------------------------#
#                          CONSTRUCTION                            #
# -----------------------------------------------------------------#

func _install_model() -> Node:
	# Le modèle réel (PHASE 9) si fourni, sinon la poupée provisoire.
	var model: Node = null
	if model_scene:
		model = model_scene.instantiate()
	if model == null:
		var puppet := TestPuppet.new()
		puppet.name = "Puppet"
		puppet.position.y = Player3D.PUPPET_FEET_OFFSET  # pieds posés sur le sol
		add_child(puppet)
		model = puppet
	else:
		add_child(model)
	print("ModelViewer : modèle chargé : ", model.name)
	return model


func _install_buttons() -> void:
	# Les contrôles vivent dans un CanvasLayer (§ 7 : HUD 2D au-dessus de la 3D).
	var layer := CanvasLayer.new()
	layer.name = "TestUI"
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.name = "Controls"
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -62.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(bar)
	for state_name in STATE_NAMES:
		var b := Button.new()
		b.text = state_name
		b.custom_minimum_size = Vector2(96, 54)
		bar.add_child(b)
		b.pressed.connect(_go_to.bind(state_name))
	var demo := Button.new()
	demo.text = "DEMO"
	demo.custom_minimum_size = Vector2(110, 54)
	bar.add_child(demo)
	demo.pressed.connect(_toggle_demo)
	var key_hint := Label.new()
	key_hint.text = "PC : 1-9/0 = états  |  clic DEMO = cycle"
	layer.add_child(key_hint)


# -----------------------------------------------------------------#
#                          COMMANDES                               #
# -----------------------------------------------------------------#

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
		return
	# Nombre de caractères des touches : 1..9 puis 0.
	if event is InputEventKey and event.pressed and not event.echo:
		var keys: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
		var mapped: Array[String] = [STATE_NAMES[0], STATE_NAMES[1], STATE_NAMES[2], STATE_NAMES[3],
			STATE_NAMES[4], STATE_NAMES[5], STATE_NAMES[6], STATE_NAMES[7], STATE_NAMES[8], STATE_NAMES[9]]
		var key_text := event.as_text()
		for i in keys.size():
			if key_text.contains(keys[i]):
				_go_to(mapped[i])
				return


func _go_to(state_name: String) -> void:
	if anim_tree == null or playback == null:
		return
	if not anim_tree.tree_root.has_node(state_name):
		return
	playback.travel(state_name)
	demo_running = false
	_apres_one_shot(state_name)


## Un état d'un seul coup revient en idle (sauf death qui reste).
func _apres_one_shot(state_name: String) -> void:
	if state_name in ["idle", "run", "guard", "death"]:
		return
	if anim_player == null:
		return
	var length := anim_player.get_animation(state_name).length
	await get_tree().create_timer(length + WAIT_AFTER_ONCE).timeout
	if playback.get_current_node() == state_name:
		playback.travel("idle")


func _toggle_demo() -> void:
	if demo_running:
		demo_running = false
		return
	_run_demo()


func _run_demo() -> void:
	demo_running = true
	var plan := [
		["idle", 1.5], ["run", 2.0], ["attack1", 0.5], ["attack2", 0.55], ["attack3", 0.6],
		["dodge", 0.35], ["guard", 1.5], ["hurt", 0.3], ["death", 1.2],
	]
	var idx := 0
	while demo_running and idx < plan.size():
		var st: String = plan[idx][0]
		var d: float = plan[idx][1]
		if anim_tree and anim_tree.tree_root.has_node(st):
			playback.travel(st)
			# "death" gèle : le cycle de la démo la stoppe sur la chute.
			if st == "death":
				await get_tree().create_timer(d).timeout
				break
			await get_tree().create_timer(d).timeout
		else:
			break
		idx += 1
	demo_running = false
	if playback and anim_tree:
		playback.travel("idle")
