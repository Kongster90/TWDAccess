<#
  Development helper: let conversations run, answering each dialog choice with the given number
  keys in turn (the last one repeats), until something other than a choice needs the player (a
  hint, a struggle, a hotspot announcement, the death screen) or nothing happens for -Quiet seconds.
    .\talk.ps1 -Answers 2,1,1
#>
param([string[]]$Answers = @("1"), [int]$Seconds = 300, [int]$Quiet = 25)

$dev = $PSScriptRoot
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$n0 = (Get-Content $log).Count
$seen = $n0
$i = 0
$end = (Get-Date).AddSeconds($Seconds)
$lastChange = Get-Date
$lastCount = $n0
while ((Get-Date) -lt $end) {
    & "$dev\game_input.ps1" -Focus | Out-Null
    $lines = Get-Content $log
    if ($lines.Count -ne $lastCount) { $lastCount = $lines.Count; $lastChange = Get-Date }
    $new = @($lines | Select-Object -Skip $seen)
    $seen = $lines.Count
    $stop = $false
    foreach ($l in $new) {
        if ($l -match "say! Choices") {
            $key = $Answers[[Math]::Min($i, $Answers.Count - 1)]; $i++
            Start-Sleep -Milliseconds 600
            & "$dev\game_input.ps1" -Keys $key | Out-Null
        } elseif ($l -match "say! " -and $l -notmatch "say! \d: ") { $stop = $true }
        elseif ($l -match "You are dead|struggle: started") { $stop = $true }
    }
    if ($stop) { break }
    if (((Get-Date) - $lastChange).TotalSeconds -ge $Quiet) { break }
    Start-Sleep -Milliseconds 700
}
Get-Content $log | Select-Object -Skip $n0 |
    Where-Object { $_ -match "say|subtitle|LoadScript|SaveSlots|struggle|actions:|lookaround:" -and $_ -notmatch "console>" } |
    ForEach-Object { $_.Substring(19) }
