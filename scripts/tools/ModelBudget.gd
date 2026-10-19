extends RefCounted
class_name ModelBudget
## Budgets de modèles (DESIGN.md § 6.2 et § 6.3), partagés par l'outil
## `tools/check_model_budgets.gd` et par `tests/Phase9Test.tscn`.
##
## Un modèle est jugé sur ce que le moteur voit vraiment : le nombre de
## triangles de ses maillages, le nombre de surfaces (une surface = un appel de
## dessin) et la présence des 10 états d'animation du § 20.5.
##
## Les budgets dépendent du rôle, déduit du nom de fichier (§ 6.3 :
## `hero_nawi.glb`, `enemy_soldier.glb`, `boss_captain.glb`, `weapon_sabre.glb`).

## Rôle → plafonds du § 6.2. `draw_calls` compte les surfaces, pas les objets :
## deux maillages qui partagent un matériau restent deux appels de dessin.
const BUDGETS := {
	"hero": {"triangles": 6000, "draw_calls": 40},
	"ally": {"triangles": 6000, "draw_calls": 40},
	"enemy": {"triangles": 3500, "draw_calls": 30},
	"brute": {"triangles": 5000, "draw_calls": 35},
	"boss": {"triangles": 9000, "draw_calls": 45},
	# § 6.2 donne « 0 appel de dessin » pour l'arme : elle est fusionnée dans le
	# maillage de l'héroïne. Un `weapon_*.glb` séparé reste une surface, donc on
	# tolère 1 ; au-delà, il faut le fusionner.
	"weapon": {"triangles": 800, "draw_calls": 1},
	# La table ne donne qu'un budget d'arène entière (< 60 000 tris, ≤ 6 appels
	# pour tout le décor) : par objet, on garde une marge volontairement basse.
	"prop": {"triangles": 2000, "draw_calls": 6},
}

## Préfixes de nommage du § 6.3, du plus spécifique au plus général.
const ROLE_PREFIXES := [
	["hero", "hero"],
	["ally", "ally"],
	["brute", "brute"],
	["chief", "brute"],
	["enemy", "enemy"],
	["boss", "boss"],
	["weapon", "weapon"],
	["prop", "prop"],
]


## Rôle d'après le nom de fichier ou de nœud. Un nom inconnu est traité comme
## un personnage standard : c'est le budget le plus courant, donc le plus sûr.
static func role_from_path(path: String) -> String:
	var file_name := path.trim_suffix("/").get_file().to_lower()
	for entry: Array in ROLE_PREFIXES:
		if file_name.begins_with(String(entry[0])):
			return String(entry[1])
	return "enemy"


static func limits_for(role: String) -> Dictionary:
	return BUDGETS.get(role, BUDGETS["enemy"])


## Mesure un modèle (n'importe quel nœud contenant des `MeshInstance3D`).
## Retourne { triangles, draw_calls, materials, meshes, animations }.
static func analyse(root: Node) -> Dictionary:
	var report := {
		"triangles": 0,
		"draw_calls": 0,
		"materials": [],
		"meshes": 0,
		"animations": PackedStringArray(),
	}
	if root == null:
		return report
	var instances := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		instances.append(root)
	for node in instances:
		var instance := node as MeshInstance3D
		var mesh := instance.mesh
		if mesh == null:
			continue
		report["meshes"] = int(report["meshes"]) + 1
		for surface in mesh.get_surface_count():
			report["draw_calls"] = int(report["draw_calls"]) + 1
			report["triangles"] = int(report["triangles"]) + _surface_triangles(mesh, surface)
			var material := instance.get_active_material(surface)
			if material != null:
				var material_name := material.resource_name
				if material_name.is_empty():
					material_name = material.resource_path.get_file()
				if material_name.is_empty():
					material_name = "mat_%d" % material.get_instance_id()
				var materials: Array = report["materials"]
				if not materials.has(material_name):
					materials.append(material_name)
	var player := _find_animation_player(root)
	if player != null:
		report["animations"] = player.get_animation_list()
	return report


## Triangles d'une surface : le nombre d'indices s'il y en a (maillage indexé),
## sinon le nombre de sommets. `get_faces()` est évité : il duplique les
## sommets et gonfle la mesure sur les gros maillages.
static func _surface_triangles(mesh: Mesh, surface: int) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	if arrays.is_empty():
		return 0
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if not indices.is_empty():
		return int(indices.size() / 3)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return int(vertices.size() / 3)


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


## Liste des écarts au budget. Vide = le modèle passe.
## `check_animations` : un personnage doit exposer les 10 états du § 20.5 ;
## une arme ou un décor n'en a pas besoin.
static func violations(report: Dictionary, role: String,
		check_animations: bool = true) -> Array[String]:
	var problems: Array[String] = []
	var limits := limits_for(role)
	var triangles := int(report.get("triangles", 0))
	var draw_calls := int(report.get("draw_calls", 0))
	if triangles > int(limits["triangles"]):
		problems.append("%d triangles (plafond %s : %d)" % [
			triangles, role, int(limits["triangles"])])
	if draw_calls > int(limits["draw_calls"]):
		problems.append("%d appels de dessin (plafond %s : %d)" % [
			draw_calls, role, int(limits["draw_calls"])])
	if check_animations and role in ["hero", "ally", "enemy", "brute", "boss"]:
		var animations: PackedStringArray = report.get("animations", PackedStringArray())
		var missing: Array[String] = []
		for state_name in CharacterAnimation.STATE_NAMES:
			if not animations.has(state_name):
				missing.append(state_name)
		if not missing.is_empty():
			problems.append("états d'animation absents : %s" % ", ".join(missing))
	return problems


## Résumé lisible pour la console.
static func describe(path: String, report: Dictionary, role: String) -> String:
	return "%s [%s] : %d tris, %d appels de dessin, %d maillages, %d matériaux, %d animations" % [
		path.get_file(), role, int(report["triangles"]), int(report["draw_calls"]),
		int(report["meshes"]), (report["materials"] as Array).size(),
		(report["animations"] as PackedStringArray).size()]
