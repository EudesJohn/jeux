extends CharacterBody3D
class_name EnemyBase3D
## Ennemi générique (DESIGN.md § 9 et § 20.7), piloté entièrement par
## `EnemyData` : les 6 types du § 9 (soldat, éclaireur, archer, brute, chef,
## garde d'alerte) sont le MÊME script avec une autre fiche.
##
## États : IDLE → PATROL → CHASE → TELEGRAPH → ATTACK → RECOVER → HURT → DEAD.
##
## Lisibilité 3D (§ 9) :
##  * télégraphe : le modèle flashe en rouge pendant 0,3 à 0,5 s ;
##  * **jeton d'attaque** : 2 ennemis attaquent au maximum ; les autres tournent
##    autour de la cible à 3 m (strafing) ;
##  * cible = joueuse la plus proche (coop) ;
##  * séparation entre ennemis pour ne pas se superposer.

enum State { IDLE, PATROL, CHASE, TELEGRAPH, ATTACK, RECOVER, HURT, DEAD }

const GRAVITY: float = 20.0
const PUPPET_FEET_OFFSET: float = -0.42
const FLASH_TIME: float = 0.08
const FLASH_COLOR: Color = Color(1.0, 0.9, 0.75)
const TELEGRAPH_COLOR: Color = Color(0.95, 0.28, 0.18)
const STUN_COLOR: Color = Color(0.75, 0.75, 0.95)
const DEATH_TIME: float = 1.2                  ## cadavre avant disparition
const SWING_DELAY: float = 0.10                ## début d'attaque → hitbox active
const HURT_TIME: float = 0.2
const SEPARATION_RADIUS: float = 1.2
const SEPARATION_STRENGTH: float = 3.0
const STRAFE_SPEED_RATIO: float = 0.6          ## vitesse en tournant autour (§ 9)
const PATROL_SPEED_RATIO: float = 0.35
const STRAFE_RADIUS: float = 3.0               ## distance de strafing (§ 9)
const BUFF_TICK: float = 0.4                   ## le chef rafraîchit son buff
const AIM_LINE_WIDTH: float = 0.05

## Le niveau s'abonne : mort (cauris lâchés), alerte du garde, invocation du chef.
signal died(enemy: Node, cauris: int)
signal alerted(enemy: Node, position: Vector3, count: int)
signal summons(enemy: Node, type_name: String, position: Vector3)

@export var data: EnemyData
@export var lane_mode: bool = true
@export var lane_depth: float = 3.0
@export var lane_center_z: float = 0.0

@onready var visual: Node3D = $Visual
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var hitbox: Hitbox3D = $Visual/Hitbox3D

var state: State = State.IDLE
var health: float = 30.0
var max_health: float = 30.0
var target: Player3D = null
var dead: bool = false
## PHASE 7 : position publiée sur le réseau (cf. `Player3D.net_position`).
var net_position: Vector3 = Vector3.ZERO
var playing_hit: bool = false               ## vrai pendant télégraphe + attaque
var strafe_dir: float = 1.0
var home: Vector3 = Vector3.ZERO
var vulnerable_left: float = 0.0            ## brute : fenêtre de vulnérabilité (§ 9)
var buff_mult: float = 1.0                  ## buff du chef (§ 9)
var slow_mult: float = 1.0                  ## boue du § 11 (−40 %)
var aiming: bool = false                    ## ligne de visée visible (archer)

var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

var _buff_left: float = 0.0
var _slow_left: float = 0.0
var _summon_left: float = 0.0
var _buff_tick: float = 0.0
var _fire_cooldown: float = 0.0
var _stun_left: float = 0.0
var _flash_left: float = 0.0
var _state_time: float = 0.0
var _hit_active: bool = false
var _alerted_once: bool = false
var _anim_ready: bool = false
var _anim_tries: int = 0
var _patrol_target: Vector3 = Vector3.ZERO
var _patrol_wait: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _tints: Array[Color] = []
var _aim_line: MeshInstance3D = null
var _culling_active: bool = false
## ANNEXE §7.3 : affixes d'élite (vide = ennemi normal).
var elite_affixes: Array[String] = []
var _elite_shield: int = 0
var _elite_summon_left: float = 0.0
const ELITE_COLOR: Color = Color(0.96, 0.78, 0.22)


