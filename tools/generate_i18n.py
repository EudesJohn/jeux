"""Génère les fichiers .po de `assets/i18n/` (DESIGN.md § 24).

Le français est la langue source : la clé d'un texte EST le texte français,
ce qui évite de réécrire tous les écrans. Un texte sans traduction reste
affiché en français, jamais vide.

    python tools/generate_i18n.py          # écrit fr.po, en.po, fon.po

Pour ajouter une langue : compléter `FON` / créer un dictionnaire du même
genre, puis l'ajouter à `FON`-like et à `LANGS`.
"""
import pathlib
import re

OUT_DIR = pathlib.Path("assets/i18n")

# (français, anglais) — l'ordre suit les écrans du jeu.
TEXTES = [
    # ---------------------------------------------------------------- menu
    ("GUERRIÈRE D'ABOMEY", "WARRIOR OF ABOMEY"),
    ("Libère les prisonniers. Traverse le royaume.",
     "Free the prisoners. Cross the kingdom."),
    ("Jouer", "Play"),
    ("Coop WiFi", "Wi-Fi co-op"),
    ("2 joueuses sur le même WiFi local (hotspot ou box).",
     "2 players on the same local Wi-Fi (hotspot or router)."),
    ("Armurerie", "Armoury"),
    ("Réglages", "Settings"),
    ("Quitter", "Quit"),
    ("Niveaux PHASE 3", "Phase 3 levels"),
    ("Sauvetage PHASE 4", "Phase 4 rescue"),
    ("Arène PHASE 2", "Phase 2 arena"),
    ("Réglage", "Balance test"),
    ("Combat PHASE 1", "Phase 1 combat"),
    # -------------------------------------------------------- choix du mode
    ("CHOISIR UN MODE", "CHOOSE A MODE"),
    ("Aventure", "Adventure"),
    ("5 chapitres, 25 niveaux, la carte du royaume et ses étoiles.",
     "5 chapters, 25 levels, the kingdom map and its stars."),
    ("Sauvetage", "Rescue"),
    ("17 niveaux + une escorte : libérer les prisonniers avant le temps.",
     "17 levels + an escort: free the prisoners before time runs out."),
    ("Survie", "Survival"),
    ("Vagues sans fin, un bonus entre chaque vague — record : %d.",
     "Endless waves, a bonus between each wave — record: %d."),
    ("Chasse aux boss", "Boss hunt"),
    ("%d gardien(s) débloqué(s) : les enchaîner, sans pause.",
     "%d guardian(s) unlocked: chain them, no pause."),
    ("Défi du jour", "Daily challenge"),
    ("Défi du jour — %s", "Daily challenge — %s"),
    ("— série : %d jour(s).", "— streak: %d day(s)."),
    ("Arène d'entraînement", "Training arena"),
    ("Mannequins, verrouillage et garde parfaite — pour sentir le combat.",
     "Dummies, lock-on and perfect guard — to feel the combat."),
    ("Disponible dans une prochaine phase.", "Coming in a later phase."),
    # ------------------------------------------------------- carte du royaume
    ("CARTE DU ROYAUME", "KINGDOM MAP"),
    ("CHAPITRE %d — %s", "CHAPTER %d — %s"),
    ("CHAPITRE %d — NIVEAU %d", "CHAPTER %d — LEVEL %d"),
    ("Chapitre %d", "Chapter %d"),
    ("CAURIS %d", "COWRIES %d"),
    ("JOUER", "PLAY"),
    ("Libérer les prisonniers", "Free the prisoners"),
    ("Vaincre le gardien", "Defeat the guardian"),
    ("Vaincre le boss", "Defeat the boss"),
    ("Vaincre toutes les vagues", "Defeat all waves"),
    ("Escorter le villageois", "Escort the villager"),
    ("Atteindre la sortie", "Reach the exit"),
    ("Choisis un niveau sur la carte.", "Pick a level on the map."),
    ("Les collines d'Abomey", "The hills of Abomey"),
    ("La route du sel", "The salt road"),
    ("La forêt sacrée", "The sacred forest"),
    ("Les remparts de nuit", "The night ramparts"),
    ("Le palais du roi", "The king's palace"),
    # ------------------------------------------------------------- sauvetage
    ("SAUVETAGE", "RESCUE"),
    ("OBJECTIF VERROUILLÉ", "OBJECTIVE LOCKED"),
    ("ESCORTE", "ESCORT"),
    ("%d prisonnier%s", "%d prisoner%s"),
    ("%d villageois", "%d villager(s)"),
    ("· NUIT", "· NIGHT"),
    # -------------------------------------------------------------- armurerie
    ("ARMURERIE", "ARMOURY"),
    ("Améliorations permanentes : elles s'appliquent à chaque niveau.",
     "Permanent upgrades: they apply to every level."),
    ("Acheter", "Buy"),
    ("Retour au menu", "Back to menu"),
    ("Cette amélioration est déjà au maximum.",
     "This upgrade is already maxed out."),
    ("Pas assez de cauris (il en manque %d).",
     "Not enough cowries (missing %d)."),
    ("%s améliorée — niveau %d !", "%s upgraded — level %d!"),
    ("%d cauris", "%d cowries"),
    ("Niveau %d / %d  %s", "Level %d / %d  %s"),
    ("Vitalité", "Vitality"),
    ("Force", "Might"),
    ("Souffle", "Breath"),
    ("+10 vie maximale par niveau", "+10 max health per level"),
    ("+8 % de dégâts par niveau", "+8% damage per level"),
    ("+20 énergie au départ par niveau", "+20 starting energy per level"),
    # --------------------------------------------------------------- réglages
    ("RÉGLAGES", "SETTINGS"),
    ("Musique", "Music"),
    ("Effets", "Effects"),
    ("Voix", "Voice"),
    ("Taille des boutons", "Button size"),
    ("Opacité des boutons", "Button opacity"),
    ("Échelle 3D", "3D scale"),
    ("Difficulté", "Difficulty"),
    ("Facile", "Easy"),
    ("Normal", "Normal"),
    ("Difficile", "Hard"),
    ("Qualité graphique", "Graphics quality"),
    ("Faible", "Low"),
    ("Moyenne", "Medium"),
    ("Haute", "High"),
    ("Langue", "Language"),
    ("Vibration", "Vibration"),
    ("Retour", "Back"),
    # ------------------------------------------------------------------ pause
    ("PAUSE", "PAUSED"),
    ("Reprendre", "Resume"),
    ("Recommencer", "Restart"),
    ("Quitter le niveau", "Leave level"),
    # ---------------------------------------------------------------- résultat
    ("CONTINUER", "CONTINUE"),
    ("REJOUER", "REPLAY"),
    ("MENU", "MENU"),
    ("ÉCHEC", "FAILED"),
    ("NIVEAU TERMINÉ", "LEVEL COMPLETE"),
    ("tu es tombée au combat", "you fell in battle"),
    ("un prisonnier est mort", "a prisoner died"),
    ("le villageois est mort", "the villager died"),
    ("temps écoulé", "time is up"),
    ("objectif manqué", "objective missed"),
    ("%s      %s restantes      +%d cauris", "%s      %s left      +%d cowries"),
    ("%d vague(s) — record %d%s", "%d wave(s) — record %d%s"),
    ("(NOUVEAU !)", "(NEW!)"),
    ("BONUS : %s", "BONUS: %s"),
    # -------------------------------------------------------------------- HUD
    ("VIE %d / %d      ÉNERGIE %d / %d", "HEALTH %d / %d      ENERGY %d / %d"),
    ("PRISONNIERS %d/%d", "PRISONERS %d/%d"),
    ("GARDIEN : %s", "GUARDIAN: %s"),
    ("GARDE PARFAITE !", "PERFECT GUARD!"),
    ("ESQUIVE PARFAITE !", "PERFECT DODGE!"),
    ("GARDE BRISÉE", "GUARD BROKEN"),
    ("SPÉCIAL PRÊT", "SPECIAL READY"),
    ("VAGUE %d REPOUSSÉE — CHOISIR UN BONUS", "WAVE %d REPELLED — CHOOSE A BONUS"),
    ("SOIN", "HEAL"),
    ("ÉNERGIE", "ENERGY"),
    ("FORCE", "MIGHT"),
    ("+40 % de vie", "+40% health"),
    ("+15 % de dégâts", "+15% damage"),
    ("Spécial rechargé", "Special recharged"),
    # ---------------------------------------------------------------- objectifs
    ("Libérer les prisonniers (%d/%d)", "Free the prisoners (%d/%d)"),
    ("Escorter le villageois jusqu'à la sortie (%d/%d)",
     "Escort the villager to the exit (%d/%d)"),
    ("Éliminer tous les ennemis (%d / %d vagues)",
     "Defeat every enemy (%d / %d waves)"),
    ("Survie — vague %d", "Survival — wave %d"),
    ("Tenir jusqu'à la fin du temps", "Hold out until time runs out"),
    ("Villageois perdu", "Villager lost"),
    # ------------------------------------------------------------------- coop
    ("COOP WIFI — 2 JOUEUSES", "WI-FI CO-OP — 2 PLAYERS"),
    ("Héberger une partie", "Host a game"),
    ("Rejoindre une partie", "Join a game"),
    ("Se connecter", "Connect"),
    ("Commencer", "Start"),
    ("IP de l'hôte (ex. 192.168.43.1)", "Host IP (e.g. 192.168.43.1)"),
    ("Recherche des parties sur le réseau… (ou tape l'IP de l'hôte)",
     "Searching for games… (or type the host IP)"),
    ("En attente d'une joueuse…", "Waiting for a player…"),
    ("Connectée", "Connected"),
    ("Aucune partie détectée. Tape l'IP affichée sur l'autre téléphone.",
     "No game detected. Type the IP shown on the other phone."),
    ("Connexion impossible. Vérifie que les deux téléphones sont sur le",
     "Connection failed. Check that both phones are on the"),
    ("MÊME réseau (le plus simple : le hotspot d'un des deux) et que l'IP est bonne.",
     "SAME network (simplest: one phone's hotspot) and that the IP is right."),
    ("Un seul réseau WiFi : la box, ou le hotspot de l'un des deux téléphones.",
     "One Wi-Fi network: the router, or one phone's hotspot."),
    ("La joueuse est partie. En attente…", "The other player left. Waiting…"),
    ("Joueuse %d connectée — prêt.", "Player %d connected — ready."),
    ("Joueuse %d à terre — %d s pour la relever !",
     "Player %d is down — %d s to revive her!"),
    ("Joueuse %d relevée.", "Player %d revived."),
    ("Joueuse %d a quitté la partie — tu continues en solo.",
     "Player %d left the game — you continue solo."),
    ("Arène coop", "Co-op arena"),
    ("Couloir coop", "Co-op corridor"),
    ("Niveau : %s", "Level: %s"),
    ("Niveau : Couloir coop", "Level: Co-op corridor"),
    ("Joueuse %s", "Player %s"),
    # ------------------------------------------------ auto-adaptation (§ 25)
    ("Le jeu ralentit (%d images/s). Passer en qualité %s ?",
     "The game is slowing down (%d fps). Switch to %s quality?"),
    ("Oui, alléger", "Yes, lighten it"),
    ("Non", "No"),
    # ------------------------------------------- objectifs journaliers et succès
    ("BUTS DU JOUR", "TODAY'S GOALS"),
    ("Récompense : %d cauris", "Reward: %d cowries"),
    ("Vaincre %d ennemis aujourd'hui.", "Defeat %d enemies today."),
    ("Réussir %d gardes parfaites aujourd'hui.", "Land %d perfect guards today."),
    ("Libérer %d prisonniers aujourd'hui.", "Free %d prisoners today."),
    ("Terminer %d niveau(x) aujourd'hui.", "Finish %d level(s) today."),
    ("Tenir %d vagues en Survie aujourd'hui.", "Hold %d Survival waves today."),
    ("Succès", "Achievements"),
    ("SUCCÈS", "ACHIEVEMENTS"),
    ("SUCCÈS : %s", "ACHIEVEMENT: %s"),
    ("Succès débloqués", "Achievements unlocked"),
    ("Verrouillé", "Locked"),
    ("Aucun succès pour le moment : joue un niveau !",
     "No achievement yet: play a level!"),
    # ------------------------------------------------------ modificateurs du jour
    ("dégâts ennemis doublés", "enemy damage doubled"),
    ("ennemis rapides", "fast enemies"),
    ("une seule vie", "single life"),
    ("réanimation", "revive"),
]

