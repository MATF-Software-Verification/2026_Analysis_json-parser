#include <stddef.h>
#include <stdint.h>
#include <unistd.h>

#include "json.h"

/*
 * AFL++ harness: običan izvršni program kojim upravlja spoljašnji afl-fuzz
 * proces. Za razliku od libFuzzer harnessa, ovde postoji main(), a svaki
 * generisani test case stiže preko standardnog ulaza (file descriptor 0).
 */
int main(void)
{
   /*
    * Obrađujemo najviše 4095 ulaznih bajtova. Poslednji bajt je rezervisan za
    * završni NUL radi bezbednog predstavljanja sadržaja kao C stringa, iako
    * parseru uvek prosleđujemo stvarnu dužinu ulaza.
    */
   uint8_t buffer[4096];
   size_t length;
   json_settings settings = { 0 };
   json_value *value;

   /* Jedan read() je dovoljan jer AFL++ za svaki test pokreće novi harness i
    * prosleđuje mali test case preko stdin-a. -1 označava grešku čitanja; ona
    * nije parser crash, pa harness završava bez prijavljivanja nalaza. */
   length = read(0, buffer, sizeof(buffer) - 1);
   if (length == (size_t)-1)
      return 0;

   /* Dodatni NUL nije deo fuzzovanog inputa: obe API funkcije dobijaju length. */
   buffer[length] = 0;

   /* Strogi režim: komentari i druga proširenja nisu omogućeni. NULL rezultat
    * znači da parser odbija ulaz; json_value_free(NULL) je podržan poziv. */
   value = json_parse((const json_char *)buffer, length);
   json_value_free(value);

   /* Drugi prolaz nad istim bajtovima uključuje podršku za komentare. Tako
    * jedna AFL++ kampanja istražuje obe javne putanje parsera. */
   settings.settings = json_enable_comments;
   value = json_parse_ex(&settings, (const json_char *)buffer, length, 0);
   json_value_free(value);

   /* AFL++ prirodni crash registruje preko signala, a hang preko timeout-a.
    * Status 0 znači da oba parser poziva za ovaj ulaz nisu srušila proces. */
   return 0;
}
