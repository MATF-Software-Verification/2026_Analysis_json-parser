# AFL++ — rezultati

## Cilj

Nezavisno coverage-guided fuzz testiranje pomoću AFL++ alata. Ovo je prvi od dva alata koji nisu obrađeni na vežbama. AFL++ mutira početni korpus, meri edge coverage instrumentisanog programa i zadržava ulaze koji otkrivaju nove putanje. Crash ulaze odvaja u `crashes/`, prekoračenja timeout-a u `hangs/`, a zanimljive ulaze u `queue/`.

## Razlika u odnosu na libFuzzer

Oba alata su coverage-guided fuzzeri, ali imaju različitu arhitekturu:

| Osobina | libFuzzer | AFL++ u ovom projektu |
|---|---|---|
| Način rada | in-process runtime linkovan sa ciljem | zaseban `afl-fuzz` proces upravlja executable-om |
| Harness interfejs | `LLVMFuzzerTestOneInput(data, size)` | običan `main()` koji čita `stdin` |
| Instrumentacija | `-fsanitize=fuzzer,address,undefined` | `afl-clang-fast` coverage instrumentacija |
| Detekcija u našoj konfiguraciji | coverage + ASan + UBSan | coverage + prirodni crash + timeout |
| Glavni artefakti | corpus i `crash-*` ulaz | `queue/`, `crashes/`, `hangs/`, `fuzzer_stats` |

Zato rezultati nisu kontradiktorni: libFuzzer build je uz UBSan prijavio aritmetiku nad NULL pokazivačem, dok AFL++ bez sanitizera ne prijavljuje nedefinisano ponašanje koje samo po sebi ne ruši proces.

## Preduslovi

```bash
sudo apt-get update
sudo apt-get install -y afl++
```

Na macOS-u se aktuelni AFL++ može instalirati preko Homebrew-a:

```bash
brew install afl++
afl-clang-fast --version
afl-fuzz --version
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

Fajl `fuzz_harness.c` je analysis-owned adapter. Čita najviše 4095 bajtova proizvoljnog binarnog ulaza sa `stdin`, ostavlja jedan bajt za završni NUL i prosleđuje stvarnu dužinu parseru u dva režima:

1. strogi režim putem `json_parse`;
2. režim sa komentarima putem `json_parse_ex` sa `json_enable_comments`.

Oba rezultata se odmah oslobađaju. Harness ne pretpostavlja ispravnost ulaza. Njegov status 0 znači samo da konkretan ulaz nije prirodno srušio proces; odbijanje neispravnog JSON-a je normalan ishod.

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

- `-i` — direktorijum koji sadrži isključivo početne seed fajlove;
- `-o` — koren AFL++ kampanje (`queue`, `crashes`, `hangs` i statistika);
- `-V` — automatski završava demonstrativnu kampanju posle zadatog vremena;
- `-t 5000` — izvršavanje duže od 5000 ms klasifikuje kao hang;
- `-m none` — ne nameće dodatni AFL++ memory limit;
- `--` — razdvaja opcije fuzera od komande ciljnog programa.

Promenljiva `AFL_SKIP_CRASHES=1` odnosi se samo na preskakanje crashujućih početnih seedova tokom dry run-a; novi crash-evi pronađeni fuzzingom i dalje se čuvaju. `AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1` zaobilazi Linux `core_pattern` zaštitu, što može otežati razlikovanje crash-a od timeout-a, dok `AFL_SKIP_CPUFREQ=1` izbegava zahtev za promenom CPU governor-a.

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

### Naknadno utvrđeno ograničenje sačuvanog pokretanja

Pregledom sirovog izlaza utvrđeno je da je prvobitna skripta kao `-i` direktorijum prosledila ceo `build/`. Pošto se executable takođe nalazio u tom direktorijumu, AFL++ je učitao **7**, a ne 6 početnih seedova:

```text
Loaded a total of 7 seeds.
orig:fuzz_harness
Some test cases are huge (127 kB)
```

Sedmi seed bio je binarni `fuzz_harness`, veličine oko 127 kB. To ne poništava zabeleženu činjenicu da u toj kampanji nije sačuvan crash ni hang, ali znači da statistike queue-a, brzine i coverage-a ne predstavljaju čistu kampanju pokrenutu samo iz šest dokumentovanih JSON seedova. Skripta je zato ispravljena tako da koristi poseban `build/corpus/`, dok executable ostaje u `build/`.

### Neuspešno lokalno pokretanje na Apple Silicon macOS-u

Ispravljena skripta je pokrenuta i na Apple Silicon Mac-u (Homebrew LLVM Clang 23.1.0, `afl-fuzz++5.02c`). Build harnessa i učitavanje šest seedova prolaze, ali kampanja pada pre početka fuzzing-a:

```text
[-] SYSTEM ERROR : shmget() failed, try running afl-system-config
    Stop location : afl_shm_init(), src/afl-sharedmem.c:344
    OS message : Invalid argument
