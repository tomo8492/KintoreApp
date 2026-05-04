#!/usr/bin/env python3
"""
Extract body diagram SVG assets from workout-cool's TSX components.

Outputs:
  - body-base.svg               (silhouette + face details, neutral gray)
  - body-{muscle}.svg           (one per muscle, that muscle in solid orange,
                                 transparent everywhere else)
  - hitzones.swift              (Swift dictionary: muscle name → bounding rect
                                 in viewBox coords for tap detection)

Source: /tmp/workout-cool (MIT License, © 2023 Mathias Bradiceanu).
"""

import re
import os
import json
from pathlib import Path

SRC_ROOT = Path("/tmp/workout-cool/src/features/workout-builder/ui")
MAIN_TSX = SRC_ROOT / "muscle-selection.tsx"
GROUPS_DIR = SRC_ROOT / "muscles"
OUT_DIR = Path("/tmp/body-svg-out")
OUT_DIR.mkdir(parents=True, exist_ok=True)

VIEWBOX = (0, 0, 535, 462)
NEUTRAL = "#757575"   # workout-cool's silhouette gray
HIGHLIGHT = "#FF6B35" # WorkoutKit accent

# Map workout-cool muscle name → WorkoutKit Muscle enum rawValue
MUSCLE_MAP = {
    "CHEST":      "chest",
    "BACK":       "lats",       # workout-cool BACK ≈ lats wing
    "TRAPS":      "traps",
    "SHOULDERS":  "deltoids",
    "BICEPS":     "biceps",
    "TRICEPS":    "triceps",
    "FOREARMS":   "forearms",
    "ABDOMINALS": "abs",
    "OBLIQUES":   "obliques",
    "QUADRICEPS": "quadriceps",
    "HAMSTRINGS": "hamstrings",
    "GLUTES":     "glutes",
    "CALVES":     "calves",
}

GROUP_FILES = {
    "CHEST":      "chest-group.tsx",
    "BACK":       "back-group.tsx",
    "TRAPS":      "traps-group.tsx",
    "SHOULDERS":  "shoulders-group.tsx",
    "BICEPS":     "biceps-group.tsx",
    "TRICEPS":    "triceps-group.tsx",
    "FOREARMS":   "forearms-group.tsx",
    "ABDOMINALS": "abdominals-group.tsx",
    "OBLIQUES":   "obliques-group.tsx",
    "QUADRICEPS": "quadriceps-group.tsx",
    "HAMSTRINGS": "hamstrings-group.tsx",
    "GLUTES":     "glutes-group.tsx",
    "CALVES":     "calves-group.tsx",
}

# Regex captures every <path … /> block. Each path may have multi-line `d` attribute.
PATH_RE = re.compile(r'<path\b([^>]*?)/>', re.DOTALL)
ATTR_RE = re.compile(r'(\w+(?:-\w+)?)\s*=\s*(?:"([^"]*)"|\{([^}]*)\})', re.DOTALL)


def parse_paths(tsx: str):
    """Yield dicts of attributes for every <path … /> found in tsx."""
    for m in PATH_RE.finditer(tsx):
        body = m.group(1)
        attrs = {}
        for am in ATTR_RE.finditer(body):
            key = am.group(1)
            val = am.group(2) if am.group(2) is not None else am.group(3)
            attrs[key] = val
        yield attrs


# ---------- Bounding box for SVG path "d" attributes ----------

NUM_RE = re.compile(r'-?\d+(?:\.\d+)?')

def bbox(d_str: str):
    """Cheap-and-good bounding box: every numeric pair in path d data."""
    nums = list(map(float, NUM_RE.findall(d_str)))
    xs = nums[0::2]
    ys = nums[1::2]
    if not xs:
        return None
    return (min(xs), min(ys), max(xs), max(ys))


def merge_bbox(a, b):
    if a is None: return b
    if b is None: return a
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


# ---------- Build base silhouette SVG ----------

main_tsx = MAIN_TSX.read_text()

