"""Sépare un accessoire (sabre, fourreau, bouclier…) d'un modèle et l'exporte
en .glb à part, prêt à être attaché dans Godot (main droite, dos, ceinture).

Le fichier source n'est JAMAIS enregistré : un .blend est ouvert en mémoire, un
.glb est importé, et seul le .glb de sortie est écrit. Refus si
--output == --input.

Deux façons de choisir ce qu'on exporte :
  --name "Sabre*"      par nom (joker * autorisé, insensible à la casse ;
                       sans joker, simple « contient ») — cumulable, ou
                       séparé par des virgules : --name "Sabre,Fourreau"
  --selected           ce qui est déjà sélectionné dans le .blend (la
                       sélection est enregistrée dans le fichier), pratique
                       quand on a cliqué les objets dans l'éditeur.

Windows (cmd/PowerShell) :

    "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b ^
        -P tools\\blender\\separate_prop.py -- ^
        --input "D:\\assets\\clean\\hero.glb" ^
        --name "Sabre,Fourreau" ^
        --output "D:\\assets\\props\\sabre.glb"

Lister les objets disponibles sans rien exporter :

    blender -b -P tools/blender/separate_prop.py -- --input hero.glb --list

Options :
    --origin centre|min|max|monde   où tombe l'origine du .glb exporté
                                    (centre par défaut : le pivot est au milieu
                                    de l'accessoire, ce que Godot attend pour
                                    une arme qu'on tourne autour de sa poignée)
    --no-apply                      garde les transformations sur le nœud au
                                    lieu de les cuire dans le maillage
    --merge-materials               ramène l'accessoire à un seul matériau
    --scale 1.0                     échelle appliquée avant export
"""

from __future__ import annotations

import argparse
import fnmatch
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def log(message: str) -> None:
    print(f"[prop] {message}", flush=True)


def triangles(mesh: bpy.types.Mesh) -> int:
    return sum(max(0, len(p.vertices) - 2) for p in mesh.polygons)


