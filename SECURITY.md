# Security & privacy notes

## What this repository contains

* Markdown guides (EN / VI / FR) and PowerShell/Python scripts.
* Screenshots of a tablet running HarmonyOS 4.2 + microG.

## What it does **not** contain

* No Huawei firmware, no `UPDATE.APP`, no `dload` packages, no `.elf`/`.img` binaries.
  The `.gitignore` blocks them, and the release workflow only packages text + scripts.
* No credentials, tokens, cookies, account names or e-mail addresses.
* No device serial numbers. Every command in the guides uses a placeholder or
  `adb` without `-s`.
* No EDL / partition backup. Keep yours offline.

## Verification

Every file the procedure consumes is pinned by SHA-256 in the README table.
Verify before flashing:

```powershell
Get-FileHash .\update_full_base.zip -Algorithm SHA256
# 65C6039F24F9BA9C040E1BA9CF050E1720BF37F9AB293DE7B16E7D004BC02213
```

The scripts refuse to continue when a hash does not match (see
`unlock-abl.ps1`), when an image is larger than its partition
(`stage-flash.py`, `flash-hos42.ps1`), or when the tablet is in fastbootd.

## Threat model / caveats

* The unlocked bootloader (`verifiedbootstate=orange`) means physical access equals
  full control — no lock screen protects the data.
* microG is a third-party re-implementation of Play Services. Install the APKs only from
  the official `microG/GmsCore` release page; the `-hw` variants are signed by the microG
  project, not by Google.
* Aurora Store fetches APKs from Google's servers through an anonymous (or your own)
  Google session. Prefer the F-Droid build (pinned in the guide).

## Reporting

Open an issue for anything that looks wrong in the procedure (wrong hash, wrong
partition name, a step that no longer matches current firmware). Do **not** open an
issue containing your own backup, serial number or account data.
