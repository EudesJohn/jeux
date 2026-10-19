extends Objective
class_name ClearWaves
## Objectif « clear » (PHASE 3) : vider toutes les vagues du `WaveSpawner3D`.
## Le niveau se termine quand plus aucune vague n'attend et que le champ est vide.

var cleared_waves: int = 0
var total_waves: int = 0
var spawned_total: int = 0


func start() -> void:
	var spawner := _spawner()
	if spawner == null:
		return
	total_waves = spawner.total_waves()
	spawner.wave_cleared.connect(_on_wave_cleared)


func _on_wave_cleared(_index: int) -> void:
	cleared_waves += 1


func success() -> bool:
	var spawner := _spawner()
	if spawner == null:
		return false
	if not spawner.finished:
		return false
	return spawner.living().is_empty()


func progress() -> float:
	var spawner := _spawner()
	if spawner == null or total_waves <= 0:
		return 0.0
	var done := float(cleared_waves)
	if spawner.finished and spawner.living().is_empty():
		done = float(total_waves)
	return clampf(done / float(total_waves), 0.0, 1.0)


func description() -> String:
	return "Éliminer tous les ennemis (%d / %d vagues)" % [cleared_waves, maxi(total_waves, 1)]


func _spawner() -> WaveSpawner3D:
	if level == null:
		return null
	return level.get("spawner") as WaveSpawner3D
