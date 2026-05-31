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

function Assert-BodyInOrder {
    param(
        [string]$Body,
        [string[]]$Tokens,
        [string]$Message
    )

    $position = -1
    foreach ($token in $Tokens) {
        $next = $Body.IndexOf($token, $position + 1, [StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message missing or out of order token: $token")
            return
        }

        $position = $next
    }
}

function Assert-BodyContains {
    param(
        [string]$Body,
        [string[]]$Patterns,
        [string]$Message
    )

    foreach ($pattern in $Patterns) {
        if ($Body -notmatch $pattern) {
            $failures.Add("$Message missing pattern: $pattern")
        }
    }
}

function Assert-Contains {
    param([string]$Path, [string]$Pattern, [string]$Message)

    $text = Read-File $Path
    if ($text -notmatch $Pattern) {
        $failures.Add("$Message ($Path): $Pattern")
    }
}

function Assert-NotContains {
    param([string]$Path, [string]$Pattern, [string]$Message)

    $text = Read-File $Path
    if ($text -match $Pattern) {
        $failures.Add("$Message ($Path): $Pattern")
    }
}

$opener = Read-File "Jobs/Machinist/Opener/MachinistOpener.cs"

$firstDrill = Get-Body $opener "private static void BuildFirstDrillSlot\(Slot slot\)" "first Drill opener slot"
$secondDrill = Get-Body $opener "private static void BuildSecondDrillSlot\(Slot slot\)" "second Drill opener slot"
$fullMetal = Get-Body $opener "private static void BuildFullMetalFieldSlot\(Slot slot\)" "Full Metal Field opener slot"

Assert-BodyInOrder $firstDrill @(
    "AddGcdIfUnlocked(slot, ActionId.Drill);",
    "AddTargetAbilityIfReady(slot, ActionId.Checkmate);",
    "AddTargetAbilityIfReady(slot, ActionId.DoubleCheck);"
) "G1 opener slot must spend the first Checkmate/Double Check pair only after Drill"

Assert-BodyInOrder $secondDrill @(
    "AddGcdIfUnlocked(slot, ActionId.Drill);",
    "AddTargetAbilityIfReady(slot, ActionId.Checkmate);",
    "AddTargetAbilityIfReady(slot, ActionId.Wildfire);"
) "G5 opener slot must spend saved Checkmate before Wildfire"

Assert-BodyInOrder $fullMetal @(
    "AddGcdIfUnlocked(slot, ActionId.FullMetalField);",
    "AddTargetAbilityIfReady(slot, ActionId.DoubleCheck);",
    "AddSelfAbilityWithoutReadinessGate(slot, ActionId.Hypercharge);"
) "G6 opener slot must spend saved Double Check before Hypercharge"

Assert-BodyContains $firstDrill @(
    "ActionId\.Checkmate",
    "ActionId\.DoubleCheck"
) "G1 opener slot must keep one early ammo pair"

Assert-BodyContains $secondDrill @(
    "ActionId\.Checkmate",
    "ActionId\.Wildfire"
) "G5 opener slot must keep Checkmate and Wildfire in one native Slot"

Assert-BodyContains $fullMetal @(
    "ActionId\.DoubleCheck",
    "ActionId\.Hypercharge"
) "G6 opener slot must keep Double Check and Hypercharge in one native Slot"

Assert-Contains "docs/DEVELOPMENT.md" 'G1 `Drill`.*`Double Check`.*`Checkmate`' "Development docs must record G1 opener ammo behavior"
Assert-Contains "docs/DEVELOPMENT.md" 'G2 `Air Anchor`.*G3 `Chain Saw`.*saved second `Double Check` / `Checkmate`' "Development docs must record saved ammo hold through G2/G3"
Assert-Contains "docs/DEVELOPMENT.md" 'G5 first weave spends saved `Checkmate`, then `Wildfire` takes the second weave' "Development docs must record G5 saved-ammo weave order"
Assert-Contains "docs/DEVELOPMENT.md" 'G6 first weave spends saved `Double Check`, then `Hypercharge` takes the second weave' "Development docs must record G6 saved-ammo weave order"

Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "ShouldDelayOpenerWildfireForSavedAmmo|ShouldDelayOpenerHyperchargeForSavedAmmo|ShouldUseSavedAmmoBeforeOpenerBurst|ShouldPreferCheckmateBeforeOpenerWildfire" "HiAuRo IOpener must express opener saved-ammo ordering through Slot order, not old resolver delay helpers"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist" "Opener saved-ammo migration must remain Helper-backed and HiAuRo-native"

if ($failures.Count -gt 0) {
    Write-Host "Machinist opener saved-ammo weave validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist opener saved-ammo weave validation passed."
