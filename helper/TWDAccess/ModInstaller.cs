using System.Security.Cryptography;

namespace TWDAccess;

/// <summary>
/// Copies the mod into the game folder and removes it again. The "mod" folder next to the helper
/// mirrors the game folder (Archives\DebugLoader.lua and TWDAccess\*.lua). Every installed file is
/// recorded with its SHA-256 in TWDAccess\installed.txt, and a file in Archives is only replaced or
/// deleted if its current hash is one we wrote, so another mod's files are never touched.
/// </summary>
internal static class ModInstaller
{
    private const string ModFolder = "TWDAccess";
    private const string ManifestName = "installed.txt";

    // Files kept across updates; they belong to the player.
    private static readonly string[] UserFiles = { "settings.txt", "twda.log" };

    // Files earlier test builds put in Archives, with the marker their plain text contained.
    private static readonly string[] LegacyArchiveFiles =
    {
        "_resdesc_50_TWDAccess.lua", "_resdesc_50_TWDAccessTxt.lua", "TWDAccess_installed.txt",
    };

    public static void Install(string gameDir)
    {
        string sourceRoot = Path.Combine(AppContext.BaseDirectory, "mod");
        if (!Directory.Exists(sourceRoot))
        {
            Log.Write($"Mod files missing from {sourceRoot}; not installing.");
            return;
        }
        try
        {
            RemoveLegacyFiles(gameDir);
            Directory.CreateDirectory(Path.Combine(gameDir, ModFolder));
            var manifest = ReadManifest(gameDir);
            var shipped = Directory.GetFiles(sourceRoot, "*", SearchOption.AllDirectories)
                .Select(f => Path.GetRelativePath(sourceRoot, f))
                .ToList();

            // Files from an older version that this one no longer ships.
            foreach (var stale in manifest.Keys.Except(shipped, StringComparer.OrdinalIgnoreCase).ToList())
            {
                string path = Path.Combine(gameDir, stale);
                if (File.Exists(path) && Hash(path) == manifest[stale]) File.Delete(path);
                manifest.Remove(stale);
            }

            int copied = 0;
            foreach (var relative in shipped)
            {
                string source = Path.Combine(sourceRoot, relative);
                string target = Path.Combine(gameDir, relative);
                string hash = Hash(source);
                if (File.Exists(target))
                {
                    string current = Hash(target);
                    if (current == hash)
                    {
                        manifest[relative] = hash;
                        continue;
                    }
                    bool ours = manifest.TryGetValue(relative, out var recorded) && recorded == current;
                    bool inModFolder = relative.StartsWith(ModFolder + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
                    if (!ours && !inModFolder)
                    {
                        Log.Write($"{target} belongs to another mod; not overwriting it. TWD Access cannot start until it is removed.");
                        continue;
                    }
                }
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                File.Copy(source, target, overwrite: true);
                manifest[relative] = hash;
                copied++;
            }
            WriteManifest(gameDir, manifest);
            Log.Write(copied == 0 ? "Mod files are up to date." : $"Installed {copied} mod file(s) into {gameDir}");
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"Could not install the mod: {ex.Message}");
        }
    }

    public static int Uninstall(string gameDir)
    {
        RemoveLegacyFiles(gameDir);
        var manifest = ReadManifest(gameDir);
        int removed = 0;
        foreach (var (relative, hash) in manifest)
        {
            string path = Path.Combine(gameDir, relative);
            if (File.Exists(path) && Hash(path) == hash)
            {
                File.Delete(path);
                removed++;
            }
        }
        string modDir = Path.Combine(gameDir, ModFolder);
        foreach (var name in UserFiles.Append(ManifestName))
        {
            string path = Path.Combine(modDir, name);
            if (File.Exists(path)) File.Delete(path);
        }
        if (Directory.Exists(modDir) && !Directory.EnumerateFileSystemEntries(modDir).Any())
            Directory.Delete(modDir);
        Console.WriteLine(removed == 0 ? "The mod is not installed." : $"Removed TWD Access ({removed} file(s)).");
        return 0;
    }

    private static void RemoveLegacyFiles(string gameDir)
    {
        string archives = Path.Combine(gameDir, "Archives");

        // Test builds kept their manifest ("sha256 name") in Archives.
        string legacyManifest = Path.Combine(archives, "TWDAccess_installed.txt");
        if (File.Exists(legacyManifest))
        {
            foreach (var line in File.ReadAllLines(legacyManifest))
            {
                var parts = line.Split(' ', 2, StringSplitOptions.TrimEntries);
                if (line.StartsWith('#') || parts.Length != 2) continue;
                string path = Path.Combine(archives, parts[1]);
                if (File.Exists(path) && Hash(path) == parts[0]) File.Delete(path);
            }
        }

        foreach (var name in LegacyArchiveFiles)
        {
            string path = Path.Combine(archives, name);
            if (!File.Exists(path)) continue;
            bool ours = name.EndsWith(".txt") ||
                        File.ReadAllBytes(path).AsSpan().IndexOf("TWD Access"u8) >= 0;
            if (ours) File.Delete(path);
        }
    }

    private static string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));

    private static Dictionary<string, string> ReadManifest(string gameDir)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        string path = Path.Combine(gameDir, ModFolder, ManifestName);
        if (!File.Exists(path)) return result;
        foreach (var line in File.ReadAllLines(path))
        {
            if (line.StartsWith('#')) continue;
            var parts = line.Split(' ', 2, StringSplitOptions.TrimEntries);
            if (parts.Length == 2) result[parts[1]] = parts[0];
        }
        return result;
    }

    private static void WriteManifest(string gameDir, Dictionary<string, string> manifest)
    {
        var lines = new List<string> { "# Files installed by TWD Access (sha256 path). Used for updates and uninstall." };
        lines.AddRange(manifest.Select(kv => $"{kv.Value} {kv.Key}"));
        File.WriteAllLines(Path.Combine(gameDir, ModFolder, ManifestName), lines);
    }
}
