#include "lich.h"


#define DISCONNECT do\
{\
	if (!RTEST(rb_funcall(rb_gv_get("$_CLIENT_"), rb_intern("closed?"), 0))) {\
		rb_funcall(rb_gv_get("$_CLIENT_"), rb_intern("puts"), 1, rb_str_new2("--- Lich's connection to the game has been closed."));\
		rb_funcall(rb_gv_get("$_CLIENT_"), rb_intern("close"), 0);\
	}\
	if (!RTEST(rb_funcall(rb_gv_get("$_SERVER_"), rb_intern("closed?"), 0))) {\
		rb_funcall(rb_gv_get("$_SERVER_"), rb_intern("close"), 0);\
	}\
} while (0)

#define rb_reg_regcomp(str) rb_reg_regcomp(rb_str_new2(str))

#ifdef GSL_HOOKS
#  define ZEROHOOKS do {\
	for (i = 0; i < L_STAT_SZ; i++)\
	{\
		stat_ary[i].hook = 0;\
	}\
	for (i = 0; i < L_MISC_SZ; i++)\
	{\
		misc_ary[i].hook = 0;\
	}\
  } while (0)
#else
#  define ZEROHOOKS
#endif

#ifdef TIMETEST
#  define TIMESAVE rb_gv_set("$LINE_RECV", rb_funcall(rb_cTime, rb_intern("now"), 0))
#  define TIMEECHO rb_funcall(rb_gv_get("$_CLIENT_"), rb_intern("puts"), 1, rb_funcall(rb_funcall(rb_cTime, rb_intern("now"), 0), rb_intern("-"), 1, rb_gv_get("$LINE_RECV")))
#else
#  define TIMESAVE
#  define TIMEECHO
#endif

#ifdef LICHDEBUG
#  define DEBUG(ptr) printf("%s", ptr)
#else
#  define DEBUG(ptr)
#endif

struct tag_chk {
	void (*func)();
#ifdef GSL_HOOKS
	void (*hook)();
#endif
	VALUE re;
};

struct hook {
	union {
		void (*func)();
		VALUE proc;
	} u;
	char tag[3];
	unsigned char proc_p;
};


static VALUE taghash;
static struct hook *hooks;
static int nhooks;


static VALUE re_obj_gslgsm, rel, rem;
static VALUE roomre, alsore;
static VALUE npcre, stripre;
static VALUE re_obj_dig;
static VALUE re, re2, re3, re4, re5;
static VALUE downstream_hooks;

static ID id_gets;
static ID id_write;
static ID id_push;
static ID id_statscript_incoming;
static ID id_namescript_incoming;
static ID id_gsub;
static ID id_match;
static ID id_first;
static ID id_clear;
static ID id_post_match;
static ID id_pre_match;
static ID id_gsl_stopwatch;
static ID id_now;
static ID id_to_i;
static ID id_slice;
static ID id_hyphen;
static ID id_empty_p;
static ID id_shift;
static ID id_puts;
static ID id_plus;
static ID id_call;
static ID id_sub_bang;
static ID id_chomp_bang;
static ID id_sub;
static ID id_last;
static ID id_first;
ID id_strip;
ID id_split;
ID id_chop;
ID id_chomp;
ID id_io;
ID id_wakeme;
ID id_names;
ID id_thread;


/* For dynamically hooking specific tags during runtime */
#ifdef GSL_HOOKS
static void hook_assoc_func(void (*func)(), char tag[])
{
	hooks = realloc(hooks, sizeof(struct hook) * (nhooks + 1));
	if (!hooks) rb_raise(rb_eNoMemError, "out of memory");
	hooks[nhooks].proc_p = 0;
	hooks[nhooks].u.func = func;
	strncpy(hooks[nhooks++].tag, tag, 3);
}

static VALUE hook_assoc_proc(VALUE self, VALUE str, VALUE proc)
{
	int i;

	if NIL_P(proc) {
		for (i = 0; i < nhooks; i++)
		{
			if (!strcoll(hooks[i].tag, RSTRING(str)->ptr)) {
				rb_gc_force_recycle(hooks[i].u.proc);
				hooks[i].tag[0] = '\0';
				hooks[i].u.proc = Qnil;
			}
		}
		return Qnil;
	}
	hooks = realloc(hooks, sizeof(struct hook) * (nhooks + 1));
	if (!hooks) rb_raise(rb_eNoMemError, "out of memory");
	if (!rb_respond_to(proc, id_call)) rb_raise(rb_eTypeError, "object must be a proc or respond to :call in the same way");
	hooks[nhooks].proc_p = 1;
	hooks[nhooks].u.proc = proc;
	rb_global_variable(&proc);
	strncpy(hooks[nhooks++].tag, RSTRING(str)->ptr, 3);
	return Qtrue;
}
#endif


