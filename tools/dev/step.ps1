<#
  Development helper: press keys in the game and print what TWD Access said in response.
    .\step.ps1 Down,Down,Enter        # keys, one second apart
    .\step.ps1 -Lua 'Menu_Seasons()'   # run Lua through the dev console instead
#>
param([string[]]$Keys, [string]$Lua, [int]$DelayMs = 1000, [int]$SettleMs = 1500)

$tool = Join-Path $PSScriptRoot "game_input.ps1"
$speech = Join-Path $PSScriptRoot "..\..\dist\TWDAccess\logs\speech.log"
$before = if (Test-Path $speech) { (Get-Content $speech).Count } else { 0 }

& $tool -Focus | Out-Null
if ($Lua) {
    Invoke-WebRequest -UseBasicParsing -Method Post -Body $Lua http://127.0.0.1:41234/enqueue | Out-Null
}
foreach ($k in $Keys) {
    & $tool -Keys $k -DelayMs $DelayMs | Out-Null
}
Start-Sleep -Milliseconds $SettleMs
if (Test-Path $speech) {
    (Get-Content $speech) | Select-Object -Skip $before | ForEach-Object { "  said: " + $_.Substring(13) }
}