# -----------------------------------------------------------------#
#                          INITIALISATION                          #
# -----------------------------------------------------------------#

func _ready() -> void:
	add_to_group("enemies")
	if data == null:
		data = EnemyRegistry.get_data("soldier")
	# Difficulté (§ 9 : Facile ×0,7, Difficile ×1,3) et coop (§ 22.3 : ×1,5).
	max_health = data.health * GameState.difficulty_health_mult() * GameState.coop_health_mult()
	health = max_health
	home = global_position
	_patrol_target = home
	strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_fire_cooldown = data.fire_period
	_summon_left = data.summon_period
	hurtbox.owner_actor = self
	hitbox.owner_actor = self
	hitbox.damage = data.damage * GameState.difficulty_damage_mult() * GameState.enemy_damage_mult()
	hitbox.knockback = 1.2
	# Les critiques (§ 8.7) sont celles de la JOUEUSE : un ennemi n'en fait pas.
	hitbox.crit_chance = 0.0
	_setup_model()
	_apply_elite()
	_setup_aim_line()
	_setup_culling()


## ANNEXE §7.3 : sous un palier de difficulté, un ennemi peut naître élite.
## Aucun palier (sauvegardes existantes) = aucun élite : les tests et les
## niveaux actuels gardent exactement les mêmes statistiques.
func _apply_elite() -> void:
	if GameState.tier == null:
		return
	if randf() >= GameState.elite_chance():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	elite_affixes = EliteAffix.roll(GameState.max_elite_affixes(), rng)
	if elite_affixes.is_empty():
		return
	add_to_group("elites")
	max_health *= 1.35
	health = max_health
	hitbox.damage *= 1.15
	_elite_shield = EliteAffix.shield_charges(elite_affixes)
	_elite_summon_left = EliteAffix.summon_period(elite_affixes)
	_restore_tint()


## § 25 : hors écran, l'ennemi ne calcule plus son IA. Sur un téléphone, une
## arène peut contenir une vingtaine d'ennemis dont la moitié derrière la
## caméra. En mode headless (tests), le culling est désactivé : sans rendu,
## « hors écran » ne veut rien dire et les tests de combat deviendraient faux.
func _setup_culling() -> void:
	if not Quality.culling_enabled():
		return
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.name = "ScreenNotifier"
	notifier.aabb = AABB(Vector3(-1.2, -0.2, -1.2), Vector3(2.4, 2.4, 2.4))
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	notifier.screen_entered.connect(_on_screen_entered)
	_culling_active = true


func _on_screen_exited() -> void:
	if _culling_active:
		set_physics_process(false)


func _on_screen_entered() -> void:
	set_physics_process(true)


## § 6.6 : le modèle est remplaçable. Sans `model_scene`, on utilise la poupée de
## test, teintée et mise à l'échelle selon le type (§ 15.2 : silhouette et
## couleur uniques par ennemi).
func _setup_model() -> void:
	var model: Node3D = null
	if data.model_scene:
		model = data.model_scene.instantiate() as Node3D
		visual.add_child(model)
	else:
		var puppet := TestPuppet.new()
		puppet.name = "Puppet"
		# Les pieds de la poupée sont à 0,42 m : le décalage suit l'échelle.
		puppet.position.y = PUPPET_FEET_OFFSET * data.model_scale
		visual.add_child(puppet)
		model = puppet
	model.scale = Vector3.ONE * data.model_scale
	if not is_equal_approx(data.model_scale, 1.0):
		# Le corps et la zone de dégâts suivent la taille (brute, chef).
		scale_collision($CollisionShape3D, data.model_scale)
		scale_collision(hurtbox, data.model_scale)
		scale_collision(hitbox, data.model_scale)
	# Chaque maillage de la poupée a son propre ShaderMaterial : la teinte
	# n'affecte donc que cet ennemi.
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("tint", data.tint)
		_materials.append(material)
		_tints.append(data.tint)
	anim_tree = CharacterAnimation.build_state_machine(self, model)
	playback = CharacterAnimation.playback_of(anim_tree)


