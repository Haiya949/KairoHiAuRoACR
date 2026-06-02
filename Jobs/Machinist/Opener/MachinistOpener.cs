using ActionId = HiAuRo.Helper.MCHHelper.EN.Skills;

using HiAuRo.Runtime;

namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistOpener : IOpener
{
    private const int OpenerSlotMaxDurationMs = 3_500;

    private static readonly (Func<bool> IsAvailable, Action<Slot> Build)[] StandardOpenerSteps =
    [
        (static () => IsFirstOpenerSlotAvailable(), BuildFirstOpenerSlot),
        (static () => IsSecondOpenerSlotAvailable(), BuildSecondOpenerSlot),
        (static () => IsGcdUnlocked(ActionId.ChainSaw), BuildChainSawSlot),
        (static () => IsGcdUnlocked(ActionId.Excavator), BuildExcavatorSlot),
        (static () => IsSecondDrillOpenerSlotAvailable(), BuildSecondDrillSlot),
        (static () => IsFullMetalFieldOpenerSlotAvailable(), BuildFullMetalFieldSlot),
    ];

    private List<Action<Slot>>? _activeSequence;

    public uint Level => 58;

    public List<Action<Slot>> Sequence => _activeSequence ??= BuildSequence();

    public int StartCheck()
    {
        _activeSequence = BuildSequence();
        return CanStart() && _activeSequence.Count > 0 ? 0 : -1;
    }

    public int StopCheck(int index) => -1;

    public void InitCountDown(CountDownHandler handler)
    {
        handler.AddAction(4_000, () => new Spell(ActionId.Reassemble, SpellTargetType.Self)
        {
            Type = SpellType.Ability,
        });
    }

    private static List<Action<Slot>> BuildSequence()
    {
        return StandardOpenerSteps
            .Where(step => step.IsAvailable())
            .Select(step => step.Build)
            .ToList();
    }

    private static bool IsFirstOpenerSlotAvailable()
    {
        return IsAirAnchorFirstOpenerActive()
            ? IsGcdUnlocked(ActionId.AirAnchor)
            : IsGcdUnlocked(ActionId.Drill);
    }

    private static bool IsSecondOpenerSlotAvailable()
    {
        return IsAirAnchorFirstOpenerActive()
            ? IsGcdUnlocked(ActionId.Drill)
            : IsGcdUnlocked(ActionId.AirAnchor);
    }

    private static bool IsSecondDrillOpenerSlotAvailable()
    {
        return IsGcdUnlocked(ActionId.AirAnchor)
            && IsGcdUnlocked(ActionId.ChainSaw)
            && IsGcdUnlocked(ActionId.Excavator)
            && IsGcdUnlocked(ActionId.Drill);
    }

    private static bool IsFullMetalFieldOpenerSlotAvailable()
    {
        return IsSecondDrillOpenerSlotAvailable()
            && IsGcdUnlocked(ActionId.FullMetalField);
    }

    private static void BuildFirstOpenerSlot(Slot slot)
    {
        if (IsAirAnchorFirstOpenerActive())
        {
            BuildAirAnchorSlot(slot);
            return;
        }

        BuildFirstDrillSlot(slot);
    }

    private static void BuildSecondOpenerSlot(Slot slot)
    {
        if (IsAirAnchorFirstOpenerActive())
        {
            BuildFirstDrillSlot(slot);
            return;
        }

        BuildAirAnchorSlot(slot);
    }

    private static void BuildFirstDrillSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddGcdIfUnlocked(slot, ActionId.Drill);
        AddTargetAbilityIfReady(slot, ActionId.Checkmate);
        AddTargetAbilityIfReady(slot, ActionId.DoubleCheck);
    }

    private static void BuildAirAnchorSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddGcdIfUnlocked(slot, ActionId.AirAnchor);
        AddSelfAbilityIfReady(slot, ActionId.BarrelStabilizer);
    }

    private static void BuildChainSawSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddGcdIfUnlocked(slot, ActionId.ChainSaw);
    }

    private static void BuildExcavatorSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddGcdIfUnlocked(slot, ActionId.Excavator);
        AddTargetAbilityWithoutReadinessGate(slot, LevelAtLeast(80) ? ActionId.AutomatonQueen : ActionId.RookAutoturret);
        AddSelfAbilityIfReady(slot, ActionId.Reassemble);
    }

    private static void BuildSecondDrillSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddGcdIfUnlocked(slot, ActionId.Drill);
        AddTargetAbilityIfReady(slot, ActionId.Checkmate);
        AddTargetAbilityIfReady(slot, ActionId.Wildfire);
    }

    private static void BuildFullMetalFieldSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddGcdIfUnlocked(slot, ActionId.FullMetalField);
        AddTargetAbilityIfReady(slot, ActionId.DoubleCheck);
        AddSelfAbilityWithoutReadinessGate(slot, ActionId.Hypercharge);
    }

    private static bool CanStart()
    {
        return !MachinistSpellHelper.ShouldStopActions()
            && IsGcdUnlocked(ActionId.Drill)
            && (!IsAirAnchorFirstOpenerActive() || IsGcdUnlocked(ActionId.AirAnchor));
    }

    private static void PrepareOpenerSlot(Slot slot)
    {
        slot.MaxDuration = OpenerSlotMaxDurationMs;
    }

    private static void AddGcdIfUnlocked(Slot slot, uint actionId)
    {
        AddGcdIfReady(slot, actionId, IsGcdUnlocked(actionId));
    }

    private static void AddGcdIfReady(Slot slot, uint actionId, bool isReady)
    {
        if (!isReady)
            return;

        slot.Add(TargetSpell(actionId));
    }

    private static void AddTargetAbilityIfReady(Slot slot, uint actionId)
    {
        AddAbilityIfReady(slot, TargetAbility(actionId));
    }

    private static void AddSelfAbilityIfReady(Slot slot, uint actionId)
    {
        AddAbilityIfReady(slot, SelfAbility(actionId));
    }

    private static void AddTargetAbilityWithoutReadinessGate(Slot slot, uint actionId)
    {
        slot.Add(TargetAbility(actionId));
    }

    private static void AddSelfAbilityWithoutReadinessGate(Slot slot, uint actionId)
    {
        slot.Add(SelfAbility(actionId));
    }

    private static void AddAbilityIfReady(Slot slot, Spell spell)
    {
        if (spell.IsReadyWithCanCast())
            slot.Add(spell);
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

    private static bool IsGcdUnlocked(uint actionId)
    {
        return actionId switch
        {
            ActionId.Drill => LevelAtLeast(58),
            ActionId.AirAnchor => LevelAtLeast(76),
            ActionId.ChainSaw => LevelAtLeast(90),
            ActionId.Excavator => LevelAtLeast(96),
            ActionId.FullMetalField => LevelAtLeast(100),
            _ => true,
        };
    }

    private static bool IsAirAnchorFirstOpenerActive()
    {
        return MachinistTimelineState.IsActive(MachinistTimelineVariable.OpenerAirAnchorFirst);
    }

    private static bool LevelAtLeast(int level)
    {
        var currentLevel = HelperRuntime.GetCurrentLevel();
        return currentLevel <= 0 || currentLevel >= level;
    }
}
