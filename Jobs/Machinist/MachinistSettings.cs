namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistSettings : AcrSettings
{
    public const string CombatModeDaily = "日随模式";
    public const string CombatModeHighEnd = "高难模式";
    public static readonly string[] CombatModeOptions = [CombatModeDaily, CombatModeHighEnd];

    public const string TargetSelectionManual = "手动目标";
    public const string TargetSelectionNearestEnemy = "最近敌人";
    public static readonly string[] TargetSelectionOptions = [TargetSelectionManual, TargetSelectionNearestEnemy];

    public string CombatMode = CombatModeDaily;
    public string TargetSelection = TargetSelectionManual;

    public int FirstBurstAnchorMs { get; set; } = 120_000;
    public int BurstWindowLeadMs { get; set; } = 2_500;
    public int BurstWindowTailMs { get; set; } = 18_000;
    public int StrongGcdLookaheadMs { get; set; } = 6_000;
    public int HyperchargeToolCooldownLookaheadMs { get; set; } = 8_000;
    public int BatteryBurstSpendThreshold { get; set; } = 50;
    public int BatteryOvercapSpendThreshold { get; set; } = 90;
    public int HeatOvercapThreshold { get; set; } = 90;

    public bool IsHighEndMode => CombatMode == CombatModeHighEnd;
}
