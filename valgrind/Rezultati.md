# Valgrind Memcheck — rezultati

## Cilj

Valgrind Memcheck se koristi za proveru neispravnih čitanja i upisa, korišćenja neinicijalizovanih vrednosti, pogrešnog oslobađanja i curenja memorije tokom stvarnog izvršavanja parsera.

Analiza se pokreće nad dva nezavisna skupa:

- dodatnim testovima iz `unit_tests/test_json_parser.c`;
- originalnim upstream testovima iz `json-parser/tests/test.c`.

## Preduslovi

Analiza je predviđena za Linux:

```bash
sudo apt-get update
sudo apt-get install -y gcc valgrind
```

### Ograničenje na macOS-u

Zvanična Valgrind stranica [Supported Platforms](https://valgrind.org/info/platforms.html) navodi podršku za Darwin samo na Intel arhitekturama: `X86/Darwin` do macOS 10.13 i `AMD64/Darwin` do macOS 11.0. Kombinacija `ARM64/Darwin`, koju koristi Apple Silicon, nije navedena među podržanim platformama. I [aktuelno Valgrind izdanje](https://valgrind.org/downloads/current.html) navodi Darwin samo za `x86` i `amd64`, dok je `arm64` podržan na drugim operativnim sistemima, kao što su Linux i FreeBSD.

Zbog toga ova tehnika neće biti lokalno reprodukovana na savremenom Apple Silicon (`arm64`) Mac-u. Ne koristi se nezvanični fork, virtuelna mašina ili drugi workaround samo radi ponavljanja analize. U ovom repozitorijumu ostaju sačuvani rezultati stvarnog pokretanja u podržanom Linux okruženju, uz jasno navedene verzije alata i ograničenje platforme.

Formulacija za odbranu:

> Valgrind Memcheck analiza izvršena je u Linux okruženju i njeni rezultati su sačuvani u repozitorijumu. Moj računar koristi Apple Silicon macOS, za koji Valgrind nema zvaničnu `ARM64/Darwin` podršku, pa ovu tehniku nisam lokalno reprodukovao na tom računaru.

## Reprodukcija

Iz korena repozitorijuma:

```bash
./valgrind/run_memcheck.sh
```

Skripta prevodi oba test programa sa debug simbolima i bez optimizacije, a zatim ih pokreće sa opcijama:

```text
--leak-check=full
--show-leak-kinds=all
--track-origins=yes
--errors-for-leak-kinds=definite,indirect,possible
--error-exitcode=99
```

`--error-exitcode=99` obezbeđuje da skripta ne može završiti uspešno ako Memcheck pronađe grešku ili sigurno, posredno ili moguće curenje. Memorija koja je samo još uvek dostupna (`reachable`) prikazuje se u izveštaju, ali sama po sebi ne menja izlazni status.

## Dokumentacija alata i opcija

Korišćenje Memcheck-a i značenje njegovih nalaza zasnovani su na zvaničnoj dokumentaciji:

- [Valgrind User Manual](https://valgrind.org/docs/manual/manual.html) — opšta upotreba Valgrind-a i zajedničke opcije;
- [Memcheck Manual](https://valgrind.org/docs/manual/mc-manual.html) — vrste memorijskih grešaka, provera curenja i Memcheck opcije;
- [Supported Platforms](https://valgrind.org/info/platforms.html) — zvanično podržane kombinacije procesorske arhitekture i operativnog sistema;
- [Current Releases](https://valgrind.org/downloads/current.html) — platforme obuhvaćene aktuelnim izdanjem.

Opcije iz `run_memcheck.sh` imaju sledeću ulogu:

- `--leak-check=full` prikazuje detalje za svako otkriveno curenje;
- `--show-leak-kinds=all` prikazuje sve kategorije curenja;
- `--track-origins=yes` pokušava da pronađe poreklo neinicijalizovanih vrednosti;
- `--errors-for-leak-kinds=definite,indirect,possible` određuje koje kategorije curenja utiču na broj grešaka;
- `--error-exitcode=99` vraća status `99` ako je Valgrind pronašao grešku koja se računa prema izabranim pravilima;
- `--log-file=...` čuva Memcheck izveštaj u odgovarajućem fajlu u `valgrind/results/`.

Na podržanom sistemu lokalna dokumentacija može se otvoriti komandama:

```bash
man valgrind
valgrind --help
```

## Rezultat

Dokumentovano pokretanje koristi Valgrind 3.22.0 i GCC 13.3.0 nad `json-parser` revizijom `8ac4477ad3e63dc107e17ad49484edaa17d18d35`. Oba skupa testova završila su izlaznim statusom nula, bez Memcheck grešaka i bez memorije koja je ostala zauzeta na izlazu.

### Dodatni testovi

```text
in use at exit: 0 bytes in 0 blocks
All heap blocks were freed -- no leaks are possible
ERROR SUMMARY: 0 errors from 0 contexts
```

### Upstream testovi

```text
in use at exit: 0 bytes in 0 blocks
All heap blocks were freed -- no leaks are possible
ERROR SUMMARY: 0 errors from 0 contexts
```

Tačan broj alokacija i oslobađanja nalazi se u `results/sazetak.txt` i sirovim Memcheck izveštajima.

## Tumačenje i ograničenja

Rezultat pokazuje da Memcheck na konkretno izvršenim Linux putanjama nije prijavio curenje niti neispravan memorijski pristup. Posebno su izvršene uspešne i neuspešne putanje parsiranja, stringovi, ugnježdeni objekti i nizovi, prilagođeni alokator i ograničenje memorije.

Čist Memcheck rezultat nije dokaz odsustva svih memorijskih grešaka niti dokaz potpune funkcionalne ispravnosti parsera. Alat može proveriti samo putanje koje su testovi stvarno izvršili, u konkretnom Linux okruženju i sa korišćenim ulazima. Zato se rezultat posmatra zajedno sa pokrivenošću testova i narednim fuzzing analizama.

## Sačuvani rezultati

- `results/memcheck-jedinicni-testovi.txt` — sirovi Memcheck izveštaj nad dodatnim testovima;
- `results/memcheck-upstream-testovi.txt` — sirovi Memcheck izveštaj nad upstream testovima;
- `results/izlaz-jedinicnih-testova.txt` i `izlaz-upstream-testova.txt` — izlazi test programa;
- `results/sazetak.txt` — verzija alata i ključne metrike.
