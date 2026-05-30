namespace KairoHiAuRoACR.Jobs.Ninja;

public sealed class NinjaRotationUi : IRotationUI
{
    private readonly NinjaSettings _settings;

    public NinjaRotationUi(NinjaSettings settings)
    {
        _settings = settings;
    }

    public void RegisterControls(IAcrUiBuilder builder)
    {
        builder.AddMainControl();
        builder.AddBuiltinQt(BuiltinQt.Hold, false);
        builder.AddTab("忍者");

        builder.AddGroup("诊断");
        builder.AddCheckbox("打印天地人状态", ref _settings.LogTenChiJinStatus);
        builder.AddIntInput("打印间隔(ms)", ref _settings.LogIntervalMs, 100, 1_000);
        builder.AddLabel("日志输出: [Kairo NIN] HasTenChiJin=True/False");
    }
}
