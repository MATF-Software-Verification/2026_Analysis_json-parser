# Izveštaj o analizi projekta json-parser

## 1. Podaci o seminarskom radu

- **Autor:** Miloš Kutlešić
- **Broj indeksa:** 1046/2022
- **Predmet:** Verifikacija softvera
- **Tip rada:** analiza projekta otvorenog koda
- **Analizirani projekat:** `json-parser/json-parser`
- **Grana:** `master`
- **Commit:** `8ac4477ad3e63dc107e17ad49484edaa17d18d35`

## 2. Cilj rada

Cilj rada je primena više tehnika verifikacije na malu biblioteku napisanu u programskom jeziku C.
Analiza treba da ispita funkcionalnu ispravnost, bezbednost rada sa memorijom, robusnost prema neočekivanim ulazima i potencijalna uska grla.
Nije cilj samo pokrenuti alate, već protumačiti njihove rezultate i omogućiti njihovu potpunu reprodukciju.

## 3. Opis analiziranog projekta

`json-parser` je DOM parser za JSON napisan u prenosivom ANSI C/C89.
Glavni javni interfejs definisan je u fajlu `json.h`, dok se implementacija parsera nalazi u `json.c`.
Biblioteka iz tekstualnog JSON ulaza formira stablo vrednosti tipova objekat, niz, broj, string, logička vrednost i `null`.
Dobijeno stablo korisnik oslobađa funkcijom `json_value_free`, odnosno odgovarajućom varijantom kada koristi sopstveni alokator.

Analizirani izvorni kod dodat je kao Git submodule u direktorijumu `json-parser/`.
Submodule je zaključan na navedeni commit kako bi svi rezultati ostali ponovljivi čak i ako se upstream grana kasnije promeni.

## 4. Početna provera projekta

Pre izbora konkretnih alata provereno je da se neizmenjena verzija projekta može prevesti i testirati.
Build konfiguracija generisana je zvaničnom skriptom:

```bash
cd json-parser
./configure
```

Zatim su napravljene statička i deljena biblioteka:

```bash
make clean
make
```

Dobijaju se `libjsonparser.a` i deljena biblioteka: `libjsonparser.so` na Linux-u, odnosno `libjsonparser.dylib` na macOS-u.
Prevođenje je završeno bez greške.

## 5. Postojeći test program

Upstream projekat sadrži C test program `tests/test.c` i skup JSON ulaza u direktorijumu `tests/`.
Test program je preveden u strogom C89 režimu komandom:

```bash
cc -std=c89 -ansi -Wall -Wpedantic -Werror \
  -pedantic -pedantic-errors -D_ANSI_SOURCE \
  -DJSON_TRACK_SOURCE -I. json.c tests/test.c \
  -lm -o json-test
```

Testovi su pokrenuti iz direktorijuma koji sadrži ulazne JSON fajlove:

```bash
(cd tests && ../json-test)
```

Program je završio izlaznim kodom `0`.
Nisu prijavljeni neočekivano prihvaćeni nevalidni ulazi, neočekivano odbijeni validni ulazi niti nepodudaranje očekivanog broja test fajlova.
Ovaj rezultat predstavlja početno stanje, a ne dokaz potpune ispravnosti parsera.

## 6. Obim analize

Primarni predmet analize su `json.c`, javni interfejs iz `json.h` i ponašanje funkcija `json_parse`, `json_parse_ex`, `json_value_free` i `json_value_free_ex`. Analiza obuhvata prihvatanje i odbijanje ulaza, izgradnju DOM stabla, obradu brojeva i stringova, ograničenje memorije, prilagođene alokatore i oslobađanje delimično ili potpuno izgrađenog stabla.

Python binding nije deo primarnog obima. Biće razmatran samo ako neki nalaz direktno pokaže da utiče na C biblioteku koja je predmet rada. Originalni projekat se tokom analize ne menja bez reprodukovanog nalaza i zasebno sačuvanog patch-a.

## 7. Početni skup testova

Postojeći test program razvrstava ulaze u četiri grupe:

| Grupa | Broj | Očekivanje |
|---|---:|---|
| `valid-*.json` | 14 | ulaz mora biti prihvaćen u strogom režimu |
| `invalid-*.json` | 11 | ulaz mora biti odbijen u strogom režimu |
| `ext-valid-*.json` | 4 | ulaz sa komentarima mora biti prihvaćen kada je opcija uključena |
| `ext-invalid-*.json` | 3 | neispravan extension ulaz mora biti odbijen |

