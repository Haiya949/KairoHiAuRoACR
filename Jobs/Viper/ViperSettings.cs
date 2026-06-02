namespace KairoHiAuRoACR.Jobs.Viper;

public sealed class ViperSettings : AcrSettings
{
    public const string CombatModeDaily = "日随模式";
    public const string CombatModeHighEnd = "高难模式";
    public static readonly string[] CombatModeOptions = [CombatModeDaily, CombatModeHighEnd];

    public string CombatMode = CombatModeDaily;

    public int FirstBurstAnchorMs { get; set; } = 1_000;
    public int BurstWindowLeadMs { get; set; } = 2_500;
    public int BurstWindowTailMs { get; set; } = 17_500;
    public int ReawakenPreBurstHoldMs { get; set; } = 30_000;
    public int SerpentsIreResourceForecastLookaheadMs { get; set; } = 30_000;
    public int SerpentsIreResourceForecastSafetyMs { get; set; } = 600;
    public int BuffRefreshThresholdMs { get; set; } = 8_000;
    public int ReawakenBuffCoverageMs { get; set; } = 18_000;
    public int RattlingCoilOvercapStacks { get; set; } = 3;
    public int AoeEnemyCount { get; set; } = 3;
    public int TrueNorthDecisionLeadMs { get; set; } = 1_200;
    public int TrueNorthMinWeaveMs { get; set; } = 700;

    public bool IsHighEndMode => CombatMode == CombatModeHighEnd;
}
