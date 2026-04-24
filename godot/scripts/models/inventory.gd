extends RefCounted
class_name Inventory

## Inventory v0.1
##
## Slot-based inventory that supports stackable and non-stackable item records.
## Stack behavior is driven by design/items.json stack_size values.

var owner_character_id: String = ""
var max_slots: int = 20

# Array[Dictionary] with entries:
# { "item_id": String, "quantity": int }
var item_stacks: Array = []

var _registry: DataRegistry = null


func initialize(character_id: String, registry: DataRegistry, inventory_max_slots: int = 20) -> void:
	owner_character_id = character_id
	_registry = registry
	max_slots = max(1, inventory_max_slots)
	item_stacks.clear()


func add_item(item_id: String, quantity: int) -> bool:
	if _registry == null:
		push_error("[Inventory] DataRegistry is null.")
		return false
	if quantity <= 0:
		push_error("[Inventory] quantity must be > 0.")
		return false
	if not _registry.has_record("item", item_id):
		push_error("[Inventory] Unknown item_id: %s" % item_id)
		return false

	var item_record := _registry.get_record("item", item_id)
	var stack_size := max(1, int(item_record.get("stack_size", 1)))
	var remaining := quantity

	# Fill existing stacks first.
	for stack in item_stacks:
		if str(stack.get("item_id", "")) != item_id:
			continue
		var existing_qty := int(stack.get("quantity", 0))
		if existing_qty >= stack_size:
			continue
		var space := stack_size - existing_qty
		var add_now := min(space, remaining)
		stack["quantity"] = existing_qty + add_now
		remaining -= add_now
		if remaining == 0:
			return true

	# Create new stacks if slots remain.
	while remaining > 0:
		if item_stacks.size() >= max_slots:
			push_warning("[Inventory] Not enough slots to add all items for %s. Added partial amount." % item_id)
			return false
		var add_now := min(stack_size, remaining)
		item_stacks.append({
			"item_id": item_id,
			"quantity": add_now
		})
		remaining -= add_now

	return true


func remove_item(item_id: String, quantity: int) -> bool:
	if quantity <= 0:
		push_error("[Inventory] quantity must be > 0.")
		return false
	if get_item_count(item_id) < quantity:
		push_warning("[Inventory] Not enough items to remove: %s x%d" % [item_id, quantity])
		return false

	var remaining := quantity
	for i in range(item_stacks.size() - 1, -1, -1):
		var stack := item_stacks[i]
		if str(stack.get("item_id", "")) != item_id:
			continue
		var stack_qty := int(stack.get("quantity", 0))
		var remove_now := min(stack_qty, remaining)
		stack_qty -= remove_now
		remaining -= remove_now
		if stack_qty <= 0:
			item_stacks.remove_at(i)
		else:
			stack["quantity"] = stack_qty
		if remaining == 0:
			break

	return remaining == 0


func has_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true
	return get_item_count(item_id) >= quantity


func get_item_count(item_id: String) -> int:
	var total := 0
	for stack in item_stacks:
		if str(stack.get("item_id", "")) == item_id:
			total += int(stack.get("quantity", 0))
	return total


func get_all_items() -> Array:
	return item_stacks.duplicate(true)
