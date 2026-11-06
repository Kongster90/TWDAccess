namespace TWDAccess;

/// <summary>
/// The tabkey setting in the game folder's TWDAccess\settings.txt (settings.lua): Tab, or a letter
/// the mod uses in its place. Read as the helper starts, to leave out the Steam overlay warning when
/// the mod does not use Shift+Tab, and to say once when the setting cannot be used: the mod only
/// logs that, since its scripts start again with every scene in Season One.
/// </summary>
internal static class TabKey
{
    // The letters the mod refuses, and why (settings.lua keeps the same list).
    private static readonly Dictionary<char, string> Taken = new()
    {
        ['W'] = "walks", ['A'] = "walks", ['S'] = "walks", ['D'] = "walks",
        ['Z'] = "walks on French keyboards",
        ['Q'] = "is used in action scenes", ['E'] = "is used in action scenes",
        ['T'] = "shows the game's labels", ['F'] = "uses things in The Final Season",
        ['P'] = "is a key of the game's", ['R'] = "draws the bow",
    };

    /// <summary>Moved: the mod uses a letter instead of Tab. Problem: what to say when the setting
    /// cannot be used (the mod then keeps Tab); null when it can, or is not there.</summary>
    public static (bool Moved, string? Problem) Read(string gameDir)
    {
        string path = Path.Combine(gameDir, "TWDAccess", "settings.txt");
        string? value = null;
        try
        {
            foreach (string line in File.ReadLines(path))
            {
                string[] parts = line.Split('=', 2);
                if (parts.Length == 2 && parts[0].Trim() == "tabkey") value = parts[1].Trim();
            }
        }
        catch (IOException) { }
        if (value == null) return (false, null);
        Log.Write($"tabkey = {value}");
        string key = value.ToUpperInvariant();
        if (key == "TAB") return (false, null);
        if (key == "") return (false, "The tabkey setting is empty. Using Tab.");
        if (key.Length == 1 && key[0] >= 'A' && key[0] <= 'Z')
        {
            if (!Taken.TryGetValue(key[0], out string? why)) return (true, null);
            return (false, $"The tabkey setting, {value}, cannot be used: {key} {why}. Using Tab. Choose another letter in settings.txt.");
        }
        return (false, $"The tabkey setting, {value}, cannot be used: it must be Tab or a letter. Using Tab. Choose another letter in settings.txt.");
    }
}
