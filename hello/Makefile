# Makefile cho kernel module hello.ko
#   Ubuntu (kernel dang chay):  make
#   Raspberry Pi (build cheo):  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KDIR=$HOME/rpi/linux
obj-m += hello.o

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
