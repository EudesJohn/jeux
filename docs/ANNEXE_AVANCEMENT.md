# Annexe « arènes, armes, progression, personnalisation, difficulté » — avancement

Mis à jour le 19 octobre 2026. Cette page dit **ce qui existe réellement** dans
le dépôt, ce qui est vérifié par un test, et ce qui reste à faire. Elle ne
remplace pas l'annexe : en cas de contradiction, l'annexe gagne.

L'annexe annonce 10 à 14 semaines de travail. Elle a été traitée par **blocs**,
dans son ordre, avec un test headless par bloc. Aucun de ces blocs n'est une
phase terminée au sens du dossier 3D : ce sont les fondations vérifiables.

## Ce qui est fait et testé

| Bloc | Livré | Test |
|---|---|---|
| **6B — armes** | `WeaponData` complet (5 raretés, 6 types, formule `damage_at`), `AffixData` (les 10 affixes), `WeaponSystem` (coût 60 × niveau^1,5, ascension 5/10, maîtrise 0-20, chargement des `.tres`), **11 fiches d'armes** dans `data/weapons/` (les 8 armes jouables du prompt + 3 armes de boss), inventaire sauvegardé (obtention, affixes tirés, équipement, amélioration, ascension, coups/maîtrise), dégâts de l'arme équipée branchés dans `Player3D._attack_damage` | `tests/Phase6BTest.tscn` — 142 vérifications |
| **6C — progression** | `Progression` : XP `100 × niveau^1,6`, niveaux 1-60, 3 points d'attribut par niveau, 1 compétence tous les 2 niveaux, vie `100 + 8 × Vitalité + 4 × niveau`, dégâts §4.3, critique, DPS estimé ; `SkillTree` (**15 talents**, 3 branches), `GearData` (**6 sets**, **4 talismans**) ; niveau, XP, points, attributs, talents sauvegardés ; Force, Vitalité et critique branchés sur `Player3D` | inclus dans `Phase6BTest` |
| **6D — personnalisation** | `CharacterLook` (silhouette par blend shapes, hauteur −6 %/+8 %, coiffure, peinture, tenue, 3 couleurs, bannière, titre), sérialisation pour la sauvegarde, application aux pièces de tenue | inclus dans `Phase6BTest` |
| **7B — foule et spectateurs** | `CrowdManager` : **un seul MultiMesh**, 60/150/300 spectateurs selon la qualité, couleurs et phase par instance, aucune ombre ; `shaders/crowd.gdshader` (animation 100 % GPU) ; jauge d'excitation (montée, plafond, retombée, audio) ; `SpectatorCamera` (AUTO / FREE / CROWD) ; rôles joueur/spectateur dans `Network` (2 joueurs + 4 spectateurs, hôte autoritaire) ; **`Arena3D`** : sol, 6 gradins, tribune, 4 points d'apparition, foule montée (palettes royale / marché / fleuve / nuit) | `tests/Phase7BTest.tscn` — 49 vérifications |
| **8B — difficulté** | `DifficultyTier` + **4 paliers** `.tres` (Récit, Guerrière, Légende, Éternelle) avec les multiplicateurs du §7.1 ; `GameState.use_tier()` (multiplicateurs, potions, checkpoints, élites, phases de boss) ; persistance dans les réglages ; **code des couleurs** blanc/jaune/rouge dans `Hitbox3D`, `DamageInfo`, `DangerZone3D`, ennemis et boss ; **7 affixes d'élite** réellement appliqués (`EliteAffix` + `EnemyBase3D`) ; écran de mort qui nomme l'attaque et donne un conseil | `tests/Phase8BTest.tscn` — 96 vérifications |
| **Musique** | **4 boucles originales de 19,2 s** (menu, calme, tension, combat) sur cloche 12/8, djembé, dundun, kenkeni, balafon, kora et chant synthétisé — `tools/generate_music.py`, `docs/MUSIQUE.md` | `Phase8Test` : boucle de 19,20 s chargée |

Réglages : un sélecteur **« Palier de défi »** a été ajouté au panneau de
réglages. Choisir un palier remplace l'ancienne difficulté à trois valeurs ;
choisir l'ancienne difficulté efface le palier. Les deux sauvegardes restent
compatibles.

## Ce qui est partiel (à ne pas présenter comme fini)

- **Les 8 armes ne sont pas 8 movesets.** Une seule animation de combo existe
  (sabre). Les fiches changent les dégâts, la rareté, les affixes et la
  progression, pas encore les enchaînements, les spéciaux ni les tirs. Les
  modèles sont des primitives remplaçables par `mesh_scene`.
