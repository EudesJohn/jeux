extends Node3D
class_name LevelBase3D
## Moteur de niveau unique (DESIGN.md § 20.9) : tout est piloté par `LevelData`.
## « Changer un .tres donne un autre niveau » (§ 28 PHASE 3) : `load_level()`
## reconstruit sol, pièges, ramassages, checkpoint, sortie, ambiance, caméra,
## vagues et objectif à partir de la seule ressource.
##
## PHASE 3 : décors « graybox » (blocs simples), 3 objectifs (clear, survive,
## exit), 6 types d'ennemis, les 6 pièges du § 11, checkpoints, cauris, potions.
## PHASE 4 : Sauvetage et Escorte (§ 12.2) — cages à libérer en 2 s,
## villageois à conduire à la sortie, objectif « boss » en squelette, écran de
## résultat et écran de défaite.

const DEFAULT_LEVEL: String = "res://data/levels/lane_01.tres"
const GROUND_THICKNESS: float = 0.4
const LANE_MARGIN: float = 2.0                 ## murs latéraux hors zone jouable
const OCRE: Color = Color(0.78, 0.49, 0.23)
const SAND: Color = Color(0.85, 0.68, 0.42)
const STONE: Color = Color(0.42, 0.40, 0.38)
const GOLD: Color = Color(0.89, 0.66, 0.17)
const NIGHT_AMBIENT: Color = Color(0.12, 0.16, 0.36)

signal level_completed(stars: int)
signal level_failed(reason: String)
signal checkpoint_activated(position: Vector3)

@export var level_data: LevelData
@export var build_graybox: bool = true
## Vitesse des vagues pour les tests (< 1 = plus rapide).
@export var wave_delay_multiplier: float = 1.0

@onready var environment_node: WorldEnvironment = $WorldEnvironment
@onready var built: Node3D = $Level
@onready var hazards_root: Node3D = $Hazards
@onready var pickups_root: Node3D = $Pickups
@onready var entities_root: Node3D = $Entities
@onready var player: Player3D = $Player3D
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HUD = $HUD
@onready var touch_controls: TouchControls = $TouchControls

var spawner: WaveSpawner3D = null
var objective: Objective = null
var checkpoint: Checkpoint3D = null
var exit_area: Area3D = null
## PHASE 4 : prisonniers et villageois (§ 12.2), posés par le niveau.
var allies_root: Node3D = null
## Écran de fin (§ 13, § 16) : victoire ou défaite, REJOUER / CONTINUER.
var result_screen: ResultScreen = null
## § 16 (PHASE 5) : pause réelle (Reprendre, Recommencer, Réglages, Quitter).
var pause_menu: PauseMenu = null
## PHASE 6 : levé par `BossBase3D` quand le gardien tombe (objectif « boss »).
var boss_defeated: bool = false
## Boss en cours (§ 10) et file d'attente de la Chasse aux boss (§ 12.4).
var boss: BossBase3D = null
var boss_chain_left: Array[String] = []
## Racine des zones de danger au sol : elles survivent au boss qui les a posées.
var zones_root: Node3D = null
## Ralenti de 0,6 s au dernier coup (§ 10) : les tests le coupent.
var boss_slowmo: bool = true
## § 12.3 : choix de bonus de la Survie (null hors Survie ou hors choix).
var bonus_choice: BonusChoice = null
## Vagues tenues en Survie (§ 12.3) : sert au record local.
var survival_waves: int = 0
var _interact_target: Prisoner3D = null
## PHASE 7 : coop WiFi (§ 22). Null hors coop : le niveau reste solo.
var coop: CoopDirector = null
## PHASE 8 : musique et bruits du niveau (§ 17).
var audio: AudioDirector = null

var time_left: float = 0.0
var stars_earned: int = 0
var completed: bool = false
var failed: bool = false
var exit_reached: bool = false
var checkpoint_used: bool = false
var player_deaths: int = 0
var spawn_point: Vector3 = Vector3(2.0, 0.1, 0.0)
var ground_size: Vector3 = Vector3.ZERO        ## lisible par les tests
var paused: bool = false

var _rng := RandomNumberGenerator.new()
var _night_light: OmniLight3D = null
var _decor_multimesh: MultiMeshInstance3D = null


func _ready() -> void:
	Settings.apply_3d_scale()
	EnemyRegistry.preload_all()
	allies_root = Node3D.new()
	allies_root.name = "Allies"
	add_child(allies_root)
	# § 25 : un changement de qualité s'applique tout de suite, sans recharger.
	if not Settings.quality_changed.is_connected(_on_quality_changed):
		Settings.quality_changed.connect(_on_quality_changed)
	result_screen = ResultScreen.new()
	result_screen.name = "ResultScreen"
	result_screen.replay_pressed.connect(restart)
	# § 16 : « Résultat → Carte » ; depuis une scène de test, retour au menu.
	result_screen.menu_pressed.connect(leave_level)
	add_child(result_screen)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.setup(self)
	if level_data == null:
		level_data = GameState.current_level_data as LevelData
	if level_data == null:
		level_data = load(DEFAULT_LEVEL) as LevelData
	if Network.is_coop():
		_setup_coop()
	else:
		player.died.connect(_on_player_died)
	load_level(level_data)


