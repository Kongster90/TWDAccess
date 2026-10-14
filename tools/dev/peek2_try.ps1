<#
  Development helper: from the death screen, reload, wait for the hiding cue, start watch_peek2.lua
  and press the given keys in turn (one second apart), then print WP lines and speech.
    .\peek2_try.ps1 -Keys D
#>
param([string[]]$Keys = @("D"), [int]$AfterMs = 12000, [switch]$NoReload)
$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$n0 = (Get-Content $log).Count
if (-not $NoReload) {
  & "$dev\game_input.ps1" -Keys Enter | Out-Null
  $end = (Get-Date).AddSeconds(90)
  while ((Get-Date) -lt $end) {
    & "$dev\game_input.ps1" -Focus | Out-Null
    if ((Get-Content $log | Select-Object -Skip $n0) -match "To lean out") { break }
    Start-Sleep -Milliseconds 300
  }
}
Invoke-WebRequest -UseBasicParsing -Method Post -Body ("PEEK2_SECONDS = 25`n" + (Get-Content -Raw "$dev\watch_peek2.lua")) http://127.0.0.1:41234/enqueue | Out-Null
foreach ($k in $Keys) { & "$dev\game_input.ps1" -Keys $k -DelayMs 1000 | Out-Null }
$end = (Get-Date).AddMilliseconds($AfterMs)
while ((Get-Date) -lt $end) { & "$dev\game_input.ps1" -Focus | Out-Null; Start-Sleep -Milliseconds 500 }
Get-Content $log | Select-Object -Skip $n0 | Where-Object { $_ -match "WP t|say|struggle|peek" -and $_ -notmatch "console>|TWDA.log" } | ForEach-Object { $_.Substring(9) }
