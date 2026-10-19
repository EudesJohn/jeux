# Guerrière d'Abomey — version 3D low-poly

Source de vérité : **DESIGN.md** (dossier de production § 1 à § 33).
État détaillé, problèmes connus et commandes de contrôle : **ETAT.md**.
Avancement : **PHASE 8 — son, traductions fr/en/fon, succès, objectifs
du jour et qualité auto-adaptative** (détail plus bas). La **PHASE 9** est
préparée et testée (budgets, branchement sans code, animations) ; il ne manque
que les modèles `.glb` du modeleur.
PHASE 7 — Coop WiFi : lobby hôte/invité, un `Player3D` par téléphone, hôte
autoritaire, réanimation à 10 s.
PHASE 2 — Combat complet et « game feel » : garde parfaite avec
contre-attaque, esquive parfaite, tourbillon du sabre, critiques, hit-stop,
tremblement de caméra, particules d'impact, flash de dégâts, nombres de dégâts,
caméra ARENA avec verrouillage automatique, valeurs réglables dans
`data/balance.tres`. Validée par `tests/Phase2Test.tscn` (106 vérifications
avec fenêtre, 105 sans la chaîne tactile — aucune ignorée hors `--headless`).
PHASE 3 — Niveaux, ennemis, pièges et objectifs : les 5 niveaux `.tres`
(3 couloirs + 2 arènes), le spawner de vagues (§ 20.11), l'IA complète du § 9
(poursuite, télégraphe, jeton d'attaque, archer, armure de la brute, buff et
invocation du chef, garde d'alerte), les 6 pièges du § 11, les checkpoints du
§ 13, les cauris et potions, le HUD du § 16 et les objectifs du § 20.10.
Validée par `tests/Phase3Test.tscn` (210 vérifications avec fenêtre, 202 sans la
chaîne tactile — aucune ignorée hors `--headless`).
PHASE 4 — Sauvetage et Escorte : cages à libérer par une interaction de 2 s,
villageois à conduire à la sortie (40 vie, sa mort = échec), objectifs Rescue /
Escort / ReachExit / Survive / KillBoss, écran Résultat et écran Défaite,
17 niveaux de Sauvetage + 1 niveau d'Escorte dans `data/levels/rescue/`
(table du § 12.2 : prisonniers, pièges, temps, 5 niveaux de nuit), générés par
`tools/generate_rescue_levels.gd`. Écran de choix **Sauvetage (PHASE 4)** du
menu, avec étoiles enregistrées et déblocage séquentiel. Validée par
`tests/Phase4Test.tscn` (271 vérifications avec fenêtre, 265 sans la chaîne
tactile — aucune ignorée hors `--headless`).
PHASE 5 — Boucle complète : menu principal (Jouer, Armurerie, Réglages,
Quitter), choix du mode, **carte du royaume** des 25 niveaux de campagne avec
étoiles et déblocage séquentiel, panneau « avant-niveau » (objectif, ennemis,
temps, récompense), **pause** qui fige vraiment le jeu (Reprendre /
Recommencer / Réglages / Quitter), **armurerie** à trois améliorations
permanentes payées en cauris et **panneau de réglages** (difficulté, volumes,
taille des boutons, opacité, échelle 3D, qualité, langue, vibration). Validée par
`tests/Phase5Test.tscn` (285 vérifications, aucune ignorée, y compris
`--headless`).
PHASE 6 — Boss et tous les modes : **`BossBase3D`** (3 phases, télégraphe,
zones de danger au sol, appel de soldats, armure du colosse, nuit du sorcier,
combos du général) et les **5 gardiens** du § 10 dans `data/bosses/` ; chaque
chapitre se referme désormais sur son boss (`ch1_l5` → `ch5_l5`). Le HUD affiche
la grande barre de vie, le nom et la phase du gardien, un ralenti de 0,6 s
accompagne le dernier coup. Trois modes hors campagne sont jouables :
**Survie** (vagues sans fin, bonus entre les vagues, record local), **Chasse aux
boss** (les gardiens déjà vaincus, enchaînés sans pause) et **Défi du jour**
(graine de la date, modificateurs « dégâts doublés / nuit / ennemis rapides /
une seule vie », série de jours). Validée par `tests/Phase6Test.tscn`
(128 vérifications, aucune ignorée, y compris `--headless`).
PHASE 7 — Coop WiFi : **lobby** (l'hôte affiche son IP en grand, l'invitée voit
les parties détectées par broadcast *et* peut taper l'IP à la main), **un
`Player3D` par pair** créé par `MultiplayerSpawner`, **hôte autoritaire** (lui
seul simule vagues, dégâts, timer, objectifs), **difficulté coop** (§ 22.3 :
ennemis ×1,3, 6 à l'écran, vie ×1,5), **réanimation** de 10 s à deux et
**déconnexion** qui prévient et renvoie au menu. Validée par
`tests/Phase7Test.tscn` (49 vérifications) et par deux instances réelles sur
localhost (`tests/Phase7Net.tscn`, 13 + 16 vérifications).

**Correctifs « ça ne répond pas au doigt » (téléphone, 18 oct.) —** trois causes
réelles, vérifiées sur l'itel S667LN (720×1612, Android) :

1. `input_devices/pointing/emulate_mouse_from_touch` était à `false` : le doigt
   ne produisait aucun clic, donc **aucun `Button`** du jeu ne réagissait (menu,
   carte, pause, armurerie, réglages). Il est passé à `true` ; le joystick et les
   boutons d'action lisent le tactile *et* la souris en ignorant le clic émulé
   (`InputEvent.DEVICE_ID_EMULATION`), donc un seul déclenchement par appui.
2. Dans l'APK, les fiches de niveau sont exportées en `.tres.remap` :
   `_load_levels()` ne trouvait **aucun** niveau, la carte du royaume et l'écran
   de Sauvetage restaient vides (et « JOUER » restait grisé). Les deux écrans
   enlèvent désormais le suffixe `.remap` avant de filtrer.
3. Mise en page en 2:1 (canvas 1612×720) : le « Retour » du choix du mode
   sortait sous l'écran et l'écran de résultat n'était plus centré. Corrigé par
   des ancres ; deux vérifications de plus dans `Phase5Test`.

Parcours rejoué au doigt sur le téléphone : menu → Jouer → Aventure → carte →
niveau 1 → joystick (déplacement réel) → pause → Reprendre.

PHASE 1 (joueuse jouable) : arène de test complète validée par
`tests/Phase1Test.tscn` (61 vérifications), lancée sur téléphone (60 FPS).

---

## A. Ouvrir le projet (2 min)

1. Installe **Godot 4.3+** (version standard, pas .NET) : https://godotengine.org/download
2. Lancement de Godot → **Importer** → choisis le dossier `guerriere-abomey-3d/` (celui qui contient `project.godot`).
3. Ouvre puis **F5** (ou le bouton ▶). Résultat attendu :
   - écran Splash (fond indigo, titre or, 2 s), tap pour sauter ;
   - MainMenu : un **cube rouge qui tourne** sur fond noir, caméra 1280×720 paysage.
4. Erreurs acceptables à ce stade : aucune. Si une erreur s'affiche, copie-la telle quelle et renvoie-la.

## B. Export Android — installations (une seule fois)

1. **JDK 17 (OpenJDK)** : installe-le (Adoptium/Temurin "Windows x64 MSI" par ex.).
2. **Android SDK** : installe Android Studio, puis via *SDK Manager* :
   *SDK Platform 34*, *Platform-Tools*, *Build-Tools 34*, **NDK** + *CMake* (recommandés par la doc Godot de ta version).
3. Dans Godot : *Éditeur → Paramètres Éditeur → Export → Android*, renseigne les chemins **JDK** et **SDK**.
4. *Projet → Installer les modèles d'exportation* (télécharge le modèle Android une fois).
5. Sur ton **téléphone** : active *Options développeur → Débogage USB*.
   (Android 9 et moins : active aussi « Installer via USB ».)

## C. APK de test (1 clic)

1. *Projet → Exporter…* → **Ajouter** → *Android*.
2. Onglet *Options* : vérifie
   - *Architectures* : **arm64-v8a + armeabi-v7a** cochées ;
   - *Orientation* : **Paysage** ;
   - *Permissions* : `VIBRATE`, `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE` (INTERNET est requis par ENet LAN, aucune autre utilisation) ;
   - *Textures* 3D : ETC2 / ASTC activé ;
3. **Clé de debug** : laissée vide (`debug.keystore` par défaut) — suffit pour tester.
4. Clic **Export Projet** → garde `export/guerriere-abomey-debug.apk`.
   - Si le journal affiche *« Tous les outils 'apksigner' … n'ont pas pu s'exécuter »*
     puis *« Le APK résultant n'est pas signé »*, c'est que `apksigner` ne trouve pas
     de Java. Renseigne le JDK dans *Paramètres Éditeur → Export → Android*, ou lance
     Godot avec `JAVA_HOME` défini (ex. `C:\Program Files\Android\Android Studio\jbr`).
     Un APK non signé **refuse de s'installer** sur le téléphone.
5. Variante la plus rapide : **téléphone branché en USB → bouton Déploiement en un clic** (icône Android en haut à droite). Teste immédiatement.

Export en ligne de commande (même résultat, sans ouvrir l'éditeur) :
```bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
godot --headless --path . --export-debug "Android" export/guerriere-abomey-debug.apk
```
Installation sur téléphone branché : `adb install -r export/guerriere-abomey-debug.apk`
(`adb` est dans `platform-tools` du SDK Android ; `-r` remplace l'installation précédente).

## D. Clé de release (à faire PLUS TARD, en PHASE 10 seulement)

```bash
keytool -genkeypair -v -keystore release.keystore -alias guerriere -keyalg RSA -keysize 2048 -validity 10000
```
⚠️ Sauvegarde `release.keystore` + mot de passe hors du PC et **hors Git** : sans eux, aucune mise à jour Google Play possible. Ainsi `export/release.keystore` doit rester hors Git.

## E. Checklist PHASE 0 (à cocher sur téléphone)

- [ ] Le jeu s'ouvre en **paysage** sur téléphone, sans crash.
- [ ] Cube 3D fluide : **30 FPS minimum** (active *Débogueur → Monitor* sur PC ou `DisplayServer` FPS simplement en joueur d'écran — les compteurs dédiés arrivent en PHASE 0.5).
- [ ] Après fermeture forcée : réouverture possible, aucune erreur bloquante.
- [ ] Envoie l'**APK par WhatsApp** possible (< 120 Mo — ici ~30 Mo).

Si tout passe : **PHASE 0 validée** (déjà le cas sur l'itel S24 : 60 FPS, zéro crash).

## F. PHASE 0.5 — Pipeline 3D : ModelViewer + Mixamo (§ 6)

**Ce qui est déjà dans le projet :**
- `scenes/tests/ModelViewer.tscn` : sol ocre, ciel indigo, caméra, **compteurs FPS / triangles / draw calls**.
- `scripts/tests/TestPuppet.gd` : mannequin provisoire (10 articulations) avec les animations standards `idle, run, attack1-3, dodge, guard, hurt, death, interact` (§ 5).
- `AnimationTree` + `AnimationNodeStateMachine` (§ 6.4 : tous les personnages partagent le même state machine).
- Accès : bouton **« Test ModelViewer (PHASE 0.5) »** sur le menu principal, ou `F6` sur la scène sur PC.

**Validation attendue (sur PC et téléphone) :**
- Poupée rouge/indigo/or animée, `DEMO` : idle → course → 3 coups → esquive → garde → blessure → mort, sans erreur.
- Compteur : **30 FPS min** (téléphone d'entrée de gamme), **< 120 000 tris**, **< 100 draw calls**.

**Pour remplacer la poupée par un vrai personnage Mixamo (à faire une fois) :**
1. Va sur **mixamo.com** (compte Adobe gratuit) : modèle « X Bot » gratuit ou ton propre FBX de Blender.
2. Charge le modèle, pose les marqueurs (menton, mains, genoux), applique le **rig automatique**.
3. Anime : `Idle`, `Running`, `Sword Slash` x3, `Roll`, `Block`, `Hit Reaction`, `Death`. Tout le monde se nomme EXACTEMENT idle/run/attack1/attack2/attack3/dodge/guard/hurt/death + interact.
4. Télécharger : première animation « **With Skin** » (FBX) ; les autres « **Without Skin** ».
5. Dans Blender : supprime les courbes inutiles, garde les clés propres, et exporte en **.glb** (T-pose, +Y up, animations incluses) dans `assets/models/hero.glb`.
6. Dans Godot : importe le .glb → dans le dock *Import → Rig*, « **Retargeting** → **Humanoid** » (BoneMap + SkeletonProfileHumanoid) et **Enable** → *Reimport*.
7. Le viewer ne change pas de code : *ModelViewer → Inspector → Model Scene*, glisse `hero.glb` (ou ton .tscn) ; les animations retargetées portant les noms standards jouent immédiatement via la `State Machine` existante.

## G. PHASE 1 — Joueuse jouable (§ 7, § 8, § 20)

**Ce qui est dans le projet :**
- `scenes/tests/CombatTest.tscn` : arène plate (sol ocre + 3 blocs gris), la
  joueuse, un mannequin d'entraînement, la caméra LANE automatique (§ 3.2), le HUD
  vie/énergie et les commandes tactiles (joystick flottant + 4 boutons).
- `Player3D` : machine à états (idle, course, attaque, esquive, garde, blessure,
  mort), mouvement relatif à la caméra, rotation du modèle, combo de 3 coups avec
  aimant d'attaque, esquive invincible (3,6 m), garde à −70 %, réapparition
  automatique (provisoire en PHASE 1), branchements HUD et vibration.
- `Dummy3D` : encaisse les coups, nombres de dégâts flottants, riposte
  télégraphiée (0,4 s) toutes les 2,6 s, mort puis réapparition.
- `scripts/tests/TestPuppet.gd` : poupée provisoire (10 articulations) qui fournit
  les 10 animations standard du § 6.4. **Chaque clip écrit toutes les pistes**
  (voir `_clip`) : pendant un fondu, une piste absente du clip d'arrivée est mise
  à l'échelle par le poids de l'autre et tend vers 0 — le torse tombait aux pieds
  dès le premier coup.

**Lancer le jeu :** F5 → Splash → menu principal → bouton **« Combat LANE (PHASE 1) »**.
Clavier PC de secours : WASD/flèches, J attaque, K esquive, L garde, I spécial.

**Tests automatiques :**
```bash
godot --headless --path . res://tests/Phase1Test.tscn   # logique (doigts simulés : ignorés)
godot --path . res://tests/Phase1Test.tscn              # logique + doigts -> « PHASE 1 : OK »
```
Le test charge la vraie arène et vérifie la chaîne tactile, le déplacement, la
limite de couloir, le combo, l'esquive, la garde, la riposte, la mort et la
réapparition — ainsi que la stabilité de la pose pendant les fondus (§ 6.4).

`tests/ShotProbe.tscn` imprime la géométrie du HUD et des boutons, puis enregistre
deux captures de l'arène — au repos (`user://shot_idle.png`) et pendant un coup
(`user://shot_attack.png`) : pratique pour contrôler le rendu sans téléphone, car
un fondu d'animation raté n'apparaît qu'après un changement d'état.

**À valider sur téléphone (§ 28) :** bouger au joystick, enchaîner 3 coups,
esquiver, bloquer, voir la vie baisser puis remonter ; 30 FPS minimum.

## H. PHASE 2 — Combat complet et « game feel » (§ 8, § 20, § 28)

**Ce qui est dans le projet :**
- `data/balance.tres` (+ `data/resources/Balance.gd`) : **toutes** les valeurs de
  combat du § 8 (vie, vitesse, combo, recul, hit-stop, esquive, garde,
  stabilité, spécial, critiques, valeurs du mannequin, rayon de verrouillage).
  Le code ne décide plus rien en dur : modifier ce fichier change le jeu.
- `Player3D` : **garde parfaite** (bouton levé dans les 0,18 s avant l'impact →
  0 dégât, ennemi étourdi 0,8 s, contre-attaque automatique, +15 énergie,
  ralenti), **stabilité de garde** (30, −5 par coup bloqué, +5/s, garde brisée à
  0 → étourdie 0,6 s), **esquive parfaite** (< 0,12 s avant l'impact → ralenti
  0,3 s et +10 énergie), **spécial du sabre** (tourbillon 360° : coût 100,
  invincible, dégâts ×3 sur 2,5 m), flash de dégâts, aimant d'attaque et buffer
  d'entrée désormais pilotés par `balance.tres`.
- `Hitbox3D` : **critiques 8 % ×1,5** (§ 8.7), hit-stop (§ 8.2 : 0,05 / 0,05 /
  0,09 s), tremblement de caméra et particules d'impact par coup.
- `autoload/FX.gd` : `hit_stop`, `slow_motion`, `shake`, `impact` (particules
  `CPUParticles3D` jetables), `damage_number`, `hit_feedback`. Deux effets qui se
  chevauchent ne peuvent plus laisser le jeu figé (identifiant de gel).
- `DamageNumber` (Label3D flottant, doré et plus grand sur un critique) et
  `ImpactFX` (étincelle dorée, garde, parfaite, spécial, dégâts).
- `CameraRig` **mode ARENA** : 7 m derrière la joueuse, 4 m de haut, FOV 55,
  alignée sur la ligne joueuse → cible ; **verrouillage automatique** sur
  l'ennemi le plus proche dans 8 m avec priorité à celui qui attaque ;
  changement de cible **en touchant un ennemi à l'écran** ; nouvelle cible
  automatique si elle meurt ; **anneau doré 3D** (`TargetRing`) sous la cible et
  **anneau du HUD** (`LockOnMarker`) qui suit la cible projetée à l'écran.
- `HUD` : barres de vie, d'énergie et de **stabilité de garde**, « SPÉCIAL PRÊT »
  clignotant, **vignette de dégâts** (shader `damage_vignette`, s'intensifie
  quand la vie baisse), messages centraux « GARDE PARFAITE ! », « ESQUIVE
  PARFAITE ! », « GARDE BRISÉE ».
- `Dummy3D` : encaisse les critiques, `stun()` (étourdissement sur garde
  parfaite), flash, nombres de dégâts partagés, valeurs lues dans `balance.tres`.

**Nouvelles scènes de test :**
- `scenes/tests/ArenaTest.tscn` — **ARENA** (disque de 14 m, 3 mannequins,
  verrouillage, anneau, HUD complet) : c'est là qu'on sent le game feel.
  Bouton **« Arène ARENA (PHASE 2) »** du menu principal.
- `scenes/tests/BalanceTest.tscn` — **réglage à chaud** : 15 curseurs qui
  écrivent directement dans `data/balance.tres` pendant la partie (dégâts,
  critique, hit-stop, garde parfaite, stabilité, esquive, spécial, vie du
  mannequin, rayon de verrouillage…). **IMPRIMER** enregistre les réglages dans
  `user://balance_tuned.tres` et les affiche en clair ; **RECHARGER** remet les
  valeurs du fichier ; **MASQUER** libère la moitié gauche de l'écran pour jouer.
  Bouton **« Réglage à chaud (PHASE 2) »** du menu principal.

**Tests automatiques :**
```bash
godot --headless --path . res://tests/Phase2Test.tscn   # logique (doigts simulés : ignorés)
godot --path . res://tests/Phase2Test.tscn              # logique + doigts -> « PHASE 2 : OK »
godot --headless --path . res://tests/Phase3Test.tscn   # logique (doigts simulés : ignorés)
godot --path . res://tests/Phase3Test.tscn              # logique + doigts -> « PHASE 3 : OK »
godot --headless --path . res://tests/Phase4Test.tscn   # Sauvetage (bouton tactile ignoré)
godot --path . res://tests/Phase4Test.tscn              # + doigt maintenu -> « PHASE 4 : OK »
godot --headless --path . res://tests/Phase5Test.tscn   # boucle menu → carte → niveau → résultat → boutique
godot --path . res://tests/Phase5Test.tscn              # idem avec fenêtre (rendu réel)
godot --headless --path . res://tests/Phase6Test.tscn   # boss, phases, Survie, Chasse, Défi du jour
godot --path . res://tests/Phase6Test.tscn              # idem avec fenêtre (rendu réel)
godot --headless --path . res://tests/Phase6Test.tscn   # PHASE6_ONLY=bosses,fight,…
```
Avec fenêtre, ces deux tests pilotent les **vrais contrôles tactiles** du § 7
(doigt posé sur le joystick puis incliné, appui sur Attaque / Garde / Esquive) :
les boutons et le joystick coupent alors leur pilotage à la souris, sinon celle
du bureau déplacerait la joueuse au milieu d'une mesure.
Le test charge la **vraie arène ARENA** et vérifie les valeurs de
`balance.tres`, les critiques, le hit-stop, le tremblement, les particules, le
flash de dégâts, la garde parfaite (contre-attaque, étourdissement, énergie), la
stabilité et la garde brisée, l'esquive parfaite, le tourbillon 360° (les
adversaires derrière la joueuse sont touchés, ceux hors du rayon non), le
verrouillage ARENA (cible la plus proche, changement au doigt, cible morte), le
HUD (vignette, messages, anneau) et les curseurs de `BalanceTest`.

`tests/Phase2Shot.tscn` enregistre trois captures dans `user://`
(`shot_p2_arena.png`, `shot_p2_guard.png`, `shot_p2_special.png`) et imprime la
géométrie du HUD : pratique pour contrôler le rendu sans téléphone.

**À valider sur téléphone (§ 28) :** garde parfaite (0 dégât + contre-attaque),
esquive parfaite (ralenti), tourbillon du sabre à 100 % d'énergie, verrouillage
ARENA et anneau de cible, critiques dorés ; 30 FPS minimum.

**Après test :** les réglages qui te plaisent se copient de
`user://balance_tuned.tres` vers `data/balance.tres`.

## I. PHASE 4 — Sauvetage et Escorte (§ 12.2)

**Ce qui est dans le projet :**
- `data/levels/rescue/` : **17 niveaux de Sauvetage + 1 niveau d'Escorte**, en
  `.tres`, conformes à la table du § 12.2 — 1 prisonnier puis 2, 3 et 4 ;
  soldats → éclaireurs → archers et gardes d'alerte → brutes ; pièges qui
  s'ajoutent (fosses, flèches, feu, pics, boue) ; 150 s → 130 s → 110 s →
  100 s ; les niveaux **13 à 17 se jouent de nuit** (brouillard sombre +
  `OmniLight` autour de la joueuse).
- `scripts/level/Prisoner3D.gd` : cage en barreaux, **interaction de 2 s**
  (bouton « Interaction » maintenu, ou touche **E** au clavier). Les barreaux
  passent du gris à l'or avec la jauge ; lâcher la fait redescendre. Libéré, le
  prisonnier suit la joueuse comme un allié.
- `scripts/level/Villager3D.gd` + `Ally3D.gd` : villageois de 40 vie qui suit la
  joueuse ; **sa mort fait échouer le niveau** immédiatement.
- `scripts/objectives/` : `RescueObjective`, `EscortObjective`, `ReachExit`,
  `Survive`, `KillBossObjective` (squelette, branché en PHASE 6).
- `scripts/ui/ResultScreen.gd` : écran **NIVEAU TERMINÉ** (étoiles, temps,
  cauris) ou **ÉCHEC** avec la raison, boutons **REJOUER** et **MENU**.
- `HUD` : compteur **PRISONNIERS x/y** et jauge de maintien au centre de l'écran.
- `scenes/ui/RescueSelect.tscn` : choix des niveaux de Sauvetage avec étoiles
  sauvegardées et déblocage séquentiel. Bouton **« Sauvetage (PHASE 4) »** du
  menu principal.
- `tools/generate_rescue_levels.gd` : régénère les 18 fiches (le contenu reste
  modifiable à la main dans l'inspecteur).

**Régénérer les niveaux :**
```bash
godot --headless --path . --script res://tools/generate_rescue_levels.gd
```

**À valider sur téléphone (§ 28) :** maintenir « Interaction » 2 s près d'une
cage (la jauge monte et la cage s'ouvre), lâcher avant la fin (la jauge
redescend), conduire le villageois à l'anneau doré sans le perdre, et voir la
nuit des niveaux 13-17 ; 30 FPS minimum.

**Limites connues (phases suivantes) :** les ennemis ne ciblent pas encore les
alliés, et le mode coop n'est pas encore branché sur les niveaux de Sauvetage.

## J. PHASE 5 — Boucle complète (§ 14.4, § 16)

**Ce qui est dans le projet :**
- `scenes/main/MainMenu.tscn` + `MainMenu.gd` : **Jouer**, **Armurerie**,
  **Réglages**, **Quitter**, plus un accès discret aux scènes de test des
  phases précédentes. La Coop WiFi est visible mais verrouillée (PHASE 7).
- `scenes/ui/ModeSelect.tscn` : six modes, tous jouables (Aventure, Sauvetage,
  Arène d'entraînement, puis Survie, Chasse aux boss et Défi du jour en
  PHASE 6).
- `scenes/ui/AdventureMap.tscn` + `AdventureMap.gd` : la **carte du royaume**
  — 5 chapitres, 25 niveaux `.tres` (`data/levels/adventure/`, générés par
  `tools/generate_levels.gd`). Chaque bouton affiche ses étoiles ou « verrouillé » ;
  le niveau 1 est ouvert, chaque suivant demande **au moins 1 étoile sur le
  précédent**. Le panneau de droite montre objectif, type de terrain, nombre
  d'ennemis et de vagues, temps limite, récompense et record avant de lancer.
  Les fiches viennent des données : ajouter un `.tres` l'ajoute à la carte
  (les noms de chapitres sont dans `AdventureMap.gd`).
- `scripts/ui/PauseMenu.gd` : **PAUSE** réelle (`get_tree().paused = true`),
  donc timer, vagues, ennemis et joueuse se figent réellement ; le menu reste
  actif. **Reprendre**, **Recommencer** (niveau reparti à zéro), **Réglages**,
  **Quitter le niveau** (retour à la carte en campagne, au menu sinon).
- `scripts/ui/SettingsPanel.gd` : difficulté, volumes musique / effets / voix,
  **taille des boutons**, opacité des boutons, **échelle 3D**, qualité
  graphique, langue, vibration. Chaque changement s'applique aussitôt et est
  écrit dans `SaveManager.data["settings"]` (rien ne se perd au redémarrage).
- `scenes/ui/Shop.tscn` + `Shop.gd` : l'**armurerie** — Vitalité (+10 vie max),
  Force (+8 % de dégâts), Souffle (+10 énergie au départ), 3 niveaux chacune,
  prix croissants (`SaveManager.UPGRADES`). Les cauris viennent des niveaux ;
  un aperçu chiffré montre vie, dégâts et énergie après achat. Les achats
  s'appliquent réellement en jeu : `Player3D` ajoute `upgrade_bonus` à la vie
  maximale, à l'énergie de départ et à ses dégâts (`damage_multiplier`).
- `ResultScreen` : en campagne le bouton devient **CONTINUER** et ramène à la
  carte ; en Sauvetage il ramène au choix des niveaux.

**Boucle validée :** menu → mode → carte → avant-niveau → niveau → résultat →
armurerie → carte, en une seule partie, avec la sauvegarde qui garde étoiles,
cauris et améliorations d'un lancement à l'autre.

**À valider sur téléphone (§ 16, § 28) :** la carte (boutons lisibles au doigt,
verrous et étoiles), le panneau avant-niveau, la pause qui fige vraiment le jeu,
Recommencer, les curseurs de réglages (taille des boutons surtout) et un achat
en armurerie ; 30 FPS minimum.

**Limites connues (phases suivantes) :** pas encore d'armes ni d'arbre de
compétences complets (§ 14.4).

## K. PHASE 6 — Boss et tous les modes (§ 10, § 12.3-12.5)

**Ce qui est dans le projet :**
- `scripts/ai/BossBase3D.gd` : le gardien du § 10, **piloté par `BossData`**.
  Trois phases (100-60 %, 60-30 %, 30-0 %) : le télégraphe raccourcit, le
  répertoire d'attaques s'ouvre, le tempo accélère. Six attaques possibles
  (`charge`, `sweep`, `slam`, `arrows`, `orbs`, `teleport`), chacune **pose sa
  zone de danger au sol avant de frapper** (`DangerZone3D`) : la joueuse a le
  temps de sortir du disque rouge. Il rejoint le groupe `enemies` (verrouillage
  et coups de la joueuse inchangés), appelle des soldats en phase 2, encaisse
  avec son armure (colosse : 3 gardes parfaites la brisent) et éteint la lumière
  (sorcier). Dernier coup : **ralenti 0,6 s à 0,2×**.
- `data/bosses/` : les **5 gardiens** — capitaine des pillards (ch. 1), chef
  archer du fleuve (2), colosse blindé (3), sorcier des ténèbres (4), général
  rival (5, combos de 5 coups). Régénérables :
  `godot --headless --path . --script res://tools/generate_bosses.gd`.
- `data/levels/adventure/chN_l5.tres` : **chaque chapitre se referme sur son
  boss** (arène, 150 s, sans piège) — `tools/generate_adventure_levels.gd`
  régénère les 25 fiches.
- `HUD` : grande barre de vie du gardien, nom + « PHASE n », rouge sombre en
  dernière phase, message « GARDIEN : … » à l'apparition.
- `scripts/modes/ModeBuilder.gd` : fabrique les fiches des trois modes hors
  campagne (aucun `.tres` à maintenir) ; `LevelBase3D` les joue comme un niveau
  normal.
  * **Survie** (§ 12.3) : arène, `endless` dans `WaveSpawner3D`, difficulté qui
    monte toutes les 5 vagues, un boss toutes les 10. Après chaque vague,
    `BonusChoice` propose **soin +40 %, force +15 % ou spécial rechargé** ; le
    flux des vagues attend le choix (`flow_paused`). Record local enregistré
    dans `SaveManager.data["survival_record"]` et affiché sur la carte du mode.
  * **Chasse aux boss** (§ 12.4) : `boss_chain` enchaîne les gardiens **déjà
    vaincus** sans écran ni soin, 2 potions pour toute la chasse.
  * **Défi du jour** (§ 12.5) : `DailySeed` (AAAAMMJJ) sème le niveau — même
    graine, même arène sur tous les téléphones ; un modificateur par jour
    (`damage` ×2, `night`, `fast` ×1,25, `one_life` sans réapparition) et une
    **série de jours consécutifs** (`daily.streak`).
- `scenes/ui/ModeSelect.tscn` : les six modes sont jouables, la carte Survie
  affiche le record et la carte Défi du jour le modificateur et la série.

**Deux correctifs trouvés en testant ces modes (18 oct.) :**
1. *Les ennemis n'attaquaient jamais une joueuse immobile.* Dans `_state_chase`,
   le corps à corps encerclait à 3 m (`STRAFE_RADIUS`) **sans demander le jeton
   d'attaque** (§ 9) : deux ennemis tournaient indéfiniment autour d'une joueuse
   qui ne bougeait pas, et aucune vague ne se terminait — la Survie se gagnait en
   posant le téléphone. Le jeton est maintenant demandé dans l'encerclement
   (`_can_attack()`), donc au plus 2 ennemis approchent et frappent, les autres
   continuent de tourner.
2. *Aucune pression dans une arène fermée.* Le soldat a 9 m de vue et
   apparaissait sur le bord du disque (12 m) : il ne voyait pas la joueuse
   immobile. Désormais, en arène (`layout = "arena"`), `WaveSpawner3D` appelle
   `EnemyBase3D.hunt()` à l'apparition (§ 3.1 : dans une arène fermée, il n'y a
   nulle part où se cacher). Deux vérifications de comportement de plus dans
   `Phase6Test` (la vague entre dans l'arène, la joueuse immobile perd de la vie).

**Tests :**
```bash
godot --headless --path . res://tests/Phase6Test.tscn   # 128 vérifications
PHASE6_ONLY=fight,survival godot --headless --path . res://tests/Phase6Test.tscn
```

**À valider sur téléphone (§ 28) :** sortir à temps des disques rouges (charge,
sabre, pluie de flèches), voir les 3 phases du capitaine puis du général,
enchaîner deux gardiens en Chasse aux boss, choisir un bonus entre deux vagues
de Survie et vérifier que le record survit au redémarrage ; 30 FPS minimum.

**Limites connues (phases suivantes) :** les 4 armes supplémentaires et les
alliées jouables du § 14 arrivent avec les phases suivantes.

## L. PHASE 7 — Coop WiFi à deux joueuses (§ 22)

**Ce qui est dans le projet :**
- `autoload/Network.gd` : toute la partie réseau. ENet/UDP **port 7777**
  (2 joueuses), découverte par broadcast UDP **port 7778** avec expiration à
  5 s, connexion par **IP manuelle** en secours, `launch_coop_level()`,
  `restart_coop_level()` et les helpers de difficulté
  (`coop_count_mult()`, `coop_max_on_screen()`). `is_coop()` ignore
  l'`OfflineMultiplayerPeer` que Godot installe en solo — sans ce test, tout le
  jeu se croirait en réseau hors ligne.
- `scenes/ui/Lobby.tscn` (**menu → Coop WiFi**) : bouton « Héberger » → l'IP
  s'affiche en grand, choix du niveau, « Commencer » grisé tant que personne
  n'est connecté ; côté invité, un bouton par partie détectée **et** un champ
  d'IP. Le lobby réutilise `lane_02` (couloir) et `arena_01` (arène).
- `scripts/level/CoopDirector.gd` : tout ce qui est réseau dans un niveau.
  Il crée un `Player3D` par pair (`MultiplayerSpawner`), un
  `MultiplayerSynchronizer` par joueur et par ennemi (20 Hz), reçoit les coups
  de l'invitée (`Network.request_hit`), envoie l'instantané de niveau 5 fois par
  seconde (timer, objectif, vie du gardien) et gère réanimation/déconnexion.
- **Hôte autoritaire** (§ 22.1) : `LevelBase3D._process()` laisse l'hôte
  simuler ; chez l'invitée, `WaveSpawner3D` ne tourne pas (`finished`), les
  ennemis sont des reflets sans IA (`EnemyBase3D._physics_process`) et les
  coups partent en RPC. Vérifié de bout en bout : un coup de l'invitée traverse
  le réseau, l'hôte l'applique, la vie revient répliquée.
- **Lissage** : Godot 4.3 n'interpole pas les `MultiplayerSynchronizer`. On
  réplique donc `net_position` (et non `position`) et la copie distante glisse
  vers la valeur reçue (`Player3D._follow_network`), sinon 20 Hz se voit.
- **Difficulté coop** (§ 22.3) : `Network.coop_count_mult()` (×1,3, arrondi au
  supérieur), `coop_max_on_screen()` (6) et `GameState.coop_health_mult()`
  (×1,5) sont appliqués par le spawner et par les ennemis.
- **Réanimation** : tomber en coop n'est pas mourir — la joueuse passe `downed`,
  les ennemis l'ignorent, l'autre a **10 s** pour la relever (« Interaction »
  maintenue 2 s à moins de 2,5 m), sinon le niveau échoue. La jauge est celle de
  l'interaction existante ; le message s'affiche en clair.
- **Déconnexion** : l'hôte qui part prévient l'invitée (`_on_server_disconnected`
  → `fail_offline`), l'invitée qui part laisse l'hôte continuer en solo
  (« Joueuse n a quitté la partie — tu continues en solo »).

**Tester sur deux téléphones (5 min) :**
1. Les deux téléphones sur le **même WiFi**. Le plus fiable : le **hotspot de
   l'un des deux** (certaines box isolent les clients entre eux).
2. Téléphone A : `Coop WiFi` → **Héberger une partie** → noter l'IP affichée
   (ex. `192.168.43.1`).
3. Téléphone B : `Coop WiFi` → **Rejoindre une partie** → la partie de A
   apparaît au bout de 1-2 s, sinon taper l'IP à la main → **Se connecter**.
4. A : choisir le niveau → **Commencer**. Le niveau se charge chez les deux.
5. À vérifier : chaque joueuse bouge *sa* joueuse ; les ennemis sont les mêmes
   des deux côtés ; le timer est identique ; une joueuse à 0 vie tombe (message
   « à terre ») et l'autre la relève en maintenant *Interaction* à côté d'elle ;
   couper le WiFi de B affiche un message clair chez A (et inversement).

**Tester sur l'ordinateur (deux instances, sans téléphone) :**
```bash
# terminal 1 (invitée, se connecte à 127.0.0.1)
PHASE7_ROLE=guest godot --headless --path . res://tests/Phase7Net.tscn

# terminal 2 (hôte)
PHASE7_ROLE=host godot --headless --path . res://tests/Phase7Net.tscn
```
Chaque instance affiche `PHASE 7 RÉSEAU (host|guest) : OK` et sort en code 0.

**Tests :**
```bash
godot --headless --path . res://tests/Phase7Test.tscn   # 49 vérifications, sans second appareil
PHASE7_ONLY=host  godot --headless --path . res://tests/Phase7Test.tscn
PHASE7_ONLY=downed godot --headless --path . res://tests/Phase7Test.tscn
```
`Phase7Test` ouvre un vrai serveur ENet (aucun client) pour que
`is_coop()`/`is_host()` soient vrais, puis vérifie le niveau coop, la
difficulté, la réplication et la chute/réanimation ; la dernière section coupe
la connexion et vérifie que le solo n'a pas bougé.

**Limites connues :**
- les niveaux **avec gardien** ne sont pas proposés en coop : chez l'invitée le
  boss n'est qu'un reflet (vie répliquée, attaques non simulées).
- pas d'interpolation d'animation pour la copie distante (elle rejoue
  `idle`/`death` selon l'état) : les attaques de l'autre joueuse ne sont pas
  encore visibles.
- la réanimation n'affiche pas de jauge dédiée (celle de l'interaction sert).
- deux joueuses maximum (§ 22, `MAX_CLIENTS = 1`).

## M. PHASE 8 — Son, traductions, succès, objectifs du jour, performance (§ 17, § 24, § 25, § 28)

**Ce qui est dans le projet :**
- `autoload/AudioManager.gd` : **18 bruitages** et **4 morceaux** (accueil +
  3 couches de tambours) chargés **une seule fois** au démarrage — aucun
  `load()` en plein combat. Le pool de 12 `AudioStreamPlayer` évite de couper un
  son quand un autre démarre ; les voix positionnelles sont limitées à **8**,
  portée 14 m, sans réverbération (§ 25).
- **Musique dynamique** : les 3 couches (`layer_calm`, `layer_tension`,
  `layer_combat`, même tempo, boucle de 4,80 s) démarrent ensemble et restent
  alignées à l'échantillon ; l'intensité (ennemis à l'écran, vie) fait monter
  la 2ᵉ puis la 3ᵉ couche avec un **crossfade de 0,5 s**. Les WAV sont
  synthétisés par `python tools/generate_audio.py` (aucun enregistrement réel
  n'existe encore) et rebouclés dans le code, ce qui marche aussi dans l'APK.
- **Sous-titres** (§ 17) : `AudioManager.play_voice(&"level_start")` émet
  toujours `voice_line` ; le sous-titre s'affiche **même sans fichier audio**.
  Les emplacements (`assets/audio/voice/`, fr / en / fon) attendent des
  locuteurs natifs ; voir `assets/audio/voice/LISEZ-MOI.txt`.
- **Traductions** (§ 24) : `assets/i18n/{fr,en,fon}.po` — **166 textes** dans
  chaque langue, le français servant de clé. `autoload/Localizer.gd` traduit
  automatiquement tout `Label`/`Button` ajouté à l'arbre et retraduit l'écran
  au changement de langue, **sans redémarrage** ; les textes construits avec
  des nombres passent par `Localizer.set_text()` (la traduction se fait avant
  le formatage). Un texte absent du `.po` reste en français, jamais vide.
  `Réglages → Langue` pilote `TranslationServer`.
- **Succès** : 12 fiches `data/achievements/*.tres` (compteur + seuil), donc
  ajouter un succès ne touche pas au code. Les compteurs vivent dans
  `SaveManager.data["stats"]` et progressent en écoutant `Events` : aucun
  script de gameplay ne connaît les succès. Un déblocage s'écrit dans la
  sauvegarde, affiche un bandeau de 3 s et reste acquis. **Écran des succès**
  (menu principal → Succès) : une ligne par fiche, jauge et « 7 / 20 »,
  compteur en tête, titres cachés tant qu'ils sont verrouillés.
- **Objectifs du jour** : 3 buts tirés de la date (`DailySeed`), suivis à part
  des compteurs de succès (ils repartent de zéro chaque jour), affichés dans
  **Choix du mode**, payés **150 cauris** une seule fois quand les trois sont
  atteints.
- **Performance** (§ 25) : `autoload/Quality.gd` applique Faible / Moyenne /
  Haute (échelle 3D, ombre blob ou vraie ombre 1024 px, contour de la joueuse,
  densité des particules) et propose **de lui-même** de descendre d'un cran si
  le jeu tient **moins de 24 images/s pendant 5 s** — proposition refusable,
  jamais imposée. Le décor répété passe en `MultiMesh`, les nombres de dégâts
  et les particules d'impact sont **remis au pool** au lieu d'être recréés.
- **Export** : le preset Android exclut `tests/`, `tools/`, les sources
  (`.blend`, `.psd`, `.kra`, `.xcf`) et les `.md`, active `arm64-v8a` et déclare
  les permissions `VIBRATE` + `INTERNET` (§ 26).

**Tests :**
```bash
godot --headless --path . res://tests/Phase8Test.tscn   # 95 vérifications
PHASE8_ONLY=audio,succes godot --headless --path . res://tests/Phase8Test.tscn
```
Le test couvre la banque de sons, le fondu d'intensité, les 8 voix 3D, les
sous-titres, les 3 langues (bascule à chaud et clé inconnue laissée en
français), les 12 succès de bout en bout (compteurs, déblocage unique, bandeau,
écran), les objectifs du jour et la récompense unique, puis la qualité
(Faible/Moyenne/Haute, proposition sous 24 images/s), le pooling des effets et
les filtres d'export. Il restaure la sauvegarde et les réglages à la fin.

**Planche d'assets :** `tools/slice_asset_sheet.gd` découpe une planche posée
sur un fond uni (`assets/ui/source/planche_assets.webp` par défaut) en PNG
détourés, plus `manifest.json` et une planche-contact HTML numérotée :
```bash
godot --headless --path . --script res://tools/slice_asset_sheet.gd -- \
    --source=res://assets/ui/source/planche_assets.webp \
    --out=res://assets/ui/sliced --min-area=400 --padding=4 \
    --gallery=res://export/planche_assets.html
```
Le fond n'est retiré que par **remplissage depuis les bords** : un motif de la
couleur du fond *à l'intérieur* d'un dessin (drapé, bijou) reste intact ; les
pixels de contour encore teintés sont dépollués. `--dry-run` liste les pièces
sans rien écrire. Les images sources restent hors de l'APK (`assets/ui/source`
est exclu de l'export).

Pour **nommer** les pièces, ouvrir `export/planche_assets.html`, remplir
`assets/ui/source/planche_assets.noms.txt` (gabarit déjà numéroté, avec taille
d'origine), puis relancer avec `--names=res://assets/ui/source/planche_assets.noms.txt --clean` :
```
12=reine_dahomey        → reine_dahomey.png
13=garde du palais      → garde_du_palais.png   (espaces et accents retirés)
```
Les pièces non nommées gardent `asset_NN` ; un doublon devient `nom_2` ; un
numéro hors planche est signalé. `--clean` ne retire que les PNG, leurs
`.import` et le manifeste du dossier de sortie.

**Limites connues :**
- l'audio et les voix sont **provisoires** : tambours synthétisés, aucun
  enregistrement en fon. Les sous-titres fonctionnent, pas encore les voix.
- le fon est traduit pour les textes du jeu, mais **pas relu par un locuteur
  natif** (les entrées concernées portent `#. À TRADUIRE` dans le `.po`).
- l'auto-adaptation se contente de **proposer** un cran en moins : pas de
  résolution dynamique ni de réduction automatique de la distance d'affichage.
- les succès ne sont pas synchronisés entre deux téléphones en coop (chacun
  garde les siens).

## N. PHASE 9 — Vrais modèles 3D : la chaîne est prête (§ 6.2, § 6.3, § 6.6)

Les `.glb` du modeleur ne sont pas encore livrés ; tout ce qui les reçoit, les
mesure et les branche est en place et vérifié.

**Ce qui est dans le projet :**
- **Branchement sans code** (§ 6.6) : `PlayerData.model_scene`,
  `EnemyData.model_scene` et `BossData.model_scene` remplacent la poupée de test.
  Côté ennemi, `model_scale` agrandit le modèle **et** ses collisions
  (`EnemyBase3D.scale_collision`), ce qui couvre brute et chef (§ 15.2).
- **Animations** : `CharacterAnimation` construit l'`AnimationTree` à partir du
  premier `AnimationPlayer` du modèle, avec les 10 états du § 20.5. Un modèle
  incomplet est signalé au lieu de figer le personnage.
- **Budgets** (§ 6.2) : `scripts/tools/ModelBudget.gd` mesure triangles,
  appels de dessin (= surfaces), matériaux et animations ; le rôle et donc le
  plafond viennent du nom de fichier (`hero_`, `enemy_`, `boss_`, `weapon_`,
  `prop_`…). `tools/check_model_budgets.gd` parcourt `assets/models/`, imprime un
  rapport et **sort en code 1** si un modèle dépasse ou ne s'ouvre pas.
- `assets/models/LISEZ-MOI.txt` : noms attendus, conventions d'export, états
  d'animation, commande de vérification.

**Tests :**
```bash
godot --headless --path . res://tests/Phase9Test.tscn   # 31 vérifications
PHASE9_ONLY=budgets,remplacement,glb godot --headless --path . res://tests/Phase9Test.tscn
```
Le test vérifie les plafonds par rôle, la mesure (triangles, appels, matériaux,
10 animations), le refus d'un modèle trop lourd ou trop découpé, le
remplacement de la poupée chez la joueuse **et** chez l'ennemi (échelle 1,3 et
collision 0,52 incluses), l'état `run` atteint dans l'`AnimationTree`, et un
aller-retour `.glb` (GLTFDocument) relu et remesuré comme un fichier de
modeleur.

**Limites connues :**
- **aucun modèle réel** n'est encore dans `assets/models/` : la poupée de test
  reste le rendu par défaut.
- l'export glTF de Godot ne transporte pas les `AnimationPlayer` ; les modèles
  animés viennent de Blender (les actions y sont exportées). L'aller-retour du
  test ne prouve donc que la géométrie et les matériaux.
- le retargeting Mixamo et les textures de costume demandent les fichiers
  sources ; rien ne peut être vérifié avant leur livraison.
- les budgets de `prop` sont une marge de travail : le § 6.2 ne donne qu'un
  plafond pour l'arène entière (< 60 000 tris, ≤ 6 appels).
