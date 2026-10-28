# download.ps1 — fetch the HarmonyOS 4.2 China packages + the Google stack, verify hashes.
#
#   .\download.ps1                 # into .\downloads
#   .\download.ps1 -Out D:\files -Jobs 8
#
# Huawei's CDN throttles a single long transfer after ~1 GB but serves fresh connections fast,
# so big files are pulled as 64 MiB ranges, six at a time.

param(
    [string]$Out  = ".\downloads",
    [int]$ChunkMB = 64,
    [int]$Jobs    = 6
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$curl = 'curl.exe'

$base = 'http://update.dbankcdn.com/download/data/pub_13/HWHOTA_hota_900_9'
$files = @(
    @{ n = 'update_full_base.zip'
       u = "$base/77/v3/v9yZI3GeRSCCVYPPG7T_5A/full/update_full_base.zip"
       h = '65C6039F24F9BA9C040E1BA9CF050E1720BF37F9AB293DE7B16E7D004BC02213' },
    @{ n = 'update_full_cust_DBY-W09_all_cn.zip'
       u = "$base/9b/v3/EcY-XW4RTNOY1DrkyHKRqw/full/update_full_cust_DBY-W09_all_cn.zip"
       h = '4D5C9D48942C92161776DCD6B2A82CC623BC7C5720AA9E5E23A1A5F05C6554C9' },
    @{ n = 'update_full_preload_DBY-W09_all_cn_R1.zip'
       u = "$base/94/v3/Wbkd1I4_SWOtYB4jX0ycDg/full/update_full_preload_DBY-W09_all_cn_R1.zip"
       h = '4C1A00658798D2EE5670FC6A7EF3E03C2AD5A380CA7CFF18A1B06DD9C409B17E' },
    @{ n = 'com.google.android.gms-252432034-hw.apk'
       u = 'https://github.com/microG/GmsCore/releases/download/v0.3.17.252432/com.google.android.gms-252432034-hw.apk'
       h = '' },
    @{ n = 'com.android.vending-84022634-hw.apk'
       u = 'https://github.com/microG/GmsCore/releases/download/v0.3.17.252432/com.android.vending-84022634-hw.apk'
       h = '' },
    @{ n = 'com.aurora.store_76.apk'
       u = 'https://f-droid.org/repo/com.aurora.store_76.apk'
       h = '' }
)

function Get-RemoteSize([string]$Url) {
    $probe = & $curl -sS -r 0-0 -D - -o NUL --max-time 40 $Url 2>&1
    $cr = ($probe | Select-String -Pattern 'Content-Range:\s*bytes\s+0-0/(\d+)').Matches
    if ($cr) { return [int64]$cr[0].Groups[1].Value }
    $cl = ($probe | Select-String -Pattern 'Content-Length:\s*(\d+)' | Select-Object -Last 1).Matches
    if ($cl) { return [int64]$cl[0].Groups[1].Value }
    return 0
}

function Get-Parallel([string]$Url, [string]$Dest, [int64]$Total, [int]$ChunkMB, [int]$Jobs) {
    $chunk = [int64]$ChunkMB * 1MB
    $n = [int][math]::Ceiling($Total / $chunk)
    $partDir = "$Dest.parts"
    New-Item -ItemType Directory -Force -Path $partDir | Out-Null
    $jobs = @{}
    for ($i = 0; $i -lt $n; $i++) {
        $name = Join-Path $partDir ('part_{0:d4}' -f $i)
        $start = $i * $chunk
        $end = [math]::Min($start + $chunk - 1, $Total - 1)
        $want = $end - $start + 1
        if ((Test-Path $name) -and ((Get-Item $name).Length -eq $want)) { continue }
        while (($jobs.Keys | Where-Object { -not $jobs[$_].HasExited }).Count -ge $Jobs) { Start-Sleep -Milliseconds 400 }
        $argStr = '-sS -L --fail --retry 3 --retry-delay 2 -r "{0}-{1}" -o "{2}" "{3}"' -f $start, $end, $name, $Url
        $jobs[$i] = Start-Process -FilePath $curl -ArgumentList $argStr -WindowStyle Hidden -PassThru
    }
    foreach ($k in $jobs.Keys) { $jobs[$k].WaitForExit() }

    if (Test-Path $Dest) { Remove-Item $Dest -Force }
    $out = [System.IO.File]::Create($Dest)
    $buf = New-Object byte[] (4 * 1MB)
    for ($i = 0; $i -lt $n; $i++) {
        $name = Join-Path $partDir ('part_{0:d4}' -f $i)
        $in = [System.IO.File]::OpenRead($name)
        try { while (($r = $in.Read($buf, 0, $buf.Length)) -gt 0) { $out.Write($buf, 0, $r) } }
        finally { $in.Dispose() }
    }
    $out.Dispose()
    Remove-Item $partDir -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($f in $files) {
    $dest = Join-Path $Out $f.n
    if ((Test-Path $dest) -and $f.h -and ((Get-FileHash $dest -Algorithm SHA256).Hash -eq $f.h)) {
        Write-Host "SKIP $($f.n) (already verified)"
        continue
    }
    Write-Host "`n=== $($f.n) ==="
    $size = Get-RemoteSize $f.u
    if ($size -le 0) { Write-Warning "cannot determine size for $($f.u)"; continue }
    if ($size -gt 200MB -and $f.n -like 'update_full_*') {
        Get-Parallel -Url $f.u -Dest $dest -Total $size -ChunkMB $ChunkMB -Jobs $Jobs
    } else {
        & $curl -sS -L --fail --retry 5 --retry-delay 3 -o $dest $f.u
    }
    if (-not (Test-Path $dest)) { Write-Warning "download failed: $($f.n)"; continue }
    $got = (Get-FileHash $dest -Algorithm SHA256).Hash
    if ($f.h) {
        if ($got -eq $f.h) { Write-Host "OK   $($f.n)  sha256 matches" }
        else { Write-Warning "MISMATCH $($f.n)`n  got  $got`n  want $($f.h)" }
    } else {
        Write-Host "OK   $($f.n)  sha256 $got"
    }
}

Write-Host "`nDone. Contents of ${Out}:"
Get-ChildItem $Out | Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } | Format-Table -AutoSize
