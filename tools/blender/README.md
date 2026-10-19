# Outils Blender 4.x — préparation des modèles

Quatre scripts `bpy` à lancer **en ligne de commande**, sans ouvrir l'interface.
Ils ne modifient **jamais** le fichier d'entrée : ils refusent un `--output`
identique à l'`--input` et écrivent toujours un nouveau fichier.

| Script | Rôle |
|---|---|
| `clean_character.py` | nettoie un `.glb` brut (plans parasites, origine aux pieds, 1,70 m, Decimate, 1 matériau) |
| `separate_prop.py` | sort un accessoire (sabre, fourreau) dans son propre `.glb` |
| `batch_export.py` | applique le nettoyage à tout un dossier + rapport CSV |
| `add_shape_keys_template.py` | crée les shape keys vides `shoulders`, `muscle`, `hips`, `slim` |

Ordre conseillé : **clean → separate_prop → shape keys**, puis
`tools/check_model_budgets.gd` avant de déposer le `.glb` dans `assets/models/`.

## 1. Trouver Blender (Windows)

Installation par défaut :

```
C:\Program Files\Blender Foundation\Blender 4.2\blender.exe
```

Pour ne plus taper le chemin, dans **cmd** (une fois par session) :

```bat
set BLENDER="C:\Program Files\Blender Foundation\Blender 4.2\blender.exe"
```

…ou ajouter `C:\Program Files\Blender Foundation\Blender 4.2\` au `PATH`, puis
utiliser simplement `blender`. Dans Git Bash, les chemins avancent en `/` :

```bash
BLENDER="/c/Program Files/Blender Foundation/Blender 4.2/blender.exe"
"$BLENDER" --version
```

Le séparateur `--` est obligatoire : tout ce qui le suit appartient au script,
tout ce qui le précède à Blender.

## 2. Nettoyer un personnage

```bat
%BLENDER% -b -P tools\blender\clean_character.py -- ^
    --input "D:\assets\raw\hero.glb" ^
    --output "D:\assets\clean\hero_nawi.glb" ^
    --height 1.70 --budget 6000
```

Ce que fait l'outil, dans l'ordre :

1. supprime caméras, lumières, vides et **plans/sols parasites** (nom évocateur
   ou dalle plate et large — `--keep-plans` pour les garder) ;
2. fusionne tous les morceaux en un maillage unique et applique les
   transformations ;
3. centre le corps en X/Y et **pose l'origine entre les pieds** (`Z = 0`) ;
4. met à l'échelle pour **1,70 m** (`--height 0` pour ne pas toucher) ;
5. **Decimate COLLAPSE** jusqu'au budget (`--budget 0` pour ne pas décimer) :
   les UV sont interpolées, donc les textures suivent ;
6. fusionne les matériaux en **un seul** :
   - `--material-strategy first` (défaut) garde la texture du matériau dominant ;
   - `--material-strategy vertex-color` cuit les couleurs dans les couleurs de
     sommets (aucune texture, mais les couleurs restent) ;
7. recalcule les normales vers l'extérieur (+ lissage ; `--no-smooth` sinon) ;
8. exporte en `.glb` **sans animation ni skin** (on est avant le rig).

Options utiles : `--merge-distance 0.0001` (soudure des sommets, `0` = aucune),
`--keep-plans`, `--json mesures.json` (mesures détaillées).
Code de sortie `0` = OK, `1` = fichier inutilisable ou argument faux.

Exemple Git Bash :

```bash
"$BLENDER" -b -P tools/blender/clean_character.py -- \
    --input assets/raw/hero.glb --output assets/clean/hero_nawi.glb
```

## 3. Sortir un accessoire

```bat
%BLENDER% -b -P tools\blender\separate_prop.py -- ^
    --input "D:\assets\clean\hero_nawi.glb" ^
    --name "Sabre,Fourreau" ^
    --output "D:\assets\props\weapon_sabre.glb"
