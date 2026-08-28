# LLVM libFuzzer — rezultati

## Cilj

Fuzz testiranje pomoću LLVM `libFuzzer`-a sa uključenim AddressSanitizer i UndefinedBehaviorSanitizer instrumentacijom. Cilj je pronalaženje ulaza koji izazivaju pad programa, memorijske greške ili nedefinisano ponašanje.

## Preduslovi

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y clang
```

macOS:

```bash
xcode-select --install  # samo ako Command Line Tools vec nisu instalirani
clang --version
```

Apple Command Line Tools obezbeđuje Clang. Korišćeni Clang mora da podržava `-fsanitize=fuzzer,address,undefined`; libFuzzer dokumentacija navodi da ga novije verzije Clang-a uključuju i da posebna instalacija nije potrebna. Na pripremnom Apple Silicon računaru potvrđen je Clang 21.0.0. Za razliku od Valgrind-a, AddressSanitizer zvanično podržava macOS, pa se ova tehnika može lokalno reprodukovati.

Korišćena verzija u dokumentovanom pokretanju:

```text
Ubuntu clang version 18.1.3 (1ubuntu1)
```

Ovo je verzija kojom su dobijeni sačuvani rezultati projekta. Lokalno macOS pokretanje može koristiti noviji Clang i zbog verzije alata ili platforme imati drugačiji broj izvršenih ulaza, brzinu i detalje stack trace-a. Suštinski nalaz mora se potvrditi prema istoj lokaciji i istoj vrsti nedefinisanog ponašanja, a ne prema identičnoj statistici fuzzinga.

## Reprodukcija

Iz korena repozitorijuma:

```bash
./libfuzzer/run_libfuzzer.sh
```

Podrazumevano trajanje je 60 sekundi i može se promeniti:

```bash
FUZZ_SECONDS=30 ./libfuzzer/run_libfuzzer.sh
```

## Harness

Fajl `fuzz_json_parser.c` prosleđuje proizvoljan binarni ulaz parseru u dva prolaza:

1. strogi režim putem `json_parse`;
2. režim sa komentarima putem `json_parse_ex` sa `json_enable_comments`.

Oba rezultata se odmah oslobađaju pozivom `json_value_free`. Harness ne pretpostavlja ispravnost ulaza.

Funkcija `LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)` nema sopstveni `main`: njega pri povezivanju obezbeđuje `-fsanitize=fuzzer`. `data` može sadržati proizvoljne bajtove i ugrađeni NUL, pa se parseru prosleđuje eksplicitni `size` umesto rezultata `strlen`. Povratna vrednost `0` znači samo da je harness završio obradu konkretnog ulaza; validnost JSON-a nije uslov uspeha.

## Zvanična dokumentacija

- [LLVM libFuzzer](https://llvm.org/docs/LibFuzzer.html) — fuzz target `LLVMFuzzerTestOneInput`, seed corpus, pokretanje i opcija `-fsanitize=fuzzer`;
- [Clang AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html) — memorijske greške, `-fsanitize=address`, debug informacije i podržane platforme;
- [Clang UndefinedBehaviorSanitizer](https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html) — vrste nedefinisanog ponašanja, `-fsanitize=undefined` i ponašanje pri nalazu.

Zvanična libFuzzer dokumentacija opisuje isti workflow koji koristi skripta: napraviti fuzz target, prevesti ga sa fuzzer i sanitizer instrumentacijom, pripremiti corpus, pokrenuti executable nad corpus direktorijumom i sačuvati ulaz koji izaziva pad ili sanitizer nalaz.

## Konfiguracija

Prevođenje koristi:

```text
-std=c89 -Wall -Wextra -Wpedantic -Werror
 -Wno-error=deprecated-declarations (samo na macOS-u zbog deprecated sprintf)
 -fsanitize=fuzzer,address,undefined
 -O1 -g -fno-omit-frame-pointer
