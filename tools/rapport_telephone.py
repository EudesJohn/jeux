"""Écrit export/phone/RAPPORT_TELEPHONE.md à partir des mesures du téléphone.

Appelé par tools/tester_telephone.sh, mais utilisable seul :

    python tools/rapport_telephone.py export/phone

Entrées lues (si présentes) :
    appareil.txt          modèle, Android, ABI, RAM, écran, densité
    rapport_perf.json     écrit par scripts/debug/AutoTest.gd pendant le test
    adb_erreurs.txt       commandes adb qui ont échoué
    gfxinfo.txt           dumpsys gfxinfo (images ignorées, janky frames)
    battery.txt           dumpsys battery (température)

Sortie : RAPPORT_TELEPHONE.md, en français, avec un verdict
VERT (30+ images/s stables), ORANGE (chutes) ou ROUGE (sous 30).
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

SEUIL_FPS = 30.0          # en dessous : injouable sur ce téléphone
SEUIL_1PCT = 25.0         # « pire 1 % » : ce que le joueur ressent
SEUIL_MIN = 20.0


def sans_accents(texte: str) -> str:
    """« modèle » -> « modele » : les clés du fichier restent comparables."""
    table = str.maketrans("àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ", "aaaeeeeiioouuucAAAEEEEIIOOUUUC")
    return texte.translate(table)


def lire_appareil(dossier: Path) -> dict[str, str]:
    champs: dict[str, str] = {}
    fichier = dossier / "appareil.txt"
    if not fichier.exists():
        return champs
    for ligne in fichier.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" in ligne:
            cle, valeur = ligne.split("=", 1)
            champs[sans_accents(cle.strip()).lower()] = valeur.strip()
    return champs


def lire_mesures(dossier: Path) -> list[dict]:
    fichier = dossier / "rapport_perf.json"
    if not fichier.exists():
        return []
    try:
        contenu = json.loads(fichier.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    return contenu.get("etapes", [])


def janky(dossier: Path) -> str:
    """Pourcentage d'images « janky » lu dans dumpsys gfxinfo (Android 13)."""
    fichier = dossier / "gfxinfo.txt"
    if not fichier.exists():
        return ""
    texte = fichier.read_text(encoding="utf-8", errors="replace")
    trouve = re.search(r"Janky frames:\s*(\d+)\s*\(([\d.]+)%\)", texte)
    if not trouve:
        return ""
    return f"{trouve.group(2)} % d'images saccadées ({trouve.group(1)} images)"


def temperature(dossier: Path) -> str:
    fichier = dossier / "battery.txt"
    if not fichier.exists():
        return ""
    trouve = re.search(r"temperature:\s*(\d+)", fichier.read_text(encoding="utf-8", errors="replace"))
    if not trouve:
        return ""
    return f"{int(trouve.group(1)) / 10:.1f} °C"


def incidents(dossier: Path) -> dict[str, int]:
    """Compte les crashs/ANR et les erreurs de script lus dans logcat.txt."""
    fichier = dossier / "logcat.txt"
    if not fichier.exists():
        return {"crashs": 0, "erreurs_script": 0, "present": 0}
    texte = fichier.read_text(encoding="utf-8", errors="replace")
    crashs = len(re.findall(r"FATAL EXCEPTION|ANR in |Force finishing", texte))
    erreurs = len(re.findall(r"USER SCRIPT ERROR", texte))
    return {"crashs": crashs, "erreurs_script": erreurs, "present": 1}


def verdict(mesures: list[dict]) -> tuple[str, str]:
    if not mesures:
        return "INCONNU", "aucune mesure : le test automatique n'a pas tourné"
    moyennes = [m["fps_moyen"] for m in mesures]
    if min(moyennes) < SEUIL_FPS:
        return "ROUGE", f"une étape tombe à {min(moyennes)} images/s (seuil {SEUIL_FPS:.0f})"
    pires = [m.get("fps_1pct_bas", 0) for m in mesures]
    minima = [m.get("fps_min", 99) for m in mesures]
    if min(pires) < SEUIL_1PCT or min(minima) < SEUIL_MIN:
        return "ORANGE", (
            f"moyennes correctes, mais des chutes à {min(pires):.1f} images/s "
            f"(pire 1 %) et {min(minima):.1f} en pointe"
        )
    return "VERT", "30 images/s et plus partout, sans chute notable"


