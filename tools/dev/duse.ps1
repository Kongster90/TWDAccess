<#
  Development helper: use hotspots by display name through DEV.use (devuse.lua, loaded on demand),
  letting each conversation run (talk.ps1) before the next.
    .\duse.ps1 "Lilly's Door","Duck","Clementine" -Answers 1
  "Chalk X#2" does the hotspot's second action (Inspect) instead of its first that is not looking.
#>
param([Parameter(Mandatory)][string[]]$Names, [string[]]$Answers = @("1"), [int]$Quiet = 12)

$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
& "$dev\console.ps1" -File "$dev\devuse.lua" -WaitMs 300 | Out-Null
foreach ($name in $Names) {
    $n0 = (Get-Content $log).Count
    $index = "nil"
    $hotspot = $name
    if ($name -match '^(.*)#(\d+)$') { $hotspot = $Matches[1]; $index = $Matches[2] }
    $escaped = $hotspot -replace '"', '\"'
    & "$dev\console.ps1" "return DEV.use(`"$escaped`", false, $index)" -WaitMs 300 | Out-Null
    $end = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $end) {
        & "$dev\game_input.ps1" -Focus | Out-Null
        $new = Get-Content $log | Select-Object -Skip $n0
        if ($new -match "DEVUSE (done|no) ") { break }
        Start-Sleep -Milliseconds 700
    }
    "== ${name}: " + (($new | Select-String "DEVUSE") -join " ")
    & "$dev\talk.ps1" -Answers $Answers -Quiet $Quiet | Where-Object { $_ -match "say!|Got|No more|LoadScript" } | Select-Object -Last 4
}
