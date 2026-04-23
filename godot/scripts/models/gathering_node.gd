extends RefCounted
class_name GatheringNode

## GatheringNode v0.1
##
## Runtime node state used by GatheringSystem.

var node_id: String = ""
var gathering_node_id: String = ""
var display_name: String = ""
var required_tool_item_id: String = ""
var output_item_id: String = ""
var output_quantity_min: int = 1
var output_quantity_max: int = 1
var respawn_seconds: int = 60
var is_depleted: bool = false


func load_from_record(instance_node_id: String, gathering_record: Dictionary) -> void:
	node_id = instance_node_id
	gathering_node_id = str(gathering_record.get("id", ""))
	display_name = str(gathering_record.get("display_name", gathering_node_id))
	required_tool_item_id = str(gathering_record.get("required_tool_item_id", ""))
	output_item_id = str(gathering_record.get("output_item_id", ""))
	output_quantity_min = int(gathering_record.get("output_quantity_min", 1))
	output_quantity_max = int(gathering_record.get("output_quantity_max", output_quantity_min))
	respawn_seconds = int(gathering_record.get("respawn_seconds", 60))
	is_depleted = false
