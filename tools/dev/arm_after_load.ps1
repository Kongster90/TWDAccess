<#
  Development helper: press a key (Enter: Play, Continue, or reload on the death screen), wait until
  the mod is up in the new state ("choices: attached"), then run the given Lua files in the console.
    .\arm_after_load.ps1 -Files probe_scope.lua
#>
param([string[]]$Files = @(), [string]$Key = "Enter", [int]$Seconds = 90)
$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$n0 = (Get-Content $log).Count
if ($Key) { & "$dev\game_input.ps1" -Focus | Out-Null; & "$dev\game_input.ps1" -Keys $Key | Out-Null }
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end -and -not ((Get-Content $log | Select-Object -Skip $n0) -match "choices: attached")) {
    & "$dev\game_input.ps1" -Focus | Out-Null; Start-Sleep -Milliseconds 300
}
foreach ($f in $Files) { & "$dev\console.ps1" -File (Join-Path $dev $f) | Select-Object -Last 1 }
