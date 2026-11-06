TWD Access 1.3.0
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

CHANGES.txt lists what is new in each version.


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
                      to. Each is read with its actions and how far away it is. Where you walk
                      about (Season One and 400 Days), something you cannot use from where you
                      stand is called "out of reach", and Enter walks there. "Blocked" means a
                      walk there already stopped short, for example at a closed gate; such things
                      come last. "In another area" means the game will not let you use it until
                      you have walked over there, for example across a fence. When a door you
                      open leaves nothing to use beyond it, the mod says it is open and offers
                      "Open doorway": Enter walks you through. The tabkey setting (below) can
                      move Tab to a letter of your choice, and Shift+Tab to Shift and that
                      letter.
  1 to 4             Pick one of a thing's actions (Look At, Use, Talk To...).
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
  tabkey         Tab, or a letter: the key that moves between the things around you, with
                 Shift to go back, everywhere the mod uses Tab. Some letters cannot be used,
                 because the game already uses them: W, A, S, D, Z, Q, E, F, T, P and R. With
                 one of those, TWDAccess.exe says so when it starts and the mod keeps Tab.
                 Takes effect the next time the game starts.
  streaming      true opens TWD Access in a window of its own, so OBS can record its beeps and
                 tones: add an Application Audio Capture and pick the window marked
                 [TWDAccess.exe]. Takes effect the next time TWDAccess.exe starts.
  menus, tooltips, choices   true or false: read menus, their help lines, and choices.


LANGUAGES

The game can show its text in French, German, Spanish, Portuguese, Italian, Russian, Simplified
Chinese or Traditional Chinese as well as English: in the game's main menu, Settings, then
Languages. The mod then reads the game's text in that language; its own words ("Main menu",
"Tab to choose") stay in English. Use a screen reader voice that speaks the language you choose.
Not every season has every language: the game's language setting says which ones do.


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

If the game seems to lag or stops taking keys after Shift+Tab, the Steam overlay has probably
opened: Steam opens it with Shift+Tab, which the mod uses too. Press Shift+Tab again to close it.
To stop it happening, turn the overlay off for this game: in your Steam Library, right-click The
Walking Dead: The Telltale Definitive Series, choose Properties, and on the General page uncheck
"Enable the Steam Overlay while in-game". Or keep the overlay and give it another shortcut in
Steam's Settings, under In Game. Or move the mod off Tab to a letter with the tabkey setting
(under Settings above). TWDAccess.exe reminds you of this when it starts
while the overlay is on with Shift+Tab and the mod uses Tab. GOG Galaxy's overlay opens with Shift+Tab as well; it can be
turned off in Galaxy's settings.


LICENCES

TWD Access is released under the MIT licence (LICENSE.txt). It speaks through Prism by Ethin
Probst and contributors (github.com/ethindp/prism), under the Mozilla Public License 2.0; Prism's
notice and the licences of what it uses are in the licenses folder. The Walking Dead: The
Telltale Definitive Series belongs to its owners; this mod only adds speech to it.
