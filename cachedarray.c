#include "lich.h"
#include <sys/types.h>
#include <unistd.h>

#ifndef LICH_CACHE_MAX_SIZE
#  define LICH_CACHE_MAX_SIZE 64
#endif

/*
 *
 * Implements arrays that store only a fixed amount in RAM,
 * caching anything beyond that in a tempfile on the HDD.
 *
 */

static VALUE lich_cache_dump(VALUE);
static VALUE lich_cache_setname(VALUE);


VALUE lich_cCachedAry;
static int lich_cache_max_size;
extern VALUE rb_cArray;
static VALUE rb_mObSpace;

static ID id_dir;
static ID id_file;
static ID id_filename;
static ID id_define_finalizer;


static char *
lich_cache_dirname()
{
	char pwd[512] = { '\0' };
	char *tmpdir;
	VALUE cv_dir;

	cv_dir = rb_cvar_get(lich_cCachedAry, id_dir);
	if (RTEST(cv_dir))
		return strdup(RSTRING(cv_dir)->ptr);

	(tmpdir = getenv("TEMP")) ||
	(tmpdir = getenv("TMP")) ||
	(tmpdir = getenv("TMPDIR"));

	if (tmpdir)
		return strdup(tmpdir);

	getcwd(pwd, sizeof(pwd));
	return strdup(pwd);
}


static VALUE
lich_cache_s_dir(VALUE klass)
{
	char *dptr;
	VALUE dir;
	
	dptr = lich_cache_dirname();
	dir = rb_str_new2(dptr);
	free(dptr);
	return dir;
}


static VALUE
lich_cache_openfile(VALUE self)
{
	char *filename;
	VALUE rfile = Qfalse;

	if ( CLASS_OF(self) != lich_cCachedAry )
		rb_raise(rb_eArgError, "object of type `%s' expected (`%s' received)", rb_class2name(lich_cCachedAry), rb_class2name(CLASS_OF(self)));

	rfile = rb_ivar_get(self, id_file);
	if (RTEST(rfile))
		return rfile;

	filename = RSTRING(lich_cache_setname(self))->ptr;
	rfile = rb_file_open(filename, "wb+");
	rb_ivar_set(self, id_file, rfile);
	return rfile;
}


static VALUE
lich_cache_setname(VALUE self)
{
	char buffer[512] = { '\0' };
	char separator, *dptr;
	VALUE name;

	if ( CLASS_OF(self) != lich_cCachedAry )
		rb_raise(rb_eArgError, "object of type `%s' expected (`%s' given)",
		         rb_class2name(lich_cCachedAry),
		         rb_class2name(CLASS_OF(self)));

	name = rb_ivar_get(self, id_filename);
	if (RTEST(name))
		return name;

	if (getenv("windir"))
		separator = '\\';
	else
		separator = '/';

	dptr = lich_cache_dirname();
	snprintf(buffer, sizeof(buffer), "%s%c.cache.%d.%d", dptr, separator, getpid(), abs(NUM2LONG(rb_obj_id(self))) );
	free(dptr);
	return rb_ivar_set(self, id_filename, rb_str_new2(buffer));
}


/* Finalizer called by the GC anytime a CachedArray object is sweeped away; ensures deletion of the tempfile. */
static VALUE
lich_cache_finalize(VALUE self, VALUE arg)
{
	VALUE fname, fobj;

	fname = rb_ivar_get(self, id_filename);
	fobj = rb_ivar_get(self, id_file);
	if (RTEST(fobj))
		rb_io_close(fobj);

	if (!RTEST(fname))
	{
		fname = rb_ivar_get(arg, id_filename);
		fobj = rb_ivar_get(arg, id_file);
		if (RTEST(fobj))
			rb_io_close(fobj);
	}

	unlink(RSTRING(fname)->ptr);
	return Qnil;
}


