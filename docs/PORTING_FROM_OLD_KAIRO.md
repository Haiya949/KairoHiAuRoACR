# 从旧 Kairo ACR 参考迁移

旧工程路径：

```text
E:\ff14\ACR\Kairo
```

它是另一个插件体系下写的 ACR，只能作为职业策略参考，不能作为 HiAuRo 工程规范。

迁移时最高约束是 HiAuRo 官方作者指南：

```text
E:\ff14\HiAuRo\HiAuRo-master\doc\ACR_AUTHOR_GUIDE.md
docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md
```

如果旧 Kairo 和官方文档冲突，以官方文档为准。

## 可以参考的内容

- 职业技能 ID、状态 ID、量谱使用点。
- 起手和爆发顺序。
- 资源池化、倾泻、保留策略。
- 单体 / AOE 分支。
- 高难时间线中哪些行为需要外部控制。
- 已有测试脚本里表达的职业规则。

## 不直接迁移的内容

- AEAssist 命名空间和 API。
- 旧 `RotationEntry` 构造方式。
- 旧 `JobViewWindow` / QT UI 写法。
- 旧 `SlotResolverData` 构造器写法。
- 旧 opener、trigger、timeline 类型。
- 旧插件特有的 spell helper、target helper、事件接口。

如果旧逻辑依赖 AEAssist API，先翻译成 HiAuRo 能提供的数据：

| 旧概念 | HiAuRo 侧落点 |
|--------|---------------|
| 职业入口 | `IRotationEntry` |
| 技能优先级 | `Rotation.SlotResolvers` 顺序 |
| GCD Resolver | `ISlotResolver` + `SlotMode.Gcd` |
| 能力技 Resolver | `ISlotResolver` + `SlotMode.OffGcd` |
| QT 开关 | `IRotationUI` + `IAcrUiBuilder` |
| 设置 | `AcrSettings` + `ISettingsProvider<T>` |
| 职业量谱 | `HiAuRo.Helper.<Job>Helper` |
| 连击变化 | `ComboHelper` / `GetActionChange()` |

## 迁移顺序

建议按这个顺序迁移每个职业：

1. 技能 / 状态 / 量谱 ID 对齐到 `HiAuRo.Helper`。
2. 最小 GCD 循环。
3. 基础能力技。
4. 爆发 QT。
5. AOE。
6. 资源防溢出。
7. 开场。
8. 时间线和高难控制。

不要一开始就搬完整高难逻辑。先保证木桩循环能稳定跑，再逐层加策略。

## 迁移检查

每次从旧 Kairo 抄策略前先问：

- 这个判断需要的数据在 HiAuRo / Helper 中是否存在？
- 如果不存在，是补 Helper，还是暂时降级成保守策略？
- 这个逻辑是通用循环，还是某个副本时间线特化？
- 它是否会让无时间线木桩循环变弱？
- 它是否依赖旧插件的即时状态假设？

只有通过这些检查后，才把策略写进 HiAuRo ACR。
