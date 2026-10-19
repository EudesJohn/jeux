extends Node
## Test fonctionnel de l'ANNEXE PHASES 6B / 6C / 6D :
##   godot --headless --path . res://tests/Phase6BTest.tscn
##
## Vérifie sur les artefacts réels :
##   * les 8 armes jouables (+ 3 armes de boss) se chargent depuis .tres ;
##   * les raretés, le tirage d'affixes et le coût 60 × niveau^1,5 ;
##   * l'inventaire : obtention, équipement, amélioration, maîtrise ;
##   * les formules de niveau, de vie et de dégâts du §4 ;
##   * CharacterLook : silhouette, sérialisation, tenues.
##
## Sortie : « PHASE 6B : OK » (code 0) ou la liste des échecs (code 1).

const PLAYABLE: Array[String] = [
	"sabre", "machette", "sabres_jumeaux", "epee_bouclier",
	"lance", "massue", "arc_court", "fusil_pierre",
]

var failures: int = 0
var checks: int = 0
var save_data: Dictionary = {}


func _ready() -> void:
	print("=== Test fonctionnel PHASE 6B / 6C / 6D ===")
	save_data = SaveManager.data.duplicate(true)
	_test_weapons()
	_test_affixes()
	_test_inventory()
	_test_progression()
	_test_skills_and_gear()
	_test_look()

	SaveManager.data = save_data
	SaveManager.save_game()
	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d" % [checks, failures])
	print("PHASE 6B : %s" % ("OK" if failures == 0 else "ÉCHECS"))
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  ÉCHEC ", label)


func _test_weapons() -> void:
	print("- Fiches d'armes (§3.2, §8)")
	for id in PLAYABLE:
		var weapon := WeaponSystem.load_weapon(id)
		_check(weapon != null and weapon.id == id, "arme jouable chargée : %s" % id)
	_check(WeaponSystem.all_weapons().size() == 11, "11 fiches .tres au total")
	_check(WeaponSystem.exists("gubasa_ancetres") and not WeaponSystem.exists("inconnue"),
		"exists() distingue une fiche réelle")

	var sabre := WeaponSystem.load_weapon("sabre")
	var mythic := WeaponSystem.load_weapon("masse_colosse")
	_check(is_equal_approx(sabre.rarity_mult(), 1.0), "commune ×1,00")
	_check(is_equal_approx(mythic.rarity_mult(), 2.0), "mythique ×2,00")
	_check(sabre.rarity_name() == "Commune", "nom de rareté lisible")
	_check(sabre.rarity_color() != mythic.rarity_color(), "couleurs de rareté distinctes")

	# §4.3 / §8 : 10 × 1,00 × (1 + 0,08 × 1) = 10,8 au niveau 1.
	_check(is_equal_approx(sabre.damage_at(1), 10.8), "dégâts niveau 1 = 10,8")
	_check(is_equal_approx(sabre.damage_at(10), 18.0), "dégâts niveau 10 = 18,0")
	_check(is_equal_approx(sabre.damage_at(1, 0.10), 11.88), "bonus additif appliqué")
	_check(is_equal_approx(sabre.dps_at(1), 10.8), "DPS = dégâts × vitesse")
	_check(WeaponSystem.load_weapon("arc_court").is_ranged, "arc court à distance")
	_check(WeaponSystem.load_weapon("fusil_pierre").is_ranged, "fusil à distance")
	_check(WeaponSystem.load_weapon("lame_legendaire").rune_slots == 2,
		"deux emplacements de runes sur une légendaire")


