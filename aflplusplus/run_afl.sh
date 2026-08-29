#!/usr/bin/env bash

# Reproduktivna AFL++ coverage-guided fuzzing kampanja nad json-parser-om.
#
# Pipeline ima tri koraka:
#   1. priprema čistog seed korpusa;
#   2. prevođenje upstream parsera i našeg harnessa sa AFL++ instrumentacijom;
#   3. vremenski ograničeno pokretanje afl-fuzz-a i čuvanje dokaza.

# -e: prekid pri neuspehu komande.
# -u: greška pri korišćenju nedefinisane promenljive.
# pipefail: pipeline pada ako padne bilo koja njegova komanda.
set -euo pipefail

# Apsolutne putanje računaju se iz lokacije skripte, pa pokretanje ne zavisi
# od trenutnog radnog direktorijuma korisnika.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
CORPUS_DIR="$BUILD_DIR/corpus"
RESULTS_DIR="$SCRIPT_DIR/results"
FUZZ_BINARY="$BUILD_DIR/fuzz_harness"

# Korisnik može promeniti trajanje, npr. FUZZ_SECONDS=30 ./run_afl.sh.
# Ako promenljiva nije zadata, kampanja traje 60 sekundi.
FUZZ_SECONDS="${FUZZ_SECONDS:-60}"

# Potrebne su dve različite AFL++ komponente:
#   afl-clang-fast - Clang wrapper koji dodaje coverage instrumentaciju;
#   afl-fuzz       - zaseban proces koji mutira ulaze i upravlja kampanjom.
for cmd in afl-clang-fast afl-fuzz; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Nedostaje obavezna komanda: $cmd" >&2
        exit 2
    fi
done

# Svako pokretanje dobija čist build, početni korpus i findings kampanju.
# Bez čišćenja findings/ afl-fuzz može odbiti da prepiše staru sesiju ili je
# nastaviti, što bi pomešalo statistike dva pokretanja. Dokumentovani tekstualni
# rezultati ostaju do trenutka kada ih novo pokretanje prepiše.
rm -rf "$BUILD_DIR" "$RESULTS_DIR/findings"
mkdir -p "$CORPUS_DIR" "$RESULTS_DIR"

# U corpus/ se kopiraju isključivo početni JSON dokumenti. Executable se čuva
# jedan nivo iznad, kako nikada ne bi bio pogrešno protumačen kao fuzzing seed.
cp "$SCRIPT_DIR"/seed-corpus/* "$CORPUS_DIR"/
cd "$REPO_ROOT"

echo "Prevodjenje harnessa sa AFL++ instrumentacijom..."

# afl-clang-fast prevodi originalni json.c i analysis-owned fuzz_harness.c:
# -std=c89                 - upstream je ANSI C/C89 biblioteka;
# -Wall/-Wextra/-Wpedantic - širok skup compiler upozorenja;
# -Werror                  - upozorenja tretira kao build greške;
# -O1                      - umerena optimizacija uz čitljive tragove;
# -g                       - debug simboli za eventualni crash;
# -D_ANSI_SOURCE           - aktivira ANSI grane upstream koda;
# -Ijson-parser            - omogućava pronalaženje json.h;
# -lm                      - linkuje matematičku biblioteku zbog pow().
afl-clang-fast -std=c89 -Wall -Wextra -Wpedantic -Werror \
    -O1 -g \
    -D_ANSI_SOURCE -Ijson-parser \
    json-parser/json.c aflplusplus/fuzz_harness.c -lm \
    -o "$FUZZ_BINARY"

echo "Pokretanje AFL++ fuzzing-a ($FUZZ_SECONDS sekundi)..."

# Neuspešan exit status afl-fuzz-a prvo se mora sačuvati i protumačiti, pa se
# strogi `-e` privremeno isključuje. Posle komande odmah se ponovo uključuje.
set +e

# AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES zaobilazi Linux core_pattern proveru
# kada sistem šalje core dump drugom servisu; to može otežati razlikovanje
# crash-a od timeout-a, pa se ograničenje dokumentuje u rezultatima.
# AFL_SKIP_CRASHES dozvoljava da se eventualni crashujući početni seed preskoči
# tokom dry-run faze; ne znači da se novi crash-evi kampanje ne čuvaju.
# AFL_SKIP_CPUFREQ preskače Linux proveru CPU governor-a, bez root izmene sistema.
# Opcije afl-fuzz komande:
# -i: čist seed korpus; -o: direktorijum kampanje; -V: ukupno trajanje;
# -t: timeout jednog izvršavanja; -m none: bez dodatnog memory limita;
# --: kraj AFL++ opcija i početak komande ciljnog programa.
# stdout i stderr se spajaju u izlaz.txt kao sirovi dokaz kampanje.
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
AFL_SKIP_CRASHES=1 \
AFL_SKIP_CPUFREQ=1 \
afl-fuzz -i "$CORPUS_DIR" -o "$RESULTS_DIR/findings" \
    -V "$FUZZ_SECONDS" \
    -t 5000 \
    -m none \
    -- "$FUZZ_BINARY" \
    >"$RESULTS_DIR/izlaz.txt" 2>&1
status=$?
set -e

echo "AFL++ je zavrsio sa statusom $status."

# sazetak.txt čuva verzije, trajanje, završnu AFL++ statistiku i broj stvarnih
# id:* artefakata. `tee` istovremeno prikazuje i upisuje sažetak.
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
    grep -E 'cycles|total_crashes|unique_crashes|total_hangs|unique_hangs|saved_crashes|total_execs|execs_per_sec' "$RESULTS_DIR/izlaz.txt" || true
    echo
    # Broje se samo AFL++ test-case fajlovi, ne README ili drugi metapodaci.
    echo "Crashes: $(find "$RESULTS_DIR/findings/default/crashes" -maxdepth 1 -type f -name 'id:*' 2>/dev/null | wc -l)"
    echo "Hangs: $(find "$RESULTS_DIR/findings/default/hangs" -maxdepth 1 -type f -name 'id:*' 2>/dev/null | wc -l)"
    echo "Queue: $(find "$RESULTS_DIR/findings/default/queue" -maxdepth 1 -type f -name 'id:*' 2>/dev/null | wc -l)"
} | tee "$RESULTS_DIR/sazetak.txt"