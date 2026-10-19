# Rapport final — Guerrière d'Abomey

19 octobre 2026 · Éditeur **Johnson Studio** (Bénin, eudesjohn650@mail.com)

## 1. Ce qui a été livré

### Scripts Blender 4.x (`tools/blender/`)

| Fichier | Rôle |
|---|---|
| `clean_character.py` | `.glb` brut → parasites retirés, centré, origine aux pieds, 1,70 m, Decimate à 6 000 triangles, 1 matériau, normales recalculées, export `.glb` avant rig |
| `separate_prop.py` | sort un accessoire (sabre, fourreau…) par nom ou sélection vers son propre `.glb` |
| `batch_export.py` | tout un dossier + `rapport_modeles.csv` (triangles avant/après, texture, échelle) |
| `add_shape_keys_template.py` | `Basis` + `shoulders`, `muscle`, `hips`, `slim` vides, avec le mode d'emploi de chaque sculpture |
| `README.md` | commandes Windows, budgets par rôle, pannes fréquentes |

Aucun script n'écrit dans le fichier d'entrée : un `--output` identique à
l'`--input` est refusé (code de sortie 1, vérifié).

### Téléphone (`tools/tester_telephone.sh`, `.bat`, `rapport_telephone.py`)

Un seul script fait tout : détection d'`adb` (3 essais de 60 s si
« unauthorized »), export de l'APK debug, `adb install -r` (données conservées),
lancement, drapeau `user://auto_test.flag`, test automatique de 4 minutes,
collecte `gfxinfo` / `meminfo` / `batterie` / `logcat`, récupération du rapport
du jeu et rédaction de `export/phone/RAPPORT_TELEPHONE.md` avec un verdict.

