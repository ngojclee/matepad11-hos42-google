# Files you need — exact sources, sizes and hashes

Everything the procedure consumes, in the order it is used. Verify every SHA-256 before flashing:
`Get-FileHash <file> -Algorithm SHA256`.

## 0. HarmonyOS 2 C432 package (downgrade stage only)

Needed when the tablet is still on HOS 3.x — see the "Stage 0" section of the guide.

| File | Size | SHA-256 |
|---|---|---|
| `update_full_base.zip.dbk` | 4 205 754 241 B | `FB8C26238FA547C51AFBC17598BE67BD9117392A2EBC9ECCB92B16FD657C6778` |

HiSuite fetches this by itself when you choose *Switch to another version → 2.0.0.278 (C432E2R2P1)*.
It **deletes** the file from `%USERPROFILE%\Documents\HiSuite\ROM\` after each attempt, so keep a copy
and drop it back into `ROM\` to skip the 4.2 GB download next time. The same package can be obtained
through *Firm Finder* (model `DBY_W09`, region `C432`, HarmonyOS 2).

## 1. Bootloader-side binaries (small, hard to find)

| File | Size | SHA-256 | Where it goes |
|---|---|---|---|
| `abl_hw865870unlock.elf` | 602 112 B | `552E96D2565627563B7F2B072F720EFD048ABDF11FA050959AEC55E7D3F0B79D` | `firmware\` — written to the `abl` partition (LUN 4) to unlock |
| `dbyprog_emmc_firehose` | 697 648 B | `A0E08A0A26B1356E04FB3B3097C70237A2E3E0861DBD1A99CAFBAB4F5ADC7C9D` | `firmware\` — EDL firehose loader |
| `blank_oeminfo.img` | 100 663 296 B | `3388E81D7056DC3C01DB6E20B195DBF9659CFF346E5A2411DEA470B277E387AC` | `firmware\` — erases the C432 region identity |
| `bootHMOS4.2.img` | 100 663 296 B | *(only needed for APatch root)* | `firmware\` — stock 4.2 boot image to patch |

These four are attached to the **latest release** of this repository.

## 2. HarmonyOS 4.2 China — HOTA packages (from Huawei's CDN)

Base URL: `http://update.dbankcdn.com/download/data/pub_13/HWHOTA_hota_900_9`

| File | Size | SHA-256 |
|---|---|---|
| `update_full_base.zip` | 4 788 537 569 B | `65C6039F24F9BA9C040E1BA9CF050E1720BF37F9AB293DE7B16E7D004BC02213` |
| `update_full_cust_DBY-W09_all_cn.zip` | 379 357 B | `4D5C9D48942C92161776DCD6B2A82CC623BC7C5720AA9E5E23A1A5F05C6554C9` |
| `update_full_preload_DBY-W09_all_cn_R1.zip` | 840 016 077 B | `4C1A00658798D2EE5670FC6A7EF3E03C2AD5A380CA7CFF18A1B06DD9C409B17E` |

Direct links (verified at the time of writing):

```
http://update.dbankcdn.com/download/data/pub_13/HWHOTA_hota_900_9/77/v3/v9yZI3GeRSCCVYPPG7T_5A/full/update_full_base.zip
http://update.dbankcdn.com/download/data/pub_13/HWHOTA_hota_900_9/9b/v3/EcY-XW4RTNOY1DrkyHKRqw/full/update_full_cust_DBY-W09_all_cn.zip
http://update.dbankcdn.com/download/data/pub_13/HWHOTA_hota_900_9/94/v3/Wbkd1I4_SWOtYB4jX0ycDg/full/update_full_preload_DBY-W09_all_cn_R1.zip
```

> Huawei's CDN throttles a single long transfer after ~1 GB. `scripts/download.ps1` splits the file
> into 64 MiB ranges and downloads six at a time: 4.8 GB in ~3 minutes instead of ~50.

## 3. HarmonyOS 2 China — `dload` packages (rebrand step)

These are **different** files from the HOTA packages above: they are the three zips that go inside
`dload\` on the USB stick.

| File | Size | SHA-256 |
|---|---|---|
| `update_sd_base.zip` | 4 244 205 633 B | `A27C37D782409DCF30F86E1AE3599E00ACF2E7CA122D1C33F9EE201E59EE4B40` |
| `update_sd_cust_DBY-W09_all_cn.zip` | 348 663 B | `3382AC6155D9919F85703CFD4C051007CDE95937480AD7451552360256546B1F` |
| `update_sd_preload_DBY-W09_all_cn_R5.zip` | 402 618 860 B | `832735F4DA7615DE6E2C2D5CE71979282A1C078E9CEE1E561751EF066EB31E48` |

They are not on Huawei's public CDN index; the community obtains them from the file pack linked in the
source XDA thread, or by querying *Firm Finder*:

1. <https://ffusersubmission.byethost17.com/?i=2>
2. Model `DBY_W09`, region `C00`, pick the **HarmonyOS 2** build.
3. Open a package's `filelist.xml`, delete the trailing part of the URL and type the real file name.

`update_sd_*` naming matters: the Recovery updater only accepts files whose names start with
`update_sd_`.

## 4. Google stack

| File | Size | Source |
|---|---|---|
| `com.google.android.gms-252432034-hw.apk` | 90.65 MB | <https://github.com/microG/GmsCore/releases> (`-hw` build — required) |
| `com.android.vending-84022634-hw.apk` | 4.02 MB | same release |
| `com.aurora.store_76.apk` | 8.93 MB | <https://f-droid.org/repo/com.aurora.store_76.apk> |

The `-hw` suffix is not cosmetic: the regular microG build does **not** get signature spoofing on
HarmonyOS, the Huawei build does.

## 5. Tooling

| Tool | Notes |
|---|---|
| Python 3.10+ | `python --version` |
| [platform-tools](https://developer.android.com/tools/releases/platform-tools) | `adb`, `fastboot` |
| [bkerler/edl](https://github.com/bkerler/edl) | `pip install -r requirements.txt` |
| [Zadig](https://zadig.akeo.ie/) | binds WinUSB to `QUSB_BULK_CID…` once per PC |

## Directory layout used by the scripts

```
<repo>\
  edl\                          bkerler/edl checkout
  firmware\
    dbyprog_emmc_firehose
    abl_hw865870unlock.elf
    blank_oeminfo.img
    bootHMOS4.2.img
  downloads\
    update_full_base.zip
    update_full_cust_DBY-W09_all_cn.zip
    update_full_preload_DBY-W09_all_cn_R1.zip
  work\                         extracted images (extract_updateapp.py)
  stage\                        staging tree (stage-flash.py)
  backup-YYYYMMDD\              EDL backup
```

`edl-env.ps1` reads `EDL_DIR` and `EDL_LOADER` from the environment if you prefer another layout.
