# Kairo HiAuRo ACR 开发规范

## 定位

本工程是 Kairo 在 HiAuRo 框架下的 ACR 总包。输出文件固定为 `Kairo.dll`，作者目录固定为 `ACR/Kairo/`，不要按单职业命名 DLL。

## 官方文档优先级

开发必须严格遵循 HiAuRo 官方作者指南：

```text
E:\ff14\HiAuRo\HiAuRo-master\doc\ACR_AUTHOR_GUIDE.md
https://github.com/denghaoxuan991876906/HiAuRo/blob/master/doc/ACR_AUTHOR_GUIDE.md
```

优先级：

1. `ACR_AUTHOR_GUIDE.md`
2. HiAuRo 主工程源码中的接口定义
3. `HiAuRo.Helper` README 和源码
4. 本仓库 Kairo 文档
5. 旧 `E:\ff14\ACR\Kairo` 职业逻辑参考

如果发生冲突，按优先级高的执行。旧 Kairo 是另一个插件体系，不能覆盖 HiAuRo 官方开发原则。

当前目标：

- 使用 HiAuRo 原生 ACR 接口，不引入 AEAssist ACR API。
- 一个 DLL 支持多个职业，每个职业一个 `IRotationEntry`。
- Helper 按 `HiAuRo.Helper` README 规定作为 git submodule 引入。
- 旧 `E:\ff14\ACR\Kairo` 只作为职业策略、ID、开场和优先级参考。

## 运行时边界

必须按官方运行时全景图理解 ACR 执行顺序：

```text
RuntimeCore.OnTick
→ ACRLifecycle.Update
→ AIRunner.Update
→ OnBattleUpdate
→ 执行轴 / 事实轴 / 辅助轴
→ Opener
→ SpellQueue
→ AILoop_Normal.GetNextSlot
→ SlotResolvers
→ SlotExecutor.Execute
```

因此：

- 基础 Resolver 属于 `AILoop` 正常循环，是最后一层常规决策。
- 副本时间线、强制技能、强制爆发、特定停手不要隐藏在基础 Resolver 里。
- 需要时间线或事实轴配合的行为，应放到 HiAuRo 官方支持的执行轴、事实轴、触发器、QT、热键或事件回调中。
- `OnBattleUpdate` 可以维护轻量状态，但不能替代 SlotResolver 的窗口控制。
- Opener 和 SpellQueue 的优先级高于正常循环，职业逻辑必须能接受这一点。

## 工程结构

```text
KairoHiAuRoACR/
├─ KairoHiAuRoACR.slnx
├─ KairoHiAuRoACR.csproj
├─ GlobalUsings.cs
├─ Helper/                         # HiAuRo.Helper git submodule
├─ Jobs/
│  └─ Machinist/
│     ├─ MachinistRotationEntry.cs
│     ├─ MachinistRotationUi.cs
│     ├─ MachinistSettings.cs
│     └─ Resolvers/
│        ├─ GCD/
│        └─ OffGCD/
└─ docs/
```

约定：

- `Jobs/<JobName>/` 只放该职业专属逻辑。
- 跨职业复用代码以后放 `Shared/`，不要让一个职业直接引用另一个职业目录。
- 职业入口类命名为 `<JobName>RotationEntry`。
- Resolver 命名为 `<JobName><Purpose>Resolver`，按 `GCD` / `OffGCD` / 特殊用途分目录。
- 设置类命名为 `<JobName>Settings`，继承 `AcrSettings`。
- UI 类命名为 `<JobName>RotationUi`，实现 `IRotationUI`。

## Helper 引用规则

Helper 必须按其 README 的规定方式引用：

```powershell
git submodule add https://github.com/denghaoxuan991876906/HiAuRo.Helper.git Helper
dotnet sln KairoHiAuRoACR.slnx add Helper/HiAuRo.Helper/HiAuRo.Helper.csproj
```

项目引用写法：

```xml
<ProjectReference Include="Helper\HiAuRo.Helper\HiAuRo.Helper.csproj">
  <Private>False</Private>
</ProjectReference>
```

含义：

- 编译时可以直接使用 `MCHHelper`、`BRDHelper` 等静态 API。
- 输出目录不复制 `HiAuRo.Helper.dll`。
- 运行时由 HiAuRo 宿主初始化 Helper 上下文。

不要把 Helper 源码手动复制进 ACR 工程，也不要把 `HiAuRo.Helper.dll` 当成 ACR 附带 DLL 发布。

## RotationEntry 规则

每个职业一个入口类：

```csharp
public sealed class MachinistRotationEntry : IRotationEntry, ISettingsProvider<MachinistSettings>
{
    public string AuthorName { get; } = "Kairo";
    public bool UseCustomUi { get; } = false;
    public IEnumerable<HiAuRo.ACR.Jobs> TargetJobs { get; } = [HiAuRo.ACR.Jobs.MCH];
    public MachinistSettings Settings { get; set; } = new();

    public Rotation? Build(string settingFolder)
    {
        return new Rotation
        {
            TargetJob = HiAuRo.ACR.Jobs.MCH,
            AcrType = AcrType.PvE,
            MinLevel = 1,
            MaxLevel = 100,
            SlotResolvers = [...]
        };
    }
}
```

注意：

- `AuthorName` 必须是 `Kairo`。
- `UseCustomUi` 默认 false，优先使用 HiAuRo 的 `IUiBuilder`。
- `TargetJobs` 和 `Rotation.TargetJob` 必须一致。
- `Build()` 只组装 Rotation，不做大量运行时计算。
- 一个职业不要注册多个入口。

## Resolver 规则

Resolver 只做两件事：

- `Check()`：轻量判断是否可用，返回 `<0` 表示不执行。
- `Build(Slot slot)`：把最终技能塞进 Slot。

约定：

- GCD 技能用 `SlotMode.Gcd`。
- 能力技用 `SlotMode.OffGcd`，并在 Spell 上设置 `Type = SpellType.Ability`。
- `SlotMode.Always` 只给真正需要每帧检查的特殊逻辑。
- 不在 `Check()` 里做重 I/O、复杂扫描或大量分配。
- 需要目标的技能先判断 `Data.Target.Current != null`。
- 暂停开关统一尊重 `BuiltinQt.Hold`。

## UI / QT / Settings

基础 UI：

```csharp
builder.AddMainControl();
builder.AddBuiltinQt(BuiltinQt.Burst, true);
builder.AddBuiltinQt(BuiltinQt.Hold, false);
builder.AddTab("mch", "MCH");
builder.AddQtToggle("MCH_MinimalLoop", true, "基础循环");
```

约定：

- QT id 加职业前缀，例如 `MCH_MinimalLoop`，避免多职业冲突。
- 持续开关用 QT。
- 一次性动作以后再接 Hotkey。
- 需要持久化的职业配置放进 `<JobName>Settings`。

## 构建和部署

构建：

```powershell
E:\ff14\HiAuRo\KairoHiAuRoACR\scripts\build.ps1
```

部署：

```powershell
E:\ff14\HiAuRo\KairoHiAuRoACR\scripts\deploy.ps1
```

验证：

- 构建必须 `0 errors`。
- `ACR/Kairo/` 下只保留要扫描的 `.dll`，旧测试 DLL 改成 `.bak`。
- 游戏内 `/hi reload` 后确认当前职业能识别到 Kairo ACR。
