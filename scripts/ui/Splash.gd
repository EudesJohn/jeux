extends Control
## Splash (§ 16) : logo + chargement. 2 s puis MainMenu ; tout appui saute.


func _ready() -> void:
	get_tree().create_timer(2.0).timeout.connect(_go)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_go()


func _go() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
