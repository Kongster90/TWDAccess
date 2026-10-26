using System.Diagnostics;
using System.Runtime.InteropServices;

namespace TWDAccess;

/// <summary>
/// Turns the game's camera for the mod: The Final Season aims the bow with the mouse only, and the
/// game reads the mouse's relative movement, so the mod asks for small moves (/mouse?dx=..&dy=..)
/// while it brings a target to the middle of the screen. Moves are sent only while the game's
/// window is in front.
/// </summary>
internal static class Mouse
{
    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT { public uint type; public InputUnion u; }

    [DllImport("user32.dll")] private static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    private const uint MouseEventMove = 0x0001;
    private const int MaxStep = 400;

    private static bool GameInFront()
    {
        GetWindowThreadProcessId(GetForegroundWindow(), out uint pid);
        try
        {
            using var process = Process.GetProcessById((int)pid);
            return process.ProcessName.Equals("WDC", StringComparison.OrdinalIgnoreCase);
        }
        catch (ArgumentException)
        {
            return false;
        }
    }

    // (The game takes little of one large jump: a move is sent as steps of at most StepPixels, one
    // every StepMs, as a hand on the mouse would.)
    private const int StepPixels = 20;
    private const int StepMs = 8;

    public static string Move(int dx, int dy)
    {
        dx = Math.Clamp(dx, -MaxStep, MaxStep);
        dy = Math.Clamp(dy, -MaxStep, MaxStep);
        if (!GameInFront()) return "not in front";
        int steps = Math.Max(1, (Math.Max(Math.Abs(dx), Math.Abs(dy)) + StepPixels - 1) / StepPixels);
        int sentX = 0, sentY = 0;
        var input = new INPUT[1];
        input[0].type = 0;
        input[0].u.mi.dwFlags = MouseEventMove;
        for (int i = 1; i <= steps; i++)
        {
            int x = dx * i / steps, y = dy * i / steps;
            input[0].u.mi.dx = x - sentX;
            input[0].u.mi.dy = y - sentY;
            sentX = x;
            sentY = y;
            SendInput(1, input, Marshal.SizeOf<INPUT>());
            if (i < steps) Thread.Sleep(StepMs);
        }
        return "ok";
    }
}
