param(
    [string]$LibraryPath
)

$ErrorActionPreference = 'Stop'
$productRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $LibraryPath) {
    # Linked worktrees share the original checkout's Git directory. Resolve
    # the sibling source library from there, not from the worktree's parent.
    $gitCommonDirectory = git -C $productRoot rev-parse --path-format=absolute --git-common-dir
    if ($LASTEXITCODE -eq 0) {
        $checkoutRoot = Split-Path -Parent $gitCommonDirectory
        $LibraryPath = Join-Path (Split-Path -Parent $checkoutRoot) 'LycheeUI'
    } else {
        $LibraryPath = Join-Path (Split-Path -Parent $productRoot) 'LycheeUI'
    }
}
$libraryRoot = (Resolve-Path -LiteralPath $LibraryPath).Path
$embeddedRoot = Join-Path $productRoot 'addon\LycheeGroup\Libs\LycheeUI'
$embeds = [xml](Get-Content -LiteralPath (Join-Path $libraryRoot 'embeds.xml') -Raw)
$runtimeFiles = @('embeds.xml') + @($embeds.SelectNodes('//*[local-name()="Script"]') | ForEach-Object { $_.file })

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
if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
    Copy-Item -LiteralPath $lockPath -Destination (Join-Path $embeddedRoot '.lock') -Force
}
Write-Output "LycheeUI embedded at $embeddedRoot"