/* Environment update functions for GSL (Wizard front-end) encoded character info */
static void gsl_famvision_start(VALUE string)
{
	VALUE hostsock = rb_gv_get("$_SERVER_"), clisock = rb_gv_get("$_CLIENT_"), hostbuffer = rb_gv_get("$_SERVERBUFFER_");
	VALUE line, reobj;

	while (RTEST(line = rb_funcall(hostsock, id_gets, 0)))
	{
		rb_funcall(clisock, id_write, 1, line);
		rb_funcall(hostbuffer, id_push, 1, line);

		if (RSTRING(line)->ptr[0] == '\034') {
			if (RSTRING(line)->len < 4) {
				continue;
			}
			rb_funcall(lich_cScript, id_statscript_incoming, 1, line);
			if (RSTRING(line)->ptr[3] == 'f') {
				break;
			}
			else if (RSTRING(line)->ptr[3] == 'j') {
				rb_gv_set("$familiar_paths", rb_str_new2(&RSTRING(line)->ptr[5]));
			}
		}
		else {
			rb_funcall(lich_cScript, id_namescript_incoming, 1, rb_funcall(line, id_gsub, 2, stripre, rb_str_new("", 0)));
			if (RTEST(reobj = rb_funcall(roomre, id_match, 1, line))) {
				rb_gv_set("$familiar_room", line);
				if (strchr(RSTRING(line)->ptr, ',')) {
					rb_gv_set("$familiar_area", rb_funcall(rb_funcall(line, id_split, 1, rb_str_new(",", 1)), id_first, 0));
				}
				rb_funcall(rb_gv_get("$familiar_npcs"), id_clear, 0);
				rb_gv_set("$familiar_pcs", rb_str_new("", 0));
			}
			else if (RTEST(reobj = rb_funcall(alsore, id_match, 1, line))) {
				rb_gv_set("$familiar_pcs", rb_funcall(reobj, id_post_match, 0));
			}
			else if (RTEST(reobj = rb_funcall(npcre, id_match, 1, line))) {
				rb_funcall(rb_gv_get("$familiar_npcs"), id_push, 1, rb_funcall(reobj, id_pre_match, 0));
			}
		}
	}
}

static void gsl_gift_stopwatch(VALUE string)
{
	rb_funcall(lich_cGift, id_gsl_stopwatch, 0);
}

static void gsl_clock_tick(VALUE string)
{
	static VALUE zero = INT2FIX(0);
	VALUE volatile tacmd;
	VALUE timebuf, timenow;

	timenow = rb_funcall(rb_cTime, id_now, 0);
	timenow = rb_funcall(timenow, id_to_i, 0);
	timebuf = rb_funcall(string, id_slice, 1, re_obj_dig);
	timebuf = rb_funcall(timebuf, id_to_i, 0);
	rb_gv_set("$_TIMEOFFSET_", rb_funcall(timenow, id_hyphen, 1, timebuf));

	if (rb_gv_get("$TALIMIT") == zero) {
		rb_gv_set("$TA_waiting_on_resp", zero);
	}
	else if (rb_gv_get("$TA_waiting_on_resp") == zero) /* nil */;
	else if (rb_gv_get("$TA_waiting_on_resp") >= rb_gv_get("$TALIMIT")) {
		if (RTEST(rb_funcall(rb_gv_get("$_TA_BUFFER_"), id_empty_p, 0))) {
			rb_gv_set("$TA_waiting_on_resp", INT2FIX(FIX2INT(rb_gv_get("$TALIMIT")) - 1));
		}
		else if (RTEST(tacmd = rb_funcall(rb_gv_get("$_TA_BUFFER_"), id_shift, 0))) {
				rb_funcall(rb_gv_get("$_SERVER_"), id_puts, 1, tacmd);
				rb_funcall(rb_gv_get("$_CLIENT_"), id_puts, 1, rb_funcall(rb_str_new2("(sent: "), id_plus, 1,
					rb_funcall(rb_funcall(tacmd, id_chomp, 0), id_plus, 1, rb_str_new2(")"))));
				if (RTEST(rb_funcall(rb_gv_get("$_TA_BUFFER_"), id_empty_p, 0))) {
					rb_gv_set("$TA_waiting_on_resp", INT2FIX(FIX2INT(rb_gv_get("$TALIMIT")) - 1));
				}
			}
	}
	else {
		rb_gv_set("$TA_waiting_on_resp", INT2FIX(FIX2INT(rb_gv_get("$TA_waiting_on_resp")) - 1));
	}
}

