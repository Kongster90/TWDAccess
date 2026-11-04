# TWD Access: handoff notes

Read this first. It is written for the next agent picking up this project, and kept current at
the end of each session.

Last updated: 2026-11-03 (nineteenth session: Tab says "out of reach", "blocked" and "in another
area" in free walking, and an opened door that leaves nothing to Tab to (the Macon pharmacy) is
offered as "Open doorway", and the dairy porch has "Porch steps"; tested in the game (pharmacy,
dairy), released as TWD Access 1.3.0, and the repository made PUBLIC after a history clean-up;
see the nineteenth-session item; before that the
eighteenth: the "streaming" setting, released as TWD Access 1.1.0; fixes for the game's other
languages and the later seasons tested in French, released as TWD Access 1.2.0).

## Start here (where the last session stopped)

- Nineteenth session, 2026-11-03 (the user playing Season 1 Episode 2 at the dairy in THEIR Save 1,
  streaming; the tones were heard on stream). They asked for the Tab list to say which things
  cannot be used from where Lee stands: at the dairy, things beyond the fence were offered like
  any other until Lee went through. Asked for options 1 to 3 below (not a "usable only" filter,
  which in free walking would drop most things, the cameras being fixed). Tested offline first
  (the user was using the computer), then in the game once they were away (below). Built into
  dist by restart.ps1. Committed as e5b3af8 (hash after the history rewrite below). (The default Python has no lupa; the repo's .venv has it,
  which build_mod.py uses.) All in lookaround.lua (Season 1 and 400 Days free walking):
  1. Tab on a thing the reticle cannot take from here (the walk offer in cycle) now says a reason
     after the name: "Toolbox, out of reach, to your left, 15 meters. Enter walks there, 3 of 20".
     Things usable from here are read with their actions as before.
  2. `blocked` (weak table, agent -> { from, near }): set in walkTick's "got to N meters ... can go
     no further this way" branch (not for another floor or a place such as stairs). Tab says
     "blocked, the last walk stopped near Gate" (near = nearestWayOut within 3 m, else just
     "blocked"); such things rank last (2.5, after behind) and the list key carries a "!" so the
     order is redone. Cleared by any use (forgetNoWay, from the Main_OnUse/PathToAndUseAgent hook),
     by a later walk there that arrives, or when Lee is NO_WAY_CLEAR_METERS (10) from where he
     stopped. ("There is no way to X" still drops a thing from the list, as before.)
  3. "in another area": dialogAllows(agent) == nil, i.e. findDialogWithNode finds no loaded dialog
     for its use node (dialogs load by area; the gazebo from the barn side). Such things are never
     clickable here. Verified at the dairy: it is the picket gate / porch and the barn gate split
     (below). Not said of characters or of anything within 3 m (Lilly, below).
  F6 (describeLookaround) adds only "blocked" / "in another area" in front of the distance (not
  "out of reach", which would be said of most things). README.txt (Exploring, Tab) explains the
  three words. CHANGES.txt not yet updated (written at release time).
  4. The user's bug: Episode 1, Macon drugstore office at night (env_drugstoreOffice.lua): after
     "Door to Pharmacy: 2 Open" (the keys) nothing said to walk through the doorway; they had to
     walk a little to the right by hand to start the alarm (their twda.log, 18:14 and 18:22 on
     2026-11-03: the list was only Lilly, Bedding, First Aid Kit, TV). Item F / issue #15's
     doorway. FIX (generic, no agent names needed, as the trigger's name is unknown): the
     Main_OnUse hook remembers a door/gate/hatch used (`openDoor`: agent, label, where Lee stood).
     openDoorway(): once that door's hotspot is gone (not Game Selectable, or hidden; within
     DOORWAY_SECONDS = 60 of the use) while Lee is still on this side (not half a meter past it)
     and stood within 4 m to open it, the place "Open doorway" (name "doorway:<door agent>") is
     listed, with a point 2.5 m past the door straight on from where Lee stood, put on the walk
     boxes (none offered if that point lands on this side: no floor beyond). The frame loop says
     once, 1.2 s after control is back, "<Door> is open. Enter walks through it." and sets the
     walk offer; NOT said if a subtitle line, a hint or an action scene came after the use (the
     story moved on: Episode 2's farmhouse Door, then the rush to Clementine), though still on
     Tab. startWalk(agent, act, name) takes the entry's name; a doorway walk uses
     AgentPathToPosition to that point (goalDistance(w) measures to it); arrival says "Through the
     doorway. If nothing happens, walk on a little with <keys>" (keysAlong: the way through on
     screen, as runto.lua). Places in cycle are always walk offers now.
  OFFLINE TEST (new): tools\dev\offline_lookaround.lua + .py run lookaround.lua under lupa with
  stand-ins for the engine (doorway announced, walked, gone once through; the three tags; blocked
  last, cleared by a use and by 10 m; not announced after a line; Lilly; the porch steps). All 22
  checks pass. Run `python tools/dev/offline_lookaround.py <folder with lupa>`.
  TESTED IN THE GAME the same evening (user: "Go ahead and try/test everything you need", while
  away), Save 2 only:
  - Pharmacy (dev_saves\pharmacy, saves.txt env_drugstoreExteriorNight.lua): Gate Latch, Brick,
    TV Store 2, Lee's Brother 2 + choice 1, Kill x6, Find keys -> office. "Door to Pharmacy: 2 Open"
    -> "No more key office. No more food" -> "Door to Pharmacy is open. Enter walks through it." ->
    Enter: "Walking to Open doorway." -> "Oh no." (the alarm) at once. The door agent is
    obj_doorDrugstoreOfficePharmacy; the point walked to was 2.5 m past it. WORKS.
  - FOUND there: Lilly (1 m away) was "in another area": her use dialog is not loaded either, yet
    she talks when used directly. Fixed: reachTag never says "in another area" of a character
    (isCharacterAgent) or of anything within 3 m.
  - Dairy (dev_saves\ep2_dairy, saves.txt env_dairyExteriorDay.lua; the opening talk takes ~4 min
    with talk.ps1 -Answers 1,1,1,1). tools\dev\probe_areas.lua (AREA lines) showed the dialog-not-
    loaded set: from the yard, the porch things (Front Door, Plants, Shoe Bucket, Awards, Wind
    Chimes) and the barn side (Barn Door, Hay Bales, Hay Pile, Sign, Shoes, Gazebo, Corn Field);
    from the porch, the reverse (the yard's things, Mark, the generator...). So "in another area"
    = beyond the picket gate or the barn gate. Tab in the yard: "Front Door, in another area, 19
    meters", "Mailbox, out of reach, to your right, 1 meters", things in reach with their actions.
    "Blocked": from the porch, Lee saw -> "Lee got to 8 meters ... Close by: Front Door" -> Tab:
    "Lee saw, blocked, the last walk stopped near Front Door, behind you, 8 meters" (last of 27).
    The barn gate by day is story-locked (Andy: "after we get back from securing the perimeter").
  - FOUND there: the picket gate ("Door picket fence farm gate: Use") takes Lee UP ONTO THE PORCH
    (y 3.9, a walk-box set of its own; Lee at 21.9 3.9 -4.8); using the gate again from the porch
    only plays the same scene, and walks to the yard stop short. The way down is walking into
    trigger_dialog_exitPorch (25.5 3.9 -3.8; no hotspot). Fixed: SCENE_PLACES
    env_dairyexteriorday.lua: "Porch steps", sameLevel (listed only within 1.5 m of its height,
    i.e. on the porch), taken = "Down the porch steps, in the yard.". Tested: "Porch steps, below
    you, 1 meters" -> Enter -> "Walking to Porch steps." -> "Down the porch steps, in the yard."
    (Lee at 25.7 0.0 7.6). New: SCENE_PLACES `sameLevel` and `taken` (placeTaken; said when a
    scene takes over a walk to a place, instead of "the walk was cut short").
  - NOT DONE, worth a look: the dairy yard also has warp triggers (trigger_warp_fromFrontYard_
    toSwing / toSwing_fromFrontYard at 23.4 9.8 and 20.3 9.1, fromBarn_toGazebo / toGazebo_fromBarn,
    WorkBench2 ones disabled by day; tools\dev\triggers1.lua lists them). The user's walks to the
    swing (16 m short), gazebo, sign, hay, corn field stopped short; walking into
    fromFrontYard_toSwing from the gate (walk_to.lua) did not move Lee anywhere new. Panel and
    Power Switch are "out of reach" at 1 m (only usable inside the Generator close-up).
  - Restored afterwards: Save 2 files and prefs.prop from that session's scratchpad backup (every
    save file checked by MD5; only the game's own session_*.epage / menu_log_*.estore telemetry
    differs, which it rotates itself), settings.txt (streaming = true, devconsole = false) and
    saves.txt byte-identical. Game and helper closed. dist\TWDAccess and the game folder hold the
    new (dev) build, so the user's next play has these changes.
  - The user's own twda.log of that evening (18:00 to 20:05, Macon and the dairy) was LOST: three
    restart.ps1 runs, and it kept only one twda.prev.log. restart.ps1 now also copies twda.log to
    <game>\TWDAccess\oldlogs\twda-<time>.log (last ten kept).
  New dev scripts: probe_areas.lua, probe_gate.lua, walk_to.lua (WALK_TO = "<agent>").