Validni ulazi obuhvataju korenske proste vrednosti, objekte, nizove, celobrojne i decimalne brojeve, eksponente, Unicode escape sekvence i direktan UTF-8 tekst. Nevalidni ulazi obuhvataju prazan dokument, višak zatvarajućih zagrada, nedostajuće zareze, vodeću nulu, nedovršene literalne vrednosti i neočekivanu zatvarajuću zagradu. Extension testovi proveravaju linijske i blok komentare, komentar na kraju dokumenta, dokument bez vrednosti, nezavršen blok komentar i neispravnu uvodnu sekvencu komentara.

Pored fajlova, `tests/test.c` direktno proverava prazne i obične stringove, escape sekvence, ugrađeni nul-bajt preko `\\u0000` i jedan Unicode surrogate-pair slučaj. Testovi koriste prilagođene funkcije `noisy_alloc` i `noisy_free`, ali njihov ispis nije dokaz da ne postoje curenja ili neispravni memorijski pristupi.

Početni skup uglavnom proverava prihvatanje ili odbijanje dokumenta. Ne proverava sistematski sadržaj kompletnog DOM stabla, sve granice brojčanih tipova, sve putanje neuspešne alokacije, `max_memory`, pokrivenost grana niti robusnost na proizvoljnim binarnim ulazima.

## 8. Verifikaciona svojstva

- **P1:** validan JSON mora biti prihvaćen, a nevalidan odbijen.
- **P2:** tipovi, dužine i vrednosti u DOM stablu moraju odgovarati ulazu.
- **P3:** parser ne sme čitati niti pisati van prosleđene granice ulaza i alociranih blokova.
- **P4:** sve alokacije moraju biti oslobođene na uspešnim i neuspešnim putanjama.
- **P5:** proizvoljan ulaz ne sme izazvati pad, hang ili grešku sanitizera.
- **P6:** brojčani overflow mora biti bezbedno obrađen, uključujući prelazak sa `json_integer` na `json_double`.
- **P7:** `max_memory` i prilagođene funkcije za alokaciju i oslobađanje moraju biti poštovani.
- **P8:** komentari moraju biti odbijeni u strogom režimu, a podržani samo kada je `json_enable_comments` uključen.
- **P9:** greške moraju vratiti `NULL`, upotrebljivu dijagnostiku i ne smeju ostaviti nedostupne alokacije.

## 9. Izbor tehnika

| # | Alat/tehnika | Primarna svojstva | Obrazloženje |
|---:|---|---|---|
| 1 | Jedinični testovi + `lcov` | P1, P2, P6, P7, P8, P9 | dodaju semantičke i granične provere; `lcov` meri line i branch coverage i ne računa se zasebno |
| 2 | Valgrind Memcheck | P3, P4, P9 | traži invalid read/write, use-after-free, double free i curenja memorije |
| 3 | LLVM `libFuzzer` | P3, P5 | coverage-guided generisanje ulaza uz sanitizer instrumentaciju |
| 4 | Clang Static Analyzer | P3, P4, P9 | analizira putanje bez oslanjanja samo na konkretne test ulaze |
| 5 | AFL++ | P3, P5 | nezavisni coverage-guided fuzzer i prvi alat koji nije obrađen na vežbama |
| 6 | `cppcheck` | P3, P4, P6, P9 | dopunska statička analiza C koda i drugi alat koji nije obrađen na vežbama |

Kod `cppcheck` analize fokus će biti na kategorijama `warning`, `error`, `performance` i `portability`, a ne na formatiranju izvornog koda. Time se alat ne koristi kao stilska provera. CodeQL i CBMC ostaju rezervni alati i ne računaju se među šest tehnika bez zasebno reprodukovane analize.

Za svaki usvojeni alat biće sačuvani:

- precizna verzija alata;
- skripta za reprodukciju;
- korišćena konfiguracija i ulazi;
- relevantni sirovi rezultati;
- tumačenje nalaza;
- ograničenja i mogući lažno pozitivni rezultati.

## 10. Rezultati pojedinačnih analiza

### 10.1 Jedinični testovi i `lcov`

