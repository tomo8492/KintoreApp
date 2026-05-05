#!/usr/bin/env python3
"""Generate per-exercise body-diagram annotations for the first 50 high-priority slugs.

Each output file lives at WorkoutKit/Resources/BodyAnnotations/<slug>.json and matches the
ExerciseAnnotation schema declared in WorkoutKit/Domain/Models/ExerciseAnnotation.swift.

Coordinate notes (viewBox 535x462, normalized 0..1):
  - Front body silhouette: x ~= [0.04, 0.46]
  - Back body silhouette:  x ~= [0.54, 0.96]
  - y is top->down: head ~ 0.05, hips ~ 0.43, knees ~ 0.66, ankles ~ 0.95.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "WorkoutKit" / "Resources" / "BodyAnnotations"

# Anchor positions per anatomical landmark (front body unless suffixed _back).
LANDMARK = {
    # Front
    "chest":          (0.22, 0.21),
    "abs":            (0.21, 0.33),
    "obliques":       (0.16, 0.32),
    "shoulder_front": (0.27, 0.18),
    "biceps":         (0.13, 0.30),
    "forearm":        (0.10, 0.40),
    "wrist":          (0.08, 0.43),
    "quad":           (0.20, 0.55),
    "knee":           (0.20, 0.66),
    "shin":           (0.20, 0.78),
    "hip":            (0.21, 0.45),
    "neck":           (0.22, 0.10),
    # Back
    "trap_back":      (0.74, 0.13),
    "lats":           (0.79, 0.27),
    "triceps":        (0.83, 0.30),
    "lower_back":     (0.77, 0.42),
    "glute":          (0.78, 0.46),
    "ham":            (0.78, 0.58),
    "calf":           (0.78, 0.78),
    "shoulder_back":  (0.71, 0.18),
}

# Label-anchor templates (where the text card sits). Left edge or right edge.
LEFT_TOP   = (0.04, 0.10)
LEFT_MID   = (0.04, 0.35)
LEFT_LOW   = (0.04, 0.65)
RIGHT_TOP  = (0.98, 0.10)
RIGHT_MID  = (0.98, 0.35)
RIGHT_LOW  = (0.98, 0.65)
RIGHT_VLOW = (0.98, 0.85)


def pt(xy):
    return {"x": float(xy[0]), "y": float(xy[1])}


def arrow(arrow_id: str, frm, to, *, curve: str = "straight", color: str = "primary"):
    return {
        "id": arrow_id,
        "from": pt(frm),
        "to": pt(to),
        "curve": curve,
        "color": color,
    }


def label(label_id: str, position, anchor, key: str, color: str = "info"):
    return {
        "id": label_id,
        "position": pt(position),
        "labelAnchor": pt(anchor),
        "labelKey": key,
        "color": color,
    }


# Move-down arrow used for descending phase of squat-like movements.
def move_arrow(start_xy, dy, color="primary", curve="straight"):
    return arrow("descend", start_xy, (start_xy[0], start_xy[1] + dy), color=color, curve=curve)


# Configuration: 50 high-priority slugs grouped logically.
# Each entry is (slug, view, list_of_arrows, list_of_annotations).
# `key` patterns are `form.<slug>.annotation.<id>`.
def build():
    items = []

    # ---------- Squat / lunge family (compound) ----------
    items.append(("barbell-back-squat", "front", [
        arrow("hip-down", LANDMARK["hip"], (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.10), color="primary"),
    ], [
        label("knee", LANDMARK["knee"], LEFT_LOW, "form.barbell-back-squat.annotation.knee", color="info"),
        label("back", LANDMARK["chest"], RIGHT_TOP, "form.barbell-back-squat.annotation.back", color="success"),
        label("hip",  LANDMARK["hip"],   LEFT_MID, "form.barbell-back-squat.annotation.hip",  color="info"),
    ]))

    items.append(("front-squat", "front", [
        arrow("hip-down", LANDMARK["hip"], (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.10), color="primary"),
    ], [
        label("elbow", LANDMARK["shoulder_front"], LEFT_TOP, "form.front-squat.annotation.elbow", color="info"),
        label("torso", LANDMARK["chest"],          RIGHT_TOP,"form.front-squat.annotation.torso", color="success"),
        label("knee",  LANDMARK["knee"],           LEFT_LOW, "form.front-squat.annotation.knee",  color="info"),
    ]))

    items.append(("goblet-squat", "front", [
        arrow("hip-down", LANDMARK["hip"], (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.10), color="primary"),
    ], [
        label("chest", LANDMARK["chest"], RIGHT_TOP, "form.goblet-squat.annotation.chest", color="success"),
        label("knee",  LANDMARK["knee"],  LEFT_LOW,  "form.goblet-squat.annotation.knee",  color="info"),
    ]))

    items.append(("bulgarian-split-squat", "front", [
        arrow("front-knee", LANDMARK["knee"], (LANDMARK["knee"][0], LANDMARK["knee"][1] + 0.06), color="primary"),
    ], [
        label("balance", LANDMARK["abs"], RIGHT_MID, "form.bulgarian-split-squat.annotation.balance", color="info"),
        label("knee",    LANDMARK["knee"], LEFT_LOW, "form.bulgarian-split-squat.annotation.knee",    color="warning"),
    ]))

    items.append(("dumbbell-walking-lunge", "front", [
        arrow("step-down", LANDMARK["hip"], (LANDMARK["hip"][0] - 0.05, LANDMARK["hip"][1] + 0.08), color="primary", curve="curved"),
    ], [
        label("knee",  LANDMARK["knee"], LEFT_LOW,  "form.dumbbell-walking-lunge.annotation.knee", color="info"),
        label("torso", LANDMARK["chest"], RIGHT_TOP,"form.dumbbell-walking-lunge.annotation.torso", color="success"),
    ]))

    items.append(("barbell-walking-lunge", "front", [
        arrow("step-down", LANDMARK["hip"], (LANDMARK["hip"][0] - 0.05, LANDMARK["hip"][1] + 0.08), color="primary", curve="curved"),
    ], [
        label("knee",  LANDMARK["knee"], LEFT_LOW,  "form.barbell-walking-lunge.annotation.knee",  color="info"),
        label("torso", LANDMARK["chest"], RIGHT_TOP,"form.barbell-walking-lunge.annotation.torso", color="success"),
    ]))

    items.append(("step-up", "front", [
        arrow("up", (LANDMARK["knee"][0], LANDMARK["knee"][1] + 0.06), LANDMARK["hip"], color="primary"),
    ], [
        label("drive", LANDMARK["quad"], LEFT_MID,  "form.step-up.annotation.drive",  color="primary"),
        label("torso", LANDMARK["chest"], RIGHT_TOP,"form.step-up.annotation.torso", color="success"),
    ]))

    items.append(("sissy-squat", "front", [
        arrow("knee-forward", LANDMARK["knee"], (LANDMARK["knee"][0] - 0.04, LANDMARK["knee"][1] + 0.06), color="primary", curve="curved"),
    ], [
        label("knee",  LANDMARK["knee"], LEFT_LOW, "form.sissy-squat.annotation.knee", color="warning"),
        label("torso", LANDMARK["chest"], RIGHT_TOP,"form.sissy-squat.annotation.torso", color="info"),
    ]))

    # ---------- Hip hinge / deadlift family ----------
    items.append(("barbell-deadlift", "front", [
        arrow("hip-up", (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.05), LANDMARK["hip"], color="primary"),
    ], [
        label("back",   LANDMARK["chest"], RIGHT_TOP, "form.barbell-deadlift.annotation.back",   color="success"),
        label("hinge",  LANDMARK["hip"],   LEFT_MID,  "form.barbell-deadlift.annotation.hinge",  color="primary"),
        label("legs",   LANDMARK["quad"],  RIGHT_MID, "form.barbell-deadlift.annotation.legs",   color="info"),
    ]))

    items.append(("romanian-deadlift", "front", [
        arrow("hip-back", LANDMARK["hip"], (LANDMARK["hip"][0] + 0.04, LANDMARK["hip"][1] + 0.04), color="primary", curve="curved"),
    ], [
        label("hinge", LANDMARK["hip"],   LEFT_MID,  "form.romanian-deadlift.annotation.hinge", color="primary"),
        label("ham",   LANDMARK["quad"],  RIGHT_MID, "form.romanian-deadlift.annotation.ham",   color="info"),
        label("back",  LANDMARK["chest"], RIGHT_TOP, "form.romanian-deadlift.annotation.back",  color="success"),
    ]))

    items.append(("sumo-deadlift", "front", [
        arrow("hip-up", (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.05), LANDMARK["hip"], color="primary"),
    ], [
        label("stance", LANDMARK["quad"], RIGHT_MID, "form.sumo-deadlift.annotation.stance", color="info"),
        label("torso",  LANDMARK["chest"], RIGHT_TOP, "form.sumo-deadlift.annotation.torso", color="success"),
    ]))

    items.append(("trap-bar-deadlift", "front", [
        arrow("hip-up", (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.05), LANDMARK["hip"], color="primary"),
    ], [
        label("legs",  LANDMARK["quad"],  RIGHT_MID, "form.trap-bar-deadlift.annotation.legs", color="info"),
        label("back",  LANDMARK["chest"], RIGHT_TOP, "form.trap-bar-deadlift.annotation.back", color="success"),
    ]))

    items.append(("kettlebell-swing", "front", [
        arrow("swing", (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.10), (LANDMARK["chest"][0], LANDMARK["chest"][1] + 0.04), color="primary", curve="curved"),
    ], [
        label("hip",  LANDMARK["hip"],   LEFT_MID,  "form.kettlebell-swing.annotation.hip",  color="primary"),
        label("core", LANDMARK["abs"],   RIGHT_MID, "form.kettlebell-swing.annotation.core", color="info"),
    ]))

    items.append(("barbell-hip-thrust", "front", [
        arrow("up", (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.04), LANDMARK["hip"], color="primary"),
    ], [
        label("squeeze", LANDMARK["hip"], LEFT_MID, "form.barbell-hip-thrust.annotation.squeeze", color="primary"),
        label("rib",     LANDMARK["chest"], RIGHT_TOP, "form.barbell-hip-thrust.annotation.rib",  color="info"),
    ]))

    items.append(("glute-bridge", "front", [
        arrow("up", (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.04), LANDMARK["hip"], color="primary"),
    ], [
        label("squeeze", LANDMARK["hip"], LEFT_MID,  "form.glute-bridge.annotation.squeeze", color="primary"),
        label("core",    LANDMARK["abs"], RIGHT_MID, "form.glute-bridge.annotation.core",    color="info"),
    ]))

    # ---------- Push / chest family ----------
    items.append(("barbell-bench-press", "front", [
        arrow("press-up", (LANDMARK["chest"][0], LANDMARK["chest"][1] + 0.05), LANDMARK["chest"], color="primary"),
    ], [
        label("scap",  LANDMARK["shoulder_front"], LEFT_TOP, "form.barbell-bench-press.annotation.scap",  color="info"),
        label("touch", LANDMARK["chest"],          RIGHT_TOP,"form.barbell-bench-press.annotation.touch", color="info"),
        label("feet",  LANDMARK["shin"],           LEFT_LOW, "form.barbell-bench-press.annotation.feet",  color="success"),
    ]))

    items.append(("dumbbell-bench-press", "front", [
        arrow("press-up", (LANDMARK["chest"][0], LANDMARK["chest"][1] + 0.05), LANDMARK["chest"], color="primary"),
    ], [
        label("range", LANDMARK["chest"],         RIGHT_TOP, "form.dumbbell-bench-press.annotation.range", color="primary"),
        label("scap",  LANDMARK["shoulder_front"], LEFT_TOP, "form.dumbbell-bench-press.annotation.scap",  color="info"),
    ]))

    items.append(("incline-barbell-bench-press", "front", [
        arrow("press-up", (LANDMARK["chest"][0], LANDMARK["chest"][1] + 0.04), (LANDMARK["chest"][0], LANDMARK["chest"][1] - 0.02), color="primary"),
    ], [
        label("upper", LANDMARK["chest"],         RIGHT_TOP,"form.incline-barbell-bench-press.annotation.upper", color="primary"),
        label("scap",  LANDMARK["shoulder_front"], LEFT_TOP,"form.incline-barbell-bench-press.annotation.scap",  color="info"),
    ]))

    items.append(("incline-dumbbell-press", "front", [
        arrow("press-up", (LANDMARK["chest"][0], LANDMARK["chest"][1] + 0.04), (LANDMARK["chest"][0], LANDMARK["chest"][1] - 0.02), color="primary"),
    ], [
        label("upper", LANDMARK["chest"],         RIGHT_TOP,"form.incline-dumbbell-press.annotation.upper", color="primary"),
        label("scap",  LANDMARK["shoulder_front"], LEFT_TOP,"form.incline-dumbbell-press.annotation.scap",  color="info"),
    ]))

    items.append(("decline-barbell-press", "front", [
        arrow("press-up", (LANDMARK["chest"][0], LANDMARK["chest"][1] + 0.05), LANDMARK["chest"], color="primary"),
    ], [
        label("lower", LANDMARK["chest"], RIGHT_TOP, "form.decline-barbell-press.annotation.lower", color="primary"),
    ]))

    items.append(("dumbbell-fly", "front", [
        arrow("close", (LANDMARK["shoulder_front"][0] - 0.05, LANDMARK["shoulder_front"][1] + 0.06), LANDMARK["chest"], color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["biceps"], LEFT_MID, "form.dumbbell-fly.annotation.elbow", color="info"),
        label("range", LANDMARK["chest"],  RIGHT_TOP,"form.dumbbell-fly.annotation.range", color="primary"),
    ]))

    items.append(("cable-fly", "front", [
        arrow("close", (LANDMARK["shoulder_front"][0] - 0.05, LANDMARK["shoulder_front"][1] + 0.06), LANDMARK["chest"], color="primary", curve="curved"),
    ], [
        label("squeeze", LANDMARK["chest"], RIGHT_TOP, "form.cable-fly.annotation.squeeze", color="primary"),
    ]))

    items.append(("pec-deck", "front", [
        arrow("close", (LANDMARK["shoulder_front"][0] - 0.05, LANDMARK["shoulder_front"][1] + 0.04), LANDMARK["chest"], color="primary", curve="curved"),
    ], [
        label("elbow",   LANDMARK["biceps"], LEFT_MID, "form.pec-deck.annotation.elbow",   color="info"),
        label("squeeze", LANDMARK["chest"],  RIGHT_TOP,"form.pec-deck.annotation.squeeze", color="primary"),
    ]))

    items.append(("cable-crossover", "front", [
        arrow("cross", (LANDMARK["shoulder_front"][0] - 0.05, LANDMARK["shoulder_front"][1] - 0.02), LANDMARK["abs"], color="primary", curve="curved"),
    ], [
        label("range", LANDMARK["chest"], RIGHT_TOP, "form.cable-crossover.annotation.range", color="primary"),
    ]))

    items.append(("dip", "front", [
        arrow("press-up", (LANDMARK["chest"][0], LANDMARK["chest"][1] + 0.05), LANDMARK["chest"], color="primary"),
    ], [
        label("lean", LANDMARK["chest"], RIGHT_TOP, "form.dip.annotation.lean", color="info"),
        label("low",  LANDMARK["biceps"], LEFT_MID, "form.dip.annotation.low",  color="warning"),
    ]))

    # ---------- Overhead press family ----------
    items.append(("dumbbell-shoulder-press", "front", [
        arrow("press-up", LANDMARK["shoulder_front"], (LANDMARK["shoulder_front"][0], LANDMARK["shoulder_front"][1] - 0.10), color="primary"),
    ], [
        label("core",   LANDMARK["abs"],   RIGHT_MID, "form.dumbbell-shoulder-press.annotation.core",   color="info"),
        label("press",  LANDMARK["shoulder_front"], LEFT_TOP, "form.dumbbell-shoulder-press.annotation.press", color="primary"),
    ]))

    items.append(("seated-barbell-shoulder-press", "front", [
        arrow("press-up", LANDMARK["shoulder_front"], (LANDMARK["shoulder_front"][0], LANDMARK["shoulder_front"][1] - 0.10), color="primary"),
    ], [
        label("back",  LANDMARK["chest"], RIGHT_TOP, "form.seated-barbell-shoulder-press.annotation.back", color="success"),
        label("press", LANDMARK["shoulder_front"], LEFT_TOP, "form.seated-barbell-shoulder-press.annotation.press", color="primary"),
    ]))

    items.append(("arnold-press", "front", [
        arrow("rotate", (LANDMARK["chest"][0] + 0.02, LANDMARK["chest"][1]), (LANDMARK["shoulder_front"][0], LANDMARK["shoulder_front"][1] - 0.06), color="primary", curve="curved"),
    ], [
        label("rotate", LANDMARK["shoulder_front"], LEFT_TOP, "form.arnold-press.annotation.rotate", color="primary"),
    ]))

    items.append(("push-press", "front", [
        arrow("dip-drive", (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.04), (LANDMARK["shoulder_front"][0], LANDMARK["shoulder_front"][1] - 0.10), color="primary"),
    ], [
        label("dip",   LANDMARK["hip"],   LEFT_MID,  "form.push-press.annotation.dip",   color="info"),
        label("drive", LANDMARK["shoulder_front"], LEFT_TOP, "form.push-press.annotation.drive", color="primary"),
    ]))

    # ---------- Pull / row / pull-up family ----------
    items.append(("pull-up", "back", [
        arrow("up", LANDMARK["lats"], (LANDMARK["lats"][0], LANDMARK["lats"][1] - 0.08), color="primary"),
    ], [
        label("scap", LANDMARK["trap_back"], RIGHT_TOP, "form.pull-up.annotation.scap", color="info"),
        label("lats", LANDMARK["lats"],      LEFT_MID,  "form.pull-up.annotation.lats", color="primary"),
    ]))

    items.append(("chin-up", "back", [
        arrow("up", LANDMARK["lats"], (LANDMARK["lats"][0], LANDMARK["lats"][1] - 0.08), color="primary"),
    ], [
        label("grip", LANDMARK["trap_back"], RIGHT_TOP, "form.chin-up.annotation.grip", color="info"),
        label("bicep",LANDMARK["lats"],      LEFT_MID,  "form.chin-up.annotation.bicep",color="primary"),
    ]))

    items.append(("inverted-row", "back", [
        arrow("pull", (LANDMARK["lats"][0], LANDMARK["lats"][1] + 0.06), LANDMARK["lats"], color="primary"),
    ], [
        label("body", LANDMARK["lower_back"], RIGHT_MID, "form.inverted-row.annotation.body", color="success"),
        label("scap", LANDMARK["trap_back"],  RIGHT_TOP, "form.inverted-row.annotation.scap", color="info"),
    ]))

    items.append(("barbell-row", "back", [
        arrow("pull", (LANDMARK["lats"][0], LANDMARK["lats"][1] + 0.04), LANDMARK["lats"], color="primary"),
    ], [
        label("hinge", LANDMARK["lower_back"], RIGHT_MID, "form.barbell-row.annotation.hinge", color="info"),
        label("scap",  LANDMARK["trap_back"],  RIGHT_TOP, "form.barbell-row.annotation.scap",  color="primary"),
    ]))

    items.append(("dumbbell-row", "back", [
        arrow("pull", (LANDMARK["lats"][0], LANDMARK["lats"][1] + 0.04), LANDMARK["lats"], color="primary"),
    ], [
        label("hinge", LANDMARK["lower_back"], RIGHT_MID, "form.dumbbell-row.annotation.hinge", color="info"),
        label("scap",  LANDMARK["trap_back"],  RIGHT_TOP, "form.dumbbell-row.annotation.scap",  color="primary"),
    ]))

    items.append(("t-bar-row", "back", [
        arrow("pull", (LANDMARK["lats"][0], LANDMARK["lats"][1] + 0.04), LANDMARK["lats"], color="primary"),
    ], [
        label("scap", LANDMARK["trap_back"],  RIGHT_TOP, "form.t-bar-row.annotation.scap", color="primary"),
        label("hinge",LANDMARK["lower_back"], RIGHT_MID, "form.t-bar-row.annotation.hinge", color="info"),
    ]))

    items.append(("seated-cable-row", "back", [
        arrow("pull", (LANDMARK["lats"][0] + 0.04, LANDMARK["lats"][1]), LANDMARK["lats"], color="primary"),
    ], [
        label("scap",  LANDMARK["trap_back"], RIGHT_TOP, "form.seated-cable-row.annotation.scap", color="primary"),
        label("torso", LANDMARK["lower_back"], RIGHT_MID,"form.seated-cable-row.annotation.torso", color="info"),
    ]))

    items.append(("lat-pulldown", "back", [
        arrow("pull-down", (LANDMARK["lats"][0], LANDMARK["lats"][1] - 0.10), LANDMARK["lats"], color="primary"),
    ], [
        label("lats",  LANDMARK["lats"],     LEFT_MID,  "form.lat-pulldown.annotation.lats",  color="primary"),
        label("torso", LANDMARK["lower_back"], RIGHT_MID,"form.lat-pulldown.annotation.torso",color="success"),
    ]))

    items.append(("face-pull", "back", [
        arrow("pull", (LANDMARK["trap_back"][0], LANDMARK["trap_back"][1] + 0.05), LANDMARK["trap_back"], color="primary", curve="curved"),
    ], [
        label("scap", LANDMARK["trap_back"], RIGHT_TOP, "form.face-pull.annotation.scap", color="primary"),
    ]))

    # ---------- Curl / extension / raise family (isolation) ----------
    items.append(("barbell-curl", "front", [
        arrow("curl", (LANDMARK["forearm"][0], LANDMARK["forearm"][1]), LANDMARK["biceps"], color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["biceps"], LEFT_MID, "form.barbell-curl.annotation.elbow", color="info"),
        label("torso", LANDMARK["chest"],  RIGHT_TOP,"form.barbell-curl.annotation.torso", color="success"),
    ]))

    items.append(("dumbbell-curl", "front", [
        arrow("curl", (LANDMARK["forearm"][0], LANDMARK["forearm"][1]), LANDMARK["biceps"], color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["biceps"], LEFT_MID, "form.dumbbell-curl.annotation.elbow", color="info"),
    ]))

    items.append(("hammer-curl", "front", [
        arrow("curl", (LANDMARK["forearm"][0], LANDMARK["forearm"][1]), LANDMARK["biceps"], color="primary", curve="curved"),
    ], [
        label("grip", LANDMARK["forearm"], LEFT_LOW, "form.hammer-curl.annotation.grip", color="info"),
    ]))

    items.append(("preacher-curl", "front", [
        arrow("curl", (LANDMARK["forearm"][0], LANDMARK["forearm"][1]), LANDMARK["biceps"], color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["biceps"], LEFT_MID, "form.preacher-curl.annotation.elbow", color="primary"),
    ]))

    items.append(("dumbbell-lateral-raise", "front", [
        arrow("raise", LANDMARK["forearm"], (LANDMARK["forearm"][0] - 0.05, LANDMARK["shoulder_front"][1]), color="primary", curve="curved"),
    ], [
        label("delt",  LANDMARK["shoulder_front"], LEFT_TOP, "form.dumbbell-lateral-raise.annotation.delt",  color="primary"),
        label("trap",  LANDMARK["trap_back"], RIGHT_TOP, "form.dumbbell-lateral-raise.annotation.trap",  color="warning"),
    ]))

    items.append(("dumbbell-front-raise", "front", [
        arrow("raise", LANDMARK["forearm"], (LANDMARK["forearm"][0] + 0.04, LANDMARK["shoulder_front"][1]), color="primary", curve="curved"),
    ], [
        label("front", LANDMARK["shoulder_front"], LEFT_TOP, "form.dumbbell-front-raise.annotation.front", color="primary"),
    ]))

    items.append(("rear-delt-fly", "back", [
        arrow("open", LANDMARK["lats"], (LANDMARK["shoulder_back"][0] + 0.05, LANDMARK["shoulder_back"][1]), color="primary", curve="curved"),
    ], [
        label("rear", LANDMARK["shoulder_back"], RIGHT_TOP, "form.rear-delt-fly.annotation.rear", color="primary"),
        label("scap", LANDMARK["trap_back"],     RIGHT_MID, "form.rear-delt-fly.annotation.scap", color="info"),
    ]))

    items.append(("tricep-pushdown", "back", [
        arrow("press", (LANDMARK["triceps"][0] - 0.05, LANDMARK["triceps"][1]), (LANDMARK["triceps"][0] - 0.05, LANDMARK["triceps"][1] + 0.10), color="primary"),
    ], [
        label("elbow", LANDMARK["triceps"], LEFT_MID, "form.tricep-pushdown.annotation.elbow", color="info"),
    ]))

    items.append(("overhead-tricep-extension", "back", [
        arrow("extend", (LANDMARK["triceps"][0], LANDMARK["triceps"][1] + 0.04), (LANDMARK["triceps"][0], LANDMARK["triceps"][1] - 0.06), color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["triceps"], LEFT_MID, "form.overhead-tricep-extension.annotation.elbow", color="primary"),
    ]))

    items.append(("skull-crusher", "back", [
        arrow("extend", (LANDMARK["triceps"][0], LANDMARK["triceps"][1] + 0.04), (LANDMARK["triceps"][0], LANDMARK["triceps"][1] - 0.04), color="primary", curve="curved"),
    ], [
        label("elbow", LANDMARK["triceps"], LEFT_MID, "form.skull-crusher.annotation.elbow", color="warning"),
    ]))

    items.append(("leg-extension", "front", [
        arrow("extend", (LANDMARK["shin"][0], LANDMARK["shin"][1] + 0.06), LANDMARK["shin"], color="primary", curve="curved"),
    ], [
        label("knee", LANDMARK["knee"], LEFT_LOW,  "form.leg-extension.annotation.knee", color="info"),
        label("hip",  LANDMARK["hip"],  RIGHT_MID, "form.leg-extension.annotation.hip",  color="success"),
    ]))

    items.append(("seated-leg-curl", "back", [
        arrow("curl", LANDMARK["calf"], LANDMARK["ham"], color="primary", curve="curved"),
    ], [
        label("ham", LANDMARK["ham"], LEFT_LOW, "form.seated-leg-curl.annotation.ham", color="primary"),
    ]))

    items.append(("standing-calf-raise", "back", [
        arrow("up", (LANDMARK["calf"][0], LANDMARK["calf"][1] + 0.06), LANDMARK["calf"], color="primary"),
    ], [
        label("range", LANDMARK["calf"], RIGHT_VLOW, "form.standing-calf-raise.annotation.range", color="primary"),
    ]))

    # ---------- Bodyweight & core ----------
    items.append(("push-up", "front", [
        arrow("descend", LANDMARK["chest"], (LANDMARK["chest"][0], LANDMARK["chest"][1] + 0.10), color="primary"),
    ], [
        label("body", LANDMARK["abs"],   RIGHT_MID, "form.push-up.annotation.body", color="success"),
        label("hand", LANDMARK["wrist"], LEFT_MID,  "form.push-up.annotation.hand", color="info"),
    ]))

    items.append(("plank", "front", [], [
        label("neck", LANDMARK["neck"], LEFT_TOP,  "form.plank.annotation.neck", color="info"),
        label("core", LANDMARK["abs"],  RIGHT_MID, "form.plank.annotation.core", color="primary"),
        label("hip",  LANDMARK["hip"],  RIGHT_LOW, "form.plank.annotation.hip",  color="success"),
    ]))

    items.append(("side-plank", "front", [], [
        label("hip",      LANDMARK["hip"],      RIGHT_LOW, "form.side-plank.annotation.hip",      color="success"),
        label("oblique",  LANDMARK["obliques"], LEFT_MID,  "form.side-plank.annotation.oblique",  color="primary"),
    ]))

    items.append(("crunch", "front", [
        arrow("curl", (LANDMARK["abs"][0], LANDMARK["abs"][1] - 0.04), LANDMARK["abs"], color="primary", curve="curved"),
    ], [
        label("range", LANDMARK["abs"],   RIGHT_MID, "form.crunch.annotation.range", color="primary"),
        label("neck",  LANDMARK["neck"],  LEFT_TOP,  "form.crunch.annotation.neck",  color="info"),
    ]))

    items.append(("russian-twist", "front", [
        arrow("twist", (LANDMARK["obliques"][0], LANDMARK["obliques"][1]), (LANDMARK["obliques"][0] + 0.10, LANDMARK["obliques"][1]), color="primary", curve="curved"),
    ], [
        label("twist", LANDMARK["obliques"], LEFT_MID,  "form.russian-twist.annotation.twist", color="primary"),
        label("back",  LANDMARK["abs"],      RIGHT_MID, "form.russian-twist.annotation.back",  color="info"),
    ]))

    items.append(("mountain-climber", "front", [
        arrow("knee-in", (LANDMARK["knee"][0], LANDMARK["knee"][1]), LANDMARK["abs"], color="primary", curve="curved"),
    ], [
        label("core", LANDMARK["abs"], RIGHT_MID, "form.mountain-climber.annotation.core", color="primary"),
        label("hip",  LANDMARK["hip"], LEFT_MID,  "form.mountain-climber.annotation.hip",  color="info"),
    ]))

    items.append(("burpee", "front", [
        arrow("jump", (LANDMARK["hip"][0], LANDMARK["hip"][1] + 0.05), (LANDMARK["chest"][0], LANDMARK["chest"][1] - 0.04), color="primary", curve="curved"),
    ], [
        label("flow", LANDMARK["chest"], RIGHT_TOP, "form.burpee.annotation.flow", color="primary"),
        label("core", LANDMARK["abs"],   LEFT_MID,  "form.burpee.annotation.core", color="info"),
    ]))

    items.append(("ab-wheel-rollout", "front", [
        arrow("roll-out", LANDMARK["abs"], (LANDMARK["abs"][0] - 0.10, LANDMARK["abs"][1] - 0.04), color="primary", curve="curved"),
    ], [
        label("brace", LANDMARK["abs"],       RIGHT_MID, "form.ab-wheel-rollout.annotation.brace", color="primary"),
        label("hip",   LANDMARK["lower_back"], RIGHT_LOW, "form.ab-wheel-rollout.annotation.hip",   color="warning"),
    ]))

    # ---------- Stretching ----------
    items.append(("childs-pose", "back", [], [
        label("hip",  LANDMARK["glute"],     RIGHT_MID, "form.childs-pose.annotation.hip",  color="primary"),
        label("back", LANDMARK["lower_back"], RIGHT_LOW, "form.childs-pose.annotation.back", color="success"),
    ]))

    items.append(("downward-dog", "back", [], [
        label("hip",   LANDMARK["glute"], RIGHT_MID, "form.downward-dog.annotation.hip",   color="primary"),
        label("calf",  LANDMARK["calf"],  RIGHT_VLOW,"form.downward-dog.annotation.calf",  color="info"),
        label("spine", LANDMARK["lats"],  LEFT_MID,  "form.downward-dog.annotation.spine", color="success"),
    ]))

    items.append(("cobra-stretch", "front", [], [
        label("chest", LANDMARK["chest"], RIGHT_TOP, "form.cobra-stretch.annotation.chest", color="primary"),
        label("hip",   LANDMARK["hip"],   LEFT_MID,  "form.cobra-stretch.annotation.hip",   color="info"),
    ]))

    items.append(("pigeon-pose", "front", [], [
        label("hip",  LANDMARK["hip"],  LEFT_MID,  "form.pigeon-pose.annotation.hip",  color="primary"),
        label("torso",LANDMARK["chest"], RIGHT_TOP,"form.pigeon-pose.annotation.torso",color="success"),
    ]))

    items.append(("butterfly-stretch", "front", [], [
        label("knee",  LANDMARK["knee"], LEFT_LOW,  "form.butterfly-stretch.annotation.knee",  color="primary"),
        label("torso", LANDMARK["chest"], RIGHT_TOP,"form.butterfly-stretch.annotation.torso", color="info"),
    ]))

    return items


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    items = build()
    written = 0
    for slug, view, arrows, annotations in items:
        payload = {
            "slug": slug,
            "view": view,
            "arrows": arrows,
            "annotations": annotations,
        }
        path = OUT_DIR / f"{slug}.json"
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
            f.write("\n")
        written += 1
    print(f"wrote {written} annotation files to {OUT_DIR}")


if __name__ == "__main__":
    main()
