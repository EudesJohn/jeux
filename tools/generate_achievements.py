"""Écrit les fiches de succès `data/achievements/*.tres` (PHASE 8).

    python tools/generate_achievements.py

Un succès = un compteur (`stat`) et un seuil (`target`). `Achievements`
incrémente les compteurs depuis les signaux de `Events`, puis débloque.
"""
import pathlib

OUT = pathlib.Path("data/achievements")

SUCCES = [
    # id, titre, description, compteur, seuil, caché
    ("premiere_victoire", "Première victoire",
     "Terminer un niveau, quel qu'il soit.", "levels", 1, False),
    ("liberatrice", "Libératrice",
     "Libérer 10 prisonniers.", "rescued", 10, False),
    ("grande_liberatrice", "Grande libératrice",
     "Libérer 50 prisonniers.", "rescued", 50, False),
    ("gardienne", "Gardienne",
     "Réussir 20 gardes parfaites.", "perfect_guards", 20, False),
    ("main_de_fer", "Main de fer",
     "Réussir 100 gardes parfaites.", "perfect_guards", 100, False),
    ("chasseuse", "Chasseuse",
     "Vaincre 100 ennemis.", "kills", 100, False),
    ("fleau_du_royaume", "Fléau du royaume",
     "Vaincre 500 ennemis.", "kills", 500, False),
    ("tombeur_de_gardiens", "Tombeur de gardiens",
     "Vaincre un gardien de chapitre.", "bosses", 1, False),
    ("maitre_des_gardiens", "Maître des gardiens",
     "Vaincre les 5 gardiens du royaume.", "bosses", 5, False),
    ("infatigable", "Infatigable",
     "Tenir 10 vagues en Survie.", "survival_waves", 10, False),
    ("fidele", "Fidèle au royaume",
     "Relever le défi du jour 7 jours de suite.", "daily_streak", 7, False),
    ("duo_de_choc", "Duo de choc",
     "Terminer un niveau en coop WiFi.", "coop_levels", 1, False),
]

MODELE = """[gd_resource type="Resource" script_class="AchievementData" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/resources/AchievementData.gd" id="1"]

[resource]
script = ExtResource("1")
id = "{id}"
title = "{title}"
description = "{description}"
stat = "{stat}"
target = {target}
hidden = {hidden}
"""


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for ident, title, description, stat, target, hidden in SUCCES:
        path = OUT / f"{ident}.tres"
        path.write_text(MODELE.format(
            id=ident, title=title, description=description,
            stat=stat, target=target,
            hidden="true" if hidden else "false"), encoding="utf-8")
    print(f"{len(SUCCES)} succès écrits dans {OUT}")


if __name__ == "__main__":
    main()
