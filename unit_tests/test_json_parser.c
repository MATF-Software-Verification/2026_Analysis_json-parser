#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "json.h"

static unsigned tests_run = 0;
static unsigned tests_failed = 0;
static int known_issues_mode = 0;

#define CHECK(condition) do { \
   ++tests_run; \
   if (!(condition)) { \
      ++tests_failed; \
      fprintf(stderr, "%s %s:%d: %s\n", \
         known_issues_mode ? "ODSTUPANJE" : "NEUSPEH", \
         __FILE__, __LINE__, #condition); \
   } \
} while (0)

/* Parsira prosledjeni tekst koristeci jednostavni javni API biblioteke. */
static json_value *parse_text(const char *text)
{
   return json_parse(text, strlen(text));
}

/* Pronalazi vrednost clana JSON objekta na osnovu imena kljuca. */
static json_value *object_member(json_value *object, const char *name)
{
   unsigned int i;

   if (!object || object->type != json_object)
      return 0;

   for (i = 0; i < object->u.object.length; ++i)
   {
      json_object_entry *entry = &object->u.object.values[i];
      size_t name_length = strlen(name);

      if (entry->name_length == name_length &&
          memcmp(entry->name, name, name_length) == 0)
      {
         return entry->value;
      }
   }

   return 0;
}

/* Proverava parsiranje prostih JSON vrednosti na korenu dokumenta. */
static void test_root_primitives(void)
{
   json_value *value;

   value = parse_text("29");
   CHECK(value != 0);
   CHECK(value && value->type == json_integer);
   CHECK(value && value->u.integer == 29);
   json_value_free(value);

   value = parse_text("-3.25e2");
   CHECK(value != 0);
   CHECK(value && value->type == json_double);
   CHECK(value && value->u.dbl == -325.0);
   json_value_free(value);

   value = parse_text("true");
   CHECK(value && value->type == json_boolean && value->u.boolean == 1);
   json_value_free(value);

   value = parse_text("false");
   CHECK(value && value->type == json_boolean && value->u.boolean == 0);
   json_value_free(value);

   value = parse_text("null");
   CHECK(value && value->type == json_null);
   json_value_free(value);
}

/* Proverava strukturu i sadrzaj ugnjezdenog DOM stabla. */
static void test_nested_dom(void)
{
   const char *text =
      "{\"name\":\"Milos\",\"active\":true,\"scores\":[8,9,10],"
      "\"address\":{\"city\":\"Beograd\"}}";
   json_value *root = parse_text(text);
   json_value *name;
   json_value *active;
   json_value *scores;
   json_value *address;
   json_value *city;

   CHECK(root != 0);
   CHECK(root && root->type == json_object);
   CHECK(root && root->type == json_object && root->u.object.length == 4);

   name = object_member(root, "name");
   CHECK(name && name->type == json_string);
   CHECK(name && name->type == json_string && name->u.string.length == 5);
   CHECK(name && name->type == json_string && name->u.string.ptr &&
         memcmp(name->u.string.ptr, "Milos", 5) == 0);
   CHECK(name && name->parent == root);

   active = object_member(root, "active");
   CHECK(active && active->type == json_boolean && active->u.boolean == 1);

   scores = object_member(root, "scores");
   CHECK(scores && scores->type == json_array);
   CHECK(scores && scores->type == json_array && scores->u.array.length == 3);
   CHECK(scores && scores->type == json_array && scores->u.array.values &&
         scores->u.array.length > 0 && scores->u.array.values[0] &&
         scores->u.array.values[0]->type == json_integer &&
         scores->u.array.values[0]->u.integer == 8);
   CHECK(scores && scores->type == json_array && scores->u.array.values &&
         scores->u.array.length > 2 && scores->u.array.values[2] &&
         scores->u.array.values[2]->type == json_integer &&
         scores->u.array.values[2]->u.integer == 10);
   CHECK(scores && scores->type == json_array && scores->u.array.values &&
         scores->u.array.length > 1 && scores->u.array.values[1] &&
         scores->u.array.values[1]->parent == scores);

   address = object_member(root, "address");
   CHECK(address && address->type == json_object);
   city = object_member(address, "city");
   CHECK(city && city->type == json_string);
   CHECK(city && city->type == json_string && city->u.string.length == 7);
   CHECK(city && city->type == json_string && city->u.string.ptr &&
         memcmp(city->u.string.ptr, "Beograd", 7) == 0);

   json_value_free(root);
}

