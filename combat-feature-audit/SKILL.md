---
name: combat-feature-audit
description: Audit a game's combat feature set into a source-backed Markdown inventory, or incrementally fill missing combat features in an existing inventory. Use for gameplay systems analysis, not lifecycle or networking documentation.
---

# Combat Feature Audit

Create and maintain a **feature inventory**, not an architecture overview. The inventory should answer what players, enemies, weapons/equipment, projectiles, statuses, encounters, and world objects can do in combat; how each feature is activated; what it changes; and where the behavior is implemented.

Read [the feature taxonomy](references/feature_taxonomy.md) before starting. Use only the relevant categories, but check every category for gaps when the request says "all combat features" or equivalent.

## Scope

- Default to local gameplay behavior. Exclude networking, replication, transport, anti-cheat, and UI presentation unless the user includes them.
- Treat a feature as established only when code or consumed data demonstrates it. A field name, unused keyword, or one-off comment alone is not enough.
- Describe reusable mechanics once and list variants or content-specific exceptions beneath it. Do not turn every hero skill or every enemy into a separate framework feature unless it introduces a distinct mechanic.
- Treat weapons, loadout equipment, weapon parts, relics, runes, and item affixes as combat features only when they change combat availability, actions, attributes, targeting, damage, survivability, or other runtime combat rules. Exclude inventory, shop, crafting, collection, and visual skin flows that do not do so.
- Keep lifecycle details only when they explain a feature's activation, timing, cancellation, or outcome. Do not structure the document around `Awake`, `Update`, or call chains.

## Choose The Working Mode

### Create a new inventory

Use this when the user asks for a new Markdown artifact. Use the requested path; if none is given, create `COMBAT_FEATURES.md` at the project root. Make its title and section language match the repository and user context.

### Augment an existing inventory

Use this when the user supplies or points to a Markdown file. Read it completely before changing it. Preserve correct content, section order, wording conventions, and manually maintained material. Add only missing features, missing dimensions of existing features, or corrections supported by code. Do not replace the document with a new generic outline.

### Review only

If the user asks for a gap analysis without asking to update an artifact, report missing or questionable entries with source evidence and leave files unchanged.

## Evidence-Gathering Workflow

1. Identify the engine, top-level gameplay namespaces, table/data models, and the requested documentation target. Inspect existing Markdown before broad source searches.
2. Map generic combat abstractions first: entities, skills/actions, weapons/equipment, targeting, hit detection, damage, status effects, attributes, movement/control, world interaction, and encounters.
3. For weapon/equipment systems, map the equipped-item model and its runtime consumers before cataloguing content: weapon slots and switching, firing/reload/alternate actions, ammunition or heat, upgrades, parts/affixes/sets, equipment-granted skills, and stat/effect attachment. Group parameterized content under the shared mechanic.
4. Enumerate behavior variants from implementation directories and the data fields that select them. For data-driven code, verify both the producer field and its runtime consumer.
5. Search event definitions and their subscribers. An event is a feature extension point only when at least one gameplay component subscribes or invokes it.
6. Record each confirmed feature with its activation, conditions, outcome, modifiers/limits, and code evidence. Link related features rather than duplicating their rules.
7. Compare the result against the existing document or the taxonomy. Add an explicit `待确认`/`未发现实现` note only when it helps distinguish a likely gap from a confirmed capability; do not fill gaps by guessing.
8. Re-read the edited Markdown and validate that headings, tables, code fences, source paths, and internal links are coherent.

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
- Group parameterized variations under one mechanic when they share activation and resolution. Name the variations where the difference changes gameplay, for example direct/charge/channel casting, linear/homing/bouncing trajectory, or hard/soft control.
- Audit weapon and equipment behavior as a first-class feature family. Cover loadout/slot and switch rules, firing/reload/alternate actions, resource and durability/heat limits when present, equipment-granted skills/effects, upgrades/refinement/quality tiers, parts/affixes/sets, and the exact runtime path by which each modifier affects combat. Do not list every item ID, skin, or loot row as a separate feature.
- Separate similarly named features when their state rules differ. `knockback`, `knockup`, `stun`, `freeze`, `interrupt`, and `root` must not be collapsed unless source code genuinely uses one shared rule.
- Include both positive and negative rules: immunity, mutual exclusion, target filters, nonlethal flags, stack caps, refresh policies, and cleanup conditions frequently define the actual mechanic.
- Do not claim timing, priority, or formula ordering from naming alone. Cite the code that applies it.

## Updating Existing Markdown

- Add content at the closest semantic section. Create a new heading only for a missing feature family, not for a single narrow exception.
- Retain existing source citations and add precise evidence for new claims.
- Update an existing feature entry when new evidence changes its conditions or interactions; do not create contradictory duplicates.
- Add a short change note only if the target document already uses change notes or the user asks for one.
- Do not alter unrelated headings, prose, formatting, or the document's scope.

## Quality Bar

Before finalizing, confirm the document has coverage for the applicable categories in `references/feature_taxonomy.md`, that no entry is merely a code-lifecycle narration, and that each high-impact claim can be traced to a runtime implementation. State remaining blind spots plainly, such as inaccessible assets, generated code, or unconsumed data.
