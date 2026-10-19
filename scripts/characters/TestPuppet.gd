extends Node3D
## Mannequin provisoire de PHASE 0.5 (DOSSIER.md § 6.6) : construit en
## primitives avec pivots d'articulation, il génère la bibliothèque
## d'animations STANDARDS du projet :
##   idle, run, attack1-3, dodge, guard, hurt, death, interact.
## Le code gameplay ne connaît QUE ces noms ; remplacer par le vrai .glb
## Mixamo (§ 6.4) ne touchera pas à l'AnimationTree ni au viewer.

## NOTE : ce fichier vit dans `scripts/characters/`, PAS dans `scripts/tests/`.
## Le filtre d'export Android exclut `scripts/tests/*`, alors que `Player3D`,
## `EnemyBase3D` et `Dummy3D` instancient cette poupée quand aucun `.glb` n'est
## fourni. Déplacée ici, elle part bien dans l'APK (bug constaté sur l'itel le
## 19 octobre : `LevelBase3D` ne trouvait plus de `Player3D` typé).
class_name TestPuppet

const CEL_SHADER := preload("res://shaders/cel_shading.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

## Couleurs DA (§ 5) : peau / rouge Dahomey / indigo / or / lame.
const COL := {
	"skin": Color(1.0, 0.84, 0.71),
	"tunic": Color(0.702, 0.149, 0.118),
	"cloth": Color(0.122, 0.165, 0.361),
	"gold": Color(0.890, 0.663, 0.169),
	"lame": Color(0.55, 0.55, 0.60),
}

## Hauteur du torse au repos. L'idle anime la POSITION du torse (respiration),
## donc cette piste doit exister dans TOUS les clips : voir `_clip`.
const REST_TORSO_Y: float = 1.05
## Articulations écrites par TOUS les clips (voir `_clip`).
const ANIM_PATHS: Array[String] = [
	"Pivot", "Pivot/Torso", "Pivot/Torso/PivotRArm",
	"Pivot/Torso/PivotLArm", "Pivot/PivotLegR", "Pivot/PivotLegL",
]

var anim_player: AnimationPlayer
var outline_material: ShaderMaterial
var _white_tex: ImageTexture


func _ready() -> void:
	_white_tex = _white_texture()
	outline_material = ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	anim_player = _build_puppet()


## VivTex 1x1 blanche pour l'ouverture d'uniforme albedo_tex du cel-shading
## quand le modèle n'a pas encore de vraie texture (§ 6.2).
func _white_texture() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


# -----------------------------------------------------------------#
#                          CONSTRUCTION                            #
# -----------------------------------------------------------------#

func _mat(color_key: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CEL_SHADER
	m.set_shader_parameter("tint", COL[color_key])
	m.set_shader_parameter("albedo_tex", _white_tex)
	m.next_pass = outline_material
	return m


func _add_pivot(p_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = p_name
	p.position = pos
	parent.add_child(p)
	return p


func _cap(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_puppet() -> AnimationPlayer:
	var pivot := _add_pivot("Pivot", self, Vector3(0, 0, 0))

	# Torse : contient aussi la tête et les bras (toute la partie haute).
	var torso := _add_pivot("Torso", pivot, Vector3(0, 1.05, 0))
	_add_mesh(torso, _cap(0.24, 0.65), _mat("tunic"), Vector3(0, 0, 0))
	_add_mesh(torso, _sphere(0.16), _mat("skin"), Vector3(0, 0.55, 0))
	# Bannière or dans le dos (accessoire emblématique § 15.3).
	_add_mesh(torso, _box(0.02, 0.5, 0.34), _mat("gold"), Vector3(0, 0.0, -0.22))

	# Bras : pivots aux épaules, membres vers le bas (-Y).
	var r_arm := _add_pivot("PivotRArm", torso, Vector3(0.3, 0.2, 0.0))
	_add_mesh(r_arm, _cap(0.07, 0.42), _mat("skin"), Vector3(0, -0.24, 0))
	_add_mesh(r_arm, _box(0.05, 0.02, 0.55), _mat("lame"), Vector3(0, -0.46, 0.28))

	var l_arm := _add_pivot("PivotLArm", torso, Vector3(-0.3, 0.2, 0.0))
	_add_mesh(l_arm, _cap(0.07, 0.42), _mat("skin"), Vector3(0, -0.24, 0))

	# Jambes : pivots aux hanches sous le pivot du corps.
	var r_leg := _add_pivot("PivotLegR", pivot, Vector3(0.11, 0.95, 0.0))
	_add_mesh(r_leg, _cap(0.08, 0.5), _mat("cloth"), Vector3(0, -0.28, 0))

	var l_leg := _add_pivot("PivotLegL", pivot, Vector3(-0.11, 0.95, 0.0))
	_add_mesh(l_leg, _cap(0.08, 0.5), _mat("cloth"), Vector3(0, -0.28, 0))

	# Lecteur d'animations - bibliothèque "", renommée plus tard par le viewer.
	return _make_anim_player()


func _make_anim_player() -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "AnimPlayer"
	player.root_node = NodePath("..")  ## repère des pistes : le mannequin parent
	add_child(player)

	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_idle())
	lib.add_animation("run", _make_run())
	lib.add_animation("attack1", _make_attack(0.5, -0.9, 1.5))
	lib.add_animation("attack2", _make_attack(0.55, 0.6, -1.2))
	lib.add_animation("attack3", _make_attack3())
	lib.add_animation("dodge", _make_dodge())
	lib.add_animation("guard", _make_guard())
	lib.add_animation("hurt", _make_hurt())
	lib.add_animation("death", _make_death())
	lib.add_animation("interact", _make_interact())
	player.add_animation_library("", lib)
	player.play("idle")
	return player


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _box(w: float, h: float, d: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(w, h, d)
	return m


# -----------------------------------------------------------------#
#                     ANIMATIONS (standard)                        #
# -----------------------------------------------------------------#

## Construction d'un clip. keys : { chemin_chemin_noeud: [[t, (rx,ry,rz)], ...] } angles en radians.
func _anim(len: float, loop: bool) -> Animation:
	var a := Animation.new()
	a.length = len
	if loop:
		a.loop_mode = Animation.LOOP_LINEAR
	return a


## Injecte une piste de rotation. keys : Array[ [t, Vector3 angles_rad], ... ].
func _rot(anim: Animation, node_path: String, keys: Array) -> void:
	var idx := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(idx, node_path)
	for k in keys:
		var q := Quaternion.from_euler(Vector3(k[1].x, k[1].y, k[1].z))
		anim.rotation_track_insert_key(idx, k[0], q)


## Piste de position (buste pour la respiration).
func _pos(anim: Animation, node_path: String, keys: Array) -> void:
	var idx := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(idx, node_path)
	for k in keys:
		anim.position_track_insert_key(idx, k[0], k[1])


## Construit un clip COMPLET. Pendant un fondu, Godot met à l'échelle la piste
## d'une animation par le poids de celle-ci : une piste absente du clip
## d'arrivée tend donc vers 0 et effondre l'articulation. Un clip qui n'animait
## que le bras faisait ainsi tomber le torse (respiré par l'idle) à hauteur des
## pieds. Chaque clip écrit donc TOUTES les pistes de ANIM_PATHS, à la pose de
## repos par défaut ; `rotations` et `positions` remplacent celles du mouvement.
## keys : { chemin_noeud: [[t, Vector3], ...] }, angles en radians.
func _clip(len: float, loop: bool, rotations: Dictionary = {},
		positions: Dictionary = {}) -> Animation:
	var a := _anim(len, loop)
	for path in ANIM_PATHS:
		var keys: Array = rotations.get(path, [[0.0, Vector3.ZERO], [len, Vector3.ZERO]])
		_rot(a, path, keys)
	var torso_keys: Array = positions.get("Pivot/Torso", [
		[0.0, Vector3(0, REST_TORSO_Y, 0)], [len, Vector3(0, REST_TORSO_Y, 0)],
	])
	_pos(a, "Pivot/Torso", torso_keys)
	return a


func _make_idle() -> Animation:
	return _clip(2.0, true, {
		"Pivot/Torso/PivotRArm": [[0.0, Vector3(0, 0, 0)], [1.0, Vector3(0.06, 0, 0)], [2.0, Vector3(0, 0, 0)]],
		"Pivot/Torso/PivotLArm": [[0.0, Vector3(0, 0, 0)], [1.0, Vector3(0.06, 0, 0)], [2.0, Vector3(0, 0, 0)]],
	}, {
		"Pivot/Torso": [[0.0, Vector3(0, REST_TORSO_Y, 0)], [1.0, Vector3(0, REST_TORSO_Y - 0.03, 0)], [2.0, Vector3(0, REST_TORSO_Y, 0)]],
	})


func _make_run() -> Animation:
	return _clip(0.8, true, {
		"Pivot/PivotLegR": [[0.0, Vector3(0.7, 0, 0)], [0.4, Vector3(-0.7, 0, 0)], [0.8, Vector3(0.7, 0, 0)]],
		"Pivot/PivotLegL": [[0.0, Vector3(-0.7, 0, 0)], [0.4, Vector3(0.7, 0, 0)], [0.8, Vector3(-0.7, 0, 0)]],
		"Pivot/Torso/PivotRArm": [[0.0, Vector3(-0.6, 0, 0)], [0.4, Vector3(0.6, 0, 0)], [0.8, Vector3(-0.6, 0, 0)]],
		"Pivot/Torso/PivotLArm": [[0.0, Vector3(0.6, 0, 0)], [0.4, Vector3(-0.6, 0, 0)], [0.8, Vector3(0.6, 0, 0)]],
	})


## Coup générique : coups 1 et 2 (aller-retour du bras armé).
func _make_attack(len: float, back: float, front: float) -> Animation:
	return _clip(len, false, {
		"Pivot/Torso/PivotRArm": [
			[0.0, Vector3(back, 0, 0)], [len * 0.6, Vector3(front, 0, 0)], [len, Vector3(front, 0, 0)],
		],
	})


## Coup 3 (finisseur) : grand balayage + torsion du torse.
func _make_attack3() -> Animation:
	return _clip(0.6, false, {
		"Pivot/Torso/PivotRArm": [[0.0, Vector3(-1.2, 0, 0)], [0.35, Vector3(1.8, 0, 0)], [0.6, Vector3(0.9, 0, 0)]],
		"Pivot/Torso": [[0.0, Vector3(0, -0.4, 0)], [0.35, Vector3(0, 0.4, 0)], [0.6, Vector3(0, 0, 0)]],
	})


func _make_dodge() -> Animation:
	return _clip(0.35, false, {
		"Pivot": [[0.0, Vector3(0, 0, 0)], [0.14, Vector3(-0.5, 0, 0)], [0.35, Vector3(0, 0, 0)]],
	})


func _make_guard() -> Animation:
	return _clip(1.0, true, {
		"Pivot/Torso/PivotRArm": [[0.0, Vector3(1.2, 0, 0)], [1.0, Vector3(1.2, 0, 0)]],
		"Pivot/Torso/PivotLArm": [[0.0, Vector3(1.0, 0, 0)], [1.0, Vector3(1.0, 0, 0)]],
	})


func _make_hurt() -> Animation:
	return _clip(0.3, false, {
		"Pivot": [
			[0.0, Vector3(0, 0, 0)], [0.1, Vector3(0, 0, 0.12)], [0.2, Vector3(0, 0, -0.12)], [0.3, Vector3(0, 0, 0)],
		],
	})


func _make_death() -> Animation:
	return _clip(1.0, false, {
		"Pivot": [[0.0, Vector3(0, 0, 0)], [1.0, Vector3(1.6, 0, 0)]],
	})


func _make_interact() -> Animation:
	return _clip(1.2, true, {
		"Pivot/Torso": [[0.0, Vector3(-0.6, 0, 0)], [0.9, Vector3(-0.6, 0, 0)], [1.2, Vector3(0, 0, 0)]],
	})