static VALUE
lich_cache_purge(VALUE self)
{
	VALUE fname;

	fname = rb_ivar_get(self, id_filename);
	if (!RTEST(fname))
		fname = lich_cache_setname(self);

	unlink(RSTRING(fname)->ptr);
	return Qnil;
}


static VALUE
lich_cache_init(VALUE self)
{
	VALUE proc;

	lich_cache_setname(self);
	proc = rb_proc_new(lich_cache_finalize, self);
//	return rb_funcall(rb_mObSpace, id_define_finalizer, 2, self, proc);
	rb_funcall(rb_mObSpace, id_define_finalizer, 2, self, proc);
	return Qnil;
}


static VALUE
lich_cache_size_check(int argc, VALUE *argv, VALUE self)
{
	int len = RARRAY(self)->len;

	if (len >= lich_cache_max_size)
		lich_cache_dump(self);
	return rb_call_super(argc, argv);
}


static VALUE
lich_cache_dump(VALUE self)
{
	VALUE *aptr, filename = rb_ivar_get(self, id_filename);
	int len, i;
	char *sptr, *end;
	OpenFile *of;
	FILE *f;

	if (!RTEST(filename))
		filename = lich_cache_setname(self);

	len = RARRAY(self)->len;
	aptr = RARRAY(self)->ptr;
	GetOpenFile(lich_cache_openfile(self), of);
	f = GetWriteFile(of);
	if (!f)
		rb_raise(rb_eSystemCallError, strerror(errno));

	for (i = 0; i < len; i++)
	{
		sptr = RSTRING(aptr[i])->ptr;
		end = &sptr[RSTRING(aptr[i])->len - 1];
		fputs(sptr, f);
		if (*end != '\n')
#ifdef __MINGW32__
			fputs("\r\n", f);
#else
			fputs("\n", f);
#endif
	}
	return rb_ary_clear(self);
}


static VALUE
lich_cache_history(VALUE self)
{
	FILE *f;
	OpenFile *of;
	int size;
	char buffer[4096];
	VALUE ary, fname;

	size = sizeof(buffer);
	fname = rb_ivar_get(self, id_filename);
	if (!RTEST(fname))
		fname = lich_cache_setname(self);

	GetOpenFile(lich_cache_openfile(self), of);
	if (!of)
		return rb_ary_new();
	f = GetReadFile(of);
	rewind(f);

	ary = rb_ary_new();
	while (fgets(buffer, size, f))
		rb_ary_push(ary, rb_str_new2(buffer));

	return ary;
}


static VALUE
lich_cache_to_a(VALUE self)
{
	VALUE *aptr, ary = lich_cache_history(self);
	int i, len;
	
	len = RARRAY(self)->len;
	aptr = RARRAY(self)->ptr;

	for (i = 0; i < len; i++)
	{
		rb_ary_push(ary, aptr[i]);
	}
	
	return ary;
}


static VALUE
lich_cache_find(VALUE self)
{
	VALUE *aptr, bval, ary = lich_cache_to_a(self);
	int i, len;

	aptr = RARRAY(ary)->ptr;
	len = RARRAY(ary)->len;

	for (i = 0; i < len; i++)
	{
		bval = rb_yield(aptr[i]);
		if (RTEST(bval))
			return aptr[i];
	}
	return Qnil;
}


static VALUE
lich_cache_find_all(VALUE self)
{
	VALUE *aptr, bval, rary, ary = lich_cache_to_a(self);
	int i, len;

	rary = rb_ary_new();
	aptr = RARRAY(ary)->ptr;
	len = RARRAY(ary)->len;

	for (i = 0; i < len; i++)
	{
		bval = rb_yield(aptr[i]);
		if (RTEST(bval))
			rb_ary_push(rary, aptr[i]);
	}
	return rary;
}


static VALUE
lich_cache_collect(VALUE self)
{
	VALUE *aptr, bval, rary, ary = lich_cache_to_a(self);
	int i, len;

	rary = rb_ary_new();
	aptr = RARRAY(ary)->ptr;
	len = RARRAY(ary)->len;

	for (i = 0; i < len; i++)
	{
		bval = rb_yield(aptr[i]);
		rb_ary_push(rary, bval);
	}
	return rary;
}


