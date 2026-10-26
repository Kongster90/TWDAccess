<#
  Development helper: close foobar2000's "Playback error" boxes, which the user's music player
  sometimes puts over the game (the user allowed closing them, 2026-10-25). Only windows of that
  exact title owned by foobar2000 are closed. With -Watch it checks every 10 seconds.
    .\close_playback_errors.ps1 [-Watch -Seconds 20000]
#>
param([switch]$Watch, [int]$Seconds = 20000)
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public static class PlaybackErrors {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
"@
function CloseThem {
    $found = New-Object System.Collections.ArrayList
    [PlaybackErrors]::EnumWindows({ param($h, $l)
        $sb = New-Object System.Text.StringBuilder 256
        [void][PlaybackErrors]::GetWindowText($h, $sb, 256)
        if ($sb.ToString() -eq "Playback error" -and [PlaybackErrors]::IsWindowVisible($h)) { [void]$found.Add($h) }
        $true }, [IntPtr]::Zero) | Out-Null
    foreach ($h in $found) {
        $procId = 0
        [void][PlaybackErrors]::GetWindowThreadProcessId($h, [ref]$procId)
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -like "foobar*") {
            [PlaybackErrors]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
            "{0} closed a Playback error box" -f (Get-Date -Format "HH:mm:ss")
        }
    }
}
if (-not $Watch) { CloseThem; exit 0 }
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) { CloseThem; Start-Sleep -Seconds 10 }
