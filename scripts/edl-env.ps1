# edl-env.ps1 — shared environment for every script in this folder.
# Dot-source it:   . "$PSScriptRoot\edl-env.ps1"
#
# Override anything with environment variables before running:
#   $env:EDL_DIR    folder that contains edl.py          (default: <repo>\edl)
#   $env:EDL_LOADER path to dbyprog_emmc_firehose        (default: <repo>\firmware\dbyprog_emmc_firehose)
#   $env:PYTHON_BIN python executable                    (default: python)

$ErrorActionPreference = 'Continue'

$RepoRoot  = Split-Path $PSScriptRoot -Parent
$EdlDir    = if ($env:EDL_DIR)    { $env:EDL_DIR }    else { Join-Path $RepoRoot 'edl' }
$Loader    = if ($env:EDL_LOADER) { $env:EDL_LOADER } else { Join-Path $RepoRoot 'firmware\dbyprog_emmc_firehose' }
$Python    = if ($env:PYTHON_BIN) { $env:PYTHON_BIN } else { 'python' }
$Adb       = 'adb'
$Fastboot  = 'fastboot'

# edl's progress bar prints U+2588 and dies on cp1252 — this is not optional
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'

function Invoke-Edl {
    param([Parameter(ValueFromRemainingArguments = $true)] $Args_)
    & $Python (Join-Path $EdlDir 'edl.py') @Args_
}

function Assert-File([string]$Path) {
    if (-not (Test-Path $Path)) { throw "missing file: $Path" }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Wait-Edl([int]$Seconds = 40) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        $d = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
             Where-Object { $_.InstanceId -match 'VID_05C6' }
        if ($d) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Wait-Fastboot([int]$Seconds = 60) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Fastboot devices 2>$null) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

Write-Host "repo    : $RepoRoot"
Write-Host "edl dir : $EdlDir"
Write-Host "loader  : $Loader"
