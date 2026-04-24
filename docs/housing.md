# Housing

Stage 7 introduces a minimal, data-driven housing/building framework.

## Included in Stage 7

- Build piece contract in `design/build_pieces.json`:
  - `id`
  - `display_name`
  - `category`
  - `placement_type`
  - `required_item_counts`
  - `max_health`
  - `tags`
- `BuildPiece` runtime model for placed piece state.
- `BuildingSystem` for abstract placement/removal flow:
  - cost validation
  - inventory cost consumption
  - local placed-piece tracking
  - placeholder material refund on removal

## Explicitly not included yet

- 3D placement preview
- physics/snap solving
- world persistence
- multiplayer ownership/synchronization
- polished building UI

This keeps Stage 7 focused on modular foundations for the upcoming movement/test-world stage.
