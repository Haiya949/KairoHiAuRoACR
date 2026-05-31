using KairoHiAuRoACR.Jobs.BlackMage.Opener;
using KairoHiAuRoACR.Jobs.BlackMage.Resolvers.GCD;
using KairoHiAuRoACR.Jobs.BlackMage.Resolvers.OffGCD;
using KairoHiAuRoACR.Jobs.BlackMage.Triggers;
using HiAuRoJob = HiAuRo.ACR.Jobs;

namespace KairoHiAuRoACR.Jobs.BlackMage;

public sealed class BlackMageRotationEntry : IRotationEntry, ISettingsProvider<BlackMageSettings>
{
    private readonly List<SlotResolverData> _slotResolvers =
    [
        new() { Resolver = new BlackMageLeyLinesResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new BlackMageTriplecastResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new BlackMageSwiftcastResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new BlackMageManafontResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new BlackMageTransposeResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new BlackMageAmplifierResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new BlackMageAoeGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new BlackMageSingleTargetGcdResolver(), Mode = SlotMode.Gcd },
    ];

    public string AuthorName { get; } = "Kairo";
    public bool UseCustomUi { get; } = false;
    public IEnumerable<HiAuRoJob> TargetJobs { get; } = [HiAuRoJob.BLM];
    public BlackMageSettings Settings { get; set; } = new();

    public Rotation? Build(string settingFolder)
    {
        BlackMageSpellHelper.Configure(Settings);
        var targetResolver = new BlackMageTargetResolver();

        return new Rotation
        {
            SlotResolvers = _slotResolvers,
            Opener = new BlackMageOpener(),
            EventHandler = new BlackMageRotationEventHandler(),
            TriggerActions =
            [
                new TriggerAction_Hotkey(),
                new TriggerAction_Potion(),
            ],
            TargetResolvers = [targetResolver],
            AcrType = AcrType.PvE,
            MinLevel = 70,
            MaxLevel = 100,
            TargetJob = HiAuRoJob.BLM,
            Description = "Kairo HiAuRo BLM level 100 high-end rotation"
        };
    }

    public IRotationUI? GetRotationUI() => new BlackMageRotationUi(Settings);

    public void OnDrawSetting()
    {
    }

    public void Dispose()
    {
    }

    public void OnEnterRotation()
    {
        BlackMageSpellHelper.Configure(Settings);
        BlackMageSpellHelper.Reset();
    }

    public void OnExitRotation()
    {
        BlackMageSpellHelper.Reset();
    }
}
