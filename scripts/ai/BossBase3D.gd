extends CharacterBody3D
class_name BossBase3D
## Boss de fin de chapitre (DESIGN.md § 10) : 3 phases (100-60 %, 60-30 %,
## 30-0 %), zones de danger dessinées au sol, appel de soldats, armure du
## colosse, nuit du sorcier, combos du général rival.
##
## Il est piloté par `BossData` : les 5 boss du § 10 sont le MÊME script avec
## une autre fiche (`data/bosses/*.tres`).
##
## Le boss n'est pas lancé par le `WaveSpawner3D` : c'est le niveau qui le
## pose (`LevelBase3D._build_boss()`). Il rejoint le groupe « enemies » pour
## que la joueuse puisse le verrouiller et le frapper comme un ennemi.

enum State { IDLE, APPROACH, TELEGRAPH, ATTACK, RECOVER, STAGGER, DEAD }

const GRAVITY: float = 20.0
const GRAYS: Array[Color] = [Color(0.30, 0.28, 0.26), Color(0.22, 0.20, 0.19)]
const FLASH_TIME: float = 0.08
const FLASH_COLOR: Color = Color(1.0, 0.92, 0.8)
const TELEGRAPH_COLOR: Color = Color(1.0, 0.35, 0.2)
const DEATH_TIME: float = 1.6
const SLOWMO_SCALE: float = 0.2
const SLOWMO_TIME: float = 0.6
const DEATH_SLIDE: float = 1.0

## Le niveau s'abonne : mort (cauris + objectif) et demande d'invocation.
signal died(boss: BossBase3D, cauris: int)
signal phase_changed(phase: int)
signal health_changed(current: float, maximum: float)
signal summon_requested(type_name: String, count: int, at: Vector3)

@export var data: BossData
## Racine où poser les zones de danger (le niveau) : elles survivent au boss.
var zone_root: Node3D = null
## Ralenti de 0,6 s au dernier coup (§ 10). Coupé par les tests.
var slowmo_on_death: bool = true

var health: float = 300.0
var max_health: float = 300.0
var phase: int = 1
var state: State = State.IDLE
var dead: bool = false
var target: Player3D = null
## Colosse (§ 10) : nombre de gardes parfaites encaissées, armure cassée ?
var perfect_guards: int = 0
var armor_broken: bool = false
## Dernière attaque jouée : lisible par les tests.
var last_attack: String = ""
var attacks_started: int = 0

var _visual: Node3D
var _hurtbox: Hurtbox3D
var _hitbox: Hitbox3D
var _materials: Array[StandardMaterial3D] = []
var _tints: Array[Color] = []

var _state_time: float = 0.0
var _cooldown: float = 1.0
var _attack_index: int = 0
var _attack_left: float = 0.0
var _combo_left: int = 0
var _charge_left: float = 0.0
var _charge_dir: Vector3 = Vector3.FORWARD
var _flash_left: float = 0.0
var _hit_active: bool = false
var _summoned_phase: int = 0


# -----------------------------------------------------------------#
#                          CONSTRUCTION                            #
# -----------------------------------------------------------------#

func _ready() -> void:
	add_to_group("enemies")
	if data == null:
		data = BossRegistry.get_data("captain")
	max_health = data.health * GameState.difficulty_health_mult() * GameState.coop_health_mult()
	health = max_health
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_build_body()
	_build_boxes()
	Events.perfect_guard.connect(_on_perfect_guard)
	health_changed.emit(health, max_health)


## Corps graybox (§ 15.3 : silhouette massive, épaules larges, couleur unique).
## Remplaçable par un `.glb` sans toucher au code (§ 6.6).
func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55 * data.model_scale * 0.5
	capsule.height = 1.7 * data.model_scale * 0.5 + capsule.radius
	shape.shape = capsule
	shape.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var s := data.model_scale
	_add_box(_visual, "Torso", Vector3(0.95, 1.05, 0.55) * s, Vector3(0.0, 1.0, 0.0) * s,
		data.tint)
	_add_box(_visual, "Belt", Vector3(1.05, 0.22, 0.62) * s, Vector3(0.0, 0.46, 0.0) * s,
		data.tint.darkened(0.35))
	_add_box(_visual, "Head", Vector3(0.46, 0.44, 0.46) * s, Vector3(0.0, 1.62, 0.0) * s,
		data.tint.lightened(0.15))
	_add_box(_visual, "ArmL", Vector3(0.26, 0.9, 0.26) * s, Vector3(-0.62, 1.05, 0.0) * s,
		data.tint.darkened(0.12))
	_add_box(_visual, "ArmR", Vector3(0.26, 0.9, 0.26) * s, Vector3(0.62, 1.05, 0.0) * s,
		data.tint.darkened(0.12))
	_add_box(_visual, "LegL", Vector3(0.3, 0.85, 0.3) * s, Vector3(-0.26, 0.42, 0.0) * s,
		GRAYS[0])
	_add_box(_visual, "LegR", Vector3(0.3, 0.85, 0.3) * s, Vector3(0.26, 0.42, 0.0) * s,
		GRAYS[0])
	# Arme : une lame large, lisible de loin.
	_add_box(_visual, "Blade", Vector3(0.1, 0.12, 1.5) * s, Vector3(0.62, 1.0, -0.8) * s,
		Color(0.82, 0.84, 0.88))