Napisan je dodatni C89 test program `unit_tests/test_json_parser.c` sa 69 standardnih provera. Testovi obuhvataju korenske proste vrednosti, ugnježdeno DOM stablo, string i Unicode obradu, nevalidne ulaze i error buffer, eksplicitnu dužinu ulaza, režim komentara, granice brojeva, prilagođeni alokator, `max_memory` i `JSON_TRACK_SOURCE`.

Kompletna analiza reprodukuje se skriptom:

```bash
./unit_tests/run_tests.sh
```

Standardni skup završio je bez neuspeha:

```text
Izvrseno provera: 69
Neuspesnih provera: 0
```

Pokrivenost je merena samo nad `json-parser/json.c`:

| Metrika | Pokriveno | Ukupno | Pokrivenost |
|---|---:|---:|---:|
| Linije | 407 | 503 | 80,9% |
| Funkcije | 10 | 10 | 100,0% |
| Grane | 250 | 368 | 67,9% |

Poseban režim testa reprodukuje tri odstupanja:

1. `{"a":1,}` se prihvata kao objekat iako završni zarez nije deo gramatike [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259);
2. `[1,2,]` se prihvata kao niz iz istog razloga;
3. uz `JSON_TRACK_SOURCE`, čvor dobija odgovarajući red, ali polje `col` ostaje nula.

Prva dva nalaza potiču iz logike koja dozvoljava zatvaranje objekta ili niza neposredno nakon zareza. Treći nalaz potiče od toga što se `cur_col` postavlja i kopira u čvorove, ali se ne uvećava pri prolasku kroz karaktere. Reprodukcioni testovi i detaljno tumačenje nalaze se u [`unit_tests/Rezultati.md`](unit_tests/Rezultati.md).

Ovi nalazi se tretiraju kao reprodukovana funkcionalna odstupanja. Završni zarezi utiču na usklađenost sa standardnom JSON gramatikom, dok kolona utiče na opcionu dijagnostičku funkcionalnost. Za sada nije utvrđen bezbednosni uticaj.

Ovo poglavlje biće dopunjavano nakon završetka svake sledeće analize. Rezultati neće biti proglašavani bezbednosnim bagovima bez dodatne reprodukcije i procene uticaja.

### 10.2 Valgrind Memcheck

Valgrind Memcheck je pokrenut nad dva skupa testova: dodatnim jediničnim testovima i upstream testovima. Skripta koristi `--leak-check=full`, `--show-leak-kinds=all`, `--track-origins=yes` i `--error-exitcode=99`.

Reprodukcija:

```bash
./valgrind/run_memcheck.sh
```

Rezultat: oba skupa završila su bez Memcheck grešaka i bez memorije zauzete na izlazu.

| Skup | Alokacije | Oslobađanja | Greške |
|---|---:|---:|---:|
| Dodatni testovi | 65 | 65 | 0 |
| Upstream testovi | 414 | 414 | 0 |

Čist Memcheck rezultat potvrđuje da na izvršenim putanjama nema curenja niti neispravnih pristupa, ali nije dokaz odsustva svih memorijskih grešaka. Detalji: [`valgrind/Rezultati.md`](valgrind/Rezultati.md).

### 10.3 LLVM libFuzzer

libFuzzer je pokrenut sa AddressSanitizer i UndefinedBehaviorSanitizer instrumentacijom. Harness prosleđuje proizvoljan binarni ulaz parseru u strogom režimu i režimu sa komentarima.

Reprodukcija:

```bash
./libfuzzer/run_libfuzzer.sh
```

**Pronađen potvrđen nalaz:** UBSan prijavljuje nedefinisano ponašanje na liniji 437 `json.c`:

```text
json-parser/json.c:437:34: runtime error: applying non-zero offset 2 to null pointer
```

Uzrok: u prvom prolazu parsera, kada se zatvori string ključ unutar objekta, `top->u.object.values` još uvek nije alociran i iznosi `NULL`. Linija:

```c
chars[0] += string_length + 1;
```

izvršava aritmetiku nad `NULL` pokazivačem, što je nedefinisano ponašanje prema C standardu. Nalaz je reprodukovan deterministički na normalnom JSON dokumentu sa komentarima:

```text
/* komentar */ {"a":1}
```

