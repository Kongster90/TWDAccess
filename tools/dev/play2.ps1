<#
  Development helper (Season 2): play on by ear with the usual reactions (onsay.ps1 rules): answer
  dialog choices with -Answer, Enter on "Enter!" cues and single offers, hold Q in struggles and E on
  "E now", arrows on dodge cues. Stops when something needs a decision: a list to choose from, free
  walking, hiding, a drag, a guided path, the death screen or a menu.
    .\play2.ps1 -Seconds 300 [-Answer 1] [-StartKeys Enter]
#>
param([int]$Seconds = 300, [string]$Answer = "1", [string[]]$StartKeys,
      [string]$Stop = "You are dead|can move|lean out|(?<!(nearest|first), or )Tab to choose|[Mm]enu|My Choices|Choose:|Nothing chosen")
$rules = @("Choices\. 1=>$Answer", "(?<!Tab to choose, )(?<!Hold )Enter!=>Enter", "Enter to do it=>Enter", "again\? Enter=>Enter",
  "Enter for the (nearest|first)=>Enter", "Struggle! Press Q=>+Q", "Struggle!=>^Q", "Too late=>+Q", "E now=>E", "Right arrow!=>Right", "Left arrow!=>Left", "Up arrow!=>Up", "Down arrow!=>Down",
  "Drag: hold Up=>^Up", "Drag: hold Down=>^Down", "Drag: hold Left=>^Left", "Drag: hold Right=>^Right",
  "E, [0-9]+ times=>+E", "Q, [0-9]+ times=>+Q", "Press [Ss]hift and E together=>Shift+E", "Press [Ss]hift and Q together=>Shift+Q", "Guided path=>^W","Try S$=>^S", "Try W$=>^W", "S goes on=>^S", "W goes on=>^W","Hold Enter!=>^Enter", "Hold E!=>^E", "Hold Q!=>^Q", "\sE!$=>E", "\sQ!$=>Q", "Let go!=>Space")
# A choice already waiting (it came up between runs): answer it first.
$all = Get-Content "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$lastAsk = ($all | Select-String "say! Choices" | Select-Object -Last 1).LineNumber
$lastAnswer = ($all | Select-String "say! \d: " | Select-Object -Last 1).LineNumber
if ($lastAsk -and $lastAsk -gt $all.Count - 40 -and (-not $lastAnswer -or $lastAnswer -lt $lastAsk)) {
    "answering a waiting choice with $Answer"
    $StartKeys = @($Answer) + @($StartKeys | Where-Object { $_ })
}
& (Join-Path $PSScriptRoot "onsay.ps1") -Rules $rules -Seconds $Seconds -Stop $Stop -StartKeys $StartKeys
