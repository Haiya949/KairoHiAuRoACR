using HiAuRo.Runtime;
using ActionId = HiAuRo.Helper.VPRHelper.EN.Skills;

namespace KairoHiAuRoACR.Jobs.Viper;

public sealed class ViperQuickOpener : IOpener
{
    private const int OpenerSlotMaxDurationMs = 3_500;

    private static readonly (Func<bool> IsAvailable, Action<Slot> Build)[] QuickOpenerSteps =
    [
        (static () => true, BuildFirstGcdSlot),
        (static () => true, BuildSecondGcdAndSerpentsIreSlot),
        (static () => true, BuildDreadwinderSlot),
        (static () => true, BuildHuntersCoilSlot),
        (static () => true, BuildSwiftskinsCoilSlot),
        (static () => true, BuildBaseFinisherSlot),
    ];

    private List<Action<Slot>>? _activeSequence;

    public uint Level => 80;
    public List<Action<Slot>> Sequence => _activeSequence ??= BuildSequence();

    public int StartCheck()
    {
        _activeSequence = BuildSequence();
        return CanStart() && _activeSequence.Count > 0 ? 0 : -1;
    }

    public int StopCheck(int index) => -1;

    public void InitCountDown(CountDownHandler handler)
    {
        if (QTHelper.IsEnabled(QTKey.QuickOpener))
            handler.AddAction(100, ActionId.Slither, SpellTargetType.Target);
    }

    private static List<Action<Slot>> BuildSequence()
    {
        return QuickOpenerSteps
            .Where(step => step.IsAvailable())
            .Select(step => step.Build)
            .ToList();
    }

    private static bool CanStart()
    {
        return QTHelper.IsEnabled(QTKey.QuickOpener)
            && !ViperSpellHelper.ShouldStopActions()
            && ActionId.ReavingFangs.IsLevelEnough();
    }

    private static void PrepareSlot(Slot slot)
    {
        slot.MaxDuration = OpenerSlotMaxDurationMs;
    }

    private static void BuildFirstGcdSlot(Slot slot)
    {
        PrepareSlot(slot);
        slot.Add(TargetSpell(ActionId.ReavingFangs));
    }

    private static void BuildSecondGcdAndSerpentsIreSlot(Slot slot)
    {
        PrepareSlot(slot);
        slot.Add(TargetSpell(ActionId.SwiftskinsSting));
        slot.Add(SelfAbility(ActionId.SerpentsIre));
    }

    private static void BuildDreadwinderSlot(Slot slot)
    {
        PrepareSlot(slot);
        slot.Add(TargetSpell(ActionId.Vicewinder));
    }

    private static void BuildHuntersCoilSlot(Slot slot)
    {
        PrepareSlot(slot);
        slot.Add(TargetSpell(ActionId.HuntersCoil));
        slot.Add(TargetAbility(ActionId.TwinfangBite));
        slot.Add(TargetAbility(ActionId.TwinbloodBite));
    }

    private static void BuildSwiftskinsCoilSlot(Slot slot)
    {
        PrepareSlot(slot);
        slot.Add(TargetSpell(ActionId.SwiftskinsCoil));
        slot.Add(TargetAbility(ActionId.TwinbloodBite));
        slot.Add(TargetAbility(ActionId.TwinfangBite));
    }

    private static void BuildBaseFinisherSlot(Slot slot)
    {
        PrepareSlot(slot);
        slot.Add(ViperSpellHelper.GetBaseGcd() ?? TargetSpell(ActionId.HindsbaneFang));
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
}
