# 黑魔开发记录

## 范围

黑魔代码只放在 `Jobs/BlackMage/` 下。其他职业只能作为模板参考，本职业开发时不要修改其他职业目录。

`E:\ff14\ACR\Kairo\BlackMage` 只能作为循环策略参考。不要迁移 AEAssist API、时间轴运行时、旧 QT 结构，或旧的目标选择 / 倒计时桥接逻辑。

## HiAuRo 边界

- 优先遵循 `E:\ff14\HiAuRo\HiAuRo-master\doc\ACR_AUTHOR_GUIDE.md`。
- 使用 HiAuRo 原生 `IRotationEntry`、`Rotation`、`IOpener`、`ISlotResolver`、`IAcrUiBuilder`、`CountDownHandler`。
- 技能 ID、状态 ID 和职能量数据使用 `HiAuRo.Helper`。当前黑魔代码使用 `BLMHelper.EN.Skills`、`BLMHelper.EN.Buffs` 和 `BLMHelper` 的量谱快捷接口。
- Helper 已有数据时，不保留本地 `BlackMageActionId` 或 `BlackMageStatusId` 目录。

## 时间轴边界

原黑魔 ACR 里有爆发、资源保留、移动、停手恢复和群攻控制等时间轴变量名。这些名字可以作为以后设计接口的词汇保留，但本次 HiAuRo 移植不迁移旧时间轴运行时。

迁移规则：允许保留时间轴变量名作为未来接口词汇，但不要迁移时间轴运行时。

当前生产黑魔代码不得引用 `TimelineController`、旧 `BlackMageTimeline*` 类或 AEAssist 时间轴 API。后续如果要恢复时间轴能力，应通过 HiAuRo 支持的执行轴、事实轴、触发器、QT、热键或事件机制重建。

## 当前策略记录

