#!/usr/bin/env python3
"""フォーム注釈の重なり・見切れ検査ツール。

AnnotatedFormView の吹き出し(コールアウト)レイアウトを SwiftUI の実装定数で
シミュレートし、以下の違反を検出する:

  1. clip    — 吹き出しカードが写真の外にはみ出す(見切れ)
  2. overlap — 吹き出しカード同士が重なる
  3. dot     — 吹き出しカードが他アノテーションのドットを覆い隠す

ja / en 両ロケールの文言で検査する(en の方が長くなりがち)。
複数フレーム種目はフレームごとに独立して検査する(同時表示されないため)。

使い方:
  python3 tools/check_form_annotations.py            # 全 JSON を検査
  python3 tools/check_form_annotations.py <slug>...  # 指定 slug のみ

終了コード: 違反 0 件なら 0、violations があれば 1。
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANN_DIR = os.path.join(ROOT, "WorkoutKit/Resources/FormAnnotations")
XCSTRINGS = os.path.join(ROOT, "WorkoutKit/Resources/Localizable.xcstrings")

# ---- AnnotatedFormView のレイアウト定数(実装と同期させること) ----
# 検査する写真表示幅(pt)。iPhone SE 相当の最狭幅と標準幅の両方で検査する。
WIDTHS = [320.0, 358.0]
FONT = 12.0          # .caption semibold ≒ 12pt
LINE_H = 16.0        # 1 行の高さ
PAD_H = 10.0 * 2     # 水平 padding
PAD_V = 6.0 * 2      # 垂直 padding
MAX_W_RATIO = 0.45   # カード最大幅 = 写真幅の 45%
CLAMP = 4.0          # .position の端クランプ
DOT_R = 7.0          # ドット半径(14pt 円)

# 文字幅の概算: 全角(CJK)は FONT、半角は FONT*0.55
def text_width(s: str) -> float:
    w = 0.0
    for ch in s:
        w += FONT if ord(ch) > 0x2E80 else FONT * 0.55
    return w


def card_rect(anchor_x, anchor_y, text, W, H):
    """AnnotationCard.clampedCenter() を再現してカードの矩形を返す。

    カードの実サイズを見積もり、矩形全体が写真内(margin CLAMP)に収まるよう
    中心をシフトする(ビュー実装と同じロジック)。
    """
    max_w = W * MAX_W_RATIO
    tw = text_width(text)
    if tw + PAD_H <= max_w:
        cw, lines = tw + PAD_H, 1
    else:
        cw = max_w
        lines = math.ceil(tw / (max_w - PAD_H))
    ch = lines * LINE_H + PAD_V
    half_w, half_h = cw / 2 + CLAMP, ch / 2 + CLAMP
    cx = min(max(anchor_x * W, min(half_w, W / 2)), max(W - half_w, W / 2))
    cy = min(max(anchor_y * H, min(half_h, H / 2)), max(H - half_h, H / 2))
    return (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2), lines


def intersects(a, b, margin=0.0):
    return not (a[2] + margin <= b[0] or b[2] + margin <= a[0]
                or a[3] + margin <= b[1] or b[3] + margin <= a[1])


def load_labels():
    d = json.load(open(XCSTRINGS))
    out = {}
    for key, entry in d["strings"].items():
        locs = entry.get("localizations", {})
        out[key] = {
            lang: locs.get(lang, {}).get("stringUnit", {}).get("value", "")
            for lang in ("ja", "en")
        }
    return out


def check_frame(slug, frame, labels, W):
    H = W / frame["aspect"]
    problems = []
    for lang in ("ja", "en"):
        rects = []
        for ann in frame["annotations"]:
            text = labels.get(ann["labelKey"], {}).get(lang)
            if not text:
                problems.append(f"[{lang}] {ann['id']}: 文言キー未登録 {ann['labelKey']}")
                continue
            rect, _ = card_rect(ann["labelAnchor"]["x"], ann["labelAnchor"]["y"], text, W, H)
            rects.append((ann["id"], rect))
            # 1. 見切れ
            over = []
            if rect[0] < 0: over.append(f"左に{-rect[0]:.0f}pt")
            if rect[1] < 0: over.append(f"上に{-rect[1]:.0f}pt")
            if rect[2] > W: over.append(f"右に{rect[2]-W:.0f}pt")
            if rect[3] > H: over.append(f"下に{rect[3]-H:.0f}pt")
            if over:
                problems.append(f"[{lang}] clip: '{ann['id']}' が {' / '.join(over)} 見切れ (W={W:.0f})")
        # 2. カード同士の重なり
        for i in range(len(rects)):
            for j in range(i + 1, len(rects)):
                if intersects(rects[i][1], rects[j][1]):
                    problems.append(
                        f"[{lang}] overlap: '{rects[i][0]}' と '{rects[j][0]}' が重なる (W={W:.0f})")
        # 3. カードが他アノテーションのドットを覆う
        for aid, rect in rects:
            for ann in frame["annotations"]:
                if ann["id"] == aid:
                    continue
                dx, dy = ann["position"]["x"] * W, ann["position"]["y"] * H
                dot = (dx - DOT_R, dy - DOT_R, dx + DOT_R, dy + DOT_R)
                if intersects(rect, dot):
                    problems.append(
                        f"[{lang}] dot: '{aid}' のカードがドット '{ann['id']}' を覆う (W={W:.0f})")
    return problems


def main():
    labels = load_labels()
    only = set(sys.argv[1:])
    total = 0
    for name in sorted(os.listdir(ANN_DIR)):
        if not name.endswith("-annotations.json"):
            continue
        slug = name[: -len("-annotations.json")]
        if only and slug not in only:
            continue
        doc = json.load(open(os.path.join(ANN_DIR, name)))
        for frame in doc["frames"]:
            seen = set()
            for W in WIDTHS:
                for p in check_frame(slug, frame, labels, W):
                    key = p.split(" (W=")[0]
                    if key in seen:  # 同一違反は最狭幅の 1 回だけ報告
                        continue
                    seen.add(key)
                    print(f"NG {slug}/{frame['id']}: {p}")
                    total += 1
    if total:
        print(f"\n{total} violations")
        return 1
    print("OK: 重なり・見切れなし(全フレーム、ja/en、W=" +
          "/".join(str(int(w)) for w in WIDTHS) + "pt)")
    return 0


def main_all():
    """レイアウト検査 + 注釈キー実在検査の両方を実行する。"""
    layout_rc = main()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    problems = check_label_keys_exist(root)
    if problems:
        print("\n".join(problems))
        print(f"\n{len(problems)} violations (label key existence)")
        return 1
    print("OK: 注釈キーは全て xcstrings に ja/en 揃って存在(FormAnnotations + BodyAnnotations)")
    return layout_rc



# ---------------------------------------------------------------------------
# 追加検査 (2026-07-30): 注釈 JSON が参照するローカライズキーの実在確認。
#
# 経緯: 「未参照キーの整理」で FormAnnotations だけを突き合わせた結果、同じ
# form.<slug>.annotation.<id> 名前空間を使う BodyAnnotations 側の参照キー 243 件
# を誤って削除し、136 種目の人体図でキー文字列が画面に露出する回帰を起こした。
# 再発防止のため、両ディレクトリの参照キーが xcstrings に ja/en 揃って存在する
# ことを CI (annotations-qa ジョブ) で必ず検査する。
# ---------------------------------------------------------------------------

def _collect_label_keys(path):
    keys = set()
    for name in sorted(os.listdir(path)):
        if not name.endswith(".json"):
            continue
        with open(os.path.join(path, name), encoding="utf-8") as fh:
            payload = json.load(fh)

        def walk(node):
            if isinstance(node, dict):
                for key, value in node.items():
                    if key in ("labelKey", "phaseLabelKey") and isinstance(value, str):
                        keys.add((name, value))
                    else:
                        walk(value)
            elif isinstance(node, list):
                for item in node:
                    walk(item)

        walk(payload)
    return keys


def check_label_keys_exist(repo_root):
    catalog_path = os.path.join(repo_root, "WorkoutKit/Resources/Localizable.xcstrings")
    with open(catalog_path, encoding="utf-8") as fh:
        catalog = json.load(fh)["strings"]

    problems = []
    for rel in ("WorkoutKit/Resources/FormAnnotations", "WorkoutKit/Resources/BodyAnnotations"):
        directory = os.path.join(repo_root, rel)
        if not os.path.isdir(directory):
            continue
        for source, key in sorted(_collect_label_keys(directory)):
            entry = catalog.get(key)
            if entry is None:
                problems.append(f"NG {rel}/{source}: キー未定義 '{key}'")
                continue
            localizations = entry.get("localizations", {})
            for lang in ("ja", "en"):
                if lang not in localizations:
                    problems.append(f"NG {rel}/{source}: '{key}' に {lang} 訳が無い")
    return problems


if __name__ == "__main__":
    sys.exit(main_all())