# Fon : le relu par un locuteur natif n'a pas encore eu lieu (§ 24). Les
# entrées absentes gardent le français, jamais une case vide.
FON = {
    "Jouer": "Da wǔ",
    "Quitter": "Sín",
    "Musique": "Wè",
    "Effets": "Súsú",
    "Voix": "Kpanle",
    "Retour": "Lɛ̌kɔ́",
    "Oui": "Ɛɛn",
    "Non": "Eǒ",
    "Sauvetage": "Hùnmɛ́",
    "Survie": "Nɔ̀ gbɔ̀n",
    "Aventure": "Kpéé",
    "Force": "Sè",
}

LANGS = {
    "fr": "Français (langue source)",
    "en": "English",
    "fon": "Fon (à relire par un locuteur natif)",
}


def po_quote(text: str) -> str:
    """Échappe une chaîne pour un fichier .po (une seule ligne)."""
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_po(locale: str, pairs: list[tuple[str, str]], untranslated: bool) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: Guerriere d\'Abomey 1.0\\n"',
        f'"Language: {locale}\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
    ]
    for source, target in pairs:
        lines.append("")
        if untranslated and target == source:
            lines.append("#. À TRADUIRE : relu par un locuteur natif du fon (§ 24)")
        lines.append("#: " + source[:60].replace("\n", " "))
        lines.append("msgid " + po_quote(source))
        lines.append("msgstr " + po_quote(target))
    path = OUT_DIR / f"{locale}.po"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    fr = [(source, source) for source, _ in TEXTES]
    en = list(TEXTES)
    fon = [(source, FON.get(source, source)) for source, _ in TEXTES]
    write_po("fr", fr, untranslated=False)
    write_po("en", en, untranslated=False)
    write_po("fon", fon, untranslated=True)
    for locale, name in LANGS.items():
        total = len(fon)
        done = sum(1 for s, t in (fon if locale == "fon" else en) if s != t or locale == "fr")
        print(f"{locale}.po : {total} entrées ({name})"
              + (f" — {done} traduites, {total - done} à relire" if locale == "fon" else ""))


if __name__ == "__main__":
    main()
