# Daily content generation, started by the Windows scheduled task
# "OgrenmeAsistani-GunlukIcerik" (see scripts/install_daily_task.ps1), through
# scripts/daily_generate_hidden.vbs so no console window pops up.
#
# Runs tool/generate_lite_content.dart until the free daily Gemini quota ends
# (it stops by itself) or every konu has content. It ONLY generates: it never
# seeds Firestore and never pushes to GitHub — those stay manual, with a
# review of the new content first.
#
# Manual run / test:  powershell -File scripts\daily_generate.ps1 --dry-run

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# Dart prints UTF-8; without this PowerShell decodes it as the OEM code page
# and Turkish letters turn into garbage.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$logDir = Join-Path $repo 'tool\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("daily_generate_{0:yyyy-MM-dd}.log" -f (Get-Date))

function Write-Log([string]$line) {
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding UTF8
}

# The task runs without the interactive PATH, so use the Flutter SDK's Dart.
$dart = 'C:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe'
if (-not (Test-Path $dart)) { $dart = 'dart' }

Write-Log ("=== {0:yyyy-MM-dd HH:mm:ss} basladi ===" -f (Get-Date))

# Run through cmd so Dart's stderr (retry notes, quota waits) arrives as plain
# text; PowerShell would otherwise wrap each stderr line in a red error record.
$extra = ($args | ForEach-Object { "`"$_`"" }) -join ' '
cmd /c "`"$dart`" run tool/generate_lite_content.dart $extra 2>&1" | ForEach-Object { Write-Log $_ }

Write-Log ("=== {0:yyyy-MM-dd HH:mm:ss} bitti (cikis kodu: $LASTEXITCODE) ===" -f (Get-Date))
