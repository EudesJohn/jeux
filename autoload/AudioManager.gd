extends Node
## Audio (DESIGN.md § 17, § 25, § 12.10). Tout le son passe par ici.
##
## * **Musique dynamique** : 3 couches de tambours (calme / tension / combat)
##   strictement alignées (même tempo, même longueur de boucle) ; l'intensité
##   (§ 17 : nombre d'ennemis et vie) fait monter ou descendre les couches 2 et
##   3, avec un **crossfade de 0,5 s**. L'écran d'accueil a son propre morceau.
## * **SFX** : banque chargée UNE fois au démarrage (§ 18 règle 6 : jamais de
##   `load()` en plein combat) et lue par un pool de 12 lecteurs sur le bus SFX.
## * **Audio 3D** : les sons des ennemis partent d'un pool de 8
##   `AudioStreamPlayer3D` (§ 25 : « limité à 8 voix »), portée courte, sans
##   réverbération ; le bus reste le même, seul le placement change.
## * **Voix** : emplacements vides (les enregistrements en fon viendront de
##   locuteurs natifs, § 31). Le sous-titre s'affiche même sans fichier : le HUD
##   écoute `voice_line`.
##
## Les buses `Music`, `SFX`, `Voice` existent depuis la PHASE 0 et leurs volumes
## sont réglés par `Settings`.

signal music_set_changed(music_set: StringName)
## § 17 : sous-titres des voix (le HUD les affiche via `tr("VOICE_<ligne>")`).
signal voice_line(line_id: StringName)
## Intensité courante (0 = calme, 1 = combat), pour les tests et le HUD debug.
signal intensity_changed(value: float)

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const VOICE_DIR := "res://assets/audio/voice/"

const MUSIC_FADE: float = 0.5              ## § 17 : crossfade 0,5 s
const SFX_POOL_SIZE: int = 12              ## § 25
const VOICES_3D: int = 8                   ## § 25 : 8 voix positionnelles max
const SFX_3D_DISTANCE: float = 14.0        ## portée courte des ennemis
const SILENT_DB: float = -60.0

## Les 3 couches superposables, dans l'ordre d'apparition (§ 17).
const LAYERS: Array[StringName] = [&"calm", &"tension", &"combat"]
## Seuils d'intensité d'entrée/sortie de chaque couche (avec recouvrement : le
## crossfade se fait couche par couche, jamais en coup de hache).
const LAYER_RANGE := {
	&"tension": Vector2(0.15, 0.55),
	&"combat": Vector2(0.60, 1.0),
}

## Lignes de voix prévues (§ 17). Les fichiers sont facultatifs : voir
## `assets/audio/voice/LISEZ-MOI.txt`.
const VOICE_LINES: Array[StringName] = [
	&"intro", &"level_start", &"low_health", &"revive", &"victory", &"defeat",
]

## Sons joués en positionnel (§ 17 : « sons des ennemis »).
const SFX_3D: Array[StringName] = [
	&"hit", &"hurt", &"death_enemy", &"boss_roar", &"guard_perfect", &"crit",
]

var current_set: StringName = &""
var intensity: float = 0.0
## Nombre de sons réellement refusés faute de fichier : les tests le lisent.
var missing_sounds: Array[StringName] = []

var _music_layers: Dictionary = {}              ## { couche: AudioStreamPlayer }
var _music_menu: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _sfx_bank: Dictionary = {}                  ## { StringName: AudioStream }
var _voice_bank: Dictionary = {}                ## { StringName: AudioStream }
var _layer_tweens: Dictionary = {}
var _fade_time: float = MUSIC_FADE


func _ready() -> void:
	_build_sfx_pool()
	_build_3d_pool()
	_load_bank("sfx", SFX_DIR, _sfx_bank)
	_load_voice_bank()
	_build_music()
	_load_music_streams()


# -----------------------------------------------------------------#
#                        MUSIQUE (§ 17)                             #
# -----------------------------------------------------------------#

func _build_music() -> void:
	# Un lecteur par couche + un pour l'écran d'accueil, tous sur le bus Music.
	for layer in LAYERS:
		var p := AudioStreamPlayer.new()
		p.name = "Music_%s" % layer
		p.bus = &"Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_music_layers[layer] = p
	_music_menu = AudioStreamPlayer.new()
	_music_menu.name = "Music_menu"
	_music_menu.bus = &"Music"
	_music_menu.volume_db = SILENT_DB
	add_child(_music_menu)


func _load_music_streams() -> void:
	var menu: AudioStream = _resource(MUSIC_DIR + "music_menu.wav")
	if menu != null:
		_music_menu.stream = _looped(menu)
	for layer in LAYERS:
		var stream: AudioStream = _resource(MUSIC_DIR + "layer_%s.wav" % layer)
		if stream == null:
			continue
		var player: AudioStreamPlayer = _music_layers[layer]
		player.stream = _looped(stream)


