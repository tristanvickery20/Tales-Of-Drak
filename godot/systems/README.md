# Systems

This folder contains gameplay-adjacent systems for the Godot side of the framework.

## Stage 3: Data Loader Shell
- `res://scripts/systems/data_registry.gd`

## Stage 4: Character + Stats
- `res://scripts/models/player_character.gd`
- `res://scripts/systems/stat_calculator.gd`
- `res://scripts/systems/character_factory.gd`

## Stage 5: Inventory + Equipment
- `res://scripts/models/inventory.gd`
- `res://scripts/models/equipment.gd`
- `res://scripts/systems/equipment_stat_calculator.gd`

## Stage 6: Gathering + Crafting
- `res://scripts/models/gathering_node.gd`
- `res://scripts/systems/gathering_system.gd`
- `res://scripts/systems/crafting_system.gd`

## Stage 7: Housing + Building
- `res://scripts/models/build_piece.gd`
- `res://scripts/systems/building_system.gd`

## Stage 8: Movement + Test World Prototype
- `res://scripts/player/third_person_controller.gd`
- `res://scripts/world/test_world_controller.gd`
- `res://scripts/ui/debug_hud.gd`
- `res://scenes/test_world/test_world.tscn`

### Stage 8 playable controls
- Move: `W A S D`
- Jump: `Space`
- Sprint: `Shift` (placeholder)
- Interact gather node: `E` (when close)
- Craft test recipe: `C`
- Place build test piece: `B`

### What Stage 8 proves
- Framework systems can be initialized together in one scene.
- Inventory updates from gathering, crafting, and building costs are visible in HUD.
- Build placement can spawn simple placeholder meshes and consume resources.

This remains prototype-first: no combat, no multiplayer sync, no polished art/UI.
