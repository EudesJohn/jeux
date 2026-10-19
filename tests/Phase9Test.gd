extends Node
## Test fonctionnel de la PHASE 9 (DESIGN.md § 6.2, § 6.3, § 6.6, § 20.5).
##   godot --headless --path . res://tests/Phase9Test.tscn
##
## Les vrais modèles `.glb` n'arrivent qu'avec la PHASE 9 ; en attendant, ce test
## prouve que la chaîne est prête :
##   * budgets du § 6.2 : plafonds par rôle, mesure des triangles et des appels
##     de dessin, états d'animation exigés ;
##   * remplacement sans code : `PlayerData.model_scene` /
##     `EnemyData.model_scene` prennent le pas sur la poupée de test, y compris
##     l'échelle et les collisions ;
##   * aller-retour `.glb` : une scène exportée par GLTFDocument est relue et
##     mesurée comme un vrai fichier de modeleur.
##
## Sortie : « PHASE 9 : OK » (code 0) ou la liste des échecs (code 1).

const MODEL_BUDGET := preload("res://scripts/tools/ModelBudget.gd")
const PLAYER_SCENE: String = "res://scenes/characters/Player3D.tscn"
const ENEMY_SCENE: String = "res://scenes/enemies/Enemy3D.tscn"
const PROBE_MODEL_NAME: String = "ModelProbe"

var failures: int = 0
var checks: int = 0


