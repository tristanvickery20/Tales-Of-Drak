# Scripts

Reusable GDScript files live here.

Current structure:

- `models/` — runtime models (`player_character.gd`, `inventory.gd`, `equipment.gd`, `gathering_node.gd`, `build_piece.gd`)
- `systems/` — framework systems (`data_registry.gd`, `character_factory.gd`, `stat_calculator.gd`, `equipment_stat_calculator.gd`, `gathering_system.gd`, `crafting_system.gd`, `building_system.gd`)
- `player/` — player controller logic (`third_person_controller.gd`)
- `world/` — scene/session orchestrators (`test_world_controller.gd`)
- `ui/` — lightweight UI/HUD scripts (`debug_hud.gd`, `mobile_controls.gd`)
- `debug/` — stage-specific debug runners

### Input flow (Stage 8.6)

Both desktop keyboard and the mobile touch overlay drive the same Godot
`InputMap` actions (defined in `godot/project.godot`):

| Action        | Keyboard | Mobile button / control |
|---------------|----------|-------------------------|
| `move_*`      | WASD     | left thumbstick         |
| `jump`        | Space    | "Jump" button           |
| `sprint`      | Shift    | "Sprint" button (hold)  |
| `interact`    | E        | "Interact" button       |
| `craft`       | C        | "Craft" button          |
| `place_build` | B        | "Place" button          |

`third_person_controller.gd` reads movement/jump/sprint via
`Input.get_action_strength` / `Input.is_action_pressed`.
`test_world_controller.gd` reads interact/craft/place via
`Input.is_action_just_pressed`.
`mobile_controls.gd` calls `Input.action_press` / `Input.action_release`
for the same actions, so all existing systems work unchanged.

Guidelines:

- Prefer small scripts by responsibility instead of giant controller scripts.
- Keep framework systems data-driven and local-first.
- Add clear comments when introducing new data fields expected from `/design` JSON.