static void gsl_gsv_update(VALUE string)
{
	rb_hash_aset(taghash, rb_str_new2("GSb"), rb_str_substr(string, -11, 9));
	rb_hash_aset(taghash, rb_str_new2("GSa"), rb_str_substr(string, -21, 9));
	rb_hash_aset(taghash, rb_str_new2("GSZ"), rb_str_substr(string, -31, 9));
	rb_hash_aset(taghash, rb_str_new2("MGSZ"), rb_str_substr(string, -41, 9));
	rb_hash_aset(taghash, rb_str_new2("GSY"), rb_str_substr(string, -51, 9));
	rb_hash_aset(taghash, rb_str_new2("MGSY"), rb_str_substr(string, -61, 9));
	rb_hash_aset(taghash, rb_str_new2("GSX"), rb_str_substr(string, -71, 9));
	rb_hash_aset(taghash, rb_str_new2("MGSX"), rb_str_substr(string, -81, 9));
}

static void gsl_generic_update(VALUE string)
{
	VALUE substr = rb_str_substr(string, 1, 3);

	rb_hash_aset(taghash, substr, rb_str_substr(string, 4, RSTRING(string)->len - 4));
#ifdef GSL_HOOKS
	register int i;
	for (i = 0; i < nhooks; i++)
	{
		if (!strcoll(hooks[i].tag, RSTRING(string)->ptr)) {
			if (hooks[i].proc_p) rb_funcall(hooks[i].u.proc, id_call, 0);
			else hooks[i].u.func();
		}
	}
#endif
}

static void gsl_npc_push(VALUE string)
{
	VALUE istr = string, reobj, sav = rb_str_new("", 0);

	while (RTEST(reobj = rb_funcall(re_obj_gslgsm, id_match, 1, istr)))
	{
		if (RTEST(rb_funcall(istr, id_sub_bang, 2, rem, rb_str_new("", 0)))) {
			rb_funcall(istr, id_chomp_bang, 0);
			rb_funcall(rb_gv_get("$npcs"), id_push, 1, istr);
		}
		else {
			rb_funcall(istr, id_chomp_bang, 0);
			rb_funcall(istr, id_sub_bang, 2, rel, rb_str_new("", 0));
		}
		rb_str_cat2(sav, RSTRING(istr)->ptr);
		istr = rb_funcall(rb_gv_get("$_SERVER_"), id_gets, 0);
		rb_funcall(rb_gv_get("$_CLIENT_"), id_write, 1, istr);
	}
	rb_funcall(sav, id_chomp_bang, 0);
	rb_funcall(lich_cScript, id_namescript_incoming, 1, sav);
}

static void gsl_obvious_exits(VALUE string)
{
	rb_gv_set("$_PATHSLINE_", string);
	rb_funcall(lich_cScript, id_namescript_incoming, 1, string);
}

static void gsl_room_pc_list(VALUE string)
{
	rb_gv_set("$pcs", rb_funcall(string, id_sub, 2, rb_str_new2("Also here: "), rb_str_new("", 0)));
	rb_funcall(lich_cScript, id_namescript_incoming, 1, string);
}

static void gsl_empty_str_or_flag(VALUE string)
{
	rb_funcall(lich_cScript, id_statscript_incoming, 1, string);
}

static void gsl_moved_room(VALUE string)
{
	rb_gv_set("$room_count", rb_funcall(rb_gv_get("$room_count"), id_plus, 1, INT2FIX(1)));
}

static void gsl_skip_death(VALUE string)
{
	VALUE tmp;

	rb_gv_set("$_SERVERSTRING_", (tmp = rb_funcall(rb_gv_get("$_SERVER_"), id_gets, 0)));
	rb_funcall(rb_gv_get("$_CLIENT_"), id_write, 1, tmp);
	rb_funcall(rb_gv_get("$_SERVERBUFFER_"), id_push, 1, tmp);
	rb_funcall(lich_cScript, id_statscript_incoming, 1, tmp);
}

