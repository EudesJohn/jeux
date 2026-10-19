# Musique — tambours de guerre ouest-africains

## Ce qui est joué

Le jeu contient **quatre boucles originales de 19,2 s** (8 mesures à 100 BPM,
22050 Hz mono), générées par `tools/generate_music.py` :

| Fichier | Usage | Contenu |
|---|---|---|
| `music_menu.wav` | menu principal | balafon, kora, djembé doux, cloche, chant grave |
| `layer_calm.wav` | exploration | cloche 12/8, djembé léger, balafon, souffle |
| `layer_tension.wav` | ennemis proches | dundun, slaps, balafon, cloche |
| `layer_combat.wav` | combat | djembé plein, kenkeni, dundun, chant « hé ! » |

Les trois couches `layer_*` sont **strictement alignées** (même durée, même
tempo) : `AudioManager` les superpose et les fait entrer en fondu selon
l'intensité du combat (calme → tension → combat). Remplacer un fichier par un
enregistrement réel ne demande aucune modification de code.

## Base rythmique

La cloche suit le **cycle 12/8 (Bembé)**, commun aux tambours d'Afrique de
l'Ouest :

```
x . x x . x . x x . x .
0 1 2 3 4 5 6 7 8 9 10 11
```

Djembé (basse, ton, slap), dundun, kenkeni et cloche se répondent ; le balafon
joue une pentatonique de ré mineur, la kora une basse par mesure. Le chant est
une **synthèse de voyelles** (pas de parole, pas de locuteur enregistré).

## Droits

**Aucun enregistrement tiers n'est utilisé.** Tout est synthétisé par le script
du projet : la musique est donc libre de droits pour le jeu, sans attribution
extérieure. Une version avec musiciens et chanteurs (et voix en fon) reste
souhaitable pour la sortie commerciale ; les noms de fichiers sont déjà prêts.

## Régénérer

```bash
python tools/generate_music.py
godot --headless --path . --editor --quit   # réimporte les WAV
```

Le script est déterministe (graines fixes) : relancer produit exactement les
mêmes fichiers. Chaque fichier pèse ≈ 827 Ko (3,3 Mo au total).
