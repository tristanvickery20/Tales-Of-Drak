# Contributing

Thanks for helping shape Tales of Drak.

This project is currently in **framework prototype** mode. The goal is to build a clean, extendable base for a dark fantasy co-op RPG in Godot.

## What to optimize for

- clarity over cleverness
- small, reviewable additions
- data-driven content
- modular folders and files
- local-first foundation before multiplayer depth

## Before you contribute

Please read:

- `README.md`
- `ROADMAP.md`
- files in `/docs`
- the relevant JSON file in `/design`

## Contribution rules

1. Do not try to build the entire game in one pass.
2. Do not add MMO systems.
3. Do not overengineer abstractions early.
4. Prefer expanding data files before adding system code.
5. Keep filenames and IDs stable once introduced.
6. Use placeholders when a feature is not actually implemented yet.
7. Do not remove existing prototype files unless necessary.

## Data file conventions

- Use snake_case IDs.
- Keep display names human-readable.
- Reference related content by ID.
- Add new fields deliberately and document them inside the same file's schema section.
- Keep examples representative but small.

## Godot conventions

- Keep systems separated by concern.
- Avoid giant scripts.
- Prefer thin scenes and reusable resources.
- Keep multiplayer code isolated under `/godot/multiplayer` where possible.
- Do not hard-wire game balance into scripts if it can live in JSON or resources.

## Pull request guidance

Good pull requests usually:

- touch one system or one data area
- explain why the change exists
- update related docs when the structure changes
- avoid unrelated cleanup

## Early project note

The repository is still forming its public-facing framework conventions. When in doubt, keep the change boring, explicit, and easy for the next contributor to understand.
