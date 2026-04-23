# Roadmap

This roadmap is intentionally conservative. The project is building a clean framework first, not racing toward feature overload.

## Framework Prototype v0.1

Goal: define the base shape of the project.

Deliverables:

- repository structure for docs, data, and Godot code
- starter design data in JSON
- short design documentation for core systems
- placeholder Godot folders for scenes, scripts, resources, UI, multiplayer, and systems
- one dungeon shell definition
- one multiplayer lobby shell definition
- mount and pet placeholder data

Out of scope:

- persistent online world
- MMO servers or shard architecture
- advanced AI or combat behaviors
- production art pipeline
- fully playable content loop

## v0.2

Goal: prove local gameplay foundations.

Target additions:

- character resource definitions
- stat calculation helper scripts
- inventory model
- equipment slot model
- basic interactable gathering node scenes
- basic crafting station scene shell
- build piece snapping rules prototype

## v0.3

Goal: prove a vertical slice skeleton.

Target additions:

- one playable class loop
- one starter enemy family
- one dungeon blockout
- one crafting station flow
- one buildable shelter flow
- one pet and one mount spawn placeholder in-engine

## v0.4

Goal: introduce co-op structure safely.

Target additions:

- Godot high-level multiplayer lobby shell
- host/join flow for small sessions
- synchronized character spawn shell
- synchronized dungeon entry shell
- non-authoritative placeholder sync for testing

## v0.5 and beyond

Potential future direction:

- deeper combat rules
- status effects
- better enemy behaviors
- more classes and subclasses
- expanded dungeon content
- stronger housing and settlement systems
- more robust network authority model

## Rules for expansion

Before adding a new system, ask:

1. Does it fit the current prototype target?
2. Can it be data-driven?
3. Is there a smaller version that proves the idea first?
4. Will contributors understand where it belongs immediately?
