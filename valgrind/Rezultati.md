# Valgrind Memcheck — rezultati

## Cilj

Valgrind Memcheck se koristi za proveru neispravnih čitanja i upisa, korišćenja neinicijalizovanih vrednosti, pogrešnog oslobađanja i curenja memorije tokom stvarnog izvršavanja parsera.

Analiza se pokreće nad dva nezavisna skupa:

- dodatnim testovima iz `unit_tests/test_json_parser.c`;
- originalnim upstream testovima iz `json-parser/tests/test.c`.

## Preduslovi

```bash
sudo apt-get update
sudo apt-get install -y gcc valgrind
```

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

Rezultat potvrđuje da na izvršenim putanjama nije pronađeno curenje niti neispravan memorijski pristup. Posebno su izvršene uspešne i neuspešne putanje parsiranja, stringovi, ugnježdeni objekti i nizovi, prilagođeni alokator i ograničenje memorije.

Čist Memcheck rezultat nije dokaz odsustva svih memorijskih grešaka. Alat može proveriti samo putanje koje su testovi stvarno izvršili. Zato se rezultat posmatra zajedno sa pokrivenošću testova i narednim fuzzing analizama.

## Sačuvani rezultati

- `results/memcheck-jedinicni-testovi.txt` — sirovi Memcheck izveštaj nad dodatnim testovima;
- `results/memcheck-upstream-testovi.txt` — sirovi Memcheck izveštaj nad upstream testovima;
- `results/izlaz-jedinicnih-testova.txt` i `izlaz-upstream-testova.txt` — izlazi test programa;
- `results/sazetak.txt` — verzija alata i ključne metrike.
