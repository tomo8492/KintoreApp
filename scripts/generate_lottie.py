#!/usr/bin/env python3
"""
generate_lottie.py
==================

sample/2d-lottie-prototype 用に、5 種目分の Lottie JSON を生成する。

LottieFiles CDN は curl/WebFetch を 403 でブロックする(ANIMATION_RESEARCH.md
記載の既知問題)。本スクリプトは、既存 Swift プロト
(WorkoutKit/Features/Library/ExerciseAnimation/Animations/*.swift)で
定義した正規化座標ポーズ関数を Python に移植し、N フレームをサンプリングして
Lottie v5.7.0 互換 JSON を出力する。

成果物の位置づけ:
  - 「Lottie 経路の自前生成 fallback」(タスク指示の Step 2 オプション C/D)。
  - lottie-ios で再生できる本物の Lottie JSON。
  - LottieFiles 由来ではないため、ライセンスは MIT(プロジェクトと同一扱い)。

Lottie JSON 仕様の最低限:
  - v=5.7.0, fr=60, ip=0, op=N, w/h=1024, layers=[Shape ty=4]
  - 各 bone: ShapeLayer(ty=4) -> Group(ty="gr") -> Path(ty="sh") + Stroke(ty="st")
  - Path は KeyframedShapeProperty: a=1, k=[{t, s:[ShapeData]}]
  - 補間は線形(o=in_tangent, i=out_tangent を 0 ベクトルで指定して直線化)
  - Y 軸は Lottie 規約に合わせて下方向(StickFigure 正規化と一致)

座標変換:
  - 正規化(0..1) → Lottie ピクセル(0..CANVAS): point * CANVAS
"""

from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass
from typing import Callable, List, Tuple

# ------------------------------------------------------------------
# 出力設定
# ------------------------------------------------------------------
CANVAS = 1024  # 正方キャンバス。表示側で aspectRatio 調整するので正方で生成。
FRAMES = 60    # 1 サイクルを 60 フレームでサンプル。
FPS = 30       # 30fps なら 1 サイクル = 2.0 秒。各種目の cycleDuration は
               # 表示側で fr/sec を変えずに loopMode で十分。

# ------------------------------------------------------------------
# 補間ユーティリティ(Swift StickFigure と等価)
# ------------------------------------------------------------------
def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t

def lerp_pt(a: Tuple[float, float], b: Tuple[float, float], t: float) -> Tuple[float, float]:
    return (lerp(a[0], b[0], t), lerp(a[1], b[1], t))

def bounce(phase: float) -> float:
    """0..1 の phase を 0→1→0 の往復(ease-in-out)に。"""
    return (1 - math.cos(2 * math.pi * phase)) / 2

def keyframe(pairs: List[Tuple[float, Tuple[float, float]]], phase: float) -> Tuple[float, float]:
    p = max(0.0, min(1.0, phase))
    for i in range(len(pairs) - 1):
        p0, v0 = pairs[i]
        p1, v1 = pairs[i + 1]
        if p0 <= p <= p1:
            t = 0.0 if p1 == p0 else (p - p0) / (p1 - p0)
            return lerp_pt(v0, v1, t)
    return pairs[-1][1]


# ------------------------------------------------------------------
# 各種目のポーズ関数(Swift 移植)
# ------------------------------------------------------------------
@dataclass
class Pose:
    bones: List[Tuple[Tuple[float, float], Tuple[float, float]]]  # 線分リスト
    head: Tuple[Tuple[float, float], float]                       # (center, radiusRatio)


def pushup_pose(phase: float) -> Pose:
    depth = bounce(phase)
    toes = (0.13, 0.95)
    knee = lerp_pt((0.30, 0.80), (0.30, 0.86), depth)
    hip = lerp_pt((0.46, 0.65), (0.46, 0.80), depth)
    shoulder = lerp_pt((0.70, 0.55), (0.70, 0.78), depth)
    head_pt = lerp_pt((0.80, 0.50), (0.80, 0.74), depth)
    wrist = (0.78, 0.94)
    elbow = lerp_pt((0.76, 0.75), (0.62, 0.86), depth)
    bones = [
        (toes, knee), (knee, hip), (hip, shoulder),
        (shoulder, elbow), (elbow, wrist),
    ]
    return Pose(bones=bones, head=(head_pt, 0.05))


