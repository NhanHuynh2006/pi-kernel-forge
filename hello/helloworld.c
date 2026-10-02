// helloworld.c - chuong trinh user-space thu nghiem bien dich cheo cho Raspberry Pi
// Sinh vien: Huynh Le Thanh Nhan - MSSV 24119068
#include <stdio.h>
#include <sys/utsname.h>

int main(void)
{
	struct utsname u;

	uname(&u);
	printf("Hello World! SV Huynh Le Thanh Nhan - MSSV 24119068\n");
	printf("Chay tren may %s, kernel %s, kien truc %s\n", u.nodename, u.release, u.machine);
	return 0;
}
