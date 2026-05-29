using KairoHiAuRoACR.Jobs.Machinist.Data;

namespace KairoHiAuRoACR.Jobs.Machinist;

public static class MachinistSpellHelper
{
    private const int OpeningBurstWindowMs = 20_000;
    private const int BioblasterRefreshSeconds = 3;
    private const int ReassembleSequenceLookaheadPaddingMs = 250;
    private const int QueenActiveEstimateMs = 15_000;
    private const int WildfirePackageDurationMs = 10_000;
    private const int HyperchargeBeforeWildfireWindowMs = 4_000;
    private const int WildfireBurstPackageLookaheadMs = 40_000;
    private const int PreWildfireOvercapHeatThreshold = 100;
    private const int PreWildfireOvercapHyperchargeMinCooldownMs = 20_000;
    private const int PreWildfireOvercapHyperchargeMaxCooldownMs = 30_000;
    private const int ReassembleChargePressureMs = 8_000;
    private const int ReassembleRechargeMs = 55_000;
    private const int ReassembleBurstSafetyMs = 3_000;
    private const int ReassembleExcavatorReserveMs = 8_000;

    private static readonly uint[] StrongGcdPriority =
    [
        MachinistActionId.Excavator,
        MachinistActionId.FullMetalField,
        MachinistActionId.ChainSaw,
        MachinistActionId.AirAnchor,
        MachinistActionId.Drill,
    ];

    private static readonly uint[] ReassembleTargetPriority =
    [
        MachinistActionId.Excavator,
        MachinistActionId.ChainSaw,
        MachinistActionId.Drill,
        MachinistActionId.AirAnchor,
    ];

    private static MachinistSettings _settings = new();
    private static int _currentBattleTimeMs;
    private static int? _firstPostOpenerBurstAnchorMs;
    private static int? _lastWildfirePackageStartedAtMs;
    private static int? _lastHyperchargePackageStartedAtMs;
    private static int _robotActiveUntilMs;
    private static readonly Dictionary<uint, int> CombatActionLastUsedAtMs = new();
    private static readonly Dictionary<uint, int> CombatActionUseCounts = new();

    public static void Configure(MachinistSettings settings)
    {
        _settings = settings;
    }

    public static void Reset()
    {
        _currentBattleTimeMs = 0;
        _firstPostOpenerBurstAnchorMs = null;
        _lastWildfirePackageStartedAtMs = null;
        _lastHyperchargePackageStartedAtMs = null;
        _robotActiveUntilMs = 0;
        CombatActionLastUsedAtMs.Clear();
        CombatActionUseCounts.Clear();
    }

    public static void UpdateBattleTime(int battleTimeMs)
    {
        var next = Math.Max(0, battleTimeMs);
        if (_currentBattleTimeMs > 5_000 && next <= 1_000)
            Reset();

        _currentBattleTimeMs = next;
    }

    public static void RecordCombatActionUse(uint actionId)
    {
        TrackBurstPackageAction(actionId);
        CombatActionUseCounts[actionId] = CombatActionUseCounts.GetValueOrDefault(actionId) + 1;
        CombatActionLastUsedAtMs[actionId] = _currentBattleTimeMs;

        if (actionId is MachinistActionId.AutomatonQueen or MachinistActionId.RookAutoturret)
            _robotActiveUntilMs = _currentBattleTimeMs + QueenActiveEstimateMs;

        if (actionId is MachinistActionId.QueenOverdrive or MachinistActionId.RookOverdrive or MachinistActionId.Detonator)
            _robotActiveUntilMs = 0;
    }

    public static void MarkCombatActionIssued(uint actionId)
    {
        TrackBurstPackageAction(actionId);
        CombatActionLastUsedAtMs[actionId] = _currentBattleTimeMs;
    }

    public static bool ShouldStopActions()
    {
        return QTHelper.IsEnabled(BuiltinQt.Hold) || QTHelper.IsEnabled(QTKey.Stop);
    }

    public static bool IsOverheated()
    {
        return HelperRuntime.HasStatus(MachinistStatusId.Overheated)
            || HelperRuntime.HasStatus(MachinistStatusId.Hypercharged);
    }

