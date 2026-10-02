// SPDX-License-Identifier: GPL-2.0
/*
 * hello.c - Kernel module "Hello World" cho bai tap build kernel Raspberry Pi
 * Sinh vien: Huynh Le Thanh Nhan - MSSV 24119068
 */
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/utsname.h>

#define SV_INFO "SV Huynh Le Thanh Nhan - MSSV 24119068"

static int __init hello_init(void)
{
	pr_info("hello: Xin chao! %s\n", SV_INFO);
	pr_info("hello: da nap vao kernel %s, kien truc %s\n",
		utsname()->release, utsname()->machine);
	return 0;
}

static void __exit hello_exit(void)
{
	pr_info("hello: Tam biet! %s - da go module\n", SV_INFO);
}

module_init(hello_init);
module_exit(hello_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Huynh Le Thanh Nhan - 24119068");
MODULE_DESCRIPTION("Hello World kernel module - bai tap build kernel Raspberry Pi");
MODULE_VERSION("1.0");
