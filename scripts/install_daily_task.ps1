# Registers (or replaces) the daily content-generation task for the current
# Windows user. No administrator rights needed.
#
#   powershell -File scripts\install_daily_task.ps1            # install
#   powershell -File scripts\install_daily_task.ps1 -Remove    # uninstall
#
# Runs scripts\daily_generate.ps1 every day at 11:15 local time (the free
# Gemini daily quota resets at midnight Pacific time = 10:00 in Turkey during US daylight saving time, 11:00 otherwise). If the computer was off
# at that time, the task starts as soon as the computer is available again
# (StartWhenAvailable). It does not wake a sleeping computer.

param([switch]$Remove)

$name = 'OgrenmeAsistani-GunlukIcerik'

if ($Remove) {
    Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Görev kaldırıldı: $name"
    exit 0
}

$launcher = Join-Path $PSScriptRoot 'daily_generate_hidden.vbs'
# wscript + a .vbs launcher runs the job with no window at all.
$action = New-ScheduledTaskAction -Execute 'wscript.exe' `
    -Argument "//B //Nologo `"$launcher`""
$trigger = New-ScheduledTaskTrigger -Daily -At '11:15'
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 8)

Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger `
    -Settings $settings -Description 'Öğrenme Asistanı: günlük Gemini kotasıyla YKS içeriği üretir (seed/push yapmaz).' `
    -Force | Out-Null
Write-Host "Görev kuruldu: $name (her gün 11:15, kaçırılırsa bilgisayar açılınca)"
