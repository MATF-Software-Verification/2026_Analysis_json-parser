#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
SOURCE="json-parser/json.c"

if ! command -v cppcheck >/dev/null 2>&1; then
    echo "Greška: cppcheck nije pronađen u PATH-u." >&2
    exit 127
fi

mkdir -p "$RESULTS_DIR"
cd "$REPO_ROOT"

COMMON_OPTIONS=(
    --std=c89
    --language=c
    --platform=unix64
    -D_ANSI_SOURCE
    -U_MSC_VER
    -U__STDC_VERSION__
    -Ijson-parser
    --enable=warning,performance,portability
    --check-level=exhaustive
    --inconclusive
    --relative-paths=.
)
TEXT_TEMPLATE='{file}:{line}:{column}: {severity}: {id}: {message} [CWE-{cwe}]'

run_configuration() {
    local name="$1"
    shift
    local config_options=("$@")

    cppcheck "${COMMON_OPTIONS[@]}" "${config_options[@]}" \
        --xml --xml-version=2 "$SOURCE" \
        2>"$RESULTS_DIR/${name}.xml"

    cppcheck "${COMMON_OPTIONS[@]}" "${config_options[@]}" \
        --template="$TEXT_TEMPLATE" "$SOURCE" \
        2>"$RESULTS_DIR/${name}.txt"
}

# Bibliotečka (podrazumevana) C89 konfiguracija.
run_configuration cppcheck-c89 -UJSON_TRACK_SOURCE

# Konfiguracija korišćena u testovima projekta; proverava i opciona polja za lokaciju izvora.
run_configuration cppcheck-c89-track-source -DJSON_TRACK_SOURCE

{
    printf 'Cppcheck verzija: '
    cppcheck --version
    printf 'Standard: C89\n'
    printf 'Platforma: unix64\n'
    printf 'Izvor: %s\n' "$SOURCE"
    printf 'Omogućene kategorije: error (podrazumevano), warning, performance, portability\n'
    printf 'Dodatno: exhaustive analiza i inconclusive nalazi\n'
    printf 'Konfiguracije: _ANSI_SOURCE; _ANSI_SOURCE + JSON_TRACK_SOURCE\n'
} >"$RESULTS_DIR/metapodaci.txt"

python3 - "$RESULTS_DIR" <<'PY'
import collections
import pathlib
import sys
import xml.etree.ElementTree as ET

results = pathlib.Path(sys.argv[1])
lines = []
total = collections.Counter()
for path in sorted(results.glob("cppcheck-*.xml")):
    errors = ET.parse(path).getroot().find("errors")
    counts = collections.Counter(item.get("severity", "nepoznato") for item in errors)
    total.update(counts)
    lines.append(f"{path.name}: " + ", ".join(
        f"{severity}={counts.get(severity, 0)}"
        for severity in ("error", "warning", "performance", "portability")
    ))
lines.append("UKUPNO: " + ", ".join(
    f"{severity}={total.get(severity, 0)}"
    for severity in ("error", "warning", "performance", "portability")
))
(results / "sazetak.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

printf 'Cppcheck analiza je završena. Rezultati su u %s\n' "$RESULTS_DIR"
