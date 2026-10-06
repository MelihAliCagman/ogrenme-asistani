# Registers (or replaces) the daily content-generation task for the current
# Windows user. No administrator rights needed.
#
#   powershell -File scripts\install_daily_task.ps1            # install
#   powershell -File scripts\install_daily_task.ps1 -Remove    # uninstall
#
# Runs scripts\daily_generate.ps1 every day at 03:30 local time (the free
# Gemini quota resets at 00:00 UTC = 03:00 in Turkey). If the computer was off
# at that time, the task starts as soon as the computer is available again
# (StartWhenAvailable). It does not wake a sleeping computer.

param([switch]$Remove)

$name = 'OgrenmeAsistani-GunlukIcerik'

if ($Remove) {
    Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Görev kaldırıldı: $name"
    exit 0
}

$script = Join-Path $PSScriptRoot 'daily_generate.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At '03:30'
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 8)

Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger `
    -Settings $settings -Description 'Öğrenme Asistanı: günlük Gemini kotasıyla YKS içeriği üretir (seed/push yapmaz).' `
    -Force | Out-Null
Write-Host "Görev kuruldu: $name (her gün 03:30, kaçırılırsa bilgisayar açılınca)"
