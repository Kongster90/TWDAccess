# TWD Access: handoff notes

Read this first. It is written for the next agent picking up this project, and kept current at
the end of each session.

Last updated: 2026-10-03.

## Start here (where the last session stopped)

- The user plays with the keyboard (NVDA). They would use a PS5 controller only if controller
  support is added later; not a priority.
- Season 1 menus, choices, hotspots and the opening of Episode 1 work. The zombie cop attack was
  solved on 2026-10-03 (see "Episode 1 notes"); the user then played it themselves in slot 1 with
  Tab, Enter and the aim assist, through the woods, to Clementine's backyard (their save,
  2026-10-03 16:49, is env_clementineHouseExterior.lua). They said most of it worked "without any
  major issues".
- Walking and navigation (the user's request) was started on 2026-10-03 in the backyard: Tab and F6
  give distances, Enter walks Lee to a hotspot the camera does not show, and simple hotspots can
  then be used from there (see "Season 1 during play: free walking"). Tested in slot 2 (Pool Cover,
  Woods, Gate). Not yet tried by the user; ask how it went. Ideas for what is still missing are
  in item 1 of "Not done yet".
- Save slot 2 is the agent's test slot (the user said to play there). Its save is now the backyard
  checkpoint (env_clementineHouseExterior.lua; on load Lee falls and walks in by himself for about
  30 seconds before control returns, "Hello? Anybody?!"). Copies of both slot 2 files are in
  dev_saves\zombiecop and dev_saves\backyard (copy them back into Documents\Telltale Games\The
  Walking Dead Definitive with the game closed to return to a scene). Slot 1 is the user's own
  game: never delete, copy over or play it.
- Reload the current checkpoint from the dev console with `CheckpointLoad()` (also gives a fresh
  Lua state, so hot-copied modules that hook functions load cleanly).
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

Built but only partly tested:

- Season 1 Save Slots copy mode (F10, then Enter on the target slot): not tried. Delete with Yes
  was tested on the test slot (slot 2) only. The Rewind (F9) and Stats (F10) buttons on the Episode
  screen only appear once an episode has been played; their panes are untested.
- Hotspots in third-person scenes: only tested in the opening's first-person and close-up scenes.

Not done yet, in suggested order:

1. More navigation, once the user has tried what exists: manual walking help (W A S D move
   relative to fixed cameras that cut as Lee walks, so say which key heads towards a chosen hotspot,
   or announce camera cuts), announce when Lee bumps into something while walking by hand, say
   "Lee can move now" when control returns after a walk-in (the backyard opening says nothing for
   30 s; F6 says "Nothing on screen to read"), and exits to other areas. Check other free-walk
   scenes (inside Clementine's house, the farm, the motor inn) for cameras that do turn.
2. Zombie cop leftovers: nothing is said when Lee reaches the car (the S hint just stops; the
   "Shotgun, several actions, to your left. Shotgun shell: Take, to your right" announcement is the
   cue), and after calling out to the figure the user heard "Use the S key to get away" four times
   (the second backing-away; worked in the end).
3. Action scenes, more generally: action choices (mode_DialogActionChoice), struggles
   (mode_struggle.lua: Struggle_Start, ButtonMash_*), aiming with the reticle in later episodes
   (ReticleUI_InCombatMode with "Shoot" icons, isShootIcon in mode_reticle.lua; aiming.lua only
   covers mode_shotgun), and in auto mode, holding movement keys for "Use the S key" prompts (the
   handlers are in mode_Chored_Move.imap; the mod cannot press keys itself).
4. Things that happen silently: picking something up (the inventory, WDInventory_*,
   ui_inventory.scene, shows an icon only), and the title screen ("Click to Begin": nothing is
   said, and whether a key passes it is unknown; restart.ps1 clicks).
5. Check the menus of Season 2, Michonne, A New Frontier and The Final Season. The later seasons
   probably use the same widget framework as the hub; Season 2 probably the same panes as Season 1.
6. Escape both releases the hotspot the mod is holding and opens the pause menu.
7. Uninstall: ModInstaller --uninstall removes Archives\DebugLoader.lua, but saves made with the mod
   need it to load (see "Loading saves"); keep it, or warn.
8. Later, optional: controller support. Keyboard is the primary target and is enough for the user;
   if a controller is added it will be a PS5 DualSense, so hints should name PlayStation buttons and
   follow the game's own device switch (Menu_UsingJoystick in Season 1). Mod commands (F5 to F11)
   would need a button combination; check which buttons the game leaves free (the touchpad click is
   a candidate) and whether a keyboard press flips the game out of controller mode.
9. Before release: set discovery and devconsole to false in the installed settings.txt, delete the
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
    panes, messagebox, prompts, choices, lookaround, actions, aiming, subtitles, hotkeys, then
    discovery and devconsole if enabled.
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
  - choices.lua: Season 1 dialog choices and the timed-choice pause.
  - lookaround.lua: hotspots (Tab, Shift+Tab, Enter, Escape releases), including ones out of view in
    look-around scenes; TWDA.describeLookaround for F6; TWDA.useWithReticle and TWDA.reticleBusy
    for auto mode.
  - prompts.lua: the death screen.
  - actions.lua: action scenes (the actionscenes setting, F11); TWDA.inActionScene.
  - aiming.lua: the shotgun aiming at the zombie cop (mode_shotgun): Tab aim assist, arrow keys,
    Enter fires, on/off target speech, auto fire in auto mode; TWDA.describeAiming for F6.
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
  _wd1_saveslot2_autosave.bundle) at checkpoints: zombiecop\ and backyard\.

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
  GitHub Issues, default triage labels, single-context domain docs. The `gh` CLI is not installed,
  so the issue-based skills cannot work until the user installs it and signs in.
