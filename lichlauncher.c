#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <windows.h>
#include "regcheck.c"

#define KEYSTRING "Software\\Classes\\Simutronics.Autolaunch\\Shell\\Open\\command\\"
#define DATSTRING "launcher-uninstall.dat"

#define reg_set_value(a,b) reg_set_value(HKEY_LOCAL_MACHINE, a, b)
#define reg_get_value(a) reg_get_value(HKEY_LOCAL_MACHINE, a)

static char *get_winini()
{
	char *ptr;
	char buffer[4096] = { '\0' };
	FILE *f;
	
	ptr = getenv("windir");
	if (!ptr) {
		fprintf(stderr, "windir unknown");
		exit(1);
	}

	snprintf(buffer, sizeof(buffer) - 1, "%s\\win.ini", ptr);
	f = fopen(buffer, "r");
	if (!f) {
		perror("fopen");
		exit(1);
	}

	while (*buffer && !strstr(buffer, "LauncherPath")) {
		if (feof(f)) {
			fprintf(stderr, "unable to find LauncherPath string in win.ini!\n");
			exit(1);
		}
		fgets(buffer, sizeof(buffer), f);
	}

	ptr = calloc(1, strlen(buffer) + 1);
	if (!ptr) {
		perror("calloc");
		exit(1);
	}

	fclose(f);
	strcpy(ptr, buffer);
	return ptr;
}

static void write_uninstall_key()
{
	int f;
	FILE *fptr;
	char *str;

	str = reg_get_value(KEYSTRING);
	if (!str) {
		fprintf(stderr, "error, key `%s' does not exist\n", KEYSTRING);
		exit(1);
	}
	if (strstr(str, "lich")) {
		fprintf(stderr, "Note: registry value `%s' contains the substring `lich', will not overwrite saved key value with a self-modified key value.\n", str);
		return;
	}

	f = open(DATSTRING, O_WRONLY | O_CREAT);
	if (f == -1) {
		perror("open");
		return;
	}
	write(f, str, strlen(str));
	write(f, "\r\n", 2);
	free(str);

	str = get_winini();
	write(f, str, strlen(str));
	close(f);
	free(str);
}

static char *read_uninstall_key()
{
	int f;
	char *buf, *bptr;
	FILE *fptr;

	if (! (buf = calloc(1, 256)) ) {
		perror("calloc");
		exit(1);
	}
	bptr = buf;

	f = open(DATSTRING, O_RDONLY);
	if (f == -1) {
		perror("open");
		exit(1);
	}
	read(f, buf, 255);
	close(f);

	while (bptr < &buf[255] && *bptr != '\r' && *bptr != '\n')
		bptr++;
	if (bptr == &buf[255]) {
		fprintf(stderr, "fatal: corrupted launcher-uninstall.dat file.\n");
		exit(1);
	}
	while (bptr <= &buf[255]) {
		*bptr = '\0';
		bptr++;
	}

	return buf;
}

static char *read_uninstall_winini()
{
	FILE *f;
	char buffer[4096] = { '\0' }, *p;

	f = fopen(DATSTRING, "r");
	fgets(buffer, sizeof(buffer), f);

	memset(buffer, '\0', sizeof(buffer));
	fgets(buffer, sizeof(buffer), f);
	fclose(f);

	p = strchr(buffer, '=');
	if (!p || (strlen(buffer) == 0)) {
		fprintf(stderr, "fatal: corrupt launcher-uninstall.dat file.\n");
		exit(1);
	}

	return strdup(++p);
}

static void change_dir(char **argv)
{
	static char save[256] = { '\0' };
	char buf[256] = { '\0' };
	char *p;

	if (*save) {
		chdir(save);
		return;
	}

	strncpy(buf, argv[0], 255);
	p = &buf[strlen(buf) - 1];
	while (*p && *p != '/' && *p != '\\')
		*p-- = '\0';
	*p = '\0';
	chdir(buf);
	getcwd(save, sizeof(save));
}

