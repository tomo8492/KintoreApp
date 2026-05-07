#!/usr/bin/env bash
# generate_app_store_screenshots.sh
#
# CLAUDE.md §-1.15 / Tests/WorkoutKitUITests/AppStoreScreenshotTests.swift 準拠。
# App Store 提出用スクリーンショットを 3 デバイス × 2 ロケール × 10 シナリオ = 60 枚生成する。
#
# 出力: /tmp/app-store/<device-label>-<locale>-<scenario>.png
#
# 必要環境:
#   - Xcode 16+(xcresulttool export attachments を使う)
#   - jq(manifest.json をパースする)
#   - 対象シミュレータ:
#       * iPhone 16 Plus       (6.7", 1290×2796)
#       * iPhone 16 Pro Max    (6.9", 1320×2868)
#       * iPad Pro 13-inch (M4)(13",  2064×2752)
#
# 使い方:
#   $ ./scripts/generate_app_store_screenshots.sh
#
# オプション:
#   APP_STORE_OUT=/path/to/dir   出力先(default: /tmp/app-store)
#   SCREENSHOT_DEVICES="..."     カンマ区切りで device label をフィルタ
#   SCREENSHOT_LOCALES="ja,en"   カンマ区切りで locale をフィルタ
#   KEEP_RESULT_BUNDLES=1        xcresult を残す(普段は削除)

set -euo pipefail

# ----- Config -----

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly OUT_DIR="${APP_STORE_OUT:-/tmp/app-store}"
readonly TMP_ROOT="$(mktemp -d /tmp/app-store-run.XXXXXX)"
readonly SCHEME="WorkoutKit"
readonly TEST_TARGET="WorkoutKitUITests"
readonly TEST_CLASS="AppStoreScreenshotTests"
readonly DEVELOPER_DIR_DEFAULT="/Applications/Xcode.app/Contents/Developer"

# DEVELOPER_DIR を必ず Xcode.app に向ける(CommandLineTools のままだと
# xcresulttool が無いため abort する)。
export DEVELOPER_DIR="${DEVELOPER_DIR:-$DEVELOPER_DIR_DEFAULT}"

if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required (brew install jq)" >&2
    exit 1
fi
if [[ ! -d "$DEVELOPER_DIR" ]]; then
    echo "error: DEVELOPER_DIR=$DEVELOPER_DIR not found. Install Xcode." >&2
    exit 1
fi

# Targets: "label|simulator name". Plus 表記の型番も Apple 公式の解像度ごとに 1 つだけ採用。
# iPhone 16 系 / iPad Pro 13-inch M4 は iOS 18.5 シミュレータでしか利用できないため、
# OS バージョンを明示してマッチを安定させる(SDK 26 で OS=latest にすると not found になる)。
TARGETS=(
    "iphone-67|iPhone 16 Plus|18.5"
    "iphone-69|iPhone 16 Pro Max|18.5"
    "ipad-13|iPad Pro 13-inch (M4)|18.5"
)

LOCALES=("ja" "en")

# フィルタ
if [[ -n "${SCREENSHOT_DEVICES:-}" ]]; then
    IFS=',' read -r -a wanted <<<"$SCREENSHOT_DEVICES"
    filtered=()
    for entry in "${TARGETS[@]}"; do
        label="${entry%%|*}"
        for w in "${wanted[@]}"; do
            if [[ "$label" == "$w" ]]; then filtered+=("$entry"); fi
        done
    done
    TARGETS=("${filtered[@]}")
fi
if [[ -n "${SCREENSHOT_LOCALES:-}" ]]; then
    IFS=',' read -r -a LOCALES <<<"$SCREENSHOT_LOCALES"
fi

mkdir -p "$OUT_DIR"

# ----- Helpers -----

