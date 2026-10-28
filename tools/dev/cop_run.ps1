<#
  Development helper: the zombie cop (Season 1 Episode 1) from slot 2's episode screen or its death
  screen, up to the shotgun aiming. Presses Enter (Continue, or reload on the death screen), arms
  cop_setup.lua and any -Watch scripts once the mod is up, holds S on "Use the S (back) key", then
  keeps the game focused for -Seconds and prints the log lines matching -Filter.
    .\cop_run.ps1 -Watch probe_shotgun.lua -Seconds 60 -Filter "PS |CS |aiming"
#>
param([string[]]$Watch = @(), [int]$Seconds = 60, [string]$Filter = "CS |aiming|say", [switch]$NoEnter,
      [string[]]$Keys = @())
$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$n0 = (Get-Content $log).Count
function NewLines { Get-Content $log | Select-Object -Skip $n0 }
if (-not $NoEnter) { & "$dev\game_input.ps1" -Focus | Out-Null; & "$dev\game_input.ps1" -Keys Enter | Out-Null }
$end = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $end -and -not ((NewLines) -match "choices: attached")) {
    & "$dev\game_input.ps1" -Focus | Out-Null; Start-Sleep -Milliseconds 300
}
foreach ($w in @("cop_setup.lua") + $Watch) { & "$dev\console.ps1" -File (Join-Path $dev $w) | Out-Null }
$end = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $end -and -not ((NewLines) -match "S \(back\) key")) {
    & "$dev\game_input.ps1" -Focus | Out-Null; Start-Sleep -Milliseconds 200
}
& "$dev\holdkey.ps1" -Key S -Ms 7000 | Out-Null
& "$dev\console.ps1" "DEV_COP_GO = true" | Out-Null
foreach ($k in $Keys) { & "$dev\game_input.ps1" -Keys $k | Out-Null }
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    & "$dev\game_input.ps1" -Focus | Out-Null
    if ((NewLines | Select-Object -Last 3) -match "You are dead") { break }
    Start-Sleep -Milliseconds 500
}
NewLines | Where-Object { $_ -match $Filter } | ForEach-Object { $_.Substring(0, [Math]::Min(240, $_.Length)) }
