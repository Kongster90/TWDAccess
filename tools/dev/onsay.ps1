<#
  Development helper: keep the game focused and, each time the mod says something matching a
  pattern, press the given keys. Pairs are "regex=>Key,Key". A key written "+Q" starts pressing Q
  over and over (about 10 times a second) and "^Q" holds Q down, either until another rule fires.
  Stops after -Seconds or on -Stop. -StartKeys are pressed once at the start.
    .\onsay.ps1 -Rules "Rock: Use=>Enter","Struggle!=>+Q","E now=>E" -Seconds 60
#>
param([string[]]$Rules, [int]$Seconds = 60, [string]$Stop = "You are dead", [string[]]$StartKeys)

$dev = $PSScriptRoot
$speech = Join-Path $dev "..\..\dist\TWDAccess\logs\speech.log"
$seen = (Get-Content $speech).Count
$end = (Get-Date).AddSeconds($Seconds)
foreach ($k in $StartKeys) { & "$dev\game_input.ps1" -Focus | Out-Null; & "$dev\game_input.ps1" -Keys $k | Out-Null }
$parsed = @(foreach ($r in $Rules) { $p = $r -split "=>", 2; [pscustomobject]@{ Pattern = $p[0]; Keys = @($p[1] -split ",") } })
$mash = $null
$hold = $null
. "$dev\game_input.ps1"
$names = @{ Up = 0x26; Down = 0x28; Left = 0x25; Right = 0x27; Shift = 0x10; Enter = 0x0D }
function VkOf([string]$k) { if ($names.ContainsKey($k)) { [uint16]$names[$k] } else { [uint16][int][char]$k.ToUpper() } }
$lastFocus = Get-Date
while ((Get-Date) -lt $end) {
    if (((Get-Date) - $lastFocus).TotalMilliseconds -gt 1500) { & "$dev\game_input.ps1" -Focus | Out-Null; $lastFocus = Get-Date }
    $lines = Get-Content $speech
    $new = $lines | Select-Object -Skip $seen
    $seen = $lines.Count
    foreach ($line in $new) {
        "{0} heard: {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $line.Substring([Math]::Min(13, $line.Length))
        foreach ($rule in $parsed) {
            if ($line -match $rule.Pattern) {
                $mash = $null
                if ($hold) { [GameInput]::KeyState((VkOf $hold), $false); $hold = $null }
                foreach ($k in $rule.Keys) {
                    if ($k.StartsWith("+")) { $mash = $k.Substring(1) }
                    elseif ($k.StartsWith("^")) { $hold = $k.Substring(1) }
                    else { & "$dev\game_input.ps1" -Keys $k | Out-Null }
                }
                "  pressed " + ($rule.Keys -join ",")
                break
            }
        }
        if ($line -match $Stop) { if ($hold) { [GameInput]::KeyState((VkOf $hold), $false) }; return }
    }
    # (Mashing in batches from one call: about ten presses a second, as fast as a person.)
    if ($mash) { & "$dev\game_input.ps1" -Keys (@($mash) * 6) -DelayMs 60 -HoldMs 30 | Out-Null }
    elseif ($hold) { [GameInput]::KeyState((VkOf $hold), $true); Start-Sleep -Milliseconds 100 }
    else { Start-Sleep -Milliseconds 200 }
}
if ($hold) { [GameInput]::KeyState((VkOf $hold), $false) }