```

- `--name` accepte des jokers (`"Sabre*"`) ou de simples fragments, séparés par
  des virgules ; insensible à la casse ;
- `--selected` prend la sélection déjà enregistrée dans un `.blend` ;
- `--origin centre` (défaut) place le pivot au milieu de l'accessoire,
  `min`/`max`/`monde` pour un autre point ;
- `--list` affiche les objets et leurs triangles **sans rien exporter** :

```bat
%BLENDER% -b -P tools\blender\separate_prop.py -- --input hero_nawi.glb --list
```

Un accessoire n'a pas de rig : garde `--no-apply` si tu veux conserver la
transformation monde (utile pour un sabre déjà positionné dans la main).

## 4. Traiter un dossier entier + rapport CSV

```bat
%BLENDER% -b -P tools\blender\batch_export.py -- ^
    --input-dir "D:\assets\raw" ^
    --output-dir "D:\assets\clean" ^
    --height 1.70 --budget 6000
```

Écrit `<output-dir>\rapport_modeles.csv` (UTF-8 BOM, séparateur `;`, ouvrable
directement dans Excel français) avec une ligne par fichier :

```
fichier ; statut ; triangles_avant ; triangles_apres ; budget ; objets_supprimes ;
materiaux_avant ; materiaux_apres ; texture_max_px ; textures ; echelle ;
hauteur_avant_m ; hauteur_apres_m ; sortie_ko ; duree_s ; message
```

Un fichier cassé n'arrête pas le lot (`statut = ERREUR` et le message dans la
dernière colonne). Code de sortie `0` si tout est OK, `1` sinon.

Options : `--pattern "enemy_*.glb"` (répétable), `--recursive`,
`--stop-on-error`, `--sep ,` (tableur anglophone), `--no-report`.

## 5. Shape keys (`shoulders`, `muscle`, `hips`, `slim`)

```bat
%BLENDER% -b -P tools\blender\add_shape_keys_template.py -- ^
    --input "D:\assets\clean\hero_nawi.glb" ^
    --output "D:\assets\clean\hero_nawi_shapekeys.blend"
```

Le `.blend` produit contient `Basis` puis les quatre clés **vides** (valeur 0).
Sculpte-les dans *Object Data → Shape Keys* (le mode d'emploi de chaque clé est
imprimé par le script et commenté en tête du fichier), puis réexporte :

```bat
%BLENDER% -b -P tools\blender\add_shape_keys_template.py -- ^
    --input "D:\assets\clean\hero_nawi_shapekeys.blend" ^
    --output "D:\assets\clean\hero_nawi_shapekeys.glb"
```

Sans modèle sous la main, `--demo` fabrique un corps factice et `--list` montre
les clés existantes. L'export `.glb` passe par `export_morph` : `export_apply`
doit rester `False`, sinon Blender supprime les clés.

## 6. Budgets attendus par rôle

Le nom du fichier décide du budget appliqué par `tools/check_model_budgets.gd`
(DESIGN.md § 6.3) :

| Préfixe | Triangles | Exemple |
|---|---|---|
| `hero_`, `ally_` | 6 000 | `--budget 6000` |
| `enemy_` | 3 500 | `--budget 3500` |
| `brute_` | 5 000 | `--budget 5000` |
| `boss_` | 9 000 | `--budget 9000` |
| `weapon_` | 800 | `--budget 800` |
| `prop_` | 2 000 | `--budget 2000` |

## 7. Pannes fréquentes

| Message | Cause / solution |
|---|---|
| `ModuleNotFoundError: No module named 'bpy'` | le script a été lancé avec `python`, pas avec Blender |
| `--input introuvable` | chemin Windows avec espaces : mets-le entre guillemets |
| APK/modèle trop lourd après nettoyage | baisse `--budget`, ou `--material-strategy vertex-color` si les textures sont minuscules |
| Blender quitte en 0 alors que l'export a échoué | regarde la ligne `[clean] ÉCHEC : …` : Blender renvoie parfois 0 malgré `sys.exit(1)` |
| le `.glb` n'a plus de textures | `--material-strategy vertex-color`, ou les images étaient des matériaux plats |
| shape keys absentes du `.glb` | `export_apply=True` quelque part : cet outil le laisse à `False` |
