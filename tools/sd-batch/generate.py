#!/usr/bin/env python3
"""WorkoutKit — Stable Diffusion バッチ生成スクリプト.

Top-50 種目のフォーム解説イラストを 1 枚ずつ生成し、
``output/<slug>.png`` と ``output/report.json`` を書き出す。

依存:
    Python 3.10+
    requests >= 2.28  (``pip install requests``)
    Pillow >= 10.0    (``pip install Pillow``)  ← 任意。インストール済みなら検証に使う

バックエンド:
    ``--backend drawthings`` (既定)  Draw Things の HTTP API (Automatic1111 互換)
    ``--backend diffusers``           HuggingFace Diffusers + MPS

参考: ``style-guide.md`` がプロンプト規約の唯一の正。
"""
from __future__ import annotations

import argparse
import base64
import json
import logging
import os
import sys
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# 共通プロンプト(style-guide.md と必ず一致させる)
# ---------------------------------------------------------------------------

STYLE_PREFIX = (
    "clean isometric illustration, flat shading, athletic instruction diagram, "
    "neutral pure-white studio background, soft directional lighting from upper left, "
    "single subject, full body in frame, centered composition, "
    "no text, no logo, no branding, no UI elements, no captions"
)

CHARACTER = (
    "athletic Asian male, age 28, lean muscular build, "
    "short black hair, clean-shaven, neutral expression, "
    "plain white short-sleeve t-shirt, plain black athletic shorts, white gym shoes, "
    "no accessories, no jewelry, no tattoos"
)

QUALITY_TAGS = (
    "high detail, anatomically correct, professional fitness instruction style, "
    "clear silhouette, balanced composition, sharp focus, even lighting"
)

NEGATIVE_TAGS = (
    "extra limbs, extra fingers, missing fingers, fused fingers, "
    "mutated hands, malformed limbs, distorted anatomy, "
    "multiple people, two heads, duplicate body, "
    "blurry, low quality, low resolution, jpeg artifacts, noise, "
    "watermark, signature, text overlay, caption, logo, brand name, "
    "nsfw, suggestive, lingerie, "
    "photo, photograph, photorealistic skin pores, "
    "weird shadow, harsh contrast, oversaturated"
)

DEFAULT_PARAMS = {
    "sampler_name": "DPM++ 2M Karras",
    "steps": 28,
    "cfg_scale": 6.5,
    "width": 1024,
    "height": 1024,
}

MAX_RETRIES = 3
RETRY_SEED_BUMP = 1  # 失敗のたびに seed を +1 する

# ---------------------------------------------------------------------------
# Logger
# ---------------------------------------------------------------------------

logger = logging.getLogger("sd-batch")


def configure_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )


# ---------------------------------------------------------------------------
# データ構造
# ---------------------------------------------------------------------------


@dataclass
class ExerciseSpec:
    slug: str
    pose: str
    equipment: str


@dataclass
class GenerationOutcome:
    slug: str
    status: str  # "success" | "failed"
    seed_used: int
    attempts: int
    elapsed_sec: float
    output_path: str | None = None
    error: str | None = None


@dataclass
class Report:
    generated_at: str
    backend: str
    api_url: str | None
    base_seed: int
    total: int
    success_count: int = 0
    failed_count: int = 0
    outcomes: list[GenerationOutcome] = field(default_factory=list)


# ---------------------------------------------------------------------------
# プロンプト合成
# ---------------------------------------------------------------------------


def build_positive_prompt(spec: ExerciseSpec) -> str:
    parts = [
        STYLE_PREFIX,
        CHARACTER,
        spec.pose,
        f"equipment: {spec.equipment}" if spec.equipment else "",
        QUALITY_TAGS,
    ]
    return ", ".join(p for p in parts if p)


def build_negative_prompt(spec: ExerciseSpec) -> str:
    return NEGATIVE_TAGS


# ---------------------------------------------------------------------------
# バックエンド: Draw Things (Automatic1111 互換 HTTP API)
# ---------------------------------------------------------------------------


class DrawThingsBackend:
    """Draw Things が listen している sdapi/v1/txt2img を叩く."""

    def __init__(self, api_url: str, timeout: int = 600) -> None:
        self.api_url = api_url.rstrip("/")
        self.timeout = timeout
        try:
            import requests  # noqa: F401  (遅延 import で起動コストを抑える)
        except ImportError as exc:
            raise SystemExit(
                "requests が見つからない。`pip install requests` を実行してください。"
            ) from exc
        self._requests = __import__("requests")

    def healthcheck(self) -> None:
        url = f"{self.api_url}/sdapi/v1/sd-models"
        try:
            r = self._requests.get(url, timeout=10)
            r.raise_for_status()
        except Exception as exc:
            raise RuntimeError(
                f"Draw Things API に接続できない({url}): {exc}\n"
                "  - Draw Things を起動 / Settings ▸ Server で API を有効化したか確認"
            ) from exc
        logger.info("Draw Things API OK (%s)", url)

    def txt2img(
        self,
        prompt: str,
        negative: str,
        seed: int,
    ) -> bytes:
        payload: dict[str, Any] = {
            "prompt": prompt,
            "negative_prompt": negative,
            "seed": seed,
            **DEFAULT_PARAMS,
        }
        url = f"{self.api_url}/sdapi/v1/txt2img"
        r = self._requests.post(url, json=payload, timeout=self.timeout)
        r.raise_for_status()
        data = r.json()
        images = data.get("images") or []
        if not images:
            raise RuntimeError(f"API がイメージを返さなかった: {data}")
        return base64.b64decode(images[0])


