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
New-Item -ItemType Directory -Path $embeddedRoot -Force | Out-Null
foreach ($file in $runtimeFiles) {
    Copy-Item -LiteralPath (Join-Path $libraryRoot $file) -Destination (Join-Path $embeddedRoot $file) -Force
}
Copy-Item -LiteralPath (Join-Path $libraryRoot 'Media') -Destination $embeddedRoot -Recurse -Force
Write-Output "LycheeUI embedded at $embeddedRoot"
