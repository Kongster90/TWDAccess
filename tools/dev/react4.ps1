<#
  Development helper (The Final Season): a background reactor for long play sessions. Reacts to the
  mod's speech as a listening player would: Enter on the death screen, Q when a walker is announced
  (kept by combat4.lua until it is in reach) or in reach, mashing in struggles, E when told, the
  keys QTEs name, drags, and dialog choices with -Answer (2 when 1 is "Say nothing"). It never
  explores (no "Enter to do it").
    .\react4.ps1 -Seconds 3000 [-Answer 1] [-Extra "Release Brake=>Tab,Enter"]
#>
param([int]$Seconds = 3000, [string]$Answer = "1", [string[]]$Extra = @())
$rules = @("You are dead=>Enter", "On target. Enter shoots=>Enter,Enter,Enter", "Burning walkers cannot be killed=>R", "Bow in hand: R draws=>R", "Hold W to go on=>^W", "Hold A to go on=>^A", "Hold S to go on=>^S", "Hold D to go on=>^D", "can move=>", "(?-i)Another walker=>", "more close! Q to attack, E to=>E", "more close! Q to attack!$=>Q", "Walker, \d+ meters=>Q", "Walker! Q to=>Q", "Walker! E to=>E",
  "Struggle! Press Q=>+Q", "(?-i)\bE now=>E", "(?-i)Too late=>+Q", "Choices\. 1: Say nothing\. 2=>2", "Choices\. 1=>$Answer",
  "Press [Ss]hift and E together=>Shift+E", "Press [Ss]hift and Q together=>Shift+Q",
  "E, [0-9]+ times=>+E", "Q, [0-9]+ times=>+Q", "Hold Enter!=>^Enter", "Hold E!=>^E", "Hold Q!=>^Q",
  "(?<!Hold )Enter!=>Enter", "\sE!$=>E", "\sQ!$=>Q",
  "Left arrow!=>Left", "Right arrow!=>Right", "Up arrow!=>Up", "Down arrow!=>Down",
  "Drag: hold Up=>^Up", "Drag: hold Down=>^Down", "Drag: hold Left=>^Left", "Drag: hold Right=>^Right",
  "Let go!=>Space") + $Extra
& (Join-Path $PSScriptRoot "onsay.ps1") -Rules $rules -Seconds $Seconds -Stop "ZZZZNEVER"
