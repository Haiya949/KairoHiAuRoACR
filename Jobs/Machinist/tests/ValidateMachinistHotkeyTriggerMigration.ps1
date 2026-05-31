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

Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "class TriggerAction_Hotkey : ITriggerAction" "MCH must expose a HiAuRo trigger action for timeline hotkeys"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "\[TriggerDisplay\(" "Hotkey trigger must use HiAuRo trigger metadata"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" '\[TriggerTypeName\("KairoMCHHotkey"\)\]' "Hotkey trigger must have a stable HiAuRo type discriminator"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "public MachinistHotkeyAction Key \{ get; set; \}" "Hotkey trigger must expose a serializable enum key"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "public void Draw\(IUiBuilder builder\)" "Hotkey trigger must use HiAuRo IUiBuilder"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "builder\.AddDropdown" "Hotkey trigger must declare dropdown UI"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "HotkeyHelper\.ExecuteById\(MachinistHotkeyIds\.Potion\)" "Potion hotkey request must go through the registered HiAuRo hotkey resolver"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "SlotHelper\.Enqueue" "Non-potion timeline hotkeys must enqueue a HiAuRo Slot"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "SpellType\.Ability" "Hotkey trigger spells must be abilities"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "using ActionId = HiAuRo\.Helper\.MCHHelper\.EN\.Skills;" "Hotkey trigger must use Helper MCH IDs"
Assert-NotContains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "AEAssist|ImGui|JobViewWindow|MachinistActionId|UseActionManager|TimelineController|AI\.Instance" "Hotkey trigger must not leak old plugin APIs or local IDs"

Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" "class TriggerAction_Potion : ITriggerAction" "MCH must expose a dedicated HiAuRo trigger action for potion requests"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" "\[TriggerDisplay\(" "Potion trigger must use HiAuRo trigger metadata"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" '\[TriggerTypeName\("KairoMCHPotion"\)\]' "Potion trigger must have a stable HiAuRo type discriminator"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" "HotkeyHelper\.ExecuteById\(MachinistHotkeyIds\.Potion\)" "Potion trigger must execute the registered HiAuRo potion hotkey"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" "public void Draw\(IUiBuilder builder\)" "Potion trigger must use HiAuRo IUiBuilder"
Assert-NotContains "Jobs/Machinist/Triggers/TriggerAction_Potion.cs" "AEAssist|ImGui|JobViewWindow|MachinistActionId|UseActionManager|TimelineController|AI\.Instance|QTKey\.UsePotion" "Potion trigger must not leak old plugin APIs, local IDs, or old UsePotion QT"

Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "new TriggerAction_Hotkey\(\)" "Rotation must register MCH hotkey trigger action"
Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "new TriggerAction_Potion\(\)" "Rotation must register MCH potion trigger action"
Assert-Contains "Jobs/Machinist/Triggers/MachinistHotkeyIds.cs" "public const string Potion = " "MCH must centralize the stable potion hotkey id"
Assert-Contains "Jobs/Machinist/Triggers/MachinistHotkeyIds.cs" "hk_" "MCH potion hotkey id must use HiAuRo's hotkey id prefix"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'new HotkeyResolver_Potion\(\)' "MCH UI must register the potion hotkey resolver"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "UsePotion" "MCH must not restore old UsePotion QT; potion remains a hotkey"

Assert-Contains "docs/DEVELOPMENT.md" "KairoMCHHotkey" "Development docs must record the hotkey trigger discriminator"
Assert-Contains "docs/DEVELOPMENT.md" "KairoMCHPotion" "Development docs must record the potion trigger discriminator"
Assert-Contains "docs/DEVELOPMENT.md" "MachinistHotkeyIds.Potion" "Development docs must describe the potion hotkey id contract"

if ($failures.Count -gt 0) {
    Write-Host "Machinist hotkey trigger migration validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist hotkey trigger migration validation passed."
