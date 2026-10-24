<#
  Development helper: build the mod and copy its Lua files into the game folder, without
  restarting. The next new Lua state (a season or scene change) runs them. Finish a session with
  restart.ps1 or the dotnet build, so dist\TWDAccess matches.
    .\sync.ps1
#>
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$game = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series"
& "$root\.venv\Scripts\python.exe" "$root\tools\build_mod.py" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "Mod build failed"; exit 1 }
Copy-Item "$root\build\mod\TWDAccess\*.lua" "$game\TWDAccess\" -Force
"synced"