## § 17 : « 3 couches de tambours (calme / tension / combat) ». Le morceau de
## l'écran d'accueil remplace les couches ; le niveau les superpose.
func play_music_set(music_set: StringName) -> void:
	if music_set == current_set:
		return
	current_set = music_set
	music_set_changed.emit(music_set)
	_fade_time = MUSIC_FADE
	if music_set == &"menu":
		_start_menu_music()
		return
	if music_set == &"none":
		_fade_all(0.0)
		return
	_start_layer_music()


func _start_menu_music() -> void:
	for layer in LAYERS:
		_fade_channel(_music_layers[layer], 0.0)
	if _music_menu.stream == null:
		return
	if not _music_menu.playing:
		_music_menu.play()
	_fade_channel(_music_menu, 1.0)


func _start_layer_music() -> void:
	_fade_channel(_music_menu, 0.0)
	var started := false
	for layer in LAYERS:
		var player: AudioStreamPlayer = _music_layers[layer]
		if player.stream != null and not player.playing:
			# Toutes les couches démarrent au même instant : elles restent
			# alignées à l'échantillon près, c'est ce qui permet de les fondre.
			player.play(0.0)
			started = true
	if started:
		_apply_intensity(intensity, true)
	else:
		_apply_intensity(intensity, false)


func stop_music() -> void:
	play_music_set(&"none")


## Intensité 0 à 1 (§ 17 : « selon nombre d'ennemis et vie »). Les couches 2 et
## 3 apparaissent en fondu : jamais de saut brutal.
func set_intensity(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, intensity):
		return
	intensity = value
	intensity_changed.emit(intensity)
	if current_set == &"level":
		_apply_intensity(intensity, true)


func _apply_intensity(value: float, animate: bool) -> void:
	var gains := {&"calm": 1.0}
	for layer in LAYERS:
		if layer == &"calm":
			continue
		var span: Vector2 = LAYER_RANGE[layer]
		var raw := inverse_lerp(span.x, span.y, value)
		gains[layer] = clampf(raw, 0.0, 1.0)
	_fade_many(gains, animate)


func _fade_many(gains: Dictionary, animate: bool) -> void:
	for layer in gains:
		if not _music_layers.has(layer):
			continue
		_fade_channel(_music_layers[layer], float(gains[layer]), animate)


func _fade_all(gain: float) -> void:
	_fade_many({&"calm": gain, &"tension": gain, &"combat": gain}, true)
	_fade_channel(_music_menu, gain)


## Fondu d'un lecteur vers un gain linéaire. `animate` à faux : application
## immédiate (démarrage des couches, tests).
func _fade_channel(player: AudioStreamPlayer, gain: float, animate: bool = true) -> void:
	var target := SILENT_DB if gain <= 0.001 else linear_to_db(gain)
	if not animate:
		player.volume_db = target
		return
	var key := player.name
	if _layer_tweens.has(key) and _layer_tweens[key] is Tween:
		(_layer_tweens[key] as Tween).kill()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target, _fade_time)
	_layer_tweens[key] = tween


## Gain linéaire courant d'une couche (0 = muette) : utilisé par les tests.
func layer_gain(layer: StringName) -> float:
	if not _music_layers.has(layer):
		return 0.0
	var player: AudioStreamPlayer = _music_layers[layer]
	if player.volume_db <= SILENT_DB + 0.01:
		return 0.0
	return db_to_linear(player.volume_db)


func layer_playing(layer: StringName) -> bool:
	return _music_layers.has(layer) and (_music_layers[layer] as AudioStreamPlayer).playing


## Longueur de boucle commune aux 3 couches (le crossfade n'a de sens que si
## elles sont alignées) : lisible par les tests.
func layer_loop_length() -> float:
	var player: AudioStreamPlayer = _music_layers[LAYERS[0]]
	if player.stream == null:
		return 0.0
	return player.stream.get_length()


# -----------------------------------------------------------------#
#                            SFX                                    #
# -----------------------------------------------------------------#

func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SFX%d" % i
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)


func _build_3d_pool() -> void:
	for i in VOICES_3D:
		var p := AudioStreamPlayer3D.new()
		p.name = "SFX3D%d" % i
		p.bus = &"SFX"
		p.max_distance = SFX_3D_DISTANCE
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 4.0
		# § 17 : « sans réverbération » — le bus SFX n'a aucun effet.
		add_child(p)
		_pool_3d.append(p)


func register_sfx(sfx_name: StringName, stream: AudioStream) -> void:
	_sfx_bank[sfx_name] = stream


func has_sfx(sfx_name: StringName) -> bool:
	return _sfx_bank.has(sfx_name)


