$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    argon serve default.project.json --sourcemap --host 127.0.0.1 --port 8000
    if ($LASTEXITCODE -ne 0) { throw 'Argon could not start. Check whether port 8000 is already in use.' }
} finally {
    Pop-Location
}
