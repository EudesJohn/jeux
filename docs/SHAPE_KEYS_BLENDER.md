# Shape keys de silhouette — à créer dans Blender

Réponse à la demande de la PHASE 6D. Le code lit ces noms **exactement**
(`CharacterLook.SHAPE_KEYS`). Un nom différent est simplement ignoré : le
curseur correspondant ne fait rien.

## Noms et plages

| Shape key | Curseur | Plage utile | Effet |
|---|---|---|---|
| `shoulders` | Carrure | 0 → 1 | Épaules et poitrine ; 0 = étroite, 1 = large |
| `muscle` | Musculature | 0 → 1 | Volume des bras et des jambes |
| `hips` | Hanches | 0 → 1 | Largeur du bassin |
| `slim` | Minceur | 0 → 1 | Silhouette affinée (taille marquée) |

Le cinquième curseur (hauteur, −6 % / +8 %) n'est **pas** une shape key : il
applique une échelle à la racine (`CharacterLook.height_scale()`), sans toucher
au squelette. La posture (droite / fière / souple) reste une animation ou un
léger décalage du buste, pas une shape key.

## Règles à respecter

1. **Créer les 4 shape keys sur le corps ET sur chaque pièce de tenue**
   (tunique, pagnes, brassards, jambières, colliers). Mêmes noms, mêmes valeurs
   de base : c'est la seule façon d'éviter que l'armure traverse le corps.
2. **Ne jamais modifier le squelette** (os, orientations, repos). Les animations
   Mixamo doivent continuer de fonctionner telles quelles.
3. **Budget** : 4 shape keys × (corps + 5 pièces) = 24 canaux. Rester sous
   **6 000 triangles** pour le corps habillé (§ 6.3 du dossier 3D).
4. **Bornes** : les shape keys vont de 0 à 1 ; le code clampe à [0, 1]. Ne pas
   utiliser de valeurs négatives.
5. **Ordre stable** : ne pas renommer après export, les sauvegardes stockent le
   nom, pas l'index.

## Export `.glb`

1. Sélectionner le corps **et** les pièces de tenue, puis `Fichier → Exporter →
   glTF 2.0 (.glb)`.
2. Dans le panneau d'export, cocher :
   - **Mesh → Shape Keys** (obligatoire) ;
   - **Mesh → Apply Modifiers** (les modificateurs doivent être appliqués) ;
   - **Animation** uniquement si le fichier contient aussi les animations.
3. Vérifier dans Godot : ouvrir le `.glb`, sélectionner le `MeshInstance3D`,
   l'inspecteur doit lister `shoulders`, `muscle`, `hips`, `slim`.
4. Vérifier en jeu avec `godot --headless --path . res://tests/ModelViewer.tscn`
   puis l'atelier (à venir). En cas d'absence : l'outil de nettoyage
   `tools/blender/clean_character.py` peut supprimer les shape keys s'il
   applique les modificateurs (option à vérifier avant le lot).
