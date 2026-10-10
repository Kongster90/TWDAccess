<#
  Development helper: reload the current checkpoint, start a watch script as soon as the mod is up
  in the new state, keep the game focused for a while, then print the new log lines.
    .\checkpoint_watch.ps1 -Seconds 60                       # watch_struggle.lua by default
    .\checkpoint_watch.ps1 -Watch watch_scene.lua -Seconds 90 -Filter "W2 |say"
  -NoReload skips the CheckpointLoad (for watching from where the game is now); -Watch none starts no
  watch script.
#>
param([int]$Seconds = 60, [AllowEmptyString()][string]$Watch = "watch_struggle.lua", [string]$Filter = "WS |say|struggle|subtitle|lookaround|actions",
      [switch]$NoReload)

$game = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series"
$log = "$game\TWDAccess\twda.log"
$tool = Join-Path $PSScriptRoot "game_input.ps1"
$n0 = (Get-Content $log).Count

& $tool -Focus | Out-Null
if (-not $NoReload) {
    Invoke-WebRequest -UseBasicParsing -Method Post -Body "CheckpointLoad()" http://127.0.0.1:41234/enqueue | Out-Null
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 250
        if ((Get-Content $log | Select-Object -Skip $n0) -match "choices: attached") { break }
        if ($i % 8 -eq 0) { & $tool -Focus | Out-Null }
    }
}
if ($Watch -and $Watch -ne "none") {
    $code = Get-Content -Raw (Join-Path $PSScriptRoot $Watch)
    Invoke-WebRequest -UseBasicParsing -Method Post -Body $code http://127.0.0.1:41234/enqueue | Out-Null
}
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) { & $tool -Focus | Out-Null; Start-Sleep -Seconds 2 }
Get-Content $log | Select-Object -Skip $n0 | Where-Object { $_ -match "^\d\d:\d\d:\d\d" -and $_ -match $Filter -and $_ -notmatch "console>" }
