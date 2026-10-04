<#
  Development helper: rebuild the mod and helper, restart the game, and wait at the hub main menu.
    .\restart.ps1
#>
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$dev = $PSScriptRoot
$game = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series"

Get-Process WDC -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process TWDAccess -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
# Keep the previous session's logs (it may have been the user playing) as *.prev.
Move-Item "$game\TWDAccess\twda.log" "$game\TWDAccess\twda.prev.log" -Force -ErrorAction SilentlyContinue
Remove-Item "$game\TWDAccess\next_script.txt" -ErrorAction SilentlyContinue

& "$root\.venv\Scripts\python.exe" "$root\tools\build_mod.py" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "Mod build failed"; exit 1 }
Remove-Item "$root\dist\TWDAccess\mod" -Recurse -Force -ErrorAction SilentlyContinue
$build = dotnet build "$root\helper\TWDAccess\TWDAccess.csproj" -c Release -o "$root\dist\TWDAccess" 2>&1
if ($LASTEXITCODE -ne 0) { $build | Select-String "error"; exit 1 }
Remove-Item "$root\dist\TWDAccess\logs.prev" -Recurse -Force -ErrorAction SilentlyContinue
Move-Item "$root\dist\TWDAccess\logs" "$root\dist\TWDAccess\logs.prev" -Force -ErrorAction SilentlyContinue

Start-Process -FilePath "$root\dist\TWDAccess\TWDAccess.exe" -WorkingDirectory "$root\dist\TWDAccess" -WindowStyle Minimized
Start-Sleep -Seconds 35
& "$dev\game_input.ps1" -Click 0.5, 0.85 | Out-Null

$log = "$game\TWDAccess\twda.log"
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    & "$dev\game_input.ps1" -Focus 2>$null | Out-Null
    if ((Test-Path $log) -and (Select-String -Path $log -Pattern "say! Main menu" -Quiet)) { "at main menu"; exit 0 }
}
"main menu not reached; see $log"
exit 1
