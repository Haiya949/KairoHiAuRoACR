using HiAuRo.ACR.TargetResolvers;
using OmenTools.Dalamud.Services.ObjectTable.Abstractions.ObjectKinds;

namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistTargetResolver : ITargetResolver
{
    private readonly MachinistSettings _settings;
    private readonly ITargetResolver _nearestEnemy = new TargetResolver_最近敌人();

    public MachinistTargetResolver(MachinistSettings settings)
    {
        _settings = settings;
    }

    public bool ResolveTarget(out IBattleChara agent)
    {
        agent = null!;

        if (_settings.TargetSelection == MachinistSettings.TargetSelectionNearestEnemy)
            return _nearestEnemy.ResolveTarget(out agent);

        return false;
    }
}
