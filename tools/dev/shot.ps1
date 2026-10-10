<#
  Development helper: save a screenshot of the game window (for describing drawn pages and panels).
    .\shot.ps1 -Out C:\path\name.png
#>
param([Parameter(Mandatory)][string]$Out)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class ShotWin { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); public struct RECT { public int L, T, R, B; } }
"@
$p = Get-Process WDC | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$r = New-Object ShotWin+RECT
[void][ShotWin]::GetWindowRect($p.MainWindowHandle, [ref]$r)
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"saved $Out"
