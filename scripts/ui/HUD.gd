extends CanvasLayer
class_name HUD
## HUD de combat (DESIGN.md § 16). Barres de vie, d'énergie et de stabilité de
## garde, « SPÉCIAL PRÊT », vignette de dégâts, messages de réussite
## (« GARDE PARFAITE ! ») et anneau de verrouillage (§ 3.2).
## PHASE 3 ajoute le bloc « niveau » : timer, objectif et compteur de cauris
## (§ 16). Les indicateurs de prisonniers arrivent en PHASE 4 ; la barre de boss
## avec la PHASE 6.
##
## Le HUD n'appelle jamais le gameplay : il écoute `Events` et les signaux de la
## joueuse (§ 18 règle 3).

const LOW_HEALTH_RATIO: float = 0.3
const LOW_HEALTH_VIGNETTE: float = 0.3      ## vignette permanente quand la vie est basse
const VIGNETTE_FADE: float = 0.7
const POPUP_RISE: float = 34.0
const POPUP_TIME: float = 1.0

@onready var life: ProgressBar = $Bars/Life
@onready var energy: ProgressBar = $Bars/Energy
@onready var stability: ProgressBar = $Bars/Stability
@onready var values: Label = $Bars/Values
@onready var special_ready_label: Label = $Bars/SpecialReady
@onready var vignette: ColorRect = $Vignette
@onready var popup: Label = $Popup
@onready var lock_on: LockOnMarker = $LockOn
@onready var timer_label: Label = $Level/Timer
@onready var objective_label: Label = $Level/Objective
@onready var cauris_label: Label = $Level/Cauris
@onready var result_label: Label = $Level/Result
## § 16 (PHASE 4) : « indicateurs prisonniers » et jauge de l'interaction de 2 s.
@onready var prisoners_label: Label = $Level/Prisoners
@onready var hold_bar: ProgressBar = $Level/Hold

var player: Player3D
## Niveau en cours (LevelBase3D) : timer et objectif sont lus chez lui (§ 20.9).
var level: Node = null
## § 10 : boss en cours. La grande barre de vie et le nom s'affichent pendant
## le combat, et disparaissent avec le gardien.
var boss: Node = null
var boss_box: Control
var boss_name: Label
var boss_bar: ProgressBar

var _popup_base_y: float = 0.0
var _popup_tween: Tween = null
var _vignette_tween: Tween = null
var _ready_blink: Tween = null
var _vignette_intensity: float = 0.0
var _special_ready: bool = false


func _ready() -> void:
	_popup_base_y = popup.position.y
	_build_boss_bar()
	popup.modulate.a = 0.0
	Events.player_damaged.connect(_on_player_damaged)
	Events.perfect_guard.connect(_on_perfect_guard)
	Events.perfect_dodge.connect(_on_perfect_dodge)
	Events.guard_broken.connect(_on_guard_broken)
	Events.special_ready.connect(_on_special_ready)
	Events.cauris_changed.connect(_on_cauris_changed)


# -----------------------------------------------------------------#
#                    BARRE DE BOSS (§ 10, PHASE 6)                 #
# -----------------------------------------------------------------#

## Grande barre de vie + nom du gardien, en haut au centre (§ 10 : « grande
## barre de vie, nom affiché »). Construite par le code : aucun nœud à ajouter
## dans la scène.
func _build_boss_bar() -> void:
	boss_box = Control.new()
	boss_box.name = "BossBar"
	boss_box.anchor_left = 0.5
	boss_box.anchor_right = 0.5
	boss_box.offset_left = -350.0
	boss_box.offset_right = 350.0
	boss_box.offset_top = 6.0
	boss_box.offset_bottom = 76.0
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_box)

	boss_name = Label.new()
	boss_name.name = "BossName"
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 26)
	boss_name.add_theme_color_override("font_color", Color(0.89, 0.66, 0.17))
	boss_name.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_name.offset_bottom = 34.0
	boss_box.add_child(boss_name)

	boss_bar = ProgressBar.new()
	boss_bar.name = "BossLife"
	boss_bar.show_percentage = false
	boss_bar.max_value = 100.0
	boss_bar.value = 100.0
	boss_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	boss_bar.offset_top = -30.0
	boss_bar.offset_bottom = -6.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.14, 0.12)
	fill.set_corner_radius_all(4)
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_box.add_child(boss_bar)
	boss_box.visible = false


## Branche (ou débranche) le HUD sur un boss. Appelé par le niveau quand le
## gardien apparaît, et à la mort du précédent en Chasse aux boss (§ 12.4).
func bind_boss(target: Node) -> void:
	boss = target
	if target == null:
		boss_box.visible = false
		boss_name.text = ""
		return
	boss_box.visible = true
	boss_bar.max_value = 100.0
	boss_bar.value = 100.0
	_refresh_boss()
	_show_popup(Localizer.format_tr("GARDIEN : %s", [boss_title()]), Color(0.89, 0.66, 0.17))


