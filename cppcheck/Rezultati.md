# Cppcheck — rezultati statičke analize

## Cilj i obuhvat

Cppcheck je samostalan alat za statičku analizu C/C++ koda; nije deo GCC-a niti Clang/LLVM ekosistema. Ne pokreće program i ne koristi konkretne testne ulaze, već sopstvenim parserom, preprocesorom, value-flow modelom i skupom pravila traži obrasce mogućih grešaka. Zbog drugačijeg modela ne mora prijaviti iste stvari kao Clang Static Analyzer ili runtime sanitizers.

Analiziran je C izvor biblioteke `json-parser/json.c` alatom Cppcheck, bez izmene submodula. Osnov analize su samo kategorije **error**, **warning**, **performance** i **portability**. Kategorija `style` nije omogućena niti je korišćena za zaključak.

Analiza obuhvata dve podržane konfiguracije istog izvora:

1. podrazumevanu bibliotečku konfiguraciju (`_ANSI_SOURCE`);
2. konfiguraciju sa praćenjem lokacije u ulazu (`_ANSI_SOURCE` i `JSON_TRACK_SOURCE`), koju koriste testovi ovog repozitorijuma.

Korišćen je standard **C89**, u skladu sa načinom prevođenja projekta (`-std=c89`), jezik je eksplicitno postavljen na C, a ciljna platforma na 64-bitni Unix (`unix64`). Makroi `_MSC_VER` i `__STDC_VERSION__` eksplicitno su isključeni da Cppcheck ne bi analizirao MSVC ili C99 grane koje ne pripadaju izabranoj C89 konfiguraciji.

## Preduslovi

Potrebni su `cppcheck` i `python3`. Sačuvani Linux rezultat koristi Cppcheck 2.13.0. Na pripremnom Apple Silicon Mac-u potvrđena je dostupnost Cppcheck-a 2.21.0; rezultat te verzije treba uporediti sa sačuvanim izlazom nakon lokalnog pokretanja.

Na Debian/Ubuntu sistemu alat se može instalirati naredbom:

```bash
sudo apt-get install cppcheck
```

Na macOS-u:

```bash
brew install cppcheck
cppcheck --version
python3 --version
```

## Reprodukcija

Iz korena repozitorijuma:

```bash
./cppcheck/run_cppcheck.sh
```

Skripta pokreće iscrpnu analizu (`--check-level=exhaustive`) i uključuje i nalaze označene kao nesigurne (`--inconclusive`). Za svaku konfiguraciju čuva XML i čitljiv tekstualni izlaz, a zatim iz XML-a programski pravi zbirni pregled.

### Zašto se alat pokreće četiri puta

Postoje dve preprocesorske konfiguracije, a svaka se analizira u dva izlazna formata:

1. osnovni C89 kod → XML;
2. osnovni C89 kod → tekst;
3. C89 sa `JSON_TRACK_SOURCE` → XML;
4. C89 sa `JSON_TRACK_SOURCE` → tekst.

To su dve konfiguracije iste tehnike, a ne četiri različite analize koje se sabiraju. XML je mašinski čitljiv dokaz iz koga Python pravi `sazetak.txt`; tekstualni fajl je namenjen čoveku. Cppcheck rezultate standardno ispisuje na stderr, pa skripta koristi `2>` iako se ne radi o neuspehu komande.

### Značenje ključnih opcija

- `--std=c89` — bira C89 pravila jezika;
- `--language=c` — izvor eksplicitno tretira kao C;
- `--platform=unix64` — koristi model veličina tipova za 64-bitni Unix;
- `-D_ANSI_SOURCE` — aktivira ANSI granu upstream biblioteke;
- `-U_MSC_VER` i `-U__STDC_VERSION__` — isključuju MSVC i C99 grane koje nisu deo ove konfiguracije;
- `-Ijson-parser` — omogućava pronalaženje `json.h`;
- `--enable=warning,performance,portability` — pored uvek aktivnog `error`, uključuje tri ciljane severity kategorije;
- `--check-level=exhaustive` — bira dublju, sporiju value-flow analizu;
- `--inconclusive` — prikazuje i nalaze za koje Cppcheck nema potpunu sigurnost;
- `--relative-paths=.` — stabilizuje putanje u rezultatima između različitih mašina;
- `--xml --xml-version=2` — generiše XML v2 za programsku obradu;
- `--template=...` — definiše čoveku čitljiv tekstualni format.

