#include "lich.h"

/*
 * Silly little parser to squeeze as much speed
 * as possible out of Wizard script interpreting
 *
 */




extern ID id_chop;
extern ID id_strip;

static ID id_lines;
static ID id_labels;


/* Take advantage of the compiler's switch() efficiency */
static int
wizard_label_switch(char *ptr, int len)
{
	int i;

	for (i = 0; i < len; i++)
	{
		switch (ptr[i])
		{
			case 'A':	case 'B':	case 'C':
			case 'D':	case 'E':	case 'F':
			case 'G':	case 'H':	case 'I':
			case 'J':	case 'K':	case 'L':
			case 'M':	case 'N':	case 'O':
			case 'P':	case 'Q':	case 'R':
			case 'S':	case 'T':	case 'U':
			case 'V':	case 'W':	case 'X':
			case 'Y':	case 'Z':

			case 'a':	case 'b':	case 'c':
			case 'd':	case 'e':	case 'f':
			case 'g':	case 'h':	case 'i':
			case 'j':	case 'k':	case 'l':
			case 'm':	case 'n':	case 'o':
			case 'p':	case 'q':	case 'r':
			case 's':	case 't':	case 'u':
			case 'v':	case 'w':	case 'x':
			case 'y':	case 'z':

			case '0':	case '1':	case '2':
			case '3':	case '4':	case '5':
			case '6':	case '7':	case '8':
			case '9':

			case '_':	case '\r':	case '\n':
			case '-':	case '%':
				continue;

			case ':':	/* Hit a colon before any illegal label chars: guaranteed to be a label */
				return 1;
			
			default:	/* Whitespace, punctuation, comment (#), etc. -- can't be a label */
				return 0;
		}
	}
	return 0;
}


/* Parse the whole file and return a hash of { "label" => line_no } pairs */
static VALUE
wizard_parse_file(VALUE self, VALUE file)
{
	FILE *fptr;
	OpenFile *of;
	char buffer[4096] = { '\0' };
	int i, slen, size = sizeof(buffer);
	VALUE s, hash = rb_hash_new(), ary = rb_ary_new();

	Check_Type(file, T_FILE);
	GetOpenFile(file, of);

	if (!of)
		return Qnil;
	fptr = of->f;
	if (!fptr)
		return Qnil;

	for (i = 0; fgets(buffer, size, fptr); i++)
	{
		slen = strlen(buffer);
		if (buffer[slen - 1] == '\n')
		{
			buffer[--slen] = '\0';
			if (buffer[slen - 1] == '\r')
				buffer[--slen] = '\0';
		}
		s = rb_str_new(buffer, slen);

		if (wizard_label_switch(buffer, slen))
		{
			s = rb_funcall(s, id_strip, 0);
			s = rb_funcall(s, id_chop, 0);
			rb_hash_aset(hash, s, INT2FIX(i));
			rb_ary_push(ary, rb_str_new2(""));
		}
		else
		{
			rb_ary_push(ary, s);
		}
	}

	rb_ivar_set(self, id_lines, ary);
	rb_ivar_set(self, id_labels, hash);
	return Qtrue;
}


static VALUE
wizard_label_check(VALUE klass, VALUE str)
{
	if (wizard_label_switch(RSTRING(str)->ptr, RSTRING(str)->len))
		return Qtrue;
	else
		return Qfalse;
}


void
Init_wizardparser()
{
	lich_cScript = rb_eval_string("Script");
	rb_define_singleton_method(lich_cScript, "wizard_label_check", wizard_label_check, 1);
	rb_define_method(lich_cScript, "wizard_parse_file", wizard_parse_file, 1);

	id_lines = rb_intern("@lines");
	id_labels = rb_intern("@labels");

	rb_global_variable(&id_lines);
	rb_global_variable(&id_labels);

#ifdef __MINGW32__
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("wizardparser.dll"));
#else
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("wizardparser.so"));
#endif
}
