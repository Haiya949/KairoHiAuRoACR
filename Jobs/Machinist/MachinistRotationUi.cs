namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistRotationUi : IRotationUI
{
    public void RegisterControls(IUiBuilder builder)
    {
        builder.AddMainControl();
        builder.AddBuiltinQt(BuiltinQt.Burst, true);
        builder.AddBuiltinQt(BuiltinQt.Hold, false);
        builder.AddTab("mch", "MCH");
        builder.AddQtToggle("MCH_MinimalLoop", true, "基础循环");
    }
}

