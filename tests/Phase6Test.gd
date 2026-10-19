extends Node
## Test fonctionnel de la PHASE 6 (DESIGN.md § 10, § 12.3-12.5, § 28) :
##   godot --headless --path . res://tests/Phase6Test.tscn
##
## Validation de la phase :
##   * les 5 gardiens du § 10 (fiches, 3 phases, attaques qui s'ouvrent) ;
##   * le combat de boss : barre du HUD, phases, zones de danger, mort,
##     objectif « boss » et victoire ;
##   * la Chasse aux boss (§ 12.4) : enchaînement sans pause ;
##   * la Survie (§ 12.3) : vagues sans fin, bonus entre les vagues, record ;
##   * le Défi du jour (§ 12.5) : graine stable, modificateurs, série ;
##   * le sélecteur de mode : les trois modes sont jouables.
##
## Sortie : « PHASE 6 : OK » (code 0) ou la liste des échecs (code 1).

const LEVEL_SCENE: String = "res://scenes/levels/LevelBase3D.tscn"
const BOSS_DIR: String = "res://data/bosses"
const FROZEN_WAVES: float = 1000.0

var failures: int = 0
var checks: int = 0
var level: LevelBase3D = null
var save_data: Dictionary = {}


func _ready() -> void:
	print("=== Test fonctionnel PHASE 6 ===")
	save_data = SaveManager.data.duplicate(true)
	var only := OS.get_environment("PHASE6_ONLY")
	var sections: Dictionary = {
		"bosses": _test_boss_data,
		"fight": _test_boss_fight,
		"rush": _test_boss_rush,
		"survival": _test_survival,
		"daily": _test_daily,
		"modes": _test_modes,
	}
	for section_name in sections.keys():
		if only != "" and not only.split(",").has(section_name):
			continue
		await (sections[section_name] as Callable).call()

	# Une sauvegarde de test ne doit jamais rester sur le téléphone.
	SaveManager.data = save_data
	SaveManager.save_game()
	Engine.time_scale = 1.0
	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d" % [checks, failures])
	print("PHASE 6 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
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


## Le HUD se met à jour dans `_process` : lire son texte après des frames de
## rendu (et non de physique seule), sinon la vérification devient une course.
func _ui_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Attend qu'une condition devienne vraie (au plus `limit` secondes). Renvoie
## l'état final : sert aux vérifications qui dépendent du temps réel (vagues,
## ennemis qui approchent).
func _until(condition: Callable, limit: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return bool(condition.call())


func _reset_save(cauris: int = 0) -> void:
	var fresh := SaveManager.DEFAULT_DATA.duplicate(true)
	fresh["cauris"] = cauris
	SaveManager.data = fresh


func _unload() -> void:
	if level == null or not is_instance_valid(level):
		level = null
		return
	if level.spawner != null:
		level.spawner.finished = true
	level.queue_free()
	level = null
	await _frames(4)


## Charge un niveau jouable, ralenti de mort coupé. `frozen` fige les vagues
## (tests de données) ; sinon le niveau vit à son rythme (tests de comportement).
func _load(data: LevelData, frozen: bool = true) -> LevelBase3D:
	await _unload()
	var scene := load(LEVEL_SCENE).instantiate() as LevelBase3D
	scene.level_data = data
	scene.wave_delay_multiplier = FROZEN_WAVES if frozen else 1.0
	scene.boss_slowmo = false
	add_child(scene)
	await _frames(10)
	level = scene
	return level


func _damage_boss(boss: BossBase3D, amount: float) -> void:
	var info := DamageInfo.new()
	info.amount = amount
	info.knockback = 0.0
	boss.on_hit_received(info)


# -----------------------------------------------------------------#
#                       § 10 : LES GARDIENS                        #
# -----------------------------------------------------------------#

func _test_boss_data() -> void:
	print("[bosses] 5 fiches, 3 phases, attaques progressives")
	var files := 0
	var dir := DirAccess.open(BOSS_DIR)
	if dir != null:
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				files += 1
	_check(files == 5, "5 fiches de boss (%d)" % files)
	_check(BossRegistry.ids().size() == 5, "5 identifiants au registre")

	var seen: Array[String] = []
	for boss_id in BossRegistry.ORDER:
		var data := BossRegistry.get_data(boss_id)
		_check(data != null and data.id == boss_id, "fiche %s chargée" % boss_id)
		if data == null:
			continue
		seen.append(data.display_name)
		_check(data.health >= 280.0, "%s : %d vie" % [boss_id, data.health])
		_check(data.damage > 0.0 and data.attack_range > 0.0, "%s : attaque définie" % boss_id)
		# 3 phases : 100-60, 60-30, 30-0.
		_check(data.phase_for_ratio(1.0) == 1 and data.phase_for_ratio(0.55) == 2
			and data.phase_for_ratio(0.2) == 3, "%s : 3 phases" % boss_id)
		var phase_1 := data.attacks_at_phase(1)
		var phase_2 := data.attacks_at_phase(2)
		var phase_3 := data.attacks_at_phase(3)
		_check(not phase_1.is_empty(), "%s : attaques en phase 1" % boss_id)
		_check(phase_3.size() >= phase_2.size() and phase_2.size() >= phase_1.size(),
			"%s : le répertoire s'ouvre (%d/%d/%d)" % [boss_id, phase_1.size(), phase_2.size(), phase_3.size()])
		_check(data.telegraph_for_phase(3) < data.telegraph_for_phase(1),
			"%s : télégraphe plus court en phase 3" % boss_id)
	_check(seen.size() == 5 and seen[4] == "Général rival", "les 5 gardiens du § 10")
	_check(BossRegistry.for_chapter(1).id == "captain", "chapitre 1 : le capitaine")
	_check(BossRegistry.for_chapter(5).id == "rival_general", "chapitre 5 : le général rival")

	var captain := BossRegistry.get_data("captain")
	_check(captain.summon_phase == 2 and captain.summon_count == 2,
		"le capitaine appelle 2 soldats en phase 2")
	var general := BossRegistry.get_data("rival_general")
	_check(general.combo_hits >= 5, "le général enchaîne 5 coups")
	var colossus := BossRegistry.get_data("colossus")
	_check(colossus.armor_guards > 0, "le colosse a une armure à briser")
	var sorcerer := BossRegistry.get_data("shadow_sorcerer")
	_check(sorcerer.darken_arena, "le sorcier plonge l'arène dans le noir")


# -----------------------------------------------------------------#
#                    COMBAT DE BOSS ET OBJECTIF                    #
# -----------------------------------------------------------------#

func _test_boss_fight() -> void:
	print("[fight] barre de boss, phases, zones de danger, victoire")
	_reset_save(0)
	var data := load("res://data/levels/adventure/ch1_l5.tres") as LevelData
	_check(data != null and data.objective == "boss" and data.boss_id == "captain",
		"ch1_l5 pose le capitaine")
	await _load(data)
	_check(level.boss != null and is_instance_valid(level.boss), "un boss est dans l'arène")
	if level.boss == null:
		return
	var boss := level.boss
	_check(boss.data.id == "captain", "c'est bien le capitaine")
	_check(boss.phase == 1, "le combat démarre en phase 1")
	_check(boss.health == boss.max_health and boss.max_health >= 280.0,
		"vie pleine (%d)" % int(boss.max_health))
	_check(level.hud != null and level.hud.boss_bar_visible(), "la barre de boss du HUD est visible")
	await _ui_frames(3)
	_check(level.hud.boss_name_text().contains("Capitaine"), "le HUD nomme le gardien")
	_check(level.hud.boss_name_text().contains("PHASE 1"), "le HUD affiche la phase")
	_check(not level.boss_defeated, "l'objectif boss n'est pas encore rempli")
	_check(level.objective != null and not level.objective.success(), "objectif non rempli au départ")

	# Zone de danger : une attaque pose un disque au sol, et le niveau le garde.
	level.zones_root = level.zones_root if level.zones_root != null else Node3D.new()
	boss.call("_execute", "sweep")
	await _frames(2)
	_check(level.zones_root.get_child_count() > 0, "une attaque pose une zone de danger au sol")

	# Phase 2 à 55 %, phase 3 sous 30 %.
	_damage_boss(boss, boss.max_health * 0.45)
	await _frames(2)
	_check(boss.phase == 2, "phase 2 à 55 %% (%d)" % boss.phase)
	await _ui_frames(3)
	_check(level.hud.boss_name_text().contains("PHASE 2"), "le HUD suit la phase 2")
	_damage_boss(boss, boss.max_health * 0.30)
	await _frames(2)
	_check(boss.phase == 3, "phase 3 sous 30 %% (%d)" % boss.phase)
	await _ui_frames(3)
	_check(level.hud.boss_name_text().contains("PHASE 3"), "le HUD suit la phase 3")

	# Mort : cauris, objectif rempli, niveau gagné.
	_damage_boss(boss, boss.max_health)
	await _frames(4)
	_check(level.boss_defeated, "le gardien tombé remplit l'objectif boss")
	_check(level.objective.success(), "KillBossObjective réussit")
	_check(level.pickup_nodes().size() > 0, "le gardien lâche ses cauris")
	await _frames(6)
	_check(level.completed, "le niveau se termine après le boss")
	_check(level.hud.result_text().contains("NIVEAU TERMINÉ"), "bandeau de victoire")
	_check(SaveManager.stars_for("boss_captain") >= 1, "le boss conquis est mémorisé")
	await _unload()


# -----------------------------------------------------------------#
#                 § 12.4 : CHASSE AUX BOSS                         #
# -----------------------------------------------------------------#

func _test_boss_rush() -> void:
	print("[rush] enchaînement des gardiens, sans pause")
	_reset_save(0)
	var data := ModeBuilder.boss_rush_data(["captain", "colossus"])
	_check(data.objective == "boss", "la chasse est un niveau à objectif boss")
	_check(data.boss_id == "captain" and data.boss_chain == ["colossus"],
		"le premier gardien puis le suivant")
	_check(data.potion_pickups == 2, "deux potions pour toute la chasse")
	_check(data.time_limit == 0, "pas de chrono entre les gardiens")
	await _load(data)
	_check(level.boss != null and level.boss.data.id == "captain", "le capitaine ouvre la chasse")
	_damage_boss(level.boss, level.boss.max_health)
	await _wait(1.3)
	_check(level.boss != null and is_instance_valid(level.boss)
		and level.boss.data.id == "colossus", "le colosse arrive sans écran intermédiaire")
	_check(not level.boss_defeated, "la chasse n'est pas gagnée au premier gardien")
	await _ui_frames(3)
	_check(level.hud.boss_name_text().contains("Colosse"), "le HUD change de gardien")
	# Le colosse porte une armure (§ 10) : ses coups valent un quart tant qu'elle
	# n'est pas brisée — on frappe donc jusqu'à la chute.
	for _hit in 6:
		if level.boss == null or not is_instance_valid(level.boss):
			break
		_damage_boss(level.boss, level.boss.max_health)
		await _frames(2)
	await _frames(8)
	_check(level.boss_defeated, "le dernier gardien tombe")
	_check(level.completed, "la chasse se termine après le dernier")
	_check(level.hud.boss_bar_visible() == false or level.boss == null,
		"plus de barre de boss à la fin")
	await _unload()


# -----------------------------------------------------------------#
#                   § 12.3 : SURVIE ET BONUS                       #
# -----------------------------------------------------------------#

func _test_survival() -> void:
	print("[survival] vagues sans fin, bonus, record")
	_reset_save(0)
	var data := ModeBuilder.survival_data()
	_check(data.endless and data.objective == "survive", "la Survie est sans fin")
	_check(data.time_limit == 0, "aucune limite de temps")
	_check(not data.is_lane(), "la Survie se joue en arène")
	await _load(data, false)
	_check(level.completed == false and level.failed == false, "la Survie ne se gagne pas au départ")
	_check(level.objective != null and not level.objective.success(),
		"l'objectif « survive » sans chrono ne réussit pas tout seul")
	_check(level.objective.description().contains("vague"), "le HUD affiche le numéro de vague")
	_check(level.spawner != null and level.spawner.level_data.endless, "le spawner est en mode sans fin")

	# § 3.1 : en arène fermée, la vague arrive et attaque même une joueuse
	# immobile (sinon la Survie se gagnerait en ne touchant à rien).
	var arrived := await _until(func() -> bool: return level.enemy_nodes().size() > 0, 8.0)
	_check(arrived, "la première vague de Survie entre dans l'arène")
	var hurt := await _until(func() -> bool:
		return level.player.health < level.player.balance.max_health, 12.0)
	_check(hurt, "les ennemis approchent et frappent une joueuse immobile")

	# Vague nettoyée pour de vrai : le flux se suspend et trois bonus s'ouvrent.
	level.player.health = level.player.balance.max_health
	for node in level.enemy_nodes():
		if node is EnemyBase3D:
			var info := DamageInfo.new()
			info.amount = 9999.0
			(node as EnemyBase3D).on_hit_received(info)
	var cleared := await _until(func() -> bool: return level.survival_waves >= 1, 8.0)
	_check(cleared, "la vague nettoyée est comptée")
	_check(level.bonus_choice != null and is_instance_valid(level.bonus_choice),
		"un choix de bonus s'ouvre entre les vagues")
	_check(level.spawner.flow_paused, "les vagues attendent le choix")
	if level.bonus_choice == null:
		return
	_check(level.bonus_choice.buttons.size() == 3, "trois bonus proposés")
	var damages_before := level.player.run_damage_mult
	level.bonus_choice.pick("damage")
	await _frames(2)
	_check(level.player.run_damage_mult > damages_before, "le bonus de force augmente les dégâts")
	_check(not level.spawner.flow_paused, "les vagues reprennent après le choix")
	_check(level.bonus_choice == null, "l'écran de bonus se referme")
	var next := await _until(func() -> bool: return level.enemy_nodes().size() > 0, 8.0)
	_check(next, "la vague suivante arrive après le choix")

	# Soin et spécial : les deux autres bonus font ce qu'ils annoncent.
	level.player.health = level.player.balance.max_health * 0.2
	level.apply_bonus("heal")
	_check(level.player.health > level.player.balance.max_health * 0.5, "le soin rend 40 % de vie")
	level.player.set_energy(0.0)
	level.apply_bonus("special")
	_check(level.player.energy >= level.player.balance.max_energy, "le spécial est rechargé")

	# Record local : la chute (une seule vie en Survie) enregistre les vagues.
	level.survival_waves = 7
	level.call("_on_player_died")
	await _frames(2)
	_check(level.failed, "la joueuse tombée termine la Survie")
	_check(SaveManager.survival_record() == 7, "le record de Survie est enregistré (%d)"
		% SaveManager.survival_record())
	_check(level.hud.result_text().contains("record"), "l'écran annonce le record")
	# Un moins bon run n'écrase pas le record.
	_check(not SaveManager.record_survival(3), "un run plus faible ne remplace pas le record")
	_check(SaveManager.survival_record() == 7, "le record reste à 7")
	await _unload()


# -----------------------------------------------------------------#
#                  § 12.5 : DÉFI DU JOUR                           #
# -----------------------------------------------------------------#

func _test_daily() -> void:
	print("[daily] graine du jour, modificateurs, série")
	_reset_save(0)
	var a := ModeBuilder.daily_data(20261018)
	var b := ModeBuilder.daily_data(20261018)
	_check(a.id == b.id and a.id.begins_with("daily_"), "même date, même identifiant (%s)" % a.id)
	_check(a.modifier == b.modifier, "même date, même modificateur (%s)" % a.modifier)
	_check(a.display_name == b.display_name, "même date, même titre")
	_check(a.enemy_total() == b.enemy_total(), "même date, mêmes effectifs")
	_check(ModeBuilder.DAILY_MODIFIERS.has(a.modifier), "le modificateur est l'un des quatre")
	_check(not a.is_lane() and a.objective == "survive", "le défi est une arène à tenir")
	_check(a.time_limit > 0, "le défi a un chrono (contrairement à la Survie)")
	_check(not ModeBuilder.modifier_label(a.modifier).is_empty(), "le modificateur a un libellé")

	# Le modificateur s'applique au niveau chargé.
	var one_life := ModeBuilder.daily_data(20261018)
	one_life.modifier = "one_life"
	one_life.id = "daily_test_one_life"
	await _load(one_life)
	_check(GameState.modifier == "one_life", "le niveau pose le modificateur du jour")
	_check(GameState.is_one_life(), "« une seule vie » est actif")
	level.call("_on_player_died")
	await _frames(2)
	_check(level.failed, "« une seule vie » : la première chute termine le niveau")
	await _unload()

	GameState.modifier = "fast"
	_check(is_equal_approx(GameState.enemy_speed_mult(), 1.25), "« ennemis rapides » : ×1,25")
	GameState.modifier = "damage"
	_check(is_equal_approx(GameState.enemy_damage_mult(), 2.0), "« dégâts doublés » : ×2")
	# La vitesse se vérifie sur un vrai ennemi, « ennemis rapides » actif.
	GameState.modifier = "fast"
	var enemy := EnemyRegistry.get_scene().instantiate() as EnemyBase3D
	enemy.data = EnemyRegistry.get_data("soldier")
	add_child(enemy)
	await _frames(2)
	_check(is_equal_approx(enemy.speed_now(), enemy.data.speed * 1.25),
		"la vitesse de l'ennemi suit le modificateur (%.2f vs %.2f, mod=%s)" % [
			enemy.speed_now(), enemy.data.speed * 1.25, GameState.modifier])
	enemy.queue_free()
	await _frames(2)
	GameState.modifier = ""

	# Série : un jour gagné entretient la suite, la veille compte.
	var daily: Dictionary = SaveManager.data["daily"]
	daily["last_date"] = DailySeed.today_seed() - 1
	daily["streak"] = 3
	DailySeed.record_daily_result(true)
	_check(int(daily["streak"]) == 4, "une victoire le lendemain prolonge la série (%d)"
		% int(daily["streak"]))
	_check(int(daily["last_date"]) == DailySeed.today_seed(), "la date du jour est notée")
	DailySeed.record_daily_result(true)
	_check(int(daily["streak"]) == 4, "le même jour ne compte qu'une fois")
	DailySeed.record_daily_result(false)
	_check(int(daily["streak"]) == 4, "une défaite ne prolonge pas la série")


# -----------------------------------------------------------------#
#                        CHOIX DU MODE                             #
# -----------------------------------------------------------------#

func _test_modes() -> void:
	print("[modes] les trois modes hors campagne sont jouables")
	var packed := load("res://scenes/ui/ModeSelect.tscn") as PackedScene
	var screen := packed.instantiate() as ModeSelect
	add_child(screen)
	await _frames(4)
	for id in ["survie", "boss_rush", "defi"]:
		var button := screen.mode_buttons.get(id) as Button
		_check(button != null, "carte « %s » présente" % id)
		if button == null:
			continue
		_check(not button.disabled, "« %s » n'est plus verrouillé" % id)
		_check(button.get_signal_connection_list("pressed").size() > 0,
			"« %s » lance bien un mode" % id)
	_check(screen.mode_buttons["survie"].text.contains("record"),
		"la carte Survie affiche le record")
	screen.queue_free()
	await _frames(2)
