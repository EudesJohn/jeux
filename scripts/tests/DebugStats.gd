extends Label
## Compteurs de perf à l'écran (DOSSIER.md § 6.2 / § 25) : FPS, triangles
## rendus et draw calls. Bûches : < 120 000 tris/frame et < 100 draw calls.

var _acc: float = 0.0
var _draw_calls: int = 0
var _primitive_count: int = 0
var _vertices_count: int = 0


func _process(delta: float) -> void:
	# Mise à jour 4 fois par seconde pour rester lisible.
	_acc += delta
	if _acc < 0.25:
		return
	_acc = 0.0
	text = "FPS %d | Tris %d | Draw calls %d" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	]
