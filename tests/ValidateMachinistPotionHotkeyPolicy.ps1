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

$hotkeyTrigger = Read-File "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs"
$potionTrigger = Read-File "Jobs/Machinist/Triggers/TriggerAction_Potion.cs"

Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'AddQtHotkey\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*new\s+HotkeyResolver_Potion\(\)\)' "Potion must be a Chinese-labeled UI hotkey"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" 'UsePotion|QTKey\.Potion|QTKey\.UsePotion|AddQtToggle\([^\n]*Potion|AddQtToggle\([^\n]*UsePotion' "Potion must not be exposed as a persistent QT"
Assert-NotContains "Jobs/Machinist/QTKey.cs" 'Potion|UsePotion' "QT catalog must not contain potion keys"

Assert-Contains "Jobs/Machinist/Triggers/MachinistHotkeyIds.cs" 'public const string Potion = "hk_[^"]*\p{IsCJKUnifiedIdeographs}[^"]*";' "Potion hotkey id must point at the registered Chinese UI hotkey"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" '\[TriggerTypeName\("KairoMCHPotion"\)\]' "Dedicated potion trigger must keep its stable discriminator"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" 'HotkeyHelper\.ExecuteById\(MachinistHotkeyIds\.Potion\)' "Dedicated potion trigger must request the registered hotkey"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" 'AddLabel\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*"\)' "Potion trigger authoring UI must show Chinese text"
Assert-NotContains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" 'SlotHelper\.Enqueue|new Slot\(|QTKey\.UsePotion|UsePotion|SpellType\.Ability' "Dedicated potion trigger must not enqueue a spell or restore old UsePotion QT"

Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" 'MachinistHotkeyAction\.Potion' "Generic hotkey trigger must include Potion"
Assert-InOrder $hotkeyTrigger @(
    "if (Key == MachinistHotkeyAction.Potion)",
    "HotkeyHelper.ExecuteById(MachinistHotkeyIds.Potion);",
    "return true;",
    "var spell = CreateSpell(Key);",
    "SlotHelper.Enqueue(slot);"
) "Generic hotkey trigger must handle Potion through HotkeyHelper before non-potion Slot enqueue"
Assert-NotContains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" 'QTKey\.UsePotion|UsePotion' "Generic hotkey trigger must not restore the old potion QT gate"

Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" 'new TriggerAction_Hotkey\(\)' "Rotation must register the generic hotkey trigger"
Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" 'new TriggerAction_Potion\(\)' "Rotation must register the dedicated potion trigger"
Assert-Contains "docs/DEVELOPMENT.md" "Potion remains explicit hotkey/timeline request" "Development docs must record potion as explicit hotkey/timeline request"
Assert-Contains "docs/timeline_variables.md" "KairoMCHPotion" "Timeline docs must expose the dedicated potion trigger"
Assert-Contains "docs/timeline_variables.md" 'MachinistHotkeyIds\.Potion' "Timeline docs must describe the shared potion hotkey id"
Assert-NotContains "Jobs/Machinist" 'AEAssist|JobViewWindow|MachinistActionId|QTKey\.UsePotion|UsePotion QT' "Potion migration must not leak old plugin APIs, local IDs, or old UsePotion QT"

if ($failures.Count -gt 0) {
    Write-Host "Machinist potion hotkey validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist potion hotkey validation passed."
