"""Musique originale du jeu — tambours de guerre ouest-africains.

    python tools/generate_music.py

Aucun enregistrement tiers n'est utilisé : tout est SYNTHÉTISÉ ici, donc
libre de droits pour le jeu. La base rythmique est la cloche 12/8 (Bembé),
le cycle polyrythmique commun aux tambours d'Afrique de l'Ouest :

    x . x x . x . x x . x .      (positions 0,2,3,5,7,8,10 sur 12)

Les 4 fichiers remplacent ceux de `assets/audio/music/` aux MÊMES noms, donc
`AudioManager` les charge sans changement de code :

    music_menu.wav     thème du menu (balafon, tambours doux)
    layer_calm.wav     exploration (cloche, djembé léger)
    layer_tension.wav  ennemis proches (dundun, slaps)
    layer_combat.wav   combat (djembé plein, kenkeni, chant)

Les 3 couches font exactement la même durée (8 mesures, 19,2 s à 100 BPM) et
sont superposables : le fondu de `AudioManager` reste aligné. La traîne de
chaque coup est reportée au début du tampon (« wrap »), la boucle est nette.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
BPM = 100.0
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
BARS = 8
LOOP = BAR * BARS
STEPS = 12                    # subdivisions ternaires par mesure
STEP = BAR / STEPS
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "assets", "audio", "music")

# Cloche 12/8 (Bembé) : la pulsation de référence de tout le morceau.
BELL_STEPS = (0, 2, 3, 5, 7, 8, 10)
# Pentatonique de ré mineur, la plus courante sur les balafons.
D4, F4, G4, A4, C5 = 293.66, 349.23, 392.00, 440.00, 523.25
PENTA = (D4, F4, G4, A4, C5)


# ------------------------------------------------------------------ #
#                          INSTRUMENTS                               #
# ------------------------------------------------------------------ #

def djembe_bass(t: float, gain: float = 1.0) -> float:
    f = 52.0 + 38.0 * math.exp(-t * 30.0)
    return math.sin(2.0 * math.pi * f * t) * math.exp(-t * 13.0) * gain


def djembe_tone(t: float, gain: float = 1.0, rng: random.Random = None) -> float:
    r = rng or random
    body = math.sin(2.0 * math.pi * 196.0 * t) * math.exp(-t * 18.0)
    skin = r.uniform(-1.0, 1.0) * math.exp(-t * 40.0) * 0.5
    return (body + skin) * gain


def djembe_slap(t: float, gain: float = 1.0, rng: random.Random = None) -> float:
    r = rng or random
    noise = r.uniform(-1.0, 1.0) * math.exp(-t * 55.0)
    click = math.sin(2.0 * math.pi * 380.0 * t) * math.exp(-t * 70.0)
    return (noise + 0.6 * click) * gain


def dundun(t: float, freq: float = 62.0, gain: float = 1.0) -> float:
    f = freq * (1.0 + 0.06 * math.exp(-t * 12.0))
    return math.sin(2.0 * math.pi * f * t) * math.exp(-t * 7.0) * gain


def kenkeni(t: float, freq: float = 220.0, gain: float = 1.0) -> float:
    metal = math.sin(2.0 * math.pi * freq * t)
    metal += 0.5 * math.sin(2.0 * math.pi * freq * 2.41 * t)
    metal += 0.25 * math.sin(2.0 * math.pi * freq * 3.77 * t)
    return metal * math.exp(-t * 26.0) * 0.4 * gain


def cowbell(t: float, freq: float = 640.0, gain: float = 1.0) -> float:
    metal = math.sin(2.0 * math.pi * freq * t)
    metal += 0.45 * math.sin(2.0 * math.pi * freq * 2.76 * t)
    metal += 0.2 * math.sin(2.0 * math.pi * freq * 5.40 * t)
    return metal * math.exp(-t * 9.0) * 0.35 * gain


def shaker(t: float, gain: float = 1.0, rng: random.Random = None) -> float:
    r = rng or random
    prev = r.uniform(-1.0, 1.0)
    current = r.uniform(-1.0, 1.0)
    return (current - prev) * 0.5 * math.exp(-t * 70.0) * gain


def balafon(t: float, freq: float, gain: float = 1.0) -> float:
    """Lame de bois frappée : fondamentale + partiel métallique + attaque."""
    env = math.exp(-t * 5.5)
    tone = math.sin(2.0 * math.pi * freq * t)
    tone += 0.35 * math.sin(2.0 * math.pi * freq * 3.93 * t) * math.exp(-t * 14.0)
    tone += 0.18 * math.sin(2.0 * math.pi * freq * 9.2 * t) * math.exp(-t * 30.0)
    strike = math.sin(2.0 * math.pi * 1200.0 * t) * math.exp(-t * 90.0) * 0.25
    return (tone * env + strike) * gain


def kora(t: float, freq: float, gain: float = 1.0) -> float:
    """Corde pincée : harmoniques qui s'éteignent du plus aigu au plus grave."""
    value = 0.0
    for harmonic in range(1, 7):
        value += (1.0 / harmonic) * math.sin(
            2.0 * math.pi * freq * harmonic * t) * math.exp(-t * (2.2 + harmonic * 1.4))
    return value * gain * 0.6


