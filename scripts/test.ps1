$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $luneCommand = Get-Command lune -ErrorAction SilentlyContinue
    $localLune = Join-Path (Get-Location) '.tools/lune/lune.exe'
    if ($luneCommand) { & $luneCommand.Source run tests/run.luau }
    elseif (Test-Path -LiteralPath $localLune) { & $localLune run tests/run.luau }
    else { throw 'Install the pinned tools with rokit install, then run the checks again.' }
    if ($LASTEXITCODE -ne 0) { throw 'Game checks failed.' }
} finally {
    Pop-Location
}
