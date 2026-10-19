extends RefCounted
class_name CharacterAnimation
## Bibliothèque d'animations partagée par TOUS les personnages (DESIGN.md § 6.4).
## Un seul endroit définit la liste des états standards et construit
## l'AnimationTree (AnimationNodeStateMachine) : remplacer la poupée de test par
## un vrai .glb Mixamo (§ 6.6) ne change ni cette liste ni le code gameplay.

## Noms d'états STANDARDS du projet (§ 20.5). Tous les modèles (poupée, .glb
## Mixamo retargeté) doivent exposer exactement ces noms d'animations.
const STATE_NAMES: Array[String] = [
	"idle", "run", "attack1", "attack2", "attack3",
	"dodge", "guard", "hurt", "death", "interact",
]

## Durée de fondu entre deux états. Court : le combat doit rester net.
const XFADE: float = 0.12


## Premier AnimationPlayer trouvé dans le modèle (le .glb importé en contient un).
static func find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_anim_player(child)
		if found:
			return found
	return null


## Construit un AnimationTree à état unique sur `host` (le personnage) à partir
## des animations du `model`. Retourne null (et prévient) si le modèle n'expose
## aucune animation. Toutes les paires d'états sont reliées : chaque état est
## atteignable par `playback.travel(nom_etat)`.
static func build_state_machine(host: Node, model: Node,
		state_names: Array[String] = STATE_NAMES) -> AnimationTree:
	var names: Array[String] = state_names
	if names.is_empty():
		names = STATE_NAMES
	var player := find_anim_player(model)
	if player == null:
		push_warning("CharacterAnimation : aucun AnimationPlayer dans %s" % model.name)
		return null

	var tree := AnimationTree.new()
	tree.name = "AnimTree"
	tree.anim_player = player.get_path()
	var state_machine := AnimationNodeStateMachine.new()
	var installed: Array[String] = []
	for state_name in names:
		if not player.has_animation(state_name):
			push_warning("CharacterAnimation : animation '%s' absente de %s" % [state_name, model.name])
			continue
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = state_name
		state_machine.add_node(state_name, anim_node)
		installed.append(state_name)
	for from_state in installed:
		for to_state in installed:
			if to_state == from_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = XFADE
			state_machine.add_transition(from_state, to_state, transition)
	tree.tree_root = state_machine
	host.add_child(tree)
	tree.active = true
	return tree


## Raccourci : le playback de la machine à états (travel / get_current_node).
static func playback_of(tree: AnimationTree) -> AnimationNodeStateMachinePlayback:
	if tree == null:
		return null
	return tree.get("parameters/playback") as AnimationNodeStateMachinePlayback


## Démarre la machine à états sur `state_name` en réessayant à chaque frame.
## Un AnimationTree n'accepte start()/travel() qu'après quelques frames : appelé
## trop tôt, l'appel est silencieusement ignoré et le personnage reste figé.
## À appeler depuis _physics_process tant que la fonction renvoie false.
static func start_when_ready(playback: AnimationNodeStateMachinePlayback,
		state_name: String, tries: int, max_tries: int = 30) -> bool:
	if playback == null:
		return true
	if tries >= max_tries:
		push_warning("CharacterAnimation : état '%s' jamais démarré" % state_name)
		return true
	playback.start(state_name)
	return playback.get_current_node() != StringName("")
