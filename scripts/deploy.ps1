param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",

    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceDll = Join-Path $RepoRoot "bin\$Configuration\net10.0-windows\Kairo.dll"
$DeployDir = Join-Path $env:APPDATA "XIVLauncherCN\pluginConfigs\HiAuRo\ACR\Kairo"
$DeployDll = Join-Path $DeployDir "Kairo.dll"

if (!$SkipBuild) {
    & (Join-Path $PSScriptRoot "build.ps1") -Configuration $Configuration
}

if (!(Test-Path -LiteralPath $SourceDll)) {
    throw "Source DLL was not found: $SourceDll"
}

if (!(Test-Path -LiteralPath $DeployDir)) {
    New-Item -ItemType Directory -Path $DeployDir | Out-Null
}

Copy-Item -LiteralPath $SourceDll -Destination $DeployDll -Force

$activeDlls = Get-ChildItem -LiteralPath $DeployDir -File -Filter "*.dll" |
    Where-Object { $_.Name -notlike "*.bak*" }

if ($activeDlls.Count -gt 1) {
    $activeDllList = ($activeDlls | Select-Object -ExpandProperty Name) -join ", "
    throw "Multiple active DLLs are present in $DeployDir. HiAuRo may scan more than Kairo.dll. Active DLLs: $activeDllList"
}

Write-Host "[Kairo] Deployed: $DeployDll"