func _add_box(parent: Node3D, box_name: String, size: Vector3, offset: Vector3,
		color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	parent.add_child(instance)
	_materials.append(material)
	_tints.append(color)
	return instance


## Zones de dégâts : la joueuse le frappe (hurtbox), lui frappe avec sa lame
## (hitbox) — mêmes couches que les ennemis du § 19.
func _build_boxes() -> void:
	_hurtbox = Hurtbox3D.new()
	_hurtbox.name = "Hurtbox3D"
	_hurtbox.collision_layer = 4
	_hurtbox.collision_mask = 0
	_hurtbox.position = Vector3(0.0, 1.0 * data.model_scale * 0.5, 0.0)
	var hurt_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55 * data.model_scale * 0.5
	capsule.height = 1.7 * data.model_scale * 0.5 + capsule.radius
	hurt_shape.shape = capsule
	_hurtbox.add_child(hurt_shape)
	_hurtbox.owner_actor = self
	add_child(_hurtbox)

	_hitbox = Hitbox3D.new()
	_hitbox.name = "Hitbox3D"
	_hitbox.collision_layer = 16
	_hitbox.collision_mask = 2
	_hitbox.damage = data.damage * GameState.difficulty_damage_mult()
	_hitbox.knockback = 2.0
	_hitbox.is_heavy = true
	_hitbox.crit_chance = 0.0
	_hitbox.position = Vector3(0.0, 0.9, -1.2 * data.model_scale * 0.5)
	var hit_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.4, 1.6) * data.model_scale * 0.6
	hit_shape.shape = box
	_hitbox.add_child(hit_shape)
	_hitbox.owner_actor = self
	_visual.add_child(_hitbox)


# -----------------------------------------------------------------#
#                            BOUCLE                                #
# -----------------------------------------------------------------#

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_flash_left = maxf(0.0, _flash_left - delta)
	if _flash_left <= 0.0:
		_restore_tint()
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		move_and_slide()
		return

	_state_time += delta
	match state:
		State.IDLE:
			_state_idle(delta)
		State.APPROACH:
			_state_approach(delta)
		State.TELEGRAPH:
			_state_telegraph(delta)
		State.ATTACK:
			_state_attack(delta)
		State.RECOVER:
			_state_recover()
		State.STAGGER:
			_state_stagger()
	move_and_slide()


func _state_idle(delta: float) -> void:
	if not is_instance_valid(target):
		target = _nearest_player()
		if target == null:
			return
	_face_toward(target)
	var distance := _flat(target.global_position - global_position).length()
	if distance > data.attack_range + 1.2:
		state = State.APPROACH
		_state_time = 0.0
		return
	velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
	if _state_time >= _cooldown:
		_begin_telegraph(_next_attack())


func _state_approach(delta: float) -> void:
	if not is_instance_valid(target):
		target = _nearest_player()
		state = State.IDLE
		_state_time = 0.0
		return
	_face_toward(target)
	var dir := _flat(target.global_position - global_position).normalized()
	var distance := _flat(target.global_position - global_position).length()
	if distance <= data.attack_range + 0.4:
		state = State.IDLE
		_state_time = 0.0
		return
	var speed := data.speed * (1.0 + 0.12 * float(phase - 1))
	velocity.x = move_toward(velocity.x, dir.x * speed, 16.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 16.0 * delta)


func _state_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if is_instance_valid(target) and last_attack != "charge":
		_face_toward(target)
	if _state_time >= data.telegraph_for_phase(phase):
		_execute(last_attack)


