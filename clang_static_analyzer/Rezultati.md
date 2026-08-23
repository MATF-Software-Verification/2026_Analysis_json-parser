# Rezultati — Clang Static Analyzer

## Cilj i konfiguracija

Analiziran je isključivo `json-parser/json.c`, bez izmene izvornog koda ili submodula. Korišćen je Clang Static Analyzer iz Clang-a 18.1.3 u stvarnoj C89 konfiguraciji:

```sh
clang --analyze -std=c89 -pedantic -Ijson-parser \
  -Xanalyzer -analyzer-checker=core,unix,security,deadcode \
  -Xanalyzer -analyzer-output=text json-parser/json.c
```

Analiza je završena izlaznim kodom 0 i prijavila je **3 upozorenja**. `-std=c89` aktivira C89 grane u `json.h` i `json.c` (na primer, `json_int_t` je `long`, a `JSON_INT_MAX` je `LONG_MAX`). Time nalaz nije dobijen analizom pod podrazumevanim novijim C standardom.

Reprodukcija:

```sh
cd /home/gamzatore/Workspace/2026_Analysis_json-parser
sh clang_static_analyzer/run_analysis.sh
```

Skripta ponovo stvara tekstualni trag, PLIST izveštaj i TSV sažetak u `clang_static_analyzer/results/`.

## Sažetak klasifikacije

| # | Lokacija | Checker | Klasifikacija | Težina |
|---|---|---|---|---|
| 1 | `json.c:683:37` | `deadcode.DeadStores` | potvrđeno | niska |
| 2 | `json.c:975:10` | `security.insecureAPI.strcpy` | potvrđena neograničena operacija; preliv zavisi od pozivaoca | srednja |
| 3 | `json.c:977:10` | `security.insecureAPI.strcpy` | potvrđena neograničena operacija; preliv zavisi od pozivaoca | niska–srednja |

**Potvrđeno:** 3 upozorenja (dva `strcpy` upozorenja su dve lokacije istog API problema).  
**False positive:** 0.  
Ova klasifikacija ne znači da su oba `strcpy` poziva dokazano iskoristiva u uobičajenoj upotrebi; potvrđeno je da funkcija nema informaciju o kapacitetu odredišta i zato ne može da sprovede granicu.

## Interpretacija svakog nalaza

### 1. Mrtvo upisivanje u `b` — linija 683

U grani u kojoj `++state.ptr == end`, kod postavlja `b = 0` i odmah izlazi iz unutrašnje `while` petlje. Nakon toga se postavljaju `flag_next | flag_reproc` i izlazi se i iz `switch` grane; vrednost promenljive `b` se pre sledećeg upisa nigde ne čita.

**Zaključak:** potvrđen mrtav upis, a ne false positive. Ne izaziva kvar niti bezbednosni problem, ali je suvišan i može da zavara čitaoca da je nulti znak potreban daljem toku. Uklanjanje samo dodele `b = 0` ne menja ponašanje te putanje.

### 2. `strcpy(error_buf, error)` — linija 975

`error` je lokalni niz veličine `json_error_max` (128), ali je `error_buf` samo `char *`. Potpis `json_parse_ex` ne prima kapacitet odredišnog bafera, pa implementacija ne može da proveri da li pozivalac zaista prosleđuje najmanje 128 bajtova. Ako je bafer manji od proizvedene poruke plus završni NUL, sledi upis van granica.

**Zaključak:** upozorenje nije false positive: neograničena kopija u bafer nepoznate veličine zaista postoji. Ipak, nema dokaza o prelivu kada pozivalac poštuje nameravanu konvenciju i obezbedi `json_error_max` bajtova. Rizik je prvenstveno slab API ugovor. Robusno rešenje je API koji prima veličinu bafera; Clang-ov predlog `strlcpy` nije prenosivo C89 rešenje i sam ne rešava nedostatak poznatog kapaciteta.

### 3. `strcpy(error_buf, "Unknown error")` — linija 977

Ista API slabost postoji i u rezervnoj grani. Ovde je izvor fiksan i zahteva 14 bajtova uključujući završni NUL, pa je praktičan rizik manji, ali se kapacitet `error_buf` i dalje ne zna. Bafer kraći od 14 bajtova bi bio prepisan.

**Zaključak:** potvrđena neograničena operacija, nije false positive. To je druga lokacija istog korenskog problema kao nalaz #2, a ne nezavisan dizajnerski propust.

## False positive nalazi

Nema nalaza koji su nakon pregleda označeni kao false positive. Bezbednosni checker je sintaksički konzervativan i sam ne dokazuje iskoristivost, ali oba označena poziva stvarno nemaju proverljivu granicu odredišta. Zato su zadržani kao uslovni, potvrđeni API rizici umesto da budu odbačeni.

## Artefakti

- `run_analysis.sh` — reproduktivna C89 analiza i generisanje rezultata;
- `results/sirovi_izlaz.txt` — kompletan tekstualni izlaz stvarnog pokretanja;
- `results/nalazi.tsv` — sažet mašinski čitljiv spisak;
- `results/okruzenje.txt` — verzija, konfiguracija i komanda;
- `results/report.plist` — generiše skripta kao mašinski čitljiv Analyzer izveštaj.

HTML/build izlaz nije sačuvan, u skladu sa zadatim opsegom.
