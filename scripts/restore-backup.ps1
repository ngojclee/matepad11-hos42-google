# restore-backup.ps1 — rollback: write every backed-up partition back over fastboot.
#
#   .\restore-backup.ps1 -Backup D:\edl-backup
#   .\restore-backup.ps1 -Backup D:\edl-backup -Relock
#
# Flashes lun0 / lun1 / lun4 from the backup. By default it keeps the unlocked ABL
# (pass -Relock to restore the original, locked bootloader as well).

param(
    [Parameter(Mandatory = $true)][string]$Backup,
    [switch]$Relock
)

. "$PSScriptRoot\edl-env.ps1"

if (-not (Test-Path $Backup)) { throw "backup not found: $Backup" }
if (-not (Wait-Fastboot 20)) { throw 'No fastboot device.' }

$userspace = (& $Fastboot getvar is-userspace 2>&1 | Select-Object -First 1)
if ($userspace -notmatch 'no') { throw 'Refusing to flash from fastbootd.' }

$skip = @('abl_after_write', 'gpt_lun0', 'gpt_lun1', 'gpt_lun2', 'gpt_lun3', 'gpt_lun4', 'gpt_lun5',
          'gpt_main0', 'gpt_main1', 'gpt_main2', 'gpt_main3', 'gpt_main4', 'gpt_main5',
          'gpt_backup0', 'gpt_backup1', 'gpt_backup2', 'gpt_backup3', 'gpt_backup4', 'gpt_backup5')
if (-not $Relock) { $skip += 'abl' }

$failed = @()
foreach ($lun in 0, 1, 4) {
    $dir = Join-Path $Backup "lun$lun"
    if (-not (Test-Path $dir)) { continue }
    $files = Get-ChildItem $dir -Filter *.bin | Where-Object { $skip -notcontains $_.BaseName } | Sort-Object Length
    Write-Host "`n===== LUN $lun : $($files.Count) partitions ====="
    foreach ($f in $files) {
        $part = $f.BaseName
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $out = & $Fastboot flash $part $f.FullName 2>&1
        if ($out -match 'OKAY|Finished') {
            Write-Host ("OK   {0,-20} {1,8:N1} MB {2,7:N1}s" -f $part, ($f.Length / 1MB), $sw.Elapsed.TotalSeconds)
        } else {
            Write-Warning ("FAIL {0} :: {1}" -f $part, (($out | Select-Object -Last 2) -join ' '))
            $failed += $part
        }
    }
}

Write-Host "`nfailed=$($failed -join ',')"
Write-Host 'userdata was erased during the process — Android will re-create it on first boot.'
Write-Host 'When ready: fastboot reboot'
