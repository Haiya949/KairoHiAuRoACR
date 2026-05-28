using KairoHiAuRoACR.Jobs.Machinist.Resolvers.GCD;
using KairoHiAuRoACR.Jobs.Machinist.Resolvers.OffGCD;
using HiAuRoJob = HiAuRo.ACR.Jobs;

namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistRotationEntry : IRotationEntry, ISettingsProvider<MachinistSettings>
{
    private readonly List<SlotResolverData> _slotResolvers =
    [
        new() { Resolver = new MachinistBurstAbilityResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new MachinistSingleTargetGcdResolver(), Mode = SlotMode.Gcd },
    ];

    public string AuthorName { get; } = "Kairo";
    public bool UseCustomUi { get; } = false;
    public IEnumerable<HiAuRoJob> TargetJobs { get; } = [HiAuRoJob.MCH];
    public MachinistSettings Settings { get; set; } = new();

    public Rotation? Build(string settingFolder)
    {
        return new Rotation
        {
            SlotResolvers = _slotResolvers,
            AcrType = AcrType.PvE,
            MinLevel = 1,
            MaxLevel = 100,
            TargetJob = HiAuRoJob.MCH,
            Description = "Kairo HiAuRo MCH framework"
        };
    }

    public IRotationUI? GetRotationUI() => new MachinistRotationUi();

    public void OnDrawSetting()
    {
    }

    public void Dispose()
    {
    }

    public void OnEnterRotation()
    {
    }

    public void OnExitRotation()
    {
    }
}
