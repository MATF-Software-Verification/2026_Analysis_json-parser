# Rezultati jediničnih testova i merenja pokrivenosti

## Cilj

Dodatni testovi proveravaju semantički sadržaj DOM stabla, granične slučajeve javnog API-ja, upravljanje prilagođenim alokatorom, ograničenje memorije, režim komentara i informacije o izvornoj lokaciji. Pokrivenost se meri samo nad analiziranim fajlom `json-parser/json.c`.

## Preduslovi

Na Ubuntu/Debian sistemu:

```bash
sudo apt-get update
sudo apt-get install -y gcc lcov
```

Na macOS-u sa Homebrew-om:

```bash
xcode-select --install  # samo ako Command Line Tools vec nisu instalirani
brew install lcov
```

Paket `lcov` obezbeđuje i komandu `genhtml`. Dostupnost alata može se proveriti komandama:

```bash
gcc --version
lcov --version
genhtml --version
```

Potrebna je `lcov` verzija 2.0 ili novija zbog korišćenih opcija za obradu grešaka i branch coverage. Skripta prekida rad jasnom porukom ako je dostupna starija verzija.

Korišćene verzije u dokumentovanom pokretanju:

```text
gcc 13.3.0
lcov 2.0-1
```

## Reprodukcija

Iz korena seminarskog repozitorijuma:

```bash
./unit_tests/run_tests.sh
```

Skripta:

1. prevodi `json.c` i `test_json_parser.c` u strogom C89 režimu;
2. uključuje `JSON_TRACK_SOURCE` i GCC coverage instrumentaciju;
3. pokreće standardni skup testova;
4. odvojeno reprodukuje dokumentovana odstupanja;
5. prikuplja line, function i branch coverage pomoću `lcov`-a;
6. generiše lokalni HTML izveštaj u ignorisanom direktorijumu `unit_tests/build/coverage-html/`.

## LCOV dokumentacija i poreklo komandi

Korišćene komande zasnovane su na sledećoj dokumentaciji:

