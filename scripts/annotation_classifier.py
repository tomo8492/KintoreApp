"""Classify an exercise into a movement-pattern template.

Inputs come from `WorkoutKit/Resources/exercises_seed.json`:
  - typeRaw            (STRENGTH / CALISTHENICS / WARMUP / CARDIO / STRETCHING)
  - primaryMuscleRaw   (15 muscle groups)
  - mechanicsTypeRaw   (COMPOUND / ISOLATION / null)
  - slug               (kebab-case)

Output: a template name registered in `annotation_registry.TEMPLATES`.

Order of priority (most specific first):
  1. slug-pattern overrides
  2. typeRaw == WARMUP / CARDIO / STRETCHING
  3. STRENGTH / CALISTHENICS by primary muscle + mechanics + slug hint
"""

from __future__ import annotations


_SLUG_OVERRIDES = {
    # Carries
    "dumbbell-farmer-walk": "carry",
    "sandbag-carry":        "carry",
    "bear-crawl":           "carry",
    "crab-walk":            "carry",
    # Olympic / explosive
    "clean-and-press":   "clean",
    "hang-clean":        "clean",
    "power-clean":       "clean",
    "dumbbell-thruster": "thruster",
    # Pallof press
    "pallof-press": "pallof",
    # Dead-bug + bird-dog (warmup / hold)
    "dead-bug": "dead_bug",
    "bird-dog": "bird_dog",
    # Hangs / static holds
    "dead-hang":         "dead_hang",
    "plate-pinch":       "dead_hang",
    "wrist-roller":      "wrist_curl",
    "wall-sit-quad":     "plank_hold",
    "hollow-body-hold":  "plank_hold",
    "l-sit":             "plank_hold",
    "handstand-hold":    "handstand",
    "glute-bridge-hold": "plank_hold",
    "plank-hold":        "plank_hold",
    # Specific warm-ups that don't fit primary-muscle table
    "scapular-pull-up":   "warmup_spine",
    "scapular-push-up":   "warmup_spine",
    "inchworm-walkout":   "warmup_full",
    "world-greatest-stretch": "warmup_full",
    "spider-lunge":       "warmup_hip",
    "monster-walk":       "warmup_hip",
    "band-pull-apart":    "warmup_arm",
    # Cardio specials
    "battle-ropes":       "cardio_punch",
    "shadow-boxing":      "cardio_punch",
    "heavy-bag-boxing":   "cardio_punch",
    "swimming-breaststroke": "cardio_full",
    "swimming-freestyle":    "cardio_full",
    "ski-erg":               "cardio_full",
    "rowing-machine":        "cardio_full",
    "jump-rope":             "cardio_rope",
    # Specific stretches that need explicit routing
    "cobra-to-down-dog": "stretch_full",
    "world-greatest-stretch-static": "stretch_full",
    "downward-dog-pedal":   "stretch_calf",
    "knee-to-wall-mobility": "stretch_calf",
    "soleus-stretch":        "stretch_calf",
    "sphinx-pose":           "stretch_abs",
    "standing-abdominal-stretch": "stretch_abs",
    # Misc
    "kettlebell-rdl":         "deadlift",
    "single-leg-rdl":         "deadlift",
    "dumbbell-romanian-deadlift": "deadlift",
    "deficit-deadlift":       "deadlift",
    "snatch-grip-deadlift":   "deadlift",
    "rack-pull":              "deadlift",
    "good-morning":           "back_extension",
    "jefferson-curl":         "back_extension",
    "reverse-hyperextension": "back_extension",
    "hyperextension":         "back_extension",
    "back-extension":         "back_extension",
    "superman":               "back_extension",
    "suitcase-deadlift":      "deadlift",
    "dragon-flag":            "leg_raise",
    "v-up":                   "leg_raise",
    "windshield-wipers":      "oblique",
    # Triceps that are compound bench-press-like
    "close-grip-bench-press": "bench_press",
    "tricep-dip-bench":       "push_up",
    "diamond-push-up":        "push_up",
    # Glute compound
    "cossack-squat":      "lunge",
    "lateral-lunge":      "lunge",
    "curtsy-lunge":       "lunge",
    "reverse-lunge":      "lunge",
    "dynamic-lunge":      "lunge",
    "pistol-squat":       "squat",
    # Jumps / explosive
    "squat-jump":     "jump_squat",
    "tuck-jump":      "jump_squat",
    "broad-jump":     "jump_squat",
    # Sit-ups / crunches
    "sit-up":             "crunch",
    "decline-sit-up":     "crunch",
    "weighted-crunch":    "crunch",
    "cable-crunch":       "crunch",
    "reverse-crunch":     "leg_raise",
    "bicycle-crunch":     "oblique",
    "side-crunch":        "oblique",
    "lateral-leg-raise":  "oblique",
    "leg-raise":          "leg_raise",
    "hanging-leg-raise":  "leg_raise",
    "hanging-knee-raise": "leg_raise",
    # Side bend → side_bend template
    "dumbbell-side-bend":  "side_bend",
    "weighted-side-bend":  "side_bend",
    "standing-side-bend":  "side_bend",
    "cable-woodchopper":   "oblique",
    # Shrug-like
    "y-raise":             "rear_delt",
    # Rear-delt isolation
    "cable-rear-delt-fly":  "rear_delt",
    "machine-rear-delt-fly": "rear_delt",
    "reverse-pec-deck":      "rear_delt",
    "single-arm-cable-rear-fly": "rear_delt",
    # Kickback (tricep)
    "dumbbell-tricep-kickback": "kickback",
    # Glute kickback / abduction
    "cable-glute-kickback": "glute_kickback",
    "donkey-kick":          "glute_kickback",
    "fire-hydrant":         "abduction",
    "clamshell":            "abduction",
    "hip-abduction-machine": "abduction",
    "abductor-machine":     "abduction",
    "hip-extension-machine": "glute_kickback",
    # Pull-through is hinge with cable
    "cable-pull-through":   "hinge",
    # Frog pump = hip thrust
    "frog-pump":             "hip_thrust",
    "single-leg-glute-bridge": "hip_thrust",
    "banded-glute-bridge":   "hip_thrust",
    "hip-thrust-banded":     "hip_thrust",
    "dumbbell-hip-thrust":   "hip_thrust",
}


