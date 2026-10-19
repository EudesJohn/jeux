"""Nettoyage d'un personnage .glb brut (sortie d'IA) pour Godot 4.

Le fichier d'entrée n'est JAMAIS modifié : on l'importe en mémoire, on
travaille, et on écrit un NOUVEAU .glb (refus si --output == --input).

Étapes, dans cet ordre :
  1. suppression des plans/sols parasites, caméras, lumières, vides ;
  2. fusion des maillages en un seul objet, transformations appliquées ;
  3. centrage sur X/Y et origine posée aux pieds (Z = 0) ;
  4. mise à l'échelle pour une hauteur totale de 1,70 m (paramètre) ;
  5. réduction à un budget de triangles (Decimate COLLAPSE, UV préservées) ;
  6. fusion des matériaux en un seul ;
  7. recalcul des normales vers l'extérieur ;
  8. export .glb AVANT le rig (aucune animation, aucun skin).

Windows (PowerShell ou cmd), Blender 4.x installé par défaut :

    "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b ^
        -P tools\\blender\\clean_character.py -- ^
        --input "D:\\assets\\raw\\hero.glb" ^
        --output "D:\\assets\\clean\\hero.glb"

Ou, si `blender` est dans le PATH (bash Git for Windows) :

    blender -b -P tools/blender/clean_character.py -- \
        --input assets/raw/hero.glb --output assets/clean/hero.glb

Options utiles :
    --height 1.70        hauteur finale en mètres (0 = ne pas redimensionner)
    --budget 6000        triangles visés (0 = ne pas décimer)
    --keep-plans         ne supprime pas les plans plats (décor voulu)
    --material-strategy first|vertex-color
                         first : garde le matériau dominant (sa texture) ;
                         vertex-color : cuit la couleur de chaque matériau dans
                         les couleurs de sommets, puis un seul matériau sans
                         texture (utile quand l'IA a fait 12 matériaux plats).
    --no-smooth          laisse le facettage tel quel (par défaut lissage)
    --merge-distance 0.0001  soudure des sommets doublons (m) ; 0 = aucune

Code de sortie : 0 si tout va bien, 1 si le fichier est inutilisable.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector

# ---------------------------------------------------------------------------
# Constantes de détection
# ---------------------------------------------------------------------------

#: Mots qui trahissent un décor produit par un générateur d'images 3D.
MOTS_PARASITES = (
    "ground", "floor", "sol", "terrain", "plane", "plan_", "backdrop",
    "background", "fond", "shadowcatcher", "shadow_catcher", "shadow",
    "pedestal", "piedestal", "socle", "base_plate", "plate", "sky", "ciel",
    "grid", "grille", "stage", "scene_",
)

#: Un plan parasite a peu de faces : au-delà, c'est un vrai maillage.
MAX_FACES_PLAN = 64

#: Un plan est « plat » si son épaisseur fait moins de 2 % de sa largeur.
RATIO_PLAT = 0.02


# ---------------------------------------------------------------------------
# Petites aides
# ---------------------------------------------------------------------------

def log(message: str) -> None:
    """Affiche une ligne préfixée, pour distinguer nos messages de ceux de Blender."""
    print(f"[clean] {message}", flush=True)


def triangles(mesh: bpy.types.Mesh) -> int:
    """Nombre de triangles réels (un quad compte pour 2, un n-gone pour n-2)."""
    return sum(max(0, len(poly.vertices) - 2) for poly in mesh.polygons)


def bbox_monde(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    """Boîte englobante en coordonnées monde (matrix_world comprise)."""
    if not obj.data.vertices:
        return Vector((0, 0, 0)), Vector((0, 0, 0))
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    mini = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maxi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return mini, maxi


def selectionner(obj: bpy.types.Object) -> None:
    """Désélectionne tout, puis sélectionne `obj` et en fait l'objet actif."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def appliquer_transformations(obj: bpy.types.Object) -> None:
    """Applique location/rotation/échelle : le maillage devient la référence."""
    selectionner(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def dossier_parent(chemin: Path) -> Path:
    """Crée le dossier de sortie s'il manque (Blender n'échoue pas sinon)."""
    chemin.parent.mkdir(parents=True, exist_ok=True)
    return chemin


def exporter_glb(obj: bpy.types.Object, sortie: Path, morph: bool = False) -> None:
    """Exporte UN objet en .glb, sans animation ni skin (on est avant le rig).

    Les noms d'options changent légèrement d'une version 4.x à l'autre : on ne
    passe que celles que l'opérateur connaît vraiment (get_rna_type()).
    """
    selectionner(obj)
    options = {
        "filepath": str(sortie),
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": True,
        "export_yup": True,
        "export_animations": False,
        "export_skins": False,
        "export_morph": morph,
        "export_morph_normal": morph,
        "export_texcoords": True,
        "export_normals": True,
        "export_materials": "EXPORT",
        "export_extras": False,
    }
    connues = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
    bpy.ops.export_scene.gltf(**{k: v for k, v in options.items() if k in connues})
    log(f"écrit : {sortie}")


# ---------------------------------------------------------------------------
# 1. Nettoyage du décor
# ---------------------------------------------------------------------------

def supprimer_parasites(keep_plans: bool = False) -> list[str]:
    """Supprime caméras, lumières, objets vides et plans/sols parasites.

    Un plan est retenu comme parasite s'il réunit :
      - un nom évocateur (ground, floor, backdrop…), OU
      - peu de faces (<= 64), horizontal (épaisseur en Z <= 2 % de la largeur)
        ET aussi large que la silhouette du personnage.
    Le dernier critère évite de manger des cheveux ou des pans de tissu, qui
    sont verticaux et étroits.
    """
    supprimes: list[str] = []

    # Caméras, lumières, vides : jamais utiles dans un modèle de personnage.
    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT", "EMPTY"}:
            supprimes.append(f"{obj.name} ({obj.type.lower()})")
            bpy.data.objects.remove(obj, do_unlink=True)

    maillages = [o for o in bpy.data.objects if o.type == "MESH"]

    # Emprise horizontale de la scène : sert de mètre pour « assez large ».
    emprise = 0.0
    for obj in maillages:
        mini, maxi = bbox_monde(obj)
        emprise = max(emprise, maxi.x - mini.x, maxi.y - mini.y)

    for obj in list(maillages):
        mesh = obj.data
        if len(mesh.polygons) == 0:
            supprimes.append(f"{obj.name} (maillage vide)")
            bpy.data.objects.remove(obj, do_unlink=True)
            continue

        nom = obj.name.lower()
        # --keep-plans désactive AUSSI la règle par nom : un décor voulu peut
        # s'appeler « floor » ou « backdrop ».
        par_nom = (not keep_plans) and any(mot in nom for mot in MOTS_PARASITES)

        mini, maxi = bbox_monde(obj)
        dx, dy, dz = maxi.x - mini.x, maxi.y - mini.y, maxi.z - mini.z
        largeur = max(dx, dy)
        plat = largeur > 0 and dz <= RATIO_PLAT * largeur
        horizontal = dz <= RATIO_PLAT * max(dx, dy, 1e-6)
        grand = emprise > 0 and largeur >= 0.8 * emprise
        par_forme = (
            not keep_plans
            and len(mesh.polygons) <= MAX_FACES_PLAN
            and plat
            and horizontal
            and grand
        )

        if par_nom or par_forme:
            raison = "nom" if par_nom else "forme plate"
            supprimes.append(f"{obj.name} ({raison})")
            bpy.data.objects.remove(obj, do_unlink=True)

    # Le nom est conservé dans la liste AVANT suppression (l'objet n'existe plus).
    if supprimes:
        log("supprimés : " + ", ".join(supprimes))
    else:
        log("aucun parasite détecté")
    return supprimes


# ---------------------------------------------------------------------------
# 2. Fusion, centrage, échelle
# ---------------------------------------------------------------------------

def fusionner_maillages() -> bpy.types.Object:
    """Fusionne tous les maillages restants en un seul objet.

    Un personnage d'IA arrive souvent en 5 à 20 morceaux (torse, cheveux,
    pagnes…). Un seul maillage = un seul draw call dans Godot et un budget
    de triangles mesurable.
    """
    maillages = [o for o in bpy.data.objects if o.type == "MESH"]
    if not maillages:
        raise RuntimeError("aucun maillage utilisable après le nettoyage")

    # Détache les parents en gardant la position monde, puis applique les
    # transformations : sinon la fusion mélange des repères différents.
    for obj in maillages:
        if obj.parent is not None:
            selectionner(obj)
            bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
        appliquer_transformations(obj)

    # L'objet actif reçoit les autres : on prend le plus gros (le corps).
    principal = max(maillages, key=lambda o: triangles(o.data))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in maillages:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = principal
    if len(maillages) > 1:
        bpy.ops.object.join()
    log(f"fusion : {len(maillages)} objet(s) -> '{principal.name}'")
    return principal


def centrer_et_poser_origine(obj: bpy.types.Object) -> float:
    """Centre le personnage en X/Y, pose l'origine aux pieds, renvoie sa hauteur."""
    mini, maxi = bbox_monde(obj)
    centre = Vector(((mini.x + maxi.x) / 2.0, (mini.y + maxi.y) / 2.0, 0.0))

    # Déplace pour que les pieds touchent Z = 0 et que le corps soit centré.
    obj.location = obj.location + Vector((-centre.x, -centre.y, -mini.z))
    appliquer_transformations(obj)

    # L'origine (le point que Godot prendra comme position du nœud) part au
    # curseur 3D, laissé à (0,0,0) : elle est donc entre les pieds.
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    selectionner(obj)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

    mini, maxi = bbox_monde(obj)
    hauteur = maxi.z - mini.z
    log(f"hauteur d'origine : {hauteur:.3f} m")
    return hauteur


def mettre_a_l_echelle(obj: bpy.types.Object, hauteur_cible: float) -> float:
    """Met à l'échelle pour obtenir `hauteur_cible` (m). Renvoie le facteur."""
    if hauteur_cible <= 0:
        log("échelle : inchangée (--height 0)")
        return 1.0
    mini, maxi = bbox_monde(obj)
    hauteur = maxi.z - mini.z
    if hauteur <= 1e-6:
        raise RuntimeError("hauteur nulle : le maillage est plat, rien à mettre à l'échelle")
    facteur = hauteur_cible / hauteur

    # L'échelle est appliquée au maillage (pas laissée sur l'objet) : Godot
    # reçoit des sommets déjà à la bonne taille.
    obj.scale = (facteur, facteur, facteur)
    appliquer_transformations(obj)
    log(f"échelle ×{facteur:.4f} -> {hauteur_cible:.2f} m")
    return facteur


# ---------------------------------------------------------------------------
# 3. Nettoyage du maillage
# ---------------------------------------------------------------------------

def souder(obj: bpy.types.Object, distance: float = 0.0001) -> None:
    """Soude les sommets doublons (l'IA en laisse beaucoup) et les faces libres.

    Les UV sont conservées : `remove_doubles` fusionne les sommets mais chaque
    boucle (loop) garde ses coordonnées UV.
    """
    selectionner(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    if distance and distance > 0:
        bpy.ops.mesh.remove_doubles(threshold=distance)
        log(f"soudure : {distance} m")
    if hasattr(bpy.ops.mesh, "delete_loose"):
        bpy.ops.mesh.delete_loose(use_verts=True, use_edges=True, use_faces=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def decimer(obj: bpy.types.Object, budget: int) -> dict[str, int]:
    """Réduit à `budget` triangles avec Decimate COLLAPSE.

    Pourquoi COLLAPSE : il interpole les UV (les coutures tiennent) et garde la
    silhouette. 'UNSUBDIV' détruit la topologie, 'DISSOLVE' casse les UV : à
    éviter sur un personnage texturé.
    """
    avant = triangles(obj.data)
    if budget <= 0 or avant <= budget:
        log(f"triangles : {avant} (budget {budget or 'aucun'}) — rien à décimer")
        return {"avant": avant, "apres": avant}

    # Boucle courte : un seul passage vise un peu juste (les triangles
    # dégénérés disparaissent ensuite), on corrige le ratio si besoin.
    for essai in range(1, 6):
        courant = triangles(obj.data)
        if courant <= budget:
            break
        ratio = max(0.01, min(1.0, budget / float(courant)))
        mod = obj.modifiers.new(name="Decimate", type="DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True  # sortie 100 % triangles
        selectionner(obj)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        log(f"décimation {essai} : ratio {ratio:.3f} -> {triangles(obj.data)} triangles")

    apres = triangles(obj.data)
    if apres > budget:
        log(f"ATTENTION : {apres} triangles restants pour un budget de {budget}")
    else:
        log(f"triangles : {avant} -> {apres} (budget {budget})")
    return {"avant": avant, "apres": apres}


def fusionner_materiaux(obj: bpy.types.Object, strategie: str = "first") -> dict:
    """Ramène le maillage à UN seul matériau.

    `first`        : garde le matériau du plus grand nombre de faces (donc sa
                     texture, souvent l'atlas du corps) et y remappe tout.
                     Les textures des autres matériaux sont perdues : le
                     rapport le dit.
    `vertex-color` : écrit la couleur de chaque matériau dans un calque de
                     couleur par boucle, puis crée un matériau unique qui lit
                     ce calque. Aucune texture, mais les couleurs restent.
    """
    mesh = obj.data
    materiaux = [m for m in mesh.materials if m is not None]
    avant = len(materiaux)
    if avant == 0:
        log("matériaux : aucun (rien à fusionner)")
        return {"avant": 0, "apres": 0, "strategie": strategie}

    # Poids de chaque emplacement de matériau, en faces.
    poids: dict[int, int] = {}
    for poly in mesh.polygons:
        poids[poly.material_index] = poids.get(poly.material_index, 0) + 1

    if strategie == "vertex-color":
        calque = mesh.color_attributes.get("Couleur")
        if calque is None:
            calque = mesh.color_attributes.new(name="Couleur", type="FLOAT_COLOR", domain="CORNER")

        # Couleur de base de chaque matériau (Principled, sinon couleur d'aperçu).
        couleurs: dict[int, tuple[float, float, float, float]] = {}
        for index, mat in enumerate(mesh.materials):
            couleur = (0.8, 0.8, 0.8, 1.0)
            if mat is not None:
                if mat.use_nodes:
                    for node in mat.node_tree.nodes:
                        if node.type == "BSDF_PRINCIPLED":
                            valeur = node.inputs["Base Color"].default_value
                            couleur = (valeur[0], valeur[1], valeur[2], valeur[3])
                            break
                else:
                    couleur = tuple(mat.diffuse_color)
            couleurs[index] = couleur

        for poly in mesh.polygons:
            couleur = couleurs.get(poly.material_index, (0.8, 0.8, 0.8, 1.0))
            for li in poly.loop_indices:
                calque.data[li].color = couleur

        mat_unique = bpy.data.materials.new("M_Personnage")
        mat_unique.use_nodes = True
        nodes = mat_unique.node_tree.nodes
        liens = mat_unique.node_tree.links
        principled = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        if principled is not None:
            attr = nodes.new("ShaderNodeVertexColor")
            attr.layer_name = calque.name
            liens.new(attr.outputs["Color"], principled.inputs["Base Color"])
        log("matériaux : couleur cuite dans les couleurs de sommets")
    else:
        # Emplacement dominant : celui qui couvre le plus de faces.
        dominant = max(poids, key=lambda i: poids[i]) if poids else 0
        mat_unique = mesh.materials[dominant] if dominant < len(mesh.materials) else None
        if mat_unique is None:
            mat_unique = bpy.data.materials.new("M_Personnage")
        textures_perdues = [
            m.name for i, m in enumerate(mesh.materials)
            if m is not None and m.use_nodes and i != dominant
            and any(n.type == "TEX_IMAGE" for n in m.node_tree.nodes)
        ]
        if textures_perdues:
            log(f"ATTENTION : textures perdues en fusionnant : {', '.join(textures_perdues)}")

    # Tout sur l'emplacement 0, puis un seul matériau dans la liste.
    for poly in mesh.polygons:
        poly.material_index = 0
    mesh.materials.clear()
    mesh.materials.append(mat_unique)
    log(f"matériaux : {avant} -> 1 ('{mat_unique.name}')")
    return {"avant": avant, "apres": 1, "strategie": strategie, "nom": mat_unique.name}


def recalculer_normales(obj: bpy.types.Object, lisser: bool = True) -> None:
    """Normales vers l'extérieur + lissage optionnel (rendu low-poly propre)."""
    selectionner(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if lisser:
        bpy.ops.object.shade_smooth()
    log("normales recalculées" + (" + lissage" if lisser else ""))


def rapport_textures() -> dict:
    """Taille de la plus grande texture utilisée (px) et liste des images."""
    images = []
    for image in bpy.data.images:
        if image.users == 0 or image.size[0] == 0:
            continue
        images.append({"nom": image.name, "largeur": int(image.size[0]), "hauteur": int(image.size[1])})
    maxi = max((max(i["largeur"], i["hauteur"]) for i in images), default=0)
    return {"max_px": maxi, "images": images}


# ---------------------------------------------------------------------------
# Pipeline complet (réutilisé par batch_export.py)
# ---------------------------------------------------------------------------

def clean_and_export(
    entree: Path,
    sortie: Path,
    hauteur: float = 1.70,
    budget: int = 6000,
    keep_plans: bool = False,
    strategie_materiau: str = "first",
    lisser: bool = True,
    distance_soudure: float = 0.0001,
    decimer_maillage: bool = True,
) -> dict:
    """Nettoie `entree` et écrit `sortie`. Renvoie un dictionnaire de mesures."""
    entree = Path(entree).expanduser()
    sortie = Path(sortie).expanduser()
    if not entree.exists():
        raise FileNotFoundError(f"fichier d'entrée introuvable : {entree}")
    if entree.resolve() == sortie.resolve():
        raise ValueError("--output ne peut pas être le fichier d'entrée (il ne doit jamais être modifié)")
    if entree.suffix.lower() not in {".glb", ".gltf"}:
        raise ValueError(f"format non géré : {entree.suffix} (attendu .glb ou .gltf)")

    debut = time.time()

    # Scène vide : aucune donnée du fichier Blender courant ne fuit.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(entree))
    log(f"importé : {entree.name}")

    objets_avant = len(bpy.data.objects)
    supprimes = supprimer_parasites(keep_plans=keep_plans)
    tuiles_avant = rapport_textures()

    obj = fusionner_maillages()
    obj.name = "Personnage"
    obj.data.name = "PersonnageMesh"

    hauteur_origine = centrer_et_poser_origine(obj)
    facteur = mettre_a_l_echelle(obj, hauteur)

    souder(obj, distance_soudure)
    decoupe = decimer(obj, budget) if decimer_maillage else {"avant": triangles(obj.data), "apres": triangles(obj.data)}
    materiaux = fusionner_materiaux(obj, strategie_materiau)
    recalculer_normales(obj, lisser=lisser)

    rapport = rapport_textures()
    bpy.context.view_layer.update()

    dossier_parent(sortie)
    exporter_glb(obj, sortie)

    mini, maxi = bbox_monde(obj)
    stats = {
        "fichier": entree.name,
        "sortie": str(sortie),
        "statut": "OK",
        "triangles_avant": decoupe["avant"],
        "triangles_apres": decoupe["apres"],
        "budget": budget,
        "objets_supprimes": len(supprimes),
        "objets_total_avant": objets_avant,
        "materiaux_avant": materiaux["avant"],
        "materiaux_apres": materiaux["apres"],
        "texture_max_px": rapport["max_px"],
        "textures": rapport["images"],
        "textures_avant_fusion_max_px": tuiles_avant["max_px"],
        "echelle": round(facteur, 6),
        "hauteur_avant_m": round(hauteur_origine, 4),
        "hauteur_apres_m": round(maxi.z - mini.z, 4),
        "sortie_octets": sortie.stat().st_size if sortie.exists() else 0,
        "duree_s": round(time.time() - debut, 2),
    }
    log(
        "terminé : {tris_avant} -> {tris_apres} triangles, {h:.2f} m, "
        "{mat_avant} -> 1 matériau, {taille} Ko en {duree} s".format(
            tris_avant=stats["triangles_avant"], tris_apres=stats["triangles_apres"],
            h=stats["hauteur_apres_m"], mat_avant=stats["materiaux_avant"],
            taille=stats["sortie_octets"] // 1024, duree=stats["duree_s"],
        )
    )
    return stats


# ---------------------------------------------------------------------------
# Ligne de commande
# ---------------------------------------------------------------------------

def parse_args(argv: list[str]) -> argparse.Namespace:
    """Lit les arguments qui suivent `--` (sinon Blender mange les siens)."""
    parser = argparse.ArgumentParser(
        prog="clean_character.py",
        description="Nettoie un .glb de personnage brut et l'exporte pour Godot 4.",
    )
    parser.add_argument("--input", required=True, help=".glb/.gltf brut (jamais modifié)")
    parser.add_argument("--output", required=True, help=".glb de sortie")
    parser.add_argument("--height", type=float, default=1.70, help="hauteur finale en m (0 = inchangée)")
    parser.add_argument("--budget", type=int, default=6000, help="triangles visés (0 = pas de décimation)")
    parser.add_argument("--keep-plans", action="store_true", help="garder les plans plats (décor voulu)")
    parser.add_argument("--material-strategy", choices=("first", "vertex-color"), default="first")
    parser.add_argument("--no-smooth", action="store_true", help="ne pas lisser les normales")
    parser.add_argument("--merge-distance", type=float, default=0.0001, help="soudure des sommets (m), 0 = aucune")
    parser.add_argument("--json", help="écrit aussi les mesures dans ce fichier JSON")
    return parser.parse_args(argv)


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parse_args(argv)
    try:
        stats = clean_and_export(
            entree=Path(args.input),
            sortie=Path(args.output),
            hauteur=args.height,
            budget=args.budget,
            keep_plans=args.keep_plans,
            strategie_materiau=args.material_strategy,
            lisser=not args.no_smooth,
            distance_soudure=args.merge_distance,
        )
    except Exception as erreur:  # noqa: BLE001 — on veut un code de sortie propre
        log(f"ÉCHEC : {erreur}")
        return 1

    if args.json:
        dossier_parent(Path(args.json))
        Path(args.json).write_text(json.dumps(stats, indent=2, ensure_ascii=False), encoding="utf-8")
        log(f"mesures écrites : {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
