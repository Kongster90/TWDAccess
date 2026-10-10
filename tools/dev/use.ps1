<#
  Development helper: use a hotspot by keys, as a player would. Tabs until the mod names it (the
  -Name text, matched against what is spoken), walks there first if the mod offers that, presses
  an action number if given, then Enter, and lets any conversation run (talk.ps1).
    .\use.ps1 -Name "Energy Bar"
    .\use.ps1 -Name Clementine -Action 2 -Answers 1,1
#>
param([Parameter(Mandatory)][string]$Name, [string]$Action, [string[]]$Answers = @("1"), [int]$Quiet = 12,
      [int]$MaxTabs = 45)

$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"

function NewSpeech([int]$from) { Get-Content $log | Select-Object -Skip $from | Where-Object { $_ -match " say!? " } }

# The name as said at the start of a line, not part of a longer one ("Chuck", not "Chuck's Camp").
$pattern = " say!? " + [regex]::Escape($Name) + "(?=[:,.]| is |$)"
$found = $false
for ($i = 0; $i -lt $MaxTabs; $i++) {
    $n0 = (Get-Content $log).Count
    & "$dev\game_input.ps1" -Keys Tab | Out-Null
    Start-Sleep -Milliseconds 1600
    $said = NewSpeech $n0
    if (($said | Select-Object -Last 1) -match $pattern) { $found = $true; break }
}
if (-not $found) { "never heard '$Name'"; exit 1 }
$last = ($said | Select-Object -Last 1)
"heard: " + $last.Substring(19)
if ($last -match "Enter walks there") {
    $n0 = (Get-Content $log).Count
    & "$dev\game_input.ps1" -Keys Enter | Out-Null
    $end = (Get-Date).AddSeconds(60)
    $walksOn = 0
    while ((Get-Date) -lt $end) {
        & "$dev\game_input.ps1" -Focus | Out-Null
        $said = NewSpeech $n0
        # The game took Lee over on the way (a remark, a short scene): walk on, as told.
        if ((@($said) -match "cut short.*Enter walks on").Count -gt $walksOn) {
            $walksOn++
            & "$dev\game_input.ps1" -Keys Enter | Out-Null
            $end = (Get-Date).AddSeconds(60)
        }
        if ($said -match "stopped|blocked|still can't|camera does not show|out of view from here|no further|At the ") { break }
        if (($said | Where-Object { $_ -notmatch "Walking to" }) -match $pattern) { break }
        Start-Sleep -Milliseconds 800
    }
    ($said | Select-Object -Last 1).Substring(19)
    # The walk ended short, or at a place with its own instructions ("At the stairs"): stop here.
    if ($said -match "stopped|blocked|still can't|no further|At the ") { exit 0 }
}
if ($Action) { & "$dev\game_input.ps1" -Keys $Action | Out-Null; Start-Sleep -Milliseconds 500 }
& "$dev\game_input.ps1" -Keys Enter | Out-Null
& "$dev\talk.ps1" -Answers $Answers -Quiet $Quiet
