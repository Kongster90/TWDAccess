using System.Text;

namespace TWDAccess;

/// <summary>Thread-safe append-only logging into the "logs" folder next to the executable.</summary>
internal static class Log
{
    private static readonly object Gate = new();
    private static readonly UTF8Encoding Utf8NoBom = new(false);

    public static string Directory { get; } = Path.Combine(AppContext.BaseDirectory, "logs");

    public static bool Echo { get; set; } = true;

    static Log()
    {
        System.IO.Directory.CreateDirectory(Directory);
    }

    public static void Write(string message) => Append("TWDAccess.log", message, Echo);

    /// <summary>Appends a timestamped line to a named log file in the logs folder.</summary>
    public static void Append(string fileName, string message, bool echo = false)
    {
        string line = $"{DateTime.Now:HH:mm:ss.fff} {message}";
        lock (Gate)
        {
            File.AppendAllText(Path.Combine(Directory, fileName), line + Environment.NewLine, Utf8NoBom);
            if (echo) Console.WriteLine(line);
        }
    }

    /// <summary>Appends raw text (already line-structured) to a named log file.</summary>
    public static void AppendRaw(string fileName, string text)
    {
        lock (Gate)
        {
            File.AppendAllText(Path.Combine(Directory, fileName), text, Utf8NoBom);
        }
    }
}