func _state_attack(delta: float) -> void:
	if last_attack == "charge" and _charge_left > 0.0:
		var dash_speed := data.speed * 4.2
		velocity.x = _charge_dir.x * dash_speed
		velocity.z = _charge_dir.z * dash_speed
		_charge_left -= dash_speed * delta
		if _charge_left <= 0.0:
			_charge_left = 0.0
			_hitbox.deactivate()
			_hit_active = false
			_enter_recover()
		return
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if _state_time >= _attack_left:
		if _hit_active:
			_hitbox.deactivate()
			_hit_active = false
		_enter_recover()


func _state_recover() -> void:
	if _state_time < data.recover_time * (1.0 - 0.12 * float(phase - 1)):
		return
	# § 10 : le général rival enchaîne des combos en phase 3.
	if _combo_left > 0 and phase >= 3:
		_combo_left -= 1
		_begin_telegraph(_next_attack())
		return
	state = State.IDLE
	_state_time = 0.0
	_cooldown = maxf(0.35, 1.15 - 0.18 * float(phase - 1))


func _state_stagger() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * 0.016)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * 0.016)
	if _state_time >= 0.8:
		state = State.IDLE
		_state_time = 0.0
		_cooldown = 0.5


# -----------------------------------------------------------------#
#                           ATTAQUES                               #
# -----------------------------------------------------------------#

func _next_attack() -> String:
	var pool := data.attacks_at_phase(phase)
	var kind := pool[_attack_index % pool.size()]
	_attack_index += 1
	return kind


func _begin_telegraph(kind: String) -> void:
	# § 17 : le gardien rugit avant chaque attaque (audio 3D).
	AudioManager.play_sfx_at(self, &"boss_roar", randf_range(1.05, 1.2))
	state = State.TELEGRAPH
	_state_time = 0.0
	last_attack = kind
	attacks_started += 1
	if is_instance_valid(target):
		_face_toward(target)
		_charge_dir = _flat(target.global_position - global_position).normalized()
	# Télégraphe lisible (§ 9) : le modèle flashe en rouge.
	_set_tint(TELEGRAPH_COLOR)
	_flash_left = data.telegraph_for_phase(phase)


## Applique l'attaque choisie. Chaque attaque pose ses zones de danger AVANT de
## frapper : la joueuse a le temps de sortir du disque (§ 10).
func _execute(kind: String) -> void:
	state = State.ATTACK
	_state_time = 0.0
	_restore_tint()
	var zone_damage := data.damage * GameState.difficulty_damage_mult()
	var warn := 0.45
	match kind:
		"charge":
			_charge_left = data.charge_distance
			_attack_left = 1.6
			# Traînée de zones sur la trajectoire de la charge.
			for i in 3:
				var at := global_position + _charge_dir * (data.charge_distance * 0.3 * float(i + 1))
				DangerZone3D.spawn(zone_root, at, data.charge_width, zone_damage, warn, self)
			_hitbox.activate()
			_hit_active = true
		"sweep":
			_attack_left = 0.5
			DangerZone3D.spawn(zone_root, global_position, data.sweep_radius, zone_damage, warn, self)
			_hitbox.activate()
			_hit_active = true
		"slam":
			_attack_left = 0.6
			DangerZone3D.spawn(zone_root, global_position, data.slam_radius, zone_damage, warn, self)
			_shake_camera(0.25)
		"arrows":
			_attack_left = 0.7
			var center := global_position
			if is_instance_valid(target):
				center = target.global_position
			var count := maxi(1, data.arrow_count + (2 if phase >= 3 else 0))
			for i in count:
				var angle := TAU * float(i) / float(count) + randf() * 0.4
				var spread := 3.2 + randf() * 2.4
				var at := center + Vector3(cos(angle) * spread, 0.0, sin(angle) * spread)
				DangerZone3D.spawn(zone_root, at, data.arrow_radius, zone_damage * 0.8,
					warn + 0.15, self)
		"orbs":
			_attack_left = 0.5
			if is_instance_valid(target):
				for i in 3:
					var offset := Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
					DangerZone3D.spawn(zone_root, target.global_position + offset,
						data.sweep_radius * 0.55, zone_damage * 0.9, warn + 0.3, self)
		"teleport":
			# Disparaît et réapparaît derrière la joueuse, lame déjà levée.
			_attack_left = 0.5
			if is_instance_valid(target):
				var behind := target.global_position - _flat(target.global_position - global_position).normalized() * 3.0
				behind.y = global_position.y
				global_position = behind
				_face_toward(target)
			DangerZone3D.spawn(zone_root, global_position, data.sweep_radius * 0.9,
				zone_damage, warn * 0.8, self)
			_hitbox.activate()
			_hit_active = true
		_:
			_attack_left = 0.5
	if phase >= 3 and data.combo_hits > 1:
		_combo_left = data.combo_hits - 1
	# § 10 : « appelle 2 soldats en phase 2 ».
	if data.summon_phase > 0 and phase >= data.summon_phase and _summoned_phase < data.summon_phase:
		_summoned_phase = data.summon_phase
		var at := global_position + _forward() * -2.0
		summon_requested.emit(data.summon_type, data.summon_count, at)