def conseils(mesures: list[dict]) -> list[str]:
    """Recommandations concrètes, qualité par qualité, à partir des chiffres."""
    lignes: list[str] = []
    par_nom = {m["nom"]: m for m in mesures}

    def ligne_qualite(nom: str, etiquette: str) -> None:
        m = par_nom.get(nom)
        if not m:
            return
        if m["fps_moyen"] < SEUIL_FPS:
            lignes.append(
                f"- **{etiquette}** : {m['fps_moyen']} images/s → passer en qualité "
                "Faible, échelle 3D 0,6 et réduire la foule (6 ennemis à l'écran)."
            )
        elif m.get("fps_1pct_bas", 99) < SEUIL_1PCT:
            lignes.append(
                f"- **{etiquette}** : {m['fps_moyen']} images/s en moyenne mais "
                f"{m['fps_1pct_bas']} sur les pires images → désactiver les ombres "
                "réelles (Réglages → Qualité) et l'outline, garder l'échelle 3D 0,7."
            )
        elif m.get("draw_calls", 0) > 200:
            tris = f"{m.get('triangles', 0):,}".replace(",", " ")
            lignes.append(
                f"- **{etiquette}** : {m['fps_moyen']} images/s, jouable, mais "
                f"{m['draw_calls']} appels de dessin et {tris} primitives : "
                "c'est la qualité la plus chère, à réserver aux téléphones récents."
            )
        else:
            lignes.append(f"- **{etiquette}** : {m['fps_moyen']} images/s, fluide — ne rien changer.")

    for nom, etiquette in (("arene_faible", "Qualité Faible"),
                           ("arene_moyenne", "Qualité Moyenne"),
                           ("arene_haute", "Qualité Haute")):
        ligne_qualite(nom, etiquette)

    # Étapes hors qualité (combat scénarisé, sauvegarde, boss) : ce sont elles
    # qui révèlent les micro-blocages, pas la moyenne.
    for m in mesures:
        if m["nom"].startswith("arene_"):
            continue
        if m.get("fps_1pct_bas", 99) < SEUIL_1PCT:
            lignes.append(
                f"- **{m['nom']}** ({m.get('qualite')}) : {m['fps_moyen']} images/s de "
                f"moyenne mais {m['fps_1pct_bas']} sur les pires images → micro-blocages "
                "à l'apparition des ennemis ou des effets ; vérifier la première seconde "
                "de la vague et le coût du passage en qualité Haute."
            )

    # L'étape la plus lourde en appels de dessin : c'est là qu'est le coût.
    if mesures:
        lourde = max(mesures, key=lambda m: m.get("draw_calls", 0))
        tris = f"{lourde.get('triangles', 0):,}".replace(",", " ")
        lignes.append(
            f"- Étape la plus chargée : **{lourde['nom']}** avec "
            f"{lourde.get('draw_calls', 0)} appels de dessin et "
            f"{tris} primitives à l'écran."
        )
        if lourde.get("draw_calls", 0) > 200:
            lignes.append(
                "  → au-delà de ~200 appels, le processeur graphique attend : "
                "regrouper les décors statiques (un maillage par zone) avant d'ajouter des ennemis."
            )
    return lignes


