"""Liste les littéraux affichables des scripts (hors tests) pour bâtir les .po.

Usage : python tools/list_strings.py
"""
import pathlib
import re

LITERAL = re.compile(r'"([^"\n]{2,120})"')
SKIP = {
    "font_color", "font_size", "separation", "text", "modulate:a", "color",
    "panel", "Title", "title", "detail", "name", "levels", "join", "host",
    "cauris", "stars", "streak", "settings", "rescue", "survive", "escort",
    "restart", "leave_level", "prisoner_status", "time_left", "total_time",
    "heal", "damage", "special", "vitalite", "force", "souffle", "sabre",
    "touch_button", "paused", "root", "ui_cancel", "ui_accept",
}
CODE_WORDS = {"res://", "user://", "uid://", "/root/", "%s/%s", "%d:%02d", "%s — %s", " | "}


def main() -> None:
    seen: dict[str, str] = {}
    for path in sorted(pathlib.Path("scripts").rglob("*.gd")):
        if "tests" in path.parts or path.parts[0] == "tools":
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for raw in LITERAL.findall(text):
            value = raw.strip()
            if not re.search(r"[A-Za-z]", value):
                continue
            if value in SKIP or any(w in value for w in CODE_WORDS):
                continue
            if re.fullmatch(r"[a-z_0-9./]+", value):     # identifiants, chemins
                continue
            if value.startswith("res://") or value.startswith("user://"):
                continue
            if len(value) < 4 and not re.search(r"[\u00c0-\u017f]", value):
                continue
            seen.setdefault(value, str(path))
    for value in sorted(seen):
        print(f"{value!r:62} {seen[value]}")
    print(f"TOTAL {len(seen)}")


if __name__ == "__main__":
    main()
