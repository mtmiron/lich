/* FIXME: partial implementation of a single array tracking which game lines are necessary to retain and which aren't.  This is an optomized version of the current implementation, which maintains one array for each active script: current design wastes RAM with duplicate strings and runs in O(n) time, whereas the single-array scheme runs in flat ordinal time */

#include "lich.h"


extern VALUE rb_cScript;
static VALUE dary;
static VALUE minidx;

static ID id_lineno;
static ID id_list;



static VALUE
lich_script_s_puts(int argc, VALUE *argv, VALUE self)
{
	while (argc--)
	{
		rb_ary_store(dary, RARRAY(dary)->len, *argv++)
	}
	return dary;
}


static VALUE
lich_script_gets(VALUE self)
{
	VALUE rb_curidx, rb_scrlist;
	int scridx, offset;
	static int count = 0;

	if (RBASIC(self)->klass != rb_cScript)
	{
		rb_raise(rb_eArgumentError, "object is of type `%s' (expected Script)", rb_class_of(self));
	}

	rb_scridx = rb_iv_get(self, id_lineno);
	scridx = FIX2INT(rb_scridx);

	if (scridx < minidx)
	{
		off

void
Init_scriptio()
{
	rb_define_singleton_method(rb_cScript, "puts", lich_script_s_puts, -1);
	rb_define_method(rb_cScript, "gets", lich_script_gets, 0);

	id_lineno = rb_intern("@scriptio_lineno");
	dbuffer = rb_ary_new();
	rb_cvar_set(rb_cScript, rb_intern("@@data_buffer"), dbuffer);
}