## PHASE 8 : un seul directeur audio par niveau ; il rejoue la musique à
## chaque niveau (l'intensité repart de zéro).
func _setup_audio() -> void:
	if audio == null:
		audio = AudioDirector.new()
		audio.name = "Audio"
		add_child(audio)
	audio.setup(self, player)


## PHASE 7 : en coop, `CoopDirector` remplace la joueuse unique de la scène par
## une joueuse par pair et réplique les ennemis (§ 22.1).
func _setup_coop() -> void:
	coop = CoopDirector.new()
	coop.name = "Coop"
	add_child(coop)
	coop.setup(self)
	coop.local_player_ready.connect(_on_coop_player_ready)
	coop.coop_message.connect(_on_coop_message)
	Events.player_downed.connect(_on_player_downed)


# -----------------------------------------------------------------#
#                        CHARGEMENT                                #
# -----------------------------------------------------------------#

## Construit (ou reconstruit) le niveau à partir d'une fiche. Deux appels avec
## deux `LevelData` différents donnent deux niveaux différents.
func load_level(data: LevelData) -> void:
	if data == null:
		return
	_clear_content()
	level_data = data
	GameState.current_level_data = data
	GameState.reset_run()
	time_left = float(data.time_limit) * GameState.time_mult()
	stars_earned = 0
	completed = false
	failed = false
	exit_reached = false
	checkpoint_used = false
	# Graine fixée par l'identifiant du niveau : le même .tres donne toujours
	# la même disposition (pièges et ramassages reproductibles).
	_rng.seed = hash("%s:%d" % [data.id, data.enemy_waves.size()])
	boss_defeated = false
	boss = null
	boss_chain_left.clear()
	_interact_target = null
	# § 12.5 : le modificateur du jour s'applique à tout le niveau (vitesse,
	# dégâts doubles, une seule vie).
	GameState.modifier = data.modifier
	survival_waves = 0
	if result_screen != null:
		result_screen.hide_screen()
	_build_ground()
	_build_hazards()
	_build_pickups()
	_build_checkpoint()
	_build_exit()
	_build_allies()
	_setup_environment()
	_setup_camera()
	_setup_player()
	# Les vagues AVANT l'objectif : `ClearWaves.start()` lit le total de vagues
	# du spawner (sinon l'avancement de l'objectif reste bloqué à 0 %).
	_setup_waves()
	_setup_objective()
	_build_boss()
	_setup_audio()
	_apply_quality()
	hud.bind_level(self)
	if coop != null:
		# L'hôte crée les deux joueuses ; l'invitée les reçoit par le réseau.
		coop.start_level()
	else:
		hud.bind(player)


func _clear_content() -> void:
	_decor_multimesh = null
	for root in [built, hazards_root, pickups_root, entities_root, allies_root]:
		if root == null:
			continue
		for child in root.get_children():
			child.queue_free()
	_interact_target = null
	if boss != null:
		boss.queue_free()
		boss = null
	boss_chain_left.clear()
	if zones_root != null:
		for zone in zones_root.get_children():
			zone.queue_free()
	if spawner != null:
		Events.enemy_died.disconnect(_on_enemy_died)
		spawner.queue_free()
		spawner = null
	if objective != null:
		objective.queue_free()
		objective = null
	if exit_area != null:
		exit_area.queue_free()
		exit_area = null
	if _night_light != null:
		_night_light.queue_free()
		_night_light = null
	if bonus_choice != null:
		bonus_choice.queue_free()
		bonus_choice = null


# -----------------------------------------------------------------#
#                        GÉOMÉTRIE (graybox)                       #
# -----------------------------------------------------------------#

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1                   ## couche 1 world (§ 19)
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var material := StandardMaterial3D.new()
	material.albedo_color = OCRE
	mesh.material_override = material
	var collision := CollisionShape3D.new()

	if level_data.is_lane():
		var width := (level_data.lane_half_depth + LANE_MARGIN) * 2.0
		ground_size = Vector3(level_data.length_m, GROUND_THICKNESS, width)
		# Le couloir va de x = 0 (départ) à x = length_m (sortie) : le sol est
		# centré sur la moitié du niveau (sinon la 2e moitié est un vide).
		body.position.x = level_data.length_m * 0.5
		var box := BoxMesh.new()
		box.size = ground_size
		mesh.mesh = box
		var shape := BoxShape3D.new()
		shape.size = ground_size
		collision.shape = shape
		mesh.position.y = -GROUND_THICKNESS * 0.5
		collision.position.y = -GROUND_THICKNESS * 0.5
	else:
		var radius := level_data.arena_radius
		ground_size = Vector3(radius * 2.0, GROUND_THICKNESS, radius * 2.0)
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = GROUND_THICKNESS
		disc.radial_segments = 32
		mesh.mesh = disc
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = GROUND_THICKNESS
		collision.shape = shape
		mesh.position.y = -GROUND_THICKNESS * 0.5
		collision.position.y = -GROUND_THICKNESS * 0.5

	body.add_child(mesh)
	body.add_child(collision)
	built.add_child(body)
	if build_graybox:
		_build_decor()


