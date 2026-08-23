# Cppcheck — rezultati statičke analize

## Cilj i obuhvat

Analiziran je C izvor biblioteke `json-parser/json.c` alatom Cppcheck, bez izmene submodula. Osnov analize su samo kategorije **error**, **warning**, **performance** i **portability**. Kategorija `style` nije omogućena niti je korišćena za zaključak.

Analiza obuhvata dve podržane konfiguracije istog izvora:

1. podrazumevanu bibliotečku konfiguraciju (`_ANSI_SOURCE`);
2. konfiguraciju sa praćenjem lokacije u ulazu (`_ANSI_SOURCE` i `JSON_TRACK_SOURCE`), koju koriste testovi ovog repozitorijuma.

Korišćen je standard **C89**, u skladu sa načinom prevođenja projekta (`-std=c89`), jezik je eksplicitno postavljen na C, a ciljna platforma na 64-bitni Unix (`unix64`). Makroi `_MSC_VER` i `__STDC_VERSION__` eksplicitno su isključeni da Cppcheck ne bi analizirao MSVC ili C99 grane koje ne pripadaju izabranoj C89 konfiguraciji.

## Preduslovi

Potrebni su `cppcheck` i `python3`. Dokumentovano pokretanje koristi Cppcheck 2.13.0.

Na Debian/Ubuntu sistemu alat se može instalirati naredbom:

```bash
sudo apt-get install cppcheck
```

## Reprodukcija

Iz korena repozitorijuma:

```bash
./cppcheck/run_cppcheck.sh
```

Skripta pokreće iscrpnu analizu (`--check-level=exhaustive`) i uključuje i nalaze označene kao nesigurne (`--inconclusive`). Za svaku konfiguraciju čuva XML i čitljiv tekstualni izlaz, a zatim iz XML-a programski pravi zbirni pregled.

## Rezultat i klasifikacija

U obe konfiguracije dobijen je isti rezultat:

| Konfiguracija | error | warning | performance | portability |
|---|---:|---:|---:|---:|
| C89, podrazumevana | 0 | 0 | 0 | 0 |
| C89, `JSON_TRACK_SOURCE` | 0 | 0 | 0 | 0 |

Cppcheck nije prijavio nalaze u ciljanim kategorijama. Zbog toga nema kandidata koji bi se klasifikovali kao potvrđena greška, lažno pozitivan nalaz ili nalaz za dodatnu proveru. Prazne `.txt` datoteke predstavljaju originalni Cppcheck izlaz bez dijagnostika; XML datoteke sadrže prazan element `<errors>`.

## Ručna provera

Nakon automatske analize pregledana su mesta sa složenijom aritmetikom pokazivača i izraza:

- `json-parser/json.c:435–447`: tokom prvog prolaza parser namerno koristi polje pokazivača kao brojač potrebne memorije. Izraz na liniji 437 može predstavljati nedefinisano ponašanje u izvršavanju kada se aritmetika radi nad nultim pokazivačem, ali ga Cppcheck 2.13.0 u izabranoj konfiguraciji **nije prijavio**. Zato ovo nije Cppcheck nalaz i nije uračunato u tabelu; ostaje ograničenje ove tehnike koje treba proveravati dinamičkim alatima.
- `json-parser/json.c:876`: uslovni izraz je zagrađen kao drugi argument funkcije `pow`, pa je redosled operatora jednoznačan. Eventualna preporuka za dodatno pojašnjenje izraza pripadala bi kategoriji `style`, koja je namenski van obuhvata.
- Provereno je da analiza cilja samo `json.c` i zaglavlje koje on uključuje, bez testova, drugih alata i generisanih artefakata.

Ručna provera zato ne menja klasifikaciju: **0 potvrđenih Cppcheck nalaza u ciljanim kategorijama**. Ona takođe pokazuje da čist statički izveštaj nije dokaz odsustva svih grešaka.

## Ograničenja

- Rezultat važi za Cppcheck 2.13.0, C89 i navedene dve konfiguracije.
- Cppcheck koristi sopstveni model standardne biblioteke; ne izvršava program i ne može zameniti sanitizere, fuzzing ili dinamičku analizu.
- Nisu analizirane platforme Windows, 32-bitni Unix ni korisničko redefinisanje tipova `json_char`/`json_int_t`, jer nisu deo konkretne konfiguracije ovog repozitorijuma.
- Kategorije `style`, `information` i `unusedFunction` nisu osnova ove analize.

## Sačuvani rezultati

- `results/cppcheck-c89.xml` i `results/cppcheck-c89.txt` — podrazumevana C89 konfiguracija;
- `results/cppcheck-c89-track-source.xml` i `results/cppcheck-c89-track-source.txt` — C89 konfiguracija sa `JSON_TRACK_SOURCE`;
- `results/sazetak.txt` — programski izračunat broj nalaza po ciljanoj kategoriji;
- `results/metapodaci.txt` — verzija alata i parametri analize.
