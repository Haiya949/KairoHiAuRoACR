param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$DeployDir = (Join-Path $env:APPDATA "XIVLauncherCN\pluginConfigs\HiAuRo\ACR\Kairo")
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function U {
    param([int[]]$Codes)

    return -join ($Codes | ForEach-Object { [char]$_ })
}

function Read-File {
    param([string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $failures.Add("Missing file: $Path")
        return ""
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add("$Message`: $Pattern")
    }
}

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -match $Pattern) {
        $failures.Add("$Message`: $Pattern")
    }
}

$project = Read-File "KairoHiAuRoACR.csproj"
$deployScript = Read-File "scripts\deploy.ps1"
$compliance = Read-File "docs\HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md"

Assert-Contains $project "<AssemblyName>Kairo</AssemblyName>" "ACR assembly name must stay Kairo"
Assert-Contains $project '<ProjectReference Include="Helper\\HiAuRo\.Helper\\HiAuRo\.Helper\.csproj">[\s\S]*<Private>False</Private>' "Helper must be referenced with Private=False"
Assert-Contains $project '<Compile Remove="Helper\\\*\*\\\*\.cs" />' "ACR project must not compile Helper source directly"
Assert-Contains $project '<PackageReference Include="HiAuRo\.Sdk"[^>]*>[\s\S]*<ExcludeAssets>runtime</ExcludeAssets>' "HiAuRo.Sdk runtime assets must not be copied into the ACR package"

Assert-Contains $deployScript '\$SourceDll = Join-Path \$RepoRoot "bin\\\$Configuration\\net10\.0-windows\\Kairo\.dll"' "Deploy script must deploy only Kairo.dll from the build output"
Assert-Contains $deployScript '\$DeployDir = Join-Path \$env:APPDATA "XIVLauncherCN\\pluginConfigs\\HiAuRo\\ACR\\Kairo"' "Deploy script must target HiAuRo ACR/Kairo"
Assert-Contains $deployScript 'Copy-Item -LiteralPath \$SourceDll -Destination \$DeployDll -Force' "Deploy script must copy only the ACR DLL"
Assert-Contains $deployScript '\$activeDlls\.Count -gt 1[\s\S]*throw' "Deploy script must fail on multiple active DLLs instead of only warning"
Assert-NotContains $deployScript 'Write-Warning "Multiple active DLLs' "Deploy script must not merely warn about multiple active DLLs"
Assert-NotContains $deployScript 'Copy-Item[\s\S]*HiAuRo\.Helper\.dll|HiAuRo\.Helper\.dll[\s\S]*Copy-Item' "Deploy script must not copy HiAuRo.Helper.dll"

foreach ($text in @($compliance)) {
    Assert-Contains $text "<Private>False</Private>" "Docs must record Helper Private=False"
    Assert-Contains $text "Kairo\.dll" "Docs must record the deployed ACR DLL name"
}

$notCopyHelper = (U 0x8F93,0x51FA,0x4E0D,0x590D,0x5236) + ' `HiAuRo.Helper.dll`'
Assert-Contains $compliance ([regex]::Escape($notCopyHelper)) "Compliance docs must say Helper DLL is not copied"

$outputDir = Join-Path $Root "bin\Debug\net10.0-windows"
if (Test-Path -LiteralPath $outputDir) {
    $outputDlls = Get-ChildItem -LiteralPath $outputDir -File -Filter "*.dll" | Select-Object -ExpandProperty Name
    if ($outputDlls -contains "HiAuRo.Helper.dll") {
        $failures.Add("Build output must not contain HiAuRo.Helper.dll.")
    }
}

if (Test-Path -LiteralPath $DeployDir) {
    $activeDlls = @(Get-ChildItem -LiteralPath $DeployDir -File -Filter "*.dll" | Where-Object { $_.Name -notlike "*.bak*" })
    if ($activeDlls.Count -ne 1 -or $activeDlls[0].Name -ne "Kairo.dll") {
        $failures.Add("Deploy directory must contain exactly one active ACR DLL named Kairo.dll. Active DLLs: $($activeDlls.Name -join ', ')")
    }

    if (Test-Path -LiteralPath (Join-Path $DeployDir "HiAuRo.Helper.dll")) {
        $failures.Add("Deploy directory must not contain HiAuRo.Helper.dll.")
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Deployment package boundary validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Deployment package boundary validation passed."
