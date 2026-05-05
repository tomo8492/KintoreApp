#!/usr/bin/env python3
"""Generate body-diagram annotation JSONs for every exercise that lacks one.

Loads `WorkoutKit/Resources/exercises_seed.json` (345 exercises) and writes a
file per slug to `WorkoutKit/Resources/BodyAnnotations/<slug>.json`. Existing
files are preserved (they were authored by hand or by `generate_body_annotations.py`).

A categorical classifier (`annotation_classifier.classify`) maps each exercise
to a movement-pattern template defined in:
  - `annotation_strength_templates.py`
  - `annotation_aux_templates.py`

Each template returns `(view, arrows, labels)` keyed by stable annotation `id`s
that resolve to translations via `inject_annotation_strings.py`.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from annotation_classifier import classify  # noqa: E402
from annotation_strength_templates import (  # noqa: E402
    t_squat, t_lunge, t_jump_squat, t_hinge, t_deadlift, t_hip_thrust,
    t_glute_kickback, t_abduction, t_bench_press, t_fly, t_rear_delt,
    t_push_up, t_handstand, t_shoulder_press, t_lateral_raise, t_front_raise,
    t_pulldown, t_pull_up, t_row, t_curl, t_tricep_pushdown,
    t_overhead_extension, t_kickback, t_wrist_curl, t_dead_hang, t_shrug,
    t_calf_raise, t_leg_curl, t_leg_extension, t_back_extension, t_crunch,
    t_leg_raise, t_oblique, t_side_bend, t_pallof, t_plank_hold, t_dead_bug,
    t_bird_dog, t_carry, t_clean, t_thruster, t_swing,
)
from annotation_aux_templates import (  # noqa: E402
    t_warmup_arm, t_warmup_leg, t_warmup_hip, t_warmup_torso, t_warmup_spine,
    t_warmup_full, t_warmup_neck, t_warmup_ankle, t_warmup_wrist,
    t_cardio_full, t_cardio_legs, t_cardio_punch, t_cardio_rope,
    t_stretch_chest, t_stretch_back, t_stretch_lats, t_stretch_lower_back,
    t_stretch_glute, t_stretch_ham, t_stretch_quad, t_stretch_calf,
    t_stretch_shoulder, t_stretch_neck, t_stretch_tricep, t_stretch_bicep,
    t_stretch_forearm, t_stretch_oblique, t_stretch_abs, t_stretch_full,
)

SEED_PATH = ROOT / "WorkoutKit" / "Resources" / "exercises_seed.json"
OUT_DIR   = ROOT / "WorkoutKit" / "Resources" / "BodyAnnotations"

TEMPLATES = {
    # Strength / calisthenics
    "squat":            t_squat,
    "lunge":            t_lunge,
    "jump_squat":       t_jump_squat,
    "hinge":            t_hinge,
    "deadlift":         t_deadlift,
    "hip_thrust":       t_hip_thrust,
    "glute_kickback":   t_glute_kickback,
    "abduction":        t_abduction,
    "bench_press":      t_bench_press,
    "fly":              t_fly,
    "rear_delt":        t_rear_delt,
    "push_up":          t_push_up,
    "handstand":        t_handstand,
    "shoulder_press":   t_shoulder_press,
    "lateral_raise":    t_lateral_raise,
    "front_raise":      t_front_raise,
    "pulldown":         t_pulldown,
    "pull_up":          t_pull_up,
    "row":              t_row,
    "curl":             t_curl,
    "tricep_pushdown":  t_tricep_pushdown,
    "overhead_extension": t_overhead_extension,
    "kickback":         t_kickback,
    "wrist_curl":       t_wrist_curl,
    "dead_hang":        t_dead_hang,
    "shrug":            t_shrug,
    "calf_raise":       t_calf_raise,
    "leg_curl":         t_leg_curl,
    "leg_extension":    t_leg_extension,
    "back_extension":   t_back_extension,
    "crunch":           t_crunch,
    "leg_raise":        t_leg_raise,
    "oblique":          t_oblique,
    "side_bend":        t_side_bend,
    "pallof":           t_pallof,
    "plank_hold":       t_plank_hold,
    "dead_bug":         t_dead_bug,
    "bird_dog":         t_bird_dog,
    "carry":            t_carry,
    "clean":            t_clean,
    "thruster":         t_thruster,
    "swing":            t_swing,
    # Warm-up
    "warmup_arm":   t_warmup_arm,
    "warmup_leg":   t_warmup_leg,
    "warmup_hip":   t_warmup_hip,
    "warmup_torso": t_warmup_torso,
    "warmup_spine": t_warmup_spine,
    "warmup_full":  t_warmup_full,
    "warmup_neck":  t_warmup_neck,
    "warmup_ankle": t_warmup_ankle,
    "warmup_wrist": t_warmup_wrist,
    # Cardio
    "cardio_full":  t_cardio_full,
    "cardio_legs":  t_cardio_legs,
    "cardio_punch": t_cardio_punch,
    "cardio_rope":  t_cardio_rope,
    # Stretching
    "stretch_chest":      t_stretch_chest,
    "stretch_back":       t_stretch_back,
    "stretch_lats":       t_stretch_lats,
    "stretch_lower_back": t_stretch_lower_back,
    "stretch_glute":      t_stretch_glute,
    "stretch_ham":        t_stretch_ham,
    "stretch_quad":       t_stretch_quad,
    "stretch_calf":       t_stretch_calf,
    "stretch_shoulder":   t_stretch_shoulder,
    "stretch_neck":       t_stretch_neck,
    "stretch_tricep":     t_stretch_tricep,
    "stretch_bicep":      t_stretch_bicep,
    "stretch_forearm":    t_stretch_forearm,
    "stretch_oblique":    t_stretch_oblique,
    "stretch_abs":        t_stretch_abs,
    "stretch_full":       t_stretch_full,
}


def existing_slugs() -> set[str]:
    return {p.stem for p in OUT_DIR.glob("*.json")}


def write_annotation(slug: str, view: str, arrows: list, labels: list) -> None:
    payload = {
        "slug": slug,
        "view": view,
        "arrows": arrows,
        "annotations": labels,
    }
    path = OUT_DIR / f"{slug}.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    seed = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    have = existing_slugs()

    written = 0
    skipped = 0
    template_usage: dict[str, int] = {}
    unknown_templates: list[str] = []

    for ex in seed:
        slug = ex["slug"]
        if slug in have:
            skipped += 1
            continue

        template_name = classify(ex)
        factory = TEMPLATES.get(template_name)
        if factory is None:
            unknown_templates.append(f"{slug} -> {template_name}")
            continue

        view, arrows, labels = factory(slug)
        # Dedup labels with the same id (template + override could collide).
        seen = set()
        unique_labels = []
        for lbl in labels:
            if lbl["id"] in seen:
                continue
            seen.add(lbl["id"])
            unique_labels.append(lbl)

        write_annotation(slug, view, arrows, unique_labels)
        written += 1
        template_usage[template_name] = template_usage.get(template_name, 0) + 1

    print(f"wrote {written} new annotation files (skipped {skipped} existing)")
    print(f"total slugs covered: {len(existing_slugs())}")
    if unknown_templates:
        print(f"WARNING: {len(unknown_templates)} unknown templates:")
        for u in unknown_templates[:20]:
            print(f"  - {u}")
    print()
    print("template usage (top 20):")
    for name, count in sorted(template_usage.items(), key=lambda x: -x[1])[:20]:
        print(f"  {name:22s} {count}")
    return 0 if not unknown_templates else 1


if __name__ == "__main__":
    raise SystemExit(main())