func boss_title() -> String:
	if boss == null or not is_instance_valid(boss):
		return ""
	var data: BossData = boss.get("data")
	return data.display_name if data != null else "Gardien"


func _refresh_boss() -> void:
	if boss == null or not is_instance_valid(boss):
		boss_box.visible = false
		return
	var ratio: float = float(boss.call("health_ratio"))
	boss_bar.value = clampf(ratio * 100.0, 0.0, 100.0)
	var phase := int(boss.get("phase"))
	boss_name.text = "%s   ·   PHASE %d" % [boss_title(), maxi(1, phase)]
	# Dernière phase : la barre vire au rouge sombre (lisibilité, § 16).
	boss_name.add_theme_color_override("font_color",
		Color(1.0, 0.42, 0.34) if phase >= 3 else Color(0.89, 0.66, 0.17))


## Textes et visibilité lus par les tests.
func boss_bar_visible() -> bool:
	return boss_box != null and boss_box.visible


func boss_name_text() -> String:
	return boss_name.text if boss_name != null else ""


## Lie le HUD à une joueuse (appelé par la scène de niveau, § 20.9).
func bind(target: Player3D) -> void:
	if target == null or player == target:
		return
	player = target
	target.health_changed.connect(_on_health_changed)
	target.energy_changed.connect(_on_energy_changed)
	_on_health_changed(target.health, target.balance.max_health)
	_on_energy_changed(target.energy, target.balance.max_energy)
	if target.balance != null:
		stability.max_value = target.balance.guard_stability_max
	stability.value = target.guard_stability


func _process(_delta: float) -> void:
	# Stabilité de garde (§ 8.4) : elle évolue à chaque blocage et régénère.
	if player != null and is_instance_valid(player):
		stability.value = player.guard_stability
	if boss_box != null and boss_box.visible:
		_refresh_boss()
	_refresh_level()


# -----------------------------------------------------------------#
#                     BLOC NIVEAU (§ 16, PHASE 3)                  #
# -----------------------------------------------------------------#

## Branche le HUD sur un niveau (timer, objectif, cauris).
func bind_level(target: Node) -> void:
	level = target
	_refresh_level()
	_on_cauris_changed(int(SaveManager.data["cauris"]) + GameState.cauris_this_run)


func _refresh_level() -> void:
	if level == null or not is_instance_valid(level):
		return
	var limit := float(level.call("total_time")) if level.has_method("total_time") else 0.0
	var left := float(level.get("time_left"))
	if limit <= 0.0:
		timer_label.text = "—"
		timer_label.modulate = Color.WHITE
	else:
		timer_label.text = _format_time(left)
		# Moins de 20 s : le timer passe au rouge (§ 16).
		timer_label.modulate = Color(1.0, 0.45, 0.4) if left <= 20.0 else Color.WHITE
	var objective: Variant = level.get("objective")
	if objective != null:
		objective_label.text = objective.description()
	_update_prisoners()


## Indicateurs du § 16 : « PRISONNIERS 1/3 » et jauge de l'interaction.
## Le HUD ne fait que LIRE le niveau (§ 18 règle 3).
func _update_prisoners() -> void:
	if level == null or not level.has_method("prisoner_status"):
		prisoners_label.text = ""
		hold_bar.visible = false
		return
	var status: Vector2i = level.call("prisoner_status")
	if status.y > 0:
		Localizer.set_text(prisoners_label, "PRISONNIERS %d/%d", [status.x, status.y])
	else:
		prisoners_label.text = ""
	var available: bool = bool(level.call("interact_available"))
	hold_bar.visible = available
	hold_bar.value = float(level.call("interact_ratio")) if available else 0.0


## Textes lisibles par les tests.
func prisoner_text() -> String:
	return prisoners_label.text


func hold_visible() -> bool:
	return hold_bar.visible


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [total / 60, total % 60]


func _on_cauris_changed(total: int) -> void:
	Localizer.set_text(cauris_label, "CAURIS %d", [total])

## Bandeau de fin de niveau : « NIVEAU TERMINÉ ★★ » ou « ÉCHEC — temps ».
func show_result(text: String, stars: int) -> void:
	var stars_text := ""
	if stars > 0:
		stars_text = "  " + "★".repeat(clampi(stars, 0, 3))
	result_label.text = text + stars_text
	result_label.modulate.a = 1.0
	result_label.add_theme_color_override("font_color",
		Color(0.89, 0.66, 0.17) if stars > 0 else Color(1.0, 0.45, 0.4))
	_show_popup(text, Color(0.89, 0.66, 0.17) if stars > 0 else Color(1.0, 0.45, 0.4))


