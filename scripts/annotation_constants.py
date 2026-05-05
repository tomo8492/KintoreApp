"""Anatomical landmarks + label-anchor constants for annotation templates.

Coordinate system (matches generate_body_annotations.py):
  - viewBox 535x462, normalized 0..1, origin top-left.
  - Front body silhouette: x ~= [0.04, 0.46], head ~ y=0.05, hips ~ 0.43.
  - Back  body silhouette: x ~= [0.54, 0.96], same y mapping.
"""

from __future__ import annotations

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
    "groin":          (0.21, 0.50),
    "ankle":          (0.20, 0.92),
    # Back
    "trap_back":      (0.74, 0.13),
    "lats":           (0.79, 0.27),
    "triceps":        (0.83, 0.30),
    "lower_back":     (0.77, 0.42),
    "glute":          (0.78, 0.46),
    "ham":            (0.78, 0.58),
    "calf":           (0.78, 0.78),
    "shoulder_back":  (0.71, 0.18),
    "neck_back":      (0.74, 0.10),
    "ankle_back":     (0.78, 0.92),
}

LEFT_TOP   = (0.04, 0.10)
LEFT_MID   = (0.04, 0.35)
LEFT_LOW   = (0.04, 0.65)
LEFT_VLOW  = (0.04, 0.85)
RIGHT_TOP  = (0.98, 0.10)
RIGHT_MID  = (0.98, 0.35)
RIGHT_LOW  = (0.98, 0.65)
RIGHT_VLOW = (0.98, 0.85)


def pt(xy):
    return {"x": float(xy[0]), "y": float(xy[1])}


def offset(landmark_xy, dx=0.0, dy=0.0):
    return (landmark_xy[0] + dx, landmark_xy[1] + dy)


def arrow(arrow_id, frm, to, *, curve="straight", color="primary"):
    return {
        "id": arrow_id,
        "from": pt(frm),
        "to": pt(to),
        "curve": curve,
        "color": color,
    }


def label(label_id, position, anchor, slug, color="info"):
    return {
        "id": label_id,
        "position": pt(position),
        "labelAnchor": pt(anchor),
        "labelKey": f"form.{slug}.annotation.{label_id}",
        "color": color,
    }
