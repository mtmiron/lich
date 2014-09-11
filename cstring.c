#include "lich.h"
#include <string.h>
#include <strings.h>
#include <unistd.h>


/*
 * Simple (reversable) stand-in for strfry().  This is in no way
 *  cryptographically sound and is useful only for obfuscation.
 *
 */
static VALUE
strfry_thunk(VALUE self)
{
	char *ptr, c;
	int i, len;

	ptr = RSTRING(self)->ptr;
	len = RSTRING(self)->len;
	swab(ptr);

	for (i = 0; i < len; i++)
	{
		c = ptr[i];
		ptr[i] = ptr[len - i];
		ptr[len - i] = c;
	}
	return self;
}


/*
 * The limitations above are fully applicable here as well.
 *  Ruby-wrapper for the memfrob() func.
 *
 */
static VALUE
memfrob_thunk(VALUE self)
{
	Check_Type(self, T_STRING);

	memfrob(RSTRING(self)->ptr);
	return self;
}


void
Init_cstring()
{
	extern VALUE rb_cString;

	rb_define_method(rb_cString, "strfry", strfry_thunk, 0);
	rb_define_method(rb_cString, "memfrob", memfrob_thunk, 0);
}
