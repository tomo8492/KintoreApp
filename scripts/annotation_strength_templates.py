"""Strength + calisthenics movement-pattern templates."""

from __future__ import annotations

from annotation_constants import (
    LANDMARK, LEFT_TOP, LEFT_MID, LEFT_LOW, LEFT_VLOW,
    RIGHT_TOP, RIGHT_MID, RIGHT_LOW, RIGHT_VLOW,
    arrow, label, offset,
)


def t_squat(slug):
    return ("front", [
        arrow("hip-down", LANDMARK["hip"], offset(LANDMARK["hip"], dy=0.10), color="primary"),
    ], [
        label("knee", LANDMARK["knee"], LEFT_LOW, slug, color="info"),
        label("torso", LANDMARK["chest"], RIGHT_TOP, slug, color="success"),
        label("hip", LANDMARK["hip"], LEFT_MID, slug, color="info"),
    ])


def t_lunge(slug):
    return ("front", [
        arrow("step-down", LANDMARK["hip"], offset(LANDMARK["hip"], dx=-0.05, dy=0.08), color="primary", curve="curved"),
    ], [
        label("knee", LANDMARK["knee"], LEFT_LOW, slug, color="info"),
        label("torso", LANDMARK["chest"], RIGHT_TOP, slug, color="success"),
        label("balance", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_jump_squat(slug):
    return ("front", [
        arrow("jump", offset(LANDMARK["hip"], dy=0.06), offset(LANDMARK["chest"], dy=-0.06), color="primary"),
    ], [
        label("drive", LANDMARK["quad"], LEFT_MID, slug, color="primary"),
        label("land", LANDMARK["knee"], LEFT_LOW, slug, color="warning"),
    ])


def t_hinge(slug):
    return ("front", [
        arrow("hip-back", LANDMARK["hip"], offset(LANDMARK["hip"], dx=0.04, dy=0.04), color="primary", curve="curved"),
    ], [
        label("hinge", LANDMARK["hip"], LEFT_MID, slug, color="primary"),
        label("back", LANDMARK["chest"], RIGHT_TOP, slug, color="success"),
        label("ham", LANDMARK["quad"], RIGHT_MID, slug, color="info"),
    ])


def t_deadlift(slug):
    return ("front", [
        arrow("hip-up", offset(LANDMARK["hip"], dy=0.05), LANDMARK["hip"], color="primary"),
    ], [
        label("back", LANDMARK["chest"], RIGHT_TOP, slug, color="success"),
        label("hinge", LANDMARK["hip"], LEFT_MID, slug, color="primary"),
        label("legs", LANDMARK["quad"], RIGHT_MID, slug, color="info"),
    ])


def t_hip_thrust(slug):
    return ("front", [
        arrow("up", offset(LANDMARK["hip"], dy=0.04), LANDMARK["hip"], color="primary"),
    ], [
        label("squeeze", LANDMARK["hip"], LEFT_MID, slug, color="primary"),
        label("rib", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_glute_kickback(slug):
    return ("back", [
        arrow("kick", offset(LANDMARK["ham"], dy=0.05), LANDMARK["glute"], color="primary", curve="curved"),
    ], [
        label("squeeze", LANDMARK["glute"], RIGHT_MID, slug, color="primary"),
        label("core", offset(LANDMARK["lower_back"], dy=-0.04), RIGHT_TOP, slug, color="info"),
    ])


def t_abduction(slug):
    return ("back", [
        arrow("kick", LANDMARK["glute"], offset(LANDMARK["glute"], dx=0.06), color="primary", curve="curved"),
    ], [
        label("squeeze", LANDMARK["glute"], RIGHT_MID, slug, color="primary"),
        label("torso", LANDMARK["lower_back"], RIGHT_TOP, slug, color="info"),
    ])


def t_bench_press(slug):
    return ("front", [
        arrow("press-up", offset(LANDMARK["chest"], dy=0.05), LANDMARK["chest"], color="primary"),
    ], [
        label("scap", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="info"),
        label("range", LANDMARK["chest"], RIGHT_TOP, slug, color="primary"),
        label("feet", LANDMARK["shin"], LEFT_LOW, slug, color="success"),
    ])


def t_fly(slug):
    return ("front", [
        arrow("close", offset(LANDMARK["shoulder_front"], dx=-0.05, dy=0.06), LANDMARK["chest"], color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["biceps"], LEFT_MID, slug, color="info"),
        label("squeeze", LANDMARK["chest"], RIGHT_TOP, slug, color="primary"),
    ])


def t_rear_delt(slug):
    return ("back", [
        arrow("open", LANDMARK["lats"], offset(LANDMARK["shoulder_back"], dx=0.05), color="primary", curve="curved"),
    ], [
        label("rear", LANDMARK["shoulder_back"], RIGHT_TOP, slug, color="primary"),
        label("scap", LANDMARK["trap_back"], RIGHT_MID, slug, color="info"),
    ])


def t_push_up(slug):
    return ("front", [
        arrow("descend", LANDMARK["chest"], offset(LANDMARK["chest"], dy=0.10), color="primary"),
    ], [
        label("body", LANDMARK["abs"], RIGHT_MID, slug, color="success"),
        label("hand", LANDMARK["wrist"], LEFT_MID, slug, color="info"),
        label("core", LANDMARK["abs"], RIGHT_LOW, slug, color="info"),
    ])


def t_handstand(slug):
    return ("front", [
        arrow("press-up", LANDMARK["shoulder_front"], offset(LANDMARK["shoulder_front"], dy=-0.10), color="primary"),
    ], [
        label("press", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="primary"),
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
        label("alignment", LANDMARK["hip"], RIGHT_LOW, slug, color="success"),
    ])


def t_shoulder_press(slug):
    return ("front", [
        arrow("press-up", LANDMARK["shoulder_front"], offset(LANDMARK["shoulder_front"], dy=-0.10), color="primary"),
    ], [
        label("press", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="primary"),
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_lateral_raise(slug):
    return ("front", [
        arrow("raise", LANDMARK["forearm"], offset(LANDMARK["forearm"], dx=-0.05, dy=-0.20), color="primary", curve="curved"),
    ], [
        label("delt", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="primary"),
        label("trap", LANDMARK["trap_back"], RIGHT_TOP, slug, color="warning"),
    ])


def t_front_raise(slug):
    return ("front", [
        arrow("raise", LANDMARK["forearm"], offset(LANDMARK["forearm"], dx=0.04, dy=-0.20), color="primary", curve="curved"),
    ], [
        label("front", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="primary"),
    ])


def t_pulldown(slug):
    return ("back", [
        arrow("pull-down", offset(LANDMARK["lats"], dy=-0.10), LANDMARK["lats"], color="primary"),
    ], [
        label("lats", LANDMARK["lats"], LEFT_MID, slug, color="primary"),
        label("torso", LANDMARK["lower_back"], RIGHT_MID, slug, color="success"),
    ])


def t_pull_up(slug):
    return ("back", [
        arrow("up", LANDMARK["lats"], offset(LANDMARK["lats"], dy=-0.08), color="primary"),
    ], [
        label("scap", LANDMARK["trap_back"], RIGHT_TOP, slug, color="info"),
        label("lats", LANDMARK["lats"], LEFT_MID, slug, color="primary"),
    ])


def t_row(slug):
    return ("back", [
        arrow("pull", offset(LANDMARK["lats"], dy=0.04), LANDMARK["lats"], color="primary"),
    ], [
        label("scap", LANDMARK["trap_back"], RIGHT_TOP, slug, color="primary"),
        label("hinge", LANDMARK["lower_back"], RIGHT_MID, slug, color="info"),
    ])


def t_curl(slug):
    return ("front", [
        arrow("curl", LANDMARK["forearm"], LANDMARK["biceps"], color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["biceps"], LEFT_MID, slug, color="info"),
        label("torso", LANDMARK["chest"], RIGHT_TOP, slug, color="success"),
    ])


def t_tricep_pushdown(slug):
    return ("back", [
        arrow("press", offset(LANDMARK["triceps"], dx=-0.05), offset(LANDMARK["triceps"], dx=-0.05, dy=0.10), color="primary"),
    ], [
        label("elbow", LANDMARK["triceps"], LEFT_MID, slug, color="info"),
        label("range", LANDMARK["triceps"], RIGHT_MID, slug, color="primary"),
    ])


def t_overhead_extension(slug):
    return ("back", [
        arrow("extend", offset(LANDMARK["triceps"], dy=0.04), offset(LANDMARK["triceps"], dy=-0.06), color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["triceps"], LEFT_MID, slug, color="primary"),
        label("range", LANDMARK["shoulder_back"], RIGHT_TOP, slug, color="info"),
    ])


def t_kickback(slug):
    return ("back", [
        arrow("extend", LANDMARK["triceps"], offset(LANDMARK["triceps"], dx=0.05, dy=0.08), color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["triceps"], LEFT_MID, slug, color="warning"),
        label("hinge", LANDMARK["lower_back"], RIGHT_MID, slug, color="info"),
    ])


def t_wrist_curl(slug):
    return ("front", [
        arrow("curl", offset(LANDMARK["wrist"], dy=0.02), LANDMARK["wrist"], color="primary", curve="curved"),
    ], [
        label("grip", LANDMARK["forearm"], LEFT_LOW, slug, color="primary"),
    ])


def t_dead_hang(slug):
    return ("front", [], [
        label("grip", LANDMARK["wrist"], LEFT_TOP, slug, color="primary"),
        label("scap", LANDMARK["shoulder_front"], LEFT_MID, slug, color="info"),
    ])


def t_shrug(slug):
    return ("back", [
        arrow("up", offset(LANDMARK["trap_back"], dy=0.06), LANDMARK["trap_back"], color="primary"),
    ], [
        label("trap", LANDMARK["trap_back"], RIGHT_TOP, slug, color="primary"),
        label("neck", LANDMARK["neck_back"], LEFT_TOP, slug, color="info"),
    ])


def t_calf_raise(slug):
    return ("back", [
        arrow("up", offset(LANDMARK["calf"], dy=0.06), LANDMARK["calf"], color="primary"),
    ], [
        label("range", LANDMARK["calf"], RIGHT_VLOW, slug, color="primary"),
    ])


def t_leg_curl(slug):
    return ("back", [
        arrow("curl", LANDMARK["calf"], LANDMARK["ham"], color="primary", curve="curved"),
    ], [
        label("ham", LANDMARK["ham"], LEFT_LOW, slug, color="primary"),
        label("hip", LANDMARK["glute"], RIGHT_MID, slug, color="info"),
    ])


def t_leg_extension(slug):
    return ("front", [
        arrow("extend", offset(LANDMARK["shin"], dy=0.06), LANDMARK["shin"], color="primary", curve="curved"),
    ], [
        label("knee", LANDMARK["knee"], LEFT_LOW, slug, color="info"),
        label("hip", LANDMARK["hip"], RIGHT_MID, slug, color="success"),
    ])


def t_back_extension(slug):
    return ("back", [
        arrow("extend", offset(LANDMARK["lower_back"], dy=0.06), LANDMARK["lower_back"], color="primary", curve="curved"),
    ], [
        label("hinge", LANDMARK["lower_back"], RIGHT_MID, slug, color="primary"),
        label("squeeze", LANDMARK["glute"], RIGHT_LOW, slug, color="info"),
    ])


def t_crunch(slug):
    return ("front", [
        arrow("curl", offset(LANDMARK["abs"], dy=-0.04), LANDMARK["abs"], color="primary", curve="curved"),
    ], [
        label("range", LANDMARK["abs"], RIGHT_MID, slug, color="primary"),
        label("neck", LANDMARK["neck"], LEFT_TOP, slug, color="info"),
    ])


def t_leg_raise(slug):
    return ("front", [
        arrow("curl", offset(LANDMARK["shin"], dy=0.06), LANDMARK["abs"], color="primary", curve="curved"),
    ], [
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="primary"),
        label("brace", LANDMARK["hip"], LEFT_MID, slug, color="info"),
    ])


def t_oblique(slug):
    return ("front", [
        arrow("twist", LANDMARK["obliques"], offset(LANDMARK["obliques"], dx=0.10), color="primary", curve="curved"),
    ], [
        label("twist", LANDMARK["obliques"], LEFT_MID, slug, color="primary"),
        label("back", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_side_bend(slug):
    return ("front", [
        arrow("twist", offset(LANDMARK["obliques"], dy=-0.04), offset(LANDMARK["obliques"], dy=0.04), color="primary", curve="curved"),
    ], [
        label("twist", LANDMARK["obliques"], LEFT_MID, slug, color="primary"),
        label("torso", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


def t_pallof(slug):
    return ("front", [
        arrow("press", LANDMARK["chest"], offset(LANDMARK["chest"], dx=0.10), color="primary"),
    ], [
        label("brace", LANDMARK["abs"], RIGHT_MID, slug, color="primary"),
        label("torso", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


def t_plank_hold(slug):
    return ("front", [], [
        label("neck", LANDMARK["neck"], LEFT_TOP, slug, color="info"),
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="primary"),
        label("hip", LANDMARK["hip"], RIGHT_LOW, slug, color="success"),
    ])


def t_dead_bug(slug):
    return ("front", [
        arrow("twist", LANDMARK["abs"], offset(LANDMARK["abs"], dx=0.06), color="primary", curve="curved"),
    ], [
        label("brace", LANDMARK["abs"], RIGHT_MID, slug, color="primary"),
        label("back", LANDMARK["hip"], LEFT_MID, slug, color="info"),
    ])


def t_bird_dog(slug):
    return ("back", [
        arrow("extend", offset(LANDMARK["glute"], dx=0.04), offset(LANDMARK["lats"], dx=-0.04), color="primary", curve="curved"),
    ], [
        label("core", LANDMARK["lower_back"], RIGHT_MID, slug, color="primary"),
        label("alignment", LANDMARK["glute"], RIGHT_LOW, slug, color="success"),
    ])


def t_carry(slug):
    return ("front", [
        arrow("step-down", LANDMARK["hip"], offset(LANDMARK["hip"], dx=0.05, dy=0.04), color="primary", curve="curved"),
    ], [
        label("posture", LANDMARK["chest"], RIGHT_TOP, slug, color="success"),
        label("grip", LANDMARK["wrist"], LEFT_MID, slug, color="info"),
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="primary"),
    ])


def t_clean(slug):
    return ("front", [
        arrow("hip-up", offset(LANDMARK["hip"], dy=0.05), LANDMARK["shoulder_front"], color="primary", curve="curved"),
    ], [
        label("hinge", LANDMARK["hip"], LEFT_MID, slug, color="primary"),
        label("drive", LANDMARK["quad"], RIGHT_MID, slug, color="info"),
        label("rack", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="info"),
    ])


def t_thruster(slug):
    return ("front", [
        arrow("press-up", LANDMARK["shoulder_front"], offset(LANDMARK["shoulder_front"], dy=-0.10), color="primary"),
    ], [
        label("drive", LANDMARK["quad"], LEFT_MID, slug, color="primary"),
        label("press", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="info"),
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_swing(slug):
    return ("front", [
        arrow("swing", offset(LANDMARK["hip"], dy=0.10), offset(LANDMARK["chest"], dy=0.04), color="primary", curve="curved"),
    ], [
        label("hinge", LANDMARK["hip"], LEFT_MID, slug, color="primary"),
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])