static void ch_winini(const char *newstr)
{
	FILE *oldf, *newf;
	char buffer[4096] = { '\0' }, *p;

	p = getenv("windir");
	if (!p) {
		fprintf(stderr, "fatal: windir unknown.\n");
		exit(1);
	}
	chdir(p);
	oldf = fopen("win.ini", "r");
	newf = fopen("win.ini.tmp", "w");
	
	while (fgets(buffer, sizeof(buffer), oldf))
	{
		if ( !strncmp(buffer, "LauncherPath=", strlen("LauncherPath=")) )
		{
			change_dir(NULL);
			memset(buffer, '\0', sizeof(buffer));
			if (newstr)
			{
				strncpy(buffer, newstr, sizeof(buffer));
			}
			else
			{
				getcwd(buffer, sizeof(buffer));
				strncat(buffer, "\\lich.exe\n", sizeof(buffer) - strlen(buffer) - strlen("\\lich.exe\n"));
			}
			fwrite("LauncherPath=", sizeof(char), strlen("LauncherPath="), newf);
		}
		fwrite(buffer, sizeof(char), strlen(buffer), newf);
		memset(buffer, '\0', sizeof(buffer));
	}
	fclose(oldf);
	fclose(newf);

	chdir(p);
	unlink("win.ini");
	rename("win.ini.tmp", "win.ini");
}

static void install()
{
	char *p, buf[2048] = { '\0' }, d[1024] = { '\0' };

	write_uninstall_key();

	p = reg_get_value(KEYSTRING);
	if (!p) {
		fprintf(stderr, "no Simutronics registry key exists; aborting.\n");
		exit(1);
	}

	getcwd(d, 1024);
	snprintf(buf, sizeof(buf), "\"%s\\lich.exe\" %%1", d);
	reg_set_value(KEYSTRING, buf);
	ch_winini(NULL);

	printf("Modification of system registry successful.\n");
	printf("See the Lich directions.txt file for further information.\n");
	fflush(stdout);
}

static void uninstall()
{
	char *p;

	change_dir(NULL);
	p = read_uninstall_key();
	reg_set_value(KEYSTRING, p);
	free(p);
	
	change_dir(NULL);
	p = read_uninstall_winini();
	ch_winini(p);
	free(p);
	
	change_dir(NULL);
	if (unlink(DATSTRING) == -1) {
		perror("unlink");
		exit(1);
	}

	printf("Restoration of system registry successful.\n");
	printf("See the Lich directions.txt file for further information.\n");
	fflush(stdout);
}

static void help()
{
	fprintf(stderr, "usage:  lichlauncher.exe {option}\n\n");
	fprintf(stderr, "\tOptions:\n\n");
	fprintf(stderr, "\t-h\tThis list.\n\n");
	fprintf(stderr, "\t-i\tInstall to the Windows registry so the program will automatically run anytime you login to a Simutronics game.\n\n");
	fprintf(stderr, "\t-u\tUninstall from the Windows registry (this restores whatever registry key existed when you used the -i option).\n\n");
	fprintf(stderr, "\t-v\tView the current value of the registry key.\n");
	exit(0);
}

static void view()
{
	char *p;
	
	p = reg_get_value(KEYSTRING);
	fprintf(stderr, "Key: HKEY_LOCAL_MACHINE\\%s\nValue: %s\n", KEYSTRING, p);
	free(p);

	p = get_winini();
	fprintf(stderr, "WIN.ini: %s", p);
	free(p);
}

static void do_pause()
{
	char buf[2];

	printf("\nPlease press ENTER to close this window...");
	fgets(buf, sizeof(buf), stdin);
}

int main(int argc, char **argv)
{
	int i, j;
	struct {
		void (*func)();
		char *name;
	} opts[] = {
		{ help, "-h", },
		{ install, "-i", },
		{ uninstall, "-u", },
		{ view, "-v", },
		NULL,
	};

	atexit(do_pause);

	if (argc < 2) {
		help();
	}
	change_dir(argv);

	for (i = 1; i < argc; i++)
	{
		for (j = 0; opts[j].func; j++)
		{
			if ( !strcasecmp(argv[i], opts[j].name) ) {
				opts[j].func();
				exit(0);
			}
		}
	}

	help();
	return 0;
}
