extends Control
class_name ModeSelect
## Choix du mode (§ 16). Tous les modes du dossier sont jouables : Aventure et
## Sauvetage ont une carte, Survie / Chasse aux boss / Défi du jour fabriquent
## leur fiche avec `ModeBuilder` (§ 12.3-12.5) puis lancent la scène de niveau
## commune — un mode n'est pas un moteur à part (§ 18 règle 2).

const GOLD: Color = Color(0.89, 0.66, 0.17)
const LEVEL_SCENE: String = "res://scenes/levels/LevelBase3D.tscn"
const TEXT: Color = Color(0.96, 0.91, 0.82)

var mode_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.10, 0.078, 0.067)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.name = "Modes"
	column.add_theme_constant_override("separation", 8)
	# La colonne occupe la hauteur utile : sur un téléphone en 2:1, une colonne
	# centrée à hauteur fixe poussait « Retour » sous l'écran.
	column.custom_minimum_size = Vector2(760.0, 0.0)
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 0.0
	column.anchor_bottom = 1.0
	column.offset_left = -380.0
	column.offset_right = 380.0
	column.offset_top = 8.0
	column.offset_bottom = -8.0
	add_child(column)

	var title := Label.new()
	title.text = "CHOISIR UN MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)

	_add_mode(column, "Aventure", "aventure",
		"5 chapitres, 25 niveaux, la carte du royaume et ses étoiles.",
		_on_adventure)
	_add_mode(column, "Sauvetage", "sauvetage",
		"17 niveaux + une escorte : libérer les prisonniers avant le temps.",
		_on_rescue)
	_add_mode(column, "Arène d'entraînement", "arene",
		"Mannequins, verrouillage et garde parfaite — pour sentir le combat.",
		_on_arena)
	var record := SaveManager.survival_record()
	_add_mode(column, "Survie", "survie",
		"Vagues sans fin, un bonus entre chaque vague — record : %d." % record,
		_on_survival)
	_add_mode(column, "Chasse aux boss", "boss_rush",
		"%d gardien(s) débloqué(s) : les enchaîner, sans pause." % BossRegistry.unlocked_for_rush().size(),
		_on_boss_rush)
	_add_mode(column, "Défi du jour", "defi",
		ModeBuilder.modifier_label(ModeBuilder.daily_data().modifier) + " — série : %d jour(s)."
			% int(SaveManager.data["daily"].get("streak", 0)), _on_daily)

	# PHASE 8 : les trois buts du jour, sous la carte du Défi du jour.
	var goals_title := Label.new()
	goals_title.name = "DailyGoalsTitle"
	goals_title.text = "BUTS DU JOUR"
	goals_title.add_theme_font_size_override("font_size", 16)
	goals_title.add_theme_color_override("font_color", GOLD)
	column.add_child(goals_title)

	var goals_box := VBoxContainer.new()
	goals_box.name = "DailyGoals"
	goals_box.add_theme_constant_override("separation", 2)
	column.add_child(goals_box)
	for goal in DailySeed.goals():
		var line := Label.new()
		line.name = "Goal_%s" % String(goal["stat"])
		line.text = ("✓ " if bool(goal["done"]) else "• ") + DailySeed.goal_line(goal)
		line.add_theme_font_size_override("font_size", 14)
		line.add_theme_color_override("font_color",
			GOLD if bool(goal["done"]) else Color(TEXT, 0.78))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goals_box.add_child(line)

	var reward := Label.new()
	reward.name = "DailyReward"
	reward.text = Localizer.format_tr("Récompense : %d cauris", [DailySeed.REWARD_CAURIS])
	reward.add_theme_font_size_override("font_size", 14)
	reward.add_theme_color_override("font_color",
		GOLD if DailySeed.reward_claimed() else Color(TEXT, 0.7))
	goals_box.add_child(reward)

	var back := Button.new()
	back.name = "Back"
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0.0, 50.0)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back)
	column.add_child(back)


func _add_mode(parent: VBoxContainer, label: String, id: String,
		description: String, action: Callable) -> void:
	var button := Button.new()
	button.name = id
	button.text = "%s\n%s" % [label, description]
	button.custom_minimum_size = Vector2(0.0, 62.0)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", TEXT)
	button.disabled = not action.is_valid()
	if action.is_valid():
		button.pressed.connect(action)
	else:
		button.tooltip_text = "Disponible dans une prochaine phase."
	mode_buttons[id] = button
	parent.add_child(button)


func _on_adventure() -> void:
	GameState.mode = GameState.GameMode.ADVENTURE
	get_tree().change_scene_to_file("res://scenes/ui/AdventureMap.tscn")


func _on_rescue() -> void:
	GameState.mode = GameState.GameMode.RESCUE
	get_tree().change_scene_to_file("res://scenes/ui/RescueSelect.tscn")


func _on_survival() -> void:
	GameState.mode = GameState.GameMode.SURVIVAL
	GameState.current_level_data = ModeBuilder.survival_data()
	get_tree().change_scene_to_file(LEVEL_SCENE)


## § 12.4 : les gardiens déjà vaincus, l'un après l'autre, sans pause.
func _on_boss_rush() -> void:
	GameState.mode = GameState.GameMode.BOSS_RUSH
	GameState.current_level_data = ModeBuilder.boss_rush_data()
	get_tree().change_scene_to_file(LEVEL_SCENE)


## § 12.5 : même graine = même niveau, le même jour, sur tous les téléphones.
func _on_daily() -> void:
	GameState.mode = GameState.GameMode.DAILY
	GameState.current_level_data = ModeBuilder.daily_data()
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _on_arena() -> void:
	GameState.mode = GameState.GameMode.ARENA
	get_tree().change_scene_to_file("res://scenes/tests/ArenaTest.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
