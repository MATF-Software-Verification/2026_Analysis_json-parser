#!/bin/sh
# Reproduktivno pokretanje Clang Static Analyzer-a nad json-parser/json.c.
#
# Ulaz je originalni upstream fajl json-parser/json.c, a svi generisani
# artefakti se čuvaju u clang_static_analyzer/results/. Skripta ne menja
# analizirani izvorni kod i ne pravi izvršni program: Analyzer simbolički
# prati moguće putanje direktno kroz C izvor.

# -e: prekid pri prvoj neuspešnoj komandi.
# -u: greška ako se upotrebi nedefinisana shell promenljiva.
set -eu

# Apsolutne putanje se računaju iz lokacije same skripte, pa pokretanje ne
# zavisi od trenutnog radnog direktorijuma korisnika.
# CDPATH= sprečava da korisnički CDPATH promeni ponašanje ili ispis komande cd.
# `cd --` označava kraj opcija, a `pwd` vraća apsolutnu putanju.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

# Analizira se samo upstream implementacija. Include direktorijum je potreban
# da bi Clang pri obradi json.c pronašao odgovarajući json.h.
SOURCE="$REPO_DIR/json-parser/json.c"
INCLUDE_DIR="$REPO_DIR/json-parser"
RESULTS_DIR="$SCRIPT_DIR/results"

# CLANG se može zadati spolja, npr.
# CLANG=/opt/homebrew/opt/llvm/bin/clang sh run_analysis.sh
# Ako nije zadat, koristi se `clang` pronađen preko PATH-a.
CLANG=${CLANG:-clang}

# -p dozvoljava da direktorijum već postoji i pravi nedostajuće roditelje.
mkdir -p "$RESULTS_DIR"

# okruzenje.txt čuva tačnu komandu i verziju Clang-a. Time se kasnije može
# utvrditi kojim toolchain-om i na kojoj platformi je rezultat reprodukovan.
{
  printf 'Komanda: %s --analyze -std=c89 -pedantic -I%s -Xanalyzer -analyzer-checker=core,unix,security,deadcode -Xanalyzer -analyzer-output=text %s\n\n' "$CLANG" "$INCLUDE_DIR" "$SOURCE"
  "$CLANG" --version
} > "$RESULTS_DIR/okruzenje.txt"

# Prvi prolaz proizvodi tekstualni trag namenjen čitanju i diff-u.
#
# --analyze: pokreće Static Analyzer umesto običnog prevođenja.
# -std=c89: analizira kod u standardu za koji je upstream biblioteka pisana.
# -pedantic: prijavljuje odstupanja od izabranog jezičkog standarda.
# -I: dodaje direktorijum u kome se traži json.h.
# -Xanalyzer: narednu opciju prosleđuje direktno Static Analyzer-u.
# -analyzer-checker=... uključuje četiri grupe provera:
#   core     - osnovne programske greške (NULL, tok vrednosti i slično),
#   unix     - greške povezane sa Unix/POSIX API-jima,
#   security - potencijalno nebezbedne operacije, poput neograničenog strcpy,
#   deadcode - upise čije se vrednosti nikada ne pročitaju.
# -analyzer-output=text: zapisuje čoveku čitljiv trag putanje do upozorenja.
# `> ... 2>&1` spaja standardni izlaz i standardni izlaz za greške u jedan
# dokazni fajl, jer Clang dijagnostiku uobičajeno ispisuje na stderr.
"$CLANG" --analyze \
  -std=c89 -pedantic -I"$INCLUDE_DIR" \
  -Xanalyzer -analyzer-checker=core,unix,security,deadcode \
  -Xanalyzer -analyzer-output=text \
  "$SOURCE" > "$RESULTS_DIR/sirovi_izlaz.txt" 2>&1

# Drugi prolaz ponavlja istu analizu, ali pravi PLIST: mašinski čitljiv XML
# izveštaj sa lokacijama, checker imenima i simboličkim putanjama nalaza.
# Opcija -o određuje izlazni fajl. stdout i stderr se čuvaju odvojeno da
# pomoćna dijagnostika ne bi završila unutar report.plist:
#   plist_stdout.txt - običan stdout (normalno je prazan),
#   plist_stderr.txt - upozorenja i napomene ispisane tokom PLIST prolaza.
# Zbog toga postojanje plist_stderr.txt nije samo po sebi neuspeh analize.
"$CLANG" --analyze \
  -std=c89 -pedantic -I"$INCLUDE_DIR" \
  -Xanalyzer -analyzer-checker=core,unix,security,deadcode \
  -Xanalyzer -analyzer-output=plist \
  -o "$RESULTS_DIR/report.plist" \
  "$SOURCE" > "$RESULTS_DIR/plist_stdout.txt" 2> "$RESULTS_DIR/plist_stderr.txt"

# Poslednji korak iz tekstualnog traga izdvaja samo završne warning redove u
# mali TSV sažetak. Python dobija dve putanje kao argumente: izvor i odredište.
# Quoted heredoc oznaka <<'PY' sprečava shell da proširuje `$`, backslash i
# druge znakove unutar Python programa.
python3 - "$RESULTS_DIR/sirovi_izlaz.txt" "$RESULTS_DIR/nalazi.tsv" <<'PY'
import re
import sys

# sys.argv[1] je sirovi_izlaz.txt, a sys.argv[2] je nalazi.tsv.
src, dst = sys.argv[1:]

# Hvata: putanju, liniju, kolonu, poruku i checker iz standardnog Clang
# warning formata. Ostale note i delovi simboličke putanje se ne unose u TSV.
pattern = re.compile(r'^(.*?):(\d+):(\d+): warning: (.*?) \[([^]]+)\]$')
rows = []
with open(src, encoding='utf-8') as handle:
    for line in handle:
        match = pattern.match(line.rstrip('\n'))
        if match:
            path, line_no, column, message, checker = match.groups()
            rows.append((checker, line_no, column, message))
# Fajl se uvek ponovo generiše, pa ne ostaju nalazi iz prethodnog pokretanja.
with open(dst, 'w', encoding='utf-8', newline='') as handle:
    handle.write('checker\tlinija\tkolona\tporuka\n')
    for row in rows:
        handle.write('\t'.join(row) + '\n')
print('Clang Static Analyzer: sačuvano nalaza:', len(rows))
PY
