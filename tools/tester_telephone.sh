#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Test complet sur téléphone Android branché en USB — Guerrière d'Abomey
#
#   bash tools/tester_telephone.sh              # export + installation + test
#   bash tools/tester_telephone.sh --no-build   # réutilise build/guerriere_debug.apk
#   bash tools/tester_telephone.sh --seconds 600
#
# Ce script fait A, B et C du protocole :
#   A. détecte adb et l'appareil (modèle, Android, RAM, ABI, écran, densité) ;
#   B. exporte l'APK debug, l'installe avec -r (les données sont gardées) et
#      lance le jeu ;
#   C. pousse le drapeau `user://auto_test.flag`, laisse le test automatique
#      tourner (menu, combat 5 ennemis, arène Faible/Moyenne/Haute, Sauvetage,
#      boss), échantillonne gfxinfo/meminfo/batterie, récupère
#      `user://rapport_perf.json` et écrit export/phone/RAPPORT_TELEPHONE.md.
#
# Ce script ne désinstalle rien, n'efface aucune donnée, ne demande aucune
# permission et ne lit que le paquet du jeu. En cas d'échec d'une commande adb,
# il l'écrit dans le rapport et continue.
# ---------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/export/phone"
APK="$ROOT/build/guerriere_debug.apk"
PKG="com.dahomey.guerriereabomey"
ACTIVITE_DEFAUT="$PKG/com.godot.game.GodotApp"
SECONDES=420
BUILD=1

while [ $# -gt 0 ]; do
  case "$1" in
    --no-build) BUILD=0 ;;
    --seconds) SECONDES="${2:-420}"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "option inconnue : $1"; exit 2 ;;
  esac
  shift
done

mkdir -p "$OUT"
ERREURS="$OUT/adb_erreurs.txt"
: > "$ERREURS"

log() { printf '[tester] %s\n' "$*"; }
note_erreur() { printf '%s — %s\n' "$*" >> "$ERREURS"; log "ÉCHEC : $*"; }

# --- A. détection -----------------------------------------------------------

trouver_adb() {
  local c
  for c in \
    "$(command -v adb 2>/dev/null)" \
    "${ANDROID_HOME:-}/platform-tools/adb" \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "$HOME/AppData/Local/Android/Sdk/platform-tools/adb" \
    "/d/android/sdk/platform-tools/adb" \
    "/c/Android/sdk/platform-tools/adb" \
    "/d/Android/sdk/platform-tools/adb"; do
    [ -z "$c" ] && continue
    if [ -x "$c" ] && [ -f "$c" ]; then printf '%s\n' "$c"; return 0; fi
    if [ -f "$c.exe" ]; then printf '%s.exe\n' "$c"; return 0; fi
  done
  return 1
}

ADB="$(trouver_adb || true)"
if [ -z "$ADB" ]; then
  log "adb introuvable. Installe-le :"
  log "  1) Android Studio > SDK Manager > SDK Tools > Android SDK Platform-Tools"
  log "  2) ou : https://developer.android.com/studio/releases/platform-tools"
  log "  3) ajoute le dossier platform-tools au PATH (ou pose le SDK dans D:\\android\\sdk)"
  exit 1
fi
log "adb : $ADB"

# Le téléphone peut mettre quelques secondes à apparaître après le branchement.
trouver_appareil() {
  local essai
  for essai in 1 2 3; do
    ETAT="$("$ADB" devices | awk 'NR>1 && NF {print $2" "$1}' | head -1)"
    if [ -z "$ETAT" ]; then
      if [ "$essai" -eq 1 ]; then
        log "téléphone non détecté : vérifier câble, mode transfert, débogage USB"
      fi
      sleep 4
      continue
    fi
    case "$ETAT" in
      "unauthorized "*)
        log "###########################################################"
        log "#  Accepte la fenêtre « Autoriser le débogage USB »         #"
        log "#  sur le téléphone (coche « Toujours autoriser »).         #"
        log "###########################################################"
        sleep 60
        continue
        ;;
      "device "*)
        SERIAL="${ETAT#device }"
        return 0
        ;;
      *)
        log "état inconnu : $ETAT"
        sleep 5
        ;;
    esac
  done
  return 1
}

