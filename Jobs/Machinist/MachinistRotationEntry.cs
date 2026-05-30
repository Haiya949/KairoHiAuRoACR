using KairoHiAuRoACR.Jobs.Machinist.Resolvers.GCD;
using KairoHiAuRoACR.Jobs.Machinist.Resolvers.OffGCD;
using HiAuRoJob = HiAuRo.ACR.Jobs;

namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistRotationEntry : IRotationEntry, ISettingsProvider<MachinistSettings>
{
    private readonly List<SlotResolverData> _slotResolvers =
    [
        new() { Resolver = new MachinistQueenOverdriveResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new MachinistWildfireResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new MachinistBarrelStabilizerResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new MachinistHyperchargeResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new MachinistQueenResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new MachinistReassembleResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new MachinistGaussRoundResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new MachinistAoeGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new MachinistOverheatedGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new MachinistStrongGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new MachinistBaseGcdResolver(), Mode = SlotMode.Gcd },
    ];

    public string AuthorName { get; } = "Kairo";
    public bool UseCustomUi { get; } = false;
    public IEnumerable<HiAuRoJob> TargetJobs { get; } = [HiAuRoJob.MCH];
    public MachinistSettings Settings { get; set; } = new();

    public Rotation? Build(string settingFolder)
    {
        MachinistSpellHelper.Configure(Settings);
        var targetResolver = new MachinistTargetResolver();

        return new Rotation
        {
            SlotResolvers = _slotResolvers,
            Opener = new MachinistOpener(),
            EventHandler = new MachinistRotationEventHandler(),
            TriggerActions =
            [
                new TriggerAction_TimelineVariable(),
                new TriggerAction_Hotkey(),
                new TriggerAction_Potion(),
            ],
            TargetResolvers = [targetResolver],
            AcrType = AcrType.PvE,
            MinLevel = 1,
            MaxLevel = 100,
            TargetJob = HiAuRoJob.MCH,
            Description = "Kairo HiAuRo MCH rotation"
        };
    }

    public IRotationUI? GetRotationUI() => new MachinistRotationUi(Settings);

    public void OnDrawSetting()
    {
    }

    public void Dispose()
    {
    }

    public void OnEnterRotation()
    {
        MachinistSpellHelper.Configure(Settings);
        MachinistSpellHelper.Reset();
        MachinistTimelineState.ResetAll();
    }

    public void OnExitRotation()
    {
        MachinistSpellHelper.Reset();
        MachinistTimelineState.ResetAll();
    }
}
