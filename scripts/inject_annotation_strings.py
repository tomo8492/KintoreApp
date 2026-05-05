#!/usr/bin/env python3
"""Inject ja/en localization entries for body-diagram annotation labels into
WorkoutKit/Resources/Localizable.xcstrings.

For each `form.<slug>.annotation.<id>` key referenced by the JSON files in
WorkoutKit/Resources/BodyAnnotations/, ensure the xcstrings catalogue has a
ja + en stringUnit entry.

Strategy:
  - Default (id-based) translations apply to almost all slugs (e.g. "knee" → 膝はつま先方向に)
  - Optional per-slug overrides for cases where the generic phrasing reads wrong

Idempotent: re-running does not duplicate keys; existing entries are kept as-is.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANNOT_DIR = ROOT / "WorkoutKit" / "Resources" / "BodyAnnotations"
XCSTRINGS = ROOT / "WorkoutKit" / "Resources" / "Localizable.xcstrings"

# id-based defaults, keyed by the suffix after `annotation.`
DEFAULTS = {
    "knee":     ("膝はつま先方向に",                  "Knees track over toes"),
    "back":     ("背中をまっすぐ保つ",                "Keep a neutral spine"),
    "hip":      ("股関節を後ろに引く",                "Sit hips back"),
    "torso":    ("胸を張って体幹を固める",            "Chest up, brace your core"),
    "core":     ("お腹に力を入れる",                  "Brace your core"),
    "neck":     ("首は自然に保つ",                    "Keep the neck neutral"),
    "scap":     ("肩甲骨を寄せる",                    "Pinch shoulder blades"),
    "elbow":    ("肘の位置を固定する",                "Pin elbows in place"),
    "feet":     ("足を床にしっかり押し付ける",        "Drive feet into the floor"),
    "touch":    ("胸の中央でバーを止める",            "Touch bar to mid-chest"),
    "scap_b":   ("肩甲骨を寄せる",                    "Squeeze shoulder blades"),
    "upper":    ("胸の上部に効かせる",                "Target the upper chest"),
    "lower":    ("胸の下部に効かせる",                "Target the lower chest"),
    "range":    ("可動域を最大に",                    "Use full range of motion"),
    "squeeze":  ("頂点でしっかり収縮",                "Squeeze hard at the top"),
    "press":    ("頭の上にまっすぐ押し上げる",        "Press straight overhead"),
    "drive":    ("脚で爆発的に押し上げる",            "Drive explosively with legs"),
    "rotate":   ("動作の中で手のひらを回転",          "Rotate palms during the lift"),
    "dip":      ("浅いクォータースクワットで反動",    "Quarter-dip for momentum"),
    "rib":      ("肋骨を内側に締める",                "Tuck ribs down"),
    "hinge":    ("股関節を蝶番のように曲げる",        "Hinge from the hips"),
    "lats":     ("広背筋に集中する",                  "Focus on lats"),
    "ham":      ("ハムストリングを意識する",          "Feel the hamstrings"),
    "legs":     ("脚で床を押し返す",                  "Push the floor away"),
    "stance":   ("足幅は肩幅より広く取る",            "Wider than shoulder stance"),
    "bicep":    ("上腕二頭筋でしっかり引く",          "Pull with the biceps"),
    "grip":     ("グリップを強く握る",                "Grip the bar tightly"),
    "rear":     ("リアデルトに集中",                  "Target rear delts"),
    "delt":     ("肩のラインまで上げる",              "Raise to shoulder height"),
    "front":    ("フロントデルトに効かせる",          "Target the front delts"),
    "trap":     ("僧帽筋ですくみ過ぎない",            "Don't shrug into traps"),
    "body":     ("頭から踵まで一直線",                "Body in a straight line"),
    "hand":     ("手は肩幅よりやや広く",              "Hands slightly wider than shoulders"),
    "balance":  ("骨盤の左右差に注意",                "Keep hips square"),
    "lean":     ("やや前傾姿勢で胸に効かせる",        "Lean forward to target chest"),
    "low":      ("肘を90度より深く下げない",          "Don't drop elbows past 90°"),
    "twist":    ("肩ではなく体幹で回旋",              "Rotate from the core, not shoulders"),
    "flow":     ("一連の動作を素早く流れるように",    "Move smoothly through each phase"),
    "brace":    ("腰が反らないよう腹圧を保つ",        "Brace abs to protect lower back"),
    "calf":     ("ふくらはぎが伸びるのを感じる",      "Feel the calves stretching"),
    "spine":    ("背骨を長く伸ばす",                  "Lengthen the spine"),
    "chest":    ("胸を大きく開く",                    "Open the chest fully"),
    # Special: slug-specific overrides handled below
}

# slug-specific overrides for cases where DEFAULTS don't read right.
# key = (slug, id) → (ja, en)
OVERRIDES = {
    ("childs-pose", "hip"):     ("お尻をかかとに近づける",           "Sink hips toward heels"),
    ("childs-pose", "back"):    ("背骨をリラックスさせて伸ばす",     "Relax and lengthen the spine"),
    ("downward-dog", "hip"):    ("お尻を高く押し上げる",             "Push hips up and back"),
    ("cobra-stretch", "hip"):   ("骨盤を床につけたまま",             "Keep hips on the floor"),
    ("pigeon-pose", "hip"):     ("前脚側のお尻を伸ばす",             "Stretch the front-leg glute"),
    ("butterfly-stretch", "knee"): ("膝を床に近づける",              "Lower knees toward floor"),
    ("plank", "hip"):           ("お尻が落ちないように",             "Don't let hips sag"),
    ("plank", "core"):          ("腹筋に常に力を入れる",             "Keep core tight throughout"),
    ("side-plank", "hip"):      ("腰が落ちないように",               "Keep hips lifted"),
    ("side-plank", "oblique"):  ("脇腹で体を支える",                 "Support body with the obliques"),
    ("crunch", "neck"):         ("首を引っ張らない",                 "Don't pull on the neck"),
    ("crunch", "range"):        ("肩甲骨が床から離れる程度",         "Lift only until shoulder blades leave the floor"),
    ("russian-twist", "back"):  ("背中を丸めない",                   "Avoid rounding the back"),
    ("dumbbell-shoulder-press", "core"): ("腰を反らさない",          "Don't arch the lower back"),
    ("seated-barbell-shoulder-press", "back"): ("背もたれに密着",   "Press back into the bench"),
    ("ab-wheel-rollout", "hip"):("腰を反らさない",                   "Don't let the lower back arch"),
    ("sissy-squat", "knee"):    ("膝への負担に注意",                 "Mind the knee load"),
    ("dip", "low"):             ("肩を下げ過ぎない",                 "Don't drop shoulders too low"),
    ("kettlebell-swing", "core"):("腹圧で腰を守る",                  "Brace abs to protect the spine"),
    ("inverted-row", "body"):   ("頭から踵まで一直線",               "Body in a straight line"),
    ("seated-cable-row", "torso"):("背中をまっすぐ保つ",             "Keep torso upright"),
    ("face-pull", "scap"):      ("肘を高く保ち外旋",                 "Elbows high, externally rotate"),
    ("kettlebell-swing", "hip"):("ヒップヒンジで前後に振る",         "Drive the swing from the hips"),
    ("burpee", "core"):         ("腰を反らさない",                   "Don't sag the lower back"),
    ("rear-delt-fly", "scap"):  ("肩甲骨を寄せ過ぎない",             "Don't over-pinch the shoulder blades"),
    ("preacher-curl", "elbow"): ("肘をパッドから離さない",           "Keep elbows pinned to the pad"),
    ("hammer-curl", "grip"):    ("手のひらを向かい合わせ",           "Palms face each other"),
    ("dumbbell-front-raise", "front"): ("肩の高さで止める",          "Stop at shoulder height"),
    ("dumbbell-lateral-raise", "trap"):("僧帽筋ですくみ過ぎない",    "Don't shrug into the traps"),
    ("leg-extension", "hip"):   ("骨盤をシートに固定",               "Keep hips planted on the seat"),
    ("seated-leg-curl", "ham"): ("ハムを完全収縮",                   "Fully contract the hamstrings"),
    ("step-up", "drive"):       ("前足の踵で押し上げる",             "Drive through the front heel"),
    ("front-squat", "elbow"):   ("肘を高く前に出す",                 "Keep elbows high and forward"),
    ("dumbbell-fly", "elbow"):  ("肘を軽く曲げて固定",               "Soft elbow bend, locked in place"),
    ("decline-barbell-press", "lower"): ("胸の下部に効かせる",       "Targets the lower chest fibres"),
    ("incline-barbell-bench-press", "upper"): ("胸の上部に効かせる",  "Target the upper chest"),
    ("incline-dumbbell-press", "upper"):  ("胸の上部に効かせる",      "Target the upper chest"),
    ("dumbbell-bench-press", "range"): ("ダンベルなら可動域広く",     "Use a deeper ROM with dumbbells"),
    ("cable-crossover", "range"):("胸の中心で交差させる",            "Cross hands at the centre line"),
    ("cable-fly", "squeeze"):   ("胸の中心でしっかり収縮",          "Squeeze chest at the centre"),
    ("pec-deck", "squeeze"):    ("中央で1秒キープ",                  "Hold one second in the middle"),
    ("standing-calf-raise", "range"): ("可動域を最大に",              "Maximize ankle range"),
    ("mountain-climber", "hip"):("お尻を上下させない",               "Keep hips level — no bouncing"),
    ("burpee", "flow"):         ("動作を流れるように繋げる",         "Flow through each phase"),
    # accessibility fallback label
}

A11Y_KEY = "a11y.library.detail.annotated-diagram.label"
A11Y_JA  = "ターゲット筋肉とフォームの注意点を示した解剖図"
A11Y_EN  = "Annotated body diagram with form cues"


def collect_required_keys() -> dict[str, tuple[str, str]]:
    """Return mapping of {labelKey: (ja, en)} required by all annotation JSONs."""
    out: dict[str, tuple[str, str]] = {}
    for json_path in sorted(ANNOT_DIR.glob("*.json")):
        data = json.loads(json_path.read_text(encoding="utf-8"))
        slug = data["slug"]
        for ann in data["annotations"]:
            key = ann["labelKey"]
            # parse: form.<slug>.annotation.<id>
            try:
                _, slug_in_key, _, ident = key.split(".", 3)
            except ValueError:
                raise SystemExit(f"malformed labelKey: {key} in {json_path}")
            if slug_in_key != slug:
                raise SystemExit(f"slug mismatch in {key} (expected {slug})")
            override = OVERRIDES.get((slug, ident))
            if override:
                out[key] = override
            elif ident in DEFAULTS:
                out[key] = DEFAULTS[ident]
            else:
                raise SystemExit(f"no default translation for id={ident!r} (key={key})")
    out[A11Y_KEY] = (A11Y_JA, A11Y_EN)
    return out


def make_unit(key: str, ja: str, en: str) -> dict:
    return {
        "extractionState": "manual",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "ja": {"stringUnit": {"state": "translated", "value": ja}},
        },
    }


def main():
    catalogue = json.loads(XCSTRINGS.read_text(encoding="utf-8"))
    strings = catalogue.setdefault("strings", {})

    required = collect_required_keys()
    added = 0
    skipped = 0
    for key, (ja, en) in sorted(required.items()):
        if key in strings:
            skipped += 1
            continue
        strings[key] = make_unit(key, ja, en)
        added += 1

    XCSTRINGS.write_text(
        json.dumps(catalogue, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"added {added} keys, skipped {skipped} (already present); total required {len(required)}")


if __name__ == "__main__":
    main()
