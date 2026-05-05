#!/usr/bin/env python3
"""WorkoutKit — 生成画像を Asset Catalog に統合するスクリプト.

``output/<slug>.png`` を ``WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/<slug>.imageset/`` に
``Contents.json`` 付きで配置する。Swift からは ``Image("ExercisePhotos/<slug>")`` で参照できる
(``provides-namespace`` を有効化するため)。

衝突時の挙動:
    既存ファイルがあると差分情報(サイズ / 更新日時)を提示し、
    ``[k]eep / [r]eplace / [a]ll-replace / [s]kip-all`` を対話で確認。
    ``--force``      無条件で上書き
    ``--dry-run``    実際にはコピーせず、操作内容だけ表示
"""
from __future__ import annotations

import argparse
import datetime
import json
import logging
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger("sd-integrate")

# ---------------------------------------------------------------------------
# 既定パス
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIR = Path(__file__).parent / "output"
DEFAULT_ASSETS_DIR = REPO_ROOT / "WorkoutKit" / "Resources" / "Assets.xcassets" / "ExercisePhotos"

NAMESPACE_CONTENTS = {
    "info": {"author": "xcode", "version": 1},
    "properties": {"provides-namespace": True},
}

IMAGESET_CONTENTS_TEMPLATE = {
    "images": [],
    "info": {"author": "xcode", "version": 1},
}


# ---------------------------------------------------------------------------
# データ
# ---------------------------------------------------------------------------


@dataclass
class IntegrationDecision:
    REPLACE = "replace"
    KEEP = "keep"
    SKIP_REMAINING = "skip-remaining"
    REPLACE_REMAINING = "replace-remaining"


# ---------------------------------------------------------------------------
# Logger
# ---------------------------------------------------------------------------


def configure_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )


# ---------------------------------------------------------------------------
# ヘルパ
# ---------------------------------------------------------------------------


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def ensure_namespace_dir(assets_dir: Path) -> None:
    """ExercisePhotos/Contents.json を必要なら作る."""
    assets_dir.mkdir(parents=True, exist_ok=True)
    contents = assets_dir / "Contents.json"
    if not contents.exists():
        write_json(contents, NAMESPACE_CONTENTS)
        logger.info("created namespace Contents.json: %s", contents)


def file_summary(path: Path) -> str:
    if not path.exists():
        return "<missing>"
    stat = path.stat()
    size_kb = stat.st_size / 1024
    mtime = datetime.datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M")
    return f"{size_kb:7.1f} KB  {mtime}"


def prompt_user(slug: str, src: Path, dst: Path) -> str:
    """対話で衝突解決. 標準入力が tty でない場合は keep にフォールバック."""
    if not sys.stdin.isatty():
        logger.warning("[%s] 既存あり、stdin が tty でないため keep", slug)
        return IntegrationDecision.KEEP

    print()
    print(f"=== conflict on '{slug}' ===")
    print(f"  existing : {file_summary(dst)}")
    print(f"  new      : {file_summary(src)}")
    while True:
        ans = input("[k]eep existing / [r]eplace / [a]ll-replace / [s]kip-all: ").strip().lower()
        if ans in ("k", "keep", ""):
            return IntegrationDecision.KEEP
        if ans in ("r", "replace"):
            return IntegrationDecision.REPLACE
        if ans in ("a", "all-replace"):
            return IntegrationDecision.REPLACE_REMAINING
        if ans in ("s", "skip-all"):
            return IntegrationDecision.SKIP_REMAINING
        print("  → k / r / a / s のいずれかを入力してください")


def copy_into_imageset(
    slug: str,
    src_png: Path,
    assets_dir: Path,
    dry_run: bool,
) -> None:
    imageset_dir = assets_dir / f"{slug}.imageset"
    dst_png = imageset_dir / f"{slug}.png"
    contents_json = imageset_dir / "Contents.json"

    if dry_run:
        logger.info("[dry-run] copy %s -> %s", src_png, dst_png)
        logger.info("[dry-run] write %s", contents_json)
        return

    imageset_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src_png, dst_png)

    payload = json.loads(json.dumps(IMAGESET_CONTENTS_TEMPLATE))
    payload["images"] = [
        {"filename": dst_png.name, "idiom": "universal", "scale": "1x"},
        {"idiom": "universal", "scale": "2x"},
        {"idiom": "universal", "scale": "3x"},
    ]
    write_json(contents_json, payload)
    logger.info("[%s] integrated -> %s", slug, dst_png.relative_to(REPO_ROOT))


# ---------------------------------------------------------------------------
# メインフロー
# ---------------------------------------------------------------------------


def discover_pngs(output_dir: Path) -> list[Path]:
    return sorted(p for p in output_dir.glob("*.png") if p.is_file())


def run(args: argparse.Namespace) -> int:
    if not args.output_dir.exists():
        logger.error("output dir not found: %s", args.output_dir)
        return 2

    pngs = discover_pngs(args.output_dir)
    if not pngs:
        logger.error("no PNG files in %s", args.output_dir)
        return 2

    logger.info("found %d PNG(s) in %s", len(pngs), args.output_dir)

    if not args.dry_run:
        ensure_namespace_dir(args.assets_dir)
    else:
        logger.info("[dry-run] would ensure namespace at %s", args.assets_dir)

    replace_remaining = args.force
    skip_remaining = False
    summary = {"copied": 0, "kept": 0, "skipped": 0}

    for src in pngs:
        slug = src.stem
        dst_png = args.assets_dir / f"{slug}.imageset" / f"{slug}.png"

        if skip_remaining:
            logger.info("[%s] skipped (skip-all)", slug)
            summary["skipped"] += 1
            continue

        if dst_png.exists() and not replace_remaining:
            decision = prompt_user(slug, src, dst_png)
            if decision == IntegrationDecision.KEEP:
                summary["kept"] += 1
                continue
            if decision == IntegrationDecision.SKIP_REMAINING:
                summary["kept"] += 1
                skip_remaining = True
                continue
            if decision == IntegrationDecision.REPLACE_REMAINING:
                replace_remaining = True
            # else REPLACE -> fall through

        copy_into_imageset(slug, src, args.assets_dir, args.dry_run)
        summary["copied"] += 1

    logger.info(
        "done. copied=%d kept=%d skipped=%d",
        summary["copied"],
        summary["kept"],
        summary["skipped"],
    )
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="生成済み PNG を Asset Catalog の ExercisePhotos namespace に取り込む"
    )
    p.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="generate.py の出力ディレクトリ",
    )
    p.add_argument(
        "--assets-dir",
        type=Path,
        default=DEFAULT_ASSETS_DIR,
        help="統合先 namespace ディレクトリ",
    )
    p.add_argument("--force", action="store_true", help="既存ファイルを問答無用で上書き")
    p.add_argument("--dry-run", action="store_true", help="実際にはコピーせず操作だけ表示")
    p.add_argument("--verbose", "-v", action="store_true")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    configure_logging(args.verbose)
    try:
        return run(args)
    except KeyboardInterrupt:
        logger.warning("中断されました")
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
