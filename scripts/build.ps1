$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    argon build default.project.json --output build/DontPressTheButton.rbxlx --xml
    if ($LASTEXITCODE -ne 0) { throw 'Argon build failed.' }
    $luneCommand = Get-Command lune -ErrorAction SilentlyContinue
    $localLune = Join-Path (Get-Location) '.tools/lune/lune.exe'
    if ($luneCommand) { & $luneCommand.Source run scripts/build.luau }
    elseif (Test-Path -LiteralPath $localLune) { & $localLune run scripts/build.luau }
    else { throw 'Install the pinned tools with rokit install, then run this build again.' }
    if ($LASTEXITCODE -ne 0) { throw 'Room construction failed.' }
    argon sourcemap default.project.json --output sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Sourcemap generation failed.' }
} finally {
    Pop-Location
}