def squat_pose(phase: float) -> Pose:
    depth = bounce(phase)
    ankleL = (0.36, 0.95); ankleR = (0.64, 0.95)
    kneeL = lerp_pt((0.37, 0.74), (0.30, 0.78), depth)
    kneeR = lerp_pt((0.63, 0.74), (0.70, 0.78), depth)
    hipL = lerp_pt((0.42, 0.55), (0.40, 0.74), depth)
    hipR = lerp_pt((0.58, 0.55), (0.60, 0.74), depth)
    shoulderL = lerp_pt((0.39, 0.36), (0.37, 0.52), depth)
    shoulderR = lerp_pt((0.61, 0.36), (0.63, 0.52), depth)
    elbowL = lerp_pt((0.36, 0.50), (0.42, 0.55), depth)
    elbowR = lerp_pt((0.64, 0.50), (0.58, 0.55), depth)
    wristL = lerp_pt((0.34, 0.62), (0.46, 0.55), depth)
    wristR = lerp_pt((0.66, 0.62), (0.54, 0.55), depth)
    neck = lerp_pt((0.50, 0.32), (0.50, 0.48), depth)
    head_pt = lerp_pt((0.50, 0.22), (0.50, 0.40), depth)
    bones = [
        (ankleL, kneeL), (ankleR, kneeR),
        (kneeL, hipL), (kneeR, hipR),
        (hipL, hipR),
        (hipL, shoulderL), (hipR, shoulderR),
        (shoulderL, shoulderR),
        (shoulderL, elbowL), (elbowL, wristL),
        (shoulderR, elbowR), (elbowR, wristR),
        (neck, shoulderL), (neck, shoulderR),
    ]
    return Pose(bones=bones, head=(head_pt, 0.06))


def plank_pose(phase: float) -> Pose:
    breath = bounce(phase) * 0.01
    toes = (0.13, 0.95)
    knee = (0.32, 0.85)
    hip = (0.50, 0.74 + breath)
    shoulder = (0.74, 0.72 + breath)
    head_pt = (0.83, 0.69 + breath)
    elbow = (0.74, 0.94)
    wrist = (0.86, 0.94)
    bones = [
        (toes, knee), (knee, hip), (hip, shoulder),
        (shoulder, elbow), (elbow, wrist),
    ]
    return Pose(bones=bones, head=(head_pt, 0.05))


def lunge_pose(phase: float) -> Pose:
    depth = bounce(phase)
    front_ankle = (0.55, 0.95)
    front_knee = (0.55, 0.78)
    back_ankle = lerp_pt((0.50, 0.95), (0.20, 0.95), depth)
    back_knee = lerp_pt((0.50, 0.78), (0.30, 0.86), depth)
    hip = lerp_pt((0.55, 0.55), (0.55, 0.62), depth)
    shoulder = lerp_pt((0.55, 0.30), (0.55, 0.37), depth)
    head_pt = lerp_pt((0.55, 0.20), (0.55, 0.27), depth)
    elbow = lerp_pt((0.55, 0.42), (0.60, 0.45), depth)
    wrist = lerp_pt((0.55, 0.55), (0.65, 0.55), depth)
    bones = [
        (front_ankle, front_knee), (front_knee, hip),
        (back_ankle, back_knee), (back_knee, hip),
        (hip, shoulder),
        (shoulder, elbow), (elbow, wrist),
    ]
    return Pose(bones=bones, head=(head_pt, 0.05))


# Burpee は 7 キーポーズの位相補間。
_BURPEE_PHASES = [0.00, 0.18, 0.42, 0.58, 0.78, 0.93, 1.00]
_STAND   = dict(toes=(0.45, 0.95), knee=(0.45, 0.78), hip=(0.45, 0.55),
                shoulder=(0.45, 0.30), head=(0.45, 0.20),
                elbow=(0.45, 0.42), wrist=(0.45, 0.54))
_SQUATH  = dict(toes=(0.45, 0.95), knee=(0.40, 0.82), hip=(0.50, 0.80),
                shoulder=(0.55, 0.72), head=(0.62, 0.70),
                elbow=(0.60, 0.86), wrist=(0.66, 0.94))
_PLANK_B = dict(toes=(0.13, 0.95), knee=(0.30, 0.85), hip=(0.46, 0.74),
                shoulder=(0.70, 0.62), head=(0.80, 0.57),
                elbow=(0.70, 0.78), wrist=(0.72, 0.94))
