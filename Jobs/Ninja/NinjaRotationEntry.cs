using HiAuRoJob = HiAuRo.ACR.Jobs;

namespace KairoHiAuRoACR.Jobs.Ninja;

public sealed class NinjaRotationEntry : IRotationEntry, ISettingsProvider<NinjaSettings>
{
    public string AuthorName { get; } = "Kairo";
    public bool UseCustomUi { get; } = false;
    public IEnumerable<HiAuRoJob> TargetJobs { get; } = [HiAuRoJob.NIN];
    public NinjaSettings Settings { get; set; } = new();

    public Rotation? Build(string settingFolder)
    {
        return new Rotation
        {
            SlotResolvers = [],
            EventHandler = new NinjaRotationEventHandler(Settings),
            AcrType = AcrType.PvE,
            MinLevel = 70,
            MaxLevel = 100,
            TargetJob = HiAuRoJob.NIN,
            Description = "Kairo HiAuRo NIN Ten Chi Jin status diagnostic"
        };
    }

    public IRotationUI? GetRotationUI() => new NinjaRotationUi(Settings);

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