## Agrandit la forme de collision d'un nœud et de ses enfants (brute, chef :
## § 15.2 « large ×1,3 »). La forme est dupliquée : les scènes partagées entre
## plusieurs ennemis ne sont jamais modifiées.
static func scale_collision(node: Node, factor: float) -> void:
	var targets: Array[Node] = []
	if node is CollisionShape3D:
		targets.append(node)
	targets.append_array(node.find_children("*", "CollisionShape3D", true, false))
	for target in targets:
		var shape_node := target as CollisionShape3D
		var source := shape_node.shape as Shape3D
		if source == null:
			continue
		var copy := source.duplicate() as Shape3D
		if copy is CapsuleShape3D:
			(copy as CapsuleShape3D).radius *= factor
			(copy as CapsuleShape3D).height *= factor
		elif copy is BoxShape3D:
			(copy as BoxShape3D).size *= factor
		shape_node.shape = copy


## Ligne rouge de visée de l'archer (§ 9), cachée hors attaque.
func _setup_aim_line() -> void:
	if not data.ranged:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(AIM_LINE_WIDTH, AIM_LINE_WIDTH, 1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.25, 0.2)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_line = MeshInstance3D.new()
	_aim_line.name = "AimLine"
	_aim_line.mesh = mesh
	_aim_line.material_override = material
	_aim_line.visible = false
	visual.add_child(_aim_line)


# -----------------------------------------------------------------#
#                           BOUCLE                                 #
# -----------------------------------------------------------------#

func _physics_process(delta: float) -> void:
	_ensure_anim_idle()
	# § 22.1 : chez l'invitée, l'ennemi est un reflet : aucune IA, il glisse vers
	# la position envoyée par l'hôte.
	if Network.is_coop() and not is_multiplayer_authority():
		global_position = global_position.lerp(net_position, 1.0 - exp(-14.0 * delta))
		return
	net_position = global_position
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_tick_timers(delta)

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return

	_state_time += delta

	# Étourdi (garde parfaite, § 8.4) : plus rien, il encaisse.
	if _stun_left > 0.0:
		_abort_attack()
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return

	match state:
		State.IDLE, State.PATROL:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.TELEGRAPH:
			_state_telegraph(delta)
		State.ATTACK:
			_state_attack(delta)
		State.RECOVER:
			_state_recover(delta)
		State.HURT:
			_state_hurt(delta)

	_apply_separation(delta)
	move_and_slide()
	if lane_mode:
		global_position.z = clampf(global_position.z,
			lane_center_z - lane_depth, lane_center_z + lane_depth)


func _tick_timers(delta: float) -> void:
	_flash_left = maxf(0.0, _flash_left - delta)
	_stun_left = maxf(0.0, _stun_left - delta)
	if _flash_left <= 0.0 and _stun_left <= 0.0:
		_restore_tint()
	vulnerable_left = maxf(0.0, vulnerable_left - delta)
	_buff_left = maxf(0.0, _buff_left - delta)
	if _buff_left <= 0.0:
		buff_mult = 1.0
	_slow_left = maxf(0.0, _slow_left - delta)
	if _slow_left <= 0.0:
		slow_mult = 1.0
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	# Chef (§ 9) : buff +20 % aux alliés proches et une invocation / 12 s.
	if data.buff_allies or data.summon_period > 0.0:
		_tick_officer(delta)


# -----------------------------------------------------------------#
#                          DÉCISIONS                               #
# -----------------------------------------------------------------#

## Repos et patrouille : il surveille (vue 9 m, § 9) et marche sur place.
func _state_idle(delta: float) -> void:
	var candidate := _nearest_player()
	if candidate != null and _distance_to(candidate) <= data.sight_range:
		target = candidate
		if not _alerted_once and data.alert_reinforcements > 0:
			_alerted_once = true
			alerted.emit(self, global_position, data.alert_reinforcements)
		_enter_chase()
		return
	# Hors de vue (9 m, § 9) : il n'a plus de cible et reprend sa patrouille.
	target = null

	_patrol_wait = maxf(0.0, _patrol_wait - delta)
	if _patrol_wait <= 0.0 and global_position.distance_to(_patrol_target) < 0.6:
		_patrol_wait = 1.0 + randf() * 1.5
		_patrol_target = home + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-2.0, 2.0))
	var to_target := _flat(_patrol_target - global_position)
	if to_target.length() > 0.4:
		var dir := to_target.normalized()
		var speed := speed_now() * PATROL_SPEED_RATIO
		velocity.x = move_toward(velocity.x, dir.x * speed, 12.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, 12.0 * delta)
		_face(dir)
		if state == State.PATROL:
			_play("run")
		else:
			state = State.PATROL
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if state != State.IDLE:
			state = State.IDLE
			_play("idle")


