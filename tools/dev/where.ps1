<#
  Development helper: hold a key for -Ms milliseconds (keeping the game focused), then print Lee's
  position, the scene camera and whether he is dying. For finding routes that have no hotspots.
    .\where.ps1 -Key W -Ms 2000
#>
param([string]$Key = "", [int]$Ms = 0)
$dev = $PSScriptRoot
if ($Key) { & "$dev\holdkey.ps1" -Key $Key -Ms $Ms | Out-Null }
& "$dev\console.ps1" 'local l = AgentGetWorldPos(Game_GetPlayer()) return ("lee=(%.1f,%.1f,%.1f) cam=%s dying=%s"):format(l.x, l.y, l.z, TWDA.agentName(SceneGetCamera(SceneGetBottomScene())), tostring(Logic["Dying"]))' -WaitMs 500 | Select-Object -Last 1