func _test_affixes() -> void:
	print("- Affixes et amélioration (§3.1, §3.3, §3.4)")
	_check(AffixData.IDS.size() == 10, "10 affixes au catalogue")
	for id in AffixData.IDS:
		_check(AffixData.is_known(id), "affixe connu : %s" % id)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var rolled := AffixData.roll(3, rng)
	_check(rolled.size() == 3, "trois affixes tirés")
	_check(rolled[0] != rolled[1] and rolled[1] != rolled[2] and rolled[0] != rolled[2],
		"tirages distincts")

	var rare := WeaponSystem.load_weapon("fusil_pierre")
	var epic := WeaponSystem.load_weapon("massue")
	_check(WeaponSystem.affixes_for(rare, rng).size() == 1, "rare : 1 affixe")
	_check(epic.affix_count() == 0, "commune : 0 affixe")
	_check(WeaponSystem.load_weapon("sabres_jumeaux").affix_count() == 1,
		"rareté rare -> 1 affixe")
	_check(WeaponSystem.load_weapon("lame_legendaire").affix_count() == 3,
		"légendaire -> 3 affixes")
	_check(mythic_affixes() == 3, "mythique -> 3 affixes")

	var bonus := AffixData.damage_bonus(["tranchant", "tranchant"])
	_check(is_equal_approx(bonus, 0.20), "deux fois Tranchant = +20 %")
	_check(is_equal_approx(AffixData.stat_bonus(["critique", "rapide"], "crit"), 0.08),
		"stat_bonus lit la bonne statistique")

	_check(WeaponSystem.upgrade_cost(1) == 60, "niveau 1 -> 2 : 60 cauris")
	_check(WeaponSystem.upgrade_cost(2) == 170, "niveau 2 -> 3 : 170 cauris")
	_check(WeaponSystem.upgrade_cost(5) == 671, "niveau 5 -> 6 : 671 cauris")
	_check(WeaponSystem.upgrade_cost(9) == 1620, "niveau 9 -> 10 : 1620 cauris")
	_check(WeaponSystem.upgrade_cost(10) == -1, "niveau 10 : maximum")
	_check(WeaponSystem.is_ascension_level(5) and WeaponSystem.is_ascension_level(10),
		"ascensions à 5 et 10")
	_check(not WeaponSystem.is_ascension_level(6), "pas d'ascension au niveau 6")
	_check(WeaponSystem.mastery_after_hits(250) == 2, "250 coups -> maîtrise 2")
	_check(WeaponSystem.mastery_after_hits(99999) == 20, "maîtrise plafonnée à 20")
	_check(not WeaponSystem.combo_unlocked(4, 4) and WeaponSystem.combo_unlocked(5, 4),
		"combo de 4 coups à maîtrise 5")
	_check(not WeaponSystem.combo_unlocked(11, 5) and WeaponSystem.combo_unlocked(12, 5),
		"combo de 5 coups à maîtrise 12")


func mythic_affixes() -> int:
	return WeaponSystem.load_weapon("gubasa_ancetres").affix_count()


