namespace KairoHiAuRoACR.Jobs.Machinist;

public static class MachinistBurstPlanner
{
    public const int BurstCycleMs = 120_000;

    public static bool IsInBurstWindow(int battleTimeMs, int firstAnchorMs, int leadMs, int tailMs)
    {
        var elapsed = GetElapsedInBurstCycle(battleTimeMs, firstAnchorMs);
        return elapsed <= tailMs || elapsed >= BurstCycleMs - leadMs;
    }

    public static int GetTimeToNextBurstWindow(int battleTimeMs, int firstAnchorMs, int leadMs, int tailMs)
    {
        if (IsInBurstWindow(battleTimeMs, firstAnchorMs, leadMs, tailMs))
            return 0;

        var elapsed = GetElapsedInBurstCycle(battleTimeMs, firstAnchorMs);
        return Math.Max(0, BurstCycleMs - leadMs - elapsed);
    }

    public static int GetTimeToNextBurstAnchor(int battleTimeMs, int firstAnchorMs)
    {
        var anchor = GetCurrentOrPreviousBurstAnchor(battleTimeMs, firstAnchorMs);
        if (battleTimeMs <= anchor)
            return anchor - battleTimeMs;

        return anchor + BurstCycleMs - battleTimeMs;
    }

    private static int GetCurrentOrPreviousBurstAnchor(int battleTimeMs, int firstAnchorMs)
    {
        if (battleTimeMs <= firstAnchorMs)
            return firstAnchorMs;

        var cycles = (battleTimeMs - firstAnchorMs) / BurstCycleMs;
        return firstAnchorMs + cycles * BurstCycleMs;
    }

    private static int GetElapsedInBurstCycle(int battleTimeMs, int firstAnchorMs)
    {
        var elapsed = battleTimeMs - firstAnchorMs;
        var remainder = elapsed % BurstCycleMs;
        return remainder < 0 ? remainder + BurstCycleMs : remainder;
    }
}
