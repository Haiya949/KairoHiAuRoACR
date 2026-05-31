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

    if ((Get-Item -LiteralPath $fullPath) -is [System.IO.DirectoryInfo]) {
        $builder = New-Object System.Text.StringBuilder
        Get-ChildItem -LiteralPath $fullPath -Recurse -File |
            Where-Object { $_.Extension -eq ".cs" -and $_.FullName -notmatch '\\(docs|tests)\\' } |
            Sort-Object FullName |
            ForEach-Object {
                [void]$builder.AppendLine((Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8))
            }

        return $builder.ToString()
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Assert-FileNotExists {
    param([string]$Path, [string]$Message)

    if (Test-Path -LiteralPath (Join-Path $Root $Path)) {
        $failures.Add("$Message ($Path)")
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

Assert-FileNotExists "Jobs/Machinist/Resolvers/OffGCD/MachinistDismantleResolver.cs" "Dismantle must not be an automatic OffGCD resolver"
Assert-FileNotExists "Jobs/Machinist/Resolvers/OffGCD/SlotResolver_OffGCD_Dismantle.cs" "Dismantle must not keep the old automatic OffGCD resolver"

Assert-NotContains "Jobs/Machinist/Resolvers" "Dismantle|AutoDismantle|GetDismantleOffGcd" "Dismantle must not be part of automatic resolver rotation"
Assert-NotContains "Jobs/Machinist/MachinistRotationEntry.cs" "DismantleResolver|AutoDismantle|GetDismantleOffGcd" "Rotation must not register automatic Dismantle"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "Dismantle|AutoDismantle" "Dismantle must not be exposed as a persistent QT"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "GetDismantleOffGcd|AutoDismantle|ActionId\.Dismantle" "SpellHelper must not auto-cast Dismantle"

Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'AddQtHotkey\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*new\s+HotkeyResolver_NormalSpell\(ActionId\.Dismantle,\s*"[^"]*\p{IsCJKUnifiedIdeographs}[^"]*"\)\)' "UI must keep Dismantle as an explicit Chinese hotkey"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" 'MachinistHotkeyAction\.Dismantle => TargetAbility\(ActionId\.Dismantle,\s*"[^"]*\p{IsCJKUnifiedIdeographs}[^"]*"\)' "Timeline hotkey trigger must support explicit Dismantle"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" 'MachinistHotkeyAction\.Dismantle => "[^"]*\p{IsCJKUnifiedIdeographs}[^"]*。"' "Timeline hotkey trigger must describe explicit Dismantle in Chinese"
Assert-Contains "docs/DEVELOPMENT.md" "Dismantle remains explicit hotkey/timeline control" "Development docs must record Dismantle as explicit-only control"
Assert-Contains "Jobs/Machinist/docs/execution_axis_variables.md" "Dismantle" "Execution-axis authoring docs must expose Dismantle through KairoMCHHotkey"

if ($failures.Count -gt 0) {
    Write-Host "Machinist explicit Dismantle validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist explicit Dismantle validation passed."
