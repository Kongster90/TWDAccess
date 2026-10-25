<#
  Development helper (The Final Season): use every thing in the Tab list in turn (not places or
  walkers), waiting after each until the mod speaks again, until only places are left, or a
  choice, a death or a scene change comes up. -Skip names things to leave alone.
    .\useall4.ps1 [-Max 12] [-Skip "Open Door","Pick Up Flowers"]
#>
param([int]$Max = 12, [string[]]$Skip = @())

$dev = $PSScriptRoot
$speech = Join-Path $dev "..\..\dist\TWDAccess\logs\speech.log"
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$used = @{}
for ($round = 0; $round -lt $Max; $round++) {
    # One Tab cycle: find the first thing not used yet.
    $pick = $null
    $seen = @{}
    for ($i = 0; $i -lt 15; $i++) {
        $before = (Get-Content -Encoding UTF8 $speech).Count
        & "$dev\game_input.ps1" -Focus | Out-Null
        & "$dev\game_input.ps1" -Keys Tab | Out-Null
        Start-Sleep -Milliseconds 700
        $said = (Get-Content -Encoding UTF8 $speech | Select-Object -Skip $before) -join " "
        if ($said -notmatch "\] (.+?), (?:[^,]*, )*(\d+) of (\d+)") { continue }
        $name = $Matches[1]
        if ($seen.ContainsKey($name)) { break }
        $seen[$name] = $true
        if ($name -like "Place:*" -or $name -like "*walk up to it*" -or $used.ContainsKey($name) -or $Skip -contains $name) { continue }
        $pick = $name
        break
    }
    if (-not $pick) { "nothing left to use"; exit 0 }
    $used[$pick] = $true
    $n0 = (Get-Content $log).Count
    Start-Sleep -Milliseconds 400
    & "$dev\game_input.ps1" -Focus | Out-Null
    & "$dev\game_input.ps1" -Keys Enter | Out-Null
    Start-Sleep -Milliseconds 1200
    if (-not ((Get-Content $log | Select-Object -Skip $n0) -match "lookaround4: using")) {
        & "$dev\game_input.ps1" -Focus | Out-Null
        & "$dev\game_input.ps1" -Keys Enter | Out-Null
    }
    "used: $pick"
    # Wait until something is said that hands control back (or needs a decision), or until the
    # talk has been quiet for 4 seconds (a thing that stays on offer is not announced again).
    $start = Get-Date
    $end = $start.AddSeconds(90)
    $lastCount = -1; $quietSince = Get-Date
    while ((Get-Date) -lt $end) {
        & "$dev\game_input.ps1" -Focus | Out-Null
        Start-Sleep -Milliseconds 800
        $new = @(Get-Content $log | Select-Object -Skip $n0)
        if ($new -match "say! Choices|You are dead|LoadScript|Struggle!") { "stopped: something needs the player"; exit 0 }
        if ($new -match " say .*(can move|Tab to choose|Enter to do it|Nothing more|Nothing to interact)") { break }
        $talk = @($new -match "subtitle|say").Count
        if ($talk -ne $lastCount) { $lastCount = $talk; $quietSince = Get-Date }
        if (((Get-Date) - $start).TotalSeconds -gt 4 -and ((Get-Date) - $quietSince).TotalSeconds -gt 4) { break }
    }
}
