#include <stddef.h>
#include <stdint.h>
#include <unistd.h>

#include "json.h"

/* AFL++ harness: cita ulaz sa stdin, prosledjuje parseru u oba rezima. */
int main(void)
{
   uint8_t buffer[4096];
   size_t length;
   json_settings settings = { 0 };
   json_value *value;

   length = read(0, buffer, sizeof(buffer) - 1);
   if (length == (size_t)-1)
      return 0;

   buffer[length] = 0;

   /* Strogi rezim */
   value = json_parse((const json_char *)buffer, length);
   json_value_free(value);

   /* Rezim sa komentarima */
   settings.settings = json_enable_comments;
   value = json_parse_ex(&settings, (const json_char *)buffer, length, 0);
   json_value_free(value);

   return 0;
}
