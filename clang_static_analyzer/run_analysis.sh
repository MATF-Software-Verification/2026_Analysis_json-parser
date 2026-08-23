#!/bin/sh
# Reproduktivno pokretanje Clang Static Analyzer-a nad json-parser/json.c.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SOURCE="$REPO_DIR/json-parser/json.c"
INCLUDE_DIR="$REPO_DIR/json-parser"
RESULTS_DIR="$SCRIPT_DIR/results"

CLANG=${CLANG:-clang}
mkdir -p "$RESULTS_DIR"

{
  printf 'Komanda: %s --analyze -std=c89 -pedantic -I%s -Xanalyzer -analyzer-checker=core,unix,security,deadcode -Xanalyzer -analyzer-output=text %s\n\n' "$CLANG" "$INCLUDE_DIR" "$SOURCE"
  "$CLANG" --version
} > "$RESULTS_DIR/okruzenje.txt"

# Tekstualni trag je namenjen čitanju i diff-u.
"$CLANG" --analyze \
  -std=c89 -pedantic -I"$INCLUDE_DIR" \
  -Xanalyzer -analyzer-checker=core,unix,security,deadcode \
  -Xanalyzer -analyzer-output=text \
  "$SOURCE" > "$RESULTS_DIR/sirovi_izlaz.txt" 2>&1

# PLIST čuva mašinski čitljive putanje i metapodatke svakog nalaza.
"$CLANG" --analyze \
  -std=c89 -pedantic -I"$INCLUDE_DIR" \
  -Xanalyzer -analyzer-checker=core,unix,security,deadcode \
  -Xanalyzer -analyzer-output=plist \
  -o "$RESULTS_DIR/report.plist" \
  "$SOURCE" > "$RESULTS_DIR/plist_stdout.txt" 2> "$RESULTS_DIR/plist_stderr.txt"

# Sažet, deterministički pregled warning redova iz tekstualnog traga.
python3 - "$RESULTS_DIR/sirovi_izlaz.txt" "$RESULTS_DIR/nalazi.tsv" <<'PY'
import re
import sys

src, dst = sys.argv[1:]
pattern = re.compile(r'^(.*?):(\d+):(\d+): warning: (.*?) \[([^]]+)\]$')
rows = []
with open(src, encoding='utf-8') as handle:
    for line in handle:
        match = pattern.match(line.rstrip('\n'))
        if match:
            path, line_no, column, message, checker = match.groups()
            rows.append((checker, line_no, column, message))
with open(dst, 'w', encoding='utf-8', newline='') as handle:
    handle.write('checker\tlinija\tkolona\tporuka\n')
    for row in rows:
        handle.write('\t'.join(row) + '\n')
print('Clang Static Analyzer: sačuvano nalaza:', len(rows))
PY
