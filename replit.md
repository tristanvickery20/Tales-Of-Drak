# Tales of Drak — Replit Setup

## Project type
Open-source dark fantasy co-op RPG framework prototype for **Godot**.
The repository is data-driven: gameplay content lives in JSON files under
`/design`, Godot scripts/scenes under `/godot`, design notes under `/docs`,
and a Python validator under `/tools`.

## Repository layout
- `design/` — JSON data files (classes, items, weapons, armor, recipes, etc.)
- `docs/`   — Markdown design docs and the v0.1 data contract
- `godot/`  — Godot project (scripts, scenes, systems)
- `tools/`  — `validate_character_framework.py` data-contract validator
- `serve.py` — Replit-only dashboard web server (see below)

## Replit web preview
Godot is a desktop engine and cannot run inside Replit's iframe preview.
To make the project meaningfully previewable here, `serve.py` runs a small
Python stdlib HTTP server (`http.server`) that exposes a dashboard:

- `/`                 — Overview of design data files and docs
- `/design/`          — Browseable list of JSON design files
- `/design/<file>`    — Pretty-printed JSON view of a single file
- `/docs/`            — List of Markdown docs
- `/docs/<file>`      — Rendered Markdown view of a single doc
- `/validate`         — Runs `tools/validate_character_framework.py` and
                        shows pass/fail plus stdout/stderr

The server binds **0.0.0.0:5000** with no-cache headers and does not perform
host-header validation, so the Replit proxy iframe works out of the box.

## Workflow
- **Start application** — `python3 serve.py` (port 5000, webview)

## Deployment
Configured as **autoscale** with run command `python3 serve.py`.

## Editing rules carried over from the upstream project
- Prefer editing JSON in `/design` before adding Godot code.
- Reference content by `id`, never by display name.
- Keep entries small and explicit; preserve schema fields shown in
  `docs/data-contract.md`.
- Run `python3 tools/validate_character_framework.py` (or hit `/validate`)
  after data changes.
