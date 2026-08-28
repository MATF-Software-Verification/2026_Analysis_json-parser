#!/usr/bin/env bash

# -e prekida skriptu kada komanda vrati gresku.
# -u prijavljuje gresku pri koriscenju nedefinisane promenljive.
# pipefail prijavljuje neuspeh ako bilo koja komanda u pipeline-u ne uspe.
set -euo pipefail

# SCRIPT_DIR je apsolutna putanja direktorijuma u kojem se nalazi ova skripta.
# REPO_ROOT je koren seminarskog repozitorijuma, jedan nivo iznad skripte.
# Zato se skripta moze pokrenuti iz bilo kog trenutnog direktorijuma.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# build/ sadrzi generisane izvrsne programe i ne cuva se kao rezultat analize.
# results/ sadrzi Memcheck izvestaje, izlaze testova i sazetak za dokumentovanje.
BUILD_DIR="$SCRIPT_DIR/build"
RESULTS_DIR="$SCRIPT_DIR/results"
UNIT_BINARY="$BUILD_DIR/test_json_parser"
UPSTREAM_BINARY="$BUILD_DIR/upstream_tests"

# Provera preduslova pre brisanja ili pravljenja bilo kog artefakta:
# - gcc prevodi parser i oba testna programa;
# - git cita tacan commit analiziranog submodula;
# - valgrind pokrece Memcheck analizu.
# Status 2 oznacava da okruzenje nije spremno za analizu.
for command_name in gcc git valgrind; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Nedostaje obavezna komanda: $command_name" >&2
        exit 2
    fi
done

# Svako pokretanje pocinje cistim build direktorijumom kako stari executable
# fajlovi ne bi bili pogresno predstavljeni kao rezultat trenutnog build-a.
# Sacuvani tekstualni rezultati se zatim osvezavaju u results/ direktorijumu.
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RESULTS_DIR"
cd "$REPO_ROOT"

echo "Prevodjenje dodatnih i upstream testova..."

# Prvi executable povezuje originalni json.c sa nasim dodatnim testovima.
# Opcije prevodjenja:
# -std=c89 i -ansi zahtevaju ANSI C89;
# -Wall, -Wextra i -Wpedantic ukljucuju stroge grupe upozorenja;
# -Werror, -pedantic i -pedantic-errors ne dozvoljavaju da upozorenja i
# odstupanja od standarda budu zanemarena;
# -O0 iskljucuje optimizacije da izvrsavanje ostane blisko izvornom kodu;
# -g dodaje debug simbole koje Memcheck koristi za imena funkcija i linije;
# -D_ANSI_SOURCE bira ANSI granu originalnog parsera;
# -DJSON_TRACK_SOURCE ukljucuje pracenje reda i kolone u DOM cvorovima;
# -Ijson-parser omogucava pronalazenje javnog zaglavlja json.h;
# json-parser/json.c je originalna implementacija koja se analizira;
# unit_tests/test_json_parser.c je nas dodatni testni program;
# -lm povezuje matematicku biblioteku;
# -o "$UNIT_BINARY" zadaje putanju generisanog executable fajla.
gcc -std=c89 -ansi -Wall -Wextra -Wpedantic -Werror \
    -pedantic -pedantic-errors -O0 -g \
    -D_ANSI_SOURCE -DJSON_TRACK_SOURCE -Ijson-parser \
    json-parser/json.c unit_tests/test_json_parser.c -lm \
    -o "$UNIT_BINARY"

# Drugi executable povezuje isti originalni json.c sa upstream testovima.
# Koristi iste kljucne uslove build-a, ali testni ulaz dolazi iz originalnog
# json-parser/tests/test.c umesto iz naseg dodatnog testnog programa.
gcc -std=c89 -ansi -Wall -Wpedantic -Werror \
    -pedantic -pedantic-errors -O0 -g \
    -D_ANSI_SOURCE -DJSON_TRACK_SOURCE -Ijson-parser \
    json-parser/json.c json-parser/tests/test.c -lm \
    -o "$UPSTREAM_BINARY"

# Zajednicke Memcheck opcije cuvaju se u Bash nizu da oba skupa testova budu
# analizirana pod istim uslovima:
# --leak-check=full daje detaljan zapis za svako otkriveno curenje;
# --show-leak-kinds=all prikazuje sve kategorije curenja;
# --track-origins=yes trazi poreklo neinicijalizovanih vrednosti;
# --errors-for-leak-kinds odredjuje koje kategorije curenja ulaze u greske;
# --error-exitcode=99 vraca status 99 ako Memcheck pronadje takvu gresku.
VALGRIND_OPTIONS=(
    --leak-check=full
    --show-leak-kinds=all
    --track-origins=yes
    --errors-for-leak-kinds=definite,indirect,possible
    --error-exitcode=99
)

echo "Memcheck nad dodatnim testovima..."

# --log-file odvaja Memcheck dijagnostiku od izlaza samog testnog programa.
# Standardni izlaz testova cuva se u izlaz-jedinicnih-testova.txt.
# Zbog set -e, Memcheck status 99 odmah prekida skriptu.
valgrind "${VALGRIND_OPTIONS[@]}" \
    --log-file="$RESULTS_DIR/memcheck-jedinicni-testovi.txt" \
    "$UNIT_BINARY" >"$RESULTS_DIR/izlaz-jedinicnih-testova.txt"

echo "Memcheck nad upstream testovima..."

# Upstream test se pokrece iz json-parser/tests jer relativnim putanjama cita
# valid-*.json, invalid-*.json i ostale testne ulaze iz tog direktorijuma.
# Zagrade stvaraju subshell, pa promena direktorijuma ne utice na ostatak
# skripte. Ovde se i stdout i stderr test programa cuvaju u istom fajlu.
(
    cd "$REPO_ROOT/json-parser/tests"
    valgrind "${VALGRIND_OPTIONS[@]}" \
        --log-file="$RESULTS_DIR/memcheck-upstream-testovi.txt" \
        "$UPSTREAM_BINARY" \
        >"$RESULTS_DIR/izlaz-upstream-testova.txt" 2>&1
)

# Zavrsni blok pravi kratak, citljiv sazetak bez izmene sirovih izvestaja:
# - belezi verzije Valgrind-a i GCC-a;
# - belezi tacan commit originalnog json-parser submodula;
# - grep izdvaja stanje heap-a, broj alokacija i ERROR SUMMARY.
# tee istovremeno prikazuje sazetak u terminalu i cuva ga u results/sazetak.txt.
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

# Do ove poruke se stize samo ako su build, oba testa, oba Memcheck pokretanja
# i pravljenje sazetka zavrsili uspesno.
echo "Valgrind Memcheck analiza je zavrsena bez prijavljenih gresaka."
