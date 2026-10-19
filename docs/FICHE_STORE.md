# Fiche Google Play — Abomey Warriors

Éditeur : **Johnson Studio** · Bénin · eudesjohn650@mail.com
Politique de confidentialité : `docs/POLITIQUE_CONFIDENTIALITE.md` (à héberger,
voir § 7).

---

## 1. Français

**Nom de l'application** (30 caractères max) : `Abomey Warriors` (15)

**Description courte** (80 caractères max) :

> Sabre au poing, libérez le royaume du Dahomey. Action 3D low-poly, hors ligne.

**Description complète** (4 000 caractères max) :

> **Le royaume est tombé. Une lame se lève.**
>
> Abomey Warriors est un jeu d'action-aventure 3D en low-poly, inspiré du
> royaume du Dahomey. Vous incarnez une jeune guerrière qui traverse cinq
> chapitres pour libérer les villages, briser les cages et affronter les
> gardiens du royaume.
>
> **Un combat au sabre lisible**
> Trois coups enchaînés, une garde qui contre-attaque si vous la tenez au bon
> moment, une esquive qui ralentit le temps, des coups critiques et un tourbillon
> qui balaie la foule. Chaque ennemi annonce son attaque : on gagne en lisant,
> pas en martelant l'écran.
>
> **Cinq chapitres, vingt-cinq niveaux**
> Couloirs, arènes, pièges, checkpoints et cauris à ramasser. Chaque chapitre se
> referme sur son gardien, avec ses trois phases et ses zones de danger.
>
> **Des modes qui changent la donne**
> Campagne, Sauvetage (dix-sept tableaux), Escorte, Survie sans fin, Chasse aux
> boss et Défi du jour avec sa graine quotidienne.
>
> **À deux sur le même Wi-Fi**
> Le mode coopératif relie deux téléphones sur le réseau local, sans serveur ni
> compte : l'hôte affiche son adresse, l'invitée la saisit ou la voit apparaître.
> Difficulté ajustée, réanimation à deux.
>
> **Pensé pour le téléphone**
> Commandes tactiles (joystick et boutons redimensionnables), trois niveaux de
> qualité, échelle 3D réglable, interface en français, anglais et fon, et un jeu
> qui fonctionne **entièrement hors ligne**.
>
> Aucune publicité. Aucun achat intégré. Aucune donnée personnelle collectée.

**Catégorie** : Jeux → Action
**Étiquettes** : action, aventure, low-poly, Afrique, hack and slash, hors ligne
**Classification du contenu** : violence fantastique non réaliste (combat au
sabre, pas de sang) → questionnaire Google Play : « Violence – fantastique »,
aucun autre contenu sensible. Public visé : 7 ans et plus.
**Langues** : français (complet), anglais (complet), fon (interface).
**Achats intégrés** : non. **Publicités** : non. **Compte requis** : non.

---

## 2. English

**App name** : `Abomey Warriors` (15 characters)

**Short description** (80 characters max) :

> Sword in hand, free the kingdom of Dahomey. Offline low-poly 3D action.

**Full description** :

> **The kingdom has fallen. One blade rises.**
>
> Abomey Warriors is a low-poly 3D action-adventure inspired by the kingdom
> of Dahomey. Play a young warrior across five chapters: free villages, break
> open cages and face the kingdom's guardians.
>
> **Readable sword combat** — three-hit combos, a guard that counters when timed
> right, a dodge that slows time, critical hits and a spinning sweep. Every
> enemy telegraphs its attack: you win by reading, not by mashing.
>
> **Five chapters, twenty-five levels** — corridors, arenas, traps,
> checkpoints and cowrie shells. Each chapter ends with its guardian, with three
> phases and ground danger zones.
>
> **Modes that change the fight** — Campaign, Rescue (seventeen boards), Escort,
> endless Survival, Boss Hunt and a Daily Challenge seeded by the date.
>
> **Two players on the same Wi-Fi** — co-op links two phones on the local
> network with no server and no account; the host shows its address, the guest
> types it or picks it from the list. Tuned difficulty and two-player revive.
>
> **Built for phones** — touch controls (resizable joystick and buttons), three
> quality levels, adjustable 3D scale, French, English and Fon interface, and it
> runs **fully offline**.
>
> No ads. No in-app purchases. No personal data collected.

