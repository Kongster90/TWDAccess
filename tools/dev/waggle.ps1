<#
  Development helper: press two keys in turn, fast, for -Seconds (a waggle struggle: Left and
  Right arrows), keeping the game focused.
    .\waggle.ps1 [-A Left] [-B Right] [-Seconds 6] [-GapMs 60]
#>
param([string]$A = "Left", [string]$B = "Right", [double]$Seconds = 6, [int]$GapMs = 60)
. (Join-Path $PSScriptRoot "game_input.ps1")
$names = @{ Up = 0x26; Down = 0x28; Left = 0x25; Right = 0x27 }
function VkOf([string]$k) { if ($names.ContainsKey($k)) { [uint16]$names[$k] } else { [uint16][int][char]$k.ToUpper() } }
$h = (Get-Process WDC | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1).MainWindowHandle
$end = (Get-Date).AddSeconds($Seconds)
$n = 0
while ((Get-Date) -lt $end) {
    if ($n % 10 -eq 0) { [void][GameInput]::Focus($h) }
    [GameInput]::Key((VkOf $A), $true, 30); Start-Sleep -Milliseconds $GapMs
    [GameInput]::Key((VkOf $B), $true, 30); Start-Sleep -Milliseconds $GapMs
    $n++
}
"pressed $n pairs"