- [zvanični LCOV repozitorijum i osnovni workflow](https://github.com/linux-test-project/lcov);
- [`lcov(1)` dokumentacija](https://manpages.debian.org/unstable/lcov/lcov.1.en.html) za `--capture`, `--directory`, `--output-file`, `--extract`, `--summary`, `--rc` i `--ignore-errors`;
- [`genhtml(1)` dokumentacija](https://manpages.debian.org/unstable/lcov/genhtml.1.en.html) za `--output-directory`, `--branch-coverage` i `--title`.

Posle instalacije dokumentacija je dostupna i lokalno:

```bash
man lcov
man genhtml
```

Workflow u `run_tests.sh` prati dokumentovani redosled:

1. `gcc --coverage` instrumentiše program i omogućava nastanak `.gcno` i `.gcda` podataka;
2. testni program se pokreće da bi se zabeležile izvršene linije i grane;
3. `lcov --capture` prikuplja podatke u sirovi `.info` tracefile;
4. `lcov --extract` zadržava samo originalni `json-parser/json.c`;
5. `genhtml` pravi HTML prikaz pokrivenosti;
6. `lcov --summary` ispisuje zbirne line, function i branch coverage metrike.

`--ignore-errors mismatch` i `--ignore-errors unused` odnose se samo na LCOV obradu coverage podataka, a ne na testne neuspehe. `mismatch` pretvara nepodudarnost povezanih zapisa u upozorenje, dok `unused` dopušta nastavak ako obrazac za izdvajanje ne odgovara nijednom zapisu.

## Organizacija testova

`test_json_parser.c` sadrži deset grupa standardnih testova:

| Grupa | Predmet provere |
|---|---|
| `test_root_primitives` | integer, double, boolean i null korenske vrednosti |
| `test_nested_dom` | objekti, nizovi, roditeljske veze i ugnježdene vrednosti |
| `test_strings_and_unicode` | escape sekvence, ugrađeni nul-bajt i UTF-8 konverzija `\u20AC` |
| `test_invalid_inputs_and_errors` | odbijanje sintaksno neispravnih ulaza i popunjavanje error buffera |
| `test_explicit_length_boundary` | poštovanje eksplicitne dužine ulaza |
| `test_comment_modes` | razlika strogog i `json_enable_comments` režima |
| `test_number_boundaries` | `LONG_MAX`, prelazak velikog integera u double i veliki eksponent |
| `test_custom_allocator_and_cleanup` | balans alokacija/oslobađanja na uspešnoj i neuspešnoj putanji |
| `test_memory_limit` | odbijanje malog i prihvatanje dovoljnog `max_memory` limita |
| `test_source_tracking` | red izvornog dokumenta uz `JSON_TRACK_SOURCE` |

Poseban režim `--poznati-nalazi` reprodukuje odstupanja, ali se ne meša sa prolaznim regresionim skupom.

Naziv „poznati nalazi“ znači da ovaj režim ne otkriva probleme ponovo, već deterministički reprodukuje odstupanja koja su ranije pronađena i ručno potvrđena. Prva dva nalaza otkrivena su negativnim graničnim testovima JSON gramatike; nakon nalaza kod objekta proverena je i srodna putanja za niz. Očekivano ponašanje potvrđeno je prema RFC 8259. Treći nalaz otkriven je proverom stvarnih vrednosti `line` i `col`, a njegov uzrok je potvrđen pregledom `cur_col` logike u `json.c`.

Standardni skup mora da prođe 69/69 provera. Režim `--poznati-nalazi` namerno postavlja očekivanja ispravnog ponašanja koja trenutna biblioteka krši, pa vraća neuspešan exit status kada reprodukuje nalaze. `run_tests.sh` taj status obrađuje posebno i proverava tačne oznake sva tri nalaza, čime razlikuje očekivanu reprodukciju od proizvoljnog pada programa. UBSan nalaz aritmetike nad NULL pokazivačem nije deo ove grupe, već zasebne libFuzzer analize.

## Rezultat standardnih testova

```text
Izvrseno provera: 69
Neuspesnih provera: 0
```

Svih 69 provera javnog API-ja i strukture rezultata prošlo je uspešno.

## Pokrivenost `json.c`

| Metrika | Pokriveno | Ukupno | Pokrivenost |
|---|---:|---:|---:|
| Linije | 407 | 503 | 80,9% |
| Funkcije | 10 | 10 | 100,0% |
| Grane | 250 | 368 | 67,9% |

Visoka funkcijska pokrivenost znači da je svaka funkcija u `json.c` izvršena najmanje jednom. Ona ne znači da su sve putanje kroz funkcije proverene. Pokrivenost grana od 67,9% pokazuje da ostaju neizvršene kombinacije, naročito retke error putanje, alternativne pretprocesorske konfiguracije i ekstremni slučajevi Unicode/overflow obrade.

## Dokumentovana odstupanja

### 1. Prihvatanje završnog zareza u objektu

Ulaz:

```json
{"a": 1,}
```

parser prihvata i vraća `json_object`, iako gramatika [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259) definiše članove objekta kao član praćen sa nula ili više ponavljanja `, član`. Posle zareza zato mora uslediti sledeći član, a ne `}`.

### 2. Prihvatanje završnog zareza u nizu

Ulaz:

```json
[1, 2,]
```

parser prihvata i vraća `json_array`. RFC 8259 na isti način definiše niz kao vrednost praćenu ponavljanjima `, vrednost`, pa završni zarez bez naredne vrednosti nije validan JSON.

Referentni Python parser `json.loads` odbija oba ulaza. Ovo poređenje je korišćeno samo kao dodatna reprodukcija; osnov za zaključak je JSON gramatika iz RFC 8259.

U `json.c`, zatvaranje niza u stanju traženja vrednosti prihvata `]`, a zatvaranje objekta prihvata `}` i nakon što je zarez već uklonio zastavicu koja zahteva prethodnu vrednost. Zbog toga su oba završna zareza prihvaćena.

### 3. Kolona izvornog položaja ostaje nula

Kada je uključen `JSON_TRACK_SOURCE`, čvor na drugom redu dobija ispravan `line == 2`, ali `col` ostaje `0`, iako se vrednost nalazi posle uvlačenja i ključa.

Pregled implementacije pokazuje da se `cur_col` postavlja na nulu nakon novog reda i kopira u `json_value`, ali se ne uvećava pri prolasku kroz ostale karaktere. Funkcionalnost zato prati red, ali ne i stvarnu kolonu.

### Reprodukcioni izlaz

```text
ODSTUPANJE unit_tests/test_json_parser.c:352: value == 0
ODSTUPANJE unit_tests/test_json_parser.c:358: value == 0
ODSTUPANJE unit_tests/test_json_parser.c:366: member && member->col > 0
REPRODUKOVANO: zavrsni-zarez-objekat
REPRODUKOVANO: zavrsni-zarez-niz
REPRODUKOVANO: kolona-uvek-nula
Provera poznatih nalaza: 3
Reprodukovanih odstupanja: 3
```

Ovi nalazi su reproduktivna odstupanja od očekivanog ponašanja. Završni zarezi predstavljaju odstupanje od standardne JSON gramatike; problem kolone predstavlja neispravnu realizaciju opcione funkcionalnosti za praćenje izvornog položaja. Njihov bezbednosni uticaj nije utvrđen i ne treba ga preuveličavati.

## Sačuvani rezultati

- `results/izlaz-testova.txt` — standardni testovi;
- `results/poznati-nalazi.txt` — reprodukcija tri odstupanja;
- `results/sazetak-pokrivenosti.txt` — verzije alata i coverage metrike.

Detaljni HTML izveštaj se ne verzioniše jer je generisan, obiman i može se ponovo napraviti jednom komandom.

## Zaključak

Dodatni testovi značajno proširuju upstream skup jer ne proveravaju samo prihvatanje/odbijanje fajlova, već i semantiku DOM stabla, javna podešavanja i vlasništvo nad memorijom. Standardni skup prolazi 69/69 provera. Istovremeno su pronađena dva povezana odstupanja u gramatici završnog zareza i jedno odstupanje u `JSON_TRACK_SOURCE` praćenju kolone. Pokrivenost od 80,9% linija i 67,9% grana predstavlja dobru osnovu za ciljane dinamičke i statičke analize u narednim fazama.
