"""Prépare un corps de base pour les blendshapes Godot : crée les shape keys
VIDES `shoulders`, `muscle`, `hips`, `slim` et explique comment les sculpter.

Le fichier source n'est jamais modifié : on importe, on ajoute les clés, on
écrit un NOUVEAU fichier (.blend pour sculpter, ou .glb pour Godot).

Windows :

    "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b ^
        -P tools\\blender\\add_shape_keys_template.py -- ^
        --input "D:\\assets\\clean\\hero.glb" ^
        --output "D:\\assets\\clean\\hero_shapekeys.blend"

Puis on sculpte dans Blender (voir les instructions imprimées), et on exporte :

    "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b ^
        -P tools\\blender\\add_shape_keys_template.py -- ^
        --input "D:\\assets\\clean\\hero_shapekeys.blend" ^
        --output "D:\\assets\\clean\\hero_shapekeys.glb"

Sans fichier d'entrée, `--demo` fabrique un corps factice (sphère allongée) :
utile pour vérifier la chaîne avant d'avoir le vrai modèle.

Comment ça marche côté Godot 4 :
  - chaque shape key non-Basis devient un « blend shape » du MeshInstance3D ;
  - la valeur 0 = corps de base, 1 = forme sculptée (on peut dépasser) ;
  - glTF n'exporte que les clés RELATIVES : le Basis doit rester en premier
    (c'est ce que fait ce script) ;
  - 4 clés × N sommets × 2 (position + normale) coûtent de la mémoire : sur un
    téléphone d'entrée de gamme, reste sous ~8 clés pour un personnage.

Options :
    --object "Corps"     nom du maillage à équiper (défaut : le plus gros)
    --names "shoulders,muscle,hips,slime"
    --slider-max 1.0     valeur maximale du curseur de chaque clé
    --demo               créer un corps factice si --input est absent
    --list               lister les shape keys existantes et sortir
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy

#: Clés demandées par le jeu (DESIGN.md § 8.6 : morphologie de la joueuse).
CLES_PAR_DEFAUT = ("shoulders", "muscle", "hips", "slim")

#: Mode d'emploi de chaque clé, imprimé à la fin. Le sculpteur n'a pas à lire
#: le code : tout est là.
INSTRUCTIONS = {
    "shoulders": (
        "Épaules plus larges / plus carrées. En Edit Mode, sélectionne la bande "
        "de sommets au-dessus des pectoraux (couronne d'épaule), active le "
        "‘Proportional Editing’ (O) rayon ≈ 0,12 m et pousse de +3 à +4 cm vers "
        "l'extérieur en X. Laisse les bras et le cou intacts : c'est la "
        "silhouette qui doit changer, pas la pose."
    ),
    "muscle": (
        "Musculature visible. Onglet Sculpt, brosse ‘Inflate’ (I) taille 0,08 m, "
        "force ≈ 0,3 : biceps, deltoïdes, pectoraux, abdos, mollets. +1 à +2 cm "
        "suffisent en low-poly. Symétrie X activée (barre d'outils > Symmetry) "        "pour ne pas sculpter un seul côté."
    ),
    "hips": (
        "Hanches plus larges, taille marquée. Sélectionne le bassin (sous le "
        "nombril) et écarte de +3 cm en X ; remonte légèrement les crêtes "
        "iliaques. Vérifie en vue de face que les jambes restent droites."
    ),
    "slim": (
        "Version amincie : MÊME geste que ‘hips’ mais vers l'intérieur (−3 cm), "
        "plus une taille rentrée de −1,5 cm. Cette clé est l'opposé de ‘muscle’ "
        "et ‘shoulders’ : on ne l'utilise jamais en même temps qu'elles à 1,0."
    ),
}


def log(message: str) -> None:
    print(f"[shape] {message}", flush=True)


def creer_corps_demo() -> bpy.types.Object:
    """Corps factice : une sphère allongée, assez de sommets pour sculpter."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0)
    obj = bpy.context.active_object
    obj.name = "Corps"
    obj.scale = (0.28, 0.18, 0.85)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    log("corps de démonstration créé (--demo)")
    return obj


def choisir_maillage(nom: str | None) -> bpy.types.Object:
    """Prend l'objet demandé, sinon le maillage qui a le plus de sommets."""
    maillages = [o for o in bpy.data.objects if o.type == "MESH"]
    if not maillages:
        raise RuntimeError("aucun maillage dans la scène")
    if nom:
        for obj in maillages:
            if obj.name == nom or obj.name.lower() == nom.lower():
                return obj
        raise RuntimeError(f"maillage '{nom}' introuvable (disponibles : {', '.join(o.name for o in maillages)})")
    return max(maillages, key=lambda o: len(o.data.vertices))


