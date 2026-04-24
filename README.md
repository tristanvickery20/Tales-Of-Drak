# Tales of Drak

Tales of Drak is an open-source dark fantasy co-op RPG framework prototype built for Godot.

This repository is **not** trying to ship the full game yet. The current goal is to create a clean, expandable foundation for a future 4–6 player co-op RPG with:

- D&D-style classes, subclasses, stats, and progression
- itemization and equipment data
- inventory foundations
- housing and snapping build pieces
- gathering and crafting
- pet and mount placeholders
- a single dungeon shell
- a multiplayer lobby shell

## Current scope

This repo is currently focused on **Framework Prototype v0.1** only.

Included in v0.1:

1. character data
2. class and subclass data
3. stats and progression scaffolding
4. items and equipment data
5. inventory foundation
6. snapping build piece data
7. gathering node data
8. crafting recipe data
9. pet and mount placeholders
10. one dungeon shell definition
11. one multiplayer lobby shell structure

Not included yet:

- MMO systems
- live service features
- large-scale lore dumps
- full questing pipelines
- advanced networking implementation
- full combat implementation
- production-ready UI

## Stage tracker

- ✅ Stage 1: Repo foundation
- ✅ Stage 2: Data Contract v0.1
- ✅ Stage 3: Godot Data Loader Shell
- ✅ Stage 4: Character + Stats Framework
- ✅ Stage 5: Inventory + Equipment Framework
- ✅ Stage 6: Gathering + Crafting Framework
- ✅ Stage 7: Housing + Building Framework
- ✅ Stage 8: Movement + Test World Prototype
- 🟡 Stage 8.5: Web Preview Pipeline — *configured, awaiting first successful Actions run*

Stage 8 introduces a tiny playable graybox test world that wires movement, gathering, crafting, and building into one sandbox scene.

Stage 8.5 adds a GitHub Actions pipeline that validates the design data, exports the Godot test world to Web, and publishes it to GitHub Pages so it can be opened from a phone. See `docs/web-preview.md` for setup, limitations, and the manual GitHub Pages step required to enable it.

## Vision

Build a modular, open-source-friendly Godot framework for a dark fantasy RPG that starts local-first, stays data-driven, and can grow into a co-op experience without collapsing under its own complexity.

## Design principles

- **Foundation first** — define structure before building deep systems.
- **Local-first** — single-player and offline-friendly scaffolding first.
- **Co-op-ready** — prepare for Godot high-level multiplayer later.
- **Data-driven** — core gameplay content should be extendable through JSON.
- **Contributor-friendly** — keep names, folders, and files obvious.
- **AI-friendly** — write files so future AI assistance can safely extend them.

## Repository structure

```text
Tales-Of-Drak/
  README.md
  LICENSE
  ROADMAP.md
  CONTRIBUTING.md

  /docs
    vision.md
    pillars.md
    combat.md
    progression.md
    multiplayer.md
    housing.md
    crafting.md
    art-direction.md
    lore-overview.md

  /design
    classes.json
    subclasses.json
    species.json
    items.json
    weapons.json
    armor.json
    enemies.json
    dungeons.json
    build_pieces.json
    crafting_recipes.json
    gathering_nodes.json
    mounts.json
    pets.json
    quests.json

  /godot
    project.godot
    scenes/
    scripts/
    resources/
    ui/
    multiplayer/
    systems/
```

## Data contract

- See `docs/data-contract.md` for the v0.1 JSON schema and reference rules used by all `/design` files.

## Contributor workflow for adding new data

When adding gameplay content, prefer editing JSON data files before writing system code.

### General rules

- Keep entries small and explicit.
- Reuse IDs instead of duplicating meaning.
- Do not mix multiple systems into one file.
- Add placeholders instead of half-building a full feature.
- Preserve backward compatibility where possible.

### Example process

1. Pick the correct file in `/design`.
2. Add a new entry with a unique `id`.
3. Keep the structure consistent with existing examples.
4. Reference other content by ID, not by display name.
5. If a new field is needed, add it to the file's documented schema section first.
6. Only then add or update Godot-side handling in `/godot`.

## Godot note

The Godot project is intentionally nested under `/godot` so docs and design data can live cleanly at the repository root.

## Open-source direction

This repo is being prepared to be readable, forkable, and extendable by future contributors. The early focus is a strong skeleton, not maximum feature count.
