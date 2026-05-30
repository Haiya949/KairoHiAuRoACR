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
        $failures.Add("$Message ($Path)")
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
        $failures.Add("$Message ($Path)")
    }
}

$requiredFiles = @(
    "Jobs/Ninja/NinjaRotationEntry.cs",
    "Jobs/Ninja/NinjaRotationEventHandler.cs",
    "Jobs/Ninja/NinjaRotationUi.cs",
    "Jobs/Ninja/NinjaSettings.cs"
)

foreach ($file in $requiredFiles) {
    [void](Read-File $file)
}

Assert-Contains "Jobs/Ninja/NinjaRotationEntry.cs" 'AuthorName\s*\{\s*get;\s*\}\s*=\s*"Kairo"' "NIN entry author must be Kairo"
Assert-Contains "Jobs/Ninja/NinjaRotationEntry.cs" 'UseCustomUi\s*\{\s*get;\s*\}\s*=\s*false' "NIN must use HiAuRo native UI"
Assert-Contains "Jobs/Ninja/NinjaRotationEntry.cs" 'TargetJobs\s*\{\s*get;\s*\}\s*=\s*\[HiAuRoJob\.NIN\]' "NIN entry must target NIN"
Assert-Contains "Jobs/Ninja/NinjaRotationEntry.cs" 'TargetJob\s*=\s*HiAuRoJob\.NIN' "NIN rotation target job must match entry"
Assert-Contains "Jobs/Ninja/NinjaRotationEntry.cs" 'EventHandler\s*=\s*new\s+NinjaRotationEventHandler\(Settings\)' "NIN rotation must register the Ten Chi Jin diagnostic event handler"
Assert-Contains "Jobs/Ninja/NinjaRotationEntry.cs" 'Description\s*=\s*"Kairo HiAuRo NIN Ten Chi Jin status diagnostic"' "NIN diagnostic description should be explicit"
Assert-Contains "Jobs/Ninja/NinjaRotationEntry.cs" 'ISettingsProvider<NinjaSettings>' "NIN settings must be HiAuRo-native"

Assert-Contains "Jobs/Ninja/NinjaRotationUi.cs" 'AddMainControl\(\)' "NIN UI must expose the main ACR control"
Assert-Contains "Jobs/Ninja/NinjaRotationUi.cs" 'AddBuiltinQt\(BuiltinQt\.Hold,\s*false\)' "NIN UI must expose Hold"
Assert-Contains "Jobs/Ninja/NinjaRotationUi.cs" 'AddTab\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*"\)' "NIN UI tab must be Chinese"
Assert-Contains "Jobs/Ninja/NinjaRotationUi.cs" 'AddCheckbox\([^\r\n]*LogTenChiJinStatus' "NIN UI must expose the diagnostic logging switch"
Assert-Contains "Jobs/Ninja/NinjaRotationUi.cs" 'AddIntInput\([^\r\n]*LogIntervalMs' "NIN UI must expose the diagnostic interval"

Assert-Contains "Jobs/Ninja/NinjaRotationEventHandler.cs" 'NINHelper\.HasTenChiJin' "NIN diagnostic must read NINHelper.HasTenChiJin"
Assert-Contains "Jobs/Ninja/NinjaRotationEventHandler.cs" 'Hi\.Print\(\$"\[Kairo NIN\] HasTenChiJin=\{hasTenChiJin\}' "NIN diagnostic must print the helper status value to chat"
Assert-NotContains "Jobs/Ninja/NinjaRotationEventHandler.cs" 'Hi\.Info\(' "NIN diagnostic should use direct chat print, not plugin info log"
Assert-Contains "Jobs/Ninja/NinjaRotationEventHandler.cs" 'OnBattleUpdate\(int battleTimeMs\)' "NIN diagnostic must run from the battle update callback"
Assert-Contains "Jobs/Ninja/NinjaRotationEventHandler.cs" 'NinjaSettings' "NIN diagnostic interval and enable switch must come from settings"
Assert-Contains "Jobs/Ninja/NinjaRotationEventHandler.cs" 'Slot\?\s+BeforeSpell\(Slot\s+slot\)' "NIN event handler must implement the current HiAuRo BeforeSpell signature"

Assert-Contains "Jobs/Ninja/NinjaSettings.cs" 'public\s+bool\s+LogTenChiJinStatus\s*=\s*true' "NIN diagnostic logging should be enabled by default"
Assert-Contains "Jobs/Ninja/NinjaSettings.cs" 'public\s+int\s+LogIntervalMs\s*=\s*1_000' "NIN diagnostic logging should default to one line per second"

Assert-NotContains "Jobs/Ninja/NinjaRotationEntry.cs" 'AEAssist|JobViewWindow|SlotResolverData\(.*new|Kairo\.Ninja' "NIN entry must not leak old AEAssist APIs"
Assert-NotContains "Jobs/Ninja/NinjaRotationEventHandler.cs" 'Console\.WriteLine|Debug\.WriteLine' "NIN diagnostic should use HiAuRo logging, not console output"

if ($failures.Count -gt 0) {
    Write-Host "Ninja Ten Chi Jin diagnostic validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Ninja Ten Chi Jin diagnostic validation passed."
