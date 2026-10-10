# TWD Access: handoff notes

Read this first. It is written for the next agent picking up this project, and kept current at
the end of each session.

Last updated: 2026-10-09 (fifth session, about 09:00; see the first items).

## Start here (where the last session stopped)

- Fifth session, 2026-10-09 early morning (user asleep, "keep working on the mod"; questions saved
  for the end). The fourth session (2026-10-08 evening to 2026-10-09 02:00) finished Episode 2 and
  played Episode 3 in slot 2 as far as Clementine's shooting lesson on the train
  (env_trainAfterStop.lua), but ran out of time before writing its Episode 3 work down; the
  fifth session reconstructed it from that session's transcript into "Episode 3 notes", the file
  map (sniper.lua, panels.lua, readables.lua) and the tools list. See "Fifth session" below that
  for what the fifth session itself did.
- The fifth session finished Episode 3 and played Episode 4 in slot 2 to the outskirts of
  Crawford (env_crawfordExterior.lua; dev_saves\ep4_crawford, saved 08:38): through the manhole,
  hiding (lean W), then "Guard: Move To. Enter to do it." and a guided path (sneaking up on the
  guard with Kenny). Next: gamepressure's Episode IV "Georgia's Last City" pages (Arrival and
  Battery, then Meds and Escape).
- The game closed at 08:44 because the user closed it (not a crash). Free commit memory was then
  4.8 GB of 34: the SteelSeries capture service starts a copy with every game launch and two
  copies held about 10 GB (see the memory note), so the session did not relaunch the game and
  did code work instead (names, walk danger stop, issues #16 to #19). Before launching
  again, check free commit memory (Win32_OperatingSystem FreeVirtualMemory); ask the user to
  restart SteelSeries GG or reboot if it is low. Each restart.ps1 adds a capture copy, so
  restart as rarely as possible.
- dist\TWDAccess was rebuilt at the end with every change (the installed copy in the game folder
  is replaced from it at the next launch).
- Game closings in the fourth session: three crashes (with .dmp files in the game folder) at
  22:52, 23:01 and 23:04 on 2026-10-08 were Windows running out of commit memory (the SteelSeries
  leak; see the memory note), not the mod. At 01:54 on 2026-10-09 the game closed with no dump, 45
  s after a development walk across the train (DEV.route through the cab doors and the boxcar
  door); cause unknown, the mod logged nothing unusual.
- Third session, 2026-10-08 afternoon (user waiting, "keep working on the mod"): Episode 2 played
  in slot 2 from the start (from dev_saves\ep1done, Episode 2 "Play") through the bear trap, the
  rations, zombie David's attack, the dairy, the fence and the tractor escape, the bandit camp
  (Jolene) and back to the dairy for the evening (env_dairy..., Brenda cooking). Next: the barn
  mystery (walkthrough steps in "Episode 2 notes"), then dinner. Everything below marked
  2026-10-08 (third) is new and tested by keys or by play_by_ear.ps1 unless it says otherwise.
- The game crashed (its own .dmp files in the game folder) four times at the dairy tractor; all
  four were caused by a development query that called AgentSelectionIsOccluded on every hotspot,
  never by the mod. Do not call AgentSelectionIsOccluded.

- The user plays with the keyboard (NVDA). They would use a PS5 controller only if controller
  support is added later; not a priority.
- 2026-10-05 the user played slot 1 on from the backyard into Clementine's house and kept dying to
  the babysitter: the mod said nothing during the fight (a struggle, then punches, then the
  hammer). On 2026-10-07/08 (user asleep, "get as far as you can") the agent made that fight
  playable by ear (struggle.lua, fight targets in lookaround.lua and actions.lua) and verified it in
  normal mode with keys only (tools\dev\play_by_ear.ps1), then played slot 2 on through the gate,
  the car push, Hershel's farm (talking to everyone; the fence attack: turnchoice.lua), the drive
  to Macon, the drugstore (radio, batteries, office, Clementine's finger) and into the start of the
  Motor Inn stealth (peek.lua). See "Episode 1 notes" for each scene. Ask the user how the house
  fight goes for them; their slot 1 save (2026-10-05 12:40) starts right inside it.
- Later on 2026-10-08 (user said to keep going) the agent played slot 2 through the Motor Inn
  stealth, the TV-store distraction and Lee's brother, the pharmacy and the drugstore finale (save
  Carley, kick the walker off Clementine, run to Larry) to the end of Episode 1: the statistics
  screen, the credits and back to Season 1's menu. New modules guided.lua and runto.lua, and
  several fixes (see "Season 1 during play: ..." and "Episode 1 notes"). Then Episode 2 was
  started: the bear trap (env_woodsBearTrap.lua) passed silently (David's leg, the trap, a cable,
  a rock, a stick, a tree and Ben are offered through the reticle for about 90 s with no panic
  meter, so nothing was announced; Travis got shot). actions.lua now also reads out, once, what
  appears in view in fixed-view scenes ("sceneoffers"). Done in the third session: the trap is
  now a countdown with its actions read out, and David was saved by keys.
- Earlier: the zombie cop attack was solved on 2026-10-03 and the user played it in slot 1 to
  Clementine's backyard ("most of that worked"). Walking (Tab, Enter walks there, F6 distances)
  dates from then; the user has used it in the yard and the house.
- Save slot 2 is the agent's test slot (the user said to play there). Its save is now in Episode 3
  (see the first item). Copies of slot 2 at many checkpoints are
  in dev_saves (see Files). To use one: close the game, copy both files into Documents\Telltale
  Games\The Walking Dead Definitive, set slot 2's line in <game>\TWDAccess\saves.txt to the
  scene's script (the loader needs it; listed with each copy under Files), then restart.ps1 and
  load_slot2.ps1. Copying files while the game runs made a load hang. Slot 1 is the user's own
  game: never delete, copy over or play it. (dev_saves\house was made from a copy of the user's
  slot 1 files, with the slot name inside the small bundle changed to slot 2; slot 1 itself was
  only read.)
- Reload the current checkpoint from the dev console with `CheckpointLoad()`. It reloads the last
  autosave held in memory (not the file) and re-runs the mod (main.lua), so hot-copied modules that
  hook functions load cleanly. Checkpoints move on as you play: winning a fight moves it past the
  fight.
- The user's settings.txt now has actionscenes = normal and subtitles = speaker (both their own
  choice with F11/F7). Tests that need another mode set `TWDA.settings.actionscenes` in memory from
  the dev console instead of changing the file.
- The dev console is on in the installed settings.txt (devconsole = true); leave it on while
  developing, turn it off for a release.

## What this project is

TWD Access is a screen-reader accessibility mod for "The Walking Dead: The Telltale Definitive
Series" (Steam app 1449690), made for a blind player who uses NVDA. The goal is to make the whole
game playable by ear: menus and settings, dialog choices, QTEs, subtitles and on-screen text, all
spoken through the Prism screen-reader library (github.com/ethindp/prism). Prism picks NVDA when it
is running and otherwise falls back to other screen readers or SAPI.

The user wants:

- Everything spoken through Prism to their screen reader of choice (NVDA here).
- Voiced character lines (subtitles) silent by default, switchable with a hotkey.
- Replies written for a screen reader: headings and short lists, no wide tables, no ASCII art.
- To be told what you are doing; long silent stretches worry them.
- Help with timing as a choice, not forced on them: timed dialog choices wait (choicetimer), and
  action scenes have a setting (actionscenes: normal, slow or auto, F11).

They are fine with you launching and closing the game yourself for testing; only close a copy of
the game you started.

## Current status

Working and tested in the game:

- The mod loads on the title screen, in the hub ("Definitive") menu, in Season 1's menu and inside
  Season 1 Episode 1, and survives every switch between them, including Season 1's scene changes
  inside an episode (LoadScript) and loading a save (see "Getting our Lua into the game").
- Speech end to end: game -> helper -> Prism -> NVDA.
- The hub menu and everything under it: the main menu, Settings (Audio/Display, Graphics,
  Brightness, Languages, About), Season Select, Developer Commentary, Character Viewer, Art Gallery,
  Music Player, Credits and the quit popup. Each menu announces its name and item count; items are
  read with value, type and help line; value changes are spoken; popups read title, message and how
  to use them; F6 describes the screen.
- Season 1's own menu (panes.lua, messagebox.lua): Main (Play, Settings, Definitive Menu, Exit
  Game), Settings and its Audio, Gameplay and Graphics panes (each row read as "Label, value", Left
  and Right change, Enter on a value steps it, Apply and Cancel added to the end of the arrow list),
  the Controls chart, Save Slots (Enter plays the highlighted slot, F9 delete, F10 copy), Choose a
  Display Style, the Episode screen (Left/Right or Page Up/Down switch episodes, Enter plays) and the
  Yes/No message box (delete confirmation, exit confirmation). Keys pressed while a pane animates
  are queued and run in order.
- Season 1's pause menu (Escape during play): the same pane code as the main menu.
- Season 1 Episode 1, played in save slot 2 from the start through the car crash, out of the car and
  up to the zombie cop attack:
  - Dialog choices are read as a numbered list ("Choices. 1: ... 4: Say nothing"); 1 to 4 pick.
  - Timed choices wait for the player (setting choicetimer = pause, the default): the mod pauses all
    dialogs while choices are up and resumes them the moment one is picked (choices.lua).
  - Tutorial hints are read ("Use the mouse to take a look around.", "Now MOVE toward the window,
    using the W (forward) key.").
  - Hotspots (lookaround.lua): Tab and Shift+Tab move the reticle to each object you can interact
    with, turning the camera in first-person look-around scenes, even to things behind you. It reads
    "Window: 1 Look, 2 Climb Out, 1 of 5"; number keys choose an action ("Climb Out"); Enter does
    it (several times if needed, such as kicking the window). F6 lists all hotspots.
  - Guided walking with W or S works as the game intends; the hint names the key.
  - Loading a save made in a later scene (Continue on slot 2, whose save is in
    env_woodsClementine.lua) and reloading the checkpoint after a death both bring the mod back
    and run the right scene script.
  - The death screen ("You are dead", prompts.lua) is read, and Enter reloads the last checkpoint.
  - Action scenes (actions.lua), setting actionscenes = normal | slow | auto, F11 cycles it (the
    user asked for a choice; default slow). During one, newly usable things are announced by name,
    action and side ("Shotgun shell: Take, to your right"); slow runs the game at 0.45 speed; auto
    uses each new non-"Look" thing in turn through the reticle (TWDA.useWithReticle), turning the
    camera to it, and aims and fires the shotgun.
  - Things out of view in look-around scenes: Tab includes them and the reticle turns the camera
    to them by holding at that screen edge ("Shotgun: Pick Up, 2 of 3" once reached); F6 says
    "to your left/right", "behind you".
  - Shotgun aiming at the zombie cop (aiming.lua): announced on entry; Tab aims for you, arrow
    keys aim by hand, Enter fires; "On target. Enter to fire." / "Off target".
- Subtitles are captured with the speaker's name (silent by default).

- Season 1 Episode 1 further on (2026-10-07/08, slot 2, by keys; see "Episode 1 notes"):
  - Struggles (struggle.lua): "Struggle! Press Q over and over. Then E when told.", "Halfway",
    "E now!", "Too late. Q again!"; F6 gives the percentage. Auto mode presses Q and E itself.
  - Fights (the reticle in combat mode): targets have no name or tooltip, so the mod names them
    from their use dialog node ("babysitter: Punch. Enter!"); Enter goes for the first target on
    offer; the reticle is let go after each blow (the camera follows it in fights).
  - Turn choices (turnchoice.lua): "Turn: Left arrow towards Shawn, Right arrow towards Duck"; the
    mod turns on the arrow keys (the game ignores them on PC).
  - Peeking from cover (peek.lua): "Hiding. Hold W up, A left, D right to lean out", "Leaning out
    up. S to get back", "Back in cover".
  - Inventory (inventory.lua): "Got hammer", "No more batteries"; F6 ends with "Carrying: ...".
  - Number keys pick an action even when the reticle has dozed off (remembered until Enter);
    Backspace leaves a close-up (Carley's radio, Clementine's finger).
  - Walking: things in view that Lee must walk up to (the gate) are listed and offered as a walk,
    to the game's own use position. The Tab list puts things in view first and is re-sorted when
    Lee has moved. Selectable props with no name, action or use dialog are left out.
  - Action scenes: what can be used from here is announced first and alone, things to do before
    things to look at, talking last, with "Enter!" or "Tab to choose, Enter."; the next Tab (or
    Enter with nothing chosen) goes to the first of them.
  - Dialog choices: the arrow keys now read the game's own highlight (it does not wrap at the ends,
    which is how the old counting drifted: the user heard 3 and Lee said 2).

Built but only partly tested:

- Season 1 Save Slots copy mode (F10, then Enter on the target slot): not tried. Delete with Yes
  was tested on the test slot (slot 2) only. The Rewind (F9) and Stats (F10) buttons on the Episode
  screen only appear once an episode has been played; their panes are untested.
- Hotspots in third-person scenes: tested in the house, yard, farm, drugstore and office.
- Slow mode's "hold Q to keep pressing" in struggles: not tried (the same call as auto mode's
  presses, which works).

Not done yet, in suggested order. Items 1 to 9 of the 2026-10-03 list are GitHub issues #1 to #9
(labelled needs-triage); keep the two in step, and close an issue when its item is done. The items
A to E (2026-10-08) are issues #10 to #14, F is #15, G to J (2026-10-09) are #16 to #19.

