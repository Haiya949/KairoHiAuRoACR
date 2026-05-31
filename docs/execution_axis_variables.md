# 机工执行轴变量

本文档记录 Kairo 机工 ACR 暴露给 HiAuRo 执行轴使用的触发动作和变量。这里的示例只属于执行轴，不是事实轴或辅助轴。执行轴必须使用 HiAuRo 原生节点，例如 `HiAuRo.Execution.TreeActionNode, HiAuRo`，动作 `$type` 使用 ACR 注册的 `TriggerTypeName` 短名。

## 轴类型边界

HiAuRo 运行时有三类轴，文件不要混放：

- 执行轴：放在 `ExecutionTimelines/{TerritoryTypeId}.json`，用于执行动作、请求热键、强制技能、切换 Kairo 机工变量。
- 事实轴：放在 `FactTimelines/{TerritoryTypeId}.json`，用于描述事实事件或机制锚点；本仓库当前不提供事实轴示例。
- 辅助轴：放在 `AssistTimelines/{TerritoryTypeId}.json`，用于辅助提示；本仓库当前不提供辅助轴示例。

本仓库的 `docs/execution_timelines/` 只存放执行轴示例。复制到游戏配置目录时需要改名为副本 TerritoryTypeId：

| 副本 | 作者示例 | 运行时目标 |
|---|---|---|
| M9S | `docs/execution_timelines/M9S-MCH-execution.json` | `ExecutionTimelines/1321.json` |
| M10S | `docs/execution_timelines/M10S-MCH-execution.json` | `ExecutionTimelines/1323.json` |
| M11S | `docs/execution_timelines/M11S-MCH-execution.json` | `ExecutionTimelines/1325.json` |

这些执行轴使用 `KairoMCH*` 触发动作；运行时必须先加载 Kairo ACR，让 Rotation 注册触发动作类型。如果在插件已经运行时复制执行轴，复制后需要重载 ACR/执行轴，避免自定义动作在注册前被当成未知类型。

## 触发动作

### `KairoMCHTimelineVariable`

设置机工 ACR 自有的时间轴变量。动作属性：

- `Action`: `MachinistTimelineVariableAction` 枚举名。
- `Value`: 对单个变量动作生效，`true` 为打开，`false` 为关闭。
- `Remark`: 备注，仅用于执行轴说明。

触发器作者界面显示中文名称，方便游戏内编辑；JSON 中的 `Key` / `Action` 仍使用英文 enum 枚举名，保证已有执行轴和模板的序列化值稳定。

常用预设：

- `StartDelayedBurstHold`: 打开禁止爆发、总留资源和各细分留资源，并关闭释放标记。用于机制前延后两分钟爆发。
- `ReleaseDelayedBurstPackage`: 关闭留资源，打开强制爆发、释放延迟爆发和各细分释放标记，并调用 `ReanchorBurstCycleToCurrentTime()` 重锚后续 120s 周期。
- `ResetDelayedBurstPackage`: 关闭延迟爆发相关的强制、禁止、总留资源、释放标记和各细分 hold/dump。
- `ResetAllTimelineVariables`: 关闭所有公开变量，适合转阶段或轴结束兜底。

### `KairoMCHHotkey`

请求一次机工快捷动作。动作属性：

- `Key`: `MachinistHotkeyAction` 枚举名。
- `Remark`: 备注。

支持值：`Potion`、`Sprint`、`Tactician`、`Dismantle`、`SecondWind`、`ArmsLength`、`HeadGraze`、`LegGraze`、`FootGraze`。

`Potion` 通过 `MachinistHotkeyIds.Potion` 调用 UI 中注册的 `hk_爆发药`。其他热键用 `HiAuRo.Helper.MCHHelper` 技能 ID 创建 `SpellType.Ability` 的 `Slot` 并交给 HiAuRo 队列。

### `KairoMCHPotion`

专用爆发药请求动作，等价于 `KairoMCHHotkey` 的 `Key = Potion`。时间轴需要表达“这里请求一次爆发药”时优先使用这个短动作。

## 公开变量

这些变量全部为 `0/1` 语义，`1` 表示打开：

| 变量 | 含义 |
|---|---|
| `mch_force_burst` | 把当前窗口视为爆发窗口 |
| `mch_forbid_burst` | 禁止计划爆发资源 |
| `mch_hold_all_burst` | 总留资源，覆盖野火、枪管、热量、电量、强 GCD 和整备目标 |
| `mch_release_delayed_burst` | 释放延迟爆发包 |
| `mch_dump_resources` | 立即泄热量、电量和可泄资源 |
| `mch_hold_wildfire` | 保留野火 |
| `mch_dump_wildfire` | 释放野火 |
| `mch_hold_barrel` | 保留枪管稳定器 |
| `mch_dump_barrel` | 释放枪管稳定器 |
| `mch_hold_checkmate_doublecheck` | 保留 Checkmate / Double Check |
| `mch_dump_checkmate_doublecheck` | 释放 Checkmate / Double Check |
| `mch_hold_battery` | 保留电量和机器人 |
| `mch_dump_battery` | 释放电量和机器人 |
| `mch_hold_heat` | 保留热量 |
| `mch_dump_heat` | 释放热量 |
| `mch_hold_strong_gcd` | 保留强 GCD |
| `mch_dump_strong_gcd` | 释放强 GCD |
| `mch_hold_reassemble_drill` | 保留整备给 Drill/强 GCD 目标 |
| `mch_dump_reassemble_drill` | 释放整备目标 |
| `mch_opener_air_anchor_first` | 特殊起手变量，打开后 G1 使用 Air Anchor，G2 使用 Drill |

## 写轴规则

- 节点 `$type` 使用 `HiAuRo.Execution.TreeRoot, HiAuRo`、`HiAuRo.Execution.TreeSequence, HiAuRo`、`HiAuRo.Execution.TreeParallel, HiAuRo`、`HiAuRo.Execution.TreeDelayNode, HiAuRo`、`HiAuRo.Execution.TreeActionNode, HiAuRo`。
- 动作 `$type` 使用 `KairoMCHTimelineVariable`、`KairoMCHHotkey`、`KairoMCHPotion`。
- 延后爆发按 `StartDelayedBurstHold` -> `ReleaseDelayedBurstPackage` -> `ResetDelayedBurstPackage` 的顺序写。
- `mch_opener_air_anchor_first` 必须在起手开始前打开，并且要在 before OpenerMgr starts 的时间点生效；它只改变起手前两个 GCD 的顺序，不改变后续 Chain Saw、Excavator、第二个 Drill、Full Metal Field；起手开始后 running opener snapshot 不再被变量变化改写。
- 副本机制轴优先用 Boss 技能/事实轴锚点替换长 `Delay`；模板里的 Delay 只用于说明写法。
- 只使用 HiAuRo 原生节点类型和 KairoMCH 触发动作。

模板文件：`docs/templates/MCH-execution-axis-template.json`。

具体副本轴建议从模板复制后另存，并按 Boss 技能锚点、事实轴事件和团队策略补充。当前可参考：

- `docs/execution_timelines/M9S-MCH-execution.json`
- `docs/execution_timelines/M10S-MCH-execution.json`
- `docs/execution_timelines/M11S-MCH-execution.json`
