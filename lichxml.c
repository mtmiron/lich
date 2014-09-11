/*
 * lichxml.c:
 *
 * 	A simple markup-language parser.
 *
 * 	Essentially a Ruby wrapper for the
 * 	GMarkupParser functions included in
 * 	glib-2.0.  Includes no error reporting;
 * 	code is written to silently compensate.
 *
 */

#include <glib.h>
/* #include <glib/gmarkup.h> */

#ifdef STANDALONE_PARSER
#	include <ruby.h>
#else
#	include "lich.h"
#endif


/* Speedup: only intern frequently-used strings once */
static ID id_call;
static ID id_cb_hash;
static ID id_text_callback;
static ID id_g_context;

static VALUE lich_cXML;
static GMarkupParser g_parser;



/*
 * Initialization function for all LichXML Ruby objects
 *
 */
static VALUE lichxml_init_func(VALUE self)
{
	VALUE rb_context;
	GMarkupParseContext *context;

	context = g_markup_parse_context_new(&g_parser, 0, (gpointer)self, NULL);
	rb_context = Data_Wrap_Struct(rb_cObject, NULL, g_markup_parse_context_free, context);

	rb_iv_set(self, "@g_context", rb_context);

	if ( !RTEST(rb_iv_get(self, "@cb_hash")) )
		rb_iv_set(self, "@cb_hash", rb_hash_new());

	g_markup_parse_context_parse(context, "<root>", 6, NULL);
	return self;
}


/*
 * Called to check if a Ruby object responds to an element
 * name as a method (for mixing in Ruby modules to LichXML
 * objects).
 *
 */
static inline int lichxml_mixin_check(const gchar *element_name, gpointer user_data)
{
	if ( !RTEST((VALUE)user_data) )
		return 0;
	else if ( rb_respond_to((VALUE)user_data, rb_intern(element_name)) )
		return 1;

	return 0;
}


/*
 * Construct a Ruby hash from two gchar** arrays.
 *
 */
static VALUE lichxml_make_arg_hash(const gchar **attr_names, const gchar **attr_values)
{
	int i;
	VALUE attribute_hash;

	if ( !attr_names || !attr_values )
		return Qnil;

	attribute_hash = rb_hash_new();
	for (i = 0; attr_names[i] != NULL; i++)
		rb_hash_aset(attribute_hash, rb_str_new2(attr_names[i]), rb_str_new2(attr_values[i]));

	return attribute_hash;
}


/*
 * Function called by glib whenever an element is opened (e.g. "<elementName>...").
 *
 * This function calls a Ruby proc object if a matching @cb_hash element is found.
 *
 */
static void lichxml_start_element(GMarkupParseContext *context,
                                   const gchar *element_name,
											  const gchar **attribute_names,
											  const gchar **attribute_values,
											  gpointer user_data,
											  GError **error)
{
	int i;
	VALUE cb_hash;
	VALUE cb_proc;
	VALUE attribute_hash;

	if ( lichxml_mixin_check(element_name, user_data) )
	{
		attribute_hash = lichxml_make_arg_hash(attribute_names, attribute_values);
		rb_funcall((VALUE)user_data, rb_intern(element_name), 1, attribute_hash);
		return;
	}

	cb_hash = rb_ivar_get((VALUE)user_data, id_cb_hash);
	if ( !RTEST(cb_hash) )
		rb_raise(rb_eStandardError, "current LichXML object unknown");

	cb_proc = rb_hash_aref(cb_hash, rb_str_new2(element_name));
	if ( !RTEST(cb_proc) )
		return;

	attribute_hash = lichxml_make_arg_hash(attribute_names, attribute_values);
	rb_funcall(cb_proc, id_call, 1, attribute_hash);
	return;
}


/*
 * Function called by glib whenever text is encountered
 *
 */
static void lichxml_text(GMarkupParseContext *context,
                         const gchar *text,
								 gsize text_len,
								 gpointer user_data,
								 GError **error)
{
	VALUE cb_proc;
	VALUE rbstr;

	cb_proc = rb_ivar_get((VALUE)user_data, id_text_callback);
	if ( NIL_P(cb_proc) )
		return;

	rbstr = rb_str_new((char*)text, (int)text_len);
	rb_funcall(cb_proc, id_call, 1, rbstr);
	return;
}


/*
 * Implements the Ruby method "LichXML#parse"
 *
 * If an error occurs, deallocates the previous (now useless)
 * GMarkupParseContext object and calls the above initialize func
 *
 */
static VALUE parse_rb_string(VALUE self, VALUE rb_str)
{
	gchar *gstr;
	GMarkupParseContext *g_context;

	gstr = RSTRING(rb_str)->ptr;
	Data_Get_Struct(rb_ivar_get(self, id_g_context), GMarkupParseContext, g_context);
	if (!g_markup_parse_context_parse(g_context, gstr, strlen(gstr), NULL))
	{
		g_markup_parse_context_free(g_context);
		lichxml_init_func(self);
	}

	return Qnil;
}


/*
 * Implements the Ruby method "LichXML#define_text_callback"
 *
 */
static VALUE define_rb_text_callback(VALUE self)
{
	rb_need_block();
	rb_iv_set(self, "@text_callback", rb_block_proc());
	return Qtrue;
}


/*
 * Implements the Ruby method "LichXML#define_callback"
 *
 */
static VALUE define_rb_callback(VALUE self, VALUE rb_key)
{
	VALUE block;
	VALUE cb_hash;

	rb_need_block();

	block = rb_block_proc();
	cb_hash = rb_iv_get(self, "@cb_hash");

	rb_hash_aset(cb_hash, rb_key, block);
	return Qtrue;
}


/*
 * Implements the Ruby method "LichXML#undefine_callback"
 *
 */
static VALUE undefine_rb_callback(VALUE self, VALUE rb_key)
{
	VALUE cb_hash = rb_iv_get(self, "@cb_hash");

	return rb_hash_delete(cb_hash, rb_key);
}


/*
 * Implements the Ruby method "LichXML#current_element"
 *
 */
static VALUE lichxml_get_current_element(VALUE self)
{
	GMarkupParseContext *context;
	const gchar *gstr;

	Data_Get_Struct(rb_iv_get(self, "@g_context"), GMarkupParseContext, context);
	gstr = g_markup_parse_context_get_element(context);
	return rb_str_new2(gstr);
}


/*
 * Perform initial environment setup; declare Ruby bindings, etc.
 *
 */
void Init_lichxml()
{
	g_parser.start_element = lichxml_start_element;
	g_parser.text = lichxml_text;
/*	g_parser.passthrough = lichxml_text; */

	id_call = rb_intern("call");
	id_g_context = rb_intern("@g_context");
	id_cb_hash = rb_intern("@cb_hash");
	id_text_callback = rb_intern("@text_callback");

	lich_cXML = rb_define_class("LichXML", rb_cObject);

	rb_define_attr(lich_cXML, "cb_hash", 1, 0);

	rb_define_method(lich_cXML, "initialize", lichxml_init_func, 0);
	rb_define_method(lich_cXML, "current_element", lichxml_get_current_element, 0);
	rb_define_method(lich_cXML, "parse", parse_rb_string, 1);

	rb_define_method(lich_cXML, "define_callback", define_rb_callback, 1);
	rb_define_method(lich_cXML, "undefine_callback", undefine_rb_callback, 1);
	rb_define_method(lich_cXML, "define_text_callback", define_rb_text_callback, 0);
}