    public static bool IsRobotActive()
    {
        return _robotActiveUntilMs > _currentBattleTimeMs
            || HelperRuntime.RecentlyUsedSpell(MachinistActionId.AutomatonQueen, QueenActiveEstimateMs)
            || HelperRuntime.RecentlyUsedSpell(MachinistActionId.RookAutoturret, QueenActiveEstimateMs);
    }

    public static int GetHeat() => MCHHelper.HeatGauge;

    public static int GetBattery() => MCHHelper.BatteryGauge;

    public static bool CanWeave(int minGcdCooldownMs = 650)
    {
        return GCDHelper.GetGCDCooldown() >= minGcdCooldownMs;
    }

    public static Spell? GetAoeGcd()
    {
        if (!HasTarget() || !QTHelper.IsEnabled(QTKey.Aoe))
            return null;

        var fillerActionId = LevelAtLeast(82) ? MachinistActionId.Scattergun : MachinistActionId.SpreadShot;
        if (GetEnemyCountNearTarget(5f) < GetAoeFillerTargetThreshold(fillerActionId))
            return null;

        if (IsOverheated())
        {
            var autoCrossbow = TargetSpell(MachinistActionId.AutoCrossbow);
            if (autoCrossbow.IsReadyWithCanCast())
                return autoCrossbow;
        }

        if (ShouldUseBioblasterOnAoe())
            return TargetSpell(MachinistActionId.Bioblaster);

        var filler = TargetSpell(fillerActionId);
        return filler.IsReadyWithCanCast() ? filler : null;
    }

