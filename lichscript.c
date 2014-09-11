/*
 * Copyright (C) 2005-2006 Murray Miron.
 * ALL RIGHTS RESERVED.
 *
 * See included "License.txt" file for conditions of redistribution.
*/

#include "lich.h"

#ifndef BUF_MXARYSZ
# define BUF_MXARYSZ 64
#endif
#ifndef MAX_BUFFER_SIZE
#	define MAX_BUFFER_SIZE 1024
#endif

static void array_io_blocking_chk(VALUE self, VALUE array, VALUE wakelist);
static VALUE old_lich_script_self(VALUE);

static VALUE thread_hash;
static ID id_paused;
static ID id_sleeplist;
static ID id_uniques;
static ID id_wakeme_uniques;
static ID id_unique_io;
static ID id_upstream_index;
static ID id_wakeme_upstream;
static ID id_upstream_io;
static ID id_threads;
static ID id_index;
static ID id_push;
static ID id_list;
static ID id_raise;
static ID id_hash;
static ID id_key;
static ID id_paused;
static ID id_sleeplist;
static ID id_wakeme_status;
static ID id_thread;

static ID id_namescript_incoming_stable;
static ID id_status_scripts;

extern ID id_chomp;
extern ID id_wakeme;
extern ID id_names;
extern ID id_io;



/* FIXME: Alternate implementation of IO#popen() to fix a Windows deadlock issue */
#ifdef __MINGW32__
#include <sys/fcntl.h>

extern VALUE rb_cFile;
extern VALUE rb_cIO;
extern VALUE rb_cThread;
extern int ruby_safe_level;
VALUE lich_mPipe;
static void lich_pipe_finalize(OpenFile *, int);

static VALUE
lich_pipe_alloc(VALUE self)
{
	NEWOBJ(obj, struct RFile);
	OBJSETUP(obj, rb_cIO, T_FILE);
	return (VALUE)obj;
}

static VALUE
lich_io_s_popen(char *cmd)
{
	VALUE pipe;
	
	pipe = rb_funcall(rb_cIO, rb_intern("popen"), 2, rb_str_new2(cmd), rb_str_new2("rb+"));
	rb_extend_object(pipe, lich_mPipe);
	return pipe;

/* FIXME: the following code creates a named (maybe anonymous?), presumably asynchronous pipe with working read, broken write, and segfaults on close */
#if 0
	STARTUPINFO sti = { 0 };
	SECURITY_ATTRIBUTES sats = { 0 };
	PROCESS_INFORMATION pi = { 0 };
	HANDLE childin_r, childin_w, childout_r, childout_w;
	BYTE buffer[MAX_BUFFER_SIZE];
	DWORD writ, excode, read, available;
	OpenFile *fp;
	int pid;

	// Set security attributes
	sats.nLength = sizeof(sats);
	sats.bInheritHandle = 1;
	sats.lpSecurityDescriptor = NULL;

	// Create pipes
	childin_r = childin_w = childout_r = childout_w = NULL;
	if ( !CreatePipe(&childin_r, &childin_w, &sats, 0) ) return 0;
	if ( !CreatePipe(&childout_r, &childout_w, &sats, 0) ) return 0;
	CloseHandle(childin_w);
	CloseHandle(childout_r);

	// Set startup info
	sti.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
	sti.wShowWindow = SW_HIDE;
	sti.hStdInput = childin_r;
	sti.hStdOutput = childout_w;
	sti.hStdError = childout_w;

	// Create the process
	if ( !(pid = CreateProcess(NULL, cmd, NULL, NULL, 1, 0, NULL, NULL, &sti, &pi)) ) return 0;

	// Allocate and fill in Ruby object
	VALUE obj = lich_pipe_alloc(rb_cFile);
	MakeOpenFile(obj, fp);
	rb_extend_object(obj, lich_mPipe);

	fp->f = (FILE *)childin_r;//fdopen(childin_r, O_WRONLY);
	fp->f2 = (FILE *)childout_w;//fdopen(childout_w, O_RDONLY);
	fp->finalize = lich_pipe_finalize;
	if (!fp->f || !fp->f2) return 0;
	fp->pid = pid;//pi.hProcess;

	return (VALUE)obj;
#endif
}

