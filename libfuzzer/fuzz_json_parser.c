#include <stddef.h>
#include <stdint.h>

#include "json.h"

/*
 * Fuzzing harness povezuje libFuzzer sa javnim API-jem json-parser biblioteke.
 * Ovo nije deo originalnog upstream projekta, vec seminarski testni program.
 *
 * Opcija -fsanitize=fuzzer obezbedjuje main funkciju i mnogo puta poziva
 * LLVMFuzzerTestOneInput sa razlicitim ulazima. Harness zato nema svoj main.
 * Svaki poziv mora da prihvati i prazan, binaran, neispravan ili validan JSON
 * bez pretpostavke da je data nul-terminiran tekstualni string.
 */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
   /*
    * Nulta inicijalizacija bira podrazumevana podesavanja parsera. Promenljiva
    * value cuva koren DOM stabla kada parsiranje uspe, odnosno NULL kada
    * parser odbije ulaz.
    */
   json_settings settings = { 0 };
   json_value *value;

   /*
    * Prvi prolaz kroz harness testira strogi javni API json_parse.
    * data se kastuje u tip json_char koji API ocekuje, ali se bajtovi ne
    * menjaju niti kopiraju. Eksplicitni size je granica ulaza, pa strlen nije
    * potreban i ulaz sme da sadrzi ugradjeni NUL bajt.
    */
   value = json_parse((const json_char *)data, size);

   /*
    * Uspeh i neuspeh parsiranja moraju zavrsiti bez curenja memorije.
    * json_value_free oslobadja celo dobijeno DOM stablo, a poziv sa NULL je
    * bezbedan kada je parser odbio ulaz.
    */
   json_value_free(value);

   /*
    * Isti ulaz se zatim testira kroz prosireni API sa ukljucenim komentarima.
    * Time fuzzing pokriva i dodatne putanje za blokovske i linijske komentare,
    * a upravo je ova konfiguracija aktivirala dokumentovani UBSan nalaz.
    */
   settings.settings = json_enable_comments;
   value = json_parse_ex(
      &settings, (const json_char *)data, size, 0);
   json_value_free(value);

   /*
    * Nula znaci da je harness zavrsio obradu ulaza. Ne znaci da je ulaz validan
    * JSON. Pad procesa, ASan ili UBSan izvestaj predstavljaju nalaz fuzzinga.
    */
   return 0;
}
