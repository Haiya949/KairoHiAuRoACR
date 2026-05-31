namespace KairoHiAuRoACR.Jobs.Viper.Resolvers.GCD;

public sealed class ViperReawakenGcdResolver : ISlotResolver
{
    private Spell? _spell;

    public int Check()
    {
        if (ViperSpellHelper.ShouldStopActions())
            return -100;

        if (ViperSpellHelper.ShouldBlockCombatRotationActions())
            return -90;

        _spell = ViperSpellHelper.GetReawakenGcd();
        return _spell is not null ? 0 : -1;
    }

    public void Build(Slot slot)
    {
        if (_spell is not null)
            slot.Add(_spell);
    }
}
