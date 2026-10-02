# Kịch bản quay đầy đủ — Huỳnh Lê Thành Nhân — MSSV 24119068

Kịch bản bám theo 6 yêu cầu của thầy. Mọi lệnh dưới đây **đã chạy thử thật trên laptop, Pi 5 và Pi ảo ngày 28/09/2026**.
Kết quả ở mục **[THẤY]** là kết quả thật của lần chạy thử đó.

## Yêu cầu của thầy → video nào

| # | Yêu cầu | Mức | Video |
|---|---|---|---|
| 1 | Định danh tên SV | bắt buộc | **mọi video**: echo tên+MSSV, `date`, hostname `nhan-24119068` / `nhan-24119068-rpi`, kernel mang tên `nhan24119068@hcmute`, driver in tên SV |
| 2 | Build kernel cho Raspberry Pi + chạy thử helloworld.c | bắt buộc | **01** |
| 3 | Load driver vào kernel Ubuntu | bắt buộc | **02** |
| 4 | Kiểm tra bằng `dmesg` | bắt buộc | **02** (và 04, 05) |
| 5 | Copy kernel qua Raspberry Pi thật; nếu dùng Pi ảo thì chú ý cùng kernel version | nâng cao | **03** (Pi 5 thật) + **05** (Pi ảo, cùng version 5.4.83-v8+) |
| 6 | Copy file .ko qua Pi, load driver, xem `dmesg` | nâng cao | **04** (Pi 5 thật) + **05** (Pi ảo) |

Tên file upload (đúng thứ tự):
```
24119068_HuynhLeThanhNhan_01_BuildKernel_HelloWorld.mp4
24119068_HuynhLeThanhNhan_02_LoadDriver_Ubuntu_dmesg.mp4
24119068_HuynhLeThanhNhan_03_CopyKernel_RaspberryPi5.mp4
24119068_HuynhLeThanhNhan_04_CopyKo_RaspberryPi5_dmesg.mp4
24119068_HuynhLeThanhNhan_05_RaspAo_CungKernelVersion_dmesg.mp4
```

Ký hiệu: **[NÓI]** = lời đọc, **[GÕ]** = lệnh gõ, **[THẤY]** = kết quả phải hiện ra.
➡ **Pause/Resume** = bấm nút tạm dừng/tiếp tục của OBS để cắt đoạn chờ.

---

## Chuẩn bị chung (không quay)

1. **OBS**: nguồn *Screen Capture (PipeWire)* → cả màn hình; Output → mp4, lưu vào `~/Videos`.
   Muốn đưa thẻ SV lên hình: thêm *Video Capture Device* (webcam) góc nhỏ.
2. Mở **terminal mới** (prompt `nhanhuynh@nhan-24119068`), bấm `Ctrl + Shift + +` 3–4 lần cho chữ to, gõ `clear`.
3. Laptop ở Wi-Fi **NhanHuynh**. Pi 5 cắm thẻ **128 GB**, dùng củ sạc riêng.
4. Tắt thông báo (Do Not Disturb).

**Quy tắc bật / tắt Pi 5 (quan trọng):**
- Tắt: trong Pi gõ `sudo poweroff`, chờ đèn thôi nháy, **rút dây nguồn**.
- Bật: cắm thẻ → cắm nguồn → chờ **2 phút**. Đèn xanh là đang chạy.
- Nếu 1 phút sau đèn vẫn **đỏ**: rút nguồn **15 giây** rồi cắm lại. Bấm nút nguồn chỉ khi đèn đỏ. **Đừng bấm khi đèn xanh**, vì bấm lúc đó là ra lệnh tắt Pi.

---

## VIDEO 01 — Định danh, build kernel Raspberry Pi, chạy thử helloworld.c (YC 1, 2)

**Start Recording.**

**[NÓI]** "Em là Huỳnh Lê Thành Nhân, MSSV 24119068. Video 1: build kernel cho Raspberry Pi và chạy thử
chương trình helloworld."
```bash
echo "Huynh Le Thanh Nhan - MSSV 24119068"; date; hostname
```
**[THẤY]** tên, ngày giờ, `nhan-24119068`. (Đưa thẻ SV lên camera 2–3 giây.)

