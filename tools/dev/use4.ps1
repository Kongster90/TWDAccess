<#
  Development helper (The Final Season): Tab until the mod names a thing (or place), press Enter,
  and check twda.log for lookaround4's "using" (or lookaround2's "walking to"); Enter again once if
  the first press was lost.
    .\use4.ps1 -Name "Open Drawer"
    .\use4.ps1 -Name "Place: Someone coming"
#>
param([string]$Name, [int]$MaxTabs = 20)

$dev = $PSScriptRoot
$speech = Join-Path $dev "..\..\dist\TWDAccess\logs\speech.log"
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$found = $false
for ($i = 0; $i -lt $MaxTabs; $i++) {
    $before = (Get-Content -Encoding UTF8 $speech).Count
    & "$dev\game_input.ps1" -Focus | Out-Null
    & "$dev\game_input.ps1" -Keys Tab | Out-Null
    Start-Sleep -Milliseconds 700
    $said = (Get-Content -Encoding UTF8 $speech | Select-Object -Skip $before) -join " "
    if ($said -match ("\] " + [regex]::Escape($Name) + ",")) { $found = $true; "found: $said"; break }
}
if (-not $found) { "never found $Name"; exit 1 }
for ($try = 0; $try -lt 2; $try++) {
    $n0 = (Get-Content $log).Count
    Start-Sleep -Milliseconds 500
    & "$dev\game_input.ps1" -Focus | Out-Null
    & "$dev\game_input.ps1" -Keys Enter | Out-Null
    Start-Sleep -Milliseconds 1200
    $new = Get-Content $log | Select-Object -Skip $n0
    if ($new -match "lookaround4: using|lookaround2: walking to") { ($new -match "lookaround4: using|lookaround2: walking to") | Select-Object -First 1; exit 0 }
}
"Enter did nothing"
exit 1
