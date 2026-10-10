<#
  Development helper: hold a key along a guided path, letting go when the mod says "Stop!" and
  holding it again -WaitMs later, until the path ends, choices come up or Lee dies. Written for
  Brenda's showdown in the dairy farmhouse (Episode 2), to find out when moving is safe again.
    .\stopgo.ps1 -Key W -WaitMs 3000 -Seconds 60
#>
param([string]$Key = "W", [int]$WaitMs = 3000, [int]$Seconds = 60)

$code = [int][char]$Key
. (Join-Path $PSScriptRoot "game_input.ps1")
$log = "G:\Steam\steamapps\common\The Walking Dead The Telltale Definitive Series\TWDAccess\twda.log"
$h = (Get-Process WDC | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1).MainWindowHandle
$fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
[void]$fs.Seek(0, 'End')
$reader = New-Object System.IO.StreamReader($fs)
$holding = $true
$resumeAt = Get-Date
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    while ($null -ne ($line = $reader.ReadLine())) {
        if ($line -match "say!? (.*)$|subtitle (.*)$|guided: (.*)$") {
            "{0:HH:mm:ss.fff} {1}" -f (Get-Date), $line.Substring(19)
            if ($line -match "Stop! Let go") { $holding = $false; [GameInput]::KeyState([uint16]$code, $false); $resumeAt = (Get-Date).AddMilliseconds($WaitMs); "released" }
            if ($line -match "You are dead|Choices\.|path ended") { [GameInput]::KeyState([uint16]$code, $false); "done"; exit 0 }
        }
    }
    if (-not $holding -and (Get-Date) -ge $resumeAt) { $holding = $true; "holding again" }
    [void][GameInput]::Focus($h)
    if ($holding) { [GameInput]::KeyState([uint16]$code, $true) }
    Start-Sleep -Milliseconds 100
}
[GameInput]::KeyState([uint16]$code, $false)
