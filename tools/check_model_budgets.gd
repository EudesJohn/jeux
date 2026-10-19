extends SceneTree
## Vérifie les budgets des modèles (DESIGN.md § 6.2, § 6.3, PHASE 9).
##
##     godot --headless --path . --script res://tools/check_model_budgets.gd
##     godot --headless --path . --script res://tools/check_model_budgets.gd -- \
##         --dir=res://assets/models --no-animations
##
## Chaque `.glb` (ou `.gltf`, ou scène `.tscn`) du dossier est mesuré : triangles,
## surfaces (= appels de dessin), matériaux, animations. Le rôle vient du nom de
## fichier (`hero_`, `enemy_`, `boss_`, `weapon_`, `prop_`…) et fixe les plafonds
## du § 6.2. Code de sortie 1 si un modèle dépasse, 0 sinon.
##
## Options :
##   --dir=PATH        dossier à parcourir (défaut : res://assets/models)
##   --file=PATH       un seul fichier (répétable)
##   --no-animations   ne pas exiger les 10 états d'animation
##   --quiet           n'afficher que les problèmes

const DEFAULT_DIR := "res://assets/models"
const EXTENSIONS: Array[String] = ["glb", "gltf", "tscn", "scn"]
## Preload plutôt que le nom global : un outil doit tourner même sur un projet
## qui n'a pas encore été ouvert dans l'éditeur (cache des classes absent).
const Budget := preload("res://scripts/tools/ModelBudget.gd")

var directories: Array[String] = []
var files: Array[String] = []
var check_animations := true
var quiet := false


func _init() -> void:
	_parse_args()
	if directories.is_empty():
		directories.append(DEFAULT_DIR)
	var targets: Array[String] = files.duplicate()
	for directory in directories:
		targets.append_array(_scan(directory))
	if targets.is_empty():
		print("Aucun modèle dans %s (les .glb de la PHASE 9 n'arrivent que plus tard)." % ", ".join(directories))
		quit(0)
		return
	var failed := 0
	var ignored := 0
	for path in targets:
		var report := _measure(path)
		if report.is_empty():
			# Un fichier illisible ne doit pas passer pour un succès : la CI
			# doit Hurler quand un modèle livré ne s'ouvre pas.
			print("  ÉCHEC %s : illisible" % path.get_file())
			failed += 1
			continue
		if int(report["meshes"]) == 0:
			# Scène dont les maillages sont créés dans _ready (poupée de test) :
			# il n'y a rien à mesurer ici, ce n'est pas un modèle importé.
			print("%s : aucun maillage statique, ignoré" % path.get_file())
			ignored += 1
			continue
		var role: String = Budget.role_from_path(path)
		var problems: Array[String] = Budget.violations(report, role, check_animations)
		if not quiet:
			print(Budget.describe(path, report, role))
		if problems.is_empty():
			if not quiet:
				print("    ok")
			continue
		failed += 1
		print("  ÉCHEC %s" % path.get_file())
		for problem in problems:
			print("    - %s" % problem)
	print("Modèles traités : %d, en échec : %d, ignorés : %d" % [
		targets.size(), failed, ignored])
	quit(1 if failed > 0 else 0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else ""
		match key:
			"--dir":
				directories.append(value)
			"--file":
				files.append(value)
			"--no-animations":
				check_animations = false
			"--quiet":
				quiet = true
			_:
				if key.begins_with("--"):
					push_warning("Option inconnue : %s" % key)


## Liste récursive des modèles d'un dossier.
func _scan(path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Dossier introuvable : %s" % path)
		return found
	for file in dir.get_files():
		var clean := file.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension().to_lower() in EXTENSIONS:
			found.append(path.trim_suffix("/") + "/" + clean)
	for sub in dir.get_directories():
		found.append_array(_scan(path.trim_suffix("/") + "/" + sub))
	return found


## Charge et mesure un modèle. Un `.glb` est lu directement (GLTFDocument),
## ce qui marche même sans import préalable ; une scène passe par `load()`.
func _measure(path: String) -> Dictionary:
	var root: Node = null
	var extension := path.get_extension().to_lower()
	var os_path := path
	if path.begins_with("res://") or path.begins_with("user://"):
		os_path = ProjectSettings.globalize_path(path)
	if extension == "glb" or extension == "gltf":
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(os_path, state)
		if error != OK:
			push_error("Lecture impossible : %s (erreur %d)" % [path, error])
			return {}
		root = document.generate_scene(state)
	else:
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("Scène illisible : %s" % path)
			return {}
		root = scene.instantiate()
	if root == null:
		push_error("Modèle vide : %s" % path)
		return {}
	var report: Dictionary = Budget.analyse(root)
	root.free()
	return report
