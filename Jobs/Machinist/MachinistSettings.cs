namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistSettings : AcrSettings
{
    public const string CombatModeDaily = "日随模式";
    public const string CombatModeHighEnd = "高难模式";
    public static readonly string[] CombatModeOptions = [CombatModeDaily, CombatModeHighEnd];
    public const string BatteryStrategyBudgetFirst = "预算优先";
    public const string BatteryStrategyFullFirst = "满电优先";
    public const string BatteryStrategyThresholdFirst = "阈值优先";
    public static readonly string[] BatteryStrategyOptions = [BatteryStrategyBudgetFirst, BatteryStrategyFullFirst, BatteryStrategyThresholdFirst];

    public string CombatMode = CombatModeDaily;
    public string BatteryStrategy = BatteryStrategyBudgetFirst;

    public int FirstBurstAnchorMs { get; set; } = 120_000;
    public int BurstWindowLeadMs { get; set; } = 2_500;
    public int BurstWindowTailMs { get; set; } = 18_000;
    public int StrongGcdLookaheadMs { get; set; } = 6_000;
    public int HyperchargeToolCooldownLookaheadMs { get; set; } = 8_000;
    public int BatteryBurstSpendThreshold { get; set; } = 50;
    public int BatteryOvercapSpendThreshold { get; set; } = 90;
    public int HeatOvercapThreshold { get; set; } = 90;
    public int BatteryThresholdStrategySpendThreshold = 70;
    public float DailyWeakTargetBurstHpThreshold = 0.12f;
    public float DailyDumpResourcesHpThreshold = 0.03f;
    public bool DailyMinionResourceGuardEnabled = true;
    public float DailyQueenHpThreshold = 0.75f;
    public bool IsHighEndMode => CombatMode == CombatModeHighEnd;
}
