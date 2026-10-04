using System.Diagnostics;
using System.IO.MemoryMappedFiles;
using System.Runtime.InteropServices;
using System.Text;

namespace TWDAccess;

/// <summary>
/// Listens for OutputDebugString messages (the classic DBWIN_BUFFER protocol, as used by
/// DebugView) and records the ones coming from the game process into logs/debug.log.
/// The engine reports script errors this way, which makes it our window into Lua failures.
/// </summary>
internal sealed class DebugMonitor : IDisposable
{
    private readonly Thread _thread;
    private volatile bool _stop;
    private EventWaitHandle? _bufferReady, _dataReady;
    private MemoryMappedFile? _buffer;

    public Action<string>? OnGameMessage { get; set; }

    public DebugMonitor()
    {
        _thread = new Thread(Run) { IsBackground = true, Name = "Debug monitor" };
    }

    public bool Start()
    {
        try
        {
            _bufferReady = new EventWaitHandle(false, EventResetMode.AutoReset, "DBWIN_BUFFER_READY", out _);
            _dataReady = new EventWaitHandle(false, EventResetMode.AutoReset, "DBWIN_DATA_READY", out _);
            _buffer = MemoryMappedFile.CreateOrOpen("DBWIN_BUFFER", 4096, MemoryMappedFileAccess.ReadWrite);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or WaitHandleCannotBeOpenedException)
        {
            Log.Write("Debug monitor unavailable: " + ex.Message);
            return false;
        }
        _thread.Start();
        return true;
    }

    private void Run()
    {
        using var view = _buffer!.CreateViewAccessor(0, 4096, MemoryMappedFileAccess.Read);
        var bytes = new byte[4096 - 4];
        var pidNames = new Dictionary<int, string>();
        while (!_stop)
        {
            _bufferReady!.Set();
            if (!_dataReady!.WaitOne(500)) continue;

            int pid = view.ReadInt32(0);
            view.ReadArray(4, bytes, 0, bytes.Length);
            int len = Array.IndexOf(bytes, (byte)0);
            if (len < 0) len = bytes.Length;
            string message = Encoding.Default.GetString(bytes, 0, len).TrimEnd('\r', '\n');

            if (!pidNames.TryGetValue(pid, out var name))
            {
                try { name = Process.GetProcessById(pid).ProcessName; }
                catch (ArgumentException) { name = "?"; }
                pidNames[pid] = name;
            }
            if (!name.Equals("WDC", StringComparison.OrdinalIgnoreCase)) continue;

            Log.Append("debug.log", message);
            OnGameMessage?.Invoke(message);
        }
    }

    public void Dispose()
    {
        _stop = true;
        _thread.Join(1000);
        _buffer?.Dispose();
        _bufferReady?.Dispose();
        _dataReady?.Dispose();
    }
}