static void gsl_roomtitle_update(VALUE string)
{
	char *end, strbuf[256];
	VALUE tmp;

	strbuf[255] = '\0';
	tmp = rb_gv_set("$_SERVERSTRING_", rb_funcall(rb_gv_get("$_SERVER_"), id_gets, 0));
	strncpy(strbuf, RSTRING(tmp)->ptr, 256);
	rb_funcall(rb_gv_get("$_CLIENT_"), id_write, 1, tmp);
	rb_funcall(rb_gv_get("$_SERVERBUFFER_"), id_push, 1, tmp);
	rb_gv_set("$roomtitle", tmp);
	if (end = strchr(strbuf, ',')) {
		*end = '\0';
		rb_gv_set("$roomarea", rb_str_new(strbuf, strlen(strbuf)));
	}
	rb_funcall(rb_gv_get("$npcs"), id_clear, 0);
	rb_gv_set("$pcs", rb_str_new("", 0));
	rb_funcall(lich_cScript, id_namescript_incoming, 1, tmp);
}

static void gsl_roomdesc_update(VALUE string)
{
	VALUE tmp, sav, strbuf, reobj;
	VALUE hostsock = rb_gv_get("$_SERVER_");
	VALUE clisock = rb_gv_get("$_CLIENT_");
	VALUE hostbuffer = rb_gv_get("$_SERVERBUFFER_");

	tmp = rb_funcall(hostsock, id_gets, 0);
	rb_funcall(clisock, id_write, 1, tmp);
	rb_funcall(hostbuffer, id_push, 1, tmp);
	sav = rb_funcall(tmp, id_gsub, 2, re2, rb_str_new("", 0));
	rb_gv_set("$roomdescription", sav);
	rb_funcall(sav, id_chomp_bang, 0);
	tmp = rb_funcall(hostsock, id_gets, 0);
	if (RTEST(rb_funcall(re5, id_match, 1, tmp))) {
		rb_funcall(clisock, id_write, 1, tmp);
		rb_funcall(hostbuffer, id_push, 1, tmp);
		sav = rb_funcall(sav, id_plus, 1, rb_funcall(tmp, id_gsub, 2, re, rb_str_new("", 0)));
		sav = rb_funcall(sav, id_chomp, 0);
		while (!RTEST(rb_funcall(re3, id_match, 1, tmp))) {
			tmp = rb_funcall(hostsock, id_gets, 0);
			rb_funcall(clisock, id_write, 1, tmp);
			rb_funcall(hostbuffer, id_push, 1, tmp);
			strbuf = rb_funcall(rb_funcall(tmp, id_gsub, 2, re2, rb_str_new("", 0)), id_chomp, 0);
			rb_str_cat2(sav, RSTRING(strbuf)->ptr);
			if (RTEST(reobj = rb_funcall(re4, id_match, 1, tmp))) {
				rb_funcall(rb_gv_get("$npcs"), id_push, 1, rb_funcall(reobj, id_pre_match, 0));
			}
		}
		rb_funcall(lich_cScript, id_namescript_incoming, 1, sav);
	}
	else {
		rb_funcall(lich_cScript, id_namescript_incoming, 1, sav);
		rb_gv_set("$_SERVERSTRING_", tmp);
		rb_funcall(clisock, id_write, 1, tmp);
		rb_funcall(hostbuffer, id_push, 1, tmp);
	}
}


