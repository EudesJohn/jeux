extends Resource
class_name SpawnEntry
## Une ligne de vague (DESIGN.md § 20.11) : « 3 soldats », « 1 archer »…
## `type` est un identifiant d'ennemi de `data/enemies/` (soldier, scout,
## archer, brute, chief, guard) ; la casse est ignorée.

@export_enum("soldier", "scout", "archer", "brute", "chief", "guard")
var type: String = "soldier"
@export_range(0, 20, 1) var count: int = 1
