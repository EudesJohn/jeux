extends Node3D
class_name ImpactFX
## Particules d'impact (DESIGN.md § 8.7 et § 28 : « particules d'impact »).
## `ImpactFX.spawn(...)` affiche l'effet ; le nœud n'est PAS jeté : il repart
## dans un pool (§ 25, pooling) et resservira à l'impact suivant.
##
## CPUParticles3D uniquement (pas de GPUParticles) : le moteur Compatibility
## (OpenGL ES 3.0, § 4) doit tourner sur les téléphones d'entrée de gamme.
## Le nombre de particules suit la qualité graphique (`Performance`).

## Couleurs de la DA (§ 5) : or royal, crème, bleu fleuve (garde), rouge (dégâts).
const GOLD: Color = Color(0.89, 0.66, 0.17)
const CREAM: Color = Color(0.96, 0.91, 0.82)
const BLUE: Color = Color(0.24, 0.55, 0.75)
const RED: Color = Color(0.72, 0.16, 0.13)

const LIFETIME: float = 0.45
const SELF_FREE_DELAY: float = 1.0
const POOL_MAX: int = 16

static var _pool: Array[ImpactFX] = []

var _particles: CPUParticles3D = null


## `kind` : "hit" (coup normal), "crit" (étincelle dorée, § 8.7), "block"
## (garde), "perfect" (garde parfaite), "special" (tourbillon), "hurt".
## `parent` doit être un Node3D du monde.
static func spawn(parent: Node, position: Vector3, kind: String = "hit",
		scale_mult: float = 1.0) -> void:
	if parent == null:
		return
	var fx := _take()
	fx.name = "ImpactFX"
	parent.add_child(fx)
	fx.global_position = position
	fx._build(kind, scale_mult * Quality.particle_scale())


## Nombre d'effets en réserve (tests du pooling).
static func pool_size() -> int:
	return _pool.size()


static func _take() -> ImpactFX:
	while not _pool.is_empty():
		var candidate: ImpactFX = _pool.pop_back()
		if is_instance_valid(candidate) and candidate.get_parent() == null \
				and candidate._particles != null:
			return candidate
	return ImpactFX.new()


func _build(kind: String, scale_mult: float) -> void:
	if _particles == null or not is_instance_valid(_particles):
		_particles = CPUParticles3D.new()
		add_child(_particles)
	var particles := _particles
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3(0.0, -6.0, 0.0)
	particles.lifetime = LIFETIME
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0

	match kind:
		"crit":
			particles.amount = 26
			particles.initial_velocity_min = 4.5
			particles.initial_velocity_max = 7.5
			particles.scale_amount_min = 0.16
			particles.scale_amount_max = 0.30
			particles.color = GOLD
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 0.28
		"block":
			particles.amount = 12
			particles.initial_velocity_min = 2.0
			particles.initial_velocity_max = 3.6
			particles.scale_amount_min = 0.08
			particles.scale_amount_max = 0.16
			particles.color = BLUE
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 0.24
		"perfect":
			particles.amount = 22
			particles.initial_velocity_min = 3.0
			particles.initial_velocity_max = 5.5
			particles.scale_amount_min = 0.10
			particles.scale_amount_max = 0.22
			particles.color = CREAM
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 0.30
		"special":
			particles.amount = 30
			particles.initial_velocity_min = 3.5
			particles.initial_velocity_max = 6.0
			particles.scale_amount_min = 0.12
			particles.scale_amount_max = 0.24
			particles.color = CREAM
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 1.2
			particles.spread = 90.0
		"hurt":
			particles.amount = 14
			particles.initial_velocity_min = 2.5
			particles.initial_velocity_max = 4.5
			particles.scale_amount_min = 0.09
			particles.scale_amount_max = 0.18
			particles.color = RED
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 0.26
		_:
			particles.amount = 18
			particles.initial_velocity_min = 3.0
			particles.initial_velocity_max = 5.5
			particles.scale_amount_min = 0.10
			particles.scale_amount_max = 0.20
			particles.color = GOLD
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particles.emission_sphere_radius = 0.25

	particles.scale_amount_min *= scale_mult
	particles.scale_amount_max *= scale_mult
	particles.emitting = true
	_auto_release()


## Retour au pool après la vie des particules. `ignore_time_scale` : un hit-stop
## (§ 8.2) fige le temps du jeu — l'effet ne doit pas rester à l'écran pour
## autant.
func _auto_release() -> void:
	await get_tree().create_timer(SELF_FREE_DELAY, true, false, true).timeout
	if not is_instance_valid(self):
		return
	_release()


func _release() -> void:
	if _particles != null and is_instance_valid(_particles):
		_particles.emitting = false
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	if _pool.size() < POOL_MAX:
		_pool.append(self)
	else:
		queue_free()
