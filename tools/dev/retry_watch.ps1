<#
  Development helper: on the death screen (or any reload), press Enter, wait for the mod to start
  in the new Lua state, then run a dev console file at once (a watcher such as watch_s2.lua).
    .\retry_watch.ps1 -File watch_s2.lua
#>
param([string]$File = "watch_s2.lua", [string]$Key = "Enter", [int]$TimeoutS = 30)

$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$n0 = (Get-Content $log).Count
& "$dev\game_input.ps1" -Focus | Out-Null
if ($Key) { & "$dev\game_input.ps1" -Keys $Key | Out-Null }
$end = (Get-Date).AddSeconds($TimeoutS)
while ((Get-Date) -lt $end) {
    & "$dev\game_input.ps1" -Focus | Out-Null
    $new = Get-Content $log | Select-Object -Skip $n0
    if ($new -match "choices: attached") { break }
    Start-Sleep -Milliseconds 100
}
$code = "TWDA.safeInclude('devtools')`n" + (Get-Content -Raw (Join-Path $dev $File))
Invoke-WebRequest -UseBasicParsing -Method Post -Body $code http://127.0.0.1:41234/enqueue | Out-Null
"watcher sent"
