namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistSettings : AcrSettings
{
    public int FirstBurstAnchorMs { get; set; } = 120_000;
    public int BurstWindowLeadMs { get; set; } = 2_500;
    public int BurstWindowTailMs { get; set; } = 18_000;
    public int StrongGcdLookaheadMs { get; set; } = 6_000;
    public int HyperchargeToolCooldownLookaheadMs { get; set; } = 8_000;
    public int LongFightBurstPlanMs { get; set; } = 30_000;
    public int PrepullReassembleCountdownMs { get; set; } = 4_500;
    public int CountdownPullActionQueueLeadMs { get; set; } = 250;
    public int BatteryBurstSpendThreshold { get; set; } = 50;
    public int BatteryOvercapSpendThreshold { get; set; } = 90;
    public int HeatOvercapThreshold { get; set; } = 90;
}