## Décor « graybox » (§ 28 PHASE 3 : « blocs simples ») : piliers sur les côtés
## en couloir, rochers en arène. Aucune collision : c'est du volume visuel.
##
## § 25 : les blocs passent par UN SEUL `MultiMeshInstance3D` (un seul appel de
## dessin au lieu de six ou sept), avec la couleur par instance, et le décor
## lointain disparaît par `visibility_range`.
func _build_decor() -> void:
	var count := 6 if level_data.is_lane() else 7
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE          # la taille réelle est dans la transformation
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in count:
		var height := _rng.randf_range(1.4, 3.2)
		var size := Vector3(_rng.randf_range(1.0, 2.4), height, _rng.randf_range(1.0, 2.0))
		var origin := _decor_position(i, count) + Vector3(0.0, height * 0.5, 0.0)
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(size), origin))
		multimesh.set_instance_color(i, STONE.lerp(SAND, _rng.randf()))
	var decor := MultiMeshInstance3D.new()
	decor.name = "Decor"
	decor.multimesh = multimesh
	decor.material_override = material
	decor.visibility_range_end = 120.0
	decor.visibility_range_end_margin = 8.0
	built.add_child(decor)
	_decor_multimesh = decor


## Nombre d'instances de décor (tests du § 25 : un seul nœud de décor).
func decor_instance_count() -> int:
	if not is_instance_valid(_decor_multimesh) or _decor_multimesh.multimesh == null:
		return 0
	return _decor_multimesh.multimesh.instance_count


# -----------------------------------------------------------------#
#                  QUALITÉ GRAPHIQUE (§ 25)                        #
# -----------------------------------------------------------------#

## Applique la qualité choisie à la scène : ombre au sol, contour de la
## joueuse en qualité Haute, et une lampe directionnelle (avec ombre) seulement
## dans ce même réglage. Rappelé à chaque changement dans les Réglages.
func _apply_quality() -> void:
	_apply_blob_shadow()
	_apply_outline()
	_apply_sun_light()


## § 25 : ombre « blob » (un disque sombre sous les pieds) par défaut — c'est
## ce qui coûte le moins cher sur un téléphone d'entrée de gamme.
func _apply_blob_shadow() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.get_node_or_null("BlobShadow") != null:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 0.45
	mesh.height = 0.01
	mesh.radial_segments = 16
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	var blob := MeshInstance3D.new()
	blob.name = "BlobShadow"
	blob.mesh = mesh
	blob.material_override = material
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position = Vector3(0.0, 0.02, 0.0)
	player.add_child(blob)


## § 25 : « Haute : ombre de la joueuse + outline ». Le contour est une copie
## de chaque maillage, noire, légèrement gonflée et retournée (grow + cull
## front) : le procédé classique du cel-shading, sans shader supplémentaire.
func _apply_outline() -> void:
	if player == null or not is_instance_valid(player):
		return
	var visual := player.get_node_or_null("Visual")
	if visual == null:
		return
	var existing := visual.get_node_or_null("Outline")
	if not Quality.outline_enabled():
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.06, 0.05, 0.05)
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	material.grow_amount = 0.018
	var outline := Node3D.new()
	outline.name = "Outline"
	visual.add_child(outline)
	# La liste est figée avant la boucle : on ne copie pas les copies.
	for source in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := source as MeshInstance3D
		if mesh_instance.name.begins_with("Outline_"):
			continue
		var copy := MeshInstance3D.new()
		copy.name = "Outline_%s" % mesh_instance.name
		copy.mesh = mesh_instance.mesh
		copy.material_override = material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.transform = outline.global_transform.affine_inverse() * mesh_instance.global_transform
		outline.add_child(copy)


## Qualité Haute : une seule lampe directionnelle, avec ombre (§ 25).
func _apply_sun_light() -> void:
	var existing := built.get_node_or_null("SunLight")
	if not Quality.real_shadows_enabled():
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		return
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	# Mesuré sur l'itel S667LN (19 oct.) : en mode par défaut (PSSM 4 splits),
	# la passe d'ombre redessine TOUT le décor quatre fois — 1,4 M de primitives
	# contre 276 k en qualité Faible, et le pire 1 % tombe sous 30 images/s.
	# Une seule tranche orthogonale suffit pour une caméra d'arène : la même
	# ombre, un quart du coût.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# Au-delà de 18 m, l'ombre ne se voit plus à l'écran : inutile de la calculer.
	sun.directional_shadow_max_distance = 18.0
	sun.directional_shadow_blend_splits = false
	built.add_child(sun)


func _on_quality_changed(_quality: String) -> void:
	_apply_quality()


func _decor_position(index: int, count: int) -> Vector3:
	if level_data.is_lane():
		# Hors de la zone jouable (±3 m) : jamais dans les pieds de la joueuse.
		var x := (float(index) + 0.5) * (level_data.length_m / float(count))
		var side := 1.0 if index % 2 == 0 else -1.0
		var z := side * (level_data.lane_half_depth + LANE_MARGIN * 0.6)
		return Vector3(x, 0.0, z)
	var ring := level_data.arena_radius - 2.0
	var angle := TAU * float(index) / float(count)
	return Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)


