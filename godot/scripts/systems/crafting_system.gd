extends RefCounted
class_name CraftingSystem

## CraftingSystem v0.1
##
## Recipe execution using design/crafting_recipes.json records and Inventory.

var _registry: DataRegistry = null


func initialize(registry: DataRegistry) -> void:
	_registry = registry


func can_craft(recipe_id: String, inventory: Inventory) -> bool:
	if _registry == null:
		push_error("[CraftingSystem] DataRegistry is null.")
		return false
	if inventory == null:
		push_error("[CraftingSystem] Inventory is null.")
		return false

	var recipe := _registry.get_record("crafting_recipe", recipe_id)
	if recipe.is_empty():
		push_error("[CraftingSystem] Unknown recipe_id: %s" % recipe_id)
		return false

	if not _validate_recipe_item_refs(recipe):
		return false

	return get_missing_requirements(recipe_id, inventory).is_empty()


func craft(recipe_id: String, inventory: Inventory) -> Dictionary:
	var recipe := _registry.get_record("crafting_recipe", recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "unknown_recipe"}

	var missing := get_missing_requirements(recipe_id, inventory)
	if not missing.is_empty():
		print("[CraftingSystem] Missing materials for %s: %s" % [recipe_id, JSON.stringify(missing)])
		return {"ok": false, "reason": "missing_requirements", "missing": missing}

	if not _validate_recipe_item_refs(recipe):
		return {"ok": false, "reason": "invalid_item_refs"}

	var inputs: Dictionary = recipe.get("input_item_counts", {})
	for item_id in inputs.keys():
		if not inventory.remove_item(item_id, int(inputs[item_id])):
			return {"ok": false, "reason": "remove_failed", "item_id": item_id}

	var outputs: Dictionary = recipe.get("output_item_counts", {})
	for item_id in outputs.keys():
		if not inventory.add_item(item_id, int(outputs[item_id])):
			return {"ok": false, "reason": "add_failed", "item_id": item_id}

	print("[CraftingSystem] Crafted %s successfully." % recipe_id)
	return {"ok": true, "recipe_id": recipe_id, "outputs": outputs}


func get_missing_requirements(recipe_id: String, inventory: Inventory) -> Dictionary:
	var recipe := _registry.get_record("crafting_recipe", recipe_id)
	if recipe.is_empty():
		return {"recipe_id": "missing"}

	var missing := {}
	var inputs: Dictionary = recipe.get("input_item_counts", {})
	for item_id in inputs.keys():
		var required_qty := int(inputs[item_id])
		var have_qty := inventory.get_item_count(item_id)
		if have_qty < required_qty:
			missing[item_id] = required_qty - have_qty
	return missing


func get_available_recipes(inventory: Inventory) -> Array:
	var available: Array = []
	for recipe in _registry.get_records("crafting_recipe"):
		var rid := str(recipe.get("id", ""))
		if rid.is_empty():
			continue
		if can_craft(rid, inventory):
			available.append(recipe)
	return available


func _validate_recipe_item_refs(recipe: Dictionary) -> bool:
	var inputs: Dictionary = recipe.get("input_item_counts", {})
	var outputs: Dictionary = recipe.get("output_item_counts", {})

	for item_id in inputs.keys():
		if not _registry.has_record("item", item_id):
			push_error("[CraftingSystem] Recipe references unknown input item_id: %s" % item_id)
			return false

	for item_id in outputs.keys():
		if not _registry.has_record("item", item_id):
			push_error("[CraftingSystem] Recipe references unknown output item_id: %s" % item_id)
			return false

	return true
