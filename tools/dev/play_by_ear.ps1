<#
  Development helper: plays a fight the way a player listening to the mod would, reacting only to
  what the mod says (the "say" lines in twda.log), with human-ish timing. Written for the
  babysitter fight in Clementine's house (2026-10-07) with actionscenes = normal.
    .\play_by_ear.ps1 -Seconds 90 -MashMs 130 -ReactMs 500
    .\play_by_ear.ps1 -HoldQ        # hold Q down instead of pressing it (the slow-mode assist)
  Rules: "Struggle!" starts pressing Q every MashMs; "E now!" presses E; "Too late" starts Q again;
  a line ending "Enter!" presses Enter; "Tab to choose" presses Tab, then Enter; "Turn:" presses
  the -Turn arrow (Right by default; the arrows need the extended-key flag). Stops at choices
  or the death screen (-Answer 1 answers every choice with 1 instead). Run it right after the checkpoint loads (see checkpoint_watch.ps1 -Seconds 0).
#>
param([int]$Seconds = 90, [int]$MashMs = 130, [int]$ReactMs = 500, [switch]$HoldQ, [string]$Turn = "Right", [switch]$IgnoreChoices, [int]$Answer = 0, [int]$HoldS = 6, [string]$StartKey = "", [string[]]$Leans = @(),
      [string]$Skip = "", [string[]]$Prefer = @(), [switch]$StickyHold)

. (Join-Path $PSScriptRoot "game_input.ps1")
$game = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series"
$log = "$game\TWDAccess\twda.log"
$proc = Get-Process WDC | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $proc.MainWindowHandle

$fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
[void]$fs.Seek(0, 'End')
$reader = New-Object System.IO.StreamReader($fs)

function Press([int]$code, [string]$label) {
    [void][GameInput]::Focus($h)
    [GameInput]::Key([uint16]$code, ($code -ge 0x21 -and $code -le 0x28), 50)
    "{0:HH:mm:ss.fff} press {1}" -f (Get-Date), $label
}

# -StartKey Enter: press it once listening (Enter on the death screen reloads a checkpoint that
# may start the action at once).
if ($StartKey -eq "Enter") { Press 0x0D "Enter" } elseif ($StartKey -eq "F6") { Press 0x75 "F6" }
# With -Answer, a choice already waiting when listening starts is answered too.
if ($Answer -gt 0) {
    # (The last list of choices with no "choices: ended" after it: subtitles may have come since.)
    $choiceLines = Get-Content $log -Tail 80 | Where-Object { $_ -match "^\S+\s+\S+ (say! Choices\.|choices: ended)" }
    if (($choiceLines | Select-Object -Last 1) -match " say! Choices\.") { Press (0x30 + $Answer) "$Answer (waiting choice)" }
}