static VALUE
lich_pipe_close(VALUE self)
{
	OpenFile *of;

	GetOpenFile(self, of);
	CloseHandle((HANDLE)of->f);
	CloseHandle((HANDLE)of->f2);
//	rb_io_close(self);
	of->f = of->f2 = NULL;
	return self;
}

static VALUE
lich_pipe_gets(VALUE self)
{
	OpenFile *fptr;
	char buffer[MAX_BUFFER_SIZE];
	DWORD read = 0, available = 0;
	HANDLE pipe;

	fptr = RFILE(self)->fptr;
	pipe = (HANDLE)fptr->f;

	retry:
	if ( !PeekNamedPipe(pipe, buffer, sizeof(buffer), &read, &available, NULL) )
		rb_thread_schedule();
	if (read) return rb_funcall(self, rb_intern("__gets__"), 0);
	rb_thread_schedule();
	goto retry;
}

static void
lich_pipe_finalize(OpenFile *fptr, int noraise)
{
	if (!fptr->f)
		return;
	CloseHandle(fptr->f);
	CloseHandle(fptr->f2);
	fptr->f = fptr->f2 = NULL;
	return;
}
#endif

static VALUE
lich_script_s_popen(VALUE self, VALUE cmd)
{
#ifdef __MINGW32__
	ruby_safe_level = 0;
	return lich_io_s_popen(RSTRING(cmd)->ptr);
#else
	char buffer[MAX_BUFFER_SIZE] = { 0 };
	snprintf(buffer, sizeof(buffer), "IO.popen('%s', 'r+')", RSTRING(cmd)->ptr);
	return rb_eval_string(buffer);
#endif
}

/* "Batch update functions" for handling blocking-socket-like behavior (i.e. the thread signaling that allows Lich to avoid polling) & keeping scripts informed during primary "user-client<->game-host" socket input/output */
static void lich_script_incoming(VALUE scriptlist, VALUE wakelist, VALUE io, VALUE string)
{
	int i;
	VALUE ary;

	for (i = 0; i < RARRAY(scriptlist)->len; i++)
	{
		rb_ary_push(rb_ivar_get(RARRAY(scriptlist)->ptr[i], io), string);
	}
	for (i = 0; i < RARRAY(wakelist)->len; i++)
	{
		rb_rescue(rb_thread_wakeup, RARRAY(wakelist)->ptr[i], 0, 0);
	}
}

VALUE lich_namescript_incoming_fast(VALUE self, VALUE string)
{
	VALUE stringchmp, scriptlist, io, wakelist;

	stringchmp = rb_funcall(string, id_chomp, 0);
	scriptlist = rb_cvar_get(lich_cScript, id_names);
	wakelist = rb_cvar_get(lich_cScript, id_wakeme);
	lich_script_incoming(scriptlist, wakelist, id_io, stringchmp);
	return Qnil;
}

VALUE lich_namescript_incoming_stable(VALUE self, VALUE string)
{
	VALUE stringchmp = rb_funcall(string, id_chomp, 0);

	return rb_funcall(lich_cScript, id_namescript_incoming_stable, 1, stringchmp);
}

VALUE lich_statscript_incoming(VALUE self, VALUE string)
{
	VALUE stringchmp, scriptlist, io, wakelist;

	stringchmp = rb_funcall(string, id_chomp, 0);
	scriptlist = rb_cvar_get(lich_cScript, id_status_scripts);
	wakelist = rb_cvar_get(lich_cScript, id_wakeme_status);
	lich_script_incoming(scriptlist, wakelist, id_io, stringchmp);
	return Qnil;
}

VALUE lich_uniqscript_incoming(VALUE self, VALUE string)
{
	VALUE stringchmp, scriptlist, io, wakelist;

	stringchmp = rb_funcall(string, id_chomp, 0);
	scriptlist = rb_cvar_get(lich_cScript, id_uniques);
	wakelist = rb_cvar_get(lich_cScript, id_wakeme_uniques);
	lich_script_incoming(scriptlist, wakelist, id_unique_io, stringchmp);
	return Qnil;
}

