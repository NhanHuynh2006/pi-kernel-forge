#!/usr/bin/env bash
# Chuẩn bị Raspberry Pi ảo (chạy 1 lần, KHÔNG cần quay video):
#  - tải Raspberry Pi OS 2021-01-11 (kernel gốc 5.4.83-v8+ = đúng version kernel rpi-5.4.y)
#  - lấy kernel8.img + bcm2710-rpi-3-b-plus.dtb ra ngoài cho QEMU
#  - bật SSH, đặt hostname có tên SV, nới ảnh lên 4G (QEMU bắt buộc kích thước thẻ SD là lũy thừa của 2)
set -euo pipefail
cd "$(dirname "$0")"

PI_HOSTNAME="${1:-nhan-24119068-rpi}"
NAME=2021-01-11-raspios-buster-armhf-lite
URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-01-12/$NAME.zip"

[ -f "$NAME.zip" ] || wget -c "$URL"
if [ ! -f disk.img ]; then
    unzip -o "$NAME.zip"
    mv "$NAME.img" disk.img
fi

LOOP="$(sudo losetup -f --show -P disk.img)"
cleanup() {
    sudo umount mnt/boot 2>/dev/null || true
    sudo umount mnt/root 2>/dev/null || true
    sudo losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p mnt/boot mnt/root
sudo mount "${LOOP}p1" mnt/boot
sudo mount "${LOOP}p2" mnt/root

cp mnt/boot/kernel8.img mnt/boot/bcm2710-rpi-3-b-plus.dtb .
sudo touch mnt/boot/ssh                                   # bật SSH khi boot
echo "$PI_HOSTNAME" | sudo tee mnt/root/etc/hostname >/dev/null
sudo sed -i "s/raspberrypi/$PI_HOSTNAME/g" mnt/root/etc/hosts

cleanup
trap - EXIT

SIZE=$(stat -c %s disk.img)
if [ "$SIZE" -lt $((4 * 1024 * 1024 * 1024)) ]; then
    qemu-img resize -f raw disk.img 4G
fi

echo
echo ">> Xong. Kernel gốc trong máy ảo:"
zcat kernel8.img 2>/dev/null | strings | grep -m1 "Linux version" || true
echo ">> Chạy thử: ./launch.sh   (đăng nhập pi / raspberry, hostname: $PI_HOSTNAME)"
