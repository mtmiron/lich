#include <expat.h>
#include "lich.h"

#define CALLBACKS (rb_const_get(cXMLParser, rb_intern("CALLBACKS")))

struct callback {
	void (*func)(const char **attr);
};

void callback_register(const char *str, void (*func)());


static void tag_start(void *data, const char *el, const char **attr);
static void tag_end(void *data, const char *el);
static void text_handler(void *data, const char *text, int len);
VALUE parser_get_context();

static XML_Parser p;
static VALUE cStream;
VALUE cXMLParser;



XML_Parser
init_parser()
{
	char root[] = "<root>";
	p = XML_ParserCreate(NULL);

	XML_UseParserAsHandlerArg(p);
	XML_SetElementHandler(p, tag_start, tag_end);
	XML_SetCharacterDataHandler(p, text_handler);
	XML_Parse(p, root, strlen(root), 0);
	return p;
}

VALUE
parser_get_context()
{
	VALUE context, stream;

	context = rb_cv_get(cStream, "@@context");
	stream = rb_cv_get(cXMLParser, "@@stream");

	if (!RARRAY(context)->len)
		return rb_hash_aref(stream, rb_str_new2("main"));
	else
		return RARRAY(context)->ptr[RARRAY(context)->len - 1];
}

VALUE
rb_def_callback(VALUE self, VALUE str)
{
	rb_need_block();
	return rb_hash_aset(CALLBACKS, str, rb_block_proc());
}

void
callback_register(str, func)
	const char *str;
	void (*func)();
{
	struct callback *buf;

	rb_hash_aset(CALLBACKS, rb_str_new2(str), Data_Make_Struct(rb_cObject, struct callback, NULL, free, buf));
	buf->func = func;
}

static VALUE
get_callback_proc(val, attr)
	VALUE val;
	const char **attr;
{
	VALUE buf = val;

	while (TYPE(buf) == T_HASH && attr[0])
	{
		buf = rb_hash_aref(buf, rb_str_new2(attr[1]));
	}
	return buf;
}

static void *
get_callback_func(el)
	const char *el;
{
	struct callback *cb;
	VALUE func;

	func = rb_hash_aref(CALLBACKS, rb_str_new2(el));
	if (NIL_P(func)) return (void *)(-1);
	Data_Get_Struct(func, struct callback, cb);
	if (cb) return cb->func;
	return (void *)(-1);
}

static void
text_handler(data, text, len)
	void *data;
	const char *text;
	int len;
{
	VALUE cur = parser_get_context();
	
	rb_funcall(cur, rb_intern("write"), 1, rb_str_new(text, len));
}

static void
tag_start(data, el, attr)
	void *data;
	const char *el, **attr;
{
	int i = 0;
	void (*func)();
	VALUE proc = rb_hash_aref(CALLBACKS, rb_str_new2(el));
	VALUE hash;

	proc = get_callback_proc(proc, attr);
	if (!NIL_P(proc)) {
		hash = rb_hash_new();
		while (attr[i])
		{
			rb_hash_aset(hash, rb_str_new2(attr[i]), rb_str_new2(attr[i + 1]));
			i += 2;
		}
		rb_funcall(proc, rb_intern("call"), 1, hash);
		return;
	}

	func = get_callback_func(el);
	if ((int)func != -1) func(attr);
}

static void
tag_end(data, el)
	void *data;
	const char *el;
{
	char buf[strlen(el) + 1];
	const char *attr[] = { (char *)NULL };

	memset(buf, '\0', sizeof(buf));
	strcpy(buf, "/");
	strcat(buf, el);
	tag_start(data, &buf[0], attr);
}

static VALUE
xmlparser_parse(self, str)
	VALUE self, str;
{
	XML_Parse(p, RSTRING(str)->ptr, RSTRING(str)->len, 0);
	return Qnil;
}
	
void
Init_xmlparser()
{
	cXMLParser = rb_define_class("XMLParser", rb_cObject);
	cStream = rb_define_class_under(cXMLParser, "Stream", rb_cObject);

	rb_define_const(cXMLParser, "CALLBACKS", rb_hash_new());
	rb_define_singleton_method(cXMLParser, "parse", xmlparser_parse, 1);

	init_parser();
}
