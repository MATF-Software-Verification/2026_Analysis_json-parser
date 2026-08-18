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

## 6. Plan analize

Planirani skup obuhvata jedinične testove uz pokrivenost koda, fuzz testiranje, dinamičku analizu memorije i statičku analizu.
Najmanje dva izabrana alata neće biti alati obrađeni na vežbama.
Konačan izbor biće potvrđen tek nakon kratkih eksperimenata izvodljivosti.
Za svaki usvojeni alat biće sačuvani:

- precizna verzija alata;
- skripta za reprodukciju;
- korišćena konfiguracija i ulazi;
- relevantni sirovi rezultati;
- tumačenje nalaza;
- ograničenja i mogući lažno pozitivni rezultati.

## 7. Rezultati pojedinačnih analiza

Ovo poglavlje će biti dopunjavano nakon završetka svake pojedinačne analize.
Rezultati neće biti proglašavani bagovima dok se ne reprodukuju i ne provere u odnosu na očekivano ponašanje biblioteke.

## 8. Zaključak

Početna provera potvrđuje da je izabrani commit u stanju pogodnom za dalju analizu: projekat se prevodi, modularan je i poseduje izvršive početne testove.
Konačni zaključak biće napisan nakon sprovođenja najmanje šest tehnika i poređenja njihovih nalaza.
