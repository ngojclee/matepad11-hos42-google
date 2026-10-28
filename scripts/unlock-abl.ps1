# unlock-abl.ps1 — Stage D: write the unlocked ABL into the abl partition (LUN 4).
#
#   .\unlock-abl.ps1 -Abl .\firmware\abl_hw865870unlock.elf
#
# The dload step writes a stock ABL and relocks the bootloader. Run this afterwards,
# then `fastboot getvar unlocked` must print "yes".
#
# The original abl is in the backup (lun4\abl.bin) if you ever need to go back.

param(
    [string]$Abl = '.\firmware\abl_hw865870unlock.elf'
)

. "$PSScriptRoot\edl-env.ps1"
Assert-File $Abl

$expected = '552E96D2565627563B7F2B072F720EFD048ABDF11FA050959AEC55E7D3F0B79D'
$sha = Get-Sha256 $Abl
Write-Host "unlock ABL : $Abl  $((Get-Item $Abl).Length) bytes"
Write-Host "sha256     : $sha"
if ($sha -ne $expected) {
    throw "hash mismatch — expected $expected. Refusing to write an unknown bootloader."
}

if (-not (Wait-Edl 30)) { throw 'No 9008 device. Boot the tablet into EDL first.' }

Write-Host "`n=== saving the current ABL for safety ==="
$before = Join-Path $env:TEMP 'abl_before.bin'
Invoke-Edl r abl $before --memory=ufs --lun=4 --loader=$Loader

Write-Host "`n=== writing the unlocked ABL (LUN 4) ==="
Invoke-Edl w abl $Abl --memory=ufs --lun=4 --loader=$Loader
if ($LASTEXITCODE -ne 0) { throw 'write failed' }

Write-Host "`n=== read-back verification ==="
$after = Join-Path $env:TEMP 'abl_after.bin'
Remove-Item $after -Force -ErrorAction SilentlyContinue
Invoke-Edl r abl $after --memory=ufs --lun=4 --loader=$Loader

$len = (Get-Item $Abl).Length
$buf = New-Object byte[] $len
$fs  = [System.IO.File]::OpenRead($after)
try { [void]$fs.Read($buf, 0, $len) } finally { $fs.Dispose() }
$head = Join-Path $env:TEMP 'abl_head.bin'
[System.IO.File]::WriteAllBytes($head, $buf)
if ((Get-Sha256 $head) -ne $sha) { throw 'VERIFY FAILED — ABL not written correctly' }
Write-Host '*** unlock ABL OK ***'

Write-Host "`n=== rebooting to the system ==="
Invoke-Edl reset --resetmode=reset --loader=$Loader
Start-Sleep -Seconds 45
& $Adb wait-for-device 2>$null
$locked = & $Adb shell getprop ro.boot.flash.locked 2>$null
Write-Host "ro.boot.flash.locked = $locked   (0 = unlocked)"
