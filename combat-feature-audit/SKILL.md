---
name: combat-feature-audit
description: Audit a game's combat feature set into a source-backed Markdown inventory, incrementally fill missing combat features in an existing inventory, or review coverage gaps without editing. Use for gameplay systems analysis, not lifecycle or networking architecture documentation.
---

# Combat Feature Audit

Create and maintain a **feature inventory**, not an architecture overview. The inventory should answer what players, enemies, weapons/equipment, projectiles, statuses, encounters, and world objects can do in combat; how each feature is activated; what it changes; and where the behavior is implemented.

Use [the feature taxonomy](references/feature_taxonomy.md) after the initial project-specific discovery pass. Treat it as a minimum coverage checklist, never as a complete list of possible mechanics. Unless the user explicitly limits the scope, check every taxonomy category plus project-specific and cross-category mechanics.

## Scope

- Resolve scope in this order: the current user's explicit request, the existing inventory's explicit scope, then the default full combat scope. If expanding an existing inventory would contradict its stated scope, report the boundary instead of silently expanding it.
- Default to local gameplay behavior. Exclude networking, replication, transport, anti-cheat, and UI presentation unless the user includes them. When networking is included, document only its effects on combat rules; do not turn the inventory into networking architecture documentation.
- Treat a feature as established only when code or consumed data demonstrates it. A field name, unused keyword, or one-off comment alone is not enough.
- Describe reusable mechanics once and list variants or content-specific exceptions beneath it. Do not turn every hero skill or every enemy into a separate framework feature unless it introduces a distinct mechanic.
- Treat weapons, loadout equipment, weapon parts, relics, runes, and item affixes as combat features only when they change combat availability, actions, attributes, targeting, damage, survivability, or other runtime combat rules. Exclude inventory, shop, crafting, collection, and visual skin flows that do not do so.
- Keep lifecycle details only when they explain a feature's activation, timing, cancellation, or outcome. Do not structure the document around `Awake`, `Update`, or call chains.

## Choose The Working Mode

### Create a new inventory

Use this when the user asks for a new Markdown artifact. Use the requested path; if none is given, create `COMBAT_FEATURES.md` at the project root. Make its title and section language match the repository and user context.

### Augment an existing inventory

Use this when the user supplies or points to a Markdown file. Read it completely before changing it, but treat its headings as an output baseline rather than a discovery boundary. Preserve correct content, section order, wording conventions, and manually maintained material. Add only missing features, missing dimensions of existing features, or corrections supported by code. Do not replace the document with a new generic outline.

### Review only

If the user asks for a gap analysis without asking to update an artifact, report missing or questionable entries with source evidence and leave files unchanged.

## Evidence-Gathering Workflow

1. Identify the engine, top-level gameplay namespaces, table/data models, and the requested documentation target. Learn the project's own combat vocabulary from its source organization and project documentation. Read existing Markdown for output conventions, but do not use its current headings to limit discovery.
2. Map generic combat abstractions and project-specific systems: entities, skills/actions, weapons/equipment, targeting, hit detection, damage, status effects, attributes, movement/control, world interaction, encounters, and mechanics named in the project that do not fit those families.
3. For weapon/equipment systems, map the equipped-item model and its runtime consumers before cataloguing content: weapon slots and switching, firing/reload/alternate actions, ammunition or heat, upgrades, parts/affixes/sets, equipment-granted skills, and stat/effect attachment. Group parameterized content under the shared mechanic.
4. Enumerate behavior variants from implementation directories and the data fields that select them. For data-driven code, verify both the producer field and its runtime consumer.
5. Search event definitions and their subscribers. An event is a feature extension point only when at least one gameplay component subscribes or invokes it.
6. Record each confirmed feature with its activation, conditions, outcome, modifiers/limits, and code evidence. Link related features rather than duplicating their rules.
7. Run a cross-system pass for mechanics formed by interactions between feature families. Follow the relevant events, hooks, tags, shared state, direct calls, or data selectors far enough to explain the combined activation and outcome. Record the combined mechanic separately when its gameplay rule is not explained by the component entries alone.
8. Compare the result against the taxonomy as a minimum checklist. Also make an explicit project-specific/unclassified pass; do not force an unfamiliar mechanic into the closest predefined category merely to complete the checklist.
9. Record unresolved evidence and audit boundaries. Distinguish `未发现实现` from `未检查/无法确认`, and name inaccessible assets, generated code, external data, or excluded scope that could affect the result. Do not fill gaps by guessing.
10. When a Markdown artifact was edited, re-read it and validate that headings, tables, code fences, source paths, and internal links are coherent. In review-only mode, validate the report instead and leave files unchanged.