func _state_chase(delta: float) -> void:
	if not is_instance_valid(target) or target.state == Player3D.State.DEAD:
		target = _nearest_player()
		if target == null:
			state = State.IDLE
			return
	_face_toward(target)
	var distance := _distance_to(target)
	var dir := _flat(target.global_position - global_position).normalized()
	var speed := speed_now()

	# Archer (§ 9) : il garde sa distance et tire ; trop près, il recule.
	if data.keep_distance > 0.0:
		if distance < data.keep_distance - 0.5:
			velocity.x = -dir.x * speed
			velocity.z = -dir.z * speed
			_play("run")
			return
		if distance > data.keep_distance + 1.5:
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_play("run")
			return
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_play("idle")
		if _fire_cooldown <= 0.0 and _can_attack():
			_begin_telegraph()
		return

	if distance <= data.attack_range:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		# Jeton d'attaque (§ 9) : sans jeton, on tourne autour à 3 m.
		if _can_attack():
			_begin_telegraph()
		else:
			_strafe(delta)
		return

	# Poursuite. Sans jeton et déjà près, on encercle au lieu de coller — mais on
	# DEMANDE le jeton ici aussi : sans cette demande, deux ennemis s'encerclaient
	# à 3 m sans jamais attaquer une joueuse qui reste immobile.
	if not _can_attack() and distance < STRAFE_RADIUS + 1.5:
		_strafe(delta)
		return
	velocity.x = move_toward(velocity.x, dir.x * speed, 14.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 14.0 * delta)
	_play("run")


## § 9 : « les autres tournent autour à 3 m » (strafing).
func _strafe(delta: float) -> void:
	var dir := _flat(target.global_position - global_position).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x) * strafe_dir
	var approach := dir * clampf(_distance_to(target) - STRAFE_RADIUS, -1.0, 1.0)
	var move := (side + approach).normalized() * speed_now() * STRAFE_SPEED_RATIO
	velocity.x = move_toward(velocity.x, move.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, move.z, 14.0 * delta)
	_play("run")


func _state_telegraph(delta: float) -> void:
	# § 17 : grognement au télégraphe — le son signale le coup autant que la
	# couleur du modèle, c'est ce qui rend l'attaque lisible au doigt.
	if _state_time <= delta:
		AudioManager.play_sfx_at(self, &"hurt", randf_range(0.62, 0.72))
	velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
	if _state_time >= data.telegraph_time:
		_begin_attack()


func _state_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	# La Hitbox s'ouvre un peu après le début du coup (lisible), puis se ferme.
	if not _hit_active and _state_time >= SWING_DELAY:
		_hit_active = true
		if data.ranged:
			_ranged_shot()
		else:
			hitbox.activate()
	if data.ranged and _hit_active:
		_aim_line_update()
	if _state_time >= data.attack_duration:
		hitbox.deactivate()
		_hit_active = false
		# Brute (§ 9) : vulnérable 0,9 s après son attaque lourde.
		if data.armor and data.vulnerable_time > 0.0:
			vulnerable_left = data.vulnerable_time
		_enter_recover()


func _state_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	# Éclaireur (§ 9) : il recule après son coup avant de revenir.
	if is_instance_valid(target):
		var away := _flat(global_position - target.global_position).normalized()
		velocity.x += away.x * data.retreat_after_attack * 1.5
		velocity.z += away.z * data.retreat_after_attack * 1.5
	if _state_time >= data.recover_time:
		AttackTokenManager.release(self)
		_enter_chase()


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	if _state_time >= HURT_TIME:
		_enter_chase()


# -----------------------------------------------------------------#
#                      ATTAQUE (§ 9, § 8.4)                        #
# -----------------------------------------------------------------#