_STRETCH_BY_MUSCLE = {
    "chest":      "stretch_chest",
    "lats":       "stretch_lats",
    "lowerBack":  "stretch_lower_back",
    "glutes":     "stretch_glute",
    "hamstrings": "stretch_ham",
    "quadriceps": "stretch_quad",
    "calves":     "stretch_calf",
    "deltoids":   "stretch_shoulder",
    "traps":      "stretch_neck",
    "triceps":    "stretch_tricep",
    "biceps":     "stretch_bicep",
    "forearms":   "stretch_forearm",
    "obliques":   "stretch_oblique",
    "abs":        "stretch_abs",
    "fullBody":   "stretch_full",
}


_WARMUP_BY_MUSCLE = {
    "deltoids":   "warmup_arm",
    "hamstrings": "warmup_leg",
    "quadriceps": "warmup_leg",
    "glutes":     "warmup_hip",
    "obliques":   "warmup_torso",
    "lowerBack":  "warmup_spine",
    "fullBody":   "warmup_full",
    "traps":      "warmup_neck",
    "calves":     "warmup_ankle",
    "forearms":   "warmup_wrist",
    "lats":       "warmup_spine",
    "abs":        "warmup_full",
    "chest":      "warmup_arm",
    "biceps":     "warmup_arm",
    "triceps":    "warmup_arm",
}


_CARDIO_BY_MUSCLE = {
    "fullBody":   "cardio_full",
    "deltoids":   "cardio_punch",
    "lats":       "cardio_full",
    "quadriceps": "cardio_legs",
    "hamstrings": "cardio_legs",
    "calves":     "cardio_rope",
    "chest":      "cardio_full",
    "glutes":     "cardio_legs",
}


