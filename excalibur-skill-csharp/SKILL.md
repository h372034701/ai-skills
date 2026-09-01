---
name: excalibur-skill-csharp
description: Implement Excalibur skills in native C# with evidence-based lifecycle, performance, GC, and SkillTrigger selection. Use for C# skill logic, not Skill DSL authoring.
---

# Excalibur C# Skill

将 Excalibur 技能实现为原生 C#，作为 Skill DSL 表达能力的补充。C# 是所选技能实现的唯一执行来源，配置中的 `logicfile` 使用 `csharp://<key>`；不要同时维护一份可执行 DSL 镜像。

CSharpSkill 的基本目标不是替换 DSL，而是避免在复杂逻辑中写出冗长、重复或难以维护的 DSL。对于复杂条件、聚合、排序、状态决策和领域算法，C# 通常更适合实现，且 AI 更擅长生成、重构和验证这类结构化代码。对于 DSL 已经能够简洁、清晰表达的技能，继续使用 DSL。

## 适用范围

使用本 Skill 处理：

- `CSharpSkillLogic`、`CSharpSkillRegistry`、`SkillInstance` 的技能实现
- 将既有技能从 DSL 迁移到 C#，但不把 DSL 当作 C# 的运行时依赖
- 评估某段逻辑是否需要原有 `SkillTrigger`

不要使用本 Skill 编写或修复 Scene DSL、Impact DSL，或声称完成了游戏内验收。

## 工作区证据目录

实现前确认并按需读取以下完整目录：

- `Excalibur/Assets/Scripts/Excalibur/BattleLogic`：完整 C# 战斗运行时代码，包含 Skill、Entity、Scene、Impact、子弹、召唤物、移动、资源和生命周期 API。
- `Resource/Source/Config/Skills`：完整生产 Skill DSL 脚本目录，用于理解原行为、技能配置和 DSL 表达边界。
- `Excalibur/Assets/Scripts/Excalibur/BattleLogic/Skill`：C# 技能框架、SkillTrigger、生命周期和 XML 文档。
- `.vscode/trigger-catalog.json`：生成的 SkillTrigger 权威元数据。

## 证据顺序

实现前只读取必要证据，并按以下优先级解决冲突：

1. 当前对话确认的技能行为、技能 ID、配置 ID 和资源
2. `CSharp技能框架规格.md` 与 `CSharpSkillLogic.cs`
3. `Excalibur/Assets/Scripts/Excalibur/BattleLogic` 中相关运行时类型、XML 注释和对象池实现
4. `Resource/Source/Config/Skills` 中目标 DSL 与可靠案例
5. `.vscode/trigger-catalog.json` 及原有 Trigger 实现

必须确认技能配置的 `logicfile`、技能 ID、触发时机和 owner/target 语义。缺少关键游戏语义时停止并提出单一问题，不猜测。

## CSharpFirst 不变量

- 逻辑类必须无状态；禁止在逻辑对象字段保存 `SkillInstance`、owner、target 或施法期间状态。
- 施法状态只能放在对应 `SkillInstance.CustomDatas`，并在 `OnReset` 清理；若逻辑是一次性的纯被动计算，优先不保存状态。
- 使用私有构造函数、静态工厂和显式 `Register()`；在 `SkillSystem.Init` 注册一次。
- 回调只使用确定性的 `long` 时间和现有生命周期：`OnStart`、`OnTick`、`OnComplete`、`OnInterrupt`、`OnReset`、`OnExecutePassive`。
- 不引入协程、异步、独立时间轴、手写累计时间阈值，也不绕过现有对象池和清理流程。
- `BuildSections` 只有在确实需要 Section、消息队列或 SkillTrigger 时间轴时才实现；纯被动/一次性逻辑可留空并放在 `OnExecutePassive`。
- 不在 C# 中解析 DSL、复制 DSL 调试器或创建第二套 Trigger 适配层。

## SkillTrigger 选型决策

是否使用原有 `SkillTrigger` 必须按以下权重从高到低评估：

### 1. C# 代码短小精悍（最高权重）

