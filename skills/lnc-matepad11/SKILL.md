---
name: lnc-matepad11
description: >-
  Use when the user asks for lnc-matepad11, mentions a Huawei MatePad 11 (DBY-W09 / DBY-W09S, chip kona SM8250),
  HarmonyOS 2 C432, HarmonyOS 4.2 C00, EDL / 9008 recovery, Huawei bootloader unlock, Zadig WinUSB, UPDATE.APP
  unpacking, or wants to rebrand / flash / root this tablet or set up microG on it. Self-contained playbook with the
  tooling, partition map, verified hashes, traps and recovery steps proven on real hardware.
---

# lnc-matepad11 — Huawei MatePad 11 (DBY-W09) full-control playbook

Target hardware: **Huawei MatePad 11 (2021)**, model `DBY-W09` / `DBY-W09S`, Qualcomm `kona`
(SM8250), Wi-Fi only, UFS storage. Everything below was executed end to end on real hardware.

## 0. Reference run

| Item | Value |
|---|---|
| Start | `DBY-W09S 2.0.0.278 (C432E2R2P1)` — Android 10, bootloader locked |
| End | `DBY-W09 4.2.0.208 (C00E100)` — Android 12, bootloader **unlocked**, microG (+ signature spoofing) |
| Duration | ~2 h, most of it copying and waiting |
| Safety net | full EDL backup (91 files / 12.87 GB, `userdata` excluded) |