```

Uzrok je sistemski: AFL++ za coverage bitmap koristi SysV deljenu memoriju koju macOS podrazumevano ne dozvoljava u traženoj veličini; alat sam predlaže pokretanje `afl-system-config` za izmenu sistemskih parametara. To je workaround van opsega projekta (ista kategorija kao Valgrind na arm64 macOS-u), pa ovo pokretanje ne daje fuzzing rezultat i nema uticaja na sačuvane rezultate. Sačuvani rezultat ostaje onaj iz Linux okruženja.

## Tumačenje i ograničenja

AFL++ je u 30 sekundi izvršio parser nad stotinama mutiranih ulaza i postigao 75,08% coverage bez pronalaska crash-eva ili hang-ova. Ovo je očekivan rezultat za kratko trajanje nad stabilnim parserom.

Ograničenja:

- Trajanje od 30 sekundi je demonstrativno; duže pokretanje bi pokrilo više putanja.
- AFL++ bez uključenih sanitizera ne može otkriti nedefinisano ponašanje koje ne izaziva pad procesa. UBSan nalaz pronađen libFuzzer-om (aritmetika nad NULL u prvom prolazu) AFL++ ne bi otkrio jer ne izaziva segfault.
- Sačuvana statistika potiče iz starog pokretanja sa nenamernim sedmim binarnim seedom; pokušaj reprodukcije na Apple Silicon macOS-u pao je na sistemskom ograničenju deljene memorije (`shmget()`), pa sačuvani Linux rezultat ostaje dokaz za ovu tehniku.

## Sačuvani rezultati

- `results/izlaz.txt` — puni izlaz AFL++ pokretanja;
- `results/sazetak.txt` — verzija alata, statistika i broj crash/hang/queue.

## Zaključak

Sačuvano AFL++ pokretanje nije pronašlo crash-eve niti hang-ove za 30 sekundi i prijavilo je 75,08% coverage i 372 nova korpus elementa — uz dokumentovano ograničenje nenamernog sedmog binarnog seeda. Pokušaj reprodukcije na Apple Silicon Mac-u pao je pre početka kampanje na macOS ograničenju SysV deljene memorije, pa je ova tehnika dokumentovana iz Linux okruženja, na sličan način kao Valgrind. Odsustvo UBSan nalaza je očekivano: AFL++ bez sanitizera ne može otkriti nedefinisano ponašanje koje ne izaziva prirodni pad.

## Zvanična dokumentacija

- [AFL++ dokumentacija](https://aflplus.plus/docs/) — početna tačka za instrumentaciju, korpus i pokretanje kampanje;
- [Fuzzing in Depth](https://aflplus.plus/docs/fuzzing_in_depth/) — instrumentisanje cilja, izbor početnog korpusa i coverage-guided tok;
- [AFL++ environment variables](https://aflplus.plus/docs/env_variables/) — značenje `AFL_*` promenljivih;
- [AFL++ instalacija](https://aflplus.plus/docs/install/) — podržani načini instalacije, uključujući macOS napomene.

Lokalna dokumentacija:

```bash
afl-fuzz -h
afl-clang-fast -hh
```