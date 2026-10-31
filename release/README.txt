TWD Access 1.0.0
Screen reader support for The Walking Dead: The Telltale Definitive Series


WHAT IT DOES

TWD Access makes the whole game playable by ear. It speaks through your screen reader (NVDA,
JAWS and others), or through Windows' own voice if no screen reader is running. It reads:
- the menus, settings and save screens of every season;
- dialog choices, with the timer on timed choices held until you pick;
- the things you can look at, use and walk to, and lets you reach them from the keyboard;
- quick-time events, struggles, fights, guided paths, drags, hiding and leaning out;
- aiming, by a tone you follow with the arrow keys;
- notices, items you pick up, the death screen, and each episode's choices at the end.

It covers every season in the Definitive Series: Season One (with 400 Days), Season Two, A New
Frontier, The Final Season and Michonne. All of them have been played through from start to end
with the mod, by ear.

Character speech (subtitles) is not read by default, since you hear the voices; F7 turns it on.


WHAT YOU NEED

- Windows 10 or 11, 64-bit.
- The Walking Dead: The Telltale Definitive Series, on Steam.
- A screen reader if you like (NVDA works best). Nothing else needs installing: .NET is built in.


INSTALLING AND PLAYING

1. Unzip the TWDAccess folder anywhere, for example in Documents.
2. Each time you want to play, run TWDAccess.exe in that folder. It puts the mod into the game
   folder, says "TWD Access ready, using NVDA. Starting the game.", and starts the game through
   Steam. Leave it running: it closes by itself when the game closes.
3. The game opens on its title screen. Press Enter (or click) to go on to the main menu, which
   is read out.

If the game is already running, start TWDAccess.exe anyway; it connects to it.
Do not run the game without TWDAccess.exe once you have saves made with the mod: the mod's
start-up script stays in the game folder, and the game needs TWDAccess.exe for speech.


KEYS

The mod's own keys (the game does not use them):
  F5          Repeat the last thing said.
  F6          Describe what is on screen: the menu and its keys, the choices, the action going
              on, or the things around you and what you carry.
  F7          Character speech: off, speaker names only, or full lines.
  F8          Stop speech.
  F11         Action scenes: normal speed, slow motion, or the mod plays them for you.
  F4          Sound beacons: a sound on what Tab chose, on everything near, or off.
  F3          Beeps louder. Shift+F3: quieter.
  In menus, for controller buttons that have no key: F9 (X), F10 (Y), Page Up and Page Down
  (the shoulder buttons). The mod names these when a menu uses them.

Menus: Up and Down arrows (or Left and Right where the mod says so) and Enter. Escape goes back.

Dialog choices: they are read as a numbered list. Press 1 to 4, or move with Up and Down and
press Enter.

Exploring:
  Tab and Shift+Tab   Move between the things you can interact with and the places you can walk
                      to. Each is read with its actions and how far away it is.
  1 to 4              Pick one of a thing's actions (Look At, Use, Talk To...).
  Enter               Do it. The mod walks you there first if needed.
  W A S D             Walk yourself, as usual.
  Backspace           Step back out of a close-up, or stop a walk.
  Escape              The game's pause menu.

Action scenes: the mod says what to press as each prompt appears, for example "Q!",
"Left arrow!", "E, then Q, then E!", "Struggle! Press Q over and over. Then E when told.",
"Hold S to go on", "Drag: hold Left arrow.". When aiming, the arrow keys aim and a tone guides
you: it rises as you get closer and ticks twice when you are on target; then press Enter.
F6 repeats what is going on.


SETTINGS

Settings are kept in the game folder, in TWDAccess\settings.txt, and can be changed there with
Notepad. Most of them also have a key above.
  subtitles      off, speaker or full (F7).
  choicetimer    pause holds the timer on timed choices; normal keeps the game's timer.
  actionscenes   normal, slow or auto (F11). New players start on slow.
  beacons        tab, all or off (F4).
  beepvolume     How loud the beeps are, in percent (F3).
  aim            sound (you aim by the tone) or auto (the mod aims for you).
  bowturn        How fast the arrow keys turn the bow in The Final Season.
  menus, tooltips, choices   true or false: read menus, their help lines, and choices.


SAVES

Saves made while the mod is installed name the mod's start-up script, so they only load while it
is in the game folder. Removing the mod (below) leaves that script and its save records in place
unless you ask for everything to go.


REMOVING THE MOD

Open a command prompt in the TWDAccess folder and type:
  TWDAccess.exe --uninstall
This removes the mod but keeps the small start-up script if you have saves made with the mod.
  TWDAccess.exe --uninstall --all
removes everything; saves made with the mod may then no longer load.


OTHER OPTIONS

  TWDAccess.exe --backend SAPI     Use another voice (NVDA, JAWS, SAPI, OneCore...).
  TWDAccess.exe --game "path"      The game folder, if it is not found through Steam.
  TWDAccess.exe --no-launch        Do not start the game; wait for you to start it.
  TWDAccess.exe --help             All the options.


IF SOMETHING GOES WRONG

Logs are in the logs folder next to TWDAccess.exe (what was spoken is in speech.log), and in
the game folder's TWDAccess\twda.log. The mod was played through once, mostly choosing the first
answer, so other choices can lead to scenes it has not met; F6 and Tab usually still help there.


LICENCES

TWD Access is released under the MIT licence (LICENSE.txt). It speaks through Prism by Ethin
Probst and contributors (github.com/ethindp/prism), under the Mozilla Public License 2.0; Prism's
notice and the licences of what it uses are in the licenses folder. The Walking Dead: The
Telltale Definitive Series belongs to its owners; this mod only adds speech to it.