if ! trouver_appareil; then
  note_erreur "appareil absent" "aucun appareil en état « device » après 3 essais"
  log "Téléphone non détecté : vérifie le câble, le mode « transfert de fichiers »"
  log "et Options développeur > Débogage USB. Rapport partiel dans $OUT."
  exit 1
fi
ADB="$ADB -s $SERIAL"
log "appareil : $SERIAL"

prop() { $ADB shell getprop "$1" 2>/dev/null | tr -d '\r'; }
MODELE="$(prop ro.product.model)"
ANDROID_V="$(prop ro.build.version.release)"
ABI="$(prop ro.product.cpu.abi)"
RAM_TOTAL="$($ADB shell cat /proc/meminfo 2>/dev/null | awk '/MemTotal/ {print int($2/1024)}' | tr -d '\r')"
RAM_TOTAL="${RAM_TOTAL:-0}"
ECRAN="$($ADB shell wm size 2>/dev/null | tr -d '\r')"
DENSITE="$($ADB shell wm density 2>/dev/null | tr -d '\r')"
{
  echo "modele=$MODELE"
  echo "android=$ANDROID_V"
  echo "abi=$ABI"
  echo "ram_mo=$RAM_TOTAL"
  echo "ecran=$ECRAN"
  echo "densite=$DENSITE"
  echo "serial=$SERIAL"
} > "$OUT/appareil.txt"
log "modèle $MODELE · Android $ANDROID_V · $ABI · ${RAM_TOTAL} Mo · $ECRAN"

# --- B. export et installation ---------------------------------------------

if [ "$BUILD" -eq 1 ]; then
  GODOT="$(command -v godot 2>/dev/null || true)"
  if [ -z "$GODOT" ]; then
    GODOT="$(ls -1 "$HOME"/Downloads/Godot_v4*/Godot_v4*-stable_win64_console.exe \
                  "$HOME"/Downloads/Godot_v4*/Godot_v4*.exe 2>/dev/null | head -1)"
  fi
  if [ -z "$GODOT" ]; then
    note_erreur "export" "Godot introuvable (ni dans le PATH ni dans ~/Downloads/Godot_v4*)"
    exit 1
  fi
  # Sans JAVA_HOME, apksigner échoue et l'APK sort NON SIGNÉ (donc ininstallable).
  if [ -z "${JAVA_HOME:-}" ] && [ -d "/c/Program Files/Android/Android Studio/jbr" ]; then
    export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
  fi
  log "export de l'APK debug…"
  mkdir -p "$(dirname "$APK")"
  # On supprime l'ancien APK : c'est le fichier produit qui prouve le succès,
  # pas le texte du journal (Godot n'écrit pas toujours « APK »).
  rm -f "$APK"
  "$GODOT" --headless --path "$ROOT" --export-debug "Android" "$APK" 2>&1 \
    | tee "$OUT/export.log" | tail -3
  if [ ! -f "$APK" ]; then
    note_erreur "export" "aucun APK produit — voir export/phone/export.log"
    exit 1
  fi
  log "APK : $(du -h "$APK" | cut -f1)"
fi

log "installation (-r, les données sont conservées)…"
$ADB install -r "$APK" 2>&1 | tee "$OUT/install.log" | tail -3
grep -qE "Success" "$OUT/install.log" || note_erreur "installation" "$(tail -2 "$OUT/install.log" | tr '\n' ' ')"