VALUE lich_upscript_incoming(VALUE self, VALUE string)
{
	VALUE stringchmp, scriptlist, io, wakelist;

	stringchmp = rb_funcall(string, id_chomp, 0);
	scriptlist = rb_cvar_get(lich_cScript, id_upstream_index);
	wakelist = rb_cvar_get(lich_cScript, id_wakeme_upstream);
	lich_script_incoming(scriptlist, wakelist, id_upstream_io, stringchmp);
	return Qnil;
}


/* `Script.self' method: returns the instance object of class Script associated with the current thread -- for recalling the using-script's object regardless of scope.  Called from the majority of script methods to identify the caller; also halts calling script if its `paused' flag is raised. */
VALUE
lich_script_self(VALUE self)
{
	VALUE entry, ary, thr, grp;

	thr = rb_thread_current();
	grp = rb_thread_group(thr);
	entry = rb_hash_aref(thread_hash, grp);

	if (RTEST(entry))
	{
		while ( RTEST(rb_ivar_get(entry, id_paused)) )
		{
			ary = rb_ivar_get(entry, id_sleeplist);
			rb_ary_push(ary, thr);
			rb_thread_stop();
			rb_ary_delete(ary, thr);
		}
		return entry;
	}
	return Qnil;
}


#if 0
static VALUE
old_lich_script_self(VALUE self)
{
	VALUE thr, thgrp, *aptr, buf;
	ID id_sleeplist, id_paused, id_threads,
			id_index;
	int i, len;

	id_threads = rb_intern("@threads");
	id_index = rb_intern("@@index");

	thr = rb_thread_current();
	thgrp = rb_thread_group(thr);
	
	buf = rb_cvar_get(lich_cScript, id_index);
	aptr = RARRAY(buf)->ptr;
	len = RARRAY(buf)->len;

	for (i = 0; i < len; i++)
	{
		buf = rb_ivar_get(aptr[i], id_threads);
		if (buf != thgrp)
			continue;
		while ( RTEST(rb_ivar_get(aptr[i], id_paused)) )
		{
			buf = rb_ivar_get(aptr[i], id_sleeplist);
			rb_ary_push(buf, thr);
			rb_thread_stop();
			rb_ary_delete(buf, thr);
		}
		return aptr[i];
	}
	return Qnil;
}


static VALUE old_lich_script_self(VALUE self)
{
	long i;
	VALUE list = rb_cv_get(lich_cScript, "@@index");
	VALUE me;
	ID paused = rb_intern("@paused");
	ID sleeplist = rb_intern("@sleeplist");
	ID threads = rb_intern("@threads");

	for (i = 0; i < RARRAY(list)->len; i++)
	{
		if (rb_ivar_get(RARRAY(list)->ptr[i], threads) == rb_thread_group(rb_thread_current())) {
			me = RARRAY(list)->ptr[i];
			while ( RTEST(rb_ivar_get(me, paused)) )
			{
				rb_ary_push(rb_ivar_get(me, sleeplist), rb_thread_current());
				rb_thread_stop();
				rb_ary_delete(rb_ivar_get(me, sleeplist), rb_thread_current());
			}
			return me;
		}
	}
	return Qnil;
}
#endif

/* `puts' methods for targeting a single script (I/O mimicking array: pushes a string onto the IO array of the script and signals any threads that are "blocked" while waiting for data that data is waiting to be consumed) */
VALUE lich_script_puts(VALUE self, VALUE string)
{
	VALUE array, wakelist;
	register int i;

	rb_funcall(rb_iv_get(self, "@io"), id_push, 1, rb_funcall(string, id_chomp, 0));
	array = rb_funcall(rb_ivar_get(self, id_threads), id_list, 0);
	wakelist = rb_cvar_get(lich_cScript, id_wakeme);
	for (i = 0; i < RARRAY(array)->len; i++)
	{
		if (rb_ary_includes(wakelist, RARRAY(array)->ptr[i]) == Qtrue) {
			rb_rescue(rb_thread_wakeup, RARRAY(array)->ptr[i], 0, 0);
		}
	}
	return Qtrue;
}

