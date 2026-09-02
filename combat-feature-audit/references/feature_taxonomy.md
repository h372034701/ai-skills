# Combat Feature Taxonomy

Use this as a minimum coverage checklist for feature inventories, not as an exhaustive universe of combat mechanics or a claim that every project implements every entry. Record only mechanics supported by the target project's code and consumed data. Preserve project-specific concepts that do not fit the predefined categories instead of silently omitting or force-fitting them.

## 1. Skills and Actions

- Input bindings, held/released input, aim source, targeting mode, input buffering, action cancellation, and action locks.
- Active, passive, instant, charged, channeled, aimed, toggle, recast, combo, reload, dash, summon, transform, and child/triggered actions.
- Availability: cooldown, charges, recharge, initial cooldown, global/skill lockout, seal, requirements, resource checks, range, line of sight, and valid target checks.
- Costs and refunds: health, mana/energy, ammunition, special gauges, consumables, and cooldown/charge changes.
- Cast timing: wind-up, animation hit frame, repeated attacks, recovery, cast completion, interruptibility, and cast-end cleanup.
- Telegraphed areas, targeting indicators, aim locking, launch point selection, and attack direction rules.

## 2. Weapons, Equipment, and Loadouts

- Weapon slots, equip/unequip, weapon switching, alternate weapons, loadout restrictions, ownership, and shared versus independent resources.
- Basic fire, alternate fire, reload, charge, burst, sustained fire, melee/firearm mode changes, weapon-granted skills, and weapon-specific action locks or recovery.
- Ammunition, magazines, reload timing, heat/overheat, durability, fuel, charges, recharge, jam/empty handling, refunds, and resource transfer between weapons.
- Weapon base attributes, attack profiles, projectile/effect wiring, damage types, firing patterns, range/spread/recoil, and target restrictions when consumed by combat runtime code.
- Equipment slots and replacement rules; armor/accessory/relic/rune/chip/weapon-part effects; unique or mutually exclusive equipment; set bonuses; and source attribution for granted stats, skills, statuses, or triggers.
- Progression that changes combat: quality/rarity, level, upgrade, refinement, evolution, sockets, random affixes, rerolls, and scaling rules. Exclude collection, shop, crafting, cosmetics, and inventory-only behavior unless they change the equipped combat state.

## 3. Targets, Projectiles, and Hit Resolution

- Target pools, faction filtering, tags/types, nearest/farthest/random/area/position targets, priority rules, and target retention.
- Projectile creation, projectile lifetime, launch patterns, spread, multishot, burst, bounce, pierce, fork, return, and child projectile behavior.
- Trajectory: direct, linear, ballistic, ground-targeted, homing, orbiting, beam, stationary area, wall bounce, chain, delayed, and attached motion.
- Collision and impact: unit, wall, floor, destructible, projectile-vs-projectile, area overlap, hit count caps, per-target hit gating, and hit interval.
- Hit-side effects: impact effect, explosion, secondary cast, resource gain, status application, hit-stop, screen shake, and camera/gamepad feedback when gameplay timing is affected.

## 4. Damage, Defense, and Recovery

- Base damage construction; additive and multiplicative modifiers; snapshots versus live attributes; source ownership; and child-action inheritance.
- Accuracy, miss, evasion, critical chance, critical multiplier, weak point, backstab/front attack, distance scaling, and target-type overrides.
- Armor, resistance, vulnerability, independent reduction layers, true damage, fixed/percent health damage, damage caps/floors, and nonlethal damage.
- Damage prevention and redirection: invulnerability, immunity, barrier/shield, block/parry, absorb, substitute/decoy, lock-health, and one-time prevention.
- Timing and ordering: pre-damage hooks, final-damage hooks, after-damage hooks, hit versus actual-health-loss semantics, death checks, and overkill.
- Recovery: healing, leech/lifesteal, regeneration, healing modifiers, revive, and recovery caps.

## 5. Buffs, Debuffs, and Attributes

- Add/remove/replace rules, source attribution, unique instances, mutually exclusive states, duplicate policies, parent-child statuses, and aura propagation.
- Duration: permanent states, independent stack timers, shared timer refresh, periodic stack decay, expiration, and removal cleanup.
- Stack behavior: stack gain/loss, max stacks, overflow behavior, stack cooldown, conditional stack creation, and state at full stacks.
- Event callbacks: cast, attack, projectile lifecycle, hit, damage, critical, dodge, kill, death, movement, dash, room, item, or other project-specific events.
- Attribute modification: flat and multiplicative changes, conditional matching by skill/target/tag, max-resource recalculation, speed, cooldown, range, damage, defense, and derived resource caps.
- Status conversion, dispel/cleanse, status immunity/resistance, and application chance/duration scaling.
- Damage over time, heal over time, delayed death, periodic proc, explosion on expiration, and triggered follow-up actions.

## 6. Control, Movement, and State Disruption

- Interrupt, poise/toughness, stagger, super armor, control immunity, and interrupt-level comparisons.
- Knockback, pull, knockup/airborne, launch, slam, bounce, displacement immunity, wall interaction, and landing events.
- Stun, freeze, root, slow, fear, charm, silence, sleep, stealth/invisibility, reveal, and movement/attack/cast restrictions.
- Player dash, enemy charge, teleport, forced movement, collision with navigation/world geometry, and movement recovery.

## 7. Units, Summons, and AI

- Unit spawning, lifetime, despawn/death conditions, health and resource initialization, tags/factions, and Boss phase changes.
- Summons, companions, turrets, traps, hazards, and ownership/credit rules.
- AI perception, aggro propagation, target selection, line-of-sight rules, movement modes, skill queues, priorities, weighted choices, state-specific actions, and phase/encounter scripting.

## 8. World Combat and Encounters

- Destructible objects, damageable obstacles, collision blockers, walls/floors, cover, and line-of-sight obstruction.
- Traps, environmental hazards, trigger zones, timed/pressure/contact triggers, interactable combat objects, and scripted room objects.
- Room entry/exit gates, wave start/end, enemy budgets, spawn groups/weights, spawn location constraints, combat-end locks, reward gates, and boss encounter states.
- Drops, currency/resources, reward generation, pickups generated by combat, and kill attribution where it affects rewards.

## 9. Project-Specific and Cross-System Mechanics

- Mechanics expressed in the project's own domain language that do not fit the preceding families, such as combat directors, rule mutators, time manipulation, stance or formation systems, or nonstandard victory and failure rules.
- Emergent or composed mechanics whose gameplay rule exists only through interaction between multiple families, such as equipment-driven damage hooks that create statuses, encounter phases that rewrite skill availability, or reactions produced by combinations of tags and effects.
- Unclassified but evidenced mechanics. Keep them visible under a project-appropriate name until their role is understood; do not discard them because the taxonomy has no matching label.

## Recommended Inventory Shape

```text
# <Project> 战斗功能点清单

## 范围与证据标准
## 功能总览
## 技能与操作
## 武器、装备与构筑
## 目标、抛射物与命中
## 伤害、防御与恢复
## Buff、Debuff 与属性
## 控制、位移与打断
## 单位、召唤物与 AI
## 关卡、障碍物、触发器与波次
## 项目特有与跨系统机制
## 审计边界与待确认项
## 源码索引
```

Use this structure only when creating a new document. For an existing document, preserve its established organization and fill the nearest matching section.
