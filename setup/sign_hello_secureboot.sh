#!/usr/bin/env bash
# Ký hello.ko để nạp được vào kernel Ubuntu khi Secure Boot đang BẬT (video 02).
# Không cần nếu `mokutil --sb-state` báo "SecureBoot disabled".
#
# Lần đầu:  ./sign_hello_secureboot.sh enroll
#           -> tạo khóa ~/bt-kernel/mok, đặt 1 mật khẩu tạm, KHỞI ĐỘNG LẠI máy,
#              màn hình xanh "MOK management": Enroll MOK -> Continue -> Yes -> nhập mật khẩu -> Reboot
# Mỗi lần build lại hello.ko:  make && ./sign_hello_secureboot.sh
set -euo pipefail
cd "$(dirname "$0")"

KEYDIR="$HOME/bt-kernel/mok"
KEY="$KEYDIR/MOK.priv"; CERT="$KEYDIR/MOK.der"
SIGN_FILE="/lib/modules/$(uname -r)/build/scripts/sign-file"

if [ "${1:-}" = enroll ]; then
    mkdir -p "$KEYDIR"; chmod 700 "$KEYDIR"
    if [ ! -f "$KEY" ]; then
        openssl req -new -x509 -newkey rsa:2048 -nodes -days 3650 -outform DER \
            -subj "/CN=Huynh Le Thanh Nhan 24119068 module signing/" \
            -addext "extendedKeyUsage=codeSigning" \
            -keyout "$KEY" -out "$CERT"
        chmod 600 "$KEY"
    fi
    sudo mokutil --import "$CERT"
    echo ">> Đã xếp hàng khóa. Khởi động lại máy và chọn 'Enroll MOK' ở màn hình xanh."
    exit 0
fi

[ -f "$KEY" ] || { echo "Chưa có khóa. Chạy: $0 enroll"; exit 1; }
[ -f hello.ko ] || { echo "Chưa có hello.ko, chạy make trước."; exit 1; }
if mokutil --test-key "$CERT" 2>&1 | grep -q "is not enrolled"; then
    echo "Khóa chưa được enroll (chưa reboot + Enroll MOK?)."; exit 1
fi
"$SIGN_FILE" sha256 "$KEY" "$CERT" hello.ko
echo ">> Đã ký hello.ko:"
modinfo hello.ko | grep -E '^(signer|sig_hashalgo|vermagic)'