def _classify_strength(slug: str, primary: str, mech: str | None) -> str:
    """Classify STRENGTH or CALISTHENICS by primary muscle + slug hints."""
    s = slug

    # Slug-pattern hints first
    if "shrug" in s:
        return "shrug"
    if "calf-raise" in s or s.endswith("calf-raise"):
        return "calf_raise"
    if "fly" in s or "pec-deck" in s:
        return "fly"
    if "lateral-raise" in s:
        return "lateral_raise"
    if "front-raise" in s or "plate-front" in s:
        return "front_raise"
    if "rear-delt" in s or s.endswith("rear-fly"):
        return "rear_delt"
    if "pulldown" in s or "pullover" in s:
        return "pulldown"
    if "pull-up" in s or s.endswith("-pull-up") or s == "pull-up" or s == "weighted-pull-up":
        return "pull_up"
    if s.endswith("-row") or "-row-" in s or s in {"meadows-row", "pendlay-row", "seal-row", "landmine-row", "chest-supported-row"}:
        return "row"
    if "wrist-curl" in s or "reverse-wrist" in s:
        return "wrist_curl"
    if "wrist-roller" in s:
        return "wrist_curl"
    if "reverse-barbell-curl" in s:
        return "curl"
    if s.endswith("-curl") or "curl" in s:
        if primary == "hamstrings":
            return "leg_curl"
        if primary == "biceps":
            return "curl"
        if primary == "forearms":
            return "wrist_curl"
        if primary == "abs":
            return "crunch"
    if "extension" in s or "skull-crusher" in s or "tate-press" in s or "jm-press" in s:
        if primary == "quadriceps":
            return "leg_extension"
        if primary == "lowerBack":
            return "back_extension"
        if primary == "triceps":
            if "overhead" in s or "lying" in s or "bench" in s:
                return "overhead_extension"
            return "tricep_pushdown"
    if "pushdown" in s:
        return "tricep_pushdown"
    if "bench-press" in s:
        return "bench_press"
    if "press" in s and primary == "chest":
        return "bench_press"
    if "press" in s and primary in ("deltoids", "fullBody"):
        return "shoulder_press"
    if "press" in s and primary == "triceps":
        return "tricep_pushdown"
    if "push-up" in s or "push-up" == s:
        return "push_up"
    if "deadlift" in s:
        return "deadlift"
    if "squat" in s:
        return "squat"
    if "lunge" in s or "step-up" in s:
        return "lunge"
    if "swing" in s:
        return "swing"
    if "shrug" in s:
        return "shrug"

    # Fall back to primary muscle
    by_primary = {
        "quadriceps": "squat" if mech == "COMPOUND" else "leg_extension",
        "glutes":     "hip_thrust" if mech == "COMPOUND" else "glute_kickback",
        "hamstrings": "deadlift" if mech == "COMPOUND" else "leg_curl",
        "calves":     "calf_raise",
        "chest":      "bench_press" if mech == "COMPOUND" else "fly",
        "lats":       "pull_up" if mech == "COMPOUND" else "pulldown",
        "lowerBack":  "back_extension",
        "traps":      "shrug",
        "deltoids":   "shoulder_press" if mech == "COMPOUND" else "lateral_raise",
        "biceps":     "curl",
        "triceps":    "tricep_pushdown",
        "forearms":   "wrist_curl",
        "abs":        "crunch",
        "obliques":   "oblique",
        "fullBody":   "carry",
    }
    return by_primary.get(primary, "squat")


def classify(exercise: dict) -> str:
    slug = exercise["slug"]
    if slug in _SLUG_OVERRIDES:
        return _SLUG_OVERRIDES[slug]

    type_raw = exercise.get("typeRaw")
    primary = exercise.get("primaryMuscleRaw") or "fullBody"
    mech = exercise.get("mechanicsTypeRaw")

    if type_raw == "WARMUP":
        return _WARMUP_BY_MUSCLE.get(primary, "warmup_full")
    if type_raw == "CARDIO":
        return _CARDIO_BY_MUSCLE.get(primary, "cardio_full")
    if type_raw == "STRETCHING":
        return _STRETCH_BY_MUSCLE.get(primary, "stretch_full")

    return _classify_strength(slug, primary, mech)
