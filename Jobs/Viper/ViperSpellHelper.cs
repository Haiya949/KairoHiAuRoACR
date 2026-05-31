using OmenTools.Dalamud.Services.ObjectTable.Abstractions.ObjectKinds;
using ActionId = HiAuRo.Helper.VPRHelper.EN.Skills;
using StatusId = HiAuRo.Helper.VPRHelper.EN.Buffs;

namespace KairoHiAuRoACR.Jobs.Viper;

public enum ViperCombatProfile
{
    Daily,
    HighEnd,
}

public enum TimelineBurstIntent
{
    Default,
    ForceBurst,
    ForbidBurst,
}

public enum ViperPositionalRequirement
{
    None,
    Flank,
    Behind,
}

public static class ViperSpellHelper
{
    private const int BurstCycleMs = 120_000;
    private const int TimelinePotionRequestWindowMs = 5_000;
    private const float WeakTargetBurstHpThreshold = 0.12f;
    private const float DumpResourcesHpThreshold = 0.03f;
    private const float MeleeRange = 3.5f;
    private const float RangedFallbackMaxRange = 20f;
    private const int PositionalHintFillLeadMs = 1_200;

    private static readonly uint[] ReawakenActions =
    [
        ActionId.FirstGeneration,
        ActionId.SecondGeneration,
        ActionId.ThirdGeneration,
        ActionId.FourthGeneration,
        ActionId.Ouroboros,
    ];

    private static readonly uint[] ReawakenFollowUpActions =
    [
        ActionId.FirstLegacy,
        ActionId.SecondLegacy,
        ActionId.ThirdLegacy,
        ActionId.FourthLegacy,
    ];

    private static readonly uint[] FollowUpBaseActions =
    [
        ActionId.SerpentsTail,
        ActionId.Twinfang,
        ActionId.Twinblood,
    ];

    private static readonly uint[] FollowUpReplacementActions =
    [
        ActionId.DeathRattle,
        ActionId.LastLash,
        ActionId.TwinfangBite,
        ActionId.TwinbloodBite,
        ActionId.TwinfangThresh,
        ActionId.TwinbloodThresh,
        ActionId.FirstLegacy,
        ActionId.SecondLegacy,
        ActionId.ThirdLegacy,
        ActionId.FourthLegacy,
        ActionId.UncoiledTwinfang,
        ActionId.UncoiledTwinblood,
    ];

    private static readonly uint[] DreadwinderComboActions =
    [
        ActionId.HuntersCoil,
        ActionId.SwiftskinsCoil,
        ActionId.HuntersDen,
        ActionId.SwiftskinsDen,
    ];

    private static readonly uint[] AoeDreadwinderActions =
    [
        ActionId.Vicepit,
        ActionId.HuntersDen,
        ActionId.SwiftskinsDen,
    ];

    private static readonly uint[] SecondStepActions =
    [
        ActionId.HuntersSting,
        ActionId.SwiftskinsSting,
    ];

    private static readonly uint[] ThirdStepActions =
    [
        ActionId.FlankstingStrike,
        ActionId.FlanksbaneFang,
        ActionId.HindstingStrike,
        ActionId.HindsbaneFang,
    ];

    private static readonly uint[] AoeSecondStepActions =
    [
        ActionId.HuntersBite,
        ActionId.SwiftskinsBite,
    ];

    private static readonly uint[] AoeThirdStepActions =
    [
        ActionId.JaggedMaw,
        ActionId.BloodiedMaw,
    ];

    private static ViperSettings _settings = new();
    private static int _currentBattleTimeMs;
    private static int? _timelinePotionRequestedAtMs;
    private static int _dreadwinderFollowUpsRemaining;
    private static uint _lastDreadwinderFollowUpId;
    private static bool _dreadwinderComboIsAoe;
    private static bool _suppressDreadwinderActionChangeFallback;
    private static readonly Dictionary<string, bool> _timelineOwnedQtDefaults = new(StringComparer.Ordinal);
    private static readonly Dictionary<uint, int> CombatActionLastUsedAtMs = new();

    public static void Configure(ViperSettings settings)
    {
        _settings = settings;
    }

    public static void Reset()
    {
        ResetCombatState();
    }

    public static void ResetCombatState()
    {
        _currentBattleTimeMs = 0;
        _timelinePotionRequestedAtMs = null;
        _dreadwinderFollowUpsRemaining = 0;
        _lastDreadwinderFollowUpId = 0;
        _dreadwinderComboIsAoe = false;
        _suppressDreadwinderActionChangeFallback = false;
        CombatActionLastUsedAtMs.Clear();
        ViperTimelineState.ResetAll();
        ResetTimelineManagedQt();
    }

    public static void UpdateBattleTime(int battleTimeMs)
    {
        var next = Math.Max(0, battleTimeMs);
        if (_currentBattleTimeMs > 5_000 && next <= 1_000)
            ResetCombatTracking();

        _currentBattleTimeMs = next;
    }

    private static void ResetCombatTracking()
    {
        _timelinePotionRequestedAtMs = null;
        _dreadwinderFollowUpsRemaining = 0;
        _lastDreadwinderFollowUpId = 0;
        _dreadwinderComboIsAoe = false;
        _suppressDreadwinderActionChangeFallback = false;
        CombatActionLastUsedAtMs.Clear();
        ViperTimelineState.ResetAll();
        ResetTimelineManagedQt();
    }

