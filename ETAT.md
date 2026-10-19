# État du projet et problèmes connus

Mis à jour le 19 octobre 2026 (PHASE 8 terminée, PHASE 9 préparée).

## 1. Où en est le projet

| Élément | État | Contrôle |
|---|---|---|
| PHASE 0 à 8 | terminées | Phases 1→8 : 1 190 vérifications, 0 échec |
| PHASE 9 (modèles réels) | chaîne prête, **modèles absents** | `tests/Phase9Test.tscn` : 31/0 |
| PHASE 10 (publication) | **bloquée** (keystore release, visuels) | — |
| Planche d'assets | découpée (57 pièces) | `assets/ui/sliced/` + `export/planche_assets.html` |
| APK de test | 51,5 Mo, **signé**, à jour | `export/guerriere-abomey-debug.apk` |
| Versionnage | dépôt `main` à jour | <https://github.com/EudesJohn/jeux> |

## 2. Problèmes trouvés et corrigés

1. **Fondu de musique muet dans le test** — les `Tween` ne s'avancent pas pendant
   la toute première image du moteur ; la mesure tombait avant leur démarrage.
   Corrigé en laissant passer deux images avant les sections.
2. **`ProgressBar.vertical_alignment` n'existe pas** (écran des succès) — l'erreur
   interrompait la création des lignes, l'écran restait vide. Remplacé par
   `size_flags_vertical`.
3. **Clé de traduction inexistante dans le test** (`VIE %d / %d` au lieu du vrai
   bandeau du HUD) et vérification faite après retour en français : le test
   mesurait autre chose que ce qu'il annonçait.
4. **Scripts de test et d'outils dans l'APK** — le filtre d'export contenait
   `tests/*`, mais les scripts compilés vivent sous `scripts/tests/` ; 16 fichiers
   (`ArenaTest`, `DebugPlayer`, `ModelBudget`…) partaient dans l'APK. Filtre
   complété (`scripts/tests/*`, `scripts/tools/*`) et **le test vérifie maintenant
   la ligne `exclude_filter` précise**, plus le fichier entier (l'ancien
   `contains("tools/*")` passait à tort).
5. **Outil de modèles : chemin absolu cassé** — `globalize_path()` appliqué à un
   chemin Windows (`C:/…`) rendait le fichier illisible. Corrigé.
6. **Outil de modèles : fichier illisible compté comme succès** (code 0).
   Il échoue maintenant (code 1), pour que la CI ne laisse pas passer un modèle
   corrompu.
7. **`class_name` inconnu hors éditeur** — un script lancé avec `--script` ne
   voit pas une classe globale ajoutée après le dernier import. Les outils
   utilisent `preload()` ; ouvrir l'éditeur enregistre la classe.
8. **`PackedScene.pack()` ignore les enfants sans `owner`** — le modèle de test
   exporté était vide (0 maillage, 0 animation). Corrigé dans le test.
9. **`AnimationPlayer.add_animation()` n'existe pas en Godot 4** — il faut une
   `AnimationLibrary`. Corrigé.
10. **Plantaison (segfault) de l'export glTF en headless** quand il suit
    l'instanciation puis la libération de personnages. Contourné : le test
    exporte le `.glb` **avant** les sections qui créent des personnages. C'est un
    défaut du moteur (dummy renderer), pas du jeu.
11. **APK non signé** — `--export-debug` sans `JAVA_HOME` produit un APK qui
    **refuse de s'installer** (« apksigner n'a pas pu s'exécuter »). Déjà
    documenté dans le README (§ C) ; rencontré à nouveau, réexporté avec
    `JAVA_HOME`, APK signé vérifié (`META-INF/ANDROIDD.RSA`).
12. **Numéro de textes faux dans le README** (167 au lieu de 166 : l'en-tête
    `msgid ""` était compté).

## 3. Problèmes ouverts (demandent une décision ou un fichier)

1. **Aucun modèle `.glb`** dans `assets/models/` : la poupée de test reste le
   rendu. Dès livraison : `godot --headless --path . --script res://tools/check_model_budgets.gd`
   puis brancher `model_scene` dans les `.tres` (aucun code à toucher).
2. **Pièces découpées non nommées** (`asset_01`…`asset_57`) : je ne peux pas voir
   les images. Ouvrir `export/planche_assets.html`, remplir
   `assets/ui/source/planche_assets.noms.txt`, relancer avec `--names=… --clean`.
3. **57 PNG inutilisés dans l'APK** (+≈2,8 Mo). À exclure (`assets/ui/sliced/*`)
   tant qu'aucun écran ne s'en sert, ou à brancher.
4. **Version `0.1.0`, code 1** alors que les phases 8-9 sont livrées : à décider
   (ex. `0.8.0` / code 8) avant tout partage.
5. **Aucune clé de release** : AAB Google Play impossible (PHASE 10).
6. **Politique de confidentialité et captures d'écran** absentes (PHASE 10) ;
   il manque le nom/contact de l'éditeur pour les rédiger.
7. **Aucun test sur téléphone ici** : tout est validé en `--headless` (les
   contrôles tactiles simulés y sont ignorés). FPS, triangles et draw calls
   réels restent à mesurer sur l'itel S667LN.

## 4. Dette et limites techniques

- **Dépôt git** : créé le 19 octobre 2026, premier commit `4edfc92` poussé sur
  <https://github.com/EudesJohn/jeux> (branche `main`). Le `.gitignore` laisse
  dehors le cache `.godot/`, les APK/AAB, les clés (`*.keystore`) et les sources
  lourdes (`*.blend`, `*.psd`) : 457 fichiers, 7,9 Mo, pas de fichier > 1 Mo.
  La copie non versionnée de `D:/Jeux Benin` n'est **pas**
  ce dépôt : le dépôt est `guerriere-abomey-3d/`, où se trouve `project.godot`.
- **Export glTF de Godot sans animations** : les `AnimationPlayer` ne sont pas
  transportés. Les modèles animés doivent venir de Blender ; l'aller-retour du
  test ne prouve que géométrie et matériaux.
- **Audio provisoire** : tambours synthétisés (`tools/generate_audio.py`), aucune
  voix enregistrée ; le fon n'est pas relu par un locuteur natif.
- **Planche 1344×896** : correcte pour des icônes, trop basse pour des textures
  1024² de personnage ; le style « image générée » ne correspond pas au low-poly
  du jeu, à valider avant usage.
- **Pas de profiling** : `DebugStats` affiche FPS/tris/draw calls, mais aucune
  mesure n'a été faite sur appareil.
- **`--clean` de l'outil de découpe** supprime tous les `.png` du dossier de
  sortie : ne jamais le pointer sur un dossier contenant autre chose.

## 5. Commandes de contrôle

```bash
# Toute la suite (chaque commande doit sortir en code 0)
for p in 1 2 3 4 5 6 7 8 9; do
  godot --headless --path . res://tests/Phase${p}Test.tscn
done

# Budgets des modèles (code 1 si dépassement ou fichier illisible)
godot --headless --path . --script res://tools/check_model_budgets.gd

# Découpe de la planche (puis nommage)
godot --headless --path . --script res://tools/slice_asset_sheet.gd -- \
    --gallery=res://export/planche_assets.html

# APK signé (JAVA_HOME obligatoire, sinon APK non installable)
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
godot --headless --path . --export-debug "Android" export/guerriere-abomey-debug.apk
```
