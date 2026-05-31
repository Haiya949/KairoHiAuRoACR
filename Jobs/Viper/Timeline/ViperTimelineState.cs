namespace KairoHiAuRoACR.Jobs.Viper;

public static class ViperTimelineState
{
    private static readonly Dictionary<string, bool> Values = new(StringComparer.Ordinal);

    public static void ExposeDefaults()
    {
        foreach (var variable in ViperTimelineVariable.All)
            Values.TryAdd(variable, false);
    }

    public static bool IsActive(string variableName)
    {
        ExposeDefaults();
        return Values.GetValueOrDefault(variableName);
    }

    public static void Set(string variableName, bool value)
    {
        ExposeDefaults();
        if (!ViperTimelineVariable.All.Contains(variableName, StringComparer.Ordinal))
            return;

        Values[variableName] = value;
    }

    public static void SetMany(IEnumerable<string> variableNames, bool value)
    {
        foreach (var variableName in variableNames)
            Set(variableName, value);
    }

    public static void ResetAll()
    {
        ExposeDefaults();
        foreach (var variableName in ViperTimelineVariable.All)
            Values[variableName] = false;
    }
}
