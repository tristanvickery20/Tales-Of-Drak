# Scripts

Reusable GDScript files live here.

Current structure:

- `models/` — runtime models (`player_character.gd`, `inventory.gd`, `equipment.gd`, `gathering_node.gd`, `build_piece.gd`)
- `systems/` — framework systems (`data_registry.gd`, `character_factory.gd`, `stat_calculator.gd`, `equipment_stat_calculator.gd`, `gathering_system.gd`, `crafting_system.gd`, `building_system.gd`)
- `player/` — player controller logic (`third_person_controller.gd`)
- `world/` — scene/session orchestrators (`test_world_controller.gd`)
- `ui/` — lightweight UI/HUD scripts (`debug_hud.gd`)
- `debug/` — stage-specific debug runners

Guidelines:

- Prefer small scripts by responsibility instead of giant controller scripts.
- Keep framework systems data-driven and local-first.
- Add clear comments when introducing new data fields expected from `/design` JSON.
