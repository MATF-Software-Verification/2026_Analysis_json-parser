#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RESULTS_DIR="$SCRIPT_DIR/results"
TEST_BINARY="$BUILD_DIR/test_json_parser"
RAW_COVERAGE="$BUILD_DIR/coverage-raw.info"
FILTERED_COVERAGE="$BUILD_DIR/coverage-json-parser.info"
HTML_DIR="$BUILD_DIR/coverage-html"

for command_name in gcc lcov genhtml; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Nedostaje obavezna komanda: $command_name" >&2
        exit 2
    fi
done

lcov_major="$(lcov --version | sed -n 's/.*version \([0-9][0-9]*\).*/\1/p')"
if [ -z "$lcov_major" ] || [ "$lcov_major" -lt 2 ]; then
    echo "Potrebna je lcov verzija 2.0 ili novija." >&2
    exit 2
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RESULTS_DIR"

echo "Prevodjenje testova sa coverage instrumentacijom..."
cd "$REPO_ROOT"
gcc \
    -std=c89 -ansi -Wall -Wextra -Wpedantic -Werror \
    -pedantic -pedantic-errors -O0 -g --coverage \
    -D_ANSI_SOURCE -DJSON_TRACK_SOURCE \
    -Ijson-parser \
    json-parser/json.c \
    unit_tests/test_json_parser.c \
    -lm \
    -o "$TEST_BINARY"

echo "Pokretanje testova..."
"$TEST_BINARY" 2>&1 | tee "$RESULTS_DIR/izlaz-testova.txt"

echo "Reprodukcija poznatih odstupanja..."
set +e
"$TEST_BINARY" --poznati-nalazi \
    >"$RESULTS_DIR/poznati-nalazi.txt" 2>&1
known_status=$?
set -e

cat "$RESULTS_DIR/poznati-nalazi.txt"
if [ "$known_status" -eq 0 ] || \
   ! grep -q '^REPRODUKOVANO: zavrsni-zarez-objekat$' "$RESULTS_DIR/poznati-nalazi.txt" || \
   ! grep -q '^REPRODUKOVANO: zavrsni-zarez-niz$' "$RESULTS_DIR/poznati-nalazi.txt" || \
   ! grep -q '^REPRODUKOVANO: kolona-uvek-nula$' "$RESULTS_DIR/poznati-nalazi.txt" || \
   ! grep -q '^Reprodukovanih odstupanja: 3$' "$RESULTS_DIR/poznati-nalazi.txt"; then
    echo "Nisu reprodukovana sva tri dokumentovana odstupanja." >&2
    exit 1
fi

echo "Prikupljanje pokrivenosti..."
lcov --capture \
    --directory "$BUILD_DIR" \
    --output-file "$RAW_COVERAGE" \
    --rc branch_coverage=1 \
    --ignore-errors mismatch

lcov --extract "$RAW_COVERAGE" '*/json-parser/json.c' \
    --output-file "$FILTERED_COVERAGE" \
    --rc branch_coverage=1 \
    --ignore-errors unused

genhtml "$FILTERED_COVERAGE" \
    --output-directory "$HTML_DIR" \
    --branch-coverage \
    --title "json-parser - pokrivenost jedinicnim testovima" \
    >/dev/null

{
    echo "Verzije alata"
    echo "=============="
    gcc --version | sed -n '1p'
    lcov --version
    echo
    echo "Pokrivenost json.c"
    echo "=================="
    lcov --summary "$FILTERED_COVERAGE" --rc branch_coverage=1 2>&1
} | tee "$RESULTS_DIR/sazetak-pokrivenosti.txt"

echo
echo "HTML izvestaj: $HTML_DIR/index.html"
