param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
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

    if ((Get-Item -LiteralPath $fullPath) -is [System.IO.DirectoryInfo]) {
        $builder = New-Object System.Text.StringBuilder
        Get-ChildItem -LiteralPath $fullPath -Recurse -File |
            Where-Object { $_.Extension -in ".cs", ".md", ".json", ".ps1" } |
            Sort-Object FullName |
            ForEach-Object {
                [void]$builder.AppendLine((Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8))
            }

        return $builder.ToString()
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

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $text = Read-File $Path
    if ($text -notmatch $Pattern) {
        $failures.Add("$Message ($Path): $Pattern")
    }
}

function Assert-NotContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $text = Read-File $Path
    if ($text -match $Pattern) {
        $failures.Add("$Message ($Path): $Pattern")
    }
}

function Assert-BodyContains {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string[]]$Patterns,
        [string]$Message
    )

    $body = Get-Body $Text $SignaturePattern $Message
    foreach ($pattern in $Patterns) {
        if ($body -notmatch $pattern) {
            $failures.Add("$Message missing pattern: $pattern")
        }
    }
}

function Assert-InOrder {
    param(
        [string]$Path,
        [string[]]$Tokens,
        [string]$Message
    )

    $text = Read-File $Path
    $position = -1
    foreach ($token in $Tokens) {
        $next = $text.IndexOf($token, $position + 1, [System.StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message; missing or out of order token: $token ($Path)")
            return
        }

        $position = $next
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

Assert-NotContains "Jobs/Machinist/MachinistRotationEntry.cs" "MachinistAirAnchorBatteryDoubleWeaveResolver" "MCH must not bind Queen/Rook to the Air Anchor slot"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "AddIssuedStrongGcdSpell|AppendFixed120AirAnchorDoubleWeave|GetAirAnchorBatteryDoubleWeaveOffGcdSlot|ShouldAddQueenToAirAnchorDoubleWeave|ShouldUseAirAnchorBarrelWeave|TryGetRecentAirAnchorBurstWeaveTime|Fixed120AirAnchor" "MCH fixed 120s Queen/Rook release must not use the removed Air Anchor binding"
Assert-NotContains "Jobs/Machinist/Resolvers" "AirAnchorBatteryDoubleWeave" "Removed Air Anchor resolver must not be registered or referenced"
Assert-Contains "Jobs/Machinist/Resolvers/GCD/MachinistStrongGcdResolver.cs" "AddIssuedSpell\(slot, _spell\)" "Strong GCD resolver must use normal issued tracking"

Assert-BodyContains $helper "private static bool ShouldSpendBatteryInFixed120Burst\(\)" @(
    "ShouldUseFixed120BurstPackage\(\)",
    "HasUsedCurrentFixed120BurstAction\(ActionId\.Drill\)",
    "!HasUsedCurrentFixed120BurstAction\(ActionId\.ChainSaw\)",
    "!HasUsedCurrentFixed120BurstAction\(ActionId\.AutomatonQueen\)",
    "!HasUsedCurrentFixed120BurstAction\(ActionId\.RookAutoturret\)"
) "Queen/Rook fixed 120s release must open after Drill and before Chain Saw"

Assert-BodyContains $helper "private static bool ShouldHoldGcdForFixed120Queen\(\)" @(
    "ShouldSpendBatteryInFixed120Burst\(\)",
    "!ShouldHoldBatteryForTimeline\(\)",
    "!IsRobotActive\(\)",
    "LevelAtLeast\(40\)"
) "Fixed 120s GCDs must briefly wait if Queen/Rook has not been issued before Chain Saw"

Assert-BodyContains $helper "public static Spell\? GetStrongGcd\(\)" @(
    "if \(ShouldHoldGcdForFixed120Queen\(\)\)",
    "return null;"
) "Strong GCD selection must not queue Chain Saw before the fixed 120s Queen/Rook"

Assert-BodyContains $helper "public static Spell\? GetBaseComboGcd\(\)" @(
    "if \(ShouldHoldGcdForFixed120Queen\(\)\)",
    "return null;"
) "Base combo must not fill the fixed 120s Queen/Rook wait with 123"

Assert-BodyContains $helper "public static Spell\? GetAoeGcd\(\)" @(
    "if \(ShouldHoldGcdForFixed120Queen\(\)\)",
    "return null;"
) "AOE filler must not fill the fixed 120s Queen/Rook wait"

Assert-BodyContains $helper "public static Spell\? GetQueenOffGcd\(\)" @(
    "var shouldSpendBatteryInFixed120Burst = ShouldSpendBatteryInFixed120Burst\(\);",
    "shouldSpendBatteryInFixed120Burst \? 0 :",
    "ShouldUseDumpResources\(\) \|\| IsForceBurstActive\(\) \|\| shouldSpendBatteryInFixed120Burst \|\| shouldSpendBatteryByBudget \|\| CanUseBurstResource\(\)"
) "Queen/Rook resolver must own the summon and may clip if needed before Chain Saw"

Assert-InOrder "docs/DEVELOPMENT.md" @(
    "fixed 120s burst order",
    "Drill -> Queen/Rook",
    "Chain Saw"
) "Development docs must record that Queen/Rook is released before Chain Saw"

Assert-NotContains "docs/DEVELOPMENT.md" "Air Anchor.*Barrel Stabilizer \\+ Queen/Rook|AddIssuedStrongGcdSpell|Air Anchor double-weave|Air Anchor battery double-weave" "Development docs must not describe the removed Air Anchor-bound Queen/Rook plan"

if ($failures.Count -gt 0) {
    Write-Host "Machinist fixed-120 Queen-before-ChainSaw validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist fixed-120 Queen-before-ChainSaw validation passed."
