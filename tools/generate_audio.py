"""Génère les assets audio provisoires du § 17 (WAV mono 22 050 Hz, 16 bits).

    python tools/generate_audio.py

Aucun enregistrement réel n'existe encore : ce script SYNTHÉTISE des tambours,
calebasses, cloches et bruitages pour que le jeu ne soit pas muet. Les vrais
fichiers (tambours joués, voix en fon par des locuteurs natifs, § 31) se
déposent aux MÊMES noms sans toucher au code.

Détails utiles :
* Les boucles de musique sont rendues avec **report de la traîne** au début du
  tampon (« wrap ») : le fondu de fin tombe au tout début du tour suivant, la
  boucle est donc parfaitement raccord.
* 100 BPM, 4 temps par mesure : la mesure fait 2,4 s, une boucle de 2 mesures
  4,8 s. Les 3 couches d'un même morceau sont TOUJOURS alignées (on peut les
  superposer et les enchaîner en fondu).
"""

import math
import os
import random
import struct
import wave

RATE = 22050
BPM = 100.0
BEAT = 60.0 / BPM                  # 0,6 s
BAR = BEAT * 4                     # 2,4 s
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "assets", "audio")


# ------------------------------------------------------------------ #
#                        PETITS SYNTHÉS                              #
# ------------------------------------------------------------------ #

def kick(t: float, gain: float = 1.0) -> float:
    """Grosse caisse : sinus qui descend de 90 à 45 Hz."""
    f = 45.0 + 45.0 * math.exp(-t * 28.0)
    env = math.exp(-t * 16.0)
    return math.sin(2.0 * math.pi * f * t) * env * gain


def shaker(t: float, gain: float = 1.0, rng: random.Random = None) -> float:
    """Calebasse : bruit bref, éclairci par une différence (passe-haut)."""
    r = rng or random
    n = r.uniform(-1.0, 1.0)
    return n * math.exp(-t * 55.0) * gain


def snare(t: float, gain: float = 1.0, rng: random.Random = None) -> float:
    r = rng or random
    noise = r.uniform(-1.0, 1.0) * math.exp(-t * 24.0)
    tone = math.sin(2.0 * math.pi * 185.0 * t) * math.exp(-t * 26.0) * 0.4
    return (noise + tone) * gain


def bell(t: float, freq: float = 880.0, gain: float = 1.0) -> float:
    """Cloche : partiels inharmoniques (2,76 et 5,4 × la fondamentale)."""
    env = math.exp(-t * 2.6)
    value = math.sin(2.0 * math.pi * freq * t)
    value += 0.4 * math.sin(2.0 * math.pi * freq * 2.76 * t) * math.exp(-t * 4.0)
    value += 0.2 * math.sin(2.0 * math.pi * freq * 5.40 * t) * math.exp(-t * 6.0)
    return value * env * 0.5 * gain


def tone(t: float, freq: float, gain: float = 1.0, decay: float = 6.0) -> float:
    return math.sin(2.0 * math.pi * freq * t) * math.exp(-t * decay) * gain


def sweep(t: float, f0: float, f1: float, gain: float = 1.0,
          decay: float = 6.0) -> float:
    """Sifflement d'épée / esquive : fréquence glissante."""
    k = decay
    f = f1 + (f0 - f1) * math.exp(-t * 8.0)
    return math.sin(2.0 * math.pi * f * t) * math.exp(-t * k) * gain


def noise(t: float, gain: float = 1.0, decay: float = 12.0,
          rng: random.Random = None) -> float:
    r = rng or random
    return r.uniform(-1.0, 1.0) * math.exp(-t * decay) * gain


# ------------------------------------------------------------------ #
#                        RENDU ET ÉCRITURE                           #
# ------------------------------------------------------------------ #

def render(duration: float, voice, wrap: bool = False) -> list:
    """Échantillonne `voice(t)`. `wrap` : la traîne repasse au début (boucle)."""
    total = int(duration * RATE)
    tail = int(min(0.35, duration * 0.2) * RATE)
    buf = [0.0] * total
    for i in range(total + (tail if wrap else 0)):
        sample = voice(i / RATE)
        j = i % total if wrap else i
        if j < total:
            buf[j] += sample
    return buf


