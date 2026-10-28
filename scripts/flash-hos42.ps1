# flash-hos42.ps1 — Stage E: flash the staged HarmonyOS 4.2 image set over fastboot.
#
#   .\flash-hos42.ps1 -Stage .\stage
#
# Expects this layout (created by stage-flash.py):
#   stage\lun0\*.img   stage\lun1\*.img   stage\lun4\*.img
#
# Safety rules baked in:
#   * refuses to run on fastbootd (is-userspace must be "no")
#   * refuses to flash an image larger than its partition
#   * never flashes "abl" (keeps the bootloader unlocked)
#   * stops at the first failure and does NOT reboot

param(
    [string]$Stage = '.\stage',
    [switch]$Force
)

. "$PSScriptRoot\edl-env.ps1"

if (-not (Test-Path $Stage)) { throw "stage folder not found: $Stage" }
if (-not (Wait-Fastboot 20)) { throw 'No fastboot device. Put the tablet in fastboot (Vol- while plugging the cable).' }

$userspace = (& $Fastboot getvar is-userspace 2>&1 | Select-Object -First 1)
Write-Host "is-userspace : $userspace"
if ($userspace -notmatch 'no') {
    throw 'The tablet is in fastbootd. Reboot to the real bootloader (adb reboot bootloader) — flashing from fastbootd bricks devices.'
}

$unlocked = (& $Fastboot getvar unlocked 2>&1 | Select-Object -First 1)
Write-Host "unlocked     : $unlocked"
if ($unlocked -notmatch 'yes' -and -not $Force) {
    throw 'Bootloader is locked. Run unlock-abl.ps1 first (or pass -Force if you know what you are doing).'
}

function Get-PartitionSize([string]$Name) {
    $line = & $Fastboot getvar "partition-size:$Name" 2>&1 | Select-Object -First 1
    if ($line -match '(0x[0-9a-fA-F]+)') { return [int64]$Matches[1] }
    return 0
}

$failed = @()
$count  = 0
foreach ($lun in 0, 1, 4) {
    $dir = Join-Path $Stage "lun$lun"
    if (-not (Test-Path $dir)) { continue }
    $files = Get-ChildItem $dir -Filter *.img | Sort-Object Length
    Write-Host "`n===== LUN $lun : $($files.Count) partitions ====="

    foreach ($f in $files) {
        $part = $f.BaseName
        if ($part -eq 'abl') { Write-Warning "skipping 'abl' (would relock the bootloader)"; continue }
        if ($part -like 'gpt*') { Write-Warning "skipping GPT file $($f.Name)"; continue }

        $cap = Get-PartitionSize $part
        if ($cap -gt 0 -and $f.Length -gt $cap) {
            Write-Warning ("{0}: image {1:N0} B > partition {2:N0} B — SKIPPED" -f $part, $f.Length, $cap)
            $failed += $part
            continue
        }

        $sw  = [Diagnostics.Stopwatch]::StartNew()
        $out = & $Fastboot flash $part $f.FullName 2>&1
        $count++
        if ($out -match 'OKAY|Finished') {
            Write-Host ("OK   {0,-20} {1,8:N1} MB {2,7:N1}s" -f $part, ($f.Length / 1MB), $sw.Elapsed.TotalSeconds)
        } else {
            Write-Warning ("FAIL {0} :: {1}" -f $part, (($out | Select-Object -Last 2) -join ' '))
            $failed += $part
            break
        }
    }
    if ($failed.Count) { break }
}

Write-Host "`nflashed=$count  failed=$($failed -join ',')"
if ($failed.Count) {
    Write-Warning 'Stopped early. Fix the problem and re-run; nothing was rebooted.'
} else {
    Write-Host 'All good. Now: fastboot reboot'
}