**[NÓI]** "Em dùng Raspberry Pi 5. Chip BCM2712 của Pi 5 chỉ được hỗ trợ từ kernel 6.1, nên em dùng mã nguồn
kernel chính thức của Raspberry Pi nhánh rpi-6.18.y, cùng dòng 6.18 với Raspberry Pi OS trên Pi."
```bash
cd ~/rpi/linux-6.18
git log -1 --oneline
head -5 Makefile
aarch64-linux-gnu-gcc --version | head -1
```
**[THẤY]** `7e030b607 media: i2c: arducam_64mp: ...`; `VERSION = 6`, `PATCHLEVEL = 18`, `SUBLEVEL = 53`;
`aarch64-linux-gnu-gcc (GNU Toolchain for the A-profile Architecture 9.2-2019.12 ...) 9.2.1`.

**[NÓI]** "Biên dịch chéo từ máy x86 sang ARM 64-bit, cấu hình mặc định cho Pi 5 là bcm2712_defconfig."
```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2712_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
```
> menuconfig cần cửa sổ terminal **ít nhất 19 dòng × 80 cột**. Nếu báo *Your display is too small*: bấm
> `Ctrl + -` 1–2 lần (hoặc phóng to cửa sổ bằng `Super + ↑`), gõ lại lệnh menuconfig, thoát xong thì `Ctrl + +` lại.

Trong menuconfig: vào *General setup* cho thấy *Local version = -v8-16k*, **không đổi gì**, `< Exit >` đến khi thoát.
Nếu hỏi lưu thì chọn **No**.

**[NÓI]** "Build Image, modules và device tree. Em đặt tên người build là nhan24119068 để kernel mang tên em."
```bash
date
make -j12 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     KBUILD_BUILD_USER=nhan24119068 KBUILD_BUILD_HOST=hcmute \
     Image modules dtbs
```
➡ Để chữ chạy 10–15 giây rồi **Pause**. Chờ khoảng **10 phút** tới khi dấu nhắc lệnh hiện lại, không có dòng `Error`. **Resume.**
```bash
date
ls -lh arch/arm64/boot/Image
strings arch/arm64/boot/Image | grep "Linux version"
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease
```
**[THẤY]** 2 mốc `date` cách nhau khoảng 10 phút; Image khoảng 29M;
`Linux version 6.18.53-v8-16k+ (nhan24119068@hcmute) ...`; `6.18.53-v8-16k+`.

**[NÓI]** "Hai mốc thời gian chứng minh em build thật; dòng Linux version có tên nhan24119068 là kernel của em.
Giờ em chạy thử chương trình helloworld.c."
```bash
cd ~/bt-kernel/helloworld
cat helloworld.c
gcc -o helloworld-x86 helloworld.c
./helloworld-x86
aarch64-linux-gnu-gcc -static -o helloworld-arm64 helloworld.c
file helloworld-x86 helloworld-arm64
qemu-aarch64 ./helloworld-arm64
```
**[THẤY]**
`Hello World! SV Huynh Le Thanh Nhan - MSSV 24119068` / `... kien truc x86_64`;
`helloworld-arm64: ELF 64-bit LSB executable, ARM aarch64 ... statically linked`;
chạy bằng qemu-aarch64: `... kien truc aarch64`.

**[NÓI]** "Bản x86 chạy trên laptop. Bản ARM 64-bit em chạy thử bằng trình giả lập qemu-aarch64, và sẽ chạy trên
Pi thật ở video 4. Tiếp theo là helloworld dạng kernel module, tức là driver hello.c."
```bash
cd ~/bt-kernel/hello-rpi
cat hello.c
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KDIR=~/rpi/linux-6.18
file hello.ko
modinfo hello.ko
```
**[THẤY]** `ELF 64-bit LSB relocatable, ARM aarch64`; `author: Huynh Le Thanh Nhan - 24119068`;
`vermagic: 6.18.53-v8-16k+ SMP preempt mod_unload modversions aarch64`.

