"""Traite tout un dossier de modèles bruts et écrit un rapport CSV.

Pour chaque .glb du dossier d'entrée, le script applique exactement le pipeline
de `clean_character.py` (mêmes réglages, importé depuis le même dossier), écrit
le modèle nettoyé dans le dossier de sortie et ajoute UNE ligne au CSV :
triangles avant/après, taille de texture, échelle, hauteur, durée, erreur.

Aucun fichier d'entrée n'est modifié. Le script refuse un dossier de sortie
identique au dossier d'entrée.

Windows :

    "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b ^
        -P tools\\blender\\batch_export.py -- ^
        --input-dir "D:\\assets\\raw" ^
        --output-dir "D:\\assets\\clean" ^
        --height 1.70 --budget 6000

Le CSV est écrit en UTF-8 avec BOM et séparateur « ; » : il s'ouvre
directement dans Excel français. `--sep ,` pour un tableur anglophone.

Options :
    --pattern "*.glb"     filtre des fichiers (répétable)
    --stop-on-error       s'arrête au premier échec (défaut : continue)
    --recursive           descend dans les sous-dossiers
    --merge-distance 0.0001   soudure des sommets (transmise au nettoyage)
    --no-report           n'écrit pas le CSV (essai rapide)
"""

from __future__ import annotations

import argparse
import csv
import importlib.util
import io
import sys
import time
from pathlib import Path

# Le pipeline commun vit dans clean_character.py : on le charge par son chemin
# pour que les deux scripts restent lançables seuls, sans package Python.
DOSSIER = Path(__file__).resolve().parent


