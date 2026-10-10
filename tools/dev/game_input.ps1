<#
  Development helper: sends input to the running game window (WDC.exe) for automated testing.

  Examples:
    .\game_input.ps1 -Click 0.5,0.85          # click at 50% width, 85% height of the game window
    .\game_input.ps1 -Keys Enter              # press Enter
    .\game_input.ps1 -Keys Down,Down,Enter    # several keys, with a short pause between them
    .\game_input.ps1 -Screenshot out.png      # save a half-size screenshot of the screen
    .\game_input.ps1 -Focus                   # only bring the game window to the front
    .\game_input.ps1 -Keys W -HoldMs 2000     # hold a key down (walking)
#>
param(
    [switch]$Focus,
    [double[]]$Click,
    [string[]]$Keys,
    [int]$DelayMs = 250,
    [int]$HoldMs = 60,
    [string]$Screenshot
)

Add-Type -Language CSharp @"
using System;
using System.Runtime.InteropServices;
public static class GameInput {
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] struct UNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public UNION u; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint mapType);
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);

    // Returns true only if the window really is in the foreground afterwards.
    public static bool Focus(IntPtr h) {
        if (GetForegroundWindow() == h) return true;
        uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
        uint me = GetCurrentThreadId();
        AttachThreadInput(me, fgThread, true);
        // Tapping Alt also lifts the foreground lock for background processes.
        keybd_event(0x12, 0, 0, IntPtr.Zero);
        keybd_event(0x12, 0, 2, IntPtr.Zero);
        ShowWindow(h, 9);
        BringWindowToTop(h);
        SetForegroundWindow(h);
        AttachThreadInput(me, fgThread, false);
        System.Threading.Thread.Sleep(200);
        return GetForegroundWindow() == h;
    }
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        var a = new INPUT[2];
        a[0].type = 0; a[0].u.mi.dwFlags = 0x0002;
        a[1].type = 0; a[1].u.mi.dwFlags = 0x0004;
        SendInput(2, a, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void Key(ushort vk, bool extended, int hold) {
        ushort scan = (ushort)MapVirtualKey(vk, 0);
        uint ext = extended ? 1u : 0u;
        var a = new INPUT[2];
        a[0].type = 1; a[0].u.ki.wVk = vk; a[0].u.ki.wScan = scan; a[0].u.ki.dwFlags = 0x0008 | ext;
        a[1].type = 1; a[1].u.ki.wVk = vk; a[1].u.ki.wScan = scan; a[1].u.ki.dwFlags = 0x0008 | 0x0002 | ext;
        SendInput(1, new[] { a[0] }, Marshal.SizeOf(typeof(INPUT)));
        System.Threading.Thread.Sleep(hold);
        SendInput(1, new[] { a[1] }, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void KeyState(ushort vk, bool down) {
        var a = new INPUT[1];
        a[0].type = 1; a[0].u.ki.wVk = vk; a[0].u.ki.wScan = (ushort)MapVirtualKey(vk, 0);
        // (Arrows, Page Up/Down, Home, End, Insert and Delete need the extended flag, or they
        // arrive as number-pad keys.)
        uint ext = ((vk >= 0x21 && vk <= 0x28) || vk == 0x2D || vk == 0x2E) ? 1u : 0u;
        a[0].u.ki.dwFlags = 0x0008u | ext | (down ? 0u : 0x0002u);
        SendInput(1, a, Marshal.SizeOf(typeof(INPUT)));
    }
}
"@

$vk = @{
    Enter = 0x0D; Escape = 0x1B; Space = 0x20; Tab = 0x09; Backspace = 0x08
    Left = 0x25; Up = 0x26; Right = 0x27; Down = 0x28
    F1 = 0x70; F2 = 0x71; F3 = 0x72; F4 = 0x73; F5 = 0x74; F6 = 0x75; F7 = 0x76; F8 = 0x77; F9 = 0x78; F10 = 0x79; F11 = 0x7A; F12 = 0x7B; PageUp = 0x21; PageDown = 0x22; Delete = 0x2E; Home = 0x24; End = 0x23
}
$extended = @('Left', 'Up', 'Right', 'Down', 'PageUp', 'PageDown', 'Delete', 'Home', 'End')

if ($Click -or $Keys -or $Focus) {
    $proc = Get-Process WDC -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $proc) { Write-Error "The game window was not found."; exit 1 }
    $h = $proc.MainWindowHandle
    if (-not [GameInput]::Focus($h)) { Write-Error "Could not bring the game window to the front; no input sent."; exit 1 }
    Start-Sleep -Milliseconds 300

    if ($Click) {
        $r = New-Object GameInput+RECT
        [void][GameInput]::GetWindowRect($h, [ref]$r)
        $x = [int]($r.Left + ($r.Right - $r.Left) * $Click[0])
        $y = [int]($r.Top + ($r.Bottom - $r.Top) * $Click[1])
        [GameInput]::Click($x, $y)
        "clicked $x,$y"
        Start-Sleep -Milliseconds $DelayMs
    }
    foreach ($combo in $Keys) {
        # "Shift+Tab": modifiers are held while the last key is pressed.
        $parts = $combo -split '\+'
        $k = $parts[-1]
        $mods = @($parts | Select-Object -SkipLast 1 | ForEach-Object { @{ Shift = 0x10; Ctrl = 0x11; Alt = 0x12 }[$_] })
        if ($vk.ContainsKey($k)) { $code = $vk[$k] }
        elseif ($k.Length -eq 1) { $code = [int][char]$k.ToUpper() }
        else { Write-Error "Unknown key $k"; continue }
        foreach ($m in $mods) { [GameInput]::KeyState([uint16]$m, $true); Start-Sleep -Milliseconds 30 }
        [GameInput]::Key([uint16]$code, $extended -contains $k, $HoldMs)
        foreach ($m in $mods) { [GameInput]::KeyState([uint16]$m, $false) }
        "pressed $combo"
        Start-Sleep -Milliseconds $DelayMs
    }
}

if ($Screenshot) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
    $small = New-Object System.Drawing.Bitmap $bmp, ([int]($b.Width / 2)), ([int]($b.Height / 2))
    $small.Save($Screenshot, [System.Drawing.Imaging.ImageFormat]::Png)
    "saved $Screenshot"
}