VALUE lich_script_upstream_puts(VALUE self, VALUE string)
{
	VALUE array;
	int i;

	rb_funcall(rb_ivar_get(self, id_upstream_io), id_push, 1, rb_funcall(string, id_chomp, 0));
	array = rb_funcall(rb_ivar_get(self, id_threads), id_list, 0);
	for (i = 0; i < RARRAY(array)->len; i++)
	{
		if (rb_ary_includes(rb_cv_get(lich_cScript, "@@wakeme_upstream"), RARRAY(array)->ptr[i]) == Qtrue) {
			rb_rescue(rb_thread_wakeup, RARRAY(array)->ptr[i], 0, 0);
		}
	}
	return Qtrue;
}

VALUE lich_script_unique_puts(VALUE self, VALUE string)
{
	VALUE array;
	int i;

	rb_funcall(rb_ivar_get(self, id_unique_io), id_push, 1, rb_funcall(string, id_chomp, 0));
	array = rb_funcall(rb_ivar_get(self, id_threads), id_list, 0);
	for (i = 0; i < RARRAY(array)->len; i++)
	{
		if (rb_ary_includes(rb_cvar_get(lich_cScript, id_wakeme_uniques), RARRAY(array)->ptr[i]) == Qtrue) {
			rb_rescue(rb_thread_wakeup, RARRAY(array)->ptr[i], 0, 0);
		}
	}
	return Qtrue;
}


/* `gets' methods for targeting a single script (shifts the socket-mimicking I/O array & returns a line the same way a 'gets' function on a socket would) */
VALUE lich_script_gets(VALUE self)
{
	VALUE array = rb_iv_get(self, "@io");

	array_io_blocking_chk(self, array, rb_cvar_get(lich_cScript, id_wakeme));
	return rb_ary_shift(array);
}

VALUE lich_script_upstream_gets(VALUE self)
{
	VALUE array = rb_iv_get(self, "@upstream_io");

	array_io_blocking_chk(self, array, rb_cvar_get(lich_cScript, id_wakeme_upstream));
	return rb_ary_shift(array);
}

VALUE lich_script_unique_gets(VALUE self)
{
	VALUE array = rb_iv_get(self, "@unique_io");

	array_io_blocking_chk(self, array, rb_cvar_get(lich_cScript, id_wakeme_uniques));
	return rb_ary_shift(array);
}


/* `I/O' mimicking array: simulates blocking-socket operations; if array is empty at time of call, pushes current thread onto the "waiting for I/O available signal" list (a `Script' class variable) and sleeps infinitely (i.e. until it's woken by the fake "I/O available" signal) */
static void array_io_blocking_chk(VALUE self, VALUE array, VALUE wakelist)
{
	while (RARRAY(array)->len < 1)
	{
		rb_thread_critical_set(self, Qtrue);
		rb_ary_push(wakelist, rb_thread_current());
		rb_thread_stop();
		rb_thread_critical_set(self, Qtrue);
		rb_ary_delete(wakelist, rb_thread_current());
		rb_thread_critical_set(self, Qfalse);
	}
	return;
}


/* Singleton methods for accessing `Script' class variables outside of the scope of the class */
VALUE lich_script_index(VALUE self) { return rb_cvar_get(lich_cScript, id_index); }
VALUE lich_script_names(VALUE self) { return rb_cvar_get(lich_cScript, id_names); }
VALUE lich_script_wakeme(VALUE self) { return rb_cvar_get(lich_cScript, id_wakeme); }
VALUE lich_script_upstream_index(VALUE self) { return rb_cvar_get(lich_cScript, id_upstream_index); }
VALUE lich_script_wakeme_upstream(VALUE self) { return rb_cvar_get(lich_cScript, id_wakeme_upstream); }
VALUE lich_script_status_scripts(VALUE self) { return rb_cvar_get(lich_cScript, id_status_scripts); }
VALUE lich_script_wakeme_status(VALUE self) { return rb_cvar_get(lich_cScript, id_wakeme_status); }
VALUE lich_script_uniques(VALUE self) { return rb_cvar_get(lich_cScript, id_uniques); }
VALUE lich_script_wakeme_uniques(VALUE self) { return rb_cvar_get(lich_cScript, id_wakeme_uniques); }