func _test_inventory() -> void:
	print("- Inventaire et sauvegarde (§3.4)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	SaveManager.data["cauris"] = 2000
	SaveManager.data["weapons_owned"] = ["sabre"]
	SaveManager.data["weapon_levels"] = {"sabre": 1}
	SaveManager.data["equipped_weapon"] = "sabre"
	SaveManager.data["weapon_affixes"] = {}
	SaveManager.data["weapon_ascensions"] = {}
	SaveManager.data["weapon_mastery"] = {}
	SaveManager.data["weapon_hits"] = {}

	SaveManager.equip_weapon("sabre")
	_check(is_equal_approx(SaveManager.equipped_damage_mult(), 1.0),
		"sabre de départ = ×1,00 (PHASE 2 inchangée)")
	_check(not SaveManager.owns_weapon("lance"), "lance pas encore possédée")
	_check(SaveManager.own_weapon("lance", rng), "obtention de la lance")
	_check(not SaveManager.own_weapon("lance", rng), "pas de doublon")
	_check(not SaveManager.own_weapon("arme_bidon", rng), "arme inconnue refusée")
	_check(SaveManager.weapon_affixes("lance").is_empty(), "commune : aucun affixe")

	_check(SaveManager.own_weapon("fusil_pierre", rng), "obtention du fusil (rare)")
	_check(SaveManager.weapon_affixes("fusil_pierre").size() == 1,
		"un affixe tiré sur le fusil")
	_check(SaveManager.equip_weapon("fusil_pierre"), "équipement du fusil")
	_check(SaveManager.equipped_weapon() == "fusil_pierre", "arme équipée relue")
	_check(not SaveManager.equip_weapon("masse_colosse"), "arme non possédée non équipable")

	var before := int(SaveManager.data["cauris"])
	_check(SaveManager.upgrade_weapon("fusil_pierre"), "amélioration payée")
	_check(SaveManager.weapon_level("fusil_pierre") == 2, "niveau 2 après amélioration")
	_check(int(SaveManager.data["cauris"]) == before - 60, "60 cauris débités")
	SaveManager.data["cauris"] = 0
	_check(not SaveManager.upgrade_weapon("fusil_pierre"), "sans cauris, refus")
	_check(SaveManager.weapon_level("fusil_pierre") == 2, "niveau inchangé après refus")

	SaveManager.data["weapon_levels"]["fusil_pierre"] = 5
	_check(SaveManager.ascend_weapon("fusil_pierre"), "ascension au niveau 5")
	_check(SaveManager.weapon_ascended("fusil_pierre", 5), "ascension enregistrée")
	_check(not SaveManager.ascend_weapon("fusil_pierre"), "pas de double ascension")

	_check(SaveManager.add_weapon_hits("fusil_pierre", 250) == 2, "maîtrise après 250 coups")
	_check(SaveManager.add_weapon_hits("fusil_pierre", 50) == 3, "les coups s'additionnent")
	SaveManager.save_game()
	_check(FileAccess.file_exists(SaveManager.SAVE_PATH), "sauvegarde écrite")


func _test_progression() -> void:
	print("- Progression (§4.1, §4.2, §4.3)")
	_check(Progression.MAX_LEVEL == 60, "niveau maximum 60")
	_check(Progression.xp_to_next(1) == 100, "niveau 1 -> 2 : 100 XP")
	_check(Progression.xp_to_next(2) == 303, "niveau 2 -> 3 : 303 XP")
	_check(Progression.xp_to_next(60) == 0, "aucune XP après 60")
	_check(Progression.level_for_xp(Progression.total_xp_for(10)) == 10,
		"XP cumulée -> niveau 10")
	_check(Progression.total_xp_for(1) == 0, "niveau 1 = 0 XP cumulée")
	_check(Progression.attribute_points_for(10) == 27, "3 points par niveau")
	_check(Progression.skill_points_for(10) == 4, "1 compétence tous les 2 niveaux")

	_check(is_equal_approx(Progression.max_health(0, 1), 104.0), "vie de base 104")
	_check(is_equal_approx(Progression.max_health(10, 20), 260.0), "vie avec Vitalité")
	_check(is_equal_approx(Progression.max_energy(25), 200.0), "énergie avec Esprit")
	_check(is_equal_approx(Progression.force_mult(10), 1.3), "+3 % dégâts par Force")
	_check(is_equal_approx(Progression.agility_mult(10), 1.15), "+1,5 % par Agilité")
	_check(is_equal_approx(Progression.cauris_mult(20), 1.2), "+1 % cauris par Chance")

	var damage := Progression.melee_damage(10.0, 10, 1.0, 1, 0.10)
	_check(is_equal_approx(damage, 15.444), "dégâts §4.3 = base × Force × rareté × niveau × bonus")
	var crit := Progression.melee_damage(10.0, 10, 1.0, 1, 0.10, true)
	_check(is_equal_approx(crit, damage * 1.5), "critique ×1,5")
	_check(is_equal_approx(Progression.crit_chance(0, 0), 0.08), "critique de base 8 %")
	_check(is_equal_approx(Progression.crit_chance(10, 10), 0.17),
		"Agilité et Chance augmentent le critique")
	_check(is_equal_approx(Progression.estimated_dps(10.0, 1.2, 0, 1.0, 1, 0.0, 0, 0),
		10.8 * 1.04 * 1.2), "DPS estimé avec critique moyen")


func _test_skills_and_gear() -> void:
	print("- Arbre de compétences et équipement (§4.4-4.6)")
	var total := 0
	for branch in SkillTree.BRANCHES:
		var skills := SkillTree.branch_skills(branch)
		_check(skills.size() == 5, "5 talents dans la branche %s" % branch)
		total += skills.size()
	_check(total == 15, "15 talents au total")
	_check(SkillTree.max_rank("frappe_lourde") == 3, "3 rangs pour Frappe lourde")
	_check(SkillTree.max_rank("combo_quatre") == 1, "1 rang pour l'enchaînement de quatre")
	_check(SkillTree.cost("frappe_lourde", 0) == 1, "premier rang : 1 point")
	_check(SkillTree.cost("frappe_lourde", 1) == 2, "deuxième rang : 2 points")
	_check(SkillTree.cost("frappe_lourde", 3) == -1, "rang maximum : plus de coût")
	_check(SkillTree.can_learn("frappe_lourde", 0, 1), "apprenable avec 1 point")
	_check(not SkillTree.can_learn("frappe_lourde", 1, 1), "pas assez de points pour le rang 2")
	_check(is_equal_approx(SkillTree.stat_total({"frappe_lourde": 2}, "heavy_damage"), 0.10),
		"deux rangs = +10 % de dégâts lourds")
	_check(SkillTree.has_unlock({"combo_quatre": 1}, "combo_4"), "combo de 4 débloqué")
	_check(not SkillTree.has_unlock({"combo_quatre": 0}, "combo_4"), "rang 0 = pas de déblocage")
	_check(SkillTree.total_spent({"frappe_lourde": 2}) == 3, "coût cumulé de deux rangs")

	_check(GearData.SET_IDS.size() == 6, "6 sets d'armure")
	_check(GearData.TALISMAN_IDS.size() == 4, "4 talismans")
	_check(GearData.set_bonus("recrue", 1).is_empty(), "1 pièce : aucun bonus")
	_check(is_equal_approx(float(GearData.set_bonus("recrue", 2)["health_mult"]), 0.10),
		"2 pièces : +10 % vie")
	var four := GearData.set_bonus("recrue", 4)
	_check(int(four["potion_bonus"]) == 1 and is_equal_approx(float(four["health_mult"]), 0.10),
		"4 pièces : les deux bonus")
	var talismans: Array[String] = ["cauri", "plume"]
	var aggregate := GearData.aggregate("chasseuse", 2, talismans)
	_check(is_equal_approx(float(aggregate["loot_mult"]), 0.20), "Cauri : +20 % butin")
	_check(is_equal_approx(float(aggregate["speed_mult"]), 0.20), "set + plume : +20 % vitesse")
	var four_talismans: Array[String] = ["cauri", "dent_du_lion", "plume", "oeil"]
	var capped := GearData.talisman_bonus(four_talismans)
	_check(not capped.has("perfect_guard_window"), "4e talisman ignoré (3 emplacements)")

	# Progression sauvegardée : niveau, points, attributs, talents.
	SaveManager.data["level"] = 1
	SaveManager.data["xp"] = 0
	SaveManager.data["attribute_points"] = 0
	SaveManager.data["skill_points"] = 0
	SaveManager.data["attributes"] = {}
	SaveManager.data["skill_ranks"] = {}
	_check(SaveManager.add_xp(100) == 1, "100 XP = niveau 2")
	_check(SaveManager.player_level() == 2, "niveau 2 enregistré")
	_check(SaveManager.attribute_points_left() == 3, "3 points d'attribut")
	_check(SaveManager.spend_attribute("force"), "point placé en Force")
	_check(SaveManager.attribute_value("force") == 1, "Force = 1")
	_check(SaveManager.attribute_points_left() == 2, "2 points restants")
	_check(not SaveManager.spend_attribute("magie"), "attribut inconnu refusé")
	_check(SaveManager.add_xp(303) == 1, "303 XP de plus = niveau 3")
	_check(SaveManager.player_level() == 3, "niveau 3")
	_check(SaveManager.skill_points_left() == 1, "1 point de compétence au niveau 3")
	_check(SaveManager.learn_skill("frappe_lourde"), "Frappe lourde apprise")
	_check(SaveManager.skill_rank("frappe_lourde") == 1, "rang 1 enregistré")
	_check(SaveManager.skill_points_left() == 0, "point dépensé")
	_check(not SaveManager.learn_skill("frappe_lourde"), "pas de point pour le rang 2")
	_check(is_equal_approx(SaveManager.skill_stat("heavy_damage"), 0.05),
		"le talent modifie les statistiques")
	_check(is_equal_approx(SaveManager.attribute_crit_bonus(), 0.0), "sans Agilité : pas de critique")


func _test_look() -> void:
	print("- Personnalisation (§5)")
	_check(CharacterLook.SHAPE_KEYS.size() == 4, "quatre shape keys de silhouette")
	_check(CharacterLook.SHAPE_KEYS.has("shoulders") and CharacterLook.SHAPE_KEYS.has("slim"),
		"noms de shape keys documentés")

	var look := CharacterLook.new()
	look.height = 0.0
	_check(is_equal_approx(look.height_scale(), 0.94), "taille minimale -6 %")
	look.height = 1.0
	_check(is_equal_approx(look.height_scale(), 1.08), "taille maximale +8 %")
	look.height = 0.5
	_check(is_equal_approx(look.height_scale(), 1.01), "taille neutre")

	look.shoulders = 0.8
	look.hairstyle_id = "braids_02"
	look.primary_color = Color("#123456")
	var restored := CharacterLook.from_dict(look.to_dict())
	_check(is_equal_approx(restored.shoulders, 0.8), "carrure sérialisée")
	_check(restored.hairstyle_id == "braids_02", "coiffure sérialisée")
	_check(restored.primary_color == Color("#123456"), "couleur sérialisée")
	_check(restored.outfit_id == look.outfit_id, "tenue par défaut conservée")

	# Un mesh sans blend shapes ne doit pas planter l'atelier.
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	add_child(body)
	look.apply_to(body, null)
	look.apply_to_piece(body)
	_check(is_instance_valid(body), "apply_to tolère l'absence de blend shapes")
	body.queue_free()