Host requirements: Windows + Python 3 + platform-tools + [bkerler/edl](https://github.com/bkerler/edl);
a USB stick ≥ 8 GB (NTFS) **and** a USB-C OTG adapter/hub.

## 1. Partition map (read from the live GPT — trust this, not blog posts)

| LUN | Size | Partitions |
|---|---|---|
| 0 | ~57 GB | `ssd` `persist` `nvme` `misc` `bsp_info` `oeminfo`(96 MB) `bootfail_info` `rrecord` `cache` `frp` `log` `eng_system` `eng_vendor` `erecovery*` `recovery*` `ramdisk`(2 MB) `vbmeta_*` `patch` `kpatch` `metadata` `preas` `preavs` `super` `version` `preload` `userdata` |
| 1 | 32 MB | `xbl` `xbl_config` |
| 2 | 32 MB | `reserved4` |
| 3 | 32 MB | `cdt` `ddr` |
| 4 | 2 GB | `aop` `tz` `hyp` `modem` `bluetooth` **`abl`(4 MB @ 0xc206000)** `dsp` `keymaster` **`boot`(96 MB)** `devcfg` `qupfw` `vbmeta` `dtbo` `uefisecapp` `featenabler` `devinfo` `dip` `apdp` `limits` `rawdump` `storsec` `uefivarstore` `secdata` |
| 5 | 32 MB | `modemst1` `modemst2` `fsg` `fsc` |

Golden rules: **`abl` and `boot` live on LUN 4**; `super`/`preload`/`oeminfo` on LUN 0.
Always run `printgpt --lun=<N>` before writing anything.

## 2. EDL basics

```powershell
adb reboot edl                      # HOS 2 accepts this; HOS 3.0.0.216 does not
# bind WinUSB once per PC: Zadig → List All Devices → QUSB_BULK_CID… → WinUSB
$env:PYTHONIOENCODING = 'utf-8'     # mandatory, see §4
python edl.py printgpt --memory=ufs --lun=0 --loader=<firehose>
```

| Task | Command |
|---|---|
| Read one partition | `r <part> <file> --memory=ufs --lun=<N> --loader=<loader>` |
| Read everything but a few | `rl <dir> --memory=ufs --loader=<loader> --skip=super,preload,secdata,userdata` |
| Write one partition | `w <part> <file> --memory=ufs --lun=<N> --loader=<loader>` |
| Raw sectors | `rs <start> <count> <file> --memory=ufs --lun=<N> --loader=<loader>` |
| Leave EDL | `reset --resetmode=reset` (or `poweroff`) |

`rl` writes into per-LUN subfolders (`lun0\`, `lun4\`, …) named `<partition>.bin`.
Measured speed: ~40 MB/s read, ~30 MB/s write.

## 3. The only procedure that actually boots

Hand-flashing 4.2 onto the C432 layout **fails** (kernel panic ~15 s, no USB). The stock
updater must repartition first, and the region identity must be neutralised:

1. **Backup** (EDL `rl --skip=userdata` + `rs 0 34` per LUN). Verify `abl` is a 4 MiB ELF.
2. **Blank `oeminfo`** — `w oeminfo blank_oeminfo.img --lun=0`. Without this the CN system
   will not boot on a C432 device.
3. **dload Chinese HarmonyOS 2** — three `update_sd_*.zip` inside `dload\` on an NTFS stick,
   Recovery → *Update mode → Memory card/OTG update*. This repartitions
   (`version` 32 → 576 MB, `preas` 1024 → 296 MB, `super` 7528 → 7352 MB) and installs `C00`.
4. **Restore the unlock ABL** — `w abl abl_hw865870unlock.elf --lun=4`, verify by read-back.
5. **Flash HOS 4.2 over fastboot** — 41 partitions from the eight `.app` entries of the three
   HOTA packages; skip `abl` (relock) and the two 36 MB ramdisks that do not fit a 32 MB partition.
6. **microG `-hw`** + Aurora Store; spoofing works on HOS 4.2 (`System spoofs signature: ✓`).

## 4. Traps that cost real time

1. **`PYTHONIOENCODING=utf-8` is mandatory.** edl's progress bar prints `█`; on cp1252 Python
   dies with `UnicodeEncodeError` in the middle of a firehose session.
2. **A dead session leaves the tablet in "Sahara error state"** (`Mode detected: error`).
   `usb.reset()` does not help — hold **Power 20–30 s**, then re-enter EDL.
3. **`Start-Process -ArgumentList` does not quote.** Paths with spaces get shredded
   (`curl: try 'curl --help'`). Pass one pre-quoted string or use `& $exe @array`.
4. **`Get-Command adb` may resolve to scrcpy's adb**, which ships no `fastboot.exe`.
   Point at platform-tools explicitly.
5. **`UPDATE.APP` header length varies per entry** (98, 126, 12386, 49250, 2030938…).
   It is the offset to the payload — never clamp it to “reasonable” values or you lose
   `BOOT`/`SUPER`.
6. **The container's `size` field is u32** (4 GiB), so `SUPER` arrives as two sparse parts.
   The second part begins with a DONT_CARE chunk covering everything part 0 wrote:
   overlay it, do not concatenate (concatenating yields 14.7 GB of garbage).
7. **The 16-byte type field truncates names**: `vbmeta_hw_product` → `vbmeta_hw_produc`,
   `erecovery_ramdisk` → `erecovery_ramdis`. Fix before staging.
8. **`recovery*` and `erecovery*` live on LUN 0**, not LUN 4 (a size validator caught this).
9. **`fastbootd` is a brick factory.** `fastboot getvar is-userspace` must print `no`.
10. **HOS 4.2 disables EDL.** Never reboot after a 4.2 flash without the unlock ABL in place;
    re-flash `abl` while still in fastboot.

## 5. Recovery playbook

| Symptom | Action |
|---|---|
| `Mode detected: error` | Power 20–30 s, re-enter EDL |
| Boot loop, no USB at all | Power 20 s → hold `Vol-` and plug the cable → fastboot → re-flash |
| Boot loop with fastboot | re-run the flash script; never reboot mid-way |
| dload rejects the package | `oeminfo` still C432 → blank it again |
| Recovery will not open | hold `Vol+` first, then Power; release Power at the logo |
| Need the original system | restore backup over fastboot (lun0/1/4), keep `abl` to stay unlocked |

## 6. Root

APatch works on **HOS 4.2** (the `boot` image carries a ramdisk). It does **not** work on
HOS 2, where Huawei splits kernel (`boot`) and ramdisk (`ramdisk` partition) — there is no
place for the userspace daemon. Root is **not** required for microG.
