extends Control
class_name VirtualJoystick
## Joystick virtuel flottant (DESIGN.md § 7, squelette § 20.12).
## Il apparaît là où le pouce se pose dans la moitié gauche, avec zone morte de
## 12 % et vitesse proportionnelle à l'inclinaison. Il publie son vecteur dans
## Events.joystick_vector et ne consomme AUCUN événement (mouse_filter IGNORE) :
## les boutons d'action de droite restent indépendants (multitouch).

const BASE_RADIUS: float = 90.0      ## course du pouce (px, base 1280×720)
const BASE_KNOB: float = 55.0        ## pastille de 110 px (§ 7)
const COLOR_BASE: Color = Color(0.10, 0.13, 0.25, 0.30)
const COLOR_RING: Color = Color(0.89, 0.66, 0.17, 0.45)
const COLOR_KNOB: Color = Color(0.89, 0.66, 0.17, 0.55)
const MOUSE_INDEX: int = -99         ## index fictif pour le test souris sur PC

@export var radius: float = BASE_RADIUS
@export var knob_radius: float = BASE_KNOB
@export var deadzone: float = 0.12
## Test au clavier/souris sur PC (§ 7). Les tests sans écran le coupent : la
## souris du bureau déplacerait la joueuse au milieu d'une mesure.
@export var mouse_control: bool = true

var touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _active: bool = false
var _radius_px: float = BASE_RADIUS
var _knob_px: float = BASE_KNOB


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_settings()


func _apply_settings() -> void:
	## § 7 : taille réglable de 80 à 130 %, opacité réglable.
	_radius_px = radius * Settings.button_scale
	_knob_px = knob_radius * Settings.button_scale
	modulate.a = Settings.button_opacity
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin(touch.index, touch.position)
		elif touch.index == touch_index:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == touch_index:
			_drag(drag.position)
	elif event is InputEventMouseButton:
		# Test sur PC à la souris (sur téléphone, le tactile suffit).
		# Un doigt produit aussi un clic émulé : l'ignorer, sinon le joystick
		# se croirait tenu par la souris et ne suivrait plus le glissement.
		var mouse := event as InputEventMouseButton
		if not mouse_control or mouse.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_begin(MOUSE_INDEX, mouse.position)
			elif touch_index == MOUSE_INDEX:
				_release()
	elif event is InputEventMouseMotion and touch_index == MOUSE_INDEX:
		if mouse_control:
			_drag((event as InputEventMouseMotion).position)


func _begin(index: int, position: Vector2) -> void:
	if touch_index != -1 or not _in_zone(position):
		return
	touch_index = index
	_origin = position
	_offset = Vector2.ZERO
	_active = true
	Events.joystick_vector = Vector2.ZERO
	queue_redraw()


func _drag(position: Vector2) -> void:
	_offset = (position - _origin).limit_length(_radius_px)
	var vector := _offset / _radius_px
	Events.joystick_vector = vector if vector.length() > deadzone else Vector2.ZERO
	queue_redraw()


func _release() -> void:
	touch_index = -1
	_active = false
	_offset = Vector2.ZERO
	Events.joystick_vector = Vector2.ZERO
	queue_redraw()


func _in_zone(position: Vector2) -> bool:
	## Moitié gauche de l'écran (§ 7) : le pouce se pose où il veut, bas ou haut.
	var viewport_size := get_viewport_rect().size
	return position.x < viewport_size.x * 0.5


func _draw() -> void:
	if not _active:
		return
	draw_circle(_origin, _radius_px, COLOR_BASE)
	draw_arc(_origin, _radius_px, 0.0, TAU, 48, COLOR_RING, 3.0, true)
	draw_circle(_origin + _offset, _knob_px, COLOR_KNOB)
	draw_arc(_origin + _offset, _knob_px, 0.0, TAU, 48, COLOR_RING, 2.0, true)