A. (#10) Done 2026-10-08: the Motor Inn stealth plays by ear (see "Episode 1 notes"). Closed.
B. (#11) Drugstore exterior, on arriving in Macon: an optional "aim and shoot the walker attacking
   Duck" moment passed silently (Carley shot it). Its checkpoint was not kept; play on from
   dev_saves\fence (about 5 minutes of talk and walking) or try the Episode screen's Rewind (F9).
C. (#12) Close-ups: done 2026-10-08 (third): WDBackButton_IsOccupied() is the flag; only things
   within 3 meters are listed. Check Carley's radio again, then close #12.
D. (#13) Names to tidy: "board zombie attack" (the game's own name key, shown raw), "photo torn"
   (inventory name from the icon), "Kenny, Katjaa, and Duck"; the use node fallback for unnamed
   hotspots ("punch_babySitter" -> "babysitter: Punch") could use a small word list.
F. (#15) Partly done 2026-10-08 (third): stairs are offered as "Stairs" where Lee walks (stair
   triggers in the scene). Still open: doorways and people who are not hotspots. Places with no
   hotspot that Lee must walk into: the open pharmacy door in the office
   (nothing is offered after "Open"; walking through it, to the left, starts the alarm), the
   Motor Inn stairs (walk left along the far wall, then hold W), and the people at the end of
   Episode 1 (they are not selectable; walking up to each starts the talk). AgentPathToPosition
   and AgentPathToAgent work for these; PathAgentDoesPathReachDestination always returns false
   (useless). Ideas: list nearby characters and doorways as walk targets in free walking.
G. (#16) The first Enter after a mod walk arrives sometimes does nothing (Episode 4 house doors,
   shed door, grave); a second Enter works. Not solved; see "Fifth session: more mod changes".
H. (#17) Walks take the shortest way and can lead Lee into walkers (Savannah sewers). A walk now
   stops on the panic vignette or Logic["Dying"] ("Danger! Walk stopped short of ..."), untested.
I. (#18) saves.txt missed one save (Episode 4 house search); the slot-file watcher in
   carryover.lua is the fix, not yet seen working.
J. (#19) Countdowns said "about 1 second" at each step of the alley chase (Episode 4); the time
   now accounts for the timer's speed and the scene's time scale, untested.
E. (#14) Long walks are slow and silent (Lee limps: 35 m to Hershel took about 40 s after "Walking
   to Hershel"); maybe say the distance left now and then, and when Lee is stopped by a scene, say
   nothing rather than "Lee stopped before reaching ..." (the gate at Clementine's).

1. (#1) More navigation, once the user has tried what exists: manual walking help (W A S D move
   relative to fixed cameras that cut as Lee walks, so say which key heads towards a chosen hotspot,
   or announce camera cuts), announce when Lee bumps into something while walking by hand, say
   "Lee can move now" when control returns after a walk-in (the backyard opening says nothing for
   30 s; F6 says "Nothing on screen to read"), and exits to other areas. Check other free-walk
   scenes (inside Clementine's house, the farm, the motor inn) for cameras that do turn.
2. (#2) Zombie cop leftovers: nothing is said when Lee reaches the car (the S hint just stops; the
   "Shotgun, several actions, to your left. Shotgun shell: Take, to your right" announcement is the
   cue), and after calling out to the figure the user heard "Use the S key to get away" four times
   (the second backing-away; worked in the end).
3. (#3) Action scenes, more generally. Done 2026-10-08: struggles (struggle.lua), fights with the
   combat reticle (punch, hammer), turn choices (mode_choice, turnchoice.lua), peeking (peek.lua).
   Still to do: action choices (mode_DialogActionChoice, not met yet), aiming with the reticle in
   later episodes (ReticleUI_InCombatMode with "Shoot" icons, isShootIcon in mode_reticle.lua;
   aiming.lua only covers mode_shotgun; item B may be the first), and in auto mode, holding
   movement keys for "Use the S key" prompts (the handlers are in mode_Chored_Move.imap; the mod
   cannot press keys itself).
4. (#4) Things that happen silently. Done 2026-10-08: the inventory (inventory.lua). Still to do:
   the title screen ("Click to Begin": nothing is said, and whether a key passes it is unknown;
   restart.ps1 clicks).
5. (#5) Check the menus of Season 2, Michonne, A New Frontier and The Final Season. The later seasons
   probably use the same widget framework as the hub; Season 2 probably the same panes as Season 1.
6. (#6) Escape both releases the hotspot the mod is holding and opens the pause menu.
7. (#7) Uninstall: ModInstaller --uninstall removes Archives\DebugLoader.lua, but saves made with the mod
   need it to load (see "Loading saves"); keep it, or warn.
8. (#8) Later, optional: controller support. Keyboard is the primary target and is enough for the user;
   if a controller is added it will be a PS5 DualSense, so hints should name PlayStation buttons and
   follow the game's own device switch (Menu_UsingJoystick in Season 1). Mod commands (F5 to F11)
   would need a button combination; check which buttons the game leaves free (the touchpad click is
   a candidate) and whether a keyboard press flips the game out of controller mode.
9. (#9) Before release: set discovery and devconsole to false in the installed settings.txt, delete the
   TWDAccess\dumps folder in the game directory, and remove the stale TWDAccess\globals_*.txt,
   trap.log and stack_*.luac files.

## Hard constraints and decisions (do not undo these)

- The game executable WDC.exe is wrapped in SteamStub DRM. Decrypting or unpacking it was blocked by
  the safety classifier. Do not try again in any form (Steamless, memory dumps, native injection,
  proxy DLLs). Everything runs as Lua inside the game plus a separate helper program.
- The engine only runs scripts from its resource system when they are in Telltale's encrypted
  "\x1bLEo" format. The user explicitly approved using ttarchext.exe (from the Telltale Modding
  Group's Script Editor repository) only to convert our own bootstrap script into that format:
  `ttarchext -V 7 -e 0 -o 67 <script> <outdir>` (game 67 is this game). Extracting or decrypting the
  game's own archives was not approved; ask the user first if it ever seems necessary.
- Reading the game's scripts that are already loaded in memory, through Lua's own debug library and
  string.dump, is how the game's UI code has been studied (see Developer tooling). That has been
  fine.

## How it works

Two parts:

- **The mod**: Lua that runs inside the game. It hooks the game's own UI functions, works out what
  to say, and sends the text to the helper with the engine's HTTP functions
  (`HttpGetAsync("http://127.0.0.1:41234/speak?k=<state>&s=<seq>&t=<urlencoded>")`).
- **The helper** (helper/TWDAccess, C# .NET 10): a small local HTTP server on 127.0.0.1:41234 that
  speaks through prism.dll on a dedicated thread. It also installs the mod files into the game folder,
  starts the game through Steam, and exits when the game closes.

### Getting our Lua into the game

1. **Archives\DebugLoader.lua**, our bootstrap in the encrypted format. The title screen script
   (boottitle.lua) and the hub menu script (menu_main.lua) contain a leftover developer hook:
   `if ResourceExists("DebugLoader.lua") then require("DebugLoader.lua") ... end`. Loose files in
   the Archives folder count as game resources, so the game loads our file by itself. No game file
   is replaced.
2. On that `require` path the menu then calls `require("MenuBootUtils.lua")` and
   `Callback_OnLoadDebugMenu:Add(...)`. The bootstrap stubs both (a require shim that answers
   MenuBootUtils.lua itself, and a callback object with Add, Exists, Remove and Run), otherwise the
   menu stalls on its loading screen. Only install these stubs on the require path; installing them
   elsewhere broke Season 1's loading.
3. The bootstrap then loads the real mod, plain-text Lua in the **TWDAccess** folder next to WDC.exe
   (the game's working directory), with `io.open` and `load`. The io, os, debug and package libraries
   are all available.
4. **Carry-over.** Every switch between the title, the hub, a season and an episode throws the Lua
   state away and starts a new one, via `SubProject_ResetEngine(project, firstScript)` or the engine's
   `ResetGame(firstScript, ...)`; Season 1 also changes scenes inside an episode with
   `LoadScript(script)` (after the car crash: `LoadScript("env_woodsClementine.lua")`), which starts a
   new state too. carryover.lua wraps all of these (and `ResetEngine`, logged, in case). It writes the
   real first script, with a timestamp, to TWDAccess\next_script.txt and passes "DebugLoader.lua"
   instead. The new state runs our bootstrap, which starts the mod and then runs the real script with
   `loadfile(name)(...)`; Telltale's loadfile loads resources by name. (The bootstrap's own
   LoadScript fallback calls the unhooked original.) The note is always deleted, and is only honoured
   if it is under 2 minutes old and we were not loaded through require. The bootstrap stores the real
   script in the global `TWDA_firstScript`.
5. **Loading saves.** A save records its state's first script (`ScriptManagerGetCurrentScriptName()`),
   which for states the mod started is "DebugLoader.lua". That is good, because loading such a save
   starts the mod, but it means the bootstrap gets no note and must work out the real script. It
   tries, in order: TWDAccess\saves.txt (lines "slot<TAB>script", written by carryover.lua whenever
   the game saves; the slot is `SaveSlots_GetSlot()`, e.g. "wd1_saveslot2.bundle"; copying and
   deleting slots keep it in step, and starting an episode from the menu clears the slot's line),
   then the stored name if it is not ours, then `SubProject_GetEpisodeFirstScript()`.
   Consequence: saves made with the mod need Archives\DebugLoader.lua to load. The bootstrap works
   on its own without the TWDAccess folder, so an uninstall should leave that one file in place if
   the player has such saves (ModInstaller --uninstall currently removes it; to do).
   Saves made in a state the mod never reached (before the LoadScript hook existed) name the real
   script and load without the mod until the next scene change.
6. main.lua guards itself with a global (`TWDA`), so it runs once per Lua state.
7. **Threads die with scenes.** The engine kills script threads when scenes change, including the
   mod's frame thread and the dev console's. Every hooked function call revives the frame thread
   (hooks.lua `revive`); EnginePostUpdate, which the engine calls every frame, is hooked for exactly
   that. The dev console has a watchdog on the frame thread. Test threads started from the console
   can die mid-scene too (one did about 43 seconds into the zombie cop attack).

### Engine facts that matter

- Lua 5.2.3. In bytecode, numbers are 4-byte floats and size_t is 4 bytes.
- **The game pauses all Lua while its window is not focused.** Nothing speaks, and dev-console
  commands queue until the game is in front again.
- Some game states replace `error()` with a version that does not stop execution, so the mod never
  relies on error() (TWDA.include returns ok plus error instead).
- `debug.traceback` returns an empty string; build stacks with `debug.getinfo` (TWDA.stack in
  discovery.lua).
- HTTP: `HttpGetAsync(url)` arrives. `HttpPostAsync` sends no body. `HttpGetAndWait` and
  `HttpPostAndWait` work, but yield the calling script thread.
- `InputPCIsVKeyPressed(vk)` reads the keyboard; hotkeys are polled each frame.
- Text agents show either literal text in the "Text String" property, or a dialog node name in
  "Text Dialog 2.0 Node Name" plus a file handle in "Text Dialog 2.0 File". Resolve with
  `DlgEvaluateToNode(file, node, "text", false):GetText()` (TWDA.nodeText and TWDA.agentText in
  text.lua). Some values are images, such as language names (`<ui_listToggle_languageEnglish.d3dtx>`);
  text.lua turns those into words.
- `SceneGetAgents(scene)` lists a scene's agents; `AgentGetChildren`, `AgentIsHidden`,
  `AgentGetParent` and `AgentFind` all work.
- Input maps can be listed with `InputMapperGetActiveMapperNames()`, then
  `InputMapperGetNumEvents(imap)`, `InputMapperGetInput(imap, i)` (a key code: 13 Enter, 27 Escape,
  37-40 arrows, 512-521 gamepad buttons) and `InputMapperGetCallback(imap, i)`.

### The hub's widget framework (also the pause menu; probably seasons 3 and 4)

- Menus are built with Menu_Create, Menu_Add, Menu_Push and Menu_Show, and widget classes such as
  ListButtonLite, ListToggle, ListSlider, Chooser, Carousel and Header.
- Every selectable thing is created by the global constructor `Button(agent)`, which adds a
  `Select(self, bSelect)` method. menus.lua wraps Select on every new button, so every focus change
  is caught. A button's widget is `button.widget`; for settings rows it is the parent agent's widget
  (`WidgetInitializer_GetWidgetFromAgent`).
- In widget menus the keyboard has the arrows, Enter or Space (select) and Escape (back). The
  controller's X, Y, bumper and trigger buttons have no keyboard key. Synthetic gamepad events are
  ignored because `Input_UseCursor()` is always true on PC. So the mod runs the matching legend
  command instead: Legend_Add(button, label, command) records it. F9 is X, F10 is Y, Page Up and
  Page Down are the bumpers.
- Game bug: when some menus open, keyboard focus lands on a mouse-only arrow button (settings rows,
  list scroll arrows) and the arrow keys then cannot leave it. menus.lua moves focus to the row's
  centre button or the first real item, unless the selection came from the mouse.
- Season Select (menu_seasons.lua): one Play button per season in a carousel
  (ui_seasons_groupButtons_<season>_button, plus padding buttons), mouse-only arrows
  ui_seasons_arrowLeft/Right, and Back. Left and Right run Menu_Seasons_OnLeft/OnRight (upvalues
  mButtonList, the seasons' widgets, and mCurrentIndex) and leave the game's focus on the left
  arrow, where Down and Enter do nothing (the user got stuck there on 2026-10-03). menus.lua
  redirects arrow focus to the showing season's Play button (the scene button whose widget is
  mButtonList[mCurrentIndex]; selecting the widget itself only highlights it), quietly, and also
  focuses it when the screen opens; the spoken hint is "Enter to play". Tested by keys on
  2026-10-03 (Down, Enter, Right, Left, Enter into Season 1).
  Do not poll Buttons_GetSelected and reselect each frame: that looped (the season text repeated).
- Popups: `DialogBox(message, header, button1Node, ..., dlogFile)`, usually through UI_Confirm.
  Popups have no Escape binding, and nothing is selected until an arrow is pressed.
- Credits: `Credits(...)` plays a dialog; the text is one long block on agent
  "ui_creditsClosing_text".

### Season 1 framework (panes.lua and messagebox.lua)

- Different code base (projectseason1, menuseason1 scripts). Menus are panes: the global
  `MenuPanes` table and the `Pane` class (menupane.lua), with per-pane scripts such as
  pane_gameplay.lua and pane_saveslots.lua. The current mode is `mode_MainMenu`
  (mode_mainmenu.lua); it keeps the visible pane in an upvalue, `mCurrentPane`, which the mod reads
  with `TWDA.upvalue(mode_MainMenu.OnUp, "mCurrentPane")`.
- A pane has `name` ("Main", "Settings", "Gameplay", "Save Slots", "Play Style", "Episode"...),
  `agent`, `mControls` (every agent), `mIndexedControls` (the up/down list), `mSelectedIndex`,
  `mCurrentSelected` (nil in mouse mode until something is chosen), `mControlGroups`, and methods
  OnUp, OnDown, SelectNext(delta), UpdateSelection(old, new), OnMouseLUp(event) (a click; it uses
  `mCurrentSelected or event.agent`), OnLeft and OnRight, and on some panes OnA, OnX, OnY, OnLB,
  OnRB and OnBackButton. `NoBackButton = true` means the pane cannot be left with Back (Play Style).
- Agent properties: "Menu Control - Role" (Button, Label, Highlight, Arrow Button Left/Right,
  Title, Icon), "Menu Control - Group" (the row: "Subtitles", "Apply", "Back", "Slot 1"...), and
  "Game Selectable".
- Input: ui_menu.imap binds only the keyboard's Left, Right, A, D and Escape (to OnStartButton), and
  the controller. The mode's own OnUp, OnDown, OnA, OnX, OnY, OnLB, OnRB and OnBackButton lock
  input, call the pane, and unlock. `ShouldRejectInput` (an upvalue) refuses input while loading,
  while a message box is up, while input is locked, or during a pane change. `Menu_UsingJoystick()`
  is false on keyboard, so the panes behave as for the mouse.
- What panes.lua does: Up and Down call the mode's OnUp/OnDown (selecting the first item first when
  nothing is selected); Enter calls the mode's OnA if the pane has one, otherwise a click; Backspace
  calls OnBackButton. Each action runs in its own thread (they wait on animations); keys pressed
  while one runs or input is locked go into a short queue.
- Settings rows: the value button ("...subtitlesButton") sits next to a label agent ending in
  "Label" under a "...Parent" agent; the mod reads "Label, value". In mouse mode a click on the value
  steps it forward, and Apply and Cancel are only reachable by mouse (a controller applies with A
  on any row); the mod appends them to the arrow list (extrasOf, only for panes without OnA). The
  pane's own OnLeft/OnRight error on a row with no arrows (leaving input locked), so the mod wraps
  them to do nothing there (guardArrows).
- Save Slots (pane_saveslots.lua): the globals `mCurrentSlot` (follows the arrows; Delete and Copy
  use it) and `mSelectedSlot` (only a click sets it; Play and OnA use it) can differ, which would
  load the wrong save. The mod sets both to the highlighted slot before Enter. OnX deletes (with a
  confirmation box), OnY enters copy mode (upvalue `mbInCopyMode` of OnMouseLUp); in copy mode a
  click on a slot copies to it.
- Episode pane: no up/down list. Agents "_labelEpisodeTitle", "_buttonPlay" (Play, Continue, Get or
  Coming Soon), "_buttonEpisodePrevious"/"_buttonEpisodeNext" (hidden at the ends), "_buttonRewind"
  (OnX) and "_buttonStats" (OnY). OnLB/OnRB switch episodes; the pane's OnLeft/OnRight only do that
  on one console, so the mod maps Left/Right to OnLB/OnRB.
- Message box: `MessageBox_Display(dlog, messageNode, button1Node, button2Node)` pushes
  `mode_UI_MessageBox`, whose ui_messageBox.imap has mouse events only. Agents
  ui_messageBox_message, ui_messageBox_button1 and ui_messageBox_button2; the mode's OnButton1 and
  OnButton2 answer it (button 2 is No). messagebox.lua adds the keys.
- `AgentGetScreenPos(agent)` gives screen coordinates (0 to 1, y downwards); the mod uses it to read
  a control's texts in reading order and to order Apply/Cancel.
- Pause menu: `mode_PauseMenu`, same structure (upvalue mCurrentPane, pane "Pause"), but the mode
  has no OnA, so Enter clicks. Escape opens it during play (pause.imap -> Main_OnPause, which also
  calls Game_PauseAllDialogs).

### Season 1 during play (choices.lua, lookaround.lua, prompts.lua)

- Dialog choices: `mode_DialogChoice`. OnStart writes the option texts with AgentSetProperty "Text
  String" (collected by choices.lua). Number keys 1-4 pick (the game's own binding). Every way of
  picking goes through the local `selectChoice` in mode_dialog.lua (an upvalue of
  mode_DialogChoice.OnChoice); choices.lua wraps it with debug.setupvalue.
- Timed choices: the countdown is the dialog engine's own (`DlgGetChoices(instance, true)[1]`
  .Remaining/.Total). `PauseDialogTimer(true)` only pauses the on-screen timer bar, not the
  countdown. `Game_PauseAllDialogs()` / `Game_ResumeAllDialogs()` (wdgame.lua; DlgPause on every
  dialog; `Game_AllDialogsPaused()`) do stop it, as the pause menu does; a pick made while paused
  is kept and applied on resume.
- Hotspots: the reticle system (mode_reticle.lua). `TWDA.upvalue(Reticle_Update, "mUseables")` lists
  the scene's hotspots (agents; filter by "Game Selectable" and AgentIsHidden).
  `ReticleController_SetScreenPos(x, y, false)` moves the reticle and wakes it (true = do not wake);
  the reticle falls asleep (`ReticleUI_IsAwake()`) and drops focus a moment after the mouse stops.
  `Reticle_GetAgentFocused()` is the focused agent. In look-around scenes the camera is a "pan cam"
  (`CameraControlReticle_GetCamera()` with "Pan Cam - Horiztonal Max Percentage Allowed" > 0) that
  turns towards the reticle; things behind it (AgentGetScreenPos z <= 0) are reached by pushing the
  reticle to a screen edge. The game shows the focus with `Reticle_UpdateActionIcons(default,
  choices, defaultText)` (choices[i]["Choice Display Text"], in number-key order) and
  `Tooltip_Show(verb, noun)`; the display name is `Dialog_GetText(noun, nil, "text.dlog")`.
- reticle.imap: 1-4 choose an action (`OnChoice` -> local selectAction), mouse click does it
  (`mode_Reticle:DoAction()`); Enter only does it with a controller (`mbJoystickOn`), so the mod's
  Enter calls DoAction. DoAction needs the reticle's focus at that moment and has a short cooldown
  (upvalue mReticleNotActiveUntil); it starts the action with `Main_OnUse(agent)` or, when the
  hotspot's "WD Should Path" is set, `PathToAndUseAgent(agent)` (Lee walks there first). The mod
  hooks those two to see whether Enter actually started something, and re-aims and retries if not.
- Which hotspots count: Reticle_Update only considers useables for which its local
  `agentIsClickableNoDialog(useable)` is true (reach it with TWDA.upvalue); the mod lists only those,
  which removes things that are visible but not usable yet. The reticle is measured against each
  useable's dot (`useable.dot`, an agent; `AgentGetLogicalScreenPos(dot)`, same coordinates as
  `ReticleController_GetScreenPos`), not the object's own position, so the mod aims at the dot.
  Invisible trigger volumes ("...TriggerAgent") are left out.
- Hotspot list order: things in view first, then things behind the camera, fixed until the set of
  hotspots changes. Things that could not be focused are skipped until the player moves or the
  camera (CameraControlReticle_GetCamera) changes. `TWDA.lookDebug = true` logs Enter decisions.
- Death screen: `mode_UI_Death` (no input map; the words are an image, then "Click to continue" on
  ui_death_textMouse). `mode_UI_Death:UnPause()` is what the click does: CheckpointLoad.
- Names and verbs without focus: `agent.mProps[k]` where k is the upvalue kUseName or kVerb of
  Reticle_UpdateActionIcons ("WDUseable - Verb"). The name goes through
  `Dialog_GetText(noun, nil, "text.dlog")`; the verb is usually plain text already ("Look At",
  "Take") and empty for hotspots with several actions.
- Using a hotspot always goes through the reticle (focus it, then `mode_Reticle:DoAction()`).
  DoAction stores the chosen action (upvalue mActivatedActionIndex, plus agent.lastSelectedIcon)
  and the use instance it started (mUseInstance); when the hotspot's use dialog reaches its
  choices node ("Reticle presentation" user prop), `Reticle_HandleReticleInstance` selects
  `getAdjustedChoices(instance)[mActivatedActionIndex]` with DlgSelectChoice, but only for that
  instance and while mode_Reticle is active. `Main_OnUse(agent)` on its own (the old
  TWDA.useHotspot) therefore leaves the dialog waiting at its choices, and Main_OnUse_Simple has
  also locked the mode (SwapMode(eModeLocked), which deactivates mode_Reticle), so the scene stalls;
  this is what killed Lee at the zombie cop in earlier attempts. Removed on 2026-10-03.
- Such hotspots show their actions a moment after the focus: the presentation dialog calls
  Reticle_UpdateActionIcons(nil, choices). lookaround.lua waits for that (current.actionsFor)
  before DoAction. The choices node can be read without focus: `DlgEvaluateToNode(dlog, node,
  "choices", false)` gives {Dlog, Node ID}; `DlgChoicesGetDisplayProps(dlog, id)` maps the visible
  choices' ids to {"Choice Display Text"}; `DlgNodeGetChildNodes` lists all choices. The node is
  agent.mProps["WDUseable - Action Use Dialog Start Node"] in the agent's "WDUseable - Action Use
  Dialog File", else the scene agent's "Dialog Agent - File Primary" (findDialogWithNode).
- "WDUseable - Use Activate On Look" hotspots (look triggers such as obj_LookAtZombiesTriggerAgent)
  play their dialog as soon as the reticle passes over them (Reticle_FocusChange calls
  Dialog_Play directly). Never start them with Main_OnUse (that locks the mode).
- The reticle system is off (mode_Reticle deactivated; upvalue mbReticleSystemActive false) while
  any use dialog or cutscene runs; reticleReady() covers it.
- Out-of-view hotspots: the game's agentIsClickableNoDialog requires AgentIsOnScreen, so in
  look-around scenes lookaround.lua also lists selectable, unhidden useables that are off screen
  (AgentGetScreenPos x or y outside 0..1, or z <= 0), and turns the camera by holding the reticle at
  that edge (ReticleController_SetScreenPos(0.97, y) for right). The pan camera there is
  "reticleCamV" with "Pan Cam - Horiztonal Max Percentage Allowed" 0.7.
- Action scenes: `ui_panicmeter.scene` is not hidden (red vignette) and `Logic["Dying"]` is true for
  as long as one lasts. `Death_Enable(false)` (mode_ui_death.lua, mPrefs["Enable death"]) stops the
  death screen, but the scene then stalls rather than moving on, so it is not an assist.
- Time: `SetTimeScale(scale)` / `GetTimeScale()` slow the whole game (0.35 made the zombie attack
  about three times slower in wall-clock time). Always set it back to 1.
- Player and paths: `Game_GetPlayer()` (Lee), `AgentGetWorldPos`, `PathAgentTo`,
  `PathToAndUseAgent`, `PathAgentGetPathDistanceRemaining`, `PathAgentIsBlocked`,
  `WalkBoxesPosOnWalkBoxes`, `GetFreewalkEnabled()` (false in the guided bits).
- Movement: mode_Chored_Move.imap (W A S D and arrows); in guided bits the hint names the key.
- Tutorial hints are on agent ui_helptext_text (spoken by uitext.lua).
- The engine calls the global `EnginePostUpdate` every frame; hooks.lua hooks it so the mod's frame
  thread comes back within a frame after the engine kills it (the death screen did).

### Season 1 during play: free walking (navigate.lua, lookaround.lua)

- Free walking: input map Navigate.imap (the game's navigate.lua): W A S D and arrows
  (Navigate_OnButtonUp/Down/Left/Right) walk relative to the camera, Shift runs, a click walks to
  the spot (Navigate_OnMouseLUp). Check with `InputMapperIsActive("Navigate.imap")` (lookaround.lua
  canWalk). The cameras are fixed per area (backyard: cam_nav_yardPoolLevel and others) and cut as
  Lee walks; CameraControlReticle_GetCamera still returns "reticleCamV" with a pan range, so
  panningCamera() is true here although holding the reticle at an edge turns nothing.
- `AgentPathToAgent(Game_GetPlayer(), agent)` walks Lee there with the game's path-finding (as
  PathToAndUseAgent does) and only returns when he arrives (true) or stops (false; a movement key
  stops him). It must run in its own thread (ThreadStart), or it blocks the mod's frame loop for
  the whole walk. `PathAgentStop(lee)` stops it; `PathAgentIsBlocked(lee)` reports getting stuck.
  `PathAgentIsPathing` stayed false during these walks. Other path functions:
  AgentPathToPosition, PathAgentGetUsePosition, PathAgentDoesPathReachDestination,
  WalkBoxesPosOnWalkBoxes.
- Backyard hotspots all have "WDUseable - Far Use" set (usable from a distance), so the reticle
  only needs them on screen. Walking to one usually brings it into view (Woods, Gate); the Pool
  Cover stays out of every camera's view near it, also for a sighted player.
- What the mod does: Tab tries to focus the hotspot as before; where Lee can walk and it is out of
  view, after 2.5 s it says "<name> is out of view, N meters away. Enter walks there." Enter walks
  (in a thread), saying "Walking to <name>."; on arrival the reticle aims at it again and its name
  and actions are read. If it is still out of view and its use dialog has no "Reticle
  presentation" choices node (presentsChoices), the mod offers "the camera does not show it from
  here, but Lee can <verb> it. Enter to do it." and Enter uses it with Main_OnUse directly (fine
  for such simple hotspots; Pool Cover: "Maybe I'll just go for a dip."). While walking, and for a
  few seconds after such a message, the names of other hotspots the reticle passes over are not
  spoken (quietUntil), because they cut the message off. F6 adds distances in meters (game units
  are about a meter).

### Season 1 during play: struggles, fights, turn choices, peeking, inventory (2026-10-08)

- Struggles (mode_struggle.lua; struggle.lua). `Struggle_Start(agent)` pushes the local
  mode_Struggle (input map struggle.imap: Q (81) Struggle_Mash, E (69) Struggle_DeathBlow_B, Enter
  OnEnter which only works on one TV platform). Upvalues of Struggle_Start: mStruggleAgent (set for
  the whole struggle, cleared by Struggle_End), mode_Struggle, monitor (its upvalue update does the
  scoring; its upvalues mDeathBlowReadyStart, mDeathBlowController, kDeathBlowDefaultTime = 2).
  Each mash (`mode_Struggle:Struggle_Mash()`, ignored for 0.5 s after the mode starts) raises the
  agent's "Button Mash - Current Percentage", which drains between presses
  (ButtonMash_buttonMashMonitorThread, scaled by frame time); "Chore Scrubber - Percentage Current"
  follows it. At or under 1% for 0.75 s the struggle is lost ("Struggle Losing Allowed"); at 95%
  the finishing move is ready for about 2 s: on keyboard and mouse mDeathBlowButton is "B" = E.
  Missing it pushes the meter back. Struggle_Finish sets "Struggle Won"/"Struggle Finished". Slow
  time does not make mashing easier (both gain and drain scale), only gives more time to react.
- Fights. The reticle in combat mode (ReticleUI_InCombatMode() true) offers targets such as
  obj_babySitterFacePunch with no name, no verb and an empty tooltip; Reticle_UpdateActionIcons is
  called with no choices. Their "WDUseable - Action Use Dialog Start Node" says what they do
  ("punch_babySitter", "grab_hammer"). DoAction on them works without choosing an action. In
  fights the camera follows the reticle: holding it where the last target was turned the view so
  the next target was off screen and not clickable (agentIsClickableNoDialog needs AgentIsOnScreen
  and not AgentSelectionIsOccluded, and, unless "WDUseable - Far Use", Lee at its usePosAgent).
- Turn choices (mode_choice.lua; turnchoice.lua). Choice_Start pushes mode_choice; the logic
  agent "logic_mode_choice" (upvalue kLogicAgentName of mode_choice.OnButtonLeft) holds "Choice -
  Dlg Node Left/Right/Up/Down" (such as "choice_centerToShawn"; empty = nothing that way) and
  "Choice - Dialog File". The local transition(side) (upvalue of OnButtonLeft; sides kSideLeft 1,
  kSideRight 2, kSideUp 3, kSideDown 4 as upvalues of the mode's update thread,
  TWDA.upvalue(mode_choice.OnActivate, "update")) plays the node. On PC OnButtonLeft and friends
  return at once (not Xfinity) and OnTap only works with touch; a mouse player turns by pushing the
  reticle past "Choice - Reticle Move Width" from the centre (the update thread). The mod calls
  transition for the arrow keys, ignores a second press within 1.2 s, and, while a turn choice is
  up, lists only what is in view (holding the reticle at an edge would turn Lee too).
- Peeking (mode_peek.lua; peek.lua). Peek_Start(up, down, left, right) sets one chore per direction
  on "logic_mode_peek" (property names in the upvalue kChores of Peek_AddDirectionChore: "Peek -
  Chore Up" and so on; ResourceGetName gives "stealthmission_station1_peekup.chore"). OnDirection
  (W A S D and arrows) marks directions pressed; the peek sticks after the key is let go and the
  opposite key ends it; Peek_IsPeeking() says whether Lee is out.
- Inventory (wdinventory.lua; inventory.lua). The upvalue inventoryItems of WDInventory_Refresh
  lists every registered item: key ("Inventory - Hammer", "Drugstore - PlayerFood", "Office - got
  photo", "Drugstore - Player Batteries"), texture ("ui_useIcon_hammer.d3dtx", sometimes empty) and
  propValue (count or true/false, kept current by the game's property callback; the logic agent
  is "logic_inventory_items").
- Number keys on hotspots: reticle.imap 49-52 call mode_Reticle:OnChoice(evt) -> selectAction(code
  - 48), which needs mActionExists[i] (only while the reticle is awake on the object, upvalue of
  selectAction). The mod remembers the number and applies it with selectAction just before
  DoAction. mode_Reticle:OnBack(event) is the right click: it leaves close-ups.
- Dialog choices: mode_DialogChoice keeps the highlighted option in the upvalue mHighlightedIdx
  (OnDown/OnUp: idx + 1 / - 1, clamped, no wrap); Enter picks it.
- Fights, more: the moment to strike. The reticle closes (ReticleUI_Contract) while a walker is
  not yet in reach and opens again (ReticleUI_Expand plus an icons call) on the same target when
  it is; pressing early only gets Lee's "Wait for it..." (no penalty). lookaround.lua says "Now!
  Enter!" on that second opening (auto mode strikes). Entering combat mode makes everything on
  offer new again for actions.lua, and in fights only things in view are announced.
- Enter on something just announced (actions.lua or peek.lua) does the announced action (the
  truck's "Move To" rather than its first action "Look At"; looking verbs are Look, Examine,
  Observe and Inspect), unless a number key was used. Targets with no listed actions ("Zombie",
  icon only) are used directly. Announcements are ordered: doing, then moving ("Move To"), then
  looking, then talking, and list a hotspot's actions from its use dialog when it has several
  ("Zombie: Examine, Stab"; TWDA.hotspotActions).
- Guided paths (guided.lua): ChoredMovement_GetController() is nil unless a path is running;
  ChoredMovement_GetTimePercent() is the progress. Where the game shows no hint of its own, the
  mod says "Guided path. Hold W or S to move along it" (the Motor Inn stairs and walkway).
- Running for it (runto.lua): a table maps scene script and hint text to a target agent; on that
  hint the mod says "Run to Larry! Hold Shift and W and D", the keys worked out from where the
  target is on screen relative to Lee (W away from the camera, S towards it), updated as he
  moves. Only the drugstore's "Run!" is in the table so far.
- Peeking (more): leaning out at the Motor Inn is timed in some places (over the wall at the
  first cover, to the left at the RV: timer_ZombiesSeeLee, then cs_peekdeath_<station>_<dir>,
  about 5 to 6 s). peek.lua says "Get back now, <key>!" after 3 s of any lean, and reads what
  comes into view ("Zombie: Examine, Stab. Enter!"); actions.lua stays quiet while hiding.
- End of an episode: the statistics screen (ui_stats.imap; agents ui_stats_decision<n>Title, Desc,
  Result; Enter is the game's Stats_OnLeftClick) is read in full, and F6 repeats it; the credits
  (mode_UI_Credits, one text on ui_credits_text) are announced and read on F6; after an episode
  they cannot be skipped (OnMouseLDouble only works from the menu).
- Look triggers: hotspots whose use node starts "cs_" (or whose verb is "Cs") play a short scene
  when the reticle passes over them (the walkers seen from cover at the Motor Inn); the mod calls
  their action "Look".

### Season 1 during play: countdowns, moving cover, what the reticle can take (2026-10-08, third)

- What the reticle can take (lookaround.lua clickable and hotspots). Reticle_Update focuses a
  hotspot only if all of these hold: agentIsClickableNoDialog (on screen, in reach); with the mouse
  outside fights ("tighter selection": not Platform_IsBimodal, not Logic.bUsingJoystick, not
  ReticleUI_InCombatMode) the hotspot itself is under the reticle (AgentAtScreenPos(pos) ==
  useable); and CachedUseableQueue_GetCached(useable), the cached agentIsClickableDialogOnly:
  findDialogWithNode(agent, mProps[kUseDialog]) finds its dialog and
  DialogManager_ItemIsValid(dlog, node) is true (the game refreshes one hotspot per frame). The mod
  now checks all three. Dialog validity is three-way in the mod: true; false = loaded but not
  valid (story-locked, such as the plow lever until Lee leans out right at the tractor, the chock
  until he leans left) - left out of every list; nil = the dialog is not loaded here (dialogs load
  by area: from the barn side of the dairy the gazebo has none) - still listed as a walk target.
- A hotspot's actions without focus (actionsOf) also look in the scene's dialog files; before,
  a hotspot with no file of its own (most) got none, because ipairs stopped at the nil first entry.
  "Leg: Look At, Chop" at the bear trap.
- Countdowns (actions.lua countdown()). timer.lua: a timer agent counts "Timer Progress" (0 to 1)
  over "Timer Length" seconds of game time (frame time times SceneGetTimeScale times "Timer Speed
  Multiplier") while "Timer Enabled" and Logic["Timers Enabled"] (a global switch, toggled by
  Timer_GlobalToggle; not used by the mod) and, unless "Timer Pause During Dialog" is false, not
  in mode_Cutscene_Interaction or mode_DialogChoice; at 1 it plays "Timer Dialog on completion"
  (property callbacks registered with PropertyAddKeyCallback; found in debug.getregistry()).
  Background chatter timers have no completion scene; a countdown is a timer whose completion
  node starts "cs_" and whose progress moved in the last second. It makes an action scene (slow
  mode slows it), is announced once ("Hurry: about 60 seconds", first in the announcement so the
  key comes last), and F6 says the time left. Property keys are CRC64 (ECMA-182, as Telltale
  symbols) of the lower-cased name; PropertyGetKeys gives them as symbols, so names can be checked
  by hashing guesses.
- Moving cover (cover.lua). The dairy tractor: trigger_tractorRearEdge and trigger_tractorFrontEdge
  move with it; reaching either edge starts timer_tractorDeath (1 s). The mod measures where Lee is
  between them (0 rear, 1 front) and says "Walk: A", "Run: Shift and A" (below 0.25, until past
  0.5), "Stop" (above 0.7) or "Too far! Back: D"; the key is worked out by projecting Lee's position
  and a point a meter along the path through the camera in use (SceneGetCamera(scene) is the
  camera agent; CameraGetScreenPosFromWorldPos(camera, pos)). The tractor speeds up from 0.6 to
  0.9 m/s on the last stretch; Lee walks at 0.6. A table per scene, like runto.lua. While it runs,
  the game's hint is not spoken (it would cut the cue off), and actions.lua only announces, when a
  countdown starts, the nearest thing to do, preferring one whose action word is in the timer's
  name (timer_KickDeath: "Kick"); it waits up to a second for that one.
- Fights: Enter with nothing focused goes for the first thing to do, not one only to look at
  (zombie David's body lay beside the walker to kick); nothing only to look at is announced in a
  fight. Turn choices are announced again when the same choice comes back after a push (zombie
  David's head: "Turn: Left arrow to smash left, Right arrow to smash right", three times).
- Peeking: what the reticle lands on when Lee leans out is announced first. Enter does not follow
  an announcement older than 15 s, or one the reticle has read something else after.
- Announcements merge identical entries ("Hand, 2 of them: Look At, Chop") and rank a hotspot by
  its only action when it has no verb of its own (TWDA.offerTexts, soleVerb in actions.lua).
- Hints (uitext.lua) interrupt during action scenes ("Use the S (back) key to get away!").
- Known: a hotspot's verb property can be stale ("Zombie: Pull" announced where the action is now
  Kick; the reticle then says "Zombie: Kick").

### Episode 2 notes (2026-10-08, third session)

- Start (env_woodsBearTrap.lua): "Zombie: Hit" (a walker eating a rabbit), the talk with Mark,
  then the bear trap: after "It's now or never" a 60 s countdown (timer_chop1, ends in
  cs_outOfBullets) then 30 s more (timer_chop2, cs_outOfTime: David is left, Travis is shot). Leg:
  2 Chop, then "Leg: Chop. Enter!" four more times saves David (he passes out and is carried).
- Motor Inn (env_motorInn.lua; dev_saves\ep2_motorinn, David saved): rations. Talk to people
  ("Give Food To" is action 2), the food choice is "1: Exit. 2: [Give Half an Apple]...". Walking
  up to some people starts a talk by itself (Clementine). Mark and Larry ask for the axe. Kenny's
  talk leads into zombie David attacking Katjaa: a struggle (Q, E), then a turn choice three
  times (Right worked each time), "Walker: Shove", "Walker: Kick" four times on "Now! Enter!",
  "Use the S (back) key to get away!" (hold S), a second struggle, Carley shoots it. The checkpoint
  is at "Walker: Shove" (about 4 s to act after loading).
- Then Andy and Danny, and the drive to the dairy (env_dairyExteriorDay.lua; dev_saves\ep2_dairy):
  free roam; talk to Andy to walk the fence (env_dairyExteriorFence.lua): Arrow: 2 Pull, Zombie:
  2 Push, Zombie: Push, Hand: 2 Chop twice, Fencepost: Push (a struggle that waits), then the
  bandits. Behind the tractor (peek): lean right (D), Plow Lever: Pull; lean left (A), Chock:
  Pull; the tractor rolls (cover.lua guides); at its first stop lean left, Zombie: Pull; second
  stop lean left, Zombie: Pull, then kick it within 5 s (timer_KickDeath; "Now! Enter!" twice), a
  struggle, walk/run on to the gate. Checkpoints at the start of the hiding and at the second stop.
  dev_saves\ep2_after_tractor is the yard afterwards (env_dairyExteriorDay.lua).
- The bandit camp: talk to Kenny and Clementine (the swing) first; the gate where Andy and Danny
  wait ("Andy & Danny", use_gateHouse) then works (Lee walks over). env_woodsJoleneCamp.lua: hold
  W (guided), then free roam: Save Lots Box twice, Dairy Box, Box (on the table right of the tent;
  Lee walks there), Camera: Pick Up, Tent: Examine (enters it), Sleeping Bag (Clementine's hat),
  then Jolene: a choice, "Jolene: Shoot" (Enter shoots). Back to the dairy in the evening.
- Evening at the dairy (env_dairyExteriorDay.lua / env_dairyBarnDay.lua; the checkpoint is at the
  barn entrance): Barn Door (the yard gate on the way must be used first: Lee stops short and the
  mod says "Lee got to 10 meters from Barn Door and can go no further this way. Close by: Gate, 2
  meters"), Clementine: 2 Give Hat To, the Door at the back (a look-around view with Kenny: look
  at the Lock, then a Screw: Andy comes; "Distract Andy to get him out of the barn"), out via the
  Barn Door, the barn-side gate (obj_gateBarnDairyExteriorLeft), Toolbox: 2 Use, Multi-Tool: Use,
  Generator: 2 Use (a close-up): Power Switch: 2 Push, Panel: 3 Use Multi-Tool On, Belt: 3 Use
  Multi-Tool On (Andy then fixes it), back to the barn's Door: a 60 s countdown, Screw: 2 Use
  Multi-Tool On four times, Andy: dinner. env_dairyHouse.lua (slot 2's save now): the stairs need
  S (not W) to climb (Stairs: Enter walks to the foot, W steps on, S climbs; the mod says so);
  upstairs the Closet Door: Open (a close-up); the Power Cord is just below its view: 2 Use ("What
  the hell?", a light behind the wall); Bedroom Door: Open; Bookshelf: 2 Push; Door: Open (Mark,
  legless); then "Get to Clementine before she eats!": Stairs, W then S down... (S went down
  here), Clementine (Lee walks there), dinner choices.
- Meat locker (env_dairyMeatLocker.lua; dev_saves\ep2_meatlocker): Air Conditioner: Examine;
  Larry's heart attack is a turn choice (Left = Kenny, Right = Lilly; "choice_CenterToLeft", the
  mod now names the person on that side) that resolves by itself when nothing is pressed; Air
  Conditioner again (a close-up: Backspace out), Lilly: Talk To (coins), Larry: Search, three
  Pockets: Search (wallet, ring, coins), the two Screws: Unscrew (from the air conditioner view),
  Clementine goes through the vent. Barn at night (env_dairyBarnNight.lua; dev_saves\ep2_barnnight):
  take one weapon (Sickle: Take), Kenny, Door: Use, a guided path (W), hiding (lean A when Kenny
  says "See where he is now"), "Grab the gun!!": Rifle: Grab, Danny: Eviscerate (about 3 s),
  choices, Danny's fate: "Danny: Kill" or "Danny: Spare". Outside (env_dairyExteriorNight.lua):
  guided paths, Brenda; Screen Door: Open; the showdown: walk (W) until each warning (the dialog
  BrenedaShowdownTriggers: "Stop right there!", "Stay back!", "I don't want to kill you, Lee!"),
  stop within about a second, Brenda: Talk To, first choice, walk on; then Andy: Punch, two
  struggles, "Andy: Block. Enter!"; last: Kenny "Walk away" (or kill Andy). The walk home
  (env_woodsAbandonedCamp.lua; dev_saves\ep2_car): guided "Approach the car slowly" (W),
  Tailgate: 2 Unlock, Food, Supplies twice, Food, Hoodie, then the statistics and credits.
  Episode 2 done by keys on 2026-10-08 (late).
- Later in the third session (after the user said "Try again" when the session had stalled): the
  helper TWDAccess.exe was reported by Windows as hung and closed (AppHangB1, 17:21) while the
  game ran on, silent. Cause unknown. During play the helper writes only to its log files (Log.Write
  echoes to the console, but is only used at start and exit), so a frozen console is unlikely; a
  blocked speech thread (prism_backend_output to NVDA on the STA thread) would fit better. If it
  happens again: note what NVDA was doing, and consider a watchdog that restarts the speech thread.
- Last part of the session (user: "Keep going"): guided.lua says "Stop! Let go of W." when
  someone warns Lee while he moves on a path (subtitle phrases, only while a key is held, and the
  Dialog_Play node "BrenedaShowdownTriggers"), then offers what can be done standing still
  ("Brenda: Talk To. Enter to do it.") and, after the talk, "Go on: hold W."; it ignores a key
  held under a quarter second. subtitles.lua has TWDA.onSubtitle handlers. Outside action scenes,
  a single new thing gets "Enter to do it." (only when it is the only thing that can be done:
  "Danny: Kill" and "Danny: Spare" get "Tab to choose, Enter."), and a hint naming its action
  ("Grab the gun!!") gets "Enter!". A hotspot's actions from its use dialog (only choices with
  "Reticle presentation") win over its verb property, which can be stale ("Danny: Talk To" was
  really Eviscerate). Enter with nothing chosen takes the only usable thing. Floors are only
  marked in scenes with stair triggers, at 2.6 m (the meat locker's air conditioner is high on a
  wall); stair triggers named "chorebox" are skipped. Entering or leaving a close-up clears the
  "can't be reached" marks. Turn choices whose nodes only name a direction ("CenterToLeft") name
  the person on that side of the screen. A use node like "walk_away" names the action ("Kenny:
  Walk away"). Tools: stopgo.ps1; play_by_ear.ps1 starts walking on "Guided path. Hold W or S",
  walks on "Go on: hold W.", stops on "Stop!", presses Enter on "Enter to do it.".
- Also new in the later part: things on another floor are marked in F6 ("7 meters, upstairs"),
  walks to them say "It is upstairs"; the nearest stair trigger on Lee's floor is offered as
  "Stairs" (a place, not a hotspot: Enter walks there, "At the stairs. Hold W or S to go up or
  down."); guided.lua learns which key moves the path on ("S goes on along the path", "W does not
  move Lee here. Try S", "Halfway"); free-walk lists are nearest first and Tab starts from the top
  after Lee has moved; a walk that ends far short says so and names what is close by; close-ups
  (WDBackButton_IsOccupied) are announced in F6 ("Close-up, Backspace to go back") and list only
  things within 3 meters; when one thing behind the camera cannot be reached, all things behind
  are skipped until Lee moves or the camera changes (the camera check now includes the scene's
  camera, so leaving a close-up counts).

### Episode 3 notes (fourth session, 2026-10-09 00:00 to 02:00; written up by the fifth)

Played in slot 2 from the Episode 3 "Play" button (after dev_saves\ep2done; the game asked
whether to fill in missing decisions: "No" returns to the episode screen, "Yes" starts it).

- Macon (env_drugstoreExterior.lua, the Episode 3 version): Lee and Kenny scouting. The jeep:
  Push does nothing useful; the winch at its front is only offered once Lee has walked left along
  the jeep to its front (hidden until then; item F). Winch: take the cable, "Trailer Axle: Attach",
  then the winch control (to the left); climb onto the jeep and take Kenny's hand (twice). Kenny's
  hand was left out at first: nothing was under its dot (AgentAtScreenPos returned nil); the mod
  now counts a nil hit as visible and probes points near the dot, cached for half a second, only
  for dots on screen.
- The supply run in the pharmacy: from cover the shelves are read out when Lee first hides
  (peek.lua counts what is usable the first time). Its checkpoint drops straight into the escape
  (Lee dies about 9 s after loading if nothing is done): the counter, a door struggle, the fridge,
  the zombie pilot (two blows: the mod says "Again! Enter!" when the same character is offered
  again within 10 s of a use, outside fights, only for characters (not obj_ agents) with one
  action that is neither looking nor talking), then a struggle.
- The Motor Inn in the evening (env_motorInn.lua; dev_saves\ep3_bandits): "Lilly's Door: Open,
  Look At. Enter to do it." (the walking-case announcement; people are left out of it so every
  talk does not end with "Kenny: Talk To. Enter to do it."). Lilly's talk; Duck offers to play
  detective; the clues: Clementine (she must mention the missing pink chalk before Duck finds the
  scuff; talk to her again), Broken Glass, Chalk X (2 Inspect), the gate, the scuff, the fence, the
  grate, then the bag, which starts the bandit attack.
- The bandit attack (env_motorInnBanditAttack.lua): the first shot works by itself; then Lee hides
  behind the RV. Leaning out left (A) raises a rifle scope (mode_sniper, about 10 s,
  timer_sniperScope) while bandits duck in and out of cover; Lee is shot about 35 s into the hiding
  if nobody is hit. sniper.lua: "Rifle scope. Enter shoots when someone is in sight.", "In sight!
  Enter!", "Gone.", "Hit!", "Missed."; Enter fires through the game's sniperFireAtPos at the point
  where the target itself is under the screen (the game's own Enter fires nothing on PC; only a
  click). Phase 2: three bandits. Phase 3: walkers come at the RV from both sides; with the scope
  up and Lee not leaning, A and D move him to the other side ("Nothing in sight here. D for the
  other side.", then "Other side."). Only head shots stop walkers: obj_ZombieHead<n> is a child
  of Zombie<n>, and the mod shoots the child; a body shot counts as a hit and changes nothing. The
  hotspots' verbs mean nothing here ("Talk To" on a walker); while the scope is up only targets
  are selectable, so the mod takes exactly those. Won by ear with 10 shots, no misses.
- On the road (env_road.lua; dev_saves\ep3_road): the RV argument about the traitor, Lilly left
  behind; in the RV talk to Clementine, then Katjaa; a short struggle that ends by itself
  (struggle.lua no longer says "Halfway" the moment one starts).
- The wrecked train (env_wreckedTrain.lua; dev_saves\ep3_train): Katjaa wants water for Duck: the
  nearest Boxcar Door has it. Lee ends up inside the boxcar (its floor is raised) and cannot walk
  anywhere; the way out is the boxcar door, then the ladder from the train's walkway. When a walk
  fails, the mod's "Close by:" now prefers doors, ladders and stairs over whatever is nearest
  (Kenny). The puzzle (gamepressure's walkthrough has the order): up to the engine's cab (Cab
  Door), a notepad that needs a pencil (Clementine says it is in the RV: RV door, Pencil: Take),
  rub the pencil on it; readables.lua reads the page aloud (cam_notepad: "Engine Startup. Panel 6:
  seven switches, left to right: down, down, up, up, up, down, up. Panel 5: the left dial turned
  sideways, the right one straight up. Panel 9: a handle, turned left, then turned right."). The
  notepad view has no reticle; Backspace calls the game's back action there. The cab console
  close-up: panels.lua names the controls "Switch 1 of 7" and so on and says how each is set
  ("up", "down"; from logic properties found with logicdiff.lua); Kenny says the dash lit up when
  panel 6 is right; then the left dial ("Now we're talkin'!"; the right dial does nothing). The
  engine compartments: one holds the tools (monkey wrench, spanner, spike remover: take the spike
  remover; only one can be taken), compartment A holds panel 9's handle (turn left, then right:
  "Holy shit, we're golden!"). Kenny: "we're still attached": Coupler Pin: Pry (the spike
  remover). Chuck turns up in the boxcar.
- env_trainBeforeStop.lua: talk to Katjaa, Chuck and Clementine; the throttle; Katjaa asks Lee to
  wipe Duck's face (Rag); Lee will not go back in before talking to Kenny (the cab door); Kenny
  will not stop the train: a fist fight ("Fist: Block. Enter to do it."); the by-ear script won it.
- env_clearing.lua: Duck ("Duck: Shoot", worked by ear).
- env_trainAfterStop.lua (slot 2's save; dev_saves\ep3_trainafter): Ben and Clementine in the
  boxcar, the whiskey and the backpack, Chuck's talk, Clementine's shooting lesson: choices that
  steer her aim, taking turns ("Aim left. Aim right. Keep it steady." and "Aim higher. Aim lower.
  Keep it steady."); two logic values (-1, 0, 1) say how far off she is and she fires once both
  are 0. The mod puts where her aim is before the choices ("Up and down, her aim is on the
  bottle. Choices. 1: ..."; panels.lua TWDA.choiceContext). Seen working once, after a live reload
  of choices.lua (which then broke choice input with double hooks); not yet replayed cleanly. The
  game closed during a second Chuck conversation (see Start here).

### Fifth session (2026-10-09 morning): the end of Episode 3

Played in slot 2 from dev_saves\ep3_trainafter to the end of Episode 3 (dev_saves\ep3done; the
game is back at Season 1's menu, and Episode 4's "Play" is next).

- The shooting lesson (env_trainAfterStop.lua) works by ear: "Left to right, her aim is too far
  left. Choices. 1: Aim left. 2: Aim right. 3: Keep it steady." Both bottles hit.
- The rest of the train: Backpack: 2 Take (scissors; Clementine's haircut follows when Lee talks
  to her), Bottle of Whiskey: 2 Take, Chuck (outside the cab's front door): 2 Give Bottle To,
  Kenny (first option), Map Bin: 2 Search (the map), Chuck again (the map), Clementine (the
  Marsh House), then the train stops at the overpass (env_overpass.lua; dev_saves\ep3_overpass).
  Getting about the train: the cab has two Cab Doors (front: Chuck; rear: the walkway by Ben),
  the boxcar's front Boxcar Door joins the walkway. Entering the cab sets off a remark from
  Kenny.
- The overpass: Ladder (Omid and Christa), FRS Truck: Open, Truck: Search (tape), Ladder down,
  walk to the Train Station (100 m; env_station.lua): Window: Look At, Clementine: 2 Boost (she
  unlocks the door), Door: 2 Open, then "Hurry: about 15 seconds. Door: Open, Prop. Enter!"
  (Enter props it with the spike remover; if time runs out Lee just steps out again). Careful:
  using the propped Door again takes the tool back and closes it. Gap: Look At, Clementine: 2
  Boost at the gap starts the attack (its checkpoint is right before it): "Press W to back away!"
  (a guided path, env_station_move_LeeMoveBackwardsToDoor_1); hold W all the way; punch only on
  "Now! Enter!" (a blow before a walker is in reach stops Lee and both walkers catch him:
  cs_killedWhileTwoZombiesApproach); "Spike Remover: Pick Up" when it comes in reach; "zombie, 2
  of them: Hit"; a struggle (Q, E); "KEYS! NOW!": Key: Take, "Cage Door: Unlock. Enter to do it.",
  "Cage Door: Open. Enter to do it.", "zombie: Shoot. Enter!". Then Christa, Blowtorch: Grab,
  Clementine's question, the Door back to the overpass.
- The tanker: Ladder: 2 Use, Hitch: 3 Cut (the hose leaks), Blowtorch: 3 Use Tape On, Blowtorch:
  2 Use, Omid: 2 Give Blowtorch To, "Blowtorch: Use. Enter to do it." (dropped on the walkers),
  the jump choice, then a turn choice between Christa (left) and Omid (right): turning right
  offers "Omid: 1 Grab, 2 Yell To" (not done in time in this run: "You didn't help"; the
  statistics say both live anyway). env_epilogue.lua: Kenny, the walkie-talkie stranger,
  NextTimeOn.lua, the statistics, the credits.

Mod changes in the fifth session (all tested by ear in the station attack unless noted):
- actions.lua: a fight while Lee moves on a guided path announces its unnamed targets as
  "zombie, 2 of them: Punch. Keep moving. Enter only when told" (TWDA.isFightTarget: no game name).
- actions.lua orderByUrgency: things to do that a line said in the last 8 s names come first
  ("KEYS! NOW!" puts Key before Cage Door), then what the reticle is on.
- actions.lua sceneoffers (fixed views): a hotspot that gains an action is announced with just
  that action ("Cage Door: Unlock. Enter to do it.") and Enter does it (TWDA.preferNextTab(name,
  actionIndex) sets lookaround's remembered pick, which now always wins over "first action that
  is not looking"); the thing just used that changes its actions is announced again ("Cage
  Door: Open. Enter to do it."). In free walking, a hotspot in view that gains an action
  is announced ("Omid: Give Blowtorch To. Enter to do it."; not yet heard in a test).
- actions.lua: a turn choice counts as an action scene (what is in view after turning is
  announced with its key; slow mode applies). turnchoice.lua: nodes that only name a direction
  ("choice_centerLeft", "choice_left") name the person on that side, where a person is any
  named agent that is not an obj_ (Omid, Christa: "Grab", "Yell To"). Both untested (built
  after the finale was played).
- lookaround.lua: "Ben is out of view from here, but Lee can still talk to Ben. Enter to do it."
  (was "...the camera does not show it from here, but Lee can talk to it").
- tools\dev: use.ps1 matches whole names ("Chuck", not "Chuck's Camp"); play_by_ear.ps1 holds the
  key on "Press W to ..." through the fight (only death or the time limit lets go) and takes
  -Skip "regex" (lines to ignore, to see what the game does without them).

### Episode 4 notes (fifth session, 2026-10-09)

Started from dev_saves\ep3done (Season 1 menu, slot 2, Episode 4 "Play"; no missing-decisions
prompt this time).

- Opening (PreviouslyOn.lua, env_savannahStreets.lua): a long silent shot; the game only runs
  while focused. The bell, then "Hurry: about 8 seconds. Zombie: Shoot. Enter!", then the rifle
  scope (sniper.lua) at the walkers going for Clementine: "In sight! Enter!", "Hit!" six times.
- The house yard (env_manorExteriorDay.lua): Pet Door is locked (needs a dog's collar chip);
  Shovel: Pick Up ("Dirt Mound: Look At, Dig. Enter to do it."), Dirt Mound: 2 Dig, Carcass: 2
  Pick Up (the pet collar), Pet Door: Unlock ("House Door: Unlock" is announced too).
- Inside (env_manorInteriorHouseSearch.lua; dev_saves\ep4_house): open the three downstairs
  Doors, then Christa asks about meds; Ben upstairs: a guided path (W) to the attic
  (env_manorInteriorAttic.lua), the zombie boy: choice 2 ("I'll take care of it"), Zombie: Look
  At, then "Zombie: Look At, Shoot, Bash, Stomp" (3 Bash used), the burial (yard): Grave: Place
  Boy In, Shovel: Pick Up, Loose Dirt: Shovel four times, a stranger watches; Ben stays.
- River Street (env_savannahRiverStreet.lua): Newspaper Machine (Open fails), Telescope ("needs
  a quarter"), then "Cash Register: Open" and "Newspaper Machine: Bash" are announced as new;
  Bash gives coins; Telescope: Use Quarter On; in the telescope view the second Building (the
  one behind) shows the stranger; a guided path (W, about 15 s) to the newsstand; hiding (lean
  W only); Molly's attack: "block first punch: Block. Enter!", "Now! Enter!", "block second
  punch: Counter. Enter!" (won by ear); talk; the alley: Kenny's Hand: Grab, Dumpster: Push,
  Manhole: Open, Climbing Pick: Pick Up, Manhole: Pry, a struggle (all by ear; each announced as
  "Hurry: about 1 second", see the countdown change below).
- The sewers (env_savannahSewers.lua; dev_saves\ep4_sewers at the start, ep4_sewers_after after
  the walker grab): stairs down are free walking here (A went down from where the mod's
  "Stairs" stops; the mod's "Hold W or S" was wrong for this one); the slope down is a guided path
  (W). At the bottom: Passage Way (the one 13 m away, obj_passageWay, "Enter"; the one 31 m away,
  obj_passageTowardsExit, leads into the walkers), the valve Pipe: 2 Turn right, 4 Pick Up
  (the valve), the other Passage Way: 2 Pry, then the OTHER pipe (obj_drainagePipeLogical01,
  the one away from the wheel; both are called "Pipe"): 2 Place Valve, 2 Turn right ("Here
  they come"; the checkpoint is here): about 25 s to get into the low passage (Tab to "Passage
  Way, to your left", Enter walks, Enter again). In the passage hold W (camera
  cam_nav_halfHeight) to the bend, then S (camera halfHeightValve) out at its north end into the
  main corridor. Path-finding through the passage goes out of its south end past the walkers
  (death), so only walk with the mod's targets from the corridor. "Way on along the tunnel"
  (new, SCENE_PLACES in lookaround.lua: trigger_dialog_chuck) is where Chuck lies. Then
  "Zombie: Attack"; a walker grabs Lee's leg from a grate: "zombie arm: Shoot, Pry" (Pry, not
  Shoot: the shot brings the group and kills Lee about a minute later), a struggle, "Zombie: 1
  Shoot, 2 Attack" (Attack). Upper tunnel: Ladder: 2 Pry (Lee falls, loosening the Sign), Sign:
  Pick Up, Passage: Walk Through (the shelter, env_cancerGroupHideout.lua), Door: Open, Vernon's
  group, "Gun: Calmly Take. Enter to do it.".
- Back at the house (env_manorInteriorClementineSearch.lua; dev_saves\ep4_clemsearch): the real
  stair top is trigger_dialog_stairsTop; S from there goes down. Backyard Door, Shed Door
  ("About 15 seconds left" there is harmless), Clementine and the radio, the planning talk.

### Fifth session: more mod changes made during Episode 4

- carryover.lua: a save the hooks miss is caught by comparing the slot files' contents
  (wd1_saveslot1..12.bundle under %USERPROFILE%\Documents\Telltale Games\The Walking Dead
  Definitive, read as the module loads, before the scene's script runs) every 3 s ("slot file
  changed: save slot ..."). The house search save at 06:26 was missed by every hook (cause not
  found; Checkpoint() in checkpoint.lua calls SaveSlots_Save or SaveGame, both hooked); the fix
  was only tested by reading the code, as later saves went through SaveSlots_Save. recordSave
  logs "a save, but no slot known" when it cannot record.
- actions.lua countdown: time left divides by "Timer Speed Multiplier" and the scene's time
  scale (untested; the alley chase said "about 1 second" each step).
- actions.lua, free walking: a hotspot in view whose action list gains something is announced
  ("Dirt Mound: Look At, Dig", "House Door: Unlock", "Pipe: Pick Up"), held until control is
  back; not on the thing just taken from ("Pipe: Place Valve" after taking the valve), not when
  the one-thing announcement already said it. Shooting or killing is never offered with "Enter
  to do it." in free walking (the barricade walkers on River Street).
- actions.lua: "A number key to choose, then Enter." where the one thing announced has several
  actions; in action scenes the numbers are said ("Zombie: 1 Shoot, 2 Attack. Pick a number, then
  Enter!") and lookaround's strike cue too ("Now! 2 Shoot, 3 Pry. Pick a number, then Enter!").
- lookaround.lua: plain Enter takes the first action that is not looking and not "Shoot" when
  there is another (firstUseAction); a number pressed before the reticle reaches a just-announced
  thing applies to that thing; Enter follows a fresh announcement (8 s) even when the reticle
  drifted onto the thing beside it, unless Tab was pressed since; "is it only looking" is judged
  by the action list, not the (often stale) verb property ("Carcass: Look At" was really "Look
  At, Pick Up"); camelCase name keys that resolve to themselves are made readable ("zombieArm" ->
  "Zombie arm"); camera triggers ("trigger_cam_upstairsWide") are no longer taken for stairs;
  SCENE_PLACES adds walk targets per scene where the way on has no hotspot.
- turnchoice.lua: no longer names Lee or walkers as the person on a side; each node is named
  once while the choice lasts (people moving on screen made the name flip and the choice be
  announced over and over).
- tools\dev: where.ps1 (hold a key, print Lee's position, camera, dying), trace_saves.lua (log
  calls to every save-looking global in the current state), play_by_ear.ps1 -Prefer Pry,Attack
  (answers "Pick a number" with the first listed word found).

Open problems seen in Episode 4 (also in "Not done yet"):
- The first Enter right after a mod walk arrives often does nothing (house doors, the shed door,
  the grave); a second Enter works. Traced once: Enter with focus on the door, doAction ran, no
  Main_OnUse and no retry message. Not solved.
- Walks take the shortest path and can lead Lee into walkers (the sewers). Ideas: stop a walk
  when the panic vignette or Logic["Dying"] appears and say so; per-scene "avoid" notes.
- Names still raw in places: "christa and omid", "door manor", "fountain" in the burial yard,
  "block first punch", "map savannah", "tape danger", "shovel empty", "valve on", "bottle
  whiskey", "key train station", "ice climber" (the climbing pick), "bottle breakable".

### Season 1 during play: rifle scope, panels, readables (fourth session, 2026-10-09)

- Rifle scope (mode_sniper.lua; sniper.lua). Active while InputMapperIsActive("mode_sniper.imap").
  The scope turns with mouse drags (two pan chores) and a click fires: sniperFire (upvalue of
  mode_sniper.OnRelease) calls sniperFireAtPos(screenPos) (its upvalue), which hits when a target
  is what AgentAtScreenPos finds there. The mod tests points around each target's dot (and the
  agent's own screen position) every 0.08 s, nearest target to Lee first.
- Logic values (panels.lua): the game's logic properties are Logic_IsReady's upvalue mLogicProps;
  keys are symbols (CRC64 of names the mod does not know), found by using a control and seeing
  which value changed (tools\dev\logicdiff.lua; propdiff.lua does the same for one agent's own
  properties). panels.lua also gives TWDA.hotspotLabel (a name for an agent) and
  TWDA.hotspotState (its setting, read in focus speech and F6).
- Drawn pages (readables.lua): when the scene camera (SceneGetCamera(SceneGetBottomScene())) is
  one in its table, the page's description is read once and F6 repeats it. The descriptions were
  written from screenshots (tools\dev\shot.ps1).
- Carry-over: the note's timestamp is now seconds of the day from os.date, because os.time() only
  changes in 128-second steps with the engine's 4-byte float numbers (t + 60 == t); the old stamp
  made the bootstrap ignore a fresh note on the pharmacy-to-Motor-Inn LoadScript. The bootstrap's
  log line now says why a note was not used ("[note 300 s old]"). carryover.lua also records the
  slot's scene on SaveLoad_AutoSaveDelayed, SaveLoad_Checkpoint and friends (the save at the start
  of env_trainAfterStop.lua went through none of the first four).

### Episode 1 notes (what the game expects, as found while testing)

- Police car: choices; look-around where only the rear-view mirror counts at first ("Look At").
- Crash: wake in the car; Tab to the window (behind Lee), Enter 3 or 4 times to kick it; hold W;
  Window: 2 (Climb Out), Enter; hold W about 30 seconds to limp along the car to the cop.
- At the cop: Keys: Take, then Handcuffs: Unlock makes Lee drop the keys ("Shit.", scripted); take
  them again, Unlock again (sometimes once more).
- Zombie cop (solved 2026-10-03; walkthroughs agree, verified in the game). Times are game seconds
  after the checkpoint loads (the mod's TWDA.now; slow mode stretches them 1/0.45 in real time):
  - About 10 s: "Use the S (back) key to get away!". Hold S until Lee's back is at the car (about
    5 s of game time; dialog backingAwayFromCopFinished). Releasing early leaves him short and
    the scene waits.
  - Then look around: the shotgun shell lies to the right (obj_shellShotgunWD, "Take"), the shotgun
    to the left (obj_shotgunWD, one visible action "Pick Up"). Either order works; walkthroughs
    advise the shell first. With the mod: Tab reaches them (the camera turns), Enter uses them.
  - After both, Lee loads, fumbles and drops the shell: obj_shellShotgunWD_ground ("Take") appears
    near his leg, on the right, and the reticle is usually already on it; Enter.
  - Lee then loads ("Don't make me do this...") and the shotgun aiming mode starts (about 38 s):
    mode_shotgun (below). Fire with the cop's head under the crosshair: cs_ShootZombieSuccess. A
    miss plays cs_shootZombieFailure.
  - At about 54 s, whatever has happened, the cop catches Lee (cs_zombieCatchesLee, Logic["Dying"]
    true, red vignette) and Lee dies about 11 s later unless he shoots in time. The look trigger
    (SeeZombies) is not needed; starting it via Main_OnUse made the cop catch Lee early
    (cs_zombieCatchesLee_Far, 12 s after it).
  - After the kill: obj_shotgunWD_LeeDrop, then Cop and obj_LookUpHillAgent (someone watching on
    the hill; then calling for help and running to Clementine's house). Not played yet.
- Shotgun aiming (mode_shotgun.lua; only in this scene: its chores are
  cam_pan_player_horizontal/vertical_adv_woodsClementineStage4). Input map mode_shotgun.imap is
  active and ReticleUI_InCombatMode() is true. ShotGun_Update sets the pan chores' times from the
  mouse pointer every frame: `h_chore:MouseUpdate(x)` and `v_chore:MouseUpdate(1 - y)` with x, y =
  `ScreenToViewport(CursorGetPos())`, absolute (0 to 1 is the whole pan). So
  `CursorSetPos(ViewportToScreen(Vector(x, y, 0)))` aims. Firing is Shotgun_Fire (upvalue of
  mode_shotgun.OnGamepadButtonA; a click calls it): success when
  `AgentAtScreenPos(Vector(0.5, 0.5), true, cop) == cop` (in practice the head; obj_ShootZombieCopMiss
  covers the rest). OnEnterKey and the arrow handlers return at once unless Platform_IsXfinity, so on
  PC only the mouse works; aiming.lua calls mode_shotgun:OnGamepadButtonA() for Enter. At the start
  (pointer 0.5, 0.5) the head is above and right of the crosshair; about (0.60, 0.42) hits it, and
  it moves as the cop crawls closer. Measuring: AgentGetScreenPos and the scene camera
  (cam_pan_player, also CameraControlReticle_GetCamera "reticleCamV") do not follow the pan;
  `CameraGetScreenPosFromWorldPos(AgentFind("cam_pan_player_horizontal"), headPos).x` does follow
  the left-right pan (moving the pointer right moves the head left on screen, about 2 screen widths
  per pointer unit); nothing found follows the up-down pan, so the aim assist sweeps the pointer
  height between 0.25 and 0.65 until the hit test says the cop is under the crosshair. Screenshots
  (game_input.ps1 -Screenshot) were how the mapping was checked.

- Clementine's house, the babysitter (env_clementineHouseInterior.lua; user's checkpoint and
  dev_saves\house start inside the first struggle, which is lost about 2 s after loading if
  nothing is pressed). Order: struggle 1 (logic_babysitterStruggle1: Q then E) -> punch her face
  (obj_babySitterFacePunch, combat reticle; about 10 s) -> Lee slips: punch/kick again while she
  crawls (about 3 s before cs_leeDiesBetweenKitchenAndDoor) -> struggle 2 -> Clementine holds out
  the hammer: obj_hammerWD_Clementine ("hammer: Grab") and the face are both offered; grab the
  hammer -> hit her about five times as the face comes back (obj_babySitterFacePunch again; a 10 s
  timer timer_BabysitterAttackHammer, and ClemHouseHint_WaitForHammer). Then "Did you kill it?".
  Scene functions: ClemHouseInt_* (AttackStart/Success/Fail, StartFightCrawl, MovePhaseStart with
  reversed scoot-away controls, not met in testing).
- Leaving with Clementine (env_clementineHouseExterior.lua): obj_Gate is on screen but not
  clickable until Lee stands at its use position (not "Far Use"); walking there is interrupted by
  Shawn and Chet talking (Lee stops short; Tab and Enter again). Then the car in the road: "car in
  way: Push" twice, timed (Lee dies about 35 s after "Lee, quick!"); its middle is just off the
  left edge but its click dot is on screen.
- Hershel's farm (env_hershelFarmExteriorNight.lua, then env_hershelFarmExterior.lua): talk to
  Kenny, Katjaa, Clementine, Duck, Shawn ("Need a hand?"), then Hershel (35 m away; the walk takes
  about 40 s). Hershel's talk ends in the fence attack (autosave at "GO! I'll get my gun"; the
  attack starts about 18 s after loading that). Phase 1 (10 s, timer_LeeSavesNoOne): turn choice,
  Left towards Shawn, Right towards Duck; each view offers "Help" (obj_attackStationShawn/Duck).
  Helping Duck: "Zombie: Hit" (twice), Kenny then pulls Duck free ("I got you!"), Lee: "Now
  Shawn!", and Shawn dies regardless. Doing nothing plays cs_leeDoesNothing; phase 2 then offers
  "Shawn: Help" for another 10 s. Hershel's reaction differs.
- Macon: env_drugstoreExterior.lua (item B), env_drugstoreInterior.lua (free roam after a long
  talk; the checkpoint is at free roam): Energy Bar (take), Radio close-up (flip it over, Battery
  door: no batteries; two "Battery" then appear: take both; give them to Carley, action 3; Radio
  again: flip, battery door, Batteries, battery door, Antenna, flip, On/Off: "You fixed it!"),
  Office door -> env_drugstoreOffice.lua: Pallet, Clementine, Alley, Photo (2 Take), Carley's talk,
  Desk (2 Move; Clementine cuts her finger), Drawer (Open, Search), First Aid Kit (2 Search: gives
  the bandage), Clementine (2 Examine finger of) -> close-up "Finger: 1 Pull on, 2 Inspect, 3
  Bandage". Exit, then Carley: "You ready to head out?" -> the Motor Inn.
- The Motor Inn (env_motorinn_stealthmission.lua; dev_saves\motorinn). Hiding at stations with
  the peek keys (taps stick; the opposite key brings Lee back). Order that worked: lean left (A):
  Pillow, 2 Take; lean right (D): Truck: Move To; at the truck lean left: Zombie: 2 Smother (the
  pillow muffles Carley's shot); Door: Open; Spark Plug: Take; Gear Shift: Unlock; Car: Push (it
  rolls onto the second walker); Window (only offered while leaning up, W): 3 Use spark plug on
  (Glenn crushes it), again 3 (breaks it); Awl: Take; lean left: Brick Wall: Move To; at the wall
  peek up (W) and at once Zombie: Stab, then "Zombie: Stab. Enter!" to finish it; next cover
  (the RV, A and D only): lean left, Zombie: Stab, then the walker comes round: early presses get
  "Wait for it", the mod says "Now! Enter!" when it is in reach (twice: chest, then eye); then
  the walker pinned under the car: Zombie: Stab (uses up the awl); Axe: Take ("Two more."). Then
  walk (free walking) left along the far wall at the stairs (camera cam_nav_stairs: W was -x,
  A +z, D -z, S +x there) until a short scene, hold W up the stairs and along the walkway (a
  guided path), "Zombie: Talk To. Enter!" (a hit), a struggle (Q then E), "Zombie: Use Axe On.
  Enter!", Door: 2 Chop / Break down, Irene's choices. Back to the drugstore
  (dev_saves\drugstore_evening).
- Drugstore at night ("Hey, Bud"): Doug: "Let's have a look around" -> outside
  (env_drugstoreExteriorNight.lua; dev_saves\pharmacy is from there): Trapped Walker: 2 Compare
  photo to; TV Store: 2 Use remote on (the remote is in the office drawer: Drawer: Open, then
  Search; go back in through Doug: 3 Go back inside); Lock: 3 Use axe on; Gate Latch: Open;
  Brick: Take; TV Store: 2 Throw brick at ("Now's the time"); Lee's Brother: 2 Approach, a choice,
  then "Lee's Brother: Kill" about five times (Enter each time it is offered again), "Find keys".
  In the office: Door to Pharmacy: 2 Open (a silent 5 s scene; keys and food are used up), then
  walk through the doorway (nothing is offered: item F) -> "Oh no." (the alarm).
- Finale (env_drugstoreInteriorPrologue.lua; dev_saves\finale): Board/Front Door announcements;
  Doug's choice; Front Door: Push (twice, Enter as each comes back); a struggle; Cane: Take;
  Front Door: Bar; turn choice "Left arrow towards Doug, Right arrow towards Carley" (the game:
  "Save Doug or Carley"); Right then "Purse: Take" saves Carley; "Zombie: Kick. Enter!" three
  times (the third after "Now! Enter!"); "Run!": run to Larry at the office door within about 3
  s (runto.lua says Shift and W and D); Kenny's hand. Then env_motorInn_end.lua
  (dev_saves\motorinn_end): Glenn (the flashlight), then walk up to Kenny, Carley, Duck (the
  group talk), the "next time" preview (NextTimeOn.lua), the statistics screen, the credits, and
  Season 1's main menu (dev_saves\ep1done).

## Files

Project root: C:\Users\dengs\Downloads\TWD

- `HANDOFF.md`: this file.
- `helper/TWDAccess/`: the C# helper.
  - Program.cs: options (--no-launch, --no-install, --uninstall, --game PATH, --backend NAME,
    --port N); starts everything and launches the game.
  - Speech.cs: Prism on one STA thread (prism_init, prism_registry_acquire_best,
    prism_backend_output). Prism.cs has the P/Invoke declarations.
  - LocalServer.cs: the tiny HTTP server. Routes: /speak (numbered batches), /say, /sayi, /stop,
    /log (to logs/game.log), /enqueue and /cmd (dev console). Anything else goes to
    logs/requests.log.
  - SpeechSequencer.cs: puts numbered speech batches back in order.
  - ModInstaller.cs: copies dist/TWDAccess/mod/** into the game folder, keeps a SHA-256 manifest in
    TWDAccess/installed.txt, and never overwrites another mod's DebugLoader.lua.
  - DebugMonitor.cs: captures the game's OutputDebugString output into logs/debug.log.
  - GameLocator.cs: finds the game through Steam's library manifests.
- `mod/src/DebugLoader.lua`: the bootstrap (encrypted at build time). `mod/src/probe.lua` is the
  obsolete first probe, kept only for reference.
- `mod/lua/`: the mod, plain Lua, installed to <game>\TWDAccess\.
  - main.lua: loads the modules in order: core, settings, text, hooks, carryover, uitext, menus,
    panes, messagebox, prompts, choices, lookaround, actions, aiming, sniper, struggle, turnchoice,
    inventory, peek, guided, runto, cover, readables, panels, subtitles, hotkeys, then discovery
    and devconsole if enabled.
  - sniper.lua: the rifle scope (mode_sniper; Episode 3's bandit attack): in sight, Enter shoots,
    sides, auto mode; TWDA.describeSniper for F6.
  - panels.lua: controls whose setting matters to a puzzle (the train's cab console), named and
    read with their setting; also TWDA.choiceContext (the shooting lesson's aim before choices).
  - readables.lua: drawn pages read aloud by camera name (the train's notepad);
    TWDA.describeReadable for F6.
  - core.lua: logging (TWDAccess\twda.log), TWDA.say (batched per frame, numbered), the per-frame
    script thread (TWDA.onFrame(name, fn); registering a name again replaces it).
  - settings.lua: TWDAccess\settings.txt (subtitles, menus, tooltips, choices, choicetimer,
    actionscenes, discovery, devconsole). Settings added in a new version are written into an
    existing file.
  - text.lua: cleanText (Telltale markup and button glyphs), nodeText, agentText, keyOrText,
    normalCaps, joinSentences.
  - hooks.lua: hookGlobal, hookBefore, hookAfter and hookMethod. Wrappers survive the game
    redefining a function, several modules can hook the same function, and TWDA.wrappers marks our
    wrappers. TWDA.unwrap(fn) peels wrappers off; TWDA.upvalue(fn, name) reads a game script's local
    (such as mode_MainMenu's mCurrentPane).
  - carryover.lua: the engine-reset redirect described above.
  - uitext.lua: the AgentSetProperty "Text String" dispatcher and spoken hint agents.
  - menus.lua: everything for the widget framework (see above). TWDA.visibleText(agent) joins the
    visible text of an agent and its children.
  - panes.lua: Season 1's pane menus (see above); TWDA.describePane for F6 and TWDA.paneButton for
    F9, F10, Page Up and Page Down.
  - messagebox.lua: Season 1's Yes/No message box; TWDA.describeMessageBox for F6.
  - choices.lua: Season 1 dialog choices, the game's own highlight for the arrow keys, and the
    timed-choice pause.
  - lookaround.lua: hotspots (Tab, Shift+Tab, Enter, number keys, Backspace out of close-ups,
    Escape releases), including ones out of view in look-around scenes, walks to things out of
    reach, and fight targets named from their use node; TWDA.describeLookaround for F6;
    TWDA.useWithReticle, TWDA.reticleBusy and TWDA.preferNextTab for actions.lua.
  - prompts.lua: the death screen.
  - actions.lua: action scenes (the actionscenes setting, F11); TWDA.inActionScene.
  - aiming.lua: the shotgun aiming at the zombie cop (mode_shotgun): Tab aim assist, arrow keys,
    Enter fires, on/off target speech, auto fire in auto mode; TWDA.describeAiming for F6.
  - struggle.lua: struggles (mode_struggle): announcements, F6, slow mode's hold-Q, auto mode.
  - turnchoice.lua: turn choices (mode_choice): announces the arrows, turns on arrow keys.
  - inventory.lua: says what is gained or used; TWDA.describeInventory for F6.
  - peek.lua: peeking from cover (mode_peek): directions, leaning out and back, "Get back now",
    things coming into view.
  - guided.lua: guided paths (ChoredMovement) that come without a hint of their own.
  - runto.lua: "Run!" moments with a known target (a table per scene): which keys head there.
  - cover.lua: walking in moving cover (a table per scene; the dairy tractor): walk, run, stop
    cues; TWDA.coverWalkActive, TWDA.describeCover for F6.
  - actions.lua also has the countdowns (TWDA.countdown, TWDA.describeCountdown), TWDA.offerTexts
    and the "what is on offer" announcements outside action scenes (sceneoffers).
  - prompts.lua also reads the end-of-episode statistics and the episode credits.
  - subtitles.lua: speaker and line from Subtitle_OnCreate.
  - hotkeys.lua: F5 repeat, F6 describe screen, F7 subtitle mode, F8 stop, F11 action scenes, F9, F10, Page Up and
    Page Down (the controller's X, Y and bumpers: Season 1 panes first, then the hub's legend
    commands).
  - discovery.lua (development only): wraps UI-looking functions and classes and logs calls; also
    dumps globals.
  - devconsole.lua and devtools.lua (development only): run Lua sent from outside; DEV.dump,
    DEV.dumpScript, DEV.where and DEV.unwrap.
- `tools/build_mod.py`: syntax-checks the Lua with the real Lua 5.2 from the `lupa` package,
  encrypts the bootstrap with ttarchext, and writes build/mod/Archives and build/mod/TWDAccess.
- `tools/prism/`: prism.dll v0.18.3 (x64 release build; no runtime dependencies), prism.h and
  licences.
- `tools/ttarchext/ttarchext.exe`: only for the bootstrap; see the constraints above.
- `tools/dev/`: development scripts (see below).
- `.venv/`: Python environment with lupa (`python -m venv .venv`, then
  `.venv\Scripts\python -m pip install lupa`).
- `dev_saves/` (git-ignored): copies of the test slot's two save files (wd1_saveslot2.bundle and
  _wd1_saveslot2_autosave.bundle) at checkpoints, with the scene script saves.txt needs:
  zombiecop\ (env_woodsClementine.lua), backyard\ (env_clementineHouseExterior.lua), house\
  (env_clementineHouseInterior.lua, inside the babysitter struggle), afterfight\
  (env_clementineHouseInterior.lua, "Did you kill it?"), farmnight\
  (env_hershelFarmExteriorNight.lua), fence\ (env_hershelFarmExterior.lua, the fence attack),
  motorinn\ (the Motor Inn stealth start; the script is probably env_motorinn_stealthmission.lua
  (ResourceExists says yes), but that was not checked: check before loading it). Also
  user_slot1_house\ (a backup copy of the user's own slot 1 files of 2026-10-05) and
  user_logs_oct5\ (their twda.log and speech.log of that session). Added later on 2026-10-08:
  motorinn\ is confirmed as env_motorinn_stealthmission.lua; drugstore_evening\
  (env_drugstoreInterior.lua, after the Motor Inn), pharmacy\ (env_drugstoreExteriorNight.lua,
  outside at night), finale\ (env_drugstoreInteriorPrologue.lua), motorinn_end\
  (env_motorInn_end.lua), ep1done\ (Episode 1 finished; slot 2 as after the credits).
  Added in the third session: ep2_after_trap\ is env_motorInn.lua with David left behind;
  ep2_motorinn\ (env_motorInn.lua, David saved), ep2_dairy\ (env_dairyExteriorDay.lua, arriving),
  ep2_after_tractor\ (env_dairyExteriorDay.lua, after the fence and the tractor),
  ep2_meatlocker\ (env_dairyMeatLocker.lua), ep2_barnnight\ (env_dairyBarnNight.lua), ep2_car\
  (env_woodsAbandonedCamp.lua), ep2done\ (Episode 2 finished).
  Added in the fourth session (Episode 3): ep3_bandits\ (env_motorInn.lua, the Motor Inn in the
  evening, before the clue hunt and the bandit attack), ep3_road\ (env_road.lua, after the bandit
  attack), ep3_train\ (env_wreckedTrain.lua, the wrecked train after the water for Duck),
  ep3_clearing\ (env_clearing.lua, the clearing with Duck; the fourth session copied it as
  "ep3_trainafter" 27 s before the next save), ep3_trainafter\ (env_trainAfterStop.lua, on the
  train after Duck; copied by the fifth session from slot 2's 01:31 save).
  Added in the fifth session: ep3_overpass\ (env_overpass.lua, the train just stopped at the
  overpass, before Omid and Christa), ep3done\ (Episode 3 finished; slot 2 as after the credits,
  saves.txt line env_epilogue.lua, not needed to start Episode 4 from the menu).
  Episode 4: ep4_house\ (env_manorInteriorHouseSearch.lua), ep4_sewers\ (env_savannahSewers.lua,
  arriving), ep4_sewers_after\ (env_savannahSewers.lua, after the walker grab, in the upper
  tunnel), ep4_clemsearch\ (env_manorInteriorClementineSearch.lua, back at the house),
  ep4_crawford\ (env_crawfordExterior.lua, Crawford's outskirts after the manhole and hiding).

In the game folder (G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series):
Archives\DebugLoader.lua, plus the TWDAccess folder (the mod's Lua, settings.txt, twda.log,
installed.txt, next_script.txt while switching). Development leftovers live there too: dumps\,
globals_*.txt and stack_*.luac.

## Build, install and run

Build the mod, then the helper (the helper copies build/mod into its output):

```
.venv\Scripts\python tools\build_mod.py
dotnet build helper\TWDAccess\TWDAccess.csproj -c Release -o dist\TWDAccess
```

Delete dist\TWDAccess\mod before building the helper, so removed files do not linger.

Run `dist\TWDAccess\TWDAccess.exe`. It installs the mod, says "TWD Access ready, using NVDA", starts
the game through Steam, and exits when the game closes. Logs are in dist\TWDAccess\logs:
TWDAccess.log, speech.log (everything spoken), game.log (console output) and debug.log.
`TWDAccess.exe --uninstall` removes the mod.

## Developer tooling and workflow

- `tools\dev\restart.ps1`: kills the game, rebuilds everything, starts the helper and game, clicks
  past "Click to Begin", and waits until "Main menu" is spoken (about 70 seconds). Use it after
  changing Lua that hooks game functions: re-including those modules double-registers hooks.
- Faster for poll-based modules (panes, messagebox, hotkeys): run build_mod.py, copy the changed
  files from build\mod\TWDAccess into <game>\TWDAccess, then
  `tools\dev\console.ps1 -File tools\dev\reload.lua -WaitMs 3000`.
  **Always finish with restart.ps1 (or the dotnet build into dist).** TWDAccess.exe installs from
  dist\TWDAccess\mod and puts its copies back over hot-copied files; on 2026-10-02 the user played
  with stale panes.lua and lookaround.lua because of this. restart.ps1 keeps the previous session's
  logs as <game>\TWDAccess\twda.prev.log and dist\TWDAccess\logs.prev (that may be the user's own
  play session).
- To reach Season 1's menu from the hub: `step.ps1 -Lua 'Menu_Seasons()'`, then
  `step.ps1 -Lua 'Menu_Seasons_Play(1)' -SettleMs 20000`.
- `tools\dev\step.ps1 -Keys Down,Enter` or `step.ps1 -Lua '<code>'`: focuses the game, presses keys
  or runs Lua through the dev console, and prints what the mod said.
- `tools\dev\goto.ps1 -Target "Settings" -Enter`: presses Down (or -Key Up) until a phrase is
  spoken, then Enter. More reliable than counting presses.
- `tools\dev\game_input.ps1`: low-level focus, click, keys and -Screenshot. Read screenshots with the
  Read tool to see the game. Keys are sent as scan codes; arrows, Page Up/Down, Home, End and
  Delete need the extended flag (handled), or they arrive as number-pad keys.
- `tools\dev\console.ps1 '<lua>'`: runs Lua through the dev console and prints the result.
- `tools\dev\find_upvalue.lua`: lists every loaded function with an upvalue of a given name (set
  FIND_UPVALUE first); how the hidden dialog timer and selectChoice were found.
- `tools\dev\trap_transitions.lua`: wraps every scene/load/reset-looking global and writes each
  call straight to TWDAccess\trap.log; how LoadScript was found.
- `tools\dev\watch_hotspots.lua`: for 60 seconds, logs each change in the set of usable hotspots
  (WATCH lines in twda.log).
- `tools\dev\watch_scene.lua`: for 120 seconds, logs (W2 lines) the clickable hotspots with their
  visible actions, every Dialog_Play node, action icons, uses, mode changes, Dying, the reticle and
  combat state and Lee's position. Start it right after a checkpoint loads (wait for "choices:
  attached" in twda.log). How the zombie cop was solved.
- `tools\dev\holdkey.ps1 -Key S -Ms 25000 -Until "backingAwayFromCopFinished"`: holds a key while
  keeping the game focused (game_input.ps1 -HoldMs lost the hold when focus was stolen, and Lee
  stopped short of the car), optionally until a text appears in twda.log.
- Scene tests that must react faster than PowerShell round trips (the zombie cop gives about 15 s)
  are best written as a Lua thread run from the console that waits for each hotspot and acts
  (aim the reticle at its dot, wait for the icons, selectAction, DoAction). The 2026-10-03 session
  did that, then replayed the scene with keys only (Tab until the focus speech matches, Enter).
- game_input.ps1 also takes `-HoldMs 3000` (hold a key, for walking) and combinations such as
  `Shift+Tab`.
- Dev console: with devconsole = true in settings.txt, POST Lua to
  http://127.0.0.1:41234/enqueue. Results appear in dist\TWDAccess\logs\game.log and twda.log. The
  game must be focused for commands to run.
- Reading game code: in the console, `DEV.dumpScript("menu_options")` or `DEV.dump("ClassName")`
  writes bytecode to <game>\TWDAccess\dumps. Then run
  `python tools\dev\luadis.py --summary <file.luac>` (or without --summary for a full listing). Use
  `DEV.where("FunctionName")` for parameters and the source file.
- Discovery: set discovery = true in settings.txt, or `TWDA.safeInclude("discovery")` in the
  console, to log calls to UI-looking functions into twda.log.
- Driving a scene from a script: poll twda.log for a hint or a "choices:" line, then press keys
  with game_input.ps1 (see the session's pattern: wait for "S (back) key", then
  `game_input.ps1 -Keys S -HoldMs 30000`). Startup log lines to wait for after loading a save:
  "choices: attached to mode_DialogChoice".
- Added 2026-10-08 (all in tools\dev):
  - `load_slot2.ps1 [-Play]`: from the hub menu (after restart.ps1), into Season 1 and slot 2's
    episode screen (and Continue).
  - `checkpoint_watch.ps1 -Watch watch_struggle.lua -Seconds 60`: CheckpointLoad, start a watch
    script as soon as the mod is up, keep the game focused, print the new log lines (-NoReload,
    -Watch none, -Filter).
  - `watch_struggle.lua`: logs calls to every struggle/fight/scene-looking global (ClemHouse*,
    Struggle_*, ButtonMash_*, PanicMeter_*...), Dialog_Play, action icons, Text String changes,
    clickable and shown hotspots, modes, input maps, the reticle and Dying ("WS" lines).
    `watch_choice.lua` does the same for turn choices ("WC" lines).
  - `play_by_ear.ps1`: plays a fight as a listening player would, reacting only to the mod's speech
    (mash Q on "Struggle!", E on "E now!", Enter on "...Enter!", Tab then Enter on "Tab to choose",
    an arrow on "Turn:"; -HoldQ, -Turn Left, -IgnoreChoices, -ReactMs). How the house fight and the
    fence were verified in normal mode.
  - `follow.ps1 [-Keys k]`: keep the game focused and print speech until something needs the
    player. `talk.ps1 -Answers 2,1`: let conversations run, answering choices in turn.
    `use.ps1 -Name "Energy Bar" [-Action 2]`: Tab until the mod names it, walk there if offered,
    press the action number and Enter, then talk.ps1.
  - Multi-line Lua for console.ps1 goes in a file (-File); passing it as an argument through
    `powershell -File` mangles it. From Bash, `powershell -File step.ps1 -Keys Down,Down` passes one
    key name "Down,Down"; call step.ps1 from PowerShell (`& .\tools\dev\step.ps1 -Keys Down,Down`).
  - The game runs whenever it has focus, including while you read logs between tool calls if focus
    stays on it: timed scenes need a script that reacts (play_by_ear.ps1), not step-by-step calls.
- Added 2026-10-08 (third session):
  - play_by_ear.ps1 now also: -Answer 1 answers every dialog choice with 1; -StartKey Enter (or F6)
    presses it once listening (Enter on the death screen reloads, and some checkpoints start the
    action at once); -Leans D,A leans that way at each new "Hiding. To lean out"; holds the key
    on "Use the S (back) key" until anything else is said (-HoldS cap); holds keys on cover.lua's
    "Walk: A" / "Run: Shift and A" and lets go on "Stop"; starts mashing on "Struggle," (F6) too.
    It is the quickest way through a timed stretch: `play_by_ear.ps1 -Seconds 150 -Answer 1
    -StartKey Enter -Leans A`.
  - react.ps1 -When "regex" -Keys Tab,2,Enter: wait for a phrase, then press keys.
  - watch_tractor.lua: positions of Lee and the tractor's cover edges (WT lines).
  - In the mod (development): TWDA.frameOff = { name = true } skips frame callbacks
    (TWDA.frameNames() lists them); TWDA.tracing = true writes TWDA.trace lines straight to the log
    (actionsOf and the countdown scan have them), TWDA.traceFrames = { lookaround = true } traces
    callbacks (floods the log: load_slot2.ps1 reads the log's tail and then fails).
  - use.ps1 now only acts when the latest line names the target (it acted on Carley after an
    earlier line mentioned Kenny).
  - The game crashes (writes a .dmp in its folder) on AgentSelectionIsOccluded for some agents
    (the dairy tractor scene). Do not call it.
- Added in the fourth session (2026-10-09, all in tools\dev):
  - devuse.lua (DEV.use("Lilly's Door"), DEV.use("Clementine", true) only walks,
    DEV.use("Chalk X", false, 2) does action 2) and duse.ps1 -Names "Duck","Chalk X#2" -Answers 1
    (uses each in turn, letting the talk run): hurrying through exploration the mod already
    handles.
  - devroute.lua: DEV.route({ "obj_rvDoorSide", "obj_trainEngineLadder" }) walks and uses agents
    in turn (doors and ladders across the train). The game closed 45 s after one such route.
  - logicdiff.lua (DEV.logicKeys: which logic value a control's use changes) and propdiff.lua
    (DEV.snap / DEV.diff on one agent's properties).
  - shot.ps1 -Out file.png: a screenshot of the game window (for drawn pages).
  - watch_shootout.lua, watch_sniper.lua, watch_zombies.lua, watch_walkers.lua,
    sniper_autofire.lua: how the bandit attack's scope was worked out.
  - load_slot2.ps1 now accepts "Play" as well as "Continue" on the episode screen.

Gotchas:

- The Claude desktop window often takes focus back a few seconds after an action, which pauses the
  game. step.ps1 refocuses before every action; keep action bursts short.
- In Git Bash, `curl` arguments that start with "/" get rewritten into Windows paths. Use
  `export MSYS_NO_PATHCONV=1`, or use PowerShell.
- Do not edit C# or project files with Python heredocs: backslash sequences such as "\b" get
  mangled. Use the Edit and Write tools.
- PowerShell displays UTF-8 logs as mojibake ("Â©", "â€™"); the text itself is fine.
- Never press Enter on "Exit Game" then "OK", and avoid changing the user's settings; if you
  change one for a test, change it back (step.ps1 prints what was spoken, so check before
  pressing Enter).
- Save slots: slot 1 is the user's (on 2026-10-02 they deleted their older Game 1 themselves and
  started a new game there). Slot 2 is the agent's test slot; deleting and restarting it is fine.
  Never touch slot 1, and do not start a game in another empty slot unless asked. Enter on an empty
  slot opens Choose a Display Style, which has no Back: choosing Standard (the default) and then
  Backspace from the Episode screen leaves the slot empty.
- A scene that starts the moment its save loads (the house fight) cannot be switched to another
  actionscenes mode from the console in time; edit settings.txt for the test and put the user's
  value back (normal) afterwards (done that way on 2026-10-07).
- After any SetTimeScale or Death_Enable experiment, put them back (SetTimeScale(1),
  Death_Enable(true)); the mod only restores time scales it set itself (0.45).
- Lua syntax is checked by build_mod.py, but a misspelt local becomes a global silently. To list the
  globals a module uses, compile it with lupa (`lupa.lua52.LuaRuntime(encoding=None)`,
  `string.dump`) and run luadis.py on the result, looking for `_ENV[...]` names.
- PowerShell scripts need `-ExecutionPolicy Bypass` when run from Bash.
- Git: the first commit (ce1fdff) was made on 2026-10-03 at the user's request, as the fixed point
  for reviews (/mattpocock-skills:code-review). The branch is "main"; the remote "origin" is
  https://github.com/Kongster90/TWDAccess.git (the user's repository, linked and pushed at their
  request). No git identity is configured on this machine; commits use
  `git -c user.name="dengs" -c user.email=<the user's email>` for themselves only. Only commit or
  push if the user asks.
- Matt Pocock's engineering skills are set up (CLAUDE.md "Agent skills", docs/agents/): issues in
  GitHub Issues, default triage labels, single-context domain docs. The repository is private.
  The `gh` CLI (2.102.0) is installed at C:\Program Files\GitHub CLI\gh.exe and signed in as
  Kongster90 (installed during the 2026-10-03 session, so that session's shells needed the full
  path). All five triage labels exist in the repo (the four besides `wontfix` were created on
  2026-10-03), next to GitHub's defaults and an `accessibility` label. Issues #1 to #9 are the
  "Not done yet" list below.
