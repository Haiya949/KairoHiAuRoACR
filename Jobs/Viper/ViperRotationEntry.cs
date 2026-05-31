using KairoHiAuRoACR.Jobs.Viper.Resolvers.GCD;
using KairoHiAuRoACR.Jobs.Viper.Resolvers.OffGCD;
using HiAuRoJob = HiAuRo.ACR.Jobs;

namespace KairoHiAuRoACR.Jobs.Viper;

public sealed class ViperRotationEntry : IRotationEntry, ISettingsProvider<ViperSettings>
{
    private readonly List<SlotResolverData> _slotResolvers =
    [
        new() { Resolver = new ViperFollowUpAbilityResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new ViperSerpentsIreResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new ViperTrueNorthResolver(), Mode = SlotMode.OffGcd },
        new() { Resolver = new ViperReawakenGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new ViperDreadwinderGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new ViperRattlingCoilGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new ViperAoeGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new ViperRangedFallbackGcdResolver(), Mode = SlotMode.Gcd },
        new() { Resolver = new ViperBaseGcdResolver(), Mode = SlotMode.Gcd },
    ];

    public string AuthorName { get; } = "Kairo";
    public bool UseCustomUi { get; } = false;
    public IEnumerable<HiAuRoJob> TargetJobs { get; } = [HiAuRoJob.VPR];
    public ViperSettings Settings { get; set; } = new();

    public Rotation? Build(string settingFolder)
    {
        ViperSpellHelper.Configure(Settings);
        ViperTimelineState.ExposeDefaults();
        var targetResolver = new ViperTargetResolver();

        return new Rotation
        {
            SlotResolvers = _slotResolvers,
            Opener = new ViperQuickOpener(),
            EventHandler = new ViperRotationEventHandler(),
            TriggerActions =
            [
                new TriggerAction_TimelineVariable(),
                new TriggerAction_Hotkey(),
                new TriggerAction_Potion(),
            ],
            TargetResolvers = [targetResolver],
            AcrType = AcrType.PvE,
            MinLevel = 80,
            MaxLevel = 100,
            TargetJob = HiAuRoJob.VPR,
            Description = "Kairo HiAuRo VPR rotation"
        };
    }

    public IRotationUI? GetRotationUI() => new ViperRotationUi(Settings);

    public void OnDrawSetting()
    {
    }

    public void Dispose()
    {
    }

    public void OnEnterRotation()
    {
        ViperSpellHelper.Configure(Settings);
        ViperSpellHelper.ResetCombatState();
        ViperTimelineState.ResetAll();
    }

    public void OnExitRotation()
    {
        ViperSpellHelper.ResetCombatState();
        ViperTimelineState.ResetAll();
    }
}
