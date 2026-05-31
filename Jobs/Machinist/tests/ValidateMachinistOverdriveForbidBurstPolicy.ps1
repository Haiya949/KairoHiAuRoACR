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
$docs = Read-File "docs/DEVELOPMENT.md"
$body = Get-Body $helper "public static Spell\? GetQueenOverdriveOffGcd\(\)" "Queen/Rook overdrive policy"
$forbidBurstLabel = [regex]::Escape((U @(0x4fdd, 0x7559, 0x7206, 0x53d1)))

Assert-Contains $body "IsForbidBurstActive\(\)" "Queen/Rook overdrive must respect the visible ForbidBurst control before explicit release or dump"
Assert-InOrder $body @(
    "if (IsForbidBurstActive())",
    "if (!HasTarget() || !IsRobotActive()"
) "Queen/Rook overdrive must check ForbidBurst before release/dump eligibility"
Assert-Contains $body "LevelAtLeast\(80\) \? ActionId\.QueenOverdrive : ActionId\.RookOverdrive" "Queen/Rook overdrive must keep low-level action selection"
Assert-Contains $docs "Queen/Rook Overdrive.*ForbidBurst" "Development docs must record that overdrive respects ForbidBurst"
Assert-Contains $docs "$forbidBurstLabel.*Queen/Rook Overdrive" "Development docs must explain the user-visible hold behavior"
Assert-NotContains $helper "MachinistActionId|MachinistStatusId|AEAssist|Kairo\.Machinist" "Queen/Rook overdrive policy must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Queen/Rook overdrive ForbidBurst validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist Queen/Rook overdrive ForbidBurst validation passed."
