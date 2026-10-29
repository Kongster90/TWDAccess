<#
  Development helper (Michonne): keep the game focused while a background react4.ps1 plays, and
  stop when something new the mod says needs the player (things to use, "can move", a close-up,
  the death screen), or after -Seconds; then print the recent meaningful log lines (mlog.ps1).
    .\mplay.ps1 [-Seconds 240] [-Lines 30]
#>
param([int]$Seconds = 240, [int]$Lines = 30,
      [string]$Until = 'can move|You are dead|Enter to do it|Tab to choose|Tab and Enter|Close-up|Nothing to interact|Drag:|Choose:|lean out|Try S|W does not')
$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$from = (Get-Item $log).Length
$end = (Get-Date).AddSeconds($Seconds)
$hit = $null
while ((Get-Date) -lt $end -and -not $hit) {
    & "$dev\game_input.ps1" -Focus | Out-Null
    $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite'); $fs.Seek($from, 'Begin') | Out-Null
    $text = (New-Object System.IO.StreamReader($fs)).ReadToEnd(); $from = $fs.Position; $fs.Close()
    foreach ($line in ($text -split "`n")) {
        if ($line -match ' say!? ' -and $line -match $Until) { $hit = $line.Trim() }
    }
    Start-Sleep -Milliseconds 700
}
if ($hit) { "STOP: $hit" } else { "time up" }
& "$dev\mlog.ps1" -Lines $Lines