def main() -> int:
    dossier = Path(sys.argv[1] if len(sys.argv) > 1 else "export/phone")
    appareil = lire_appareil(dossier)
    etapes = lire_mesures(dossier)
    mesurees = [e for e in etapes if e.get("statut") == "mesuree" and "fps_moyen" in e]
    autres = [e for e in etapes if e not in mesurees]
    niveau, raison = verdict(mesurees)
    conseils_txt = conseils(mesurees)

    lignes: list[str] = [
        "# Rapport téléphone — Guerrière d'Abomey",
        "",
        f"Généré le {datetime.now():%d/%m/%Y à %H:%M} par `tools/tester_telephone.sh`.",
        "",
        "## 1. Appareil",
        "",
        "| Champ | Valeur |",
        "|---|---|",
        f"| Modèle | {appareil.get('modele', 'inconnu')} |",
        f"| Android | {appareil.get('android', 'inconnu')} |",
        f"| Architecture | {appareil.get('abi', 'inconnue')} |",
        f"| RAM totale | {appareil.get('ram_mo', '?')} Mo |",
        f"| Écran | {appareil.get('ecran', '?')} |",
        f"| Densité | {appareil.get('densite', '?')} |",
        "",
        "## 2. Mesures",
        "",
    ]

    if mesurees:
        lignes += [
            "| Étape | Qualité | FPS moyen | FPS min | 1 % bas | Appels | Primitives | Mémoire max |",
            "|---|---|---|---|---|---|---|---|",
        ]
        for m in mesurees:
            # Virgules remplacées par des espaces : 1 407 052 se lit mieux
            # que 1,407,052 dans un rapport français.
            lignes.append((
                f"| {m['nom']} | {m['qualite']} | {m['fps_moyen']} | {m['fps_min']} | "
                f"{m['fps_1pct_bas']} | {m.get('draw_calls', 0)} | "
                f"{m.get('triangles', 0):,} | {m['memoire_max_mo']} Mo |"
            ).replace(",", " "))
    else:
        lignes.append("Aucune mesure : `user://rapport_perf.json` n'a pas été récupéré.")
        lignes.append("")
        lignes.append("Vérifier que l'APK est **debug** (le test automatique refuse de")
        lignes.append("tourner en release) et que `run-as` a pu écrire le drapeau.")

    if autres:
        lignes += ["", "Étapes non mesurées :"]
        for e in autres:
            lignes.append(f"- {e.get('nom')} — {e.get('raison', e.get('statut'))}")

    lignes += ["", "## 3. Verdict", "", f"**{niveau}** — {raison}.", ""]

    if conseils_txt:
        lignes += ["### Réglages recommandés", ""] + conseils_txt + [""]

    complement = janky(dossier)
    temp = temperature(dossier)
    faits = incidents(dossier)
    lignes += ["### Relevés système", ""]
    if complement:
        lignes.append(f"- gfxinfo : {complement}")
    if temp:
        lignes.append(f"- Température batterie en fin de test : {temp}")
    if faits["present"]:
        lignes.append(f"- Crashs et ANR : {faits['crashs']}")
        lignes.append(f"- Erreurs de script Godot : {faits['erreurs_script']}")
    lignes.append("")

    erreurs = []
    fichier_erreurs = dossier / "adb_erreurs.txt"
    if fichier_erreurs.exists():
        erreurs = [l for l in fichier_erreurs.read_text(encoding="utf-8", errors="replace").splitlines() if l.strip()]
    lignes += ["## 4. Erreurs adb", ""]
    lignes += [f"- {e}" for e in erreurs] if erreurs else ["Aucune."]

    lignes += ["", "## 5. Fichiers", ""]
    for nom in ("boot.png", "fin.png", "rapport_perf.json", "gfxinfo.txt",
                "meminfo.txt", "battery.txt", "logcat.txt", "install.log", "export.log"):
        if (dossier / nom).exists():
            lignes.append(f"- `{dossier.as_posix()}/{nom}`")

    sortie = dossier / "RAPPORT_TELEPHONE.md"
    sortie.write_text("\n".join(lignes) + "\n", encoding="utf-8")
    print(f"[rapport] {niveau} — {sortie}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
