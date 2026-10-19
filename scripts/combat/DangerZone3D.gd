extends Node3D
class_name DangerZone3D
## Zone de danger DESSINÉE AU SOL (DESIGN.md § 10 : « zones de danger dessinées
## au sol, decals rouges »). Elle s'allume pendant le télégraphe, puis frappe
## une seule fois tout ce qui se trouve dans le disque.
##
## Utilisée par `BossBase3D` (charge, sabre circulaire, pluie de flèches, onde
## de la frappe au sol, boules d'ombre). Le disque est un simple cylindre plat :
## aucun decal ni texture à fournir (§ 4 : budgets).

const RING: int = 40
const IDLE_ALPHA: float = 0.16
const READY_ALPHA: float = 0.42

var radius: float = 2.0
var damage: float = 10.0
var warn_time: float = 0.7       ## temps de lecture avant le coup (§ 9 : 0,3-0,5 s)
var linger: float = 0.22         ## temps d'extinction
var owner_actor: Node = null     ## le boss : ses zones ne le blessent pas
## ANNEXE §7.2 : couleur du code d'attaque (Hitbox3D.Danger).
var danger: int = Hitbox3D.Danger.WHITE

var triggered: bool = false
var expired: bool = false         ## lisible par les tests
var elapsed: float = 0.0

var _mesh: MeshInstance3D
var _material: StandardMaterial3D


## Crée et pose une zone. `at` est la position au sol (y ignoré).
static func spawn(parent: Node, at: Vector3, zone_radius: float, zone_damage: float,
		warning: float, source: Node = null, zone_danger: int = 0) -> DangerZone3D:
	if parent == null:
		return null
	var zone := DangerZone3D.new()
	zone.name = "DangerZone3D"
	zone.radius = maxf(0.2, zone_radius)
	zone.damage = maxf(0.0, zone_damage)
	zone.warn_time = maxf(0.05, warning)
	zone.owner_actor = source
	zone.danger = zone_danger
	parent.add_child(zone)
	zone.global_position = Vector3(at.x, 0.02, at.z)
	return zone


func _ready() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = RING
	mesh.rings = 1
	_material = StandardMaterial3D.new()
	var color := Hitbox3D.DANGER_COLORS[clampi(danger, 0, Hitbox3D.DANGER_COLORS.size() - 1)]
	_material.albedo_color = Color(color.r, color.g, color.b, IDLE_ALPHA)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	_mesh = MeshInstance3D.new()
	_mesh.name = "Disc"
	_mesh.mesh = mesh
	_mesh.material_override = _material
	add_child(_mesh)


func _process(delta: float) -> void:
	if expired:
		return
	elapsed += delta
	if not triggered:
		# Le rouge s'intensifie : la joueuse sait exactement quand partir.
		var ratio := clampf(elapsed / warn_time, 0.0, 1.0)
		_material.albedo_color.a = lerpf(IDLE_ALPHA, READY_ALPHA, ratio)
		if elapsed >= warn_time:
			_trigger()
		return
	var fade := clampf(1.0 - (elapsed - warn_time) / linger, 0.0, 1.0)
	_material.albedo_color.a = READY_ALPHA * fade
	if elapsed >= warn_time + linger:
		expired = true
		queue_free()


## Frappe : blesse toutes les joueuses présentes dans le disque.
func _trigger() -> void:
	triggered = true
	for player in get_tree().get_nodes_in_group("players"):
		var actor := player as Node3D
		if actor == null or actor == owner_actor:
			continue
		if actor.get("state") == Player3D.State.DEAD:
			continue
		var flat := Vector2(actor.global_position.x - global_position.x,
			actor.global_position.z - global_position.z)
		if flat.length() > radius:
			continue
		var hurtbox: Hurtbox3D = actor.get("hurtbox")
		if hurtbox == null:
			continue
		var info := DamageInfo.new()
		info.amount = damage
		info.knockback = 1.6
		info.source_position = global_position
		info.source_actor = owner_actor
		info.is_heavy = true
		info.danger = danger
		hurtbox.receive_hit(info)
		FX.impact(get_tree().current_scene, actor.global_position + Vector3(0.0, 1.0, 0.0), "hit")
