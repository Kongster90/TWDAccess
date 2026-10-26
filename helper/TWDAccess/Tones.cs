using System.Globalization;
using System.Runtime.InteropServices;

namespace TWDAccess;

/// <summary>
/// Short tones for the mod's sound beacons (/tone): a small mixer on one waveOut stream, so tones
/// overlap and each has its own pan, volume, pitch and waveform. The mod works out where a thing is
/// from the camera and sends a tone for it: panned left or right, quieter further away, muffled
/// when behind.
/// </summary>
internal sealed class Tones : IDisposable
{
    private const int SampleRate = 44100;
    private const int FramesPerBuffer = 1024; // about 23 ms
    private const int BufferCount = 4;

    [StructLayout(LayoutKind.Sequential)]
    private struct WAVEFORMATEX
    {
        public ushort wFormatTag, nChannels;
        public uint nSamplesPerSec, nAvgBytesPerSec;
        public ushort nBlockAlign, wBitsPerSample, cbSize;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct WAVEHDR
    {
        public IntPtr lpData;
        public uint dwBufferLength, dwBytesRecorded;
        public IntPtr dwUser;
        public uint dwFlags, dwLoops;
        public IntPtr lpNext, reserved;
    }

    [DllImport("winmm.dll")] private static extern int waveOutOpen(out IntPtr hwo, uint device, ref WAVEFORMATEX format, IntPtr callback, IntPtr instance, uint flags);
    [DllImport("winmm.dll")] private static extern int waveOutPrepareHeader(IntPtr hwo, IntPtr header, int size);
    [DllImport("winmm.dll")] private static extern int waveOutWrite(IntPtr hwo, IntPtr header, int size);
    [DllImport("winmm.dll")] private static extern int waveOutUnprepareHeader(IntPtr hwo, IntPtr header, int size);
    [DllImport("winmm.dll")] private static extern int waveOutReset(IntPtr hwo);
    [DllImport("winmm.dll")] private static extern int waveOutClose(IntPtr hwo);

    private const uint WaveMapper = 0xFFFFFFFF;
    private const uint CallbackEvent = 0x00050000;
    private const uint WhdrDone = 0x00000001;

    private sealed class Voice
    {
        public double[] Freqs = Array.Empty<double>();
        public int NoteFrames, Frame;
        public double Phase, Left, Right, Low;
        public char Wave;
        public bool Muffled;
    }

    private readonly List<Voice> _voices = new();
    private readonly AutoResetEvent _done = new(false);
    private readonly Thread? _thread;
    private readonly Random _random = new();
    private IntPtr _device;
    private volatile bool _stop;

    public Tones()
    {
        var format = new WAVEFORMATEX
        {
            wFormatTag = 1, nChannels = 2, nSamplesPerSec = SampleRate, wBitsPerSample = 16,
            nBlockAlign = 4, nAvgBytesPerSec = SampleRate * 4,
        };
        int result = waveOutOpen(out _device, WaveMapper, ref format, _done.SafeWaitHandle.DangerousGetHandle(), IntPtr.Zero, CallbackEvent);
        if (result != 0)
        {
            Log.Write($"Tones: no sound output (waveOutOpen {result})");
            _device = IntPtr.Zero;
            return;
        }
        _thread = new Thread(Run) { IsBackground = true, Name = "Tones", Priority = ThreadPriority.AboveNormal };
        _thread.Start();
    }

