# MatePad 11 (DBY-W09) → HarmonyOS 4.2 C00 + microG — Hướng dẫn tiếng Việt

> Đã làm thật trên **Huawei MatePad 11 (2021) DBY-W09S**, Snapdragon 865/870 (`kona`).
> Ban đầu: `2.0.0.278 (C432E2R2P1)`, Android 10, bootloader khoá.
> Kết quả: `4.2.0.208 (C00E100)`, Android 12, bootloader **mở**, microG fake signature **BẬT**.

Quy ước: 🖥 = làm trên PC, 📱 = làm trên tablet.

---

## 0. Quy trình gồm những gì

| Chặng | Mục đích | Công cụ |
|---|---|---|
| A | Backup toàn bộ qua EDL (phao cứu sinh) | `edl.py` |
| B | Xoá định danh vùng (`oeminfo`) | `edl.py` |
| C | Cài **HarmonyOS 2 China** (rebrand → C00) | Recovery + USB |
| D | Ghi lại **ABL unlock** | `edl.py` |
| E | Flash **HarmonyOS 4.2 C00** | `fastboot` |
| F | Cài **microG `-hw`** + Aurora Store | `adb` |

Chặng C là **bắt buộc**: máy C432 không chịu boot hệ CN, và layout phân vùng của 4.2 khác HOS 2.
Trình nạp chính hãng (`dload`) tự đổi bảng phân vùng — đó là lý do phải dùng nó thay vì flash tay.

---

## 1. Chuẩn bị