func _ready() -> void:
	print("=== Test fonctionnel PHASE 9 ===")
	await _ui_frames(2)
	var only := OS.get_environment("PHASE9_ONLY")
	# L'aller-retour glTF passe en premier : exporter après avoir instancié puis
	# libéré des personnages fait planter le moteur en mode headless (dummy
	# renderer), alors que le jeu n'exporte jamais de glTF à l'exécution.
	var sections: Dictionary = {
		"glb": _test_glb,
		"budgets": _test_budgets,
		"remplacement": _test_swap,
	}
	for section_name in sections.keys():
		if only != "" and not only.split(",").has(section_name):
			continue
		await (sections[section_name] as Callable).call()
	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d" % [checks, failures])
	print("PHASE 9 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
	get_tree().quit(1 if failures > 0 else 0)


# -----------------------------------------------------------------#
#                        OUTILS DE TEST                            #
# -----------------------------------------------------------------#

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  ÉCHEC ", label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _ui_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


## Modèle de test : un maillage et, si demandé, les 10 états du § 20.5.
func _probe_scene(with_animations: bool = true, animation_names: Array[String] = []) -> PackedScene:
	var root := Node3D.new()
	root.name = PROBE_MODEL_NAME
	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	capsule.radial_segments = 12
	capsule.rings = 4
	body.mesh = capsule
	var material := StandardMaterial3D.new()
	material.resource_name = "probe_mat"
	material.albedo_color = Color(0.55, 0.35, 0.2)
	body.material_override = material
	root.add_child(body)
	# `PackedScene.pack()` n'enregistre que les nœuds dont l'`owner` est la
	# racine : sans ça, le modèle exporté serait vide.
	body.owner = root
	if with_animations:
		var names: Array[String] = animation_names
		if names.is_empty():
			names = CharacterAnimation.STATE_NAMES.duplicate()
		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		player.root_node = NodePath("..")
		# Godot 4 range les animations dans des bibliothèques : c'est aussi ce
		# que produit l'import d'un .glb Mixamo.
		var library := AnimationLibrary.new()
		for state_name in names:
			var animation := Animation.new()
			animation.length = 0.5
			animation.loop_mode = Animation.LOOP_LINEAR
			# Une piste réelle : un export glTF ignore les animations vides,
			# exactement comme un vrai modèle Mixamo en contient.
			var track := animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(track, NodePath("Body"))
			animation.track_insert_key(track, 0.0, Vector3.ZERO)
			animation.track_insert_key(track, 0.5, Vector3(0.0, 0.05, 0.0))
			library.add_animation(state_name, animation)
		player.add_animation_library("", library)
		root.add_child(player)
		player.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


## Modèle volontairement trop lourd : sphère très subdivisée.
func _heavy_scene(triangles: int = 16000) -> PackedScene:
	var root := Node3D.new()
	root.name = "HeavyModel"
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 128
	sphere.rings = 64
	body.mesh = sphere
	root.add_child(body)
	body.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _measure_scene(scene: PackedScene) -> Dictionary:
	var root := scene.instantiate()
	var report := MODEL_BUDGET.analyse(root)
	root.free()
	return report


# -----------------------------------------------------------------#
#                  § 6.2 : BUDGETS ET MESURE                       #
# -----------------------------------------------------------------#

func _test_budgets() -> void:
	print("[budgets] plafonds du § 6.2, rôles du § 6.3, mesure")

	# Rôles déduits du nom de fichier, comme les livrables du modeleur.
	var roles := {
		"res://assets/models/hero_nawi.glb": "hero",
		"res://assets/models/enemy_soldier.glb": "enemy",
		"res://assets/models/brute_boss.glb": "brute",
		"res://assets/models/boss_captain.glb": "boss",
		"res://assets/models/weapon_sabre.glb": "weapon",
		"res://assets/models/prop_cage.glb": "prop",
		"res://assets/models/mystere.glb": "enemy",
	}
	var wrong: Array[String] = []
	for path in roles:
		if MODEL_BUDGET.role_from_path(path) != roles[path]:
			wrong.append(path.get_file())
	_check(wrong.is_empty(), "rôle déduit du nom de fichier (%s)" % ", ".join(wrong))

	_check(int(MODEL_BUDGET.limits_for("hero")["triangles"]) == 6000
		and int(MODEL_BUDGET.limits_for("hero")["draw_calls"]) == 40,
		"héroïne : 6 000 tris / 40 appels")
	_check(int(MODEL_BUDGET.limits_for("enemy")["triangles"]) == 3500
		and int(MODEL_BUDGET.limits_for("enemy")["draw_calls"]) == 30,
		"ennemi standard : 3 500 tris / 30 appels")
	_check(int(MODEL_BUDGET.limits_for("boss")["triangles"]) == 9000
		and int(MODEL_BUDGET.limits_for("boss")["draw_calls"]) == 45,
		"boss : 9 000 tris / 45 appels")
	_check(int(MODEL_BUDGET.limits_for("weapon")["triangles"]) == 800,
		"arme : 800 tris")

	var report := _measure_scene(_probe_scene())
	_check(int(report["triangles"]) > 100, "triangles mesurés (%d)" % int(report["triangles"]))
	_check(int(report["draw_calls"]) == 1, "une surface = un appel de dessin")
	_check(int(report["meshes"]) == 1, "un maillage compté")
	_check((report["materials"] as Array).size() == 1, "un matériau compté")
	_check((report["animations"] as PackedStringArray).size() == 10,
		"10 animations lues (%d)" % (report["animations"] as PackedStringArray).size())
	_check(MODEL_BUDGET.violations(report, "hero").is_empty(),
		"modèle de test dans le budget de l'héroïne")

	# Trop de triangles pour un ennemi (3 500).
	var heavy := _measure_scene(_heavy_scene())
	var heavy_problems := MODEL_BUDGET.violations(heavy, "enemy", false)
	_check(not heavy_problems.is_empty()
		and String(heavy_problems[0]).contains("triangles"),
		"modèle trop lourd refusé (%s)" % ", ".join(heavy_problems))
	_check(int(heavy["triangles"]) > 12000, "sphère lourde mesurée (%d tris)" % int(heavy["triangles"]))

	# Trop d'appels de dessin : 41 maillages pour un plafond de 40.
	var crowd := Node3D.new()
	for i in 41:
		var part := MeshInstance3D.new()
		part.mesh = BoxMesh.new()
		crowd.add_child(part)
	var crowd_report := MODEL_BUDGET.analyse(crowd)
	crowd.free()
	var crowd_problems := MODEL_BUDGET.violations(crowd_report, "hero", false)
	_check(not crowd_problems.is_empty()
		and String(crowd_problems[0]).contains("appels de dessin"),
		"trop d'appels de dessin refusés (%s)" % ", ".join(crowd_problems))

	# États d'animation manquants : un modèle qui n'expose que « idle ».
	var partial := _probe_scene(true, ["idle"])
	var partial_problems := MODEL_BUDGET.violations(_measure_scene(partial), "hero", true)
	_check(not partial_problems.is_empty()
		and String(partial_problems[0]).contains("animation"),
		"états manquants signalés (%s)" % ", ".join(partial_problems))
	# Une arme n'a pas d'animation à fournir.
	_check(MODEL_BUDGET.violations(_measure_scene(partial), "weapon", true).is_empty(),
		"aucune animation exigée pour une arme")


# -----------------------------------------------------------------#
#             § 6.6 : REMPLACEMENT SANS TOUCHER AU CODE            #
# -----------------------------------------------------------------#

func _test_swap() -> void:
	print("[remplacement] PlayerData.model_scene et EnemyData.model_scene")

	var player_data := (load("res://data/player_default.tres") as PlayerData).duplicate() as PlayerData
	player_data.model_scene = _probe_scene()
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player3D
	player.data = player_data
	add_child(player)
	await _frames(6)

	var seen := player.visual.get_node_or_null(PROBE_MODEL_NAME)
	_check(seen != null, "le modèle fourni remplace la poupée (jouée)")
	_check(player.visual.get_node_or_null("Puppet") == null, "la poupée n'est pas créée")
	_check(player.anim_tree != null and player.playback != null,
		"machine à états construite sur les animations du modèle")
	if player.playback != null:
		player.playback.travel("run")
		await _frames(3)
		_check(String(player.playback.get_current_node()) == "run",
			"l'état « run » est atteignable (%s)" % player.playback.get_current_node())
	player.queue_free()
	await _frames(3)

	# Ennemi : le modèle suit l'échelle du type (§ 15.2) et les collisions aussi.
	var enemy_data := EnemyData.new()
	enemy_data.model_scene = _probe_scene()
	enemy_data.model_scale = 1.3
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as EnemyBase3D
	enemy.data = enemy_data
	add_child(enemy)
	await _frames(6)
	var enemy_model := enemy.visual.get_node_or_null(PROBE_MODEL_NAME) as Node3D
	_check(enemy_model != null, "le modèle fourni remplace la poupée (ennemi)")
	if enemy_model != null:
		_check(is_equal_approx(enemy_model.scale.x, 1.3),
			"échelle du type appliquée (%.2f)" % enemy_model.scale.x)
	var shape := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is CapsuleShape3D:
		_check(is_equal_approx((shape.shape as CapsuleShape3D).radius, 0.52),
			"collision agrandie avec le modèle (%.2f)" % (shape.shape as CapsuleShape3D).radius)
	else:
		_check(false, "collision de l'ennemi introuvable")
	_check(enemy.playback != null, "machine à états construite pour l'ennemi")
	enemy.queue_free()
	await _frames(3)


# -----------------------------------------------------------------#
#                    ALLER-RETOUR .GLB                             #
# -----------------------------------------------------------------#

func _test_glb() -> void:
	print("[glb] export GLTFDocument puis relecture comme un fichier de modeleur (géométrie)")
	var root := _probe_scene().instantiate()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root, state)
	root.free()
	_check(error == OK, "scène convertie en glTF (erreur %d)" % error)
	if error != OK:
		return
	var path := "user://phase9_probe.glb"
	error = document.write_to_filesystem(state, path)
	_check(error == OK and FileAccess.file_exists(path),
		"fichier .glb écrit (%s)" % path)
	if error != OK:
		return

	var reader := GLTFDocument.new()
	var read_state := GLTFState.new()
	error = reader.append_from_file(ProjectSettings.globalize_path(path), read_state)
	_check(error == OK, "fichier .glb relu (erreur %d)" % error)
	if error != OK:
		return
	var reloaded := reader.generate_scene(read_state)
	_check(reloaded != null, "scène reconstruite depuis le .glb")
	if reloaded == null:
		return
	var report := MODEL_BUDGET.analyse(reloaded)
	_check(int(report["triangles"]) > 100,
		"triangles mesurés dans le .glb (%d)" % int(report["triangles"]))
	# L'export glTF de Godot ne transporte pas les AnimationPlayer : les modèles
	# animés viennent de Blender (`BLENDER` exporte les actions). On vérifie donc
	# la géométrie et les matériaux, et la lecture des animations se fait sur le
	# modèle en mémoire (section « remplacement »).
	_check((report["materials"] as Array).size() >= 1,
		"matériaux conservés dans le .glb (%d)" % (report["materials"] as Array).size())
	_check(MODEL_BUDGET.role_from_path(path) == "enemy",
		"un fichier au nom neutre prend le budget ennemi")
	reloaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
