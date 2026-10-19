param(
    [string]$LibraryPath = (Join-Path $PSScriptRoot '..\..\LycheeUI')
)

$ErrorActionPreference = 'Stop'
$libraryRoot = (Resolve-Path -LiteralPath $LibraryPath).Path
$productRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$embeddedRoot = Join-Path $productRoot 'addon\LycheeGroup\Libs\LycheeUI'
$runtimeFiles = @('embeds.xml', 'Core.lua', 'Theme.lua', 'Motion.lua', 'Components.lua', 'Native.lua', 'Menu.lua')

foreach ($file in $runtimeFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $libraryRoot $file) -PathType Leaf)) {
        throw "Missing LycheeUI runtime file: $file"
    }
}

$lockPath = Join-Path $libraryRoot '.lock'
if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
    $libraryLock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
    if ($libraryLock.status -eq 'frozen') {
        $sourceFiles = @($runtimeFiles) + @(Get-ChildItem -LiteralPath (Join-Path $libraryRoot 'Media') -File -Recurse -Force | ForEach-Object {
            $_.FullName.Substring($libraryRoot.Length + 1).Replace('\', '/')
        })
        if (Compare-Object -ReferenceObject @($libraryLock.runtimeFiles.path) -DifferenceObject $sourceFiles) {
            throw 'LycheeUI is frozen: runtime file list differs from .lock.'
        }
        foreach ($file in $libraryLock.runtimeFiles) {
            $hash = (Get-FileHash -LiteralPath (Join-Path $libraryRoot $file.path) -Algorithm SHA256).Hash
            if ($hash -ne $file.sha256) {
                throw "LycheeUI is frozen: $($file.path) differs from .lock."
            }
        }
        Write-Output "LycheeUI freeze verified: $($libraryLock.version) / r$($libraryLock.revision)"
    }
}

New-Item -ItemType Directory -Path $embeddedRoot -Force | Out-Null
foreach ($file in $runtimeFiles) {
    Copy-Item -LiteralPath (Join-Path $libraryRoot $file) -Destination (Join-Path $embeddedRoot $file) -Force
}
Copy-Item -LiteralPath (Join-Path $libraryRoot 'Media') -Destination $embeddedRoot -Recurse -Force
Write-Output "LycheeUI embedded at $embeddedRoot"
