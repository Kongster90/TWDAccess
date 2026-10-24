<#
  Development helper (Season 2 and A New Frontier): use each named thing in turn (use2.ps1), then
  let the talk run with play2.ps1 (choices answered with -Answer, prompts pressed) until the player
  can move again.
    .\useall.ps1 -Names "Billiard Table","Card Players#2","Drunk" -Answer 1
  "Name#N" picks action N.
#>
param([string[]]$Names, [string]$Answer = "1", [int]$TalkSeconds = 90)

$dev = $PSScriptRoot
foreach ($entry in $Names) {
    $parts = $entry -split "#", 2
    $action = if ($parts.Count -gt 1) { [int]$parts[1] } else { 0 }
    "== $entry"
    & "$dev\use2.ps1" -Name $parts[0] -Action $action -NoFollow 2>&1 | Select-Object -Last 2
    if ($LASTEXITCODE -ne 0) { continue }
    # (Straight on, so a prompt that comes at once is not missed; stops when the player can move.)
    & "$dev\play2.ps1" -Seconds $TalkSeconds -Answer $Answer 2>&1 | Select-String -NotMatch "heard: [A-Z][a-z]+( [A-Z][a-z]+)?$" | Select-Object -Last 6
}