**[NÓI]** "hello.ko biên dịch cho đúng kernel 6.18.53 vừa build, kiến trúc aarch64, nên không nạp được vào Ubuntu x86.
Em nạp nó vào Pi 5 ở video 4. Hết video 1."
**Stop.**

**Đạt khi:** có echo tên + hostname, 2 mốc date, dòng `(nhan24119068@hcmute)`, helloworld chạy được, và `modinfo` có aarch64 + vermagic 6.18.53.

---

## VIDEO 02 — Load driver vào kernel Ubuntu, kiểm tra dmesg (YC 1, 3, 4)

Terminal mới, gõ `clear`. **Start Recording.**

**[NÓI]** "Em là Huỳnh Lê Thành Nhân, MSSV 24119068. Video 2: biên dịch cùng file hello.c cho kernel Ubuntu đang
chạy, nạp driver vào kernel và kiểm tra bằng dmesg."
```bash
echo "Huynh Le Thanh Nhan - MSSV 24119068"; date; hostname
uname -r
cd ~/bt-kernel/hello-ubuntu
cat hello.c
cat Makefile
make
modinfo hello.ko
```
**[THẤY]** `7.0.0-34-generic`; `vermagic: 7.0.0-34-generic ...` (x86, không có aarch64).
Hai dòng *warning: compiler differs / pahole version differs* là bình thường.

**[NÓI]** "Máy em bật Secure Boot nên kernel chỉ nhận module có chữ ký. Em đã đăng ký khóa riêng vào MOK,
giờ ký hello.ko."
```bash
mokutil --sb-state
./sign_hello_secureboot.sh
```
**[THẤY]** `SecureBoot enabled`; `signer: Huynh Le Thanh Nhan 24119068 module signing`.

**[NÓI]** "Nạp driver vào kernel Ubuntu:"
```bash
sudo insmod hello.ko
lsmod | grep hello
sudo dmesg | tail -5
```
**[THẤY]** `hello  12288  0`;
`hello: Xin chao! SV Huynh Le Thanh Nhan - MSSV 24119068`
`hello: da nap vao kernel 7.0.0-34-generic, kien truc x86_64`

**[NÓI]** "Gỡ driver:"
```bash
sudo rmmod hello
lsmod | grep hello
sudo dmesg | tail -3
```
**[THẤY]** `lsmod` không còn dòng hello; `hello: Tam biet! SV Huynh Le Thanh Nhan - MSSV 24119068 - da go module`.

**[NÓI]** "Driver nạp và gỡ thành công trên kernel Ubuntu, kiến trúc x86_64. Hết video 2." **Stop.**

**Đạt khi:** có đủ chuỗi `make → insmod → lsmod → dmesg → rmmod → dmesg`, và dmesg có tên SV.

---

## VIDEO 03 — Copy kernel qua Raspberry Pi 5 thật (YC 1, 5)

**Trước khi quay:** Pi 5 đã bật bằng **kernel gốc**. Kiểm tra nhanh bằng
`ssh pi@nhan-24119068-rpi.local uname -r`, phải ra `6.18.50+rpt-rpi-2712`.

**Start Recording.**

**[NÓI]** "Em là Huỳnh Lê Thành Nhân, MSSV 24119068. Video 3: copy kernel tự build qua Raspberry Pi 5 thật.
Đầu tiên em cho thấy Pi đang chạy kernel gốc của Raspberry Pi OS."
```bash
echo "Huynh Le Thanh Nhan - MSSV 24119068"; date; hostname
ssh pi@nhan-24119068-rpi.local
```
(mật khẩu `raspberry`) Trong Pi:
```bash
hostname; cat /proc/device-tree/model; echo
uname -r; cat /proc/version
sudo poweroff
```
**[THẤY]** `nhan-24119068-rpi`; `Raspberry Pi 5 Model B Rev 1.1`; `6.18.50+rpt-rpi-2712`;
`Linux version 6.18.50+rpt-rpi-2712 (serge@raspberrypi.com) ...`. Đây là **kernel gốc** do Raspberry Pi build.

