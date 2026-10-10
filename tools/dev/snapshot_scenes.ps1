<#
  Development helper: while it runs, copy the test slot's two save files into
  dev_saves\auto\<scene script>\ each time the game saves slot 2 at a scene start (the
  "SaveSlots_Save: save slot wd1_saveslot2.bundle -> X.lua" line in twda.log), so a scene can be
  replayed later without playing up to it again. Later autosaves in the scene overwrite the slot,
  not these copies. To load one: close the game, copy the files back into the save folder and set
  saves.txt's slot 2 line to the folder name plus ".lua" (see load_slot2.ps1).
    .\snapshot_scenes.ps1 -Minutes 120      # run it in the background
#>
param([int]$Minutes = 120)

$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$saves = Join-Path $env:USERPROFILE "Documents\Telltale Games\The Walking Dead Definitive"
$root = Join-Path $PSScriptRoot "..\..\dev_saves\auto"

$fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
[void]$fs.Seek(0, 'End')
$reader = New-Object System.IO.StreamReader($fs)
$end = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $end) {
    $line = $reader.ReadLine()
    if ($null -eq $line) { Start-Sleep -Milliseconds 500; continue }
    if ($line -match "SaveSlots_Save: save slot wd1_saveslot2\.bundle -> (\S+)\.lua") {
        $scene = $Matches[1]
        # (The files are written a moment after the line.)
        Start-Sleep -Seconds 5
        $dir = Join-Path $root $scene
        New-Item -ItemType Directory -Force $dir | Out-Null
        Copy-Item (Join-Path $saves "wd1_saveslot2.bundle"), (Join-Path $saves "_wd1_saveslot2_autosave.bundle") $dir -Force
        "{0:HH:mm:ss} copied {1}" -f (Get-Date), $scene
    }
}
$reader.Close()
