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
$startLines = @(Get-Content $speech)
$seen = $startLines.Count
# (Lines from the last few seconds count too: a prompt said just before this run started.)
$nowTime = Get-Date
while ($seen -gt 0) {
    $stamp = $startLines[$seen - 1].Substring(0, [Math]::Min(12, $startLines[$seen - 1].Length))
    $t = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($stamp, "HH:mm:ss.fff", $null, 0, [ref]$t)) { break }
    if (($nowTime - $t).TotalSeconds -gt 1.5) { break }
    $seen--
}
$end = (Get-Date).AddSeconds($Seconds)
# ("^W" holds W from the start, until a rule fires.)
$startHold = $null
foreach ($k in $StartKeys) {
    if ($k.StartsWith("^")) { $startHold = $k.Substring(1); continue }
    & "$dev\game_input.ps1" -Focus | Out-Null; & "$dev\game_input.ps1" -Keys $k | Out-Null
}
$parsed = @(foreach ($r in $Rules) { $p = $r -split "=>", 2; [pscustomobject]@{ Pattern = $p[0]; Keys = @($p[1] -split ",") } })
$mash = $null
$hold = $startHold
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
    # (Pressed here directly: game_input.ps1 focuses and waits 300 ms on each call, too slow to mash.)
    if ($mash) { $vkm = VkOf $mash; for ($i = 0; $i -lt 8; $i++) { [GameInput]::Key($vkm, $false, 30); Start-Sleep -Milliseconds 45 } }
    elseif ($hold) { [GameInput]::KeyState((VkOf $hold), $true); Start-Sleep -Milliseconds 100 }
    else { Start-Sleep -Milliseconds 200 }
}
if ($hold) { [GameInput]::KeyState((VkOf $hold), $false) }
