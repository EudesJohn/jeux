extends Node3D
class_name Ally3D
## Allié du mode Sauvetage (§ 12.2, PHASE 4) : prisonnier libéré ou villageois
## escorté. 40 vie, aucune collision de corps (il glisse au sol sans pousser
## personne) et une Hurtbox3D sur la couche 4 pour que les pièges du § 11
## puissent le blesser.
##
## Il n'attaque pas et ne se défend pas : sa seule défense, c'est la joueuse.
## `is_ally` empêche la Hitbox de la joueuse de le frapper (§ 8 : pas de tir
## ami) ; les ennemis, eux, ne s'occupent que de la joueuse (PHASE 4).

const BODY_COLOR: Color = Color(0.72, 0.52, 0.34)
const HEAD_COLOR: Color = Color(0.55, 0.38, 0.24)
const HURT_COLOR: Color = Color(1.0, 0.5, 0.45)

signal died(ally: Ally3D)

@export var max_health: float = 40.0          ## § 12.2 : villageois = 40 vie
@export var speed: float = 3.4                ## un peu plus vite que la joueuse
@export var follow_distance: float = 2.4      ## distance de suivi visée
@export var stop_distance: float = 1.6        ## il ne colle pas aux talons

## Un allié : la Hitbox de la joueuse l'ignore (tir ami interdit).
var is_ally: bool = true
var health: float = 40.0
var hurt: bool = false                        ## a encaissé un coup (§ 13 étoiles)
var dead: bool = false
var follow: bool = false                      ## suit la joueuse ?
var target: Node3D = null                     ## la joueuse suivie
var hurtbox: Hurtbox3D = null

var _body: MeshInstance3D
var _head: MeshInstance3D
var _body_material: StandardMaterial3D
var _flash_left: float = 0.0


func _ready() -> void:
	health = max_health
	_build()
	hurtbox = Hurtbox3D.new()
	hurtbox.name = "Hurtbox3D"
	hurtbox.collision_layer = 4               ## couche 4 : blessable par les pièges
	hurtbox.collision_mask = 0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.6
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.85
	hurtbox.add_child(collision)
	add_child(hurtbox)
	hurtbox.owner_actor = self
	add_to_group("allies")


## Graybox du § 28 : un corps, une tête, et un signe distinctif côté enfant.
func _build() -> void:
	_body = MeshInstance3D.new()
	_body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.28
	body_mesh.height = 1.2
	_body.mesh = body_mesh
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = BODY_COLOR
	_body.material_override = _body_material
	_body.position.y = 0.75
	add_child(_body)

	_head = MeshInstance3D.new()
	_head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	_head.mesh = head_mesh
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = HEAD_COLOR
	_head.material_override = head_material
	_head.position.y = 1.55
	add_child(_head)

	_add_marker()


## Signe distinctif : les enfants (prisonnier, villageois) le remplacent.
func _add_marker() -> void:
	pass


func _physics_process(delta: float) -> void:
	_flash_left = maxf(0.0, _flash_left - delta)
	_body_material.albedo_color = HURT_COLOR if _flash_left > 0.0 else BODY_COLOR
	if dead or not follow or target == null or not is_instance_valid(target):
		return
	var away := target.global_position - global_position
	away.y = 0.0
	var distance := away.length()
	if distance <= maxf(stop_distance, follow_distance - 0.6):
		return
	var step := minf(speed * delta, maxf(distance - stop_distance, 0.0))
	global_position += away.normalized() * step
	# Il regarde toujours du côté de la joueuse.
	if absf(away.x) > 0.05 or absf(away.z) > 0.05:
		rotation.y = atan2(-away.x, -away.z)


## Appelée par la Hurtbox3D : les alliés encaissent, ils ne bloquent pas.
func on_hit_received(info: DamageInfo) -> int:
	if dead:
		return Hurtbox3D.Result.DODGED
	health = maxf(0.0, health - info.amount)
	hurt = true
	_flash_left = 0.15
	FX.damage_number(_world(), global_position + Vector3(0.0, 1.7, 0.0), info.amount, "normal")
	Events.prisoner_hurt.emit(self, info.amount)
	if health <= 0.0:
		_die()
	return Hurtbox3D.Result.HIT


func _die() -> void:
	if dead:
		return
	dead = true
	follow = false
	visible = false
	set_physics_process(false)
	died.emit(self)
	Events.ally_died.emit(self)


## Soins (potion du § 8.6 donnée à un allié, PHASE 6 : alliées jouables).
func heal(amount: float) -> void:
	if dead:
		return
	health = minf(max_health, health + amount)


func health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)


func _world() -> Node:
	var parent := get_parent()
	return parent if parent != null else get_tree().current_scene