- Eighteenth session, 2026-11-02 evening (the user playing Season 1 in THEIR Save 1, streaming with
  OBS, running dist\TWDAccess): two things came up.
  - Stuck at the Motor Inn truck: "Handle truck door: Open" does nothing; the door is locked by
    design (no line, no reaction, so Enter seemed broken; the user declined looking into a "nothing
    happened" cue for now). They had never leaned left (A) at the first wall, where the pillow is;
    told them the order in "Episode 1 notes" (The Motor Inn).
  - OBS could not record the mod's tones: Tones.cs plays through waveOut in TWDAccess.exe, and on
    Windows 11 its console window belongs to WindowsTerminal.exe, so the user's Application Audio
    Capture (wasapi_process_output_capture, "TWDAccess", in %APPDATA%\obs-studio\basic\scenes\
    Untitled.json) captured Windows Terminal. In the classic console (conhost.exe) the window is
    reported as the program's own (checked: Process.MainWindowHandle of cmd.exe under conhost).
    NEW SETTING streaming (settings.lua, default false; the helper reads it from the game folder's
    settings.txt): with true, OwnWindow.cs starts the helper again through conhost.exe with the same
    arguments (env TWDACCESS_OWN_WINDOW stops a loop; skipped when output is redirected or the
    process already has a window) and the first copy exits; the helper's window is titled "TWD
    Access" (OBS lists "[TWDAccess.exe]: TWD Access"). README updated. TESTED with the user's OK:
    dist rebuilt, streaming = true put in the user's settings.txt, started like a double-click: it
    reopened in conhost, one TWDAccess.exe with its own window, game found (not relaunched). Not
    yet heard through OBS by the user.
  - 2026-11-03 (user: "push and have it in as a new release. I'm thinking about making it public
    sometime today"): TWD ACCESS 1.1.0 RELEASED (tag v1.1.0, TWDAccess-1.1.0.zip, notes in
    release\notes-1.1.0.md; version in TWDAccess.csproj, main.lua and README.txt). The zip was
    tested from its unzipped folder against the running game (same result as above), then
    dist\TWDAccess rebuilt at 1.1.0 and started again for the user. Going public is still the
    user's call; two early commits carried their Gmail address as author (told them; rewritten
    on 2026-11-03, see the nineteenth session).
  - 2026-11-03, other languages (user: "Sure, why not, go for it"): the hub's Settings > Languages
    > Display Text (one row; Left/Right: English, Traditional Chinese, German, Russian, Spanish,
    Portuguese, Italian, French, Simplified Chinese), then Escape > "Language Changed" popup >
    Apply restarts the main menu. The language is kept in Documents\Telltale Games\The Walking Dead
    Definitive\prefs.prop. Tested FRENCH in Season 1 Save 2 from dev_saves\motorinn (pillow, truck,
    smother, car door, spark plug). Then everything was put back byte-identical (prefs.prop, Save 2
    = dev_saves\s1_slot2_before_aimtones, saves.txt, settings.txt with devconsole = false); game
    and helper left closed. Findings (the first three FIXED the same day, below):
    - Works: hub and Season 1 menus, save slots, episode screen, names and verbs of things,
      subtitles, all in French (game text). The mod's own words stay English ("Main menu",
      "Hiding. To lean out", "Get back now", "Keys:", "Carrying:"); inventory names come from
      agent names, so English ("Got pillow", "sparkplug").
    - looksOnly (lookaround.lua) matches English verbs only: Enter on "Camion: 1 Regarder, 2 Se
      déplacer vers" LOOKED (English: Move To). "Examiner" and "Observer" match by luck ("^examine",
      "^observe"), so Smother was chosen right. Needs a language-free signal (the action's icon?).
    - TWDA.normalCaps (text.lua) and the run-of-capitals fix in menus.lua are ASCII-only: "PARAMÈTRES"
      was read "ParamÈTres", "ÉPISODE" "ÉPisode" (UTF-8 capitals are not %u/%a).
    - distinctName mixes English agent words into French names ("Car motor inn porte", "Car push
      hint voiture"): the skip list is the localized name's words.
    - The French key hint "Regarder par-dessus le mur (Z)" is for AZERTY; on QWERTY the mod's W
      works and Z does nothing. AZERTY keyboards not tried.
    - Dialog choices not reached (none in that stretch).
  - 2026-11-03, the language FIXES (user: "Yes, go ahead"), COMMITTED as 31af1dc, NOT RELEASED:
    - LangGetCurLanguage() gives "english", "french", "russian", "chinese" (Simplified)...:
      TWDA.language() / TWDA.isEnglish() in text.lua. LocalizationGetAllInstalledLanguages() lists
      nine. The game's own tooltip: Italian only in Season One and The Final Season, Traditional
      Chinese only in The Final Season, A New Frontier and Michonne.
    - Look vs do: a hotspot's kVerb prop ("WDUseable - Verb") is English in every language ("Look
      At", "Go", "Talk to", "Take"; Dialog_GetText translates it), and each action choice carries
      "Choice Icon", whose ResourceGetName is language-free (ui_useicon_eye.d3dtx = look; the
      Season 1 list has talk, punch, headbutt, pistolshoot, hatchetchop, sneak, walk...). text.lua
      notes shown text -> English (TWDA.noteVerb from gameVerb, TWDA.noteVerbIcon from the
      Reticle_UpdateActionIcons hook and actionsOf; nothing noted in English), and TWDA.englishVerb
      is now used by looksOnly, isBlow, the "talk" and threat checks (lookaround.lua), the talk
      checks in actions.lua, peek.lua and turnchoice.lua, and firstUseAction's "shoot".
    - Kinds of things by name (door, gate, ladder, zombie...): TWDA.hotspotWords / kindWords add
      the agent name's words outside English (nearestWayOut, doorUse, actions.lua wayThrough,
      turnchoice isPerson).
    - Capitals: TWDA.lower (Latin-1 capitals, Œ, Cyrillic, by UTF-8 bytes), caseShape (same-length
      A/a mask so %u/%l see two-byte letters), normalCaps rewritten, TWDA.capitalRuns replaces the
      menus.lua gsub. joinSentences knows 。！？： and … (no "而战。. Left").
    - Alike names outside English: numbered by sorted agent name ("Porte 1", "Fenêtre 2", "Oreiller
      2"), only where the English rule would add words (zombies stay "Zombie"). English unchanged.
    - actions.lua mentioned(): words with two-byte letters ("fenêtre") match subtitle lines.
    - TESTED in Season 1 Save 2 (dev_saves\motorinn, saves.txt line env_motorInn_stealthMission.lua)
      in French (Enter after the lean-right announcement now does "Se déplacer vers"; "Paramètres",
      "Épisode 1 : Un Nouveau Jour"), Russian ("Выбор Сезона"; all Motor Inn verbs mapped) and
      Simplified Chinese (text reaches speech intact; "拳打" = Punch), then English again (truck,
      names such as "Car motor inn door" as before; no hook errors). Language switching: hub
      Settings > Languages; the first Left/Right only focuses the row. Copies of prefs.prop per
      language are in that session's scratchpad only. Afterwards prefs.prop (English), Save 2
      (dev_saves\s1_slot2_before_aimtones), saves.txt and settings.txt (devconsole = false) were
      put back byte-identical; game and helper closed; dist\TWDAccess and the game folder hold the
      new build. Not tried: other seasons in another language, dialog choices, a real Chinese or
      Russian voice in NVDA.
  - 2026-11-03 (user: "Commit and update everything on github. Make it a new release, with the
    changes in a changes text file"): TWD ACCESS 1.2.0 RELEASED (tag v1.2.0, TWDAccess-1.2.0.zip,
    notes in release\notes-1.2.0.md; version in TWDAccess.csproj, main.lua and README.txt).
    New: release\CHANGES.txt (every version, newest first), copied into the zip by
    make_release.py; README.txt has a LANGUAGES section and points to CHANGES.txt. The zip was
    tested from its unzipped folder (1.2.0 starting, "Main menu", no module failures), then
    dist\TWDAccess rebuilt at 1.2.0; prefs.prop, which the game rewrites while running, put back.
  - 2026-11-03, the later seasons in French (user: "Yes, test it"), committed as 9c3c098:
    - The look-vs-do code (Reticle_UpdateActionIcons, ICON_VERBS) is Season 1's (and 400 Days')
      only: Reticle_UpdateActionIcons is nil in The Final Season's play and in Season 2's state.
      Season 2, A New Frontier and Michonne (lookaround2.lua) do verbs[1] on Enter, number keys for
      the rest; The Final Season (lookaround4.lua) uses the game's own Useable_OnButtonUse. So no
      English verb words decide anything there.
    - Listing icons: ResourceGetNames("*useicon*") / ("*icon*.d3dtx") once a season's archives are
      on (Season 1 and A New Frontier from their menus; Season 2, The Final Season and Michonne
      only in play, or ResourceSetEnable("WalkingDead201") etc. from the menu). Season 1: 134
      ui_useicon_* (mostly items), plus ui_icon_eye/_ear/_talk/_kick/_hand. Season 2 and A New
      Frontier use ui_icon_<camelCase> (eye, listen, talk, walk, punch, kick, hitHead...). The Final
      Season and Michonne: no action icon textures found. text.lua now also matches ui_icon_ and
      maps kick (not tested in a scene).
    - TESTED in French: Season 2 from dev_saves\s2_ep2_cabinnight (saves.txt line must say
      CabinInterior.lua, or the bootstrap loads the slot's recorded scene): dialog choices read and
      picked by number ("Choices. 1: Je n'ai pas ouvert la porte ! ..."), "Sarah s'en souviendra.",
      then LakeWoodsClearing: "Portes de camion: Regarder. Scie à métaux: Attraper", Tab, Enter
      ("Attraper Scie à métaux, walking there"). The Final Season: menus and episode screen in French
      ("Continuer Épisode 1"); dev_saves\s4_ep1_school loaded BoardingSchoolDorm.lua (saves.txt) with
      nothing usable (Useable_GetCount 0), so no hotspot test there. A New Frontier and Michonne:
      not played (same module as Season 2).
    - Still English-only (cosmetic): lookaround4 nameOf's "^No " state check ("No walker in range"
      is said without the trap's name in other languages) and its English preposition list; the
      silent choice is "Say nothing"; menus.lua's "Paused" header.
    - Archives per language (Archives\WDC_pc_<Lang>ProjectSeason<N>): Chinese and Russian 1-4 and
      Michonne; French, German, Spanish, Portuguese 1-4; Italian 1, 2 and 4; Traditional Chinese 3,
      4 and Michonne.
    - Restored byte-identical afterwards (backup in that session's scratchpad\seasons-backup):
      prefs.prop (English), every Save 2 file, global.bundle, menu.bundle, ttcd.prop, saves.txt,
      settings.txt (devconsole = false); one English start checked the build (no module errors);
      game and helper closed.

- Seventeenth session, release (2026-10-31; user: "go for it. Make one", then chose MIT, version
  1.0.0 and a published GitHub release): TWD ACCESS 1.0.0 IS RELEASED as a GitHub release (tag
  v1.0.0, asset TWDAccess-1.0.0.zip) on the private repository. Version 1.0.0 in TWDAccess.csproj
  and main.lua; LICENSE (MIT, Kongster90) at the root. `python tools/make_release.py` builds
  build\release\TWDAccess-<version>.zip: a self-contained single-file TWDAccess.exe (dotnet publish
  -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true;
  prism.dll is inside it and extracted at run time; checked: "Prism 0.18.3 initialised ... using
  backend NVDA"), mod\ without devconsole, devtools and discovery, README.txt (release\README.txt,
  the players' read-me), LICENSE.txt, licenses\prism\ (Prism's NOTICE and the LICENSES folder of
  tools\prism-windows-x64.zip). Release notes: release\notes-1.0.0.md. Tested from the zip's folder
  against the real game: it installed the mod (the dev modules in the game folder were removed as
  stale), started the game, ENTER PASSES THE "CLICK TO BEGIN" TITLE SCREEN (answers checklist item
  4), the hub menu and Michonne's menu spoke, no module errors.
  - The installed settings.txt now has devconsole = false and discovery = false (checklist #9). FOR
    DEVELOPMENT set devconsole = true there again and run tools\dev\restart.ps1 (which installs the
    dev build, dev modules included). The game folder's dumps\, globals_*.txt and the like were
    left in place (dev leftovers, not part of the zip).
  - dist\TWDAccess (the framework-dependent dev build) was rebuilt at 1.0.0 too.

- Seventeenth session, morning of 2026-10-29 (user: "Start loose ends", after Michonne was committed
  as d11ee4e): THE TWO SEASON 1 LOOSE ENDS ARE DONE, tested in Season 1 Save 2 (dev_saves\ep3_bandits
  and ep4_meds), then Save 2 put back (byte-identical to dev_saves\s1_slot2_before_aimtones; saves.txt
  line env_manorInteriorClementineSearch.lua). Game closed, autorun.lua deleted, dist rebuilt (its
  mod and the game folder's match). Committed and pushed at the user's request (see git log).
  - The Motor Inn "gate flicker" was not a stuck gate: using the gate takes Lee out through it
    silently, and outside two hotspots were both "Gate" (obj_motorInnGate, the way back in, and
    obj_motorInnGateOuter, the dumpster gate, which cannot be used from inside: "PathToAndUseAgent
    ended without a use"), so in and out sounded like nothing. lookaround.lua's distinctName now
    tells apart things the game names alike by the words of their own agent names that the others
    lack ("Gate", "Outer gate"; before, only people were told apart). Tested: going out, the mod
    says "Outer gate: Use", and F6 lists both. The clue hunt order that works: Clementine, Broken
    Glass: 2 Inspect, Chalk X: 2 Inspect, Clementine again (the pink chalk), Chalk Scuff: 2 Inspect
    (Duck), Gate: Use (out), Fence, Grate: 2 Open, Bag: 2 Pick Up (the attack starts).
  - The bandit attack by tone (aim = sound): phase 1, 2 hits in 3 s; phase 2, the tone also led to
    Clementine and Duck, clickable while they run for the RV (a shot "hit"); phase 3 (walkers both
    sides, the death checkpoint lands here): 10 head shots, "Nothing in sight here. A for the other
    side." and "Other side." work, scene over (env_road.lua). Fixed: sniper.lua leaves the main
    cast out of the targets (FRIENDS, also obj_use<Name>: "obj_useMolly"); peek.lua no longer says
    "Hiding. To lean out: A left" while the scope moves Lee to the other side (it sent him straight
    back). Phase 2 not replayed after the friends fix (the checkpoint is past it).
  - Molly's classroom scope (Episode 4): the tone led to obj_useMolly (Molly) first; the shot still
    saved her (the walker was in front). After the fix it leads to obj_mollyFightZombieHallway: one
    hit in 2.5 s, Molly saved, Ben's confession goes on.
  - Tools: aimbyear.ps1 leans the way the mod names ("To lean out: D right") and switches sides on
    "D for the other side"; probe_occluded.lua (where a hotspot is visible around its dot),
    probe_focus.lua (what the reticle focuses at a point).

- Seventeenth session, 2026-10-28 22:15 to 10-29 about 04:30 (user asleep: "Go ahead and start on
  [Michonne]. Everything from the previous days stands. Closing playback error windows."; then
  "We can try to fix those 2 loose ends after this": the Season 1 Motor Inn scope test and the
  Duck/gate reticle flicker are NEXT). ALL OF MICHONNE IS PLAYED by ear in its Save 2
  (wdm_saveslot2; the user's Save 1 untouched and empty), answering 1, Episodes 1 to 3 and each
  Your Choices screen. Then Episode 1 was replayed to its storeroom to hear the fixes made on the
  way (Restart Episode 1), and Save 2 was put back to the finished season afterwards
  (dev_saves\m_ep3done, byte-identical; saves.txt line wdm_saveslot2.bundle Epilogue.lua). Other dev
  saves: m_ep1done, m_ep2done (copy all *wdm_saveslot2* files, game closed). No foobar2000
  playback error boxes came up. Committed and pushed at the user's request in the morning (see git
  log). Game closed; dev autorun.lua deleted;
  dist\TWDAccess rebuilt (its mod matches the game folder's copy). See "Michonne (seventeenth
  session)" below for the framework, every fix, and what is still untested.
  - Also fixed for every season: Season Select after coming back from a season left keyboard focus
    on the carousel's left arrow, so Enter on "Michonne" slid left and opened The Final Season
    (twice, by the test tools; no save touched). menus.lua now moves focus to the season's Play
    button when the focus is an arrow too (tested: wrap round to Michonne, Enter opened Michonne).
  - Backspace no longer opens the pause menu where the game binds it (Michonne's UI.imap); Escape
    does. Worth a check in Season 2, whose engine Michonne shares (not tried there).
  - New test tools: watch_sm.lua (copy to <game>\TWDAccess\autorun.lua), mplay.ps1 (keep focus,
    stop when the player is needed), mrun.ps1 (mplay in a loop, Enter on single offers), muse.ps1
    (use named things in turn), mlog.ps1 (log without noise), usehere.lua (Game_UseAgent with a
    verb), dragtry.lua, qteagents.lua, qtestate.lua, probe_multi.lua, fill_struggle.lua,
    radio_m.lua, radio_sweep.ps1, waggle.ps1, dump_pathcb.lua, tilekids.lua, menufields.lua,
    widgetkeys.lua, globals_like.lua, mstats_test.lua. onsay.ps1 takes "+Up/Down" (two keys in
    turn). The reactor used: react4.ps1 -Answer 1 -Extra "Stab\. Enter to do it=>Enter","again\?
    Enter=>Enter","Up and Down arrows in turn=>+Up/Down","Left and Right arrows in
    turn=>+Left/Right","E, then Q, then E!=>E,Q,E",... (see the section).
  - Careful with to_season.ps1 from a season's menu: the carousel opens at the last season used,
    so Right N-1 times can land elsewhere; and goto.ps1 sometimes misses "Definitive Menu" and
    presses Enter on Episodes (it opened The Final Season's Episodes screen with "Restart Episode
    4" focused; nothing was pressed there, its save is unchanged). Prefer step-by-step keys that
    check what was said before Enter.

- Sixteenth session, 2026-10-28 10:20 to about 12:30 (user asked which other scenes let you aim, then
  "Yes, add tones": the bow's aiming tone for Season 1's shotgun and rifle scope). Done and tested
  by tone alone (tools\dev\aimbyear.ps1 taps the arrows from the logged tone and presses Enter on
  the tick). Committed and pushed (see git log). Game closed; autorun.lua deleted; Season 1 Save 2 restored from
  dev_saves\s1_slot2_before_aimtones (identical files; saves.txt line
  env_manorInteriorClementineSearch.lua). dist\TWDAccess\mod has every change (restart.ps1).
  - Setting: bowaim is renamed aim (sound or auto), for the bow, the shotgun and the scope. The
    user's file had bowaim = sound and now has aim = sound (old key dropped on load). With aim =
    auto both Season 1 scenes behave exactly as before (Tab assist; "In sight! Enter!").
  - sounds.lua: TWDA.aimTone (the bow's tone, shared: 300 to 1000 Hz, pan, muffled, the 1500/2000
    Hz double tick); TWDA.aimDebug = true logs each one ("aimtone:" lines).
  - Shotgun (aiming.lua): arrows move the pointer (Shift x3); the tone is panned to where a shot
    would hit the cop, found by the hit test along the crosshair's row (then rows above and below);
    the head through cam_pan_player_horizontal was up to 0.1 screen off what a shot hits. Near (0.08
    screen), arrows let go, the mod closes across and sweeps the height. TWDA.getPointer/setPointer
    exported. Tested: from a start far left (-Kick 0.15,0.45) the cop was hit by tone alone.
  - Scope (sniper.lua): the game's sniperUpdate turns the scope with the pointer's ABSOLUTE place
    (MouseUpdate(x), MouseUpdate(1 - y)) and sniperFire shoots at the screen middle (dumped from
    memory). Sound mode: arrows move the pointer (0.2/s, Shift x3), tone on the target nearest the
    crosshair (in sight first; muffled while behind cover), height kept level, last 0.06 closed,
    Enter = sniperFireAtPos(middle) (miss: the game's Miss Dialog Node). Measured: a pointer move
    shifts the view the other way about 1.0 across and 0.8 up/down. mode_peek.OnDirection is
    wrapped so arrows do not lean while the scope is up (mode_peek.imap binds the arrows too).
    Tested: Episode 4 opening (8 hits, Clementine saved) and the school hallway behind the vending
    machine (lean W, 5 hits, Vernon's scene went on). The opening is tight: the walkers reach
    Clementine about 6 s after the scope comes up if nothing is hit.
  - (Done the next morning, see the first item:) the Motor Inn bandit attack and Molly's
    classroom scope, and the "gate flicker" at the clue hunt (two hotspots both called "Gate").
  - The user pressed F3 once and F4 three times at 10:34 to check that work was still going on:
    settings.txt now has beepvolume = 40 (was 30) and beacons = tab (was true, the same thing).
    Their choice; left as they are. (The user may press keys in the game while it is being tested.)
  - New dev tools: probe_shotgun.lua, probe_scope.lua (PS/PSC lines), cop_setup.lua + cop_run.ps1
    (zombie cop from dev_saves\zombiecop to the shotgun), aimdebug.lua (also as autorun.lua),
    aimbyear.ps1 (-Kick, -EnterOn, -LeanKey), arm_after_load.ps1, usechain.ps1. Episode screen
    F9 (Rewind) did nothing in Season 1 slot 2.

- Fifteenth session, 2026-10-28 00:10 to about 01:35 (user: "try the barn/farm part again in season 4
  and maybe try to figure it out ... look online if you need to ... If not you can move on to try to
  finish up the season"; closing foobar2000's Playback error boxes allowed). THE BARN IS SOLVED AND
  THE FINAL SEASON IS FINISHED in Save 2 (Episode 4 to the hat on the windowsill, the statistics and
  back to the main menu). Committed and pushed as da87270. The game was closed at the end; dev autorun.lua
  deleted; settings.txt untouched (actionscenes normal); dist\TWDAccess\mod has every change (copied
  from build\mod after the last sync; the helper itself was not rebuilt, no C# changed).
  - The barn loop, what it was: after "We need to get these pen doors closed" control comes back
    with Clementine standing ON trigger_dialog_clementimeOut, a line 0.7 by 0.1 m (enter dialog
    empty, EXIT dialog cs_clementimeOut). Its enter fired during the cut scene (triggerwd.lua's
    RunDialog only runs a non-ambient dialog in play mode: Game_IsPlayMode). Stepping off the line
    plays her fall, "Cover me", hands the player over to AJ (Objective: Close The Stall Doors), and
    AJ closes stall door 1 (struggle_stallDoor1), door 2 (a QTE), then door 3 (rope) -> wheelbarrow
    (W) -> knife and rope QTEs -> a walker fight as AJ ("Press E to stun, then Q to kill") -> "Good
    job, AJ". Tab and Enter used stall door 3 as Clementine from where she stood, she never stepped
    off, and that branch's wheelbarrow push ran the barn's opening again (cs_holdDoor...): the loop.
    Found from the TrueAchievements Episode 4 guide (works in the built-in browser; WebFetch gets
    403) and the fandom transcript (Take_Us_Back/Transcript, also only in the browser), then
    checked in the game: holding W a second off the line ran Trigger_OnExitDialog and the scene.
  - Fixed (lookaround4.lua): Enter on a thing while she stands inside an enabled trigger with an
    exit dialog whose box is thin (under 0.5 m one way: a line, not a zone) first walks her 1.2 m
    towards the thing (TWDA.walkTo with noResume: lookaround2 does not resume such a walk after a
    scene), then uses it if no scene started (also when the step was blocked). NOT YET TESTED AT
    THE BARN (the checkpoint had moved past it; Episode 4 offers only Restart); tested that the wide
    zone trigger_dialog_leaveLloyd (4 by 4 m round Lloyd in the flashback, exit = leaving him) is
    left alone and Question works (the first version stepped there and was blocked).
  - Fixed and tested: TWDA.playerName() takes "AJ" (said "Lee can move" as AJ); combat4 names AJ's
    prompts "E to stun", "Q to attack" (were "aj stun"); an early E is kept even with more walkers
    close (only an early Q is dropped then; early E stunned the first barn walker by ear); speaker
    "AJToddler" (the last flashback) is said "AJ" (not heard yet).
  - Played after the barn: Clementine's last scene (choices "Live for me", "You have to kill me"),
    the ranch flashback (FortMcCarrollRanch.lua: horse ride W, Rodney, Lloyd, Eddie, car push with A,
    S, D, W, the nursery, the locker key), Act 3 as AJ (ForestShack: spearfishing by shooter4, skull
    collectible, Replace Spear, Go Outside, the hat in the creek, Tenn), BoardingSchoolExteriorGate
    (places: Sweethearts ... At the gates), BoardingSchoolExterior (Clementine alive), dinner,
    BoardingSchoolDorm (Place Skull, Place Crystal, Place Calypso Cauliflower, Place Hat), 17 pages of
    statistics. All worked by keys; the reactor answered choices with 1.
  - Seen, not fixed: the notice "Put Clementine's hat by the window when you're done" comes after
    the hat is placed (the game's order); some subtitles are said two or three times ("Ahhhh! You
    stupid asshole!", Eddie); the hallway credits on the walls (BoardingSchoolDorm) are not read;
    "Your Choices, Episode N" statistics pages are picture collages (only the title is read; fine);
    place names spoil a little ("Poor lloyd", "Beams fall"); TFS has no CheckpointLoad global
    (Death() then Enter reloads the checkpoint).
  - New dev saves: s4_ep4_barnfight (Save 2 just before AJ's walker fight in the barn) and
    s4_ep4done (season finished; copy all *wd4_saveslot2* files, game closed). Save 2 holds
    s4_ep4done's state now (saves.txt: BoardingSchoolDorm.lua).
  - New test tools: watch_barn4.lua (WB lines: player, mode, position, dialog and trigger calls,
    who ran cs_holdDoor; copy to autorun.lua), probe_trigger4.lua (PROBE_TRIGGER's box and whether
    the player is in it), waitplay4.ps1 (keep focus while react4 plays; stop when something needs the
    player; print the log without noise), react4.ps1 -EarlyKey E and a "more close! E to" rule.
  - Questions for the user: whether to replay Episode 4 from its start in Save 2 to hear the barn
    fix (restore dev_saves\s4_ep4done afterwards); the earlier ones below are still open. Michonne
    is the only season left unplayed (release plan: after it).

- Fourteenth session, 2026-10-26 22:00 to 2026-10-27 about 04:00 (user asleep: "keep playing season 4",
  closing Playback error boxes allowed; none came up). Committed and pushed when the user woke
  ("Yes, commit and push tonight's work"). See "The Final
  Season, Episodes 2 to 4 (fourteenth session)" below. Played in Save 2 from just after the
  burning-school fight (the user's own win): the end of Episode 2, ALL of Episode 3 (Abel, the river,
  Minerva, James's barn, the party, the herd with the flashlights, the dock searchlight, the pier
  fight, the boat, Lilly) and Episode 4 up to ForestBarn.lua.
  - (SOLVED in the fifteenth session: see above. Not a game bug: Clementine has to step off
    trigger_dialog_clementimeOut.) WHERE IT WAS STUCK: Episode 4, ForestBarn.lua, the barn. "We need to get these pen doors
    closed": Close Stall Door (obj_logicalStallDoor3) starts amb_closeDoorTimer (about 15 s, then
    Death); the only thing then offered is Move Wheelbarrow (a guided push, W, 11.4 s); when the
    push reaches 100% the game plays cs_holdDoor (hold the barn door struggle), cs_nowWhat, the
    pitchfork again (struggle_backFoulBeast, "won false" every time, even in auto mode), and Close
    Stall Door 3 again: an endless loop, five times round, with and without a reload in between.
    Tried and ruled out: idling (death), S instead of W (no movement, death), tapping W (slower,
    death), Shift+W (no movement), pausing the push (it waits at 50%; holdDoor still at 100%), the
    rope (a look, then the pitchfork), winning backFoulBeast (auto mode), walking to stall doors 1
    and 2 (they stay hidden; the game's own useable list, mCurrentUseables, only ever has the
    wheelbarrow), slow mode. Logic keys are right ("2 - Entered ForestBarn" true; act 2). Only
    trigger: trigger_dialog_clementimeOut. ForestBarn.lua's functions are about stunning walkers
    (ForestBarn_DisableZombieTri, "Stunning an already stunned zombie"). Not known whether the mod
    causes it. Next: ask the user to try the barn (they can see if anything differs), or replay the
    episode from its start (Episodes, Restart Episode 4: Save 2 would lose its Episode 4 progress;
    the user has played in it too, so ask first). Save 2's checkpoint is the stall door (saves.txt: ForestBarn.lua).
  - The dev autorun.lua was deleted from the game folder at the end; settings.txt untouched
    (actionscenes normal, beacons true, beepvolume 30). dist\TWDAccess\mod has every change (copied
    after each sync). The game was closed at the end (free commit had fallen to 6.6 GB; 12 GB after).
  - Fixed and tested in the game unless marked: the bow no longer draws itself over the end-of-
    episode statistics, or with a walker close that Q and E can fight, and Enter goes to the game
    when the bow is up but cannot shoot ("Use Guts", Episode 3); labels for things with no noun ("Let
    Him Smoke", not "Abel, let Him Smoke"), "choice" after a thing that makes a story choice ("Useable
    - Type" Choice) and the notice glyph iconUseable_updated read as "a thing marked choice"; verbs
    ending in a preposition ("Smear Guts On Louis"); hiding behind walkers from flashlights (Q from up
    to 15 m, warnings); a group is walkers within 7.5 m (was 5.5); guard names left out of prompts
    ("Q to stab, E to clobber"); QTEs with several targets in one prompt (Armando's knee or head:
    Tab and Enter), duplicates and model numbers left out of target names; a false "Too late" in
    struggles (waits 1.2 s); the Episodes screen puts the focus on Start; "Objective: Escape";
    place names without "bg_"/"cs_"; "zombat" triggers are no places; walkers that come for her are
    not "walk up to it" targets; mod walks run while walkers are near (untested whether it speeds
    her: SetRunning is called, "lookaround2: running true" logs); auto mode waits half a second
    before acting on a walker (it broke the shore escape); "Hurry!" before what is on offer when a
    scene dialog named "...Timer" starts (heard in the barn). New searchlight4.lua for the dock's
    searchlight (Episode 3): written after the barn stopped play, loads cleanly, not heard there.
  - Questions for the user: the barn (above); whether the herd escape on the shore (Episode 4 start)
    is playable for them by ear in normal mode (seven walkers to shove with E while the mod's walk
    runs to "Get off me"; it worked in auto mode only for the test reactor); the earlier questions
    (AJ shoot at the train station, aim assist) are still open.

- Thirteenth session, 2026-10-25 about 21:30 to 2026-10-26 09:00 (user away overnight: "start working
  on season 4", play to its end, questions saved). Committed and pushed at the end of the
  afternoon with the user (they said "go ahead and push": everything seemed to work). Since then
  the user played The Final Season's Save 2 on through the burning-school fight themselves (its
  checkpoint is wherever they left it: look before playing on), and tests in Season 1's slot 3. See
  "The Final Season, Episodes 1 and 2 (thirteenth session)" below for what was found. Where it
  stopped: Episode 2, BoardingSchoolExteriorDamaged.lua, the burning-school fight after Lilly's raid
  (walkers, some burning: the bow is needed). Not yet won by the test reactor: several deaths; the
  last tries killed walkers with the bow and won struggles but more keep coming. Save 2
  (wd4_saveslot2) holds the checkpoint there. The game was left running; settings.txt actionscenes
  put back to normal.
  - Found and fixed, important: the carry-over made every scene's name "DebugLoader". game.lua's
    Game_NewScene stores FileStripExtension(ScriptManagerGetCurrentScriptName()) as the logic's
    current script (kScriptCurrent), and Game_StartScene sets "<act> - Entered <script>" from it, so no
    "Entered" key was ever set (ForestShack looks for "2 - Entered ForestTile" and replayed its first
    part, softlocked: the spear was gone). carryover.lua now hooks Game_NewScene and puts the real
    name (TWDA_firstScript) back; the script name itself stays the bootstrap's (saves need it). The
    save was repaired with LogicSet("2 - Entered ForestTile"/"ForestShack", true) and
    Game_EndScene("ForestShack.lua") (the global Game_EndScene(nextScript, bFadeOut) loads a scene).
    Every season whose game.lua has this runs the fix; Season 2 and A New Frontier were played before
    it existed (not checked whether their game.lua does the same).
  - New modules: shooter4.lua (aim for the spear fishing and rabbit stations), bow4.lua (Marlon's
    bow), stars4.lua (stargazing). New helper endpoint /mouse (Mouse.cs). Many fixes in combat4,
    guided, qte3, struggle, prompts2, menus, lookaround4, peek, actions, text: see the section.
  - Test tools: react4.ps1 now also holds the key "Hold X to go on" names (let go on "can move"),
    shoves in groups ("more close! ... E to"), draws the bow and shoots on target; onsay.ps1 takes a
    rule with no keys (it only ends a hold or mash). New watch_walkers4.lua and watch_path4.lua
    (walkers and guided paths, logged on change), close_playback_errors.ps1 (closes foobar2000's
    "Playback error" boxes; the user allowed it). The helper must be restarted for /mouse after a
    rebuild: kill TWDAccess.exe, dotnet build to dist, start it (it does not relaunch a running game).
  - Added after the user's reply (same session, 2026-10-26 about 11:00 to 12:00; not yet tried in
    play): sound beacons and aiming the bow by ear, at the user's request. Helper: Tones.cs, a small
    waveOut mixer behind /tone?f=660,990&ms=45&p=-1..1&v=0..1&w=s|q|t|n&lp=1 (overlapping tones,
    equal-power pan, lp muffles). Lua: sounds.lua (TWDA.tone; TWDA.soundDirection(point): angle from
    where AgentGetCamera(player) faces on the ground, pan, behind, distance; checked in the game),
    beacons.lua (was beacons4.lua; the nearest 4 of Tab's list within 25 m, plus Tab's choice, ping
    in turn every 0.22 s: blip 1200 Hz for things, chime 660-990 for places, square 140 Hz for
    walkers; louder nearer, muffled and lower behind; F4 and setting beacons; quiet while the bow is
    drawn; entries from TWDA.beaconEntries, free play only), bow4.lua's bowaim = sound (default):
    arrows turn the camera through /mouse, Navigate's arrow handlers are swallowed while drawn
    (W A S D still walk), the height is levelled to the target, the last 0.12 of the screen is
    closed once the arrows are let go, and a tone every 0.12 s: pan full at 30 degrees, pitch 300 to
    1000 Hz as the aim nears it, a 1500/2000 Hz double tick on target; bowaim = auto keeps the old
    automatic aim.
  - Then tuned with the user playing (2026-10-26 afternoon): the game turns about a degree per 65
    mouse pixels, so 8 px a tick (2.5 degrees a second) lost the burning-school fight (the third
    walker came from the far left). Now setting bowturn (16 px every 0.05 s) ramps to 8 times from
    0.2 to 0.8 s of holding (about 40 degrees a second), Shift triples, max 400 a tick. The user won
    the fight with it. "bow4: shooting at" now logs the target's screen position (to tell misses
    from walkers that take two arrows: ZombieCombat07 took four and lived once). Setting beepvolume
    (10 to 150 percent, sounds.lua scales every tone): F3 louder, Shift+F3 quieter (the user's
    choice of keys), said and then a blip. The user set it to 10.
  - Beacons in every season (user asked, same afternoon): TWDA.beaconEntries is a chain, each
    look-around module wrapping the one before (lookaround.lua for Season 1 and 400 Days: Tab's
    hotspots and places where Lee walks freely, not close-ups, no walkers since dead ones look
    alive; lookaround2.lua for Season 2 and A New Frontier: usables with verbs (checked every 3 s,
    not twice a second, as building verbs resets the reticle's), places as Tab has them, fight
    targets named zombie/walker and "trigger_zombieN"/"trigger_walkerN" triggers with Trigger
    Enabled as walkers; lookaround4.lua for The Final Season). Panned from the camera, as the
    walking keys are. Compiles in the game; NOT yet heard in Seasons 1 to 3 (the user was playing
    The Final Season). To check there: the pan at a Season 1 camera cut, walker triggers really
    being enabled, and the cost of Season 1's hotspots() twice a second.
  - Heard by the user in Season 1 (motor inn): the beacons work, but all of them at once are hard
    to tell apart. Setting beacons is now "tab" (default; true from before counts as tab): only
    Tab's choice pings, every 0.4 s, the list looked at every 0.25 s; "all" is the old way; "off".
    F4 goes tab, all, off. Season 1's choice is the latest of the reticle's target, the walk
    offered (walkOffer: Tab on what the reticle cannot take sets no target, "Duck, behind you, 3
    meters. Enter walks there", which first gave no beep) and the walk under way (walking); it is
    added to the list even when hotspots() has lost it after a camera cut. The running motor-inn
    state was patched live (TWDA.beaconEntries reading the "lookaround" frame function's upvalues);
    the files load it properly from the next scene.
  - The user copied Season 1's Save 2 to slot 3 (Save Slots menu, F10) to test the beacons there:
    slot 3 is the user's now, like slot 1. The copy left saves.txt without a slot 3 line: the
    menu's mCopySlot and mCurrentSlot are numbers (2, 3), saves.txt keys are file names, so
    carryover.lua's copy and delete hooks never matched (the handoff's "copying and deleting slots
    keep it in step" was not so). Fixed: slotKey() turns a number into the active slot's name with
    that number. The line "wd1_saveslot3.bundle<TAB>env_manorInteriorClementineSearch.lua" was
    added by hand (slot 3's autosave is byte for byte slot 2's).
  - Questions for the user (asked at the end of the session): the bow's keys (R draws, Enter
    shoots, Tab next target) and the helper moving the mouse to turn the camera; whether "AJ, shoot!"
    at the train station (instant game over) is so in their game; whether aiming Q and E at a walker
    beside or behind Clementine is acceptable.

- Twelfth session, 2026-10-25 00:40 to about 03:10 (user asleep: "start working on season 4", play
  through to its end; questions saved). Season 4 = The Final Season. Stopped early: the usage limit
  was reached, and the command safety check failed for the last few minutes. See "The Final Season
  (twelfth session)" below for the framework. Where it stopped: Episode 1, BoardingSchoolInterior.lua,
  just after the talk with Ruby (objective "FIND AJ"; places Entrance, Approach stairs, Approach door;
  Marlon said to follow the piano music to Louis). Save 2 (wd4_saveslot2) holds the checkpoints.
  Afterwards the user closed the game and asked for a push: the dev autorun.lua was deleted from
  the game folder, dist\TWDAccess was rebuilt (and the Lua copied into the game folder), and
  everything was committed and pushed. To watch every Lua state again while developing, copy
  tools\dev\watch_s4.lua to <game>\TWDAccess\autorun.lua (delete it before the user plays: it floods
  twda.log with WS2 lines and doubles some hooks).
  New and changed, tested in the game unless marked:
  - New configurator.lua (the story recap's questions; keys added, captions read).
  - New lookaround4.lua: Tab/Shift+Tab through the useables (labels "Pick Up Canteen"), places to
    walk to (lookaround2's places, exported as TWDA.walkPlaces/TWDA.walkTo; aims a meter past a
    story line so it is crossed) and walkers to walk up to (combat4); Enter or F uses the Tab choice
    (wraps Useable_OnButtonUse), else the only thing, else the game's own pick; F6; announcements
    ("Clementine can move. ..."), forced again when control returns after 3 s out (untested);
    Backspace leaves a station; "Nothing more here. Backspace steps back."; leaves Enter to qte3
    while a QTE target is up (untested).
  - New combat4.lua: walkers (AI agents with "AI Agent - AI Agent Enable"): "Walker, 6 meters,
    ahead." and at 3.5 m; in reach (about 2 m, half a second): "Walker! Q to attack, E to shove!";
    Q or E pressed while one comes is kept 1.5 s and done the moment it is in reach (this is how the
    first walkers and the pinned one were killed by ear); slow mode slows while one is close; auto
    attacks; F6. TWDA.walkerTargets for walking up to a walker that stays put (stops when in reach).
  - lookaround2.lua: death traps ("caught", "kill", "death"...) are no places and are steered round
    (a waypoint 2.5 m beside a trap near the straight way); walks can have stopAt/stopWhen;
    "trigger_dialog_*zombie*" story spots count as places in The Final Season.
  - struggle.lua: a struggle is announced when "Struggle - Enabled" turns true (TFS sets it up first)
    and is over only after it ran. qte3.lua: QTE targets from QTE_GetQuickTimeAgents' "QTE Prompt -
    N". prompts2.lua: TFS notices (one text agent) and the Objective/Inventory/... kinds.
    menus.lua: recap captions under the resting mouse not read; digits count as navigation keys.
    hotkeys.lua: F6 has TWDA.describeConfigurator, describeCombat, describeWalkers.
    devconsole.lua: runs TWDAccess\autorun.lua a second into each Lua state if it exists (dev only).
  - Test tools: react4.ps1 (background reactor for TFS), use4.ps1, useall4.ps1, probe_ai4.lua,
    watch_s4.lua; dumpup.lua takes DUMPUP_DEPTH.
  - Seen, not fixed: menus "Import Save? menu. No. Yes" and the import screen read buttons in child
    order, not left to right, and give no "left and right arrows" hint; the Telltale account screen
    reads only "Join" (its text is on ui_popupWindow_body); "Settings menu, 6 items. Page Down:
    Rename" (a popup's legend stuck); "Camera Sensitivity : 0"; Gameplay Settings counts 3 items for
    2; after an attack the walker going down is announced "in reach" again; guided.lua says "W does
    not move Clementine here" while a station pauses the path; examine lines have no subtitles.
  - Questions for the user: none yet beyond checking the new keys in play.

- Eleventh session, 2026-10-24 15:35 to about 16:00 (user in the game: "NVDA keeps saying escape
  before each season selection"). Season Select said "Escape Previous Menu, Michonne, Haunted
  by ..." on every Left and Right. Cause: after Menu_Seasons_Select, the game selects the mouse-only
  ui_seasons_arrowLeft from inside a WidgetInputHandler mouse function (mouseDepth 1, even on
  keyboard input), so onSelect read it rather than redirecting. The arrow has no text, and
  siblingText (Season 2's label-beside-button fallback) read its siblings: the whole screen under
  ui_seasons_reference, legend button first. That replaced the queued season text. Fix in menus.lua:
  siblingText returns nil for arrow buttons. Tested by the user in the game (patched live, then
  synced): each press now says "Michonne. Haunted by ... Left and right for other seasons, Enter to
  play". The redirect to the Play button still happens (Menu_Seasons_Select's hook sets it).
  dist\TWDAccess\mod has the new menus.lua (copied; the helper was running, so not rebuilt).
  Not committed.

- Tenth session, 2026-10-24 01:30 to about 12:30 (user: "Work through the next season if you
  can", then asleep; questions saved for the end). The season after Season 2 in the hub's Season
  Select is A NEW FRONTIER (Season 3, Javier); the carousel order is Season 1, Season 2, A New
  Frontier, The Final Season, Michonne. ALL OF A NEW FRONTIER IS NOW PLAYED by ear, Episodes 1 to 5,
  in its Save 2 (the user's Save 1 is untouched and empty), story imported from Season 2's save
  file 2 ("Clem is on the road with AJ"), choices mostly answer 1. Committed and pushed at the
  user's request after they woke (see git log). dist\TWDAccess was rebuilt at the end and the game
  closed.
  See "A New Frontier (tenth session)" below for how its framework works and what the mod does;
  the walkthrough notes are there too. New dev saves: s3_ep1done ... s3_ep5done (all
  *wd3_saveslot2* files; copy them all into the save folder to use one).
  Fixed or added, all tested in the game unless marked:
  - Bootstrap (mod\src\DebugLoader.lua): A New Frontier's engine boot script (_boot.lua) requires
    DebugLoader.lua before the engine runs it as the state's first script; the require run used to
    delete next_script.txt, so entering the season fell back to the hub. The note is now kept on
    the require path. (Season 3 states log "bootstrap: running ..." as before.)
  - menus.lua (A New Frontier's menus are the hub's widget framework): titles one level down
    ("ui_menuSettings_header_header") and headers that are not widgets (the Save Files popup, the
    story setup); a capitals heading run together with its sentence is split ("Choose How To Begin
    Your Story, 2 items. The Walking Dead: A New Frontier can be started ..."); a screen that
    changes its heading in place is read again ("Your Story So Far"); help text in a screen's own
    tooltip agent is read after the item ("Continue this story: Clem is on the road with AJ.");
    the save file in use says "checked"; legend icons ("iconCopy") are not read; the X button is
    "Close"; a widget holding several buttons counts each; "Paused" is "Pause menu"; legend keys
    of a popup no longer stick to the menu under it (mostly; "Close" is left out of titles); a
    legend button under the resting mouse is not read as a menu opens. The Episodes screen: on PC
    its arrows only move a thumbnail highlight and Enter there does nothing, so the mod makes Left
    and Right switch episodes (Carousel SelectElement) with focus kept on "Start Episode N" (Enter
    plays it); it is read once settled. The end-of-episode choice statistics (menu_stats.lua) are
    read page by page ("Choice 2 of 6. Left and right arrows for the others", last page "Enter
    continues"), and the season summary after Episode 5.
  - New qte3.lua: A New Frontier's quick-time events. Prompts (QTE_UI_ShowPrompt) say their key:
    "Enter!" for the face buttons, or "E!"/"Q!" where the QTE has "Alt Keyboard Keys" (the screen
    shows E or Q then, and Enter does not work), "Left arrow!" etc.; held prompts "Hold Enter!" and
    "Let go!" (the latter untested). Prompts that are things to pick ("obj_rockClem": "Rock:
    Enter!"; "Conrad's hand: Enter!") are found in the QTE agents' promptsCurrent and Enter does
    them (ExecuteAction). Multi-prompt QTEs (MultiQTE_Enable): "E, 3 times, fast!", "Press Shift
    and E together!". Slow mode slows all of these; auto mode does them. TWDA.qteBusy() keeps
    lookaround2 from saying "Javier can move" between the prompts of one QTE.
  - New drag3.lua: A New Frontier's drags (hold Enter, then the arrow the drag allows). The mod
    says "Drag: hold Down arrow." and holds the button itself while an arrow is held; a drag with no
    direction says "Hold Enter!" (filling the syringe). (Tested by calling the functions and with
    the user's keys as Enter plus arrow; the arrow-only path was not exercised by a real key.)
  - struggle.lua: A New Frontier's StruggleQTE ("Struggle! Press Q over and over. Then E when
    told.", "Halfway", "E now!"; meter "Struggle - Current Percentage" 0 to 1). Mashing needs about
    10 or more presses a second in normal mode; slow and auto modes work. Waggle and circle types
    have texts but were never met.
  - lookaround2.lua: ReticleSelection_GetUseables (A New Frontier's spelling) so Tab, Enter and F6
    work; stations (Game mode "Station", door or car close-ups) say "Close-up. Backspace steps
    back." and Backspace does it; places leave out camera zones (OTS, rack focus), walk-speed
    switches, and anything named zombie or walker (walker triggers, and spoilers like "Zombie
    attack"); a walk the game interrupts goes on by itself when control returns (within 20 s);
    walks steer around walkers (their "trigger_zombieN" triggers) and keep trying instead of
    "Blocked" among them. This is how the herd to the generator (Episode 5) was crossed.
  - guided.lua: A New Frontier has no ChoredMovement_GetTimePercent; progress comes from the
    controller's time, so "Halfway", "W does not move Javier here. Try S" and "S goes on" work.
  - prompts2.lua: the death screen is read in A New Frontier (Death_OnButtonPress; Enter is the
    game's own there, so the mod does not press it again).
  - Not fixed, seen on the way: struggles at 7 to 8 presses a second (the test tool's rate) often
    fall back; the Episodes screen announces the right episode only after 0.6 s; "Share this
    choice" can be read after the last statistics page; "Grab X, walking there." is said inside a
    close-up; place lists can include triggers in another room (the trailer's exterior from
    inside); a mouse pointer resting over menu items can still select them as things move under it
    (restart.ps1's click leaves the pointer at the bottom middle, over the Episodes thumbnails).
  - Game memory: WDC.exe itself grew to about 10 GB of commit over ten hours of play (free commit
    fell to 3 GB); restarting the game freed it. Restart it every few hours in long sessions.
  - Test tools (tools\dev): sync.ps1 (build and copy the Lua into the game folder; the next Lua
    state uses it), to_season.ps1 -Season 3 [-FromSeason3], watch_s3.lua (WS2 lines for A New
    Frontier's QTE, struggle, multi-QTE, drag, station, reticle and death calls), menu3.lua (the
    current widget menu's widgets and texts), tree.lua now dumps widget menus too, useall.ps1
    (use named things in turn, "Name#2" for action 2, letting play2 answer and press), chord.ps1
    (hold one key then another). play2.ps1 now mashes Q at about 12 a second (onsay presses keys
    directly), holds W on guided paths, presses E/Q/Shift+E cues, and picks up lines from the 1.5 s
    before it starts; use2.ps1 has -NoFollow; holdkey.ps1 and game_input.ps1 know Enter.

- Ninth session, 2026-10-12 00:20 to 16:45 (user: "Read the handoff file. Then progress and work
  through what you can of the rest of season 2"; user away all session). ALL OF SEASON 2 IS NOW
  PLAYED by ear in save file 2: the rest of Episode 2 (from the group talk after Carver's visit),
  Episodes 3, 4 and 5, to the ending (alone with AJ) and back to Season 2's main menu. Choices
  were mostly answer 1, so other branches are unplayed (see "Season 2 walkthrough notes" below).
  Committed and pushed (2daa27a) at the user's request. dist\TWDAccess was rebuilt with every change and the game was
  closed. The user's settings.txt is back to actionscenes = normal (it was slow for this testing).
  A "Playback error" box from the user's music player sat over the game window all session (theirs;
  left alone; it may have stolen focus now and then).
  New dev saves (copy all *wd2_saveslot2* files from the folder into the save folder to use one):
  s2_ep2_cabinnight (save file 2 as the session started), s2_ep2done, s2_ep3done, s2_ep4done,
  s2_ep5done (season finished).
  Mod fixes, all tested in the game unless marked untested:
  - guided.lua: progress is measured from where the held key started, not frame to frame (the
    chairlift ladder, Episode 2, moves under 0.1% a frame, so "W does not move Clementine" was said
    wrongly); "Halfway" only when the path crosses it. Season 2: a key held from before a path
    starts is passed on to the game (ChoredMovement_SetJoystickDirection), because the game moves
    only on key-down events: the shoe store squeeze (Episode 3: "Hold A to escape!" shown 4 s
    before a 1.3 s window) was otherwise lost even with A held. When the game's hint names no key
    ("Don't fall behind!", "Get to Luke!"), "Guided path. Hold W or S" is said at once.
  - prompts2.lua: Season 2's notices are read: Notification_ShowTutorial hints ("Hold A to
    escape!", "Push the W key to crawl forward", "Find a way through!") and
    Notification_ShowChoice ("Kenny will remember that.", "You convinced Jane to re-join the
    group."). Inventory items use the game's names ("Survival Knife", "Walkie Talkie").
  - actions.lua: one shared slow-motion switch, TWDA.setSlowFor(reason, on). Before, actions.lua
    put any 0.45 time scale back to 1 every frame outside a Season 1 action scene, so Season 2's
    slow mode never slowed dodges (only struggles). action2.lua and lookaround2.lua use it.
  - lookaround2.lua (hotspots, places, walks):
    - Fight targets are checked every 0.1 s and said after 0.3 s (the walker's head after the
      rifle struggle at the lodge is there about 3 s); things appearing where there was nothing
      after 0.3 s; things flickering in and out of selectable count for 0.8 s; announcements
      compare which agents are on offer, not only their text (the second "Walker: Chop" in the
      herd, Episode 3, was never said and Clementine died).
    - Two or three fight targets of different kinds are all named ("Walker's Arm: Stab, Walker's
      Knee: Shatter, or Walker's Head: Spike. Enter for the first"): "Sarita's Arm: Hack Off, and
      1 more" hid a story choice. Several of one kind still read "Walker 1: Shoot, and 2 more".
    - Slow mode also slows fights while a target is up (untested since the last change).
    - Things 6 m or more away are run to (Navigate_PathToAndUseAgent's bRun, as a double click;
      not clearly confirmed by ear).
    - Places: "warp" triggers are left out; "trigger_cam_nav_*" triggers are offered (the
      snowstorm's "Rest stop entrance", 115 m away, is the only sign of the way, and W leads away
      from it); in combat mode places are listed when no target is up. A mod walk pauses while a
      target is up (Enter shoots it) and walks on after; it says "N meters to go." every 10 s
      (untested by ear); its time limit grows with its length (it gave up after 120 s).
    - Unnamed hotspots read better ("Comic shop door", not "Door comic shop use point").
    - Season 2 close-ups say "Close-up. S steps back." (heard); Backspace steps back too
      (CloseUp_OnButtonExit; untested).
  - peek.lua: Season 2 hiding gets Season 1's lean feedback ("Leaning out right. A to get back",
    "Back in cover", "Get back now, A!" after 3 s; the last may be needless in Jane's lesson).
  - text.lua: CD, DVD, RV and OK stay in capitals.
  - Not mod bugs, found on the way: struggles need about 7 presses a second to rise (each adds
    4%, the meter drains a third a second whenever no press lands in a 40 ms tick); slow mode's
    hold-Q wins them easily. Some struggles cannot be won by design (the cable in Episode 3: Troy
    pulls her out; restraining Sarita). After an episode's "My Choices", Escape pressed while the
    credits screen is still loading does nothing; press it again.
  - Ideas not done: say "again" when the game asks for the same action twice ("turn it again",
    Kenny at the truck: the offer is the same as before, so nothing is said); the place names
    "Zombie snowstorm 1" (walker triggers) and "Freewalk transitions" are offered as places;
    "Got/No more" announcements are plain; F6 on a Season 2 episode's credits reads them all in
    one go (F8 stops it).
  - Test tools (tools\dev): play2.ps1 (play on by ear: answers choices, Enter on single offers and
    "Enter!", holds Q in struggles and arrows in drags; answers a choice already waiting),
    onsay.ps1 (keeps mashing through "Halfway"; "^Q" holds a key until another rule fires),
    game_input.ps1 (refocuses before each key; 120 ms presses), use2.ps1 (reads speech.log as
    UTF-8), talk.ps1 (answers a choice already waiting), watch_after2.lua (mode, maps, shown dots,
    action agents), watch_window2.lua (ChoredMovement_Start, Dialog_Play, Game_UseAgent, usables),
    watch_peek2.lua, probe_chored2.lua and probe_chored3.lua (a guided path's percent and joystick),
    probe_agent2.lua (one agent's selectable flag and verbs), peek2_try.ps1, shots_after.ps1.
    Gotchas: piping use2.ps1 into Select-Object -First 1 stops it before it presses Enter (made
    that mistake twice); a choice that appears between two script runs is missed unless the next
    run checks for it (play2 and talk now do).

- Eighth session, 2026-10-11 16:40 to 18:00 (user: "before trying to move forward with the game,
  we should try to fix some bugs first"). Bug fixes only, all tested in the game unless noted.
  Committed and pushed (c8789b1) at the user's request; #6 closed, #16 commented (left open).
  dist\TWDAccess was rebuilt (restart.ps1) and the game closed.
  - The user's own gate bug (Season 1 Episode 1, night branch: choosing "Get out of here once the
    sun goes down" leads to env_clementineHouseExterior_Night.lua): after "Through Gate." Tab kept
    offering the backyard, and walks there failed at once. lookaround.lua walkTick now says "There
    is no way to X from here." when a walk ends with Lee barely moved (under 1.5 m) and either the
    goal is over 6 m off or the walk failed within 2 s (the second "Bathroom Door" upstairs in the
    Savannah house, a meter away through the wall). Such things leave the Tab list (noWay) until
    anything is used (Main_OnUse / PathToAndUseAgent hook) or Lee is 10 m from where it was
    marked; not things on another floor. A walk that ends where the thing can be used (clickable:
    Shawn at the farm fence, far use) now counts as arrived instead of "can go no further". The
    engine facts: AgentPathToAgent to an unreachable spot returns false in 0.4 s without moving;
    to where Lee already stands it returns true at once; the walk boxes are one mesh
    (WalkBoxesPosOnWalkBoxes puts the backyard on them from the street), and
    PathAgentDoesPathReachDestination said true with 0.4 m of path left, so nothing tells in
    advance. SCENE_PLACES now has "Street" (trigger_MeetShawnNight) for that scene: walking there
    brings Shawn and Chet; places are listed only while "Trigger Enabled" is not false.
  - Issue #16 (first Enter after a walk does nothing): reproduced a cause in the Savannah house
    (dev_saves\ep4_clemsearch). After a walk that ended short, Enter fell back to current.agent,
    the last thing the reticle passed over silently on the way, and opened the Bathroom Door
    instead of going on to the Bedroom Door. Now: what the reticle passed during a walk is
    forgotten (forgetFocusPassed); "Lee stopped before reaching X. Enter walks on." sets a walk
    offer; and the game's PathToAndUseAgent (navigate.lua; DoAction uses it for "WD Should Path"
    hotspots) is watched: when it returns without calling Main_OnUse (its post-walk checks give
    up silently), lookaround.lua logs "PathToAndUseAgent ended without a use of X" and tries the
    use once more (not within 20 s of the last retry, not with a movement key held). The grave
    case itself was not reproduced; look for that log line if it comes back. Doors and people
    worked first time after walks (Kenny, the master bedroom door).
  - Issue #6: Escape is left to the game (the pause menu). Backspace already let go of a held
    hotspot outside close-ups (goBack sets target = nil; OnBack does nothing there) and now also
    stops a mod walk ("Stopped.").
  - False "Hurry: about 10 seconds. Katjaa: Talk to" at Hershel's farm: timer_KatClemChatter
    (ends in "idleBanter_katjaa", 10 s) counted as a countdown. actions.lua now skips timers whose
    end node or own name has hint, ambient, chatter, banter or idle in it (cs_ ends still count).
  - Season 2: the pause menu (root ui_menu_pause, no header) says "Pause menu, 4 items"; the
    credits (credits.lua: agent ui_credits_text, node text_credits in ui_credits20<ep>.dlog) read
    with F6 from the menu and after episodes (menus.lua rawText + formatCredits; also fixed an
    undefined kTextNode there); Chapter Select no longer says "Change Save File" when the resting
    mouse pointer is over that nav button (a real, visible PC button at the bottom; Enter still
    plays the centre panel): in carousels a non-panel selection with no arrow key or Tab in the
    last 0.5 s and no mouse move in the last 1 s is logged, not read.
  - Season 2, found and fixed: with the pause menu open over a dialog choice, choices2.lua still
    took Up, Down, 1-4 and Enter, so Down in the pause menu also read a dialog answer and Enter
    picked one (seen happen). choices2 now ignores keys while UIZ_GetActiveMenu() is not nil
    (it is nil while choices are up on their own, "ui_menu_pause" when paused), and hasChoices is
    false then, so F6 reads the menu. Season 1's hasChoices is false while mode_PauseMenu is up
    too (its choice keys are the game's own, so only F6 changed there).
  - Season 2, untested in the game: same-named hotspots are numbered in the order of their agent
    names, not by distance, so "Stall 2" stays the same stall (lookaround2.lua hotspots()).
  - Issue #20's fix (an unreachable mark is dropped once the hotspot is clickable) was already in
    the code; still not replayed at the Crawford alley.
  - New dev saves: backyard_leaving (env_clementineHouseExterior.lua, day branch, just out of the
    house after the fight) and backyard_night (env_clementineHouseExterior_Night.lua, the night
    branch). Slot 2 (Season 1) now holds Episode 4's Clementine search
    (saves.txt: env_manorInteriorClementineSearch.lua); Season 2 save file 2 is unchanged
    (CabinInterior.lua). New probes in tools\dev: probe_noway.lua (walk-box distances),
    probe_walk.lua (what AgentPathToAgent returns), probe_repath.lua, triggers1.lua (Season 1
    triggers near Lee, TRIG lines).

- Seventh session, 2026-10-10 22:20 to 2026-10-11 14:30 (user: "go ahead and start working on
  season 2", then away overnight; they came back, closed the game at 14:21 and asked for this
  handoff and a push). Everything below is committed and pushed (see git log).
  - Season 2 play is now approved (it was "not yet" on 2026-10-10 morning). The agent's Season 2
    test save is save file 2 (Season 2's Save Files carousel). The user deleted their own Season 1
    slot 1 save on 2026-10-10, on purpose; slot 1 being empty is their doing.
  - Played ALL of Season 2 Episode 1 (All That Remains) in save file 2, mostly by ear (keys and
    speech; struggles were won in auto mode because PowerShell mashing is too slow), and most of
    Episode 2. Season 2 runs on a newer Telltale framework (the Wolf Among Us generation), so most
    Season 1 gameplay modules do nothing there. New modules: choices2, lookaround2 (hotspots,
    places to walk to, steering), drag2, action2, prompts2 (death screen, inventory). Season 2
    branches added to struggle.lua, peek.lua, guided.lua and menus.lua (carousels, Import Season 1
    Save, the end-of-episode "My Choices"). Details: "Season 2 during play (seventh session)".
  - Shared changes that also touch Season 1: hotkeys.lua F6 now asks TWDA.describeDeath and
    TWDA.describeAction2 first; text.lua normalCaps treats a curly apostrophe as part of the word
    ("In Harm's Way", was "Harm’S"); struggle.lua's start text names the mash keys per season.
  - Where it stopped: Season 2 Episode 2 (A House Divided), Pete route, after the truck, the cabin
    night with Sarah, Carver's visit and the talk with the group; a guided path ("Guided path.
    Hold W or S") had just started. Save file 2's checkpoint is there: Season 2 main menu, Play,
    Continue. dev_saves\s2_ep1done holds save file 2 after Episode 1 (Season 2's files are
    wd2_saveslot2.bundle, _wd2_saveslot2_autosave.bundle and one _checkpointN.bundle per chapter).
  - The user's settings.txt is back to actionscenes = normal (it was auto for part of the
    testing). dist\TWDAccess was rebuilt with every change.
  - Known gaps in Season 2 (the pause menu title, the credits, "Change Save File" and the hotspot
    numbers were fixed in the eighth session): place names can spoil the story ("Dog finds
    zombie") and some triggers are for other characters and never fire for Clementine; struggles
    need fast mashing in normal mode (slow mode's hold-Q works for Season 2 too; untested by ear).
  - Seen in the user's own Season 1 play on 2026-10-10 (slot 1, Episode 1, from the house fight to
    the fence; they won the babysitter fight): after "Through Gate." the Tab list still offered the
    backyard's hotspots and every walk to them failed at once. Fixed in the eighth session.

- Sixth session, 2026-10-09 evening to 2026-10-10 05:25 (user: "keep going on the game"). See
  "Sixth session: 400 Days", "Season 2's menus" and "400 Days replayed" below. In short: finished
  testing Episode 4's River Street (two fixes), fixed the countdown time (#19, now also heard in
  the game; closed on GitHub), played all of 400 Days in slot 2 by ear, made Season 2's menus speak
  (all but Play, which would start a Season 2 game; ask the user first), then replayed parts of
  400 Days: the cornfield now names the safe row, works round a game bug that left the panic
  meter on, and says when to run out; Russell's mouse-only sneak now works with Up arrow (new
  fastslow.lua). All of it is committed (c84fe53, 6bdb6e2, bf710e9 and this handoff update);
  see the Git note under "Developer tooling" for pushing. dist\TWDAccess matches the source.

- Fifth session, 2026-10-09 early morning (user asleep, "keep working on the mod"; questions saved
  for the end). The fourth session (2026-10-08 evening to 2026-10-09 02:00) finished Episode 2 and
  played Episode 3 in slot 2 as far as Clementine's shooting lesson on the train
  (env_trainAfterStop.lua), but ran out of time before writing its Episode 3 work down; the
  fifth session reconstructed it from that session's transcript into "Episode 3 notes", the file
  map (sniper.lua, panels.lua, readables.lua) and the tools list. See "Fifth session" below that
  for what the fifth session itself did.
- The fifth session finished Episode 3, then played all of Episodes 4 and 5 in slot 2 by ear:
  the whole Season 1 story is now playable with the mod (dev_saves\ep5done). See "Episode 4
  notes", "Episode 5 notes" and the change lists under "Fifth session". Not played yet: the 400
  Days episode, and Seasons 2 to 4 (only their menus are partly done, issue #5). The user now
  closes SteelSeries GG while the agent works (it leaks memory with each game launch).
- The game closed at 08:44 because the user closed it (not a crash). Free commit memory was then
  4.8 GB of 34: the SteelSeries capture service starts a copy with every game launch and two
  copies held about 10 GB (see the memory note), so the session did not relaunch the game and
  did code work instead (names, walk danger stop, issues #16 to #19). Before launching
  again, check free commit memory (Win32_OperatingSystem FreeVirtualMemory); ask the user to
  restart SteelSeries GG or reboot if it is low. Each restart.ps1 adds a capture copy, so
  restart as rarely as possible.
- dist\TWDAccess was rebuilt at the end with every change (the installed copy in the game folder
  is replaced from it at the next launch).
- Where the session stopped (15:50, user asked to stop): replaying Episode 4 from its start
  (dev_saves\ep3done, Episode 4 "Play") to test the countdown fix (#19) in the alley chase after
  Molly. Got through the opening, yard, house, attic and burial to River Street; slot 2's
  checkpoint is now the start of River Street (saves.txt: env_savannahRiverStreet.lua), also
  copied to the new dev_saves\ep4_riverstreet. Next: Telescope, Newspaper Machine (Bash for
  coins), Telescope: Use Quarter On, the newsstand, Molly, then the alley chase: check whether
  "Hurry: about N seconds" now gives real times (timer_zombieGroupClosesIn). The game may still
  be running (started by the agent); close it before swapping saves.
- Fixed on the way (committed): number keys after a numbered offer that is not pressed on the
  player ("Zombie: 1 Look At, 2 Shoot, 3 Bash, 4 Stomp." for the attic boy; Enter did Look At)
  now apply to it (TWDA.numbersMean); a Tab target chosen before a newer announcement no longer
  wins ("Shovel can't be reached" at the grave after "Loose Dirt: Shovel. Enter to do it."); after
  15 s Enter takes whichever came last, announcement or focus; use-node names get PRETTY names
  ("front door"). Untested oddity: once at the grave, Enter on Loose Dirt said "christa and omid
  can't be reached from here". play_by_ear.ps1 -Answer misses a choice already waiting when a
  speaker line was logged after it (the Episode 4 opening sat on Clementine's question).
- After Season 1 was finished, the sewers (Episode 4) were replayed from dev_saves\ep4_sewers to
  test #17; see "Sewer retest" (after the Episode 5 notes) for eight fixes made there. Slot 2 now
  holds that sewer checkpoint (the leg grab), not ep5done; saves.txt says env_savannahSewers.lua.
  The game was left running at the upper tunnel, or closed at the end of the session.
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
   shed door, grave); a second Enter works. Eighth session: one cause found and fixed (Enter fell
   back to a hotspot passed silently on the way) and a retry added for PathToAndUseAgent giving up
   without a use; the grave case not reproduced. See "Start here".
H. (#17) Walks take the shortest way and can lead Lee into walkers (Savannah sewers). Tested and
   reworked 2026-10-09 (see "Sewer retest"): stops when the vignette comes up during the walk or
   when Lee heads for a still walker within 5 m; not while walkers chase him. Still open: routes
   that must avoid an area.
I. (#18) Probably not a real problem: a slot has two files, and the main wd1_saveslotN.bundle is
   rewritten at scene starts, while the checkpoint is _wd1_saveslotN_autosave.bundle (written on
   SaveSlots_Save, which the hooks catch). Do not change saves.txt by hand because of the main
   file's time: doing so loaded hallway data with the nurse's office script (reticle stuck off).
   carryover.lua now also watches the autosave file ("savewatch: ... changed" in twda.log).
J. (#19, closed 2026-10-10) Countdowns said "about 1 second" at each step of the alley chase
   (Episode 4). Fixed by measuring the fill rate; heard in the game ("about 30 seconds").
E. (#14) Long walks are slow and silent (Lee limps: 35 m to Hershel took about 40 s after "Walking
   to Hershel"). 2026-10-09: every 10 s of a walk, "N meters to go." while the distance goes down
   (not yet heard in a test: the sewer walks were shorter). When the game takes Lee over during a
   walk, nothing is said then; once he can walk again, "The walk to X was cut short, N meters
   away. Enter walks on." (tested; Enter within 30 s).

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
   probably use the same widget framework as the hub. Season 2's menus (their own UIZ framework,
   not Season 1's panes) were done on 2026-10-10; Play, Chapter Select, the save file carousel,
   Import Season 1 Save and the end-of-episode My Choices were done in the seventh session. All of
   Season 2 was played by ear by the ninth session (one path through the choices). A New Frontier
   (its menus, which are the hub's widget framework, and all five episodes) was done in the tenth
   session. The Final Season was begun in the twelfth session (menus, recap, Episode 1 to the
   school; see "Start here") and finished in the fifteenth; Michonne was played through in the
   seventeenth (2026-10-29). Every season is now done; close #5 when the user agrees.
6. (#6) Done in the eighth session: Escape is the game's (pause menu); Backspace lets go of the
   held hotspot and stops a walk.
7. (#7) Done 2026-10-09, not yet run against the real game folder: --uninstall now keeps
   Archives\DebugLoader.lua and TWDAccess\saves.txt when saves may have been made with the mod
   (saves.txt has a slot, or a save .bundle is newer than installed.txt), keeps the bootstrap's line
   in installed.txt so a later install can still update it, and says so; --uninstall --all removes
   everything. Tested on a fake game folder.
8. (#8) Later, optional: controller support. Keyboard is the primary target and is enough for the user;
   if a controller is added it will be a PS5 DualSense, so hints should name PlayStation buttons and
   follow the game's own device switch (Menu_UsingJoystick in Season 1). Mod commands (F5 to F11)
   would need a button combination; check which buttons the game leaves free (the touchpad click is
   a candidate) and whether a keyboard press flips the game out of controller mode.
9. (#9) Done 2026-10-31 (TWD Access 1.0.0 released; see "Start here"). Was: set discovery and devconsole to false in the installed settings.txt, delete the
   TWDAccess\dumps folder in the game directory, and remove the stale TWDAccess\globals_*.txt,
   trap.log and stack_*.luac files.
   The user's release plan (2026-10-24): build a release only after the whole game has been
   played through with the mod (done as of 2026-10-29; the user wants the two Season 1 loose ends
   looked at next, then the release is their call). The release must
   bundle the .NET runtime (a self-contained build; today's helper is framework-dependent,
   SelfContained false), so players need not install .NET. Also planned then: a zip without the
   dev modules (devconsole, devtools, discovery), a players' read-me (requirements, keys,
   uninstall, what is covered), Prism's NOTICE and licence files, a licence for the mod, release
   notes, and a GitHub release (the repository is private; going public is the user's call).

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
   on its own without the rest of the TWDAccess folder, so --uninstall leaves it and saves.txt in
   place when the player may have such saves (--uninstall --all removes them too).
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
  The game selects the left arrow from inside its mouse handlers even on keyboard Left and Right,
  so menus.lua treats it as mouse focus; the arrow must have no text (siblingText skips arrows),
  or it overrides the season text (2026-10-24).
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

### Sixth session: 400 Days (2026-10-09 evening)

River Street retest (Episode 4, from dev_saves\ep4_riverstreet):
- Walk danger stop (#17) false alarm: the sound agent "Zombie_wall_vocals_near_water" counted as a
  walker. Walkers must now have a head bone (AgentHasNode(agent, "head")). Fixed and tested.
- The telescope: the stranger is only seen when the view is turned fully left
  (env_savannahRiverStreet.lua: cs_telescopeLooksFarLeft once reticleCamH's "NavCam - Animation
  Time" is under 0.1; the telescope camera turns with the reticle held at a screen edge). No
  hotspot marks it, so a player could not know. lookaround.lua SCENE_VIEWS adds a Tab entry "Far
  left" for camera cam_panningTelescope; choosing it holds the reticle at the left edge until the
  view stops ("Far left, 22 of 22. Turning."), and actions.lua stays quiet meanwhile
  (TWDA.turningView). Tested twice.
- Countdowns (#19): timer_zombieGroupClosesIn reads "Timer Length" 0 yet fills at about 0.0346 a
  second (about 29 s in all, paused between steps). countdown() now measures the fill rate per
  run when the length is 0 and waits a moment (under 0.2 s) before announcing so the time comes
  with it. Checked offline with lupa against the logged numbers ("about 30 seconds", then "about
  25"); NOT yet heard in the game (the sewers had saved over the alley checkpoint). Heard in the
  game on 2026-10-10 03:07 (River Street replayed from dev_saves\ep4_riverstreet): "Hurry: about
  30 seconds. Dumpster: Push. Enter!", the same for Manhole: Open and Climbing Pick, then "about 25
  seconds" for Manhole: Pry (the timer stands still during the short scenes between steps). #19
  is closed. Slot 2 is now at the start of the sewers again.
- Also seen: "N meters to go." during a walk (#14) works; "The walk to X was cut short ... Enter
  walks on." works; use.ps1 now presses Enter on that.

400 Days (Season 1's episode screen, "Special Episode: 400 Days"; slot 2; "Generate story
decisions for skipped episodes?" Yes, then Play again). It starts at ChapterSelection.lua, a
board with five photos read as "Vince: Choose. Wyatt: Choose. ... Tab to choose, Enter."
Engine facts found:
- Game_GetPlayer() is AgentFind("Lee") (wdgame.lua) and returns nothing in 400 Days. New
  TWDA.player() (core.lua) falls back to navigate.lua's upvalue mPlayer (Russell, Bonnie, Shel);
  TWDA.playerScene() and TWDA.playerName() too. Every module now uses them (walks, distances,
  the countdown scan, runto, cover, sniper, turnchoice). Spoken "Lee ..." texts use the name.
- Speakers' agent names run together are split ("TinyCarlos" -> "Tiny Carlos").
- People the game labels alike are told apart by their own agent names (lookaround.lua
  distinctName): Vince's choice on the bus offered "Prisoner" twice (agents Dan and Justin).
- choices.lua logs "choices: ended"; play_by_ear.ps1 -Answer uses it to find a waiting choice.
Vince (prison bus): done. Choices, a struggle, "Shotgun: Grab", "Prisoner: Shoot", the window,
the walkers; the end choice (Danny's foot) worked by ear.
Wyatt (night drive with Eddie): done. In the car, after the light, "Floorboard" appeared below
the view and was not announced (gap: new things out of view in look-around scenes are not
announced until the view turns); Floorboard: Search, Seat Handle: Pull, Keys: Grab, a struggle,
Door: Close, Car: Start, then "Attacker: Punch" (obj_armNate) must be hit several times: the
"Again! Enter!" cue now also covers blows and shots at a part of someone (isBlow in
lookaround.lua), then Gear Shift: Move. Passed by ear.
Russell (Nate, the truck stop): done. The shootout: "Window: Shoot" must be repeated ("DON'T stop
shooting!") and the game never refreshes the icons, so a frame check says "Again! Enter!" when
the same blow or shot target is still in the reticle a second after its use. Passed by ear.
Then "Check through the window": with subtitles read as names only, nothing said so; actions.lua
now announces, when walking control comes back, a hotspot a line named in the last 20 s
("Window: Look Through. Enter to do it."). Then Nate: Talk To. A mouse-only gesture ("Press and
hold the left mouse button, then push the mouse forward ... sneak up quietly, or quickly to jump
out") went unanswered and the scene went on after about 18 s; made accessible later (Up arrow,
fastslow.lua; see "400 Days replayed").
Bonnie (the woods, the cornfield): done.
- The run in the woods (Chapter4A_Forest.lua): "Run!" gives about 4 s of free walking. The goal is
  trigger_dialog_bonnieShot (27 m, toward and past the camera; she is shot at), then, with no
  hint, trigger_dialog_bonnieFalls (28 m back the other way) before trigger_dialog_bonnieDies,
  which MOVES with the pursuers at about 2.6 m/s. runto.lua now takes a sequence of spots (the
  first switched on: "Trigger Enabled"), says "Run!" again when walking comes back after a short
  scene, works keys out through the scene camera from Lee's position and a point a meter toward
  the target (projecting a target behind the camera mirrored it), and silences other walking
  announcements meanwhile (TWDA.runtoActive). Passed by ear (the very first direction was still
  wrong before the last change; the final version is untested).
- The cornfield (Chapter4B_Cornfield.lua): Bonnie stays put and the field moves round her.
  Pursuers come down her row; the game's Cornfield.imap binds A, D, Left, Right (rows) and S,
  Down (look back). Keys only sometimes reached it. cornfield.lua: hooks
  Chapter4B_Cornfield_PursuerPanicMeter_Activate/Deactivate: "Someone is coming down this row!
  Left or Right arrow to change rows." and "Out of the way." (not when caught: the meter goes off
  then too); forwards the keys to the game's handlers when the game has not reacted (guard: the
  handlers' upvalue mStealthPositionChangeActive). The scene script's own debug prints can be
  read: tools\dev\watch_cornfield.lua redirects its local consolePrint into twda.log (CP lines).
  Passed by ear (three pursuers). Then the rebar: Enter on "Rebar: Pull Out" opens
  mode_drag_rebarchoice.imap for about 1.7 s (Left/Right: Chapter4B_Cornfield_RebarDragStart_On*);
  the mod says "Grab it: Left or Right arrow, quickly." and forwards those keys too.
- Drags (new drag.lua, the game's mode_drag.lua): with the cursor a drag lasts only while the
  left mouse button is held (OnActivate pops it otherwise). The controller way takes arrows and
  A/D/W/S while button A is held, and then stays. Just during mode_drag.OnActivate the mod makes
  Input_UseCursor return false and Input_IsButtonPressed(kEventCodeButtonA) true, then says "Hold
  Left arrow to pull." from logic_mode_drag's "Drag - Direction" (1 up, 2 down, 3 left, 4 right).
  The rebar came free by ear ("Hold Left arrow", "Hold Right arrow"), then "Pursuer: Attack.
  Enter!" (Dee), Bonnie's last choices.
Shel (Chapter5A_TruckStopInterior.lua, then Chapter5B_TruckStop.lua, Chapter6B_Camp.lua): done.
- The diner, kitchen and back hall are one scene split by doors that move Shel when used, silently:
  the Kitchen Doors (diner <-> kitchen) and the Pantry Door (the one with the EXIT sign: kitchen
  <-> back hall). A logic value (key symbol 13818146074159135818) says which room: 2 diner, 1
  kitchen, 3 back hall. The Alley Door's use dialog only lets her out when it is 3; from the
  kitchen an invisible "blocker_alley" covers the door, yet the mod's "out of view from here, but
  Shel can still use Alley Door" used it anyway and got only "Oh, crap! I told Roman I'd see what
  she got a hold of!". Now: a target with a blocker_* agent at its marker gets "X can't be used
  from this side. Close by: <way out>" instead (blockerInFront, nearestWayOut in lookaround.lua;
  tested: "Alley Door can't be used from this side. Close by: Pantry Door, 2 meters."). And a door
  used with Main_OnUse that moves the player more than 1.5 m within 6 s (no movement key, no
  walk) is announced: "Through Kitchen Doors." (tested on both doors). How it was found: tools are the dialog walk (DlgFindNode, DlgNodeGetNextNode,
  DlgNodeGetChildNodes, DlgGetVisibilityConditions(...).rule, RuleTestCondition) and flipping
  each logic value briefly to see which one the rule follows (scratch flip.lua; worth a dev tool).
- Out back: Roman, choices, "Jean: Look At" (the walker eating a puppy), back in, the intruder
  (kill or let go), the card game ("Seven: Choose"), weeks later Roman ("Just come see me": he
  is not selectable; walking to the Truck next to him starts it), the RV with Becca: Drawer:
  Open, then "Keys: Grab" or "Pistol: Grab", then "Drive away" (read as "Away: Drive" before a
  fix: nouns that are adverbs are now read "verb noun") or "Stephanie: Kill".
- Tavia (Chapter6B_Camp.lua): choices, then the statistics, then a new screen "who went"
  (ui_whowent.lua, mouse only): prompts.lua reads "Left with Tavia: Bonnie, Shel, Vince, Wyatt.
  Stayed at the camp: Russell. Enter to continue." from PlayWhoWentChores' upvalue whosGoing and
  Enter calls UI_WhoWent_OnLeftClick. Tested. Then the credits and Season 1's menu.
400 Days done by ear (dev_saves\400done; saves.txt line Chapter6B_Camp.lua).

Dev tools added: watch_timers.lua (TM lines), watch_input.lua (WI), watch_corn.lua (WC2),
watch_cornfield.lua (CF and CP), watch_maps.lua (WM: input maps and their bindings).
play_by_ear.ps1 learnt the cornfield, the rebar grab and drags, and holds runto's keys while
following its corrections; game_input.ps1's KeyState now sets the extended flag for arrows.

### Season 2's menus (sixth session, 2026-10-10 about 01:30 to 03:00)

Reached from the hub with tools\dev\to_season.ps1 -Season 2 (Menu_Seasons, Right, Enter; about 30
s). Season 2 loads a new Lua state (SubProject_ResetEngine(MenuSeason2)), so changed mod files
are picked up by going back to the hub and in again: to_season.ps1 -Season 2 -FromSeason2 (from
Season 2's main menu: Definitive Menu, Accept, wait for the hub). No restart needed for any module.
Copy the built file from build\mod\TWDAccess to <game>\TWDAccess first (build with the .venv
python: tools\build_mod.py needs lupa).

How Season 2's menus work (projectseason2's uiz*.lua, button.lua, popup.lua):
- UIZ_GetActiveMenu() returns the active menu's root agent: ui_menu_main, ui_menu_settings (Help
  & Options), ui_menu_av, ui_menu_gameplay, ui_menu_graphics, ui_menu_controls, ui_menu_credits,
  ui_coverflow_saveSlots, ui_popup_reference. Menus left behind stay shown underneath.
- Rows are children of the root (or one level down) named ui_list_button_reference_N,
  ui_list_slider_reference_N, ui_list_toggle_reference_N, ui_navHelp_button_reference_N (Apply).
  The selectable agent has no text; its label is a sibling (ui_list_button_label_N), shown in
  capitals. A shown ui_list_button_lock_N means locked (My Choices). The title is the root's child
  ui_header_reference_N's ui_header_N (the reference itself reads hidden). The main menu has none.
- Nothing is selected when a menu comes up; the first arrow selects. button.imap handles arrows
  and Enter, backbutton.imap Escape and Backspace (BackButton_OnEscape). Sliders and toggles
  change with Left/Right (uiz_Setting.imap). A slider's value is in the menu's registeredWidgets
  entry (isSlider, value, minVal, maxVal; matched by agent name); a toggle's on
  ui_list_toggle_var_N.
- Popups (Popup(headerNode, messageNode, ...)) are UIZ menus of their own; their texts are
  ui_popup_header*, ui_popup_message*, ui_popup_button_label_N.
- Leaving Audio/Video, Gameplay or Graphics after changing anything asks "Settings Changed ...
  Save these changes?" with Restore and Apply. The agent changed values only to test and always
  chose Restore.

What menus.lua does now (all heard in the game):
- On a new active menu, once its text is the same twice 0.3 s apart (rows are added over several
  frames): "Help & Options menu, 5 items. Up and down arrows to choose, Enter to select". The save
  carousel says "Left and right arrows to choose". A screen with no rows (Controls is a picture
  of the keys) says "Controls. Nothing to choose here, only a picture. Escape goes back" after 2
  s; a menu gone back to can show no rows for a while, so one read as empty is read again when
  rows appear (Help & Options after Controls).
- Rows: "Play", "My Choices, locked", "Display Subtitles, Off", "Music Volume, 60 percent",
  "Resolution, 1920x1080", "Apply"; a save file reads its label and the texts under it ("Empty" or
  its date). Value changes are said as they happen ("On", "50 percent").
- Popups are read whole: header, message, buttons, then "Up and down arrows to choose, Enter to
  confirm".
Menus checked: main menu (Play, My Choices, Save Files, Help & Options, Definitive Menu, Exit
Game), Save Files (three empty), Help & Options (Controls, Audio/Video, Gameplay: Display Style,
Graphics: Texture Quality, Antialiasing, Full Screen, Resolution; Credits: Episodes 1 to 5), the
Settings Changed popup. Not checked: Play (it would start a game), the credits themselves.
Watch out: Season 1's Save Slots look similar; the agent once ended up there with the user's
"Game 1" highlighted and left with Backspace. Loading Season 2's menu writes
_wd2_saveSlot1_id.estore (93 bytes) in the save folder: not a save game.

### Season 2 during play (seventh session, 2026-10-10/11)

Starting a game: Season 2's main menu, Save Files, pick save file 2 (Enter sets the active file;
SaveLoad_GetSlot() says "wd2_saveslot2.bundle"), then Play: Chapter Select (a carousel of episode
dioramas, menu_chapters.lua; Enter plays the centre one, "Continue" when there is a save). A new
game first imports a Season 1 save ("Import Season 1 Save": search, "Save File Found", then
"Select a Season 1 Save File"; slot 2's Game 2 was imported). Scene changes use LoadScript (the
carry-over works unchanged); a death reload starts a new Lua state ("loading a save"), and
SaveLoad_RestoreCheckpoint() replays the scene's opening WITHOUT resetting item states (do not use
it; reload through the pause menu, Main Menu, Play, Continue instead). Season 2 keeps one
_wd2_saveslot2_checkpointN.bundle per chapter.

The framework (projectseason2's scripts; Game_GetMode() returns a table with name and bPlayMode;
modes Navigate, Cutscene, Dialog, CloseUp, Drag, Struggle, Action, "Dialog Box" for the death
screen). What each mod module does there:
- choices2.lua: gamedialog.lua's Dialog_OnChoicesAvailable (the engine calls a stored reference,
  so wrapping the global sees nothing; the mod wraps its upvalues SetChoices and ActivateChoice,
  which are gamedialog's shared locals). mMappedChoices (slot -> choice with "Choice Display Text"
  or "First Line"; mDefaultChoice is "...") and mChoices (the slots' agents) are upvalues of
  SetChoices, not of Dialog_OnChoicesAvailable. The "Dialog" input map has only clicks and
  controller buttons, so the mod takes 1-4, Up/Down and Enter and calls Dialog_ActivateChoice(slot)
  in a thread. Timed choices: the timer bar's controller (upvalue mTimerController) has its time
  scale held at 0 (heard: waited 28 s).
- lookaround2.lua: ReticleSelection_GetUsables() (usable agents with a dot), names from
  Game_GetNounText, verbs from ReticleVerbs_BuildVerbData(agent) + ReticleVerbs_GetAvailableVerbs()
  ({ Text, Direction "South"/"East"/..., Icon }; rebuilt for the reticle's mInterfaceAgent after).
  Use = Reticle_SelectAgent, ReticleSelection_Lock(true), ReticleVerbs_SetActiveVerb(verb),
  Navigate_PathToAndUseAgent(agent) in a thread (it walks there and calls Game_UseAgent; it gives up
  silently when its path-finding fails, e.g. while Clementine leans on the kitchen door listening:
  the mod then says "Can't get to X from here"). Tab/Shift+Tab, number keys for verbs, Enter, F6.
  Announces what is on offer when control comes back ("Clementine can move" only where
  Navigate.imap walks), "X again? Enter." for blows and other repeatable actions (re-checked 1.5 s
  after each use, because some blows never leave play mode), fight targets ("Throw rock at zombie
  1, and 5 more. Enter for the nearest"; auto mode uses them). Places to walk to: enabled
  walk-in story triggers (trigger_* with "Trigger Enabled", not cam/chore/death ones), put on the
  walk boxes with WalkBoxesPosOnWalkBoxes(pos, PathAgentGetWalkBoxes(player)); Enter walks there
  with AgentPathToPosition first, then steers with DirectControl_SetJoystickDirection (screen
  direction through the scene camera) with detours, stopping on arrival, a scene, a movement key,
  or when blocked. Engine path-finding (AgentPathToAgent/Position) fails for most trigger spots;
  steering works. Some triggers are for other characters ("Dog finds zombie") and never fire for
  the player.
- drag2.lua: drag.lua's Drag_Enter ends at once unless upvalue mbDragButtonActive is set (the
  mouse button held from the click); the mod sets it, makes Input_UseCursor false during
  Drag_Activate, and keeps drag.imap on (it is switched off when the reticle hides). Arrows/WASD
  then drag (Drag_OnButtonRight...). Directions from logic_drag's "Drag - Direction X Chore"
  (chore handles, not strings). Used for the lighter flick and the stitches (Right arrow).
- action2.lua: action.lua's dodges and blows: Action_GetActiveActions() agents with "Move Right
  Enabled"/"Attack Up Enabled" and a "... Dialog"; action.imap takes arrows/WASD for moves and
  Enter for attacks (Action_OnEnterKey). Says "Right arrow!", "Enter!"; auto presses; slow mode
  runs the game at 0.45 while action agents are active.
- struggle.lua now also does Season 2 (Struggle_Enter, struggle.imap: Q or Enter mash, E
  finishes). Mashing from PowerShell was too slow to win (the meter drops to 25% after a gap);
  auto mode wins them.
- peek.lua: Season 2's Peek mode (logic_peek, "Peek" input map): "Choose: Left arrow towards
  Nick, Right arrow towards Pete" on choice cameras (cam_choice_peteOrNick); the person on each
  side is found from screen positions (the left one was missed once).
- guided.lua: ChoredMovement_IsActive in Season 2 (crawling under the porch).
- prompts2.lua: death screen (Death_ShowUI; Enter calls Death_OnButtonA), inventory ("Got
  hammer", "No more needle"; F6 "Carrying: ..." from Inventory_Activate's mContainer). Many "No
  more" lines come together when a scene takes the items (back in the shed); could be merged.
- menus.lua: carousels (CoverFlow_GetCenterPanel; the save files, Chapter Select, the end of
  episode "My Choices" whose rows are ui_coverflow_stat_{category,name,description}N_M), screens
  with their own message (Import Season 1 Save). Single-button screens need Down before Enter
  (nothing is selected until an arrow is pressed). Not done: the pause menu has no title
  ("Pause menu"), Season 2 credits text for F6.
Dev tools added: tree.lua, scenetext.lua, coverflow.lua, globs (scratch), globals_by_file.lua,
dumpup.lua (DUMPUP = "Fn": dump a function's upvalue functions), imap.lua (IMAP = "name"),
watch_s2.lua (WS2 lines: calls to Season 2 gameplay globals; the mod's own polling of
Action_GetActiveActions and ChoredMovement_IsActive floods it, filter them), watch_s2_all.lua,
watch_struggle2.lua, usables2.lua, selectables2.lua, triggers2.lua, inv2.lua, run.ps1 (run Lua,
print new twda.log lines), onsay.ps1 (press keys when the mod says something; "+Q" mashes),
use2.ps1 (Tab to a named thing, action number, Enter), retry_watch.ps1 (Enter on the death screen,
then start a watcher in the new state).
Episode 1 walkthrough notes (what the game wants): bathroom stalls, faucet, bottle; campfire:
backpack photo, drawing, lighter, Campfire: Look At, Lighter: Flick (Right arrow drag), Campfire:
Light, Log: Pick Up, Campfire: Add Fuel To, burn the log; scavengers: rock, swing at hand, branch,
kick (repeat), bite, struggles, dodges (arrows), throw rock at walkers; river shore: stairs; trail
(places), dog, camp: trash barrel (can), walker tied to the tree (branch, smash x4), knife, lid x3,
dog fight (punch, kick); Luke and Pete; shed: table, hammer (shelf falls; lift it), board (pry),
panel (kick), hole; cabin: plywood, nails x2, crawl (guided W), trap door (knife), listen at the
kitchen door until free, upstairs: Sarah (bedroom door 2), pinky swear, medicine cabinet (needle),
rags; downstairs closet door, Exit; shed: peroxide, needle thread (twice), suture with Right arrow
four times, rags; walker: kick, struggle, brick x3, rake, hammer, hit (repeat); river: bodies,
water choice; Pete or Nick (lean right for Pete), board, walker attack (twice).

### Season 2 during play: more engine facts (ninth session, 2026-10-12)

- Struggles (buttonmash.lua, ButtonMash_DoTheMash and its local MonitorThread): each press adds
  1 x "Button Mash - Rate of Increase" (4) x a constant (about 0.01) to "Button Mash - Current
  Percentage"; a 25 Hz monitor drains "Rate of Decay" (0.333) x 0.04 on every tick without a press.
  About 6.5 presses a second only holds the meter; 8 or more wins. Mashing stops while
  SceneGetTimeScale is 0.
- Guided paths (choredmovement.lua): ChoredMovement_SetJoystickDirection(joyVec) sets upvalue
  mMove to +1 or -1 by comparing the stick (camera right x, forward y) with the move agent's
  forward vector, 0 when centred; it is called from Navigate's key events only, so a key held from
  before does nothing (guided.lua now passes it on). ChoredMovement_GetTimePercent is 0 to 1; a
  long path (the chairlift ladder) moves about 3% a second.
- Notices (notification.lua): Notification_ShowTutorial(node, delay, duration) and
  Notification_ShowChoice(node, delay, duration) go through the local ShowNotification, which
  sets kTextNode on kTextAgents[index] after the delay (index: upvalues kNotificationTutorial,
  kNotificationChoice); ShowChoice is skipped when the preference "Enable Reticle Hint Dots" is
  off. Scenes call them from their own scripts (HardwareStoreExterior_ShowShelfSqueezeHint).
- Inventory: Inventory_AddItem(name) shows icon ui_item_<name>; its label is node item_<name> of
  the dialog that agent ui_inventory_text reads ("Text Dialog 2.0 File", per episode).
- Close-ups: Game mode "CloseUp", CloseUp.imap: S (83), Down arrow (40) and right click call
  CloseUp_OnButtonExit.
- Navigate_PathToAndUseAgent(agent, bRun): bRun makes the player run (local SetRunning).
- Combat mode (Reticle_IsCombatMode) can last a whole scene (the snowstorm, Episode 5), with the
  walkers' heads hidden usables until each attacks.
- The death checkpoint usually lands a few seconds before the fight that killed Clementine; a
  fight that starts at once after a reload leaves little time to react.

### Season 2 walkthrough notes, Episodes 2 to 5 (ninth session; what the game wants)

One path, mostly answer 1. Episode 2 (A House Divided), from Carver's visit: the group talk, the
walk to Pete (guided W), the bridge approach (binoculars: Lodge, Lift, Bridge, Station House);
bridge: walker knee, head, hammer pull (struggle, then drags Left and Right), Luke stuck: dodge Up,
knee, head, struggle, dodge Left and Down, struggle, pipe, stab stomach, struggle, head; give Luke
the pipe or kill the walker; Matthew is shot; station house: Alvin and Rebecca, Nick, door window,
station house door, cans, trunk (examine, open; take the survival knife; pry open with the knife:
struggle), canned food, Alvin; lodge rear: the chairlift ladder (guided W, slow; a slip with a
choice; S down again), look at trees, bridge, light; Kenny; lodge: CD, CD player, Sarita and Sarah,
box: angel ornament, put it on Christmas tree 2, Ascend stairs (place) to Rebecca, Alvin; dinner
(sit with Kenny or Luke); Walter outside, Bonnie; Luke, the knife; Walter; the wind turbine:
control panel: lighter, key, switch: unlock; hiding behind a stump: lean right (D), Cover: Run To,
dodges Down twice, shoot six walkers, struggle (rifle), then shoot the walker's head within about
3 s, grab the rifle, shoot; Carver arrives: behind the chair lean up, dodges, choices; the end.
Episode 3 (In Harm's Way): the truck, Carver's compound yard (talk to everyone; Kenny's plan),
morning speech, the garden with Bonnie, Sarah, Reggie; the yard walkers: clobber twice, dodge
Left, "Hold A to escape!" squeeze between the shelves (hold A), struggle, sledgehammer: pulverize,
dodge Down, power cable (an unwinnable struggle), Troy; place "Grabbed": Luke; roof: Hank and
Tavia, skylight 2: Enter, guided path (W), pallets down, walkie-talkies: run to, grab, drag Up;
Mike: jump to; the comic shop; Carver's punishment of Kenny; Carver's office: Alvin, external
speakers, volume knob, CD receiver, compact disc; Carver: Jump On; the escape in walker guts:
walker kill, dead walker open, entrails, smear guts on Clementine and Sarah, guided W through
the herd, chop the walker, dodge Right, then the next walker's head (Chop) within about 5 s,
struggle, Sarita's arm (hack off) or the walker; the end.
Episode 4 (Amid the Ruins): walker arm hack, dodges, struggle; Rebecca and Jane; Gap: Walk To;
skinny walker (Jane: distract it); "Don't fall behind!" guided W (about 7 s to start); the
truck stop: dead walkers' pockets 1 to 3 (bullets), Sarah's glasses, the walkers by the pickup
truck: lean right, stab and search the walker, pickup truck: move to, walkers: attack (knee,
head), dead walker: look at, choose "Let's put him on the horn" (struggle), the three walker
targets, mobile home door: kick down (twice), struggle, Luke and Sarah, fridge/furniture/milk
crate (the fridge will not budge), struggles, convince or leave Sarah; Kenny's tent: open (drag
Right); the observation deck: Rebecca (give pills), the museum: Civil War coat, souvenirs, box:
move (Clementine stands on it under the shutter), shutter: open (struggle), raccoon, hiding place;
the deck: telescopes, Arvo (hide, lean up: caught), pain killers, keep or return the bag, Jane;
deck again: Kenny, Sarah, Mike and Bonnie: follow; walkers: shoot four, cannon: push (struggle),
grab Sarah's hand (struggle), destroy the deck (support pin: hack three times), the baby, Jane's
nail file, Luke and Kenny, the Russians, shoot Rebecca or call for help; the end.
Episode 5 (No Going Back): "Push the W key to crawl forward" (hold W), baby: grab, cover, Luke:
cover; shoot the walker; the cold walk and talks; Kenny's eye: bandage remove (drag Up), rag wet
(drag Down), wound clean (twice), bandage; the night watch: Arvo, Kenny (offer rum or talk), Jane
(offer rum), transformer, fence, sign; the lake: guided W, then help or cover Luke ("Get to
Luke!" guided W), struggle, punch the ice (twice), kick the walker (three times); the truck: key
turn (drag Up), turn it again (drag Up); house 1; the stash house; the night with Mike, Bonnie and
Arvo (threaten or give the gun); the dream of Lee; the truck in the snow: gas pedal, dodge Left,
shoot the walker, truck: exit; the snowstorm: walk to "Rest stop entrance" (115 m; walkers
appear one at a time, shoot each), rest stop: enter; Kenny and Jane: Kenny's knee or arm, Jane:
push, dodge Up, Jane or Kenny: stop, Jane: push, pistol: grab, shoot Kenny or look away; the
ending with Jane or alone.

### A New Frontier (tenth session, 2026-10-24)

Reached from the hub with to_season.ps1 -Season 3 (SubProject_ResetEngine(MenuSeason3), first
script MenuBoot.lua, then Menu_Main.lua). Episodes are GarciaDominguezHouse.lua, VirginiaRoad.lua,
Junkyard.lua, JunkyardHill.lua, ... (scene changes by LoadScript, carried over as before). Saves are
wd3_saveslotN (Save 1 to 4 in Settings > Save Files; Enter on one makes it the active file, "checked").
Starting: Episodes > "Choose how to begin your story": Start New Story or Continue Your Story >
Import Save N (from Season 2's same-numbered file) or Recreate; a summary of the imported story;
Start Story; then the Episodes carousel (Start/Continue/Restart Episode N).

Framework (projectseason3 scripts; globals listed in <game>\TWDAccess\globals_s3gas.txt):
- Menus are the hub's widget framework (Menu_Create/Menu_Show, Button, Carousel, Legend_Add), so
  menus.lua works with the fixes above. The pause menu (Escape) has Resume Game, Settings, Main
  Menu (popup: Cancel/OK), Exit Game; there is no "restart checkpoint": Main Menu, Episodes,
  Continue reloads the last checkpoint.
- The PC version has keyboard bindings for nearly everything (dump with a script like the one in
  "Engine facts", InputMapperGetInput): QuickTimeEvent.imap (arrows/WASD QTE_KeyLeft..., Q, E,
  Enter QTE_EnterKey, mouse), MultiQTE.imap (arrows, Shift, Q, E, Enter), Struggle.imap (Q mash, E
  finish, arrows, Enter), Drag.imap (Enter hold, arrows), Peek.imap, Navigate.imap (Shift runs),
  Dialog.imap (Enter, arrows; choices2's 1-4 still work), Death.imap (Enter), Station.imap (right
  click, "5"), Reticle.imap (Enter does nothing on PC: Reticle_OnEnterKey only works on Xfinity).
  Input-map callbacks are held by reference: wrapping the global (WidgetInputHandler_OnKeyRight,
  Drag_OnButtonDown) catches nothing; functions called by name from Lua (QTE_UI_ShowPrompt,
  Drag_OnHoldPress) can be hooked.
- QTEs (quicktimeevent.lua): QTE_SetActivated(true/false) around a prompt (not always), then
  QTE_UI_ShowPrompt(qteAgent, action) with action "a"/"b"/"x"/"y"/"left"/.../"q"/"e"/"holda"...,
  QTE_UI_ShowSuccess/ShowFailure. The local ExecuteAction(action, bForceSuccess, bAltKeyboardKey)
  (upvalue of QTE_KeyE) matches the action against each QTE agent's promptsCurrent (upvalue
  mQuickTimeEventAgents); with "QTE - UI Enable Alt Keyboard Keys", "a"/"b" need E and "x"/"y" Q.
  A prompt can be an agent name: a thing to click with the reticle in combat mode.
  Windows are short: 1.1 to 2.6 s.
- MultiQTE_Enable(agent, true/false): prompts from "QTE Prompt - 1".., upvalues mMultiQTE_Table and
  mCurrentMultiQTEIndex of MultiQTE_OnE, local OnInput(prompt); "QTE - Type" Rapid or
  Simultaneous.
- StruggleQTE_Enter(agent): "Struggle - Type" (Button, Waggle Horizontal/Vertical, Circle
  Clockwise/Counter Clockwise), "Struggle - Current Percentage" 0 to 1 (at 0.9 it jumps to 1.01 and
  mDeathBlowReadyStart is set: E), "Struggle - Enabled" false at the end; StruggleQTE_Exit.
  DoTheMash adds about Rate of Increase (3) x a frame-time factor per press.
- Drags (drag.lua): Drag_GetActiveAgent(); upvalues mActiveAgent (its mProps[kDirUpEnabled] etc.,
  "Drag - Direction Up Enabled"...), mbHoldingButton, mPressedCode; Drag_OnHoldPress({code=13,
  type=0}, true) then Drag_OnButtonDown({type=0}) repeatedly completes a pull.
- Stations (station.lua): Game mode "Station" (close-ups of doors, drawers, panels);
  Station_AllowExit() is a query; Station_OnButtonExit(event) backs out.
- Death: Death_ShowUI, Death_OnButtonPress (Enter is bound by the game).
- Guided paths: ChoredMovement_GetController() returns the path's controller (ControllerGetTime /
  ControllerGetLength give progress); ChoredMovement_IsActive.
- Reticle hotspots as Season 2 but ReticleSelection_GetUseables; Navigate_PathToAndUseAgent(agent)
  has one parameter.
- The episode statistics: menu agent ui_stats_reference, upvalues of Menu_Stats_TransitionToPage:
  mVisibleWidget, mCurrentPageIndex, mStatPages[mCurrentEpisode]. They load under the credits, so
  page 1 is read just before "Credits. F6 reads them, Escape goes back"; Escape skips the credits.

Walkthrough notes (one path, mostly answer 1; what the game wants):
- Episode 1 (Ties That Bind, Part One): the family house talk; the drive; the gas station
  (Junkyard.lua): walker attacks (Enter prompts), siphon cars (Car 2, Truck: Siphon; Enter pumps),
  Ladder: Climb (choose Climb), gas cap: Open, Pry (drag Down), gas tank: Siphon (E pumps, alt
  keys), Scrap Heap, walk on (the story spot was named "Zombie attack": a QTE), trailer: plank:
  Move, Hole: Enter (guided W), Hatch: Open, inside: Drawer, then Max at the door: open the
  Trailer Door within about 15 s or he shoots (picking up batteries first gets stuck); Lonnie:
  [Grab Crowbar], Left arrow, struggle (fast); Clementine; the gate fight (targets); the Prescott
  bar (look at everything, Card Players: Talk To); Eli struggle (can be lost, the story goes on);
  flashback with AJ: two walker targets, "Rock: Enter!", E prompts; the gate: Pick Hammer, Muerto:
  Kill, Cassette Player; the end ([Leave With Family]).
- Episode 2 (Part Two): the airport (Prescott): look at things, Conrad, Tripp, Front Gate: Exit;
  New Frontier at the gate: E, Muerto targets, Q, Right, "Raider male" target; Kate: Give Water
  to; the street: talk to everyone, Garage Door: Open (Right, then E), Wrecked Car: Push, Wrench,
  Winch (close-up: Winch Release: Use Wrench On, Winch Motor: Connect, Winch Hook: Connect); the
  underpass: Left, Muerto, Q, "E, 3 times, fast!", Up; Conrad's hand target, struggle; guided W
  over the wall and a Right prompt; Jesus; flashback (Ava, AJ): struggle at the door; Max's
  checkpoint ([Keep your guns]); the end.
- Episode 3 (Above the Law): opening struggle and E/Q prompts; Richmond talks; dinner (cake); the
  lookout: New Richmond, Colony, Building, constellations (Constellation 1 is the Big Dipper;
  answering on was enough); flashback: Vial (Vancomycin: Take), Syringe: Take, hold Enter to fill;
  the factory: Roll-Up Door: Lift (struggle), Car Door: Open (Left, then E three times), a Down
  arrow crawl under the door within about 2 s after "Javi, go!"; crates; transformer: Throw Rock
  At; the end.
- Episode 4 (Thicker than Water): quarantine room: Pipe: Grab (struggle), Stool: Grab (struggle),
  door; the medical room (Lingard: Talk To); AJ's things; the guided drag of the body needs S, not
  W; the construction site: look at things, Garage Door: Open, Wire Cutters: Grab, a walker
  (Enter), the dark close-up "Ear"/"Panel" (Enter on Panel), then hot-wiring: Battery, Ignition,
  Starter Wire: Cut (Down arrow each), Power Ignition: Use; the execution ([Save Tripp]); the end.
- Episode 5 (From the Gallows): dominoes (Deuce-Five: Play); talks; the helicopter: look at
  things, Chopper Blade: Grab; the warehouse: zombie head and tummy targets, Left, Guts: Use; the
  herd: walk to "Reach generator" (9 to 15 m) keeping clear of walkers, a few E prompts; the gate
  panel: Button 1 opens it; the bulldozer: "E, 3 times", Q, Q, E, "Q, 5 times", "Shift and E
  together"; Kate's path; the end and the season summary (14 pages).

### The Final Season (twelfth session, 2026-10-25)

Reached from the hub with to_season.ps1 -Season 4 (MenuBoot.lua, then Menu_Main.lua; the hub's
widget menus, so menus.lua mostly works). Saves are wd4_saveslotN (Settings > Save files: Save 1 to
4; Enter makes one active, "checked"). The agent uses Save 2; the user's Save 1 is untouched.
Starting: Episodes > "Import Save?" (Yes) > "Search for Choice Data or Local Save": two buttons side
by side, LEFT and RIGHT arrows ("Check for Choice Data" on the left opens a Telltale account
sign-in screen: answer "Not now"; "Import Local Save" on the right) > "Walking Dead: A New Frontier
Local Import" list (Save 2, "5 Episodes Completed") > "Import Successful" > OK. Then the story recap
(Configurator.lua), then Episode 1 (RoadTile.lua: the car; TrainStation.lua; BoardingSchoolDorm.lua;
BoardingSchoolExterior.lua; BoardingSchoolInterior.lua ...).

Framework (projectseason4 scripts; globals in <game>\TWDAccess\globals_state.txt, globals_s4menu.txt,
globals_s4config.txt). New script files: ai_player.lua, ai_agent.lua, useable.lua, crosshair.lua,
reticlewd.lua, reticleselectionwd.lua, navigatewd.lua, directcontrolwd.lua, dialogchoices.lua,
configurator.lua, qte_util.lua, shooter.lua, orbitcam.lua, triggerwd.lua, inventorywd.lua.
Most locals that matter are not reachable from globals; tools\dev\findsrc-style searches (walk
_G, global tables and debug.getregistry, dump by line) found them (see "Developer tooling").
- The story recap (configurator.lua): Configurator.imap has NO keyboard keys on PC (clicks and the
  D-pad, and its own Left/Right handlers ignore the D-pad once the mouse was used). New
  configurator.lua in the mod: on Configurator_ChoiceEnableInput(targetList, stringList) it says
  "Which is right: Lee saved Doug, or Lee saved Carley? Left and right arrows to choose, Enter to
  confirm." (captions are the texts of ui_configurator_button1..3), Left/Right call
  Configurator_SelectButtonByIndex, 1-3 pick and confirm, Enter calls Configurator_OnA (in a thread);
  a single target ("Click to Continue") says "Enter to continue.". menus.lua reads the caption on
  each Select, but not one selected under the resting mouse or while no question is open.
- Dialog choices: dialogchoices.lua has the same SetChoices/ActivateChoice upvalues as Season 2, so
  choices2.lua works unchanged ("choices: attached to Season 2's dialog"). The layout puts "Say
  nothing" first in reading order.
- Things to use (useable.lua): every agent with the "useable" property set that is "Game
  Selectable" and visible is in the local mCurrentUseables (an upvalue of Useable_GetCount; added
  and removed by property callbacks, so it is the whole scene's set, not only what is near). The
  game picks one each frame (UpdateUseables: in Navigate mode the closest to the screen centre
  within "Useable - Max Distance"/the scene default and on screen; in a station the agent at the
  screen centre) into mSelectedUseable and shows its token "Give Magazine" with F. F, Enter and a
  left click (Useable.imap) run Useable_OnButtonUse: Navigate_PathToAndUseAgent(agent,
  Game_GetUseNodeName(agent)), which WALKS her there from anywhere in the scene (30 m to the water
  fountain worked) and uses it. A token's words: verb = Dialog_GetText(scene dialog, "Useable - Verb
  Node") or Dialog_GetText("ui_text", node), or, with no verb node, "Useable - Verb Preset" ("Grab",
  "Pick Up", "Look At"; the game shows "verb_grab"); noun = Game_GetNounText(agent).
  Input maps hold callbacks by name, resolved when the map is ACTIVATED: wrapping
  Useable_OnButtonUse works for maps activated after the wrap (every new state: main.lua wraps it
  first), but a module re-included from the dev console does not get the real Enter key until the
  map is activated again. F worked where Enter did not, once.
- Stations (station.lua; Game mode "Station": AJ's seat, the car trunk, the scrapbook, the closet):
  Station.imap backs out with the right mouse button only; Station_OnButtonExit({}) does it when
  Station_AllowExit() (a query) is true. A guided path (chored movement) does not move while a
  station is open.
- Guided paths: ChoredMovement_SetJoystickDirection(Vector(0, 1, 0)) moves one (tested); the WASD
  icon shows the key. W works on the chair push in the dorm once the close-up is closed.
- Walkers (ai_player.lua): see combat4.lua below. Death traps: some story triggers kill at once
  ("trigger_dialog_caughtByTrappedZombie", 0.9 by 0.4 m beside the walker pinned under a train car
  at the station: Trigger_OnEnterDialog then Death()). Trigger boxes: AgentLocalToWorld(trigger,
  AgentGetProperty(trigger, kExtentsMin/kExtentsMax)) gives the corners; many story triggers are
  thin lines across the way ("trigger_dialog_ajWarning" is 5 m by 0.4 m) that must be crossed.
- Struggles (struggleqte.lua, as A New Frontier: Struggle.imap Q mash, E death blow, arrows):
  StruggleQTE_Enter(agent) sets one up WITHOUT "Struggle - Enabled"; StruggleQTE_Begin starts it a
  moment later (both seen for the walker grab, struggle_zombie, about 6.5 s long, then Death()).
- QTEs: QTE_UI_ShowPrompt as A New Frontier (qte3.lua works); prompts that are things to click
  ("obj_logicalAction" at the train station, after the tutorial notice) are NOT in the agents'
  promptsCurrent (the ExecuteAction upvalue mQuickTimeEventAgents is empty): QTE_GetQuickTimeAgents()
  returns the QTE agents, whose "QTE Prompt - 1", "- 2"... hold them. Multi-prompt QTEs
  (MultiQTE_Enable) as A New Frontier ("Press Shift and E together!" worked).
- Notices (notification.lua): one text agent for every kind, "ui_notification_text" (upvalue
  kTextAgent of ShowTextNotification, an upvalue of Notification_ShowTutorial); kinds Tutorial,
  Choice, Objective ("FIND AJ"), Branch, Inventory ("You have: PALETTE KNIFE Sharp enough."),
  Relationship, Gift.
- Subtitles: examine lines in TFS often have no Subtitle_OnCreate (no "subtitle" log line), so in
  "speaker" mode nothing is said for them; the voice is heard. (Not looked into yet.)

### The Final Season, Episodes 1 and 2 (thirteenth session, 2026-10-25/26)

Played: Episode 1 from the school (river fishing, rabbits, ForestShack, ForestTile, the train station
at night, the cellar and Brody, the end: stats) and Episode 2 from the funeral to the raid (vote,
woods with AJ, Abel, James, buckshot, plans, greenhouse, dorm, dream, preparations, bow practice,
stargazing with Violet, lookout, the raid, Abel in the hall, Lilly). Scene scripts: ForestShack,
ForestTile, TrainStationNight, BoardingSchoolExteriorNight, BoardingSchoolDormNight,
BoardingSchoolBasement, then BoardingSchoolDorm, BoardingSchoolExterior, ForestTile, ForestCamp,
BoardingSchoolExteriorGate, BoardingSchoolInterior, GreenHouse, BoardingSchoolDormNight,
BoardingSchoolExteriorDusk, BellTower, BoardingSchoolExteriorGateNight, BoardingSchoolExteriorNight,
BoardingSchoolInteriorNight, BoardingSchoolExteriorDamaged.
- Carry-over and the scene name: see the first item. Game_GetCurrentScript's upvalues kLogicAgent and
  kScriptCurrent; acts in LogicGet(kAct); LogicSet of a key the logic lacks does nothing.
- Shooter stations (shooter.lua: fishing, rabbits, and Ep 2's cam_station_saveFriend shot at Sullene):
  shooter4.lua. The station camera's kTargetDialogMap names the targets; Enter fires at the one in
  view nearest the middle through the hit dialog (the same dialogs the game runs); targets coming into
  view are said ("Sullene in view. Enter!"). lookaround4 leaves Enter alone while one is up.
- Sneaking at the train station: peek (Season 2's peek.lua again; logic agent logic_systems, "Peek -
  Dialog Down/Center"...). Leaning out (S) is required: doing nothing gets her killed after ~40 s.
  In Episode 2 (woods, hiding from Abel) leaning out (A, hold it) turns into a station with "Look At
  Stranger"; Enter there goes to Peek_OnSelect (runs "Peek - Selected Dialog", empty): lookaround4
  now hooks Peek_OnSelect and uses the offered thing. peek.lua no longer says "Back in cover" when
  the peek ends in a station.
- Slow motion stuck on: TrainStationNight loads ui_panicmeter.scene (no agents, never hidden), which
  actions.lua took for Season 1's panic meter: the whole scene ran at 0.45 and walks "gave up".
  actions.lua skips the panic meter check in TFS (Useable_GetCount exists).
- Walks: from right beside the hiding crate the steering (DirectControl_SetJoystickDirection) did not
  move her until a movement key was pressed once (not understood; noted). Walking to a story spot whose
  trigger fires with nothing after it left no announcement: lookaround4 now counts the places in its
  change check when nothing is on offer.
- Choices: react4's "E now" rule matched "tell me now!" (case-insensitive -match): fixed with
  (?-i)\bE now. "[Kill her]" (Lilly, raid) and "AJ, shoot!" (Abel, train station) are game overs:
  Death() a second after the choice (the latter maybe because of missing "Entered" keys; unknown).
- Struggles: "Too late" was said when E landed: the game ends the ready state in the same frame it
  takes the E. struggle.lua counts E pressed within 0.6 s before the ready state ended as made.
- QTE click targets in turn (Lilly at the end of the raid: obj_logicalAction01, then 02): the current
  one is the prompt agent the game made kGameSelectable; qte3 picks that, and none between two. A key
  prompt up wins over a target (zombie Brody: "Left arrow!" was talked over by "Action: Enter!").
- Guided paths (choredmovement.lua): the key is not always W and the game shows it only as a red key
  on its WASD picture. GetRelativeDirection (upvalue of OnPostUpdate, under ChoredMovement_Start's
  Activate) gives 1 for the key that moves on, from the camera; the move agent's "Chored Movement -
  Reverse Controls" turns it round (dragging Omar in the raid wants A, not D). guided.lua says "Hold
  A to go on", again when it changes with the camera (held half a second, not in a cut scene), and
  "D does not move her here. Hold A". Buckshot from AJ's arm: "HOLD W A S D in the direction of the
  arrow" (A each time). A path can also stop at a stop key until the right key is pressed.
- Walker fights (combat4.lua): a walker put down stays the player's "Interaction Current Target", so
  every later walker went unannounced: targetOf ignores walkers whose "AI Agent - AI Agent Enable" is
  off. Aim: ExecuteInteraction takes "AI Player - Interaction Current Target Override" first and does
  not check the angle (the target picker wants 45 degrees), so Q and E (hooked AI_Player_Q/E) go for
  the walker in reach (2.5 m) that can still be shoved, else the game's target, else the nearest; the
  override is cleared after 2.5 s. Groups ("Walkers are dangerous in groups. Use E to break them
  up"): a second walker joining a grab is death without a struggle. "Walker, and 1 more close! Q to
  attack, E to shove!" when another walker that can still be shoved is within 5.5 m; an early key is
  then not done for the player; the keys are said again when they change (a shoved walker offers
  only Q); others coming while one is in reach are said ("Another walker, 3 meters, to your left.").
  No warnings in stations. People met like walkers (James) by name. Kill takes about 4.5 s; a shove
  stuns about 9 s. The woods fight (Episode 2) was won with shove/kill this way.
- The bow (from Louis, Episode 2; ai_player.lua): right mouse held = AI_Player_RM_Down/Up ("AI Player -
  Scrub Chore Desired Percent" 1/0; drawn: "Interaction Ranged Enable"), left click = AI_Player_L:
  runs the player's node bg_rangedProjectile (GetNode), an arrow from the camera; hits run
  bg_hitTarget (practice) or bg_projectileHit then logic_onAgentDeath/logic_targetDead. Mouse only.
  bow4.lua: R draws and puts away; drawn, it turns the camera onto the nearest target (hit boxes
  "ai_hitBox_*", walkers' heads at +1.55 m) through the helper's /mouse (relative moves, steps of 20
  px every 8 ms: one large jump is mostly swallowed), says "Walker, 4 meters. Turning to it." and
  "On target. Enter shoots." (once per target), Enter shoots (hooked Useable_OnButtonUse; a click is
  left to the game), Tab/Shift+Tab next target; re-draws a second after the game lowers it (a grab)
  until R; with nothing left it takes the next walker that comes. Bow practice: two hits end it
  (logic_doneShooting); it is required (the scene waits). Burning walkers can only be shot.
- Stargazing (constellation.lua, bell tower with Violet): stars are buttons ui_star_<name>Button<n>
  whose command is Constellation_ActivateStar(n); kGameSelectable marks the ones that can be linked
  next; the scene goes on when all lines are drawn (fish 6 stars, knife 11, bird 15). stars4.lua: Tab
  picks a linkable star ("Star 2, down and to the left, 1 of 2" from the last one), Enter links it
  (Enter is Useable_OnButtonUse here).
- Notices: their text has lines ("You have: ", "RULER", "", "Thin enough."): prompts2 joins them as
  sentences out of capitals ("You have: Ruler. Thin enough."). Glyphs "<ui_notification_keyboard
  AndMouseWasd.d3dtx>" are "W A S D" (text.lua: the part after "keyboardAndMouse").
- End of episode (menu_stats.lua, ui_stats_reference): TFS pages are pieces named after the page
  (_headerText "You and", _massiveText "39%", _secondaryHeaderText, _bodyText01.., _text01..; the
  summary page ui_stats_episode1: HeaderText, Text01..; relationships ui_stats_relativeStatPage_1_<Name>;
  "The State of the School" lineup; collectibles). menus.lua reads them in that order and puts the
  game's "15%left" and "PRAGMATIC" right. The Continue button (mCallToActionButton of
  Menu_Stats_UpdateActionButtons) is cursor-only: Enter executes it. Then the main menu and Episodes
  (Episode 2 "Start" needs the focus to land on Start first: wait, then Enter).
- Labels: "Walls01, fortify the Walls" is now "Fortify the Walls" (a verb phrase naming the thing).
- Seen, not fixed: "Candle, go to Sleep" label; "You practiced shooting with Louis" said twice;
  lookaround4 answers a left click with "Nothing to interact with here" while aiming; "Bow in hand"
  is said at every scene start while the bow is carried; struggle.lua's "Halfway" in non-fight
  struggles; "Place: Jump scare zombie" and similar trigger names are spoilers; the burning-school
  fight not yet won.

### The Final Season, Episodes 2 to 4 (fourteenth session, 2026-10-26/27)

Scenes: BoardingSchoolExteriorDamaged (end of Episode 2), then Episode 3: PreviouslyOn,
BoardingSchoolExteriorBasement (Abel), RiverShoreline (spying: places and stations give "INTEL"
notices), ForestCamp (James; "Using only E to stun walkers will satisfy James' request"), ForestBarn,
BoardingSchoolDorm (place the collectibles), BoardingSchoolInterior (the party), TrainTile (Lee,
"Clementine Flashback" is the game's speaker name), RiverShorelineNight (herd, dock, pier), RiverBoat;
Episode 4: the sinking boat, RiverShorelineNight again (the shore), the cave (torch), CliffBridge,
ForestBarn (stuck, see the first item).
- Episodes screen (TFS): it opens with the focus on the episode's own button, where Enter does
  nothing; the game moves it to "Start/Continue Episode N" only after Up or Down. menus.lua now
  selects ui_menuEpisodes_startButton (Clone_Find(menu.agent, "_startButton"):Select(true)) once the
  game has selected the episode (doing it at 0.8 s was undone by the game's own selection). Tested.
- Mouse pointer: the bow's /mouse moves leave the pointer anywhere; on Season Select it rested on the
  left arrow and Enter went to A New Frontier instead of playing The Final Season. Moving it away
  (/mouse?dx=400&dy=300 a few times) fixed it. Not fixed in the mod.
- The bow (bow4.lua): it re-drew itself at the end of Episode 2 over the statistics ("Bow drawn.
  Nothing to shoot at" said over them, and F6 described the bow). Now it re-draws only with
  something to shoot, no menu up, and no walker within 6 m that Q or E can fight (the pier fight is
  hand to hand). Enter with the bow up but "Interaction Ranged Enable" off for over 1.5 s, or with
  nothing to aim at and something the game offers (mSelectedUseable), goes to the game: "Use Guts"
  at the river was blocked by "Still drawing.".
- Useable labels (lookaround4.lua): Abel's cigarette offers verb nodes with no noun ("Let Him Smoke",
  "Burn Him", "Stub Out Cigarette"): said alone (the game shows them so); "Useable - Type" Choice
  adds ", choice"; the tutorial "When you see <ui_notification_iconUseable_updated.d3dtx>, consider
  the consequences" says "a thing marked choice" (text.lua). Verbs ending in a preposition go before
  the noun ("Smear Guts On Louis").
- Hiding behind walkers (river at night, Episode 3): see combat4.lua's comment. Every herd walker
  offers prompt 2 "x"/cs_hideBehindZombie; the game takes the target override at 7 m and brings
  her there (station "cam_station_hideBehindZombie"). bg_flashlightTimer, then
  RiverShorelineNight_EnableFlashlightTracking(true) about 6 s later, death 4 s after that unless
  hidden; the raiders shoot her walker (logic_onAgentDeath), bg_stationHideBehindZombieExit, next
  light 6 s later; five rounds, then cs_flashlightOnClemFinal. Said: "The light is on you! Q to hide
  behind a walker!", "Hiding behind a walker.", "Out in the open. Q to hide behind another
  walker!". Played through with Q on those.
- The dock (same scene): trigger_dialog_dockStealth01 and 02 are thin lines across the dock,
  enabled while the searchlight is on them (3 to 6 s at a time); crossing one while it is off is
  safe (tested by walking across each while dark). Added after the barn stopped play: new
  searchlight4.lua says the next line's light ("Crossing ahead, 3 meters. Crossing ahead is dark.
  Go!", "Light on the crossing ahead. Wait.", "Past the last crossing.") and F6 starts with it. It
  loads without errors but was NOT heard at the dock (Episode 3 is behind the save). Places "Dock
  stealth 01/02" walk a meter past each line. trigger_dialog_bg_flashlightOnClem..03 were never
  enabled.
- The pier fight: walkers in groups; a kill (4.5 s) lets the next grab her; shove first, then kill a
  stunned one (quick). GROUP_METERS 7.5. Won with "E on more close, Q on alone".
- The boat: the password (Abel: "Only one we use these days is Rockingham") was answered wrong by
  the test reactor (choice 2), which led to a knock-out fight (E). The Armando ambush is a QTE whose
  "QTE Prompt - 1" is "obj_logicalArmandoKnee,obj_logicalArmandoHead": two targets at once, a
  choice. qte3.lua splits prompts on commas: "Armando's knee, or Armando's head. Tab to choose,
  Enter does Armando's knee!" (worked; Tab switches). (Also: in TFS mQuickTimeEventAgents is keyed
  by scene; ExecuteAction iterates mQuickTimeEventAgents[mGameScene].)
- Struggles: struggle_minnie and struggle_climb end their ready state within 40 ms of E and then
  the struggle, won; "Too late" is now said only if the struggle is still on 1.2 s later. Several
  story struggles are lost by design ("won false": struggle_lilly, getBackUp, backFoulBeast).
- The shore at the start of Episode 4 (no knife, "You cannot fight the herd", objective Escape):
  trigger_dialog_clemKilledZombieWall is a box that sweeps in at about 0.6 m/s and follows her path;
  inside it, death. Walkers ZombieCombat01..07 stand between her and trigger_dialog_getOffMe
  (19 m south), where cs_getOffMe (the bite) moves the story on. Done in auto mode: Tab to "Get off
  me", Enter, the walk resumes after each shove (7 shoves). Normal mode needs E within about half a
  second for each; the reactor was too slow. Tab's list used to start with "Zombat latecomer" and
  every walker ("walk up to it"); both left out now. Auto mode's shove the moment the first walker
  came in reach broke the scene (no objective, no getOffMe): auto now waits 0.5 s.
- Mod walks call navigatewd.lua's SetRunning (upvalue of Navigate_OnButtonRun; it returns at once if
  "Player - Run Speed" is 0) while a walker is within 12 m. A test steering 1.5 s each way showed
  1.5 m walking vs 1.7 m with it: not clearly faster. Unconfirmed.
- The barn (Episode 4): "Move Wheelbarrow" is a guided push that only goes forward with W, pauses
  at 50% when W is let go, and plays cs_holdDoor at 100% (checked with ChoredMovement percent);
  amb_closeDoorTimer (about 15 s) restarts when the wheelbarrow is used and kills her if the push is
  not finished. lookaround4.lua says "Hurry!" when a "...Timer" scene dialog starts. The loop came
  from using stall door 3 as Clementine without stepping off trigger_dialog_clementimeOut: solved
  in the fifteenth session (first item).
- Other: objectives are said as "Objective: X"; place names drop "bg_"/"cs_" ("Creaky bridge");
  "Gun p250" is "gun"; "obj_logicalZombieHead1" is "walker head 1"; the mouse-only tutorial "Hold
  mouse Right Click to leave cover, then press mouse Left Click to fire" (the bridge, Minerva) is
  followed by "Bow in hand: R draws it" (not checked whether a shot was needed; the scene went on).
- Test tools: react4.ps1 -NoEarlyQ (no Q on "Walker, 6 meters"), -Extra rules now come first (so
  they can override); chord.ps1 knows Shift; watch_river4.lua (WR lines: position, attachment,
  flashlight, mode, Death/Game_RunDialog/AgentAttach calls; copy to autorun.lua), watch_dock4.lua
  (WD: the dock lines), watch_herd4.lua (WH: every trigger's box), watch_herdwalkers4.lua (WW: AI
  walkers when an objective comes). Write autorun.lua WITHOUT a byte-order mark
  ([IO.File]::WriteAllText with UTF8Encoding($false)): PowerShell's Set-Content -Encoding UTF8 adds
  one and the console reports "unexpected symbol near char(239)". Delete autorun.lua before the user
  plays.

### Michonne (seventeenth session, 2026-10-28/29)

Reached from the hub with to_season.ps1 -Season 5 (SubProject_ResetEngine(MenuSeasonM), MenuBoot.lua,
then Menu_Main.lua; -FromSeason3 also works from its main menu). Main menu: Play, Save Files, Your
Choices (locked at first), Settings, Definitive Menu, Exit Game. Save Files is a 2 by 2 grid
(ui_popupSave_grid, nCols 2, its buttons in widgets of its own); Enter makes a file current
("checked"). Play opens the Episodes screen (menu_episodeselect.lua, menu agent ui_episodeSelect):
one button, ui_episodeSelect_episodeStatus "START EPISODE 1", the episode's name drawn as a picture,
Left/Right slide (Menu_EpisodeSelect_SlideComplete). Episodes: 1 In Too Deep (ShoreLineCove.lua,
DockChesapeakeBay.lua, FerryExteriorDeck.lua, FerryInterior.lua, BoatTownApproach.lua, Flagship...),
2 Give No Shelter (PreviouslyOn.lua, FlagshipInteriorEscape..., ShorelineApproachWoods.lua,
JohnsHouseWoodsTile.lua, JohnsHouseExteriorLawn.lua...), 3 What We Deserve.

Framework: projectseasonm's scripts are Season 2's engine (reticle.lua, ReticleSelection_GetUseables,
gamedialog: choices2.lua works, Struggle_Enter, quicktimeevent.lua, peek.lua, station.lua, drag.lua
with Drag_OnHoldPress like A New Frontier, choredmovement.lua like The Final Season's) plus
deadlyfocus.lua (not met yet) and swipe.lua. Globals: <game>\TWDAccess\globals_smplay.txt,
globals_smboat.txt. Fixed or added this session (all tested in the game unless marked):
- menus.lua: the save grid is counted ("Save Files menu, 4 items. A grid, 2 across: arrow keys
  move"); a check mark agent's own text ("check Mark Current Save") is not read; the Episodes
  screen says "Episodes. Episode 2: Give No Shelter. Start Episode 2. Left and right arrows choose
  an episode, Enter plays it" (names hard-coded) and selects the button (after the mouse was used
  it is left unselected and Enter did nothing); the end-of-episode Your Choices screen
  (ui_stats_reference without Menu_Stats_TransitionToPage: ui_stats_episodeN_statM_question and
  _label) is read whole once its rows stop arriving (0.8 s), "... Down arrow, then Enter to
  continue" after an episode (Continue is selected only after an arrow) or "Escape goes back" from
  the main menu's Your Choices, where Left/Right switch episode tabs ("Episode 2", then that
  episode's list). A selected row reads question then answer (not heard yet: the row widget's name
  ui_stats_episodeN_statM is a guess). Restart Episode N asks "Restarting the Episode will cause all
  data past the selected Episode to be lost" (Cancel/OK). Credits (F6) end with a stray "empty".
- lookaround2.lua: Michonne's UI.imap opens the pause menu on Backspace (UI_OnButtonMenu, code 8);
  the wrapper drops code 8 and an active UI.imap is switched off and on (input maps take callbacks
  when activated). Backspace in free walk no longer opens the menu (tested).
  Walking to use is sometimes off for her (Navigate_IsAgentPathingEnabled false: the ferry's deck
  door, the apartment bedroom door): then, if the game has not used the thing within 0.6 s and
  no walk runs, Game_UseAgent(agent) where she stands (tested on the replay: "walking is off; using
  obj_logical_door from here", the door opened). Michonne's navigate.lua (dumped:
  dumps\up\m_PathToAndUseAgent.luac) uses the thing after AgentPathToAgent only if the walk
  reports arriving, the thing is still selectable and its input map is on; otherwise it stops
  silently (3 m from Paige with the ammo, Episode 3). A walk that ends within 4 m without a use
  now uses it too (Michonne only, isSeason2Michonne; not yet met again after the change).
  On a guided path with nothing usable in view, things out of view count (the snack bar walker:
  "Kill Walker", then the rope: "Cut Down"; both off screen while the sneak path waits).
  In a close-up (Station), a selectable thing with no actions off screen is "Something to look at:
  turn the view to it" (to your right...): Enter holds the pointer at that screen edge
  (ReticleCameraControl pans) until it is in view (the storeroom's obj_logical_sawGhostKidsTrigger;
  tested on the replay: the scene went on 0.07 s after Enter). Drag spots with no actions
  (Drag_IsDragAgent) are listed "X: take hold, then drag" and Enter calls TWDA.pickDrag (drag3.lua:
  Drag_SelectAgent, kept selected until the drag is over); drag3 then says "Drag: hold Left
  arrow." (bandaging Sam; tested by hand with the same calls, the mod's Enter not yet).
  Names: "obj_Logical_dinghy" is "Dinghy", a word that is someone in the scene keeps its capital
  ("Gag Jonas"), the same agent listed twice is listed once, "Look At." loses its full stop.
- qte3.lua: prompts shown by ShowNextPrompt without QTE_UI_ShowPrompt are found by polling the QTE
  agents (actionPromptShown, promptsCurrent, actionActivateTime); multi-prompt QTEs ("E, then Q,
  then E!", the ferry fight) are said as MultiQTE_Enable starts, from the agent's "QTE Prompt - N"
  (the call takes 0.65 s to return; values are not always Lua strings: tostring). Tested on the
  replay: said 0.66 s sooner, not repeated, the fight won first time (it had killed Michonne twice
  before, the test tool being too slow for three keys in about 1.6 s).
- struggle.lua: waggle and circle struggles (Swipe_StartWaggle/Circle after Struggle_Enter): only
  the mouse moves the meter (the chain's mProgressCallback = Struggle_OnSwipe, about 7% a stroke);
  the mod counts arrow strokes the right way and calls it ("Struggle! Press Left and Right arrows in
  turn, over and over."; the meter is "Button Mash - Current Percentage"). Tested by keys on the
  replay (sharpening the machete: Halfway in 0.6 s, "E now!" at 3 s, won). Michonne's tip "Move
  Mouse Quickly from Side to Side." now waits until after the mod's line.
- guided.lua: Michonne's GetRelativeDirection is found through ChoredMovement_Activate's
  mRefCounterActivate.mCallback (OnPostUpdate): "Hold S to go on", then "Hold D to go on" after a
  camera cut (the run through the woods, Episode 2; tested, passed). "W does not move Michonne
  here. Try S, A or D" names all keys.
- prompts2.lua: Michonne's inventory (Inventory_InitItem(logicKey, texture, text) names items,
  Inventory_HasItem) - "Got rebar" (heard twice with the dev watcher on: double hooks); F6
  "Carrying". Tips no longer cut off choices or urgent prompts said in the last 2 s
  (TWDA.choicesSaidAt, TWDA.urgentAt from qte3, drag3, struggle): "Silence is always a valid
  option..." had cut the first choice list off.
- New michonne.lua: the boat radio's dials (Episode 1): a tone rising with the dial every 5% and
  "All the way left/right" at the ends; F6 gives the percent ("Radio dial, 80 percent of the way
  round. Hold A or D to turn it"); "The radio dial is in tune. Now the squelch dial." when it lets
  go by itself (added after the replay's radio: not heard). Tested on the replay: the percent and
  "All the way right. A turns it back."; the tones go out from the same code (tone requests are
  not logged anywhere). The radio dial stops by itself in tune about the middle (chore time 2.65
  of 5); the squelch must go well down (1.6 of 6; once it was in tune at once), then Samantha
  comes through.
- Seen, not fixed: "Kill Walker Walker, walking there." (verb plus noun); a tip can still cut off a
  "Michonne can move ..." list; "Michonne can move. Nothing to interact with here" is said a second
  before some fight prompts (combat mode between prompts); the Save Files menu's "Page Down:
  RENAME" sticks to the main menu after it closes (seen in The Final Season too); Main menu's
  title count is missing the first time ("Main menu" then later "Main menu, 6 items").
Walkthrough notes (one path, answer 1): Episode 1: bush swipes (Left, Right), the dock fight;
pull the trigger choice; Pete's boat: radio (turn the Radio Dial until it stops, then the Squelch
Dial down), binoculars at the Prow: Ferry; sharpen the machete (waggle struggle); the ferry: Ladder:
Climb Ladder (guided W; slips once), Raft Locker: Open (Piece of Metal = rebar), Door: Open (locked),
Door: Use Rebar, struggle; upstairs bodies; the sneak path (Kill Walker, Cut Down, then D opens the
snack bar door); snack bar (Duffel, put things in it, Locker: Open); the fight ("E, then Q, then E"
fast); the boat town: storeroom (look at everything, Chompy..., then turn the view right); Norma's
questions; Greg: lean right (D) to the Broken Mirror: Cut Zipties (vertical waggle), screwdriver,
stab twice within about 4 s each; Your Choices. Episode 2: gag Jonas; the escape; the woods run
(S, then D); bandage Sam (drag Left); the medkit (vodka, pliers, aspirator, wound drags Up then
Left); the apartment flashback (look at things, Bedroom: Open Door, Decision time); John's house;
hiding from Randall's men (lean left, Attack); the flare and arm-lock struggles and prompts; the
radio talk with Norma (a drag); [Kill him]; Your Choices. Episode 3: the crew talk; James: Talk
To; John's house: Pete: Give Gun, Stairs, the door upstairs (Alex), Paige: Give Ammo, Stairs, talk
to Sam; the negotiation on the lawn (struggles), the house fire (struggles), the daughters
([Leave your daughters]), Sam's hand: Grab; the epilogue; Your Choices. No deaths in Episode 3.

### 400 Days replayed (sixth session, 2026-10-10 about 03:15 to 05:20)

After the River Street retest, 400 Days was replayed in slot 2 to test the open items (from
slot 2 at Episode 4, then again from dev_saves\ep5done: Season 1's episode screen, Special
Episode: 400 Days, Play; Bonnie first). Results:
- Bonnie's run in the woods (runto.lua): passed by ear three times. The first keys still flip
  within 3 s ("Run! Hold Shift and W", "W and D", "S"), unexplained, but each time she got there.
  The reticle passing over people ("Dee: Yell To") cut the keys off; lookaround.lua's speakFocus
  is now silent during a run unless the player Tabbed (TWDA.runtoActive).
- The cornfield, worked out with tools\dev\watch_pursuers.lua (PU lines: each pursuer as meters
  ahead and to the left of Bonnie, AgentGetForwardVec): Bonnie stays put and the field slides a
  row, 2.25 m, per change. Pursuers ("Pursuer1".."6", "CelebrityPursuer1".."6") walk down rows at
  about 1.7 m/s from 28 m; idle ones are parked 31.5 m behind. Each has a panic box
  (trigger_PanicMeter_pursuerN: 0.6 m wide, 29 m long; enter dialog trigger_pursuerN_panicOn,
  exit dialog trigger_pursuer_panicOff) and a kill box (trigger_pursuerN, 5 m, cs_cornfieldDie).
  The panic meter fills by distance to its pursuer whatever the row, and goes off only through
  that exit dialog. The spawn table (kPursuerSpawnOffsets) has HeadOn, HeadOnInLeftRow,
  HeadOnInRightRow, FromLeft(Close), FromRight(Close): a second pursuer can come down the next row.
  Changes in cornfield.lua:
  - The warning names the safe side from the pursuers' places: "Someone is coming down this row!
    Right arrow. Someone is in the row to the left." (also "in both rows; that one is further
    off"); plain "Left or Right arrow to change rows" when both are clear. The game's arrows on
    screen always show both, so they say nothing.
  - The exit dialog was sometimes missed (four times in a row, always the first pursuer after a
    load): Bonnie a row away, meter still on, dead 20 to 30 s later. 0.6 s after a row change, if
    the meter is still on and nobody is in her row, the mod calls the game's own
    Chapter4B_Cornfield_PursuerPanicMeter_Deactivate (logged "meter still on with nobody in
    Bonnie's row; switching it off"); if someone is, "Still in someone's row! <key>."
    Tested: fired on the first pursuer, then the whole field passed by ear.
  - The end: after a set time cornEnd() waits until Bonnie has run far enough along her path
    (ChoredMovement time target) and nothing says so (a test sat there for minutes). The mod now
    says "Nobody is coming now. Hold W to run out of the field." when mCornEndFired turns on.
  - guided.lua stays quiet during the stealth run (TWDA.cornfieldRunning: the scene's
    mSequenceActive); it had said "Guided path. Hold W or S" over the cornfield's own intro.
  - Each warning logs every pursuer's place ("cornfield: pursuers Pursuer1 23.9,2.3"), and the
    Activate hook logs which pursuer, for the user's own logs.
- Russell's sneak at the farmhouse (Chapter3C_TruckStopInterior.lua, after Window: Look Through
  and Nate: Talk To): the game's mode_fastSlow, mode_fastSlow.imap with only the mouse button
  (OnMouseLeft) and the left stick (OnLeftStick); its arrow-key handlers work only on Xfinity.
  UpdateJoystickDir: a push the mode's way (logic agent property kDirection, Input_GetJoystickDir
  numbering) with VectorDot(dir, dir) under 0.5 plays the slow dialog and, once that has played
  with the stick still pushed, pops the mode; 0.5 or more plays the fast dialog and pops at once.
  The mode lasts about 12 s, then the scene goes on by itself. New fastslow.lua: while the map is
  active it says "Sneak up quietly: hold Up arrow until it is done. Or Shift and Up arrow to jump
  out." and, while that key is held, calls mode_fastSlow.OnLeftStick with half (slow) or full
  (fast, with Shift) tilt; F6 says it too. Tested slow: "fastslow: pushing slow", and the scene
  went on 11 s after the prompt instead of 18 (Nate: "DON'T FUCKING MOVE!!"). Fast, from
  dev_saves\auto\Chapter3C_TruckStopInterior: "fastslow: pushing fast", and Jean screamed 4 s
  later (the jump-out scene). Both ways work.
- guided.lua: a movement key already held when a path starts moves nothing (the game moves on key
  presses), and the mod said "W does not move Russell here. Try S" (Russell running to the truck,
  with W still down from walking; S did nothing either). It now says "Let go of W, then hold it
  again" in that case. Not yet heard in the game.
- actions.lua: against the clock, something only to look at is no longer announced as a thing
  to do ("Hurry ... Chain: Look At. Enter!" after the chain was pulled and shot on Vince's bus).
  Not yet heard in the game.
- Number keys pick an action and Enter does it (by design; the agent once pressed only the
  number and nothing happened).
- Vince and Russell were replayed by ear without trouble otherwise (Russell's truck stop shootout:
  "Hurry: about 2 seconds. Window: Shoot. Enter!" and "Again! Enter!" over and over, as designed).
Slot 2 now: Russell's farmhouse after the sneak (loaded from dev_saves\auto\Chapter3C_TruckStopInterior;
Bonnie and Vince done; saves.txt: Chapter3C_TruckStopInterior.lua). Dev saves: dev_saves\400_russell (Russell's start,
Chapter3A_Road.lua, Bonnie and Vince done), and dev_saves\auto\ from the new snapshot script:
Chapter3B_TruckStop, Chapter3C_TruckStopInterior (Russell's farmhouse, just before the sneak),
Chapter4A_Forest (Bonnie's start), Chapter4B_Cornfield (the cornfield start); each folder name plus
".lua" is the saves.txt script.
Dev tools: watch_pursuers.lua; snapshot_scenes.ps1 (run in the background; copies slot 2 into
dev_saves\auto\<scene> at each scene-start save; it holds twda.log open, so restart.ps1 cannot
rename the log to twda.prev.log while it runs); holdkey.ps1 takes Up, Down, Left, Right, Shift;
play_by_ear.ps1 knows "Still in someone's row!", "Hold W to run out of the field" and "Let go of
W, then hold it again". The dev console code sent right after a checkpoint load can be lost:
wait a second after the "bootstrap: running" line.

### Episode 4 notes (fifth session, 2026-10-09)

Started from dev_saves\ep3done (Season 1 menu, slot 2, Episode 4 "Play"; no missing-decisions
prompt this time).

- Opening (PreviouslyOn.lua, env_savannahStreets.lua): a long silent shot; the game only runs
  while focused. The bell, then "Hurry: about 8 seconds. Zombie: Shoot. Enter!", then the rifle
  scope (sniper.lua) at the walkers going for Clementine: "In sight! Enter!", "Hit!" six times.
- The house yard (env_manorExteriorDay.lua): Pet Door is locked (needs a dog's collar chip);
  Shovel: Pick Up ("Dirt Mound: Look At, Dig. Enter to do it."), Dirt Mound: 2 Dig, Carcass: 2
  Pick Up (the pet collar), Pet Door: Unlock ("House Door: Unlock" is announced too).
- Inside (env_manorInteriorHouseSearch.lua): open the three downstairs
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

- Crawford (env_crawfordExterior.lua, after the user closed SteelSeries GG and the game was
  restarted at 09:05): "Guard: Move To. Enter to do it." then "Guard: Chop. Enter!" (a walker);
  the classroom talk (Fuel?, Medicine? ...); Ben (choice 2); the hallways
  (env_crawfordSchoolHallways.lua): walking to the Exit to Alley leads straight out; the gray shed:
  Hole (Look At), Shelf: Climb (over the fence); Garage Door: Look At, Open ("jammed"); the
  Fence: Look At, then the Garage Door again brings Molly (a story timer, timer_enterMolly, no
  danger); a struggle raises the door. The auto shop (env_crawfordAutoShop.lua;
  dev_saves\ep4_motorshop): Truck Hood: Open, Hydraulic Hose: Look At, Pry, Molly: "Can I borrow
  your hook?", Hydraulic Hose: 3 Puncture; then the battery against the clock (Unscrew and
  Detach each terminal, Battery: Pick Up), "Semi Truck: Climb" (out of reach: "Tab to it, then
  Enter"), Skylight: 2 Shoot, Hand: Grab, the jump (Hand: Grab), Molly leaves with the battery.
  Back in the hallways: Vernon and Christa at the nurse's office door; the Classroom Door brings
  Kenny and Brie with the fuel: a struggle at the door, "Zombie: Shoot", "Hatchet: Pick Up", a
  struggle (dev_saves\ep4_classroom after). Out of the classroom toward Vernon: hiding behind
  the vending machine, lean W, "Zombie, 6 of them: Shoot", then the rifle scope (5 hits). The
  nurse's office (env_crawfordSchoolNursesOffice.lua): Medical File: 2 Pick Up (a video tape),
  Camcorder: 3 Watch tape #1; Exit to Alley, the white shed ("tv" is beside it): walking up sets
  off "Hurry: about 3 seconds. Shelf: Climb. Enter!" and a struggle; over the roof; "Zombie:
  Stomp" (the doctor), "Doctor's Corpse: 2 Search" (tape #2 and a paper slip with a code; Tab
  skipped the corpse once after a failed try, see Open problems); back in the nurse's office tape
  #2 plays and the safe is opened by the game (dev_saves\ep4_meds, after the medicine). The
  classroom: Molly drops in, the rifle scope (one hit saves her), Ben's confession, the vote.
- The stairs (the escape after the vote; checkpoint just before): "Use the S (back) key to get
  away!" (a guided path where W, not S, moves: the mod says "S does not move Lee here. Try W")
  and walkers 4 to 20 come one after another ("Zombie: Shoot ... Enter!"); keep backing up and
  shoot each before backing into it (cs_deathBackingUpStairs), and keep moving or the timer runs
  out (cs_deathBackingUpTimeOut). Then Lee's leg is stuck (a turn choice, Up/Down: "Select your
  leg to free it. Look up to fight off walkers."): look up at once, shoot, look down ("Leg: Pull,
  below you"), pull on each "Now! Enter!", look up again when "Zombie: Shoot, above you. Turn
  with the arrow keys" comes. Freed by ear in the end; then "stair zombie phase: Attack" several
  times, the roof, Ben hanging (choice 1 let him go in the test run), the house
  (env_cancerGroupHideoutEpilogue.lua), Vernon, Clementine, the morning after (Clementine's Hat,
  Walkie Talkie, "Zombie: Stomp", show the bite), the radio voice, the statistics and credits.
  Episode 4 done by ear (dev_saves\ep4done once copied).
- The game crashed once (a dump at 10:37:00, 16 GB free, so not memory) two seconds into a scene
  change during a loop where a test script kept going back and forth through the nurse's office
  door. The mod no longer offers a way through for the first 20 s of a scene.

### Episode 5 notes (fifth session, 2026-10-09 afternoon)

Played in slot 2 from dev_saves\ep4done ("Episode 5: No Time Left. Play"), all by ear with
play_by_ear.ps1 except where noted; finished at 14:01 (statistics read in full).

- The morgue: the middle Cabinet (obj_morgueCabinet2): Open, Rib Spreader: 2 Pick Up,
  Elevator: 4 Use Rib Spreader On, Rib Spreader: Crank; the arm (choice 1 cuts it off); the
  elevator-shaft ladder is a guided path ("Use the W key to climb").
- The hospital roof: the Ladder only offers Pick Up after talking to Omid (who stands in a peek
  station: "Hiding. To lean out: S down"; S steps back out of it); Ladder: Pick Up, the group
  talk places it, Ladder: 2 Climb ("Climb to the bell tower.", a guided path: hold W), Bell
  Tower: Jump To, Rope: Pull, the ledge: Jump To.
- The house siege: two struggles, "lone zombie: Shoot", walkers from the window, Rope: Pull. The
  attic: Bust: Grab (timed), Coat Rack: Grab, Wall: Break (was read "verb_break"). The
  neighbours' house: Balcony Door: Open, Balcony: Cross, a guided path. Above River Street: Pole:
  Grab, two struggles (Christa, then Kenny lost). The banner, then the cleaver gauntlet to the
  Marsh House ("Walker: Use Cleaver On" many times).
- The hotel: the Door 7 m ahead: 2 Open; the stranger's long talk (speaker "Campman", now said
  as "Stranger"); the fight: "Stranger: Tackle. Enter!", struggle, "Stranger: Grab", "Headbutt",
  struggle, "Stranger: Shoot"; the Door, "Walker: Shoot", Walker: 2 Chop, Walker: Scoop,
  Clementine: 2 Smear three times (after each smear she offers Talk To again).
- The herd (a guided path, hold W; the mod's "W does not move Lee here. Try S" was wrong there,
  W was right), the jewellery shop: struggles, Baseball Bat: Grab (Clementine smashes the Office
  Door), Chair: Use, Office Door: Open, Handcuffs: Grab, Lee: Handcuff (or the Walker), the gun
  and keys choice, "Display Stand: Use. Enter to do it." (timed), "Baseball Bat: 1 Look At, 2
  Grab, 3 Kick" (Kick when handcuffed; a first try timed out because the test script did not
  pick a number), the last choices, the statistics.
- After the statistics comes the season summary (ui_seasonStats.scene): a card per character,
  five to a page, two pages. It only took a mouse click (ui_seasonstats.imap binds 768, the left
  button, to SeasonStats_OnLeftClick), so a keyboard player was stuck; prompts.lua now reads
  each page ("Season summary. Kenny: You defended his son in the drugstore. ...  Enter to
  continue.") and Enter runs SeasonStats_OnLeftClick in a thread; F6 repeats it. Tested on both
  pages. Then the credits.
- dev_saves: ep5done (copied at Season 1's menu after the credits; its checkpoint is the last one of the
  ending, env_jewelryStore.lua, so saves.txt needs "wd1_saveslot2.bundle<TAB>env_jewelryStore.lua").

### Sewer retest (fifth session, 2026-10-09 about 14:15 to 14:55)

After Season 1 was done: dev_saves\ep4_sewers loaded into slot 2 (saves.txt line set to
env_savannahSewers.lua) to test the walk danger stop (#17). Played up to the upper tunnel after
the walker grab; slot 2 is left there (checkpoint at the leg grab). Found and fixed:

- Walks into walkers (#17): the panic vignette is on the whole time near the feeding group, so
  "vignette visible" stopped every walk at once. Now: the vignette only counts if it came up
  during the walk; and a walker (agent with zombie/walker in its name, no helper) that was 8 m or
  more away at the start and comes within 5 m, standing still, with Lee heading for it, stops
  the walk. Neither while the nearest walker is moving (chasing Lee: the run into the low passage
  when the sewer walkers come must not stop). Says "Danger! A walker 9 meters away, in view.
  Walk stopped short of Stairs." Tested: the walk to the far Stairs (the shortest way past the
  group, which killed Lee once in this test too) now stops; Lee survives.
- Walks stopped by the game (a remark when Lee comes close, a chore at the low passage) ended in
  silence. Now, once Lee can walk again: "The walk to X was cut short, 7 meters away. Enter walks
  on." And a walk where Lee stops moving for 4 s ends with the usual "got to N meters" message
  (untested: not seen in this run).
- After a walk the reticle can settle on the target while Lee is still walking, so nothing was
  said on arrival (the pried passage); now it is read out on arrival.
- Number keys: a number pressed for a just-announced hotspot only counted for 8 s, Enter for 15
  s; at the valve pipe, 2 pressed after 8 s and Enter turned it left (action 1). Both now use the
  same rule (stillPreferred).
- Enter with nothing chosen and one usable thing ("Pipe: Look At, Place Valve. Enter!" pressed
  late) looked at it; now it does its first action that is not looking.
- F6 on a hotspot with several actions now says "A number key to choose, then Enter".
- Names: "zombie arm" had become "zombie" (the walker-model rule); parts (arm, hand, head, leg,
  ...) are kept now. The tooltip's raw "zombieArm" is made readable.
- After a struggle, what is on offer is news again (actions.lua sceneoffers): the walker beyond
  the arm offered "1 Shoot, 2 Attack" before and after the struggle, was not announced after it,
  and Lee died. Now "Zombie: 1 Shoot, 2 Attack. Pick a number, then Enter!" comes 3 s after "E
  now!". Passed by ear (play_by_ear.ps1 -Prefer Pry,Attack -StartKey Enter).
- play_by_ear.ps1: on "Tab to choose" with a -Prefer word on offer, it Tabs until the focus reads
  that word out, then presses its number and Enter.
- The sewer stairs: the mod's walk to "Stairs" stops 2 m short of the top (trigger_dialog_
  stairsEntrance at x -5.9); S from there slides along the wall. D (toward the stair top), then S
  goes down. The slope after it is a guided path where D (not W) goes on, and the mod said so.

### Fifth session: more mod changes made during Episode 4

- carryover.lua: a backstop for the save hooks compares each slot's checkpoint file
  (_wd1_saveslotN_autosave.bundle under %USERPROFILE%\Documents\Telltale Games\The Walking
  Dead Definitive, read as the module loads) every 3 s and logs "savewatch: ... changed". The
  "missed save" that led to it was a misreading (see item I). recordSave logs "a save, but no
  slot known" when it cannot record.
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

Later changes (afternoon, Crawford; all tested by ear in the scenes named):
- turnchoice.lua: up and down turns are named "to look up"/"to look down"; up and down work (the
  game's side numbers 3 and 4 are used when the update thread does not hold them); an arrow
  pressed while the choice drops out for a moment (during an action) is kept for 4 s and used
  when it comes back; TWDA.turnChoiceSides() lists the ways Lee can turn now.
- lookaround.lua, turn choices: the reticle is kept within the game's turning bounds (half the
  "Choice - Reticle Move Width" from the centre; past that mode_choice's update thread turns
  Lee); something out of view on a side Lee can turn to is listed and, when chosen, "X is above
  you. Turn with the arrow keys first."; the "Now! Enter!" strike cue is held back while a threat
  (shoot, attack, hit...) waits on such a side.
- actions.lua, turn choices count as action scenes; new things on a turnable side come first
  with "Turn with the arrow keys"; things that come into view after a turn count as new; while a
  countdown runs and nothing has been said for 4 s, the mod repeats what can be done ("Leg: Pull.
  Enter!") or, if nothing this way, "Nothing to do this way. Turn: Down arrow to look down".
- lookaround.lua, fights: Enter goes for the nearest target (even when the reticle rests on a
  farther one), and does not switch to an announced target of the same kind.
- actions.lua: timers whose end node is a plain "logic_" step only count as countdowns when the
  name sounds like danger (zombie, death, attack, ...); "timer_enterMolly" did not need hurrying.
  Out-of-reach things in a countdown get "Tab to it, then Enter", and a walk started with Enter
  in an action scene does the action on arrival.
- actions.lua: in free walking the door just come through is not offered (nor, for 20 s of a new
  scene, any way through); the announced-action window is 15 s.
- carryover.lua: the save watcher compares the autosave file (see item I).
- Names: "video tape", "paper slip with a code".
- tools\dev\play_by_ear.ps1: -StickyHold, -Turn Named (press the arrow the line names), follows
  "Try W", "Turn with the arrow keys ... above you" and "Nothing to do this way. Turn: X arrow",
  answers "Tab to it, then Enter", and only reads the mod's own "say" lines.

Changes during Episode 5:
- actions.lua: announcements number the actions when a thing offers two or more things to do
  ("Baseball Bat: 1 Look At, 2 Grab, 3 Kick. A number key to choose, then Enter."); a newly
  offered "Talk To" is not announced as news.
- lookaround.lua: unresolved verb keys ("verb_break") read as words; names from use nodes are
  trimmed ("zombie , 3 of them"); walkers named after their model ("zombie large low slave a")
  read as "zombie"; hotspots marked unreachable count again once clickable (issue #20).
- subtitles.lua: SPEAKERS maps agent names to on-screen names (Campman -> Stranger).
- tools\dev\play_by_ear.ps1: answers a choice already waiting when it starts; "A number key to
  choose" is answered like "Pick a number".

Open problems seen in Episode 4 (also in "Not done yet"):
- After a failed try, Tab can skip a hotspot that has since become reachable (the doctor's
  corpse in Crawford) until Lee moves.
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
  - Program.cs: options (--no-launch, --no-install, --uninstall [--all], --game PATH, --backend NAME,
    --port N); starts everything and launches the game.
  - Speech.cs: Prism on one STA thread (prism_init, prism_registry_acquire_best,
    prism_backend_output). Prism.cs has the P/Invoke declarations.
  - LocalServer.cs: the tiny HTTP server. Routes: /speak (numbered batches), /say, /sayi, /stop,
    /log (to logs/game.log), /enqueue and /cmd (dev console), /mouse?dx=&dy= (Mouse.cs: relative
    mouse moves in steps, only while WDC.exe is in front; bow4.lua turns the camera with it),
    /tone?f=&ms=&p=&v=&w=&lp= (Tones.cs: a small waveOut mixer for the beacons and the bow's tone).
    Anything else goes to logs/requests.log.
  - SpeechSequencer.cs: puts numbered speech batches back in order.
  - ModInstaller.cs: copies dist/TWDAccess/mod/** into the game folder, keeps a SHA-256 manifest in
    TWDAccess/installed.txt, and never overwrites another mod's DebugLoader.lua.
  - DebugMonitor.cs: captures the game's OutputDebugString output into logs/debug.log.
  - GameLocator.cs: finds the game through Steam's library manifests.
- `mod/src/DebugLoader.lua`: the bootstrap (encrypted at build time). `mod/src/probe.lua` is the
  obsolete first probe, kept only for reference.
- `mod/lua/`: the mod, plain Lua, installed to <game>\TWDAccess\.
  - main.lua: loads the modules in order: core, settings, text, hooks, carryover, uitext, menus,
    panes, messagebox, prompts, prompts2, choices, choices2, lookaround, lookaround2, lookaround4,
    actions, action2, qte3, configurator, aiming, sniper, struggle, combat4, shooter4, sounds, bow4,
    stars4, beacons, turnchoice, inventory,
    peek, guided, runto, cornfield, drag, drag2, drag3, fastslow, cover, readables, panels,
    subtitles, hotkeys, then discovery and devconsole if enabled.
  - The Final Season modules (twelfth session; see "The Final Season"): configurator.lua (the story
    recap's questions), lookaround4.lua (useables, places and walkers on Tab, Enter or F, stations,
    announcements) and combat4.lua (walkers: warnings, keys in reach, early Q or E kept, slow and
    auto modes; TWDA.walkerTargets; aims Q and E with the target override, groups); thirteenth
    session: shooter4.lua (shooter stations), bow4.lua (the bow: R, Enter, Tab; turns the camera with
    the helper's /mouse) and stars4.lua (stargazing); fourteenth session: searchlight4.lua (the dock's
    searchlight lines, Episode 3: the next crossing's light said; untested by ear). For every season: sounds.lua (TWDA.tone,
    TWDA.soundDirection, beepvolume and F3) and beacons.lua (sound beacons from each look-around
    module's TWDA.beaconEntries; F4). The Final Season also uses choices2,
    lookaround2 (places and walking), qte3, struggle, prompts2 (notices), guided (paths: the key from
    GetRelativeDirection) and menus.
  - A New Frontier modules (tenth session; see "A New Frontier"): qte3.lua (QTE prompts, things to
    pick, multi-prompt QTEs, TWDA.qteBusy) and drag3.lua (drags). A New Frontier also uses
    choices2, lookaround2, prompts2, struggle, guided and menus.
  - Season 2 modules (seventh session; see "Season 2 during play"): choices2.lua (dialog choices),
    lookaround2.lua (hotspots, places to walk to, steering), drag2.lua (drags), action2.lua
    (dodges and blows), prompts2.lua (death screen, inventory). Each checks for Season 2's own
    functions and does nothing elsewhere.
  - cornfield.lua (sixth session): 400 Days' cornfield rows and the rebar grab (see "Sixth
    session"); drag.lua: the game's drags by keyboard (mode_drag); fastslow.lua: sneak up or
    jump out by keyboard (mode_fastSlow; see "400 Days replayed").
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
    visible text of an agent and its children. Also Season 2's UIZ menus (see "Season 2's menus"):
    siblingText, season2TitleOf, season2PopupText, season2RowValue and the frame checks
    "menus.season2" and "menus.season2value".
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
  - prompts.lua also reads the end-of-episode statistics, the season summary (Enter goes on;
    TWDA.describeSeasonStats) and the episode credits.
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
- `tools/ttarchext/ttarchext.exe`: only for the bootstrap; see the constraints above. NOT IN GIT
  since 2026-11-03 (it has RAD Game Tools' Oodle built in; .gitignore leaves tools/ttarchext/ out):
  keep the local copy, or get it from the Telltale Modding Group's Telltale-Script-Editor
  (resources/ttarchext.exe).
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
  Episode 4: ep4_house\ (despite the name its checkpoint is probably the yard,
  env_manorExteriorDay.lua, from the pet door talk: the main file was newer, see item I),
  ep4_riverstreet\ (env_savannahRiverStreet.lua, the scene's start, before the telescope),
  ep4_sewers\ (env_savannahSewers.lua,
  arriving), ep4_sewers_after\ (env_savannahSewers.lua, after the walker grab, in the upper
  tunnel), ep4_clemsearch\ (env_manorInteriorClementineSearch.lua, back at the house),
  ep4_crawford\ (env_crawfordExterior.lua, Crawford's outskirts after the manhole and hiding),
  ep4_motorshop\ (env_crawfordAutoShop.lua), ep4_classroom\ (env_crawfordSchoolHallways.lua,
  back in the classroom with the fuel), ep4_meds\ (env_crawfordSchoolNursesOffice.lua, the
  medicine taken), ep4done\ (Episode 4 finished), ep5done\ (Episode 5 finished: Season 1 done).
  Added in the sixth session: 400_shel\ (400 Days, the start of Shel's story in the truck stop
  diner; saves.txt line Chapter5A_TruckStopInterior.lua), 400done\ (400 Days finished; saves.txt
  line Chapter6B_Camp.lua).
  Added in the eighth session: backyard_leaving\ (env_clementineHouseExterior.lua, Episode 1's
  day branch, just out of the house after the fight) and backyard_night\
  (env_clementineHouseExterior_Night.lua, the night branch the user played: the gate bug).
  Season 2 copies (all *wd2_saveslot2* files of save file 2): s2_ep1done\ (seventh session), and
  from the ninth session s2_ep2_cabinnight\ (Episode 2, the group talk after Carver's visit;
  saves.txt line "wd2_saveslot2.bundle<TAB>CabinInterior.lua" for Continue), s2_ep2done\,
  s2_ep3done\, s2_ep4done\ (each ready for Chapter Select's "Start Episode N"), s2_ep5done\ (Season
  2 finished; saves.txt then said FinaleOpenField.lua).
  A New Frontier copies (all *wd3_saveslot2* files of its Save 2; tenth session): s3_ep1done\ ..
  s3_ep4done\ (each ready for "Start Episode N" on the Episodes screen) and s3_ep5done\ (season
  finished; saves.txt said RichmondGateFinale.lua).

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
`TWDAccess.exe --uninstall` removes the mod (keeping the bootstrap and saves.txt if saves were made
with it; `--uninstall --all` removes those too).

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
- `tools\dev\to_season.ps1 -Season 2` from the hub's main menu opens that season's menu;
  `-FromSeason2` first goes from Season 2's main menu back to the hub (a fresh Lua state, so new
  mod files load). `console.ps1 -File x.lua` runs a Lua file (step.ps1 has no -File).
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
  request). Since 2026-10-10 the repository's own git config has the user's chosen identity,
  user.name Kongster90 and their GitHub no-reply address as user.email, so a plain `git commit`
  is right (every commit now has that identity: the two oldest, which had "dengs" and their Gmail,
  were rewritten on 2026-11-03 before the repository went public). Only commit or push if the user asks.
  Rewriting history (rebase, amend of pushed commits) and writes to GitHub such as editing issue
  comments can be blocked by the auto-mode safety check: then tell the user and let them decide.
- Matt Pocock's engineering skills are set up (CLAUDE.md "Agent skills", docs/agents/): issues in
  GitHub Issues, default triage labels, single-context domain docs. The repository is private.
  The `gh` CLI (2.102.0) is installed at C:\Program Files\GitHub CLI\gh.exe and signed in as
  Kongster90 (installed during the 2026-10-03 session, so that session's shells needed the full
  path). All five triage labels exist in the repo (the four besides `wontfix` were created on
  2026-10-03), next to GitHub's defaults and an `accessibility` label. Issues #1 to #9 are the
  "Not done yet" list below.
