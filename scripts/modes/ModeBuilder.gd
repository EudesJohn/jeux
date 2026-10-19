extends RefCounted
class_name ModeBuilder
## Fiches de niveau FABRIQUÉES par le code (aucun `.tres` à maintenir) pour les
## modes du § 12 qui n'ont pas de campagne :
##  * Survie (§ 12.3) : arène, vagues sans fin, bonus entre les vagues ;
##  * Chasse aux boss (§ 12.4) : enchaînement des gardiens déjà vaincus ;
##  * Défi du jour (§ 12.5) : arène semée par la date du téléphone + modificateur.
##
## Les fiches produites sont des `LevelData` normales : `LevelBase3D` les joue
## exactement comme un niveau de campagne (§ 18 règle 2).

## § 12.5 : les modificateurs du jour. Un seul par date.
const DAILY_MODIFIERS: Array[String] = ["damage", "night", "fast", "one_life"]

const DAILY_LABELS: Dictionary = {
	"damage": "dégâts ennemis doublés",
	"night": "nuit",
	"fast": "ennemis rapides",
	"one_life": "une seule vie",
}


## § 12.3 : Survie — arène de 15 m, pas de temps limite, vagues sans fin.
static func survival_data() -> LevelData:
	var data := LevelData.new()
	data.id = "survival"
	data.chapter = 0
	data.number = 0
	data.display_name = "Survie"
	data.layout = "arena"
	data.arena_radius = 15.0
	data.objective = "survive"
	data.time_limit = 0                 ## jamais de fin par le temps
	data.endless = true
	data.prisoners = 0
	data.escorts = 0
	data.hazards = []
	data.cauri_pickups = 4
	data.cauri_per_pickup = 3
	data.potion_pickups = 2
	data.checkpoint_at = 0.0
	data.night = false
	data.modifier = ""
	data.music_layer_set = "palace"
	data.reward_cauris = 0
	data.star_time_silver = 0
	data.star_time_gold = 0
	# Première vague : le spawner prend le relais ensuite (endless).
	var wave := WaveData.new()
	var entry := SpawnEntry.new()
	entry.type = "soldier"
	entry.count = 2
	wave.enemies = [entry] as Array[SpawnEntry]
	wave.delay = 1.3
	wave.start_delay = 0.8
	data.enemy_waves = [wave] as Array[WaveData]
	return data


## § 12.4 : Chasse aux boss — les gardiens déjà vaincus, l'un après l'autre,
## sans pause et avec 2 potions. Vide = le capitaine, pour apprendre.
static func boss_rush_data(ids: Array[String] = []) -> LevelData:
	var chain: Array[String] = []
	for boss_id in ids:
		chain.append(boss_id)
	if chain.is_empty():
		chain = BossRegistry.unlocked_for_rush()
	var data := LevelData.new()
	data.id = "boss_rush"
	data.chapter = 0
	data.number = 0
	data.display_name = "Chasse aux boss"
	data.layout = "arena"
	data.arena_radius = 15.0
	data.objective = "boss"
	data.time_limit = 0
	data.boss_id = chain[0]
	var rest: Array[String] = []
	for i in range(1, chain.size()):
		rest.append(chain[i])
	data.boss_chain = rest
	data.hazards = []
	data.cauri_pickups = 6
	data.cauri_per_pickup = 3
	data.potion_pickups = 2             ## § 12.4 : « 2 potions »
	data.checkpoint_at = 0.0
	data.music_layer_set = "palace"
	data.reward_cauris = 30 * chain.size()
	return data


## § 12.5 : Défi du jour — même graine = même niveau sur tous les téléphones.
static func daily_data(seed_date: int = 0) -> LevelData:
	var date_seed := seed_date
	if date_seed == 0:
		date_seed = DailySeed.today_seed()
	var rng := RandomNumberGenerator.new()
	rng.seed = date_seed
	var modifier: String = DAILY_MODIFIERS[rng.randi_range(0, DAILY_MODIFIERS.size() - 1)]
	var data := LevelData.new()
	data.id = "daily_%d" % date_seed
	data.chapter = 0
	data.number = 0
	data.display_name = "Défi du jour — %s" % String(DAILY_LABELS.get(modifier, modifier))
	data.layout = "arena"
	data.arena_radius = 14.0
	data.objective = "survive"
	data.time_limit = 90
	data.modifier = modifier
	data.night = modifier == "night"
	data.hazards = ["pit", "fire"]
	data.hazards_per_kind = 2
	data.cauri_pickups = 6
	data.cauri_per_pickup = 3
	data.potion_pickups = 1
	data.checkpoint_at = 0.0             ## « une seule vie » : pas de secours
	data.music_layer_set = "palace"
	data.reward_cauris = 80
	data.star_time_silver = 50
	data.star_time_gold = 30
	# Vagues proportionnelles à la graine : 3 vagues de difficulté croissante.
	var waves: Array[WaveData] = []
	for i in 3:
		var wave := WaveData.new()
		var entries: Array[SpawnEntry] = []
		entries.append(_entry("soldier", 2 + i + rng.randi_range(0, 1)))
		if i >= 1:
			entries.append(_entry("scout", 1 + i))
		if i >= 2:
			entries.append(_entry("archer", 1))
		wave.enemies = entries
		wave.delay = 1.2 - 0.1 * float(i)
		wave.start_delay = 0.6
		waves.append(wave)
	data.enemy_waves = waves
	return data


static func _entry(type_name: String, count: int) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.type = type_name
	entry.count = count
	return entry


## Libellé lisible d'un modificateur (§ 12.5), pour le HUD et les tests.
static func modifier_label(modifier: String) -> String:
	return String(DAILY_LABELS.get(modifier, modifier))
