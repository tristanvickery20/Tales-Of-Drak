extends RefCounted
class_name GatheringSystem

## GatheringSystem v0.1
##
## Validates nodes against DataRegistry and adds gathered outputs into Inventory.

var _registry: DataRegistry = null


func initialize(registry: DataRegistry) -> void:
	_registry = registry


func can_gather(node: GatheringNode, inventory: Inventory) -> bool:
	if _registry == null:
		push_error("[GatheringSystem] DataRegistry is null.")
		return false
	if node == null or inventory == null:
		push_error("[GatheringSystem] node/inventory is null.")
		return false
	if node.is_depleted:
		print("[GatheringSystem] Node is depleted: %s" % node.node_id)
		return false
	if not _registry.has_record("gathering_node", node.gathering_node_id):
		push_error("[GatheringSystem] Unknown gathering_node_id: %s" % node.gathering_node_id)
		return false
	if not _registry.has_record("item", node.output_item_id):
		push_error("[GatheringSystem] Invalid output_item_id: %s" % node.output_item_id)
		return false
	if not node.required_tool_item_id.is_empty() and not inventory.has_item(node.required_tool_item_id, 1):
		print("[GatheringSystem] Missing required tool: %s" % node.required_tool_item_id)
		return false
	return true


func gather(node: GatheringNode, inventory: Inventory) -> Dictionary:
	if not can_gather(node, inventory):
		return {"ok": false, "reason": "can_gather_failed"}

	var min_qty := min(node.output_quantity_min, node.output_quantity_max)
	var max_qty := max(node.output_quantity_min, node.output_quantity_max)
	var amount := randi_range(min_qty, max_qty)
	var added := inventory.add_item(node.output_item_id, amount)
	if not added:
		print("[GatheringSystem] Inventory full/limited while gathering %s x%d" % [node.output_item_id, amount])
		return {"ok": false, "reason": "inventory_add_failed", "item_id": node.output_item_id, "quantity": amount}

	deplete_node(node)
	print("[GatheringSystem] Gathered from %s -> %s x%d" % [node.display_name, node.output_item_id, amount])
	return {"ok": true, "item_id": node.output_item_id, "quantity": amount}


func deplete_node(node: GatheringNode) -> void:
	node.is_depleted = true
	print("[GatheringSystem] Node depleted: %s (respawn %ds)" % [node.node_id, node.respawn_seconds])


func reset_node(node: GatheringNode) -> void:
	node.is_depleted = false
	print("[GatheringSystem] Node reset: %s" % node.node_id)
