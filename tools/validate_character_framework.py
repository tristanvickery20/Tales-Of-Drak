#!/usr/bin/env python3
"""Framework Prototype v0.1 validator (Stages 4-8)."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / "design"

EXPECTED_RECORD_TYPES = {
    "armor.json": "armor",
    "build_pieces.json": "build_piece",
    "classes.json": "class",
    "crafting_recipes.json": "crafting_recipe",
    "dungeons.json": "dungeon",
    "enemies.json": "enemy",
    "gathering_nodes.json": "gathering_node",
    "items.json": "item",
    "mounts.json": "mount",
    "pets.json": "pet",
    "quests.json": "quest",
    "species.json": "species",
    "subclasses.json": "subclass",
    "weapons.json": "weapon",
}

REQUIRED_ABILITIES = {"strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"}
VALID_EQUIPMENT_SLOTS = {"head", "chest", "legs", "feet", "main_hand", "off_hand", "ring", "amulet", "two_hand"}
VALID_BUILD_CATEGORIES = {"foundation", "wall", "structure", "roof", "utility", "furniture", "comfort"}
VALID_PLACEMENT_TYPES = {"ground_snap", "vertical_snap", "roof_snap", "wall_snap", "ground_place"}
SNAKE_CASE_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def check_bonus_map(record: dict, key: str) -> list[str]:
    errors: list[str] = []
    bonuses = record.get(key, {})
    if not isinstance(bonuses, dict):
        return [f"{record.get('id')}: {key} must be an object"]
    for k, v in bonuses.items():
        if k not in REQUIRED_ABILITIES:
            errors.append(f"{record.get('id')}: unsupported ability key '{k}' in {key}")
        if not isinstance(v, int):
            errors.append(f"{record.get('id')}: {key}.{k} must be int")
    return errors


def check_equipment_bonus_shape(record: dict, key: str = "equipment_bonuses") -> list[str]:
    errors: list[str] = []
    bonuses = record.get(key, {})
    if not isinstance(bonuses, dict):
        return [f"{record.get('id')}: {key} must be an object"]
    for numeric_key in ("armor_class_bonus", "max_health_bonus", "movement_speed_bonus"):
        if not isinstance(bonuses.get(numeric_key, 0), int):
            errors.append(f"{record.get('id')}: {key}.{numeric_key} must be int")
    ability = bonuses.get("ability_bonuses", {})
    if not isinstance(ability, dict):
        errors.append(f"{record.get('id')}: {key}.ability_bonuses must be object")
    else:
        for k, v in ability.items():
            if k not in REQUIRED_ABILITIES:
                errors.append(f"{record.get('id')}: unsupported ability key '{k}' in {key}.ability_bonuses")
            if not isinstance(v, int):
                errors.append(f"{record.get('id')}: {key}.ability_bonuses.{k} must be int")
    return errors


def main() -> int:
    errors: list[str] = []
    parsed: dict[str, dict] = {}

    for path in sorted(DESIGN.glob("*.json")):
        try:
            parsed[path.name] = json.loads(path.read_text())
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{path.name}: failed to parse JSON ({exc})")

    for fname, expected_type in EXPECTED_RECORD_TYPES.items():
        if fname not in parsed:
            errors.append(f"{fname}: missing file")
            continue
        root = parsed[fname]
        if root.get("schema_version") != "0.1.0":
            errors.append(f"{fname}: schema_version must be 0.1.0")
        if root.get("record_type") != expected_type:
            errors.append(f"{fname}: record_type must be '{expected_type}'")
        if not isinstance(root.get("records"), list):
            errors.append(f"{fname}: records must be an array")


    # Stage 8 lightweight file checks.
    required_files = [
        ROOT / "godot/scenes/test_world/test_world.tscn",
        ROOT / "godot/scripts/world/test_world_controller.gd",
        ROOT / "godot/scripts/player/third_person_controller.gd",
        ROOT / "godot/scripts/ui/debug_hud.gd",
    ]
    for file_path in required_files:
        if not file_path.exists():
            errors.append(f"missing required Stage 8 file: {file_path.relative_to(ROOT)}")

    # Stage 8.6 — Browser / Touch Control Layer checks.
    mobile_controls = ROOT / "godot/scripts/ui/mobile_controls.gd"
    test_world_scene = ROOT / "godot/scenes/test_world/test_world.tscn"
    project_godot = ROOT / "godot/project.godot"

    if not mobile_controls.exists():
        errors.append("missing required Stage 8.6 file: godot/scripts/ui/mobile_controls.gd")

    if test_world_scene.exists():
        scene_text = test_world_scene.read_text()
        if "scripts/ui/mobile_controls.gd" not in scene_text:
            errors.append(
                "Stage 8.6: godot/scenes/test_world/test_world.tscn does not "
                "reference scripts/ui/mobile_controls.gd"
            )
        if 'name="MobileControls"' not in scene_text:
            errors.append(
                "Stage 8.6: test_world.tscn is missing the MobileControls "
                "CanvasLayer node"
            )

    if project_godot.exists():
        project_text = project_godot.read_text()
        required_actions = [
            "move_forward", "move_back", "move_left", "move_right",
            "jump", "sprint", "interact", "craft", "place_build",
        ]
        for action in required_actions:
            if f"\n{action}=" not in project_text:
                errors.append(
                    f"Stage 8.6: project.godot is missing input action '{action}'"
                )

    if errors:
        print("Validation failed:")
        for e in errors:
            print(f"- {e}")
        return 1

    classes = parsed["classes.json"]["records"]
    species = parsed["species.json"]["records"]
    subclasses = parsed["subclasses.json"]["records"]
    items = parsed["items.json"]["records"]
    weapons = parsed["weapons.json"]["records"]
    armor = parsed["armor.json"]["records"]
    gathering_nodes = parsed["gathering_nodes.json"]["records"]
    recipes = parsed["crafting_recipes.json"]["records"]
    build_pieces = parsed["build_pieces.json"]["records"]

    class_ids = {c.get("id") for c in classes}
    item_ids = {i.get("id") for i in items}

    for r in classes:
        errors.extend(check_bonus_map(r, "starter_ability_bonuses"))
    for r in species:
        errors.extend(check_bonus_map(r, "ability_bonuses"))
        if not isinstance(r.get("movement_speed_bonus", 0), int):
            errors.append(f"{r.get('id')}: movement_speed_bonus must be int")
    for r in subclasses:
        errors.extend(check_bonus_map(r, "starter_ability_bonuses"))
        if r.get("class_id") not in class_ids:
            errors.append(f"{r.get('id')}: class_id '{r.get('class_id')}' not found in classes.json")

    for r in weapons:
        rid = r.get("id")
        if r.get("base_item_id") != rid:
            errors.append(f"weapon {rid}: base_item_id must match id for v0.1")
        if rid not in item_ids:
            errors.append(f"weapon {rid}: missing base item record in items.json")
        if r.get("slot") not in VALID_EQUIPMENT_SLOTS:
            errors.append(f"weapon {rid}: invalid slot '{r.get('slot')}'")
        errors.extend(check_equipment_bonus_shape(r))

    armor_slots = VALID_EQUIPMENT_SLOTS - {"two_hand", "main_hand", "off_hand"}
    for r in armor:
        rid = r.get("id")
        if r.get("base_item_id") != rid:
            errors.append(f"armor {rid}: base_item_id must match id for v0.1")
        if rid not in item_ids:
            errors.append(f"armor {rid}: missing base item record in items.json")
        if r.get("slot") not in armor_slots:
            errors.append(f"armor {rid}: invalid slot '{r.get('slot')}'")
        errors.extend(check_equipment_bonus_shape(r))

    for node in gathering_nodes:
        nid = node.get("id")
        output_id = node.get("output_item_id")
        tool_id = node.get("required_tool_item_id", "")
        if output_id not in item_ids:
            errors.append(f"gathering node {nid}: output_item_id '{output_id}' not found in items.json")
        if tool_id and tool_id not in item_ids:
            errors.append(f"gathering node {nid}: required_tool_item_id '{tool_id}' not found in items.json")
        qmin, qmax = node.get("output_quantity_min", 1), node.get("output_quantity_max", 1)
        if not isinstance(qmin, int) or not isinstance(qmax, int) or qmin <= 0 or qmax <= 0 or qmin > qmax:
            errors.append(f"gathering node {nid}: invalid output quantity range")

    for recipe in recipes:
        rid = recipe.get("id")
        if recipe.get("recipe_id") != rid:
            errors.append(f"recipe {rid}: recipe_id must match id")
        for key in ("input_item_counts", "output_item_counts"):
            counts = recipe.get(key, {})
            if not isinstance(counts, dict):
                errors.append(f"recipe {rid}: {key} must be an object")
                continue
            for item_id, qty in counts.items():
                if item_id not in item_ids:
                    errors.append(f"recipe {rid}: {key} references unknown item '{item_id}'")
                if not isinstance(qty, int) or qty <= 0:
                    errors.append(f"recipe {rid}: {key}.{item_id} must be int > 0")
        if not isinstance(recipe.get("crafting_seconds", 0), int):
            errors.append(f"recipe {rid}: crafting_seconds must be int")

    for piece in build_pieces:
        pid = piece.get("id", "")
        if not SNAKE_CASE_RE.match(pid):
            errors.append(f"build piece {pid}: id must be snake_case")
        if piece.get("category") not in VALID_BUILD_CATEGORIES:
            errors.append(f"build piece {pid}: invalid category '{piece.get('category')}'")
        if piece.get("placement_type") not in VALID_PLACEMENT_TYPES:
            errors.append(f"build piece {pid}: invalid placement_type '{piece.get('placement_type')}'")
        req = piece.get("required_item_counts", {})
        if not isinstance(req, dict):
            errors.append(f"build piece {pid}: required_item_counts must be object")
            continue
        for item_id, qty in req.items():
            if item_id not in item_ids:
                errors.append(f"build piece {pid}: required item '{item_id}' not found in items.json")
            if not isinstance(qty, int) or qty <= 0:
                errors.append(f"build piece {pid}: required_item_counts.{item_id} must be int > 0")

    if errors:
        print("Validation failed:")
        for e in errors:
            print(f"- {e}")
        return 1

    print("Validation passed: Stage 4 + Stage 5 + Stage 6 + Stage 7 + Stage 8 data checks are consistent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