cleanup() {
    if [[ "${KEEP_RESULT_BUNDLES:-0}" != "1" ]]; then
        rm -rf "$TMP_ROOT"
    else
        echo "[info] kept result bundles under $TMP_ROOT"
    fi
}
trap cleanup EXIT

bundle_id() {
    # WorkoutKit/Resources の Info.plist は GENERATE_INFOPLIST_FILE=YES なので
    # CFBundleIdentifier を直接読めない。Shared.xcconfig から取る。
    awk -F= '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' \
        "$REPO_ROOT/Config/Shared.xcconfig" 2>/dev/null \
        || echo "com.tomo.workoutkit"
}

run_one() {
    local label="$1"
    local destination_name="$2"
    local os_version="$3"
    local locale="$4"

    local result_bundle="$TMP_ROOT/$label-$locale.xcresult"
    local extract_dir="$TMP_ROOT/$label-$locale-extracted"
    mkdir -p "$extract_dir"

    echo "==> running tests: device=$label locale=$locale"

    # Simulator が前回の状態を保持しているとビルドCTAが消えていたりする。
    # boot 状態のまま app をアンインストール → 履歴 / ProGate state を初期化。
    local bid
    bid="$(bundle_id)"
    local udid
    udid="$(xcrun simctl list devices booted -j 2>/dev/null \
        | jq -r --arg name "$destination_name" '
            [.devices[] | .[] | select(.name == $name and .state == "Booted") | .udid] | first // empty
        ')"
    if [[ -n "$udid" ]]; then
        xcrun simctl uninstall "$udid" "$bid" >/dev/null 2>&1 || true
    fi

    # xcodebuild に env を渡す(TEST_RUNNER_<name> は test runner プロセス内で <name> として読める)。
    # ⚠ TEST_RUNNER_* は xcodebuild の "build setting" 形式 (positional KEY=VALUE) では伝わらず、
    #   xcodebuild プロセスの environment variable として継承させる必要がある。
    #   試行錯誤の末、env コマンドで明示的に渡すのが最も確実だった。
    local region
    region="$( [[ $locale == ja ]] && echo ja_JP || echo en_US )"
    set +e
    env \
        TEST_RUNNER_UITEST_LOCALE="$locale" \
        TEST_RUNNER_UITEST_DEVICE_LABEL="$label" \
        xcodebuild test \
            -project "$REPO_ROOT/WorkoutKit.xcodeproj" \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$destination_name,OS=$os_version" \
            -only-testing:"$TEST_TARGET/$TEST_CLASS" \
            -resultBundlePath "$result_bundle" \
            -testLanguage "$locale" \
            -testRegion "$region" \
            COMPILER_INDEX_STORE_ENABLE=NO \
        | tail -200
    local exit_code=${PIPESTATUS[0]}
    set -e
    if [[ $exit_code -ne 0 ]]; then
        echo "[warn] xcodebuild test exited $exit_code for $label/$locale (continuing — partial screenshots may exist)" >&2
    fi

    if [[ ! -d "$result_bundle" ]]; then
        echo "[error] result bundle not found: $result_bundle" >&2
        return 1
    fi

    # Attachment 抽出。manifest.json に suggestedHumanReadableName が入っている。
    xcrun xcresulttool export attachments \
        --path "$result_bundle" \
        --output-path "$extract_dir" >/dev/null

    local manifest="$extract_dir/manifest.json"
    if [[ ! -f "$manifest" ]]; then
        echo "[error] manifest.json missing under $extract_dir" >&2
        return 1
    fi

    # manifest.json を parse して、suggestedHumanReadableName を出力ファイル名にする。
    # XCTest は attachment.name に "_<index>_<UUID>.png" を付加するため、
    # 末尾の "_<digit>+_<HEX-with-dashes>\.png" を sed で剥がして元の name に戻す。
    # Xcode が自動添付する診断ファイル(失敗時の "Debug description for X",
    # "Screen Recording", "App UI hierarchy", "UI Snapshot")は当該パターンに
    # 当てはまらない/拡張子が違うので、`<label>-<locale>-` プレフィックスでフィルタする。
    # 同名の重複が出ると上書きされる(同じシナリオを再撮影した場合は最後勝ち、許容)。
    local copied_for_target=0
    while IFS=$'\t' read -r exported raw_name; do
        [[ -z "$exported" || -z "$raw_name" ]] && continue
        local src="$extract_dir/$exported"
        if [[ ! -f "$src" ]]; then
            echo "[warn] expected file missing: $src" >&2
            continue
        fi
        # "iphone-67-ja-today_0_2A75....png" → "iphone-67-ja-today"
        local name
        name="$(printf '%s' "$raw_name" | sed -E 's/_[0-9]+_[0-9A-F-]+\.png$//')"
        # 念のため拡張子が残っていれば再除去
        name="${name%.png}"
        # マーケ用 PNG だけを残す。プレフィックスにマッチしないものは Xcode 自動診断。
        if [[ "$name" != "$label-$locale-"* ]]; then
            continue
        fi
        local dst="$OUT_DIR/$name.png"
        cp "$src" "$dst"
        copied_for_target=$((copied_for_target + 1))
    done < <(jq -r '
        .. | objects
        | select(has("exportedFileName") and has("suggestedHumanReadableName"))
        | "\(.exportedFileName)\t\(.suggestedHumanReadableName)"
    ' "$manifest")

    echo "    copied $copied_for_target screenshots to $OUT_DIR"
}

# ----- Build (warm) -----

echo "==> warming build (no destination, just compile)"
xcodebuild build-for-testing \
    -project "$REPO_ROOT/WorkoutKit.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" \
    -quiet

# ----- Loop -----

for entry in "${TARGETS[@]}"; do
    IFS='|' read -r label sim_name os_version <<<"$entry"
    # Simulator を起動しておく(前 run の Booted 状態を流用するため最低限の boot)。
    # OS が複数バージョン入っているケース(例: iPad Pro M4 が 18.5 のみ)もあるので
    # OS と name の両方で絞り込み、無ければ name 単独で fallback する。
    udid="$(xcrun simctl list devices -j \
        | jq -r --arg name "$sim_name" --arg os "$os_version" '
            [
                .devices
                | to_entries[]
                | select((.key | test("iOS " + $os + "$")) or true)
                | .value[]
                | select(.name == $name)
                | .udid
            ]
            | first // empty
        ')"
    if [[ -z "$udid" ]]; then
        echo "[warn] simulator '$sim_name' (iOS $os_version) not installed, skipping" >&2
        continue
    fi
    state="$(xcrun simctl list devices -j \
        | jq -r --arg udid "$udid" '
            [.devices[] | .[] | select(.udid == $udid) | .state] | first // empty
        ')"
    if [[ "$state" != "Booted" ]]; then
        xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    fi

    for locale in "${LOCALES[@]}"; do
        run_one "$label" "$sim_name" "$os_version" "$locale" || true
    done
done

# ----- Summary -----

echo
echo "===== Summary ====="
total="$(find "$OUT_DIR" -maxdepth 1 -name '*.png' -type f 2>/dev/null | wc -l | tr -d ' ')"
echo "total PNGs in $OUT_DIR: $total"
echo
echo "by device:"
for entry in "${TARGETS[@]}"; do
    label="${entry%%|*}"
    count="$(find "$OUT_DIR" -maxdepth 1 -name "${label}-*.png" -type f 2>/dev/null | wc -l | tr -d ' ')"
    printf "  %-12s %s\n" "$label" "$count"
done
echo
echo "by locale:"
for locale in "${LOCALES[@]}"; do
    count="$(find "$OUT_DIR" -maxdepth 1 -name "*-${locale}-*.png" -type f 2>/dev/null | wc -l | tr -d ' ')"
    printf "  %-12s %s\n" "$locale" "$count"
done
