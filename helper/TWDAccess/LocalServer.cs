using System.Net;
using System.Net.Sockets;
using System.Text;

namespace TWDAccess;

/// <summary>
/// A deliberately tiny HTTP/1.1 server bound to the loopback interface only. The game's Lua
/// sends speech and log lines here using the engine's built-in HTTP functions.
///
/// Routes (body is UTF-8 text; GET requests may pass the text as ?t=...):
///   /say    queue speech          /sayi   interrupt, then speak
///   /stop   stop speech           /log    append lines to logs/game.log
///   /cmd    returns queued commands for the game (one per line)
///   /tone   a short panned tone (Tones.cs)   /mouse  a relative mouse move (Mouse.cs)
/// Anything else is recorded in logs/requests.log so unknown request shapes can be studied.
/// </summary>
internal sealed class LocalServer
{
    private const int MaxHeaderBytes = 64 * 1024;
    private const int MaxBodyBytes = 4 * 1024 * 1024;
    private const string CrLf = "\r\n";

    private readonly TcpListener _listener;
    private readonly Speech _speech;
    private readonly CancellationTokenSource _cts = new();
    private readonly Queue<string> _commands = new();
    private readonly Tones _tones = new();

    public int Port { get; }
    public DateTime LastRequestUtc { get; private set; }
    public long RequestCount;

    private readonly SpeechSequencer _sequencer;

    public LocalServer(int port, Speech speech)
    {
        Port = port;
        _speech = speech;
        _sequencer = new SpeechSequencer(Deliver);
        _listener = new TcpListener(IPAddress.Loopback, port);
    }

    /// <summary>A /speak batch: one message per line, "flag TAB text"; i = interrupt, q = queue, s = stop.</summary>
    private void Deliver(string payload)
    {
        foreach (var line in payload.Split('\n'))
        {
            int tab = line.IndexOf('\t');
            string flag = tab >= 0 ? line[..tab] : "q";
            string message = tab >= 0 ? line[(tab + 1)..] : line;
            switch (flag)
            {
                case "s":
                    _speech.Stop();
                    break;
                case "i":
                    _speech.Say(message, interrupt: true);
                    Log.Append("speech.log", "[i] " + message);
                    break;
                default:
                    _speech.Say(message);
                    Log.Append("speech.log", message);
                    break;
            }
        }
    }

    public void Start()
    {
        _listener.Start();
        _ = AcceptLoop();
    }

    public void Stop()
    {
        _cts.Cancel();
        _listener.Stop();
    }

    public void QueueCommand(string command)
    {
        lock (_commands) _commands.Enqueue(command);
    }

    private async Task AcceptLoop()
    {
        while (!_cts.IsCancellationRequested)
        {
            TcpClient client;
            try
            {
                client = await _listener.AcceptTcpClientAsync(_cts.Token);
            }
            catch (OperationCanceledException) { return; }
            catch (ObjectDisposedException) { return; }
            catch (SocketException ex)
            {
                Log.Write("Server accept error: " + ex.Message);
                continue;
            }
            _ = Task.Run(() => Handle(client));
        }
    }

    private async Task Handle(TcpClient client)
    {
        using var _ = client;
        try
        {
            client.ReceiveTimeout = 5000;
            var stream = client.GetStream();
            var (requestLine, headers, body) = await ReadRequest(stream);
            if (requestLine == null) return;

            Interlocked.Increment(ref RequestCount);
            LastRequestUtc = DateTime.UtcNow;

            string[] parts = requestLine.Split(' ');
            string method = parts.Length > 0 ? parts[0] : "";
            string target = parts.Length > 1 ? parts[1] : "/";
            string path = target;
            string query = "";
            int q = target.IndexOf('?');
            if (q >= 0) { path = target[..q]; query = target[(q + 1)..]; }

            string text = Encoding.UTF8.GetString(body);
            if (text.Length == 0)
                text = QueryValue(query, "t") ?? "";

            string reply = Route(method, path, query, headers, text);
            await WriteResponse(stream, reply);
        }
        catch (Exception ex) when (ex is IOException or SocketException or InvalidDataException)
        {
            Log.Append("requests.log", "connection error: " + ex.Message);
        }
    }

    private string Route(string method, string path, string query, List<string> headers, string text)
    {
        switch (path)
        {
            case "/speak":
                long.TryParse(QueryValue(query, "s"), out long seq);
                _sequencer.Submit(QueryValue(query, "k") ?? "", seq, text);
                return "ok";
            case "/say":
                _speech.Say(text);
                Log.Append("speech.log", text);
                return "ok";
            case "/sayi":
                _speech.Say(text, interrupt: true);
                Log.Append("speech.log", "[i] " + text);
                return "ok";
            case "/stop":
                _speech.Stop();
                return "ok";
            case "/log":
                Log.AppendRaw("game.log", text.EndsWith('\n') ? text : text + "\n");
                return "ok";
            case "/tone":
                return _tones.Play(key => QueryValue(query, key));
            case "/mouse":
                int.TryParse(QueryValue(query, "dx"), out int dx);
                int.TryParse(QueryValue(query, "dy"), out int dy);
                return Mouse.Move(dx, dy);
            case "/enqueue":
                // Development console: queue Lua for the game to run (see devconsole.lua).
                QueueCommand(text);
                return "queued";
            case "/cmd":
                lock (_commands)
                    return _commands.Count > 0 ? _commands.Dequeue() : "";
            default:
                // Discovery: record everything about requests we did not expect.
                var sb = new StringBuilder();
                sb.Append($"{method} {path}");
                if (query.Length > 0) sb.Append($" ?{query}");
                sb.AppendLine();
                foreach (var h in headers) sb.AppendLine("    " + h);
                if (text.Length > 0) sb.AppendLine("    body: " + text.Replace("\n", "\n          "));
                Log.Append("requests.log", sb.ToString().TrimEnd());
                if (path.StartsWith("/probe/log/"))
                    Log.AppendRaw("game.log", text.EndsWith('\n') ? text : text + "\n");
                return "ok " + path;
        }
    }

