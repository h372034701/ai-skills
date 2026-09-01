# AI Skills

Personal skill collection for Codex and other Agent Skills-compatible tools.

## Skills

| Skill | Purpose | Source |
| --- | --- | --- |
| `excalibur-skill-csharp` | Implement Excalibur skills in native C# with lifecycle, performance, GC, and SkillTrigger guidance. | Custom skill maintained in this repository. |
| `excalibur-skill-dsl` | Create and maintain Excalibur Skill DSL from design requirements. | Custom skill maintained in this repository. |
| `unity-cli-operator` | Operate the standalone Unity CLI on Windows, including routing, authentication, Editor management, and Pipeline automation. | Custom skill maintained in this repository. |
| `unity-spine-resource-recovery` | Recover Spine skeleton, atlas, texture, and Unity wrapper assets from game builds or AssetRipper exports. | Custom skill maintained in this repository. |
| `eli5` | Produce simple, visual explanations for non-experts. | Adapted from [`anthropics/claude-plugins-community`](https://github.com/anthropics/claude-plugins-community/tree/main/eli5/skills/eli5). |
| `grillme` | Pressure-test an idea or plan through a focused design interview. | Imported from [`AaronZHAO84/grillme`](https://github.com/AaronZHAO84/grillme/tree/main/skills/grillme). |

Each top-level skill directory contains its required `SKILL.md` entrypoint and any supporting `agents`, `scripts`, or `references` resources.

## Install

Copy a skill directory into the personal Codex skills directory:

```powershell
$skillName = 'excalibur-skill-dsl'
Copy-Item -Recurse -LiteralPath ".\$skillName" -Destination "$env:USERPROFILE\.codex\skills\$skillName"
```

Agent Skills-compatible tools may instead use `$env:USERPROFILE\.agents\skills` as their shared installation directory.

## Provenance

The imported skills retain their upstream provenance and licensing terms. This repository does not relicense third-party content. Check an individual skill and its upstream repository before redistributing or modifying it.
