using System.Collections.Concurrent;
using System.Text;

namespace TWDAccess;

/// <summary>
/// Owns the Prism context and backend on a single dedicated thread, since Prism backend
/// instances are not thread-safe. Everything else just enqueues requests.
/// </summary>
internal sealed class Speech : IDisposable
{
    private readonly record struct Request(string? Text, bool Interrupt, bool Stop);

    private readonly BlockingCollection<Request> _queue = new();
    private readonly Thread _thread;
    private readonly string? _preferredBackend;
    private readonly ManualResetEventSlim _ready = new(false);

    public string BackendName { get; private set; } = "none";
    public string? LastSpoken { get; private set; }

    public Speech(string? preferredBackend)
    {
        _preferredBackend = preferredBackend;
        _thread = new Thread(Run) { IsBackground = true, Name = "Prism speech" };
        // SAPI and OneCore are COM based; give them an apartment of their own.
        _thread.SetApartmentState(ApartmentState.STA);
        _thread.Start();
        _ready.Wait(TimeSpan.FromSeconds(10));
    }

    public void Say(string text, bool interrupt = false)
    {
        text = Clean(text);
        if (text.Length == 0) return;
        LastSpoken = text;
        _queue.Add(new Request(text, interrupt, false));
    }

    public void Stop() => _queue.Add(new Request(null, true, true));

    public void RepeatLast()
    {
        if (LastSpoken != null) _queue.Add(new Request(LastSpoken, true, false));
    }

    private void Run()
    {
        IntPtr ctx = IntPtr.Zero, backend = IntPtr.Zero;
        try
        {
            ctx = Prism.prism_init(IntPtr.Zero);
            if (ctx == IntPtr.Zero)
            {
                Log.Write("Prism: prism_init failed");
                return;
            }
            Log.Write($"Prism {Prism.Str(Prism.prism_version_string())} initialised; backends: {DescribeBackends(ctx)}");

            if (!string.IsNullOrWhiteSpace(_preferredBackend))
            {
                ulong id = Prism.prism_registry_id(ctx, _preferredBackend!);
                if (id != 0)
                {
                    backend = Prism.prism_registry_acquire(ctx, id);
                    if (backend != IntPtr.Zero)
                    {
                        int err = Prism.prism_backend_initialize(backend);
                        if (err != Prism.PRISM_OK && err != Prism.PRISM_ERROR_ALREADY_INITIALIZED)
                        {
                            Log.Write($"Prism: backend '{_preferredBackend}' failed to initialise: {Prism.ErrorString(err)}");
                            Prism.prism_backend_free(backend);
                            backend = IntPtr.Zero;
                        }
                    }
                }
                else
                {
                    Log.Write($"Prism: unknown backend name '{_preferredBackend}', using the best available one");
                }
            }

            if (backend == IntPtr.Zero)
                backend = Prism.prism_registry_acquire_best(ctx);
            if (backend == IntPtr.Zero)
            {
                Log.Write("Prism: no speech backend is available");
                return;
            }

            BackendName = Prism.Str(Prism.prism_backend_name(backend));
            Log.Write($"Prism: using backend {BackendName}");
        }
        finally
        {
            _ready.Set();
        }

        foreach (var req in _queue.GetConsumingEnumerable())
        {
            try
            {
                if (req.Stop)
                {
                    _ = Prism.prism_backend_stop(backend);
                    continue;
                }
                int err = Prism.prism_backend_output(backend, req.Text!, req.Interrupt);
                if (err == Prism.PRISM_ERROR_NOT_IMPLEMENTED)
                    err = Prism.prism_backend_speak(backend, req.Text!, req.Interrupt);
                if (err != Prism.PRISM_OK)
                    Log.Write($"Prism: output failed ({Prism.ErrorString(err)}) for: {req.Text}");
            }
            catch (Exception ex)
            {
                Log.Write("Prism: exception while speaking: " + ex.Message);
            }
        }

        Prism.prism_backend_free(backend);
        Prism.prism_shutdown(ctx);
    }

    private static string DescribeBackends(IntPtr ctx)
    {
        var names = new List<string>();
        ulong count = (ulong)Prism.prism_registry_count(ctx);
        for (ulong i = 0; i < count; i++)
        {
            ulong id = Prism.prism_registry_id_at(ctx, (UIntPtr)i);
            names.Add(Prism.Str(Prism.prism_registry_name(ctx, id)));
        }
        return string.Join(", ", names);
    }

    /// <summary>Strips control characters and simple markup tags, and collapses whitespace.</summary>
    public static string Clean(string text)
    {
        var sb = new StringBuilder(text.Length);
        bool inTag = false;
        foreach (char c in text)
        {
            if (c == '<') { inTag = true; continue; }
            if (inTag) { if (c == '>') inTag = false; continue; }
            sb.Append(char.IsControl(c) ? ' ' : c);
        }
        // An unmatched '<' would swallow the rest; fall back to the raw text in that case.
        string s = inTag ? text : sb.ToString();
        return string.Join(' ', s.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
    }

    public void Dispose()
    {
        _queue.CompleteAdding();
        _thread.Join(TimeSpan.FromSeconds(2));
    }
}