- 先比较 DSL 与 C# 的表达长度、重复度、分支清晰度和维护成本；DSL 已能简洁表达时不要迁移到 C#。
- 若直接调用现有领域 API 能用一个清晰的回调完成复杂逻辑，优先纯 C#。
- 不为一次遍历、计数、排序、属性修正或一次性条件判断创建多个 Section/Trigger。
- 不用 `ComputeAt` 包装本来可以直接在生命周期回调完成的一次性被动行为。
- 只有当不用 Trigger 会复制复杂引擎语义、产生大量分支或难以维护时，才保留 Trigger。

### 2. 性能与 GC

- 优先使用现有容器、对象池和 `ListComponent<T>`；避免 LINQ、闭包、枚举器、临时数组、装箱和每帧分配。
- 连续逻辑放在 `OnTick` 前必须证明确实需要逐逻辑帧执行；离散事件不要用累计时间模拟。
- 可直接查询战场集合时，不要为每个流派创建一次 `FindTargetsTrigger` 和中间 `FindTargetsInfo`。
- Trigger 自带生命周期、排序和清理成本；若纯 C# 能保持同样确定性且无需这些能力，优先移除 Trigger。
- 性能判断以实际运行时 API 和对象池实现为依据，不能仅凭 DSL 示例推断。

### 3. SkillTrigger 适配程度（最低权重）

必须优先复用原有 SkillTrigger 的引擎语义，尤其是以下逻辑不可改写成纯 C# 模拟：

- 子弹、投射物的生成、飞行、碰撞、命中、销毁和预加载
- 召唤物的生成、生命周期、归属、销毁和资源清理
- 移动、位移、跟随、曲线移动、朝向和移动控制权
- 特效、动画、音频、镜头、屏幕表现、材质表现和其他表现层时序
- 依赖 SkillSection 绝对时间、消息队列、排序顺序、打断或停止处理的离散时间轴
- 需要既有 Trigger 的表现资源预加载、命中判定、碰撞边界或引擎回收语义

以上逻辑必须复用原有 SkillTrigger，不得在 C# 中直接模拟其生命周期、时间轴、资源加载、播放或回收。C# 只负责计算和决策，并通过 Section/消息中的原有 Trigger 执行引擎动作。“必须使用”优先级高于代码短小和 GC 优化。可以在同一技能中混合：核心计算用纯 C#，子弹/召唤物/移动/表现层部分用原有 Trigger。

## 推荐实现流程

1. 读取技能配置、技能 ID、C# 框架规格和相关运行时 API。
2. 先判断 DSL 是否已经足够简洁；只有 DSL 冗长、重复或难以表达时才选择 C#。
3. 将行为拆成一次性被动计算、连续计算、离散时间轴、子弹/召唤物/移动/表现层七类。
4. 对每一类按三项权重评估，并记录选择理由；表现层和引擎对象生命周期一旦涉及 SkillTrigger，必须保留原有 Trigger。
5. 一次性被动计算优先 `OnExecutePassive`；连续算法才使用 `OnTick`；需要引擎时间轴的部分使用 `BuildSections`。
6. 复用原有 Trigger，不修改 Trigger 语义；仅在现有 Trigger 缺少合法 C# 构造入口时补充最小构造器。
7. 使用现有配置入口指向 `csharp://<key>`，不要把 DSL 作为回退路径。
8. 编译相关项目，并检查新增文件、注册键、配置键、GC 分配风险和重置路径。

## 输出与验证要求

实现完成后报告：

- C# 文件、注册键、技能配置入口
- 每个行为类别选择纯 C# 或 SkillTrigger 的理由，按“代码简洁、性能/GC、适配程度”顺序说明
- 子弹、召唤物、移动是否使用原有 Trigger
- 编译或现有静态检查结果
- 未完成的资源、配置或游戏内验证项

必须提醒进行游戏内验证：目标选择、人数/命中数、伤害区域、激活时机、移动/子弹/召唤物生命周期、打断、目标丢失、表现资源和数值平衡。不要声称静态检查等同于游戏内验收。
