# Data Contract v0.1

This document defines the JSON data contract for `/design` files in **Tales of Drak**.

## Core rules

### 1) `id` naming rules

- Every record must have an `id`.
- IDs must be **snake_case** and stable once added.
- Use IDs for cross-file references, never display names.
- Good: `weeping_crypt`, `iron_ore`, `ashen_guard`
- Avoid: `WeepingCrypt`, `Iron Ore`, `class-01`

### 2) `schema_version` rules

- Every `/design/*.json` file must include a top-level `schema_version`.
- Framework Prototype v0.1 uses `"schema_version": "0.1.0"`.
- If a breaking structure change is introduced, bump the version intentionally in a dedicated change.

### 3) Required top-level pattern

Use this shape for all `/design` files:

```json
{
  "schema_version": "0.1.0",
  "record_type": "example_type",
  "records": []
}
```

- `record_type` is a simple label for what the file contains.
- `records` is the list Godot loaders should parse.

### 4) Reference rules

- Related data must reference by `id`.
- Use explicit key names for references:
  - `class_id`, `enemy_ids`, `reward_item_ids`, `required_item_counts`, etc.
- Do not reference records by `name`.

## How to add new records safely

### Add a new class
1. Add one record to `design/classes.json`.
2. Use a new snake_case `id`.
3. Keep field names consistent with existing class records.

### Add a new item
1. Add one record to `design/items.json`.
2. Keep `stack_size`, `rarity`, and `tag_ids` explicit.
3. Reuse that `item.id` in other files when needed.

### Add a new recipe
1. Add one record to `design/crafting_recipes.json`.
2. Use `input_item_counts` and `output_item_counts` maps keyed by item ID.
3. Ensure all referenced item IDs exist in `design/items.json`.

### Add a new enemy
1. Add one record to `design/enemies.json`.
2. Keep `drop_item_ids` limited to valid item IDs.
3. Optionally add the enemy ID into a dungeon's `enemy_ids`.

### Add a new build piece
1. Add one record to `design/build_pieces.json`.
2. Use `required_item_counts` keyed by valid item IDs.
3. Keep dimensions simple (`x`, `y`, `z`).

### Add a new quest
1. Add one record to `design/quests.json`.
2. Keep objective IDs simple and stable in `objective_ids`.
3. Use `reward_item_ids` with valid item IDs.

## v0.1 scope guardrails

- Keep records minimal (1-3 starter records per file is enough for early scaffolding).
- Avoid deep inheritance or abstract schema systems.
- Favor clear, parseable structures for straightforward GDScript loading.
