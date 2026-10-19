extends Node
## Point d'entrée du test réseau PHASE 7 : pose `Phase7NetRunner` sous la racine
## (il survit au changement de scène) puis s'efface.
##
##   PHASE7_ROLE=guest godot --headless --path . res://tests/Phase7Net.tscn &
##   PHASE7_ROLE=host  godot --headless --path . res://tests/Phase7Net.tscn

const RUNNER: String = "res://tests/Phase7NetRunner.gd"


func _ready() -> void:
	var runner := Node.new()
	runner.name = "Phase7NetRunner"
	runner.set_script(load(RUNNER))
	# La racine est encore occupée à installer la scène : on attend une frame.
	get_tree().root.add_child.call_deferred(runner)
