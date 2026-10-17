param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\dist'))

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$skinSource = Join-Path $repositoryRoot 'AethesticWeather'
if (-not (Test-Path -LiteralPath (Join-Path $skinSource 'AethesticWeather.ini'))) {
    throw "Rainmeter skin source not found: $skinSource"
}

$iconGenerator = Join-Path $PSScriptRoot 'Generate-Icons.ps1'
& $iconGenerator
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$staging = Join-Path ([IO.Path]::GetTempPath()) ('AethesticWeather-rmskin-' + [guid]::NewGuid().ToString('N'))
$packageSkin = Join-Path $staging 'Skins\AethesticWeather'
[IO.Directory]::CreateDirectory($packageSkin) | Out-Null

try {
    Get-ChildItem -LiteralPath $skinSource -Force | Copy-Item -Destination $packageSkin -Recurse -Force
    @'
[rmskin]
Name=AethesticWeather
Author=Alden Graham
Version=1.0.0
MinimumRainmeter=4.5.0
MinimumWindows=10.0
'@ | Set-Content -LiteralPath (Join-Path $staging 'RMSKIN.ini') -Encoding ASCII

    $rmskin = Join-Path $output 'AethesticWeather-1.0.0.rmskin'
    if (Test-Path -LiteralPath $rmskin) { Remove-Item -LiteralPath $rmskin -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($staging, $rmskin)

    # Rainmeter's installer requires its 16-byte package footer after the ZIP archive.
    $packageSize = (Get-Item -LiteralPath $rmskin).Length
    $footer = [byte[]]::new(16)
    [Array]::Copy([BitConverter]::GetBytes([long]$packageSize), 0, $footer, 0, 8)
    [Text.Encoding]::ASCII.GetBytes("RMSKIN").CopyTo($footer, 9)
    $stream = [IO.File]::Open($rmskin, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($footer, 0, $footer.Length)
    }
    finally {
        $stream.Dispose()
    }

    Write-Output "Created $rmskin"
}
finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