Côté jeu : `scripts/debug/AutoTest.gd`, **inactif en release** (deux verrous :
balise d'export `autotest`, absente du preset de release, et fichier-drapeau).

### Données éditeur

`project.godot` porte `config/author="Johnson Studio"` et
`config/copyright="© 2026 Johnson Studio"`. La politique de confidentialité
(`docs/POLITIQUE_CONFIDENTIALITE.md`, FR + EN) et la fiche Play
(`docs/FICHE_STORE.md`, FR + EN) utilisent exactement Johnson Studio, Bénin et
eudesjohn650@mail.com — aucune autre donnée personnelle.

Le manifeste Android produit par Godot ne possède pas de champ « auteur » :
l'éditeur y apparaît donc par l'étiquette de l'application, et c'est
`application/config/author` (lu par Godot et repris dans la fiche Play) qui
porte Johnson Studio. Aucune donnée inventée n'a été ajoutée.

## 2. Vérifications réellement exécutées

**Blender 4.2.9 LTS portable** (téléchargé pour l'occasion, supprimé ensuite —
il n'est pas installé sur le PC), sur une scène de test fabriquée exprès
(sol parasite nommé `Ground`, caméra, lumière, 3 matériaux, texture 512²,
17 316 triangles, un sabre) :

| Contrôle | Résultat |
|---|---|
| `clean_character` | 17 316 → **6 000** triangles, 2,92 m → **1,700 m**, 3 → **1** matériau, **UV conservées**, pieds à Z = 0, origine (0, 0, 0), sol supprimé |
| `separate_prop` | `Sabre_Fourreau` extrait : 12 triangles, 0,75 m, pivot au centre |
| `batch_export` | 2 fichiers, **2 OK / 0 échec**, CSV UTF-8 BOM `;`, 18 colonnes, durées et tailles de texture remplies |
| `add_shape_keys_template` | `Basis` + 4 clés vides ; réexport `.glb` puis réimport : **`['Basis','shoulders','muscle','hips','slim']`** |
| Refus d'écraser la source | `--output` = `--input` → message d'erreur, **code 1** |

**Téléphone branché** : itel S667LN, Android 13, arm64-v8a, 3 705 Mo,
720 × 1612, densité 320. APK debug installé **sans effacer les données**,
aucune autre application touchée, aucune permission ajoutée.

## 3. Résultat du test téléphone — **ORANGE** (après une correction)

Trois passages sur l'appareil, mêmes niveaux, même APK debug.

**Essai 1 — avant correction** :

| Étape | Qualité | FPS moyen | FPS min | 1 % bas | Appels | Primitives |
|---|---|---|---|---|---|---|
| menu | high | 60,0 | 32,6 | 50,7 | 27 | 1 188 |
| combat 5 ennemis | high | 37,7 | 6,8 | **10,5** | 588 | 1 407 052 |
| arène Faible | low | 59,5 | 18,9 | 47,4 | 150 | 276 408 |
| arène Moyenne | medium | 57,2 | 10,0 | 31,3 | 150 | 276 408 |
| arène Haute | high | 47,8 | 14,7 | 28,2 | 582 | 1 406 464 |
| Sauvetage | high | 57,6 | 15,3 | 31,3 | 392 | 889 179 |
| boss | high | 43,2 | 7,8 | 26,1 | 597 | 1 464 960 |

Verdict **ROUGE** au deuxième passage (combat à 29,1 images/s).

**Correction appliquée** : la lampe directionnelle de la qualité Haute utilisait
le mode d'ombre par défaut, PSSM à 4 tranches — la passe d'ombre redessinait tout
le décor **quatre fois**. Passée en `SHADOW_ORTHOGONAL`, distance d'ombre limitée
à 18 m (`LevelBase3D._apply_sun_light`), ce qui correspond au § 25 (« une seule
ombre, 1024 px, pour la joueuse »). Aucun autre réglage touché.

**Essai 2 — après correction** :

| Étape | Qualité | FPS moyen | FPS min | 1 % bas | Appels | Primitives |
|---|---|---|---|---|---|---|
| menu | high | 60,0 | 60,0 | 60,0 | 27 | 1 188 |
| combat 5 ennemis | high | **52,4** | 7,6 | **30,0** | **266** | **575 072** |
| arène Faible | low | 59,9 | 23,4 | 56,9 | 150 | 276 408 |
| arène Moyenne | medium | 59,8 | 24,1 | 55,4 | 150 | 276 408 |
| arène Haute | high | **58,9** | 10,3 | **43,1** | **264** | **575 068** |
| Sauvetage | high | 59,9 | 38,3 | 60,0 | 159 | 295 927 |
| boss | high | **55,9** | 15,0 | **37,8** | **276** | **599 328** |

Gain : **+39 % de moyenne** sur le combat, **+23 %** sur l'arène Haute, **+29 %**
sur le boss ; appels de dessin **−55 %**, primitives **−59 %**.

Mémoire max 39,2 Mo, batterie 46,3 °C en fin de test, aucun crash, aucun ANR.
Le verdict reste **ORANGE** pour une seule raison : une image à 7,6 (131 ms)
au démarrage d'une vague. Les moyennes (52 à 60) et le pire 1 % (30 à 60) sont
au-dessus du seuil de 30 images/s ; 20 % d'images saccadées selon `gfxinfo`.

**Réglages recommandés** : Faible, Moyenne et Haute sont désormais fluides sur
cet itel ; garder la **Moyenne** comme défaut. Le prochain gain vient
**du regroupement des décors statiques** (264 appels de dessin restants) et du
**pré-chargement des ennemis** (le saut de 131 ms à l'apparition d'une vague).

## 4. Bug réel trouvé par le téléphone (corrigé)

Le premier passage a révélé que **le jeu ne démarrait plus** dans l'APK :
`TestPuppet` vivait dans `scripts/tests/`, exclu de l'export ; `Player3D`,
`EnemyBase3D` et `Dummy3D` l'instancient, donc ces scripts ne compilaient plus
et `LevelBase3D` recevait un `CharacterBody3D` au lieu d'un `Player3D`.
Déplacé dans `scripts/characters/TestPuppet.gd` (même `class_name`), cache de
classes régénéré, `Phase1Test` repasse en code 0, et le second passage sur le
téléphone ne journalise plus aucune erreur de script.

## 5. Limites restantes

- **Un seul saut de 131 ms** subsiste au démarrage de vague : un pool
d'ennemis pré-instanciés le supprimerait (à faire, non fait ici).

- **Aucun modèle `.glb`** : la chaîne Blender est testée, mais elle attend les
  fichiers du modeleur (budgets 6 000 / 3 500 / 5 000 / 9 000 / 800 / 2 000).
- **Coop non mesurée** : il faut deux téléphones.
- **Version `0.8.0` / code 8** : cohérente avec les phases livrées ; à
  incrémenter à chaque nouvel envoi sur Play.
- **AAB Play** : produit et signé (`export/guerriere-abomey-0.8.0.aab`), mais
  pas encore envoyé sur la Play Console.
- Les chiffres ci-dessus viennent d'un APK debug, avec le moteur en mode debug
  (plus lent qu'un build release) : le release sera au mieux égal.

Actions humaines restantes :
1. Fournir les modèles `.glb` à `assets/models/` (l'outillage Blender est prêt).
2. Nommer les 57 pièces de la planche (`assets/ui/source/planche_assets.noms.txt`).
3. Coller dans Play Console l'URL de la politique, déjà en ligne :
   <https://eudesjohn.github.io/jeux/POLITIQUE_CONFIDENTIALITE.html>.
4. Envoyer `export/guerriere-abomey-0.8.0.aab` en piste de test interne.
5. Faire le test coop à deux téléphones (tout le reste est automatisé).

Déjà fait le 19 octobre : clé de release + sauvegarde, preset `Android AAB`,
AAB signé et vérifié, 4 captures du store (`export/shots/play/`), page de
confidentialité publiée sur GitHub Pages.
