#include "lich.h"

#ifndef LICH_VERSION
#	define LICH_VERSION "3.55"
#endif

#ifdef __MINGW32__
  int _CRT_glob = 0;
  char *reg_get_value(const HKEY base, const char *keypath);
#else
# include <sys/signal.h>
#endif

#define fatal_err(sig, finalize_p, string)\
do {\
	signal(sig, SIG_DFL);\
	fprintf(stderr, string);\
	if (rb_gv_get("$_SERVER_") != Qnil && !RTEST(rb_funcall(rb_gv_get("$_SERVER_"), rb_intern("closed?"), 0))) {\
		rb_funcall(rb_gv_get("$_SERVER_"), rb_intern("close"), 0);\
	}\
	rb_funcall(rb_stderr, rb_intern("puts"), 1, rb_str_new2(string));\
	if (finalize_p) rb_funcall(rb_cObject, rb_intern("heal_hosts"), 1, rb_funcall(rb_cObject, rb_intern("find_hosts_file"), 0));\
	exit(EXIT_FAILURE);\
} while (0)


extern int ruby_safe_level;
static VALUE lichconfig;
void Init_lichgui();
#ifdef LICH_LAUNCHER
VALUE gui_puts(VALUE self, VALUE string);
VALUE gui_showwindow(VALUE self);
#endif

static void sigsegvexit() { fatal_err(SIGSEGV, 0, "lich: caught SIGSEGV, aborting.\n"); }
static void sigabrtexit() { fatal_err(SIGABRT, 0, "lich: caught SIGABRT, aborting.\n"); }
static void sigintexit() { fatal_err(SIGINT, 1, "lich: caught SIGINT, exiting.\n"); }
static void sigtermexit() { fatal_err(SIGTERM, 1, "lich: caught SIGTERM, exiting.\n"); }


static inline void lich_set_config()
{
	rb_global_variable(&lichconfig);
	rb_define_readonly_variable("$LICHCONFIG", &lichconfig);
	lichconfig = rb_hash_new();
//	rb_eException = rb_eval_string("Exception");
//	rb_cRuntimeError = rb_define_class("RuntimeError", rb_eException);

	rb_gv_set("$version", rb_str_new2(LICH_VERSION));
	rb_hash_aset(lichconfig, rb_str_new2("version"), rb_str_new2(LICH_VERSION));
#ifdef __MINGW32__
	rb_hash_aset(lichconfig, rb_str_new2("OS"), rb_str_new2("Windows"));
#else
	rb_hash_aset(lichconfig, rb_str_new2("OS"), rb_str_new2("Linux"));
#endif
}


#ifdef __MINGW32__
static void reg32_setup()
{
	char *tmp;

   if (tmp = reg_get_value(HKEY_LOCAL_MACHINE, "System\\CurrentControlSet\\Services\\Tcpip\\Parameters\\DataBasePath")) {
      rb_gv_set("$hosts_dir", rb_str_new2(tmp));
      free(tmp);
   }
   else if (tmp = reg_get_value(HKEY_LOCAL_MACHINE, "SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\\DataBasePath")) {
      rb_gv_set("$hosts_dir", rb_str_new2(tmp));
      free(tmp);
   }
   if (tmp = reg_get_value(HKEY_LOCAL_MACHINE, "Software\\Simutronics\\SGE32\\Directory")) {
      rb_hash_aset(rb_gv_get("$LICHCONFIG"), rb_str_new2("SGE Directory"), rb_str_new2(tmp));
      free(tmp);
   }
   if (tmp = reg_get_value(HKEY_LOCAL_MACHINE, "Software\\Simutronics\\Launcher\\Directory")) {
      rb_hash_aset(rb_gv_get("$LICHCONFIG"), rb_str_new2("Launcher Directory"), rb_str_new2(tmp));
      free(tmp);
   }
   if (tmp = reg_get_value(HKEY_LOCAL_MACHINE, "Software\\Simutronics\\WIZ32\\Directory")) {
      rb_hash_aset(rb_gv_get("$LICHCONFIG"), rb_str_new2("Wizard Directory"), rb_str_new2(tmp));
      free(tmp);
 	}
	if (tmp = reg_get_value(HKEY_LOCAL_MACHINE, "Software\\Classes\\Simutronics.Autolaunch\\Shell\\Open\\command\\")) {
		rb_hash_aset(rb_gv_get("$LICHCONFIG"), rb_str_new2("Launcher Shell Command"), rb_str_new2(tmp));
		free(tmp);
	}
	if (tmp = getenv("windir")) {
		rb_hash_aset(rb_gv_get("$LICHCONFIG"), rb_str_new2("Windows Directory"), rb_str_new2(tmp));
		rb_hash_aset(rb_gv_get("$LICHCONFIG"), rb_str_new2("windir"), rb_str_new2(tmp));
	}
}
#endif


