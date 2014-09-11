#ifndef HAVE_LICH_H
#define HAVE_LICH_H

#if !defined __MINGW32__ && defined _WIN32
#	define __MINGW32__
#endif

#ifdef __MINGW32__
#	include "/usr/src/winruby-1.8.4/ruby.h"
#else
#	include "ruby-1.8.6/ruby.h"
#endif
#include "rubyio.h"
#include "st.h"

#define BUF_MXARYSZ 64

#define LDEBUG(str) ALDEBUG(str, 0, 0, 0)
#define ALDEBUG(str,a,b,c) do {  \
   FILE *dbgfile = fopen("lich_debug.txt", "a");   \
   if (!dbgfile) \
      rb_raise(rb_eException, "cannot open debug file"); \
   fprintf(dbgfile,str,a,b,c); \
   fflush(dbgfile);  \
   fclose(dbgfile);  \
} while (0)

#ifndef GUARANTEED_SHORTEST_ALGORITHM
#	define GUARANTEED_SHORTEST_ALGORITHM
#endif

#ifndef GSL_HOOKS
#	define GSL_HOOKS
#endif


// buffer.c
VALUE buffer_new(VALUE self);
VALUE buffer_unshift(VALUE self, VALUE obj);
VALUE buffer_push(VALUE self, VALUE obj);
VALUE buffer_find(VALUE self);
VALUE buffer_dump(VALUE self);
VALUE buffer_getfd(VALUE self);
VALUE buffer_history(VALUE self);
VALUE buffer_purge(VALUE self);
VALUE buffer_setdir(VALUE self, VALUE dir);
VALUE buffer_nosetdir(VALUE self, VALUE dir);
VALUE buffer_getdir(VALUE self);
void buffer_cleancaches();

// lichscript.c
VALUE lich_namescript_incoming(VALUE self, VALUE string);
VALUE lich_statscript_incoming(VALUE self, VALUE string);
VALUE lich_uniqscript_incoming(VALUE self, VALUE string);
VALUE lich_upscript_incoming(VALUE self, VALUE string);
VALUE lich_script_self(VALUE self);
VALUE buffer_push(VALUE self, VALUE obj);
VALUE lich_script_wake_error(VALUE *err_ary[]);

// pathfind.c
VALUE pathfind(VALUE self, VALUE destination);
VALUE mark_field_position(VALUE self, VALUE x, VALUE y);
VALUE mark_adj(VALUE self, VALUE adj);
VALUE return_clist();


VALUE lich_cScript;
VALUE lich_cParser;
VALUE lich_cGift;
VALUE lich_cTrigger;

VALUE lich_mBuffer;
VALUE lich_mPathfind;


void Init_lich_frame();
void Init_lichscript();
void Init_lichparser();
void Init_buffer();
void Init_pathfind();


#if 0
enum thread_status {
	THREAD_TO_KILL,
	THREAD_RUNNABLE,
	THREAD_STOPPED,
	THREAD_KILLED,
};

struct thread {
    struct thread *next, *prev;
    rb_jmpbuf_t context;
#ifdef SAVE_WIN32_EXCEPTION_LIST
    DWORD win32_exception_list;
#endif

    VALUE result;

    long   stk_len;
    long   stk_max;
    VALUE *stk_ptr;
    VALUE *stk_pos;
#ifdef __ia64__
    VALUE *bstr_ptr;
    long   bstr_len;
#endif

    struct FRAME *frame;
    struct SCOPE *scope;
    struct RVarmap *dyna_vars;
    struct BLOCK *block;
    struct iter *iter;
    struct tag *tag;
    VALUE klass;
    VALUE wrapper;
    NODE *cref;

    int flags;          /* misc. states (vmode/rb_trap_immediate/raised) */

    NODE *node;

    int tracing;
    VALUE errinfo;
    VALUE last_status;
    VALUE last_line;
    VALUE last_match;

    int safe;

    enum thread_status status;
    int wait_for;
    int fd;
    fd_set readfds;
    fd_set writefds;
    fd_set exceptfds;
    int select_value;
    double delay;
    rb_thread_t join;

    int abort;
    int priority;
    VALUE thgroup;

    st_table *locals;

    VALUE thread;
};
#endif
extern VALUE ruby_top_self;

#endif