# Take everything inside the outer <svg>…</svg> tag of muscle-selection.tsx,
# but BEFORE any <Group /> JSX component placement (those render inside
# their own .tsx; we generate per-muscle SVGs separately).
# Heuristic: capture all <path …/> blocks that occur in the file, since
# parse_paths only matches literal <path /> (not <ChestGroup …/> etc.).

base_paths = list(parse_paths(main_tsx))
print(f"base silhouette paths: {len(base_paths)}")

def svg_open(extra=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VIEWBOX[0]} {VIEWBOX[1]} {VIEWBOX[2]} {VIEWBOX[3]}"{extra}>'

def render_path(attrs, force_fill=None, force_alpha=None):
    """Re-emit an SVG <path/> with normalized fill."""
    d = attrs.get("d", "")
    if not d:
        return ""
    fill = force_fill if force_fill else attrs.get("fill", NEUTRAL)
    alpha = f' fill-opacity="{force_alpha}"' if force_alpha is not None else ""
    return f'  <path d="{d}" fill="{fill}"{alpha}/>\n'

# Base SVG: silhouette gray
base_svg = svg_open() + "\n"
for attrs in base_paths:
    base_svg += render_path(attrs, force_fill=NEUTRAL)
base_svg += "</svg>\n"

(OUT_DIR / "body-base.svg").write_text(base_svg)
print(f"wrote body-base.svg ({len(base_svg)} bytes)")


# ---------- Per-muscle highlight SVGs (transparent base + colored muscle) ----------
#
# Each per-muscle SVG has the SAME viewBox, fully transparent everywhere,
# with only that muscle's *visible* paths in the highlight color.
#
# We skip "fill-transparent" paths (those are workout-cool's hit zones — we
# don't want them visible). We keep the rest, recoloring to HIGHLIGHT.

bboxes = {}

for wc_name, fname in GROUP_FILES.items():
    enum_name = MUSCLE_MAP[wc_name]
    tsx = (GROUPS_DIR / fname).read_text()
    muscle_paths = list(parse_paths(tsx))
    visible = [p for p in muscle_paths if p.get("className", "") != "fill-transparent"]
    print(f"  {wc_name:>10} → {enum_name:<11} {len(muscle_paths):>2} paths "
          f"({len(visible)} visible)")

    svg = svg_open() + "\n"
    bb = None
    for p in muscle_paths:
        bb = merge_bbox(bb, bbox(p.get("d", "")))
    for p in visible:
        svg += render_path(p, force_fill=HIGHLIGHT, force_alpha=0.7)
    svg += "</svg>\n"

    out = OUT_DIR / f"body-{enum_name}.svg"
    out.write_text(svg)
    bboxes[enum_name] = bb

# ---------- Emit Swift hit-zone constants ----------

swift = ['// AUTO-GENERATED by /tmp/extract_body_svg.py — do not edit by hand.',
         '// Source: workout-cool (MIT). viewBox 0 0 535 462.',
         '',
         'import Foundation',
         '',
         'enum BodyHitZones {',
         '    /// (x, y, width, height) in workout-cool 535×462 viewBox coords.',
         '    static let zones: [String: (CGFloat, CGFloat, CGFloat, CGFloat)] = [']
for k, b in sorted(bboxes.items()):
    if b is None: continue
    x, y, x2, y2 = b
    swift.append(f'        "{k}": ({x:.1f}, {y:.1f}, {x2-x:.1f}, {y2-y:.1f}),')
swift.append('    ]')
swift.append('}')
(OUT_DIR / "BodyHitZones.swift").write_text("\n".join(swift) + "\n")

print()
print("hitzones (rawValue, bbox):")
for k, b in sorted(bboxes.items()):
    if b is None:
        print(f"  {k}: None")
    else:
        print(f"  {k:<11}: x={b[0]:6.1f} y={b[1]:6.1f} → x={b[2]:6.1f} y={b[3]:6.1f}")
