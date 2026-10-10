<#
  Development helper: optionally press keys, then keep the game focused and print what the mod says
  (and subtitles, scene changes and saves) until something needs the player: choices, a hint, a
  struggle, the death screen, or the timeout.
    .\follow.ps1 -Keys 1 -Seconds 60
    .\follow.ps1 -Stop "say! Choices|Struggle"
#>
param([string[]]$Keys, [int]$Seconds = 60,
      [string]$Stop = "say! Choices|say! .*(Tab|Enter|key)|You are dead|Struggle|out of view|Nothing chosen",
      [int]$Quiet = 0)

$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$n0 = (Get-Content $log).Count
if ($Keys) { & "$dev\step.ps1" -Keys $Keys -SettleMs 300 | Out-Null }
$end = (Get-Date).AddSeconds($Seconds)
$lastCount = $n0
$lastChange = Get-Date
while ((Get-Date) -lt $end) {
    & "$dev\game_input.ps1" -Focus | Out-Null
    $lines = Get-Content $log
    if ($lines.Count -ne $lastCount) { $lastCount = $lines.Count; $lastChange = Get-Date }
    $new = $lines | Select-Object -Skip $n0
    if ($new -match $Stop) { break }
    # -Quiet N: stop after N seconds without new log lines.
    if ($Quiet -gt 0 -and ((Get-Date) - $lastChange).TotalSeconds -ge $Quiet) { break }
    Start-Sleep -Milliseconds 800
}
Get-Content $log | Select-Object -Skip $n0 |
    Where-Object { $_ -match "say|subtitle|LoadScript|SaveSlots|struggle|actions:|lookaround:" -and $_ -notmatch "console>" } |
    ForEach-Object { $_.Substring(9) }
