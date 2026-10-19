extends Objective
class_name KillBossObjective
## Objectif « boss » (§ 12.2, PHASE 4 : squelette ; les 5 boss arrivent en
## PHASE 6 avec `BossBase3D`). Le niveau pose son gardien et lève
## `boss_defeated` : l'objectif ne fait que le lire.


func boss_defeated() -> bool:
	return level != null and level.get("boss_defeated") == true


func success() -> bool:
	return boss_defeated()


func progress() -> float:
	return 1.0 if boss_defeated() else 0.0


func bonus_achieved() -> bool:
	## § 13 : ★★★ pour un boss vaincu sans tomber sous 50 % de vie.
	return success() and level != null and float(level.call("health_ratio")) >= 0.5


func description() -> String:
	return "Vaincre le boss"
