#!/usr/bin/env python3
"""Add explicit `side` field (front/back) to every annotation cue and relocate
back-side dots that were placed on the front-body silhouette.

Why: the 2-row body diagram partitions cues into the front section and back
section. Doing it from `position.x < 0.5` alone is unreliable — many
hand-authored bench-press / squat / deadlift JSONs put back-related cues
("scap", "back" = neutral spine, "lats", "glute"…) at front-body coordinates
because the original templates focused on the front silhouette. Result: the
"後面" section is empty and the user's request "後面に肩甲骨を寄せる" never
shows up.

Fix:
  1. SIDE_BY_ID maps each well-known cue id to the anatomical side it belongs
     to. Per-slug overrides handle context-dependent ids ("hip" in plank is
     back-related, "elbow" for tricep work is back).
  2. BACK_LANDMARK_BY_ID gives the back-body coordinate to relocate to when
     the chosen side disagrees with the original position.
  3. Front-mapped cues that ended up on the back body get relocated symmetrically.

Idempotent: re-running on already-sidified JSON is a no-op (side present and
position consistent with side).

Reads/writes: WorkoutKit/Resources/BodyAnnotations/*.json (in place).
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANNOT_DIR = ROOT / "WorkoutKit" / "Resources" / "BodyAnnotations"

# ---------- Side mapping (default per id) ----------
# Anatomically front-side cues: things visible from the front body silhouette.
FRONT_IDS = {
    "knee", "chest", "abs", "core", "neck", "feet", "touch", "hand",
    "range", "delt", "front", "balance", "press", "drive", "rib",
    "stance", "twist", "flow", "brace", "low", "lean", "dip",
    "rotate", "jump", "land", "rack", "posture", "alignment",
    "upper", "lower", "oblique", "breathe", "tempo", "ankle",
    "wrist", "bicep", "body", "torso", "elbow", "legs", "grip",
    # Default-front but commonly overridden by per-slug rules.
    "hip", "squeeze",
}
# Anatomically back-side cues: scapulae / spine / posterior chain / rear.
BACK_IDS = {
    "scap", "back", "hinge", "lats", "ham", "glute", "rear",
    "trap", "spine", "calf", "shrug", "shoulders",
    # `hip` defaults to front; per-slug overrides put it on back where needed.
}

# ---------- Per-slug overrides (where default doesn't match the cue intent) ----------
SIDE_OVERRIDES: dict[tuple[str, str], str] = {
    # Hip cues that mean "don't sag glutes / drive glutes" → back
    ("plank", "hip"):                ("back"),
    ("side-plank", "hip"):           ("back"),
    ("ab-wheel-rollout", "hip"):     ("back"),
    ("kettlebell-swing", "hip"):     ("back"),
    ("dumbbell-shoulder-press", "core"): ("front"),  # explicit, default already
    # Tricep extension family — elbow cue is on the back of the arm
    ("tricep-pushdown", "elbow"):              ("back"),
    ("overhead-tricep-extension", "elbow"):    ("back"),
    ("skull-crusher", "elbow"):                ("back"),
    ("cable-tricep-rope-pushdown", "elbow"):   ("back"),
    ("kneeling-tricep-pushdown", "elbow"):     ("back"),
    ("single-arm-pushdown", "elbow"):          ("back"),
    ("single-arm-tricep-extension", "elbow"):  ("back"),
    ("dumbbell-tricep-kickback", "elbow"):     ("back"),
    ("lying-tricep-extension", "elbow"):       ("back"),
    ("bench-tricep-extension", "elbow"):       ("back"),
    ("cable-overhead-extension", "elbow"):     ("back"),
    ("tate-press", "elbow"):                   ("back"),
    ("jm-press", "elbow"):                     ("back"),
    # Burpee core stays front (it's about brace, not glutes)
    ("burpee", "core"):              ("front"),
    # Pallof press brace stays front
    ("pallof-press", "brace"):       ("front"),
    # Mountain climber hip stays front
    ("mountain-climber", "hip"):     ("front"),
    # Hip thrust: rib (front) and squeeze (back-glute)
    ("barbell-hip-thrust", "rib"):     ("front"),
    ("dumbbell-hip-thrust", "rib"):    ("front"),
    # Glute bridge / kickback / hip thrust: squeeze id is glute → back
    # (squeeze isn't in BACK_IDS by default because it's used for chest fly too)
    ("barbell-hip-thrust", "squeeze"):       ("back"),
    ("dumbbell-hip-thrust", "squeeze"):      ("back"),
    ("hip-thrust-banded", "squeeze"):        ("back"),
    ("banded-glute-bridge", "squeeze"):      ("back"),
    ("single-leg-glute-bridge", "squeeze"):  ("back"),
    ("glute-bridge", "squeeze"):             ("back"),
    ("frog-pump", "squeeze"):                ("back"),
    ("cable-glute-kickback", "squeeze"):     ("back"),
    ("donkey-kick", "squeeze"):              ("back"),
    ("fire-hydrant", "squeeze"):             ("back"),
    ("clamshell", "squeeze"):                ("back"),
    ("hip-abduction-machine", "squeeze"):    ("back"),
    ("abductor-machine", "squeeze"):         ("back"),
    ("hip-extension-machine", "squeeze"):    ("back"),
    # Back extension: squeeze = glute squeeze
    ("back-extension", "squeeze"):       ("back"),
    ("hyperextension", "squeeze"):       ("back"),
    ("reverse-hyperextension", "squeeze"): ("back"),
    ("good-morning", "squeeze"):         ("back"),
    ("jefferson-curl", "squeeze"):       ("back"),
    ("superman", "squeeze"):             ("back"),
    # Standing calf raise range stays front (it's foot/ankle range visible from front)
    # but conventional view shows calves on back, so back is fine.
    ("standing-calf-raise", "range"):    ("back"),
    ("seated-calf-raise", "range"):      ("back"),
    ("donkey-calf-raise", "range"):      ("back"),
    ("leg-press-calf-raise", "range"):   ("back"),
    ("single-leg-calf-raise", "range"):  ("back"),
    ("smith-machine-calf-raise", "range"): ("back"),
    ("banded-calf-raise", "range"):      ("back"),
}

# ---------- Back-body landmarks for relocation ----------
# When a cue is back-side but its `position` is on the front silhouette
# (x < 0.5), we relocate it to one of these anatomically-accurate back points.
BACK_LANDMARK_BY_ID = {
    "scap":      (0.74, 0.13),  # trap_back
    "back":      (0.79, 0.27),  # lats (mid-back)
    "hinge":     (0.77, 0.42),  # lower_back
    "lats":      (0.79, 0.27),
    "ham":       (0.78, 0.58),
    "glute":     (0.78, 0.46),
    "rear":      (0.71, 0.18),  # shoulder_back
    "trap":      (0.74, 0.13),
    "spine":     (0.79, 0.27),
    "calf":      (0.78, 0.78),
    "shrug":     (0.74, 0.13),
    "shoulders": (0.71, 0.18),
    "hip":       (0.78, 0.46),  # glute when "hip" is back-coded
    "squeeze":   (0.78, 0.46),  # glute squeeze
    "elbow":     (0.83, 0.30),  # tricep
    "range":     (0.78, 0.78),  # for calf raise; default landmark
}

# When a cue is front-side but its `position` is on the back silhouette,
# relocate to the corresponding front landmark.
FRONT_LANDMARK_BY_ID = {
    "knee":   (0.20, 0.66),
    "chest":  (0.22, 0.21),
    "abs":    (0.21, 0.33),
    "core":   (0.21, 0.33),
    "neck":   (0.22, 0.10),
    "feet":   (0.20, 0.78),
    "touch":  (0.22, 0.21),
    "hand":   (0.08, 0.43),
    "range":  (0.22, 0.21),
    "delt":   (0.27, 0.18),
    "front":  (0.27, 0.18),
    "balance":(0.21, 0.33),
    "press":  (0.27, 0.18),
    "drive":  (0.20, 0.55),
    "rib":    (0.22, 0.21),
    "torso":  (0.22, 0.21),
    "elbow":  (0.13, 0.30),
}


def side_for(slug: str, ident: str) -> str | None:
    if (slug, ident) in SIDE_OVERRIDES:
        return SIDE_OVERRIDES[(slug, ident)]
    if ident in BACK_IDS:
        return "back"
    if ident in FRONT_IDS:
        return "front"
    return None


def relocate(cue: dict, side: str) -> bool:
    """Move the dot to the matching silhouette half if it's on the wrong side.

    Returns True iff position was changed.
    """
    pos_x = float(cue["position"]["x"])
    on_front = pos_x < 0.5
    on_back  = pos_x >= 0.5
    ident = cue["id"]
    if side == "back" and on_front:
        new = BACK_LANDMARK_BY_ID.get(ident)
        if new is not None:
            cue["position"] = {"x": float(new[0]), "y": float(new[1])}
            return True
    elif side == "front" and on_back:
        new = FRONT_LANDMARK_BY_ID.get(ident)
        if new is not None:
            cue["position"] = {"x": float(new[0]), "y": float(new[1])}
            return True
    return False


def process(path: Path) -> tuple[bool, int, int]:
    """Returns (changed, side_added_count, relocated_count)."""
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = False
    side_added = 0
    relocated  = 0
    slug = data.get("slug", path.stem)
    for cue in data.get("annotations", []):
        ident = cue.get("id", "")
        if "side" not in cue:
            side = side_for(slug, ident)
            if side is not None:
                cue["side"] = side
                side_added += 1
                changed = True
        side = cue.get("side")
        if side in ("front", "back"):
            if relocate(cue, side):
                relocated += 1
                changed = True

    if changed:
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    return changed, side_added, relocated


def main() -> int:
    files = sorted(ANNOT_DIR.glob("*.json"))
    total_changed = 0
    total_side    = 0
    total_reloc   = 0
    for path in files:
        changed, side, reloc = process(path)
        total_changed += int(changed)
        total_side    += side
        total_reloc   += reloc
    print(f"processed {len(files)} files")
    print(f"  changed: {total_changed}")
    print(f"  cues newly tagged with side: {total_side}")
    print(f"  cues relocated to matching silhouette: {total_reloc}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
