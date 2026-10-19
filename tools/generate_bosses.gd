extends SceneTree
## Générateur des 5 GARDIENS (DESIGN.md § 10 et PHASE 6) :
## `data/bosses/boss_*.tres`. Comme pour les ennemis, tout est dans la fiche :
## le script `BossBase3D` ne décide rien en dur.
##
## Lancer :
##   godot --headless --path . --script res://tools/generate_bosses.gd
##
## Progression voulue (§ 10) : le capitaine apprend le combat de boss (charge
## et sabre), le chef archer ajoute la pluie de flèches, le colosse oblige à
## briser une armure en gardant parfaitement, le sorcier éteint la lumière et
## se téléporte, le général rival enchaîne des combos de 5 coups.

const BOSS_SCRIPT := preload("res://data/resources/BossData.gd")
const DIR: String = "res://data/bosses"

## Un gardien par chapitre, du plus simple au plus dur.
const BOSSES: Array = [
	{
		"id": "captain", "file": "captain", "display_name": "Capitaine des pillards", "chapter": 1,
		"health": 300.0, "damage": 14.0, "speed": 2.6, "attack_range": 2.6,
		"telegraph_time": 0.80, "recover_time": 0.90,
		"attacks": ["charge", "sweep"], "phase_2_attacks": ["charge"], "phase_3_attacks": [],
		"summon_phase": 2, "summon_count": 2,
		"tint": Color(0.62, 0.18, 0.16), "model_scale": 1.8, "drops_cauris": 60,
	},
	{
		"id": "river_archer", "file": "archer", "display_name": "Chef archer du fleuve", "chapter": 2,
		"health": 450.0, "damage": 12.0, "speed": 2.9, "attack_range": 2.2,
		"telegraph_time": 0.70, "recover_time": 0.80,
		"attacks": ["arrows", "sweep"], "phase_2_attacks": ["charge"], "phase_3_attacks": ["arrows"],
		"sweep_radius": 3.2,
		"tint": Color(0.20, 0.42, 0.30), "model_scale": 1.7, "drops_cauris": 80,
	},
	{
		"id": "colossus", "file": "colossus", "display_name": "Colosse blindé", "chapter": 3,
		"health": 700.0, "damage": 20.0, "speed": 2.0, "attack_range": 3.4,
		"telegraph_time": 0.95, "recover_time": 1.10,
		"attacks": ["slam", "sweep"], "phase_2_attacks": ["charge"], "phase_3_attacks": ["slam"],
		"sweep_radius": 4.4, "armor_guards": 3,
		"tint": Color(0.42, 0.40, 0.38), "model_scale": 2.3, "drops_cauris": 100,
	},
	{
		"id": "shadow_sorcerer", "file": "sorcerer", "display_name": "Sorcier des ténèbres", "chapter": 4,
		"health": 850.0, "damage": 16.0, "speed": 2.7, "attack_range": 2.8,
		"telegraph_time": 0.65, "recover_time": 0.85,
		"attacks": ["teleport", "orbs"], "phase_2_attacks": ["arrows"], "phase_3_attacks": ["orbs"],
		"arrow_count": 5, "arrow_radius": 2.0, "darken_arena": true,
		"tint": Color(0.28, 0.16, 0.42), "model_scale": 1.9, "drops_cauris": 120,
	},
	{
		"id": "rival_general", "file": "general", "display_name": "Général rival", "chapter": 5,
		"health": 1100.0, "damage": 22.0, "speed": 3.0, "attack_range": 2.8,
		"telegraph_time": 0.60, "recover_time": 0.70,
		"attacks": ["sweep", "charge"], "phase_2_attacks": ["arrows", "slam"],
		"phase_3_attacks": ["teleport", "orbs"],
		"charge_distance": 14.0, "slam_radius": 5.0, "combo_hits": 5,
		"summon_phase": 2, "summon_count": 2,
		"tint": Color(0.75, 0.12, 0.10), "model_scale": 2.0, "drops_cauris": 150,
	},
]

var written: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for values in BOSSES:
		_write(values)
	print("[generate_bosses] %d gardiens écrits dans %s" % [written, DIR])
	quit()


func _write(values: Dictionary) -> void:
	var data = BOSS_SCRIPT.new()
	for key in values.keys():
		# Les tableaux TYPÉS se construisent explicitement (cf. autres générateurs).
		if key == "file":
			continue
		if key in ["attacks", "phase_2_attacks", "phase_3_attacks"]:
			var list: Array[String] = []
			for attack in values[key]:
				list.append(String(attack))
			data.set(key, list)
		else:
			data.set(key, values[key])
	var path := "%s/boss_%s.tres" % [DIR, String(values["file"])]
	var error := ResourceSaver.save(data, path)
	if error != OK:
		printerr("[generate_bosses] échec d'écriture %s (erreur %d)" % [path, error])
		return
	written += 1
	print("  %s — %s" % [path.get_file(), data.display_name])