    public static Spell? GetOverheatedGcd()
    {
        if (!HasTarget() || HasReassembled() || !IsOverheated())
            return null;

        var actionId = LevelAtLeast(92) ? MachinistActionId.BlazingShot : MachinistActionId.HeatBlast;
        var spell = TargetSpell(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetStrongGcd()
    {
        if (!HasTarget() || IsOverheated())
            return null;

        if (HasReassembled())
            return GetReassembledStrongGcd();

        foreach (var actionId in StrongGcdPriority)
        {
            var spell = GetReadyStrongGcd(actionId);
            if (spell is not null)
                return spell;
        }

        return GetLowLevelHotShotGcd();
    }

    public static Spell? GetBaseComboGcd()
    {
        if (!HasTarget())
            return null;

        var lastCombo = HelperRuntime.GetLastComboSpellId();
        var baseAction = lastCombo switch
        {
            MachinistActionId.SplitShot or MachinistActionId.HeatedSplitShot => MachinistActionId.SlugShot,
            MachinistActionId.SlugShot or MachinistActionId.HeatedSlugShot => MachinistActionId.CleanShot,
            _ => MachinistActionId.SplitShot,
        };

        var currentAction = HelperRuntime.GetActionChange(baseAction);
        var spell = TargetSpell(currentAction);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetWildfireOffGcd()
    {
        if (!HasTarget() || !CanUseBurstResource() || !CanWeave())
            return null;

        if (ShouldDelayWildfireUntilHyperchargeForBurstPackage())
            return null;

        var spell = TargetAbility(MachinistActionId.Wildfire);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetBarrelStabilizerOffGcd()
    {
        if (!HasTarget() || !CanUseBurstResource() || !CanWeave())
            return null;

        var spell = SelfAbility(MachinistActionId.BarrelStabilizer);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetHyperchargeOffGcd()
    {
        if (!HasTarget() || !CanWeave() || IsOverheated() || HasReassembled())
            return null;

        var hypercharge = SelfAbility(MachinistActionId.Hypercharge);
        if (GetHeat() < 50 || !hypercharge.IsReadyWithCanCast())
            return null;

        var shouldUseActiveWildfireHypercharge = HasActiveWildfirePackage();
        var shouldSpendHeatForBudget = ShouldSpendHeatByBudget();

        if (!shouldUseActiveWildfireHypercharge && ShouldFinishCleanShotComboBeforeHypercharge())
            return null;

        if (!shouldUseActiveWildfireHypercharge && ShouldDelayHyperchargeForToolCooldown())
            return null;

        if (!shouldUseActiveWildfireHypercharge
            && HasStrongGcdSoon(_settings.StrongGcdLookaheadMs)
            && !shouldSpendHeatForBudget
            && GetHeat() < _settings.HeatOvercapThreshold)
            return null;

        if (shouldUseActiveWildfireHypercharge || shouldSpendHeatForBudget || ShouldUseDumpResources() || IsForceBurstActive())
            return hypercharge;

        if (CanUseBurstResource())
            return hypercharge;

        if (CanUseResourceForOvercap() && GetHeat() >= _settings.HeatOvercapThreshold)
            return hypercharge;

        return null;
    }

    public static Spell? GetQueenOffGcd()
    {
        if (!HasTarget() || IsRobotActive() || !LevelAtLeast(40))
            return null;

        if (GetBattery() < _settings.BatteryBurstSpendThreshold)
            return null;

        var shouldSpendBatteryForOvercap = GetBattery() >= _settings.BatteryOvercapSpendThreshold;
        var minWeaveMs = shouldSpendBatteryForOvercap ? 650 : 800;
        if (!CanWeave(minWeaveMs))
            return null;

        if (ShouldUseDumpResources() || IsForceBurstActive() || shouldSpendBatteryForOvercap || CanUseBurstResource())
            return BuildQueenSpell();

        return null;
    }

    public static Spell? GetQueenOverdriveOffGcd()
    {
        if (!IsRobotActive() || !ShouldUseDumpResources() || !CanWeave())
            return null;

        var spell = SelfAbility(MachinistActionId.QueenOverdrive);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetReassembleOffGcd()
    {
        if (!HasTarget() || !CanWeave() || HasReassembled() || IsOverheated())
            return null;

        var reassemble = SelfAbility(MachinistActionId.Reassemble);
        if (!reassemble.IsReadyWithCanCast())
            return null;

        var targetActionId = GetReassembleTargetActionId(GetReassembleSequenceLookaheadMs());
        if (targetActionId is null)
            return null;

        if (!WillNextGcdConsumeReassembleTarget(targetActionId.Value))
            return null;

        return reassemble;
    }

    public static void MarkReassembleOffGcdIssued()
    {
        MarkCombatActionIssued(MachinistActionId.Reassemble);
    }

    public static Spell? GetGaussRoundOffGcd()
    {
        if (!HasTarget() || !CanWeave())
            return null;

        var spell = PickGaussRoundOrRicochet();
        if (spell is null)
            return null;

        if (IsOverheated() || ShouldUseDumpResources() || spell.Charges >= 2)
            return spell;

        if (TargetSpell(MachinistActionId.Wildfire).IsReadyWithCanCast() && CanUseBurstResource())
            return null;

        return spell;
    }

    private static Spell TargetSpell(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Target);
    }

    private static Spell TargetAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Target) { Type = SpellType.Ability };
    }

    private static Spell SelfAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Self) { Type = SpellType.Ability };
    }

    private static bool HasTarget()
    {
        return global::HiAuRo.Data.Target.Current is not null;
    }

    private static bool LevelAtLeast(int level)
    {
        var currentLevel = HelperRuntime.GetCurrentLevel();
        return currentLevel <= 0 || currentLevel >= level;
    }

    private static bool HasReassembled()
    {
        return HelperRuntime.HasStatus(MachinistStatusId.Reassembled);
    }

    private static bool ShouldUseBioblasterOnAoe()
    {
        var spell = TargetSpell(MachinistActionId.Bioblaster);
        return spell.IsReadyWithCanCast()
            && (!HelperRuntime.HasStatusOnTarget(MachinistStatusId.Bioblaster)
                || HelperRuntime.GetStatusTimeLeftOnTarget(MachinistStatusId.Bioblaster) <= BioblasterRefreshSeconds);
    }

    private static int GetEnemyCountNearTarget(float range)
    {
        var nearTarget = HelperRuntime.GetEnemyCountNearTarget(range);
        return nearTarget > 0 ? nearTarget : HelperRuntime.GetNearbyEnemyCount(range);
    }

    private static int GetAoeFillerTargetThreshold(uint actionId)
    {
        return actionId == MachinistActionId.Scattergun ? 4 : 3;
    }

    private static Spell? GetReadyStrongGcd(uint actionId)
    {
        if (!IsStrongGcdAvailableByStatus(actionId))
            return null;

        var spell = TargetSpell(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static bool IsStrongGcdAvailableByStatus(uint actionId)
    {
        return actionId switch
        {
            MachinistActionId.Excavator => HelperRuntime.HasStatus(MachinistStatusId.ExcavatorReady),
            MachinistActionId.FullMetalField => HelperRuntime.HasStatus(MachinistStatusId.FullMetalMachinist),
            _ => true,
        };
    }

    private static Spell? GetLowLevelHotShotGcd()
    {
        if (LevelAtLeast(76))
            return null;

        var spell = TargetSpell(MachinistActionId.HotShot);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static Spell? GetReassembledStrongGcd()
    {
        foreach (var actionId in ReassembleTargetPriority)
        {
            var spell = GetReadyStrongGcd(actionId);
            if (spell is not null)
                return spell;
        }

        return GetLowLevelHotShotGcd();
    }

    private static bool CanUseBurstResource()
    {
        if (ShouldStopActions() || !HasTarget() || IsForbidBurstActive())
            return false;

        if (!QTHelper.IsEnabled(BuiltinQt.Burst))
            return false;

        if (ShouldUseDumpResources() || IsForceBurstActive())
            return true;

        if (ShouldUseTwoMinuteBurstPlan())
            return IsInTwoMinuteBurstWindow();

        return true;
    }

    private static bool CanUseResourceForOvercap()
    {
        return !ShouldStopActions()
            && HasTarget()
            && QTHelper.IsEnabled(BuiltinQt.Burst)
            && !IsForbidBurstActive();
    }

    private static bool ShouldUseTwoMinuteBurstPlan()
    {
        return QTHelper.IsEnabled(QTKey.HighEndMode)
            || _currentBattleTimeMs >= _settings.LongFightBurstPlanMs;
    }

    private static bool IsInTwoMinuteBurstWindow()
    {
        if (IsForceBurstActive())
            return true;

        if (_currentBattleTimeMs <= OpeningBurstWindowMs)
            return true;

        var anchor = _firstPostOpenerBurstAnchorMs ?? _settings.FirstBurstAnchorMs;
        var timeToAnchor = GetTimeToNextBurstAnchor(anchor);
        return timeToAnchor <= _settings.BurstWindowTailMs
            || timeToAnchor >= 120_000 - _settings.BurstWindowLeadMs;
    }

    private static int GetTimeToNextBurstAnchor(int anchorMs)
    {
        var diff = _currentBattleTimeMs - anchorMs;
        var mod = ((diff % 120_000) + 120_000) % 120_000;
        return mod == 0 ? 0 : 120_000 - mod;
    }

    private static bool ShouldUseDumpResources()
    {
        return QTHelper.IsEnabled(QTKey.DumpResources);
    }

    private static bool IsForceBurstActive()
    {
        return !IsForbidBurstActive() && QTHelper.IsEnabled(QTKey.ForceBurst);
    }

    private static bool IsForbidBurstActive()
    {
        return QTHelper.IsEnabled(QTKey.ForbidBurst);
    }

    private static void TrackBurstPackageAction(uint actionId)
    {
        if (actionId == MachinistActionId.Wildfire)
        {
            _lastWildfirePackageStartedAtMs = _currentBattleTimeMs;
            if (_firstPostOpenerBurstAnchorMs is null && _currentBattleTimeMs <= OpeningBurstWindowMs)
                _firstPostOpenerBurstAnchorMs = _currentBattleTimeMs + 120_000;
        }

        if (actionId == MachinistActionId.Hypercharge)
            _lastHyperchargePackageStartedAtMs = _currentBattleTimeMs;
    }

    private static bool HasActiveWildfirePackage()
    {
        if (_lastWildfirePackageStartedAtMs is not null
            && _currentBattleTimeMs - _lastWildfirePackageStartedAtMs.Value <= WildfirePackageDurationMs)
            return true;

        return HelperRuntime.HasStatusOnTarget(MachinistStatusId.Wildfire)
            && HelperRuntime.GetStatusTimeLeftOnTarget(MachinistStatusId.Wildfire) > 0.5f;
    }

    private static bool HasRecentPreBurstHypercharge()
    {
        return _lastHyperchargePackageStartedAtMs is not null
            && !IsInTwoMinuteBurstWindow()
            && _currentBattleTimeMs - _lastHyperchargePackageStartedAtMs.Value <= WildfireBurstPackageLookaheadMs;
    }

    private static bool ShouldSpendHeatByBudget()
    {
        var wildfireCooldown = TargetSpell(MachinistActionId.Wildfire).CooldownMs;
        if (GetHeat() >= _settings.HeatOvercapThreshold)
            return true;

        if (HasRecentPreBurstHypercharge())
            return false;

        if (wildfireCooldown >= PreWildfireOvercapHyperchargeMinCooldownMs
            && wildfireCooldown <= PreWildfireOvercapHyperchargeMaxCooldownMs
            && GetHeat() >= PreWildfireOvercapHeatThreshold)
            return true;

        return IsInTwoMinuteBurstWindow() || wildfireCooldown > WildfireBurstPackageLookaheadMs;
    }

    private static bool ShouldDelayWildfireUntilHyperchargeForBurstPackage()
    {
        if (ShouldUseDumpResources())
            return false;

        if (!CanUseBurstResource())
            return false;

        if (HasActiveWildfirePackage())
            return false;

        if (_lastHyperchargePackageStartedAtMs is not null
            && _currentBattleTimeMs - _lastHyperchargePackageStartedAtMs.Value <= HyperchargeBeforeWildfireWindowMs)
            return false;

        return GetHeat() >= 50 && SelfAbility(MachinistActionId.Hypercharge).IsReadyWithCanCast();
    }

    private static bool ShouldFinishCleanShotComboBeforeHypercharge()
    {
        if (GetHeat() > _settings.HeatOvercapThreshold)
            return false;

        var lastCombo = HelperRuntime.GetLastComboSpellId();
        return lastCombo is MachinistActionId.SlugShot or MachinistActionId.HeatedSlugShot;
    }

    private static bool ShouldDelayHyperchargeForToolCooldown()
    {
        return IsToolCooldownWithin(MachinistActionId.ChainSaw, _settings.HyperchargeToolCooldownLookaheadMs)
            || IsToolCooldownWithin(MachinistActionId.AirAnchor, _settings.HyperchargeToolCooldownLookaheadMs);
    }

    private static bool IsToolCooldownWithin(uint actionId, int lookaheadMs)
    {
        if (!IsActionUnlockedForCooldownLookahead(actionId))
            return false;

        return TargetSpell(actionId).CooldownMs <= lookaheadMs;
    }

    private static bool IsActionUnlockedForCooldownLookahead(uint actionId)
    {
        return actionId switch
        {
            MachinistActionId.Wildfire => LevelAtLeast(45),
            MachinistActionId.Drill => LevelAtLeast(58),
            MachinistActionId.AirAnchor => LevelAtLeast(76),
            MachinistActionId.ChainSaw => LevelAtLeast(90),
            MachinistActionId.Excavator => LevelAtLeast(96),
            MachinistActionId.FullMetalField => LevelAtLeast(100),
            _ => true,
        };
    }

    private static bool HasStrongGcdSoon(int lookaheadMs)
    {
        return GetReassembleTargetActionId(lookaheadMs) is not null;
    }

    private static int GetReassembleSequenceLookaheadMs()
    {
        return (int)Math.Max(0, GCDHelper.GetGCDCooldown()) + ReassembleSequenceLookaheadPaddingMs;
    }

    private static uint? GetReassembleTargetActionId(int lookaheadMs)
    {
        var shouldForceSpend = ShouldSpendReassembleForChargePressure();
        var hasExcavatorTarget = IsReadyForReassembleTarget(MachinistActionId.Excavator)
            || IsReassembleTargetWithin(MachinistActionId.Excavator, lookaheadMs);
        if (hasExcavatorTarget)
            return MachinistActionId.Excavator;

        if (!shouldForceSpend && ShouldReserveReassembleForNextBurstWindow())
            return null;

        if (!shouldForceSpend && ShouldReserveReassembleForExcavator())
            return null;

        foreach (var actionId in ReassembleTargetPriority)
        {
            if (actionId == MachinistActionId.Excavator)
                continue;

            if (IsReadyForReassembleTarget(actionId) || IsReassembleTargetWithin(actionId, lookaheadMs))
                return actionId;
        }

        return null;
    }

    private static bool ShouldSpendReassembleForChargePressure()
    {
        var reassemble = SelfAbility(MachinistActionId.Reassemble);
        return reassemble.Charges >= 2
            || (reassemble.Charges > 0 && reassemble.CooldownMs <= ReassembleChargePressureMs);
    }

    private static bool ShouldReserveReassembleForNextBurstWindow()
    {
        if (IsInTwoMinuteBurstWindow())
            return false;

        return GetTimeToNextBurstAnchor(_firstPostOpenerBurstAnchorMs ?? _settings.FirstBurstAnchorMs)
            <= ReassembleRechargeMs + ReassembleBurstSafetyMs;
    }

    private static bool ShouldReserveReassembleForExcavator()
    {
        if (!IsActionUnlockedForCooldownLookahead(MachinistActionId.Excavator))
            return false;

        var chainSaw = TargetSpell(MachinistActionId.ChainSaw);
        return IsActionUnlockedForCooldownLookahead(MachinistActionId.ChainSaw)
            && (chainSaw.IsReadyWithCanCast() || chainSaw.CooldownMs <= ReassembleExcavatorReserveMs);
    }

    private static bool IsReadyForReassembleTarget(uint actionId)
    {
        if (!IsActionUnlockedForCooldownLookahead(actionId))
            return false;

        if (!IsStrongGcdAvailableByStatus(actionId))
            return false;

        return TargetSpell(actionId).IsReadyWithCanCast();
    }

    private static bool IsReassembleTargetWithin(uint actionId, int lookaheadMs)
    {
        if (lookaheadMs <= 0 || !IsActionUnlockedForCooldownLookahead(actionId))
            return false;

        var remainingMs = GetTrackedReassembleTargetCooldownRemainingMs(actionId);
        return remainingMs is not null && remainingMs.Value <= lookaheadMs;
    }

    private static bool WillNextGcdConsumeReassembleTarget(uint actionId)
    {
        if (GetNextStrongGcdActionId() == actionId)
            return true;

        var remainingMs = GetTrackedReassembleTargetCooldownRemainingMs(actionId);
        return remainingMs is not null && remainingMs.Value <= GCDHelper.GetGCDCooldown();
    }

    private static uint? GetNextStrongGcdActionId()
    {
        foreach (var actionId in StrongGcdPriority)
        {
            if (GetReadyStrongGcd(actionId) is not null)
                return actionId;
        }

        return GetLowLevelHotShotGcd() is null ? null : MachinistActionId.HotShot;
    }

    private static int? GetTrackedReassembleTargetCooldownRemainingMs(uint actionId)
    {
        if (actionId == MachinistActionId.Excavator && HelperRuntime.HasStatus(MachinistStatusId.ExcavatorReady))
            return 0;

        if (!CombatActionLastUsedAtMs.TryGetValue(actionId, out var lastUsedAtMs))
            return null;

        var recastMs = actionId switch
        {
            MachinistActionId.Drill => 20_000,
            MachinistActionId.AirAnchor => 40_000,
            MachinistActionId.ChainSaw => 60_000,
            _ => (int?)null,
        };

        return recastMs is null ? null : Math.Max(0, recastMs.Value - (_currentBattleTimeMs - lastUsedAtMs));
    }

    private static Spell? BuildQueenSpell()
    {
        var actionId = LevelAtLeast(80) ? MachinistActionId.AutomatonQueen : MachinistActionId.RookAutoturret;
        var spell = TargetAbility(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static Spell? PickGaussRoundOrRicochet()
    {
        var gaussRound = LevelAtLeast(92)
            ? TargetAbility(MachinistActionId.DoubleCheck)
            : TargetAbility(MachinistActionId.GaussRound);
        var ricochet = LevelAtLeast(92)
            ? TargetAbility(MachinistActionId.Checkmate)
            : TargetAbility(MachinistActionId.Ricochet);

        var gaussReady = gaussRound.IsReadyWithCanCast();
        var ricochetReady = ricochet.IsReadyWithCanCast();
        if (!gaussReady && !ricochetReady)
            return null;

        if (!ricochetReady)
            return gaussRound;

        if (!gaussReady)
            return ricochet;

        return gaussRound.Charges >= ricochet.Charges ? gaussRound : ricochet;
    }
}
