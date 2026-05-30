using System.Collections.Concurrent;

namespace KairoHiAuRoACR.Jobs.Machinist;

public static class MachinistTimelineState
{
    public static readonly string[] PublicVariables =
    [
        MachinistTimelineVariable.ForceBurst,
        MachinistTimelineVariable.ForbidBurst,
        MachinistTimelineVariable.HoldAllBurst,
        MachinistTimelineVariable.ReleaseDelayedBurst,
        MachinistTimelineVariable.DumpResources,
        MachinistTimelineVariable.HoldWildfire,
        MachinistTimelineVariable.DumpWildfire,
        MachinistTimelineVariable.HoldBarrel,
        MachinistTimelineVariable.DumpBarrel,
        MachinistTimelineVariable.HoldCheckmateDoubleCheck,
        MachinistTimelineVariable.DumpCheckmateDoubleCheck,
        MachinistTimelineVariable.HoldBattery,
        MachinistTimelineVariable.DumpBattery,
        MachinistTimelineVariable.HoldHeat,
        MachinistTimelineVariable.DumpHeat,
        MachinistTimelineVariable.HoldStrongGcd,
        MachinistTimelineVariable.DumpStrongGcd,
        MachinistTimelineVariable.HoldReassembleDrill,
        MachinistTimelineVariable.DumpReassembleDrill,
        MachinistTimelineVariable.OpenerAirAnchorFirst,
    ];

    private static readonly ConcurrentDictionary<string, int> Variables = new();

    public static bool IsActive(string variableName)
    {
        ExposeDefaults();
        return Variables.TryGetValue(variableName, out var value) && value != 0;
    }

    public static void Set(string variableName, bool active)
    {
        ExposeDefaults();
        Variables[variableName] = active ? 1 : 0;
    }

    public static void SetMany(IEnumerable<string> variableNames, bool active)
    {
        foreach (var variableName in variableNames)
            Set(variableName, active);
    }

    public static void ResetAll()
    {
        ExposeDefaults();
        foreach (var variableName in PublicVariables)
            Variables[variableName] = 0;
    }

    public static void ExposeDefaults()
    {
        foreach (var variableName in PublicVariables)
            Variables.TryAdd(variableName, 0);
    }
}
