<#
  Development helper: from the hub main menu (where restart.ps1 leaves the game), open Season 1 and
  load save slot 2 (the agent's test slot) up to its episode screen. With -Play it also presses
  Enter there (Continue). Copy the wanted dev_saves\<name>\* into the save folder with the game
  closed first: the game caches the slots, and swapping files under it made a load hang.
    .\restart.ps1; .\load_slot2.ps1 -Play
#>
param([switch]$Play)

$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"

function Said([string]$pattern, [int]$timeoutS) {
    $end = (Get-Date).AddSeconds($timeoutS)
    while ((Get-Date) -lt $end) {
        & "$dev\game_input.ps1" -Focus | Out-Null
        if ((Get-Content $log -Tail 3) -match $pattern) { return $true }
        Start-Sleep -Milliseconds 700
    }
    return $false
}

& "$dev\step.ps1" -Lua 'Menu_Seasons()' -SettleMs 3000 | Out-Null
& "$dev\step.ps1" -Lua 'Menu_Seasons_Play(1)' -SettleMs 2000 | Out-Null
if (-not (Said "say! Main menu\. Up and down" 40)) { "Season 1 menu not reached"; exit 1 }
& "$dev\step.ps1" -Keys Down -SettleMs 800 | Out-Null
& "$dev\step.ps1" -Keys Enter -SettleMs 500 | Out-Null
if (-not (Said "Save Slots menu" 15)) { "Save Slots not reached"; exit 1 }
& "$dev\step.ps1" -Keys Down -SettleMs 800 | Out-Null
& "$dev\step.ps1" -Keys Down -SettleMs 800 | Out-Null
if (-not ((Get-Content $log -Tail 2) -match "say! Game 2")) { "Game 2 not selected"; exit 1 }
& "$dev\step.ps1" -Keys Enter -SettleMs 500 | Out-Null
if (-not (Said "(Continue|Play)\. Left and right" 15)) { "Episode screen not reached"; exit 1 }
"at the episode screen"
if ($Play) {
    Start-Sleep -Milliseconds 1500
    & "$dev\step.ps1" -Keys Enter -SettleMs 500 | Out-Null
    "pressed Continue"
}
