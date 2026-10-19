extends Node3D
class_name Hazard3D
## Piège du § 11 : fosse, flèches murales, feu, planche qui casse, pointes, boue.
## Un seul script pour les six (mêmes règles de détection, mêmes dégâts) :
## le type se choisit par `kind`, et le niveau les pose d'après `LevelData`.
##
## « Les pièges blessent aussi les ennemis » (§ 11) : la zone surveille les
## Hurtbox3D de la couche 2 (joueuse) ET de la couche 4 (ennemis).
##
## Les dégâts passent par la Hurtbox3D de la victime : esquive, garde, garde
## parfaite et invincibilité restent donc respectées (aucun coup gratuit).

enum Kind { PIT, ARROWS, FIRE, PLANK, SPIKES, MUD }

const GOLD: Color = Color(0.89, 0.66, 0.17)
const DANGER: Color = Color(0.78, 0.18, 0.13)
const DARK: Color = Color(0.12, 0.10, 0.09)
const MUD_COLOR: Color = Color(0.24, 0.19, 0.13)
const FIRE_ON: Color = Color(1.0, 0.55, 0.12)
const FIRE_OFF: Color = Color(0.25, 0.16, 0.10)

## Réglages du § 11 (modifiables depuis le niveau).
@export var damage: float = 20.0
@export var salvo_period: float = 3.0        ## flèches : salve toutes les 3 s
@export var salvo_telegraph: float = 0.5     ## fente qui clignote 0,5 s
@export var fire_on_time: float = 1.0        ## feu : 1 s ON
@export var fire_off_time: float = 2.0       ##        2 s OFF
@export var plank_delay: float = 0.6         ## planche : casse 0,6 s après contact
@export var slow_mult: float = 0.6           ## boue : −40 % de vitesse
@export var contact_cooldown: float = 1.0    ## délai entre deux touches du même acteur
@export var size: Vector3 = Vector3(1.6, 0.2, 1.6)

var kind: Kind = Kind.SPIKES
## Où reposer la victime après une chute (posé par le niveau).
var return_point: Vector3 = Vector3.ZERO

## Le piège construit lui-même ses nœuds : le niveau en crée par dizaines et
## n'a pas à charger une scène par exemplaire (§ 18 règle 6).
var area: Area3D
var mesh: MeshInstance3D
var slit: MeshInstance3D
var collision: CollisionShape3D

var active: bool = true                      ## feu : ON/OFF ; planche : cassée
var telegraphing: bool = false
var hits_given: int = 0                      ## compteur lisible par les tests
var last_victim: Node = null

var _material: StandardMaterial3D
var _slit_material: StandardMaterial3D
var _salvo_left: float = 0.0
var _fire_phase: float = 0.0
var _plank_left: float = -1.0
var _blink: float = 0.0
var _last_hit: Dictionary = {}


## Identifiant du § 11 → type. Type inconnu : pointes (inoffensif de travers).
static func kind_from_string(name: String) -> Kind:
	match name.strip_edges().to_lower():
		"pit", "fosse":
			return Kind.PIT
		"arrows", "arrow", "fleches", "flèches":
			return Kind.ARROWS
		"fire", "feu":
			return Kind.FIRE
		"plank", "planche":
			return Kind.PLANK
		"mud", "boue":
			return Kind.MUD
		_:
			return Kind.SPIKES


static func name_of_kind(value: Kind) -> String:
	match value:
		Kind.PIT:
			return "pit"
		Kind.ARROWS:
			return "arrows"
		Kind.FIRE:
			return "fire"
		Kind.PLANK:
			return "plank"
		Kind.MUD:
			return "mud"
		_:
			return "spikes"


func _ready() -> void:
	_build_nodes()
	area.area_entered.connect(_on_area_entered)
	area.body_entered.connect(_on_body_entered)
	_build_visual()
	_apply_kind_defaults()


## Zone de détection (couche 6 hazard, § 19) qui surveille les Hurtbox3D de la
## joueuse (couche 2) et des ennemis (couche 4) : « les pièges blessent aussi les
## ennemis » (§ 11).
func _build_nodes() -> void:
	area = Area3D.new()
	area.name = "Area3D"
	area.collision_layer = 32
	area.collision_mask = 2 | 4
	collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	area.add_child(collision)
	mesh = MeshInstance3D.new()
	mesh.name = "Mesh"
	area.add_child(mesh)
	slit = MeshInstance3D.new()
	slit.name = "Slit"
	area.add_child(slit)
	add_child(area)


