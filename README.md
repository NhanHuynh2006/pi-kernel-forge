# pi-kernel-forge 🔧🍓

Tự build kernel Linux cho **Raspberry Pi 5 thật** và **Raspberry Pi ảo (QEMU)**, biên dịch chéo từ Ubuntu x86,
rồi nạp driver *Hello World* tự viết vào cả kernel Ubuntu lẫn kernel trên Pi.

> Bài tập cá nhân môn Hệ điều hành / Lập trình nhúng — **Huỳnh Lê Thành Nhân — MSSV 24119068**

## Kết quả

| | Kernel gốc | Kernel tự build |
|---|---|---|
| **Raspberry Pi 5** (Model B Rev 1.1, Pi OS Trixie) | `6.18.50+rpt-rpi-2712 (serge@raspberrypi.com)` | `6.18.53-v8-16k+ (nhan24119068@hcmute)` |
| **Raspberry Pi ảo** (QEMU `raspi3b`, Pi OS 2021-01-11) | `5.4.83-v8+ (dom@buildbot)` | `5.4.83-v8+ (nhan24119068@hcmute)` — cùng version |
| **Ubuntu 26.04** (x86_64, Secure Boot bật) | `7.0.0-34-generic` | — (nạp `hello.ko` đã ký MOK) |

```
hello: Xin chao! SV Huynh Le Thanh Nhan - MSSV 24119068
hello: da nap vao kernel 6.18.53-v8-16k+, kien truc aarch64
hello: Tam biet! SV Huynh Le Thanh Nhan - MSSV 24119068 - da go module
```

## Cấu trúc

```
hello/      hello.c (kernel module), helloworld.c (chương trình user-space), Makefile
setup/      setup_host.sh (cài môi trường), sign_hello_secureboot.sh (ký module cho Secure Boot)
sdcard/     install_kernel_pi5.sh  — chép kernel tự build vào thẻ Pi 5, không xóa gì (os_prefix / tryboot)
            flash_sdcard_pi5.sh    — ghi Pi OS Trixie ra thẻ mới (cloud-init: user, Wi-Fi, SSH, hostname)
            flash_sdcard.sh        — bản cũ cho Pi 3/4 + kernel 5.4
rasp-ao/    prepare_rasp_ao.sh, launch.sh — Raspberry Pi ảo bằng QEMU (theo tài liệu môn học)
KICH_BAN_DAY_DU.md — kịch bản quay 5 video theo 6 yêu cầu của đề, mọi lệnh đã chạy thử
```

## Làm lại từ đầu

```bash
./setup/setup_host.sh                # gói build, mã nguồn kernel, toolchain, ảnh Pi OS, hostname
# mở terminal mới

# 1) Kernel Raspberry Pi 5
cd ~/rpi/linux-6.18
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2712_defconfig
make -j12 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     KBUILD_BUILD_USER=nhan24119068 KBUILD_BUILD_HOST=hcmute Image modules dtbs     # ~10 phút

# 2) Driver cho Pi và cho Ubuntu
make -C ~/bt-kernel/hello-rpi ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KDIR=~/rpi/linux-6.18
cd ~/bt-kernel/hello-ubuntu && make && ./sign_hello_secureboot.sh && sudo insmod hello.ko && sudo dmesg | tail

# 3) Chép kernel vào thẻ nhớ Pi 5 (thẻ cắm qua đầu đọc USB)
~/bt-kernel/sdcard/install_kernel_pi5.sh /dev/sdX --permanent      # --remove để về kernel gốc

# 4) Pi ảo: kernel 5.4.83 cùng version với Pi OS 2021-01-11
cd ~/rpi/linux && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig && make -j12 ... Image
cd ~/bt-kernel/rasp-ao && ./prepare_rasp_ao.sh && cp ~/rpi/linux/arch/arm64/boot/Image Image-24119068
./launch.sh Image-24119068           # đăng nhập pi / raspberry, ssh -p 5555 pi@localhost
```

Chi tiết từng bước, lời nói và kết quả mong đợi: [KICH_BAN_DAY_DU.md](KICH_BAN_DAY_DU.md).

## Những gì học được (và các lỗi đã gặp)

| Vấn đề | Nguyên nhân → cách xử lý |
|---|---|
| Kernel 5.4 của tài liệu không boot Pi 5 | chip BCM2712 chỉ có từ kernel 6.1 → dùng nhánh `rpi-6.18.y` + `bcm2712_defconfig` |
| GCC 15 của Ubuntu 26.04 quá mới cho kernel 5.4 | dùng toolchain Arm GNU **GCC 9.2** (`aarch64-none-linux-gnu`), tạo alias `aarch64-linux-gnu-*` |
| `insmod: Key was rejected by service` trên Ubuntu | Secure Boot bật → tạo khóa, `mokutil --import`, enroll khi reboot, ký bằng `scripts/sign-file` |
| Kernel tự build treo khi boot Pi 5 | `cmdline.txt` chép trước lần boot đầu mang **PARTUUID cũ** (Pi OS đổi PARTUUID ở lần boot đầu) → dùng `root=/dev/mmcblk0p2` |
| Pi 5 chỉ sáng **đèn đỏ** | Pi đang ở trạng thái tắt (halt) → rút nguồn 10–15 giây; không bấm nút nguồn khi đèn xanh |
| Thử kernel mới an toàn | `os_prefix=bt24119068/` để kernel/dtb/overlays riêng một thư mục; `tryboot.txt` + `sudo reboot '0 tryboot'` boot thử 1 lần |
| `menuconfig`: *display is too small* | terminal phải ≥ 19 dòng × 80 cột |
| `modinfo: command not found` trên Pi | lệnh nằm ở `/usr/sbin` → `sudo modinfo` / `/sbin/modinfo` |

## Môi trường

Ubuntu 26.04 (kernel 7.0, GCC 15, Secure Boot bật) · Arm GNU Toolchain 9.2-2019.12 · QEMU 10.2 ·
Raspberry Pi 5 Model B Rev 1.1 · Raspberry Pi OS Lite Trixie 2026-09-15 / Buster 2021-01-11.