def normalize(buf: list, peak: float = 0.7) -> list:
    top = max((abs(v) for v in buf), default=0.0)
    if top <= 1e-6:
        return buf
    scale = peak / top
    return [v * scale for v in buf]


def write_wav(path: str, buf: list) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32000)) for v in buf)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    print("%6.0f Ko  %s" % (len(data) / 1024.0, os.path.relpath(path)))


def mix(buf: list, voice, at: float, duration: float) -> None:
    """Ajoute `voice` (rendue sur `duration`) à l'échantillon `at` du tampon."""
    start = int(at * RATE)
    piece = render(duration, voice)
    for i, v in enumerate(piece):
        j = (start + i) % len(buf)
        buf[j] += v


# ------------------------------------------------------------------ #
#                            MUSIQUE                                 #
# ------------------------------------------------------------------ #

LOOP = BAR * 2                     # 4,8 s : 2 mesures
BEATS = 8                          # 8 temps par boucle


def music_layer(kind: str, bars: int = 2) -> list:
    """Une couche de tambours. `kind` : calm / tension / combat / menu."""
    rng = random.Random(7)
    duration = BAR * bars
    buf = [0.0] * int(duration * RATE)

    for beat in range(bars * 4):
        at = beat * BEAT
        b_in_bar = beat % 4
        # Grosse caisse : temps 1 et 3 (calme), plus dense en combat.
        if b_in_bar in (0, 2):
            mix(buf, lambda t, g=0.9 if kind != "calm" else 0.6: kick(t, g), at, 0.7)
        if kind in ("combat", "tension") and b_in_bar == 2:
            mix(buf, lambda t: kick(t, 0.5), at + BEAT * 0.5, 0.6)
        # Calebasse : croches discrètes (calme), doubles croches (combat).
        steps = 2 if kind in ("calm", "menu") else (4 if kind == "combat" else 3)
        for s in range(steps):
            sub = at + BEAT * s / steps
            gain = 0.16 if kind in ("calm", "menu") else 0.24
            mix(buf, lambda t, g=gain: shaker(t, g, rng), sub, 0.12)
        # Caisse claire : temps 2 et 4.
        if b_in_bar in (1, 3) and kind in ("tension", "combat", "menu"):
            gain = 0.5 if kind == "combat" else 0.34
            mix(buf, lambda t, g=gain: snare(t, g, rng), at, 0.35)
        # Cloche : accents de fin de mesure.
        if kind in ("combat", "menu") and b_in_bar == 3:
            mix(buf, lambda t: bell(t, 784.0 if kind == "menu" else 587.0, 0.5),
                at + BEAT * 0.5, 2.0)
    if kind == "menu":
        # Petite mélodie de cloches (2 notes par mesure) pour l'écran d'accueil.
        for beat, freq in ((0, 523.25), (1.5, 659.25), (3, 783.99), (5, 659.25),
                           (6, 523.25)):
            mix(buf, lambda t, f=freq: bell(t, f, 0.45), beat * BEAT, 2.4)
    return normalize(render(duration, lambda t: 0.0, wrap=True) if False else buf)


# ------------------------------------------------------------------ #
#                              SFX                                   #
# ------------------------------------------------------------------ #

