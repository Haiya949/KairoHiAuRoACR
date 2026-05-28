namespace KairoHiAuRoACR.Jobs.Machinist.Resolvers.GCD;

public sealed class MachinistSingleTargetGcdResolver : ISlotResolver
{
    private const uint SplitShot = 2866;
    private const uint SlugShot = 2868;
    private const uint CleanShot = 2873;
    private const uint HeatedSplitShot = 7411;
    private const uint HeatedSlugShot = 7412;
    private const uint HeatBlast = 7410;
    private const uint Drill = 16498;
    private const uint AirAnchor = 16500;
    private const uint ChainSaw = 25788;

    private uint _nextSpell = HeatedSplitShot;

    public int Check()
    {
        if (Data.Target.Current == null)
            return -1;

        if (QTHelper.IsEnabled(BuiltinQt.Hold) || !QTHelper.IsEnabled("MCH_MinimalLoop"))
            return -1;

        _nextSpell = SelectSpell();
        return new Spell(_nextSpell, SpellTargetType.Target).IsReadyWithCanCast() ? 0 : -1;
    }

    public void Build(Slot slot)
    {
        slot.Add(new Spell(_nextSpell, SpellTargetType.Target));
    }

    private static uint SelectSpell()
    {
        if (MCHHelper.HasHypercharge && new Spell(HeatBlast, SpellTargetType.Target).IsReadyWithCanCast())
            return HeatBlast;

        if (new Spell(ChainSaw, SpellTargetType.Target).IsReadyWithCanCast())
            return ChainSaw;

        if (new Spell(AirAnchor, SpellTargetType.Target).IsReadyWithCanCast())
            return AirAnchor;

        if (new Spell(Drill, SpellTargetType.Target).IsReadyWithCanCast())
            return Drill;

        return ComboHelper.LastComboSpellId switch
        {
            SplitShot or HeatedSplitShot => SlugShot.GetActionChange(),
            SlugShot or HeatedSlugShot => CleanShot.GetActionChange(),
            _ => SplitShot.GetActionChange()
        };
    }
}

