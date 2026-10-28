# backup.ps1 — Stage A: full EDL backup (everything except userdata).
#
#   .\backup.ps1 -Out D:\edl-backup
#   .\backup.ps1 -Out D:\edl-backup -Mirror E:\safe-copy
#
# Requires the tablet in EDL mode with the WinUSB driver bound (see GUIDE §2).

param(
    [string]$Out    = ".\backup-$(Get-Date -Format yyyyMMdd)",
    [string]$Mirror = ''
)

. "$PSScriptRoot\edl-env.ps1"

if (-not (Wait-Edl 30)) { throw 'No Qualcomm 9008 device found. Is the tablet in EDL?' }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

Write-Host "`n=== 1/4 read every partition except userdata ==="
Invoke-Edl rl $Out --memory=ufs --loader=$Loader --skip=userdata
if ($LASTEXITCODE -ne 0) { throw 'rl failed — check the tablet state before continuing' }

Write-Host "`n=== 2/4 explicit abl + oeminfo copies ==="
$abl  = Join-Path $Out 'abl.img'
$oem  = Join-Path $Out 'oeminfo.img'
Invoke-Edl r abl     $abl --memory=ufs --lun=4 --loader=$Loader
Invoke-Edl r oeminfo $oem --memory=ufs --lun=0 --loader=$Loader

Write-Host "`n=== 3/4 raw GPT of every LUN (34 sectors each) ==="
foreach ($lun in 0..5) {
    Invoke-Edl rs 0 34 (Join-Path $Out "gpt_lun$lun.bin") --memory=ufs --lun=$lun --loader=$Loader
}

Write-Host "`n=== 4/4 verify ==="
$files = Get-ChildItem $Out -Recurse -File
$zero  = $files | Where-Object Length -eq 0
Write-Host ("files={0}  total={1:N2} GB" -f $files.Count, (($files | Measure-Object Length -Sum).Sum / 1GB))
if ($zero) { Write-Warning ("zero-byte files: " + (($zero | ForEach-Object Name) -join ', ')) }

# abl.bin may live in lun4\ (rl writes one folder per LUN) or at the root
$ablFile = @($abl, (Join-Path $Out 'lun4\abl.bin')) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ablFile) {
    $len = (Get-Item $ablFile).Length
    $hdr = (Get-Content $ablFile -AsByteStream -TotalCount 4 | ForEach-Object { $_.ToString('X2') }) -join ' '
    Write-Host "abl  : $ablFile  $len bytes  header=$hdr"
    if ($len -ne 4194304 -or $hdr -ne '7F 45 4C 46') {
        Write-Warning 'abl.bin does not look like a 4 MiB ELF — do NOT flash anything before investigating'
    }
}
$bootFile = @((Join-Path $Out 'boot.img'), (Join-Path $Out 'lun4\boot.bin')) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($bootFile) {
    $hdr = -join ((Get-Content $bootFile -AsByteStream -TotalCount 8) | ForEach-Object { [char]$_ })
    Write-Host "boot : $bootFile  header=$hdr"
}
if (Test-Path $oem) { Write-Host "oeminfo: $oem  $((Get-Item $oem).Length) bytes" }

if ($Mirror) {
    Write-Host "`n=== mirroring critical files to $Mirror ==="
    New-Item -ItemType Directory -Force -Path $Mirror | Out-Null
    $keep = @('abl.bin', 'abl.img', 'oeminfo.bin', 'oeminfo.img', 'persist.bin', 'nvme.bin',
              'misc.bin', 'fsg.bin', 'fsc.bin', 'modemst1.bin', 'modemst2.bin',
              'xbl.bin', 'xbl_config.bin', 'cdt.bin', 'ddr.bin')
    foreach ($f in (Get-ChildItem $Out -Recurse -File | Where-Object { $keep -contains $_.Name })) {
        Copy-Item $f.FullName (Join-Path $Mirror $f.Name) -Force
    }
    Get-ChildItem $Out -Filter 'gpt_lun*.bin' | ForEach-Object { Copy-Item $_.FullName $Mirror -Force }
    Write-Host 'mirror done'
}

Write-Host "`nBackup finished: $((Resolve-Path $Out).Path)"
