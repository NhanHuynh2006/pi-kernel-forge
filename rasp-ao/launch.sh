#!/bin/bash
# Chạy Raspberry Pi ảo (QEMU, giả lập Pi 3B+ 64-bit) — dựa trên launch.sh của thầy.
#   ./launch.sh                   -> boot kernel GỐC của Raspberry Pi OS (kernel8.img, 5.4.83-v8+)
#   ./launch.sh Image-24119068    -> boot kernel TỰ BUILD
# Đăng nhập: pi / raspberry.  SSH từ Ubuntu: ssh -p 5555 pi@localhost
# Tắt máy ảo: trong Pi gõ `sudo poweroff`
cd "$(dirname "$0")"
KERNEL="${1:-kernel8.img}"
[ -f "$KERNEL" ] || { echo "Không thấy file kernel: $KERNEL"; exit 1; }
echo ">> Boot Raspberry Pi ảo với kernel: $KERNEL"

qemu-system-aarch64 \
    -M raspi3b \
    -cpu cortex-a72 \
    -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1" \
    -dtb bcm2710-rpi-3-b-plus.dtb \
    -sd disk.img \
    -kernel "$KERNEL" \
    -m 1G -smp 4 \
    -serial stdio \
    -usb -device usb-mouse -device usb-kbd \
    -device usb-net,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::5555-:22