## Joue un bruitage. `pitch` (±0,2) évite l'effet « machine » sur les coups
## répétés. `pitch` et `volume_db` optionnels pour les voix et les pas.
func play_sfx(sfx_name: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not _sfx_bank.has(sfx_name):
		_note_missing(sfx_name)
		return null
	for player in _sfx_pool:
		if not player.playing:
			player.stream = _sfx_bank[sfx_name]
			player.pitch_scale = clampf(pitch, 0.5, 2.0)
			player.volume_db = volume_db
			player.play()
			return player
	return null


## Son des ennemis : positionné dans le monde (§ 17). Le son se place à la
## position MONDIALE passée ; s'il n'y a plus de voix libre, on abandonne le son
## plutôt que de saturer le mélange (§ 25).
func play_sfx_3d(sfx_name: StringName, world_position: Vector3,
		pitch: float = 1.0) -> AudioStreamPlayer3D:
	if not _sfx_bank.has(sfx_name):
		_note_missing(sfx_name)
		return null
	for player in _pool_3d:
		if not player.playing:
			player.stream = _sfx_bank[sfx_name]
			player.pitch_scale = clampf(pitch, 0.5, 2.0)
			player.global_position = world_position
			player.play()
			return player
	return null


## Même chose depuis un nœud 3D (l'appelant n'a pas à calculer la position).
func play_sfx_at(node: Node3D, sfx_name: StringName, pitch: float = 1.0) -> AudioStreamPlayer3D:
	if node == null or not is_instance_valid(node):
		return null
	return play_sfx_3d(sfx_name, node.global_position + Vector3(0.0, 1.0, 0.0), pitch)


func _note_missing(sfx_name: StringName) -> void:
	if not missing_sounds.has(sfx_name):
		missing_sounds.append(sfx_name)
		push_warning("AudioManager : son introuvable « %s »" % sfx_name)


# -----------------------------------------------------------------#
#                       VOIX ET SOUS-TITRES (§ 17)                  #
# -----------------------------------------------------------------#

func _load_voice_bank() -> void:
	for line in VOICE_LINES:
		for lang in ["fr", "en", "fon"]:
			var key := StringName("%s_%s" % [lang, line])
			var stream: AudioStream = _resource(VOICE_DIR + "%s.wav" % key)
			if stream == null:
				stream = _resource(VOICE_DIR + "%s.ogg" % key)
			if stream != null:
				_voice_bank[key] = stream


## Joue la ligne de voix dans la langue courante et émet le sous-titre. Sans
## fichier enregistré (cas normal aujourd'hui), seul le sous-titre sort.
func play_voice(line_id: StringName) -> void:
	voice_line.emit(line_id)
	var key := StringName("%s_%s" % [Settings.language, line_id])
	if not _voice_bank.has(key):
		key = StringName("fr_%s" % line_id)
	if not _voice_bank.has(key):
		return
	for player in _sfx_pool:
		if not player.playing:
			player.stream = _voice_bank[key]
			player.pitch_scale = 1.0
			player.volume_db = 0.0
			player.bus = &"Voice"
			player.play()
			return


func has_voice(line_id: StringName) -> bool:
	return _voice_bank.has(StringName("%s_%s" % [Settings.language, line_id]))


# -----------------------------------------------------------------#
#                            OUTILS                                 #
# -----------------------------------------------------------------#

func stop_all() -> void:
	for player in _sfx_pool + _pool_3d:
		player.stop()


## Son d'interface : un seul nom pour tous les Button du jeu.
func play_ui_click() -> void:
	play_sfx(&"ui_click", randf_range(0.96, 1.04), -6.0)


func _load_bank(kind: String, directory: String, target: Dictionary) -> void:
	# La liste des noms vit dans le code : aucun balayage de dossier (dans un
	# APK exporté les ressources sont en `.remap`/`.sample`, un scan échouerait).
	var names: Array[StringName] = []
	if kind == "sfx":
		names = _sfx_names()
	for sfx_name in names:
		var stream: AudioStream = _resource(directory + "%s.wav" % sfx_name)
		if stream == null:
			stream = _resource(directory + "%s.ogg" % sfx_name)
		if stream != null:
			target[sfx_name] = stream
		else:
			_note_missing(sfx_name)


func _sfx_names() -> Array[StringName]:
	return [
		&"hit", &"crit", &"block", &"guard_perfect", &"dodge", &"swing",
		&"special", &"hurt", &"death_enemy", &"death_player", &"boss_roar",
		&"cauri", &"potion", &"unlock", &"step", &"ui_click", &"victory",
		&"defeat",
	]


func _resource(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


## Les boucles WAV sont importées en « une fois » : on force la répétition ici
## (ça marche aussi dans un APK exporté, où l'on ne peut pas éditer l'import).
func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# En échantillons, indépendamment du format d'échantillon.
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	return stream
