<#
  Development helper: from the hub's main menu, open Season Select, move to season N (1 to 4,
  Right arrow N-1 times) and press Enter. With -FromSeason2 it first leaves Season 2's own menu
  (Definitive Menu, then Accept) and waits for the hub.
    .\to_season.ps1 -Season 2
    .\to_season.ps1 -Season 2 -FromSeason2     # reload Season 2's menu (new mod files)
    .\to_season.ps1 -Season 3 -FromSeason3     # the same from A New Frontier's main menu
  The carousel order is Season 1, Season 2, A New Frontier (3), The Final Season (4), Michonne (5).
#>
param([int]$Season = 2, [switch]$FromSeason2, [switch]$FromSeason3)

$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"

function WaitFor([string]$pattern, [int]$timeoutS) {
    $end = (Get-Date).AddSeconds($timeoutS)
    while ((Get-Date) -lt $end) {
        & "$dev\game_input.ps1" -Focus | Out-Null
        if ((Get-Content $log -Tail 3) -match $pattern) { return $true }
        Start-Sleep -Milliseconds 700
    }
    return $false
}

if ($FromSeason2) {
    & "$dev\goto.ps1" -Target "Definitive Menu" | Out-Null
    & "$dev\step.ps1" -Keys Enter -SettleMs 2500 | Out-Null
    & "$dev\goto.ps1" -Target "Accept" -Key Up | Out-Null
    & "$dev\step.ps1" -Keys Enter -SettleMs 1500 | Out-Null
    if (-not (WaitFor "say! Main menu" 60)) { "hub not reached"; exit 1 }
    Start-Sleep 3
}
if ($FromSeason3) {
    & "$dev\goto.ps1" -Target "Definitive Menu" | Out-Null
    & "$dev\step.ps1" -Keys Enter -SettleMs 2500 | Out-Null
    & "$dev\goto.ps1" -Target "OK" | Out-Null
    & "$dev\step.ps1" -Keys Enter -SettleMs 1500 | Out-Null
    if (-not (WaitFor "say! Main menu" 60)) { "hub not reached"; exit 1 }
    Start-Sleep 3
}
& "$dev\step.ps1" -Lua 'Menu_Seasons()' -SettleMs 3500 | Out-Null
for ($i = 1; $i -lt $Season; $i++) { & "$dev\step.ps1" -Keys Right -SettleMs 2500 | Out-Null }
& "$dev\step.ps1" -Keys Enter -SettleMs 2000 | Out-Null
for ($i = 0; $i -lt 25; $i++) { & "$dev\game_input.ps1" -Focus | Out-Null; Start-Sleep 1 }
Get-Content $log | Select-String " say" | Select-Object -Last 1 | ForEach-Object { $_.Line }