Use fast repository searches (`rg`) and favor concrete type/method references over broad word searches. For a Unity/C# project, useful starting locations usually include runtime `Units`, `Skills`, `Weapons`/`Guns`, `Equipment`/`Gear`/`Relics`, `Buffs`/`Status`, data models, `Items`, `Map`/`Room`/`Wave`, collision code, and triggers. Adapt this routing to the repository rather than assuming these exact names.

## Feature Entry Standard

Each distinct feature should contain enough detail to answer the following, compactly and without boilerplate:

| Dimension | Required content |
| --- | --- |
| 功能 | The player- or designer-facing capability and the category it belongs to. |
| 触发与前置 | Input, AI decision, hit, timer, event, room state, resource, or other conditions. |
| 规则与结果 | The behavior, state changes, calculations, targets, and end conditions. |
| 交互与限制 | Relevant immunity, caps, cooldowns, cancellation, stacking, ordering, filtering, or ownership rules. |
| 实现证据 | Concrete source paths with type/method/field names. Include data IDs or keywords only when their consumers are identified. |

For a dense document, use a table for the top-level feature index and subsections for complex mechanisms such as damage, Buffs, control effects, or waves. Include formulas and ordered pipelines where ordering materially changes gameplay.

## Completeness Rules

- "All combat features" means all **distinct mechanics** found in scope, not an unfiltered list of every data row or class name.
- For an unqualified combat-feature audit, cover every applicable taxonomy family and project-specific/cross-system mechanics. Skip a family only when the user narrows the scope or the available evidence supports marking it out of scope.
- Group parameterized variations under one mechanic when they share activation and resolution. Name the variations where the difference changes gameplay, for example direct/charge/channel casting, linear/homing/bouncing trajectory, or hard/soft control.
- Audit weapon and equipment behavior as a first-class feature family. Cover loadout/slot and switch rules, firing/reload/alternate actions, resource and durability/heat limits when present, equipment-granted skills/effects, upgrades/refinement/quality tiers, parts/affixes/sets, and the exact runtime path by which each modifier affects combat. Do not list every item ID, skin, or loot row as a separate feature.
- Separate similarly named features when their state rules differ. `knockback`, `knockup`, `stun`, `freeze`, `interrupt`, and `root` must not be collapsed unless source code genuinely uses one shared rule.
- Include both positive and negative rules: immunity, mutual exclusion, target filters, nonlethal flags, stack caps, refresh policies, and cleanup conditions frequently define the actual mechanic.
- Do not claim timing, priority, or formula ordering from naming alone. Cite the code that applies it.

## Updating Existing Markdown

- Add content at the closest semantic section. Create a new heading for a missing or project-specific feature family, not for a single narrow exception. Do not hide a distinct mechanic by force-fitting it into an existing heading.
- Retain existing source citations and add precise evidence for new claims.
- Update an existing feature entry when new evidence changes its conditions or interactions; do not create contradictory duplicates.
- Add a short change note only if the target document already uses change notes or the user asks for one.
- Do not alter unrelated headings, prose, formatting, or the document's scope.

## Quality Bar

Before finalizing, confirm the document covers every in-scope category in `references/feature_taxonomy.md`, includes project-specific and cross-system mechanics found during discovery, contains no entry that is merely a code-lifecycle narration, and traces each high-impact claim to a runtime implementation. Always state the audited scope and evidence limitations; list remaining blind spots such as inaccessible assets, generated code, external data, or unconsumed data, and distinguish them from confirmed absence.
