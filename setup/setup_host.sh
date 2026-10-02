#!/usr/bin/env bash
# Cài môi trường trên máy Ubuntu THẬT đời mới (đã thử trên Ubuntu 26.04, GCC 15) — chạy 1 lần.
#
# Khác với setup_ubuntu.sh (dành cho máy ảo 22.04):
#  - GCC 15 của Ubuntu mới quá mới so với kernel 5.4 -> dùng toolchain Arm GCC 9.2 (tải về ~/rpi),
#    rồi tạo tên lệnh aarch64-linux-gnu-* trỏ vào nó, nên mọi lệnh trong README giữ nguyên
#    CROSS_COMPILE=aarch64-linux-gnu-
#  - Không cài QEMU (dùng Raspberry Pi THẬT + thẻ nhớ, xem sdcard/flash_sdcard.sh)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"

TC_NAME=gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu
TC_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/$TC_NAME.tar.xz"
TC_DIR="$HOME/rpi/$TC_NAME"
ALIAS_DIR="$HOME/rpi/cross-bin"

sudo apt update
sudo apt install -y git bc bison flex libssl-dev libelf-dev make libc6-dev libncurses-dev \
    build-essential "linux-headers-$(uname -r)" kmod unzip wget xz-utils rsync mokutil openssl \
    qemu-system-arm qemu-user

# Mã nguồn kernel Raspberry Pi nhánh 5.4 (đúng hướng dẫn của thầy)
mkdir -p ~/rpi
[ -d ~/rpi/linux ] || git clone --depth=1 --branch rpi-5.4.y https://github.com/raspberrypi/linux ~/rpi/linux
# Raspberry Pi 5 cần kernel >= 6.1 -> nhánh rpi-6.18.y (cùng dòng 6.18 với Pi OS Trixie 2026-09-15)
[ -d ~/rpi/linux-6.18 ] || git clone --depth=1 --branch rpi-6.18.y https://github.com/raspberrypi/linux ~/rpi/linux-6.18

# Toolchain biên dịch chéo GCC 9.2 (hợp với kernel 5.4)
if [ ! -x "$TC_DIR/bin/aarch64-none-linux-gnu-gcc" ]; then
    wget -c -O ~/rpi/$TC_NAME.tar.xz "$TC_URL"
    tar -C ~/rpi -xf ~/rpi/$TC_NAME.tar.xz
    rm ~/rpi/$TC_NAME.tar.xz
fi
mkdir -p "$ALIAS_DIR"
for f in "$TC_DIR"/bin/aarch64-none-linux-gnu-*; do
    ln -sf "$f" "$ALIAS_DIR/$(basename "$f" | sed 's/aarch64-none-linux-gnu-/aarch64-linux-gnu-/')"
done
if ! grep -q 'rpi/cross-bin' ~/.bashrc; then
    echo 'export PATH="$HOME/rpi/cross-bin:$PATH"   # toolchain GCC 9.2 cho kernel Raspberry Pi 5.4' >> ~/.bashrc
fi
export PATH="$ALIAS_DIR:$PATH"

# Thư mục làm bài: một cho Ubuntu, một cho Raspberry Pi (tránh lẫn file .ko)
mkdir -p ~/bt-kernel/hello-ubuntu ~/bt-kernel/hello-rpi ~/bt-kernel/sdcard ~/bt-kernel/rasp-ao
cp "$HERE"/hello/hello.c "$HERE"/hello/Makefile ~/bt-kernel/hello-ubuntu/
cp "$HERE"/hello/hello.c "$HERE"/hello/Makefile ~/bt-kernel/hello-rpi/
mkdir -p ~/bt-kernel/hello-rpi-ao ~/bt-kernel/helloworld
cp "$HERE"/hello/hello.c "$HERE"/hello/Makefile ~/bt-kernel/hello-rpi-ao/
cp "$HERE"/hello/helloworld.c ~/bt-kernel/helloworld/
cp "$HERE"/sdcard/*.sh ~/bt-kernel/sdcard/
cp "$HERE"/setup/sign_hello_secureboot.sh ~/bt-kernel/hello-ubuntu/
cp "$HERE"/rasp-ao/*.sh ~/bt-kernel/rasp-ao/
chmod +x ~/bt-kernel/sdcard/*.sh ~/bt-kernel/rasp-ao/*.sh ~/bt-kernel/hello-ubuntu/*.sh

# Ảnh Raspberry Pi OS 2021-01-11 (kernel gốc 5.4.83-v8+ = đúng version kernel sẽ build)
IMG=2021-01-11-raspios-buster-armhf-lite
if [ ! -f ~/bt-kernel/sdcard/$IMG.zip ]; then
    wget -c -O ~/bt-kernel/sdcard/$IMG.zip \
        "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-01-12/$IMG.zip"
fi

# Ảnh Raspberry Pi OS Lite 64-bit Trixie 2026-09-15 cho Pi 5 (kernel gốc 6.18.50)
IMG5=2026-09-15-raspios-trixie-arm64-lite
if [ ! -f ~/bt-kernel/sdcard/$IMG5.img.xz ]; then
    wget -c -O ~/bt-kernel/sdcard/$IMG5.img.xz \
        "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-09-15/$IMG5.img.xz"
fi

# Tên máy có tên SV -> hiện trong mọi dấu nhắc lệnh (định danh trong video)
if [ "${SET_HOSTNAME:-1}" = 1 ]; then
    sudo hostnamectl set-hostname nhan-24119068
    sudo sed -i 's/^127\.0\.1\.1\s.*/127.0.1.1\tnhan-24119068/' /etc/hosts
fi

echo
echo ">> Cross compiler: $(aarch64-linux-gnu-gcc --version | head -1)"
echo ">> Kernel version sẽ build: $(make -s -C ~/rpi/linux kernelversion)"
echo ">> Secure Boot: $(mokutil --sb-state 2>&1 || true)"
echo "   (nếu 'enabled' -> xem ~/bt-kernel/hello-ubuntu/sign_hello_secureboot.sh trước video 02)"
echo ">> Mở terminal MỚI để có PATH toolchain + hostname nhan-24119068."
