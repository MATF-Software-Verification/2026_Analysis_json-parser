#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RESULTS_DIR="$SCRIPT_DIR/results"
FUZZ_BINARY="$BUILD_DIR/fuzz_harness"
FUZZ_SECONDS="${FUZZ_SECONDS:-60}"

for cmd in afl-clang-fast afl-fuzz; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Nedostaje obavezna komanda: $cmd" >&2
        exit 2
    fi
done

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RESULTS_DIR"
cp "$SCRIPT_DIR"/seed-corpus/* "$BUILD_DIR"/
cd "$REPO_ROOT"

echo "Prevodjenje harnessa sa AFL++ instrumentacijom..."
afl-clang-fast -std=c89 -Wall -Wextra -Wpedantic -Werror \
    -O1 -g \
    -D_ANSI_SOURCE -Ijson-parser \
    json-parser/json.c aflplusplus/fuzz_harness.c -lm \
    -o "$FUZZ_BINARY"

echo "Pokretanje AFL++ fuzzing-a ($FUZZ_SECONDS sekundi)..."
set +e
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
AFL_SKIP_CRASHES=1 \
AFL_SKIP_CPUFREQ=1 \
afl-fuzz -i "$BUILD_DIR" -o "$RESULTS_DIR/findings" \
    -V "$FUZZ_SECONDS" \
    -t 5000 \
    -m none \
    -- "$FUZZ_BINARY" \
    >"$RESULTS_DIR/izlaz.txt" 2>&1
status=$?
set -e

echo "AFL++ je zavrsio sa statusom $status."

{
    echo "Verzija alata"
    echo "=============="
    afl-clang-fast --version 2>/dev/null | head -1 || true
    afl-fuzz --version 2>/dev/null | head -1 || true
    echo
    echo "Trajanje (sekunde): $FUZZ_SECONDS"
    echo
    echo "Statistika"
    echo "=========="
    cat "$RESULTS_DIR/izlaz.txt" | grep -E 'cycles|total_crashes|unique_crashes|total_hangs|unique_hangs|saved_crashes|total_execs|execs_per_sec' || true
    echo
    echo "Crashes: $(find "$RESULTS_DIR/findings/default/crashes" -maxdepth 1 -type f 2>/dev/null | wc -l)"
    echo "Hangs: $(find "$RESULTS_DIR/findings/default/hangs" -maxdepth 1 -type f 2>/dev/null | wc -l)"
    echo "Queue: $(find "$RESULTS_DIR/findings/default/queue" -maxdepth 1 -type f 2>/dev/null | wc -l)"
} | tee "$RESULTS_DIR/sazetak.txt"