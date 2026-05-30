namespace KairoHiAuRoACR.Jobs.Machinist;

public static class MachinistResourcePlanner
{
    public const int CycleGcdSlots = 48;
    public const int OpenerCycleMajorGcdSlots = 15;
    public const int WildfireBarrelWindowSlots = 3;
    public const int OpenerCycleFillerSlots = 30;
    public const int HeatPerComboGcd = 5;
    public const int PaidHyperchargeHeatCost = 50;
    public const int PaidHyperchargeComboSlots = 3;
    public const int PaidHyperchargePreventedHeat = PaidHyperchargeComboSlots * HeatPerComboGcd;
    public const int PaidHyperchargeHeatRelief = PaidHyperchargeHeatCost + PaidHyperchargePreventedHeat;
    public const int OpenerCycleComboHeat = OpenerCycleFillerSlots * HeatPerComboGcd;
    public const int OpenerCycleHeatAfterOnePaidHypercharge = OpenerCycleComboHeat - PaidHyperchargeHeatRelief;
    public const int OpenerCycleToolBattery = 140;
    public const int OpenerCycleComboBattery = 90;
    public const int OpenerCycleBattery = OpenerCycleToolBattery + OpenerCycleComboBattery;
    public const int PreBurstBudgetLookaheadMs = 45_000;

    private const int StandardGcdMs = 2_500;
    private const int HeatGaugeCap = 100;
    private const int BatteryGaugeCap = 100;
    private const int BatterySpendFloor = 50;
    private const int BatteryPressureLine = 90;
    private const int PreBurstResourceHoldMs = 20_000;
    private const int ExactHeatReleaseMinMs = 20_000;
    private const int ExactHeatReleaseMaxMs = 30_000;

    public static int GetPaidHyperchargeCountForCycle(int fillerSlots = OpenerCycleFillerSlots)
    {
        var comboHeat = Math.Max(0, fillerSlots) * HeatPerComboGcd;
        if (comboHeat <= HeatGaugeCap)
            return 0;

        return (int)Math.Ceiling((comboHeat - HeatGaugeCap) / (double)PaidHyperchargeHeatRelief);
    }

    public static int GetProjectedHeatAtNextBurst(int currentHeat, int timeToNextBurstAnchorMs)
    {
        var fillerSlots = GetProjectedGcdSlots(timeToNextBurstAnchorMs);
        return Math.Max(0, currentHeat) + fillerSlots * HeatPerComboGcd;
    }

    public static bool ShouldSpendHeatBeforeBurst(
        int currentHeat,
        int timeToNextBurstAnchorMs,
        bool isInBurstWindow,
        double wildfireCooldownMs)
    {
        if (currentHeat < PaidHyperchargeHeatCost)
            return false;

        if (isInBurstWindow)
            return true;

        if (IsExactHeatPreBurstRelease(currentHeat, wildfireCooldownMs))
            return true;

        if (timeToNextBurstAnchorMs <= PreBurstResourceHoldMs)
            return false;

        if (timeToNextBurstAnchorMs > PreBurstBudgetLookaheadMs)
            return currentHeat >= BatteryPressureLine;

        return GetProjectedHeatAtNextBurst(currentHeat, timeToNextBurstAnchorMs) > HeatGaugeCap;
    }

    public static bool ShouldSpendBatteryBeforeBurst(int currentBattery, int timeToNextBurstAnchorMs)
    {
        if (currentBattery < BatterySpendFloor)
            return false;

        if (timeToNextBurstAnchorMs <= PreBurstResourceHoldMs)
            return false;

        if (currentBattery >= BatteryPressureLine)
            return true;

        return GetProjectedBatteryAtNextBurst(currentBattery, timeToNextBurstAnchorMs) > BatteryGaugeCap;
    }

    public static int GetProjectedBatteryAtNextBurst(int currentBattery, int timeToNextBurstAnchorMs)
    {
        var projectedGain = (int)Math.Floor(Math.Max(0, timeToNextBurstAnchorMs) / (double)MachinistBurstPlanner.BurstCycleMs * OpenerCycleBattery);
        return Math.Max(0, currentBattery) + projectedGain;
    }

    private static bool IsExactHeatPreBurstRelease(int currentHeat, double wildfireCooldownMs)
    {
        return currentHeat >= HeatGaugeCap
            && wildfireCooldownMs >= ExactHeatReleaseMinMs
            && wildfireCooldownMs <= ExactHeatReleaseMaxMs;
    }

    private static int GetProjectedGcdSlots(int timeToNextBurstAnchorMs)
    {
        return Math.Max(0, timeToNextBurstAnchorMs) / StandardGcdMs;
    }
}
