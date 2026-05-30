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

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Assert-BodyContains {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string[]]$Patterns,
        [string]$Message
    )

    $match = [regex]::Match(
        $Text,
        "$SignaturePattern\s*\{(?<body>.*?)\n    \}",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        $failures.Add("Could not find body: $Message")
        return
    }

    foreach ($pattern in $Patterns) {
        if ($match.Groups["body"].Value -notmatch $pattern) {
            $failures.Add("$Message missing pattern: $pattern")
        }
    }
}

function Assert-BodyNotContains {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string[]]$Patterns,
        [string]$Message
    )

    $match = [regex]::Match(
        $Text,
        "$SignaturePattern\s*\{(?<body>.*?)\n    \}",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        $failures.Add("Could not find body: $Message")
        return
    }

    foreach ($pattern in $Patterns) {
        if ($match.Groups["body"].Value -match $pattern) {
            $failures.Add("$Message forbidden pattern: $pattern")
        }
    }
}

$opener = Read-File "Jobs/Machinist/Opener/MachinistOpener.cs"
$runtimeSpellExtension = Read-File "..\HiAuRo-master\HiAuRo\ACR\SpellExtension.cs"

if ($runtimeSpellExtension -notmatch "SpellTargetType\.Self => Data\.Me\.Object\?\.GameObjectID" `
    -or $runtimeSpellExtension -notmatch "SpellTargetType\.Target => Data\.Target\.Current\?\.GameObjectID") {
    $failures.Add("HiAuRo Runtime target semantics changed; re-check opener target type expectations.")
}

Assert-BodyContains $opener "private static void BuildExcavatorSlot\(Slot slot\)" @(
    "AddTargetAbilityWithoutReadinessGate\(slot,\s*LevelAtLeast\(80\) \? ActionId\.AutomatonQueen : ActionId\.RookAutoturret\)",
    "AddSelfAbilityIfReady\(slot,\s*ActionId\.Reassemble\)"
) "MCH opener must summon Queen/Rook on the current target while keeping Reassemble self-targeted"

Assert-BodyNotContains $opener "private static void BuildExcavatorSlot\(Slot slot\)" @(
    "AddSelfAbilityIfReady\(slot,\s*LevelAtLeast\(80\) \? ActionId\.AutomatonQueen : ActionId\.RookAutoturret\)"
) "MCH opener must not send Queen/Rook to Self; HiAuRo Self resolves to the player object"

Assert-BodyContains $opener "private static Spell TargetAbility\(uint actionId\)" @(
    "SpellTargetType\.Target",
    "SpellType\.Ability"
) "MCH opener target abilities must be marked as target oGCD spells"

Assert-BodyContains $opener "private static Spell SelfAbility\(uint actionId\)" @(
    "SpellTargetType\.Self",
    "SpellType\.Ability"
) "MCH opener self abilities must stay available for Reassemble and Barrel Stabilizer"

if ($failures.Count -gt 0) {
    Write-Host "Machinist opener target type validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist opener target type validation passed."
