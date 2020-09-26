#include <stdio.h>

int __attribute__((noinline, far_section)) __far
hello1(void)
{
	if (printf("Hello world!\n") == 13)
		return 0;
	else
		return 1;
}

int __attribute__((noinline, far_section)) __far
hello2(void)
{
	return hello1();
}

int main()
{
	return hello2();
}

