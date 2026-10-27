<#
  Development helper: hold one key, then after a pause hold a second, then let both go
  (A New Frontier's drags: hold Enter, then the direction).
    .\chord.ps1 -First Enter -Second Down -GapMs 600 -HoldMs 3000
#>
param([string]$First = "Enter", [string]$Second = "Down", [int]$GapMs = 600, [int]$HoldMs = 3000)

. (Join-Path $PSScriptRoot "game_input.ps1") -Focus | Out-Null
$codes = @{ Enter = 0x0D; Left = 0x25; Up = 0x26; Right = 0x27; Down = 0x28; Q = 0x51; E = 0x45; W = 0x57; A = 0x41; S = 0x53; D = 0x44; Shift = 0x10 }
[GameInput]::KeyState([uint16]$codes[$First], $true)
Start-Sleep -Milliseconds $GapMs
[GameInput]::KeyState([uint16]$codes[$Second], $true)
Start-Sleep -Milliseconds $HoldMs
[GameInput]::KeyState([uint16]$codes[$Second], $false)
Start-Sleep -Milliseconds 100
[GameInput]::KeyState([uint16]$codes[$First], $false)
"held $First then $Second"
