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

Assert-BodyContains $helper "public static Spell\? GetQueenOverdriveOffGcd\(\)" @(
    "!HasTarget\(\)",
    "!IsRobotActive\(\)",
    "!\(ShouldReleaseBatteryForTimeline\(\) \|\| ShouldUseDumpResources\(\)\)",
    "!CanWeave\(\)",
    "LevelAtLeast\(80\) \? ActionId\.QueenOverdrive : ActionId\.RookOverdrive",
    "SelfAbility\(actionId\)",
    "spell\.IsReadyWithCanCast\(\)"
) "Robot overdrive must finish active Rook/Queen during explicit battery release or generic DumpResources"

Assert-Contains "docs/DEVELOPMENT.md" "Queen/Rook Overdrive dump policy" "Development docs must record the robot overdrive dump policy"
Assert-Contains "docs/DEVELOPMENT.md" "ShouldReleaseBatteryForTimeline" "Development docs must mention timeline battery release for overdrive"
Assert-Contains "docs/DEVELOPMENT.md" "ShouldUseDumpResources" "Development docs must mention generic DumpResources for overdrive"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Queen/Rook overdrive dump validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist Queen/Rook overdrive dump validation passed."
