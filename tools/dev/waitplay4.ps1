<#
  Development helper (The Final Season): keep the game focused while a background react4.ps1 plays,
  and stop when the player has to explore (something offered, "can move", a close-up) or dies; then
  print the recent log lines without the noise (watch positions, console echoes, speaker names).
    .\waitplay4.ps1 [-Seconds 240] [-Lines 40]
#>
param([int]$Seconds = 240, [int]$Lines = 40, [string]$Until = 'can move|dead\.|Enter to do it|Tab to choose|Close-up|Nothing to interact')
$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$start = (Get-Content $log).Count
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    & "$dev\game_input.ps1" -Focus | Out-Null
    $new = Get-Content $log | Select-Object -Skip $start
    if (($new | Select-Object -Last 3) -match $Until) { break }
    Start-Sleep -Milliseconds 800
}
Get-Content $log | Select-Object -Skip ([Math]::Max(0, $start - 3)) |
    Where-Object { $_ -match '^\d\d:\d\d:\d\d' -and $_ -notmatch 'WB pos|console>|^\S+\s+\S+ say [A-Z][\w ]*$' } |
    Select-Object -Last $Lines | ForEach-Object { $_.Substring(0, [Math]::Min(220, $_.Length)) }