`sudo poweroff` sẽ tự thoát SSH, dấu nhắc lệnh trở về `nhanhuynh@nhan-24119068` (**laptop**).

**[NÓI]** "Kernel gốc là 6.18.50, kernel em build là 6.18.53, cùng dòng kernel 6.18." (gõ **trên laptop**)
```bash
make -s -C ~/rpi/linux-6.18 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease
```
➡ **Pause.** Chờ đèn Pi thôi nháy, **rút nguồn Pi**, lấy thẻ cắm vào laptop. **Resume.**

**[NÓI]** "Em chép kernel, modules và device tree tự build vào thẻ nhớ của Pi."
```bash
cd ~/bt-kernel/sdcard
./install_kernel_pi5.sh
./install_kernel_pi5.sh /dev/sda --permanent
```
(Lệnh đầu phải thấy thẻ `sda 116,5G`. Lệnh sau sẽ hỏi mật khẩu sudo của laptop.)
**[THẤY]** `Kernel tự build: 6.18.53-v8-16k+`, dòng `Linux version ... (nhan24119068@hcmute)`,
`Debian GNU/Linux 13 (trixie)`, file `bt24119068/kernel_2712.img` 29M, thư mục modules `6.18.53-v8-16k+`,
và khối `os_prefix=bt24119068/` trong config.txt.

**[NÓI]** "Kernel của em nằm riêng trong thư mục bt24119068 của phân vùng boot. Dòng os_prefix bảo firmware
nạp kernel này. Kernel gốc vẫn được giữ lại để phòng lỗi."

➡ **Pause.** Rút thẻ, cắm vào Pi, cắm nguồn, chờ 2 phút (xem *Quy tắc bật Pi 5*). **Resume.**
```bash
ssh pi@nhan-24119068-rpi.local
```
Trong Pi:
```bash
hostname; uname -r
cat /proc/version
```
**[THẤY]** `6.18.53-v8-16k+` và
`Linux version 6.18.53-v8-16k+ (nhan24119068@hcmute) (aarch64-linux-gnu-gcc ... 9.2.1 ...) #1 SMP PREEMPT <ngày giờ build ở video 01>`.

**[NÓI]** "Raspberry Pi 5 đã chạy kernel do em build: tên nhan24119068 và đúng giờ em build ở video 1.
Để Pi chạy tiếp cho video 4. Hết video 3." **Stop.** Không tắt Pi.

**Đạt khi:** `/proc/version` đổi từ `serge@raspberrypi.com` (6.18.50) sang `nhan24119068@hcmute` (6.18.53).

---

## VIDEO 04 — Copy hello.ko qua Pi 5, load driver, dmesg (YC 1, 6)

Mở **terminal laptop mới**. **Start Recording.**

**[NÓI]** "Em là Huỳnh Lê Thành Nhân, MSSV 24119068. Video 4: copy driver hello.ko và chương trình helloworld
biên dịch ở video 1 qua Raspberry Pi 5, rồi nạp driver vào kernel em tự build."
```bash
echo "Huynh Le Thanh Nhan - MSSV 24119068"; date; hostname
ls -l ~/bt-kernel/hello-rpi/hello.ko ~/bt-kernel/helloworld/helloworld-arm64
scp ~/bt-kernel/hello-rpi/hello.ko ~/bt-kernel/helloworld/helloworld-arm64 pi@nhan-24119068-rpi.local:~
ssh pi@nhan-24119068-rpi.local
```
Trong Pi:
```bash
hostname; uname -r; cat /proc/version
ls -l hello.ko helloworld-arm64
./helloworld-arm64
sudo modinfo hello.ko
sudo insmod hello.ko
lsmod | grep hello
sudo dmesg | tail -5
sudo rmmod hello
lsmod | grep hello
sudo dmesg | tail -3
```
**[THẤY]** (kết quả thật trên chính Pi 5 này):
- `Hello World! SV Huynh Le Thanh Nhan - MSSV 24119068`
- `Chay tren may nhan-24119068-rpi, kernel 6.18.53-v8-16k+, kien truc aarch64`
- `vermagic: 6.18.53-v8-16k+ SMP preempt mod_unload modversions aarch64`, trùng với `uname -r`
- `hello  49152  0`
- `hello: Xin chao! SV Huynh Le Thanh Nhan - MSSV 24119068`
- `hello: da nap vao kernel 6.18.53-v8-16k+, kien truc aarch64`
- sau rmmod: `hello: Tam biet! SV Huynh Le Thanh Nhan - MSSV 24119068 - da go module`

