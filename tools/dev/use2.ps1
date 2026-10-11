<#
  Development helper (Season 2): Tab until the mod names a thing, press its action number (if given)
  and Enter, then follow until something else needs the player.
    .\use2.ps1 -Name "Trash Barrel" -Action 2
#>
param([string]$Name, [int]$Action = 0, [int]$MaxTabs = 20, [int]$Seconds = 60)

$dev = $PSScriptRoot
$speech = Join-Path $dev "..\..\dist\TWDAccess\logs\speech.log"
$found = $false
for ($i = 0; $i -lt $MaxTabs; $i++) {
    $before = (Get-Content $speech).Count
    & "$dev\game_input.ps1" -Focus | Out-Null
    & "$dev\game_input.ps1" -Keys Tab | Out-Null
    Start-Sleep -Milliseconds 700
    $said = (Get-Content $speech | Select-Object -Skip $before) -join " "
    # (Whole names only: "Door 1" is not "Bedroom Door 1".)
    if ($said -match ("\] (Place: )?" + [regex]::Escape($Name) + "[:,]")) { $found = $true; "found: $said"; break }
}
if (-not $found) { "never found $Name"; exit 1 }
if ($Action -gt 0) { & "$dev\game_input.ps1" -Keys "$Action" | Out-Null; Start-Sleep -Milliseconds 300 }
& "$dev\game_input.ps1" -Keys Enter | Out-Null
& "$dev\follow.ps1" -Seconds $Seconds -Quiet 15 -Stop "say! Choices|can move|Enter to do it|Enter!|Struggle|You are dead|arrow!"
