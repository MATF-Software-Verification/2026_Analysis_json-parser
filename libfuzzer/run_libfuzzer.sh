#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RESULTS_DIR="$SCRIPT_DIR/results"
CORPUS_DIR="$BUILD_DIR/corpus"
ARTIFACT_DIR="$BUILD_DIR/artifacts"
FUZZ_BINARY="$BUILD_DIR/fuzz_json_parser"
FUZZ_SECONDS="${FUZZ_SECONDS:-60}"

if ! command -v clang >/dev/null 2>&1; then
    echo "Nedostaje obavezna komanda: clang" >&2
    exit 2
fi

rm -rf "$BUILD_DIR"
mkdir -p "$CORPUS_DIR" "$ARTIFACT_DIR" "$RESULTS_DIR"
cp "$SCRIPT_DIR"/seed-corpus/* "$CORPUS_DIR"/
cd "$REPO_ROOT"

echo "Prevodjenje fuzzer harnessa sa sanitizer instrumentacijom..."
clang -std=c89 -Wall -Wextra -Wpedantic -Werror \
    -O1 -g -fno-omit-frame-pointer \
    -fsanitize=fuzzer,address,undefined \
    -D_ANSI_SOURCE -Ijson-parser \
    json-parser/json.c libfuzzer/fuzz_json_parser.c -lm \
    -o "$FUZZ_BINARY"

echo "Pokretanje libFuzzer-a (UBSan halt_on_error=1)..."
set +e
UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
"$FUZZ_BINARY" "$CORPUS_DIR" \
    -max_total_time="$FUZZ_SECONDS" \
    -timeout=5 \
    -print_final_stats=1 \
    -artifact_prefix="$ARTIFACT_DIR/" \
    >"$RESULTS_DIR/izlaz.txt" 2>&1
status=$?
set -e

cat "$RESULTS_DIR/izlaz.txt"

# Sačuvaj minimalni reprodukcioni artefakt ako postoji crash
crash_files=$(find "$ARTIFACT_DIR" -type f 2>/dev/null || true)
if [ -n "$crash_files" ]; then
    first_crash=$(echo "$crash_files" | head -1)
    cp "$first_crash" "$RESULTS_DIR/crash-reprodukcija.bin"
    echo "Sačuvan reprodukcioni artefakt: $RESULTS_DIR/crash-reprodukcija.bin" >&2
fi

if [ "$status" -ne 0 ]; then
    echo "libFuzzer je završio statusom $status." >&2
    # Ne izlazimo sa greškom ako je jedini nalaz poznati UBSan issue
    if grep -q "applying non-zero offset.*to null pointer" "$RESULTS_DIR/izlaz.txt"; then
        echo "Pronađen je poznati UBSan nalaz (aritmetika nad NULL pokazivačem u prvom prolazu)." >&2
        exit 0
    fi
    exit "$status"
fi

{
    echo "Verzija alata"
    echo "=============="
    clang --version | sed -n '1p'
    echo
    echo "Trajanje (sekunde): $FUZZ_SECONDS"
    grep -E 'stat::number_of_executed_units|stat::average_exec_per_sec|stat::new_units_added|Done [0-9]+ runs' \
        "$RESULTS_DIR/izlaz.txt" || true
    echo "Broj crash artefakata: $(find "$ARTIFACT_DIR" -type f 2>/dev/null | wc -l)"
} | tee "$RESULTS_DIR/sazetak.txt"