def bbox(objets: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    """Boîte englobante commune, en coordonnées monde."""
    points: list[Vector] = []
    for obj in objets:
        points.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
    if not points:
        return Vector((0, 0, 0)), Vector((0, 0, 0))
    mini = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maxi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return mini, maxi


def selectionner(objets: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objets:
        obj.select_set(True)
    if objets:
        bpy.context.view_layer.objects.active = objets[0]


def charger(entree: Path) -> None:
    """Ouvre la source en mémoire. Aucun enregistrement n'est fait ensuite."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if entree.suffix.lower() == ".blend":
        bpy.ops.wm.open_mainfile(filepath=str(entree))
    elif entree.suffix.lower() in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(entree))
    else:
        raise ValueError(f"format non géré : {entree.suffix} (.glb, .gltf ou .blend)")
    log(f"ouvert : {entree.name}")


def correspond(obj: bpy.types.Object, motifs: list[str]) -> bool:
    """Vrai si le nom de l'objet répond à un motif (joker ou « contient »)."""
    nom = obj.name.lower()
    for motif in motifs:
        motif = motif.strip().lower()
        if not motif:
            continue
        if any(c in motif for c in "*?["):
            if fnmatch.fnmatchcase(nom, motif):
                return True
        elif motif in nom:
            return True
    return False


def recadrer_origine(objets: list[bpy.types.Object], mode: str, echelle: float) -> None:
    """Place l'ensemble à l'origine voulue et cuit les transformations.

    - `centre` : le milieu de la boîte englobante devient (0,0,0) — pivot naturel
      pour une arme (Godot la fait tourner autour de ce point).
    - `min`    : centre en X/Y et bas en Z (l'objet « pose » sur son point bas).
    - `max`    : centre en X/Y et haut en Z.
    - `monde`  : ne bouge rien ; l'origine reste celle du fichier d'origine.
    """
    mini, maxi = bbox(objets)
    if mode == "centre":
        decalage = Vector((-(mini.x + maxi.x) / 2, -(mini.y + maxi.y) / 2, -(mini.z + maxi.z) / 2))
    elif mode == "min":
        decalage = Vector((-(mini.x + maxi.x) / 2, -(mini.y + maxi.y) / 2, -mini.z))
    elif mode == "max":
        decalage = Vector((-(mini.x + maxi.x) / 2, -(mini.y + maxi.y) / 2, -maxi.z))
    else:  # monde
        decalage = Vector((0, 0, 0))

    for obj in objets:
        if decalage.length > 0:
            obj.location = obj.location + decalage
        if echelle != 1.0:
            obj.scale = (obj.scale.x * echelle, obj.scale.y * echelle, obj.scale.z * echelle)

    # Sans parent : un accessoire exporté seul ne doit pas hériter du corps.
    for obj in objets:
        if obj.parent is not None:
            selectionner([obj])
            bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")

    bpy.context.view_layer.update()


def cuire_transformations(objets: list[bpy.types.Object]) -> None:
    selectionner(objets)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def fusionner_materiaux(objets: list[bpy.types.Object]) -> None:
    """Ramène chaque objet à son premier matériau (export léger pour un accessoire)."""
    for obj in objets:
        mesh = obj.data
        if not mesh.materials:
            continue
        premier = mesh.materials[0]
        for poly in mesh.polygons:
            poly.material_index = 0
        mesh.materials.clear()
        if premier is not None:
            mesh.materials.append(premier)
    log("matériaux : un par objet")


def exporter(objets: list[bpy.types.Object], sortie: Path) -> None:
    sortie.parent.mkdir(parents=True, exist_ok=True)
    selectionner(objets)
    options = {
        "filepath": str(sortie),
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": True,
        "export_yup": True,
        "export_animations": False,
        "export_skins": False,
        "export_morph": False,
        "export_texcoords": True,
        "export_normals": True,
        "export_materials": "EXPORT",
        "export_extras": False,
    }
    connues = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
    bpy.ops.export_scene.gltf(**{k: v for k, v in options.items() if k in connues})
    log(f"écrit : {sortie} ({sortie.stat().st_size // 1024} Ko)")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="separate_prop.py",
        description="Extrait un accessoire d'un modèle vers un .glb séparé.",
    )
    parser.add_argument("--input", required=True, help="source .glb/.gltf/.blend (jamais modifiée)")
    parser.add_argument("--output", help=".glb de sortie (obligatoire sauf avec --list)")
    parser.add_argument("--name", default="", help="motif(s) de nom, séparés par des virgules")
    parser.add_argument("--selected", action="store_true", help="prendre la sélection du .blend")
    parser.add_argument("--origin", choices=("centre", "min", "max", "monde"), default="centre")
    parser.add_argument("--scale", type=float, default=1.0, help="échelle appliquée (1 = aucune)")
    parser.add_argument("--no-apply", action="store_true", help="ne pas cuire les transformations")
    parser.add_argument("--merge-materials", action="store_true", help="un seul matériau par objet")
    parser.add_argument("--list", action="store_true", help="lister les objets et sortir")
    return parser.parse_args(argv)


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parse_args(argv)

    entree = Path(args.input).expanduser()
    if not entree.exists():
        log(f"ÉCHEC : introuvable : {entree}")
        return 1

    try:
        charger(entree)
    except Exception as erreur:  # noqa: BLE001
        log(f"ÉCHEC à l'ouverture : {erreur}")
        return 1

    maillages = [o for o in bpy.data.objects if o.type == "MESH"]
    if args.list:
        log(f"{len(maillages)} maillage(s) :")
        for obj in sorted(maillages, key=lambda o: o.name.lower()):
            log(f"  {obj.name} — {triangles(obj.data)} triangles, {len(obj.data.materials)} matériau(x)")
        return 0

    if not args.output:
        log("ÉCHEC : --output manquant")
        return 1
    sortie = Path(args.output).expanduser()
    if sortie.exists() and sortie.resolve() == entree.resolve():
        log("ÉCHEC : la sortie ne peut pas être le fichier d'entrée")
        return 1

    motifs = [m for m in args.name.split(",") if m.strip()]
    choisis = [obj for obj in maillages if correspond(obj, motifs)] if motifs else []
    if args.selected:
        # getattr : dans un .glb importé, aucune sélection n'est enregistrée.
        selection = [o for o in bpy.context.selected_objects if o.type == "MESH"]
        choisis = list({obj.name: obj for obj in choisis + selection}.values())

    if not choisis:
        log("ÉCHEC : aucun objet ne correspond.")
        log("disponibles : " + ", ".join(sorted(o.name for o in maillages)))
        return 1

    log(f"retenu(s) : {', '.join(o.name for o in choisis)}")
    avant = sum(triangles(o.data) for o in choisis)

    try:
        recadrer_origine(choisis, args.origin, args.scale)
        if not args.no_apply:
            cuire_transformations(choisis)
        if args.merge_materials:
            fusionner_materiaux(choisis)
        exporter(choisis, sortie)
    except Exception as erreur:  # noqa: BLE001
        log(f"ÉCHEC à l'export : {erreur}")
        return 1

    log(f"terminé : {avant} triangles, origine « {args.origin} »")
    return 0


if __name__ == "__main__":
    sys.exit(main())
