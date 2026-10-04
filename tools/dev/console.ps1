<#
  Development helper: run Lua in the game through the dev console and print the result.
    .\console.ps1 'return Mode_GetCurrent().name'
    .\console.ps1 -File reload.lua -WaitMs 3000
  Expressions print their value; statements run as they are. The game must be focused (this script
  focuses it), and needs devconsole = true in TWDAccess\settings.txt.
#>
param([string]$Code, [string]$File, [int]$WaitMs = 1500)

if ($File) { $Code = Get-Content -Raw $File }
if (-not $Code) { Write-Error "No Lua given."; exit 1 }

$log = Join-Path $PSScriptRoot "..\..\dist\TWDAccess\logs\game.log"
$before = if (Test-Path $log) { (Get-Content $log).Count } else { 0 }

& (Join-Path $PSScriptRoot "game_input.ps1") -Focus | Out-Null
Invoke-WebRequest -UseBasicParsing -Method Post -Body $Code http://127.0.0.1:41234/enqueue | Out-Null
Start-Sleep -Milliseconds $WaitMs
if (Test-Path $log) { Get-Content $log | Select-Object -Skip $before }
