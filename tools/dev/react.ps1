<#
  Development helper: wait until the mod says something matching -When (a regex on the "say" lines
  in twda.log), then press -Keys in order (-GapMs apart), keeping the game focused, then print what
  was said over the next -Seconds. For timed scenes where a round trip per key is too slow.
    .\react.ps1 -When "Hurry" -Keys Tab,2,Enter -Seconds 20
#>
param([Parameter(Mandatory)][string]$When, [string[]]$Keys = @(), [int]$GapMs = 1200, [int]$TimeoutS = 90,
      [int]$Seconds = 15)

# (game_input.ps1 has parameters of its own, -Keys among them, which dot-sourcing it resets.)
$toPress, $waitFor = $Keys, $When
. (Join-Path $PSScriptRoot "game_input.ps1")
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$proc = Get-Process WDC | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $proc.MainWindowHandle
$fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
[void]$fs.Seek(0, 'End')
$reader = New-Object System.IO.StreamReader($fs)

$codes = @{ Tab = 0x09; Enter = 0x0D; Backspace = 0x08; Escape = 0x1B; Left = 0x25; Up = 0x26; Right = 0x27; Down = 0x28;
            F5 = 0x74; F6 = 0x75; Q = 0x51; E = 0x45; W = 0x57; A = 0x41; S = 0x53; D = 0x44 }
function Press([string]$k) {
    $code = if ($codes.ContainsKey($k)) { $codes[$k] } elseif ($k -match '^\d$') { 0x30 + [int]$k } else { [int][char]$k.ToUpper() }
    [void][GameInput]::Focus($h)
    [GameInput]::Key([uint16]$code, ($code -ge 0x21 -and $code -le 0x28), 50)
    "{0:HH:mm:ss.fff} press {1}" -f (Get-Date), $k
}
function Drain {
    while ($null -ne ($line = $reader.ReadLine())) {
        if ($line -match " say!? (.*)$") { "{0:HH:mm:ss.fff} heard: {1}" -f (Get-Date), $Matches[1]; if ($Matches[1] -match $waitFor) { $script:hit = $true } }
    }
}

$hit = $false
$end = (Get-Date).AddSeconds($TimeoutS)
while (-not $hit -and (Get-Date) -lt $end) {
    [void][GameInput]::Focus($h)
    Drain
    Start-Sleep -Milliseconds 150
}
if (-not $hit) { "never heard /$waitFor/"; exit 1 }
foreach ($k in $toPress) { Start-Sleep -Milliseconds $GapMs; Press $k; Drain }
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) { [void][GameInput]::Focus($h); Drain; Start-Sleep -Milliseconds 300 }
