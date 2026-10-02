#!/usr/bin/env bash
# Ghi Raspberry Pi OS 2021-01-11 ra thẻ nhớ + cài kernel TỰ BUILD lên thẻ (yêu cầu 5, Pi THẬT).
# Chỉ dùng cho Raspberry Pi 3 / 3B+ / 4 (kernel 5.4 không boot được Pi 5 / Pi Zero 2 W).
#
#   ./flash_sdcard.sh                 -> liệt kê thẻ nhớ đang cắm rồi dừng
#   ./flash_sdcard.sh /dev/sdX        -> GHI ĐÈ TOÀN BỘ thẻ /dev/sdX (hỏi xác nhận)
#   ./flash_sdcard.sh /dev/sdX --stock
#                                     -> GHI ĐÈ thẻ, chỉ Pi OS + kernel GỐC (dom@buildbot), chưa cần build
#   ./flash_sdcard.sh /dev/sdX --kernel-only
#                                     -> thẻ đã ghi rồi, chỉ chép kernel TỰ BUILD/modules/dtb vào
# Quay video 03 đẹp nhất: --stock -> boot Pi xem kernel gốc -> tắt, cắm thẻ lại -> --kernel-only -> boot
#
# Tùy chọn (biến môi trường):
#   WIFI_SSID=... WIFI_PASS=... WIFI_COUNTRY=VN   -> Pi tự vào Wi-Fi (không có dây LAN)
#   KDIR=~/rpi/linux                              -> cây kernel đã build xong
#   BACKUP_STOCK=1 (mặc định)                     -> giữ kernel gốc thành kernel8-goc.img
#
# Sau khi boot: đăng nhập pi / raspberry, `cat /proc/version` phải có (nhan24119068@hcmute).
set -euo pipefail
cd "$(dirname "$0")"

KDIR="${KDIR:-$HOME/rpi/linux}"
PI_HOSTNAME="${PI_HOSTNAME:-nhan-24119068-rpi}"
IMG_NAME=2021-01-11-raspios-buster-armhf-lite
IMG_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-01-12/$IMG_NAME.zip"
IMG_SHA256=d49d6fab1b8e533f7efc40416e98ec16019b9c034bc89c59b83d0921c2aefeef
MAKE_ARGS=(ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-)
export PATH="$HOME/rpi/cross-bin:$PATH"

list_cards() {
    echo "Thiết bị tháo rời được (USB / đầu đọc thẻ):"
    lsblk -d -o NAME,SIZE,TRAN,RM,MODEL | awk 'NR==1 || $3=="usb" || $3=="mmc" || $4=="1"'
}

DEV="${1:-}"
MODE="${2:-full}"
case "$MODE" in full|--stock|--kernel-only) ;; *) echo "Tùy chọn lạ: $MODE"; exit 1 ;; esac
if [ -z "$DEV" ]; then
    list_cards
    echo
    echo "Chạy lại: $0 /dev/<tên thẻ>   (ví dụ /dev/sdb hoặc /dev/mmcblk0)"
    exit 0
fi

# ---------- kiểm tra an toàn: tránh ghi nhầm ổ cứng của máy ----------
[ -b "$DEV" ] || { echo "Không có thiết bị $DEV"; exit 1; }
[ "$(lsblk -dno TYPE "$DEV")" = disk ] || { echo "$DEV không phải cả ổ (đừng chỉ định phân vùng như sdb1)"; exit 1; }
TRAN="$(lsblk -dno TRAN "$DEV" | tr -d ' ')"
RM="$(lsblk -dno RM "$DEV" | tr -d ' ')"
SIZE_B="$(lsblk -bdno SIZE "$DEV")"
if [ "$TRAN" != usb ] && [ "$TRAN" != mmc ] && [ "$RM" != 1 ]; then
    echo "TỪ CHỐI: $DEV (TRAN=$TRAN) không phải thẻ nhớ/USB tháo rời."; exit 1
fi
if [ "$SIZE_B" -gt $((256 * 1000 ** 3)) ]; then
    echo "TỪ CHỐI: $DEV lớn hơn 256 GB, không giống thẻ nhớ."; exit 1
fi
if lsblk -no MOUNTPOINTS "$DEV" | grep -qE '^/$|^/boot|^/home|\[SWAP\]'; then
    echo "TỪ CHỐI: $DEV đang chứa hệ thống của máy này."; exit 1
fi

