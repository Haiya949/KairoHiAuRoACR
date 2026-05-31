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

如果发生冲突，按优先级高的执行。Kairo 职业策略不能覆盖 HiAuRo 官方开发原则。

当前目标：

- 只使用 HiAuRo 原生 ACR 接口。
- 一个 DLL 支持多个职业，每个职业一个 `IRotationEntry`。
- Helper 按 `HiAuRo.Helper` README 规定作为 git submodule 引入。

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
- `UseCustomUi` 默认 false，职业 UI 使用 HiAuRo 的 `IAcrUiBuilder`。
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
builder.AddTab("机工士");
builder.AddQtToggle("AOE", true, "启用群攻 GCD 选择");
builder.AddDropdown("战斗模式", MachinistSettings.CombatModeOptions, ref settings.CombatMode);
```

约定：

- 游戏内可见的 Tab、QT、Hotkey、tooltip 文案默认使用中文。
- QT 悬浮窗只放战斗中常切的短标签，例如 `泄资源`、`强制爆发`、`保留爆发`、`AOE`。
- 不常切的模式配置放 settings 面板，例如 `战斗模式`；目标选择交给 HiAuRo Runtime 的 `TargetResolvers` 调度，不在 ACR 主控里暴露手动切换。
- 一次性动作以后再接 Hotkey。
- 需要持久化的职业配置放进 `<JobName>Settings`；HiAuRo 当前设置写回依赖字段名，给 UI 绑定的设置项优先使用 public 字段。

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
- `ACR/Kairo/` 下只保留要扫描的 `.dll`，其他测试 DLL 改成 `.bak`。
- 游戏内 `/hi reload` 后确认当前职业能识别到 Kairo ACR。

## 机工起手实现

- `IOpener.InitCountDown` 保留为官方倒计时入口，只注册 4s prepull Reassemble。
- HiAuRo Runtime v0.1.83 在倒计时开始事件中 `CountDownHandler.Reset()`、`OpenerMgr.Reset()`，随后懒注册 `InitCountDown`；倒计时结束后由 Runtime 自动启动 `OpenerMgr`。
- 多 GCD 起手写进 `IOpener.Sequence`，由 Runtime `OpenerMgr` 启动并逐个 Slot 推进；机工使用 dynamic Sequence snapshot，`StartCheck` 按当前等级和时间轴变量生成本轮起手，执行中使用 same Sequence snapshot，不再重建，避免 Runtime 每步读取 `Sequence` 时发生步骤漂移。
- 每个起手 Slot 以 GCD 开头，后接该 GCD 后的固定 oGCD；Runtime v0.1.83 会按 ActionCategory/recast group 自动判断能力技，ACR 仍保留 `SpellType.Ability` 标记用于兼容事件记录。
- 标准起手保存弹药顺序：G5 `Drill` -> `Checkmate` -> `Wildfire`，G6 `Full Metal Field` -> `Double Check` -> `Hypercharge`。
- standard loop opener ammo rule: G1 `Drill` consumes prepull `Reassemble` and may spend one `Double Check` plus one `Checkmate`; G2 `Air Anchor` and G3 `Chain Saw` must not spend the saved second `Double Check` / `Checkmate` charges.
- G5 first weave spends saved `Checkmate`, then `Wildfire` takes the second weave；G6 first weave spends saved `Double Check`, then `Hypercharge` takes the second weave。
- Low-level opener rule: `IOpener.Sequence` 在初始化时 skip locked opener steps；低等级不能生成空 Slot，must not wait forever。第二个 `Drill` 是后段爆发步骤，second Drill only exists after Air Anchor, Chain Saw, and Excavator，避免 58-95 级在前置步骤被跳过后重复尝试 Drill。
- ACR 生产逻辑不直接读取倒计时 IPC，也不在职业侧重注册或排队倒计时技能；倒计时恢复交给 Runtime。
- 特殊轴可在起手前打开 `mch_opener_air_anchor_first`，必须在 before OpenerMgr starts 的时间点生效；由 `MachinistOpener` 在 `StartCheck` 的 `IOpener.Sequence` 快照内把前两个 GCD 调整为 Air Anchor -> Drill；普通起手仍是 Drill -> Air Anchor。

## 机工爆发迁移

- Wildfire package 核心顺序：Full Metal Field -> Hypercharge -> Wildfire。
- Hypercharge must override generic combo and tool guards before Wildfire；但仍然不能绕过正常 oGCD weave gate，避免硬插能力技。
- Wildfire waits for the Hypercharge weave：全金属爆发后的短窗口内，如果还没有成功记录超荷，野火先等待超荷。
- loop Wildfire package follows Full Metal Field -> Hypercharge -> Wildfire；野火只统计对目标实际造成伤害的武器技，因此循环爆发里 Full Metal 后先开 Hypercharge，再让 Wildfire 尽量进入 late oGCD window，给后续 6 弹留出判定容错。
- Hypercharged is not Overheated：`StatusId.Hypercharged` 是 Barrel Stabilizer 给的超荷可用状态，不能当作过热循环状态；过热 GCD 只认 `StatusId.Overheated`。
- 120s loop first-GCD ordinary combo rule removed；循环爆发不再为了“1G 普通连击”延迟 Drill，进入循环爆发窗口后直接按 Drill -> Queen/Rook -> Double Check / Checkmate -> Air Anchor -> Double Check / Checkmate -> Barrel Stabilizer -> Chain Saw -> Reassemble -> Excavator -> Double Check -> Checkmate -> Full Metal Field -> Hypercharge -> Wildfire 铺资源，避免 120s 后继续连打普通 GCD。
- Fight 10 回归结论：不要把两分钟窗口写成 loop-package state machine。old ACR strong GCD priority 是 Excavator -> Full Metal Field -> Chain Saw -> Air Anchor -> Drill，循环爆发由普通强 GCD 优先级、起手 Wildfire 锚点和 Full Metal Field -> Hypercharge -> Wildfire 短窗口共同驱动；不要再用“本轮 Chain Saw/Excavator 已入队”这种状态阻塞 Full Metal Field，否则会让 Barrel / Full Metal / Wildfire 互相卡住。
- Checkmate / Double Check keep the natural release rule：常规只按 `Charges >= 2` 释放；时间线 dump 仍可显式释放，Full Metal / Hypercharge / Wildfire 双插保留优先。
- Battery budget/overcap policy：Queen/Rook 回到旧 ACR 的预算/防溢出/爆发资源门控，不再用 Air Anchor package state；Fight 4 暴露过 1:40 Queen/Rook 提前释放导致 120s Air Anchor 后没电量的问题，所以预算计算必须避免 120s 前低价值提前召唤。
- Fight 4 回归记录：2:10 ordinary combo 连打普通连击、2:24 Wildfire 延后，根因是循环爆发窗口被额外状态机拖住；修正方向是删除 loop-package state machine，恢复旧 ACR 的强 GCD 优先级和固定 120s 锚点。
- Fight 11 回归记录：opener Wildfire must not shift fixed 120s anchor；fixed 120s burst order 是 Drill -> Queen/Rook -> Double Check / Checkmate -> Air Anchor -> Double Check / Checkmate -> Barrel Stabilizer -> Chain Saw -> Reassemble -> Excavator -> Double Check -> Checkmate -> Full Metal Field -> Hypercharge -> Wildfire，然后进入过热连。120s 前约 30s 保留 Queen/Rook 电量；固定 120s 包内只要 Drill 已入队且 Chain Saw 还没入队，就由 Queen/Rook resolver 独立释放，GCD resolver 在人偶未入队时短暂停手，避免 Chain Saw / Excavator 后才召唤并电量溢出。Barrel Stabilizer 不和 Queen/Rook 绑定，按自身资源窗口释放；Wildfire 在固定 120s 包里不能裸开，必须等 Full Metal Field 和 Hypercharge。
- fixed 120s Full Metal Field must not wait for Wildfire cooldown：Fight 11 的 02:08 掘地飞轮后，Wildfire CD 在全金属后的第二能力窗前可转好；固定 120s 包不允许为了 `WildfirePreGcdClipWindowMs` 停 GCD 等野火，否则会把全金属拖出 0.7s+。
- ACR combat clock：fixed 120s burst package 不直接使用 Runtime battleTimeMs；Runtime battleTimeMs 在 opener / SlotExecutor 执行期间可能延后更新，所以固定 120s 包、电量保留和动作历史窗口用 MCH 自己从第一次实战动作启动的 ACR combat clock。预拉 Reassemble 不启动该时钟。
- opener second Reassemble must not reset ACR combat clock：起手内第二个整备发生时 Runtime battleTimeMs 可能仍在 0-2s，不能因此当作新开怪清理 stale tracking；只有 ACR combat clock 还没启动的早期 Reassemble 才允许清上一把残留。
- Issued-action tracking: 普通机工 resolver 必须用 `MachinistSpellHelper.AddIssuedSpell(slot, spell)` 入队，确保 `slot.Add` 后立刻记录技能；只等 `OnSpellCastSuccess` 会让同一 weave 窗口内的 Wildfire package、机器人状态和工具 CD 预测慢一拍。
- Chain Saw -> Excavator follow-up: 链锯入队后，`StatusId.ExcavatorReady` 可能还没同步到本地；整备目标追踪用 4.5s pending 窗口把刚入队的 `ActionId.ChainSaw` 视为即将出现的 `ActionId.Excavator`，窗口后只信真实状态。
- Reassemble pending target: `MachinistReassembleResolver.Check()` 选定本次整备要服务的技能，`Build()` 在 `slot.Add` 后把该目标传给 issued marker；如果 `Reassembled` 状态先于目标技能冷却/状态回写，下一次强 GCD 选择优先消费这个 pending Reassemble target，保护 next GCD 不被重新按普通优先级抢走。
- Reassemble target policy excludes Full Metal Field：Full Metal Field 依赖 `StatusId.FullMetalMachinist`，但本身不能被整备强化；整备目标只在 Excavator、Chain Saw、Drill、Air Anchor 和显式 AOE 泄资源 Scattergun 间选择。
- 当野火即将转好且下一个强 GCD 是 Full Metal Field 时，GCD resolver 可短暂停手，最多对齐 1s of the next Full Metal Field，不把这种停手写成副本时间线逻辑。
- 120s resource budget 使用 `MachinistResourcePlanner` 的纯计算：120s = 48 GCD，循环预算按 30 * 5 = 150 Heat，one paid Hypercharge per 120s budget 后为 150 - 50 - 15 = 85 Heat。
- opener Wildfire must not shift fixed 120s anchor：起手野火只记录 Wildfire package 历史，不改变 120s 循环爆发锚点；只有时间线 `ReleaseDelayedBurstPackage` 这种显式延后爆发动作才允许 `ReanchorBurstCycleToCurrentTime()` 重锚后续 120s 周期。
- 电量预算按机工循环工具和连击总收益：Air Anchor / Chain Saw / Excavator 共 7 * 20 = 140 Battery，27/3=9 个 Clean Shot 给 90 Battery，合计 230 Battery，用于判断是否在下个两分钟爆发前提前释放 Queen，避免只靠 90 电量阈值。
- Battery hold priority: `mch_hold_all_burst` 是延后爆发用的总 hold，90+ 电量或预算防溢出可以绕过它；`mch_hold_battery` 是显式单项电量 hold，不被防溢出绕过；`mch_dump_battery`/release 仍然优先释放。
- ForbidBurst/`保留爆发` 是最高优先级爆发资源硬门控：阻止 Wildfire、Barrel Stabilizer、Hypercharge、Queen/Rook summon 和 Queen/Rook Overdrive；显式 timeline dump/release 不绕过它。
- Queen/Rook Overdrive dump policy: 已召出的机器人只在 `ShouldReleaseBatteryForTimeline` 或 `ShouldUseDumpResources` 明确释放资源时主动超档；普通循环不提前终结机器人；ForbidBurst/`保留爆发` 会阻止 Queen/Rook Overdrive，低等级继续用 `RookOverdrive`，80 级后用 `QueenOverdrive`。
- Hypercharge tool guard: Chain Saw and Air Anchor cooldown integrity 高于普通热量倾泻；在非野火爆发包、非显式热量释放时，Hypercharge must not start if Chain Saw or Air Anchor is inside the exact 8s cooldown guard, and current heat does not override this guard. Barrel Stabilizer 在 Dawntrail 提供 Hypercharged 和 Full Metal Machinist，不按 50 Heat 处理。
- Daily target HP policy 只在 `日随模式` 生效：非 Boss 目标低于 12% HP 时保留计划爆发，目标低于 3% HP 时自动视为泄资源；自动泄资源 requires a live target，无目标不能被当成 0% HP；该策略 disabled in high-end mode，高难资源控制仍由 Burst/Hold QT、显式触发器或时间线变量负责。
- AOE target policy: AOE GCDs use HiAuRo `TargetHelper.GetMostCanTargetObjects` to pick the best AOE center for Auto Crossbow, Bioblaster, Scattergun/Spread Shot; this does not replace Runtime target selection, and Runtime `TargetResolvers` still owns normal current-target selection.
- Low-level Hot Shot fallback: 76 级前没有 Air Anchor 时，强 GCD fallback 使用 Helper 的 `ActionId.HotShot`，保持 `MinLevel = 1` 的低等级可运行边界。
- xivanalysis Helper catalog parity: 机工实际会用到的 `PileBunker`、`ArmPunch`、`RollerDash`、`CrownedCollider` 以及 `Tactician`、`Hypercharged`、`ExcavatorReady`、`FullMetalMachinist` 必须保留在 `HiAuRo.Helper.MCHHelper`；职业代码需要这些 ID 时继续从 Helper 取。
- 所有技能和状态 ID 继续来自 `HiAuRo.Helper.MCHHelper`；不在职业代码里恢复本地 `MachinistActionId` / `MachinistStatusId`。

## 机工执行轴变量

- 机工执行轴变量通过 HiAuRo trigger action `KairoMCHTimelineVariable` 写入 Kairo 自有状态；动作类只实现 `ITriggerAction`、`IUiBuilder.Draw()` 和 ACR 自有状态写入。
- 变量名保持当前轴兼容：`mch_hold_wildfire`、`mch_dump_wildfire`、`mch_hold_barrel`、`mch_dump_barrel`、`mch_hold_battery`、`mch_dump_battery`、`mch_hold_heat`、`mch_dump_heat`、`mch_hold_strong_gcd`、`mch_dump_strong_gcd`、`mch_hold_reassemble_drill`、`mch_dump_reassemble_drill` 等。
- `StartDelayedBurstHold` 会打开禁止爆发、总留资源和各细分 hold，并关闭释放标记；用于机制前整体延后两分钟爆发。
- `ReleaseDelayedBurstPackage` 会重锚后续 120s 爆发周期，关闭 hold，打开强制爆发、释放延迟爆发和各细分 dump。
- `ResetDelayedBurstPackage` 会还原强制/禁止/总留/释放标记和所有细分 hold/dump，避免机制状态污染后续轴。

## 机工执行轴热键

- 机工热键通过 HiAuRo trigger action `KairoMCHHotkey` 暴露，通过 enum 选择一次性动作。
- 机工爆发药通过 HiAuRo trigger action `KairoMCHPotion` 暴露，只请求一次已经在 UI 注册的爆发药热键。
- trigger authoring UI uses Chinese labels：触发器作者界面额外显示中文动作名；`KairoMCHHotkey.Key` 和 `KairoMCHTimelineVariable.Action` 的 JSON 值继续使用英文 enum，避免破坏已有执行轴和模板。
- Potion remains explicit hotkey/timeline request：爆发药不放进 QT，也不构造技能 Slot；UI、`KairoMCHHotkey Key=Potion` 和 `KairoMCHPotion` 都通过 `HotkeyHelper.ExecuteById(MachinistHotkeyIds.Potion)` 请求一次已注册热键。
- 爆发药热键 ID 使用 `MachinistHotkeyIds.Potion`，值为 UI 稳定标签生成的 `hk_爆发药`；执行轴不要重新引入 `UsePotion QT`。
- 非药水热键使用 Helper 技能 ID 生成 `SpellType.Ability` 的 Slot，并通过 `SlotHelper.Enqueue` 交给 HiAuRo 队列执行。
- Dismantle remains explicit hotkey/timeline control：`武装解除` 不注册自动 OffGCD resolver、不放进 QT；需要使用时由 UI 热键或 `KairoMCHHotkey` 执行轴动作显式请求。

## 机工执行轴写作交付物

- 作者说明在 `Jobs/Machinist/docs/execution_axis_variables.md`，记录 `KairoMCHTimelineVariable`、`KairoMCHHotkey`、`KairoMCHPotion` 的字段、变量和写轴规则。
- HiAuRo 原生执行轴模板在 `Jobs/Machinist/docs/templates/MCH-execution-axis-template.json`，节点类型使用 `HiAuRo.Execution.Tree*`，动作 `$type` 使用 `KairoMCH*` discriminator。
- 模板只保留通用延迟爆发和单项泄资源示例；具体副本应复制模板后替换 Delay 为 Boss 锚点或事实轴事件。
- 本仓库当前只提供执行轴示例；事实轴应放 `FactTimelines/{TerritoryTypeId}.json`，辅助轴应放 `AssistTimelines/{TerritoryTypeId}.json`，不要和执行轴文件混名。
- 运行时使用时，把作者示例复制到 HiAuRo 配置目录的 `ExecutionTimelines/{TerritoryTypeId}.json`；M9S/M10S/M11S 分别是 `1321.json`、`1323.json`、`1325.json`。
- M9S 具体执行轴示例在 `Jobs/Machinist/docs/execution_timelines/M9S-MCH-execution.json`，覆盖两次爆发药、三轮小怪 DataId 19170 目标选择、资源 hold/dump、策动和武装解除 Boss 技能门。
- M10S 具体执行轴示例在 `Jobs/Machinist/docs/execution_timelines/M10S-MCH-execution.json`，覆盖 Air Anchor -> Drill -> Chain Saw 特殊起手、water/surf 延后爆发释放、策动和武装解除 Boss 技能门。
- M11S 具体执行轴示例在 `Jobs/Machinist/docs/execution_timelines/M11S-MCH-execution.json`，覆盖 0/5/10 爆发药、5 分整备/强 GCD 保留释放、王室陨石热量控制、策动和武装解除 Boss 技能门。