    private static string? QueryValue(string query, string key)
    {
        foreach (var pair in query.Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            int eq = pair.IndexOf('=');
            string k = eq >= 0 ? pair[..eq] : pair;
            if (k == key)
                return eq >= 0 ? Uri.UnescapeDataString(pair[(eq + 1)..].Replace('+', ' ')) : "";
        }
        return null;
    }

    private static async Task<(string? line, List<string> headers, byte[] body)> ReadRequest(NetworkStream stream)
    {
        var buffer = new byte[8192];
        var head = new MemoryStream();
        int headerEnd = -1;
        while (headerEnd < 0)
        {
            int n = await stream.ReadAsync(buffer);
            if (n == 0) break;
            head.Write(buffer, 0, n);
            headerEnd = IndexOf(head.GetBuffer(), 0, (int)head.Length, Encoding.ASCII.GetBytes(CrLf + CrLf));
            if (head.Length > MaxHeaderBytes) throw new InvalidDataException("headers too large");
        }
        if (headerEnd < 0) return (null, new List<string>(), Array.Empty<byte>());

        byte[] all = head.ToArray();
        string headerText = Encoding.ASCII.GetString(all, 0, headerEnd);
        var lines = headerText.Split(CrLf);
        var headers = lines.Skip(1).Where(l => l.Length > 0).ToList();

        int contentLength = -1;
        bool expectContinue = false, chunked = false;
        foreach (var h in headers)
        {
            int c = h.IndexOf(':');
            if (c <= 0) continue;
            string name = h[..c].Trim(), value = h[(c + 1)..].Trim();
            if (name.Equals("Content-Length", StringComparison.OrdinalIgnoreCase))
                int.TryParse(value, out contentLength);
            else if (name.Equals("Expect", StringComparison.OrdinalIgnoreCase))
                expectContinue = value.Equals("100-continue", StringComparison.OrdinalIgnoreCase);
            else if (name.Equals("Transfer-Encoding", StringComparison.OrdinalIgnoreCase))
                chunked = value.Contains("chunked", StringComparison.OrdinalIgnoreCase);
        }
        if (contentLength > MaxBodyBytes) throw new InvalidDataException("bad content length");

        // The engine's asynchronous POST asks permission before it sends the body.
        if (expectContinue)
            await stream.WriteAsync(Encoding.ASCII.GetBytes("HTTP/1.1 100 Continue" + CrLf + CrLf));

        var body = new MemoryStream();
        int bodyStart = headerEnd + 4;
        body.Write(all, bodyStart, all.Length - bodyStart);
        if (contentLength >= 0)
        {
            while (body.Length < contentLength)
            {
                int n = await stream.ReadAsync(buffer);
                if (n == 0) break;
                body.Write(buffer, 0, n);
            }
        }
        else if (chunked || expectContinue)
        {
            // Unknown length: read until the sender goes quiet, closes, or ends the chunk stream.
            while (body.Length < MaxBodyBytes)
            {
                using var idle = new CancellationTokenSource(chunked ? 1000 : 300);
                int n;
                try { n = await stream.ReadAsync(buffer, idle.Token); }
                catch (OperationCanceledException) { break; }
                if (n == 0) break;
                body.Write(buffer, 0, n);
                if (chunked && EndsWithLastChunk(body)) break;
            }
        }

        byte[] bodyBytes = body.ToArray();
        if (contentLength >= 0 && bodyBytes.Length > contentLength) Array.Resize(ref bodyBytes, contentLength);
        if (chunked) bodyBytes = Dechunk(bodyBytes);
        return (lines[0], headers, bodyBytes);
    }

    private static bool EndsWithLastChunk(MemoryStream body)
    {
        int take = (int)Math.Min(7, body.Length);
        string tail = Encoding.ASCII.GetString(body.GetBuffer(), (int)body.Length - take, take);
        return tail.EndsWith("0" + CrLf + CrLf);
    }

    private static byte[] Dechunk(byte[] data)
    {
        var output = new MemoryStream();
        byte[] crlf = Encoding.ASCII.GetBytes(CrLf);
        int pos = 0;
        while (pos < data.Length)
        {
            int lineEnd = IndexOf(data, pos, data.Length, crlf);
            if (lineEnd < 0) break;
            string sizeText = Encoding.ASCII.GetString(data, pos, lineEnd - pos).Split(';')[0].Trim();
            if (!int.TryParse(sizeText, System.Globalization.NumberStyles.HexNumber, null, out int size) || size == 0) break;
            pos = lineEnd + 2;
            output.Write(data, pos, Math.Min(size, data.Length - pos));
            pos += size + 2;
        }
        return output.ToArray();
    }

    private static int IndexOf(byte[] data, int start, int length, byte[] pattern)
    {
        int i = data.AsSpan(start, length - start).IndexOf(pattern);
        return i < 0 ? -1 : start + i;
    }

    private static async Task WriteResponse(NetworkStream stream, string reply)
    {
        byte[] body = Encoding.UTF8.GetBytes(reply);
        string head = "HTTP/1.1 200 OK" + CrLf +
                      "Content-Type: text/plain; charset=utf-8" + CrLf +
                      $"Content-Length: {body.Length}" + CrLf +
                      "Connection: close" + CrLf + CrLf;
        await stream.WriteAsync(Encoding.ASCII.GetBytes(head));
        await stream.WriteAsync(body);
        await stream.FlushAsync();
    }
}
