# Analiza projekta json-parser

Praktični seminarski rad iz predmeta **Verifikacija softvera** na Matematičkom fakultetu Univerziteta u Beogradu.

## Autor

- Miloš Kutlešić
- broj indeksa: 1046/2022

## Analizirani projekat

- projekat: [json-parser/json-parser](https://github.com/json-parser/json-parser)
- opis: DOM JSON parser napisan u prenosivom ANSI C/C89
- analizirana grana: `master`
- analizirani commit: `8ac4477ad3e63dc107e17ad49484edaa17d18d35`
- lokalna referenca: Git submodule `json-parser/`

## Priprema projekta

```bash
git clone --recurse-submodules <URL-OVOG-REPOZITORIJUMA>
cd 2026_Analysis_json-parser
```

Ako je repozitorijum već kloniran bez submodula:

```bash
git submodule update --init --recursive
```

Pre pokretanja analiza proveriti da je submodule na analiziranom commit-u:

```bash
git submodule status
```

Očekivani rezultat počinje sa:

```text
 8ac4477ad3e63dc107e17ad49484edaa17d18d35 json-parser
```

Početni razmak znači da je submodule na očekivanom commit-u. Znak `-` znači da submodule nije inicijalizovan, dok `+` znači da je trenutno izabran drugi commit.

## Početna provera

```bash
cd json-parser
./configure
make clean
make
```

Provera napravljenih biblioteka:

```bash
# macOS
file libjsonparser.a libjsonparser.dylib

# Linux
file libjsonparser.a libjsonparser.so
```

Na macOS-u `file` treba da prepozna `.dylib`, a na Linux-u `.so` deljenu biblioteku.

Zatim se prevodi upstream test program:

```bash
cc -std=c89 -ansi -Wall -Wpedantic -Werror \
  -pedantic -pedantic-errors -D_ANSI_SOURCE \
  -DJSON_TRACK_SOURCE -I. json.c tests/test.c -lm -o json-test
```

Provera napravljenog test programa:

```bash
file json-test
```

Na macOS-u očekuje se `Mach-O 64-bit executable` (na Apple Silicon-u `arm64`), dok se na Linux-u očekuje ELF izvršni fajl.

Upstream testovi se pokreću iz direktorijuma `tests/`, jer program tamo traži ulazne JSON fajlove:

```bash
(cd tests && ../json-test)
echo $?
```

Zagrade čuvaju trenutni direktorijum: po završetku ostajemo u `json-parser/`. Izlazni kod `0` znači da su upstream testovi uspešno završeni.

Početna provera na neizmenjenom analiziranom commit-u uspešno prevodi statičku biblioteku `libjsonparser.a` i deljenu biblioteku (`libjsonparser.so` na Linux-u ili `libjsonparser.dylib` na macOS-u), a zatim izvršava postojeći C test program bez neuspešnih provera.

## Izabrane tehnike

Analiza će koristiti sledećih šest tehnika:

1. jedinične testove uz merenje pokrivenosti pomoću `lcov`-a;
2. dinamičku analizu memorije pomoću Valgrind Memcheck-a;
3. fuzz testiranje pomoću LLVM `libFuzzer`-a;
4. statičku analizu pomoću Clang Static Analyzer-a;
5. coverage-guided fuzz testiranje pomoću AFL++ — alat koji nije obrađen na vežbama;
6. statičku analizu pomoću `cppcheck`-a — alat koji nije obrađen na vežbama.

`lcov` je podrška jediničnim testovima i ne računa se kao zasebna tehnika. CodeQL i CBMC ostaju opcioni rezervni alati i neće se računati među šest tehnika bez zasebno sprovedene i dokumentovane analize.

Za svaki alat biće dodat poseban direktorijum sa skriptom za reprodukciju, rezultatima i objašnjenjem.

## Reprodukcija sprovedenih analiza

### 1. Jedinični testovi i pokrivenost

```bash
./unit_tests/run_tests.sh
```

69/69 provera prolazi; pokrivenost `json.c` 80,9% linija, 100,0% funkcija, 67,9% grana. Detalji: [`unit_tests/Rezultati.md`](unit_tests/Rezultati.md).

### 2. Valgrind Memcheck

```bash
sudo apt-get install -y gcc valgrind
./valgrind/run_memcheck.sh
```

0 grešaka, 0 curenja memorije na oba skupa testova. Detalji: [`valgrind/Rezultati.md`](valgrind/Rezultati.md).

Sačuvani rezultat dobijen je na Linux-u. Valgrind nema zvaničnu podršku za savremeni Apple Silicon (`arm64`) macOS, pa ova tehnika nije predviđena za lokalnu reprodukciju na tom računaru.

### 3. LLVM libFuzzer

Ubuntu/Debian:

```bash
sudo apt-get install -y clang
./libfuzzer/run_libfuzzer.sh
```

macOS (Homebrew LLVM, jer Apple Clang ne isporučuje fuzzer runtime):

```bash
brew install llvm
./libfuzzer/run_libfuzzer.sh
```

Pronađen potvrđen UBSan nalaz: aritmetika nad NULL pokazivačem u prvom prolazu (`json.c:437`) kada su komentari uključeni. Nalaz je reprodukovan na Linux-u (Ubuntu Clang 18.1.3) i lokalno na Apple Silicon macOS-u (Homebrew LLVM Clang 23.1.0), sa identičnim 24-bajtnim reprodukcionim ulazom. Detalji: [`libfuzzer/Rezultati.md`](libfuzzer/Rezultati.md).

### 4. Clang Static Analyzer

```bash
sudo apt-get install -y clang
./clang_static_analyzer/run_analysis.sh
```

3 nalaza: mrtav upis i dva neograničena `strcpy`. Detalji: [`clang_static_analyzer/Rezultati.md`](clang_static_analyzer/Rezultati.md).

### 5. AFL++

```bash
sudo apt-get install -y afl++
./aflplusplus/run_afl.sh
```

30-sekundno pokretanje: 0 crash-eva, 0 hang-ova, 75,08% coverage. Detalji: [`aflplusplus/Rezultati.md`](aflplusplus/Rezultati.md).

### 6. cppcheck

```bash
sudo apt-get install -y cppcheck
./cppcheck/run_cppcheck.sh
```

0 nalaza u kategorijama error, warning, performance i portability. Detalji: [`cppcheck/Rezultati.md`](cppcheck/Rezultati.md).

## Zaključci

- Dodatni skup je uspešno izvršio 69/69 standardnih provera javnog API-ja, DOM stabla, podešavanja i memorijskih putanja.
- Ostvarena je pokrivenost od 80,9% linija, 100,0% funkcija i 67,9% grana u `json.c`.
- Valgrind Memcheck nije pronašao curenja memorije ni neispravne pristupe na izvršenim putanjama.
- libFuzzer sa UBSan je pronašao potvrđeno nedefinisano ponašanje: aritmetiku nad NULL pokazivačem u prvom prolazu parsera (`json.c:437`) kada su komentari uključeni.
- Clang Static Analyzer je pronašao mrtav upis i dva neograničena `strcpy` poziva.
- AFL++ nije pronašao crash-eve niti hang-ove u 30-sekundnom pokretanju bez sanitizera.
- cppcheck nije pronašao nalaze u kategorijama error, warning, performance i portability.
- Parser prihvata završni zarez u objektu i nizu, što odstupa od gramatike RFC 8259.
- Opcija `JSON_TRACK_SOURCE` ispravno prati red, ali kolona ostaje nula jer se interni brojač kolone ne uvećava.

Detaljan opis se nalazi u fajlu [`ProjectAnalysisReport.md`](ProjectAnalysisReport.md).
