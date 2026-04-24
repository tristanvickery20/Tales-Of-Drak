# UI

Place menu and HUD scenes, theme assets, and UI scripts here.

Framework Prototype v0.1 only needs a future home for:

- title screen shell
- character shell
- inventory shell
- crafting shell
- multiplayer lobby shell

### Stage 8.6 note

Active in-game UI scripts currently live in `godot/scripts/ui/`:

- `debug_hud.gd` — minimal four-line debug overlay (character, inventory,
  prompt, last result). Stage 8.6 bumps the label font size so it stays
  readable on iPhone Safari.
- `mobile_controls.gd` — Stage 8.6 on-screen control overlay (left
  thumbstick + right action buttons). Built programmatically and added to
  `scenes/test_world/test_world.tscn` as a single `CanvasLayer` node.

This `godot/ui/` folder is reserved for full UI scenes / themes added in
later stages and is intentionally still empty.
