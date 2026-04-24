extends RefCounted
class_name BuildPiece

## BuildPiece v0.1
##
## Runtime placed-piece model for Stage 7 housing framework.

var build_piece_instance_id: String = ""
var build_piece_id: String = ""
var display_name: String = ""
var category: String = ""
var placement_type: String = ""
var required_item_counts: Dictionary = {}
var max_health: int = 100
var is_placeable: bool = true
var position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var rotation: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}


func load_from_record(instance_id: String, record: Dictionary, at_position: Dictionary, at_rotation: Dictionary) -> void:
	build_piece_instance_id = instance_id
	build_piece_id = str(record.get("id", ""))
	display_name = str(record.get("display_name", build_piece_id))
	category = str(record.get("category", ""))
	placement_type = str(record.get("placement_type", ""))
	required_item_counts = record.get("required_item_counts", {}).duplicate(true)
	max_health = int(record.get("max_health", 100))
	is_placeable = true
	position = at_position.duplicate(true)
	rotation = at_rotation.duplicate(true)


func to_summary_dict() -> Dictionary:
	return {
		"build_piece_instance_id": build_piece_instance_id,
		"build_piece_id": build_piece_id,
		"display_name": display_name,
		"category": category,
		"placement_type": placement_type,
		"required_item_counts": required_item_counts.duplicate(true),
		"max_health": max_health,
		"is_placeable": is_placeable,
		"position": position.duplicate(true),
		"rotation": rotation.duplicate(true)
	}