# -----------------------------------------------------------------#
#                            PIÈGES                                #
# -----------------------------------------------------------------#

func _build_hazards() -> void:
	if level_data.hazards.is_empty():
		return
	var kinds: Array[String] = level_data.hazards
	var total := kinds.size() * maxi(1, level_data.hazards_per_kind)
	var slot := 0
	for kind_name in kinds:
		for _copy in maxi(1, level_data.hazards_per_kind):
			var hazard := Hazard3D.new()
			hazard.name = "Hazard_%s_%d" % [kind_name, slot]
			hazard.kind = Hazard3D.kind_from_string(kind_name)
			hazard.position = _path_position(slot, total) + Vector3(0.0, 0.05, 0.0)
			hazard.return_point = _return_point(hazard.position)
			hazards_root.add_child(hazard)
			slot += 1


## Position régulière le long du parcours (couloir : en X ; arène : en cercle).
func _path_position(index: int, count: int) -> Vector3:
	if count <= 0:
		return Vector3.ZERO
	if level_data.is_lane():
		var usable := maxf(level_data.length_m - 12.0, 6.0)
		var x := 8.0 + (float(index) + 0.5) * (usable / float(count))
		var z := _rng.randf_range(-level_data.lane_half_depth, level_data.lane_half_depth)
		return Vector3(x, 0.0, z)
	var ring := maxf(level_data.arena_radius - 5.0, 2.0)
	var angle := TAU * (float(index) + 0.5) / float(count)
	return Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)


## Où reposer une victime tombée (§ 11 : « retour au bord »).
func _return_point(from: Vector3) -> Vector3:
	if level_data.is_lane():
		return Vector3(maxf(from.x - 1.6, 1.0), 0.1, clampf(from.z, -level_data.lane_half_depth, level_data.lane_half_depth))
	var pulled := Vector3(from.x, 0.0, from.z).normalized() * maxf(from.length() - 2.5, 1.0)
	return Vector3(pulled.x, 0.1, pulled.z)


# -----------------------------------------------------------------#
#                        RAMASSAGES                                #
# -----------------------------------------------------------------#

func _build_pickups() -> void:
	var total := maxi(0, level_data.cauri_pickups)
	for i in total:
		var pickup := Pickup3D.new()
		pickup.name = "Cauri%d" % i
		pickup.kind = Pickup3D.Kind.CAURI
		pickup.value = maxi(1, level_data.cauri_per_pickup)
		pickup.position = _path_position(i, maxi(total, 1)) + Vector3(0.0, 0.4, 0.0)
		pickups_root.add_child(pickup)
	for i in maxi(0, level_data.potion_pickups):
		var potion := Pickup3D.new()
		potion.name = "Potion%d" % i
		potion.kind = Pickup3D.Kind.POTION
		potion.position = _path_position(i, maxi(level_data.potion_pickups, 1)) \
			+ Vector3(0.0, 0.4, 0.0) + Vector3(3.0, 0.0, 0.0)
		pickups_root.add_child(potion)


# -----------------------------------------------------------------#
#                       CHECKPOINT ET SORTIE                       #
# -----------------------------------------------------------------#

func _build_checkpoint() -> void:
	if level_data.checkpoint_at <= 0.0:
		return
	checkpoint = Checkpoint3D.new()
	checkpoint.name = "Checkpoint"
	checkpoint.position = _checkpoint_position()
	hazards_root.add_child(checkpoint)
	checkpoint.activated.connect(_on_checkpoint_activated)


func _checkpoint_position() -> Vector3:
	var at := clampf(level_data.checkpoint_at, 0.05, 0.95)
	if level_data.is_lane():
		return Vector3(level_data.length_m * at, 0.0, 0.0)
	var ring := level_data.arena_radius * at
	return Vector3(ring, 0.0, 0.0)


func _build_exit() -> void:
	if not level_data.needs_exit():
		return
	exit_area = Area3D.new()
	exit_area.name = "Exit"
	exit_area.collision_layer = 128            ## couche 8 interactable
	exit_area.collision_mask = 2               ## joueuse
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, (level_data.lane_half_depth + LANE_MARGIN) * 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.5
	exit_area.add_child(collision)
	# Anneau doré visible de loin : c'est la sortie (§ 16 « objectif »).
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.4
	marker.mesh = torus
	marker.position.y = 1.6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GOLD
	marker.material_override = material
	exit_area.add_child(marker)
	var at_end := Vector3(maxf(level_data.length_m - 2.0, 2.0), 0.0, 0.0) if level_data.is_lane() \
		else Vector3(level_data.arena_radius - 2.0, 0.0, 0.0)
	exit_area.position = at_end
	exit_area.area_entered.connect(_on_exit_entered)
	built.add_child(exit_area)


# -----------------------------------------------------------------#
#              ALLIÉS : PRISONNIERS ET VILLAGEOIS (§ 12.2)         #
# -----------------------------------------------------------------#

