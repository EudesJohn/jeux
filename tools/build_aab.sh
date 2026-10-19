#!/usr/bin/env bash
# Exporte l'AAB Google Play signé avec la clé de release.
#
#   bash tools/build_aab.sh [sortie.aab]
#
# Le mot de passe de la clé n'est jamais versionné : il est lu dans
# export/android/.pass, injecté dans export_presets.cfg le temps de l'export,
# puis le fichier est restauré (même en cas d'erreur). Voir
# docs/SIGNATURE_RELEASE.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CFG="export_presets.cfg"
PASS_FILE="export/android/.pass"
KEYSTORE="export/android/guerriere-release.keystore"
OUT="${1:-export/guerriere-abomey-0.8.0.aab}"

[ -f "$PASS_FILE" ] || { echo "Mot de passe absent : $PASS_FILE (voir docs/SIGNATURE_RELEASE.md)" >&2; exit 1; }
[ -f "$KEYSTORE" ] || { echo "Clé absente : $KEYSTORE (voir docs/SIGNATURE_RELEASE.md)" >&2; exit 1; }
[ -f "$CFG" ] || { echo "Preset absent : $CFG" >&2; exit 1; }

# Gradle 8.2 (wrapper livré par Godot 4.3) refuse Java 21+ : il faut un JDK 17.
find_jdk17() {
  local cands=()
  [ -n "${JAVA_HOME:-}" ] && cands+=("$JAVA_HOME")
  for d in "$HOME"/Downloads/jdk-17* "$HOME"/.jdks/*17* \
           "C:/Program Files/Eclipse Adoptium"/*17* "C:/Program Files/Java"/jdk-17* \
           "C:/Program Files/Android/Android Studio/jbr"; do
    [ -d "$d" ] && cands+=("$d")
  done
  local c j
  for c in "${cands[@]}"; do
    j="$c/bin/java.exe"
    [ -x "$j" ] || j="$c/bin/java"
    if [ -x "$j" ] && "$j" -version 2>&1 | head -1 | grep -q 'version "17'; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

JDK17="$(find_jdk17 || true)"
[ -n "$JDK17" ] || {
  echo "JDK 17 introuvable (Gradle 8.2 refuse Java 21+). Installe Temurin 17" >&2
  echo "ou pose JAVA_HOME dessus. Voir docs/SIGNATURE_RELEASE.md." >&2
  exit 1
}
export JAVA_HOME="$JDK17"

GODOT="${GODOT:-$(command -v godot 2>/dev/null || true)}"
if [ -z "$GODOT" ]; then
  GODOT="$(ls -1 "$HOME"/Downloads/Godot_v4*/Godot_v4*-stable_win64_console.exe 2>/dev/null | head -1 || true)"
fi
[ -n "$GODOT" ] || { echo "Godot introuvable (PATH ou ~/Downloads/Godot_v4*)" >&2; exit 1; }

BACKUP="$(mktemp)"
cp "$CFG" "$BACKUP"

# Windows peut verrouiller brièvement le fichier après la sortie de Godot :
# on réessaie, puis on vérifie qu'aucun mot de passe ne subsiste.
restore() {
  local i
  for i in 1 2 3 4 5; do
    cp -f "$BACKUP" "$CFG" 2>/dev/null && break
    sleep 1
  done
  if grep -q 'keystore/release_password="..*"' "$CFG"; then
    echo "ERREUR : le mot de passe est resté dans $CFG — nettoyer avant tout commit" >&2
  fi
  rm -f "$BACKUP"
}
trap restore EXIT INT TERM

# Injection du mot de passe dans le seul preset « Android AAB ».
python - "$CFG" "$PASS_FILE" <<'PY'
import sys

cfg, pass_file = sys.argv[1], sys.argv[2]
with open(pass_file, encoding="utf-8") as fh:
    password = fh.read().strip()
if not password:
    sys.exit("mot de passe vide")

with open(cfg, encoding="utf-8") as fh:
    lines = fh.read().splitlines()

out = []
in_target = False
found = False
for line in lines:
    if line.startswith("[preset.") and line.endswith(".options]"):
        in_target = line.startswith("[preset.1.")
    if in_target and line.startswith("keystore/release_password="):
        out.append('keystore/release_password="%s"' % password)
        found = True
        continue
    out.append(line)

if not found:
    sys.exit("keystore/release_password introuvable dans le preset Android AAB")

with open(cfg, "w", encoding="utf-8", newline="\n") as fh:
    fh.write("\n".join(out) + "\n")
PY

echo "Export de l'AAB vers $OUT"
"$GODOT" --headless --path . --export-release "Android AAB" "$OUT"

restore
trap - EXIT INT TERM

if grep -q 'keystore/release_password="..*"' "$CFG"; then
  echo "Le preset contient encore le mot de passe : arrêt." >&2
  exit 2
fi

[ -f "$OUT" ] || { echo "AAB non produit" >&2; exit 1; }

echo "Certificat de l'AAB :"
"$JAVA_HOME/bin/keytool" -printcert -jarfile "$OUT" | grep -E "Owner|SHA256|Valid" || true

echo "Terminé : $OUT"
