# Scenes

Place Godot scenes here.

Current prototype scenes:

- `debug/` — stage-by-stage system debug runners
- `test_world/test_world.tscn` — Stage 8 playable graybox sandbox
- `dungeon/dungeon_shell.tscn` — Stage 9 graybox dungeon

Stage 8 test world includes:

- third-person movement controller
- simple camera follow
- tiny graybox environment
- gathering interaction test
- crafting hotkey test
- build placement hotkey test
- minimal debug HUD

Stage 8.6 additions to the same scene (no replacement, no new world):

- a `MobileControls` `CanvasLayer` node attached to `test_world.tscn`
  whose script is `res://scripts/ui/mobile_controls.gd`
- on-screen left thumbstick + right action buttons (Jump, Sprint,
  Interact, Craft, Place) that feed the same Godot input actions as the
  keyboard

Stage 9 dungeon shell includes:

- rectangular graybox room with floor and four walls
- player spawn point
- placeholder enemy (red box) — combat placeholder only
- placeholder reward chest (gold box) — opens with interaction, shows reward message
- exit portal (cyan archway) back to test world
- mobile controls overlay for iPhone compatibility
- simple debug HUD with interaction prompts

Keep scenes small and focused. Avoid turning one scene into the whole game.
