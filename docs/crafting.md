# Crafting

Crafting in Framework Prototype v0.1 stays intentionally small and data-driven.

## Stage 6 status

Completed:

- Gathering node data contract (`gathering_nodes.json`) with required tool, output item, quantity range, and respawn placeholder.
- Crafting recipe contract (`crafting_recipes.json`) with:
  - `recipe_id`
  - `display_name`
  - `input_item_counts`
  - `output_item_counts`
  - `required_station_id`
  - `crafting_seconds`
- `GatheringSystem` that validates tools/items, grants output, and marks nodes depleted.
- `CraftingSystem` that validates recipe item references, checks missing requirements, removes inputs, and grants outputs.

Deferred on purpose:

- station/world placement logic
- timers/animations
- large recipe databases
- multiplayer synchronization

This keeps Stage 6 focused on reusable framework logic for future dungeon loot, crafting progression, and co-op sync layers.
