extends Node

## Stage 7 debug entry point.

func _ready() -> void:
	var registry := DataRegistry.new()
	if not registry.load_all_design_data():
		print("[HousingBuildingDebug] Failed to load design data.")
		return

	var factory := CharacterFactory.new()
	var character := factory.create_level_one_character(registry, "Builder", "human", "warden", "ashen_guard")
	if character == null:
		print("[HousingBuildingDebug] Failed to create character.")
		return

	var inventory := Inventory.new()
	inventory.initialize(character.character_id, registry, 30)
	inventory.add_item("weathered_timber", 20)
	inventory.add_item("torch_kit", 2)

	print("[HousingBuildingDebug] Inventory before placement:")
	print(JSON.stringify(inventory.get_all_items(), "  "))

	var building := BuildingSystem.new()
	building.initialize(registry)

	var place_foundation := building.place_piece(
		"timber_foundation",
		inventory,
		{"x": 0.0, "y": 0.0, "z": 0.0},
		{"x": 0.0, "y": 0.0, "z": 0.0}
	)
	var place_wall := building.place_piece(
		"timber_wall",
		inventory,
		{"x": 0.0, "y": 0.0, "z": 2.0},
		{"x": 0.0, "y": 90.0, "z": 0.0}
	)

	print("[HousingBuildingDebug] Placement result foundation:")
	print(JSON.stringify(place_foundation, "  "))
	print("[HousingBuildingDebug] Placement result wall:")
	print(JSON.stringify(place_wall, "  "))

	print("[HousingBuildingDebug] Placed pieces:")
	print(JSON.stringify(building.get_placed_pieces(), "  "))

	print("[HousingBuildingDebug] Inventory after placement:")
	print(JSON.stringify(inventory.get_all_items(), "  "))

	var remove_result := {"ok": false, "reason": "none_placed"}
	if place_wall.get("ok", false):
		remove_result = building.remove_piece(str(place_wall.get("build_piece_instance_id", "")), inventory)

	print("[HousingBuildingDebug] Removal result:")
	print(JSON.stringify(remove_result, "  "))

	print("[HousingBuildingDebug] Placed pieces after removal:")
	print(JSON.stringify(building.get_placed_pieces(), "  "))
