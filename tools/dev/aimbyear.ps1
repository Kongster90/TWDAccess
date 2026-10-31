<#
  Development helper: aim the way a listening player would, from the aiming tone alone (the mod's
  aimtone lines in twda.log; set TWDA.aimDebug = true in the console first). Tapping Left or Right
  towards the pan while it is off to one side, waiting while it is near the middle (the mod closes
  the rest), Enter on the double tick (on=True, not behind cover). For the shotgun and the scope.
    .\aimbyear.ps1 -Seconds 60 [-Shots 6] [-Stop "Hit!|aiming: firing"]
#>
param([int]$Seconds = 60, [int]$Shots = 99, [double]$Dead = 0.15, [int]$TapMs = 120, [string]$Stop = "You are dead|scope down|mode over",
      [string]$Kick = "", [string]$EnterOn = "", [string]$LeanKey = "")
# (-LeanKey W taps W when the log says "To lean out": hiding before a scope.)
# (-Kick "0.1,0.5" first puts the pointer there, TWDA.setPointer, at the first tone: a start far off.
# -EnterOn "Shoot\. Enter!" also presses Enter when the log says that: prompts on the way.)
. (Join-Path $PSScriptRoot "game_input.ps1")
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$h = (Get-Process WDC | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1).MainWindowHandle
$from = (Get-Item $log).Length
$end = (Get-Date).AddSeconds($Seconds)
$fired, $lastFire = 0, [datetime]::MinValue
function NewText {
    $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite'); $fs.Seek($script:from, 'Begin') | Out-Null
    $t = (New-Object System.IO.StreamReader($fs)).ReadToEnd(); $script:from = $fs.Position; $fs.Close(); $t
}
function Tap([uint16]$code, [int]$ms) {
    [GameInput]::KeyState($code, $true); Start-Sleep -Milliseconds $ms; [GameInput]::KeyState($code, $false)
}
$last = $null
while ((Get-Date) -lt $end -and $fired -lt $Shots) {
    [void][GameInput]::Focus($h)
    $text = NewText
    if ($text -match $Stop) { "stopped: $($Matches[0])"; break }
    if ($EnterOn -and $text -match $EnterOn) { Tap 0x0D 60; "Enter on $($Matches[0])" }
    # (The way the mod names first: "To lean out: D right" in the bandit attack's second phase.)
    if ($LeanKey -and $text -match "To lean out: ([WAD]) ") { $k = $Matches[1]; Tap ([uint16][int][char]$k) 80; "lean $k" }
    elseif ($LeanKey -and $text -match "To lean out") { Tap ([uint16][int][char]$LeanKey.ToUpper()) 80; "lean $LeanKey" }
    # (The walkers at the RV come from both sides: "Nothing in sight here. D for the other side.")
    if ($text -match "([AD]) for the other side") { $k = $Matches[1]; Tap ([uint16][int][char]$k) 80; "side $k" }
    $tones = [regex]::Matches($text, "aimtone: pan=(-?[\d.]+) off=([\d.]+) on=(\w+) behind=(\w+)")
    if ($tones.Count -gt 0) { $last = $tones[$tones.Count - 1] }
    if ($Kick -and $last) {
        & (Join-Path $PSScriptRoot "console.ps1") "TWDA.setPointer($Kick) return 'kicked'" | Out-Null
        "kicked to $Kick"; $Kick = ""; $last = $null; NewText | Out-Null; continue
    }
    if ($last) {
        $pan = [double]$last.Groups[1].Value; $on = $last.Groups[3].Value -eq "true"; $behind = $last.Groups[4].Value -eq "true"
        if ($on -and -not $behind -and ((Get-Date) - $lastFire).TotalMilliseconds -gt 700) {
            Tap 0x0D 60; $fired++; $lastFire = Get-Date; "Enter (pan $pan)"; $last = $null
        } elseif ($pan -gt $Dead) { Tap 0x27 $TapMs }
        elseif ($pan -lt -$Dead) { Tap 0x25 $TapMs }
    }
    Start-Sleep -Milliseconds 80
}
"fired $fired"
