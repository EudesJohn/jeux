extends Node
## Performance entrée de gamme (DESIGN.md § 25).
##
## Deux rôles :
##  1. **auto-adaptation** : si le jeu tient moins de 24 images/s pendant 5 s,
##     on propose de baisser d'un cran la qualité graphique (jamais imposé : le
##     joueur choisit) ;
##  2. **réglages de qualité appliqués à la scène** : échelle 3D, ombre blob ou
##     vraie ombre, contour de la joueuse, densité des particules. Les niveaux
##     lisent `Quality.*` au lieu de refaire chacun les mêmes tests.
##
## (L'autoload s'appelle Quality et non Performance : Godot a déjà un singleton
## interne `Performance`, le masquer serait une source de bugs.)

signal quality_suggested(quality: String, fps: float)

const LOW_FPS: float = 24.0            ## § 25 : « si FPS < 24 pendant 5 s »
const WINDOW_SECONDS: float = 5.0
const SAMPLE_INTERVAL: float = 0.5

var _samples: Array[float] = []
var _sample_timer: float = 0.0
## Qualité déjà refusée par le joueur : on ne repropose pas la même.
var _dismissed: String = ""
var _suggestion: String = ""
var _prompt: Control = null
var _prompt_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_sample_timer += delta
	if _sample_timer < SAMPLE_INTERVAL:
		return
	_sample_timer = 0.0
	push_sample(Engine.get_frames_per_second())


## Ajoute une mesure d'images/s et réévalue la proposition. Les tests appellent
## cette fonction directement avec des valeurs connues (le mode --headless
## n'a pas de vraies images/s).
func push_sample(fps: float) -> void:
	_samples.append(maxf(fps, 0.0))
	var needed := int(ceil(WINDOW_SECONDS / SAMPLE_INTERVAL))
	while _samples.size() > needed:
		_samples.pop_front()
	_evaluate()


func samples() -> int:
	return _samples.size()


func window_filled() -> bool:
	return _samples.size() >= int(ceil(WINDOW_SECONDS / SAMPLE_INTERVAL))


func average_fps() -> float:
	if _samples.is_empty():
		return 0.0
	var total := 0.0
	for value in _samples:
		total += value
	return total / float(_samples.size())


func reset() -> void:
	_samples.clear()
	_sample_timer = 0.0
	_set_suggestion("")


## Qualité proposée (« medium », « low ») ou "" si tout va bien.
func suggested_quality() -> String:
	return _suggestion


func suggestion_visible() -> bool:
	return _prompt != null and is_instance_valid(_prompt) and _prompt.visible


## Un cran en dessous : high → medium → low (low reste low).
static func lower_quality(quality: String) -> String:
	match quality:
		"high":
			return "medium"
		"medium":
			return "low"
		_:
			return "low"


## § 25 : l'IA hors écran est désactivée sur téléphone. En mode headless il n'y
## a pas de rendu, donc « hors écran » ne veut rien dire : on laisse l'IA
## tourner (sinon les tests de combat deviendraient faux).
static func culling_enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return Settings.quality != "high"


## § 25 : pas de particules inutiles en qualité Faible.
static func particle_scale() -> float:
	match Settings.quality:
		"low":
			return 0.5
		"high":
			return 1.0
		_:
			return 0.8


static func outline_enabled() -> bool:
	return Settings.quality == "high"


## § 25 : « ombre unique 1024 px pour la joueuse » en qualité Haute ; sinon une
## ombre blob (un disque sombre sous les pieds) suffit.
static func real_shadows_enabled() -> bool:
	return Settings.quality == "high"


func _evaluate() -> void:
	var next := ""
	if Settings.quality != "low" and window_filled() and average_fps() < LOW_FPS:
		var candidate := lower_quality(Settings.quality)
		if candidate != _dismissed:
			next = candidate
	_set_suggestion(next)


func _set_suggestion(quality: String) -> void:
	if quality == _suggestion:
		return
	_suggestion = quality
	if quality.is_empty():
		_hide_prompt()
		return
	quality_suggested.emit(quality, average_fps())
	_show_prompt(quality)


# -----------------------------------------------------------------#
#                    PETIT BANDEAU DE PROPOSITION                  #
# -----------------------------------------------------------------#

func _show_prompt(quality: String) -> void:
	if _prompt == null or not is_instance_valid(_prompt):
		_build_prompt()
	var label_key := "Faible" if quality == "low" else "Moyenne"
	Localizer.set_text(_prompt_label,
		"Le jeu ralentit (%d images/s). Passer en qualité %s ?",
		[roundi(average_fps()), tr(label_key)])
	_prompt.visible = true


func _hide_prompt() -> void:
	if _prompt != null and is_instance_valid(_prompt):
		_prompt.visible = false


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PerformancePrompt"
	layer.layer = 80
	add_child(layer)

	_prompt = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.06, 0.96)
	style.border_color = Color(0.89, 0.66, 0.17, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_prompt.add_theme_stylebox_override("panel", style)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -150.0
	_prompt.offset_bottom = -70.0
	_prompt.offset_left = -330.0
	_prompt.offset_right = 330.0
	layer.add_child(_prompt)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_prompt.add_child(column)

	_prompt_label = Label.new()
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	column.add_child(_prompt_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)

	var accept := Button.new()
	accept.name = "Accept"
	accept.text = "Oui, alléger"
	accept.custom_minimum_size = Vector2(190.0, 46.0)
	accept.pressed.connect(apply_suggestion)
	row.add_child(accept)

	var refuse := Button.new()
	refuse.name = "Refuse"
	refuse.text = "Non"
	refuse.custom_minimum_size = Vector2(120.0, 46.0)
	refuse.pressed.connect(dismiss_suggestion)
	row.add_child(refuse)


## Applique la qualité proposée (le joueur a accepté).
func apply_suggestion() -> void:
	if _suggestion.is_empty():
		return
	var wanted := _suggestion
	_set_suggestion("")
	Settings.set_quality(wanted)


## Le joueur refuse : on ne repropose plus cette qualité.
func dismiss_suggestion() -> void:
	_dismissed = _suggestion
	_set_suggestion("")