_JUMP    = dict(toes=(0.45, 0.86), knee=(0.45, 0.69), hip=(0.45, 0.47),
                shoulder=(0.45, 0.22), head=(0.45, 0.12),
                elbow=(0.45, 0.06), wrist=(0.45, 0.00))
_BURPEE_SEQ = [_STAND, _SQUATH, _PLANK_B, _PLANK_B, _SQUATH, _JUMP, _STAND]


def burpee_pose(phase: float) -> Pose:
    def at(key: str) -> Tuple[float, float]:
        return keyframe(list(zip(_BURPEE_PHASES, [s[key] for s in _BURPEE_SEQ])), phase)
    toes = at("toes"); knee = at("knee"); hip = at("hip")
    shoulder = at("shoulder"); head_pt = at("head")
    elbow = at("elbow"); wrist = at("wrist")
    bones = [
        (toes, knee), (knee, hip), (hip, shoulder),
        (shoulder, elbow), (elbow, wrist),
    ]
    return Pose(bones=bones, head=(head_pt, 0.05))


# ------------------------------------------------------------------
# Lottie JSON 構築
# ------------------------------------------------------------------
def _norm_to_canvas(p: Tuple[float, float]) -> List[float]:
    return [p[0] * CANVAS, p[1] * CANVAS]

def _shape_data_for_line(p1: Tuple[float, float], p2: Tuple[float, float]) -> dict:
    """Lottie の Path Shape Data。2 頂点で線分を表現。"""
    v1 = _norm_to_canvas(p1)
    v2 = _norm_to_canvas(p2)
    return {
        "i": [[0, 0], [0, 0]],   # in tangent(線分なので 0)
        "o": [[0, 0], [0, 0]],   # out tangent
        "v": [v1, v2],           # 頂点
        "c": False,              # closed=false
    }

def _make_bone_layer(
    layer_index: int,
    bone_index: int,
    pose_fn: Callable[[float], Pose],
) -> dict:
    """1 本の bone を表すシェイプレイヤを生成。
    Path の `ks` は KeyframedShapeProperty: a=1, k=[{t, s:[ShapeData]}]。
    各キーフレームで形(2 頂点)を直接指定する。
    """
    keyframes = []
    for f in range(FRAMES + 1):
        phase = f / FRAMES
        pose = pose_fn(min(phase, 0.999999))  # bounce(1.0)=0 を避ける気休め
        if bone_index >= len(pose.bones):
            # ポーズによって bone 数が違う場合(本実装では固定だが念のため)
            # は前フレームを保持
            continue
        p1, p2 = pose.bones[bone_index]
        keyframes.append({
            "t": f,
            "s": [_shape_data_for_line(p1, p2)],
        })

    return {
        "ddd": 0,
        "ind": layer_index,
        "ty": 4,                                # ShapeLayer
        "nm": f"bone_{bone_index}",
        "sr": 1,
        "ks": _identity_transform(),
        "ao": 0,
        "shapes": [
            {
                "ty": "gr",
                "nm": "Group",
                "it": [
                    {
                        "ty": "sh",
                        "nm": "Path",
                        "ks": {
                            "a": 1,
                            "k": keyframes,
                        },
                    },
                    {
                        "ty": "st",                 # Stroke
                        "c": {"a": 0, "k": [0.0, 0.0, 0.0, 1.0]},  # 黒。表示側で
                                                                  # ColorValueProvider
                                                                  # で上書き
                        "o": {"a": 0, "k": 100},    # opacity
                        "w": {"a": 0, "k": 36},     # 線幅(CANVAS 1024 基準)
                        "lc": 2,                    # round cap
                        "lj": 2,                    # round join
                        "ml": 4,
                    },
                    _identity_shape_transform(),
                ],
            }
        ],
        "ip": 0,
        "op": FRAMES,
        "st": 0,
        "bm": 0,
    }

