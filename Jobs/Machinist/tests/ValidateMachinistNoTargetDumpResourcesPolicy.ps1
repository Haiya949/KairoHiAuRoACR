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

function Assert-BodyNotContains {
    param(
        [string]$Body,
        [string]$Pattern,
        [string]$Message
    )

    if ($Body -match $Pattern) {
        $failures.Add("$Message`: $Pattern")
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

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$dumpByHpBody = Get-Body $helper "private static bool ShouldDumpResourcesByTargetHp\(\)" "daily low-HP dump policy"

Assert-BodyContains $dumpByHpBody @(
    "!ShouldUseDailyTargetHpPolicy\(\)",
    "var target = GetCurrentTarget\(\)",
    "target is null \|\| target\.MaxHp <= 0",
    "return false",
    "\(float\)target\.CurrentHp / target\.MaxHp <= DumpResourcesHpThreshold"
) "Daily low-HP dump must require a live target before treating the target as nearly dead"

Assert-BodyNotContains $dumpByHpBody "GetCurrentTargetHpPercent\(\) <= DumpResourcesHpThreshold" "Daily low-HP dump must not use the no-target HP helper because it returns 0 for missing targets"

Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "private static bool HasTarget\(\)" "MCH policy must keep a shared live-target helper"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "target\.CurrentHp > 0" "MCH live-target helper must reject dead or stale targets"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "requires a live target" "Development docs must record that daily auto-dump is not active without a live target"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "Core\\.Me\\.GetCurrTarget|AEAssist|MachinistActionId|MachinistStatusId" "No-target dump policy must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist no-target DumpResources policy validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist no-target DumpResources policy validation passed."