KREL="5.4.83-v8+"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
if [ "$MODE" != --stock ]; then
    # ---------- kernel đã build chưa ----------
    [ -f "$KDIR/arch/arm64/boot/Image" ] || { echo "Chưa build kernel: thiếu $KDIR/arch/arm64/boot/Image"; exit 1; }
    [ -f "$KDIR/Module.symvers" ] || { echo "Chưa build modules: thiếu $KDIR/Module.symvers"; exit 1; }
    KREL="$(make -s -C "$KDIR" "${MAKE_ARGS[@]}" kernelrelease)"
    echo ">> Kernel tự build: $KREL"
    strings "$KDIR/arch/arm64/boot/Image" | grep -m1 "Linux version" || true

    # ---------- modules: cài ra thư mục tạm bằng user thường, lát nữa sudo chép sang thẻ ----------
    make -s -C "$KDIR" "${MAKE_ARGS[@]}" INSTALL_MOD_PATH="$STAGE" modules_install
    rm -f "$STAGE/lib/modules/$KREL/build" "$STAGE/lib/modules/$KREL/source"

fi

partdev() { case "$DEV" in *[0-9]) echo "${DEV}p$1" ;; *) echo "${DEV}$1" ;; esac; }
P1="$(partdev 1)"; P2="$(partdev 2)"

echo
lsblk -o NAME,SIZE,TRAN,MODEL,LABEL,MOUNTPOINTS "$DEV"
echo

if [ "$MODE" != --kernel-only ]; then
    if [ ! -f "$IMG_NAME.img" ]; then
        [ -f "$IMG_NAME.zip" ] || wget -c "$IMG_URL"
        echo "$IMG_SHA256  $IMG_NAME.zip" | sha256sum -c -
        unzip -o "$IMG_NAME.zip"
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

# ---------- mount thẻ và cài kernel ----------
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
if [ "$MODE" != --stock ]; then
    if [ "${BACKUP_STOCK:-1}" = 1 ] && [ ! -f "$B/kernel8-goc.img" ] && [ -f "$B/kernel8.img" ]; then
        sudo cp "$B/kernel8.img" "$B/kernel8-goc.img"      # kernel gốc (dom@buildbot) để so sánh / cứu
    fi
    sudo cp "$KDIR/arch/arm64/boot/Image" "$B/kernel8.img"
    sudo cp "$KDIR"/arch/arm64/boot/dts/broadcom/*.dtb "$B/"
    sudo cp "$KDIR"/arch/arm64/boot/dts/overlays/*.dtb* "$B/overlays/"
    [ -f "$KDIR/arch/arm64/boot/dts/overlays/README" ] && sudo cp "$KDIR/arch/arm64/boot/dts/overlays/README" "$B/overlays/"
    sudo rsync -a --no-owner --no-group "$STAGE/lib/modules/" "$R/lib/modules/"
    sudo chown -R root:root "$R/lib/modules/$KREL"
fi

# Pi 3 / 4 đọc kernel8.img (64-bit) khi bật arm_64bit=1
sudo sed -i '/^# bt-kernel-24119068$/,$d' "$B/config.txt"
printf '# bt-kernel-24119068\n[all]\narm_64bit=1\nkernel=kernel8.img\n' | sudo tee -a "$B/config.txt" >/dev/null

sudo touch "$B/ssh"                                                   # bật SSH
echo "$PI_HOSTNAME" | sudo tee "$R/etc/hostname" >/dev/null           # định danh trong prompt
sudo sed -i "s/raspberrypi/$PI_HOSTNAME/g" "$R/etc/hosts"

if [ -n "${WIFI_SSID:-}" ]; then
    sudo tee "$B/wpa_supplicant.conf" >/dev/null <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${WIFI_COUNTRY:-VN}

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASS"
}
EOF
    echo ">> Đã cấu hình Wi-Fi: $WIFI_SSID"
fi

sync
echo
echo ">> Trên thẻ:"
ls -lh "$B"/kernel8*.img
ls -d "$R/lib/modules/"*
{ zcat "$B/kernel8.img" 2>/dev/null || cat "$B/kernel8.img"; } | strings | grep -m1 "Linux version" || true
cleanup
trap - EXIT
echo
echo ">> XONG. Rút thẻ, cắm vào Pi 3/3B+/4, bật nguồn (lần đầu ~1-2 phút)."
echo "   Đăng nhập: pi / raspberry     SSH: ssh pi@$PI_HOSTNAME.local  (hoặc ssh pi@<IP>)"
if [ "$MODE" = --stock ]; then
    echo "   Kiểm tra : cat /proc/version   -> $KREL (dom@buildbot) = kernel GỐC"
    echo "   Sau đó tắt Pi, cắm thẻ lại máy: $0 $DEV --kernel-only"
else
    echo "   Kiểm tra : uname -r ; cat /proc/version   -> $KREL (nhan24119068@hcmute)"
fi
