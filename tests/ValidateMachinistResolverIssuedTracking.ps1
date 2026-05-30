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

function Assert-BuildMarksAfterAdd {
    param([string]$Path)

    $text = Read-File $Path
    $match = [regex]::Match(
        $text,
        "public void Build\(Slot slot\)\s*\{(?<body>.*?)\n    \}",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        $failures.Add("Could not find Build body ($Path)")
        return
    }

    $body = $match.Groups["body"].Value
    if ($body -notmatch "MachinistSpellHelper\.AddIssuedSpell\(slot,\s*_spell\)") {
        $failures.Add("Resolver must use MachinistSpellHelper.AddIssuedSpell for immediate issued tracking ($Path)")
    }
}

$resolverFiles = @(
    "Jobs/Machinist/Resolvers/GCD/MachinistAoeGcdResolver.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistOverheatedGcdResolver.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistStrongGcdResolver.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistBaseGcdResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistQueenOverdriveResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistWildfireResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistBarrelStabilizerResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistHyperchargeResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistQueenResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistGaussRoundResolver.cs"
)

foreach ($file in $resolverFiles) {
    Assert-BuildMarksAfterAdd $file
}

Assert-Contains "Jobs/Machinist/Resolvers/OffGCD/MachinistReassembleResolver.cs" "slot\.Add\(_spell\)[\s\S]*MachinistSpellHelper\.MarkReassembleOffGcdIssued\(_targetActionId\.Value\)" "Reassemble resolver must keep its dedicated issued marker after slot.Add"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "public static void MarkReassembleOffGcdIssued\(uint targetActionId\)[\s\S]*MarkCombatActionIssued\(ActionId\.Reassemble\)" "Dedicated Reassemble issued marker must delegate to the shared issued-action tracker"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "public static void AddIssuedSpell\(Slot slot, Spell spell\)[\s\S]*slot\.Add\(spell\)[\s\S]*MarkCombatActionIssued\(spell\.Id\)" "Shared issued-action helper must mark after slot.Add"

Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "public static void MarkCombatActionIssued\(uint actionId\)" "MCH helper must expose issued-action tracking for resolvers"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "TrackBurstPackageAction\(actionId\)" "Issued-action tracking must update burst package state before success callbacks arrive"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "CombatActionLastUsedAtMs\[actionId\] = _currentBattleTimeMs" "Issued-action tracking must update tracked tool recasts before success callbacks arrive"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "if \(actionId is ActionId\.AutomatonQueen or ActionId\.RookAutoturret\)\s*_robotActiveUntilMs = _currentBattleTimeMs \+ QueenActiveEstimateMs;" "Issued-action tracking must mark robot active when Queen/Rook is queued"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "if \(actionId is ActionId\.QueenOverdrive or ActionId\.RookOverdrive or ActionId\.Detonator\)\s*_robotActiveUntilMs = 0;" "Issued-action tracking must clear robot active when overdrive/detonator is queued"

Assert-Contains "docs/DEVELOPMENT.md" "Issued-action tracking" "Development docs must record resolver issued-action tracking"
Assert-Contains "docs/DEVELOPMENT.md" "slot.Add" "Development docs must state marking happens after slot.Add"
Assert-Contains "docs/DEVELOPMENT.md" "OnSpellCastSuccess" "Development docs must explain why success callback alone is too late"

Assert-NotContains "Jobs/Machinist" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist" "Issued-action tracking must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist resolver issued-action tracking validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist resolver issued-action tracking validation passed."