COMPOSANT="$($ADB shell cmd package resolve-activity --brief "$PKG" 2>/dev/null | tail -1 | tr -d '\r')"
case "$COMPOSANT" in
  */*) ;;
  *) COMPOSANT="$ACTIVITE_DEFAUT"; note_erreur "activité" "resolve-activity vide, repli sur $ACTIVITE_DEFAUT" ;;
esac
log "activité : $COMPOSANT"

# --- C. test automatique ---------------------------------------------------

$ADB logcat -c 2>/dev/null
$ADB shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1
# Un rapport d'une exécution précédente ferait croire le test terminé :
# on l'efface AVANT de poser le drapeau.
$ADB shell "run-as $PKG rm -f files/rapport_perf.json files/auto_test.flag" >/dev/null 2>&1

# Le drapeau est lu au démarrage par scripts/debug/AutoTest.gd (build debug
# uniquement : la balise d'export « autotest » n'existe pas en release).
if $ADB shell "run-as $PKG mkdir -p files" >/dev/null 2>&1 \
   && $ADB shell "run-as $PKG sh -c 'echo 1 > files/auto_test.flag'" >/dev/null 2>&1; then
  log "drapeau auto_test posé"
else
  note_erreur "drapeau" "run-as a refusé (APK non debuggable ?)"
fi

# Force l'arrêt avant de relancer : le drapeau n'est lu qu'au DÉMARRAGE du
# processus. Sans ça, une instance déjà ouverte reste au premier plan et le
# test ne démarre jamais.
$ADB shell am force-stop "$PKG" 2>/dev/null
sleep 2
$ADB shell am start -n "$COMPOSANT" 2>&1 | tail -2
sleep 6
$ADB exec-out screencap -p > "$OUT/boot.png" 2>/dev/null || note_erreur "capture" "boot.png"

log "test en cours (jusqu'à ${SECONDES} s)…"
: > "$OUT/echantillons.txt"
restant="$SECONDES"
while [ "$restant" -gt 0 ]; do
  sleep 15
  restant=$((restant - 15))
  {
    echo "=== t-$restant ==="
    $ADB shell dumpsys meminfo "$PKG" 2>/dev/null | grep -E "TOTAL PSS|TOTAL RSS" | head -2
    $ADB shell dumpsys battery 2>/dev/null | grep -E "temperature|level|status" | tr -d '\r'
  } >> "$OUT/echantillons.txt"
  if $ADB shell run-as "$PKG" ls files/rapport_perf.json >/dev/null 2>&1; then
    log "rapport du jeu détecté (fin du test)"
    break
  fi
done

$ADB shell dumpsys gfxinfo "$PKG" > "$OUT/gfxinfo.txt" 2>/dev/null || note_erreur "gfxinfo" "dumpsys"
$ADB shell dumpsys meminfo "$PKG" > "$OUT/meminfo.txt" 2>/dev/null || note_erreur "meminfo" "dumpsys"
$ADB shell dumpsys battery > "$OUT/battery.txt" 2>/dev/null || note_erreur "battery" "dumpsys"
$ADB logcat -d 2>/dev/null | grep -iE "godot|FATAL|ANR|AndroidRuntime" | tail -400 > "$OUT/logcat.txt"
$ADB exec-out screencap -p > "$OUT/fin.png" 2>/dev/null || true

if $ADB exec-out "run-as $PKG cat files/rapport_perf.json" > "$OUT/rapport_perf.json" 2>/dev/null \
   && [ -s "$OUT/rapport_perf.json" ]; then
  log "rapport_perf.json récupéré"
else
  note_erreur "rapport" "user://rapport_perf.json absent (AutoTest non déclenché ?)"
  rm -f "$OUT/rapport_perf.json"
fi

# --- D. rapport -------------------------------------------------------------

# Python sert uniquement à rédiger le rapport : on vérifie qu'il s'exécute
# vraiment (sous Windows, `python3` peut être le raccourci Microsoft Store).
PYTHON=""
for candidat in python python3 py; do
  if command -v "$candidat" >/dev/null 2>&1 && "$candidat" -c "import sys" >/dev/null 2>&1; then
    PYTHON="$candidat"
    break
  fi
done
if [ -z "$PYTHON" ]; then
  note_erreur "rapport" "Python introuvable : impossible d'écrire RAPPORT_TELEPHONE.md"
  exit 1
fi

"$PYTHON" "$ROOT/tools/rapport_telephone.py" "$OUT"
log "terminé. Verdict et détails dans export/phone/RAPPORT_TELEPHONE.md"
