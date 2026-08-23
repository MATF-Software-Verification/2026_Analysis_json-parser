# LLVM libFuzzer — rezultati

## Cilj

Fuzz testiranje pomoću LLVM `libFuzzer`-a sa uključenim AddressSanitizer i UndefinedBehaviorSanitizer instrumentacijom. Cilj je pronalaženje ulaza koji izazivaju pad programa, memorijske greške ili nedefinisano ponašanje.

## Preduslovi

```bash
sudo apt-get update
sudo apt-get install -y clang
```

Korišćena verzija u dokumentovanom pokretanju:

```text
Ubuntu clang version 18.1.3 (1ubuntu1)
```

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

## Konfiguracija

Prevođenje koristi:

```text
-std=c89 -Wall -Wextra -Wpedantic -Werror
-fsanitize=fuzzer,address,undefined
-O1 -g -fno-omit-frame-pointer
```

Pokretanje koristi `UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1` kako bi nedefinisano ponašanje odmah zaustavilo izvršavanje i sačuvalo stack trace.

## Nalaz: nedefinisano ponašanje u prvom prolazu parsera

### Simptom

Prilikom obrade seed korpusa, UBSan prijavljuje:

```text
json-parser/json.c:437:34: runtime error: applying non-zero offset 2 to null pointer
```

Program se zaustavlja sa statusom 1 i sačuvan je crash artefakt.

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