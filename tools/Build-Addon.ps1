param(
    [string]$LibraryPath,
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\dist\LycheeGroup.zip')
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Sync-LycheeUI.ps1') -LibraryPath $LibraryPath
$productRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$archivePath = [IO.Path]::GetFullPath($OutputPath)
$archiveDirectory = Split-Path -Parent $archivePath
New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
$folders = @('LycheeGroup', 'LycheeGroup_Group', 'LycheeGroup_Notes', 'LycheeGroup_UI') |
    ForEach-Object { Join-Path $productRoot "addon\$_" }
Compress-Archive -LiteralPath $folders -DestinationPath $archivePath -Force
Write-Output "Built $archivePath"
