<#
  Development helper (Michonne): mplay.ps1 in a loop that also does the obvious step a listening
  player would take: Enter when the mod offers one thing ("X: Y. Enter to do it."). Stops when
  there is a choice of things, a close-up, a death, a hint about keys, or after -Rounds.
    .\mrun.ps1 [-Rounds 8] [-Seconds 240]
#>
param([int]$Rounds = 8, [int]$Seconds = 240, [int]$Lines = 10)
$dev = $PSScriptRoot
$until = 'You are dead|Enter to do it|Tab to choose|Close-up|Choose:|lean out|Try [SWAD]|does not move|can move\.|A number picks|Nothing to interact'
for ($r = 0; $r -lt $Rounds; $r++) {
    $out = & "$dev\mplay.ps1" -Seconds $Seconds -Lines $Lines -Until $until
    $stop = ($out | Select-Object -First 1)
    if ($stop -eq "time up") {
        # (An offer made between two rounds is not seen by mplay: look at the last thing said.)
        $lastSay = Get-Content "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log" -Tail 300 |
            Where-Object { $_ -match ' say!? ' -and $_ -cnotmatch ' say [A-Z][\w ]*$' } | Select-Object -Last 1
        if ($lastSay -match 'Enter to do it' -and $lastSay -notmatch 'Tab to choose') {
            "round ${r}: (between rounds) $($lastSay.Substring([Math]::Min(30, $lastSay.Length)))  -> Enter"
            & "$dev\step.ps1" -Keys Enter -SettleMs 1500 | Out-Null
            continue
        }
        if ($lastSay -match 'Tab to choose|can move|Close-up') { "round ${r}: waiting on: $lastSay"; break }
        "round ${r}: time up, going on"; continue
    }
    if ($stop -match 'Enter to do it' -and $stop -notmatch 'Tab to choose') {
        "round ${r}: $($stop.Substring([Math]::Min(30, $stop.Length)))  -> Enter"
        & "$dev\step.ps1" -Keys Enter -SettleMs 1500 | Out-Null
        continue
    }
    $out
    break
}
