# GUERRIÈRE D'ABOMEY — Dossier de production complet (VERSION 3D)

> Document à donner à Claude (idéalement **Claude Code**) pour construire le jeu phase par phase.
> Jeu mobile Android **3D low-poly**, **hors ligne**, action-aventure et combat, **coop WiFi local à 2 joueurs**.
> Moteur : **Godot 4.x (GDScript)**. Poids cible : **< 120 Mo**. Cible : **téléphones d'entrée de gamme, 30 FPS stable**.
> Ce fichier remplace la version 2D. Il est autonome : tout ce qu'il faut est dedans.

---

## TABLE DES MATIÈRES

1. [Comment utiliser ce dossier](#1-comment-utiliser-ce-dossier)
2. [Vision et piliers](#2-vision-et-piliers)
3. [Choix 3D : le mode mixte et la caméra automatique](#3-choix-3d--le-mode-mixte-et-la-caméra-automatique)
4. [Contraintes techniques 3D](#4-contraintes-techniques-3d)
5. [Direction artistique 3D](#5-direction-artistique-3d)
6. [Pipeline des assets 3D (Blender → Mixamo → Godot)](#6-pipeline-des-assets-3d)
7. [Contrôles tactiles](#7-contrôles-tactiles)
8. [Système de combat (valeurs en mètres)](#8-système-de-combat-valeurs-en-mètres)
9. [Ennemis](#9-ennemis)
10. [Boss](#10-boss)
11. [Pièges](#11-pièges)
12. [Modes de jeu](#12-modes-de-jeu)
13. [Courbe de difficulté et niveaux](#13-courbe-de-difficulté-et-niveaux)
14. [Économie, armes, progression](#14-économie-armes-progression)
15. [Personnages : fiches de modélisation 3D](#15-personnages--fiches-de-modélisation-3d)
16. [Écrans et interface](#16-écrans-et-interface)
17. [Audio](#17-audio)
18. [Architecture du projet](#18-architecture-du-projet)
19. [Couches de collision et conventions](#19-couches-de-collision-et-conventions)
20. [Squelettes de code 3D](#20-squelettes-de-code-3d)
21. [Données (Resources)](#21-données-resources)
22. [Multijoueur coop WiFi](#22-multijoueur-coop-wifi)
23. [Sauvegarde](#23-sauvegarde)
24. [Traductions](#24-traductions)
25. [Performance 3D entrée de gamme](#25-performance-3d-entrée-de-gamme)
26. [Export Android](#26-export-android)
27. [PROMPT MAÎTRE](#27-prompt-maître)
28. [Plan de production : phases avec prompts](#28-plan-de-production--phases-avec-prompts)
29. [Tests et qualité](#29-tests-et-qualité)
30. [Publication et monétisation](#30-publication-et-monétisation)
31. [Respect culturel](#31-respect-culturel)
32. [Risques et solutions](#32-risques-et-solutions)
33. [Glossaire](#33-glossaire)

---

## 1. Comment utiliser ce dossier

**Honnêteté importante :** aucun prompt ne produit un jeu « parfait » en une seule réponse, et la 3D demande plus de travail que la 2D (modèles, animations, optimisation). La méthode qui fonctionne :

1. Ouvre **Claude Code** dans un dossier vide. Place ce fichier dans le projet sous le nom `DESIGN.md`.
2. Donne le **PROMPT MAÎTRE** (section 27) une seule fois.
3. Demande **une phase à la fois** (section 28) : `PHASE 0`, puis `PHASE 0.5`, `PHASE 1`, etc.
4. Après chaque phase : **teste sur ton téléphone**, note les bugs, renvoie-les à Claude, puis avance.
5. Utilise **Git** : un commit après chaque phase réussie.

**Qui fait quoi :**
- **Claude** : tout le code, les scènes, les données, l'UI, les personnages provisoires (capsules colorées avec arme), les fiches de modélisation, les scripts d'import.
- **Toi / un modeleur 3D** : les vrais modèles (Blender), les textures peintes. Outils d'IA « image vers 3D » possibles pour une base, mais le résultat doit être nettoyé et réduit au budget de triangles (section 6).
- Les modèles provisoires sont remplaçables **sans toucher au code** (section 6.6).

**Multijoueur WiFi :** Godot 4 gère le réseau local sans internet. Un téléphone crée un hotspot (ou même box WiFi). Aucune donnée mobile consommée.

---

## 2. Vision et piliers

**Titre :** Guerrière d'Abomey
**Genre :** action-aventure / combat 3D low-poly stylisé
**Plateforme :** Android (APK), hors ligne, coop WiFi local
**Session :** 3 à 5 minutes par niveau

**Histoire :** tu es une jeune recrue des Agojié, les guerrières du royaume du Dahomey. De chapitre en chapitre tu deviens une légende : tu libères des captifs, protèges les villages, affrontes des chefs ennemis et défends Abomey.

| Pilier | Signification concrète |
|---|---|
| Combat satisfaisant | Chaque coup « claque » : hit-stop, tremblement de caméra, son, particules |
| Sessions courtes | 3 à 5 min par niveau |
| Difficulté juste | Progressive, checkpoints, jamais injuste |
| Identité forte | Dahomey, appliqués d'Abomey, tambours, fon |
| Léger malgré la 3D | Low-poly peint à la main, tourne sur petit téléphone, partage par WhatsApp |

---

## 3. Choix 3D : le mode mixte et la caméra automatique

### 3.1 Pourquoi un mode mixte
Le tactile n'a que deux pouces. Gauche = joystick, droite = 4 boutons d'action. **Il n'y a pas de place pour contrôler une caméra** : la caméra doit donc être **automatique**. Deux types de niveaux :

| Type | Utilisé pour | Mouvement | Caméra |
|---|---|---|---|
| **LANE** (couloir) | Aventure, Sauvetage, Escorte | Avancer à gauche/droite, profondeur limitée (±3 m) | 3/4 fixe qui suit les joueurs, légèrement au-dessus |
| **ARENA** (arène) | Boss, Survie, Chasse aux boss, Défi du jour (parfois), Arène | Libre à 360° sur un disque de 14 m de rayon | Derrière la guerrière, **verrouillage automatique** sur l'ennemi le plus proche, orbite auto |

### 3.2 Règles de caméra
- **LANE :** position = centre des joueurs + décalage (0 m, 4,5 m de haut, 7,5 m de recul), regarde le centre + 1 m. Suivi fluide (lissage exponentiel 6/s). Champ de vision (FOV) 50°.
- **ARENA :** distance 7 m, hauteur 4 m, FOV 55°. Si une cible est verrouillée, la caméra se place derrière la joueuse, alignée sur la ligne joueuse→cible. Sans cible, elle suit la direction de déplacement lentement.
- **Verrouillage :** cible = ennemi le plus proche dans un rayon de 8 m, avec priorité à celui qui attaque. Changement de cible : toucher un ennemi à l'écran, ou auto si la cible meurt. Un petit anneau doré marque la cible.
- **Option :** glisser le doigt dans la zone centrale pour tourner la caméra (désactivable, désactivée par défaut).
- **Occlusion :** pas de murs entre caméra et joueuse (décors conçus pour). Objets proches qui gênent : transparence progressive.
- **Coop :** en LANE, la caméra cadre les deux joueurs (zoom arrière jusqu'à 10 m de distance entre eux). En ARENA, la caméra suit le joueur local.

### 3.3 Mouvement relatif à la caméra
Le joystick pousse la joueuse **dans le sens de l'écran** (haut = vers le fond de l'écran), calculé à partir de l'orientation de la caméra (voir code §20.4).

---

## 4. Contraintes techniques 3D

| Élément | Valeur |
|---|---|
| Moteur | Godot 4.3 ou plus récent |
| Langage | GDScript typé |
| Rendu | **Compatibility (OpenGL ES 3.0)** pour couvrir le maximum de téléphones. (Mobile/Vulkan offre un meilleur rendu mais exclut les vieux appareils.) |
| Résolution de rendu | 1280×720 de base ; option d'échelle 3D (`scaling_3d/scale`) 0,6 à 1,0 |
| FPS | 30 stable (cible), plafond 60 |
| RAM | 2 Go minimum, jeu < 450 Mo en mémoire |
| APK | < 120 Mo (idéal 80 Mo) |
| Ennemis à l'écran | 5 max (6 en coop) |
| Lumières | 1 DirectionalLight3D + max 3 lumières ponctuelles, **sans ombres** par défaut |
| Ombres | Option « Haute » : 1 cascade, 1024 px, joueuse seulement. Par défaut : ombre « blob » (Decal/Sprite3D) |
| Post-traitement | Aucun SSAO/SSR/glow. Brouillard simple autorisé |
| Format 3D | glTF 2.0 (.glb) |
| Textures | 512×512 persos, 1024 décors, atlas, compression ETC2/ASTC |
| Android min | API 24 (Android 7) |
| Architectures | arm64-v8a + armeabi-v7a |
| Réseau | LAN uniquement (ENet) |

**Réglages `project.godot` à imposer :**
- `display/window/size/viewport_width = 1280`, `viewport_height = 720`
- `display/window/handheld/orientation = 6`
- `rendering/renderer/rendering_method = "gl_compatibility"`
- `rendering/scaling_3d/mode = 0` (bilinéaire), échelle réglable
- `rendering/textures/vram_compression/import_etc2_astc = true`
- `input_devices/pointing/emulate_mouse_from_touch = true` (le doigt doit produire un clic souris, sinon **aucun `Button`** du jeu ne réagit au doigt ; le joystick et les boutons d'action du § 7 lisent le tactile *et* la souris en ignorant les doublons, ils ne se déclenchent donc qu'une fois)
- `physics/common/physics_ticks_per_second = 60`
- `application/run/max_fps = 60`

---

## 5. Direction artistique 3D

**Style :** 3D low-poly « peint à la main » : volumes simples, textures peintes avec aplats et dégradés doux, contour léger (outline) sur personnages, silhouettes très lisibles. Aucun réalisme lourd.

**Palette :**

| Nom | Hex | Usage |
|---|---|---|
| Rouge Dahomey | `#B3261E` | Tenues, danger, vie |
| Or royal | `#E3A92B` | Cauris, UI, boss |
| Indigo | `#1F2A5C` | Nuit, ombres, fond UI |
| Ocre terre | `#C77D3A` | Murs du palais, sol |
| Vert forêt | `#2E6B3A` | Forêt |
| Crème | `#F5E9D0` | Tissus clairs, texte |
| Noir charbon | `#1A1411` | Contours |
| Bleu fleuve | `#2C7DA0` | Eau, énergie spéciale |

**Motifs :** appliqués d'Abomey sur : vêtements, bannières, murs du palais, sols, cadres d'interface.

**Rendu stylisé léger :**
- Shader maison « cel-shading » à 3 paliers de lumière (un seul passage, très léger) pour personnages.
- **Outline** par coque inversée (inverted hull) : mesh dupliqué, faces inversées, légèrement gonflé. Option désactivable en qualité « Faible ».
- Éclairage de décor **pré-calculé dans les textures** (peint ou baké dans Blender), pas de lumières temps réel multiples.
- Brouillard de profondeur coloré par arène (ocre / vert / bleu / indigo la nuit).

**Arènes et décors :**
1. Cour du palais d'Abomey (murs ocre, bas-reliefs, colonnes)
2. Marché (étals, tissus colorés suspendus)
3. Forêt (arbres low-poly, lianes, brume)
4. Fleuve (berge, ponton, pirogues, eau en plan animé par texture)
5. Champ de bataille (herbes sèches, étendards, fumée en billboards)
6. Fort ennemi de nuit (torches, palissades)

Chaque décor : modules réutilisables (murs, colonnes, arbres) assemblés dans des scènes, matériau partagé (atlas) pour minimiser les draw calls.

**Animations (par personnage) :** idle, walk/run, attack1, attack2, attack3, dodge, guard_loop, guard_perfect, special, hurt, death, victory (+ interact pour libérer un prisonnier).

**UI :** boutons grands (min 96×96 px), contours or, fond indigo translucide, police lisible (Baloo 2 / Lilita One, libres de droits), icônes simples.

---

## 6. Pipeline des assets 3D

### 6.1 Outils
| Besoin | Outil |
|---|---|
| Modélisation, UV, baking | **Blender 4.x** (gratuit) |
| Peinture de textures | Blender Texture Paint, Krita, GIMP |
| Rig + animations | **Mixamo** (gratuit, compte Adobe) puis retouches dans Blender |
| Moteur | Godot 4 |
| Audio | Audacity, Reaper (essai), sons libres |

### 6.2 Budgets
| Objet | Triangles | Os | Texture | Matériaux |
|---|---|---|---|---|
| Héroïne | 4 000 à 6 000 | ≤ 40 | 1 × 1024² | 1 |
| Alliée | 4 000 à 6 000 | ≤ 40 | 1 × 1024² (ou 512²) | 1 |
| Ennemi standard | 2 000 à 3 500 | ≤ 30 | 512² | 1 |
| Brute / chef | 3 500 à 5 000 | ≤ 35 | 1024² | 1 |
| Boss | 6 000 à 9 000 | ≤ 45 | 1024² | 1-2 |
| Arme | 300 à 800 | 0 | partage atlas perso | 0 |
| Décor (arène complète) | < 60 000 total visibles | — | atlas 2048² max | ≤ 6 |
| Total à l'écran (une frame) | **< 120 000 triangles** | — | — | **< 100 draw calls** |

### 6.3 Conventions de modélisation
- Échelle : **1 unité = 1 mètre**. Héroïne : 1,70 m. Boss : 2,6 à 3,4 m.
- Origine aux **pieds**. Le personnage regarde **−Z** (avant de Godot) dans Blender après export (vérifier l'axe).
- Pose de départ : **T-pose** (nécessaire pour Mixamo).
- Nommage : `hero_nawi.glb`, `enemy_soldier.glb`, `boss_captain.glb`, `weapon_sabre.glb`, `prop_cage.glb`.
- Application des transformations (Ctrl+A) avant export, normales cohérentes, pas de n-gones.
- Export glTF 2.0 binaire (.glb), « +Y Up », compression Draco désactivée (non supportée partout), animations exportées dans des fichiers séparés.

### 6.4 Rigging et animation avec Mixamo
1. Exporter le modèle en FBX (T-pose) depuis Blender.
2. Téléverser dans Mixamo → placer les marqueurs → rig automatique.
3. Télécharger les animations : *Idle*, *Running*, *Sword And Shield Slash* (plusieurs), *Standing Block*, *Dodge / Roll*, *Hit Reaction*, *Death*, *Victory*… **sans la peau** (« Without Skin ») sauf la première.
4. Dans Godot : importer en « Skeleton3D » avec **retargeting Humanoïde** (BoneMap + SkeletonProfileHumanoid) pour que **toutes les animations fonctionnent sur tous les personnages**.
5. Construire un `AnimationTree` avec une `AnimationNodeStateMachine`.
6. Les événements d'attaque (activer la Hitbox, ouvrir la fenêtre de combo, son) sont des **Call Method Tracks** dans les clips.
7. Créer des animations propres (spécial, interaction) en retouchant dans Blender si nécessaire.

> Remarque : les animations Mixamo sont libres d'usage dans un jeu (vérifier les conditions actuelles d'Adobe), mais **tous les jeux qui les utilisent se ressemblent** : prévoir de retoucher les plus visibles (attaques, spécial) pour une identité propre.

### 6.5 Arme
Chaque arme est un mesh séparé attaché à la main via **BoneAttachment3D** (os de la main droite). Changer d'arme = changer la scène enfant. Les `Hitbox3D` sont aussi enfants de l'attachement ou du corps.

### 6.6 Remplacement sans toucher au code
- Le personnage est une scène `.tscn` avec un nœud `Model` (le `.glb` instancié) + un `AnimationTree`. Le code ne connaît **que** les noms d'animations (`idle`, `run`, `attack1`, etc.) et les nœuds `HitboxPoints`.
- Pour changer de modèle : remplacer l'instance `Model`, garder les mêmes noms d'animation. Aucun script modifié.
- Les ressources (`CharacterVisual.tres`) pointent vers la scène du modèle via `@export var model_scene: PackedScene`.

### 6.7 Génération IA (optionnel)
Des outils « texte/image vers 3D » existent. Règle : on les utilise comme **base de forme**, puis on **retopologise** (réduction des triangles, topologie propre pour animer), on repeint les textures dans la palette du jeu et on vérifie les budgets. Ne jamais intégrer un modèle IA brut (trop lourd, pas animable).

---

## 7. Contrôles tactiles

Disposition paysage 1280×720 (interface 2D dans un `CanvasLayer` au-dessus de la 3D).

| Contrôle | Position (centre) | Taille |
|---|---|---|
| Joystick virtuel flottant | moitié gauche, zone bas 320×320 | pastille 110 px |
| Attaque | (1130, 580) | 150 px |
| Esquive | (970, 620) | 110 px |
| Garde | (990, 470) | 110 px |
| Spécial | (1140, 430) | 110 px |
| Pause | (1220, 50) | 70 px |
| Interaction (apparaît près d'un prisonnier/coffre) | (850, 540) | 110 px |

**Règles :**
- Multitouch obligatoire : un doigt par contrôle (`index` des événements tactiles).
- Zone morte du joystick : 12 %. Vitesse proportionnelle à l'inclinaison.
- Vibration courte sur coup réussi (`Input.vibrate_handheld(15)`), désactivable.
- Réglages : taille (80-130 %), opacité, inversion gauche/droite, vibration.
- **Buffer d'entrée :** touche pressée jusqu'à 0,15 s avant la fin d'une action est mémorisée.
- Mode arène : toucher un ennemi à l'écran change la cible verrouillée.
- Clavier/manette pour tests PC : WASD/stick + J (attaque), K (esquive), L (garde), I (spécial), E (interaction).

---

## 8. Système de combat (valeurs en mètres)

Toutes les valeurs sont dans `data/balance.tres` pour être ajustables sans code.

### 8.1 Joueuse (niveau 1)
| Stat | Valeur |
|---|---|
| Vie max | 100 |
| Énergie spéciale max | 100 |
| Vitesse de course | 4,5 m/s |
| Vitesse en garde | 1,4 m/s |
| Accélération | 30 m/s² (arrêt net, contrôle précis) |
| Gravité | 20 m/s² |
| Rotation du modèle | 14 rad/s vers la direction |
| Dégâts de base | 10 |

### 8.2 Attaque et combo
| Coup | Dégâts (× arme) | Durée | Fenêtre d'enchaînement | Recul infligé | Avancée de la joueuse |
|---|---|---|---|---|---|
| Coup 1 | ×0,8 | 0,25 s | 0,30 s | 1,2 m | 0,4 m |
| Coup 2 | ×1,0 | 0,28 s | 0,30 s | 1,6 m | 0,5 m |
| Coup 3 (finisseur) | ×1,6 | 0,40 s | — | 4,4 m + projection | 0,8 m |

- **Aimant d'attaque :** pendant un coup, la joueuse pivote vers l'ennemi le plus proche dans un cône de 60° et 2,5 m, pour compenser l'imprécision tactile.
- Fenêtre ratée : retour au coup 1.
- Annulation par esquive possible dès la 4e frame (réactivité).
- **Hit-stop :** 0,05 s (coups 1-2), 0,09 s (coup 3), 0,15 s (spécial).

### 8.3 Esquive
- Durée 0,35 s, **invincibilité 0,25 s**, distance **3,6 m** dans la direction du joystick (ou vers l'arrière si aucune).
- Recharge 0,60 s.
- **Esquive parfaite** (< 0,12 s avant l'impact) : ralenti 0,3 s (échelle 0,3) et +10 énergie.

### 8.4 Garde
- Maintenu : −70 % de dégâts, vitesse réduite.
- **Garde parfaite :** bouton pressé dans les **0,18 s** avant l'impact → 0 dégât, ennemi étourdi 0,8 s, contre-attaque, +15 énergie.
- Stabilité : max 30, chaque coup bloqué −5, régénère 5/s ; à 0 : garde brisée, étourdi 0,6 s.

### 8.5 Spécial
- Coût 100 énergie. Gains : +6 par coup donné, +10 esquive parfaite, +15 garde parfaite, +3 si touchée.
- Un spécial par arme (§14.2). Invincible pendant l'animation, dégâts ×3, zone adaptée à l'arme.

### 8.6 Dégâts reçus
- Étourdissement 0,25 s, **invincibilité 0,8 s** ensuite.
- Vie à 0 : animation de mort, écran « Réessayer / Checkpoint (50 cauris) ».
- Potions : +30 vie.

### 8.7 Critiques et statuts
- Critique 8 % de base, ×1,5 dégâts, étincelle dorée.
- Statuts : saignement (3/s pendant 4 s), étourdissement, ralentissement (boue).

---

## 9. Ennemis

Valeurs « Normal ». Facile = vie ×0,7 / dégâts ×0,7. Difficile = ×1,3.

| Ennemi | Vie | Dégâts | Vitesse | Comportement | Dès |
|---|---|---|---|---|---|
| Soldat | 30 | 8 | 1,8 m/s | Approche, coup simple, télégraphe 0,4 s | Niv. 1 |
| Éclaireur | 20 | 6 | 4,0 m/s | Rapide, attaque puis recule, tourne autour | Niv. 3 |
| Archer | 18 | 10 | 1,4 m/s | Reste à 7 m, tire toutes les 2,2 s, ligne rouge de visée | Niv. 5 |
| Brute blindée | 90 | 16 | 1,2 m/s | Armure (bloque coups légers), vulnérable 0,9 s après son attaque lourde | Niv. 8 |
| Chef | 70 | 14 | 2,2 m/s | Buff +20 % vitesse aux alliés proches, invoque 1 soldat / 12 s | Niv. 10 |
| Garde d'alerte | 35 | 8 | 2,0 m/s | S'il te voit : alerte (+2 ennemis) | Niv. 8 (Sauvetage) |

Distances : vue 9 m, portée d'attaque 1,4 m (soldat), archer garde 7 m.

**IA (états) :** `IDLE → PATROL → CHASE → TELEGRAPH → ATTACK → RECOVER → HURT → DEAD`.

**Lisibilité 3D :**
- Télégraphe visible : flash blanc/rouge sur le modèle + son (0,3 à 0,5 s).
- **Jeton d'attaque :** max 2 ennemis attaquent simultanément ; les autres tournent autour à 3 m (`strafing`).
- Cible = joueuse la plus proche (important en coop).
- Évitement entre ennemis (séparation) pour ne pas se superposer.
- Déplacement : `NavigationAgent3D` pour contourner les obstacles (seulement si nécessaire) ; en LANE plat, simple poursuite en ligne droite.

---

## 10. Boss

Un boss **tous les 5 niveaux**, en **ARENA**. 3 phases (100-60 %, 60-30 %, 30-0 %). Dernier coup : **ralenti** 0,6 s à 0,2× + zoom caméra (FOV −10°).

| Boss | Chapitre | Vie | Attaques à apprendre |
|---|---|---|---|
| Capitaine des pillards | 1 (niv. 5) | 300 | Charge (zone au sol), sabre circulaire, appelle 2 soldats en phase 2 |
| Chef archer du fleuve | 2 (niv. 10) | 450 | Pluie de flèches (cercles rouges au sol), roulade, triple tir en phase 3 |
| Colosse blindé | 3 (niv. 15) | 700 | Frappe au sol (onde), saisie, armure qui casse après 3 gardes parfaites |
| Sorcier des ténèbres | 4 (niv. 20) | 850 | Téléportation, boules d'ombre, plonge l'arène dans la nuit |
| Général rival | 5 (niv. 25) | 1100 | Combos de 5 coups, esquive, mélange des attaques précédentes |

Tout boss : grande barre de vie, nom affiché avec animation à l'entrée, zones de danger **dessinées au sol** (decals rouges), récompense unique.

---

## 11. Pièges

| Piège | Effet | Télégraphe | Dégâts |
|---|---|---|---|
| Fosse | Chute = −20 vie, retour au bord | Bord sombre, poussière | 20 |
| Flèches murales | Salve toutes les 3 s | Fente qui clignote 0,5 s | 12 |
| Feu | Jet cyclique 1 s ON / 2 s OFF | Braises au sol | 8/s |
| Planche qui casse | Casse 0,6 s après contact | Craquements | chute |
| Pointes | Contact | Pointes visibles | 10 |
| Boue | Ralentit de 40 % | Texture sombre | 0 |

Les pièges blessent aussi les ennemis (tactique, fun).

---

## 12. Modes de jeu

### 12.1 Aventure
5 chapitres sur la carte du royaume. Chaque chapitre = 5 niveaux (LANE puis boss ARENA). Cinématiques en images fixes + texte, sautables.

### 12.2 Sauvetage (mode principal demandé)
Libérer des **prisonniers** (interaction de 2 s près de la cage) ou **escorter** un villageois à la sortie avant la fin du temps.

| Niveaux | Prisonniers | Ennemis | Pièges | Temps | Particularité |
|---|---|---|---|---|---|
| 1-3 | 1 | 3-4 soldats | aucun | 150 s | Tutoriel guidé |
| 4-7 | 2-3 | + éclaireurs, patrouilles | fosses, flèches | 130 s | Gardes en patrouille |
| 8-12 | 3-4 dispersés | + archers, gardes d'alerte | + feu | 110 s | Alerte = renforts |
| 13-17 | 4 | + brutes | tous | 100 s | **Nuit**, visibilité réduite (OmniLight autour de la joueuse, brouillard sombre) |
| 18+ | 4-5 | + chefs | tous | 90 s | Boss gardien |

Escorte : villageois (40 vie) qui suit la joueuse ; s'il meurt = échec.

### 12.3 Survie
Vagues sans fin en ARENA. Difficulté croissante toutes les 5 vagues. Choix de 1 bonus parmi 3 entre vagues. Boss toutes les 10 vagues. Record local.

### 12.4 Chasse aux boss
Enchaîner les boss déjà battus, sans pause, 2 potions. Score + temps.

### 12.5 Défi du jour (hors ligne)
Niveau généré par la **date du téléphone** (graine `AAAAMMJJ`) avec un modificateur du jour (dégâts doublés, nuit, ennemis rapides, pas de garde, une seule vie). Série (streak) de jours consécutifs.

### 12.6 Arène d'entraînement
Libre : choisir ennemis, arme ; mannequin ; test des armes avant achat.

### 12.7 Coop WiFi (2 joueurs)
Aventure, Sauvetage, Survie. Ennemis +50 % de vie, cauris partagés.

---

## 13. Courbe de difficulté et niveaux

1 nouvelle idée à la fois.

| Niveau | Nouveauté |
|---|---|
| 1 | Déplacement, attaque |
| 2 | Combo de 3 coups, cauris |
| 3 | Esquive, éclaireur |
| 4 | Garde, fosses |
| 5 | **Boss 1** (ARENA) |
| 6 | Garde parfaite, flèches murales |
| 7 | Premier spécial |
| 8 | Archer, gardes d'alerte |
| 9 | Brute blindée |
| 10 | **Boss 2** |
| 11-14 | Feu, chef, combinaisons |
| 15 | **Boss 3** |
| 16+ | Nuit, tout combiné |

**Étoiles :** ★ terminer · ★★ ≥ 50 % de vie ou temps argent · ★★★ bonus (aucun prisonnier blessé, temps or, combo de 10).

**Checkpoints :** un à mi-niveau. Une réapparition par niveau en Normal, illimité en Facile.

**Aide dynamique :** 3 échecs → proposer « mode assisté » (ennemis −20 %). 5 ★★★ d'affilée → proposer « défi ».

**Taille des niveaux LANE :** 60 à 140 m de long, 8 m de large (±4 m de profondeur jouable ±3 m pour la joueuse).

---

## 14. Économie, armes, progression

### 14.1 Monnaie
**Cauris** (ramassés, récompenses, coffres). Pas de monnaie premium en V1.
Gains moyens : niv. 1-5 : 30-60 ; 6-10 : 60-120 ; boss : 200-400.

### 14.2 Armes (5 armes, chacune avec son style, sa portée, son spécial)

| Arme | Dégâts | Vitesse | Portée | Spécial | Prix |
|---|---|---|---|---|---|
| Sabre (gbèkon) | 10 | Rapide | 1,6 m | Tourbillon (360° autour) | départ |
| Lance | 12 | Moyenne | 2,6 m | Percée en ligne droite (traverse les ennemis) | 200 |
| Arc | 7 | Moyenne | 18 m | Triple flèche en éventail | 350 |
| Massue | 18 | Lente | 1,5 m | Onde de choc au sol (zone 4 m) | 500 |
| Fusil à pierre | 25 | Très lente | 25 m | Tir perforant | 900 |

- Chaque arme : 5 niveaux d'amélioration (+10 % dégâts/niveau), prix : 80, 140, 220, 330, 500 cauris.
- Chaque arme a ses animations propres (sabre/lance/massue : mêlée ; arc/fusil : visée simplifiée, **auto-visée sur la cible verrouillée**).
- Armes supplémentaires possibles plus tard : bouclier + épée courte, hache, sagaie lancée.

### 14.3 Armures
Tissu (0 %), cuir renforcé (−10 % dégâts), plaques (−20 %, vitesse −5 %). Chaque armure change visiblement le modèle (pièces attachées).

### 14.4 Compétences (arbre à 3 branches)
| Branche | Compétences |
|---|---|
| Attaque | +dégâts, +critique, 4e coup au combo |
| Défense | +vie max, garde plus généreuse (+0,05 s), régénération légère |
| Esprit | Énergie plus rapide, esquive parfaite plus généreuse, spécial moins cher |

### 14.5 Alliées jouables
| Alliée | Style | Déblocage |
|---|---|---|
| Nawi | Équilibrée (sabre) | Départ |
| Hounon | Lancière, portée longue | Chapitre 1 |
| Adjovi | Archère, rapide | Chapitre 2 |
| Kpossou | Massue, force | Chapitre 3 |
| Capitaine Sènami | Polyvalente | Chapitre 5 |

*(Noms fictifs d'exemple à valider avec des sources béninoises.)* Techniquement, une alliée = un modèle différent + des stats différentes, avec le **même squelette humanoïde** (animations partagées).

### 14.6 Costumes
Cosmétiques seulement (textures alternatives du même modèle = **gratuit en triangles**). Inspirés des tissus et appliqués.

### 14.7 Succès
Premier sang · 10 combos · 100 gardes parfaites · 50 prisonniers sauvés · niveau sans dégâts · 7 jours de défi du jour d'affilée · tous les boss.

---

## 15. Personnages : fiches de modélisation 3D

> À donner à un modeleur 3D ou comme base pour la modélisation / génération. Style : section 5. Budgets : section 6.2.

### 15.1 Nawi (héroïne)
- Âge apparent 18-20 ans, 1,70 m, athlétique, posture droite.
- **Tenue :** haut court rouge, pagne indigo à frise dorée (appliqué), bandeau rouge, protections cuir aux avant-bras, perles, sac de cauris à la ceinture.
- **Couleurs :** rouge `#B3261E`, indigo `#1F2A5C`, or `#E3A92B`, peau et cheveux selon design final.
- **Arme de départ :** sabre courbe (gbèkon).
- **Livrables :** planche de personnage (face, profil, dos, 3/4), modèle 4 000 à 6 000 triangles en T-pose, texture 1024², déclinaisons de costume (textures).
- **Expression :** déterminée, regard direct.

### 15.2 Ennemis
- **Soldat :** tons olive/brun, lance courte ou sabre, petit bouclier. Silhouette carrée.
- **Éclaireur :** fin, capuche, deux dagues, couleurs claires. Silhouette en « X ».
- **Archer :** carquois dans le dos, grand arc, chapeau. Silhouette fine et haute.
- **Brute blindée :** large (×1,3), plaques cuir/métal, grande massue. Silhouette en « T ».
- **Chef :** étendard dans le dos, ornements, couleur rouge sombre.
- Règle : **silhouette unique** pour chaque type, reconnaissable en noir uni.

### 15.3 Boss
Taille ×1,6 à ×2, silhouette et couleur dominante uniques, accessoire emblématique. 1 modèle + 1 jeu d'animations spécifiques par boss.

### 15.4 Directives pour modeleur / IA
- Même éclairage, même angle pour toutes les planches.
- Modèle propre : edge loops aux articulations (coudes, genoux, épaules), pas de pièces qui se croisent.
- Textures : palette imposée, motifs d'appliqués, pas de textures photoréalistes.
- Pour les costumes : un seul UV, plusieurs textures.
- Fournir : `.blend` source + `.glb` export + textures PNG.

---

## 16. Écrans et interface

**Flux :** `Splash → Menu principal → Mode → Carte → Niveau → Résultat → Boutique → Carte`

| Écran | Contenu |
|---|---|
| Splash | Logo, chargement |
| Menu principal | Jouer, Coop WiFi, Armurerie, Succès, Réglages, Quitter. Fond : la guerrière en 3D qui respire (idle) devant le palais |
| Choix du mode | Cartes illustrées |
| Carte du royaume | Chemin avec nœuds, étoiles, verrous, boss ; carte 2D illustrée (légère) |
| Avant-niveau | Objectif, récompenses, arme/costume |
| HUD | Vie, énergie, cauris, timer, objectif, indicateurs prisonniers, pause, anneau de verrouillage |
| Pause | Reprendre, Recommencer, Réglages, Quitter |
| Résultat | Étoiles animées, cauris, bonus, « Suivant » |
| Armurerie | Armes, armures, costumes, améliorations, **aperçu 3D rotatif** du personnage (SubViewport léger) |
| Compétences | Arbre à 3 branches |
| Lobby coop | Créer / Rejoindre, IP en grand, liste de parties, « Prêt » |
| Réglages | Difficulté, langue, volumes, taille des boutons, vibration, **qualité graphique** (Faible/Moyenne/Haute), échelle 3D |

Animations UI : transitions 0,25 s, pulsation sur bouton principal, étoiles qui tombent.

---

## 17. Audio

- **Musique dynamique :** 3 couches de tambours (calme / tension / combat), crossfade 0,5 s selon nombre d'ennemis et vie.
- Instruments : tambours, calebasses, cloches, voix chantées.
- Effets : coups, garde, garde parfaite (note cristalline), cauris, victoire, défaite, pas (selon le sol).
- **Audio 3D positionnel** pour les sons des ennemis (`AudioStreamPlayer3D`, portée courte, sans réverbération).
- Voix en fon (locuteurs natifs) avec sous-titres.
- OGG Vorbis, budget < 25 Mo. Bus : `Music`, `SFX`, `Voice`.

---

## 18. Architecture du projet

```
guerriere-abomey/
├── project.godot
├── DESIGN.md                      # ce document
├── autoload/
│   ├── GameState.gd               # mode, niveau, joueurs, difficulté
│   ├── SaveManager.gd
│   ├── AudioManager.gd
│   ├── Settings.gd
│   ├── DailySeed.gd
│   ├── Network.gd
│   ├── FX.gd                      # hit-stop, slow-mo, shake caméra 3D
│   ├── AttackTokenManager.gd
│   └── Events.gd                  # bus de signaux
├── scenes/
│   ├── main/                      # Splash.tscn, MainMenu.tscn
│   ├── ui/                        # HUD, Pause, Result, Shop, Map, Settings
│   ├── characters/                # Player3D.tscn + modèles + visuels
│   ├── enemies/                   # EnemyBase3D.tscn + variantes
│   ├── bosses/                    # BossBase3D.tscn + 5 boss
│   ├── hazards/                   # Pit, ArrowTrap, Fire, BreakablePlank
│   ├── levels/                    # LevelBase3D.tscn (moteur unique), modules de décors
│   ├── camera/                    # CameraRig.tscn
│   ├── pickups/                   # Cauri, Potion, Chest
│   └── multiplayer/               # Lobby.tscn, CoopSpawner.tscn
├── scripts/
│   ├── combat/                    # Hitbox3D.gd, Hurtbox3D.gd, ComboController.gd, DamageInfo.gd
│   ├── ai/                        # EnemyBase3D.gd, états
│   ├── camera/                    # CameraRig.gd
│   ├── objectives/                # Objective.gd, Rescue.gd, Escort.gd, Survive.gd, ReachExit.gd, KillBoss.gd
│   ├── spawning/                  # WaveSpawner3D.gd, DailyGenerator.gd
│   ├── ui/                        # VirtualJoystick.gd, TouchButton.gd, HUD.gd
│   └── util/                      # ObjectPool.gd
├── shaders/                       # cel_shading.gdshader, outline.gdshader, water.gdshader
├── data/
│   ├── balance.tres
│   ├── weapons/*.tres
│   ├── enemies/*.tres
│   ├── levels/*.tres
│   ├── chapters/*.tres
│   ├── costumes/*.tres
│   └── achievements/*.tres
├── assets/
│   ├── models/ (characters, enemies, bosses, weapons, props, environment)
│   ├── animations/ (bibliothèque humanoïde partagée)
│   ├── textures/
│   ├── audio/ (music, sfx, voice)
│   ├── fonts/ ui/ vfx/
│   └── i18n/ (fr.po, en.po, fon.po)
├── tests/                         # scènes de test manuelles
└── export/                        # presets Android, keystore (HORS Git)
```

**Règles :**
1. Un script = une responsabilité.
2. Contenu en **Resources**, pas en dur.
3. Signaux via `Events.gd`.
4. Aucun chemin d'asset en dur dans la logique : `@export var model_scene: PackedScene`.
5. Pooling : projectiles, effets, cauris.
6. Pas de `load()` pendant le combat : précharger au chargement du niveau.

---

## 19. Couches de collision et conventions

| Couche | Nom |
|---|---|
| 1 | world |
| 2 | player |
| 3 | enemy |
| 4 | player_hitbox |
| 5 | enemy_hitbox |
| 6 | hazard |
| 7 | pickup |
| 8 | interactable |
| 9 | camera_block (optionnel) |

- Corps : `CapsuleShape3D` (rayon 0,35 m, hauteur 1,7 m pour la joueuse).
- Hitbox/Hurtbox : `Area3D` avec `BoxShape3D` ou `SphereShape3D` simples.
- Noms : scènes/scripts `PascalCase`, variables/fonctions `snake_case`, signaux au passé.
- Commentaires **en français**, noms de code **en anglais**.

---

## 20. Squelettes de code 3D

> Godot 4, GDScript typé. Points de départ, que Claude développera phase par phase.

### 20.1 `scripts/combat/DamageInfo.gd`

```gdscript
extends RefCounted
class_name DamageInfo

var amount: float = 0.0
var knockback: float = 0.0            # en mètres
var source_position: Vector3 = Vector3.ZERO
var is_heavy: bool = false
var is_critical: bool = false
```

### 20.2 `scripts/combat/Hitbox3D.gd`

```gdscript
extends Area3D
class_name Hitbox3D

# Zone qui inflige des dégâts. Activée par l'animation d'attaque.
@export var damage: float = 10.0
@export var knockback: float = 1.2
@export var hitstop: float = 0.05
@export var is_heavy: bool = false

var owner_actor: Node = null
var already_hit: Array[Node] = []

signal hit_landed(target: Node, damage: float)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = false

func activate() -> void:       # appelé par un Call Method Track
	already_hit.clear()
	monitoring = true

func deactivate() -> void:
	monitoring = false

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D and not already_hit.has(area.owner_actor):
		already_hit.append(area.owner_actor)
		var info := DamageInfo.new()
		info.amount = damage
		info.knockback = knockback
		info.source_position = global_position
		info.is_heavy = is_heavy
		var result: int = area.receive_hit(info)
		if result != Hurtbox3D.Result.DODGED:
			hit_landed.emit(area.owner_actor, damage)
			FX.hit_stop(hitstop)
```

### 20.3 `scripts/combat/Hurtbox3D.gd`

```gdscript
extends Area3D
class_name Hurtbox3D

enum Result { HIT, BLOCKED, PERFECT_GUARD, DODGED }

var owner_actor: Node = null
signal damaged(info: DamageInfo, result: int)

func receive_hit(info: DamageInfo) -> int:
	if owner_actor and owner_actor.has_method("on_hit_received"):
		var result: int = owner_actor.on_hit_received(info)
		damaged.emit(info, result)
		return result
	return Result.HIT
```

### 20.4 `scenes/characters/Player3D.gd`

```gdscript
extends CharacterBody3D
class_name Player3D

enum State { IDLE, RUN, ATTACK, DODGE, GUARD, SPECIAL, HURT, DEAD }

signal health_changed(current: float, maximum: float)
signal energy_changed(current: float, maximum: float)
signal died

@export var data: PlayerData
@onready var visual: Node3D = $Visual                  # contient le modèle .glb
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var hitbox: Hitbox3D = $Visual/Hitbox3D
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var combo: ComboController = $ComboController

const GRAVITY: float = 20.0
var state: State = State.IDLE
var health: float
var energy: float = 0.0
var facing_dir: Vector3 = Vector3.FORWARD
var lock_target: Node3D = null
var invincible_time: float = 0.0
var dodge_cooldown: float = 0.0
var guard_pressed_time: float = -1.0
var input_buffer: String = ""
var input_buffer_time: float = 0.0
var lane_mode: bool = true
var lane_depth: float = 3.0                             # profondeur max en LANE

func _ready() -> void:
	add_to_group("players")
	health = data.max_health
	hurtbox.owner_actor = self
	hitbox.owner_actor = self
	hitbox.hit_landed.connect(_on_hit_landed)
	Events.touch_action.connect(_on_touch_action)

func _physics_process(delta: float) -> void:
	invincible_time = maxf(0.0, invincible_time - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	input_buffer_time = maxf(0.0, input_buffer_time - delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	match state:
		State.IDLE, State.RUN: _state_move(delta)
		State.ATTACK:          _state_attack(delta)
		State.GUARD:           _state_guard(delta)
		State.DODGE, State.SPECIAL, State.HURT: pass
		State.DEAD:            return

	move_and_slide()
	if lane_mode:
		global_position.z = clampf(global_position.z, -lane_depth, lane_depth)

# Direction du joystick convertie dans le repère de la caméra.
func _camera_relative_dir() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var j: Vector2 = Events.joystick_vector
	if cam == null or j == Vector2.ZERO:
		return Vector3.ZERO
	var forward: Vector3 = -cam.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var dir: Vector3 = right * j.x + forward * -j.y
	return dir.limit_length(1.0)

func _state_move(delta: float) -> void:
	var dir := _camera_relative_dir()
	var target_vel := dir * data.speed
	velocity.x = move_toward(velocity.x, target_vel.x, data.accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, data.accel * delta)

	if dir.length() > 0.1:
		facing_dir = dir.normalized()
		state = State.RUN
	else:
		state = State.IDLE
		if is_instance_valid(lock_target):
			facing_dir = (lock_target.global_position - global_position).normalized()
	_rotate_visual(delta)
	anim_tree.set("parameters/locomotion/blend_position", dir.length())
	_consume_buffer()

func _rotate_visual(delta: float) -> void:
	var angle := atan2(-facing_dir.x, -facing_dir.z)   # l'avant de Godot est -Z
	visual.rotation.y = lerp_angle(visual.rotation.y, angle, data.turn_speed * delta)

func _on_touch_action(action: String, pressed: bool) -> void:
	if not pressed and action != "guard":
		return
	match action:
		"attack":  _try_attack()
		"dodge":   _try_dodge()
		"guard":   _guard_input(pressed)
		"special": _try_special()

func _try_attack() -> void:
	if state in [State.IDLE, State.RUN, State.ATTACK]:
		_magnet_to_nearest_enemy()
		combo.request_next()
		state = State.ATTACK
	else:
		_buffer("attack")

# Aimant d'attaque : pivote vers l'ennemi proche dans un cône de 60° et 2,5 m.
func _magnet_to_nearest_enemy() -> void:
	var best: Node3D = null
	var best_d := 2.5
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector3 = e.global_position - global_position
		to_e.y = 0.0
		var d := to_e.length()
		if d < best_d and facing_dir.angle_to(to_e.normalized()) < deg_to_rad(30.0):
			best_d = d
			best = e
	if best:
		facing_dir = (best.global_position - global_position).normalized()
		visual.rotation.y = atan2(-facing_dir.x, -facing_dir.z)

func _try_dodge() -> void:
	if dodge_cooldown > 0.0:
		_buffer("dodge")
		return
	if state in [State.IDLE, State.RUN, State.ATTACK]:
		state = State.DODGE
		invincible_time = data.dodge_iframes
		dodge_cooldown = data.dodge_cooldown
		var dir := _camera_relative_dir()
		if dir == Vector3.ZERO:
			dir = -facing_dir
		velocity = dir.normalized() * (data.dodge_distance / data.dodge_duration)
		anim_tree.set("parameters/state/transition_request", "dodge")
		get_tree().create_timer(data.dodge_duration).timeout.connect(_end_state)

func _guard_input(pressed: bool) -> void:
	if pressed:
		guard_pressed_time = Time.get_ticks_msec() / 1000.0
		if state in [State.IDLE, State.RUN]:
			state = State.GUARD
			anim_tree.set("parameters/state/transition_request", "guard")
	elif state == State.GUARD:
		state = State.IDLE

func _try_special() -> void:
	if energy >= data.max_energy and state in [State.IDLE, State.RUN, State.ATTACK]:
		energy = 0.0
		energy_changed.emit(energy, data.max_energy)
		state = State.SPECIAL
		invincible_time = 1.0
		anim_tree.set("parameters/state/transition_request", "special")

# Appelé par la Hurtbox3D : décide du résultat du coup reçu.
func on_hit_received(info: DamageInfo) -> int:
	if invincible_time > 0.0 or state == State.DEAD:
		return Hurtbox3D.Result.DODGED
	var now: float = Time.get_ticks_msec() / 1000.0
	if state == State.GUARD:
		if now - guard_pressed_time <= data.perfect_guard_window:
			add_energy(15.0)
			FX.slow_motion(0.25, 0.3)
			Events.perfect_guard.emit(self)
			return Hurtbox3D.Result.PERFECT_GUARD
		_apply_damage(info.amount * 0.3)
		return Hurtbox3D.Result.BLOCKED
	_apply_damage(info.amount)
	if state != State.DEAD:
		state = State.HURT
		invincible_time = data.hurt_iframes
		var away: Vector3 = (global_position - info.source_position)
		away.y = 0.0
		velocity = away.normalized() * info.knockback * 4.0
		anim_tree.set("parameters/state/transition_request", "hurt")
		get_tree().create_timer(0.25).timeout.connect(_end_state)
	return Hurtbox3D.Result.HIT

func _apply_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	health_changed.emit(health, data.max_health)
	add_energy(3.0)
	if health <= 0.0:
		state = State.DEAD
		anim_tree.set("parameters/state/transition_request", "death")
		died.emit()

func add_energy(v: float) -> void:
	energy = clampf(energy + v, 0.0, data.max_energy)
	energy_changed.emit(energy, data.max_energy)

func _on_hit_landed(_t: Node, _d: float) -> void:
	add_energy(6.0)
	Input.vibrate_handheld(15)

func _end_state() -> void:
	if state != State.DEAD:
		state = State.IDLE

func _buffer(a: String) -> void:
	input_buffer = a
	input_buffer_time = 0.15

func _consume_buffer() -> void:
	if input_buffer != "" and input_buffer_time > 0.0:
		var a := input_buffer
		input_buffer = ""
		_on_touch_action(a, true)

func _state_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)

func _state_guard(_delta: float) -> void:
	var dir := _camera_relative_dir()
	velocity.x = dir.x * data.speed * 0.3
	velocity.z = dir.z * data.speed * 0.3
```

### 20.5 `scripts/combat/ComboController.gd`

```gdscript
extends Node
class_name ComboController

# Gère l'enchaînement des 3 coups. Les Call Method Tracks des animations
# appellent open_window() et end_attack().
@export var step_names: Array[String] = ["attack1", "attack2", "attack3"]

var step: int = 0
var window_open: bool = false
var queued: bool = false
var player: Player3D

func _ready() -> void:
	player = get_parent() as Player3D

func request_next() -> void:
	if player.state != Player3D.State.ATTACK:
		_start_step(0)
	elif window_open:
		queued = true

func _start_step(i: int) -> void:
	step = i
	queued = false
	window_open = false
	player.anim_tree.set("parameters/state/transition_request", step_names[step])

func open_window() -> void:
	window_open = true
	if queued and step < step_names.size() - 1:
		_start_step(step + 1)

func end_attack() -> void:
	if queued and step < step_names.size() - 1:
		_start_step(step + 1)
	else:
		window_open = false
		step = 0
		player.state = Player3D.State.IDLE
```

### 20.6 `scripts/camera/CameraRig.gd` (caméra automatique)

```gdscript
extends Node3D
class_name CameraRig

enum Mode { LANE, ARENA }

@export var mode: Mode = Mode.LANE
@export var lane_offset: Vector3 = Vector3(0.0, 4.5, 7.5)
@export var arena_distance: float = 7.0
@export var arena_height: float = 4.0
@export var follow_speed: float = 6.0

@onready var cam: Camera3D = $Camera3D

var lock_target: Node3D = null
var arena_yaw: float = 0.0
var _shake_strength: float = 0.0
var _shake_time: float = 0.0

func _ready() -> void:
	FX.camera = cam
	cam.fov = 50.0 if mode == Mode.LANE else 55.0

func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	var center := _center_of(players)
	var desired_pos: Vector3
	var look_at_pos: Vector3 = center + Vector3(0, 1.0, 0)

	match mode:
		Mode.LANE:
			# Zoom arrière si les deux joueurs s'éloignent (coop).
			var spread := _spread_of(players)
			desired_pos = center + lane_offset + Vector3(0, 0, clampf(spread * 0.4, 0.0, 3.0))
		Mode.ARENA:
			var p: Node3D = players[0]
			if is_instance_valid(lock_target):
				var d := lock_target.global_position - p.global_position
				d.y = 0.0
				if d.length() > 0.1:
					var target_yaw := atan2(d.x, d.z)
					arena_yaw = lerp_angle(arena_yaw, target_yaw, 1.0 - exp(-4.0 * delta))
				look_at_pos = (p.global_position + lock_target.global_position) * 0.5 + Vector3(0, 1.0, 0)
			var back := Vector3(-sin(arena_yaw), 0, -cos(arena_yaw)) * -1.0
			# la caméra se place derrière la joueuse, dans l'axe joueuse -> cible
			desired_pos = p.global_position - Vector3(sin(arena_yaw), 0, cos(arena_yaw)) * arena_distance
			desired_pos.y = p.global_position.y + arena_height
			look_at_pos = look_at_pos if lock_target else p.global_position + Vector3(0, 1.0, 0)

	cam.global_position = cam.global_position.lerp(desired_pos, 1.0 - exp(-follow_speed * delta))
	cam.look_at(look_at_pos, Vector3.UP)

	if _shake_time > 0.0:
		_shake_time -= delta
		cam.h_offset = randf_range(-1.0, 1.0) * _shake_strength
		cam.v_offset = randf_range(-1.0, 1.0) * _shake_strength
		if _shake_time <= 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0

func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_time = duration

func _center_of(nodes: Array) -> Vector3:
	var c := Vector3.ZERO
	for n in nodes:
		c += (n as Node3D).global_position
	return c / float(nodes.size())

func _spread_of(nodes: Array) -> float:
	if nodes.size() < 2:
		return 0.0
	return (nodes[0] as Node3D).global_position.distance_to((nodes[1] as Node3D).global_position)
```

> Dans `FX.gd`, `shake()` appelle simplement `camera_rig.shake(...)` (3D) au lieu de modifier `offset` en 2D. `hit_stop` et `slow_motion` restent identiques (`Engine.time_scale`).

### 20.7 `scripts/ai/EnemyBase3D.gd`

```gdscript
extends CharacterBody3D
class_name EnemyBase3D

enum State { IDLE, PATROL, CHASE, TELEGRAPH, ATTACK, RECOVER, HURT, DEAD }

@export var data: EnemyData
var state: State = State.IDLE
var health: float
var target: Node3D = null
var strafe_dir: float = 1.0

@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var hitbox: Hitbox3D = $Visual/Hitbox3D
@onready var visual: Node3D = $Visual
@onready var anim_tree: AnimationTree = $AnimationTree

const GRAVITY: float = 20.0

func _ready() -> void:
	add_to_group("enemies")
	health = data.health * GameState.difficulty_health_mult()
	hurtbox.owner_actor = self
	hitbox.owner_actor = self
	hitbox.damage = data.damage * GameState.difficulty_damage_mult()
	strafe_dir = 1.0 if randf() < 0.5 else -1.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	match state:
		State.IDLE, State.PATROL: _scan_for_target()
		State.CHASE:              _chase(delta)
		State.DEAD:               return
		_:                        pass
	move_and_slide()

func _scan_for_target() -> void:
	target = _nearest_player()
	if target and global_position.distance_to(target.global_position) < data.sight_range:
		state = State.CHASE

func _chase(_delta: float) -> void:
	if not is_instance_valid(target):
		state = State.IDLE
		return
	var to_t := target.global_position - global_position
	to_t.y = 0.0
	var dist := to_t.length()
	var dir := to_t.normalized()
	_face(dir)
	if dist > data.attack_range:
		# Sans jeton d'attaque : tourne autour de la cible à ~3 m (strafe).
		if dist < 3.5 and not AttackTokenManager.holders.has(self):
			var side := Vector3(-dir.z, 0, dir.x) * strafe_dir
			velocity.x = side.x * data.speed * 0.6
			velocity.z = side.z * data.speed * 0.6
		else:
			velocity.x = dir.x * data.speed
			velocity.z = dir.z * data.speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if AttackTokenManager.request(self):
			_begin_attack()

func _begin_attack() -> void:
	state = State.TELEGRAPH
	anim_tree.set("parameters/state/transition_request", "telegraph")
	await get_tree().create_timer(data.telegraph_time).timeout
	if state == State.DEAD:
		return
	state = State.ATTACK
	anim_tree.set("parameters/state/transition_request", "attack")
	await get_tree().create_timer(data.attack_duration).timeout   # la hitbox est pilotée par l'anim
	state = State.RECOVER
	AttackTokenManager.release(self)
	await get_tree().create_timer(data.recover_time).timeout
	if state != State.DEAD:
		state = State.CHASE

func on_hit_received(info: DamageInfo) -> int:
	if state == State.DEAD:
		return Hurtbox3D.Result.DODGED
	health -= info.amount
	var away := global_position - info.source_position
	away.y = 0.0
	velocity = away.normalized() * info.knockback * 4.0
	if health <= 0.0:
		_die()
	else:
		state = State.HURT
		anim_tree.set("parameters/state/transition_request", "hurt")
		await get_tree().create_timer(0.2).timeout
		if state == State.HURT:
			state = State.CHASE
	return Hurtbox3D.Result.HIT

func _die() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	anim_tree.set("parameters/state/transition_request", "death")
	AttackTokenManager.release(self)
	Events.enemy_died.emit(self)
	await get_tree().create_timer(1.2).timeout
	queue_free()

func _face(dir: Vector3) -> void:
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 0.2)

func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("players"):
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best
```

### 20.8 `autoload/AttackTokenManager.gd`

```gdscript
extends Node

# Limite à 2 le nombre d'ennemis qui attaquent en même temps.
const MAX_ATTACKERS: int = 2
var holders: Array[Node] = []

func request(enemy: Node) -> bool:
	if holders.has(enemy):
		return true
	if holders.size() < MAX_ATTACKERS:
		holders.append(enemy)
		return true
	return false

func release(enemy: Node) -> void:
	holders.erase(enemy)
```

### 20.9 `scenes/levels/LevelBase3D.gd`

```gdscript
extends Node3D
class_name LevelBase3D

# Moteur de niveau unique : tout est piloté par LevelData.
@export var level_data: LevelData

@onready var spawner: WaveSpawner3D = $WaveSpawner3D
@onready var hazards_root: Node3D = $Hazards
@onready var entities_root: Node3D = $Entities
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var camera_rig: CameraRig = $CameraRig
@onready var player_start: Marker3D = $PlayerStart
@onready var checkpoint_marker: Marker3D = $Checkpoint

var objective: Objective
var time_left: float
var stars_earned: int = 0
var checkpoint_used: bool = false
var players: Array[Player3D] = []

func _ready() -> void:
	if GameState.current_level_data:
		level_data = GameState.current_level_data
	_setup_environment()
	_setup_camera()
	_spawn_players()
	_spawn_hazards()
	_setup_objective()
	spawner.setup(level_data, entities_root, camera_rig)
	time_left = float(level_data.time_limit) * GameState.time_mult()
	Events.objective_completed.connect(_on_win)
	Events.level_failed.connect(_on_fail)

func _setup_environment() -> void:
	# Nuit : ambiance sombre bleue + brouillard. Jour : couleurs de l'arène.
	var e: Environment = env.environment
	if level_data.night:
		e.ambient_light_color = Color("#1F2A5C")
		e.ambient_light_energy = 0.5
		e.fog_enabled = true
		e.fog_light_color = Color("#0d1230")
		e.fog_density = 0.04

func _setup_camera() -> void:
	camera_rig.mode = CameraRig.Mode.LANE if level_data.layout == "lane" else CameraRig.Mode.ARENA

func _setup_objective() -> void:
	match level_data.objective:
		"rescue":  objective = Rescue.new()
		"escort":  objective = Escort.new()
		"survive": objective = Survive.new()
		"boss":    objective = KillBoss.new()
		"exit":    objective = ReachExit.new()
	objective.setup(level_data, self)
	add_child(objective)

func _process(delta: float) -> void:
	if level_data.time_limit > 0:
		time_left -= delta
		if time_left <= 0.0:
			Events.level_failed.emit("time")

func _on_win() -> void:
	stars_earned = _compute_stars()
	SaveManager.record_level_result(level_data.id, stars_earned, GameState.cauris_this_run)
	get_tree().change_scene_to_file("res://scenes/ui/Result.tscn")

func _on_fail(_reason: String) -> void:
	if not checkpoint_used and GameState.difficulty != "hard":
		checkpoint_used = true
		_respawn_at_checkpoint()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/Defeat.tscn")

func _compute_stars() -> int:
	var s := 1
	if GameState.player_health_ratio() >= 0.5 or time_left > level_data.time_limit * 0.4:
		s = 2
	if objective.bonus_achieved():
		s = 3
	return s

func _spawn_players() -> void: pass       # Phase 3 : instancie Player3D (x2 en coop)
func _spawn_hazards() -> void: pass       # Phase 3 : instancie les pièges de level_data.hazards
func _respawn_at_checkpoint() -> void: pass
```

### 20.10 `scripts/objectives/Objective.gd` et `Rescue.gd`

```gdscript
extends Node
class_name Objective

var data: LevelData
var level: LevelBase3D

func setup(d: LevelData, l: LevelBase3D) -> void:
	data = d
	level = l

func bonus_achieved() -> bool:
	return false
```

```gdscript
extends Objective
class_name Rescue

var freed: int = 0
var total: int = 0
var prisoner_hurt: bool = false

func setup(d: LevelData, l: LevelBase3D) -> void:
	super.setup(d, l)
	total = d.prisoners
	Events.prisoner_freed.connect(_on_freed)

func _on_freed(_p: Node) -> void:
	freed += 1
	if freed >= total:
		Events.objective_completed.emit()

func bonus_achieved() -> bool:
	return not prisoner_hurt
```

### 20.11 `scripts/spawning/WaveSpawner3D.gd`

```gdscript
extends Node
class_name WaveSpawner3D

const MAX_ON_SCREEN: int = 5

var level_data: LevelData
var root: Node3D
var rig: CameraRig
var current_wave: int = 0
var alive: int = 0

func setup(d: LevelData, r: Node3D, camera_rig: CameraRig) -> void:
	level_data = d
	root = r
	rig = camera_rig
	Events.enemy_died.connect(_on_enemy_died)
	_next_wave()

func _next_wave() -> void:
	if current_wave >= level_data.enemy_waves.size():
		return
	var wave: Dictionary = level_data.enemy_waves[current_wave]
	current_wave += 1
	# wave = { "enemies": [ {"type": "Soldier", "count": 3} ], "delay": 1.5 }
	for entry in wave.get("enemies", []):
		for i in int(entry["count"]):
			while alive >= MAX_ON_SCREEN:
				await get_tree().create_timer(0.5).timeout
			_spawn(entry["type"])
			await get_tree().create_timer(float(wave.get("delay", 1.0))).timeout

func _spawn(type: String) -> void:
	var scene: PackedScene = EnemyRegistry.get_scene(type)      # table préchargée
	var e: Node3D = scene.instantiate()
	root.add_child(e)
	e.global_position = _spawn_point()
	alive += 1

func _on_enemy_died(_e: Node) -> void:
	alive = maxi(0, alive - 1)
	if alive == 0:
		_next_wave()

func _spawn_point() -> Vector3:
	var center := rig.global_position
	if level_data.layout == "lane":
		var side := -1.0 if randf() < 0.5 else 1.0
		return Vector3(center.x + side * 12.0, 0.0, randf_range(-3.0, 3.0))
	var angle := randf() * TAU
	return Vector3(cos(angle) * 12.0, 0.0, sin(angle) * 12.0)
```

### 20.12 `scripts/ui/VirtualJoystick.gd` et `TouchButton.gd` (identiques à la version 2D, dans un CanvasLayer)

```gdscript
extends Control
class_name VirtualJoystick

@export var radius: float = 90.0
@export var deadzone: float = 0.12
@onready var base: TextureRect = $Base
@onready var knob: TextureRect = $Knob

var touch_index: int = -1
var origin: Vector2

func _ready() -> void:
	base.visible = false
	knob.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1 \
				and event.position.x < get_viewport_rect().size.x * 0.5:
			touch_index = event.index
			origin = event.position
			base.global_position = origin - base.size / 2.0
			knob.global_position = origin - knob.size / 2.0
			base.visible = true
			knob.visible = true
		elif not event.pressed and event.index == touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == touch_index:
		var offset: Vector2 = (event.position - origin).limit_length(radius)
		knob.global_position = origin + offset - knob.size / 2.0
		var v := offset / radius
		Events.joystick_vector = v if v.length() > deadzone else Vector2.ZERO

func _release() -> void:
	touch_index = -1
	Events.joystick_vector = Vector2.ZERO
	base.visible = false
	knob.visible = false
```

```gdscript
extends TextureButton
class_name TouchButton

@export var action_name: String = "attack"

func _ready() -> void:
	button_down.connect(func(): Events.touch_action.emit(action_name, true))
	button_up.connect(func(): Events.touch_action.emit(action_name, false))
```

### 20.13 `autoload/Events.gd` et `autoload/FX.gd`

```gdscript
extends Node
# Events.gd : bus de signaux global
signal touch_action(action: String, pressed: bool)
signal perfect_guard(actor: Node)
signal enemy_died(enemy: Node)
signal prisoner_freed(prisoner: Node)
signal objective_completed
signal level_failed(reason: String)
signal cauris_changed(total: int)
signal boss_phase_changed(phase: int)

var joystick_vector: Vector2 = Vector2.ZERO
```

```gdscript
extends Node
# FX.gd : hit-stop, ralenti, tremblement de caméra 3D
var camera: Camera3D
var camera_rig: CameraRig

func hit_stop(duration: float) -> void:
	if duration <= 0.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func slow_motion(scale: float, duration: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func shake(strength: float, duration: float) -> void:
	if camera_rig:
		camera_rig.shake(strength, duration)
```

### 20.14 Shader cel-shading minimal (`shaders/cel_shading.gdshader`)

```glsl
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;

uniform sampler2D albedo_tex : source_color;
uniform vec4 shadow_color : source_color = vec4(0.12, 0.16, 0.36, 1.0);
uniform float steps = 3.0;

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = floor(ndl * steps) / steps;
	vec3 lit = ALBEDO * LIGHT_COLOR * ATTENUATION * band;
	DIFFUSE_LIGHT += lit;
}
```

### 20.15 Outline par coque inversée (`shaders/outline.gdshader`)

```glsl
shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.1, 0.08, 0.06, 1.0);
uniform float thickness = 0.02;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
```
Appliqué en `next_pass` du matériau du personnage. Désactivé en qualité « Faible ».

### 20.16 `autoload/DailySeed.gd`

```gdscript
extends Node

func today_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day

func generate_daily_level() -> LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = today_seed()
	var lvl := LevelData.new()
	lvl.id = "daily_%d" % today_seed()
	lvl.layout = ["lane", "arena"][rng.randi() % 2]
	lvl.objective = ["rescue", "survive", "exit"][rng.randi() % 3]
	lvl.prisoners = rng.randi_range(2, 4)
	lvl.time_limit = rng.randi_range(90, 140)
	lvl.night = rng.randf() < 0.3
	lvl.hazards = _pick_hazards(rng)
	lvl.modifier = ["double_damage", "fast_enemies", "no_guard", "one_life"][rng.randi() % 4]
	lvl.enemy_waves = _build_waves(rng)
	return lvl

func _pick_hazards(rng: RandomNumberGenerator) -> Array[String]:
	var all: Array[String] = ["pit", "arrows", "fire", "plank"]
	var out: Array[String] = []
	for h in all:
		if rng.randf() < 0.5:
			out.append(h)
	return out

func _build_waves(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var waves: Array[Dictionary] = []
	for i in rng.randi_range(3, 5):
		waves.append({
			"enemies": [
				{"type": "Soldier", "count": rng.randi_range(2, 4)},
				{"type": "Archer", "count": rng.randi_range(0, 2)}
			],
			"delay": 1.2
		})
	return waves
```

---

## 21. Données (Resources)

### 21.1 `LevelData.gd`

```gdscript
extends Resource
class_name LevelData

@export var id: String = ""
@export var chapter: int = 1
@export var number: int = 1
@export var display_name: String = ""
@export_enum("lane", "arena") var layout: String = "lane"
@export_enum("rescue", "escort", "survive", "boss", "exit") var objective: String = "rescue"
@export var length_m: float = 100.0          # longueur du couloir (lane)
@export var arena_radius: float = 14.0       # rayon de l'arène (arena)
@export var prisoners: int = 1
@export var time_limit: int = 150            # secondes, 0 = illimité
@export var enemy_waves: Array[Dictionary] = []
@export var hazards: Array[String] = []
@export var night: bool = false
@export var modifier: String = ""
@export var environment_scene: PackedScene   # décor 3D de ce niveau
@export var music_layer_set: String = "palace"
@export var reward_cauris: int = 50
@export var star_time_silver: int = 100
@export var star_time_gold: int = 70
```

### 21.2 `EnemyData.gd`

```gdscript
extends Resource
class_name EnemyData

@export var id: String = "soldier"
@export var health: float = 30.0
@export var damage: float = 8.0
@export var speed: float = 1.8              # m/s
@export var sight_range: float = 9.0        # m
@export var attack_range: float = 1.4       # m
@export var telegraph_time: float = 0.4
@export var attack_duration: float = 0.5
@export var recover_time: float = 0.8
@export var drops_cauris: int = 3
@export var armor: bool = false
@export var model_scene: PackedScene        # modèle .glb remplaçable
```

### 21.3 `PlayerData.gd`

```gdscript
extends Resource
class_name PlayerData

@export var max_health: float = 100.0
@export var max_energy: float = 100.0
@export var speed: float = 4.5
@export var accel: float = 30.0
@export var turn_speed: float = 14.0
@export var dodge_duration: float = 0.35
@export var dodge_iframes: float = 0.25
@export var dodge_distance: float = 3.6
@export var dodge_cooldown: float = 0.6
@export var perfect_guard_window: float = 0.18
@export var hurt_iframes: float = 0.8
@export var model_scene: PackedScene
```

### 21.4 `WeaponData.gd`

```gdscript
extends Resource
class_name WeaponData

@export var id: String = "sabre"
@export var display_key: String = "WEAPON_SABRE"
@export var damage: float = 10.0
@export var attack_speed: float = 1.0
@export var reach: float = 1.6
@export var is_ranged: bool = false
@export var special_scene: PackedScene
@export var mesh_scene: PackedScene          # arme 3D attachée à la main
@export var price: int = 0
@export var upgrade_prices: Array[int] = [80, 140, 220, 330, 500]
```

### 21.5 Exemple de niveau

| Champ | `level_rescue_04` |
|---|---|
| layout | lane (100 m) |
| objective | rescue |
| prisoners | 2 |
| time_limit | 130 |
| hazards | pit, arrows |
| night | false |
| enemy_waves | vague 1 : 3 soldats ; vague 2 : 2 soldats + 1 éclaireur ; vague 3 : 1 archer + 2 soldats |
| reward_cauris | 70 |

---

## 22. Multijoueur coop WiFi

**But :** 2 joueurs sur le **même réseau local** (box ou hotspot), sans internet.

### 22.1 Principe
- **Hôte autoritaire** : l'hôte simule ennemis, dégâts, objectifs, timer.
- **Client** : envoie ses **inputs** (vecteur joystick + actions), reçoit l'état.
- `ENetMultiplayerPeer` (UDP), port **7777**. Découverte : broadcast UDP port **7778**.
- `MultiplayerSpawner` (joueurs, ennemis, projectiles) et `MultiplayerSynchronizer` (position Vector3, rotation Y, vie, état d'animation).
- Fréquence de synchro : 20 Hz, avec **interpolation** côté client.

### 22.2 `autoload/Network.gd`

```gdscript
extends Node

const GAME_PORT: int = 7777
const DISCOVERY_PORT: int = 7778
const MAX_CLIENTS: int = 1
const GAME_ID: String = "GUERRIERE_ABOMEY_3D_v1"

signal peer_joined(id: int)
signal peer_left(id: int)
signal hosts_found(list: Array)
signal connection_failed

var udp_broadcaster: PacketPeerUDP
var udp_listener: PacketPeerUDP
var broadcast_timer: Timer
var discovered: Dictionary = {}
var host_name: String = "Nawi"

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(GAME_PORT, MAX_CLIENTS) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_start_broadcast()

func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, GAME_PORT) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connection_failed.connect(func(): connection_failed.emit())

func leave() -> void:
	_stop_broadcast()
	_stop_listening()
	multiplayer.multiplayer_peer = null

func _start_broadcast() -> void:
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	udp_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 1.0
	broadcast_timer.timeout.connect(_send_announce)
	add_child(broadcast_timer)
	broadcast_timer.start()

func _send_announce() -> void:
	var msg := JSON.stringify({"game": GAME_ID, "name": host_name, "port": GAME_PORT})
	udp_broadcaster.put_packet(msg.to_utf8_buffer())

func _stop_broadcast() -> void:
	if broadcast_timer:
		broadcast_timer.queue_free()
	if udp_broadcaster:
		udp_broadcaster.close()

func start_listening() -> void:
	udp_listener = PacketPeerUDP.new()
	udp_listener.bind(DISCOVERY_PORT)
	set_process(true)

func _stop_listening() -> void:
	if udp_listener:
		udp_listener.close()

func _process(_delta: float) -> void:
	if udp_listener and udp_listener.get_available_packet_count() > 0:
		var ip := udp_listener.get_packet_ip()
		var data = JSON.parse_string(udp_listener.get_packet().get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY and data.get("game") == GAME_ID:
			discovered[ip] = {"name": data.get("name", "?"), "time": Time.get_ticks_msec()}
			hosts_found.emit(discovered.keys())

func _on_peer_connected(id: int) -> void:
	peer_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	peer_left.emit(id)

func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "inconnue"
```

### 22.3 Règles coop
- **Lobby :** l'hôte voit « En attente… » avec son **adresse IP** en grand ; l'invité voit les parties détectées + **champ IP manuelle** (obligatoire en secours : certains réseaux bloquent le broadcast).
- Actions en RPC fiables ; déplacements en non fiable + interpolation.
- **Réanimation :** si une joueuse tombe, l'autre a 10 s pour la relever (2 s d'interaction), sinon échec.
- **Difficulté coop :** vie ennemis ×1,5, nombre ×1,3, max 6 à l'écran.
- **Caméra :** LANE cadre les deux ; ARENA suit le joueur local (verrouillage indépendant).
- **Déconnexion :** message clair, retour au lobby, possibilité de continuer en solo.
- **Charge :** en 3D, limiter la synchro aux données utiles (pas de transform des props).
- **Permissions Android :** `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`.
- **Test réel :** sur certains hotspots/box, l'isolation des clients bloque la connexion → documenter dans le jeu (« Activez le hotspot sur un téléphone et connectez l'autre »).

> **PHASE 7 — implémenté (voir README § L).** Trois écarts assumés avec le texte
> ci-dessus : 1) Godot 4.3 n'interpole pas les `MultiplayerSynchronizer` ; on
> réplique donc `net_position` et la copie distante glisse vers elle
> (`Player3D._follow_network`) ; 2) les joueuses sont synchronisées à 20 Hz, mais
> l'état du niveau (timer, objectif, vie du gardien) part en non fiable à 5 Hz ;
> 3) les niveaux à gardien restent solo — chez l'invitée le boss n'est qu'un
> reflet (vie répliquée, attaques non simulées).

---

## 23. Sauvegarde

Fichier `user://save.json` + sauvegarde de secours `user://save.bak`.

```gdscript
extends Node

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const VERSION := 1

var data: Dictionary = {
	"version": VERSION,
	"cauris": 0,
	"levels": {},
	"weapons_owned": ["sabre"],
	"weapon_levels": {"sabre": 1},
	"equipped_weapon": "sabre",
	"armor": 0,
	"costumes_owned": ["default"],
	"equipped_costume": "default",
	"skills": {},
	"achievements": [],
	"stats": {"kills": 0, "perfect_guards": 0, "rescued": 0},
	"daily": {"last_date": 0, "streak": 0},
	"survival_record": 0,
	"settings": {"quality": "medium", "scale_3d": 0.8}
}

func _ready() -> void:
	load_game()

func save_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				data.merge(parsed, true)
				_migrate()
				return

func record_level_result(id: String, stars: int, cauris: int) -> void:
	var cur: Dictionary = data["levels"].get(id, {"stars": 0})
	cur["stars"] = maxi(cur["stars"], stars)
	data["levels"][id] = cur
	data["cauris"] += cauris
	save_game()

func _migrate() -> void:
	data["version"] = VERSION
```

Sauvegarde automatique : fin de niveau, achat, changement de réglage. Ne jamais planter sur un fichier corrompu (backup puis valeurs par défaut).

---

## 24. Traductions

- `assets/i18n/fr.po` (défaut), `en.po`, `fon.po`. Tout texte via `tr("CLE")`.
- Police compatible avec les caractères du fon (ɖ, ɔ, ɛ, ŋ…). Vérifier avant de la choisir.
- Dialogues en données, par chapitre. Le fon est relu par un locuteur natif.

---

## 25. Performance 3D entrée de gamme

| Sujet | Règle |
|---|---|
| Triangles | < 120 000 visibles par frame |
| Draw calls | < 100 (atlas, matériaux partagés, `MultiMeshInstance3D` pour herbes/arbres répétés) |
| Personnages | 1 matériau, 1 texture, ≤ 40 os ; animations partagées (humanoïde) |
| Lumières | 1 directionnelle + ≤ 3 ponctuelles, sans ombres |
| Ombres | Blob (decal/sprite) par défaut ; option « Haute » : ombre unique 1024 px pour la joueuse |
| Particules | `CPUParticles3D`, < 30 particules par effet, billboards simples |
| Transparence | À éviter (coûteux) ; privilégier alpha-scissor pour feuillages |
| Culling | `VisibilityNotifier`/`VisibleOnScreenNotifier3D` pour désactiver l'IA hors écran ; distance de fondu |
| LOD | `visibility_range` pour les décors lointains |
| Physique | Capsules/boîtes simples ; pas de physique des corps rigides en combat |
| Mémoire | Libérer le décor précédent ; précharger au chargement du niveau |
| Audio | OGG mono pour les effets, `AudioStreamPlayer3D` limité à 8 voix |
| Qualité | **Faible** (échelle 3D 0,6, pas d'outline, particules réduites) / **Moyenne** (0,8) / **Haute** (1,0, ombre joueuse, outline) |
| Auto-adaptation | Si FPS < 24 pendant 5 s, proposer de passer en qualité inférieure |
| Mesures | FPS en debug, Profiler Godot, test réel sur téléphone 2 Go de RAM |

**Budget par frame (30 FPS = 33 ms) :** logique < 8 ms, rendu < 20 ms, marge 5 ms.

---

## 26. Export Android

**Prérequis (une seule fois) :**
1. Godot 4.x standard.
2. **JDK 17** (OpenJDK).
3. **Android SDK** (Android Studio ou ligne de commande) : Platform-Tools, Build-Tools 34, Platform 34, CMake, NDK (selon la doc Godot de ta version).
4. Godot : *Editor → Editor Settings → Export → Android* : chemins du JDK et du SDK.
5. Installer le **modèle d'export Android**.

**Clés de signature :**
- *Debug* : générée automatiquement (tests).
- *Release* : créer avec `keytool` ; **sauvegarder le keystore et le mot de passe** (sans lui, aucune mise à jour sur Google Play). Jamais dans Git.

**Preset d'export :**
- Architectures : arm64-v8a + armeabi-v7a.
- Format : APK (partage direct), **AAB** (Google Play).
- Orientation : paysage.
- Permissions : `VIBRATE`, `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`.
- Icône 192×192 + adaptative.
- Textures : ETC2/ASTC activé ; mipmaps pour les textures 3D ; compression « VRAM Compressed ».
- Réduire la taille : exclure les sources (.blend, .psd, .kra) via les filtres d'export ; ne pas exporter les fichiers de test.

**Test rapide :** téléphone en USB (débogage USB) → « Déploiement en un clic » de Godot.

---

## 27. PROMPT MAÎTRE

> Colle ceci **une seule fois** au début de la conversation avec Claude (ou Claude Code). Joins aussi ce fichier `DESIGN.md`.

```
Tu es un développeur senior de jeux mobiles Godot 4 (GDScript) et un
directeur technique 3D. Tu m'aides à créer "Guerrière d'Abomey", un jeu
mobile Android 3D low-poly HORS LIGNE d'action-aventure et de combat,
inspiré du royaume du Dahomey et des Agojié.

Tu as accès au document DESIGN.md : c'est la source de vérité sur le
gameplay, les valeurs de combat (en mètres), l'architecture, le code de
départ et le plan. Respecte-le. Si tu dois t'en écarter, dis-le et
explique pourquoi avant.

CONTRAINTES
- Godot 4.x, GDScript typé, rendu Compatibility, export APK Android,
  orientation paysage.
- 3D low-poly stylisée : < 120 000 triangles/frame, < 100 draw calls,
  1 matériau par personnage, pas d'ombres temps réel par défaut,
  30 FPS stable sur téléphone d'entrée de gamme (2 Go de RAM).
  Max 5 ennemis à l'écran. APK < 120 Mo.
- 100 % hors ligne. Sauvegarde JSON locale dans user://.
- Multijoueur COOPÉRATIF à 2 joueurs en WiFi local, sans internet.
- Commandes tactiles multitouch : joystick flottant à gauche ;
  Attaque, Esquive, Garde, Spécial, Interaction à droite ; taille et
  opacité réglables. AUCUN contrôle manuel de caméra : la caméra est
  automatique.
- Langues : français par défaut, anglais et fon via fichiers .po.

GAMEPLAY
- Deux types de niveaux : LANE (couloir 3D, caméra 3/4 qui suit) et
  ARENA (360°, caméra derrière la joueuse avec verrouillage
  automatique sur la cible). Mouvement relatif à la caméra.
- Combat : combo de 3 coups avec aimant d'attaque, esquive avec
  invincibilité courte, garde parfaite avec contre-attaque, barre de
  spécial, cauris. Valeurs précises dans DESIGN.md §8.
- 5 armes (sabre, lance, arc, massue, fusil à pierre), chacune avec son
  spécial.
- Modes : Aventure, Sauvetage, Survie, Chasse aux boss, Défi du jour
  (graine = date du téléphone), Arène, Coop WiFi.
- Un SEUL moteur de niveau réutilisé (LevelBase3D) : les niveaux sont
  décrits par des Resources (.tres). Aucune logique de niveau en dur.
- Difficulté progressive, boss tous les 5 niveaux, étoiles 1 à 3,
  checkpoints, Facile / Normal / Difficile.

DESIGN
- 3D low-poly peint à la main, couleurs chaudes (rouge, or, indigo,
  ocre), motifs des appliqués d'Abomey, shader cel-shading léger +
  outline, UI propre avec grands boutons.
- Game feel : hit-stop, screen shake caméra, ralenti sur le coup final
  de boss, particules, musique dynamique.
- Tout modèle 3D est remplaçable : le code référence des PackedScene via
  @export et des noms d'animations standards, jamais des chemins en dur,
  pour que je remplace les modèles provisoires (capsules colorées) par
  de vrais modèles Blender/Mixamo sans toucher au code.
- Squelette humanoïde partagé (retargeting Godot) pour réutiliser les
  animations sur tous les personnages.

MÉTHODE DE TRAVAIL
1. Travaille UNE phase à la fois, uniquement celle que je demande.
2. Chaque phase doit être jouable et se lancer sans erreur.
3. Avant de coder : rappelle le plan de la phase et liste les fichiers
   que tu vas créer ou modifier.
4. Code commenté en français, noms de variables en anglais, un script =
   une responsabilité, GDScript typé, aucun plugin externe.
5. À la fin de chaque phase : donne (a) les étapes de test sur
   téléphone, (b) les points de performance à vérifier (FPS, triangles,
   draw calls), (c) les bugs connus, (d) la phase suivante.
6. Si une décision est ambiguë, propose 2 options courtes plutôt que de
   bloquer.
7. Ne casse jamais ce qui fonctionne : relis un fichier avant de le
   modifier.
8. Les modèles provisoires doivent être simples mais lisibles (capsules
   et formes colorées avec la palette du DESIGN.md).
9. Pour tout ce qui touche à Mixamo/Blender (que tu ne peux pas faire
   toi-même), donne-moi un pas à pas précis et des scripts d'import.

Confirme que tu as compris en résumant le projet en 5 lignes, puis
attends la commande "PHASE 0".
```

---

## 28. Plan de production : phases avec prompts

> Durée indicative pour une personne seule à temps partiel : **18 à 26 semaines** pour une V1.0 solide. Chaque phase se termine par un **test sur téléphone** et un **commit Git**.

### PHASE 0 — Fondations (2-3 jours)
```
PHASE 0 : crée le projet Godot "guerriere-abomey" selon l'architecture
du DESIGN.md §18. Crée l'arborescence complète, project.godot avec les
réglages du §4 (rendu Compatibility), les autoloads (Events, GameState,
SaveManager, Settings, AudioManager, FX, DailySeed, Network,
AttackTokenManager) en squelettes fonctionnels, les couches de
collision 3D du §19, les 3 bus audio, et une scène Splash qui charge un
MainMenu avec un cube 3D qui tourne. Donne-moi le pas à pas pour
l'export Android (§26) et générer un APK de test.
```
**Validation :** APK qui s'ouvre en paysage et affiche un cube 3D à 30+ FPS.

### PHASE 0.5 — Pipeline 3D (3-5 jours)
```
PHASE 0.5 : prépare le pipeline d'assets 3D selon DESIGN.md §6.
Donne-moi le pas à pas pour importer dans Godot un modèle humanoïde
(.glb) rigué avec Mixamo, avec retargeting humanoïde et une
bibliothèque d'animations partagée. Crée la scène de test "ModelViewer"
(modèle, AnimationTree avec state machine idle/run/attack1-3/dodge/
guard/hurt/death), le shader cel-shading + outline (§20.14-15), et un
script qui affiche FPS, triangles et draw calls à l'écran. Utilise un
modèle gratuit de Mixamo comme test.
```
**Validation :** un personnage animé s'affiche à l'écran de ton téléphone, 30 FPS stables, avec les compteurs.

### PHASE 1 — Joueuse jouable en 3D (1,5 semaine)
```
PHASE 1 : implémente la joueuse selon DESIGN.md §7, §8 et §20 :
joystick flottant multitouch, 4 boutons tactiles, Player3D avec machine
à états, mouvement relatif à la caméra, rotation du modèle, attaque avec
combo de 3 coups (ComboController), aimant d'attaque, esquive avec
invincibilité, garde simple. CameraRig en mode LANE. Modèle provisoire :
capsule colorée avec une épée. Une arène plate avec 1 ennemi mannequin
qui encaisse des dégâts. HUD : barre de vie et d'énergie.
```
**Validation :** bouger, enchaîner 3 coups, esquiver, bloquer, voir la vie baisser/monter.

### PHASE 2 — Combat complet et « game feel » (1 semaine)
```
PHASE 2 : complète le combat : garde parfaite avec contre-attaque,
esquive parfaite, barre de spécial et spécial du sabre, hit-stop, screen
shake de caméra, particules d'impact, flash de dégâts, nombres de
dégâts, buffer d'entrée, critiques, CameraRig en mode ARENA avec
verrouillage automatique et anneau de cible. Valeurs dans
data/balance.tres. Scène de test pour ajuster les valeurs.
```

### PHASE 3 — Moteur de niveau, ennemis, pièges (2 semaines)
```
PHASE 3 : implémente LevelBase3D, LevelData, WaveSpawner3D, les 5 types
d'ennemis (soldat, éclaireur, archer, brute, chef) avec EnemyBase3D,
AttackTokenManager, strafing, les pièges (fosse, flèches, feu, planche),
checkpoints, ramassage de cauris et potions. Crée 5 niveaux de test
(3 LANE + 2 ARENA) en .tres, avec des décors "graybox" (blocs simples).
```
**Validation :** changer un .tres donne un autre niveau.

### PHASE 4 — Objectifs Sauvetage et Escorte (1,5 semaine)
```
PHASE 4 : implémente les objectifs Rescue, Escort, Survive, ReachExit,
KillBoss (squelette), prisonniers avec cage et interaction de 2 s,
villageois à escorter avec IA de suivi, timer, étoiles, écran Résultat,
écran Défaite. Crée les 12 premiers niveaux de Sauvetage selon la table
du §12.2, avec le mode nuit (lumière autour de la joueuse).
```

### PHASE 5 — Menus, carte, boutique, sauvegarde (1,5 semaine)
```
PHASE 5 : implémente MainMenu, choix du mode, carte du royaume avec
nœuds et étoiles, avant-niveau, pause, armurerie avec aperçu 3D rotatif
(SubViewport léger), boutique (armes, armures, améliorations,
compétences), SaveManager complet, réglages (volumes, taille des
boutons, difficulté, langue, qualité graphique et échelle 3D). Boucle
complète : menu → carte → niveau → résultat → boutique → carte.
```

### PHASE 6 — Boss et tous les modes (2,5 semaines)
```
PHASE 6 : implémente BossBase3D avec 3 phases, les 5 boss du §10 (zones
de danger au sol en decals), Aventure en chapitres, Survie, Chasse aux
boss, Défi du jour (DailySeed + modificateurs), Arène d'entraînement,
les 4 armes supplémentaires (lance, arc, massue, fusil) avec leurs
spéciaux et l'auto-visée, alliées jouables.
```
**Fait (18 oct.) :** `BossBase3D` + les 5 fiches de `data/bosses/` (zones de
danger au sol posées AVANT le coup), les 5 fins de chapitre en objectif boss,
la barre de boss du HUD, la Survie (vagues sans fin + bonus entre les vagues +
record), la Chasse aux boss (`boss_chain`) et le Défi du jour (graine de la
date, 4 modificateurs, série), validés par `tests/Phase6Test.tscn`. Reste de la
phase : les 4 armes supplémentaires et les alliées jouables du § 14.

### PHASE 7 — Coop WiFi (2 semaines)
```
PHASE 7 : implémente le coop 2 joueurs en WiFi local selon DESIGN.md
§22 : Network.gd complet, scène Lobby, MultiplayerSpawner/Synchronizer
(Vector3 + rotation Y + état d'animation), hôte autoritaire,
interpolation, réanimation, caméra LANE à deux joueurs, difficulté coop,
déconnexion. Donne-moi un protocole de test avec 2 téléphones et un
hotspot.
```
**Validation :** 2 téléphones sur le même hotspot terminent un niveau ensemble.

### PHASE 8 — Audio, traductions, succès, optimisation (1,5 semaine)
```
PHASE 8 : musique dynamique à 3 couches, effets sonores, audio 3D
positionnel, voix (emplacements), fichiers .po (fr, en, fon), succès,
objectifs journaliers, optimisation entrée de gamme (§25) : MultiMesh,
culling, pooling, qualités Faible/Moyenne/Haute, auto-adaptation si
FPS < 24, réduction de la taille de l'APK.
```

### PHASE 9 — Vrais modèles et polish (variable, 4 à 8 semaines)
```
PHASE 9 : intègre les vrais modèles 3D (.glb) que je te fournis :
héroïne, ennemis, boss, armes, décors. Remplace les modèles provisoires
via les @export sans changer la logique. Configure le retargeting,
les AnimationTree, les textures de costumes, l'UI finale, l'icône,
l'écran titre, les cinématiques en images fixes, et fais une passe de
polish (transitions, particules, ambiances de chaque arène) en
vérifiant les budgets de triangles et de draw calls.
```

### PHASE 10 — Publication
```
PHASE 10 : prépare la version publiable : numéro de version, icône,
captures d'écran, AAB signé pour Google Play et APK pour partage
direct, politique de confidentialité (jeu hors ligne, aucune donnée
collectée), checklist de test finale sur 3 téléphones différents.
```

**Version « minimum fun » (si le temps manque) :** phases 0 à 5 avec 1 héroïne, 3 types d'ennemis, 12 niveaux de Sauvetage, 1 boss. Le reste vient ensuite.

---

## 29. Tests et qualité

**Après chaque phase :**
- [ ] Lance sans erreur dans la console
- [ ] Testé sur **au moins un téléphone d'entrée de gamme**
- [ ] 30 FPS stable en combat avec 5 ennemis
- [ ] Triangles et draw calls dans les budgets (compteur en debug)
- [ ] Pas de fuite mémoire (10 niveaux de suite)
- [ ] Téléphone qui chauffe ? Mesurer après 10 minutes de jeu
- [ ] Mise en veille / retour d'appel : le jeu reprend
- [ ] Sauvegarde conservée après fermeture forcée
- [ ] Aucun bouton tactile « bloqué »
- [ ] Taille de l'APK notée

**Spécifique coop :**
- [ ] Connexion hôte/invité sur hotspot
- [ ] Latence ressentie < 100 ms
- [ ] Déconnexion volontaire et involontaire gérées
- [ ] Mêmes ennemis, mêmes récompenses des deux côtés

**Spécifique 3D :**
- [ ] La caméra ne traverse jamais un mur ni ne cache la joueuse
- [ ] Le verrouillage ne saute pas de cible de façon incohérente
- [ ] Le mouvement relatif à la caméra reste intuitif quand la caméra tourne

**Playtest :** 5 personnes qui ne connaissent pas le jeu, sans explication. Observer où elles bloquent.

---

## 30. Publication et monétisation

| Canal | Détails |
|---|---|
| Partage direct | APK par WhatsApp, Telegram, clé USB |
| Aptoide | Gratuit, populaire en Afrique |
| Google Play | 25 $ une fois, AAB signé |
| Itch.io | Version démo |

**Monétisation hors ligne :**
- Version gratuite : 3 premiers chapitres.
- Déblocage complet : paiement unique (Mobile Money via un intermédiaire, ou code d'activation).
- Costumes inclus dans la version complète.
- Pas de pub en V1 ; plus tard, uniquement des pubs récompensées (« continuer au checkpoint »).

> Un code d'activation purement local peut être contourné. Pour un revenu sûr : Google Play Billing (internet requis seulement à l'achat).

**Taille de l'APK :** si > 100 Mo, proposer deux APK (« Lite » avec qualité réduite et moins d'arènes, « Complet »).

---

## 31. Respect culturel

- Faire valider l'**histoire, les noms, les costumes, les symboles** par des sources béninoises : Musée d'Histoire de Ouidah, Palais royaux d'Abomey (UNESCO), historiens et conservateurs.
- Les noms de personnages ici sont **des exemples fictifs** à valider.
- Ne pas mélanger des symboles de cultures différentes.
- Voix en fon : locuteurs natifs.
- Ton : bravoure, protection, libération ; ne pas glorifier la violence réelle.
- Prévoir une section « Histoire » dans le jeu avec informations réelles et sources.
- Pour les modèles IA ou téléchargés : vérifier les licences et éviter tout contenu qui copie le travail d'un artiste.

---

## 32. Risques et solutions

| Risque | Solution |
|---|---|
| Modélisation + animation trop longues | Mixamo + retargeting humanoïde ; 1 squelette pour tous ; commencer avec 6 animations ; ennemis recolorés |
| Téléphone qui chauffe / ramer | Budgets §25, qualité Faible, échelle 3D, auto-adaptation, limite 30 FPS |
| Caméra qui gêne au tactile | Caméra 100 % automatique, LANE par défaut, verrouillage auto |
| Coop instable en 3D | Hôte autoritaire, IP manuelle, synchro légère, test sur vrai hotspot |
| Art pas professionnel | Modeleur 3D ou outil IA + retopologie ; fiches §15 ; assets remplaçables |
| APK trop lourd | Textures ≤ 1024, atlas, audio OGG, version « Lite » |
| Abandon du projet | Phases courtes, version jouable à chaque étape, minimum fun d'abord |
| Perte du keystore | Sauvegardes multiples hors ligne |
| Animations Mixamo « génériques » | Retoucher les attaques et le spécial |

---

## 33. Glossaire

| Terme | Sens |
|---|---|
| Agojié | Guerrières du royaume du Dahomey (« Amazones ») |
| Gbèkon | Sabre traditionnel (nom utilisé ici) |
| Cauris | Coquillages, ancienne monnaie, monnaie du jeu |
| Appliqués | Tissus décoratifs d'Abomey |
| Low-poly | Modèle 3D à faible nombre de triangles |
| Draw call | Commande de dessin envoyée au GPU (moins = plus rapide) |
| Retargeting | Faire fonctionner les mêmes animations sur des squelettes différents |
| Mixamo | Service gratuit de rig et d'animations pour personnages 3D |
| glTF / .glb | Format d'échange 3D recommandé pour Godot |
| Cel-shading | Ombrage par paliers, rendu « dessin animé » |
| Outline | Contour noir autour d'un modèle |
| LANE / ARENA | Couloir 3D / arène à 360° |
| Verrouillage | Cible automatique de la caméra et de la joueuse |
| Hit-stop | Micro-pause à l'impact |
| Hitbox / Hurtbox | Zone qui inflige / zone qui reçoit des dégâts |
| Télégraphe | Signal visuel avant une attaque |
| Hôte autoritaire | L'hôte décide de tout, l'invité suit |
| APK / AAB | Fichiers d'installation Android (partage / Google Play) |
| LAN | Réseau local (même WiFi) |

---

**Dernier conseil :** commence aujourd'hui par la PHASE 0, puis la PHASE 0.5 pour avoir un personnage 3D animé sur ton téléphone le plus vite possible. C'est le meilleur test de faisabilité de tout le projet.