## Cages à libérer et villageois à escorter. Comme les pièges, ils sont placés
## régulièrement le long du parcours et de façon REPRODUCTIBLE (même graine).
func _build_allies() -> void:
	var prisoners := maxi(0, level_data.prisoners)
	var escorts := maxi(0, level_data.escorts)
	if prisoners + escorts <= 0:
		return
	for i in prisoners:
		var prisoner := Prisoner3D.new()
		prisoner.name = "Prisoner%d" % i
		prisoner.max_health = level_data.ally_life
		prisoner.player = player
		prisoner.target = player
		prisoner.position = _ally_position(i, prisoners, true)
		allies_root.add_child(prisoner)
	for i in escorts:
		var villager := Villager3D.new()
		villager.name = "Villager%d" % i
		villager.max_health = level_data.ally_life
		villager.target = player
		villager.position = _ally_position(i, escorts, false)
		allies_root.add_child(villager)


## Les prisonniers sont répartis sur la 2e moitié du parcours (il faut avancer
## pour les trouver) ; les villageois attendent près du départ.
func _ally_position(index: int, count: int, prisoner: bool) -> Vector3:
	var z := 1.2 if index % 2 == 0 else -1.2
	z = clampf(z, -level_data.lane_half_depth, level_data.lane_half_depth)
	if level_data.is_lane():
		var start := 0.45 if prisoner else 0.12
		var span := 0.45 if prisoner else 0.06
		var at := start + span * (float(index) + 0.5) / float(maxi(count, 1))
		return Vector3(level_data.length_m * at, 0.0, z)
	var ring := maxf(level_data.arena_radius - (4.0 if prisoner else 3.0), 2.0)
	var angle := TAU * (float(index) + 0.5) / float(maxi(count, 1))
	return Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)


## Prisonniers encore enfermés, et celui qui est à portée de la joueuse.
func _update_interact() -> void:
	if player == null or not is_instance_valid(player):
		if touch_controls != null:
			touch_controls.set_interact_visible(false)
		return
	# § 22.3 : en coop, « Interaction » sert aussi à relever sa coéquipière.
	if coop != null and coop.downed_near(player):
		_interact_target = null
		if touch_controls != null:
			touch_controls.set_interact_visible(true)
		return
	var nearest: Prisoner3D = null
	var best := INF
	for node in prisoner_nodes():
		var prisoner := node as Prisoner3D
		if prisoner == null or prisoner.freed_flag or prisoner.dead:
			continue
		var distance := prisoner.global_position.distance_to(player.global_position)
		if distance < best:
			best = distance
			nearest = prisoner
	var available := nearest != null and best <= Prisoner3D.RANGE + 0.6
	_interact_target = nearest if available else null
	if touch_controls != null:
		touch_controls.set_interact_visible(available and not failed and not completed)


# -----------------------------------------------------------------#
#                     AMBIANCE ET CAMÉRA                           #
# -----------------------------------------------------------------#

func _setup_environment() -> void:
	var environment := environment_node.environment
	if environment == null:
		environment = Environment.new()
		environment_node.environment = environment
	if level_data.night:
		# § 12.2 : nuit = brouillard sombre + lumière autour de la joueuse.
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.05, 0.06, 0.13)
		environment.ambient_light_color = NIGHT_AMBIENT
		environment.ambient_light_energy = 0.5
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.05, 0.07, 0.19)
		environment.fog_density = 0.04
		_night_light = OmniLight3D.new()
		_night_light.name = "NightLight"
		_night_light.omni_range = 12.0
		_night_light.light_energy = 1.2
		_attach_night_light()
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.12, 0.16, 0.36)
		environment.ambient_light_color = Color(0.96, 0.91, 0.82)
		environment.ambient_light_energy = 0.4
		environment.fog_enabled = false
	_update_night_light()


## La lumière de nuit suit la joueuse locale : en coop elle n'existe qu'une
## fois celle-ci créée (§ 22.1, l'invitée reçoit sa joueuse par le réseau).
func _attach_night_light() -> void:
	if _night_light == null or player == null or not is_instance_valid(player):
		return
	if _night_light.get_parent() == null:
		player.add_child(_night_light)
	else:
		_night_light.reparent(player)


func _update_night_light() -> void:
	if _night_light == null or player == null or not is_instance_valid(player):
		return
	_night_light.global_position = player.global_position + Vector3(0.0, 2.4, 0.0)


func _setup_camera() -> void:
	camera_rig.mode = CameraRig.Mode.LANE if level_data.is_lane() else CameraRig.Mode.ARENA
	if player != null:
		camera_rig.focus = player


# -----------------------------------------------------------------#
#                        JOUEUSE                                   #
# -----------------------------------------------------------------#

func _setup_player() -> void:
	spawn_point = Vector3(2.0, 0.1, 0.0) if level_data.is_lane() else Vector3(0.0, 0.1, 0.0)
	if coop != null:
		# § 22.1 : la joueuse de la scène est remplacée par celles du réseau.
		if player != null and is_instance_valid(player):
			remove_child(player)
			player.queue_free()
		player = null
		return
	player.global_position = spawn_point
	player.velocity = Vector3.ZERO
	player.lane_mode = level_data.is_lane()
	player.lane_depth = level_data.lane_half_depth
	player.lane_center_z = 0.0
	# Le niveau gère la mort : plus de réapparition automatique de PHASE 1.
	player.auto_respawn = false
	player.reset_for_level()


