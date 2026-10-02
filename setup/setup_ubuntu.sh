#!/usr/bin/env bash
# Cài môi trường trên Ubuntu 22.04 (máy ảo VMware) — chạy 1 lần, KHÔNG cần quay video.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"

sudo apt update
sudo apt install -y git bc bison flex libssl-dev make libc6-dev libncurses-dev \
    build-essential crossbuild-essential-arm64 "linux-headers-$(uname -r)" kmod \
    qemu-system-arm qemu-utils unzip wget openssh-client mokutil

# Mã nguồn kernel Raspberry Pi nhánh 5.4 (đúng hướng dẫn của thầy)
mkdir -p ~/rpi
[ -d ~/rpi/linux ] || git clone --depth=1 --branch rpi-5.4.y https://github.com/raspberrypi/linux ~/rpi/linux

# Hai thư mục riêng: một cho Ubuntu, một cho Raspberry Pi (tránh lẫn file .ko)
mkdir -p ~/bt-kernel/hello-ubuntu ~/bt-kernel/hello-rpi ~/bt-kernel/rasp-ao
cp "$HERE"/hello/hello.c "$HERE"/hello/Makefile ~/bt-kernel/hello-ubuntu/
cp "$HERE"/hello/hello.c "$HERE"/hello/Makefile ~/bt-kernel/hello-rpi/
cp "$HERE"/rasp-ao/*.sh ~/bt-kernel/rasp-ao/
chmod +x ~/bt-kernel/rasp-ao/*.sh

# Tên máy có tên SV -> hiện trong mọi dấu nhắc lệnh (định danh trong video)
sudo hostnamectl set-hostname nhan-24119068

echo
echo ">> Secure Boot (phải là 'disabled' thì mới insmod được module tự build):"
mokutil --sb-state || true
echo ">> qemu: $(qemu-system-aarch64 --version | head -1)"
echo ">> Kernel version sẽ build: $(make -s -C ~/rpi/linux kernelversion)"
echo ">> Mở terminal MỚI để thấy hostname nhan-24119068."