def chant(t: float, freq: float = 110.0, gain: float = 1.0) -> float:
    """Voix criée (« hé ! ») : source glottique + formants, sans parole."""
    env = math.exp(-t * 2.2)
    vibrato = 1.0 + 0.02 * math.sin(2.0 * math.pi * 5.2 * t)
    source = 0.0
    for harmonic in range(1, 16):
        source += (1.0 / harmonic) * math.sin(
            2.0 * math.pi * freq * harmonic * vibrato * t)
    # Formants approximatifs d'un « è » ouvert crié.
    formants = ((700.0, 1.0), (1800.0, 0.55), (2600.0, 0.3))
    out = 0.0
    for center, weight in formants:
        out += weight * math.exp(-((freq - center) / 420.0) ** 2)
    return source * (0.25 + out) * env * gain


# ------------------------------------------------------------------ #
#                        RENDU ET MÉLANGE                            #
# ------------------------------------------------------------------ #

def render(duration: float, voice, wrap: bool = True) -> list:
    total = int(duration * RATE)
    tail = int(min(0.5, duration * 0.25) * RATE)
    buf = [0.0] * total
    for i in range(total + (tail if wrap else 0)):
        sample = voice(i / RATE)
        j = i % total if wrap else i
        if j < total:
            buf[j] += sample
    return buf


def mix(buf: list, voice, at: float, duration: float) -> None:
    start = int(round(at * RATE))
    piece = render(duration, voice, wrap=False)
    for i, value in enumerate(piece):
        buf[(start + i) % len(buf)] += value


def normalize_common(buffers: list, peak: float = 0.68) -> None:
    top = max((abs(v) for buf in buffers for v in buf), default=0.0)
    if top <= 1e-6:
        return
    scale = peak / top
    for buf in buffers:
        for i, value in enumerate(buf):
            buf[i] = value * scale


def write_wav(path: str, buf: list) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32000))
                    for v in buf)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    print("%7.0f Ko  %s  (%.1f s)" % (len(data) / 1024.0, os.path.relpath(path),
                                      len(buf) / RATE))


# ------------------------------------------------------------------ #
#                        MOTIFS ET ARRANGEMENT                       #
# ------------------------------------------------------------------ #

def add_drums(buf: list, kind: str, rng: random.Random) -> None:
    for bar in range(BARS):
        bar_at = bar * BAR
        # La cloche ne s'arrête jamais : c'est elle qui tient le cycle.
        for step in BELL_STEPS:
            gain = 0.55 if kind == "combat" else 0.4
            mix(buf, lambda t, g=gain: cowbell(t, 680.0, g), bar_at + step * STEP, 0.8)

        if kind == "calm":
            for step in (0, 6):
                mix(buf, lambda t: djembe_bass(t, 0.85), bar_at + step * STEP, 0.8)
            for step in (3, 9):
                mix(buf, lambda t: djembe_tone(t, 0.55, rng), bar_at + step * STEP, 0.5)
            for step in range(0, STEPS, 2):
                mix(buf, lambda t: shaker(t, 0.18, rng), bar_at + step * STEP, 0.15)
        elif kind == "tension":
            for step in (0, 3, 6, 9):
                mix(buf, lambda t: djembe_bass(t, 0.9), bar_at + step * STEP, 0.8)
            for step in (2, 5, 8, 11):
                mix(buf, lambda t: djembe_tone(t, 0.6, rng), bar_at + step * STEP, 0.5)
            for step in (0, 4, 8):
                mix(buf, lambda t: dundun(t, 66.0, 0.7), bar_at + step * STEP, 1.2)
            mix(buf, lambda t: djembe_slap(t, 0.5, rng), bar_at + 10 * STEP, 0.35)
        else:  # combat
            for step in (0, 3, 6, 9):
                mix(buf, lambda t: djembe_bass(t, 1.0), bar_at + step * STEP, 0.9)
            for step in (2, 5, 8, 11):
                mix(buf, lambda t: djembe_tone(t, 0.75, rng), bar_at + step * STEP, 0.6)
            for step in (4, 10):
                mix(buf, lambda t: djembe_slap(t, 0.8, rng), bar_at + step * STEP, 0.4)
            for step in (1, 4, 7, 10):
                mix(buf, lambda t: kenkeni(t, 240.0 if step % 2 else 210.0, 0.5),
                    bar_at + step * STEP, 0.5)
            for step in (0, 4, 8):
                mix(buf, lambda t: dundun(t, 58.0, 0.85), bar_at + step * STEP, 1.4)
            # Appel de guerre tous les 4 mesures (montée d'intensité).
            if bar % 4 == 0:
                mix(buf, lambda t: chant(t, 110.0, 0.55), bar_at, 1.6)
                mix(buf, lambda t: chant(t, 165.0, 0.3), bar_at + 2 * STEP, 1.2)


