using HiAuRo.Infrastructure;

namespace KairoHiAuRoACR.Jobs.Ninja;

public sealed class NinjaRotationEventHandler : IRotationEventHandler
{
    private readonly NinjaSettings _settings;
    private int _nextLogAtMs;

    public NinjaRotationEventHandler(NinjaSettings settings)
    {
        _settings = settings;
    }

    public void OnPreCombat()
    {
    }

    public void OnResetBattle()
    {
        _nextLogAtMs = 0;
    }

    public void OnNoTarget()
    {
    }

    public void OnSpellCastSuccess(Slot slot, Spell spell)
    {
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
        if (!_settings.LogTenChiJinStatus)
            return;

        var intervalMs = Math.Max(100, _settings.LogIntervalMs);
        if (battleTimeMs < _nextLogAtMs)
            return;

        var hasTenChiJin = NINHelper.HasTenChiJin;
        Hi.Print($"[Kairo NIN] HasTenChiJin={hasTenChiJin}");
        _nextLogAtMs = battleTimeMs + intervalMs;
    }

    public void OnTerritoryChanged()
    {
        _nextLogAtMs = 0;
    }

    public void OnGameEvent(ITriggerCondParams eventParams)
    {
    }

    public void OnPhaseChanged(string phaseId, string phaseName)
    {
    }
}
