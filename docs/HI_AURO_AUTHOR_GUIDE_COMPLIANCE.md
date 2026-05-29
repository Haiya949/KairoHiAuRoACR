# HiAuRo 官方作者指南遵循清单

本文是 Kairo ACR 的硬性检查表。所有职业开发必须遵循 HiAuRo 官方 `ACR_AUTHOR_GUIDE.md`，尤其是第 2 节“ACR 运行时全景图”。

官方文档：

```text
E:\ff14\HiAuRo\HiAuRo-master\doc\ACR_AUTHOR_GUIDE.md
https://github.com/denghaoxuan991876906/HiAuRo/blob/master/doc/ACR_AUTHOR_GUIDE.md
```

## 1. ACR 入口

每个职业入口必须满足：

- 实现 `IRotationEntry`。
- `AuthorName` 固定为 `Kairo`。
- `UseCustomUi` 默认 `false`。
- `TargetJobs` 只声明该入口实际支持的职业。
- `Build(string settingFolder)` 返回完整 `Rotation`。
- `GetRotationUI()` 返回该职业 `IRotationUI`，或明确返回 null。
- 需要持久化设置时，实现 `ISettingsProvider<T>`，且 `T` 继承 `AcrSettings`。

禁止：

- 使用旧插件入口接口。
- 入口类里保存战斗过程状态作为主要决策来源。
- 一个职业同时注册多个互相竞争的入口。

## 2. 运行时顺序

必须按官方运行时顺序设计：

```text
游戏每帧
→ RuntimeCore.OnTick
→ Data.IsReady
→ Coroutine / EventSystem / HotkeyPoller
→ ACRLifecycle.Update
→ 职业切换加载或卸载 ACR
→ AIRunner.Update
→ 刷新 Data.Objects / Data.Party
→ TargetResolvers
→ OnBattleUpdate
→ 执行轴 / 事实轴 / 辅助轴
→ Opener
→ SpellQueue
→ AILoop_Normal.GetNextSlot
→ 遍历 SlotResolvers
→ Check >= 0
→ SlotMode 窗口匹配
→ Build(slot)
→ SlotExecutor.Execute(slot)
→ BeforeSpell / UseAction / OnSpellCastSuccess / AfterSpell
```

设计含义：

- `SlotResolvers` 是正常循环，不是最高优先级。
- 执行轴、事实轴、辅助轴、Opener、SpellQueue 都可能先于正常循环出手。
- Resolver 不能假设自己每帧通过 `Check()` 后一定会立即 `Build()`。
- `Build()` 只在 `Check()` 通过且 SlotMode 窗口匹配时调用。
- 技能成功后的状态可能有服务器延迟，不要用“刚打出技能就立刻拥有状态”的假设写关键逻辑。

## 3. 决策优先级

必须遵守官方优先级：

```text
1. 高优先级强制技能
2. 事实轴决策
3. 辅助轴强制技能
4. Opener 起手序列
5. SpellQueue 待处理队列
6. AILoop 正常循环
```

因此：

- 木桩基础循环只写通用策略。
- 副本特化、停手、保留、强制爆发、转火和药水窗口不要硬编码进基础循环。
- 需要覆盖高优先级插入时，使用官方 `CanUseHighPrioritySlotCheck` 这类 Rotation 钩子。

当前差距：

- MCH 已接运行时读取 settings 的基础最近敌人 `TargetResolver`，但还没有副本级目标优先级。
- MCH 已接 HiAuRo 原生 `IOpener` 起手，并按当前 `CountDownHandler` 整数秒接口使用 4s prepull Reassemble。
- HiAuRo 正常 ACR 循环只在 `CombatContext.State.InCombat` 后执行；倒计时结束本身不会启动普通循环。
- 副本时间线、事实轴、辅助轴策略尚未接入 Kairo 职业逻辑。
- 面板已要求游戏内可见文案中文化，但新增职业仍需要逐项验证。

## 4. SlotMode

每个 Resolver 必须选对模式：

| 场景 | SlotMode |
|------|----------|
| GCD 技能 | `SlotMode.Gcd` |
| 能力技 / oGCD | `SlotMode.OffGcd` |
| 真正需要不受 GCD 窗口限制的逻辑 | `SlotMode.Always` |

能力技规则：

- `OffGcd` 只能在官方窗口中执行。
- 当前 GCD 内能力技数量由 `Data.Combat.AbilityCountInGcd` 追踪。
- 上限由 `Data.Combat.MaxAbilityTimesInGcd` 控制。
- 不要在 Resolver 里自行绕过 oGCD 窗口。

## 5. ISlotResolver

`Check()` 规则：

- 返回 `<0` 表示不可用。
- 返回 `>=0` 表示可用。
- 优先级由 `Rotation.SlotResolvers` 的顺序决定，不靠返回值排序。
- 必须轻量，不做 I/O，不做复杂全表扫描。
- 必须先处理无目标、Hold、等级、资源、CD 等基础条件。

`Build(Slot slot)` 规则：

- 只构建动作，不重复做复杂决策。
- GCD 使用 `slot.Add(new Spell(id, target))`。
- 能力技使用 `slot.Add(new Spell(id, target) { Type = SpellType.Ability })`。
- 需要第二插入窗口时使用官方 Slot API。

## 6. Data 使用

优先使用 HiAuRo 官方 `Data`：

- `Data.Me`
- `Data.Target`
- `Data.Party`
- `Data.Objects`
- `Data.Combat`
- `Data.BattleData`
- `Data.FactState`

不要在职业逻辑里重复实现框架已提供的对象分类、队伍扫描或战斗状态判断。

## 7. Helper 使用

按 `HiAuRo.Helper` README 引用：

```xml
<ProjectReference Include="Helper\HiAuRo.Helper\HiAuRo.Helper.csproj">
  <Private>False</Private>
</ProjectReference>
```

使用规则：

- ACR 编译时引用 Helper。
- 输出不复制 `HiAuRo.Helper.dll`。
- 运行时由 HiAuRo 宿主注入 Helper 上下文。
- Helper 缺字段时优先补 Helper submodule，再回到职业逻辑使用。

## 8. UI / QT / Hotkey

默认使用 `IAcrUiBuilder`：

- `builder.AddMainControl()`
- `builder.AddBuiltinQt(BuiltinQt.Burst, true)`
- `builder.AddBuiltinQt(BuiltinQt.Hold, false)`
- 职业 Tab

约定：

- Game-visible UI labels should be Chinese by default; 游戏内可见的 Tab、QT、Hotkey、tooltip 文案默认使用中文。
- 战斗中常切的持续策略用 QT，标签保持短而清楚，例如 `泄资源`、`强制爆发`、`保留爆发`、`AOE`。
- 低频配置放 settings 面板，例如 `战斗模式`、`目标选择`。
- 一次性命令用 Hotkey。

## 9. 验证要求

提交或部署前至少执行：

```powershell
dotnet build E:\ff14\HiAuRo\KairoHiAuRoACR\KairoHiAuRoACR.slnx -c Debug
```

并检查：

- `0 errors`。
- 输出 DLL 是 `Kairo.dll`。
- `ACR/Kairo/` 下没有旧测试 `.dll` 与当前 DLL 同时被扫描。
- 游戏内 `/hi reload` 后对应职业能识别。

职业逻辑变更还要检查：

- 无目标时不报错。
- `BuiltinQt.Hold` 生效。
- GCD / oGCD 模式正确。
- Helper 状态、量谱、技能 ID 有来源。
- 基础循环不包含副本时间线特化。
