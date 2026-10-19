extends Node
## Test fonctionnel de l'ANNEXE PHASE 8B :
##   godot --headless --path . res://tests/Phase8BTest.tscn
##
## Vérifie sur les artefacts réels :
##   * les 4 paliers .tres et leurs multiplicateurs (§7.1) ;
##   * le choix par partie, la persistance et le retour à l'ancien réglage ;
##   * le code des couleurs blanc / jaune / rouge (§7.2) ;
##   * les règles de potions, checkpoints et affixes d'élites.
##
## Sortie : « PHASE 8B : OK » (code 0) ou la liste des échecs (code 1).

class DummyTarget extends Node:
	var last_info: DamageInfo = null
	func on_hit_received(info: DamageInfo) -> int:
		last_info = info
		return Hurtbox3D.Result.HIT


var failures: int = 0
var checks: int = 0
var save_data: Dictionary = {}
var saved_tier: String = ""


func _ready() -> void:
	print("=== Test fonctionnel PHASE 8B ===")
	save_data = SaveManager.data.duplicate(true)
	saved_tier = Settings.tier
	_test_tiers()
	_test_state()
	_test_colors()
	_test_elites()
	await _test_elite_spawn()
	await _test_settings_panel()
	await _test_defeat_screen()
	await _test_hitbox_payload()

	SaveManager.data = save_data
	SaveManager.save_game()
	Settings.tier = saved_tier
	if saved_tier != "":
		GameState.use_tier(saved_tier)
	else:
		GameState.clear_tier()
	Settings.difficulty = str(save_data.get("settings", {}).get("difficulty", "normal"))
	GameState.difficulty = Settings.difficulty
	GameState.last_hit_danger = 0
	GameState.last_hit_source = ""
	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d" % [checks, failures])
	print("PHASE 8B : %s" % ("OK" if failures == 0 else "ÉCHECS"))
	get_tree().quit(1 if failures > 0 else 0)


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


func _test_tiers() -> void:
	print("- Paliers (§7.1, §7.6)")
	_check(DifficultyTier.ORDER == ["recit", "guerriere", "legende", "eternelle"],
		"ordre des quatre paliers")
	var all := DifficultyTier.all_tiers()
	_check(all.size() == 4, "quatre fiches chargées")
	for tier in all:
		_check(DifficultyTier.load_tier(tier.id) != null, "palier %s relu" % tier.id)
	_check(DifficultyTier.load_tier("inconnu") == null, "palier inconnu refusé")

	var recit := DifficultyTier.load_tier("recit")
	var guerriere := DifficultyTier.load_tier("guerriere")
	var legende := DifficultyTier.load_tier("legende")
	var eternelle := DifficultyTier.load_tier("eternelle")

	_check(is_equal_approx(recit.enemy_health_mult, 0.7), "Récit : vie ×0,7")
	_check(recit.checkpoints_in_boss, "Récit : checkpoints en boss")
	_check(not legende.checkpoints_in_boss, "Légende : aucun checkpoint en boss")
	_check(is_equal_approx(guerriere.enemy_health_mult, 1.0), "Guerrière : vie ×1,0")
	_check(is_equal_approx(legende.enemy_health_mult, 1.6), "Légende : vie ×1,6")
	_check(is_equal_approx(legende.enemy_damage_mult, 1.5), "Légende : dégâts ×1,5")
	_check(legende.max_potions == 3, "Légende : 3 potions")
	_check(legende.boss_phase_count == 4, "Légende : boss à 4 phases")
	_check(is_equal_approx(legende.elite_chance, 0.25), "Légende : élites à 25 %")
	_check(is_equal_approx(eternelle.enemy_health_mult, 2.2), "Éternelle : vie ×2,2")
	_check(is_equal_approx(eternelle.enemy_damage_mult, 2.0), "Éternelle : dégâts ×2,0")
	_check(eternelle.one_life_per_chapter, "Éternelle : une vie par chapitre")
	_check(eternelle.max_potions == 1, "Éternelle : 1 potion")
	_check(eternelle.boss_phase_count == 5, "Éternelle : boss à 5 phases")
	_check(eternelle.max_elite_affixes == 2, "Éternelle : 2 affixes par élite")
	_check(recit.frame_color != eternelle.frame_color, "couleurs de cadre distinctes")


