param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Assert-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath (Join-Path $Root $Path))) {
        $failures.Add("Missing file: $Path")
    }
}

function Assert-FileNotExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (Test-Path -LiteralPath (Join-Path $Root $Path)) {
        $failures.Add("$Message ($Path)")
    }
}

function Read-File {
    param([string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
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

function Assert-InOrder {
    param(
        [string]$Path,
        [string[]]$Tokens,
        [string]$Message
    )

    $text = Read-File $Path
    $position = -1

    foreach ($token in $Tokens) {
        $next = $text.IndexOf($token, $position + 1, [System.StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message; missing or out of order token: $token ($Path)")
            return
        }

        $position = $next
    }
}

function Get-MethodText {
    param(
        [string]$Path,
        [string]$MethodName
    )

    $text = Read-File $Path
    $match = [regex]::Match($text, "(?m)^\s*(public|private)\s+static\s+[^`r`n]*\s+$MethodName\s*\(")
    if (-not $match.Success) {
        $failures.Add("Missing method: $MethodName ($Path)")
        return ""
    }

    $braceStart = $text.IndexOf('{', $match.Index)
    if ($braceStart -lt 0) {
        $failures.Add("Missing method body: $MethodName ($Path)")
        return ""
    }

    $depth = 0
    for ($i = $braceStart; $i -lt $text.Length; $i++) {
        if ($text[$i] -eq '{') {
            $depth++
        }
        elseif ($text[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $text.Substring($match.Index, $i - $match.Index + 1)
            }
        }
    }

    $failures.Add("Unclosed method body: $MethodName ($Path)")
    return ""
}

$requiredFiles = @(
    "Jobs/BlackMage/BlackMageRotationEntry.cs",
    "Jobs/BlackMage/BlackMageRotationEventHandler.cs",
    "Jobs/BlackMage/BlackMageRotationUi.cs",
    "Jobs/BlackMage/BlackMageSettings.cs",
    "Jobs/BlackMage/BlackMageSpellHelper.cs",
    "Jobs/BlackMage/BlackMageTargetResolver.cs",
    "Jobs/BlackMage/QTKey.cs",
    "Jobs/BlackMage/Data/BlackMageActionId.cs",
    "Jobs/BlackMage/Data/BlackMageStatusId.cs",
    "Jobs/BlackMage/Opener/BlackMageOpener.cs",
    "Jobs/BlackMage/Resolvers/GCD/BlackMageAoeGcdResolver.cs",
    "Jobs/BlackMage/Resolvers/GCD/BlackMageSingleTargetGcdResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageAmplifierResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageLeyLinesResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageManafontResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageSwiftcastResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageTransposeResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageTriplecastResolver.cs"
)

foreach ($file in $requiredFiles) {
    Assert-File $file
}

Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'AuthorName\s*\{\s*get;\s*\}\s*=\s*"Kairo"' "BLM entry author must be Kairo"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'UseCustomUi\s*\{\s*get;\s*\}\s*=\s*false' "BLM must use HiAuRo native UI"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'TargetJobs\s*\{\s*get;\s*\}\s*=\s*\[HiAuRoJob\.BLM\]' "BLM entry must target BLM"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'TargetJob\s*=\s*HiAuRoJob\.BLM' "BLM rotation target job must match entry"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'AcrType\s*=\s*AcrType\.PvE' "BLM rotation must be PvE"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'MinLevel\s*=\s*70' "BLM rotation should reserve the high-end level band from 70 onward"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'MaxLevel\s*=\s*100' "BLM rotation must support current level 100"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'Opener\s*=\s*new\s+BlackMageOpener\(\)' "BLM rotation must register the level 100 opener"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'EventHandler\s*=\s*new\s+BlackMageRotationEventHandler\(\)' "BLM rotation event handler must not receive temporary target/opener polling hooks"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'TargetResolvers\s*=\s*\[targetResolver\]' "BLM rotation must register the same target resolver used by lifecycle hooks"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'ISettingsProvider<BlackMageSettings>' "BLM settings must be HiAuRo-native"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'BlackMageOpenerController|_targetResolver|TargetSelectionRetryMs|OpenerPollingRetryMs|TargetSelectionPolling|StartTargetSelectionPolling|StopTargetSelectionPolling|RestartTargetSelectionPolling|StartOpenerPolling|StopOpenerPolling|RestartOpenerPolling|OnTargetSelectionTick|OnOpenerTick|Coroutine\.Instance\.WaitAsync|TrySelectTarget\(\)|TryQueueCountdownActions|RuntimeCore\.IsRunning|MainControlHelper\.IsPaused' "BLM entry must not keep ACR-side target/opener polling bridges"

Assert-InOrder "Jobs/BlackMage/BlackMageRotationEntry.cs" @(
    "BlackMageLeyLinesResolver",
    "BlackMageTriplecastResolver",
    "BlackMageSwiftcastResolver",
    "BlackMageManafontResolver",
    "BlackMageTransposeResolver",
    "BlackMageAmplifierResolver",
    "BlackMageAoeGcdResolver",
    "BlackMageSingleTargetGcdResolver"
) "BLM resolver priority must keep planned burst/movement oGCDs before the GCD loop"

Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'class\s+BlackMageOpener\s*:\s*IOpener' "BLM opener must implement HiAuRo IOpener"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'public\s+uint\s+Level\s*=>\s*100' "BLM opener must be the level 100 opener"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'handler\.AddAction\(4_000,\s*BlackMageActionId\.FireIII,\s*SpellTargetType\.Target\)' "BLM opener must register 4000ms prepull Fire III through the latest HiAuRo CountDownHandler"
Assert-InOrder "Jobs/BlackMage/Opener/BlackMageOpener.cs" @(
    "BuildHighThunderSlot",
    "BuildSwiftAmplifierSlot",
    "BuildFirstFireIvSlot",
    "BuildLeyLinesSlot"
) "BLM opener must start with High Thunder, Swiftcast+Amplifier, Fire IV, and Ley Lines"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'AddDelaySpell\(450,\s*SelfAbility\(BlackMageActionId\.Swiftcast\)\)' "BLM opener must delay Swiftcast before the Amplifier second weave"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'Add2NdWindowAbility\(SelfAbility\(BlackMageActionId\.Amplifier\)\)' "BLM opener must use the second weave window for Amplifier"
Assert-FileNotExists "Jobs/BlackMage/Opener/BlackMageOpenerController.cs" "BLM must not keep a Kairo-side opener polling/controller bridge after returning to native IOpener/CountDownHandler"

Assert-Contains "Jobs/BlackMage/BlackMageRotationUi.cs" 'AddBuiltinQt\(BuiltinQt\.Burst,\s*true\)' "BLM UI must expose Burst"
Assert-Contains "Jobs/BlackMage/BlackMageRotationUi.cs" 'AddBuiltinQt\(BuiltinQt\.Hold,\s*false\)' "BLM UI must expose Hold"
Assert-Contains "Jobs/BlackMage/BlackMageRotationUi.cs" 'AddTab\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*"\)' "BLM UI tab must be Chinese"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationUi.cs" 'TargetSelectionOptions|_settings\.TargetSelection|目标选择|手动目标|最近敌人' "BLM UI must not expose target selection controls after Runtime owns target selection"
Assert-InOrder "Jobs/BlackMage/BlackMageRotationUi.cs" @(
    "QTKey.ForceBurst",
    "QTKey.ForbidBurst",
    "QTKey.DumpResources",
    "QTKey.HoldPolyglot",
    "QTKey.DumpPolyglot",
    "QTKey.HoldTriplecast",
    "QTKey.DumpTriplecast",
    "QTKey.HoldManafont",
    "QTKey.DumpManafont",
    "QTKey.HoldLeyLines",
    "QTKey.DumpLeyLines",
    "QTKey.ForceMovement",
    "QTKey.ForbidMovement",
    "QTKey.Aoe"
) "BLM high-end QT controls must expose burst, resource, movement, and AoE gates"
Assert-NotContains "Jobs/BlackMage/QTKey.cs" 'public const string (Stop|Burst|HighEndMode|UsePotion|PrepullFireIII)\b' "BLM must use built-in Hold/Burst and settings/hotkeys, not old AEAssist QT keys"

Assert-Contains "Jobs/BlackMage/BlackMageSettings.cs" 'FirstBurstAnchorMs\s*=\s*7_000' "BLM settings must keep the old high-end 3G burst anchor"
Assert-Contains "Jobs/BlackMage/BlackMageSettings.cs" 'ThunderRefreshMs\s*=\s*3_000' "BLM settings must keep Thunder refresh timing"
Assert-Contains "Jobs/BlackMage/BlackMageSettings.cs" 'PolyglotDumpStacks\s*=\s*2' "BLM settings must keep Polyglot dump threshold"
Assert-NotContains "Jobs/BlackMage/BlackMageSettings.cs" 'TargetSelectionManual|TargetSelectionNearestEnemy|TargetSelectionOptions|public\s+string\s+TargetSelection' "BLM target selection must not remain an ACR persistent setting after Runtime owns target selection"
Assert-NotContains "Jobs/BlackMage/BlackMageSettings.cs" 'PrepullFireIIICountdownMs|CountdownPullActionQueueLeadMs|PostCountdownPullRecoveryMs' "BLM settings must not keep countdown bridge timing settings"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'var\s+targetResolver\s*=\s*new\s+BlackMageTargetResolver\(\)' "BLM Rotation must create one Runtime-owned target resolver without ACR UI settings"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'TargetResolvers\s*=\s*\[targetResolver\]' "BLM Rotation must wire the Runtime-owned target resolver"
Assert-Contains "Jobs/BlackMage/BlackMageTargetResolver.cs" 'TargetResolver_' "BLM target resolver must delegate nearest-enemy selection to HiAuRo built-ins"
Assert-NotContains "Jobs/BlackMage/BlackMageTargetResolver.cs" 'BlackMageSettings|TargetSelection' "BLM target resolver must not depend on ACR target-selection settings"
Assert-NotContains "Jobs/BlackMage/BlackMageTargetResolver.cs" 'TrySelectTarget\(\)|global::HiAuRo\.Data\.Objects\.Refresh\(\)|OmenTools\.OmenService\.TargetManager\.Target' "BLM target resolver must not self-assign targets outside Runtime TargetResolvers"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationEventHandler.cs" 'BlackMageTargetResolver|TrySelectTarget\(\)|restartTargetSelectionPolling|RestartTargetSelectionPolling' "BLM event handler must not run ACR-side target selection hooks"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEventHandler.cs" 'Slot\?\s+BeforeSpell\(Slot\s+slot\)' "BLM event handler must implement the current HiAuRo v0.1.79 BeforeSpell signature"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationEventHandler.cs" 'void\s+BeforeSpell\(Slot\s+slot,\s*Spell\s+spell\)' "BLM event handler must not keep the old BeforeSpell signature that prevents ACR reflection loading"

Assert-Contains "Jobs/BlackMage/Data/BlackMageActionId.cs" 'public const uint HighThunder = 36986;' "BLM action catalog must include High Thunder"
Assert-Contains "Jobs/BlackMage/Data/BlackMageActionId.cs" 'public const uint FlareStar = 36989;' "BLM action catalog must include Flare Star"
Assert-Contains "Jobs/BlackMage/Data/BlackMageActionId.cs" 'public const uint Amplifier = 25796;' "BLM action catalog must include Amplifier"
Assert-Contains "Jobs/BlackMage/Data/BlackMageStatusId.cs" 'public const uint Thunderhead = 3870;' "BLM status catalog must include Thunderhead"
Assert-Contains "Jobs/BlackMage/Data/BlackMageStatusId.cs" 'public const uint HighThunder = 3871;' "BLM status catalog must include High Thunder DoT"

$helperPath = "Jobs/BlackMage/BlackMageSpellHelper.cs"
$singleTargetText = Get-MethodText -Path $helperPath -MethodName "GetSingleTargetGcd"
$astralText = Get-MethodText -Path $helperPath -MethodName "GetAstralFireGcd"
$umbralText = Get-MethodText -Path $helperPath -MethodName "GetUmbralIceGcd"
$polyglotText = Get-MethodText -Path $helperPath -MethodName "GetPolyglotGcd"
$manafontText = Get-MethodText -Path $helperPath -MethodName "GetManafontOffGcd"

if ($singleTargetText -notmatch 'GetAstralFireGcd' -or $singleTargetText -notmatch 'GetUmbralIceGcd' -or $singleTargetText -notmatch 'GetNeutralElementGcd') {
    $failures.Add("BLM single-target GCD must route neutral, Astral Fire, and Umbral Ice states through dedicated helpers")
}

foreach ($pattern in @(
    'GetThunderGcd',
    'GetFireParadoxGcd',
    'GetPolyglotGcd\(false\)',
    'GetFlareStarGcd',
    'GetDespairGcd',
    'BlackMageActionId\.FireIV'
)) {
    if ($astralText -notmatch $pattern) {
        $failures.Add("BLM Astral Fire loop missing policy token: $pattern")
    }
}

foreach ($pattern in @(
    'GetUmbralRecoveryGcd',
    'GetThunderGcd',
    'GetUmbralParadoxGcd',
    'GetUmbralFireEntryGcd'
)) {
    if ($umbralText -notmatch $pattern) {
        $failures.Add("BLM Umbral Ice loop missing policy token: $pattern")
    }
}

if ($polyglotText -notmatch 'ShouldUsePolyglotForBurstAnchor' -or $polyglotText -notmatch 'ShouldUsePolyglotForDumpStacks') {
    $failures.Add("BLM Polyglot spending must respect burst anchors and dump thresholds")
}

if ($manafontText -notmatch 'ShouldUseOpeningManafontBeforeDespair' -or $manafontText -notmatch 'ShouldClipManafontToContinueAstralFire') {
    $failures.Add("BLM Manafont policy must support the 5+7 opener tail and emergency fire continuation")
}

Assert-Contains $helperPath 'return\s+QTHelper\.IsEnabled\(BuiltinQt\.Hold\);' "BLM stop policy must use built-in Hold"
Assert-Contains $helperPath 'BLMHelper\.' "BLM helper must use HiAuRo.Helper BLM gauge accessors"
Assert-Contains $helperPath 'Data\.Me\.Object.*CurrentMp' "BLM helper must read MP through HiAuRo Data.Me.Object"
Assert-Contains $helperPath 'Spell\.IsReadyWithCanCast\(\)' "BLM helper must use HiAuRo Spell readiness checks"
Assert-Contains $helperPath 'GetAoeGcd' "BLM helper must keep a high-end AoE branch for later high-difficulty multi-target use"
Assert-NotContains $helperPath 'BlackMageOpenerController|AEAssist|Core\.Resolve|JobViewWindow|UseActionManager|Kairo\.BlackMage' "BLM HiAuRo port must not leak old AEAssist APIs or Kairo-side opener bridges"

if ($failures.Count -gt 0) {
    Write-Host "Black Mage port validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Black Mage port validation passed."