- 100 级起手使用 HiAuRo 原生倒计时，在 `4_000` ms 注册预读 `Fire III`。战斗内固定起手完整写在 `IOpener.Sequence`：开场 `High Thunder`，延迟 `Swiftcast` 加 `Amplifier`，五个 `Fire IV`，`Xenoglossy` 加 `Manafont`，第六个 `Fire IV`，`Flare Star`，第七和第八个 `Fire IV`，补一次 `High Thunder`，再打四个 `Fire IV`，第二个 `Flare Star`，最后 `Despair`。
- 战斗内起手在 `StartCheck()` 构建 `IOpener.Sequence` 快照，`StopCheck()` 返回 `-1`，匹配 HiAuRo `OpenerMgr` 的固定序列执行方式。起手内必打 GCD 直接入队，避免空 slot 被 `OpenerMgr` 跳过后提前进入普通循环或提前打黑魔纹。固定起手 slot 使用更长等待窗口，避免 GCD / oGCD 短暂不可用时跳过 5+7 起手。
- FFLogs 木桩回归 `dpVXCPM1T723KfrH` fight 15 的错误形态是：开场 `Fire III`、`High Thunder`、`Swiftcast`、`Amplifier`，然后第一发 `Fire IV` 前先放 `Ley Lines`，火阶段又打第二个 `Fire III`。因此第一发起手 `Fire IV` 后、第一次 `Blizzard III` 前，会阻止火苗 `Fire III` 重新进火。
- FFLogs 木桩回归 `dpVXCPM1T723KfrH` fight 16 锁定 100 级 5+7 起手包：五个 `Fire IV` 后必须打 `Xenoglossy`、`Manafont`、第六个 `Fire IV`、`Flare Star`、第七和第八个 `Fire IV`、补 `High Thunder`、再四个 `Fire IV`、`Flare Star`、`Despair`，然后才能进冰。这一整包属于 `IOpener.Sequence`，普通火阶段守卫只作为起手掉出后的兜底。
- 基础单体循环保留高等级火冰框架：雷维护、火阶段输出、冰阶段回蓝、火悖论、6 层灵极魂 `Flare Star`、火尾 `Despair`、通晓爆发 / 倾泻，以及魔泉续火。
- 100 级单体循环按相位顺序安排：有火苗时用一档火加火苗进三档火，火阶段读 `Fire IV` 到 6 层灵极魂后打 `Flare Star`，冰阶段和火阶段都打 `Paradox`，火阶段悖论用于生成火苗；打完应打的 `Fire IV` 和 `Paradox` 后打 `Despair`，再用 `Blizzard III` 进入三档冰，三档冰下读 `Blizzard IV` 回满 MP 和冰针。
- 如果火阶段不是带火苗进入，例如 5+7 起手后，进火后优先打火悖论，再做雷维护。这样火悖论可以先生成下一轮火苗。
- 火阶段退出不能在 `Despair` 后卡住。理想情况下仍优先通过 `Transpose` 加 `Swiftcast` / `Triplecast` 瞬发 `Blizzard III`，避免三档火直接进冰的 30% 威力惩罚；但 GCD 已经可用时，普通循环会放行 `Blizzard III`，不能为了等待理想瞬发窗口无限空转。
- 通晓使用统一爆发包判断：防溢出、魔泉前桥接、强制移动、`DumpResources`、`DumpPolyglot` 和 120 秒爆发锚点共用一套消耗策略，再选择 `Foul` 或 `Xenoglossy`。
- 120 秒爆发窗口使用 `FirstBurstAnchorMs` 的循环内经过时间判断：`BurstWindowLeadMs` 只表示锚点前窗口，`BurstWindowTailMs` 只表示锚点后窗口。锚点前窗口归属即将到来的锚点，黑魔纹重复使用保护也使用同一组窗口边界。
- 木桩 MP 循环保留旧 Transpose 恢复思路：火阶段准备离开时，如果 `Swiftcast` / `Triplecast` 能让 `Blizzard III` 瞬发，GCD 循环会等待 Transpose。这个等待必须有 GCD 亮起后的回退，不能卡住普通循环。
- 火阶段退出只在 `Flare Star` 真的可用 / 可施放时等待满灵极魂。如果禁止爆发或 `Flare Star` 不可用，循环可以回冰，不能停在火尾。
- 无目标停手恢复使用 HiAuRo 原生事件：Runtime 已经无法解析目标并调用 `OnNoTarget()` 时，黑魔可以在冰阶段且仍缺 MP 或冰针时，对自身执行 `Umbral Soul`。这不迁移旧停手时间轴变量。
- 魔泉策略保留旧高等级资源逻辑：5+7 起手例外最优先；起手后魔泉默认等 120 秒爆发窗口，除非 `DumpResources` / `DumpManafont` 打开；倾泻魔泉前仍先检查 `Despair`；如果魔泉可用且能延长火阶段，`Swiftcast` / `Triplecast` 进冰工具会让位。
- 雷刷新在 `DumpResources` 或当前目标血量低于等于 3% 时跳过，避免低收益补 DoT。单体雷和群体雷刷新都遵循这条规则。
- 高难等级配置覆盖 70 / 80 / 90 / 100：80 级以下单体通晓回退到 `Foul`，80 级以上用 `Xenoglossy`，`Despair` 要求 72 级以上，`High Thunder` / `High Thunder II` 是 100 级选择，低于 100 时通过 Helper 的 action-change 回退。
- 等级判断在 `HelperRuntime.GetCurrentLevel()` 返回非正数时失败关闭，避免 70 / 80 / 90 高难本在运行时初始化空窗里误选 100 级分支。
- 群体雷 DoT 追踪同时覆盖 100 级 `High Thunder II` 和 100 级前的 `Thunder III` / `Thunder IV` 状态，避免 70 / 80 / 90 高难群攻因为没有 `High Thunder II` 而每轮重复补雷。
- 100 级高等级群攻使用旧 Transpose 中心的 `Freeze` / `Flare` / `Flare Star` 思路：`Freeze` 回冰针，`Transpose` 转火，`Flare` 消耗火阶段，MP 空且 `Flare Star` 未准备好时再 `Transpose` 回冰。70 / 80 / 90 群攻回退到 Helper action-change 的 `Fire II` / `Blizzard II`，并保留 `Freeze` / `Flare`。
- 群攻 GCD 可以用 HiAuRo `TargetHelper.GetMostCanTargetObjects` 为 `Freeze`、`Flare` 和旧群攻填充技能选择更好的中心目标。这不替代 Runtime 目标选择；普通当前目标仍由 `Rotation.TargetResolvers` 负责。
- QT 只作为战斗中开关：强制 / 禁止爆发、资源倾泻 / 保留、强制 / 禁止移动，以及允许群攻。
- 爆发药是中文热键 / 时间轴请求：`KairoBLMPotion` / `KairoBLMHotkey`。不要恢复旧的持久 `UsePotion` QT，也不要做自动药水 resolver。
- 目标选择交给 Runtime 的 `Rotation.TargetResolvers`；黑魔 UI 不暴露手动目标模式。