$mashing = $false
$holding = 0
$sticky = $false
$holdUntil = Get-Date
$walkKeys = @()
$runUntil = $null
$leanIndex = 0
$lastMash = Get-Date
$lastFocus = Get-Date
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    while ($null -ne ($line = $reader.ReadLine())) {
        # (Only the mod's own "say" lines: a subtitle can contain " say " too.)
        if ($line -notmatch "^\S+\s+\S+ say!? (.*)$") { continue }
        $text = $Matches[1]
        "{0:HH:mm:ss.fff} heard: {1}" -f (Get-Date), $text
        # -Skip "regex": lines a test wants left alone (to see what the game does without them).
        if ($Skip -and $text -match $Skip) { "skipped"; continue }
        # Anything new said ends a guided move's hold.
        # (A "Press W to back away!" hold is kept through the fight that goes with it, as a player
        # would: Enter on "Now! Enter!" while still holding W; the train station, Episode 3.)
        if ($holding -and -not $sticky -and $text -notmatch "Use the|^Press [WASD] to ") { [GameInput]::KeyState([uint16]$holding, $false); "released"; $holding = 0 }
        if ($holding -and $text -match "^You are dead") { [GameInput]::KeyState([uint16]$holding, $false); $holding = 0 }
        # Walking in moving cover (cover.lua): hold the keys on "Walk: A" (and Shift on "Run: Shift
        # and A"), let go on "Stop".
        if ($text -match "(Walk|Run|Back): (Shift and )?([WASD](?: and [WASD])?)\s*$") {
            foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $false) }
            $walkKeys = @($Matches[3] -split " and " | ForEach-Object { [int][char]$_ })
            if ($Matches[2]) { $walkKeys = @(0x10) + $walkKeys }
            "walking " + $Matches[2] + $Matches[3]
        } elseif ($text -match "Hold W to run out of the field" -and $walkKeys.Count -eq 0) {
            # cornfield.lua: the end of the field waits for Bonnie to run.
            $walkKeys = @([int][char]"W"); "walking W (out of the field)"
        } elseif ($text -match "^Guided path\. Hold W or S" -and $walkKeys.Count -eq 0) {
            $walkKeys = @([int][char]"W"); "walking W (guided path)"
        } elseif ($text -match "^Go on: hold ([WASD])\.") {
            # guided.lua after a stop: move on along the path.
            foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $false) }
            $walkKeys = @([int][char]$Matches[1]); "walking " + $Matches[1]
        } elseif (($text -match "Stop$" -or $text -match "^Stop!") -and $walkKeys.Count -gt 0) {
            foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $false) }
            $walkKeys = @(); "stopped"
        } elseif ($text -match "^Let go of ([WASD]), then hold it again") {
            # guided.lua: a key held from before the path moves nothing until it is pressed again.
            $k = [int][char]$Matches[1]
            [GameInput]::KeyState([uint16]$k, $false); Start-Sleep -Milliseconds 300
            if ($walkKeys -notcontains $k) { $walkKeys = @($k) }
            "pressed $($Matches[1]) again"
        }
        # -Leans D,A: on each new "Hiding. To lean out" lean the next way (a player's choice).
        if ($text -match "^Hiding\. To lean out" -and $leanIndex -lt $Leans.Count) {
            Start-Sleep -Milliseconds $ReactMs
            $lk = $Leans[$leanIndex]; $leanIndex++
            Press ([int][char]$lk) "lean $lk"
        }
        if ($text -match "^Struggle[!,]") {
            Start-Sleep -Milliseconds $ReactMs
            if ($HoldQ) { [void][GameInput]::Focus($h); [GameInput]::KeyState(0x51, $true); "holding Q" } else { $mashing = $true }
        }
        elseif ($text -match "^E now") {
            Start-Sleep -Milliseconds ([int]($ReactMs / 2)); $mashing = $false
            if ($HoldQ) { [GameInput]::KeyState(0x51, $false) }
            Press 0x45 "E"
        }
        elseif ($text -match "^Too late") { if ($HoldQ) { [GameInput]::KeyState(0x51, $true) } else { $mashing = $true } }
        elseif ($text -match "Hold Shift and ([WASD](?: and [WASD])?)") {
            # Run (runto.lua): hold Shift and the keys for up to 6 seconds, following the corrections
            # it gives ("W and D") as the camera cuts.
            foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $false) }
            $walkKeys = @(0x10) + @($Matches[1] -split " and " | ForEach-Object { [int][char]$_ })
            $runUntil = (Get-Date).AddSeconds(6)
            "running Shift+" + $Matches[1]
        }
        elseif ($runUntil -and (Get-Date) -lt $runUntil -and $text -match "^([WASD](?: and [WASD])?)$") {
            foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $false) }
            $walkKeys = @(0x10) + @($Matches[1] -split " and " | ForEach-Object { [int][char]$_ })
            "running Shift+" + $Matches[1]
        }
        elseif ($text -match "Use the (W|A|S|D) \(" -or $text -match "^Press (W|A|S|D) to ") {
            # A guided move ("Use the S (back) key to get away!"): hold the key for up to -HoldS
            # seconds, or until something else is said.
            Start-Sleep -Milliseconds $ReactMs
            $holdKey = $Matches[1]
            $holding = [int][char]$holdKey
            # (-StickyHold: every such hold lasts through the shooting that comes with it, as on the
            # stairs of the Crawford school, Episode 4: back up with S, Enter at each walker.)
            $sticky = $StickyHold -or $text -match "^Press "
            $holdUntil = (Get-Date).AddSeconds($HoldS)
            "holding " + $holdKey
        }
        elseif ($text -match "^Grab it: Left or Right arrow") {
            # The rebar in 400 Days (cornfield.lua): the way to pull first.
            Start-Sleep -Milliseconds 300
            Press ($(if ($Turn -eq "Left") { 0x25 } else { 0x27 })) "$Turn (grab)"
        }
        elseif ($text -match "^Hold (Left|Right|Up|Down) arrow to pull") {
            # A drag (drag.lua): hold that arrow until something else is said (or -HoldS seconds).
            Start-Sleep -Milliseconds $ReactMs
            $holding = @{ Left = 0x25; Up = 0x26; Right = 0x27; Down = 0x28 }[$Matches[1]]
            $sticky = $false
            $holdUntil = (Get-Date).AddSeconds($HoldS)
            "holding " + $Matches[1] + " (pull)"
        }
        elseif ($text -match "^(?:Someone is coming down this row|Still in someone's row)[.!] (Left or Right|Left|Right) arrow") {
            # The cornfield in 400 Days (cornfield.lua): step into the next row, the -Turn way when
            # both are offered.
            Start-Sleep -Milliseconds $ReactMs
            $way = if ($Matches[1] -eq "Left or Right") { if ($Turn -eq "Left") { "Left" } else { "Right" } } else { $Matches[1] }
            Press ($(if ($way -eq "Left") { 0x25 } else { 0x27 })) "$way (row)"
        }
        elseif ($text -match "^Turn: ") {
            # -Turn Named: the first arrow the announcement names ("Up arrow to look up").
            $t = $Turn
            if ($Turn -eq "Named" -and $text -match "(Left|Right|Up|Down) arrow") { $t = $Matches[1] }
            $code = @{ Left = 0x25; Up = 0x26; Right = 0x27; Down = 0x28 }[$t]
            Start-Sleep -Milliseconds $ReactMs; Press $code $t
        }
        elseif ($text -match "does not move \w+ here\. Try ([WASD])" -and $holding) {
            # guided.lua: the other key moves the path on; hold that one instead.
            [GameInput]::KeyState([uint16]$holding, $false)
            $holdKey = $Matches[1]; $holding = [int][char]$holdKey; $holdUntil = (Get-Date).AddSeconds($HoldS)
            "now holding " + $holdKey
        }
        elseif ($text -match "Turn with the arrow keys" -and $text -match "(above you|below you|to your left|to your right)") {
            # A turn choice and the thing to deal with is off to that side: turn that way.
            $arrow = @{ "above you" = 0x26; "below you" = 0x28; "to your left" = 0x25; "to your right" = 0x27 }[$Matches[1]]
            Start-Sleep -Milliseconds $ReactMs; Press $arrow ("turn " + $Matches[1])
        }
        elseif ($text -match "^Nothing to do this way\. Turn: (Left|Right|Up|Down) arrow") {
            $arrow = @{ Left = 0x25; Up = 0x26; Right = 0x27; Down = 0x28 }[$Matches[1]]
            Start-Sleep -Milliseconds $ReactMs; Press $arrow ("turn " + $Matches[1])
        }
        elseif ($text -match "Pick a number, then Enter|A number key to choose, then Enter") {
            # A choice of actions ("zombie arm: 2 Shoot, 3 Pry"): the first -Prefer word found, else
            # the first number offered (what Enter alone would do).
            $num = $null
            foreach ($w in $Prefer) { if ($text -match "(\d) $w") { $num = [int]$Matches[1]; break } }
            if (-not $num -and $text -match "(\d) [A-Z]") { $num = [int]$Matches[1] }
            Start-Sleep -Milliseconds $ReactMs
            if ($num) { Press (0x30 + $num) "$num" }
            Press 0x0D "Enter"
        }
        elseif ($text -match "Tab to it, then Enter") {
            # Something out of reach to use in time: Tab goes to it, Enter walks there and does it.
            Start-Sleep -Milliseconds $ReactMs; Press 0x09 "Tab"; Start-Sleep -Milliseconds 900; Press 0x0D "Enter"
        }
        elseif ($text -match "Tab to choose") {
            Start-Sleep -Milliseconds $ReactMs
            # With a -Prefer word on offer ("zombie arm: 1 Look At, 2 Shoot, 3 Pry. Zombie: ..."):
            # Tab until the focus reads it out, then its number and Enter, as a player would.
            $want = $Prefer | Where-Object { $text -match "\d $_" } | Select-Object -First 1
            if ($want) {
                $num = $null
                for ($t = 0; $t -lt 5 -and -not $num; $t++) {
                    Press 0x09 "Tab"
                    $until = (Get-Date).AddMilliseconds(1500)
                    while ((Get-Date) -lt $until -and -not $num) {
                        $l = $reader.ReadLine()
                        if ($null -eq $l) { Start-Sleep -Milliseconds 50; continue }
                        if ($l -match "^\S+\s+\S+ say!? (.*)$") {
                            "{0:HH:mm:ss.fff} heard: {1}" -f (Get-Date), $Matches[1]
                            if ($Matches[1] -match "(\d) $want") { $num = [int]$Matches[1] }
                        }
                    }
                }
                if ($num) { Press (0x30 + $num) "$num ($want)" }
                Press 0x0D "Enter"
            } else { Press 0x09 "Tab"; Start-Sleep -Milliseconds 600; Press 0x0D "Enter" }
        }
        elseif ($text -match "Enter!$|Enter to do it.$") { Start-Sleep -Milliseconds $ReactMs; Press 0x0D "Enter" }
        elseif ($text -match " ([AD]) for the other side\.$") { Start-Sleep -Milliseconds $ReactMs; Press ([int][char]$Matches[1]) "side $($Matches[1])" }
        elseif ($text -match "her aim is (too far left|too far right|too high|too low|on the bottle)\. Choices\.") {
            # Clementine's shooting lesson (Episode 3): steer by what the mod says.
            $key = @{ "too far left" = 2; "too far right" = 1; "too high" = 2; "too low" = 1; "on the bottle" = 3 }[$Matches[1]]
            Start-Sleep -Milliseconds 800; Press (0x30 + $key) "$key (aim)"
        }
        elseif ($text -match "^Choices\." -and $Answer -gt 0) { Start-Sleep -Milliseconds 800; Press (0x30 + $Answer) "$Answer" }
        elseif (($text -match "^Choices\." -and -not $IgnoreChoices) -or $text -match "^You are dead") { [GameInput]::KeyState(0x51, $false); foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $false) }; "stopping"; $reader.Close(); exit 0 }
    }
    if ($runUntil -and (Get-Date) -ge $runUntil) {
        foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $false) }
        $walkKeys = @(); $runUntil = $null; "stopped running"
    }
    if ($walkKeys.Count -gt 0) {
        [void][GameInput]::Focus($h)
        foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $true) }
    }
    if ($holding) {
        if ((Get-Date) -ge $holdUntil) { [GameInput]::KeyState([uint16]$holding, $false); "released"; $holding = 0 }
        else { [void][GameInput]::Focus($h); [GameInput]::KeyState([uint16]$holding, $true) }
    }
    if ($mashing -and ((Get-Date) - $lastMash).TotalMilliseconds -ge $MashMs) {
        $lastMash = Get-Date
        [void][GameInput]::Focus($h)
        [GameInput]::Key([uint16]0x51, $false, 40)
    }
    if (((Get-Date) - $lastFocus).TotalSeconds -ge 2) { $lastFocus = Get-Date; [void][GameInput]::Focus($h) }
    Start-Sleep -Milliseconds 20
}
[GameInput]::KeyState(0x51, $false)
foreach ($k in $walkKeys) { [GameInput]::KeyState([uint16]$k, $false) }
$reader.Close()