**Category** : Games → Action
**Content rating** : fantasy violence (sword combat, no blood) → “Violence –
Fantasy”, nothing else. Target age: 7+.
**Languages** : French, English, Fon (UI).
**In-app purchases** : no. **Ads** : no. **Account required** : no.

---

## 3. Coordonnées développeur (obligatoire sur la fiche)

| Champ Play Console | Valeur |
|---|---|
| Nom du développeur | Johnson Studio |
| Adresse e-mail | eudesjohn650@mail.com |
| Pays | Bénin |
| Site web | *(facultatif — laisser vide tant qu'il n'existe pas)* |
| Politique de confidentialité (URL) | à héberger, voir § 7 |

Aucune autre donnée personnelle ne doit figurer sur la fiche.

## 4. Visuels à fournir

| Élément | Format | État |
|---|---|---|
| Icône | PNG 512 × 512, sans transparence | `icon.svg` à exporter |
| Bannière | PNG 1024 × 500 | à produire |
| Captures téléphone | 2 minimum (8 max), 16:9 paysage, 1920 × 1080 | `export/shots/` (à refaire en release) |
| Vidéo | facultative | — |

Les captures doivent montrer l'interface réelle : menu, carte du royaume,
combat, boss, sauvegarde, coop. Pas de texte trompeur, pas de capture d'un
appareil qui n'existe pas.

## 5. Questionnaire « Sécurité des données »

Réponses exactes, cohérentes avec la politique :

- Collecte de données ? **Non**.
- Données partagées avec des tiers ? **Non**.
- Données chiffrées en transit ? **Sans objet** (aucune donnée transmise).
- Suppression possible ? **Oui** : désinstallation ou effacement des données.
- Publicité ? **Non**. Analytics ? **Non**.

## 6. Version à publier

`version/name` et `version/code` sont dans `export_presets.cfg`
(actuellement `0.8.0` / `8`). À incrémenter à chaque envoi : Google Play refuse
un code déjà utilisé. L'**AAB signé** est produit par `bash tools/build_aab.sh`
(clé et procédure : `docs/SIGNATURE_RELEASE.md`).

**Visuels** :

| Élément Play | Fichier | Format |
|---|---|---|
| Icône | `assets/ui/store/icon_512.png` | 512×512 PNG 32 bits |
| Bannière | `export/store/feature_graphic_1024x500.png` | 1024×500 PNG |
| Captures (4) | `export/shots/play/0{1..4}_*.png` | 1280×720 PNG |

Régénération : `godot --headless --path . --script res://tools/make_store_assets.gd`
(icône + calque adaptatif) puis `python tools/make_store_assets.py` (fond
adaptatif + bannière) et `godot --path . --resolution 1280x720 res://tests/StoreShots.tscn`
(captures). L'icône du lanceur, le calque avant et le fond adaptatif sont
référencés par **les deux presets** d'export.

## 7. Héberger la politique de confidentialité

Google Play exige une **URL publique**. Le fichier
`docs/POLITIQUE_CONFIDENTIALITE.md` est publié tel quel :

- **En ligne depuis le 19 octobre 2026** sur GitHub Pages (dépôt public,
  branche `main`, dossier `/docs`, vérifié en HTTP 200) :
  <https://eudesjohn.github.io/jeux/POLITIQUE_CONFIDENTIALITE.html> ;
  `docs/index.md` sert de page d'accueil ;
- toute modification de la politique publiée sur `main` met la page à jour en
  une minute environ.

L'URL exacte obtenue doit être recopiée dans la Play Console **et** dans
`RAPPORT_FINAL.md`.
