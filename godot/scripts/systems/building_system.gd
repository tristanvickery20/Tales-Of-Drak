extends RefCounted
class_name BuildingSystem

## BuildingSystem v0.1
##
## Local-first abstract placement system. No 3D snapping/physics/networking yet.

var _registry: DataRegistry = null
var _placed_pieces: Dictionary = {}
var _instance_counter: int = 0


func initialize(registry: DataRegistry) -> void:
	_registry = registry
	_placed_pieces.clear()
	_instance_counter = 0


func can_place(build_piece_id: String, inventory: Inventory) -> bool:
	if _registry == null:
		push_error("[BuildingSystem] DataRegistry is null.")
		return false
	if inventory == null:
		push_error("[BuildingSystem] Inventory is null.")
		return false
	if not _registry.has_record("build_piece", build_piece_id):
		push_error("[BuildingSystem] Unknown build_piece_id: %s" % build_piece_id)
		return false

	var cost := get_piece_cost(build_piece_id)
	for item_id in cost.keys():
		if not inventory.has_item(item_id, int(cost[item_id])):
			return false
	return true


func place_piece(build_piece_id: String, inventory: Inventory, position: Dictionary, rotation: Dictionary) -> Dictionary:
	if not _registry.has_record("build_piece", build_piece_id):
		return {"ok": false, "reason": "unknown_build_piece"}

	var cost := get_piece_cost(build_piece_id)
	var missing := _get_missing_requirements(cost, inventory)
	if not missing.is_empty():
		return {"ok": false, "reason": "missing_requirements", "missing": missing}

	for item_id in cost.keys():
		if not inventory.remove_item(item_id, int(cost[item_id])):
			return {"ok": false, "reason": "inventory_remove_failed", "item_id": item_id}

	var record := _registry.get_record("build_piece", build_piece_id)
	var instance_id := _next_instance_id(build_piece_id)
	var piece := BuildPiece.new()
	piece.load_from_record(instance_id, record, position, rotation)
	_placed_pieces[instance_id] = piece

	print("[BuildingSystem] Placed %s as %s" % [build_piece_id, instance_id])
	return {"ok": true, "build_piece_instance_id": instance_id, "build_piece_id": build_piece_id}


func remove_piece(build_piece_instance_id: String, inventory: Inventory = null) -> Dictionary:
	if not _placed_pieces.has(build_piece_instance_id):
		return {"ok": false, "reason": "not_found"}

	var piece: BuildPiece = _placed_pieces[build_piece_instance_id]
	_placed_pieces.erase(build_piece_instance_id)

	# Placeholder refund rule: return 50% rounded down.
	var refunded := {}
	if inventory != null:
		for item_id in piece.required_item_counts.keys():
			var refund_qty := int(floor(int(piece.required_item_counts[item_id]) * 0.5))
			if refund_qty > 0:
				inventory.add_item(item_id, refund_qty)
				refunded[item_id] = refund_qty

	print("[BuildingSystem] Removed piece %s" % build_piece_instance_id)
	return {"ok": true, "removed_id": build_piece_instance_id, "refund": refunded}


func get_placed_pieces() -> Array:
	var out: Array = []
	for piece in _placed_pieces.values():
		out.append(piece.to_summary_dict())
	return out


func get_piece_cost(build_piece_id: String) -> Dictionary:
	if _registry == null:
		return {}
	var record := _registry.get_record("build_piece", build_piece_id)
	if record.is_empty():
		return {}
	return record.get("required_item_counts", {}).duplicate(true)


func _get_missing_requirements(cost: Dictionary, inventory: Inventory) -> Dictionary:
	var missing := {}
	for item_id in cost.keys():
		var required_qty := int(cost[item_id])
		var have_qty := inventory.get_item_count(item_id)
		if have_qty < required_qty:
			missing[item_id] = required_qty - have_qty
	return missing


func _next_instance_id(build_piece_id: String) -> String:
	_instance_counter += 1
	return "%s_%04d" % [build_piece_id, _instance_counter]
