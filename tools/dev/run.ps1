<#
  Development helper: run Lua in the game (a file or a string) and print what was added to
  twda.log meanwhile, without the echo of the code that console.ps1 prints.
    .\run.ps1 -File tree.lua
    .\run.ps1 'return UIZ_GetActiveMenu()'
    .\run.ps1 -File globs.lua -Pre 'GLOB_PAT = "Diorama"'
#>
param([string]$Code, [string]$File, [string]$Pre = "", [int]$WaitMs = 1500)

if ($File) { $Code = Get-Content -Raw $File }
if ($Pre) { $Code = $Pre + "`n" + $Code }
if (-not $Code) { Write-Error "No Lua given."; exit 1 }
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$before = (Get-Content $log).Count
& (Join-Path $PSScriptRoot "game_input.ps1") -Focus | Out-Null
Invoke-WebRequest -UseBasicParsing -Method Post -Body $Code http://127.0.0.1:41234/enqueue | Out-Null
Start-Sleep -Milliseconds $WaitMs
$skip = $false
Get-Content $log | Select-Object -Skip $before | ForEach-Object {
    if ($_ -match "^\S+\s+\S+ console> ") { $skip = $true; return }
    if ($skip -and $_ -match "^\S+\s+\S+ ") { $skip = $false }
    if (-not $skip) { $_ }
}
