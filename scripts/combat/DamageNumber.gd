extends Label3D
class_name DamageNumber
## Nombre de dégâts flottant (DESIGN.md § 16 : lisibilité du combat).
## Un seul endroit le fabrique : la joueuse, les ennemis et le mannequin
## l'affichent par `spawn()`. Critique = plus grand, doré, « ! » (§ 8.7).
##
## § 25 (pooling) : les étiquettes ne sont plus créées puis jetées à chaque
## coup — elles sont **réutilisées**. Sur un téléphone d'entrée de gamme, un
## échange de coups toutes les 0,4 s créait des milliers de nœuds par partie.
##
## Utilisation : DamageNumber.spawn(get_parent(), global_position, 12.0).

const NORMAL_COLOR: Color = Color(1.0, 0.93, 0.75)
const CRIT_COLOR: Color = Color(1.0, 0.78, 0.19)
const BLOCK_COLOR: Color = Color(0.62, 0.85, 1.0)
const HEAL_COLOR: Color = Color(0.45, 0.95, 0.5)

## Taille du pool : au-delà, les étiquettes en trop sont libérées pour de bon.
const POOL_MAX: int = 24

static var _pool: Array[DamageNumber] = []


## `kind` : "normal", "crit", "block", "heal". `parent` doit être un Node3D
## (le monde), pas le personnage : le nombre ne doit pas suivre le modèle.
static func spawn(parent: Node, position: Vector3, amount: float,
		kind: String = "normal") -> void:
	if parent == null:
		return
	var label := _take()
	label.name = "DamageNumber"      # nom stable (tests, débogage à l'écran)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 16
	label.position = position
	label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	match kind:
		"crit":
			label.text = "%d !" % roundi(amount)
			label.font_size = 96
			label.modulate = CRIT_COLOR
			label.outline_modulate = Color(0.35, 0.15, 0.0)
		"block":
			label.text = str(roundi(amount))
			label.font_size = 48
			label.modulate = BLOCK_COLOR
		"heal":
			label.text = "+%d" % roundi(amount)
			label.font_size = 56
			label.modulate = HEAL_COLOR
		_:
			label.text = str(roundi(amount))
			label.font_size = 64
			label.modulate = NORMAL_COLOR
	parent.add_child(label)
	label._play()


## Nombre d'étiquettes actuellement en réserve (tests du pooling).
static func pool_size() -> int:
	return _pool.size()


static func _take() -> DamageNumber:
	while not _pool.is_empty():
		var candidate: DamageNumber = _pool.pop_back()
		if is_instance_valid(candidate) and candidate.get_parent() == null:
			return candidate
	return DamageNumber.new()


## Départ du nombre flottant : il monte et s'efface, puis retourne au pool.
func _play() -> void:
	var start_y := position.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start_y + 0.9, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(_release)


func _release() -> void:
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	if _pool.size() < POOL_MAX:
		_pool.append(self)
	else:
		queue_free()
