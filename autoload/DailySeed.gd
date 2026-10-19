extends Node
## Défi du jour (DOSSIER.md § 12.5) : niveau généré par la date du téléphone
## (graine AAAAMMJJ), même comportement sur 2 téléphones le même jour.
##
## PHASE 8 : les **objectifs journaliers** vivent ici aussi. Trois buts tirés de
## la date, suivis séparément des compteurs de succès (ils repartent de zéro
## chaque jour) et payés 150 cauris quand les trois sont atteints.

signal goal_completed(goal: Dictionary)
signal goals_all_completed(reward: int)
signal streak_changed(streak: int)

## Cauris offerts quand les trois buts du jour sont atteints.
const REWARD_CAURIS := 150
const GOAL_COUNT := 3

## Réserve de buts. `targets` = palier facile / moyen / difficile ; le palier
## choisi dépend de la date, donc les trois buts changent chaque jour mais
## restent identiques sur tous les téléphones du même jour.
const POOL: Array[Dictionary] = [
	{"stat": "kills", "title": "Vaincre %d ennemis aujourd'hui.",
		"targets": [10, 20, 30]},
	{"stat": "perfect_guards", "title": "Réussir %d gardes parfaites aujourd'hui.",
		"targets": [5, 10, 15]},
	{"stat": "rescued", "title": "Libérer %d prisonniers aujourd'hui.",
		"targets": [2, 4, 6]},
	{"stat": "levels", "title": "Terminer %d niveau(x) aujourd'hui.",
		"targets": [1, 2, 3]},
	{"stat": "survival_waves", "title": "Tenir %d vagues en Survie aujourd'hui.",
		"targets": [3, 5, 8]},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_today()
	Events.enemy_died.connect(_on_enemy_died)
	Events.perfect_guard.connect(_on_perfect_guard)
	Events.prisoner_freed.connect(_on_prisoner_freed)
	Events.level_completed.connect(_on_level_completed)


func today_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day


# -----------------------------------------------------------------#
#                     SÉRIE DE JOURS (§ 12.5)                     #
# -----------------------------------------------------------------#

## Marque le résultat du jour dans SaveManager (streak § 12.5).
func record_daily_result(win: bool) -> void:
	if not win:
		return
	var daily: Dictionary = SaveManager.data["daily"]
	if int(daily.get("last_date", 0)) == today_seed():
		return
	var yesterday: int = today_seed() - 1
	if int(daily.get("last_date", 0)) == yesterday:
		daily["streak"] = int(daily.get("streak", 0)) + 1
	else:
		daily["streak"] = 1
	daily["last_date"] = today_seed()
	SaveManager.save_game()
	streak_changed.emit(int(daily["streak"]))
	Achievements.set_at_least("daily_streak", int(daily["streak"]))


func streak() -> int:
	return int(SaveManager.data.get("daily", {}).get("streak", 0))


# -----------------------------------------------------------------#
#                    OBJECTIFS JOURNALIERS                        #
# -----------------------------------------------------------------#

## Les trois buts du jour : [{stat, title, target, progress, done}].
## Le calcul est fait à partir de la graine de la date, sans hasard : deux
## téléphones du même jour affichent les mêmes buts.
func goals() -> Array[Dictionary]:
	var state := ensure_today()
	var seed := today_seed()
	var result: Array[Dictionary] = []
	var used: Array[int] = []
	for i in GOAL_COUNT:
		var index := (seed + i * 7 + (seed / 100) % 5) % POOL.size()
		# Évite deux buts sur le même compteur le même jour.
		while used.has(index):
			index = (index + 1) % POOL.size()
		used.append(index)
		var entry: Dictionary = POOL[index]
		var targets: Array = entry["targets"]
		var target := int(targets[(seed / (i + 1)) % targets.size()])
		var stat_name := String(entry["stat"])
		var progress := int(state["progress"].get(stat_name, 0))
		result.append({
			"stat": stat_name,
			"title": String(entry["title"]),
			"target": target,
			"progress": mini(progress, target),
			"done": progress >= target,
		})
	return result


## Ligne lisible d'un but : « Vaincre 20 ennemis aujourd'hui.  (7/20) ».
func goal_line(goal: Dictionary) -> String:
	return "%s  (%d/%d)" % [
		Localizer.format_tr(String(goal["title"]), [int(goal["target"])]),
		int(goal["progress"]), int(goal["target"])]


func goals_done() -> int:
	var count := 0
	for goal in goals():
		if bool(goal["done"]):
			count += 1
	return count


func reward_claimed() -> bool:
	return bool(ensure_today().get("claimed", false))


## Progression du jour d'un compteur (repart de zéro chaque jour).
func progress(stat_name: String) -> int:
	return int(ensure_today()["progress"].get(stat_name, 0))


## Ajoute de la progression du jour ; déclenche les récompenses le cas échéant.
func add_progress(stat_name: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	var state := ensure_today()
	var wanted: Array[String] = []
	for goal in goals():
		if String(goal["stat"]) == stat_name:
			wanted.append(stat_name)
	if wanted.is_empty():
		return                                    # ce compteur n'est pas du jour
	var progress_dict: Dictionary = state["progress"]
	var before := int(progress_dict.get(stat_name, 0))
	progress_dict[stat_name] = before + amount
	SaveManager.save_game()
	for goal in goals():
		if String(goal["stat"]) == stat_name and before < int(goal["target"]) \
				and int(progress_dict[stat_name]) >= int(goal["target"]):
			goal_completed.emit(goal)
	_check_reward()


## Verse la récompense UNE fois par jour, quand les trois buts sont atteints.
func _check_reward() -> void:
	var state := ensure_today()
	if bool(state.get("claimed", false)):
		return
	for goal in goals():
		if not bool(goal["done"]):
			return
	state["claimed"] = true
	SaveManager.add_cauris(REWARD_CAURIS)
	goals_all_completed.emit(REWARD_CAURIS)


## Remet la progression du jour à zéro au changement de date. Renvoie l'état.
func ensure_today() -> Dictionary:
	var daily: Dictionary = SaveManager.data["daily"]
	var state: Dictionary = daily.get("goals", {})
	if int(state.get("date", 0)) != today_seed():
		state = {"date": today_seed(), "progress": {}, "claimed": false}
		daily["goals"] = state
		SaveManager.data["daily"] = daily
		SaveManager.save_game()
	return state


# -----------------------------------------------------------------#
#                      SIGNAUX DU GAMEPLAY                        #
# -----------------------------------------------------------------#

func _on_enemy_died(enemy: Node) -> void:
	if enemy is BossBase3D:
		return
	add_progress("kills")


func _on_perfect_guard(_actor: Node) -> void:
	add_progress("perfect_guards")


func _on_prisoner_freed(_prisoner: Node) -> void:
	add_progress("rescued")


func _on_level_completed(_level_id: String, _stars: int) -> void:
	add_progress("levels")
