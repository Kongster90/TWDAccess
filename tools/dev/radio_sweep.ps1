<#
  Development helper (Michonne Episode 1, the boat's radio): tap a key (A or D) -Steps times,
  -TapMs each, printing the dial's logic values and any new subtitle after each tap.
    .\radio_sweep.ps1 -Key A -Steps 20 -TapMs 250
#>
param([string]$Key = "A", [int]$Steps = 20, [int]$TapMs = 250)
$dev = $PSScriptRoot
. "$dev\game_input.ps1"
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$h = (Get-Process WDC | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1).MainWindowHandle
$vk = [uint16][int][char]$Key.ToUpper()
for ($i = 0; $i -lt $Steps; $i++) {
    [void][GameInput]::Focus($h)
    $from = (Get-Item $log).Length
    [GameInput]::KeyState($vk, $true); Start-Sleep -Milliseconds $TapMs; [GameInput]::KeyState($vk, $false)
    Start-Sleep -Milliseconds 400
    $r = & "$dev\console.ps1" 'return LogicGet("1DockChesapeakeBay - Radio Value") .. "/" .. LogicGet("1DockChesapeakeBay - Squelch Value") .. " t=" .. string.format("%.2f", ControllerGetTime(DockChesapeakeBay_GetRadioController())) .. " s=" .. string.format("%.2f", ControllerGetTime(DockChesapeakeBay_GetSquelchController()))' | Select-Object -Last 1
    $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite'); $fs.Seek($from, 'Begin') | Out-Null
    $new = (New-Object System.IO.StreamReader($fs)).ReadToEnd(); $fs.Close()
    $subs = ($new -split "`n" | Where-Object { $_ -match 'subtitle|say!? ' -and $_ -notmatch 'console' }) -join " / "
    "$i $r $subs"
}