def melody_bar(bar: int, kind: str) -> list:
    """Motif de balafon, 6 notes par mesure (une par temps et demie)."""
    patterns = (
        (0, 2, 1, 3, 2, 0),
        (2, 3, 4, 3, 2, 1),
        (0, 1, 2, 4, 3, 2),
        (3, 2, 1, 0, 1, 2),
    )
    pattern = patterns[bar % len(patterns)]
    notes = []
    for index, degree in enumerate(pattern):
        freq = PENTA[degree % len(PENTA)]
        if kind == "combat" and bar % 2 == 1:
            freq *= 1.0 if index % 2 == 0 else 1.0
        notes.append((index * 2 * STEP, freq))
    return notes


def add_balafon(buf: list, kind: str) -> None:
    for bar in range(BARS):
        # En combat, le balafon répond une mesure sur deux (call and response).
        if kind == "combat" and bar % 2 == 1:
            continue
        for at, freq in melody_bar(bar, kind):
            gain = 0.32 if kind == "calm" else 0.42
            mix(buf, lambda t, f=freq, g=gain: balafon(t, f, g),
                bar * BAR + at, 1.6)


def add_kora(buf: list, kind: str) -> None:
    if kind == "combat":
        return
    # Basse continue : fondamentale + quinte, une attaque par mesure.
    for bar in range(BARS):
        freq = D4 / 2.0 if bar % 2 == 0 else A4 / 2.0
        mix(buf, lambda t, f=freq: kora(t, f, 0.35), bar * BAR, 3.0)
        if bar % 2 == 1:
            mix(buf, lambda t: kora(t, G4 / 2.0, 0.25), bar * BAR + 2 * STEP, 2.4)


def build_layer(kind: str) -> list:
    rng = random.Random(41 + len(kind))
    buf = [0.0] * int(LOOP * RATE)
    add_drums(buf, kind, rng)
    add_balafon(buf, kind)
    add_kora(buf, kind)
    if kind == "calm":
        # Souffle de fond (vent de la savane), très discret.
        for i in range(len(buf)):
            t = i / RATE
            buf[i] += 0.015 * math.sin(2.0 * math.pi * 0.13 * t) * (
                0.5 + 0.5 * math.sin(2.0 * math.pi * 0.031 * t))
    return buf


def build_menu() -> list:
    rng = random.Random(77)
    buf = [0.0] * int(LOOP * RATE)
    for bar in range(BARS):
        bar_at = bar * BAR
        for step in (0, 6):
            mix(buf, lambda t: djembe_bass(t, 0.55), bar_at + step * STEP, 0.9)
        for step in (3, 9):
            mix(buf, lambda t: djembe_tone(t, 0.35, rng), bar_at + step * STEP, 0.5)
        for step in (0, 4, 8):
            mix(buf, lambda t: cowbell(t, 560.0, 0.28), bar_at + step * STEP, 1.0)
        for at, freq in melody_bar(bar, "calm"):
            mix(buf, lambda t, f=freq: balafon(t, f, 0.38), bar_at + at, 1.8)
        mix(buf, lambda t: kora(t, D4 / 2.0, 0.3), bar_at, 3.0)
        if bar % 4 == 0:
            mix(buf, lambda t: chant(t, 98.0, 0.22), bar_at, 2.2)
    return buf


def main() -> int:
    calm = build_layer("calm")
    tension = build_layer("tension")
    combat = build_layer("combat")
    menu = build_menu()
    normalize_common([calm, tension, combat, menu], peak=0.68)
    # Le menu n'a ni tambours pleins ni chant : on le remonte pour qu'il ne
    # paraisse pas deux fois plus faible que le combat.
    normalize_common([menu], peak=0.55)
    write_wav(os.path.join(ROOT, "layer_calm.wav"), calm)
    write_wav(os.path.join(ROOT, "layer_tension.wav"), tension)
    write_wav(os.path.join(ROOT, "layer_combat.wav"), combat)
    write_wav(os.path.join(ROOT, "music_menu.wav"), menu)
    print("boucle : %.1f s à %.0f BPM, cloche 12/8, aucune source tierce"
          % (LOOP, BPM))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