**[NÓI]** "Cùng một file hello.c: ở video 2 chạy trên Ubuntu kiến trúc x86_64, ở video này chạy trên Raspberry Pi 5
kiến trúc aarch64 với kernel do em tự build. Hết video 4."
```bash
exit
```
**Stop.**

**Đạt khi:** `insmod` không lỗi, dmesg có tên SV + `6.18.53-v8-16k+` + `aarch64`.

---

## VIDEO 05 — Raspberry Pi ảo (QEMU), cùng kernel version, load .ko (YC 1, 5, 6)

Video này làm theo tài liệu *"build kernel trên raspberry ảo"* của thầy: kernel **rpi-5.4.y**, `bcm2711_defconfig`,
QEMU `raspi3b`. Pi ảo dùng Raspberry Pi OS 2021-01-11, có kernel gốc **5.4.83-v8+**, **trùng version** với kernel tự build.

**Start Recording.**

**[NÓI]** "Em là Huỳnh Lê Thành Nhân, MSSV 24119068. Video 5: làm trên Raspberry Pi ảo theo hướng dẫn của thầy.
Với Pi ảo phải build kernel cùng version với kernel của Raspberry Pi OS, ở đây là 5.4.83."
```bash
echo "Huynh Le Thanh Nhan - MSSV 24119068"; date; hostname
cd ~/rpi/linux
head -5 Makefile
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
date
make -j12 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     KBUILD_BUILD_USER=nhan24119068 KBUILD_BUILD_HOST=hcmute \
     Image modules dtbs
```
➡ **Pause** khoảng **5 phút**, chờ tới khi dấu nhắc lệnh hiện lại. **Resume.**
```bash
date
strings arch/arm64/boot/Image | grep "Linux version"
make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease
cd ~/bt-kernel/rasp-ao
zcat kernel8.img | strings | grep -m1 "Linux version"
```
**[THẤY]** Kernel tự build là `5.4.83-v8+ (nhan24119068@hcmute)`, kernel gốc là `5.4.83-v8+ (dom@buildbot)`: **cùng version 5.4.83-v8+**.

**[NÓI]** "Hai kernel cùng version 5.4.83-v8+, chỉ khác người build. Giờ em boot Pi ảo bằng kernel gốc trước."
```bash
./launch.sh
```
Chờ khoảng 1–2 phút (có thể **Pause**). Tới dòng `nhan-24119068-rpi login:` thì gõ **`pi`**, mật khẩu **`raspberry`**.
Gõ ở ngay terminal này; **không cần** gõ vào cửa sổ QEMU mới bật lên.
```bash
hostname; uname -r; cat /proc/version
sudo poweroff
```
**[THẤY]** `5.4.83-v8+ (dom@buildbot) ... Mon Dec 14 ... 2020` là kernel gốc. Chờ dòng `reboot: Power down`.

**[NÓI]** "Copy kernel tự build qua Pi ảo và boot bằng nó."
```bash
cp ~/rpi/linux/arch/arm64/boot/Image ~/bt-kernel/rasp-ao/Image-24119068
ls -lh Image-24119068 kernel8.img
./launch.sh Image-24119068
```
Đăng nhập `pi` / `raspberry`:
```bash
cat /proc/version
```
**[THẤY]** `Linux version 5.4.83-v8+ (nhan24119068@hcmute) (gcc version 9.2.1 ...) #1 SMP PREEMPT <giờ vừa build>`.

