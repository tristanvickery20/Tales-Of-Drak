extends CanvasLayer
class_name DebugHud

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var inventory_label: Label = $MarginContainer/VBoxContainer/InventoryLabel
@onready var prompt_label: Label = $MarginContainer/VBoxContainer/PromptLabel
@onready var result_label: Label = $MarginContainer/VBoxContainer/ResultLabel


func set_character_summary(display_name: String, class_id: String) -> void:
	title_label.text = "Character: %s (%s)" % [display_name, class_id]


func set_inventory_summary(lines: PackedStringArray) -> void:
	if lines.is_empty():
		inventory_label.text = "Inventory: (empty)"
		return
	inventory_label.text = "Inventory:\n- " + "\n- ".join(lines)


func set_prompt(text: String) -> void:
	prompt_label.text = "Prompt: %s" % text


func set_last_result(text: String) -> void:
	result_label.text = "Last: %s" % text
