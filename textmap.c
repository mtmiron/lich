#include "lich.h"


static VALUE c_map;



static VALUE load_string(char[] str, VALUE ary)
{


static VALUE rb_load_file(VALUE self, VALUE rbfstr)
{
	char buf[65535] = { '\0'; }
	FILE *f;
	VALUE listary, rmobj;

	Check_Type(rbfstr, T_STRING);

	listary = rb_iv_get(c_map, "list");
	f = fopen(RSTRING(rbfstr)->ptr, "r");
	if (!f)
		rb_raise(rb_eStdError, "file not found: %s", RSTRING(rbfstr)->ptr);

	while (fgets(buf, sizeof(buf), f))
		load_string(buf, listary);
}



void Init_textmap()
{
	c_map = rb_eval("Map");
	rb_define_singleton_method(c_map, "load_text", rb_load_file, 1);
}
