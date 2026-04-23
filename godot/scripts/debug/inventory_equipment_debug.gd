extends Node

## Stage 5 debug entry point.
## Builds a sample character, inventory, and equipment set, then prints outputs.

func _ready() -> void:
	var registry := DataRegistry.new()
	if not registry.load_all_design_data():
		print("[InventoryEquipmentDebug] Failed to load design data.")
		return

	var factory := CharacterFactory.new()
	var character := factory.create_level_one_character(
		registry,
		"Pack Tester",
		"human",
		"warden",
		"ashen_guard"
	)
	if character == null:
		print("[InventoryEquipmentDebug] Failed to create character.")
		return

	var inventory := Inventory.new()
	inventory.initialize(character.character_id, registry, 12)

	# Starter payload.
	inventory.add_item("iron_ore", 25)
	inventory.add_item("torch_kit", 2)
	inventory.add_item("rusted_longsword", 1)
	inventory.add_item("tarnished_cuirass", 1)

	var equipment := Equipment.new()
	equipment.initialize(character.character_id, registry)

	# Move items from inventory into equipment.
	if inventory.remove_item("rusted_longsword", 1):
		equipment.equip_item("main_hand", "rusted_longsword")
	if inventory.remove_item("tarnished_cuirass", 1):
		equipment.equip_item("chest", "tarnished_cuirass")

	print("[InventoryEquipmentDebug] Inventory contents:")
	print(JSON.stringify(inventory.get_all_items(), "  "))

	print("[InventoryEquipmentDebug] Equipped gear:")
	print(JSON.stringify(equipment.get_all_equipped(), "  "))

	var base_stats := character.derived_stats.duplicate(true)
	var with_equipment := EquipmentStatCalculator.calculate_with_equipment(character, equipment)

	print("[InventoryEquipmentDebug] Base derived stats:")
	print(JSON.stringify(base_stats, "  "))
	print("[InventoryEquipmentDebug] Derived stats with equipment:")
	print(JSON.stringify(with_equipment, "  "))