    public static void RecordCombatActionUse(uint actionId)
    {
        CombatActionLastUsedAtMs[actionId] = _currentBattleTimeMs;
        RecordSpellCast(actionId);
    }

    public static bool ShouldStopActions()
    {
        return QTHelper.IsEnabled(BuiltinQt.Hold);
    }

    public static bool ShouldBlockCombatRotationActions()
    {
        return _currentBattleTimeMs <= 0;
    }

    public static bool CanUseCombatActions()
    {
        return !ShouldStopActions() && HasTarget();
    }

    public static Spell? GetReawakenGcd()
    {
        if (!CanUseCombatActions())
            return null;

        var reawakenChain = GetReawakenChainGcd();
        if (reawakenChain is not null)
            return reawakenChain;

        if (!ShouldStartReawaken())
            return null;

        var spell = SelfSpell(ActionId.Reawaken);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static Spell? GetReawakenChainGcd()
    {
        if (GetAnguineTribute() <= 0 && !VPRHelper.HasReawakened)
            return null;

        foreach (var actionId in ReawakenActions)
        {
            var current = HelperRuntime.GetActionChange(actionId);
            if (current != actionId || current == ActionId.Ouroboros)
            {
                var spell = TargetSpell(current);
                if (spell.IsReadyWithCanCast())
                    return spell;
            }
        }

        foreach (var actionId in ReawakenActions)
        {
            var spell = TargetSpell(actionId);
            if (spell.IsReadyWithCanCast())
                return spell;
        }

        return null;
    }

    public static Spell? GetDreadwinderGcd()
    {
        if (!CanUseCombatActions())
            return null;

        var tracked = GetTrackedDreadwinderComboActionId();
        if (tracked is not null)
            return DreadwinderSpell(tracked.Value);

        if (ShouldTrustDreadwinderActionChangeFallback())
        {
            var current = HelperRuntime.GetActionChange(ActionId.Vicewinder);
            if (DreadwinderComboActions.Contains(current))
                return DreadwinderSpell(current);

            var currentAoe = HelperRuntime.GetActionChange(ActionId.Vicepit);
            if (DreadwinderComboActions.Contains(currentAoe))
                return DreadwinderSpell(currentAoe);
        }

        if (!ShouldStartDreadwinder())
            return null;

        var startAction = ShouldUseAoeGcd() ? ActionId.Vicepit : ActionId.Vicewinder;
        return DreadwinderSpell(startAction);
    }

    public static Spell? GetRattlingCoilGcd()
    {
        if (!CanUseCombatActions() || !ShouldUseRattlingCoil())
            return null;

        if (IsTargetOutsideMelee())
            return null;

        var spell = TargetSpell(ActionId.UncoiledFury);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetAoeGcd()
    {
        if (!CanUseCombatActions() || !ShouldUseAoeGcd())
            return null;

        var currentLeft = HelperRuntime.GetActionChange(ActionId.SteelMaw);
        var currentRight = HelperRuntime.GetActionChange(ActionId.ReavingMaw);
        var lastCombo = HelperRuntime.GetLastComboSpellId();

        Spell spell;
        if (lastCombo is ActionId.SteelMaw or ActionId.ReavingMaw)
            spell = PickAoeSecondStep();
        else if (AoeSecondStepActions.Contains(lastCombo))
            spell = PickAoeThirdStep(currentLeft, currentRight);
        else
            spell = PickAoeFirstStep();

        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetRangedFallbackGcd()
    {
        if (!CanUseCombatActions() || !QTHelper.IsEnabled(QTKey.RangedFallback))
            return null;

        var target = GetCurrentTarget();
        if (target is null)
            return null;

        var distance = GetTargetDistance(target);
        if (distance <= MeleeRange || distance > RangedFallbackMaxRange)
            return null;

        var spell = TargetSpell(ActionId.WrithingSnap);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetBaseGcd()
    {
        if (!CanUseCombatActions())
            return null;

        if (IsTargetOutsideMelee())
            return null;

        var currentLeft = HelperRuntime.GetActionChange(ActionId.SteelFangs);
        var currentRight = HelperRuntime.GetActionChange(ActionId.ReavingFangs);
        var lastCombo = HelperRuntime.GetLastComboSpellId();

        Spell spell;
        if (lastCombo is ActionId.SteelFangs or ActionId.ReavingFangs)
            spell = PickSecondStep();
        else if (SecondStepActions.Contains(lastCombo))
            spell = PickThirdStep(currentLeft, currentRight);
        else
            spell = PickFirstStep();

        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetFollowUpOffGcd()
    {
        if (!CanUseCombatActions() || !CanWeave())
            return null;

        if (ShouldUseSerpentsIre())
            return null;

        var currentAction = GetPendingFollowUpActionId();
        if (currentAction is null)
            return null;

        var spell = TargetAbility(currentAction.Value);
        if (spell.IsReadyWithCanCast())
            return spell;

        foreach (var actionId in ReawakenFollowUpActions)
        {
            var reawakenFollowUp = TargetAbility(actionId);
            if (reawakenFollowUp.IsReadyWithCanCast())
                return reawakenFollowUp;
        }

        return null;
    }

    public static Spell? GetSerpentsIreOffGcd()
    {
        if (!CanUseCombatActions() || !ShouldUseSerpentsIre() || !CanWeave(800))
            return null;

        var spell = SelfAbility(ActionId.SerpentsIre);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetTrueNorthOffGcd()
    {
        if (!ShouldUseTrueNorth())
            return null;

        var spell = SelfAbility(ActionId.TrueNorth);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static bool CanUsePotion()
    {
        if (!CanUseCombatActions())
            return false;

        if (!QTHelper.IsEnabled(BuiltinQt.Burst) || !QTHelper.IsEnabled(BuiltinQt.Potion))
            return false;

        return HasTimelinePotionRequest() && CanUseBurstResource();
    }

    public static void RequestTimelinePotion()
    {
        _timelinePotionRequestedAtMs = _currentBattleTimeMs;
    }

    public static bool HasTimelinePotionRequest()
    {
        return _timelinePotionRequestedAtMs is { } requestedAt
            && _currentBattleTimeMs - requestedAt <= TimelinePotionRequestWindowMs;
    }

    public static bool ConsumeTimelinePotionRequest()
    {
        if (!HasTimelinePotionRequest())
        {
            _timelinePotionRequestedAtMs = null;
            return false;
        }

        _timelinePotionRequestedAtMs = null;
        return true;
    }

    public static bool CanUseReawaken()
    {
        if (ShouldHoldReawakenByTimeline())
            return false;

        if (GetAnguineTribute() > 0)
            return false;

        if (ShouldHoldReawakenForSerpentsIre() && !ShouldSpendReawakenToPreventLoss())
            return false;

        if (ShouldHoldReawakenForUpcomingBurst() && !ShouldDumpResources())
            return false;

        if (ShouldHoldResourceForBaseCombo() && !ShouldDumpResources() && !CanStartDoubleReawakenBeforeSerpentsIre())
            return false;

        if (GetSerpentOffering() < 50 && !HelperRuntime.HasStatus(StatusId.ReadyToReawaken) && !HelperRuntime.HasStatus(StatusId.Reawakened))
            return false;

        if (CanUseBurstResource())
            return HasReawakenBuffCoverage() || IsForceBurstActive();

        return CanUseResourceForOvercap()
            && (ShouldSpendReawakenToPreventLoss() || HasReawakenBuffCoverage());
    }

    public static bool ShouldStartReawaken()
    {
        return CanUseReawaken();
    }

    public static string GetReawakenBlockReason()
    {
        if (GetAnguineTribute() > 0)
            return "AlreadyInReawakenCombo";

        if (ShouldHoldReawakenByTimeline())
            return "TimelineHoldReawaken";

        if (ShouldHoldReawakenForSerpentsIre() && !ShouldSpendReawakenToPreventLoss())
            return "WaitingForSerpentsIre";

        if (ShouldHoldReawakenForUpcomingBurst() && !ShouldDumpResources())
            return "UpcomingBurstHold";

        if (ShouldHoldResourceForBaseCombo() && !ShouldDumpResources() && !CanStartDoubleReawakenBeforeSerpentsIre())
            return "BaseComboInProgress";

        if (GetSerpentOffering() < 50 && !HelperRuntime.HasStatus(StatusId.ReadyToReawaken) && !HelperRuntime.HasStatus(StatusId.Reawakened))
            return "NoSerpentOfferingOrReadyAura";

        if (CanUseBurstResource() && !ShouldSpendReawakenToPreventLoss() && !HasReawakenBuffCoverage() && !IsForceBurstActive())
            return "InsufficientBuffCoverageInBurst";

        if (!CanUseBurstResource() && !CanUseResourceForOvercap())
            return "ResourceGateClosed";

        return SelfSpell(ActionId.Reawaken).IsReadyWithCanCast()
            ? "Ready"
            : "SpellNotReadyOrCannotCast";
    }

    public static bool ShouldStartDreadwinder()
    {
        if (GetAnguineTribute() > 0 || ShouldHoldDreadwinderByTimeline())
            return false;

        if (GetDreadwinderCharges() < 1)
            return false;

        if (!CanStartDreadwinderActionChange(ShouldUseAoeGcd()))
            return false;

        if (ShouldHoldDreadwinderForDelayedBaseFinisher())
            return false;

        if (ShouldDumpFullRattlingCoilBeforeDreadwinder())
            return false;

        if (ShouldHoldNewResourceForSerpentsIre())
            return false;

        if (ShouldPrioritizeRattlingCoilInBurst())
            return false;

        return CanUseBurstResource() || CanUseResourceForOvercap();
    }

    public static string GetDreadwinderBlockReason()
    {
        if (GetAnguineTribute() > 0)
            return "ReawakenComboActive";

        if (ShouldHoldDreadwinderByTimeline())
            return "TimelineHoldDreadwinder";

        if (GetDreadwinderCharges() < 1)
            return "NoDreadwinderCharges";

        if (!CanStartDreadwinderActionChange(ShouldUseAoeGcd()))
            return "ActionChangeNotReady";

        if (ShouldHoldDreadwinderForDelayedBaseFinisher())
            return "DelayedBaseFinisherPending";

        if (ShouldDumpFullRattlingCoilBeforeDreadwinder())
            return "FullRattlingCoilDumpReady";

        if (ShouldHoldNewResourceForSerpentsIre())
            return "WaitingForSerpentsIre";

        if (!CanUseBurstResource() && !CanUseResourceForOvercap())
            return "ResourceGateClosed";

        return "Ready";
    }

    private static bool CanStartDreadwinderActionChange(bool useAoe)
    {
        var startAction = useAoe ? ActionId.Vicepit : ActionId.Vicewinder;
        return HelperRuntime.GetActionChange(startAction) == startAction
            || GetDreadwinderCharges() >= 1;
    }

    public static bool CanUseDreadwinderGcd(Spell spell)
    {
        if (!IsDreadwinderComboActive() && ShouldStartDreadwinder())
            return GetDreadwinderCharges() >= 1;

        if (spell.Id is ActionId.Vicewinder or ActionId.Vicepit)
            return GetDreadwinderCharges() >= 1;

        return spell.IsReadyWithCanCast();
    }

    public static bool ShouldUseRattlingCoil()
    {
        if (GetRattlingCoilStacks() <= 0 || GetAnguineTribute() > 0)
            return false;

        if (ShouldDumpRattlingCoilByTimeline() || ShouldDumpResources())
            return true;

        if (ShouldHoldRattlingCoilByTimeline())
            return false;

        if (ShouldHoldResourceForBaseCombo())
            return false;

        if (ShouldHoldNewResourceForSerpentsIre())
            return false;

        return CanUseBurstResource() || CanUseResourceForOvercap();
    }

    public static bool CanUseSerpentsIreBeforeGcdWindow()
    {
        if (ShouldHoldSerpentsIreByTimeline() || !CanUseBurstResource())
            return false;

        var spell = SelfSpell(ActionId.SerpentsIre);
        if (!spell.IsReadyWithCanCast())
            return false;

        if (GetRattlingCoilStacks() >= _settings.RattlingCoilOvercapStacks)
            return false;

        return !HelperRuntime.HasStatus(StatusId.ReadyToReawaken);
    }

    public static bool ShouldUseSerpentsIre()
    {
        return CanUseSerpentsIreBeforeGcdWindow() && GCDHelper.GetGCDCooldown() >= 800;
    }

    public static bool CanStartDoubleReawakenBeforeSerpentsIre()
    {
        return CanUseSerpentsIreBeforeGcdWindow()
            && GetSerpentOffering() >= 50
            && GetAnguineTribute() <= 0
            && !IsDreadwinderComboActive();
    }

    public static bool ShouldHoldReawakenForSerpentsIre()
    {
        return ShouldHoldNewResourceForSerpentsIre() && !CanStartDoubleReawakenBeforeSerpentsIre();
    }

    public static bool ShouldHoldReawakenForBaseCombo()
    {
        return ShouldHoldResourceForBaseCombo();
    }

    public static bool ShouldHoldReawakenForUpcomingBurst()
    {
        if (IsForceBurstActive() || GetCombatProfile() != ViperCombatProfile.HighEnd || IsInTwoMinuteBurstWindow())
            return false;

        var timeToAnchor = GetTimeToNextTwoMinuteBurstAnchor();
        return timeToAnchor > 0 && timeToAnchor <= _settings.ReawakenPreBurstHoldMs;
    }

    public static bool ShouldHoldNewResourceForSerpentsIre()
    {
        return CanUseSerpentsIreBeforeGcdWindow();
    }

    public static bool HasReawakenBuffCoverage()
    {
        return HelperRuntime.GetAuraTimeLeft(StatusId.HuntersInstinct) * 1000 >= _settings.ReawakenBuffCoverageMs
            && HelperRuntime.GetAuraTimeLeft(StatusId.Swiftscaled) * 1000 >= _settings.ReawakenBuffCoverageMs;
    }

    public static bool CanUseBurstResource()
    {
        if (!CanUseResourceBase())
            return false;

        return ShouldDumpResources() || IsForceBurstActive() || IsInTwoMinuteBurstWindow();
    }

    public static bool CanUseResourceForOvercap()
    {
        return CanUseResourceBase();
    }

    private static bool CanUseResourceBase()
    {
        if (!CanUseCombatActions() || !QTHelper.IsEnabled(BuiltinQt.Burst) || IsForbidBurstActive())
            return false;

        var target = GetCurrentTarget();
        if (target is null)
            return false;

        return !ShouldHoldBurstForWeakTarget(target) || IsForceBurstActive();
    }

    public static bool ShouldHoldSerpentsIreByTimeline()
    {
        return ViperTimelineState.IsActive(ViperTimelineVariable.HoldSerpentsIre);
    }

    public static bool ShouldHoldReawakenByTimeline()
    {
        return ViperTimelineState.IsActive(ViperTimelineVariable.HoldReawaken);
    }

    public static bool ShouldHoldDreadwinderByTimeline()
    {
        return ViperTimelineState.IsActive(ViperTimelineVariable.HoldDreadwinder);
    }

    public static bool ShouldHoldRattlingCoilByTimeline()
    {
        return ViperTimelineState.IsActive(ViperTimelineVariable.HoldRattlingCoil);
    }

    public static bool ShouldDumpRattlingCoilByTimeline()
    {
        return ViperTimelineState.IsActive(ViperTimelineVariable.DumpRattlingCoil);
    }

    public static bool ShouldDumpResources()
    {
        return QTHelper.IsEnabled(QTKey.DumpResources)
            || QTHelper.IsEnabled(BuiltinQt.Dump)
            || ViperTimelineState.IsActive(ViperTimelineVariable.DumpResources);
    }

    public static bool IsForceBurstActive()
    {
        return !IsForbidBurstActive()
            && (QTHelper.IsEnabled(QTKey.ForceBurst)
                || ViperTimelineState.IsActive(ViperTimelineVariable.ForceBurst));
    }

    public static bool IsForbidBurstActive()
    {
        return QTHelper.IsEnabled(QTKey.ForbidBurst)
            || ViperTimelineState.IsActive(ViperTimelineVariable.ForbidBurst);
    }

    public static TimelineBurstIntent GetTimelineBurstIntent()
    {
        if (IsForbidBurstActive())
            return TimelineBurstIntent.ForbidBurst;

        if (IsForceBurstActive())
            return TimelineBurstIntent.ForceBurst;

        return TimelineBurstIntent.Default;
    }

    public static void ApplyTimelineManagedQt()
    {
        QTHelper.SetValue(QTKey.DumpResources, ShouldDumpResourcesByTargetHp(GetCurrentTarget()));
    }

    public static void SyncTimelineManagedQt()
    {
        ApplyTimelineManagedQt();
    }

    public static void ResetTimelineManagedQt()
    {
        _timelinePotionRequestedAtMs = null;

        foreach (var pair in _timelineOwnedQtDefaults)
            QTHelper.SetValue(pair.Key, pair.Value);

        _timelineOwnedQtDefaults.Clear();
        QTHelper.SetValue(QTKey.DumpResources, false);
    }

    public static bool SetTimelineQt(string key, bool value)
    {
        if (key == BuiltinQt.Potion.GetLabel() || key == BuiltinQt.Potion.GetId())
            return false;

        if (key != QTKey.DumpResources && !_timelineOwnedQtDefaults.ContainsKey(key))
            _timelineOwnedQtDefaults[key] = QTHelper.IsEnabled(key);

        QTHelper.SetValue(key, value);
        return true;
    }

    public static IBattleChara? GetBestAoeTarget(uint actionId)
    {
        return TargetHelper.GetMostCanTargetObjects(actionId, _settings.AoeEnemyCount, 5f)
            ?? global::HiAuRo.Data.Target.Current as IBattleChara;
    }

    public static int GetAoeTargetCount(uint actionId)
    {
        var target = GetBestAoeTarget(actionId);
        return target is null ? 0 : TargetHelper.GetNearbyEnemyCount(target, 5f) + 1;
    }

    public static bool ShouldUseAoeGcd()
    {
        return QTHelper.IsEnabled(BuiltinQt.AoE)
            && HasTarget()
            && GetAoeTargetCount(ActionId.SteelMaw) >= _settings.AoeEnemyCount;
    }

    public static ViperPositionalRequirement GetNextPositionalRequirement()
    {
        if (GetReawakenGcd() is not null)
            return ViperPositionalRequirement.None;

        if (GetDreadwinderGcd() is { } dreadwinder)
            return SpellNeedsPositional(dreadwinder.Id);

        if (GetRattlingCoilGcd() is not null || ShouldUseAoeGcd())
            return ViperPositionalRequirement.None;

        return GetBaseGcd() is { } baseGcd
            ? SpellNeedsPositional(baseGcd.Id)
            : ViperPositionalRequirement.None;
    }

    public static ViperPositionalRequirement SpellNeedsPositional(uint actionId)
    {
        return actionId switch
        {
            ActionId.FlankstingStrike or ActionId.FlanksbaneFang or ActionId.HuntersCoil => ViperPositionalRequirement.Flank,
            ActionId.HindstingStrike or ActionId.HindsbaneFang or ActionId.SwiftskinsCoil => ViperPositionalRequirement.Behind,
            _ => ViperPositionalRequirement.None,
        };
    }

    public static bool ShouldUseTrueNorth()
    {
        if (!CanUseCombatActions() || !QTHelper.IsEnabled(QTKey.AutoTrueNorth))
            return false;

        if (HasPendingFollowUpOffGcd() || ShouldUseSerpentsIre())
            return false;

        if (!IsInTrueNorthDecisionWindow())
            return false;

        var target = GetCurrentTarget();
        if (target is null || HelperRuntime.HasStatus(StatusId.TrueNorth))
            return false;

        return GetNextPositionalRequirement() switch
        {
            ViperPositionalRequirement.Flank => !TargetHelper.IsFlanking(target),
            ViperPositionalRequirement.Behind => !TargetHelper.IsBehind(target),
            _ => false,
        };
    }

    public static int GetTrueNorthGcdCooldown()
    {
        return (int)Math.Max(0, GCDHelper.GetGCDCooldown());
    }

    public static bool IsInTrueNorthDecisionWindow()
    {
        var gcdCooldown = GetTrueNorthGcdCooldown();
        return gcdCooldown <= _settings.TrueNorthDecisionLeadMs
            && gcdCooldown >= _settings.TrueNorthMinWeaveMs;
    }

    public static int GetPositionalHintProgress()
    {
        if (!QTHelper.IsEnabled(QTKey.AutoTrueNorth))
            return 0;

        var requirement = GetNextPositionalRequirement();
        if (requirement == ViperPositionalRequirement.None)
            return 0;

        var fillDuration = Math.Max(1, Math.Min((int)GCDHelper.GetGCDDuration(), PositionalHintFillLeadMs));
        var remaining = Math.Clamp(GetTrueNorthGcdCooldown(), 0, fillDuration);
        return 100 - (remaining * 100 / fillDuration);
    }

    public static bool ShouldHoldBurstForWeakTarget(IBattleChara target)
    {
        if (_settings.IsHighEndMode)
            return false;

        if (target.CurrentHp <= 0)
            return true;

        if (target.MaxHp <= 0)
            return false;

        return (float)target.CurrentHp / target.MaxHp <= WeakTargetBurstHpThreshold;
    }

    private static bool ShouldDumpResourcesByTargetHp(IBattleChara? target)
    {
        if (target is null || target.MaxHp <= 0)
            return false;

        return (float)target.CurrentHp / target.MaxHp <= DumpResourcesHpThreshold;
    }

    public static bool IsInTwoMinuteBurstWindow()
    {
        if (IsForceBurstActive())
            return true;

        var timeToAnchor = GetTimeToNextTwoMinuteBurstAnchor();
        return timeToAnchor <= _settings.BurstWindowTailMs
            || timeToAnchor >= BurstCycleMs - _settings.BurstWindowLeadMs;
    }

    public static int GetTimeToNextTwoMinuteBurstWindow()
    {
        return IsInTwoMinuteBurstWindow() ? 0 : GetTimeToNextTwoMinuteBurstAnchor();
    }

    public static int GetTwoMinuteBurstAnchorInMs()
    {
        if (_currentBattleTimeMs <= _settings.FirstBurstAnchorMs)
            return _settings.FirstBurstAnchorMs;

        var cycles = (_currentBattleTimeMs - _settings.FirstBurstAnchorMs) / BurstCycleMs;
        return _settings.FirstBurstAnchorMs + cycles * BurstCycleMs;
    }

    public static int GetTimeToNextTwoMinuteBurstAnchor()
    {
        var diff = _currentBattleTimeMs - _settings.FirstBurstAnchorMs;
        var mod = ((diff % BurstCycleMs) + BurstCycleMs) % BurstCycleMs;
        return mod == 0 ? 0 : BurstCycleMs - mod;
    }

    public static int GetBattleTimeInMs()
    {
        return _currentBattleTimeMs;
    }

    private static bool ShouldSpendReawakenToPreventLoss()
    {
        return GetSerpentOffering() >= 90
            || HelperRuntime.HasStatus(StatusId.ReadyToReawaken)
            || HelperRuntime.HasStatus(StatusId.Reawakened)
            || ShouldDumpResources();
    }

    public static bool ShouldHoldResourceForBaseCombo()
    {
        return GetLastComboStep() is 1 or 2;
    }

    private static bool ShouldHoldDreadwinderForDelayedBaseFinisher()
    {
        return GetLastComboStep() == 2
            && _dreadwinderFollowUpsRemaining <= 0
            && DreadwinderComboActions.Contains(_lastDreadwinderFollowUpId);
    }

    private static bool ShouldDumpFullRattlingCoilBeforeDreadwinder()
    {
        return GetRattlingCoilStacks() >= _settings.RattlingCoilOvercapStacks
            && TargetSpell(ActionId.UncoiledFury).IsReadyWithCanCast();
    }

    private static bool ShouldPrioritizeRattlingCoilInBurst()
    {
        return IsInTwoMinuteBurstWindow()
            && GetRattlingCoilStacks() > 0
            && !ShouldHoldRattlingCoilByTimeline()
            && TargetSpell(ActionId.UncoiledFury).IsReadyWithCanCast();
    }

    public static bool IsDreadwinderComboActive()
    {
        return _dreadwinderFollowUpsRemaining > 0;
    }

    public static uint? GetTrackedDreadwinderComboActionId()
    {
        if (_dreadwinderFollowUpsRemaining <= 0)
            return null;

        if (_dreadwinderFollowUpsRemaining == 2)
            return PickFirstDreadwinderFollowUpActionId(_dreadwinderComboIsAoe);

        if (DreadwinderComboActions.Contains(_lastDreadwinderFollowUpId))
            return GetOppositeDreadwinderFollowUpActionId(_lastDreadwinderFollowUpId);

        if (ShouldTrustDreadwinderActionChangeFallback())
        {
            var current = HelperRuntime.GetActionChange(ActionId.Vicewinder);
            if (DreadwinderComboActions.Contains(current))
                return current;

            var currentAoe = HelperRuntime.GetActionChange(ActionId.Vicepit);
            if (DreadwinderComboActions.Contains(currentAoe))
                return currentAoe;
        }

        return PickFirstDreadwinderFollowUpActionId(_dreadwinderComboIsAoe);
    }

    private static bool ShouldTrustDreadwinderActionChangeFallback()
    {
        return !_suppressDreadwinderActionChangeFallback;
    }

    public static void MarkDreadwinderIssued(uint actionId)
    {
        if (actionId is ActionId.Vicewinder or ActionId.Vicepit)
            StartDreadwinderTracking(actionId);
    }

    private static void RecordSpellCast(uint actionId)
    {
        if (actionId is ActionId.Vicewinder or ActionId.Vicepit)
        {
            StartDreadwinderTracking(actionId);
            return;
        }

        if (DreadwinderComboActions.Contains(actionId) && _dreadwinderFollowUpsRemaining > 0)
        {
            _dreadwinderFollowUpsRemaining--;
            _lastDreadwinderFollowUpId = actionId;

            if (_dreadwinderFollowUpsRemaining == 0)
                _suppressDreadwinderActionChangeFallback = true;
        }
    }

    private static void StartDreadwinderTracking(uint actionId)
    {
        _dreadwinderFollowUpsRemaining = 2;
        _lastDreadwinderFollowUpId = 0;
        _dreadwinderComboIsAoe = actionId == ActionId.Vicepit;
        _suppressDreadwinderActionChangeFallback = false;
    }

    private static uint PickFirstDreadwinderFollowUpActionId(bool useAoe)
    {
        var huntersActionId = useAoe ? ActionId.HuntersDen : ActionId.HuntersCoil;
        var swiftskinsActionId = useAoe ? ActionId.SwiftskinsDen : ActionId.SwiftskinsCoil;
        var damageBuffLeft = HelperRuntime.GetAuraTimeLeft(StatusId.HuntersInstinct) * 1000;
        var hasteBuffLeft = HelperRuntime.GetAuraTimeLeft(StatusId.Swiftscaled) * 1000;

        if (damageBuffLeft <= _settings.BuffRefreshThresholdMs)
            return huntersActionId;

        if (hasteBuffLeft <= _settings.BuffRefreshThresholdMs)
            return swiftskinsActionId;

        return damageBuffLeft <= hasteBuffLeft ? huntersActionId : swiftskinsActionId;
    }

    private static uint GetOppositeDreadwinderFollowUpActionId(uint actionId)
    {
        return actionId switch
        {
            ActionId.HuntersCoil => ActionId.SwiftskinsCoil,
            ActionId.SwiftskinsCoil => ActionId.HuntersCoil,
            ActionId.HuntersDen => ActionId.SwiftskinsDen,
            ActionId.SwiftskinsDen => ActionId.HuntersDen,
            _ => _dreadwinderComboIsAoe ? ActionId.HuntersDen : ActionId.HuntersCoil,
        };
    }

    public static uint? GetPendingFollowUpActionId()
    {
        if (TryGetTwinbloodFollowUp(out var twinbloodAction))
            return twinbloodAction;

        if (TryGetTwinfangFollowUp(out var twinfangAction))
            return twinfangAction;

        if (HelperRuntime.HasStatus(StatusId.PoisedForTwinblood)
            && TryGetFollowUpReplacement(ActionId.Twinblood, out var poisedTwinbloodAction))
            return poisedTwinbloodAction;

        if (HelperRuntime.HasStatus(StatusId.PoisedForTwinfang)
            && TryGetFollowUpReplacement(ActionId.Twinfang, out var poisedTwinfangAction))
            return poisedTwinfangAction;

        if (TryGetFollowUpReplacement(ActionId.SerpentsTail, out var tailAction))
            return tailAction;

        return null;
    }

    public static bool HasPendingFollowUpOffGcd()
    {
        return GetPendingFollowUpActionId() is not null;
    }

    private static bool TryGetTwinbloodFollowUp(out uint actionId)
    {
        actionId = 0;
        return HasTwinbloodFollowUpAura()
            && TryGetFollowUpReplacement(ActionId.Twinblood, out actionId);
    }

    private static bool TryGetTwinfangFollowUp(out uint actionId)
    {
        actionId = 0;
        return HasTwinfangFollowUpAura()
            && TryGetFollowUpReplacement(ActionId.Twinfang, out actionId);
    }

    private static bool HasTwinbloodFollowUpAura()
    {
        return HelperRuntime.HasStatus(StatusId.PoisedForTwinblood)
            || HelperRuntime.HasStatus(StatusId.SwiftskinsVenom)
            || HelperRuntime.HasStatus(StatusId.FellskinsVenom);
    }

    private static bool HasTwinfangFollowUpAura()
    {
        return HelperRuntime.HasStatus(StatusId.PoisedForTwinfang)
            || HelperRuntime.HasStatus(StatusId.HuntersVenom)
            || HelperRuntime.HasStatus(StatusId.FellhuntersVenom);
    }

    private static bool TryGetFollowUpReplacement(uint baseAction, out uint currentAction)
    {
        currentAction = HelperRuntime.GetActionChange(baseAction);
        return currentAction != baseAction && FollowUpReplacementActions.Contains(currentAction);
    }

    public static int GetLastComboStep()
    {
        var lastCombo = HelperRuntime.GetLastComboSpellId();
        if (lastCombo is ActionId.SteelFangs or ActionId.ReavingFangs or ActionId.SteelMaw or ActionId.ReavingMaw)
            return 1;

        if (SecondStepActions.Contains(lastCombo) || AoeSecondStepActions.Contains(lastCombo))
            return 2;

        return 0;
    }

    private static Spell PickFirstStep()
    {
        return HelperRuntime.HasStatus(StatusId.HonedSteel)
            ? TargetSpell(ActionId.SteelFangs)
            : TargetSpell(ActionId.ReavingFangs);
    }

    private static Spell PickSecondStep()
    {
        if (HelperRuntime.HasStatus(StatusId.FlankstungVenom) || HelperRuntime.HasStatus(StatusId.FlanksbaneVenom))
            return TargetSpell(ActionId.HuntersSting);

        if (HelperRuntime.HasStatus(StatusId.HindstungVenom) || HelperRuntime.HasStatus(StatusId.HindsbaneVenom))
            return TargetSpell(ActionId.SwiftskinsSting);

        var damageBuffLeft = HelperRuntime.GetAuraTimeLeft(StatusId.HuntersInstinct) * 1000;
        var hasteBuffLeft = HelperRuntime.GetAuraTimeLeft(StatusId.Swiftscaled) * 1000;

        if (damageBuffLeft <= _settings.BuffRefreshThresholdMs)
            return TargetSpell(ActionId.HuntersSting);

        if (hasteBuffLeft <= _settings.BuffRefreshThresholdMs)
            return TargetSpell(ActionId.SwiftskinsSting);

        return damageBuffLeft <= hasteBuffLeft
            ? TargetSpell(ActionId.HuntersSting)
            : TargetSpell(ActionId.SwiftskinsSting);
    }

    private static Spell PickThirdStep(uint currentLeft, uint currentRight)
    {
        if ((currentLeft == ActionId.FlankstingStrike || currentRight == ActionId.FlankstingStrike) && HelperRuntime.HasStatus(StatusId.FlankstungVenom))
            return TargetSpell(ActionId.FlankstingStrike);

        if ((currentLeft == ActionId.FlanksbaneFang || currentRight == ActionId.FlanksbaneFang) && HelperRuntime.HasStatus(StatusId.FlanksbaneVenom))
            return TargetSpell(ActionId.FlanksbaneFang);

        if ((currentLeft == ActionId.HindstingStrike || currentRight == ActionId.HindstingStrike) && HelperRuntime.HasStatus(StatusId.HindstungVenom))
            return TargetSpell(ActionId.HindstingStrike);

        if ((currentLeft == ActionId.HindsbaneFang || currentRight == ActionId.HindsbaneFang) && HelperRuntime.HasStatus(StatusId.HindsbaneVenom))
            return TargetSpell(ActionId.HindsbaneFang);

        if (ThirdStepActions.Contains(currentRight))
            return TargetSpell(currentRight);

        if (ThirdStepActions.Contains(currentLeft))
            return TargetSpell(currentLeft);

        return HelperRuntime.GetLastComboSpellId() == ActionId.SwiftskinsSting
            ? TargetSpell(ActionId.HindstingStrike)
            : TargetSpell(ActionId.FlankstingStrike);
    }

    private static Spell PickAoeFirstStep()
    {
        if (HelperRuntime.HasStatus(StatusId.HonedSteel))
            return AoeTargetSpell(ActionId.SteelMaw);

        if (HelperRuntime.HasStatus(StatusId.HonedReavers))
            return AoeTargetSpell(ActionId.ReavingMaw);

        return HelperRuntime.GetStatusTimeLeftOnTarget(StatusId.NoxiousGnash) >= 10f
            ? AoeTargetSpell(ActionId.SteelMaw)
            : AoeTargetSpell(ActionId.ReavingMaw);
    }

    private static Spell PickAoeSecondStep()
    {
        var hasteBuffLeft = HelperRuntime.GetAuraTimeLeft(StatusId.Swiftscaled) * 1000;
        return hasteBuffLeft > _settings.BuffRefreshThresholdMs
            ? AoeTargetSpell(ActionId.HuntersBite)
            : AoeTargetSpell(ActionId.SwiftskinsBite);
    }

    private static Spell PickAoeThirdStep(uint currentLeft, uint currentRight)
    {
        if (currentLeft == ActionId.BloodiedMaw && HelperRuntime.HasStatus(StatusId.GrimskinsVenom))
            return AoeTargetSpell(ActionId.BloodiedMaw);

        if (currentRight == ActionId.BloodiedMaw && HelperRuntime.HasStatus(StatusId.GrimskinsVenom))
            return AoeTargetSpell(ActionId.BloodiedMaw);

        if (currentLeft == ActionId.JaggedMaw || currentRight == ActionId.JaggedMaw)
            return AoeTargetSpell(ActionId.JaggedMaw);

        if (AoeThirdStepActions.Contains(currentLeft))
            return AoeTargetSpell(currentLeft);

        if (AoeThirdStepActions.Contains(currentRight))
            return AoeTargetSpell(currentRight);

        return AoeTargetSpell(ActionId.JaggedMaw);
    }

    private static Spell DreadwinderSpell(uint actionId)
    {
        return AoeDreadwinderActions.Contains(actionId)
            ? AoeTargetSpell(actionId)
            : TargetSpell(actionId);
    }

    private static bool CanWeave(int minGcdCooldownMs = 650)
    {
        return GCDHelper.GetGCDCooldown() >= minGcdCooldownMs;
    }

    private static bool HasTarget()
    {
        return GetCurrentTarget() is not null;
    }

    private static bool IsTargetOutsideMelee()
    {
        var target = GetCurrentTarget();
        return target is null || GetTargetDistance(target) > MeleeRange;
    }

    private static IBattleChara? GetCurrentTarget()
    {
        return global::HiAuRo.Data.Target.Current is IBattleChara { IsDead: false, IsTargetable: true } target
            && target.CurrentHp > 0
            ? target
            : null;
    }

    private static float GetTargetDistance(IBattleChara target)
    {
        var self = global::HiAuRo.Data.Me.Object;
        return self is null ? float.MaxValue : global::HiAuRo.Data.Me.DistanceToObject3D(target, false);
    }

    private static int GetSerpentOffering() => VPRHelper.Gauge?.SerpentOffering ?? 0;
    private static int GetRattlingCoilStacks() => VPRHelper.Gauge?.RattlingCoilStacks ?? 0;
    private static int GetAnguineTribute() => VPRHelper.Gauge?.AnguineTribute ?? 0;
    private static float GetDreadwinderCharges() => HelperRuntime.GetCharges(ActionId.Vicewinder);

    private static ViperCombatProfile GetCombatProfile()
    {
        return _settings.IsHighEndMode ? ViperCombatProfile.HighEnd : ViperCombatProfile.Daily;
    }

    private static Spell TargetSpell(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Target);
    }

    private static Spell SelfSpell(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Self);
    }

    private static Spell TargetAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Target) { Type = SpellType.Ability };
    }

    private static Spell SelfAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Self) { Type = SpellType.Ability };
    }

    private static Spell AoeTargetSpell(uint actionId)
    {
        return new Spell(actionId, () => GetBestAoeTarget(actionId)!);
    }
}