## Position de la joueuse (objectif « exit » et tests).
func player_position() -> Vector3:
	if player == null or not is_instance_valid(player):
		return spawn_point
	return player.global_position


## Durée totale du niveau en secondes (0 = illimité), difficulté comprise.
## Le HUD l'affiche (§ 16) : il ne lit jamais `level_data` directement.
func total_time() -> float:
	if level_data == null:
		return 0.0
	return float(level_data.time_limit) * GameState.time_mult()


# -----------------------------------------------------------------#
#                       OBJECTIF ET VAGUES                         #
# -----------------------------------------------------------------#

func _setup_objective() -> void:
	match level_data.objective:
		"survive":
			objective = SurviveObjective.new()
		"exit":
			objective = ReachExit.new()
		"rescue":
			objective = RescueObjective.new()
		"escort":
			objective = EscortObjective.new()
		"boss":
			objective = KillBossObjective.new()
		_:
			objective = ClearWaves.new()
	objective.name = "Objective"
	add_child(objective)
	objective.setup(level_data, self)
	objective.start()


func _setup_waves() -> void:
	spawner = WaveSpawner3D.new()
	spawner.name = "WaveSpawner3D"
	spawner.delay_multiplier = wave_delay_multiplier
	add_child(spawner)
	Events.enemy_died.connect(_on_enemy_died)
	spawner.wave_cleared.connect(_on_wave_cleared)
	spawner.setup(level_data, entities_root, self)


# -----------------------------------------------------------------#
#                     BOSS DE FIN DE CHAPITRE (§ 10)                #
# -----------------------------------------------------------------#

## Pose le gardien du niveau (`boss_id`) puis, en Chasse aux boss, les suivants
## (`boss_chain`) : ils arrivent l'un après l'autre, sans pause (§ 12.4).
func _build_boss() -> void:
	if level_data == null:
		return
	boss_chain_left.clear()
	if not String(level_data.boss_id).is_empty():
		boss_chain_left.append(level_data.boss_id)
	for boss_id in level_data.boss_chain:
		if not boss_chain_left.has(boss_id):
			boss_chain_left.append(boss_id)
	boss_defeated = false
	_spawn_next_boss()


func _spawn_next_boss() -> void:
	if boss_chain_left.is_empty():
		return
	if zones_root == null or not is_instance_valid(zones_root):
		zones_root = Node3D.new()
		zones_root.name = "DangerZones"
		add_child(zones_root)
	var boss_id: String = boss_chain_left.pop_front()
	boss = BossBase3D.new()
	boss.name = "Boss_%s" % boss_id
	boss.data = BossRegistry.get_data(boss_id)
	boss.zone_root = zones_root
	boss.slowmo_on_death = boss_slowmo
	boss.position = boss_spawn_position()
	entities_root.add_child(boss)
	# § 22.1 : chez l'invitée le gardien n'est qu'un reflet — sa vie arrive par
	# l'instantané du niveau, et il ne joue aucun coup.
	if coop != null and not Network.is_host():
		boss.set_physics_process(false)
	boss.died.connect(_on_boss_died)
	boss.summon_requested.connect(_on_boss_summon)
	boss.phase_changed.connect(func(phase: int) -> void:
		Events.boss_phase_changed.emit(phase))
	boss.health_changed.connect(func(current: float, maximum: float) -> void:
		Events.boss_health_changed.emit(current, maximum))
	Events.boss_spawned.emit(boss)
	if hud != null:
		hud.bind_boss(boss)


## Le gardien apparaît devant la joueuse : au fond du couloir, ou à 8 m dans
## l'arène (§ 3.1).
func boss_spawn_position() -> Vector3:
	if level_data == null:
		return Vector3(8.0, 0.1, 0.0)
	if level_data.is_lane():
		return Vector3(level_data.length_m * 0.75, 0.1, 0.0)
	return Vector3(minf(8.0, level_data.arena_radius * 0.6), 0.1, 0.0)


func _on_boss_died(dead_boss: BossBase3D, cauris: int) -> void:
	if cauris > 0:
		Pickup3D.cauri_at(pickups_root, dead_boss.global_position, cauris)
	boss = null
	Events.boss_defeated.emit(dead_boss)
	# § 12.4 : le boss suivant arrive, sans pause ni soin.
	if not boss_chain_left.is_empty():
		await get_tree().create_timer(1.0, true, false, true).timeout
		if completed or failed:
			return
		_spawn_next_boss()
		return
	boss_defeated = true
	# § 12.4 : un gardien vaincu ouvre la Chasse aux boss (et se souvient du boss).
	if dead_boss.data != null:
		SaveManager.record_level_result("boss_%s" % dead_boss.data.id, 1, 0)


## § 10 : le capitaine et le général appellent des soldats en phase 2.
func _on_boss_summon(type_name: String, count: int, at: Vector3) -> void:
	if spawner == null:
		return
	for i in count:
		spawner.spawn(type_name, at + Vector3(1.4 * float(i), 0.0, 0.0))


# -----------------------------------------------------------------#
#                   SURVIE : BONUS ENTRE LES VAGUES (§ 12.3)        #
# -----------------------------------------------------------------#

