<#
  Development helper: the last -Lines meaningful lines of twda.log (no console echoes, no speaker
  names alone, no per-frame watcher calls).
    .\mlog.ps1 [-Lines 30] [-Tail 4000]
#>
param([int]$Lines = 30, [int]$Tail = 4000)
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$noise = 'Look_SetFocus|Reticle_SelectAgent|Drag_SelectAgent|Drag_DisableProximity|Drag_IsDragAgent|Station_AllowExit|console>'
Get-Content $log -Tail $Tail | Where-Object { $_ -match '^\d\d:\d\d:\d\d' -and $_ -notmatch $noise -and $_ -cnotmatch ' say [A-Z][\w ]*$' } |
    Select-Object -Last $Lines | ForEach-Object { $_.Substring(0, [Math]::Min(220, $_.Length)) }