/* Primary I/O recv/send/scan loop for GSL encoded streams */
VALUE lich_parserloop_gsl(VALUE self)
{
#define L_STAT_SZ 2
#define L_MISC_SZ 4
	struct tag_chk stat_ary[L_STAT_SZ];
	struct tag_chk misc_ary[L_MISC_SZ];
	int i;
	ID match = id_match;
	ID id_write = id_puts;
	VALUE tmp, strip_re = rb_reg_regcomp("\\034[^\\r\\n]+(?:[\\r\\n]+)?");
	ZEROHOOKS;

	stat_ary[0].re = rb_reg_regcomp("^\\034GSFB\\d+\\034GSFM\\d+\\034GSFP\\d+");
	stat_ary[0].func = gsl_moved_room;
	stat_ary[1].re = rb_reg_regcomp("^\\034GSw0+3");
	stat_ary[1].func = gsl_skip_death;

	misc_ary[0].re = rb_reg_regcomp("^Also here: ");
	misc_ary[0].func = gsl_room_pc_list;
	misc_ary[1].re = rb_reg_regcomp("^\\r\\n$|^\\s\\*\\s");
	misc_ary[1].func = gsl_empty_str_or_flag;
	misc_ary[2].re = rb_reg_regcomp("^Obvious (?:paths|exits): ");
	misc_ary[2].func = gsl_obvious_exits;
	misc_ary[3].re = rb_reg_regcomp("\\034GSL\\r\\n$");
	misc_ary[3].func = gsl_npc_push;

	while (RTEST(tmp = rb_gv_set("$_SERVERSTRING_", rb_funcall(rb_gv_get("$_SERVER_"), id_gets, 0))))
	{
		TIMESAVE;
		rb_funcall(rb_gv_get("$_CLIENT_"), id_write, 1, tmp);
		rb_funcall(rb_gv_get("$_SERVERBUFFER_"), id_push, 1, tmp);
		if (RSTRING(tmp)->ptr[0] == '\034') {
			rb_funcall(lich_cScript, id_statscript_incoming, 1, tmp);
			if (RSTRING(tmp)->len < 4) {
				continue;
			}
			gsl_generic_update(tmp);
			switch (RSTRING(tmp)->ptr[3])
			{
				case 'q':
					gsl_clock_tick(tmp);
					break;
				case 'V':
					gsl_gsv_update(tmp);
					break;
				case 'o':
					gsl_roomtitle_update(tmp);
					break;
				case 'H':
					gsl_roomdesc_update(tmp);
					break;
				case 'e':
					gsl_famvision_start(tmp);
					break;
				case 'r':
					gsl_gift_stopwatch(tmp);
					break;
				default:
					for (i = 0; i < L_STAT_SZ; i++)
					{
						if (RTEST(rb_funcall(stat_ary[i].re, match, 1, tmp))) {
							stat_ary[i].func(tmp);
#ifdef GSL_HOOKS
							if (stat_ary[i].hook) stat_ary[i].hook(tmp);
#endif
							break;
						}
					}
			}// switch
		}// if
		else {
			for (i = 0; i < L_MISC_SZ; i++)
			{
				if (RTEST(rb_funcall(misc_ary[i].re, match, 1, tmp))) {
					misc_ary[i].func(tmp);
#ifdef GSL_HOOKS
					if (misc_ary[i].hook) misc_ary[i].hook(tmp);
#endif
					break;
				}
			}
			if (i == L_MISC_SZ) {	// no match found while looping
				rb_funcall(lich_cScript, id_namescript_incoming, 1, rb_funcall(tmp, id_gsub, 2, strip_re, rb_str_new("", 0)));
			}
		}
		TIMEECHO;
	}// while
	DISCONNECT;
	return Qnil;
}


/* Bare-bones parser loop -- for optimizing efficiency with MUDs who's encoding is not recognized */
VALUE lich_parserloop_bare(VALUE self)
{
	VALUE tmp;

	while (RTEST(tmp = rb_gv_set("$_SERVERSTRING_", rb_funcall(rb_gv_get("$_SERVER_"), id_gets, 0))))
	{
		rb_funcall(rb_gv_get("$_CLIENT_"), id_write, 1, tmp);
		rb_funcall(rb_gv_get("$_SERVERBUFFER_"), id_push, 1, tmp);
		rb_funcall(lich_cScript, id_namescript_incoming, 1, tmp);
	}
	DISCONNECT;
	return Qnil;
}


