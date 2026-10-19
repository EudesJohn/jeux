extends Resource
class_name CharacterLook
## Apparence de la guerrière (ANNEXE §5). Les curseurs de silhouette pilotent
## des blend shapes du corps ET de chaque pièce de tenue : c'est la seule
## façon de garder les animations Mixamo intactes.
##
## Les noms de shape keys sont la référence unique ; ils sont aussi listés
## dans `docs/SHAPE_KEYS_BLENDER.md` pour le modeleur.

## Shape keys à créer dans Blender (nom -> plage utile).
const SHAPE_KEYS := {
	"shoulders": "Carrure des épaules et de la poitrine (0 à 1)",
	"muscle": "Musculature des bras et des jambes (0 à 1)",
	"hips": "Largeur du bassin (0 à 1)",
	"slim": "Silhouette fine (0 à 1)",
}

@export_range(0.0, 1.0) var height: float = 0.5
@export_range(0.0, 1.0) var shoulders: float = 0.5
@export_range(0.0, 1.0) var muscle: float = 0.5
@export_range(0.0, 1.0) var hips: float = 0.5
@export_range(0.0, 1.0) var slim: float = 0.0
@export var posture: int = 0                 ## 0 droite, 1 fière, 2 souple
@export var hairstyle_id: String = "braids_01"
@export var face_paint_id: String = "none"
@export var skin_tone: Color = Color("#8A5A3C")
@export var outfit_id: String = "default"
@export var primary_color: Color = Color("#B3261E")
@export var secondary_color: Color = Color("#1F2A5C")
@export var accent_color: Color = Color("#E3A92B")
@export var banner_id: String = "applique_01"
@export var title_id: String = ""


## Applique les curseurs sur un corps qui possède les blend shapes.
## `root` reçoit l'échelle globale (hauteur), jamais le squelette.
func apply_to(body: MeshInstance3D, root: Node3D) -> void:
	if body != null:
		_set_shape(body, "shoulders", shoulders)
		_set_shape(body, "muscle", muscle)
		_set_shape(body, "hips", hips)
		_set_shape(body, "slim", slim)
	if root != null:
		root.scale = Vector3.ONE * lerpf(0.94, 1.08, clampf(height, 0.0, 1.0))


## Applique la silhouette à une pièce de tenue : mêmes blend shapes, mêmes
## valeurs, sinon l'armure ne suit pas le corps (§5.1).
func apply_to_piece(piece: MeshInstance3D) -> void:
	if piece == null:
		return
	for shape_name in SHAPE_KEYS:
		_set_shape(piece, shape_name, float(get(shape_name)))


func _set_shape(body: MeshInstance3D, shape_name: String, value: float) -> void:
	var index := body.find_blend_shape_by_name(shape_name)
	if index >= 0:
		body.set_blend_shape_value(index, clampf(value, 0.0, 1.0))


## Échelle réelle de la racine pour le curseur de taille.
func height_scale() -> float:
	return lerpf(0.94, 1.08, clampf(height, 0.0, 1.0))


## Sérialisation pour SaveManager.data["look"].
func to_dict() -> Dictionary:
	return {
		"height": height, "shoulders": shoulders, "muscle": muscle,
		"hips": hips, "slim": slim, "posture": posture,
		"hairstyle_id": hairstyle_id, "face_paint_id": face_paint_id,
		"skin_tone": skin_tone.to_html(), "outfit_id": outfit_id,
		"primary_color": primary_color.to_html(),
		"secondary_color": secondary_color.to_html(),
		"accent_color": accent_color.to_html(),
		"banner_id": banner_id, "title_id": title_id,
	}


static func from_dict(source: Dictionary) -> CharacterLook:
	var look := CharacterLook.new()
	if source.is_empty():
		return look
	look.height = clampf(float(source.get("height", look.height)), 0.0, 1.0)
	look.shoulders = clampf(float(source.get("shoulders", look.shoulders)), 0.0, 1.0)
	look.muscle = clampf(float(source.get("muscle", look.muscle)), 0.0, 1.0)
	look.hips = clampf(float(source.get("hips", look.hips)), 0.0, 1.0)
	look.slim = clampf(float(source.get("slim", look.slim)), 0.0, 1.0)
	look.posture = clampi(int(source.get("posture", look.posture)), 0, 2)
	look.hairstyle_id = str(source.get("hairstyle_id", look.hairstyle_id))
	look.face_paint_id = str(source.get("face_paint_id", look.face_paint_id))
	look.outfit_id = str(source.get("outfit_id", look.outfit_id))
	look.banner_id = str(source.get("banner_id", look.banner_id))
	look.title_id = str(source.get("title_id", look.title_id))
	for key in ["skin_tone", "primary_color", "secondary_color", "accent_color"]:
		if source.has(key):
			look.set(key, Color(str(source[key])))
	return look
