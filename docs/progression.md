# Progression

The progression model should feel familiar to players who enjoy tabletop-inspired role progression without becoming a strict tabletop simulator.

Starter assumptions:

- characters have a species, class, and subclass path
- leveling modifies core stats and unlocks future features
- subclasses branch identity without requiring a full rewrite of the base class
- equipment and crafted items should matter alongside level

## Framework Prototype v0.1 status

### Completed in Stage 4 (Character + Stats Framework)

- Data-driven character creation using `species`, `class`, and `subclass` records.
- A `PlayerCharacter` data object with level, xp, ability scores, and derived stats.
- A `CharacterFactory` that validates IDs against `DataRegistry` before character creation.

### Completed in Stage 5 (Inventory + Equipment Framework)

- Inventory model with stack-aware item operations.
- Equipment model with explicit slots and data-driven item validation.
- Equipment bonus aggregation for armor class, max health, movement speed, and ability modifiers.
- Derived-stat extension path through equipment-aware stat calculation.

### Deliberately deferred

- combat actions and turn logic
- crafting processing and recipes execution
- loot-drop pipelines
- multiplayer synchronization of character/inventory/equipment state
- visual character customization and polished UI

This keeps progression extensible while preserving a clear framework-first scope.
