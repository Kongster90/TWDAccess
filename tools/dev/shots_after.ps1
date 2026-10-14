<#
  Development helper: wait until the mod says something matching -When (pressing -Keys then), then
  take -Count screenshots -EveryMs apart into the scratch folder given by -Out (shot_N.png).
#>
param([string]$When, [string[]]$Keys, [int]$Count = 4, [int]$EveryMs = 1200, [string]$Out, [int]$Seconds = 120)
$dev = $PSScriptRoot
$speech = Join-Path $dev "..\..\dist\TWDAccess\logs\speech.log"
$seen = (Get-Content $speech).Count
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
  & "$dev\game_input.ps1" -Focus | Out-Null
  $lines = Get-Content $speech; $new = $lines | Select-Object -Skip $seen; $seen = $lines.Count
  if ($new -match $When) { break }
  Start-Sleep -Milliseconds 150
}
foreach ($k in $Keys) { & "$dev\game_input.ps1" -Keys $k | Out-Null }
for ($i = 1; $i -le $Count; $i++) {
  Start-Sleep -Milliseconds $EveryMs
  & "$dev\game_input.ps1" -Screenshot (Join-Path $Out "shot_$i.png") | Out-Null
}
"done"
