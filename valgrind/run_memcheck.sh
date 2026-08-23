#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RESULTS_DIR="$SCRIPT_DIR/results"
UNIT_BINARY="$BUILD_DIR/test_json_parser"
UPSTREAM_BINARY="$BUILD_DIR/upstream_tests"

for command_name in gcc git valgrind; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Nedostaje obavezna komanda: $command_name" >&2
        exit 2
    fi
done

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RESULTS_DIR"
cd "$REPO_ROOT"

echo "Prevodjenje dodatnih i upstream testova..."
gcc -std=c89 -ansi -Wall -Wextra -Wpedantic -Werror \
    -pedantic -pedantic-errors -O0 -g \
    -D_ANSI_SOURCE -DJSON_TRACK_SOURCE -Ijson-parser \
    json-parser/json.c unit_tests/test_json_parser.c -lm \
    -o "$UNIT_BINARY"

gcc -std=c89 -ansi -Wall -Wpedantic -Werror \
    -pedantic -pedantic-errors -O0 -g \
    -D_ANSI_SOURCE -DJSON_TRACK_SOURCE -Ijson-parser \
    json-parser/json.c json-parser/tests/test.c -lm \
    -o "$UPSTREAM_BINARY"

VALGRIND_OPTIONS=(
    --leak-check=full
    --show-leak-kinds=all
    --track-origins=yes
    --errors-for-leak-kinds=definite,indirect,possible
    --error-exitcode=99
)

echo "Memcheck nad dodatnim testovima..."
valgrind "${VALGRIND_OPTIONS[@]}" \
    --log-file="$RESULTS_DIR/memcheck-jedinicni-testovi.txt" \
    "$UNIT_BINARY" >"$RESULTS_DIR/izlaz-jedinicnih-testova.txt"

echo "Memcheck nad upstream testovima..."
(
    cd "$REPO_ROOT/json-parser/tests"
    valgrind "${VALGRIND_OPTIONS[@]}" \
        --log-file="$RESULTS_DIR/memcheck-upstream-testovi.txt" \
        "$UPSTREAM_BINARY" \
        >"$RESULTS_DIR/izlaz-upstream-testova.txt" 2>&1
)

{
    echo "Okruzenje analize"
    echo "=================="
    valgrind --version
    gcc --version | sed -n '1p'
    printf 'json-parser commit: '
    git -C "$REPO_ROOT/json-parser" rev-parse HEAD
    echo
    echo "Dodatni jedinicni testovi"
    echo "========================="
    grep -E 'in use at exit|total heap usage|All heap blocks|ERROR SUMMARY' \
        "$RESULTS_DIR/memcheck-jedinicni-testovi.txt"
    echo
    echo "Upstream testovi"
    echo "==============="
    grep -E 'in use at exit|total heap usage|All heap blocks|ERROR SUMMARY' \
        "$RESULTS_DIR/memcheck-upstream-testovi.txt"
} | tee "$RESULTS_DIR/sazetak.txt"

echo "Valgrind Memcheck analiza je zavrsena bez prijavljenih gresaka."