## Un ennemi n'attaque que s'il tient un jeton (§ 9 : 2 attaquants au maximum).
func _can_attack() -> bool:
	return AttackTokenManager.holders.has(self) or AttackTokenManager.request(self)


func _begin_telegraph() -> void:
	state = State.TELEGRAPH
	_state_time = 0.0
	playing_hit = true
	hitbox.damage = data.damage * GameState.difficulty_damage_mult() * GameState.enemy_damage_mult()
	# ANNEXE §7.2 : le flash du télégraphe prend la couleur de l'attaque
	# (blanc gardable, jaune garde parfaite, rouge imparable).
	hitbox.danger = Hitbox3D.danger_from_name(data.attack_danger)
	_set_tint(Hitbox3D.DANGER_COLORS[hitbox.danger])
	if is_instance_valid(target):
		_face_toward(target)
	_play("attack1")


func _begin_attack() -> void:
	state = State.ATTACK
	_state_time = 0.0
	_hit_active = false
	# L'archer annonce sa visée pendant le coup (§ 9 : ligne rouge).
	if data.ranged and _aim_line != null:
		_aim_line.visible = true
		aiming = true
		_aim_line_update()


func _enter_recover() -> void:
	state = State.RECOVER
	_state_time = 0.0
	playing_hit = false
	if _aim_line != null:
		_aim_line.visible = false
	aiming = false
	_restore_tint()
	if data.ranged:
		_fire_cooldown = data.fire_period


## § 3.1 : dans une arène fermée, il n'y a nulle part où se cacher — le
## spawner réveille l'ennemi dès son apparition (sinon il patrouille hors de
## vue et une Survie se gagne en restant immobile).
func hunt(actor: Node3D) -> void:
	if dead or actor == null or not (actor is Player3D):
		return
	target = actor as Player3D
	# Pas de renfort d'alerte : il a déjà vu la joueuse à l'apparition.
	_alerted_once = true
	_enter_chase()


func _enter_chase() -> void:
	state = State.CHASE
	_state_time = 0.0
	playing_hit = false


## Tir de l'archer (§ 9) : toucher instantané dans l'axe de la visée.
## Les vraies flèches volantes arriveront avec les projectiles (PHASE 6).
func _ranged_shot() -> void:
	if not is_instance_valid(target):
		return
	var to_target := target.global_position + Vector3(0.0, 1.0, 0.0) - _chest()
	if to_target.length() > data.sight_range + 4.0:
		return
	if absf(to_target.normalized().dot(_forward())) < 0.6:
		return                      # la cible s'est écartée du tir
	var info := DamageInfo.new()
	info.amount = data.damage * GameState.difficulty_damage_mult() * GameState.enemy_damage_mult()
	info.knockback = 1.0
	info.source_position = global_position
	info.source_actor = self
	target.hurtbox.receive_hit(info)
	FX.impact(_world(), target.global_position + Vector3(0.0, 1.0, 0.0), "hit")


func _aim_line_update() -> void:
	if _aim_line == null or not is_instance_valid(target):
		return
	var to_target := target.global_position + Vector3(0.0, 1.0, 0.0) - global_position
	var length := maxf(to_target.length(), 0.2)
	var mesh := _aim_line.mesh as BoxMesh
	if mesh != null:
		mesh.size = Vector3(AIM_LINE_WIDTH, AIM_LINE_WIDTH, length)
	_aim_line.position = Vector3(0.0, 1.1, 0.0)
	_aim_line.look_at(global_position + to_target, Vector3.UP)


## Annule télégraphe et coup en cours (étourdissement, mort, coup reçu).
## `deferred` : obligatoire quand on vient d'un signal physique
## (`area_entered`), où Godot refuse un changement immédiat de `monitoring`.
func _abort_attack(deferred: bool = false) -> void:
	playing_hit = false
	if _hit_active:
		if deferred:
			hitbox.set_deferred("monitoring", false)
		else:
			hitbox.deactivate()
	_hit_active = false
	if _aim_line != null:
		_aim_line.visible = false
	aiming = false
	AttackTokenManager.release(self)
	_restore_tint()