/* Proverava escape sekvence, nul-bajt i Unicode obradu stringova. */
static void test_strings_and_unicode(void)
{
   json_value *value;
   const char expected_with_nul[] = { 'a', 'b', 'c', '\0', 'd', 'e', 'f' };
   const unsigned char euro_utf8[] = { 0xE2, 0x82, 0xAC };

   value = parse_text("\"line\\nnext\"");
   CHECK(value && value->type == json_string);
   CHECK(value && value->type == json_string && value->u.string.length == 9);
   CHECK(value && value->type == json_string && value->u.string.ptr &&
         memcmp(value->u.string.ptr, "line\nnext", 9) == 0);
   json_value_free(value);

   value = parse_text("\"abc\\u0000def\"");
   CHECK(value && value->type == json_string);
   CHECK(value && value->type == json_string && value->u.string.length == 7);
   CHECK(value && value->type == json_string && value->u.string.ptr &&
         memcmp(value->u.string.ptr, expected_with_nul, 7) == 0);
   CHECK(value && value->type == json_string && value->u.string.ptr &&
         value->u.string.length == 7 && value->u.string.ptr[7] == '\0');
   json_value_free(value);

   value = parse_text("\"\\u20AC\"");
   CHECK(value && value->type == json_string);
   CHECK(value && value->type == json_string && value->u.string.length == 3);
   CHECK(value && value->type == json_string && value->u.string.ptr &&
         memcmp(value->u.string.ptr, euro_utf8, 3) == 0);
   json_value_free(value);
}

/* Proverava odbijanje nevalidnih ulaza i popunjavanje opisa greske. */
static void test_invalid_inputs_and_errors(void)
{
   static const char *invalid[] = {
      "",
      "[1 2]",
      "[01]",
      "tru",
      "\"unterminated",
      "true false"
   };
   unsigned int i;

   for (i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i)
   {
      json_settings settings = { 0 };
      char error[json_error_max] = { 0 };
      json_value *value = json_parse_ex(
         &settings, invalid[i], strlen(invalid[i]), error);

      CHECK(value == 0);
      CHECK(error[0] != '\0');
      json_value_free(value);
   }
}

/* Proverava da parser postuje eksplicitno prosledjenu duzinu ulaza. */
static void test_explicit_length_boundary(void)
{
   const char buffer[] = "true trailing";
   json_value *value;

   value = json_parse(buffer, 4);
   CHECK(value && value->type == json_boolean && value->u.boolean == 1);
   json_value_free(value);

   value = json_parse(buffer, strlen(buffer));
   CHECK(value == 0);
}

/* Proverava razliku izmedju strogog rezima i rezima sa komentarima. */
static void test_comment_modes(void)
{
   const char *text = "/* komentar */ {\"a\": 1} // kraj";
   json_settings settings = { 0 };
   char error[json_error_max] = { 0 };
   json_value *value;

   value = json_parse_ex(&settings, text, strlen(text), error);
   CHECK(value == 0);
   CHECK(error[0] != '\0');

   memset(&settings, 0, sizeof(settings));
   memset(error, 0, sizeof(error));
   settings.settings = json_enable_comments;
   value = json_parse_ex(&settings, text, strlen(text), error);
   CHECK(value && value->type == json_object);
   CHECK(value && object_member(value, "a") != 0);
   json_value_free(value);
}

/* Proverava granice celih brojeva i prelazak na double reprezentaciju. */
static void test_number_boundaries(void)
{
   char max_text[64];
   json_value *value;

   sprintf(max_text, "%ld", LONG_MAX);
   value = parse_text(max_text);
   CHECK(value && value->type == json_integer);
   CHECK(value && value->type == json_integer && value->u.integer == LONG_MAX);
   json_value_free(value);

   value = parse_text("999999999999999999999999999999999999");
   CHECK(value && value->type == json_double);
   json_value_free(value);

   value = parse_text("1e309");
   CHECK(value && value->type == json_double);
   json_value_free(value);
}

typedef struct
{
   unsigned long allocations;
   unsigned long frees;
} allocation_stats;

/* Alocira memoriju i broji uspesne alokacije testnog alokatora. */
static void *counting_alloc(size_t size, int zero, void *user_data)
{
   allocation_stats *stats = (allocation_stats *)user_data;
   void *result = zero ? calloc(1, size) : malloc(size);

   if (result)
      ++stats->allocations;

   return result;
}

