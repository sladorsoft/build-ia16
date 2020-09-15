/*
 * Replacement program for bin/i16as.exe, bin/i16ld.exe, etc. in a DJGPP
 * installation of binutils-ia16.  This program simply hands over to
 * ia16-elf/bin/as.exe, ia16-elf/bin/ld.exe, etc.
 *
 * By TK Chia.  Released under GNU GPL v3 or later.
 */

#include <errno.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#define P(name)		{ sizeof(name) - 1 < 5 ? sizeof(name) - 1 : 5, \
			  name }

int main(int argc, char **argv, char **envp)
{
	typedef struct {
		size_t cmp_len;
		char name[8];
	} prog_t;
	static const prog_t progs[] =
		{ P("ar"), P("as"), P("ld"), P("gold"), P("nm"),
		  P("objcopy"), P("objdump"), P("ranlib"), P("readelf"),
		  P("strip"), P("") };
	const prog_t *prog;
	const char *base = argv[0], *p;
	size_t dir_len;
	char *q;
	setlocale(LC_CTYPE, "POSIX");	/* for strncasecmp(...) */
	while ((p = strpbrk(base, "\\/")) != NULL)
		base = p + 1;
	dir_len = base - argv[0];
	char new_path[dir_len + sizeof("../ia16-elf/bin/objcopy.exe")];
	memcpy(new_path, argv[0], dir_len);
	if (strncasecmp(base, "i16", 3) == 0)
		base += 3;
	for (prog = progs; prog->cmp_len; ++prog) {
		if (strncasecmp(base, prog->name, prog->cmp_len) == 0) {
			q = new_path + dir_len;
			q = stpcpy(q, "../ia16-elf/bin/");
			if (prog->name[0] == 'g')
				stpcpy(q, "ld.gold");
			else {
				q = stpcpy(q, prog->name);
				stpcpy(q, ".exe");
			}
			argv[0] = new_path;
			execve(new_path, argv, envp);
			fprintf(stderr, "Cannot run %s: %s\n", new_path,
			    strerror(errno));
			return 127;
		}
	}
	putc(168, stderr);
	return 127;
}