## Valeurs du tableau du § 11 par type.
func _apply_kind_defaults() -> void:
	match kind:
		Kind.PIT:
			damage = 20.0
		Kind.ARROWS:
			damage = 12.0
		Kind.FIRE:
			damage = 8.0                    ## 8/s
			_fire_phase = 0.0
			active = true
		Kind.PLANK:
			damage = 20.0                   ## chute = 20 (comme la fosse)
		Kind.SPIKES:
			damage = 10.0
		Kind.MUD:
			damage = 0.0
	_salvo_left = salvo_period


func _build_visual() -> void:
	var box := BoxMesh.new()
	box.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	# Une boîte simple pour les six types (graybox de PHASE 3) : la fosse est un
	# trou sombre, la planche un rectangle de bois, etc.
	collision.shape = shape
	mesh.mesh = box
	_material = StandardMaterial3D.new()
	mesh.material_override = _material
	var slit_box := BoxMesh.new()
	slit_box.size = Vector3(maxf(size.x, 0.4), 0.08, 0.12)
	slit.mesh = slit_box
	slit.position = Vector3(0.0, 0.02, -size.z * 0.5 - 0.02)
	slit.visible = kind == Kind.ARROWS
	_slit_material = StandardMaterial3D.new()
	slit.material_override = _slit_material
	_paint_idle()


func _paint_idle() -> void:
	match kind:
		Kind.PIT:
			_material.albedo_color = DARK
		Kind.ARROWS:
			_material.albedo_color = Color(0.35, 0.32, 0.30)
			_slit_material.albedo_color = DANGER
		Kind.FIRE:
			_material.albedo_color = FIRE_ON if active else FIRE_OFF
		Kind.PLANK:
			_material.albedo_color = Color(0.45, 0.31, 0.18) if active else DARK
		Kind.MUD:
			_material.albedo_color = MUD_COLOR
		_:
			_material.albedo_color = Color(0.55, 0.55, 0.58)


func _physics_process(delta: float) -> void:
	match kind:
		Kind.ARROWS:
			_salvo_left -= delta
			if _salvo_left <= salvo_telegraph:
				# Fente qui clignote 0,5 s avant la salve (§ 11).
				telegraphing = true
				_blink += delta
				_slit_material.albedo_color = GOLD if fmod(_blink, 0.16) < 0.08 else DANGER
			if _salvo_left <= 0.0:
				_salvo_left = salvo_period
				telegraphing = false
				_volley()
		Kind.FIRE:
			_fire_phase = fmod(_fire_phase + delta, fire_on_time + fire_off_time)
			active = _fire_phase < fire_on_time
			_material.albedo_color = FIRE_ON if active else FIRE_OFF
			if active:
				# 8/s (§ 11) : appliqué par petits pas pour rester régulier.
				_burn(delta)
		Kind.PLANK:
			if _plank_left > 0.0:
				_plank_left -= delta
				telegraphing = true
				_blink += delta
				_material.albedo_color = GOLD if fmod(_blink, 0.12) < 0.06 else Color(0.45, 0.31, 0.18)
				if _plank_left <= 0.0:
					_break_plank()
		Kind.MUD:
			_slow_all()
		_:
			pass


# -----------------------------------------------------------------#
#                      DÉCLENCHEMENT                               #
# -----------------------------------------------------------------#

func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox3D
	if hurtbox == null or hurtbox.owner_actor == null:
		return
	var actor := hurtbox.owner_actor
	match kind:
		Kind.PIT:
			_fall(actor, hurtbox)
		Kind.PLANK:
			if active and _plank_left < 0.0:
				_plank_left = plank_delay      # craquements (§ 11)
		Kind.SPIKES:
			_touch(actor, hurtbox)
		Kind.ARROWS, Kind.FIRE, Kind.MUD:
			# Ceux-là agissent à leur rythme dans _physics_process (§ 11).
			pass


func _on_body_entered(body: Node3D) -> void:
	## Une victime sans Hurtbox3D reconnue (corps nu) : seul le piège de contact
	## s'applique, sans passer par la garde.
	if kind != Kind.SPIKES:
		return
	_touch(body, null)