## § 8.4 : étourdi par une garde parfaite de la joueuse (0,8 s).
func stun(duration: float) -> void:
	if dead or duration <= 0.0:
		return
	_stun_left = maxf(_stun_left, duration)
	_abort_attack(true)
	_play("hurt")
	_flash_left = maxf(_flash_left, duration)
	_set_tint(STUN_COLOR)


# -----------------------------------------------------------------#
#                    RÔLES SPÉCIAUX DU § 9                         #
# -----------------------------------------------------------------#

## Chef : buff des alliés proches et invocation d'un soldat.
func _tick_officer(delta: float) -> void:
	if dead:
		return
	if data.buff_allies:
		_buff_tick -= delta
		if _buff_tick <= 0.0:
			_buff_tick = BUFF_TICK
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy == self or not (enemy is EnemyBase3D):
					continue
				var other := enemy as EnemyBase3D
				if other.global_position.distance_to(global_position) <= data.buff_radius:
					other.apply_speed_buff(data.buff_mult, BUFF_TICK * 2.0)
	if data.summon_period > 0.0:
		_summon_left -= delta
		if _summon_left <= 0.0:
			_summon_left = data.summon_period
			summons.emit(self, data.summon_type, global_position - _forward() * 2.0)
	# §7.3 : un élite « Invocateur » appelle un soldat toutes les 10 s.
	var elite_period := EliteAffix.summon_period(elite_affixes)
	if elite_period > 0.0:
		_elite_summon_left -= delta
		if _elite_summon_left <= 0.0:
			_elite_summon_left = elite_period
			summons.emit(self, "soldier", global_position - _forward() * 2.0)


## Buff de vitesse d'un chef (§ 9 : +20 % pour les alliés proches).
func apply_speed_buff(multiplier: float, duration: float) -> void:
	buff_mult = maxf(buff_mult, multiplier)
	_buff_left = maxf(_buff_left, duration)


## Ralentissement (§ 11 boue) : les pièges blessent aussi les ennemis.
func apply_slow(multiplier: float, duration: float) -> void:
	slow_mult = minf(slow_mult, clampf(multiplier, 0.1, 1.0))
	_slow_left = maxf(_slow_left, duration)


## Vitesse courante, buffs du chef et boue compris.
func speed_now() -> float:
	## § 12.5 : « ennemis rapides » du Défi du jour ; §7.3 : Rapide / Enragé.
	var ratio := health / maxf(max_health, 0.001)
	return data.speed * buff_mult * slow_mult * GameState.enemy_speed_mult() \
		* EliteAffix.speed_mult(elite_affixes, ratio)


# -----------------------------------------------------------------#
#                        DÉGÂTS REÇUS                              #
# -----------------------------------------------------------------#

func on_hit_received(info: DamageInfo) -> int:
	if dead:
		return Hurtbox3D.Result.DODGED
	# § 22.1 : les ennemis appartiennent à l'hôte. La copie de l'invitée est un
	# reflet : elle ne décide ni des dégâts, ni de la mort.
	if Network.is_coop() and not Network.is_host():
		return Hurtbox3D.Result.DODGED
	# §7.3 : le Bouclier d'esprit absorbe une série de coups.
	if _elite_shield > 0 and not info.is_dot:
		_elite_shield -= 1
		FX.impact(_world(), global_position + Vector3(0.0, 1.2, 0.0), "block")
		return Hurtbox3D.Result.BLOCKED
	# Brute (§ 9) : l'armure bloque les coups LÉGERS hors fenêtre de vulnérabilité.
	if data.blocks_hit(info.is_heavy, vulnerable_left > 0.0):
		FX.impact(_world(), global_position + Vector3(0.0, 1.0, 0.0), "block")
		return Hurtbox3D.Result.BLOCKED
	# § 11 : la brûlure (is_dot) consomme la vie sans éclair ni chiffre à chaque
	# frame (sinon 60 nombres de dégâts par seconde).
	if info.is_dot:
		health = maxf(0.0, health - info.amount)
		if health <= 0.0:
			_die()
		return Hurtbox3D.Result.HIT
	# §7.3 : Blindé réduit les dégâts de 40 % tant qu'il n'est pas étourdi.
	var amount := info.amount * EliteAffix.damage_taken_mult(
		elite_affixes, _stun_left > 0.0)
	health = maxf(0.0, health - amount)
	# § 17 : le son de l'ennemi est positionnel (portée courte, 8 voix max).
	AudioManager.play_sfx_at(self, &"hurt", randf_range(0.92, 1.08))
	FX.damage_number(_world(), global_position + Vector3(0.0, 1.7, 0.0), amount,
		"crit" if info.is_critical else "normal")
	_flash_tint()
	var away := _flat(global_position - info.source_position)
	if away.length() > 0.01:
		velocity += away.normalized() * info.knockback * 2.0
	if health <= 0.0:
		_die()
		return Hurtbox3D.Result.HIT
	if _stun_left <= 0.0:
		# Un coup reçu en pleine attaque l'interrompt (sinon il devient injuste).
		if playing_hit:
			_abort_attack(true)
		state = State.HURT
		_state_time = 0.0
		_play("hurt")
	return Hurtbox3D.Result.HIT