```

Pokretanje koristi `UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1` kako bi nedefinisano ponašanje odmah zaustavilo izvršavanje i sačuvalo stack trace.

### macOS napomena o deprecated-declarations

Na novijem macOS SDK-u, uključujući Clang Apple/Xcode 21 protiv aktivnog macOSX SDK-a, `sprintf` je označen kao deprecated, pa se u originalnom `json.c` javlja 20 upozorenja klase `-Wdeprecated-declarations` (na linijama 308, 334, 351, 482, 498, 503, 518, 536, 555, 571, 586, 712, 732, 757, 775, 828, 845, 872, 957 itd.). Sa uključenim `-Werror` ta upozorenja postaju hard build greške, pre nego što se fuzzer executable fajl uopšte napravi.

Ovo je svojstvo platforme i novijeg SDK-a, a ne nalaz naše analize, pa originalni upstream kod ne ulazi u izmene. Skripta zato koristi `-Wno-error=deprecated-declarations`, što tu klasu spušta nazad na upozorenja i na Linux-u ponašanje ostaje nepromenjeno.

### macOS napomena o fuzzer runtime biblioteci

Apple Clang 21 iz kompletnog Xcode-a kompajlira sa `-fsanitize=fuzzer,address,undefined` bez greške, ali njegov toolchain ne isporučuje libFuzzer runtime biblioteku: u `.../XcodeDefault.xctoolchain/usr/lib/clang/21/lib/darwin/` postoje `asan`, `ubsan`, `tsan` i `profile` runtime-ovi, ali nijedan `libclang_rt.fuzzer_osx.a`. Linker zato pada sa `library ... libclang_rt.fuzzer_osx.a not found` iako je kompajliranje uspešno (`ld: library ... not found`, `clang: error: linker command failed`).

Rešenje je zvaničan [Homebrew LLVM](https://formulae.brew.sh/formula/llvm) (`brew install llvm`), čiji Clang dolazi sa kompletanim fuzzer runtime-om za `osx`:

```text
libclang_rt.fuzzer_osx.a
libclang_rt.fuzzer_no_main_osx.a
libclang_rt.fuzzer_interceptors_osx.a
```

Na pripremnom Apple Silicon računaru potvrđen je Homebrew LLVM Clang 23.1.0 sa gore navedenim runtime bibliotekama. Skripta zato na macOS-u preferira `/opt/homebrew/opt/llvm/bin/clang` (odnosno `/usr/local/opt/llvm/bin/clang` na Intel Mac-u) kada postoji, a na Linux-u i dalje koristi običan `clang` iz PATH-a. Na Linux-u ponašanje skripte ne menja ovo ničim, jer se tamo koristi isti sistemski Clang kao pre.

Sve ostale klase upozorenja i dalje, preko `-Werror`, prekidaju build. Pravi sanitizer nalazi ovim ne bivaju zamaskirani: njih prijavljuju ASan i UBSan tokom izvršavanja, a ne ovaj warnings flag kompajlera.

Opcije pokretanja znače:

- `-max_total_time` ograničava ukupno trajanje fuzzinga;
- `-timeout=5` prekida obradu pojedinačnog ulaza koji traje duže od pet sekundi;
- `-print_final_stats=1` ispisuje završnu statistiku;
- `-artifact_prefix` određuje gde se čuvaju ulazi koji izazovu pad ili sanitizer nalaz.

## Nalaz: nedefinisano ponašanje u prvom prolazu parsera

### Simptom

Prilikom obrade seed korpusa, UBSan prijavljuje:

```text
json-parser/json.c:437:34: runtime error: applying non-zero offset 2 to null pointer
```

Program se zaustavlja sa statusom 1 i sačuvan je crash artefakt.

### Lokalna reprodukcija na Apple Silicon macOS-u

Ovaj nalaz je dodatno reprodukovan lokalno na Apple Silicon Mac-u. Sačuvano Linux pokretanje koristilo je Ubuntu Clang 18.1.3, dok je lokalno macOS pokretanje koristilo Homebrew LLVM Clang 23.1.0 (Apple Clang ne isporučuje fuzzer runtime, vidi napomenu o fuzzer runtime biblioteci iznad).

Tok lokalnog pokretanja `FUZZ_SECONDS=30 ./libfuzzer/run_libfuzzer.sh`:

1. build prolazi uz istih 20 upozorenja o deprecated `sprintf`, bez build greške;
2. libFuzzer startuje sa entropic power schedule i učitava 4 seed fajla;
3. UBSan već pri obradi seed korpusa (`stat::number_of_executed_units: 2`) prijavljuje:
   ```text
   json-parser/json.c:437:34: runtime error: applying non-zero offset 2 to null pointer
   SUMMARY: UndefinedBehaviorSanitizer: undefined-behavior json-parser/json.c:437:34
   ```
4. pošto je `halt_on_error=1`, UBSan abort-uje proces; libFuzzer to beleži kao `deadly signal` i piše crash artefakt;
5. skripta čuva `results/crash-reprodukcija.bin`, prepoznaje tačan marker poznatog nalaza i završava statusom 0.

Uočljivo je da je crash artefakt dobio isti hash kao pri sačuvanom Linux pokretanju:

```text
crash-b7b38631dc8f544aa1bd38a6582cceec2785e20c
```

Ista 24 bajta ulaza, ista lokacija u kodu, isti tip nedefinisanog ponašanja (`__ubsan_handle_pointer_overflow`) na sasvim drugoj platformi i kompajler verziji. Nalaz je time potvrđen kao deterministički i nezavisan od platforme; razlikuju se samo statistika izvršavanja i format stack trace-a.

### Reprodukcioni ulaz

Sadržaj fajla `results/crash-reprodukcija.bin`:

```text
/* komentar */ {"a":1}\n
```

Odnosno, 24 bajta:

```text
2f 2a 20 6b 6f 6d 65 6e 74 61 72 20 2a 2f 20 7b 22 61 22 3a 31 7d 0a
```

Ovo je JSON dokument sa komentarima, koji se u strogom režimu odbija, ali u režimu sa `json_enable_comments` aktivira putanju koja vodi do linije 437.

### Uzrok

Linija 437 u `json.c`:

```c
chars[0] += string_length + 1;
```

Ova linija se izvršava u prvom prolazu parsera kada se zatvori string ključ unutar objekta. U prvom prolazu `top->u.object.values` još uvek nije alociran i iznosi `NULL`. Parser u prvom prolazu koristi `chars[0]` kao akumulator dužine preko reinterpretacije pokazivača:

```c
json_char **chars = (json_char **) &top->u.object.values;
chars[0] += string_length + 1;
```

Kada je `top->u.object.values` jednak `NULL`, sabiranje `NULL + (string_length + 1)` predstavlja aritmetiku nad nul-pokazivačem, što je nedefinisano ponašanje prema C standardu.

U drugom prolazu `values` je već alociran i ova linija se ne izvršava na isti način, pa se problem ne javlja.

### Ograničenje i tumačenje

Ovo je nedefinisano ponašanje koje se redovno javlja na normalnom, validnom JSON ulazu sa komentarima. Nije potrebno proizvoljno mutirati ulaz da bi se izazvalo — dovoljan je bilo koji JSON objekat sa ključem kada su komentari uključeni.

U praksi, sabiranje nad `NULL` se na većini platformi ponaša kao obično sabiranje celog broja i rezultat se kasnije koristi samo kao veličina, ne za dereferenciranje. Zato se ovaj problem ne manifestuje kao crash bez UBSan instrumentacije. Ipak, po standardu jezika C, aritmetika nad nul-pokazivačem je nedefinisano ponašanje i ne može se smatrati ispravnim.

### Bezbednosni uticaj

Nije utvrđen direktan bezbednosni uticaj iz ovog konkretnog nalaza. Parser koristi rezultat ove aritmetike samo u prvom prolazu kao akumulator dužine, ne za stvarni memorijski pristup. Međutim, nedefinisano ponašanje može na nekim platformama ili pod optimizacijama dovesti do neočekivanih rezultata.

## Sačuvani rezultati

- `results/izlaz.txt` — puni izlaz pokretanja sa UBSan stack trace-om;
- `results/sazetak.txt` — verzija alata i statistika pokretanja;
- `results/crash-reprodukcija.bin` — minimalni reprodukcioni ulaz (24 bajta).

## Zaključak

libFuzzer je pronašao potvrđeno nedefinisano ponašanje u prvom prolazu parsera: aritmetiku nad `NULL` pokazivačem prilikom obrade ključa objekta kada su komentari uključeni. Nalaz je reprodukovan deterministički, ne zahteva proizvoljan binarni ulaz i javlja se na normalnom JSON dokumentu sa komentarima.