def sfx_bank() -> dict:
    rng = random.Random(11)
    return {
        # Combat (§ 8) -------------------------------------------------
        "hit": lambda t: 0.8 * noise(t, 1.0, 30.0, rng) + 0.5 * kick(t, 0.6),
        "crit": lambda t: (0.9 * noise(t, 1.0, 26.0, rng)
                           + 0.6 * bell(t, 1200.0, 0.7)),
        "block": lambda t: 0.7 * noise(t, 1.0, 45.0, rng) + 0.4 * tone(t, 210.0, 0.5, 18.0),
        "guard_perfect": lambda t: (bell(t, 1568.0, 0.9) + 0.5 * bell(t, 2350.0, 0.4)),
        "dodge": lambda t: sweep(t, 1800.0, 400.0, 0.5, 9.0),
        "swing": lambda t: sweep(t, 900.0, 300.0, 0.35, 14.0),
        "special": lambda t: (sweep(t, 300.0, 1400.0, 0.6, 4.0)
                              + 0.4 * noise(t, 1.0, 6.0, rng)),
        "hurt": lambda t: (tone(t, 160.0, 0.8, 10.0)
                           + 0.4 * noise(t, 1.0, 18.0, rng)),
        "death_enemy": lambda t: (tone(t, 140.0, 0.7, 5.0)
                                  + 0.3 * noise(t, 1.0, 8.0, rng)),
        "death_player": lambda t: (tone(t, 110.0, 0.9, 2.5)
                                   + 0.3 * tone(t, 82.0, 0.7, 2.0)),
        "boss_roar": lambda t: (tone(t, 62.0, 1.0, 1.6)
                                + 0.5 * noise(t, 1.0, 1.2, rng)),
        # Monde et économie (§ 11, § 14) -------------------------------
        "cauri": lambda t: (bell(t, 1760.0, 0.55) + 0.4 * bell(t, 2637.0, 0.3)),
        "potion": lambda t: (tone(t, 660.0, 0.5, 6.0) + tone(t, 990.0, 0.4, 5.0)),
        "unlock": lambda t: (bell(t, 1046.5, 0.6) + 0.5 * bell(t, 1568.0, 0.4)),
        "step": lambda t: 0.5 * noise(t, 1.0, 60.0, rng),
        "ui_click": lambda t: 0.35 * noise(t, 1.0, 90.0, rng) + 0.25 * tone(t, 880.0, 0.4, 60.0),
        # Fins de niveau (§ 13, § 16) ----------------------------------
        "victory": lambda t: (bell(t, 523.25, 0.7) if t < 0.0 else
                              bell(t, 523.25, 0.7) * (t < 0.45)
                              + bell(t - 0.45, 659.25, 0.7) * (t >= 0.45)
                              + bell(t - 0.9, 783.99, 0.8) * (t >= 0.9)),
        "defeat": lambda t: (tone(t, 220.0, 0.6, 1.4) if t < 0.6 else
                             tone(t - 0.6, 174.61, 0.6, 1.2) if t < 1.2 else
                             tone(t - 1.2, 130.81, 0.7, 1.0)),
    }


SFX_LENGTH = {
    "hit": 0.25, "crit": 0.35, "block": 0.25, "guard_perfect": 1.2,
    "dodge": 0.4, "swing": 0.3, "special": 0.9, "hurt": 0.4,
    "death_enemy": 0.8, "death_player": 1.4, "boss_roar": 1.6, "cauri": 0.8,
    "potion": 0.8, "unlock": 1.0, "step": 0.12, "ui_click": 0.1,
    "victory": 2.0, "defeat": 2.4,
}


def main() -> None:
    # Musique : 1 morceau de menu + 3 couches superposables (§ 17).
    write_wav(os.path.join(ROOT, "music", "music_menu.wav"), music_layer("menu"))
    write_wav(os.path.join(ROOT, "music", "layer_calm.wav"), music_layer("calm"))
    write_wav(os.path.join(ROOT, "music", "layer_tension.wav"), music_layer("tension"))
    write_wav(os.path.join(ROOT, "music", "layer_combat.wav"), music_layer("combat"))
    # Bruitages.
    for name, voice in sfx_bank().items():
        buf = normalize(render(SFX_LENGTH[name], voice), 0.8)
        write_wav(os.path.join(ROOT, "sfx", "%s.wav" % name), buf)
    # Voix : emplacements (§ 17, § 31 : locuteurs natifs du fon à venir).
    os.makedirs(os.path.join(ROOT, "voice"), exist_ok=True)
    print("\nTerminé. Les voix se déposent dans assets/audio/voice/ "
          "(<langue>_<ligne>.wav) — voir assets/audio/voice/LISEZ-MOI.txt")


if __name__ == "__main__":
    main()
