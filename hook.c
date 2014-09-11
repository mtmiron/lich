#include "lich.h"


extern VALUE rb_cProc;
VALUE lich_cHook;

static VALUE hook_enable(VALUE);


/* Exception-safe wrapper to protect hook calls */
static VALUE hook_call_internal(VALUE *ary)
{
	VALUE hook;
	VALUE str;
	
	hook = ary[0];
	str = ary[1];

	rb_funcall(hook, rb_intern("call"), 1, str);
	return Qnil;
}

/* Find and call a matching Hook object */
static VALUE hook_match_call(VALUE self, VALUE str)
{
	int i, len;
	VALUE regex, disab, klass_ary, *aptr, argary[2];

	rb_secure(1);
	klass_ary = rb_cv_get(lich_cHook, "@@hook_list");
	len = RARRAY(klass_ary)->len;
	aptr = RARRAY(klass_ary)->ptr;

	for (i = 0; i < len; i++)
	{
		disab = rb_iv_get(aptr[i], "@disabled");
		if (RTEST(disab))
			continue;

		regex = rb_iv_get(aptr[i], "@regex");
		if ( RTEST(rb_funcall(regex, rb_intern("match"), 1, str)) )
		{
			argary[0] = aptr[i];
			argary[1] = str;
			rb_rescue(hook_call_internal, (VALUE)argary, NULL, 0);
			return Qtrue;
		}
	}
	return Qfalse;
}

/* Find and return a matching Hook object */
static VALUE hook_match(VALUE klass, VALUE str)
{
	int i, len;
	VALUE regex, ary, *aptr;

	rb_secure(1);
	ary = rb_cv_get(lich_cHook, "@@hook_list");
	len = RARRAY(ary)->len;
	aptr = RARRAY(ary)->ptr;

	for (i = 0; i < len; i++)
	{
		regex = rb_iv_get(aptr[i], "@regex");
		if ( RTEST(rb_funcall(regex, rb_intern("match"), 1, str)) )
			return aptr[i];
	}
	return Qnil;
}

/* Initialize hook object */
static VALUE hook_initialize(VALUE self, VALUE regex)
{
	VALUE ary;

	rb_secure(1);
	if ( !rb_respond_to(regex, rb_intern("match")) )
		rb_raise(rb_eArgError, "argument must respond to :match");

	hook_enable(self);
	rb_iv_set(self, "@regex", regex);
	ary = rb_cv_get(lich_cHook, "@@hook_list");
	rb_ary_push(ary, self);
	return self;
}

/* Disable -- but do not delete -- hook */
static VALUE hook_disable(VALUE self)
{
	rb_secure(1);
	rb_iv_set(self, "@disabled", Qtrue);
	return self;
}

/* Enable hook */
static VALUE hook_enable(VALUE self)
{
	rb_secure(1);
	rb_iv_set(self, "@disabled", Qfalse);
	return self;
}

/* Release (delete) hook */
static VALUE hook_release(VALUE self)
{
	VALUE cary;

	rb_secure(1);
	cary = rb_cv_get(lich_cHook, "@@hook_list");
	return rb_ary_delete(cary, self);
}

/* Release (delete) a matching hook */
static VALUE hook_s_release(VALUE klass, VALUE str)
{
	VALUE hook;

	rb_secure(1);
	hook = hook_match(klass, str);
	return hook_release(hook);
}

/* Effectively a synonym for Hook.new */
static VALUE hook_register(VALUE self, VALUE regex)
{
	VALUE hook;

	rb_secure(1);
	rb_need_block();
	if ( !rb_respond_to(regex, rb_intern("match")) )
		rb_raise(rb_eArgError, "argument must respond to :match");

	hook = rb_block_proc();
	RDATA(hook)->basic.klass = lich_cHook;
	hook_initialize(hook, regex);
	return hook;
}

/* Runtime bindings */
void Init_hook()
{
	lich_cHook = rb_define_class("Hook", rb_cProc);
	rb_cv_set(lich_cHook, "@@hook_list", rb_ary_new());

	rb_define_singleton_method(lich_cHook, "register", hook_register, 1);
	rb_define_singleton_method(lich_cHook, "delete", hook_s_release, 1);
	rb_define_singleton_method(lich_cHook, "release", hook_s_release, 1);
	rb_define_singleton_method(lich_cHook, "match", hook_match, 1);
	rb_define_singleton_method(lich_cHook, "call", hook_match_call, 1);

	rb_define_method(lich_cHook, "initialize", hook_initialize, 1);
	rb_define_method(lich_cHook, "disable", hook_disable, 0);
	rb_define_method(lich_cHook, "enable", hook_enable, 0);
	rb_define_method(lich_cHook, "release", hook_release, 0);
	rb_define_method(lich_cHook, "delete", hook_release, 0);

#ifdef __MINGW32__
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("hook.dll"));
#else
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("hook.so"));
#endif
}
