extends SceneTree
## Rasterise les SVG de l'icône pour le store et Android.
##
##   godot --headless --path . --script res://tools/make_store_assets.gd
##
## Produit :
##   assets/ui/store/icon_512.png                        (icône Play 512×512)
##   assets/ui/store/icon_adaptive_foreground_432.png    (calque avant, transparent)
## Le fond adaptatif et la bannière sont générés par `tools/make_store_assets.py`.

const JOBS := [
	{"src": "res://icon.svg", "dst": "res://assets/ui/store/icon_512.png", "scale": 1.0},
	{"src": "res://assets/ui/store/icon_foreground.svg",
	 "dst": "res://assets/ui/store/icon_adaptive_foreground_432.png", "scale": 1.0},
]


func _init() -> void:
	var failed := 0
	for job in JOBS:
		if not _render(job["src"], job["dst"], job["scale"]):
			failed += 1
	quit(failed)


func _render(src: String, dst: String, svg_scale: float) -> bool:
	var bytes := FileAccess.get_file_as_bytes(src)
	if bytes.is_empty():
		push_error("SVG illisible : " + src)
		return false
	var image := Image.new()
	var err := image.load_svg_from_buffer(bytes, svg_scale)
	if err != OK:
		push_error("SVG non décodé (%d) : %s" % [err, src])
		return false
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	err = image.save_png(dst)
	if err != OK:
		push_error("PNG non écrit (%d) : %s" % [err, dst])
		return false
	print("[icône] %s -> %s  %s" % [src, dst, image.get_size()])
	return true
