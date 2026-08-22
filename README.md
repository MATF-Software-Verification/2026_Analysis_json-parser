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

## Početna provera

```bash
cd json-parser
./configure
make clean
make
cc -std=c89 -ansi -Wall -Wpedantic -Werror \
  -pedantic -pedantic-errors -D_ANSI_SOURCE \
  -DJSON_TRACK_SOURCE -I. json.c tests/test.c -lm -o json-test
(cd tests && ../json-test)
```

Početna provera na neizmenjenom analiziranom commit-u uspešno prevodi statičku i deljenu biblioteku i izvršava postojeći C test program bez neuspešnih provera.

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

## Zaključci

Zaključci će biti dopunjavani nakon svake završene i reprodukovane analize. Detaljan opis će se nalaziti u fajlu [`ProjectAnalysisReport.md`](ProjectAnalysisReport.md).
