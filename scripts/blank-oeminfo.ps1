# blank-oeminfo.ps1 — Stage B: erase the global region identity.
#
#   .\blank-oeminfo.ps1 -Image .\blank_oeminfo.img
#
# This makes the device region-neutral so the Chinese dload package is accepted.
# The original image is in your EDL backup (oeminfo.bin) and can be written back at any time.

param(
    [string]$Image = '.\blank_oeminfo.img',
    [switch]$SkipVerify
)

. "$PSScriptRoot\edl-env.ps1"
Assert-File $Image

$size = (Get-Item $Image).Length
Write-Host "blank image : $Image  $size bytes  sha256=$(Get-Sha256 $Image)"
if ($size -ne 100663296) {
    Write-Warning "oeminfo on this model is 104857600 bytes... got $size. Double-check the file."
}

if (-not (Wait-Edl 30)) { throw 'No 9008 device. Boot the tablet into EDL first (adb reboot edl).' }

Write-Host "`n=== writing oeminfo ==="
Invoke-Edl w oeminfo $Image --memory=ufs --lun=0 --loader=$Loader
if ($LASTEXITCODE -ne 0) { throw 'write failed' }

if (-not $SkipVerify) {
    Write-Host "`n=== read-back verification ==="
    $tmp = Join-Path $env:TEMP 'oeminfo_verify.bin'
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Invoke-Edl r oeminfo $tmp --memory=ufs --lun=0 --loader=$Loader
    if (-not (Test-Path $tmp)) { throw 'read-back produced no file' }

    $src = Get-Sha256 $Image
    $buf = New-Object byte[] $size
    $fs  = [System.IO.File]::OpenRead($tmp)
    try { [void]$fs.Read($buf, 0, $size) } finally { $fs.Dispose() }
    $head = Join-Path $env:TEMP 'oeminfo_head.bin'
    [System.IO.File]::WriteAllBytes($head, $buf)
    $got = Get-Sha256 $head
    Write-Host "src=$src"
    Write-Host "got=$got"
    if ($src -ne $got) { throw 'VERIFY FAILED — oeminfo was not written correctly' }
    Write-Host '*** oeminfo blank OK ***'
}

Write-Host "`n=== powering off (hold Power+VolUp afterwards to enter Recovery) ==="
Invoke-Edl reset --resetmode=poweroff --loader=$Loader
