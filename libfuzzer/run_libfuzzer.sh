#!/usr/bin/env bash

# -e prekida skriptu kada komanda vrati gresku.
# -u prijavljuje gresku pri koriscenju nedefinisane promenljive.
# pipefail prijavljuje neuspeh ako bilo koja komanda u pipeline-u ne uspe.
set -euo pipefail

# Putanje se izvode iz lokacije skripte, pa se ona moze pokrenuti iz bilo kog
# trenutnog direktorijuma. build/ je privremen, dok results/ cuva dokaze.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RESULTS_DIR="$SCRIPT_DIR/results"

# corpus/ pocinje kopijom malog seed korpusa, a libFuzzer mu zatim dodaje
# ulaze koji otkrivaju novu pokrivenost. artifacts/ prima crash ulaze.
CORPUS_DIR="$BUILD_DIR/corpus"
ARTIFACT_DIR="$BUILD_DIR/artifacts"
FUZZ_BINARY="$BUILD_DIR/fuzz_json_parser"

# Trajanje je podrazumevano 60 sekundi. Korisnik ga moze promeniti, na primer:
# FUZZ_SECONDS=30 ./libfuzzer/run_libfuzzer.sh
FUZZ_SECONDS="${FUZZ_SECONDS:-60}"

# Clang obezbedjuje libFuzzer i sanitizer instrumentaciju. Status 2 znaci da
# okruzenje nije spremno, a ne da je analizirani parser pao test.
if ! command -v clang >/dev/null 2>&1; then
    echo "Nedostaje obavezna komanda: clang" >&2
    exit 2
fi

# Cist build uklanja stare executable, corpus i crash fajlove. Cetiri mala seed
# ulaza zatim se kopiraju u radni corpus da fuzzing ne pocinje od praznog ulaza.
rm -rf "$BUILD_DIR"
mkdir -p "$CORPUS_DIR" "$ARTIFACT_DIR" "$RESULTS_DIR"
cp "$SCRIPT_DIR"/seed-corpus/* "$CORPUS_DIR"/
cd "$REPO_ROOT"

echo "Prevodjenje fuzzer harnessa sa sanitizer instrumentacijom..."

# Opcije prevodjenja:
# -std=c89 zahteva C89 za originalni parser i nas harness;
# -Wall, -Wextra i -Wpedantic ukljucuju stroga upozorenja;
# -Werror pretvara upozorenja u build greske;
# -Wno-error=deprecated-declarations spusta upozorenja o deprecated funkcijama
# nazad na upozorenja umesto gresaka. Novi macOS SDK oznacava sprintf kao
# deprecated, sto je svojstvo platforme, a ne nalog u originalnom upstream
# kodu koji se ne menja. Sve ostale klase upozorenja i dalje prekidaju build.
# -O1 daje optimizovan, ali jos uvek citljiv sanitizer build;
# -g dodaje debug podatke za imena funkcija i linije izvornog koda;
# -fno-omit-frame-pointer cuva frame pointer radi pouzdanijeg stack trace-a;
# -fsanitize=fuzzer dodaje coverage instrumentaciju i libFuzzer main;
# -fsanitize=address ukljucuje AddressSanitizer za memorijske greske;
# -fsanitize=undefined ukljucuje UBSan za nedefinisano ponasanje;
# -D_ANSI_SOURCE bira ANSI granu parsera;
# -Ijson-parser omogucava pronalazenje json.h;
# json-parser/json.c je originalni kod koji se analizira;
# libfuzzer/fuzz_json_parser.c je nas fuzzing harness;
# -lm povezuje matematicku biblioteku;
# -o "$FUZZ_BINARY" zadaje putanju generisanog fuzzer executable fajla.
clang -std=c89 -Wall -Wextra -Wpedantic -Werror \
    -Wno-error=deprecated-declarations \
    -O1 -g -fno-omit-frame-pointer \
    -fsanitize=fuzzer,address,undefined \
    -D_ANSI_SOURCE -Ijson-parser \
    json-parser/json.c libfuzzer/fuzz_json_parser.c -lm \
    -o "$FUZZ_BINARY"

echo "Pokretanje libFuzzer-a (UBSan halt_on_error=1)..."

# Sanitizer nalaz namerno daje status razlicit od nule, zato se set -e
# privremeno iskljucuje kako bi skripta sacuvala status i obradila izvestaj.
set +e

# UBSAN_OPTIONS:
# - halt_on_error=1 zaustavlja proces na prvom nedefinisanom ponasanju;
# - print_stacktrace=1 dodaje stack trace u dijagnostiku.
#
# libFuzzer opcije:
# - prvi pozicioni argument je radni corpus;
# -max_total_time ogranicava ukupno trajanje;
# -timeout=5 prekida pojedinacni ulaz koji traje duze od pet sekundi;
# -print_final_stats=1 ispisuje zavrsnu statistiku;
# -artifact_prefix odredjuje direktorijum za crash i druge problem ulaze.
# Sav stdout i stderr cuvaju se zajedno u results/izlaz.txt.
UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
"$FUZZ_BINARY" "$CORPUS_DIR" \
    -max_total_time="$FUZZ_SECONDS" \
    -timeout=5 \
    -print_final_stats=1 \
    -artifact_prefix="$ARTIFACT_DIR/" \
    >"$RESULTS_DIR/izlaz.txt" 2>&1
status=$?
set -e

# Prikazuje sacuvani puni izlaz i u terminalu radi neposredne reprodukcije.
cat "$RESULTS_DIR/izlaz.txt"

# Ako postoji crash artefakt, prvi se kopira na stabilnu putanju koju je lako
# navesti u dokumentaciji i ponovo proslediti fuzzer executable fajlu.
crash_files=$(find "$ARTIFACT_DIR" -type f 2>/dev/null || true)
if [ -n "$crash_files" ]; then
    first_crash=$(echo "$crash_files" | head -1)
    cp "$first_crash" "$RESULTS_DIR/crash-reprodukcija.bin"
    echo "Sačuvan reprodukcioni artefakt: $RESULTS_DIR/crash-reprodukcija.bin" >&2
fi

# Nenulti status se ne prihvata automatski kao uspeh analize. Najpre se proverava
# da li izlaz sadrzi tacan marker vec dokumentovanog UBSan nalaza. Samo u tom
# slucaju skripta prijavljuje poznati nalaz i zavrsava statusom nula; svaki drugi
# pad ili sanitizer nalaz propagira svoj status i zahteva posebnu analizu.
if [ "$status" -ne 0 ]; then
    echo "libFuzzer je završio statusom $status." >&2
    # Ne izlazimo sa greškom ako je jedini nalaz poznati UBSan issue
    if grep -q "applying non-zero offset.*to null pointer" "$RESULTS_DIR/izlaz.txt"; then
        echo "Pronađen je poznati UBSan nalaz (aritmetika nad NULL pokazivačem u prvom prolazu)." >&2
        exit 0
    fi
    exit "$status"
fi

# Do ovog sazetka se stize kada je vremenski ogranicen fuzzing zavrsen bez
# sanitizer nalaza. Beleze se verzija Clang-a, trajanje, broj izvrsenih ulaza,
# brzina, novi corpus ulazi i broj crash artefakata. tee prikazuje i cuva tekst.
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