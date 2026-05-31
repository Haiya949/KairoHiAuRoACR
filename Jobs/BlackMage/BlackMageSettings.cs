namespace KairoHiAuRoACR.Jobs.BlackMage;

public sealed class BlackMageSettings : AcrSettings
{
    public int FirstBurstAnchorMs = 7_000;
    public int BurstWindowLeadMs = 2_500;
    public int BurstWindowTailMs = 24_000;
    public int ThunderRefreshMs = 3_000;
    public float ThunderSkipTargetHpPercent = 0.03f;
    public int ManafontMpThreshold = 3_200;
    public int DespairMpThreshold = 1_600;
    public int FireIVNoHeartMpCost = 1_600;
    public int FireIVHeartMpCost = 800;
    public int AstralFireMinimumMpToContinue = 800;
    public int UmbralIceFullMpThreshold = 9_800;
    public int PolyglotDumpStacks = 2;
    public int AoeEnemyCount = 3;
}
