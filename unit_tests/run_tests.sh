#!/usr/bin/env bash
# -e prekida skriptu kada komanda vrati gresku.
# -u prijavljuje gresku pri koriscenju nedefinisane promenljive.
# pipefail prijavljuje neuspeh ako bilo koja komanda u pipeline-u ne uspe.
set -euo pipefail

# Sve putanje izvodimo iz lokacije ove skripte, pa se skripta moze pokrenuti
# iz bilo kog trenutnog direktorijuma.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RESULTS_DIR="$SCRIPT_DIR/results"

# Izvrsni test i izlazni artefakti merenja pokrivenosti.
TEST_BINARY="$BUILD_DIR/test_json_parser"
RAW_COVERAGE="$BUILD_DIR/coverage-raw.info"
FILTERED_COVERAGE="$BUILD_DIR/coverage-json-parser.info"
HTML_DIR="$BUILD_DIR/coverage-html"

# Pre rada proveravamo da li su kompajler i oba lcov programa dostupni u PATH-u.
for command_name in gcc lcov genhtml; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Nedostaje obavezna komanda: $command_name" >&2
        exit 2
    fi
done

# Opcije u nastavku zahtevaju lcov 2.x; iz teksta verzije izdvajamo glavni broj.
lcov_major="$(lcov --version | sed -n 's/.*version \([0-9][0-9]*\).*/\1/p')"
if [ -z "$lcov_major" ] || [ "$lcov_major" -lt 2 ]; then
    echo "Potrebna je lcov verzija 2.0 ili novija." >&2
    exit 2
fi

# Svako pokretanje pocinje od cistog build direktorijuma, dok results ostaje
# mesto na kom cuvamo tekstualne rezultate pogodne za verzionisanje.
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RESULTS_DIR"

echo "Prevodjenje testova sa coverage instrumentacijom..."
cd "$REPO_ROOT"
# Opcije kompajlera:
# -std=c89          bira C89 standard;
# -ansi             ukljucuje strogi ANSI C rezim;
# -Wall             ukljucuje osnovni skup upozorenja;
# -Wextra           ukljucuje dodatna upozorenja;
# -Wpedantic        upozorava na odstupanja od izabranog C standarda;
# -Werror           svako upozorenje pretvara u gresku pri prevodjenju;
# -pedantic         zahteva strogo postovanje izabranog C standarda;
# -pedantic-errors  pedantic upozorenja pretvara u greske;
# -O0               iskljucuje optimizacije radi jasnijeg coverage rezultata;
# -g                dodaje debug informacije u izvrsni fajl;
# --coverage        instrumentise program i generise podatke za gcov/lcov;
# -D_ANSI_SOURCE    definise makro koji aktivira ANSI granu izvornog koda;
# -DJSON_TRACK_SOURCE definise makro koji dodaje line i col polja u json_value;
# -Ijson-parser     dodaje json-parser/ u putanje za pronalazenje json.h;
# json-parser/json.c je originalna implementacija koju analiziramo;
# unit_tests/test_json_parser.c je nas testni program;
# -lm               linkuje matematicku biblioteku;
# -o "$TEST_BINARY" zadaje putanju i ime izlaznog testnog programa.
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
# 2>&1 spaja standardni izlaz i greske; tee ih prikazuje i cuva u fajlu.
"$TEST_BINARY" 2>&1 | tee "$RESULTS_DIR/izlaz-testova.txt"

echo "Reprodukcija poznatih odstupanja..."
# Poznati nalazi namerno vracaju neuspeh. Privremeno gasimo -e da bismo
# sacuvali status i proverili da li su reprodukovana bas sva tri nalaza.
set +e
"$TEST_BINARY" --poznati-nalazi \
    >"$RESULTS_DIR/poznati-nalazi.txt" 2>&1
known_status=$?
set -e

# Prikazujemo sacuvani izlaz, pa zatim strogo proveravamo ocekivane oznake.
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
# --capture cita .gcda/.gcno podatke koje je napravio program preveden sa
# --coverage. branch_coverage ukljucuje i pokrivenost grana.
lcov --capture \
    --directory "$BUILD_DIR" \
    --output-file "$RAW_COVERAGE" \
    --rc branch_coverage=1 \
    --ignore-errors mismatch

# Iz sirovog izvestaja zadrzavamo samo originalni json.c, ne testni kod.
lcov --extract "$RAW_COVERAGE" '*/json-parser/json.c' \
    --output-file "$FILTERED_COVERAGE" \
    --rc branch_coverage=1 \
    --ignore-errors unused

# Od filtriranih podataka pravimo pregledan lokalni HTML izvestaj.
genhtml "$FILTERED_COVERAGE" \
    --output-directory "$HTML_DIR" \
    --branch-coverage \
    --title "json-parser - pokrivenost jedinicnim testovima" \
    >/dev/null

# U tekstualni sazetak upisujemo verzije alata i line/function/branch metrike;
# tee istovremeno prikazuje isti sadrzaj u terminalu.
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
# index.html je ulazna stranica detaljnog izvestaja po linijama izvornog koda.
echo "HTML izvestaj: $HTML_DIR/index.html"
