#!/usr/bin/env bash
# Raspberry Pi 5: ghi Raspberry Pi OS Lite 64-bit (Trixie 2026-09-15, kernel gốc 6.18.50)
# ra thẻ nhớ và cài kernel TỰ BUILD (nhánh rpi-6.18.y, bcm2712_defconfig) lên thẻ.
# (Ảnh Bookworm 2025 cũ KHÔNG boot được trên Pi 5 của SV -> dùng ảnh mới nhất.)
#
#   ./flash_sdcard_pi5.sh                       -> liệt kê thẻ nhớ đang cắm rồi dừng
#   ./flash_sdcard_pi5.sh /dev/sdX              -> XÓA SẠCH thẻ, ghi Pi OS + kernel tự build
#   ./flash_sdcard_pi5.sh /dev/sdX --stock      -> XÓA SẠCH thẻ, chỉ Pi OS + kernel GỐC (chưa cần build)
#   ./flash_sdcard_pi5.sh /dev/sdX --kernel-only-> thẻ đã ghi rồi, chỉ chép kernel/modules/dtb tự build
# Quay video 03: --stock -> boot Pi xem kernel gốc -> tắt, cắm thẻ lại -> --kernel-only -> boot
#
# Kernel tự build được chép thành kernel_24119068.img (kernel gốc kernel_2712.img giữ nguyên),
# config.txt thêm dòng kernel=kernel_24119068.img. Muốn quay về kernel gốc: xóa khối
# "# bt-kernel-24119068" cuối /boot/firmware/config.txt.
#
# Biến môi trường tùy chọn:
#   WIFI_SSID=... WIFI_PASS=...   -> Pi tự vào Wi-Fi (cloud-init network-config)
#   PI_USER=pi PI_PASS=raspberry  -> tài khoản đăng nhập (tạo bằng cloud-init user-data)
#   KDIR=~/rpi/linux-6.18         -> cây kernel đã build xong
set -euo pipefail
cd "$(dirname "$0")"

# Wi-Fi mặc định lưu riêng ngoài thư mục dự án (không nộp kèm bài): ~/bt-kernel/sdcard/wifi.env
[ -f "$HOME/bt-kernel/sdcard/wifi.env" ] && . "$HOME/bt-kernel/sdcard/wifi.env"

KDIR="${KDIR:-$HOME/rpi/linux-6.18}"
PI_HOSTNAME="${PI_HOSTNAME:-nhan-24119068-rpi}"
PI_USER="${PI_USER:-pi}"
PI_PASS="${PI_PASS:-raspberry}"
KIMG=kernel_24119068.img
IMG_NAME=2026-09-15-raspios-trixie-arm64-lite
IMG_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-09-15/$IMG_NAME.img.xz"
IMG_SHA256=cdf4f3bfac35ae947b46e4e767f935453810549779ac3290e05a6754aee627e5
STOCK_KREL="6.18.50+rpt-rpi-2712"
MAKE_ARGS=(ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-)
export PATH="$HOME/rpi/cross-bin:$PATH"

DEV="${1:-}"
MODE="${2:-full}"
case "$MODE" in full|--stock|--kernel-only) ;; *) echo "Tùy chọn lạ: $MODE"; exit 1 ;; esac
if [ -z "$DEV" ]; then
    echo "Thiết bị tháo rời được (USB / đầu đọc thẻ):"
    lsblk -d -o NAME,SIZE,TRAN,RM,MODEL | awk 'NR==1 || $3=="usb" || $3=="mmc" || $4=="1"'
    echo
    echo "Chạy lại: $0 /dev/<tên thẻ>   (ví dụ /dev/sdb hoặc /dev/mmcblk0)"
    exit 0
fi

# ---------- kiểm tra an toàn: tránh ghi nhầm ổ cứng của máy ----------
[ -b "$DEV" ] || { echo "Không có thiết bị $DEV"; exit 1; }
[ "$(lsblk -dno TYPE "$DEV")" = disk ] || [ "${ALLOW_LOOP:-0}" = 1 ] || { echo "$DEV không phải cả ổ (đừng chỉ định phân vùng như sdb1)"; exit 1; }
TRAN="$(lsblk -dno TRAN "$DEV" | tr -d ' ')"
RM="$(lsblk -dno RM "$DEV" | tr -d ' ')"
SIZE_B="$(lsblk -bdno SIZE "$DEV")"
if [ "${ALLOW_LOOP:-0}" = 1 ] && [[ "$DEV" == /dev/loop* ]]; then
    :   # chỉ để tự kiểm tra script trên file ảnh (losetup), không dùng khi ghi thẻ thật
