using HiAuRo.Runtime;
using KairoHiAuRoACR.Jobs.Machinist.Data;

namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistOpener : IOpener
{
    private static readonly uint[] StandardGcdOrder =
    [
        MachinistActionId.Drill,
        MachinistActionId.AirAnchor,
        MachinistActionId.ChainSaw,
        MachinistActionId.Excavator,
        MachinistActionId.Drill,
        MachinistActionId.FullMetalField,
    ];

    public uint Level => 58;

    public List<Action<Slot>> Sequence { get; } = [];

    public MachinistOpener()
    {
        Sequence.Add(BuildFirstDrillSlot);
        Sequence.Add(BuildAirAnchorSlot);
        Sequence.Add(BuildChainSawSlot);
        Sequence.Add(BuildExcavatorSlot);
        Sequence.Add(BuildSecondDrillSlot);
        Sequence.Add(BuildFullMetalFieldSlot);
    }

    public int StartCheck()
    {
        if (MachinistSpellHelper.ShouldStopActions())
            return -100;

        if (global::HiAuRo.Data.Target.Current is null)
            return -1;

        return StandardGcdOrder.Any(IsActionReadyForOpener) ? 0 : -2;
    }

    public int StopCheck(int index)
    {
        if (MachinistSpellHelper.ShouldStopActions())
            return 0;

        if (global::HiAuRo.Data.Target.Current is null)
            return 0;

        return -1;
    }

    public void InitCountDown(CountDownHandler handler)
    {
        handler.AddAction(4, MachinistActionId.Reassemble, SpellTargetType.Self);
    }

    private static void BuildFirstDrillSlot(Slot slot)
    {
        AddTargetGcd(slot, MachinistActionId.Drill);
        AddTargetAbility(slot, MachinistActionId.Checkmate);
        AddTargetAbility(slot, MachinistActionId.DoubleCheck);
    }

    private static void BuildAirAnchorSlot(Slot slot)
    {
        AddTargetGcd(slot, MachinistActionId.AirAnchor);
        AddSelfAbility(slot, MachinistActionId.BarrelStabilizer);
    }

    private static void BuildChainSawSlot(Slot slot)
    {
        AddTargetGcd(slot, MachinistActionId.ChainSaw);
    }

    private static void BuildExcavatorSlot(Slot slot)
    {
        AddTargetGcd(slot, MachinistActionId.Excavator);
        AddSelfAbility(slot, MachinistActionId.AutomatonQueen);
        AddSelfAbility(slot, MachinistActionId.Reassemble);
    }

    private static void BuildSecondDrillSlot(Slot slot)
    {
        AddTargetGcd(slot, MachinistActionId.Drill);
        AddTargetAbility(slot, MachinistActionId.Checkmate);
        AddTargetAbility(slot, MachinistActionId.Wildfire);
    }

    private static void BuildFullMetalFieldSlot(Slot slot)
    {
        AddTargetGcd(slot, MachinistActionId.FullMetalField);
        AddTargetAbility(slot, MachinistActionId.DoubleCheck);
        AddSelfAbility(slot, MachinistActionId.Hypercharge);
    }

    private static void AddTargetGcd(Slot slot, uint actionId)
    {
        AddIfReady(slot, new Spell(actionId, SpellTargetType.Target));
    }

    private static void AddTargetAbility(Slot slot, uint actionId)
    {
        AddIfReady(slot, new Spell(actionId, SpellTargetType.Target) { Type = SpellType.Ability });
    }

    private static void AddSelfAbility(Slot slot, uint actionId)
    {
        AddIfReady(slot, new Spell(actionId, SpellTargetType.Self) { Type = SpellType.Ability });
    }

    private static void AddIfReady(Slot slot, Spell spell)
    {
        if (spell.IsReadyWithCanCast())
            slot.Add(spell);
    }

    private static bool IsActionReadyForOpener(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Target).IsReadyWithCanCast();
    }
}
