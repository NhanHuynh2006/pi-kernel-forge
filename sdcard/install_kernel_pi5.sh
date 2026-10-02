#!/usr/bin/env bash
# Chép kernel TỰ BUILD vào thẻ nhớ Raspberry Pi 5 ĐANG DÙNG (Pi OS có sẵn) — KHÔNG xóa gì trên thẻ.
#
#   ./install_kernel_pi5.sh /dev/sdX            -> chép kernel, bật ở chế độ "boot thử" (tryboot)
#   ./install_kernel_pi5.sh /dev/sdX --permanent-> chép kernel, Pi luôn boot kernel tự build
#   ./install_kernel_pi5.sh /dev/sdX --remove   -> gỡ cấu hình, Pi về kernel gốc như cũ
#
# Mọi file kernel tự build nằm riêng trong thư mục bootfs/bt24119068/ (kernel, dtb, overlays,
# cmdline.txt) nhờ tùy chọn os_prefix của firmware; kernel gốc, dtb gốc, overlays gốc giữ nguyên.
# Modules chép vào /lib/modules/<version tự build>/ (thư mục mới, không đè module gốc).
#
# Chế độ "boot thử": bật Pi bình thường vẫn chạy kernel GỐC. Trong Pi gõ
#     sudo reboot '0 tryboot'
# thì Pi khởi động 1 lần bằng kernel TỰ BUILD. Nếu kernel tự build lỗi, rút-cắm nguồn là về kernel gốc.
#
#   KDIR=~/rpi/linux-6.18   -> cây kernel đã build xong (Image + modules + dtbs)
set -euo pipefail
cd "$(dirname "$0")"

KDIR="${KDIR:-$HOME/rpi/linux-6.18}"
PREFIX=bt24119068
MAKE_ARGS=(ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-)
export PATH="$HOME/rpi/cross-bin:$PATH"

DEV="${1:-}"
MODE="${2:---tryboot}"
case "$MODE" in --tryboot|--permanent|--remove) ;; *) echo "Tùy chọn lạ: $MODE"; exit 1 ;; esac
if [ -z "$DEV" ]; then
    echo "Thiết bị tháo rời được (USB / đầu đọc thẻ):"
    lsblk -d -o NAME,SIZE,TRAN,RM,MODEL | awk 'NR==1 || $3=="usb" || $3=="mmc" || $4=="1"'
    echo; echo "Chạy lại: $0 /dev/<tên thẻ>"; exit 0
fi

# ---------- kiểm tra an toàn ----------
[ -b "$DEV" ] || { echo "Không có thiết bị $DEV"; exit 1; }
[ "$(lsblk -dno TYPE "$DEV")" = disk ] || { echo "$DEV không phải cả ổ (đừng chỉ định sdb1)"; exit 1; }
TRAN="$(lsblk -dno TRAN "$DEV" | tr -d ' ')"; RM="$(lsblk -dno RM "$DEV" | tr -d ' ')"
if [ "$TRAN" != usb ] && [ "$TRAN" != mmc ] && [ "$RM" != 1 ]; then
    echo "TỪ CHỐI: $DEV (TRAN=$TRAN) không phải thẻ nhớ/USB tháo rời."; exit 1
fi
if lsblk -no MOUNTPOINTS "$DEV" | grep -qE '^/$|^/boot|^/home|\[SWAP\]'; then
    echo "TỪ CHỐI: $DEV đang chứa hệ thống của máy này."; exit 1
fi

partdev() { case "$DEV" in *[0-9]) echo "${DEV}p$1" ;; *) echo "${DEV}$1" ;; esac; }
P1="$(partdev 1)"; P2="$(partdev 2)"

if [ "$MODE" != --remove ]; then
    [ -f "$KDIR/arch/arm64/boot/Image" ] || { echo "Chưa build kernel: thiếu $KDIR/arch/arm64/boot/Image"; exit 1; }
    [ -f "$KDIR/Module.symvers" ] || { echo "Chưa build modules: thiếu $KDIR/Module.symvers"; exit 1; }
    [ -f "$KDIR/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb" ] || { echo "Chưa build dtbs Pi 5"; exit 1; }
    KREL="$(make -s -C "$KDIR" "${MAKE_ARGS[@]}" kernelrelease)"
    echo ">> Kernel tự build: $KREL"
    strings "$KDIR/arch/arm64/boot/Image" | grep -m1 "Linux version" || true
fi

STAGE="$(mktemp -d)"; MNT="$(mktemp -d)"
cleanup() {
    sudo umount "$MNT/boot" 2>/dev/null || true
    sudo umount "$MNT/root" 2>/dev/null || true
    rm -rf "$STAGE"; rmdir "$MNT/boot" "$MNT/root" "$MNT" 2>/dev/null || true
}
trap cleanup EXIT
if [ "$MODE" != --remove ]; then
    make -s -C "$KDIR" "${MAKE_ARGS[@]}" INSTALL_MOD_PATH="$STAGE" INSTALL_MOD_STRIP=1 modules_install
    rm -f "$STAGE/lib/modules/$KREL/build" "$STAGE/lib/modules/$KREL/source"
