namespace TWDAccess;

/// <summary>
/// The game sends each frame's speech as one asynchronous request numbered per script state, and
/// requests can overtake each other on the way. This puts them back in order, waiting at most a
/// short moment for a missing number before moving on without it.
/// </summary>
internal sealed class SpeechSequencer
{
    private static readonly TimeSpan GapWait = TimeSpan.FromMilliseconds(80);

    private readonly Action<string> _deliver;
    private readonly object _gate = new();
    private readonly SortedDictionary<long, string> _pending = new();
    private readonly Timer _timer;
    private string? _key;
    private long _next;

    public SpeechSequencer(Action<string> deliver)
    {
        _deliver = deliver;
        _timer = new Timer(_ => SkipGap());
    }

    public void Submit(string key, long seq, string payload)
    {
        lock (_gate)
        {
            if (key != _key)
            {
                // A new script state started numbering again; flush what the old one left.
                foreach (var p in _pending.Values) _deliver(p);
                _pending.Clear();
                _key = key;
                _next = seq;
            }
            if (seq < _next)
            {
                _deliver(payload); // arrived after we gave up waiting for it
                return;
            }
            _pending[seq] = payload;
            Drain();
            if (_pending.Count > 0) _timer.Change(GapWait, Timeout.InfiniteTimeSpan);
        }
    }

    private void Drain()
    {
        while (_pending.Remove(_next, out var payload))
        {
            _next++;
            _deliver(payload);
        }
    }

    private void SkipGap()
    {
        lock (_gate)
        {
            if (_pending.Count == 0) return;
            _next = _pending.Keys.First();
            Drain();
            if (_pending.Count > 0) _timer.Change(GapWait, Timeout.InfiniteTimeSpan);
        }
    }
}
