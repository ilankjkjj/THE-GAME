$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $luneCommand = Get-Command lune -ErrorAction SilentlyContinue
    $localLune = Join-Path (Get-Location) '.tools/lune/lune.exe'
    if ($luneCommand) { $testRunner = $luneCommand.Source }
    elseif (Test-Path -LiteralPath $localLune) { $testRunner = $localLune }
    else { throw 'Install the pinned tools with rokit install, then run the checks again.' }
    foreach ($suite in @('tests/run.luau', 'tests/events.luau')) {
        & $testRunner run $suite
        if ($LASTEXITCODE -ne 0) { throw "Game checks failed: $suite" }
    }
} finally {
    Pop-Location
}
