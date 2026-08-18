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

## Planirane tehnike

Konačan spisak biće potvrđen nakon početnih eksperimenata. Trenutni kandidati su:

1. jedinični testovi uz merenje pokrivenosti koda (`lcov`);
2. fuzz testiranje pomoću LLVM `libFuzzer`;
3. dinamička analiza memorije pomoću Valgrind Memcheck-a;
4. statička analiza pomoću Clang Static Analyzer-a;
5. fuzz testiranje pomoću AFL++ — alat koji nije obrađen na vežbama;
6. statička bezbednosna analiza pomoću CodeQL-a — alat koji nije obrađen na vežbama;
7. opciono: ograničeno proveravanje modela pomoću CBMC-a.

Za svaki usvojeni alat biće dodat poseban direktorijum sa skriptom za reprodukciju, rezultatima i objašnjenjem.

## Zaključci

Zaključci će biti dopunjavani nakon svake završene i reprodukovane analize. Detaljan opis će se nalaziti u fajlu [`ProjectAnalysisReport.md`](ProjectAnalysisReport.md).