# ---------------------------------------------------------------------------
# バックエンド: HuggingFace Diffusers (MPS / Metal)
# ---------------------------------------------------------------------------


class DiffusersBackend:
    """ローカル Diffusers パイプライン. 初回のみモデル DL が走る."""

    def __init__(
        self,
        model_id: str = "stabilityai/stable-diffusion-xl-base-1.0",
        resolution: int = 1024,
    ) -> None:
        try:
            import torch
            from diffusers import StableDiffusionXLPipeline
        except ImportError as exc:
            raise SystemExit(
                "Diffusers が見つからない。\n"
                "  pip install 'diffusers[torch]' transformers accelerate safetensors pillow"
            ) from exc

        device = "mps" if torch.backends.mps.is_available() else "cpu"
        if device == "cpu":
            logger.warning("MPS が使えない。CPU フォールバックは非常に遅い。")
        logger.info("Diffusers: %s on %s をロード中(初回は DL)", model_id, device)
        self._pipe = StableDiffusionXLPipeline.from_pretrained(
            model_id,
            torch_dtype=torch.float16 if device == "mps" else torch.float32,
        ).to(device)
        self._device = device
        self._resolution = resolution
        self._torch = torch

    def healthcheck(self) -> None:
        logger.info("Diffusers ready (device=%s, res=%d)", self._device, self._resolution)

    def txt2img(self, prompt: str, negative: str, seed: int) -> bytes:
        from io import BytesIO

        generator = self._torch.Generator(device=self._device).manual_seed(seed)
        result = self._pipe(
            prompt=prompt,
            negative_prompt=negative,
            num_inference_steps=DEFAULT_PARAMS["steps"],
            guidance_scale=DEFAULT_PARAMS["cfg_scale"],
            width=self._resolution,
            height=self._resolution,
            generator=generator,
        )
        image = result.images[0]
        buf = BytesIO()
        image.save(buf, format="PNG")
        return buf.getvalue()


# ---------------------------------------------------------------------------
# 入出力
# ---------------------------------------------------------------------------


def load_exercises(path: Path) -> list[ExerciseSpec]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    items = raw["exercises"]
    return [
        ExerciseSpec(slug=item["slug"], pose=item["pose"], equipment=item.get("equipment", ""))
        for item in items
    ]


