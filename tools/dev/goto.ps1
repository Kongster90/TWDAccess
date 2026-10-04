<#
  Development helper: press a key until TWD Access says something matching a pattern, then
  optionally press Enter.  .\goto.ps1 -Target "About" -Enter
#>
param([string]$Target, [string]$Key = "Down", [int]$Max = 12, [switch]$Enter, [int]$SettleMs = 4500)

$step = Join-Path $PSScriptRoot "step.ps1"
for ($i = 0; $i -lt $Max; $i++) {
    $said = & $step -Keys $Key -SettleMs 900
    $said
    if (($said | Out-String) -match [regex]::Escape($Target)) {
        if ($Enter) { & $step -Keys Enter -SettleMs $SettleMs }
        exit 0
    }
}
"never reached '$Target'"
exit 1
