param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Solution = Join-Path $RepoRoot "KairoHiAuRoACR.slnx"
$OutputDll = Join-Path $RepoRoot "bin\$Configuration\net10.0-windows\Kairo.dll"

Write-Host "[Kairo] Building $Solution ($Configuration)"
dotnet build $Solution -c $Configuration -nologo

if (!(Test-Path -LiteralPath $OutputDll)) {
    throw "Build completed but output DLL was not found: $OutputDll"
}

Write-Host "[Kairo] Output: $OutputDll"

