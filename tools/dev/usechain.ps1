<#
  Development helper: use things in turn through DEV.use (devuse.lua, armed first), letting each
  conversation run (talk.ps1, answering 1) before the next. Items are "Name" or "Name#2" (the
  second action). Stops at the first item the scene does not offer.
    .\usechain.ps1 -Items "Lilly's Door","Clementine","Chalk X#2"
#>
param([string[]]$Items, [int]$Quiet = 8)
$dev = $PSScriptRoot
foreach ($item in $Items) {
    $name, $index = $item -split "#", 2
    $lua = if ($index) { "return DEV.use(`"$name`", false, $index)" } else { "return DEV.use(`"$name`")" }
    $r = & "$dev\console.ps1" $lua | Select-Object -Last 1
    "$item -> $r"
    if ($r -match "none") { break }
    & "$dev\talk.ps1" -Answers 1 -Seconds 120 -Quiet $Quiet | Select-Object -Last 2
}