/* Miscellaneous instance methods */
VALUE lich_script_safe_p(VALUE self)
{
	return rb_iv_get(self, "@safe") == Qtrue ? Qtrue : Qfalse;
}

VALUE lich_script_set_safe(VALUE self)
{
	rb_iv_set(self, "@safe", Qtrue);
	return Qtrue;
}

VALUE lich_script_clear(VALUE self)
{
	rb_ary_clear(rb_ivar_get(self, id_io));
	rb_ary_clear(rb_ivar_get(self, id_unique_io));
	rb_ary_clear(rb_ivar_get(self, id_upstream_io));
	return Qnil;
}

/* Prevent `exit' method from exiting the program if used in a script's subthread. */
VALUE lich_script_exit(int argc, VALUE *argv)
{
	VALUE volatile script = lich_script_self(lich_cScript);

	if (script == Qnil) {
		rb_f_exit(argc, argv);
	}
	else {
		rb_funcall(rb_ivar_get(script, id_thread), id_raise, 1, rb_eSystemExit);
	}
	return Qnil;
}

VALUE lich_script_max_efficiency(VALUE self)
{
	rb_define_singleton_method(lich_cScript, "namescript_incoming", lich_namescript_incoming_fast, 1);
	return Qtrue;
}

VALUE lich_script_max_stability(VALUE self)
{
	rb_define_singleton_method(lich_cScript, "namescript_incoming", lich_namescript_incoming_stable, 1);
	return Qtrue;
}

VALUE lich_trigger_delete(VALUE self)
{
	VALUE hash = rb_cv_get(lich_cTrigger, "@@hash");

	return rb_hash_delete(hash, rb_iv_get(self, "@key"));
}

VALUE lich_trigger_aref(VALUE self, VALUE key)
{
	return rb_hash_aref(rb_cv_get(lich_cTrigger, "@@hash"), key);
}


VALUE
lich_script_s_thread_hash(VALUE self)
{
	return thread_hash;
}


