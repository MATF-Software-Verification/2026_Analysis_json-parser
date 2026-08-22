# Analiza projekta json-parser — plan rada

## Faza 1: Repozitorijum i početna provera ✅ COMPLETE

**Cilj:** Reproduktivan seminarski repozitorijum sa zaključanom verzijom analiziranog projekta.

- ✅ Napravljen privatni radni repozitorijum.
- ✅ Dodat `json-parser` kao Git submodule.
- ✅ Zaključan commit `8ac4477ad3e63dc107e17ad49484edaa17d18d35` sa grane `master`.
- ✅ Projekat preveden pomoću zvanične `configure`/`make` putanje.
- ✅ Postojeći C test program preveden i uspešno izvršen.
- ✅ Dodata zvanična CI konfiguracija kursa.
- ✅ Napravljen i pushovan početni commit.

**Isporučivo:** čista i proverena osnova za sve naredne analize.

## Faza 2: Razumevanje parsera i strategija testiranja ✅ COMPLETE

**Cilj:** Razumeti javni API, ključne putanje parsera, memorijski model i postojeće testove pre dodavanja novih analiza.

- ✅ Mapirani su `json_parse`, `json_parse_ex`, alokacija i oslobađanje stabla.
- ✅ Popisane su klase validnih i nevalidnih JSON ulaza.
- ✅ Definisana su očekivana svojstva i oracle za testove/fuzzing.
- ✅ Izabrano je šest tehnika, uključujući AFL++ i `cppcheck` kao dva alata koja nisu rađena na vežbama.

## Faza 3: Jedinični testovi i pokrivenost (Active)

**Cilj:** Dodati razumljive testove graničnih slučajeva i izmeriti line/branch coverage pomoću `lcov`.

## Faza 4: Dinamičke analize (Pending)

**Cilj:** Proveriti memorijsku ispravnost i robustnost parsera.

- Valgrind Memcheck (jedini Valgrind alat).
- LLVM libFuzzer.
- AFL++ kao alat koji nije rađen na vežbama.

## Faza 5: Statičke i formalne analize (Pending)

**Cilj:** Pronaći potencijalne defekte bez oslanjanja samo na konkretne ulaze.

- Clang Static Analyzer.
- CodeQL kao alat koji nije rađen na vežbama.
- CBMC nad pažljivo izdvojenim svojstvima, ako početni spike potvrdi izvodljivost.

## Faza 6: Izveštaj, reprodukcija i odbrana (Pending)

**Cilj:** Završiti `ProjectAnalysisReport.md`, proveriti sve skripte iz čistog checkout-a i pripremiti praktičnu demonstraciju.

- Svaki alat ima sopstveni direktorijum, skriptu, rezultate i zaključak.
- README sadrži tačne komande i konačan spisak zaključaka.
- Sve analize se mogu reprodukovati na računaru za odbranu.
- Svi otvoreni Issues nastavnika su rešeni pre odbrane.