static VALUE
lich_cache_f_get_max(VALUE klass)
{
	return INT2FIX(lich_cache_max_size);
}


static VALUE
lich_cache_f_set_max(VALUE klass, VALUE newsize)
{
	rb_secure(1);
	lich_cache_max_size = FIX2INT(newsize);
	return newsize;
}


static VALUE
lich_cache_s_m_missing(int argc, VALUE *argv, VALUE klass)
{
	return Qnil;
}


static VALUE
lich_cache_m_missing(int argc, VALUE *argv, VALUE self)
{
	int i;
	
	if ( !RTEST(rb_gv_get("$LICH_DEBUG")) )
		return Qnil;
	
	for (i = 0; i < argc; i++)
	{
		rb_warn("no method `%s' for class CachedArray.",
			rb_funcall(argv[i], rb_intern("to_s"), 0));
	}
	return Qnil;
}


/* Serves no purpose other than avoiding the hassle of sifting the older code line-by-line looking for references to the now-obsolete Buffer lib */
void
Init_buffer()
{
}


void
Init_cachedarray()
{
	rb_mObSpace = rb_eval_string("ObjectSpace");

	lich_cCachedAry = rb_define_class("CachedArray", rb_cArray);
	rb_define_global_const("Buffer", lich_cCachedAry);
	rb_cv_set(lich_cCachedAry, "@@dir", Qnil);
	lich_cache_max_size = LICH_CACHE_MAX_SIZE;

	id_filename = rb_intern("@filename");
	id_dir = rb_intern("@@dir");
	id_file = rb_intern("@file");
	id_define_finalizer = rb_intern("define_finalizer");

	rb_global_variable(&id_file);
	rb_global_variable(&id_filename);
	rb_global_variable(&id_dir);
	rb_global_variable(&id_define_finalizer);


	rb_define_singleton_method(lich_cCachedAry, "max_size", lich_cache_f_get_max, 0);
	rb_define_singleton_method(lich_cCachedAry, "max_size=", lich_cache_f_set_max, 1);
	rb_define_singleton_method(lich_cCachedAry, "dir", lich_cache_s_dir, 0);
/*	rb_define_singleton_method(lich_cCachedAry, "method_missing", lich_cache_s_m_missing, -1); */

	rb_define_method(lich_cCachedAry, "initialize", lich_cache_init, 0);
	rb_define_method(lich_cCachedAry, "push", lich_cache_size_check, -1);
	rb_define_method(lich_cCachedAry, "unshift", lich_cache_size_check, -1);
	rb_define_method(lich_cCachedAry, "dump", lich_cache_dump, 0);
	rb_define_method(lich_cCachedAry, "history", lich_cache_history, 0);
	rb_define_method(lich_cCachedAry, "purge", lich_cache_purge, 0);
	rb_define_method(lich_cCachedAry, "getfd", lich_cache_setname, 0);
	rb_define_method(lich_cCachedAry, "to_s", lich_cache_setname, 0);

/* FIXME: the following all seem to cause objects of differing classes (perhaps only String?) within a CachedArray structure to be assigned a filename as though they were CachedArray objects themselves; these empty files are not deleted when objects are GC'd
*/

	rb_define_method(lich_cCachedAry, "to_a", lich_cache_to_a, 0);
	rb_define_method(lich_cCachedAry, "find", lich_cache_find, 0);
	rb_define_method(lich_cCachedAry, "find_all", lich_cache_find_all, 0);
	rb_define_method(lich_cCachedAry, "collect", lich_cache_collect, 0);
	rb_define_method(lich_cCachedAry, "method_missing", lich_cache_m_missing, -1);

	rb_define_attr(lich_cCachedAry, "filename", 1, 0);

#ifdef __MINGW32__
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("cachedarray.dll"));
#else
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("cachedarray.so"));
#endif
}
