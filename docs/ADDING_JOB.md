# 新增职业流程

本文说明在 Kairo HiAuRo ACR 中新增一个职业的最小步骤。

新增职业前必须先读：

```text
E:\ff14\HiAuRo\HiAuRo-master\doc\ACR_AUTHOR_GUIDE.md
docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md
```

职业代码必须服从官方运行时顺序、SlotMode 窗口控制、`IRotationEntry` / `Rotation` / `ISlotResolver` 接口约定。

## 1. 建目录

以诗人为例：

```text
Jobs/Bard/
├─ BardRotationEntry.cs
├─ BardRotationUi.cs
├─ BardSettings.cs
└─ Resolvers/
   ├─ GCD/
   └─ OffGCD/
```

职业目录名使用英文职业全名，类名前缀也使用英文职业全名。

## 2. 写入口

入口类必须实现 `IRotationEntry`，如果需要设置持久化，同时实现 `ISettingsProvider<TSettings>`。

最小字段：

- `AuthorName = "Kairo"`
- `UseCustomUi = false`
- `TargetJobs = [Jobs.<JOB>]`
- `Build()` 返回 `Rotation`
- `GetRotationUI()` 返回本职业 UI

`Build()` 中按优先级排列 `SlotResolvers`，越靠前越早检查。

## 3. 写 UI

每个职业至少注册：

- `AddMainControl()`
- `BuiltinQt.Burst`
- `BuiltinQt.Hold`
- 一个职业 Tab

职业自定义 QT id 必须带职业前缀：

```text
BRD_UseSong
MCH_MinimalLoop
WAR_Defense
```

不要使用只有中文含义、没有职业前缀的 id，后续多职业会冲突。

## 4. 写 Resolver

GCD 示例：

```csharp
public sealed class BardBaseGcdResolver : ISlotResolver
{
    private uint _nextSpell;

    public int Check()
    {
        if (Data.Target.Current == null)
            return -1;

        if (QTHelper.IsEnabled(BuiltinQt.Hold))
            return -1;

        _nextSpell = SelectSpell();
        return new Spell(_nextSpell, SpellTargetType.Target).IsReadyWithCanCast() ? 0 : -1;
    }

    public void Build(Slot slot)
    {
        slot.Add(new Spell(_nextSpell, SpellTargetType.Target));
    }
}
```

OffGCD 示例：

```csharp
slot.Add(new Spell(spellId, SpellTargetType.Target) { Type = SpellType.Ability });
```

## 5. 使用 Helper

直接使用对应职业 Helper：

```csharp
if (BRDHelper.HasStraightShotReady)
{
    ...
}
```

如果 Helper 缺少某个状态、量谱或技能 ID，优先补 `HiAuRo.Helper` submodule，并在本工程验证通过后再提交回 Helper 仓库。

## 6. 编译验证

```powershell
dotnet build E:\ff14\HiAuRo\KairoHiAuRoACR\KairoHiAuRoACR.slnx -c Debug
```

验证点：

- ACR 项目无编译错误。
- 新职业入口 `TargetJobs` 正确。
- `Rotation.TargetJob` 与入口职业一致。
- `SlotResolvers` 至少有一个 GCD。
- 进入游戏切对应职业后 `/hi reload` 能识别。

## 7. 职业完成标准

最小可跑：

- 能识别职业。
- 有基础单体 GCD。
- 尊重 `BuiltinQt.Hold`。
- 不因无目标报错。

可日常使用：

- 单体 / AOE 路线。
- 常用能力技。
- 基础资源不溢出。
- 爆发 QT 可控。

可高难使用：

- 开场。
- 爆发窗口。
- 资源池化。
- 时间线 / 触发器控制。
- 明确的停手、保留、倾泻策略。
