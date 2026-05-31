namespace KairoHiAuRoACR.Jobs.Viper.Resolvers.GCD;

public sealed class ViperDreadwinderGcdResolver : ISlotResolver
{
    private Spell? _spell;

    public int Check()
    {
        if (ViperSpellHelper.ShouldStopActions())
            return -100;

        if (ViperSpellHelper.ShouldBlockCombatRotationActions())
            return -90;

        _spell = ViperSpellHelper.GetDreadwinderGcd();
        if (_spell is null)
            return -1;

        return ViperSpellHelper.CanUseDreadwinderGcd(_spell) ? 0 : -3;
    }

    public void Build(Slot slot)
    {
        if (_spell is null || !ViperSpellHelper.CanUseDreadwinderGcd(_spell))
            return;

        slot.Add(_spell);
        ViperSpellHelper.MarkDreadwinderIssued(_spell.Id);
    }
}