/* Oslobadja memoriju i broji oslobadjanja testnog alokatora. */
static void counting_free(void *ptr, void *user_data)
{
   allocation_stats *stats = (allocation_stats *)user_data;

   if (ptr)
      ++stats->frees;

   free(ptr);
}

/* Proverava balans alokacija i oslobadjanja na obe putanje parsiranja. */
static void test_custom_allocator_and_cleanup(void)
{
   const char *valid = "{\"a\":[1,2,3],\"b\":\"text\"}";
   const char *invalid = "{\"a\":[1,2,}";
   json_settings settings = { 0 };
   allocation_stats stats = { 0, 0 };
   char error[json_error_max] = { 0 };
   json_value *value;

   settings.mem_alloc = counting_alloc;
   settings.mem_free = counting_free;
   settings.user_data = &stats;

   value = json_parse_ex(&settings, valid, strlen(valid), error);
   CHECK(value != 0);
   json_value_free_ex(&settings, value);
   CHECK(stats.allocations == stats.frees);

   stats.allocations = 0;
   stats.frees = 0;
   memset(error, 0, sizeof(error));
   value = json_parse_ex(&settings, invalid, strlen(invalid), error);
   CHECK(value == 0);
   CHECK(error[0] != '\0');
   CHECK(stats.allocations == stats.frees);
}

/* Proverava ponasanje parsera sa premalim i dovoljnim limitom memorije. */
static void test_memory_limit(void)
{
   const char *text = "{\"name\":\"Milos\",\"values\":[1,2,3]}";
   json_settings settings = { 0 };
   char error[json_error_max] = { 0 };
   json_value *value;

   settings.max_memory = 1;
   value = json_parse_ex(&settings, text, strlen(text), error);
   CHECK(value == 0);
   CHECK(strstr(error, "Memory allocation failure") != 0);

   memset(&settings, 0, sizeof(settings));
   memset(error, 0, sizeof(error));
   settings.max_memory = 65536;
   value = json_parse_ex(&settings, text, strlen(text), error);
   CHECK(value != 0);
   json_value_free(value);
}

/* Proverava pracenje reda izvornog dokumenta uz JSON_TRACK_SOURCE. */
static void test_source_tracking(void)
{
   const char *text = "{\n  \"value\": 42\n}";
   json_value *root = parse_text(text);
   json_value *value = object_member(root, "value");

   CHECK(root != 0);
#ifdef JSON_TRACK_SOURCE
   CHECK(root && root->line == 1);
   CHECK(value && value->line == 2);
#else
   CHECK(0 && "Test mora biti preveden sa JSON_TRACK_SOURCE");
#endif
   json_value_free(root);
}

/* Reprodukuje dokumentovana odstupanja od ocekivanog ponasanja. */
static void test_known_issues(void)
{
   const char *source_text = "{\n  \"value\": 42\n}";
   json_value *value;
   json_value *member;

   value = parse_text("{\"a\":1,}");
   if (value != 0)
      printf("REPRODUKOVANO: zavrsni-zarez-objekat\n");
   CHECK(value == 0);
   json_value_free(value);

   value = parse_text("[1,2,]");
   if (value != 0)
      printf("REPRODUKOVANO: zavrsni-zarez-niz\n");
   CHECK(value == 0);
   json_value_free(value);

   value = parse_text(source_text);
   member = object_member(value, "value");
#ifdef JSON_TRACK_SOURCE
   if (member && member->col == 0)
      printf("REPRODUKOVANO: kolona-uvek-nula\n");
   CHECK(member && member->col > 0);
#else
   CHECK(0 && "Test mora biti preveden sa JSON_TRACK_SOURCE");
#endif
   json_value_free(value);
}

/* Bira rezim rada, pokrece testove i vraca zbirni status programa. */
int main(int argc, char **argv)
{
   if (argc == 2 && strcmp(argv[1], "--poznati-nalazi") == 0)
   {
      known_issues_mode = 1;
      test_known_issues();
      printf("Provera poznatih nalaza: %u\n", tests_run);
      printf("Reprodukovanih odstupanja: %u\n", tests_failed);
      return tests_failed == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
   }

   test_root_primitives();
   test_nested_dom();
   test_strings_and_unicode();
   test_invalid_inputs_and_errors();
   test_explicit_length_boundary();
   test_comment_modes();
   test_number_boundaries();
   test_custom_allocator_and_cleanup();
   test_memory_limit();
   test_source_tracking();

   printf("Izvrseno provera: %u\n", tests_run);
   printf("Neuspesnih provera: %u\n", tests_failed);

   return tests_failed == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
