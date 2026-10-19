extends CanvasLayer
class_name BonusChoice
## § 12.3 : « bonus entre les vagues » de la Survie. Trois cartes, un seul
## choix : le niveau suspend le flux des vagues (`spawner.flow_paused`) le temps
## du choix, puis reprend. Aucun nœud de scène à maintenir : tout est construit
## par le code, comme le reste du HUD (§ 18 règle 2).

signal chosen(id: String)

const GOLD: Color = Color(0.89, 0.66, 0.17)
const TEXT: Color = Color(0.96, 0.91, 0.82)

## Les trois bonus du § 12.3, avec leur effet réel (appliqué par le niveau).
const BONUSES: Array = [
	{"id": "heal", "title": "SOIN", "detail": "+40 % de vie"},
	{"id": "damage", "title": "FORCE", "detail": "+15 % de dégâts"},
	{"id": "special", "title": "ÉNERGIE", "detail": "Spécial rechargé"},
]

var level: Node = null
var buttons: Array[Button] = []


## Affiche le choix. `wave` est le numéro de la vague qui vient d'être repoussée.
func offer(target: Node, wave: int) -> void:
	level = target
	name = "BonusChoice"
	layer = 20
	_build(wave)


## Libellé d'un bonus, pour le message du HUD et les tests.
static func label_for(id: String) -> String:
	for bonus in BONUSES:
		if String(bonus["id"]) == id:
			return String(bonus["title"])
	return id


func _build(wave: int) -> void:
	var background := ColorRect.new()
	background.name = "Dim"
	background.color = Color(0.06, 0.05, 0.04, 0.72)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(620.0, 0.0)
	center.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "VAGUE %d REPOUSSÉE — CHOISIR UN BONUS" % maxi(1, wave + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)

	for bonus in BONUSES:
		var button := Button.new()
		button.name = String(bonus["id"])
		button.text = "%s — %s" % [String(bonus["title"]), String(bonus["detail"])]
		button.custom_minimum_size = Vector2(0.0, 62.0)
		button.add_theme_font_size_override("font_size", 21)
		button.add_theme_color_override("font_color", TEXT)
		var id := String(bonus["id"])
		button.pressed.connect(func() -> void: pick(id))
		column.add_child(button)
		buttons.append(button)


## Applique le bonus au niveau puis referme l'écran. Public : les tests et le
## clavier (1, 2, 3) passent par ici, jamais par un bouton en particulier.
func pick(id: String) -> void:
	if level != null and is_instance_valid(level):
		level.call("apply_bonus", id)
	chosen.emit(id)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			pick("heal")
		KEY_2:
			pick("damage")
		KEY_3:
			pick("special")