/* Initialize bindings to runtime environment */
void Init_lichparser()
{
	lich_cParser = rb_define_class("LichParser", rb_cObject);
	rb_define_singleton_method(lich_cParser, "gsl_loop", lich_parserloop_gsl, 0);
	rb_define_singleton_method(lich_cParser, "bare_loop", lich_parserloop_bare, 0);
	taghash = rb_gv_set("$_TAGHASH_", rb_hash_new());
/*	downstream_hooks = rb_hash_new();
	rb_define_readonly_variable("$DOWNSTREAM_HOOKS", &downstream_hooks);
*/
#ifdef GSL_HOOKS
	rb_define_singleton_method(lich_cParser, "hook", hook_assoc_proc, 2);
#endif

	re_obj_gslgsm = rb_reg_regcomp("\\034GSL|\\034GSM"), rel = rb_reg_regcomp("\\034GSL"), rem = rb_reg_regcomp("\\034GSM");
	roomre = rb_reg_regcomp("\\[[^\\]]+\\]"), alsore = rb_reg_regcomp("^Also here: ");
	npcre = rb_reg_regcomp("\\034GSM\\r\\n$"), stripre = rb_reg_regcomp("\\034[^\\r\\n]+(?:[\\r\\n]+)?");
	re_obj_dig = rb_reg_regcomp("\\d+");
	re = rb_reg_regcomp("\\034.+"), re2 = rb_reg_regcomp("\\034[^\\r\\n]+(?:[\\r\\n]+)?"), re3 = rb_reg_regcomp("\\.\\s*\\r\\n");
	re4 = rb_reg_regcomp("\\034GSM\\r\\n$"), re5 = rb_reg_regcomp("^You also see ");

//	rb_global_variable(&downstream_hooks);
	rb_global_variable(&re_obj_gslgsm);
	rb_global_variable(&rel);
	rb_global_variable(&rem);
	rb_global_variable(&roomre);
	rb_global_variable(&alsore);
	rb_global_variable(&npcre);
	rb_global_variable(&stripre);
	rb_global_variable(&re_obj_dig);
	rb_global_variable(&re);
	rb_global_variable(&re2);
	rb_global_variable(&re3);
	rb_global_variable(&re4);
	rb_global_variable(&re5);

	id_now = rb_intern("now");
	id_to_i = rb_intern("to_i");
	id_slice = rb_intern("slice");
	id_empty_p = rb_intern("empty?");
	id_puts = rb_intern("puts");
	id_call = rb_intern("call");
	id_split = rb_intern("split");
	id_gets = rb_intern("gets");
	id_write = rb_intern("write");
	id_first = rb_intern("first");
	id_last = rb_intern("last");
	id_push = rb_intern("push");
	id_shift = rb_intern("shift");
	id_clear = rb_intern("clear");
	id_match = rb_intern("match");
	id_post_match = rb_intern("post_match");
	id_pre_match = rb_intern("pre_match");
	id_plus = rb_intern("+");
	id_sub_bang = rb_intern("sub!");
	id_sub = rb_intern("sub");
	id_chomp_bang = rb_intern("chomp!");
	id_chomp = rb_intern("chomp");
	id_hyphen = rb_intern("-");
	id_gsub = rb_intern("gsub");
	id_clear = rb_intern("clear");
	id_strip = rb_intern("strip");
	id_wakeme = rb_intern("@@wakeme");
	id_io = rb_intern("@io");
	id_names = rb_intern("@@names");
	id_chop = rb_intern("chop");
	id_thread = rb_intern("@thread");

	id_statscript_incoming = rb_intern("statscript_incoming");
	id_namescript_incoming = rb_intern("namescript_incoming");
	id_gsl_stopwatch = rb_intern("stopwatch");

	rb_global_variable(&id_now);
   rb_global_variable(&id_to_i);
   rb_global_variable(&id_slice);
   rb_global_variable(&id_empty_p);
   rb_global_variable(&id_puts);
   rb_global_variable(&id_call);
   rb_global_variable(&id_split);
   rb_global_variable(&id_gets);
   rb_global_variable(&id_write);
   rb_global_variable(&id_first);
   rb_global_variable(&id_last);
   rb_global_variable(&id_push);
   rb_global_variable(&id_shift);
   rb_global_variable(&id_clear);
   rb_global_variable(&id_match);
   rb_global_variable(&id_post_match);
   rb_global_variable(&id_pre_match);
   rb_global_variable(&id_plus);
   rb_global_variable(&id_sub_bang);
	rb_global_variable(&id_sub);
   rb_global_variable(&id_chomp_bang);
   rb_global_variable(&id_chomp);
   rb_global_variable(&id_hyphen);
   rb_global_variable(&id_gsub);
   rb_global_variable(&id_clear);
	rb_global_variable(&id_chop);
	rb_global_variable(&id_strip);
	rb_global_variable(&id_io);
	rb_global_variable(&id_wakeme);
	rb_global_variable(&id_names);
	rb_global_variable(&id_thread);


   rb_global_variable(&id_statscript_incoming);
   rb_global_variable(&id_namescript_incoming);
   rb_global_variable(&id_gsl_stopwatch);

#ifdef __MINGW32__
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("lichparser.dll"));
#else
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("lichparser.so"));
#endif
}


void Init_lich_libparser()
{
	Init_lichparser();
}
