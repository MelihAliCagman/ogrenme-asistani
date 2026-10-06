# Daily content generation, started by the Windows scheduled task
# "OgrenmeAsistani-GunlukIcerik" (see scripts/install_daily_task.ps1).
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

$logDir = Join-Path $repo 'tool\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("daily_generate_{0:yyyy-MM-dd}.log" -f (Get-Date))

# The task runs without the interactive PATH, so use the Flutter SDK's Dart.
$dart = 'C:\dev\flutter\bin\cache\dart-sdk\bin\dart.exe'
if (-not (Test-Path $dart)) { $dart = 'dart' }

"=== {0:yyyy-MM-dd HH:mm:ss} basladi ===" -f (Get-Date) | Tee-Object -FilePath $log -Append
& $dart run tool/generate_lite_content.dart @args 2>&1 | Tee-Object -FilePath $log -Append
"=== {0:yyyy-MM-dd HH:mm:ss} bitti (cikis kodu: $LASTEXITCODE) ===" -f (Get-Date) | Tee-Object -FilePath $log -Append