## Une vague de Survie vient d'être nettoyée : on compte, on suspend le flux et
## on propose les trois bonus. Le niveau ne choisit jamais à la place du joueur.
func _on_wave_cleared(index: int) -> void:
	if level_data == null or not level_data.endless:
		return
	survival_waves = maxi(survival_waves, index + 1)
	# PHASE 8 : buts du jour (§ objectifs journaliers) — une vague tenue compte.
	DailySeed.add_progress("survival_waves")
	if spawner != null:
		spawner.flow_paused = true
	_offer_bonus(index)


func _offer_bonus(wave: int) -> void:
	if bonus_choice != null and is_instance_valid(bonus_choice):
		return
	bonus_choice = BonusChoice.new()
	add_child(bonus_choice)
	bonus_choice.offer(self, wave)
	bonus_choice.chosen.connect(_on_bonus_chosen)


func _on_bonus_chosen(id: String) -> void:
	bonus_choice = null
	if spawner != null:
		spawner.flow_paused = false
	if hud != null:
		hud.announce("BONUS : %s" % BonusChoice.label_for(id))


## Effet d'un bonus (§ 12.3). Public : les tests l'appellent directement.
func apply_bonus(id: String) -> void:
	if player == null:
		return
	match id:
		"heal":
			player.heal(player.balance.max_health * 0.4)
		"damage":
			player.run_damage_mult += 0.15
		"special":
			player.set_energy(player.balance.max_energy)


## Cauris lâchés par un ennemi mourant (§ 9 : `drops_cauris`).
func _on_enemy_died(enemy: Node) -> void:
	if not (enemy is EnemyBase3D):
		return
	var actor := enemy as EnemyBase3D
	var amount := maxi(0, actor.data.drops_cauris) if actor.data != null else 0
	if amount > 0:
		Pickup3D.cauri_at(pickups_root, actor.global_position, amount)


func _on_checkpoint_activated(_checkpoint: Checkpoint3D, at: Vector3) -> void:
	spawn_point = at
	checkpoint_activated.emit(at)


func _on_exit_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox3D
	if hurtbox != null and hurtbox.owner_actor is Player3D:
		exit_reached = true


# -----------------------------------------------------------------#
#                          MORT ET FIN                             #
# -----------------------------------------------------------------#

## PHASE 7 : une joueuse tombe en coop — 10 s pour la relever (§ 22.3).
func _on_player_downed(actor: Node) -> void:
	if coop == null or completed or failed:
		return
	var player_actor := actor as Player3D
	if player_actor == null:
		return
	coop.mark_downed(player_actor.peer_id)


func _on_coop_player_ready(new_player: Player3D) -> void:
	player = new_player
	if audio != null:
		audio.attach_player(player)
	player.died.connect(_on_player_died)
	_attach_night_light()
	hud.bind(player)
	if camera_rig != null:
		camera_rig.focus = player


func _on_coop_message(text: String) -> void:
	if hud != null:
		hud.announce(text)


## § 22.3 : l'hôte a coupé la partie pendant le niveau. On prévient et on
## renvoie au menu (l'invitée peut relancer une coop ou jouer en solo).
func fail_offline(reason: String) -> void:
	if completed or failed:
		return
	Network.leave()
	if hud != null:
		hud.announce(reason)
	if result_screen != null:
		result_screen.show_defeat(reason)


func _on_player_died() -> void:
	player_deaths += 1
	if completed or failed:
		return
	# § 12.5 : « une seule vie » — aucune réapparition, même en Facile.
	if GameState.is_one_life():
		_fail("vie")
		return
	# § 12.3 : en Survie, une chute termine le run — c'est elle qui donne un
	# record (une réapparition rendrait le compteur de vagues trompeur).
	if level_data != null and level_data.endless:
		_fail("vie")
		return
	# § 13 : une réapparition par niveau en Normal, illimitée en Facile.
	var respawns_left := GameState.difficulty == "easy" or not checkpoint_used
	if not respawns_left:
		_fail("vie")
		return
	checkpoint_used = true
	_respawn_player()


func _respawn_player() -> void:
	player.respawn_at(spawn_point)


func _process(delta: float) -> void:
	_update_night_light()
	_update_interact()
	if completed or failed:
		return
	if coop != null:
		# § 22.1 : l'hôte envoie l'état du niveau ; l'invitée l'applique et ne
		# simule ni le temps, ni les objectifs, ni les vagues.
		coop.tick(delta)
		if not Network.is_host():
			return
	if level_data.time_limit > 0:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			if objective != null and objective.time_up_is_success():
				_win()
			else:
				_fail("temps")
			return
	if objective != null:
		objective.process_level(delta)
		if objective.success():
			_win()
			return
		# § 12.2 : un objectif devenu impossible (villageois tué) arrête le niveau.
		if objective.failed():
			_fail(objective.failure_reason())


