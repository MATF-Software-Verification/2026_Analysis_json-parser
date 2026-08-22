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

Dobijeni su `libjsonparser.a` i `libjsonparser.so`.
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

## 11. Zaključak

Početna provera i dodatni jedinični testovi potvrđuju da se izabrani commit prevodi i da prolazi 69 standardnih provera javnog API-ja i DOM reprezentacije. Dodatni testovi ostvaruju 80,9% pokrivenosti linija i 67,9% pokrivenosti grana u `json.c`.

Istovremeno su reprodukovana tri funkcionalna odstupanja: prihvatanje završnog zareza u objektu i nizu, kao i neispravno praćenje kolone uz `JSON_TRACK_SOURCE`. Konačni zaključak o kvalitetu i memorijskoj bezbednosti biblioteke biće izveden tek nakon sprovođenja preostalih dinamičkih i statičkih analiza.