## Message central ponctuel, appelé par le niveau (bonus de Survie, § 12.3).
func announce(text: String, color: Color = Color(0.89, 0.66, 0.17)) -> void:
	_show_popup(text, color)


## Texte du bandeau de fin : lisible par les tests.
func result_text() -> String:
	return result_label.text


# -----------------------------------------------------------------#
#                       VIE, ÉNERGIE, GARDE                        #
# -----------------------------------------------------------------#

func _on_health_changed(current: float, maximum: float) -> void:
	life.max_value = maximum
	life.value = current
	# Vie basse : la barre vire au rouge (§ 16, lisibilité en combat).
	var ratio := current / maxf(maximum, 0.001)
	life.modulate = Color(1.0, 0.4, 0.35) if ratio <= LOW_HEALTH_RATIO else Color.WHITE
	# La vignette reste allumée faiblement sous 30 % de vie : alerte discrète.
	if ratio <= LOW_HEALTH_RATIO and _vignette_intensity < LOW_HEALTH_VIGNETTE:
		_set_vignette(LOW_HEALTH_VIGNETTE)
	elif ratio > LOW_HEALTH_RATIO and _vignette_intensity <= LOW_HEALTH_VIGNETTE:
		_set_vignette(0.0)
	_refresh()


func _on_energy_changed(current: float, maximum: float) -> void:
	energy.max_value = maximum
	energy.value = current
	_refresh()


func _refresh() -> void:
	Localizer.set_text(values, "VIE %d / %d      ÉNERGIE %d / %d", [
		roundi(life.value), roundi(life.max_value), roundi(energy.value), roundi(energy.max_value)
	])
	var ready := energy.value >= energy.max_value and energy.max_value > 0.0
	if ready != _special_ready:
		_show_special_ready(ready)


## Les tweens du HUD meurent avec lui : sans cela le moteur signale un
## « can_process » sur un nœud déjà hors de l'arbre à chaque changement de scène.
func _exit_tree() -> void:
	for tween in [_popup_tween, _vignette_tween, _ready_blink]:
		if tween != null and tween.is_valid():
			tween.kill()


# -----------------------------------------------------------------#
#                    RETOURS DE COMBAT (§ 28)                      #
# -----------------------------------------------------------------#

## Vignette de dégâts : plus la joueuse est basse, plus elle est rouge.
func _on_player_damaged(actor: Node, amount: float) -> void:
	if player != null and actor != player:
		return
	var ratio := 1.0 - life.value / maxf(life.max_value, 1.0)
	var peak := clampf(0.35 + 0.45 * ratio + amount / 80.0, 0.0, 1.0)
	_set_vignette(peak)
	var floor_intensity := LOW_HEALTH_VIGNETTE if ratio >= 1.0 - LOW_HEALTH_RATIO else 0.0
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(_set_vignette, peak, floor_intensity, VIGNETTE_FADE)


func _set_vignette(value: float) -> void:
	_vignette_intensity = value
	var material := vignette.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("intensity", value)


## Intensité courante : lisible par les tests.
func vignette_intensity() -> float:
	return _vignette_intensity


func _on_perfect_guard(_actor: Node) -> void:
	_show_popup("GARDE PARFAITE !", Color(0.96, 0.91, 0.82))
	_set_vignette(maxf(_vignette_intensity, 0.2))


func _on_perfect_dodge(_actor: Node) -> void:
	_show_popup("ESQUIVE PARFAITE !", Color(0.62, 0.85, 1.0))


func _on_guard_broken(_actor: Node) -> void:
	_show_popup("GARDE BRISÉE", Color(1.0, 0.45, 0.4))


func _on_special_ready(_actor: Node) -> void:
	_show_popup("SPÉCIAL PRÊT", Color(0.89, 0.66, 0.17))


func _show_special_ready(ready: bool) -> void:
	_special_ready = ready
	if _ready_blink and _ready_blink.is_valid():
		_ready_blink.kill()
	if not ready:
		special_ready_label.modulate.a = 0.0
		return
	special_ready_label.modulate.a = 1.0
	# Clignotement lent : le bouton spécial est utilisable (§ 8.5).
	_ready_blink = create_tween().set_loops()
	_ready_blink.tween_property(special_ready_label, "modulate:a", 0.35, 0.6)
	_ready_blink.tween_property(special_ready_label, "modulate:a", 1.0, 0.6)


## Message central éphémère : « GARDE PARFAITE ! », « SPÉCIAL PRÊT »…
func _show_popup(text: String, color: Color) -> void:
	popup.text = text
	popup.add_theme_color_override("font_color", color)
	popup.position.y = _popup_base_y
	popup.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(popup, "position:y", _popup_base_y - POPUP_RISE, POPUP_TIME)
	_popup_tween.tween_property(popup, "modulate:a", 0.0, POPUP_TIME).set_delay(0.35)


## Texte du message central : lisible par les tests.
func popup_text() -> String:
	return popup.text