def charger_module(nom: str, fichier: str):
    spec = importlib.util.spec_from_file_location(nom, DOSSIER / fichier)
    if spec is None or spec.loader is None:
        raise ImportError(f"impossible de charger {fichier}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[nom] = module
    spec.loader.exec_module(module)
    return module


clean = charger_module("clean_character", "clean_character.py")


#: Colonnes du rapport, dans l'ordre. Les noms sont explicites (pas d'abrégé).
COLONNES = [
    "fichier", "statut", "triangles_avant", "triangles_apres", "budget",
    "objets_supprimes", "materiaux_avant", "materiaux_apres", "texture_max_px",
    "textures", "echelle", "hauteur_avant_m", "hauteur_apres_m",
    "sortie_ko", "duree_s", "message",
]


def log(message: str) -> None:
    print(f"[batch] {message}", flush=True)


def formater_textures(textures: list[dict]) -> str:
    """« corps:1024x1024|cheveux:512x512 » — lisible dans une cellule CSV."""
    return "|".join(f"{t['nom']}:{t['largeur']}x{t['hauteur']}" for t in textures)


def fichiers_a_traiter(dossier: Path, motifs: list[str], recursive: bool) -> list[Path]:
    """Liste triée des fichiers qui correspondent aux motifs (insensible à la casse)."""
    trouves: set[Path] = set()
    for motif in motifs:
        iterateur = dossier.rglob(motif) if recursive else dossier.glob(motif)
        for chemin in iterateur:
            if chemin.is_file() and chemin.suffix.lower() in {".glb", ".gltf"}:
                trouves.add(chemin)
    return sorted(trouves, key=lambda p: p.name.lower())


def ecrire_ligne(fichier, ligne: dict) -> None:
    """Écrit une ligne en ne gardant que les colonnes connues (ordre garanti)."""
    fichier.writerow({colonne: ligne.get(colonne, "") for colonne in COLONNES})


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="batch_export.py",
        description="Nettoie un dossier de modèles et écrit un rapport CSV.",
    )
    parser.add_argument("--input-dir", required=True, help="dossier des .glb bruts (jamais modifié)")
    parser.add_argument("--output-dir", required=True, help="dossier des .glb nettoyés")
    parser.add_argument("--report", help="chemin du CSV (défaut : <output-dir>/rapport_modeles.csv)")
    parser.add_argument("--pattern", action="append", default=[], help="motif de fichier (défaut *.glb)")
    parser.add_argument("--height", type=float, default=1.70, help="hauteur finale en m (0 = inchangée)")
    parser.add_argument("--budget", type=int, default=6000, help="triangles visés (0 = pas de décimation)")
    parser.add_argument("--keep-plans", action="store_true", help="garder les plans plats")
    parser.add_argument("--material-strategy", choices=("first", "vertex-color"), default="first")
    parser.add_argument("--merge-distance", type=float, default=0.0001, help="soudure des sommets (m)")
    parser.add_argument("--no-smooth", action="store_true", help="ne pas lisser les normales")
    parser.add_argument("--recursive", action="store_true", help="inclure les sous-dossiers")
    parser.add_argument("--stop-on-error", action="store_true", help="arrêt au premier échec")
    parser.add_argument("--sep", default=";", help="séparateur CSV (défaut « ; »)")
    parser.add_argument("--no-report", action="store_true", help="ne pas écrire le CSV")
    return parser.parse_args(argv)


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parse_args(argv)

    entree = Path(args.input_dir).expanduser().resolve()
    sortie = Path(args.output_dir).expanduser().resolve()
    if not entree.is_dir():
        log(f"ÉCHEC : dossier d'entrée introuvable : {entree}")
        return 1
    if entree == sortie:
        log("ÉCHEC : --output-dir doit être différent de --input-dir (les originaux sont sacrés)")
        return 1
    sortie.mkdir(parents=True, exist_ok=True)

    motifs = args.pattern or ["*.glb"]
    fichiers = fichiers_a_traiter(entree, motifs, args.recursive)
    if not fichiers:
        log(f"aucun fichier {motifs} dans {entree}")
        return 1
    log(f"{len(fichiers)} fichier(s) à traiter")

    chemin_rapport = Path(args.report) if args.report else sortie / "rapport_modeles.csv"
    chemin_rapport.parent.mkdir(parents=True, exist_ok=True)

    debut = time.time()
    total_avant = total_apres = 0
    echecs = 0

    # On écrit le CSV au fil de l'eau : un plantage de Blender au 12e modèle
    # laisse quand même les 11 premières lignes exploitables. Avec --no-report,
    # les lignes partent dans un tampon mémoire : aucun fichier n'est créé.
    flux = (
        open(chemin_rapport, "w", newline="", encoding="utf-8-sig")
        if not args.no_report
        else io.StringIO()
    )
    try:
        writer = csv.DictWriter(flux, fieldnames=COLONNES, delimiter=args.sep)
        if not args.no_report:
            writer.writeheader()
        for index, chemin in enumerate(fichiers, start=1):
            destination = sortie / chemin.name
            log(f"[{index}/{len(fichiers)}] {chemin.name}")
            ligne: dict = {"fichier": chemin.name, "budget": args.budget}
            try:
                stats = clean.clean_and_export(
                    entree=chemin,
                    sortie=destination,
                    hauteur=args.height,
                    budget=args.budget,
                    keep_plans=args.keep_plans,
                    strategie_materiau=args.material_strategy,
                    lisser=not args.no_smooth,
                    distance_soudure=args.merge_distance,
                )
                ligne.update({
                    "statut": "OK",
                    "triangles_avant": stats["triangles_avant"],
                    "triangles_apres": stats["triangles_apres"],
                    "objets_supprimes": stats["objets_supprimes"],
                    "materiaux_avant": stats["materiaux_avant"],
                    "materiaux_apres": stats["materiaux_apres"],
                    "texture_max_px": stats["texture_max_px"],
                    "textures": formater_textures(stats["textures"]),
                    "echelle": stats["echelle"],
                    "hauteur_avant_m": stats["hauteur_avant_m"],
                    "hauteur_apres_m": stats["hauteur_apres_m"],
                    "sortie_ko": stats["sortie_octets"] // 1024,
                    "duree_s": stats["duree_s"],
                    "message": "",
                })
                total_avant += stats["triangles_avant"]
                total_apres += stats["triangles_apres"]
            except Exception as erreur:  # noqa: BLE001 — un fichier cassé ne doit pas arrêter le lot
                echecs += 1
                ligne.update({"statut": "ERREUR", "message": str(erreur).replace("\n", " ")})
                log(f"  ÉCHEC : {erreur}")
                if args.stop_on_error:
                    if not args.no_report:
                        ecrire_ligne(writer, ligne)
                    flux.flush()
                    break
            if not args.no_report:
                ecrire_ligne(writer, ligne)
            flux.flush()
    finally:
        flux.close()

    duree = time.time() - debut
    log(f"terminé en {duree:.1f} s : {len(fichiers) - echecs} OK, {echecs} échec(s)")
    log(f"triangles : {total_avant} -> {total_apres}")
    if not args.no_report:
        log(f"rapport : {chemin_rapport}")
        log("ouvert par Excel : colonnes triables par triangles_apres ou texture_max_px")
    return 0 if echecs == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