/* Initialize the Ruby bindings, etc. */
void Init_lichscript()
{
	int i;
	VALUE arr, lich_cThread;

	lich_cScript = rb_define_class("Script", rb_cObject);
	lich_cGift = rb_define_class("Gift", rb_cObject);
	lich_cTrigger = rb_define_class("Trigger", rb_cProc);
	lich_cThread = rb_eval_string("Thread");

	thread_hash = rb_hash_new();
	id_paused = rb_intern("@paused");
	id_sleeplist = rb_intern("@sleeplist");
	id_uniques = rb_intern("@@uniques");
	id_wakeme_uniques = rb_intern("@@wakeme_uniques");
	id_unique_io = rb_intern("@unique_io");
	id_upstream_index = rb_intern("@@upstream_index");
	id_wakeme_upstream = rb_intern("@@wakeme_upstream");
	id_upstream_io = rb_intern("@upstream_io");
	id_threads = rb_intern("@threads");
	id_index = rb_intern("@@index");
	id_push = rb_intern("push");
	id_list = rb_intern("list");
	id_raise = rb_intern("raise");
	id_namescript_incoming_stable = rb_intern("namescript_incoming_stable");
	id_status_scripts = rb_intern("@@status_scripts");
	id_wakeme_status = rb_intern("@@wakeme_status");
	id_threads = rb_intern("@threads");
	
	id_hash = rb_intern("@@hash");
	id_key = rb_intern("@key");
	rb_global_variable(&id_uniques);
	rb_global_variable(&id_wakeme_uniques);
	rb_global_variable(&id_unique_io);
	rb_global_variable(&id_upstream_index);
	rb_global_variable(&id_wakeme_upstream);
	rb_global_variable(&id_upstream_io);
	rb_global_variable(&id_threads);
	rb_global_variable(&id_index);
	rb_global_variable(&id_push);
	rb_global_variable(&id_list);
	rb_global_variable(&id_raise);
	rb_global_variable(&id_hash);
	rb_global_variable(&id_key);
	rb_global_variable(&id_namescript_incoming_stable);
	rb_global_variable(&id_threads);
	rb_global_variable(&id_wakeme_status);
	rb_global_variable(&id_status_scripts);
	rb_global_variable(&id_raise);

	rb_global_variable(&thread_hash);
	rb_global_variable(&id_paused);
	rb_global_variable(&id_sleeplist);

	rb_define_global_function("exit", lich_script_exit, -1);
	rb_cv_set(lich_cScript, "@@thread_hash", thread_hash);
	rb_cv_set(lich_cScript, "@@exec_id", rb_ary_new2(256));
	rb_cv_set(lich_cScript, "@@index", rb_ary_new());
	rb_cv_set(lich_cScript, "@@names", rb_ary_new());
	rb_cv_set(lich_cScript, "@@wakeme", rb_ary_new());
	rb_cv_set(lich_cScript, "@@upstream_index", rb_ary_new());
	rb_cv_set(lich_cScript, "@@wakeme_upstream", rb_ary_new());
	rb_cv_set(lich_cScript, "@@status_scripts", rb_ary_new());
	rb_cv_set(lich_cScript, "@@wakeme_status", rb_ary_new());
	rb_cv_set(lich_cScript, "@@uniques", rb_ary_new());
	rb_cv_set(lich_cScript, "@@wakeme_uniques", rb_ary_new());

	rb_define_singleton_method(lich_cScript, "thread_hash", lich_script_s_thread_hash, 0);
	rb_define_singleton_method(lich_cScript, "index", lich_script_index, 0);
	rb_define_singleton_method(lich_cScript, "names", lich_script_names, 0);
	rb_define_singleton_method(lich_cScript, "wakeme", lich_script_wakeme, 0);
	rb_define_singleton_method(lich_cScript, "upstream_index", lich_script_upstream_index, 0);
	rb_define_singleton_method(lich_cScript, "wakeme_upstream", lich_script_wakeme_upstream, 0);
	rb_define_singleton_method(lich_cScript, "status_scripts", lich_script_status_scripts, 0);
	rb_define_singleton_method(lich_cScript, "wakeme_status", lich_script_wakeme_status, 0);
	rb_define_singleton_method(lich_cScript, "uniques", lich_script_uniques, 0);
	rb_define_singleton_method(lich_cScript, "wakeme_uniques", lich_script_wakeme_uniques, 0);
	rb_define_singleton_method(lich_cScript, "max_efficiency", lich_script_max_efficiency, 0);
	rb_define_singleton_method(lich_cScript, "max_stability", lich_script_max_stability, 0);
	rb_define_singleton_method(lich_cScript, "popen", lich_script_s_popen, 1);
#ifdef __MINGW32__
	rb_define_singleton_method(lich_cScript, "namescript_incoming", lich_namescript_incoming_stable, 1);
#else
	rb_define_singleton_method(lich_cScript, "namescript_incoming", lich_namescript_incoming_fast, 1);
#endif
	rb_define_singleton_method(lich_cScript, "upscript_incoming", lich_upscript_incoming, 1);
	rb_define_singleton_method(lich_cScript, "uniqscript_incoming", lich_uniqscript_incoming, 1);
	rb_define_singleton_method(lich_cScript, "statscript_incoming", lich_statscript_incoming, 1);
	rb_define_singleton_method(lich_cScript, "self", lich_script_self, 0);
/*	rb_define_singleton_method(lich_cScript, "old_self", old_lich_script_self, 0); */
#ifdef REQUIRE_FORK_SCRIPT
	rb_define_singleton_method(lich_cScript, "fork_script", lich_script_fork_script, 2);
#endif
#ifdef __MINGW32__
	lich_mPipe = rb_define_module_under(lich_cScript, "Pipe");
	rb_define_alias(lich_mPipe, "__gets__", "gets");
	rb_define_method(lich_mPipe, "gets", lich_pipe_gets, 0);
//	rb_define_method(lich_mPipe, "close", lich_pipe_close, 0);
#endif
	rb_define_method(lich_cScript, "safe?", lich_script_safe_p, 0);
	rb_define_method(lich_cScript, "set_safe", lich_script_set_safe, 0);
	rb_define_method(lich_cScript, "clear", lich_script_clear, 0);

	rb_define_method(lich_cScript, "puts", lich_script_puts, 1);
	rb_define_method(lich_cScript, "gets", lich_script_gets, 0);
	rb_define_method(lich_cScript, "unique_puts", lich_script_unique_puts, 1);
	rb_define_method(lich_cScript, "unique_gets", lich_script_unique_gets, 0);
	rb_define_method(lich_cScript, "upstream_puts", lich_script_upstream_puts, 1);
	rb_define_method(lich_cScript, "upstream_gets", lich_script_upstream_gets, 0);

	rb_define_attr(lich_cScript, "io", 1, 0);
	rb_define_attr(lich_cScript, "upstream_io", 1, 0);
	rb_define_attr(lich_cScript, "unique_io", 1, 0);
	rb_define_attr(lich_cScript, "blocked_on_io", 1, 1);
	rb_define_attr(lich_cScript, "name", 1, 0);
	rb_define_attr(lich_cScript, "keysig", 1, 0);

	rb_define_attr(lich_cScript, "vars", 1, 0);
	rb_define_attr(lich_cScript, "dying_procs", 1, 0);
	rb_define_attr(lich_cScript, "threads", 1, 0);
	rb_define_attr(lich_cScript, "thread", 1, 0);
	rb_define_attr(lich_cScript, "sleeplist", 1, 0);

	rb_define_attr(lich_cScript, "data", 1, 0);
	rb_define_attr(lich_cScript, "lines", 1, 0);
	rb_define_attr(lich_cScript, "line_no", 1, 0);
	rb_define_attr(lich_cScript, "stackptr", 1, 0);
	rb_define_attr(lich_cScript, "current_label", 1, 0);
	rb_define_attr(lich_cScript, "jump_label", 1, 1);
	rb_define_attr(lich_cScript, "match_stack_labels", 1, 0);
	rb_define_attr(lich_cScript, "match_stack_strings", 1, 0);
	rb_define_attr(lich_cScript, "match_table_labels", 1, 0);
	rb_define_attr(lich_cScript, "match_table_strings", 1, 0);
	rb_define_attr(lich_cScript, "num", 1, 0);

	rb_define_attr(lich_cScript, "wizard_save", 1, 0);
	rb_define_attr(lich_cScript, "wizard_counter", 1, 0);

	rb_define_attr(lich_cScript, "paused", 1, 1);
	rb_define_attr(lich_cScript, "upstream", 1, 1);
	rb_define_attr(lich_cScript, "quiet", 1, 1);
	rb_define_attr(lich_cScript, "silent", 1, 1);
	rb_define_attr(lich_cScript, "quiet_exit", 1, 1);
	rb_define_attr(lich_cScript, "wizard", 1, 0);
	rb_define_attr(lich_cScript, "unique", 1, 1);
	rb_define_attr(lich_cScript, "stand_alone", 1, 0);
	rb_define_attr(lich_cScript, "die_with", 1, 1);
	rb_define_attr(lich_cScript, "no_echo", 1, 1);
	rb_define_attr(lich_cScript, "no_pause", 1, 1);
	rb_define_attr(lich_cScript, "no_ka", 1, 1);

#ifdef LICHTRIGGER
	rb_define_singleton_method(lich_cTrigger, "[]=", lich_trigger_aset, 2);
	rb_define_singleton_method(lich_cTrigger, "[]", lich_trigger_aref, 1);
	rb_define_method(lich_cTrigger, "delete", lich_trigger_delete, 0);
#endif

	rb_cv_set(lich_cTrigger, "@@hash", rb_hash_new());
	rb_cv_set(lich_cTrigger, "@@ary", rb_ary_new());
	rb_define_attr(lich_cTrigger, "proc", 1, 1);
	rb_define_attr(lich_cTrigger, "key", 1, 1);

#ifdef __MINGW32__
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("lichscript.dll"));
#else	
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("lichscript.so"));
#endif
}


void Init_lich_libscript()
{
	Init_lichscript();
}