func _die() -> void:
	dead = true
	state = State.DEAD
	_abort_attack(true)
	remove_from_group("enemies")
	remove_from_group("elites")
	# §7.3 : Explosif laisse une zone rouge au sol en mourant.
	var blast := EliteAffix.explosion(elite_affixes)
	if not blast.is_empty():
		DangerZone3D.spawn(get_parent(), global_position, float(blast["radius"]),
			data.damage * float(blast["damage"]) * GameState.difficulty_damage_mult(),
			0.5, self, Hitbox3D.Danger.RED)
	_play("death")
	died.emit(self, maxi(0, data.drops_cauris))
	Events.enemy_died.emit(self)
	await get_tree().create_timer(DEATH_TIME, true, false, true).timeout
	queue_free()


# -----------------------------------------------------------------#
#                           OUTILS                                 #
# -----------------------------------------------------------------#

## Séparation entre ennemis (§ 9 : « pour ne pas se superposer »).
func _apply_separation(delta: float) -> void:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is Node3D):
			continue
		var offset := _flat((other as Node3D).global_position - global_position)
		var distance := offset.length()
		if distance > 0.01 and distance < SEPARATION_RADIUS:
			push -= offset.normalized() * (SEPARATION_RADIUS - distance)
	velocity.x += push.x * SEPARATION_STRENGTH * delta * 10.0
	velocity.z += push.z * SEPARATION_STRENGTH * delta * 10.0


func _nearest_player() -> Player3D:
	var best: Player3D = null
	var best_distance := INF
	for player in get_tree().get_nodes_in_group("players"):
		var actor := player as Player3D
		if actor == null or actor.state == Player3D.State.DEAD:
			continue
		var distance := global_position.distance_to(actor.global_position)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best


func _distance_to(actor: Node3D) -> float:
	return _flat(actor.global_position - global_position).length()


func _face_toward(actor: Node3D) -> void:
	var dir := _flat(actor.global_position - global_position)
	if dir.length() > 0.01:
		_face(dir.normalized())


func _face(dir: Vector3) -> void:
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 0.25)


func _forward() -> Vector3:
	return -visual.global_transform.basis.z


func _chest() -> Vector3:
	return global_position + Vector3(0.0, 1.0, 0.0)


func _flat(value: Vector3) -> Vector3:
	value.y = 0.0
	return value


func _play(state_name: String) -> void:
	if playback and anim_tree and anim_tree.tree_root.has_node(state_name):
		playback.travel(state_name)


func _ensure_anim_idle() -> void:
	if _anim_ready:
		return
	_anim_ready = CharacterAnimation.start_when_ready(playback, "idle", _anim_tries)
	_anim_tries += 1


func _set_tint(color: Color) -> void:
	for material in _materials:
		material.set_shader_parameter("tint", color)


func _flash_tint() -> void:
	if _stun_left > 0.0:
		return
	_flash_left = FLASH_TIME
	_set_tint(FLASH_COLOR)


func _restore_tint() -> void:
	# Un élite garde un liseré doré reconnaissable même hors télégraphe.
	if not elite_affixes.is_empty():
		_set_tint(ELITE_COLOR)
		return
	for i in _materials.size():
		_materials[i].set_shader_parameter("tint", _tints[i])


func _world() -> Node:
	var parent := get_parent()
	return parent if parent != null else get_tree().current_scene