func _test_state() -> void:
	print("- Choix par partie et persistance")
	_check(GameState.use_tier("legende"), "palier Légende chargé")
	_check(GameState.tier_id() == "legende", "identifiant du palier")
	_check(is_equal_approx(GameState.difficulty_health_mult(), 1.6), "multiplicateur de vie actif")
	_check(is_equal_approx(GameState.difficulty_damage_mult(), 1.5), "multiplicateur de dégâts actif")
	_check(GameState.max_potions() == 3, "potions du palier")
	_check(not GameState.checkpoints_in_boss(), "checkpoint en boss interdit")
	_check(GameState.boss_phase_count() == 4, "phases de boss du palier")
	_check(GameState.difficulty == "hard", "ancienne difficulté alignée sur Légende")

	Settings.set_tier("eternelle")
	_check(Settings.tier == "eternelle" and GameState.tier_id() == "eternelle",
		"palier persistant choisi")
	_check(GameState.one_life_per_chapter(), "une vie par chapitre")
	_check(GameState.max_elite_affixes() == 2, "deux affixes d'élite")
	_check(str(SaveManager.data.get("settings", {}).get("tier", "")) == "eternelle",
		"palier sauvegardé")

	_check(not Settings.set_tier("difficile"), "palier inconnu refusé")
	_check(GameState.tier_id() == "eternelle", "palier inchangé après refus")

	# L'ancien réglage à trois valeurs reprend la main sans palier.
	Settings.set_difficulty("easy")
	_check(GameState.tier == null and Settings.tier == "", "Facile efface le palier")
	_check(is_equal_approx(GameState.difficulty_health_mult(), 0.7),
		"retour aux multiplicateurs historiques")
	Settings.set_tier("legende")
	Settings.set_tier("")
	_check(GameState.tier == null and GameState.difficulty == "easy",
		"« Aucun (historique) » restaure Facile, pas Normal")
	Settings.set_difficulty("normal")
	_check(GameState.use_tier("recit"), "Récit rechargé")
	_check(GameState.checkpoints_in_boss(), "Récit autorise les checkpoints en boss")
	GameState.clear_tier()
	_check(GameState.tier_id() == "", "palier retiré")
	_check(is_equal_approx(GameState.difficulty_health_mult(), 1.0), "retour à ×1,0")


func _test_colors() -> void:
	print("- Code des couleurs (§7.2)")
	_check(Hitbox3D.DANGER_NAMES.size() == 3, "trois couleurs")
	_check(Hitbox3D.DANGER_COLORS[0] != Hitbox3D.DANGER_COLORS[1]
		and Hitbox3D.DANGER_COLORS[1] != Hitbox3D.DANGER_COLORS[2],
		"couleurs distinctes")
	_check(Hitbox3D.danger_from_name("white") == Hitbox3D.Danger.WHITE, "blanc reconnu")
	_check(Hitbox3D.danger_from_name("yellow") == Hitbox3D.Danger.YELLOW, "jaune reconnu")
	_check(Hitbox3D.danger_from_name("red") == Hitbox3D.Danger.RED, "rouge reconnu")
	_check(Hitbox3D.danger_from_name("rouge") == Hitbox3D.Danger.RED, "nom français accepté")
	_check(Hitbox3D.danger_from_name("inconnu") == Hitbox3D.Danger.WHITE, "défaut blanc")
	var fresh_hitbox := Hitbox3D.new()
	_check(fresh_hitbox.danger == Hitbox3D.Danger.WHITE, "Hitbox par défaut : blanc")
	fresh_hitbox.free()

	var white_advice := DifficultyTier.advice_for(Hitbox3D.Danger.WHITE)
	var yellow_advice := DifficultyTier.advice_for(Hitbox3D.Danger.YELLOW)
	var red_advice := DifficultyTier.advice_for(Hitbox3D.Danger.RED)
	_check(white_advice != yellow_advice and yellow_advice != red_advice,
		"un conseil différent par couleur")
	_check(red_advice.to_lower().contains("esquive"), "le conseil rouge parle d'esquive")

	GameState.register_player_hit(Hitbox3D.Danger.RED, "Général")
	_check(GameState.last_hit_danger == Hitbox3D.Danger.RED, "coup mémorisé")
	_check(GameState.last_hit_source == "Général", "source mémorisée")
	_check(GameState.hit_advice() == red_advice, "conseil de mort cohérent")

	var enemy_data := load("res://data/enemies/archer.tres") as EnemyData
	_check(enemy_data != null and enemy_data.attack_danger == "white",
		"les ennemis existants restent en blanc")
	enemy_data.attack_danger = "red"
	_check(Hitbox3D.danger_from_name(enemy_data.attack_danger) == Hitbox3D.Danger.RED,
		"une fiche peut passer en rouge")
	enemy_data.attack_danger = "white"