elif [ "$TRAN" != usb ] && [ "$TRAN" != mmc ] && [ "$RM" != 1 ]; then
    echo "TỪ CHỐI: $DEV (TRAN=$TRAN) không phải thẻ nhớ/USB tháo rời."; exit 1
fi
if [ "$SIZE_B" -gt $((256 * 1000 ** 3)) ]; then
    echo "TỪ CHỐI: $DEV lớn hơn 256 GB, không giống thẻ nhớ."; exit 1
fi
if lsblk -no MOUNTPOINTS "$DEV" | grep -qE '^/$|^/boot|^/home|\[SWAP\]'; then
    echo "TỪ CHỐI: $DEV đang chứa hệ thống của máy này."; exit 1
fi

KREL="$STOCK_KREL (kernel gốc)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
if [ "$MODE" != --stock ]; then
    # ---------- kernel đã build chưa ----------
    [ -f "$KDIR/arch/arm64/boot/Image" ] || { echo "Chưa build kernel: thiếu $KDIR/arch/arm64/boot/Image"; exit 1; }
    [ -f "$KDIR/Module.symvers" ] || { echo "Chưa build modules: thiếu $KDIR/Module.symvers"; exit 1; }
    ls "$KDIR"/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb >/dev/null \
        || { echo "Chưa build dtbs cho Pi 5 (thiếu bcm2712-rpi-5-b.dtb)"; exit 1; }
    KREL="$(make -s -C "$KDIR" "${MAKE_ARGS[@]}" kernelrelease)"
    echo ">> Kernel tự build: $KREL"
    strings "$KDIR/arch/arm64/boot/Image" | grep -m1 "Linux version" || true

    # modules: cài ra thư mục tạm bằng user thường, lát nữa sudo chép sang thẻ
    make -s -C "$KDIR" "${MAKE_ARGS[@]}" INSTALL_MOD_PATH="$STAGE" INSTALL_MOD_STRIP=1 modules_install
    rm -f "$STAGE/lib/modules/$KREL/build" "$STAGE/lib/modules/$KREL/source"
fi

partdev() { case "$DEV" in *[0-9]) echo "${DEV}p$1" ;; *) echo "${DEV}$1" ;; esac; }
P1="$(partdev 1)"; P2="$(partdev 2)"

echo
lsblk -o NAME,SIZE,TRAN,MODEL,LABEL,MOUNTPOINTS "$DEV"
echo

if [ "$MODE" != --kernel-only ]; then
    if [ ! -f "$IMG_NAME.img" ]; then
        [ -f "$IMG_NAME.img.xz" ] || wget -c "$IMG_URL"
        echo "$IMG_SHA256  $IMG_NAME.img.xz" | sha256sum -c -
        xz -dkf "$IMG_NAME.img.xz"
    fi
    read -r -p "!!! XÓA SẠCH $DEV và ghi Raspberry Pi OS. Gõ lại đúng '$DEV' để tiếp tục: " ans
    [ "$ans" = "$DEV" ] || { echo "Hủy."; exit 1; }
    for p in $(lsblk -lno PATH "$DEV" | tail -n +2); do sudo umount "$p" 2>/dev/null || true; done
    sudo dd if="$IMG_NAME.img" of="$DEV" bs=4M conv=fsync status=progress
    sudo partprobe "$DEV" 2>/dev/null || true
    sudo udevadm settle
    sleep 2
else
    read -r -p "Chép kernel tự build vào thẻ $DEV (không xóa dữ liệu). Gõ 'y' để tiếp tục: " ans
    [ "$ans" = y ] || { echo "Hủy."; exit 1; }
fi

# ---------- mount thẻ ----------
MNT="$(mktemp -d)"
cleanup() {
    sudo umount "$MNT/boot" 2>/dev/null || true
    sudo umount "$MNT/root" 2>/dev/null || true
    rm -rf "$STAGE"; rmdir "$MNT/boot" "$MNT/root" "$MNT" 2>/dev/null || true
}
trap cleanup EXIT
for p in "$P1" "$P2"; do sudo umount "$p" 2>/dev/null || true; done
mkdir -p "$MNT/boot" "$MNT/root"
sudo mount "$P1" "$MNT/boot"
sudo mount "$P2" "$MNT/root"
B="$MNT/boot"; R="$MNT/root"