def creer_cles(obj: bpy.types.Object, noms: list[str], slider_max: float) -> list[str]:
    """Ajoute Basis puis une clé vide par nom. Renvoie les clés réellement créées."""
    if obj.data.shape_keys is None:
        # from_mix=False : la clé part du maillage tel quel, sans mélange.
        obj.shape_key_add(name="Basis", from_mix=False)
        log("clé Basis créée")

    existantes = {bloc.name for bloc in obj.data.shape_keys.key_blocks}
    creees: list[str] = []
    for nom in noms:
        if nom in existantes:
            log(f"'{nom}' existe déjà : conservée telle quelle")
            continue
        bloc = obj.shape_key_add(name=nom, from_mix=False)
        bloc.slider_min = 0.0
        bloc.slider_max = slider_max
        bloc.value = 0.0          # vide : le corps ne change pas tant qu'on ne sculpte pas
        bloc.vertex_group = ""    # aucune restriction : tous les sommets bougent
        creees.append(nom)
        log(f"clé '{nom}' ajoutée (vide)")

    # Les clés doivent rester dans l'ordre Basis -> clés : glTF exporte dans cet
    # ordre et Godot affiche les blend shapes dans le même.
    obj.data.shape_keys.use_relative = True
    return creees


def lister(obj: bpy.types.Object) -> None:
    if obj.data.shape_keys is None:
        log(f"'{obj.name}' n'a aucune shape key")
        return
    log(f"'{obj.name}' : {len(obj.data.shape_keys.key_blocks)} clé(s)")
    for bloc in obj.data.shape_keys.key_blocks:
        log(f"  {bloc.name} — valeur {bloc.value:.2f} [{bloc.slider_min:g}..{bloc.slider_max:g}]")


def importer(entree: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if entree.suffix.lower() == ".blend":
        bpy.ops.wm.open_mainfile(filepath=str(entree))
    elif entree.suffix.lower() in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(entree))
    else:
        raise ValueError(f"format non géré : {entree.suffix}")
    log(f"ouvert : {entree.name}")


def enregistrer(obj: bpy.types.Object, sortie: Path) -> None:
    """Écrit le .blend (pour sculpter) ou le .glb (pour Godot)."""
    sortie.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    if sortie.suffix.lower() == ".blend":
        bpy.ops.wm.save_as_mainfile(filepath=str(sortie))
        log(f"écrit : {sortie} (sculpte ici, puis relance avec --output …glb)")
        return

    options = {
        "filepath": str(sortie),
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": False,      # True supprimerait les shape keys !
        "export_yup": True,
        "export_animations": False,
        "export_skins": False,
        "export_morph": True,       # les blend shapes
        "export_morph_normal": True,
        "export_texcoords": True,
        "export_normals": True,
        "export_materials": "EXPORT",
    }
    connues = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
    bpy.ops.export_scene.gltf(**{k: v for k, v in options.items() if k in connues})
    log(f"écrit : {sortie} ({sortie.stat().st_size // 1024} Ko, morph targets inclus)")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="add_shape_keys_template.py",
        description="Ajoute les shape keys shoulders/muscle/hips/slim à un corps.",
    )
    parser.add_argument("--input", help="corps de base .glb/.gltf/.blend")
    parser.add_argument("--output", help=".blend (sculpture) ou .glb (Godot) ; requis sauf --list")
    parser.add_argument("--object", help="nom du maillage à équiper")
    parser.add_argument("--names", default=",".join(CLES_PAR_DEFAUT))
    parser.add_argument("--slider-max", type=float, default=1.0)
    parser.add_argument("--demo", action="store_true", help="corps factice si --input est absent")
    parser.add_argument("--list", action="store_true", help="lister les clés et sortir")
    return parser.parse_args(argv)


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parse_args(argv)

    try:
        if args.input:
            entree = Path(args.input).expanduser()
            if not entree.exists():
                raise FileNotFoundError(f"introuvable : {entree}")
            if Path(args.output).expanduser().resolve() == entree.resolve():
                raise ValueError("--output doit être un NOUVEAU fichier (la source n'est jamais modifiée)")
            importer(entree)
            obj = choisir_maillage(args.object)
        elif args.demo:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            obj = creer_corps_demo()
        else:
            raise ValueError("--input manquant (ou --demo pour un corps factice)")

        if args.list:
            lister(obj)
            return 0
        if not args.output:
            raise ValueError("--output manquant")

        noms = [n.strip() for n in args.names.split(",") if n.strip()]
        creees = creer_cles(obj, noms, args.slider_max)
        enregistrer(obj, Path(args.output).expanduser())
    except Exception as erreur:  # noqa: BLE001
        log(f"ÉCHEC : {erreur}")
        return 1

    # Mode d'emploi : uniquement pour les clés qu'on vient de créer.
    if creees:
        log("")
        log("COMMENT SCULPTER CHAQUE CLÉ (Blender : Object Data > Shape Keys)")
        for nom in creees:
            log(f"  • {nom} : {INSTRUCTIONS.get(nom, 'aucune consigne enregistrée')}")
        log("")
        log("Rappels :")
        log("  - sélectionne la clé dans la liste, monte sa valeur à 0,5 pour VOIR")
        log("    la déformation pendant la sculpture, puis remets-la à 0 avant export ;")
        log("  - ne modifie jamais 'Basis' après coup (tout le reste se décale) ;")
        log("  - nomme les clés sans accent ni espace : Godot les reprend telles quelles.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
