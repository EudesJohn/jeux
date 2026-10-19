extends Control
class_name TouchButton
## Bouton d'action tactile (DESIGN.md § 7, squelette § 20.12).
## Rond, semi-transparent, dessiné par le code (aucune texture à fournir).
## Il suit lui-même l'index du doigt : plusieurs boutons peuvent être pressés
## en même temps que le joystick (multitouch obligatoire, § 7).

signal tapped           ## appui (utilisé par Pause)
signal released_action  ## relâchement (utilisé par Garde)

@export var action_name: String = "attack"
@export var label: String = ""                     ## icônes en PHASE 5
@export var diameter: float = 110.0
@export var fill_color: Color = Color(0.12, 0.16, 0.36, 0.55)
@export var border_color: Color = Color(0.89, 0.66, 0.17, 0.70)
## Test à la souris sur PC (§ 7). Les tests le coupent : un clic du bureau
## déclencherait une attaque au milieu d'une mesure.
@export var mouse_control: bool = true

var touch_index: int = -1
var is_down: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   ## le doigt passe par _input
	add_to_group("touch_button")
	_apply_settings()


## Réglages (§ 7) : appelée à la création, et par `Settings` quand la joueuse
## change la taille ou l'opacité en cours de partie.
func apply_settings() -> void:
	_apply_settings()


func _apply_settings() -> void:
	## § 7 : taille (80-130 %) et opacité réglables.
	var size_px := diameter * Settings.button_scale
	custom_minimum_size = Vector2(size_px, size_px)
	size = Vector2(size_px, size_px)
	modulate.a = Settings.button_opacity
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		elif touch.index == touch_index:
			_release()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		# Un doigt produit aussi un clic souris émulé (§ emulate_mouse_from_touch) :
		# on l'ignore, le tactile est déjà traité juste au-dessus.
		if not mouse_control or mouse.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_press(0, mouse.position)
			else:
				_release()


func _press(index: int, position: Vector2) -> void:
	if touch_index != -1 or not get_global_rect().has_point(position):
		return
	touch_index = index
	is_down = true
	queue_redraw()
	tapped.emit()
	Events.touch_action.emit(action_name, true)


func _release() -> void:
	if touch_index == -1:
		return
	touch_index = -1
	is_down = false
	queue_redraw()
	released_action.emit()
	Events.touch_action.emit(action_name, false)


## Relâchement forcé (le bouton disparaît, § 12.2) : le doigt n'est plus sur
## rien, le jeu doit donc recevoir le relâchement — l'Interaction se maintient.
func release_now() -> void:
	_release()


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	if r <= 0.0:
		return
	var fill := fill_color
	if is_down:
		fill = Color(fill.r + 0.15, fill.g + 0.15, fill.b + 0.15, fill.a + 0.1)
	draw_circle(center, r, fill)
	draw_arc(center, r, 0.0, TAU, 48, border_color, 4.0, true)
	if label != "":
		var font := ThemeDB.fallback_font
		var font_size := int(r * 0.62)
		draw_string(font, Vector2(0.0, center.y + font_size * 0.38), label,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size)
