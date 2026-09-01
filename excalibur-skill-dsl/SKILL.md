---
name: excalibur-skill-dsl
description: Create or update Excalibur Skill DSL from a Chinese design request, with an evidence-based plan, explicit generation approval, and focused static validation. Use for Skill DSL only, not Scene or Impact DSL.
---

# Excalibur Skill DSL

Turn a design request into a complete, maintainable Excalibur Skill DSL file.
This workflow is for designers who may not know DSL implementation details.
Support direct damage, area damage, movement, projectiles, summons, and their
combinations. Do not use this skill for Scene DSL, Impact DSL, runtime code,
or automatic in-game acceptance.

## Locate The Workspace Evidence

Treat the open workspace as the client root. Before planning, confirm that it
contains these project-relative locations:

- `Resource/Source/Config/Skills`: production Skill DSL files.
- `.vscode/trigger-catalog.json`: authoritative generated Trigger
  metadata.
- `Excalibur/Assets/Scripts/Excalibur/BattleLogic/Skill`: runtime Skill code
  and XML documentation.
- `Tool/DslExtension/package.json`: extension validation commands.

Read only the evidence needed for the request. Resolve conflicts in this
order:

1. The design plan confirmed in the current conversation.
2. Trigger Catalog metadata.
3. Runtime C# implementation and XML documentation.
4. Current DSL Language Server diagnostics.
5. Production Skill DSL examples.
6. General knowledge.

Production DSL files are examples of style and structure only. They do not
override the Catalog or runtime code, and a legacy example does not prove that
invalid syntax is legal.

## Required Input

Require all of the following before planning:

- `skillId`
- A target `.dsl` path relative to the client root, beneath
  `Resource/Source/Config/Skills`
- A natural-language skill description

The request may also provide confirmed IDs, resources, animation names, time
points, variables, constraints, and reference files. Do not ask the designer
to explain technical DSL facts that can be established from the Catalog or
code. If `skillId` or a valid target path is missing, ask for it and stop
without producing a plan or changing files.

## Phase 1: Plan Only

Before changing any file, extract the casting target, target selection,
Sections, timeline, damage, movement, control, projectile or summon lifecycle,
variables, resources, and configuration dependencies.

For a gameplay decision that cannot be established from evidence, do not guess
and do not hide it in a TODO. Form a provisional plan from known information,
then collect the smallest necessary set of unresolved gameplay questions under
`待确认项`.

When choosing implementation details:

1. Use only Trigger Catalog entries whose `domain` is `Skill`. Match the outer
   call's `parent` (`root` for top-level calls).
2. Search by keyword, description, original XML wording, parameter details,
   body shape, deprecation, and replacement. Never substitute a same-named
   Scene Trigger.
3. Read the linked runtime implementation when defaults, side effects,
   lifecycle, variable transfer, or boundary behavior matters.
4. Search production Skill DSL using the candidate Trigger combinations and
   target directory. Read at most eight candidate files in detail.
5. Select two or three reliable examples based on Trigger composition, nesting
   and FunctionData body, Section/timeline structure, then character or
   directory proximity. Exclude examples with relevant diagnostics, deprecated
   or unknown Triggers, Catalog mismatches, or unexplained variables.
6. Borrow only transferable structure, Trigger composition, nesting, and
   naming style. Never copy Skill IDs, configuration IDs, resource paths, or
   variable names from an example.

If fewer than two reliable examples exist, say that the plan primarily relies
on the Trigger Catalog and runtime code; do not search indefinitely merely to
fill a quota.

Output exactly this Chinese plan structure. Do not omit headings; write `无`
where appropriate. Explain the purpose and key parameter source for every main
Trigger. For each similar case, include the relative path, why it was selected,
and what structure is being borrowed.

```text
## Skill 计划

### 1. 技能目标
### 2. 目标选择
### 3. Section 划分
### 4. 时间线
### 5. 主要 Trigger 与嵌套
### 6. 变量与作用域
### 7. 伤害、移动与控制逻辑
### 8. 所需资源与配置
### 9. 相似案例
### 10. 假设与风险
### 11. 待确认项

确认后请回复：确认生成
```

After outputting the plan, stop. Do not create, overwrite, format, or repair
files. If gameplay semantics remain unresolved, wait for answers. A reply may
authorize Phase 2 only when it includes the exact phrase `确认生成`. A change to
the plan invalidates earlier approval and requires a new `确认生成` reply.

## Phase 2: Generate After Approval

After valid approval, reread the latest confirmed plan, target file, and
relevant evidence. If material gameplay details such as target rule, timing,
count, position, movement/control, or ending condition are still missing, stop
and ask; approval does not authorize guessing.

For every used Trigger verify its keyword, parameter count and types, optional
or variadic behavior, allowed values, valid parent, body shape, subcalls, and
deprecation/replacement. Verify every variable's declaration, source, scope,
and cross-Skill transfer, plus every referenced Section number.

Create or update only the named target file and only for confirmed behavior.
Preserve local formatting and naming conventions. Do not reformat or rewrite
unrelated Skills.

Handle missing information as follows:

- Missing gameplay semantics: stop and ask the designer.
- Missing required configuration ID: never invent a plausible ID. Omit the
  dependent executable call and write a neighboring
  `// TODO(BLOCKED): ...` that states the missing value and behavior to add.
- Missing optional animation, effect, sound, or presentation resource: omit the
  optional behavior or write a neighboring `// TODO(RESOURCE): ...`.
- Use `0`, an empty string, or a default only when the confirmed plan, Catalog,
  or runtime code proves its intended semantics.

Every TODO must be specific, close to the omitted behavior, and included in the
final report.

## Phase 3: Validate And Report

Run the most relevant existing DSL checks. Prefer commands defined by
`Tool/DslExtension/package.json`; execute bulk diagnostics from
`Tool/DslExtension`, because their workspace-relative paths depend on that
directory. When only a workspace scan is available, inspect
`diagnostics/current.json` specifically for the target file and distinguish
pre-existing diagnostics from this change.

Validation must cover DSL syntax and semicolons; Skill-domain Trigger existence;
parameters, optionality, and allowed values; parent/body/nesting rules;
variables and cross-Skill transfer; Skill and Section references; and all TODOs
or warnings introduced in the target file.

Repair only errors introduced by this generation. Recheck after each repair,
for at most three rounds. Never use `dsl.diagnostics.suppress`, diagnostics
baselines, Catalog edits, XML documentation edits, or runtime-code edits to
make the target file appear clean.

If errors remain after three rounds, stop and report the blockage honestly.
Warnings may remain, but report their code, position, meaning, and recommended
action. Finish using this exact format:

```text
## 生成结果

- 文件：
- 检查：<运行的检查、目标文件 error 数、warning 数>
- 参考案例：
- TODO：
- 假设：
- 剩余 warning：
- 需要策划游戏内验证：
```

The in-game validation item must remind the designer to check target selection,
hit count, damage area, action and activation timing, movement/projectile/summon
lifecycle, interruptions, target loss, presentation resources, and balance. Do
not claim runtime or in-game acceptance has been completed.
