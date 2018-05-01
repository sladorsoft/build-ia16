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

int main(int argc, char **argv, char **envp)
{
	static const char * const progs[] = { "ar", "as", "ld", "nm",
	    "objcopy", "objdump", "ranlib", "readelf", "strip", NULL };
	const char *base = argv[0], *p, * const *prog;
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
	for (prog = progs; *prog; ++prog) {
		if (strncasecmp(base, *prog, 5) == 0) {
			q = new_path + dir_len;
			q = stpcpy(q, "../ia16-elf/bin/");
			q = stpcpy(q, *prog);
			stpcpy(q, ".exe");
			argv[0] = new_path;
			execve(new_path, argv, envp);
			fprintf(stderr, "Cannot run %s: %s\n", new_path,
			    strerror(errno));
			return 1;
		}
	}
	putc(168, stderr);
	return 1;
}