def _make_head_layer(layer_index: int, pose_fn: Callable[[float], Pose]) -> dict:
    """頭(円)レイヤ。center を Position、半径は Size を 0 アニメで指定して
    cycle 内で center だけ移動させる。Plank の breath を活かすため Position は
    アニメ可とする。"""
    pose0 = pose_fn(0.0)
    radius_ratio = pose0.head[1]
    radius = radius_ratio * CANVAS
    diameter = radius * 2

    pos_keyframes = []
    for f in range(FRAMES + 1):
        phase = f / FRAMES
        pose = pose_fn(min(phase, 0.999999))
        center = _norm_to_canvas(pose.head[0])
        pos_keyframes.append({
            "t": f,
            "s": center + [0.0],   # 3D 風だが 2D 扱い (z=0)
        })

    return {
        "ddd": 0,
        "ind": layer_index,
        "ty": 4,
        "nm": "head",
        "sr": 1,
        "ks": _identity_transform(),
        "ao": 0,
        "shapes": [
            {
                "ty": "gr",
                "nm": "Group",
                "it": [
                    {
                        "ty": "el",                            # Ellipse
                        "nm": "Ellipse",
                        "p": {
                            "a": 1,
                            "k": [
                                {
                                    "t": kf["t"],
                                    "s": kf["s"],
                                }
                                for kf in pos_keyframes
                            ],
                        },
                        "s": {"a": 0, "k": [diameter, diameter]},
                    },
                    {
                        "ty": "st",
                        "c": {"a": 0, "k": [0.0, 0.0, 0.0, 1.0]},
                        "o": {"a": 0, "k": 100},
                        "w": {"a": 0, "k": 36},
                        "lc": 2,
                        "lj": 2,
                        "ml": 4,
                    },
                    _identity_shape_transform(),
                ],
            }
        ],
        "ip": 0,
        "op": FRAMES,
        "st": 0,
        "bm": 0,
    }


def _identity_transform() -> dict:
    """Lottie レイヤ Transform。アニメなしで原点配置。"""
    return {
        "o": {"a": 0, "k": 100},                       # opacity
        "r": {"a": 0, "k": 0},                         # rotation
        "p": {"a": 0, "k": [0, 0, 0]},                 # position
        "a": {"a": 0, "k": [0, 0, 0]},                 # anchor
        "s": {"a": 0, "k": [100, 100, 100]},           # scale
    }

def _identity_shape_transform() -> dict:
    """Group 内 Transform("tr")。ShapeLayer 内のグループ末尾に必須。"""
    return {
        "ty": "tr",
        "nm": "Transform",
        "p": {"a": 0, "k": [0, 0]},
        "a": {"a": 0, "k": [0, 0]},
        "s": {"a": 0, "k": [100, 100]},
        "r": {"a": 0, "k": 0},
        "o": {"a": 0, "k": 100},
        "sk": {"a": 0, "k": 0},
        "sa": {"a": 0, "k": 0},
    }


def build_lottie(
    name: str,
    pose_fn: Callable[[float], Pose],
) -> dict:
    """1 サイクル分の Lottie JSON を生成。"""
    pose0 = pose_fn(0.0)
    layers = []
    layer_idx = 1
    for bone_idx in range(len(pose0.bones)):
        layers.append(_make_bone_layer(layer_idx, bone_idx, pose_fn))
        layer_idx += 1
    layers.append(_make_head_layer(layer_idx, pose_fn))

    # Lottie の描画順は ind 大きい方が下、小さい方が上。bone と head の順で
    # layers を並べているが、ind 値そのものは Lottie 表示順に直接影響しないので
    # 配列並びだけ気にすればよい(配列先頭が最前面)。

    return {
        "v": "5.7.0",
        "fr": FPS,
        "ip": 0,
        "op": FRAMES,
        "w": CANVAS,
        "h": CANVAS,
        "nm": name,
        "ddd": 0,
        "assets": [],
        "layers": layers,
        "markers": [],
    }


# ------------------------------------------------------------------
# main
# ------------------------------------------------------------------
TARGETS = [
    ("push-up",        pushup_pose),
    ("air-squat",      squat_pose),
    ("plank",          plank_pose),
    ("reverse-lunge",  lunge_pose),
    ("burpee",         burpee_pose),
]

def main() -> None:
    out_dir = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..",
        "WorkoutKit", "Resources", "Lottie",
    )
    out_dir = os.path.normpath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    for slug, pose_fn in TARGETS:
        lottie = build_lottie(name=slug, pose_fn=pose_fn)
        path = os.path.join(out_dir, f"{slug}.json")
        with open(path, "w", encoding="utf-8") as f:
            # separators で空白詰め(同梱サイズ削減)。
            json.dump(lottie, f, ensure_ascii=False, separators=(",", ":"))
        size_kb = os.path.getsize(path) / 1024.0
        print(f"  [ok] {slug:<14} {size_kb:6.1f} KB → {path}")

if __name__ == "__main__":
    main()