- **Arbre de compétences, sets d'armure, talismans, runes, forge, atelier,
  inventaire, bannière, emotes** : les formules et les ressources de base sont
  posées (`Progression`, `CharacterLook`), mais **les écrans et les effets
  passifs ne sont pas branchés**. Aucun `.tres` de set ou de talent n'est livré.
- **Foule** : une seule arène est montée (`Arena3D`, ambiance royale), les
  trois autres palettes existent mais n'ont pas de décor propre. Pas encore de
  bannière ni de sprites billboards pour les rangées lointaines.
- **PvP, Tournoi, spectateur réel** : seuls les rôles réseau et la décision de
  l'hôte sont livrés. Aucun niveau de duel, aucun état réduit à 10 Hz.
- **Talents et sets** : les données, les coûts et l'apprentissage sont testés,
  mais les effets **ne sont pas tous branchés** (seuls Force, Vitalité et
  critique le sont). Aucun écran d'arbre de talents ni d'inventaire.
- **Boss à 4-5 phases** : `boss_phase_count` est lu par le palier, mais
  `BossBase3D` reste à 3 phases. L'enrage après 4 minutes n'est pas codé.
- **6B « forge au village »**, démontage, fabrication, plans : non faits.
- **Musique** : originale et synthétisée ; une production avec musiciens et
  voix en fon reste souhaitable pour la sortie commerciale.

## Recherche sur les noms d'armes

Recherche web effectuée le 19 octobre 2026 (Britannica, Wikipédia
« Dahomey Amazons », African History Extra, Penn Museum). Résultat :

- **gubasa** : sabre cérémoniel fon, lame courbe, associé à Gu (dieu de la
  guerre) et aux insignes de l'autorité. Le nom est attesté dans plusieurs
  sources ; c'est celui retenu pour le sabre de départ (identifiant de
  sauvegarde conservé : `sabre`).
- **hwi** : autre forme d'`ada` fon citée par les mêmes sources, moins
  documentée ; **non utilisé** tant qu'une source béninoise ne le confirme pas.
- **« gbèkon »** (nom de l'annexe) : **aucune occurrence trouvée** dans les
  sources consultées. Remplacé par *gubasa* pour le nom affiché.
- **Agojie / Mino / Ahosi** : orthographes et régiments (dont les *gbeto*,
  chasseuses d'éléphants, et les *nyekplohento*, « moissonneuses ») confirmés
  par Wikipédia ; les noms de musique et de vodoun restent à valider.
- Les noms des autres armes (machette, lance, massue, arc, fusil à pierre)
  restent **des propositions de gameplay**, pas des noms historiques.

À faire valider par un historien ou une source béninoise avant toute
communication publique : noms d'armes, motifs d'appliqués, sets « vodoun »,
titres et bannières.

## Tests

```bash
# Les trois blocs de l'annexe
godot --headless --path . res://tests/Phase6BTest.tscn   # 142 vérifications
godot --headless --path . res://tests/Phase7BTest.tscn   #  49 vérifications
godot --headless --path . res://tests/Phase8BTest.tscn   #  96 vérifications

# Non-régression des phases existantes (1 190 vérifications)
for p in 1 2 3 4 5 6 7 8 9; do
  godot --headless --path . res://tests/Phase${p}Test.tscn
done
```

Mesuré le 19 octobre 2026 : les 12 scènes sortent en code 0 (1 508
vérifications au total). Les tests existants
n'ont pas été modifiés ; le sabre de départ au niveau 1 vaut exactement ×1,00,
donc les dégâts de la PHASE 2 sont inchangés.

## Ordre conseillé pour la suite

1. **Arènes** : une scène `Arena3D` (rayon 12-14 m, 4 points d'apparition) qui
   instancie `CrowdManager`, puis les 4 ambiances de l'annexe.
2. **Movesets** : un `WeaponMoveset` par type (lame, double, hast, contondante,
   distance, courte) plutôt que 23 scripts ; brancher `special_scene`.
3. **Élites** : appliquer les 7 affixes dans `EnemyBase3D` quand un palier est
   choisi, avec un test qui force le tirage.
4. **Écrans** : atelier (SubViewport), inventaire, forge, fiche de personnage.
5. **PvP** : duel local d'abord (deux manettes/claviers) avant le réseau, pour
   valider l'équilibrage sans dépendre du WiFi.
