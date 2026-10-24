<#
  Development helper: hold a key in the game, re-focusing the game and repeating key-down (like
  auto-repeat) so a focus steal does not end the hold (game_input.ps1 -HoldMs can lose it).
  With -Until, stop early once that text appears in twda.log.
    .\holdkey.ps1 -Key S -Ms 25000 -Until "backingAwayFromCopFinished"   # (logged by watch_scene.lua)
#>
param([string]$Key = "S", [int]$Ms = 9000, [string]$Until = "")
. (Join-Path $PSScriptRoot "game_input.ps1")
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$from = (Get-Item $log).Length
$proc = Get-Process WDC | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $proc.MainWindowHandle
$names = @{ Up = 0x26; Down = 0x28; Left = 0x25; Right = 0x27; Shift = 0x10; Enter = 0x0D }
$code = if ($names.ContainsKey($Key)) { [uint16]$names[$Key] } else { [uint16][int][char]$Key.ToUpper() }
$end = (Get-Date).AddMilliseconds($Ms)
$n = 0
while ((Get-Date) -lt $end) {
    [void][GameInput]::Focus($h)
    [GameInput]::KeyState($code, $true)
    Start-Sleep -Milliseconds 100
    $n++
    if ($Until -and $n % 5 -eq 0) {
        $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite'); $fs.Seek($from, 'Begin') | Out-Null
        $t = (New-Object System.IO.StreamReader($fs)).ReadToEnd(); $fs.Close()
        if ($t.Contains($Until)) { "stopped: saw $Until"; break }
    }
}
[GameInput]::KeyState($code, $false)