**[NÓI]** "Giờ biên dịch hello.c cho kernel 5.4.83 và copy qua Pi ảo." Mở **terminal laptop thứ hai**:
```bash
echo "Huynh Le Thanh Nhan - MSSV 24119068"; hostname
cd ~/bt-kernel/hello-rpi-ao
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KDIR=~/rpi/linux
modinfo hello.ko | grep vermagic
scp -P 5555 hello.ko ~/bt-kernel/helloworld/helloworld-arm64 pi@localhost:~
```
(hỏi yes/no thì gõ `yes`, mật khẩu `raspberry`). Quay lại **terminal Pi ảo**:
```bash
./helloworld-arm64
/sbin/modinfo hello.ko
sudo insmod hello.ko
lsmod | grep hello
dmesg | tail -5
sudo rmmod hello
dmesg | tail -3
```
**[THẤY]** (kết quả thật): `vermagic: 5.4.83-v8+ ... aarch64`; `hello  16384  0`;
`hello: Xin chao! SV Huynh Le Thanh Nhan - MSSV 24119068`;
`hello: da nap vao kernel 5.4.83-v8+, kien truc aarch64`; sau rmmod thấy `Tam biet! ...`.

**[NÓI]** "Trên Pi ảo, kernel tự build cùng version 5.4.83-v8+ với Raspberry Pi OS nên driver nạp được.
Hết video 5."
```bash
sudo poweroff
```
**Stop.**

---

## Sau khi quay xong

- Cho Pi 5 về kernel gốc: tắt Pi, rút nguồn, cắm thẻ vào laptop rồi chạy `~/bt-kernel/sdcard/install_kernel_pi5.sh /dev/sda --remove`.
- Đặt lại tên laptop (nếu muốn):
  `sudo hostnamectl set-hostname Nolan && sudo sed -i 's/^127\.0\.1\.1\s.*/127.0.1.1\tNolan/' /etc/hosts`

## Sự cố thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Pi 5 chỉ đèn **đỏ** | rút nguồn 15 giây, cắm lại, chờ 1 phút; vẫn đỏ thì bấm nút nguồn 1 lần. Đừng bấm khi đèn xanh |
| Sau `--permanent` Pi không lên mạng (quá 5 phút, đã rút cắm nguồn) | thẻ vào laptop: `./install_kernel_pi5.sh /dev/sda --remove` để về kernel gốc, rồi báo Claude |
| `ssh: Could not resolve hostname nhan-24119068-rpi.local` | Pi chưa lên xong (chờ thêm), hoặc laptop không ở Wi-Fi NhanHuynh |
| SSH báo *REMOTE HOST IDENTIFICATION HAS CHANGED* | `ssh-keygen -R nhan-24119068-rpi.local` (Pi ảo: `ssh-keygen -R "[localhost]:5555"`) |
| Build báo `Error` | chụp màn hình gửi Claude. Có bản build thử dự phòng: `~/rpi/build-test-618` (Pi 5), `~/rpi/build-test` (Pi ảo) |
| `modinfo: command not found` trong Pi | Pi 5: `sudo modinfo hello.ko`; Pi ảo: `/sbin/modinfo hello.ko` |
| `insmod: Invalid module format` trong Pi | Pi đang chạy kernel gốc; kiểm tra `uname -r` |
| `insmod: Key was rejected by service` (Ubuntu) | quên chạy `./sign_hello_secureboot.sh` sau `make` |
| Cửa sổ QEMU hiện `login:` | không cần dùng. Nếu gõ thì user `pi`, mật khẩu `raspberry` (không phải mật khẩu laptop) |
| `ssh/scp ... port 5555: Connection refused` | Pi ảo chưa boot xong, chờ thêm 1 phút |
| Muốn làm lại Pi ảo từ đầu | tắt Pi ảo, rồi `cp --sparse=always ~/bt-kernel/rasp-ao-disk-clean.img ~/bt-kernel/rasp-ao/disk.img` |