func _test_elites() -> void:
	print("- Affixes d'élite (§7.3)")
	_check(EliteAffix.IDS.size() == 7, "7 affixes d'élite")
	for id in EliteAffix.IDS:
		_check(EliteAffix.is_known(id), "affixe connu : %s" % id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var rolled := EliteAffix.roll(2, rng)
	_check(rolled.size() == 2 and rolled[0] != rolled[1], "deux affixes distincts")
	_check(EliteAffix.roll(0, rng).is_empty(), "aucun affixe à 0")
	_check(is_equal_approx(EliteAffix.damage_taken_mult(["blinde"], false), 0.6),
		"Blindé : −40 % de dégâts")
	_check(is_equal_approx(EliteAffix.damage_taken_mult(["blinde"], true), 1.0),
		"Blindé annulé par l'étourdissement")
	_check(is_equal_approx(EliteAffix.speed_mult(["rapide"], 1.0), 1.4), "Rapide : +40 %")
	_check(is_equal_approx(EliteAffix.speed_mult(["enrage"], 0.8), 1.0),
		"Enragé : pas encore actif au-dessus de 50 %")
	_check(is_equal_approx(EliteAffix.speed_mult(["enrage"], 0.4), 1.5),
		"Enragé : +50 % sous 50 % de vie")
	_check(is_equal_approx(EliteAffix.speed_mult(["rapide", "enrage"], 0.4), 2.1),
		"Rapide et Enragé se cumulent")
	_check(is_equal_approx(EliteAffix.lifesteal(["vampire"]), 0.25), "Vampire : 25 %")
	_check(EliteAffix.explodes(["explosif"]), "Explosif explose")
	_check(int(EliteAffix.explosion(["explosif"])["radius"]) == 2, "rayon d'explosion")
	_check(EliteAffix.explosion(["rapide"]).is_empty(), "pas d'explosion sans affixe")
	_check(is_equal_approx(EliteAffix.summon_period(["invocateur"]), 10.0),
		"Invocateur : toutes les 10 s")
	_check(EliteAffix.shield_charges(["bouclier"]) == 1, "Bouclier : une charge")


func _test_elite_spawn() -> void:
	print("- Apparition réelle d'un élite")
	GameState.use_tier("eternelle")
	var tier := GameState.tier
	tier.elite_chance = 1.0
	tier.max_elite_affixes = 2
	var container := Node3D.new()
	add_child(container)
	var scene := load("res://scenes/enemies/Enemy3D.tscn") as PackedScene
	var enemy := scene.instantiate() as EnemyBase3D
	container.add_child(enemy)
	await _frames(3)
	_check(enemy.elite_affixes.size() == 2, "deux affixes sur l'ennemi créé")
	var base_health := EnemyRegistry.get_data("soldier").health
	_check(is_equal_approx(enemy.max_health, base_health * 2.2 * 1.35),
		"vie d'élite = palier × 1,35")
	_check(enemy.is_in_group("elites"), "l'ennemi rejoint le groupe des élites")
	enemy.queue_free()
	container.queue_free()
	await _frames(2)
	tier.elite_chance = 0.45
	tier.max_elite_affixes = 2
	GameState.clear_tier()


func _test_settings_panel() -> void:
	print("- Panneau de réglages")
	var panel := SettingsPanel.new()
	add_child(panel)
	await _frames(2)
	var option := panel.find_child("Palier de défi", true, false) as OptionButton
	_check(option != null, "sélecteur de palier présent")
	if option != null:
		_check(option.item_count == 5, "5 choix (historique + 4 paliers)")
		_check(option.get_item_metadata(0) == "", "premier choix = historique")
		option.select(3)
		option.item_selected.emit(3)
		_check(Settings.tier == "legende", "choisir Légende applique le palier")
		_check(GameState.tier_id() == "legende", "GameState suit le panneau")
	panel.queue_free()
	await _frames(2)


func _test_defeat_screen() -> void:
	print("- Écran de mort (§7.2 règle 8)")
	GameState.register_player_hit(Hitbox3D.Danger.RED, "Général")
	var screen := ResultScreen.new()
	add_child(screen)
	await _frames(2)
	screen.show_defeat("health")
	_check(screen.shown, "écran de défaite affiché")
	var text := screen.detail_text()
	_check(text.contains("Général"), "l'attaque fautive est nommée")
	_check(text.to_lower().contains("esquive"), "le conseil d'esquive est affiché")
	screen.queue_free()
	await _frames(2)


func _test_hitbox_payload() -> void:
	print("- Propagation de la couleur dans DamageInfo")
	var root := Node3D.new()
	root.name = "TestRoot"
	add_child(root)
	var target := DummyTarget.new()
	target.name = "Cible"
	root.add_child(target)
	var hurtbox := Hurtbox3D.new()
	hurtbox.owner_actor = target
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	hurtbox.add_child(shape)
	root.add_child(hurtbox)

	var hitbox := Hitbox3D.new()
	hitbox.damage = 11.0
	hitbox.crit_chance = 0.0
	hitbox.danger = Hitbox3D.Danger.RED
	root.add_child(hitbox)
	await _frames(1)
	hitbox.activate()
	hitbox._on_area_entered(hurtbox)
	_check(target.last_info != null, "le coup atteint la cible")
	if target.last_info != null:
		_check(target.last_info.danger == Hitbox3D.Danger.RED,
			"la couleur rouge arrive dans DamageInfo")
		_check(is_equal_approx(target.last_info.amount, 11.0), "dégâts intacts")
	_check(hitbox.last_danger == Hitbox3D.Danger.RED, "dernière couleur mémorisée")
	hitbox.deactivate()
	root.queue_free()
	await _frames(3)
