using HiAuRo.ACR.TargetResolvers;
using OmenTools.Dalamud.Services.ObjectTable.Abstractions.ObjectKinds;

namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistTargetResolver : ITargetResolver
{
    private readonly ITargetResolver _nearestEnemy = new TargetResolver_最近敌人();

    public bool ResolveTarget(out IBattleChara agent)
    {
        return _nearestEnemy.ResolveTarget(out agent);
    }
}