# ---------- kernel tự build ----------
sudo sed -i '/^# bt-kernel-24119068$/,$d' "$B/config.txt"
if [ "$MODE" != --stock ]; then
    sudo cp "$KDIR/arch/arm64/boot/Image" "$B/$KIMG"
    sudo cp "$KDIR"/arch/arm64/boot/dts/broadcom/*.dtb "$B/"
    sudo cp "$KDIR"/arch/arm64/boot/dts/overlays/*.dtb* "$B/overlays/"
    if [ -f "$KDIR/arch/arm64/boot/dts/overlays/README" ]; then
        sudo cp "$KDIR/arch/arm64/boot/dts/overlays/README" "$B/overlays/"
    fi
    sudo rsync -a --no-owner --no-group "$STAGE/lib/modules/" "$R/lib/modules/"
    sudo chown -R root:root "$R/lib/modules/$KREL"
    # Tên kernel riêng -> firmware không nạp initramfs_2712 của kernel gốc (khác module)
    printf '# bt-kernel-24119068\n[all]\nkernel=%s\n' "$KIMG" | sudo tee -a "$B/config.txt" >/dev/null
fi

# ---------- lần ghi thẻ đầu: tài khoản, SSH, hostname, Wi-Fi ----------
# Trixie dùng cloud-init (giống Raspberry Pi Imager): 3 file meta-data, user-data, network-config
# trong phân vùng boot + tham số ds=nocloud trong cmdline.txt
if [ "$MODE" != --kernel-only ]; then
    IID="bt-24119068-$(date +%s)"
    HASH="$(openssl passwd -6 "$PI_PASS")"
    printf 'dsmode: local\ninstance-id: %s\n' "$IID" | sudo tee "$B/meta-data" >/dev/null
    sudo tee "$B/user-data" >/dev/null <<EOF
#cloud-config
manage_resolv_conf: false
hostname: $PI_HOSTNAME
manage_etc_hosts: true
packages:
- avahi-daemon
apt:
  preserve_sources_list: true
  conf: |
    Acquire {
      Check-Date "false";
    };
timezone: Asia/Ho_Chi_Minh
keyboard:
  model: pc105
  layout: "us"
user:
  name: $PI_USER
  shell: /bin/bash
  lock_passwd: false
  passwd: $HASH
ssh_pwauth: true
runcmd:
  - [ systemctl, enable, --now, ssh ]
EOF
    {
        printf 'network:\n  version: 2\n  ethernets:\n    eth0:\n      dhcp4: true\n      optional: true\n'
        if [ -n "${WIFI_SSID:-}" ]; then
            printf '  wifis:\n    wlan0:\n      dhcp4: true\n      regulatory-domain: "VN"\n'
            printf '      access-points:\n        "%s":\n          password: "%s"\n      optional: true\n' \
                "$WIFI_SSID" "$WIFI_PASS"
        fi
    } | sudo tee "$B/network-config" >/dev/null
    sudo sed -i -E '1 s/ ds=nocloud;i=[^ ]*//; 1 s/$/ ds=nocloud;i='"$IID"'/' "$B/cmdline.txt"
    grep -q 'cfg80211.ieee80211_regdom' "$B/cmdline.txt" \
        || sudo sed -i '1 s/$/ cfg80211.ieee80211_regdom=VN/' "$B/cmdline.txt"
    if [ -n "${WIFI_SSID:-}" ]; then echo ">> Đã cấu hình Wi-Fi: $WIFI_SSID"; fi
fi

sync
echo
echo ">> Trên thẻ:"
ls -lh "$B"/kernel*.img
ls -d "$R/lib/modules/"*
tail -4 "$B/config.txt"
cleanup
trap - EXIT
echo
echo ">> XONG. Rút thẻ, cắm vào Raspberry Pi 5, bật nguồn (lần đầu ~1-2 phút, tự khởi động lại 1 lần)."
echo "   Đăng nhập: $PI_USER / $PI_PASS     SSH: ssh $PI_USER@$PI_HOSTNAME.local  (hoặc ssh $PI_USER@<IP>)"
if [ "$MODE" = --stock ]; then
    echo "   Kiểm tra : uname -r ; cat /proc/version   -> $STOCK_KREL (kernel GỐC)"
    echo "   Sau đó tắt Pi, cắm thẻ lại máy: $0 $DEV --kernel-only"
else
    echo "   Kiểm tra : uname -r ; cat /proc/version   -> $KREL (nhan24119068@hcmute)"
fi
