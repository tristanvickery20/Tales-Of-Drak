extends Node

## Stage 6 debug entry point.

func _ready() -> void:
	var registry := DataRegistry.new()
	if not registry.load_all_design_data():
		print("[GatheringCraftingDebug] Failed to load design data.")
		return

	var factory := CharacterFactory.new()
	var character := factory.create_level_one_character(registry, "Gather Crafter", "human", "warden", "ashen_guard")
	if character == null:
		print("[GatheringCraftingDebug] Failed to create character.")
		return

	var inventory := Inventory.new()
	inventory.initialize(character.character_id, registry, 20)
	inventory.add_item("starter_hatchet", 1)
	inventory.add_item("weathered_timber", 1)

	print("[GatheringCraftingDebug] Inventory before gathering:")
	print(JSON.stringify(inventory.get_all_items(), "  "))

	var node_record := registry.get_record("gathering_node", "weathered_tree_deadfall")
	var node := GatheringNode.new()
	node.load_from_record("node_deadfall_01", node_record)

	var gathering_system := GatheringSystem.new()
	gathering_system.initialize(registry)
	var gather_result := gathering_system.gather(node, inventory)

	print("[GatheringCraftingDebug] Gathering result:")
	print(JSON.stringify(gather_result, "  "))

	print("[GatheringCraftingDebug] Inventory after gathering:")
	print(JSON.stringify(inventory.get_all_items(), "  "))

	var crafting_system := CraftingSystem.new()
	crafting_system.initialize(registry)
	var craft_result := crafting_system.craft("craft_torch_kit", inventory)

	print("[GatheringCraftingDebug] Crafting result:")
	print(JSON.stringify(craft_result, "  "))

	print("[GatheringCraftingDebug] Inventory after crafting:")
	print(JSON.stringify(inventory.get_all_items(), "  "))