fi

for p in "$P1" "$P2"; do sudo umount "$p" 2>/dev/null || true; done
mkdir -p "$MNT/boot" "$MNT/root"
sudo mount "$P1" "$MNT/boot"
sudo mount "$P2" "$MNT/root"
B="$MNT/boot"; R="$MNT/root"
[ -f "$B/config.txt" ] && [ -f "$B/kernel_2712.img" ] || { echo "Thẻ này không giống Pi OS cho Pi 5 (thiếu config.txt/kernel_2712.img)"; exit 1; }
grep -qi 'PRETTY_NAME' "$R/etc/os-release" && grep PRETTY_NAME "$R/etc/os-release"
echo ">> Kernel gốc trên thẻ:"; ls "$R/lib/modules/"

# lần đầu: giữ bản sao config.txt gốc
[ -f "$B/config.txt.goc-24119068" ] || sudo cp "$B/config.txt" "$B/config.txt.goc-24119068"
# gỡ khối cũ (nếu có) trong config.txt, và bỏ tryboot.txt cũ
sudo sed -i '/^# bt-kernel-24119068$/,/^# end bt-kernel-24119068$/d' "$B/config.txt"
sudo rm -f "$B/tryboot.txt"

if [ "$MODE" = --remove ]; then
    sudo rm -rf "$B/$PREFIX"
    echo ">> Đã gỡ: Pi sẽ boot kernel gốc (modules tự build trong /lib/modules vẫn để lại, vô hại)."
else
    sudo rm -rf "$B/$PREFIX"
    sudo mkdir -p "$B/$PREFIX/overlays"
    sudo cp "$KDIR/arch/arm64/boot/Image" "$B/$PREFIX/kernel_2712.img"
    sudo cp "$KDIR"/arch/arm64/boot/dts/broadcom/bcm2712*.dtb "$B/$PREFIX/"
    sudo cp "$KDIR"/arch/arm64/boot/dts/overlays/*.dtb* "$B/$PREFIX/overlays/"
    if [ -f "$KDIR/arch/arm64/boot/dts/overlays/README" ]; then
        sudo cp "$KDIR/arch/arm64/boot/dts/overlays/README" "$B/$PREFIX/overlays/"
    fi
    # cmdline riêng cho kernel tự build: trỏ thẳng /dev/mmcblk0p2 (Pi OS đổi PARTUUID ở lần boot đầu,
    # chép nguyên PARTUUID cũ thì kernel treo chờ phân vùng không tồn tại); bỏ tham số chỉ dùng lần đầu
    sed -E 's#root=PARTUUID=[^ ]+#root=/dev/mmcblk0p2#; s# resize##; s# init=/usr/lib/raspberrypi-sys-mods/firstboot##' \
        "$B/cmdline.txt" | sudo tee "$B/$PREFIX/cmdline.txt" >/dev/null
    sudo rsync -a --no-owner --no-group "$STAGE/lib/modules/" "$R/lib/modules/"
    sudo chown -R root:root "$R/lib/modules/$KREL"

    BLOCK=$'# bt-kernel-24119068\n[pi5]\nos_prefix='"$PREFIX"$'/\n[all]\n# end bt-kernel-24119068'
    if [ "$MODE" = --permanent ]; then
        printf '%s\n' "$BLOCK" | sudo tee -a "$B/config.txt" >/dev/null
    else
        { cat "$B/config.txt"; printf '%s\n' "$BLOCK"; } | sudo tee "$B/tryboot.txt" >/dev/null
    fi
fi

sync
echo
echo ">> Trên thẻ:"
ls -lh "$B"/kernel_2712.img "$B/$PREFIX/kernel_2712.img" 2>/dev/null || true
ls -d "$R/lib/modules/"*
[ -f "$B/tryboot.txt" ] && { echo "tryboot.txt (cuối):"; tail -5 "$B/tryboot.txt"; }
grep -A3 '^# bt-kernel-24119068$' "$B/config.txt" || true
cleanup; trap - EXIT
echo
case "$MODE" in
--tryboot)   echo ">> XONG. Bật Pi (kernel GỐC). Trong Pi: sudo reboot '0 tryboot'  -> boot 1 lần bằng kernel TỰ BUILD." ;;
--permanent) echo ">> XONG. Bật Pi -> chạy kernel TỰ BUILD ($KREL). Về kernel gốc: $0 $DEV --remove" ;;
--remove)    echo ">> XONG. Pi về kernel gốc." ;;
esac
