# MatePad 11 (DBY-W09) — HarmonyOS 4.2 + microG (Google services)

A **reproducible, field-tested** procedure to move a Huawei MatePad 11 (2021) from global
HarmonyOS 2 (C432) to **HarmonyOS 4.2 China (C00)** with a **working Google stack (microG)**,
an **unlocked bootloader** and a **full EDL backup**.

Everything in this repository was executed on a real device and the outcome verified.

```
Before : DBY-W09S  2.0.0.278 (C432E2R2P1)  · Android 10 · locked bootloader · no Google
After  : DBY-W09   4.2.0.208  (C00E100)    · Android 12 · unlocked bootloader · microG (signature spoofing ON)
```

---

## Read this first

* **You can brick your tablet.** The only thing that saved this device twice is a full EDL
  backup taken *before* any write. Do not skip step 2.
* **EDL is disabled on HarmonyOS 4.2.** If you flash 4.2 and the bootloader ends up locked,
  there is no software recovery left (test-point only). This repository always re-flashes the
  unlock ABL **before the first reboot**.
* **Never flash from `fastbootd`.** Use the real bootloader (`fastboot getvar is-userspace` must
  print `no`). Two users in the source thread destroyed their tablets by flashing from fastbootd.
* **microG, not Google Play Services.** HarmonyOS has no GMS framework. microG provides
  Play Services + a Google account; the Play Store itself is replaced by Aurora Store.
  Banking apps that require Play Integrity will not work.

## Guides

| Language | File |
|---|---|
| English | [docs/GUIDE.en.md](docs/GUIDE.en.md) |
| Tiếng Việt | [docs/GUIDE.vi.md](docs/GUIDE.vi.md) |
| Français | [docs/GUIDE.fr.md](docs/GUIDE.fr.md) |

## What you need

| Item | Notes |
|---|---|
| Huawei MatePad 11 (2021) `DBY-W09` / `DBY-W09S` | Snapdragon 865/870 (`kona`). Other models are **not** supported. |
| Windows PC with Python 3 + [platform-tools](https://developer.android.com/tools/releases/platform-tools) | Linux works too, but the scripts here are PowerShell. |
| USB flash drive ≥ 8 GB **plus a USB-C OTG adapter/hub** | Needed once, for the `dload` step. See `images/otg-hub.jpg`. |
| Patience | ~2 hours end to end, most of it waiting for copies/flashes. |

### Files and where they come from

👉 **Full table with every source URL, size and SHA-256: [docs/FILES.md](docs/FILES.md)**

The **bootloader-side binaries** (`abl_hw865870unlock.elf`, `dbyprog_emmc_firehose`,
`blank_oeminfo.img`, `bootHMOS4.2.img`) are attached to the
[binaries release](https://github.com/ngojclee/matepad11-hos42-google/releases/tag/binaries)
so you do not have to hunt for them.

Firmware packages are **not** redistributed (GitHub caps a release asset at 2 GB and the base package
is 4.8 GB). `scripts/download.ps1` pulls them from Huawei's CDN with resume, parallel ranges and
hash verification — the URL is in `FILES.md`, so nothing to search for.

| File | Size | SHA-256 |
|---|---|---|
| `abl_hw865870unlock.elf` | 602 112 B | `552E96D2565627563B7F2B072F720EFD048ABDF11FA050959AEC55E7D3F0B79D` |
| `dbyprog_emmc_firehose` (EDL loader) | 697 648 B | `A0E08A0A26B1356E04FB3B3097C70237A2E3E0861DBD1A99CAFBAB4F5ADC7C9D` |
| `update_full_base.zip` (HOS 4.2 base) | 4 788 537 569 B | `65C6039F24F9BA9C040E1BA9CF050E1720BF37F9AB293DE7B16E7D004BC02213` |
| `update_full_cust_DBY-W09_all_cn.zip` | 379 357 B | `4D5C9D48942C92161776DCD6B2A82CC623BC7C5720AA9E5E23A1A5F05C6554C9` |
| `update_full_preload_DBY-W09_all_cn_R1.zip` | 840 016 077 B | `4C1A00658798D2EE5670FC6A7EF3E03C2AD5A380CA7CFF18A1B06DD9C409B17E` |
| `update_sd_base.zip` / `update_sd_cust_*` / `update_sd_preload_*` | — | CN **HOS 2** dload packages (rebrand step) |
| `blank_oeminfo.img` | 100 663 296 B | `3388E81D7056DC3C01DB6E20B195DBF9659CFF346E5A2411DEA470B277E387AC` |

## Short version of the flow

1. **Backup** every partition over EDL (skip `userdata`).
2. **Blank `oeminfo`** — erase the global C432 identity.
3. **dload Chinese HarmonyOS 2** from a USB stick via Recovery → *Update mode → Memory card/OTG update*.
4. Verify you are on `C00`, then **restore the unlock ABL** over EDL.
5. **Flash HarmonyOS 4.2** (base + cust + preload images) with `fastboot`.
6. Boot, then install **microG `-hw`** + **Aurora Store**.
7. Optional: root with APatch, disable OTA, debloat.

Details, commands and screenshots: see the guide in your language.

## Repository layout

```
docs/            guides (EN / VI / FR)
images/          screenshots and photos used by the guides
skills/          lnc-matepad11 — the same procedure as an AI-agent skill
scripts/         every script needed to reproduce the process
  edl-env.ps1        shared environment (paths, adb/fastboot, python)
  backup.ps1         full EDL backup
  blank-oeminfo.ps1  erase the region identity
  unlock-abl.ps1     restore the unlocked ABL
  flash-hos42.ps1    flash the 4.2 image set over fastboot
  restore-backup.ps1 roll back to the backed-up system
  extract_updateapp.py   Huawei UPDATE.APP container parser
  sparse.py              Android sparse image expander / merger
  stage-flash.py         validate images against the target partition table
.github/workflows/release.yml   builds the release zip on tag
```

## Use it as an AI-agent skill

`skills/lnc-matepad11/SKILL.md` is the same knowledge base written for coding agents
(Claude Code / Codex / OpenCode / Hermes style). Drop the folder into your skills directory
and the agent picks the right scripts, knows the partition map, and refuses the known traps
(fastbootd, missing `PYTHONIOENCODING`, `abl` relock).


## Credits

* Rebrand/downgrade methodology: **faxcon**, XDA thread
  [Comprehensive MatePad 11 2021 (DBY-W09) Rebrand, Update, and Root Guide](https://xdaforums.com/t/comprehensive-matepad-11-2021-dby-w09-rebrand-update-and-root-guide.4789106/)
  (original method by 4PDA member `scoolo`).
* EDL tooling: [bkerler/edl](https://github.com/bkerler/edl).
* `UPDATE.APP` parser: [R0rt1z2/huawei-playground](https://github.com/R0rt1z2/huawei-playground).
* microG: [microG/GmsCore](https://github.com/microG/GmsCore) (`-hw` builds).
* Aurora Store: [AuroraOSS/AuroraStore](https://github.com/AuroraOSS/AuroraStore) / F-Droid.

## Disclaimer

This is a hobbyist procedure for a device **you own**. Downloading and flashing vendor firmware
may violate Huawei's terms of service and may void your warranty. No warranty of any kind —
if you follow this and your tablet stops booting, that is on you (and on your backup).
