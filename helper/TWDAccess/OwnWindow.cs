using System.Diagnostics;

namespace TWDAccess;

/// <summary>
/// The "streaming" setting. Windows 11 shows console programs in Windows Terminal, whose window
/// belongs to WindowsTerminal.exe, so OBS's Application Audio Capture cannot pick TWDAccess.exe,
/// the program that plays the mod's tones. With streaming = true in the game folder's
/// TWDAccess\settings.txt, the helper starts itself again in the classic console (conhost.exe),
/// whose window Windows reports as TWDAccess.exe's own.
/// </summary>
internal static class OwnWindow
{
    // Set for the second copy, so it never starts a third.
    private const string RelaunchedVariable = "TWDACCESS_OWN_WINDOW";

    /// <summary>True when a copy in its own window was started; this one should then exit.</summary>
    public static bool Relaunch(string gameDir, string[] args)
    {
        if (!SettingOn(gameDir) || Environment.GetEnvironmentVariable(RelaunchedVariable) != null
            || Console.IsOutputRedirected || Process.GetCurrentProcess().MainWindowHandle != IntPtr.Zero)
            return false;
        var start = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "conhost.exe")) { UseShellExecute = false };
        start.ArgumentList.Add(Environment.ProcessPath!);
        foreach (string arg in args) start.ArgumentList.Add(arg);
        start.Environment[RelaunchedVariable] = "1";
        try
        {
            Process.Start(start);
        }
        catch (Exception ex)
        {
            Log.Write($"streaming = true, but the classic console could not be started: {ex.Message}");
            return false;
        }
        Log.Write("streaming = true: started again in a window of its own (conhost.exe)");
        return true;
    }

    private static bool SettingOn(string gameDir)
    {
        string path = Path.Combine(gameDir, "TWDAccess", "settings.txt");
        try
        {
            foreach (string line in File.ReadLines(path))
            {
                string[] parts = line.Split('=', 2);
                if (parts.Length == 2 && parts[0].Trim() == "streaming") return parts[1].Trim() == "true";
            }
        }
        catch (IOException) { }
        return false;
    }
}
