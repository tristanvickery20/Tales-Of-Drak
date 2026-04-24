# Multiplayer

Multiplayer is planned, but the project starts local-first.

Framework Prototype v0.1 only needs a **multiplayer lobby shell**, not full synchronized gameplay.

Guidelines:

- use Godot built-in high-level multiplayer later
- keep networking code isolated from single-player logic where possible
- do not design for MMO scale
- target host-and-join sessions for small parties
- prefer deterministic and simple content definitions

Later prototypes can add:

- lobby UI
- ready states
- basic party sync
- dungeon entry sync
