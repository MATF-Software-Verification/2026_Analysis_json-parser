#include <stddef.h>
#include <stdint.h>

#include "json.h"

/* Prosledjuje proizvoljan binarni ulaz kroz strogi i comments rezim parsera. */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
   json_settings settings = { 0 };
   json_value *value;

   value = json_parse((const json_char *)data, size);
   json_value_free(value);

   settings.settings = json_enable_comments;
   value = json_parse_ex(
      &settings, (const json_char *)data, size, 0);
   json_value_free(value);

   return 0;
}
