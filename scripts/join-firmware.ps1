# join-firmware.ps1 — reassemble a file that was split into .partNN pieces and verify its SHA-256.
#
#   .\join-firmware.ps1 -Parts ..\firmware-parts\hotabase -Out .\update_full_base.zip
#   .\join-firmware.ps1 -Parts ..\firmware-parts\dloadbase  -Out .\update_sd_base.zip
#
# The expected hash is the official Huawei one; it is looked up automatically from the file name.

param(
    [Parameter(Mandatory = $true)][string]$Parts,
    [Parameter(Mandatory = $true)][string]$Out
)

$ErrorActionPreference = 'Stop'

$known = @{
    'update_full_base.zip'                       = '65C6039F24F9BA9C040E1BA9CF050E1720BF37F9AB293DE7B16E7D004BC02213'
    'update_full_cust_DBY-W09_all_cn.zip'        = '4D5C9D48942C92161776DCD6B2A82CC623BC7C5720AA9E5E23A1A5F05C6554C9'
    'update_full_preload_DBY-W09_all_cn_R1.zip'  = '4C1A00658798D2EE5670FC6A7EF3E03C2AD5A380CA7CFF18A1B06DD9C409B17E'
    'update_sd_base.zip'                         = 'A27C37D782409DCF30F86E1AE3599E00ACF2E7CA122D1C33F9EE201E59EE4B40'
    'update_sd_cust_DBY-W09_all_cn.zip'          = '3382AC6155D9919F85703CFD4C051007CDE95937480AD7451552360256546B1F'
    'update_sd_preload_DBY-W09_all_cn_R5.zip'    = '832735F4DA7615DE6E2C2D5CE71979282A1C078E9CEE1E561751EF066EB31E48'
}

if (-not (Test-Path $Parts)) { throw "parts folder not found: $Parts" }
$files = Get-ChildItem $Parts -File | Where-Object { $_.Name -match '\.part\d+$' } | Sort-Object Name
if (-not $files) { throw "no .partNN files in $Parts" }

$total = ($files | Measure-Object Length -Sum).Sum
Write-Host "joining $($files.Count) parts, $([math]::Round($total/1GB,2)) GiB -> $Out"
foreach ($f in $files) { Write-Host ("  {0,-56}{1,14:N0}" -f $f.Name, $f.Length) }

$stream = [System.IO.File]::Create($Out)
$buffer = New-Object byte[] (8 * 1MB)
try {
    foreach ($f in $files) {
        $in = [System.IO.File]::OpenRead($f.FullName)
        try {
            while (($read = $in.Read($buffer, 0, $buffer.Length)) -gt 0) { $stream.Write($buffer, 0, $read) }
        } finally { $in.Dispose() }
    }
} finally { $stream.Dispose() }

$size = (Get-Item $Out).Length
Write-Host "`nresult: $Out  $size bytes  ($([math]::Round($size/1GB,2)) GiB)"

$name = Split-Path $Out -Leaf
if ($known.ContainsKey($name)) {
    $want = $known[$name]
    Write-Host "hashing (this takes a minute)..."
    $got = (Get-FileHash $Out -Algorithm SHA256).Hash
    Write-Host "want: $want"
    Write-Host "got : $got"
    if ($got -ne $want) { throw 'SHA-256 MISMATCH — the parts are incomplete or corrupted, download them again' }
    Write-Host '*** hash OK ***'
} else {
    Write-Host "no known hash for $name — verify manually"
}
