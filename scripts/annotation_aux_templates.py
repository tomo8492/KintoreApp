"""Warm-up, cardio, and stretching annotation templates."""

from __future__ import annotations

from annotation_constants import (
    LANDMARK, LEFT_TOP, LEFT_MID, LEFT_LOW, LEFT_VLOW,
    RIGHT_TOP, RIGHT_MID, RIGHT_LOW, RIGHT_VLOW,
    arrow, label, offset,
)


# ---------- WARMUP / mobility ----------

def t_warmup_arm(slug):
    return ("front", [
        arrow("rotate", LANDMARK["forearm"], offset(LANDMARK["forearm"], dx=-0.04, dy=-0.06), color="primary", curve="curved"),
    ], [
        label("shoulders", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="primary"),
        label("breathe", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


def t_warmup_leg(slug):
    return ("front", [
        arrow("swing", LANDMARK["knee"], offset(LANDMARK["knee"], dx=0.05, dy=-0.04), color="primary", curve="curved"),
    ], [
        label("hip", LANDMARK["hip"], LEFT_MID, slug, color="primary"),
        label("balance", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


def t_warmup_hip(slug):
    return ("front", [
        arrow("rotate", LANDMARK["hip"], offset(LANDMARK["hip"], dx=0.05, dy=0.04), color="primary", curve="curved"),
    ], [
        label("hip", LANDMARK["hip"], LEFT_MID, slug, color="primary"),
        label("core", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_warmup_torso(slug):
    return ("front", [
        arrow("twist", LANDMARK["chest"], offset(LANDMARK["chest"], dx=0.08), color="primary", curve="curved"),
    ], [
        label("twist", LANDMARK["obliques"], LEFT_MID, slug, color="primary"),
        label("breathe", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_warmup_spine(slug):
    return ("back", [
        arrow("flow", LANDMARK["lower_back"], offset(LANDMARK["lower_back"], dy=-0.06), color="primary", curve="curved"),
    ], [
        label("spine", LANDMARK["lats"], LEFT_MID, slug, color="primary"),
        label("breathe", LANDMARK["lower_back"], RIGHT_MID, slug, color="info"),
    ])


def t_warmup_full(slug):
    return ("front", [
        arrow("jump", offset(LANDMARK["hip"], dy=0.05), offset(LANDMARK["shoulder_front"], dy=-0.05), color="primary", curve="curved"),
    ], [
        label("flow", LANDMARK["chest"], RIGHT_TOP, slug, color="primary"),
        label("breathe", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_warmup_neck(slug):
    return ("front", [
        arrow("rotate", LANDMARK["neck"], offset(LANDMARK["neck"], dx=0.05), color="primary", curve="curved"),
    ], [
        label("neck", LANDMARK["neck"], LEFT_TOP, slug, color="primary"),
        label("shoulders", LANDMARK["shoulder_front"], RIGHT_TOP, slug, color="info"),
    ])


def t_warmup_ankle(slug):
    return ("front", [
        arrow("rotate", LANDMARK["ankle"], offset(LANDMARK["ankle"], dx=0.04), color="primary", curve="curved"),
    ], [
        label("ankle", LANDMARK["ankle"], LEFT_VLOW, slug, color="primary"),
    ])


def t_warmup_wrist(slug):
    return ("front", [
        arrow("rotate", LANDMARK["wrist"], offset(LANDMARK["wrist"], dx=-0.04), color="primary", curve="curved"),
    ], [
        label("wrist", LANDMARK["wrist"], LEFT_LOW, slug, color="primary"),
    ])


# ---------- CARDIO ----------

def t_cardio_full(slug):
    return ("front", [
        arrow("flow", offset(LANDMARK["hip"], dy=0.05), offset(LANDMARK["chest"], dy=-0.04), color="primary", curve="curved"),
    ], [
        label("flow", LANDMARK["chest"], RIGHT_TOP, slug, color="primary"),
        label("breathe", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
        label("tempo", LANDMARK["hip"], LEFT_MID, slug, color="info"),
    ])


def t_cardio_legs(slug):
    return ("front", [
        arrow("step-down", LANDMARK["hip"], offset(LANDMARK["hip"], dx=-0.05, dy=0.05), color="primary", curve="curved"),
    ], [
        label("legs", LANDMARK["quad"], LEFT_MID, slug, color="primary"),
        label("breathe", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


def t_cardio_punch(slug):
    return ("front", [
        arrow("press", LANDMARK["shoulder_front"], offset(LANDMARK["shoulder_front"], dx=-0.06), color="primary"),
    ], [
        label("rotate", LANDMARK["obliques"], LEFT_MID, slug, color="primary"),
        label("hand", LANDMARK["wrist"], LEFT_LOW, slug, color="info"),
    ])


def t_cardio_rope(slug):
    return ("front", [
        arrow("jump", offset(LANDMARK["ankle"], dy=-0.04), LANDMARK["ankle"], color="primary"),
    ], [
        label("calf", LANDMARK["shin"], LEFT_LOW, slug, color="primary"),
        label("breathe", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


# ---------- STRETCHING ----------

def t_stretch_chest(slug):
    return ("front", [], [
        label("chest", LANDMARK["chest"], RIGHT_TOP, slug, color="primary"),
        label("breathe", LANDMARK["abs"], RIGHT_MID, slug, color="info"),
    ])


def t_stretch_back(slug):
    return ("back", [], [
        label("spine", LANDMARK["lats"], LEFT_MID, slug, color="primary"),
        label("breathe", LANDMARK["lower_back"], RIGHT_MID, slug, color="info"),
    ])


def t_stretch_lats(slug):
    return ("back", [], [
        label("lats", LANDMARK["lats"], LEFT_MID, slug, color="primary"),
        label("spine", LANDMARK["lower_back"], RIGHT_MID, slug, color="info"),
    ])


def t_stretch_lower_back(slug):
    return ("back", [], [
        label("hinge", LANDMARK["lower_back"], RIGHT_MID, slug, color="primary"),
        label("breathe", LANDMARK["glute"], RIGHT_LOW, slug, color="info"),
    ])


def t_stretch_glute(slug):
    return ("back", [], [
        label("hip", LANDMARK["glute"], RIGHT_MID, slug, color="primary"),
        label("back", LANDMARK["lower_back"], RIGHT_TOP, slug, color="info"),
    ])


def t_stretch_ham(slug):
    return ("back", [], [
        label("ham", LANDMARK["ham"], LEFT_LOW, slug, color="primary"),
        label("back", LANDMARK["lower_back"], RIGHT_MID, slug, color="info"),
    ])


def t_stretch_quad(slug):
    return ("front", [], [
        label("knee", LANDMARK["knee"], LEFT_LOW, slug, color="primary"),
        label("hip", LANDMARK["hip"], LEFT_MID, slug, color="info"),
    ])


def t_stretch_calf(slug):
    return ("back", [], [
        label("calf", LANDMARK["calf"], RIGHT_VLOW, slug, color="primary"),
        label("ankle", LANDMARK["ankle_back"], LEFT_VLOW, slug, color="info"),
    ])


def t_stretch_shoulder(slug):
    return ("front", [], [
        label("shoulders", LANDMARK["shoulder_front"], LEFT_TOP, slug, color="primary"),
        label("breathe", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


def t_stretch_neck(slug):
    return ("front", [], [
        label("neck", LANDMARK["neck"], LEFT_TOP, slug, color="primary"),
        label("shoulders", LANDMARK["shoulder_front"], RIGHT_TOP, slug, color="info"),
    ])


def t_stretch_tricep(slug):
    return ("back", [], [
        label("elbow", LANDMARK["triceps"], LEFT_MID, slug, color="primary"),
        label("shoulders", LANDMARK["shoulder_back"], RIGHT_TOP, slug, color="info"),
    ])


def t_stretch_bicep(slug):
    return ("front", [], [
        label("elbow", LANDMARK["biceps"], LEFT_MID, slug, color="primary"),
        label("chest", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


def t_stretch_forearm(slug):
    return ("front", [], [
        label("wrist", LANDMARK["wrist"], LEFT_LOW, slug, color="primary"),
        label("grip", LANDMARK["forearm"], LEFT_MID, slug, color="info"),
    ])


def t_stretch_oblique(slug):
    return ("front", [], [
        label("twist", LANDMARK["obliques"], LEFT_MID, slug, color="primary"),
        label("breathe", LANDMARK["chest"], RIGHT_TOP, slug, color="info"),
    ])


def t_stretch_abs(slug):
    return ("front", [], [
        label("chest", LANDMARK["chest"], RIGHT_TOP, slug, color="primary"),
        label("hip", LANDMARK["hip"], LEFT_MID, slug, color="info"),
    ])


def t_stretch_full(slug):
    return ("back", [], [
        label("spine", LANDMARK["lats"], LEFT_MID, slug, color="primary"),
        label("breathe", LANDMARK["lower_back"], RIGHT_MID, slug, color="info"),
        label("hip", LANDMARK["glute"], RIGHT_LOW, slug, color="success"),
    ])
