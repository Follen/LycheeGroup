param([string]$SourceRoot,[string]$OutputPath,[string]$ProfilePath,[string]$ModulePath,[switch]$UseInstalledLibrary)
$ErrorActionPreference='Stop'
$testRoot=$PSScriptRoot
$parts=[Collections.Generic.List[string]]::new()
$parts.Add('local probe=...')
$hashes=[Collections.Generic.List[object]]::new()
if ($UseInstalledLibrary) {
 if ($SourceRoot) { throw 'Choose SourceRoot or UseInstalledLibrary, not both' }
 $sourcePath='installed';$sourceHash='installed'
 $parts.Add('local candidate=assert(LycheeUI)')
} else {
$sourcePath=(Resolve-Path -LiteralPath $SourceRoot).Path
$manifest=[xml](Get-Content -LiteralPath (Join-Path $sourcePath 'embeds.xml') -Raw)
$parts.Add('local installed=LycheeUI;local env=setmetatable({LycheeUI=false},{__index=_G});env._G=env;local private={}')
foreach($node in $manifest.SelectNodes('//*[local-name()="Script"]')) {
 $filePath=Join-Path $sourcePath $node.file
 $code=[IO.File]::ReadAllText($filePath)
 $parts.Add("do local function chunk(...)`n"+$code+"`nend;setfenv(chunk,env);chunk('LycheeGroup',private) end")
 $hashes.Add([pscustomobject]@{path=$node.file;sha256=(Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()})
}
$hashText=($hashes|ConvertTo-Json -Compress)
$sha=[Security.Cryptography.SHA256]::Create()
try { $sourceHash=[Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($hashText))).ToLowerInvariant() } finally { $sha.Dispose() }
$parts.Add("local candidate=assert(env.LycheeUI);candidate.auditSourceHash='$sourceHash';assert(candidate~=installed and LycheeUI==installed)")
}
$moduleHash=$null
if ($ModulePath) {
 $moduleSource=(Resolve-Path -LiteralPath $ModulePath).Path
 $module=[IO.File]::ReadAllText($moduleSource)
 $parts.Add("local function LoadModule(environment,...) local function chunk(...)`n"+$module+"`nend;setfenv(chunk,environment);return chunk(...) end")
 $moduleHash=[pscustomobject]@{path=$moduleSource;sha256=(Get-FileHash -LiteralPath $moduleSource -Algorithm SHA256).Hash.ToLowerInvariant()}
} else { $parts.Add('local LoadModule=nil') }
if (-not $ProfilePath) { $ProfilePath=Join-Path $testRoot 'live_fixed_style_profile.lua' }
$profileSource=(Resolve-Path -LiteralPath $ProfilePath).Path
$profile=[IO.File]::ReadAllText($profileSource)
$parts.Add("local function Profile(...)`n"+$profile+"`nend;Profile(probe,candidate,LoadModule)")
$output=[IO.Path]::GetFullPath($OutputPath)
[IO.File]::WriteAllText($output,($parts -join "`n"),[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($output+'.manifest.json',([pscustomobject]@{source=$sourcePath;sourceHash=$sourceHash;files=$hashes;module=$moduleHash;profile=[pscustomobject]@{path=$profileSource;sha256=(Get-FileHash -LiteralPath $profileSource -Algorithm SHA256).Hash.ToLowerInvariant()};bytes=(Get-Item -LiteralPath $output).Length}|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{output=$output;sourceHash=$sourceHash;bytes=(Get-Item -LiteralPath $output).Length}|ConvertTo-Json
