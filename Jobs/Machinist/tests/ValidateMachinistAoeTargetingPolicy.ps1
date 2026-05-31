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

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

foreach ($pattern in @(
    "private static Spell BestAoeTargetSpell\(uint actionId\)",
    "private static IBattleChara GetBestAoeTarget\(uint actionId\)",
    "TargetHelper\.GetMostCanTargetObjects\(actionId, GetAoeFillerTargetThreshold\(actionId\), 5f\)",
    "GetCurrentTarget\(\)!"
)) {
    if ($helper -notmatch $pattern) {
        $failures.Add("MachinistSpellHelper.cs missing AOE targeting policy pattern: $pattern")
    }
}

Assert-BodyContains $helper "public static Spell\? GetAoeGcd\(\)" @(
    "var fillerActionId = LevelAtLeast\(82\) \? ActionId\.Scattergun : ActionId\.SpreadShot",
    "GetEnemyCountNearTarget\(5f\) < GetAoeFillerTargetThreshold\(fillerActionId\)",
    "BestAoeTargetSpell\(ActionId\.AutoCrossbow\)",
    "BestAoeTargetSpell\(ActionId\.Bioblaster\)",
    "BestAoeTargetSpell\(fillerActionId\)"
) "MCH AOE GCDs must use the best AOE target center, not always the current target"

Assert-BodyContains $helper "private static bool ShouldUseBioblasterOnAoe\(\)" @(
    "var target = GetBestAoeTarget\(ActionId\.Bioblaster\)",
    "target\.HasMyAura\(StatusId\.Bioblaster\)",
    "target\.GetAuraTimeLeft\(StatusId\.Bioblaster\) <= BioblasterRefreshSeconds"
) "Bioblaster refresh checks must inspect the selected best AOE target"

Assert-BodyContains $helper "private static Spell\? GetReassembledAoeGcd\(\)" @(
    "BestAoeTargetSpell\(ActionId\.Scattergun\)"
) "Reassembled Scattergun must also use the best AOE target center"

Assert-Contains "docs/DEVELOPMENT.md" "AOE target policy" "Development docs must record the MCH best-AOE-target policy"
Assert-Contains "docs/DEVELOPMENT.md" "TargetHelper.GetMostCanTargetObjects" "Development docs must cite the HiAuRo-native AOE target helper"
Assert-Contains "docs/DEVELOPMENT.md" "does not replace Runtime target selection" "Development docs must keep AOE target centering separate from Runtime target selection"

Assert-NotContains "Jobs/Machinist/MachinistTargetResolver.cs" "TargetResolver_最佳AOE位置|TargetResolver_最低HP敌人|TrySelectTarget|TargetManager" "MCH Runtime target resolver must remain nearest-enemy only"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "Core\\.Me\\.GetCurrTarget|AEAssist|MachinistActionId|MachinistStatusId|DynamicTargetSpell" "AOE target policy must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist AOE targeting policy validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist AOE targeting policy validation passed."
