using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace TWDAccess;

/// <summary>Finds the game's install folder through Steam's library manifests.</summary>
internal static class GameLocator
{
    public const string AppId = "1449690";
    public const string ExeName = "WDC.exe";

    public static string? SteamPath() =>
        Registry.GetValue(@"HKEY_CURRENT_USER\Software\Valve\Steam", "SteamPath", null) as string
        ?? Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath", null) as string;

    /// <summary>Whether a game folder is a Steam copy (in a Steam library), not GOG's or another.</summary>
    public static bool IsSteamCopy(string gameDir) =>
        gameDir.Replace('/', '\\').Contains(@"\steamapps\common\", StringComparison.OrdinalIgnoreCase);

    public static string? Find()
    {
        var steamPath = SteamPath();
        if (steamPath == null) return null;

        var libraries = new List<string> { steamPath };
        string vdf = Path.Combine(steamPath, "steamapps", "libraryfolders.vdf");
        if (File.Exists(vdf))
        {
            foreach (Match m in Regex.Matches(File.ReadAllText(vdf), "\"path\"\\s*\"([^\"]+)\""))
                libraries.Add(m.Groups[1].Value.Replace(@"\\", @"\"));
        }

        foreach (var lib in libraries.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            string manifest = Path.Combine(lib, "steamapps", $"appmanifest_{AppId}.acf");
            if (!File.Exists(manifest)) continue;
            var m = Regex.Match(File.ReadAllText(manifest), "\"installdir\"\\s*\"([^\"]+)\"");
            if (!m.Success) continue;
            string dir = Path.Combine(lib, "steamapps", "common", m.Groups[1].Value);
            if (File.Exists(Path.Combine(dir, ExeName))) return Path.GetFullPath(dir);
        }
        return null;
    }
}