## Rezultat i klasifikacija

U obe konfiguracije dobijen je isti rezultat:

| Konfiguracija | error | warning | performance | portability |
|---|---:|---:|---:|---:|
| C89, podrazumevana | 0 | 0 | 0 | 0 |
| C89, `JSON_TRACK_SOURCE` | 0 | 0 | 0 | 0 |

Cppcheck nije prijavio nalaze u ciljanim kategorijama. Zbog toga nema kandidata koji bi se klasifikovali kao potvrđena greška, lažno pozitivan nalaz ili nalaz za dodatnu proveru. Prazne `.txt` datoteke predstavljaju originalni Cppcheck izlaz bez dijagnostika; XML datoteke sadrže prazan element `<errors>`.

## Zašto nisu ponovljeni nalazi drugih tehnika

### UBSan: aritmetika nad NULL pokazivačem (`json.c:437`)

UBSan je ovaj izraz video tokom stvarnog izvršavanja instrumentisanog programa i primenio Clangovu runtime proveru `pointer-overflow`. Cppcheck 2.13.0 ga svojim statičkim value-flow modelom nije označio. To pokazuje ograničenje konkretnog Cppcheck modela, ne neistinitost UBSan nalaza. Dinamički sanitizer i statički analizator ne koriste isti mehanizam dokazivanja.

### Clang Analyzer: mrtav upis (`json.c:683`)

Mrtvi i suvišni upisi u Cppcheck-u tipično pripadaju stilskim/readability proverama, dok kategorija `style` namerno nije deo zadatog opsega. Zato odsustvo ovog upozorenja nije direktno neslaganje sa Clang Analyzer-om; pokrenuta su različita pravila i kategorije.

### Clang Analyzer: dva neograničena `strcpy` poziva (`json.c:975` i `json.c:977`)

Clang je koristio namenski checker `security.insecureAPI.strcpy`, koji svaki neograničeni `strcpy` poziv tretira kao kandidat za pregled. Cppcheck nema obavezu da isti API obrazac mapira u neku od ovde uključenih kategorija bez dokazivog prekoračenja konkretnog bafera. U `json_parse_ex` kapacitet `error_buf` nije poznat, ali Cppcheck u ovoj analizi nije dokazao da je prosleđeni bafer premali. Clangova upozorenja zato ostaju potvrđeni uslovni API rizici, iako ih Cppcheck nije ponovio.

### Funkcionalna odstupanja iz jediničnih testova

Prihvatanje završnog zareza i neispravno praćenje kolone predstavljaju odstupanja od očekivane funkcionalnosti. Za njih je potreban test sa konkretnim očekivanim rezultatom ili poređenje sa specifikacijom; statički analizator bez takvog funkcionalnog ugovora ne zna da je prihvatanje određenog JSON-a pogrešno. Zato se ti nalazi ni ne očekuju u Cppcheck izlazu.

Zaključak nije da su drugi nalazi nestali, već da ova konfiguracija Cppcheck-a nije imala checker ili dovoljan dokaz da ih prijavi. Upravo zato se u projektu kombinuju komplementarne tehnike.

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
- Nisu korišćene suppressions; čist izlaz nije dobijen skrivanjem poznatih poruka.

## Sačuvani rezultati

- `results/cppcheck-c89.xml` i `results/cppcheck-c89.txt` — podrazumevana C89 konfiguracija;
- `results/cppcheck-c89-track-source.xml` i `results/cppcheck-c89-track-source.txt` — C89 konfiguracija sa `JSON_TRACK_SOURCE`;
- `results/sazetak.txt` — programski izračunat broj nalaza po ciljanoj kategoriji;
- `results/metapodaci.txt` — verzija alata i parametri analize.

## Zvanična dokumentacija

- [Cppcheck priručnik](https://cppcheck.sourceforge.io/manual.html) — platforme, severity kategorije, nivoi analize, preprocesorske konfiguracije i izlazni formati;
- [Cppcheck manual PDF](https://cppcheck.sourceforge.io/manual.pdf) — verzija priručnika pogodna za lokalno čuvanje i citiranje;
- [Cppcheck CLI manual](https://man.archlinux.org/man/cppcheck.1.en) — opis opcija `--enable`, `--platform`, `--template`, `--xml` i `--xml-version`.

Lokalno dostupna dokumentacija:

```bash
cppcheck --help
man cppcheck
```