    /// <summary>
    /// Queues a tone. Query: f = frequency in Hz, or several "660,880" played one after another;
    /// ms = length of each note; p = pan, -1 left to 1 right; v = volume 0 to 1; w = s(ine),
    /// q(square), t(riangle) or n(oise); lp = 1 muffles it (behind).
    /// </summary>
    public string Play(Func<string, string?> query)
    {
        if (_device == IntPtr.Zero) return "no sound";
        double Num(string key, double fallback) =>
            double.TryParse(query(key), NumberStyles.Float, CultureInfo.InvariantCulture, out double v) ? v : fallback;
        var freqs = (query("f") ?? "880").Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out double f) ? Math.Clamp(f, 40, 8000) : 880)
            .Take(8).ToArray();
        double pan = Math.Clamp(Num("p", 0), -1, 1), volume = Math.Clamp(Num("v", 0.3), 0, 1);
        int ms = (int)Math.Clamp(Num("ms", 60), 10, 1000);
        // (Equal-power panning.)
        double angle = (pan + 1) * Math.PI / 4;
        var voice = new Voice
        {
            Freqs = freqs.Length > 0 ? freqs : new[] { 880.0 },
            NoteFrames = SampleRate * ms / 1000,
            Left = Math.Cos(angle) * volume,
            Right = Math.Sin(angle) * volume,
            Wave = (query("w") ?? "s").FirstOrDefault('s'),
            Muffled = query("lp") == "1",
        };
        lock (_voices)
        {
            if (_voices.Count < 24) _voices.Add(voice);
        }
        return "ok";
    }

    private void Run()
    {
        int bytes = FramesPerBuffer * 4;
        var headers = new IntPtr[BufferCount];
        var data = new IntPtr[BufferCount];
        int headerSize = Marshal.SizeOf<WAVEHDR>();
        var samples = new short[FramesPerBuffer * 2];
        for (int i = 0; i < BufferCount; i++)
        {
            data[i] = Marshal.AllocHGlobal(bytes);
            headers[i] = Marshal.AllocHGlobal(headerSize);
            var header = new WAVEHDR { lpData = data[i], dwBufferLength = (uint)bytes };
            Marshal.StructureToPtr(header, headers[i], false);
            waveOutPrepareHeader(_device, headers[i], headerSize);
            Fill(samples);
            Marshal.Copy(samples, 0, data[i], samples.Length);
            waveOutWrite(_device, headers[i], headerSize);
        }
        try
        {
            while (!_stop)
            {
                _done.WaitOne(100);
                for (int i = 0; i < BufferCount && !_stop; i++)
                {
                    var header = Marshal.PtrToStructure<WAVEHDR>(headers[i]);
                    if ((header.dwFlags & WhdrDone) == 0) continue;
                    Fill(samples);
                    Marshal.Copy(samples, 0, data[i], samples.Length);
                    header.dwFlags &= ~WhdrDone;
                    Marshal.StructureToPtr(header, headers[i], false);
                    waveOutWrite(_device, headers[i], headerSize);
                }
            }
        }
        finally
        {
            waveOutReset(_device);
            for (int i = 0; i < BufferCount; i++)
            {
                waveOutUnprepareHeader(_device, headers[i], headerSize);
                Marshal.FreeHGlobal(headers[i]);
                Marshal.FreeHGlobal(data[i]);
            }
        }
    }

    private void Fill(short[] samples)
    {
        Array.Clear(samples);
        lock (_voices)
        {
            for (int v = _voices.Count - 1; v >= 0; v--)
            {
                if (!Mix(_voices[v], samples)) _voices.RemoveAt(v);
            }
        }
    }

    // Adds one voice to the buffer; false when it has finished.
    private bool Mix(Voice voice, short[] samples)
    {
        int total = voice.NoteFrames * voice.Freqs.Length;
        int fade = Math.Max(1, Math.Min(voice.NoteFrames / 4, SampleRate / 200)); // (no clicks: 5 ms ends)
        for (int i = 0; i < FramesPerBuffer; i++)
        {
            if (voice.Frame >= total) return false;
            int note = voice.Frame / voice.NoteFrames, inNote = voice.Frame % voice.NoteFrames;
            double envelope = Math.Min(1, Math.Min(inNote, voice.NoteFrames - inNote) / (double)fade);
            voice.Phase += voice.Freqs[note] / SampleRate;
            if (voice.Phase >= 1) voice.Phase -= Math.Floor(voice.Phase);
            double s = voice.Wave switch
            {
                'q' => voice.Phase < 0.5 ? 0.6 : -0.6,
                't' => 4 * Math.Abs(voice.Phase - 0.5) - 1,
                'n' => _random.NextDouble() * 2 - 1,
                _ => Math.Sin(2 * Math.PI * voice.Phase),
            };
            if (voice.Muffled)
            {
                voice.Low += (s - voice.Low) * 0.08;
                s = voice.Low * 1.6;
            }
            s *= envelope * 0.5;
            int l = samples[i * 2] + (int)(s * voice.Left * short.MaxValue);
            int r = samples[i * 2 + 1] + (int)(s * voice.Right * short.MaxValue);
            samples[i * 2] = (short)Math.Clamp(l, short.MinValue, short.MaxValue);
            samples[i * 2 + 1] = (short)Math.Clamp(r, short.MinValue, short.MaxValue);
            voice.Frame++;
        }
        return true;
    }

    public void Dispose()
    {
        _stop = true;
        _done.Set();
        _thread?.Join(500);
        if (_device != IntPtr.Zero) waveOutClose(_device);
        _done.Dispose();
    }
}