## Fosse (§ 11) : chute = −20 vie et retour au bord.
func _fall(actor: Node, hurtbox: Hurtbox3D) -> void:
	if not _ready_for(actor):
		return
	hits_given += 1
	last_victim = actor
	_wound(actor, hurtbox, damage)
	if actor is Node3D:
		(actor as Node3D).global_position = return_point


## Pointes (§ 11) : dégâts au contact, avec un délai entre deux touches.
func _touch(actor: Node, hurtbox: Hurtbox3D) -> void:
	if not _ready_for(actor):
		return
	hits_given += 1
	last_victim = actor
	_wound(actor, hurtbox, damage)


## Flèches murales (§ 11) : salve de 12 dégâts sur tout ce qui est dans la fente.
func _volley() -> void:
	for victim in _victims_in_area():
		hits_given += 1
		last_victim = victim
		_wound(victim, _hurtbox_of(victim), damage)
	FX.shake(0.12)


## Feu (§ 11) : 8 dégâts par seconde tant qu'on reste dedans.
func _burn(delta: float) -> void:
	for victim in _victims_in_area():
		var hurtbox := _hurtbox_of(victim)
		if hurtbox == null:
			continue
		var info := DamageInfo.new()
		info.amount = damage * delta
		info.source_position = global_position
		info.source_actor = self
		info.is_heavy = false
		info.is_dot = true                 ## brûlure : i-frames de touche ignorées
		hurtbox.receive_hit(info)


## Planche (§ 11) : elle casse 0,6 s après le contact ; la victime tombe.
func _break_plank() -> void:
	active = false
	telegraphing = false
	_plank_left = -1.0
	_paint_idle()
	FX.shake(0.2)
	# Chute : mêmes effets que la fosse (§ 11 « chute »).
	for victim in _victims_in_area():
		hits_given += 1
		last_victim = victim
		_wound(victim, _hurtbox_of(victim), damage)
		if victim is Node3D:
			(victim as Node3D).global_position = return_point


## Boue (§ 11) : ralentit de 40 %, sans dégâts.
func _slow_all() -> void:
	for victim in _victims_in_area():
		_slow(victim)


func _slow(actor: Node) -> void:
	if actor.has_method("apply_slow"):
		actor.apply_slow(slow_mult, 0.25)
		last_victim = actor


# -----------------------------------------------------------------#
#                           OUTILS                                 #
# -----------------------------------------------------------------#

## Applique un coup en passant par la Hurtbox3D de la victime : esquive, garde
## et invincibilité restent donc respectées.
func _wound(actor: Node, hurtbox: Hurtbox3D, amount: float) -> void:
	if not is_instance_valid(actor):
		return
	var info := DamageInfo.new()
	info.amount = amount
	info.knockback = 0.0
	info.source_position = global_position
	info.source_actor = self
	info.is_heavy = true                 ## les pièges percent l'armure de la brute
	if hurtbox == null:
		hurtbox = _hurtbox_of(actor)
	if hurtbox != null:
		hurtbox.receive_hit(info)
	elif actor.has_method("on_hit_received"):
		actor.on_hit_received(info)
	var position: Vector3 = (actor as Node3D).global_position if actor is Node3D else global_position
	FX.impact(_world(), position + Vector3(0.0, 0.6, 0.0), "hit")
	FX.damage_number(_world(), position + Vector3(0.0, 1.5, 0.0), amount, "normal")


func _hurtbox_of(actor: Node) -> Hurtbox3D:
	return actor.get("hurtbox") as Hurtbox3D


## Victimes actuellement dans la zone (couches 2 et 4, § 19).
func _victims_in_area() -> Array[Node]:
	var out: Array[Node] = []
	for area in area.get_overlapping_areas():
		var hurtbox := area as Hurtbox3D
		if hurtbox != null and hurtbox.owner_actor != null:
			out.append(hurtbox.owner_actor)
	return out


## Évite de frapper deux fois de suite la même victime (pointes, fosse).
func _ready_for(actor: Node) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var last: float = float(_last_hit.get(actor, -999.0))
	if now - last < contact_cooldown:
		return false
	_last_hit[actor] = now
	return true


func _world() -> Node:
	var parent := get_parent()
	return parent if parent != null else get_tree().current_scene