def write_png(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    # Pillow があれば形式チェック
    try:
        from PIL import Image  # noqa
        with Image.open(path) as img:
            img.verify()
    except ImportError:
        pass
    except Exception as exc:
        raise RuntimeError(f"生成 PNG が壊れている({path}): {exc}") from exc


def filter_failed(report: Report, all_specs: list[ExerciseSpec]) -> list[ExerciseSpec]:
    failed_slugs = {o.slug for o in report.outcomes if o.status != "success"}
    return [s for s in all_specs if s.slug in failed_slugs]


# ---------------------------------------------------------------------------
# メインループ
# ---------------------------------------------------------------------------


def generate_one(
    backend: DrawThingsBackend | DiffusersBackend,
    spec: ExerciseSpec,
    base_seed: int,
    output_dir: Path,
) -> GenerationOutcome:
    positive = build_positive_prompt(spec)
    negative = build_negative_prompt(spec)
    output_path = output_dir / f"{spec.slug}.png"
    start = time.monotonic()

    last_error: str | None = None
    for attempt in range(1, MAX_RETRIES + 1):
        seed = base_seed + (attempt - 1) * RETRY_SEED_BUMP
        try:
            logger.info("[%s] attempt %d (seed=%d)", spec.slug, attempt, seed)
            png_bytes = backend.txt2img(positive, negative, seed=seed)
            write_png(output_path, png_bytes)
        except Exception as exc:  # noqa: BLE001 — 継続用
            last_error = str(exc)
            logger.warning("[%s] attempt %d failed: %s", spec.slug, attempt, exc)
            continue
        elapsed = time.monotonic() - start
        logger.info("[%s] OK in %.1fs", spec.slug, elapsed)
        return GenerationOutcome(
            slug=spec.slug,
            status="success",
            seed_used=seed,
            attempts=attempt,
            elapsed_sec=round(elapsed, 1),
            output_path=str(output_path),
        )

    elapsed = time.monotonic() - start
    logger.error("[%s] giving up after %d attempts", spec.slug, MAX_RETRIES)
    return GenerationOutcome(
        slug=spec.slug,
        status="failed",
        seed_used=base_seed,
        attempts=MAX_RETRIES,
        elapsed_sec=round(elapsed, 1),
        output_path=None,
        error=last_error,
    )


def write_report(report: Report, path: Path) -> None:
    payload = {
        "generated_at": report.generated_at,
        "backend": report.backend,
        "api_url": report.api_url,
        "base_seed": report.base_seed,
        "total": report.total,
        "success_count": report.success_count,
        "failed_count": report.failed_count,
        "outcomes": [asdict(o) for o in report.outcomes],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    logger.info("report written: %s", path)


def merge_previous_report(previous: Path) -> Report | None:
    if not previous.exists():
        return None
    try:
        raw = json.loads(previous.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    outcomes = [GenerationOutcome(**o) for o in raw.get("outcomes", [])]
    return Report(
        generated_at=raw.get("generated_at", ""),
        backend=raw.get("backend", ""),
        api_url=raw.get("api_url"),
        base_seed=raw.get("base_seed", 42),
        total=raw.get("total", 0),
        success_count=raw.get("success_count", 0),
        failed_count=raw.get("failed_count", 0),
        outcomes=outcomes,
    )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="WorkoutKit Top-50 種目イラストのバッチ生成"
    )
    p.add_argument(
        "--backend",
        choices=["drawthings", "diffusers"],
        default=os.environ.get("SD_BACKEND", "drawthings"),
        help="バックエンド (既定: drawthings)",
    )
    p.add_argument(
        "--api-url",
        default=os.environ.get("SD_API_URL", "http://127.0.0.1:7860"),
        help="Draw Things API URL (drawthings バックエンド時のみ)",
    )
    p.add_argument(
        "--input",
        type=Path,
        default=Path(__file__).parent / "exercises_top50.json",
        help="種目リスト JSON のパス",
    )
    p.add_argument(
        "--output-dir",
        type=Path,
        default=Path(os.environ.get("SD_OUTPUT_DIR", Path(__file__).parent / "output")),
        help="生成画像の保存先",
    )
    p.add_argument(
        "--seed",
        type=int,
        default=int(os.environ.get("SD_SEED_BASE", "42")),
        help="全種目で使うベース seed",
    )
    p.add_argument(
        "--only-failed",
        action="store_true",
        help="前回の report.json で failed だった種目だけ再生成",
    )
    p.add_argument(
        "--limit",
        type=int,
        default=None,
        help="先頭から N 種目だけ生成(動作確認用)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="API を叩かず、合成プロンプトを表示するだけ",
    )
    p.add_argument("--verbose", "-v", action="store_true")
    return p.parse_args(argv)


def make_backend(args: argparse.Namespace) -> DrawThingsBackend | DiffusersBackend:
    if args.backend == "drawthings":
        return DrawThingsBackend(api_url=args.api_url)
    return DiffusersBackend()


def run(args: argparse.Namespace) -> int:
    if not args.input.exists():
        logger.error("input not found: %s", args.input)
        return 2

    specs = load_exercises(args.input)
    logger.info("loaded %d specs from %s", len(specs), args.input)

    if args.only_failed:
        previous = merge_previous_report(args.output_dir / "report.json")
        if previous is None:
            logger.error("--only-failed が指定されたが、前回 report が見つからない")
            return 2
        specs = filter_failed(previous, specs)
        logger.info("only-failed: %d 件をリトライ", len(specs))
        if not specs:
            logger.info("失敗種目なし。何もしない。")
            return 0

    if args.limit:
        specs = specs[: args.limit]
        logger.info("limit: 先頭 %d 件のみ処理", len(specs))

    if args.dry_run:
        for spec in specs:
            print(f"=== {spec.slug} ===")
            print("POSITIVE:", build_positive_prompt(spec))
            print("NEGATIVE:", build_negative_prompt(spec))
            print()
        return 0

    backend = make_backend(args)
    backend.healthcheck()

    args.output_dir.mkdir(parents=True, exist_ok=True)

    report = Report(
        generated_at=time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        backend=args.backend,
        api_url=args.api_url if args.backend == "drawthings" else None,
        base_seed=args.seed,
        total=len(specs),
    )

    for index, spec in enumerate(specs, start=1):
        logger.info("--- (%d/%d) %s ---", index, len(specs), spec.slug)
        outcome = generate_one(backend, spec, args.seed, args.output_dir)
        report.outcomes.append(outcome)
        if outcome.status == "success":
            report.success_count += 1
        else:
            report.failed_count += 1

    write_report(report, args.output_dir / "report.json")

    logger.info(
        "done. success=%d failed=%d / total=%d",
        report.success_count,
        report.failed_count,
        report.total,
    )
    return 0 if report.failed_count == 0 else 1


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