Sačuvan je minimalni reprodukcioni artefakt `results/crash-reprodukcija.bin` (24 bajta). Bezbednosni uticaj nije utvrđen — rezultat se koristi samo kao akumulator dužine, ne za dereferenciranje. Detalji: [`libfuzzer/Rezultati.md`](libfuzzer/Rezultati.md).

### 10.4 Clang Static Analyzer

Clang Static Analyzer je pokrenut nad `json.c` u C89 konfiguraciji sa checkerima `core,unix,security,deadcode`.

Reprodukcija:

```bash
./clang_static_analyzer/run_analysis.sh
```

Pronađena 3 nalaza:

| # | Lokacija | Checker | Klasifikacija |
|---:|---|---|---|
| 1 | `json.c:683` | `deadcode.DeadStores` | Potvrđen mrtav upis |
| 2 | `json.c:975` | `security.insecureAPI.strcpy` | Neograničeni `strcpy` u `error_buf` |
| 3 | `json.c:977` | `security.insecureAPI.strcpy` | Neograničeni `strcpy` rezervne poruke |

Mrtav upis je suvišna dodela `b = 0` koja se nigde ne čita. Dva `strcpy` nalaza predstavljaju isti API problem: `json_parse_ex` ne prima kapacitet `error_buf`, pa ne može da garantuje bezbedno kopiranje. Detalji: [`clang_static_analyzer/Rezultati.md`](clang_static_analyzer/Rezultati.md).

### 10.5 AFL++

AFL++ je pokrenut kao drugi coverage-guided fuzzer, bez sanitizera, u trajanju od 30 sekundi. Ovo je prvi alat koji nije obrađen na vežbama.

Reprodukcija:

```bash
./aflplusplus/run_afl.sh
```

Rezultat:

| Metrika | Vrednost |
|---|---:|
| Novi korpus elementi | 372 |
| Pokrivenost | 75,08% |
| Crash-eva | 0 |
| Hang-ova | 0 |

AFL++ nije pronašao crash-eve niti hang-ove. Ograničenje: bez sanitizera ne može otkriti UBSan nalaz iz tehnike 3. Detalji: [`aflplusplus/Rezultati.md`](aflplusplus/Rezultati.md).

### 10.6 cppcheck

cppcheck je pokrenut u dve C89 konfiguracije sa fokusom na kategorije `error`, `warning`, `performance` i `portability`. Ovo je drugi alat koji nije obrađen na vežbama.

Reprodukcija:

```bash
./cppcheck/run_cppcheck.sh
```

Rezultat: 0 nalaza u obe konfiguracije. Ručna provera je potvrdila da cppcheck nije otkrio ni poznati UBSan problem iz tehnike 3, što je dokumentovano kao ograničenje statičke analize. Detalji: [`cppcheck/Rezultati.md`](cppcheck/Rezultati.md).

## 11. Zaključak

Sprovedeno je šest tehnika verifikacije nad `json-parser` bibliotekom. Rezultati su:

1. **Jedinični testovi** su prošli 69/69 provera i ostvarili 80,9% line i 67,9% branch coverage. Pronađena su tri funkcionalna odstupanja: završni zarez u objektu i nizu te neispravno praćenje kolone uz `JSON_TRACK_SOURCE`.
2. **Valgrind Memcheck** nije pronašao curenja memorije ni neispravne pristupe na izvršenim putanjama.
3. **libFuzzer** sa UBSan je pronašao potvrđeno nedefinisano ponašanje: aritmetiku nad `NULL` pokazivačem u prvom prolazu parsera (`json.c:437`) kada su komentari uključeni.
4. **Clang Static Analyzer** je pronašao mrtav upis i dva neograničena `strcpy` poziva u error putanji.
5. **AFL++** nije pronašao crash-eve niti hang-ove u 30-sekundnom pokretanju bez sanitizera.
6. **cppcheck** nije pronašao nalaze u ciljanim kategorijama.

Ukupno su pronađena: jedno potvrđeno nedefinisano ponašanje, tri funkcionalna odstupanja od JSON standarda, jedan mrtav upis i dva neograničena `strcpy` poziva. Nije utvrđen direktan bezbednosni uticaj ni memorjska oštećenja. Biblioteka je stabilna na proizvoljnom ulazu, ali sadrži nedefinisano ponašanje koje kompajler i optimizacija mogu iskoristiti na nepredvidiv način.