func _win() -> void:
	if completed:
		return
	completed = true
	if audio != null:
		audio.victory()
	if pause_menu != null and pause_menu.is_open:
		pause_menu.close()
	stars_earned = _compute_stars()
	# § 14.1 : la récompense du niveau s'ajoute aux cauris ramassés.
	if level_data.reward_cauris > 0:
		GameState.add_cauris(level_data.reward_cauris)
	var cauris := GameState.cauris_this_run
	SaveManager.record_level_result(level_data.id, stars_earned, cauris)
	GameState.cauris_this_run = 0
	if hud != null:
		hud.show_result("NIVEAU TERMINÉ", stars_earned)
	if result_screen != null:
		result_screen.show_win(stars_earned, time_left, cauris)
	# § 12.5 : une victoire du jour entretient (ou casse) la série de jours.
	if GameState.mode == GameState.GameMode.DAILY:
		DailySeed.record_daily_result(true)
	Events.objective_completed.emit()
	Events.level_completed.emit(level_data.id, stars_earned)
	level_completed.emit(stars_earned)


## Étoiles du § 13 : ★ terminer, ★★ ≥ 50 % de vie ou temps argent,
## ★★★ bonus de l'objectif.
func _compute_stars() -> int:
	var stars := 1
	if _health_ratio() >= 0.5 or time_left > float(level_data.star_time_silver) * 0.4:
		stars = 2
	if objective != null and objective.bonus_achieved():
		stars = 3
	return stars


## Vie restante de la joueuse (0-1) : sert aux étoiles (§ 13) et au bonus du
## boss (§ 12.2 : ★★★ si elle reste au-dessus de 50 %).
func health_ratio() -> float:
	if player == null or not is_instance_valid(player) or player.balance == null:
		return 1.0
	return clampf(player.health / maxf(player.balance.max_health, 0.001), 0.0, 1.0)


func _health_ratio() -> float:
	return health_ratio()


func _fail(reason: String) -> void:
	if failed:
		return
	failed = true
	# § 12.3 : la Survie enregistre le nombre de vagues tenues et l'affiche.
	if level_data != null and level_data.endless:
		var record := SaveManager.survival_record()
		var beat := SaveManager.record_survival(survival_waves)
		if beat:
			record = survival_waves
		reason = "%d vague(s) — record %d%s" % [
			survival_waves, record, "  (NOUVEAU !)" if beat else ""]
	if audio != null:
		audio.defeat()
	if hud != null:
		hud.show_result("ÉCHEC — " + reason, 0)
	if result_screen != null:
		result_screen.show_defeat(reason)
	if touch_controls != null:
		touch_controls.set_interact_visible(false)
	Events.level_failed.emit(reason)
	level_failed.emit(reason)


## Le niveau repart à zéro (bouton REJOUER de l'écran de résultat).
func restart() -> void:
	get_tree().paused = false
	paused = false
	if coop != null:
		Network.restart_coop_level()
		return
	load_level(level_data)


## Quitte le niveau et revient à la carte (campagne/Sauvetage) ou au menu.
func leave_level() -> void:
	get_tree().paused = false
	paused = false
	if coop != null:
		# § 22.3 : on quitte proprement la partie (l'autre joueuse est prévenue).
		Network.leave()
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
		return
	get_tree().change_scene_to_file(GameState.return_scene_path())


# -----------------------------------------------------------------#
#                          LECTURE (tests)                         #
# -----------------------------------------------------------------#

## Les pièges seuls (le checkpoint vit aussi sous `Hazards`).
func hazard_nodes() -> Array[Node]:
	var out: Array[Node] = []
	for child in hazards_root.get_children():
		if child is Hazard3D:
			out.append(child)
	return out


func pickup_nodes() -> Array[Node]:
	return pickups_root.get_children()


func enemy_nodes() -> Array[Node]:
	return entities_root.get_children()


## Prisonniers du § 12.2 (cages) : l'objectif « rescue » les compte.
func prisoner_nodes() -> Array[Node]:
	var out: Array[Node] = []
	if allies_root == null:
		return out
	for child in allies_root.get_children():
		if child is Prisoner3D:
			out.append(child)
	return out


## Villageois du § 12.2 (escorte).
func escort_nodes() -> Array[Node]:
	var out: Array[Node] = []
	if allies_root == null:
		return out
	for child in allies_root.get_children():
		if child is Villager3D:
			out.append(child)
	return out


func ally_nodes() -> Array[Node]:
	return allies_root.get_children() if allies_root != null else [] as Array[Node]


## Couple (libérés, total) affiché par le HUD (§ 16).
func prisoner_status() -> Vector2i:
	var total := 0
	var freed := 0
	for node in prisoner_nodes():
		total += 1
		if node.get("freed_flag") == true:
			freed += 1
	return Vector2i(freed, total)


## Jauge de l'interaction de 2 s (§ 12.2), pour le HUD.
func interact_ratio() -> float:
	if _interact_target == null or not is_instance_valid(_interact_target):
		return 0.0
	return _interact_target.hold_ratio()


func interact_available() -> bool:
	return _interact_target != null and is_instance_valid(_interact_target)


func objective_name() -> String:
	return objective.description() if objective != null else ""


# -----------------------------------------------------------------#
#                            PAUSE                                 #
# -----------------------------------------------------------------#

## Bouton Pause du HUD tactile (§ 7) et touche Échap : ouvre/ferme la pause.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_pause_pressed()


func _on_pause_pressed() -> void:
	if pause_menu == null:
		return
	if pause_menu.is_open:
		pause_menu.close()
	else:
		pause_menu.open()
