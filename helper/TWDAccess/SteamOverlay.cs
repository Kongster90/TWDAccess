using System.Text;
using Microsoft.Win32;

namespace TWDAccess;

/// <summary>
/// Whether the Steam overlay is on for the game with its default shortcut, Shift+Tab, which the mod
/// also uses (back through Tab's list). Opened by mistake, the overlay takes the keys and the game
/// seems to lag; players reported "Tab and Shift+Tab lag the game" (2026-11-05), which did not happen
/// here, where the overlay is off. Read from the Steam user's userdata\ID\config\localconfig.vdf:
/// "system" > "EnableGameOverlay" (absent: on) and "InGameOverlayShortcutKey" (absent: Shift+Tab;
/// "KEY_NONE" when cleared), and "apps" > app id > "OverlayAppEnable" ("0": off for that game, set
/// by the game's Properties).
/// </summary>
internal static class SteamOverlay
{
    public const string Warning =
        "Note: the Steam overlay is on for this game and opens with Shift+Tab, which TWD Access also uses. " +
        "If the game seems to lag or stops taking keys, press Shift+Tab to close the overlay. " +
        "To turn it off: right-click the game in your Steam Library, choose Properties, and uncheck " +
        "Enable the Steam Overlay while in-game. The read-me has more.";

    /// <summary>True when the overlay would open with Shift+Tab in the game; false when not, or when
    /// Steam's settings cannot be read. What was found is logged.</summary>
    public static bool OpensWithShiftTab(string steamPath, string appId)
    {
        try
        {
            string? file = LocalConfig(steamPath);
            if (file == null)
            {
                Log.Write("Steam overlay: no localconfig.vdf found");
                return false;
            }
            bool result = OpensWithShiftTab(Vdf.Parse(File.ReadAllText(file)), appId, out string detail);
            Log.Write($"Steam overlay: {detail} ({file})");
            return result;
        }
        catch (Exception ex)
        {
            Log.Write($"Steam overlay: could not read Steam's settings: {ex.Message}");
            return false;
        }
    }

    public static bool OpensWithShiftTab(Dictionary<string, object> config, string appId, out string detail)
    {
        var root = Vdf.Child(config, "UserLocalConfigStore") ?? config;
        var system = Vdf.Child(root, "system");
        string? enabled = Vdf.Value(system, "EnableGameOverlay");
        string? shortcut = Vdf.Value(system, "InGameOverlayShortcutKey");
        // (The game's own switch: in the top "apps", and in Software\Valve\Steam\apps as well in case
        // a Steam version keeps it there.)
        string? forGame = Vdf.Value(Vdf.Child(Vdf.Child(root, "apps"), appId), "OverlayAppEnable")
            ?? Vdf.Value(Vdf.Child(Vdf.Child(Vdf.Child(Vdf.Child(Vdf.Child(root, "Software"), "Valve"), "Steam"), "apps"), appId),
                "OverlayAppEnable");
        bool on = enabled != "0" && forGame != "0";
        bool shiftTab = shortcut == null || IsShiftTab(shortcut);
        detail = $"overlay {(enabled == "0" ? "off" : "on")}, for this game {(forGame == "0" ? "off" : "on")}, " +
                 $"shortcut {(shortcut == null ? "Shift+Tab (the default)" : shortcut.Replace('\t', '+'))}";
        return on && shiftTab;
    }

    // "Shift\tKEY_TAB" (as Steam writes the default), and nothing else held with it.
    private static bool IsShiftTab(string shortcut)
    {
        var keys = shortcut.Split(new[] { '\t', ' ', '+' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(k => k.ToUpperInvariant().Replace("KEY_", "")).ToHashSet();
        return keys.SetEquals(new[] { "SHIFT", "TAB" });
    }

    // The signed-in user's file (ActiveProcess\ActiveUser, while Steam runs), else the one Steam wrote
    // last (TWD Access usually starts before Steam does).
    private static string? LocalConfig(string steamPath)
    {
        string userdata = Path.Combine(steamPath, "userdata");
        if (!Directory.Exists(userdata)) return null;
        if (Registry.GetValue(@"HKEY_CURRENT_USER\Software\Valve\Steam\ActiveProcess", "ActiveUser", null) is int user && user != 0)
        {
            string active = Path.Combine(userdata, ((uint)user).ToString(), "config", "localconfig.vdf");
            if (File.Exists(active)) return active;
        }
        return Directory.GetDirectories(userdata)
            .Select(d => Path.Combine(d, "config", "localconfig.vdf"))
            .Where(File.Exists)
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .FirstOrDefault();
    }
}

/// <summary>Steam's KeyValues text files: "key" "value" and "key" { ... }, keys in any case.</summary>
internal static class Vdf
{
    public static Dictionary<string, object> Parse(string text)
    {
        int i = 0;
        return Block(text, ref i);
    }

    public static Dictionary<string, object>? Child(Dictionary<string, object>? block, string key) =>
        block != null && block.TryGetValue(key, out var v) ? v as Dictionary<string, object> : null;

    public static string? Value(Dictionary<string, object>? block, string key) =>
        block != null && block.TryGetValue(key, out var v) ? v as string : null;

    private static Dictionary<string, object> Block(string text, ref int i)
    {
        var block = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        while (true)
        {
            string? key = Token(text, ref i, out bool brace);
            if (key == null || brace) return block; // (the end, or a closing brace)
            string? value = Token(text, ref i, out brace);
            if (brace && value == "{") block[key] = Block(text, ref i);
            else if (!brace && value != null) block[key] = value;
            else return block;
        }
    }

    // The next quoted (or bare) string; brace is set for "{" (and null returned for "}").
    private static string? Token(string text, ref int i, out bool brace)
    {
        brace = false;
        while (i < text.Length)
        {
            char c = text[i];
            if (char.IsWhiteSpace(c)) { i++; continue; }
            if (c == '/' && i + 1 < text.Length && text[i + 1] == '/')
            {
                while (i < text.Length && text[i] != '\n') i++;
                continue;
            }
            if (c == '{') { i++; brace = true; return "{"; }
            if (c == '}') { i++; brace = true; return null; }
            var sb = new StringBuilder();
            if (c == '"')
            {
                i++;
                while (i < text.Length && text[i] != '"')
                {
                    if (text[i] == '\\' && i + 1 < text.Length)
                    {
                        i++;
                        sb.Append(text[i] switch { 't' => '\t', 'n' => '\n', _ => text[i] });
                    }
                    else sb.Append(text[i]);
                    i++;
                }
                i++;
                return sb.ToString();
            }
            while (i < text.Length && !char.IsWhiteSpace(text[i]) && text[i] != '{' && text[i] != '}' && text[i] != '"')
                sb.Append(text[i++]);
            return sb.ToString();
        }
        return null;
    }
}
