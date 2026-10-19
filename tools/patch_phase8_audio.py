# -*- coding: utf-8 -*-
"""Patchs de la PHASE 8 (audio) — idempotent, supprimé après usage."""
import pathlib


def edit(path, subs):
    p = pathlib.Path(path)
    raw = p.read_bytes().decode("utf-8")
    nl = "\r\n" if "\r\n" in raw else "\n"
    for old, new in subs:
        old = old.replace("\n", nl)
        new = new.replace("\n", nl)
        if old not in raw:
            if new in raw:
                continue
            raise AssertionError((path, old[:80]))
        raw = raw.replace(old, new, 1)
    p.write_bytes(raw.encode("utf-8"))
    print("ok", path)


# ---------------------------------------------------------------- AudioDirector
edit("scripts/audio/AudioDirector.gd", [(
"""var level: LevelBase3D = null
var player: Player3D = null""",
"""## Le directeur du niveau en cours : les scripts de combat (joueuse) s'y
## accrochent sans connaître la scène (§ 18 règle 3).
static var current: AudioDirector = null

var level: LevelBase3D = null
var player: Player3D = null"""),
("""func setup(level_node: LevelBase3D, player_node: Player3D) -> void:
	level = level_node
	player = player_node
	_last_position = player_node.global_position if player_node != null else Vector3.ZERO
	_connect_events()
	AudioManager.play_music_set(&"level")
	AudioManager.set_intensity(0.0)
	AudioManager.play_voice(&"level_start")""",
"""func setup(level_node: LevelBase3D, player_node: Player3D) -> void:
	current = self
	level = level_node
	_connect_events()
	AudioManager.play_music_set(&"level")
	AudioManager.set_intensity(0.0)
	AudioManager.play_voice(&"level_start")
	attach_player(player_node)


## En coop, la joueuse locale de l'invitée arrive après le décor (§ 22.2) :
## on la branche plus tard, sans relancer la musique ni la voix d'intro.
func attach_player(player_node: Player3D) -> void:
	player = player_node
	_last_position = player_node.global_position if player_node != null else Vector3.ZERO"""),
("""func _exit_tree() -> void:
	if Events.enemy_died.is_connected(_on_enemy_died):""",
"""func _exit_tree() -> void:
	if current == self:
		current = null
	if Events.enemy_died.is_connected(_on_enemy_died):"""),
])

# ---------------------------------------------------------------- LevelBase3D
edit("scripts/level/LevelBase3D.gd", [(
"""## PHASE 7 : coop WiFi (§ 22). Null hors coop : le niveau reste solo.
var coop: CoopDirector = null""",
"""## PHASE 7 : coop WiFi (§ 22). Null hors coop : le niveau reste solo.
var coop: CoopDirector = null
## PHASE 8 : musique et bruits du niveau (§ 17).
var audio: AudioDirector = null"""),
("""\t_build_boss()
\thud.bind_level(self)""",
"""\t_build_boss()
\t_setup_audio()
\thud.bind_level(self)"""),
("""## PHASE 7 : en coop, `CoopDirector` remplace la joueuse unique de la scène par
## une joueuse par pair et réplique les ennemis (§ 22.1).
func _setup_coop() -> void:""",
"""## PHASE 8 : un seul directeur audio par niveau ; il rejoue la musique à
## chaque niveau (l'intensité repart de zéro).
func _setup_audio() -> void:
\tif audio == null:
\t\taudio = AudioDirector.new()
\t\taudio.name = "Audio"
\t\tadd_child(audio)
\taudio.setup(self, player)


## PHASE 7 : en coop, `CoopDirector` remplace la joueuse unique de la scène par
## une joueuse par pair et réplique les ennemis (§ 22.1).
func _setup_coop() -> void:"""),
("""func _on_coop_player_ready(new_player: Player3D) -> void:
\tplayer = new_player
\tplayer.died.connect(_on_player_died)""",
"""func _on_coop_player_ready(new_player: Player3D) -> void:
\tplayer = new_player
\tif audio != null:
\t\taudio.attach_player(player)
\tplayer.died.connect(_on_player_died)"""),
("""func _win() -> void:
\tif completed:
\t\treturn
\tcompleted = true""",
"""func _win() -> void:
\tif completed:
\t\treturn
\tcompleted = true
\tif audio != null:
\t\taudio.victory()"""),
("""\tif hud != null:
\t\thud.show_result(\"ÉCHEC — \" + reason, 0)""",
"""\tif audio != null:
\t\taudio.defeat()
\tif hud != null:
\t\thud.show_result(\"ÉCHEC — \" + reason, 0)"""),
])

# ---------------------------------------------------------------- Player3D
edit("scripts/characters/Player3D.gd", [(
"""func _on_hit_landed(_target: Node, _damage: float) -> void:
\tadd_energy(balance.energy_per_hit)   # § 8.5 : +6 par coup donné
\tif Settings.vibration:""",
"""func _on_hit_landed(_target: Node, _damage: float) -> void:
\tadd_energy(balance.energy_per_hit)   # § 8.5 : +6 par coup donné
\tif AudioDirector.current != null:
\t\tAudioDirector.current.hit_landed(hitbox.last_critical)
\tif Settings.vibration:"""),
("""func _start_step(step_index: int) -> void:""",
"""func _start_step(step_index: int) -> void:
\t# § 17 : sifflement du sabre, un peu plus grave au 3e coup.
\tif AudioDirector.current != null:
\t\tAudioDirector.current.swing(1.0 + 0.08 * float(step_index))"""),
])

# ---------------------------------------------------------------- Pickup3D
edit("scripts/pickups/Pickup3D.gd", [(
"""\tcollected.emit(self, actor)""",
"""\t# § 17 : cauris (cloche) ou potion, deux timbres distincts.
\tAudioManager.play_sfx(&\"potion\" if kind == Kind.POTION else &\"cauri\",
\t\trandf_range(0.97, 1.05))
\tcollected.emit(self, actor)"""),
])

# ---------------------------------------------------------------- EnemyBase3D
edit("scripts/ai/EnemyBase3D.gd", [(
"""\thealth = maxf(0.0, health - info.amount)
\tFX.damage_number(_world(), global_position + Vector3(0.0, 1.7, 0.0), info.amount,
\t\t\"crit\" if info.is_critical else \"normal\")""",
"""\thealth = maxf(0.0, health - info.amount)
\t# § 17 : le son de l'ennemi est positionnel (portée courte, 8 voix max).
\tAudioManager.play_sfx_at(self, &\"hurt\", randf_range(0.92, 1.08))
\tFX.damage_number(_world(), global_position + Vector3(0.0, 1.7, 0.0), info.amount,
\t\t\"crit\" if info.is_critical else \"normal\")"""),
("""func _state_telegraph(delta: float) -> void:""",
"""func _state_telegraph(delta: float) -> void:
\t# § 17 : grognement au télégraphe — le son signale le coup autant que la
\t# couleur du modèle, c'est ce qui rend l'attaque lisible au doigt.
\tif _state_time <= delta:
\t\tAudioManager.play_sfx_at(self, &\"hurt\", randf_range(0.62, 0.72))"""),
])

# ---------------------------------------------------------------- BossBase3D
edit("scripts/ai/BossBase3D.gd", [(
"""func _begin_telegraph(kind: String) -> void:""",
"""func _begin_telegraph(kind: String) -> void:
\t# § 17 : le gardien rugit avant chaque attaque (audio 3D).
\tAudioManager.play_sfx_at(self, &\"boss_roar\", randf_range(1.05, 1.2))"""),
])

print("terminé")
