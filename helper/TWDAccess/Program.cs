using System.Diagnostics;

namespace TWDAccess;

internal static class Program
{

    private static int Main(string[] args)
    {
        var opts = Options.Parse(args);
        if (opts.Help)
        {
            Console.WriteLine("""
                TWD Access - screen reader support for The Walking Dead: The Telltale Definitive Series.

                Usage: TWDAccess [options]
                  --no-launch      Do not start the game; just listen for it.
                  --no-install     Do not copy the mod script into the game folder.
                  --uninstall      Remove the mod from the game folder and exit. The small start-up
                                   script and the save records stay if saves were made with the mod,
                                   because those saves need them to load.
                  --all            With --uninstall: remove those as well.
                  --game PATH      Game folder, if it cannot be found through Steam.
                  --backend NAME   Force a Prism backend, for example NVDA, SAPI, JAWS or OneCore.
                  --port N         Local port to listen on (default 41234).
                """);
            return 0;
        }

        string? gameDir = opts.GameDir ?? GameLocator.Find();
        Log.Write($"TWD Access {typeof(Program).Assembly.GetName().Version} starting. Game folder: {gameDir ?? "not found"}");

        if (opts.Uninstall)
        {
            if (gameDir == null)
            {
                Console.WriteLine("Game folder not found; nothing to remove.");
                return 1;
            }
            return ModInstaller.Uninstall(gameDir, opts.All);
        }

        if (gameDir != null && OwnWindow.Relaunch(gameDir, args))
            return 0;
        // (What OBS's window list shows: "[TWDAccess.exe]: TWD Access".)
        Console.Title = "TWD Access";

        using var speech = new Speech(opts.Backend);
        var server = new LocalServer(opts.Port, speech);
        try
        {
            server.Start();
        }
        catch (System.Net.Sockets.SocketException ex)
        {
            Log.Write($"Could not listen on port {opts.Port}: {ex.Message}. Is TWD Access already running?");
            speech.Say("TWD Access could not start. It may already be running.", interrupt: true);
            Thread.Sleep(3000);
            return 1;
        }
        Log.Write($"Listening on 127.0.0.1:{opts.Port}");

        using var debugMonitor = new DebugMonitor();
        if (debugMonitor.Start())
            Log.Write("Listening for the game's debug output");

        if (gameDir != null && !opts.NoInstall)
            ModInstaller.Install(gameDir);

        bool gameRunning = Process.GetProcessesByName("WDC").Length > 0;
        speech.Say($"TWD Access ready, using {speech.BackendName}." + (gameRunning ? "" : opts.NoLaunch ? "" : " Starting the game."), interrupt: true);

        // Steam's overlay opens with Shift+Tab unless told otherwise, and the mod uses Shift+Tab too.
        string? steamPath = GameLocator.SteamPath();
        if (gameDir != null && steamPath != null && GameLocator.IsSteamCopy(gameDir)
            && SteamOverlay.OpensWithShiftTab(steamPath, GameLocator.AppId))
        {
            Log.Write(SteamOverlay.Warning);
            speech.Say(SteamOverlay.Warning);
        }

        if (!gameRunning && !opts.NoLaunch)
        {
            Log.Write("Starting the game through Steam");
            Process.Start(new ProcessStartInfo($"steam://rungameid/{GameLocator.AppId}") { UseShellExecute = true });
        }

        using var quit = new ManualResetEventSlim(false);
        Console.CancelKeyPress += (_, e) => { e.Cancel = true; quit.Set(); };

        // Stay alive while the game runs. If the game was never seen, keep listening until Ctrl+C.
        bool seenGame = gameRunning, warnedNoGame = false;
        DateTime started = DateTime.UtcNow;
        while (!quit.Wait(1000))
        {
            bool running = Process.GetProcessesByName("WDC").Length > 0;
            if (running) seenGame = true;
            else if (seenGame)
            {
                Log.Write("The game has closed; TWD Access is exiting.");
                break;
            }
            else if (!opts.NoLaunch && !warnedNoGame && DateTime.UtcNow - started > TimeSpan.FromMinutes(3))
            {
                Log.Write("The game did not start within three minutes; still listening. Press Ctrl+C to exit.");
                warnedNoGame = true;
            }
        }

        server.Stop();
        return 0;
    }

    private sealed class Options
    {
        public bool Help, NoLaunch, NoInstall, Uninstall, All;
        public string? GameDir, Backend;
        public int Port = 41234;

        public static Options Parse(string[] args)
        {
            var o = new Options();
            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i].ToLowerInvariant();
                string? Next() => i + 1 < args.Length ? args[++i] : null;
                switch (a)
                {
                    case "-h" or "--help" or "/?": o.Help = true; break;
                    case "--no-launch": o.NoLaunch = true; break;
                    case "--no-install": o.NoInstall = true; break;
                    case "--uninstall": o.Uninstall = true; break;
                    case "--all": o.All = true; break;
                    case "--game": o.GameDir = Next(); break;
                    case "--backend": o.Backend = Next(); break;
                    case "--port": if (int.TryParse(Next(), out int p)) o.Port = p; break;
                    default: Console.WriteLine($"Unknown option {args[i]}"); o.Help = true; break;
                }
            }
            return o;
        }
    }
}
