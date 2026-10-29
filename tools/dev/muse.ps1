<#
  Development helper (Michonne): use each named thing in turn ("Name" or "Name#2" for action 2) with
  use2.ps1 -NoFollow, letting the background react4.ps1 play after each until the player is needed
  again (mplay.ps1). Stops at a thing it cannot find.
    .\muse.ps1 -Names "Prow#2","Snapped Rigging" [-Seconds 120]
#>
param([string[]]$Names, [int]$Seconds = 120, [int]$Lines = 12)
$dev = $PSScriptRoot
foreach ($entry in $Names) {
    $name, $action = $entry -split "#", 2
    $r = & "$dev\use2.ps1" -Name $name -Action ([int]("0" + $action)) -NoFollow
    $r | Select-Object -Last 2
    if ($r -match "never found") { break }
    & "$dev\mplay.ps1" -Seconds $Seconds -Lines $Lines
}
