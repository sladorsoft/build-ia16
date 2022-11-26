#include <stdio.h>
#include <unistd.h>

extern char **environ;

int __attribute__((noinline, far_section)) __far
hello1(char *arg0)
{
	static char *our_environ[] = { "PATH=/bin:/usr/bin", NULL };
	if (printf("Hello %s!\n", "world") == 13)
		return execle(arg0, arg0, "w00t", "w00t!", NULL, our_environ);
	else
		return 1;
}

int __attribute__((noinline, far_section)) __far
hello2(char *arg0)
{
	return hello1(arg0);
}

int main(int argc, char **argv)
{
	int i;
	if (argc == 1)
		return hello2(argv[0]);
	for (i = 1; i < argc; ++i)
		printf("%s ", argv[i]);
	putchar('\n');
	return 0;
}

