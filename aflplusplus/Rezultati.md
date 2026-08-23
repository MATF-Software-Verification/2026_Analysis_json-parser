# AFL++ — rezultati

## Cilj

Nezavisno coverage-guided fuzz testiranje pomoću AFL++ alata. Ovo je prvi od dva alata koji nisu obrađeni na vežbama.

## Preduslovi

```bash
sudo apt-get update
sudo apt-get install -y afl++
```

Korišćene verzije u dokumentovanom pokretanju:

```text
afl-clang-fast: Ubuntu clang version 17.0.6
afl-fuzz:       afl-fuzz++4.09c
```

## Reprodukcija

Iz korena repozitorijuma:

```bash
./aflplusplus/run_afl.sh
```

Podrazumevano trajanje je 60 sekundi i može se promeniti:

```bash
FUZZ_SECONDS=30 ./aflplusplus/run_afl.sh
```

Napomena: na sistemima gde `core_pattern` nije postavljen na `core` (npr. Ubuntu sa apport), skripta automatski postavlja `AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1`, `AFL_SKIP_CRASHES=1` i `AFL_SKIP_CPUFREQ=1` da bi fuzzing radio bez root prava.

## Harness

Fajl `fuzz_harness.c` čita proizvoljan binarni ulaz sa stdin i prosleđuje ga parseru u dva prolaza:

1. strogi režim putem `json_parse`;
2. režim sa komentarima putem `json_parse_ex` sa `json_enable_comments`.

Oba rezultata se odmah oslobađaju. Harness ne pretpostavlva ispravnost ulaza.

## Seed korpus

Početni korpus sadrži šest minimalnih validnih JSON dokumenata:

```text
object.json   → {"a":1}
array.json    → [1,2,3]
string.json   → "hello"
boolean.json  → true
number.json   → 42
null.json     → null
```

## Konfiguracija

Prevođenje koristi `afl-clang-fast` sa:

```text
-std=c89 -Wall -Wextra -Wpedantic -Werror
-O1 -g
```

Pokretanje koristi:

```text
afl-fuzz -i <corpus> -o <findings> -V <seconds> -t 5000 -m none
```

## Rezultat

Dokumentovano pokretanje trajalo je 30 sekundi i završilo je sa statusom 0.

```text
Statistics: 372 new corpus items found, 75.08% coverage achieved,
            0 crashes saved, 0 timeouts saved,
            total runtime 0 days, 0 hrs, 0 min, 30 sec
```

| Metrika | Vrednost |
|---|---:|
| Novi korpus elementi | 372 |
| Pokrivenost | 75,08% |
| Crash-eva | 0 |
| Hang-ova | 0 |
| Queue elemenata | 379 |

## Tumačenje i ograničenja

AFL++ je u 30 sekundi izvršio parser nad stotinama mutiranih ulaza i postigao 75,08% coverage bez pronalaska crash-eva ili hang-ova. Ovo je očekivan rezultat za kratko trajanje nad stabilnim parserom.

Ograničenja:

- Trajanje od 30 sekundi je demonstrativno; duže pokretanje bi pokrilo više putanja.
- AFL++ bez uključenih sanitizera ne može otkriti nedefinisano ponašanje koje ne izaziva pad procesa. UBSan nalaz pronađen libFuzzer-om (aritmetika nad NULL u prvom prolazu) AFL++ ne bi otkrio jer ne izaziva segfault.
- `AFL_SKIP_CRASHES=1` znači da crash-evi ne bi bili sačuvani kao artefakti, ali se i dalje registrovani u statistici. U ovom pokretanju ih nije bilo.

## Sačuvani rezultati

- `results/izlaz.txt` — puni izlaz AFL++ pokretanja;
- `results/sazetak.txt` — verzija alata, statistika i broj crash/hang/queue.

## Zaključak

AFL++ fuzzing nije pronašao crash-eve niti hang-ove u 30-sekundnom pokretanju. Alat je uspešno istražio 75,08% coverage i generisao 372 nova korpus elementa. Rezultat je konzistentan sa libFuzzer rezultatom: parser ne pada na proizvoljnom ulazu, ali libFuzzer sa UBSan-om pronalazi nedefinisano ponašanje koje AFL++ bez sanitizera ne može otkriti.