extends Node
## Réglages (DOSSIER.md § 16 « Réglages » et § 25 « Qualité »). Persistés dans
## SaveManager.data["settings"] et appliqués immédiatement (bus audio dès PHASE 0,
## échelle de rendu 3D dès PHASE 1 quand la 3D est réelle).

## PHASE 8 : les niveaux écoutent ce signal pour appliquer tout de suite un
## changement de qualité (ombre, contour, particules) sans recharger la scène.
signal quality_changed(quality: String)

var music_volume: float = 0.8
var sfx_volume: float = 0.8
var voice_volume: float = 0.8
var button_scale: float = 1.0        ## taille du HUD tactile (0,8 à 1,3, § 7)
var button_opacity: float = 0.6      ## opacité du HUD tactile (0,2 à 1,0)
var swap_sticks: bool = false        ## inversion gauche/droite du joystick et des actions
var vibration: bool = true           ## Input.vibrate_handheld sur coup réussi (§ 7)
var language: String = "fr"          ## "fr" / "en" / "fon" (fichiers .po en PHASE 8)
var quality: String = "medium"       ## "low" / "medium" / "high" (§ 25)
var scale_3d: float = 0.8            ## 0,6 à 1,0 (§ 4) ; appliqué en PHASE 1
## § 16 : la difficulté se choisit dans les Réglages et s'applique au niveau
## suivant (Facile ×0,7 vie et dégâts, Difficile ×1,3 — § 9 du DOSSIER).
var difficulty: String = "normal"
## ANNEXE §7 : palier de difficulté persistant ("" = ancienne difficulté).
var tier: String = ""
## Dernier choix explicite de l'ancienne difficulté : il est restauré quand on
## repasse le palier à « Aucun (historique) ».
var legacy_difficulty: String = "normal"
## ANNEXE §2.3 : densité de foule (0,25 / 0,5 / 1,0) selon la qualité.
var crowd_density_override: float = 0.0


func _ready() -> void:
	_load()


func _load() -> void:
	var s: Dictionary = SaveManager.data.get("settings", {})
	# La langue enregistrée s'applique avant tout écran (Localizer lit
	# `Settings.language` à son propre _ready).
	TranslationServer.set_locale(str(s.get("language", "fr")))
	music_volume = float(s.get("music_volume", 0.8))
	sfx_volume = float(s.get("sfx_volume", 0.8))
	voice_volume = float(s.get("voice_volume", 0.8))
	button_scale = float(s.get("button_scale", 1.0))
	button_opacity = float(s.get("button_opacity", 0.6))
	swap_sticks = bool(s.get("swap_sticks", false))
	vibration = bool(s.get("vibration", true))
	language = str(s.get("language", "fr"))
	quality = str(s.get("quality", "medium"))
	scale_3d = float(s.get("scale_3d", 0.8))
	difficulty = str(s.get("difficulty", "normal"))
	legacy_difficulty = str(s.get("legacy_difficulty", difficulty))
	tier = str(s.get("tier", ""))
	crowd_density_override = float(s.get("crowd_density_override", 0.0))
	GameState.difficulty = difficulty
	if tier != "" and not GameState.use_tier(tier):
		tier = ""
	apply_audio_volumes()


func save() -> void:
	SaveManager.data["settings"] = {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"voice_volume": voice_volume,
		"button_scale": button_scale,
		"button_opacity": button_opacity,
		"swap_sticks": swap_sticks,
		"vibration": vibration,
		"language": language,
		"quality": quality,
		"scale_3d": scale_3d,
		"difficulty": difficulty,
		"legacy_difficulty": legacy_difficulty,
		"tier": tier,
		"crowd_density_override": crowd_density_override,
	}
	SaveManager.save_game()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply_audio_volumes()
	save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio_volumes()
	save()


func set_voice_volume(v: float) -> void:
	voice_volume = clampf(v, 0.0, 1.0)
	apply_audio_volumes()
	save()


func set_quality(q: String) -> void:
	## Faible : échelle 0,6, pas d'outline, particules réduites (§ 25).
	## Moyenne : 0.8. Haute : 1.0 + ombre de la joueuse + outline (PHASE 9).
	match q:
		"low":
			scale_3d = 0.6
		"high":
			scale_3d = 1.0
		_:
			q = "medium"
			scale_3d = 0.8
	quality = q
	apply_3d_scale()
	quality_changed.emit(quality)
	save()


func apply_audio_volumes() -> void:
	# Évite linear_to_db(0.0) = -inf quand un volume est à zéro.
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Voice"), linear_to_db(maxf(voice_volume, 0.0001)))


## ANNEXE §7.1 : choisir un palier remplace l'ancienne difficulté à 3 valeurs.
func set_tier(value: String) -> bool:
	if value != "" and not GameState.use_tier(value):
		return false
	if value == "":
		# Retour à l'ancienne difficulté : on restaure le dernier choix
		# explicite, pas un « Normal » imposé.
		GameState.tier = null
		difficulty = legacy_difficulty
		GameState.difficulty = difficulty
	tier = value
	if value != "":
		difficulty = GameState.difficulty
	save()
	return true


## ANNEXE §2.3 : densité de la foule en MultiMesh. Faible 0,25, Moyenne 0,5,
## Haute 1,0 (60 / 150 / 300 spectateurs).
func crowd_density() -> float:
	if crowd_density_override > 0.0:
		return clampf(crowd_density_override, 0.0, 1.0)
	match quality:
		"low":
			return 0.25
		"high":
			return 1.0
		_:
			return 0.5


func set_difficulty(value: String) -> void:
	if value not in ["easy", "normal", "hard"]:
		value = "normal"
	# L'ancien réglage reprend la main : on quitte le palier de l'ANNEXE §7.
	tier = ""
	GameState.clear_tier()
	difficulty = value
	legacy_difficulty = value
	GameState.difficulty = value
	save()


func set_button_scale(value: float) -> void:
	button_scale = clampf(value, 0.8, 1.3)
	_apply_touch_buttons()
	save()


func set_button_opacity(value: float) -> void:
	button_opacity = clampf(value, 0.2, 1.0)
	_apply_touch_buttons()
	save()


func set_vibration(value: bool) -> void:
	vibration = value
	save()


func set_language(value: String) -> void:
	if value not in ["fr", "en", "fon"]:
		value = "fr"
	language = value
	save()
	# § 24 : la langue change sans redémarrer le jeu.
	var localizer := get_node_or_null("/root/Localizer")
	if localizer != null:
		localizer.call("apply", language)


func set_scale_3d(value: float) -> void:
	scale_3d = clampf(value, 0.6, 1.0)
	apply_3d_scale()
	save()


## Les boutons tactiles lisent `button_scale` à leur `_ready` ; ce relais
## applique un changement de taille pendant la partie (§ 7).
func _apply_touch_buttons() -> void:
	for node in get_tree().get_nodes_in_group("touch_button"):
		if node.has_method("apply_settings"):
			node.call("apply_settings")


func apply_3d_scale() -> void:
	## S'applique dès PHASE 1 quand le rendu 3D est actif.
	get_viewport().scaling_3d_scale = clampf(scale_3d, 0.6, 1.0)
