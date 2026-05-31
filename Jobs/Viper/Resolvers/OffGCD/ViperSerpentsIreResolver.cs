namespace KairoHiAuRoACR.Jobs.Viper.Resolvers.OffGCD;

public sealed class ViperSerpentsIreResolver : ISlotResolver
{
    private Spell? _spell;

    public int Check()
    {
        if (ViperSpellHelper.ShouldStopActions())
            return -100;

        if (ViperSpellHelper.ShouldBlockCombatRotationActions())
            return -90;

        _spell = ViperSpellHelper.GetSerpentsIreOffGcd();
        return _spell is not null ? 0 : -1;
    }

    public void Build(Slot slot)
    {
        if (_spell is not null)
            slot.Add(_spell);
    }
}