static inline void init_ruby_interpreter(int argc, char **argv)
{
   ruby_init();
   ruby_init_loadpath();
   ruby_set_argv(argc, argv);
}


static inline void init_libs()
{
#ifdef LICH_LAUNCHER
	VALUE lich_mGUI;

	Init_lichgui();
	lich_mGUI = rb_define_module("GUI");
	rb_define_module_function(lich_mGUI, "showwindow", gui_showwindow, 0);
	rb_define_module_function(lich_mGUI, "puts", gui_puts, 1);
#endif
#ifdef XMLPARSER
	Init_xmlparser();
#endif
   Init_lichparser();
   Init_socket();
   Init_buffer();
   Init_pathfind();
   Init_lichscript();
	Init_versioncmp();
	Init_cachedarray();
	Init_wizardparser();
	Init_zlib();
	Init_hook();
	Init_lich_frame();
	Init_lichxml();
	lich_set_config();
}


static inline void prep_ruby_env()
{
	ruby_script("Lich");

#ifdef __MINGW32__
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("socket.dll"));
	reg32_setup();
#else
	rb_ary_push(rb_gv_get("$\""), rb_str_new2("socket.so"));
#endif
}


static inline void sig_setup()
{
	signal(SIGSEGV, sigsegvexit);
	signal(SIGABRT, sigabrtexit);
	signal(SIGTERM, sigtermexit);
	signal(SIGINT, sigintexit);
}


int main(int argc, char **argv)
{
#ifndef __MINGW32__
	FILE *fileconf;
#endif
	char *tmp;
	char lichdir[256] = { '\0' };
	char datadir[512] = { '\0' };
	int nerr;

	sig_setup();

#ifndef __MINGW32__
	snprintf(lichdir, 256, "%s%s", getenv("HOME"), "/.lich.cfg");
	fileconf = fopen(lichdir, "rb");
	if (!fileconf) {
		perror("fopen");
		fprintf(stderr, "Your `$HOME/.lich.cfg' file cannot be opened: please create the file and put the full directory name Lich should use for settings/config files in it.\n\nFor example, to do that, you could type:    echo \"$HOME/lich\" > $HOME/.lich.cfg\n");
		exit(EXIT_FAILURE);
	}
	fgets(lichdir, 256, fileconf);
	fclose(fileconf);
	lichdir[strnlen(lichdir, 256) - 1] = '/';
	chdir(lichdir);
#else
	NtInitialize(&argc, &argv);
	strncpy(lichdir, argv[0], 255);
	tmp = &lichdir[strlen(lichdir)];
	while (tmp && (*tmp != '\\') && (*tmp != '/')) {
		tmp--;
	}
	*tmp = '\0';
	chdir(lichdir);
#endif
	
	init_ruby_interpreter(argc, argv);
	init_libs();
	prep_ruby_env();

	getcwd(lichdir, 255);
	lichdir[strlen(lichdir) + 1] = '\0';
	lichdir[strlen(lichdir)] = RSTRING(rb_const_get(rb_cFile, rb_intern("SEPARATOR")))->ptr[0];

	strcpy(datadir, lichdir);
	strcat(datadir, "data");
	datadir[strlen(datadir)] = lichdir[strlen(lichdir) - 1];

	rb_gv_set("$data_dir", rb_str_new(datadir, strlen(datadir)));
	rb_gv_set("$lich_dir", rb_str_new(lichdir, strlen(lichdir)));

	ruby_safe_level = 0;
	if (nerr = ruby_exec()) {
		tmp = RSTRING(rb_funcall(rb_gv_get("$!"), rb_intern("to_s"), 0))->ptr;
		if (!strncasecmp(tmp, "exit", 4)) ruby_stop(0);
		fprintf(stderr, "%s\n", tmp);
		fprintf(stderr, "%s\n", RSTRING(rb_funcall(rb_funcall(rb_gv_get("$!"), rb_intern("backtrace"), 0), rb_intern("join"), 1, rb_str_new2("\n")))->ptr);
		ruby_stop(nerr);
	}
	ruby_stop(0);
}