func _enter_recover() -> void:
	state = State.RECOVER
	_state_time = 0.0


func _shake_camera(strength: float) -> void:
	for camera in get_tree().get_nodes_in_group("camera_rig"):
		if camera.has_method("shake"):
			camera.call("shake", strength)


# -----------------------------------------------------------------#
#                        DÉGÂTS REÇUS                               #
# -----------------------------------------------------------------#

func on_hit_received(info: DamageInfo) -> int:
	if dead:
		return Hurtbox3D.Result.DODGED
	# Colosse (§ 10) : l'armure encaisse tant que 3 gardes parfaites ne l'ont pas
	# brisée — les coups font alors un quart des dégâts.
	var amount := info.amount
	if data.armor_guards > 0 and not armor_broken:
		amount *= 0.25
		FX.impact(get_tree().current_scene, global_position + Vector3(0.0, 1.2, 0.0), "block")
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if not info.is_dot:
		FX.damage_number(get_tree().current_scene, global_position + Vector3(0.0, 2.2, 0.0),
			amount, "crit" if info.is_critical else "normal")
		_flash_tint()
	var ratio := health / maxf(max_health, 0.001)
	var new_phase := data.phase_for_ratio(ratio)
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
		_cooldown = 0.4
	if health <= 0.0:
		_die()
		return Hurtbox3D.Result.HIT
	return Hurtbox3D.Result.HIT


## Garde parfaite de la joueuse : c'est elle qui casse l'armure du colosse.
func _on_perfect_guard(actor: Node) -> void:
	if dead or data.armor_guards <= 0 or armor_broken:
		return
	if actor == null or not (actor is Player3D):
		return
	perfect_guards += 1
	if perfect_guards >= data.armor_guards:
		armor_broken = true
		state = State.STAGGER
		_state_time = 0.0
		_hitbox.deactivate()
		_hit_active = false
		_cooldown = 0.3


func _die() -> void:
	if dead:
		return
	dead = true
	state = State.DEAD
	_hitbox.deactivate()
	_hit_active = false
	remove_from_group("enemies")
	# § 10 : ralenti 0,6 s à 0,2× au dernier coup.
	if slowmo_on_death:
		Engine.time_scale = SLOWMO_SCALE
		get_tree().create_timer(SLOWMO_TIME, true, false, true).timeout.connect(
			func() -> void: Engine.time_scale = 1.0)
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:x", -PI * 0.5, DEATH_TIME * 0.8)
	died.emit(self, maxi(0, data.drops_cauris))
	Events.enemy_died.emit(self)
	await get_tree().create_timer(DEATH_TIME, true, false, true).timeout
	queue_free()


func stun(duration: float) -> void:
	## Le boss n'est jamais étourdi longtemps : 0,6 s maximum, et seulement en
	## récupération (sinon il deviendrait trivial).
	if dead or state == State.ATTACK:
		return
	state = State.STAGGER
	_state_time = maxf(0.0, 0.8 - duration)


# -----------------------------------------------------------------#
#                            OUTILS                                #
# -----------------------------------------------------------------#

func health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)


func _nearest_player() -> Player3D:
	var best: Player3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("players"):
		var actor := node as Player3D
		if actor == null or actor.state == Player3D.State.DEAD:
			continue
		var distance := global_position.distance_to(actor.global_position)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best


func _face_toward(actor: Node3D) -> void:
	var dir := _flat(actor.global_position - global_position)
	if dir.length() > 0.01:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), 0.2)


func _forward() -> Vector3:
	return -_visual.global_transform.basis.z


func _flat(value: Vector3) -> Vector3:
	value.y = 0.0
	return value


func _set_tint(color: Color) -> void:
	for material in _materials:
		material.albedo_color = color


func _flash_tint() -> void:
	_flash_left = FLASH_TIME
	_set_tint(FLASH_COLOR)


func _restore_tint() -> void:
	for i in _materials.size():
		_materials[i].albedo_color = _tints[i]
