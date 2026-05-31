param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Read-File {
    param([string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $failures.Add("Missing file: $Path")
        return ""
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Get-Body {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string]$Message
    )

    $match = [regex]::Match(
        $Text,
        "$SignaturePattern\s*\{(?<body>.*?)\n    \}",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        $failures.Add("Could not find body: $Message")
        return ""
    }

    return $match.Groups["body"].Value
}

function Assert-InOrder {
    param(
        [string]$Text,
        [string[]]$Tokens,
        [string]$Message
    )

    $position = -1
    foreach ($token in $Tokens) {
        $next = $Text.IndexOf($token, $position + 1, [StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message missing or out of order token: $token")
            return
        }

        $position = $next
    }
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

function U {
    param([int[]]$Codes)
    return -join ($Codes | ForEach-Object { [char]$_ })
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$docs = Read-File "Jobs/Machinist/docs/DEVELOPMENT.md"
$forbidBurstLabel = [regex]::Escape((U @(0x4fdd, 0x7559, 0x7206, 0x53d1)))

$wildfireBody = Get-Body $helper "public static Spell\? GetWildfireOffGcd\(\)" "Wildfire ForbidBurst policy"
$barrelBody = Get-Body $helper "public static Spell\? GetBarrelStabilizerOffGcd\(\)" "Barrel Stabilizer ForbidBurst policy"
$hyperchargeBody = Get-Body $helper "public static Spell\? GetHyperchargeOffGcd\(\)" "Hypercharge ForbidBurst policy"
$queenBody = Get-Body $helper "public static Spell\? GetQueenOffGcd\(\)" "Queen/Rook ForbidBurst policy"
$overdriveBody = Get-Body $helper "public static Spell\? GetQueenOverdriveOffGcd\(\)" "Queen/Rook overdrive ForbidBurst policy"

Assert-InOrder $wildfireBody @(
    "if (IsForbidBurstActive())",
    "if (ShouldHoldWildfireForTimeline())",
    "if (!HasTarget() || !CanUseWildfireBurstPackage())"
) "Wildfire must respect ForbidBurst before timeline hold/dump or burst package checks"

Assert-InOrder $barrelBody @(
    "if (IsForbidBurstActive())",
    "if (ShouldHoldBarrelForTimeline())",
    "if (!HasTarget() || (!ShouldDumpBarrelForTimeline() && !CanUseBurstResource() && !ShouldUseFixed120BurstPackage()) || !CanWeave())"
) "Barrel Stabilizer must respect ForbidBurst before timeline hold/dump or burst package checks"

Assert-InOrder $hyperchargeBody @(
    "if (IsForbidBurstActive())",
    "if (!shouldUseActiveWildfireHypercharge && ShouldHoldHeatForTimeline())"
) "Hypercharge must keep ForbidBurst before heat hold/dump checks"

Assert-InOrder $queenBody @(
    "if (IsForbidBurstActive())",
    "if (ShouldReleaseBatteryForTimeline())",
    "if (ShouldHoldBatteryForTimeline())"
) "Queen/Rook summon must keep ForbidBurst before battery release/hold checks"

Assert-InOrder $overdriveBody @(
    "if (IsForbidBurstActive())",
    "if (!HasTarget() || !IsRobotActive()"
) "Queen/Rook overdrive must keep ForbidBurst before explicit release/dump checks"

Assert-Contains $docs "ForbidBurst.*Wildfire.*Barrel Stabilizer.*Hypercharge.*Queen/Rook" "Development docs must record the global burst-resource hold gate"
Assert-Contains $docs "$forbidBurstLabel.*Wildfire.*Barrel Stabilizer" "Development docs must explain the user-visible ForbidBurst behavior"
Assert-NotContains $helper "MachinistActionId|MachinistStatusId|AEAssist|Kairo\.Machinist" "Burst-resource ForbidBurst policy must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist burst-resource ForbidBurst validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist burst-resource ForbidBurst validation passed."
