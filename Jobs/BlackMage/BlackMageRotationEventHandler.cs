namespace KairoHiAuRoACR.Jobs.BlackMage;

public sealed class BlackMageRotationEventHandler : IRotationEventHandler
{
    public void OnPreCombat()
    {
    }

    public void OnResetBattle()
    {
        BlackMageSpellHelper.Reset();
    }

    public void OnNoTarget()
    {
    }

    public void OnSpellCastSuccess(Slot slot, Spell spell)
    {
        BlackMageSpellHelper.RecordCombatActionUse(spell.Id);
    }

    public Slot? BeforeSpell(Slot slot)
    {
        return null;
    }

    public void AfterSpell(Slot slot, Spell spell)
    {
    }

    public void OnBattleUpdate(int battleTimeMs)
    {
        BlackMageSpellHelper.UpdateBattleTime(battleTimeMs);
    }

    public void OnTerritoryChanged()
    {
        BlackMageSpellHelper.Reset();
    }

    public void OnGameEvent(ITriggerCondParams eventParams)
    {
    }

    public void OnPhaseChanged(string phaseId, string phaseName)
    {
    }
}
