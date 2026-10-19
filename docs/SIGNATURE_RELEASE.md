# Signature de release et AAB Google Play

Créée le 19 octobre 2026. Ce document décrit la clé **sans jamais contenir son
mot de passe** : le secret vit dans `export/android/.pass`, dossier ignoré par
git (`.gitignore` : `export/android/`).

## 1. La clé

| Élément | Valeur |
|---|---|
| Fichier | `export/android/guerriere-release.keystore` |
| Alias | `guerriere` |
| Algorithme | RSA 2048, SHA-384, validité 10 000 jours |
| DN | `CN=Johnson Studio, OU=Mobile, O=Johnson Studio, L=Cotonou, ST=Littoral, C=BJ` |
| Mot de passe | `export/android/.pass` (24 caractères générés, non versionné) |
| Sauvegarde | `~/Documents/Guerriere-Abomey-BACKUP/guerriere-release-2026-10-19.keystore` + `.pass` |

**Sauvegarde obligatoire.** Perdre ce fichier ou son mot de passe interdit toute
mise à jour de l'application sur Google Play. Copier les deux fichiers sur un
support chiffré hors du PC (clé USB, coffre-fort de mots de passe).

## 2. Exporter l'AAB signé

```bash
bash tools/build_aab.sh
```

Le script :

1. lit le mot de passe dans `export/android/.pass` ;
2. l'injecte dans `export_presets.cfg` (preset `Android AAB`), fichier qui, lui,
   est versionné **sans** mot de passe ;
3. lance `godot --headless --export-release "Android AAB"` ;
4. restaure `export_presets.cfg` quoi qu'il arrive (`trap`) ;
5. vérifie le certificat de l'AAB avec `keytool -printcert -jarfile`.

Sortie : `export/guerriere-abomey-<version>.aab` (ignoré par git).

Prérequis, une seule fois :

- **JDK 17** (pas 21 ni 25) : le wrapper Gradle 8.2 livré par Godot 4.3 refuse
  les classes Java 21+ (`Unsupported class file major version 69`). Sur ce PC :
  `C:/Users/Eudes Johnson/Downloads/jdk-17.0.20.1+1` ; il est déclaré dans
  *Éditeur → Paramètres → Export → Android → Java SDK path*, **et** le script
  `tools/build_aab.sh` le cherche pour `keytool` ;
- Android SDK configuré dans Godot, avec **build-tools 34.0.0** (ou une
  révision installée reportée dans `versions.buildTools` de
  `android/build/config.gradle` — le PC de développement utilise `36.0.0`) ;
- modèle de build Android installé : `godot --headless --path . --install-android-build-template`
  (crée `android/`, ignoré par git). Si la commande reste bloquée, extraire
  `android_source.zip` des modèles d'export dans `android/build/`, créer
  `android/.build_version` contenant `4.3.stable` et un `.gdignore` dans
  `android/build/` ;
- Gradle télécharge ses dépendances au premier export (connexion nécessaire).

## 3. Ce qu'il faut faire dans la Play Console

1. Créer l'application, puis **Play App Signing** : Google garde la clé de
   signature finale, l'AAB ci-dessus sert de *upload key*. C'est le cas
   recommandé : une clé d'upload perdue se remplace, pas la clé d'app.
2. Envoyer l'AAB en piste **Test interne** d'abord.
3. Coller l'URL publique de `docs/POLITIQUE_CONFIDENTIALITE.md` (voir
   `docs/FICHE_STORE.md` § 7) et remplir « Sécurité des données » : aucune
   donnée collectée.
4. Incrémenter `version/code` dans **les deux** presets (`Android` et
   `Android AAB`) à chaque envoi.

## 4. Vérifier un AAB

```bash
keytool -printcert -jarfile export/abomey-warriors-0.8.0.aab
```

Le certificat doit afficher `CN=Johnson Studio` et l'empreinte SHA-256 de la
clé release. `apksigner verify` ne s'applique qu'aux APK ; pour un AAB, on
utilise `keytool` ou `jarsigner -verify`.