🖥 Windows 10/11, Python 3.10+, [platform-tools](https://developer.android.com/tools/releases/platform-tools),
[bkerler/edl](https://github.com/bkerler/edl) + `pip install -r requirements.txt`.

🖥 USB ≥ 8 GB, format **NTFS**, có thư mục `dload\` ở gốc. Cần thêm **đầu chuyển/hub USB-C OTG**
để tablet đọc được USB:

![Hub USB-C OTG](images/otg-hub.jpg)

📦 Tải và kiểm hash (bảng hash ở README):

```
update_full_base.zip                      HOS 4.2 base
update_full_cust_DBY-W09_all_cn.zip       HOS 4.2 cust
update_full_preload_DBY-W09_all_cn_R1.zip HOS 4.2 preload
update_sd_base.zip                        HOS 2 CN dload (rebrand)
update_sd_cust_DBY-W09_all_cn.zip
update_sd_preload_DBY-W09_all_cn_R5.zip
blank_oeminfo.img                         xoá định danh vùng
abl_hw865870unlock.elf                    ABL unlock
dbyprog_emmc_firehose                     loader EDL
```

Chép **nguyên 3 file** `update_sd_*.zip` (không giải nén) vào `dload\`.

📱 Bật **Tùy chọn nhà phát triển → Gỡ lỗi USB**, cắm cáp và bấm **Cho phép**.

---

## 2. Chặng A — Backup EDL

🖥 Đưa máy vào EDL và gắn driver WinUSB (**1 lần cho mỗi PC**):

```powershell
adb reboot edl      # màn hình tắt, Windows hiện "QUSB_BULK_CID:…"
# Zadig → Options → List All Devices → chọn QUSB_BULK_CID… → WinUSB → Replace Driver
```

🖥 Sau đó:

```powershell
.\scripts\edl-env.ps1
python $Edl edl.py printgpt --memory=ufs --lun=0 --loader=$Loader   # phải thấy 40 phân vùng
.\scripts\backup.ps1                                                # ~12.9 GB, bỏ userdata
```

**Kiểm tra trước khi đi tiếp:** thư mục backup có ~90 file; `lun4\abl.bin` đúng 4 194 304 byte và
bắt đầu bằng `7F 45 4C 46` (ELF); `lun4\boot.bin` bắt đầu bằng `ANDROID!`; `lun0\oeminfo.bin` =
100 663 296 byte. Copy `oeminfo.bin` + `abl.bin` sang **ổ khác**.

> ⚠️ Nếu `edl.py` chết giữa phiên, máy rơi vào **Sahara error state** (`Mode detected: error`).
> Cách duy nhất: **giữ Nguồn 20–30 giây** cho máy khởi động lại.
> Luôn đặt `PYTHONIOENCODING=utf-8` (script đã làm sẵn) — progress bar của edl làm crash Python trên cp1252.

---

## 3. Chặng B — Xoá `oeminfo`

Vẫn trong EDL:

```powershell
.\scripts\blank-oeminfo.ps1     # ghi blank_oeminfo.img vào LUN 0, verify bằng cách đọc lại
```

Xong máy sẽ **tự tắt** — bình thường.

---

## 4. Chặng C — Cài HarmonyOS 2 China (`dload`)

1. Rút USB an toàn khỏi PC → cắm vào **hub OTG** → cắm hub vào tablet.
   (Cắm USB có thể làm máy tự bật — không sao.)
2. 📱 Giữ **Nguồn 15 giây** cho tắt hẳn. Sau đó **giữ Vol+ rồi bấm Nguồn**; khi hiện logo Huawei
   thì **nhả Nguồn**, vẫn giữ Vol+ thêm ~5 giây → vào **Recovery**.
3. Trong Recovery (có thể là tiếng Trung):
   * `升级模式` / **Update mode**
   * `存储卡/OTG升级` / **Memory card/OTG update**
4. Máy kiểm tra gói, **đổi bảng phân vùng** rồi ghi. 10–20 phút. **Không rút USB, không tắt máy.**
5. Khi báo thành công: **Factory reset**, rồi reboot.

Kiểm tra: **Cài đặt → Giới thiệu máy → Số bản dựng** phải là `DBY-W09 2.0.0.273 (C00E210)`
(hoặc bản `C00…` khác). Nếu vẫn `C432` → update chưa chạy.

```powershell
adb shell getprop ro.build.display.id     # DBY-W09 2.0.0.273(C00E210)
```

---

## 5. Chặng D — Ghi lại ABL unlock

`dload` đã ghi ABL stock ⇒ bootloader **khoá lại** (`verifiedbootstate=green`, `flash.locked=1`).

```powershell
adb reboot edl
.\scripts\unlock-abl.ps1        # ghi abl_hw865870unlock.elf vào LUN 4 + đọc lại verify
adb reboot bootloader
fastboot getvar unlocked        # phải là: unlocked: yes
fastboot getvar is-userspace    # phải là: is-userspace: no
```

---

## 6. Chặng E — Flash HarmonyOS 4.2

Gói 4.2 CN gồm 3 zip HOTA, mỗi zip có `UPDATE.APP` + `PTABLE.APP`. Bóc image rồi để script
kiểm tra **vừa partition thật** trên máy:

```powershell
python .\scripts\extract_updateapp.py  update_full_base.zip      -o work\base
python .\scripts\extract_updateapp.py  update_full_cust_*.zip    -o work\cust
python .\scripts\extract_updateapp.py  update_full_preload_*.zip -o work\preload
python .\scripts\sparse.py             work\base\super_part0.img work\base\super_part1.img -o work\super.img
python .\scripts\stage-flash.py        -i work -o stage           # in bảng fit, phải kết thúc "ALL GOOD"
```

`stage-flash.py` sẽ **dừng** nếu có image lớn hơn partition, và **không bao giờ** đưa `abl` (giữ unlock)
hay file `gpt` vào bộ flash.

Sau đó:

```powershell
adb reboot bootloader
fastboot getvar is-userspace     # phải "no" — nếu "yes" thì DỪNG
.\scripts\flash-hos42.ps1        # 41 phân vùng, ~9 GB, ~5 phút với USB 3
```

Script dừng ngay ở lỗi đầu tiên và **không tự reboot**.

```powershell
fastboot reboot
adb wait-for-device
adb shell getprop ro.build.display.id      # DBY-W09 4.2.0.208(C00E100)
adb shell getprop ro.build.version.release # 12
adb shell getprop ro.boot.flash.locked     # 0 → vẫn unlock
```

> ⚠️ Nếu không boot: **đừng reboot loạn**. Giữ Nguồn 20 giây, vào lại fastboot
> (giữ `Vol-` rồi cắm cáp) và chạy lại `flash-hos42.ps1`, hoặc phục hồi backup (§9).

---

## 7. Chặng F — Google (microG)

microG là bản thay thế Play Services. Bản **`-hw`** là bản dành cho Huawei: trên HOS 4.2 hệ thống báo
`System spoofs signature: ✓` — điều HOS 2 **không** làm được.

```powershell
curl.exe -L -o gms-hw.apk     https://github.com/microG/GmsCore/releases/download/v0.3.17.252432/com.google.android.gms-252432034-hw.apk
curl.exe -L -o vending-hw.apk https://github.com/microG/GmsCore/releases/download/v0.3.17.252432/com.android.vending-84022634-hw.apk
adb install -r -g gms-hw.apk
adb install -r -g vending-hw.apk

adb shell pm grant com.google.android.gms android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.google.android.gms android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant com.google.android.gms android.permission.ACCESS_BACKGROUND_LOCATION

curl.exe -L -o aurora.apk https://f-droid.org/repo/com.aurora.store_76.apk
adb install -r -g aurora.apk

adb shell settings put global ota_disable_automatic_update 1
adb shell settings put global auto_update_apps 0
```

📱 Mở **microG Settings → Self-Check**:

![microG self-check](images/microg-selfcheck.png)

* `System spoofs signature` ✓
* `microG Services installed` ✓ / `has correct signature` ✓
* `microG Companion / Play Store installed` ✓ — dấu signature của nó **vẫn đỏ**, chỉ ảnh hưởng
  Play Store thật, không ảnh hưởng Aurora.
* `microG Services Framework` ✗ — bình thường, microG không có GSF.

Tiếp theo **Google Accounts → Add account** và đăng nhập. Nếu Google báo
*"This browser or app may not be secure"* → thử lại, hoặc dùng mật khẩu ứng dụng.

Cuối cùng mở **Aurora Store**, chọn *Google* (dùng tài khoản microG) hoặc *Anonymous*:

![Aurora Store](images/aurora-store.png)

---

## 8. Tuỳ chọn: root (APatch)

Chỉ cần nếu muốn can thiệp hệ thống (hosts/AdAway, gỡ app hệ thống, sửa build.prop).
Trên HOS 4.2, `boot` **có** chứa ramdisk nên APatch chạy được — trên HOS 2 thì **không**
(vì Huawei tách kernel và ramdisk ra 2 partition).

1. Cài `APatch_*.apk`, đẩy `boot.img` stock (hoặc `bootHMOS4.2.img`) vào máy.
2. APatch → *Patch image* → lấy file đã patch ra PC.
3. `adb reboot bootloader` → `fastboot flash boot patched_boot.img` → `fastboot reboot`.
4. Mở APatch, đặt superkey.

---

## 9. Xử lý sự cố

| Hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `edl.py` báo `Mode detected: error` | phiên trước chết giữa đường (Sahara error) | **giữ Nguồn 20–30 s**, vào lại EDL |
| Kẹt logo Huawei, **không có USB** | kernel panic sau khi flash dở | giữ Nguồn 20 s → `Vol-` + cắm cáp → fastboot → flash lại |
| Boot loop **nhưng có** fastboot | image sai/thiếu | kiểm `is-userspace` = no, chạy lại `flash-hos42.ps1` |
| `dload` báo *version check failed* | `oeminfo` còn C432 | làm lại chặng B rồi chặng C |
| Không vào được Recovery | nhả Vol+ quá sớm | giữ Vol+ trước, bấm Nguồn, nhả Nguồn khi hiện logo |
| `fastboot flash super` treo | cổng USB 2 / qua hub | cắm trực tiếp cổng USB 3, chạy lại |
| Self-check đỏ phần spoofing | đang ở HOS 2, hoặc dùng bản không phải `-hw` | phải là HOS 4.2 + APK `-hw` |

### Quay lại hoàn toàn (rollback)

```powershell
adb reboot bootloader
.\scripts\restore-backup.ps1 -Backup "D:\edl-backup"   # ghi lại mọi partition, giữ ABL unlock
fastboot reboot
```

---

## 10. Được gì / mất gì

**Được:** cài app Play qua Aurora, tài khoản Google, push notification (microG Cloud Messaging),
định vị, phần lớn app cần Google, bút cảm ứng + camera (vendor gốc còn nguyên), OTA tắt vĩnh viễn.

**Mất:** Play Integrity / SafetyNet (app ngân hàng, Netflix HD), Play Store thật, Google Cast cần GMS,
dịch vụ Huawei bản quốc tế (vì đang chạy ROM Trung).

**Bảo mật:** bootloader mở (`verifiedbootstate=orange`) ⇒ ai cầm máy đều flash được.
Giữ backup EDL ở nơi khác, đừng để trong máy.
