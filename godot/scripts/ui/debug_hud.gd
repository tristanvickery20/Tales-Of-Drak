extends CanvasLayer
class_name DebugHud

## RPG HUD foundation.
##
## Adds:
## - top-left red player HP bar with centered HP number
## - compact prompt/result readout
## - BG3-inspired translucent full-screen inventory shell
## - inventory tabs: Backpack / Crafting / Character
##
## No external art assets yet. This is layout + readable RPG structure.

const HUD_FONT_SIZE: int = 16
const HP_BAR_SIZE: Vector2 = Vector2(230, 34)
const HP_FILL_MARGIN: float = 4.0
const SLOT_SIZE: Vector2 = Vector2(42, 42)
const GRID_COLUMNS: int = 8

@onready var root_margin: MarginContainer = $MarginContainer
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var inventory_label: Label = $MarginContainer/VBoxContainer/InventoryLabel
@onready var prompt_label: Label = $MarginContainer/VBoxContainer/PromptLabel
@onready var result_label: Label = $MarginContainer/VBoxContainer/ResultLabel

var _hp_fill: ColorRect
var _hp_text: Label
var _inventory_button: Button
var _inventory_overlay: ColorRect
var _inventory_panel: PanelContainer
var _tab_backpack: Button
var _tab_crafting: Button
var _tab_character: Button
var _left_panel_label: Label
var _center_panel_label: Label
var _right_grid: GridContainer
var _right_detail_label: Label
var _active_inventory_tab: String = "backpack"
var _player_hp_current: int = 50
var _player_hp_max: int = 50
var _backpack_lines: PackedStringArray = []
var _crafting_lines: PackedStringArray = []
var _character_lines: PackedStringArray = []
var _character_summary_text: String = "Character"


func _ready() -> void:
	root_margin.offset_top = 58.0
	root_margin.offset_right = -100.0
	for label in [title_label, inventory_label, prompt_label, result_label]:
		label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_player_health_bar()
	_build_inventory_button()
	_build_inventory_panel()
	set_player_health(_player_hp_current, _player_hp_max)
	_update_inventory_view()


func _make_panel_style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func _build_player_health_bar() -> void:
	var frame := PanelContainer.new()
	frame.name = "PlayerHealthBar"
	frame.anchor_left = 0.0
	frame.anchor_top = 0.0
	frame.anchor_right = 0.0
	frame.anchor_bottom = 0.0
	frame.offset_left = 12.0
	frame.offset_top = 12.0
	frame.offset_right = 12.0 + HP_BAR_SIZE.x
	frame.offset_bottom = 12.0 + HP_BAR_SIZE.y
	frame.custom_minimum_size = HP_BAR_SIZE
	frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.01, 0.01, 0.95), Color(0.6, 0.18, 0.12, 1), 6))
	add_child(frame)

	var back := Control.new()
	back.custom_minimum_size = HP_BAR_SIZE
	frame.add_child(back)

	_hp_fill = ColorRect.new()
	_hp_fill.name = "HealthFill"
	_hp_fill.color = Color(0.85, 0.02, 0.02, 0.96)
	_hp_fill.position = Vector2(HP_FILL_MARGIN, HP_FILL_MARGIN)
	_hp_fill.size = Vector2(HP_BAR_SIZE.x - HP_FILL_MARGIN * 2.0, HP_BAR_SIZE.y - HP_FILL_MARGIN * 2.0)
	back.add_child(_hp_fill)

	_hp_text = Label.new()
	_hp_text.name = "HealthText"
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 17)
	_hp_text.anchor_right = 1.0
	_hp_text.anchor_bottom = 1.0
	_hp_text.offset_left = 0.0
	_hp_text.offset_top = 0.0
	_hp_text.offset_right = 0.0
	_hp_text.offset_bottom = 0.0
	back.add_child(_hp_text)


func _build_inventory_button() -> void:
	_inventory_button = Button.new()
	_inventory_button.name = "InventoryButton"
	_inventory_button.text = "INV"
	_inventory_button.custom_minimum_size = Vector2(78, 38)
	_inventory_button.anchor_left = 1.0
	_inventory_button.anchor_top = 0.0
	_inventory_button.anchor_right = 1.0
	_inventory_button.anchor_bottom = 0.0
	_inventory_button.offset_left = -94.0
	_inventory_button.offset_top = 12.0
	_inventory_button.offset_right = -12.0
	_inventory_button.offset_bottom = 50.0
	_inventory_button.add_theme_font_size_override("font_size", 16)
	_inventory_button.pressed.connect(_toggle_inventory_panel)
	add_child(_inventory_button)


func _build_inventory_panel() -> void:
	_inventory_overlay = ColorRect.new()
	_inventory_overlay.name = "InventoryOverlay"
	_inventory_overlay.visible = false
	_inventory_overlay.color = Color(0.0, 0.0, 0.0, 0.32)
	_inventory_overlay.anchor_right = 1.0
	_inventory_overlay.anchor_bottom = 1.0
	_inventory_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inventory_overlay)

	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.visible = false
	_inventory_panel.anchor_left = 0.04
	_inventory_panel.anchor_top = 0.08
	_inventory_panel.anchor_right = 0.96
	_inventory_panel.anchor_bottom = 0.88
	_inventory_panel.offset_left = 0.0
	_inventory_panel.offset_top = 0.0
	_inventory_panel.offset_right = 0.0
	_inventory_panel.offset_bottom = 0.0
	_inventory_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.018, 0.014, 0.84), Color(0.74, 0.55, 0.32, 0.95), 10))
	add_child(_inventory_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_inventory_panel.add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)
	margin.add_child(main)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 6)
	main.add_child(top_bar)

	var title := Label.new()
	title.text = "Inventory / Character"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	_tab_character = _make_tab_button("Character", "character")
	_tab_backpack = _make_tab_button("Backpack", "backpack")
	_tab_crafting = _make_tab_button("Crafting", "crafting")
	top_bar.add_child(_tab_character)
	top_bar.add_child(_tab_backpack)
	top_bar.add_child(_tab_crafting)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(38, 32)
	close_button.pressed.connect(_toggle_inventory_panel)
	top_bar.add_child(close_button)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(columns)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(210, 260)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.055, 0.045, 0.74), Color(0.42, 0.28, 0.16, 0.95), 8))
	columns.add_child(left_panel)
	_left_panel_label = _make_text_block()
	left_panel.add_child(_wrap_margin(_left_panel_label))

	var center_panel := PanelContainer.new()
	center_panel.custom_minimum_size = Vector2(230, 260)
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.028, 0.022, 0.62), Color(0.5, 0.38, 0.22, 0.95), 8))
	columns.add_child(center_panel)
	_center_panel_label = _make_text_block()
	_center_panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_panel.add_child(_wrap_margin(_center_panel_label))

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(360, 260)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.045, 0.035, 0.74), Color(0.42, 0.28, 0.16, 0.95), 8))
	columns.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 8)
	right_margin.add_theme_constant_override("margin_top", 8)
	right_margin.add_theme_constant_override("margin_right", 8)
	right_margin.add_theme_constant_override("margin_bottom", 8)
	right_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_margin.add_child(right_vbox)

	var search := Label.new()
	search.text = "Showing All"
	search.add_theme_font_size_override("font_size", 15)
	right_vbox.add_child(search)

	_right_grid = GridContainer.new()
	_right_grid.columns = GRID_COLUMNS
	_right_grid.add_theme_constant_override("h_separation", 4)
	_right_grid.add_theme_constant_override("v_separation", 4)
	right_vbox.add_child(_right_grid)

	_right_detail_label = Label.new()
	_right_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right_detail_label.add_theme_font_size_override("font_size", 14)
	right_vbox.add_child(_right_detail_label)


func _make_tab_button(label: String, tab_id: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(92, 32)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(func() -> void:
		_active_inventory_tab = tab_id
		_update_inventory_view()
	)
	return button


func _make_text_block() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	return label


func _wrap_margin(child: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(child)
	return margin


func _toggle_inventory_panel() -> void:
	var next_visible := not _inventory_panel.visible
	_inventory_panel.visible = next_visible
	_inventory_overlay.visible = next_visible
	_update_inventory_view()


func set_player_health(current_hp: int, max_hp: int) -> void:
	_player_hp_current = max(0, current_hp)
	_player_hp_max = max(1, max_hp)
	var ratio := clamp(float(_player_hp_current) / float(_player_hp_max), 0.0, 1.0)
	if _hp_fill != null:
		_hp_fill.size.x = (HP_BAR_SIZE.x - HP_FILL_MARGIN * 2.0) * ratio
	if _hp_text != null:
		_hp_text.text = "%d / %d" % [_player_hp_current, _player_hp_max]


func set_character_summary(display_name: String, class_id: String) -> void:
	_character_summary_text = "%s (%s)" % [display_name, class_id]
	title_label.text = _character_summary_text
	if _character_lines.is_empty():
		_character_lines = PackedStringArray([_character_summary_text])
	_update_inventory_view()


func set_inventory_summary(lines: PackedStringArray) -> void:
	_backpack_lines = lines
	inventory_label.text = "Backpack: empty" if lines.is_empty() else "Backpack: %d item type(s)" % lines.size()
	_update_inventory_view()


func set_inventory_tabs(backpack_lines: PackedStringArray, crafting_lines: PackedStringArray, character_lines: PackedStringArray) -> void:
	_backpack_lines = backpack_lines
	_crafting_lines = crafting_lines
	_character_lines = character_lines
	inventory_label.text = "Backpack: empty" if backpack_lines.is_empty() else "Backpack: %d item type(s)" % backpack_lines.size()
	_update_inventory_view()


func set_crafting_summary(lines: PackedStringArray) -> void:
	_crafting_lines = lines
	_update_inventory_view()


func set_character_view(lines: PackedStringArray) -> void:
	_character_lines = lines
	_update_inventory_view()


func _update_inventory_view() -> void:
	if _left_panel_label == null or _center_panel_label == null or _right_grid == null:
		return

	_tab_character.modulate = Color(1.0, 0.82, 0.45, 1.0) if _active_inventory_tab == "character" else Color(1, 1, 1, 0.82)
	_tab_backpack.modulate = Color(1.0, 0.82, 0.45, 1.0) if _active_inventory_tab == "backpack" else Color(1, 1, 1, 0.82)
	_tab_crafting.modulate = Color(1.0, 0.82, 0.45, 1.0) if _active_inventory_tab == "crafting" else Color(1, 1, 1, 0.82)

	_left_panel_label.text = _build_left_panel_text()
	_center_panel_label.text = _build_center_panel_text()
	_rebuild_grid()
	_right_detail_label.text = _build_right_detail_text()


func _build_left_panel_text() -> String:
	var lines := PackedStringArray()
	lines.append(_character_summary_text)
	lines.append("")
	lines.append("STR 10   DEX 10   CON 10")
	lines.append("INT 10   WIS 10   CHA 10")
	lines.append("")
	lines.append("Conditions")
	lines.append("- Normal")
	lines.append("")
	lines.append("Resistances")
	lines.append("- None")
	lines.append("")
	lines.append("Notable Features")
	for entry in _character_lines:
		lines.append("- %s" % entry)
	return "\n".join(lines)


func _build_center_panel_text() -> String:
	return "CHARACTER\n\n[ Head ]\n\n[ Chest ]     [ Hands ]\n\n[ Main Hand ]   [ Off Hand ]\n\n[ Legs ]\n\n[ Boots ]\n\nAC 10\nAttack Bonus +0\nDamage prototype"


func _rebuild_grid() -> void:
	for child in _right_grid.get_children():
		child.queue_free()

	var source := _backpack_lines
	if _active_inventory_tab == "crafting":
		source = _crafting_lines
	elif _active_inventory_tab == "character":
		source = _character_lines

	var max_slots := 40
	for i in range(max_slots):
		var slot := Label.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 10)
		slot.add_theme_stylebox_override("normal", _make_panel_style(Color(0.08, 0.07, 0.055, 0.78), Color(0.28, 0.22, 0.14, 0.95), 3))
		if i < source.size():
			slot.text = _slot_text(source[i])
		else:
			slot.text = ""
		_right_grid.add_child(slot)


func _slot_text(line: String) -> String:
	var clean := line.replace("weathered_", "").replace("starter_", "").replace("placeholder", "loot")
	if clean.length() <= 10:
		return clean
	return clean.substr(0, 9)


func _build_right_detail_text() -> String:
	match _active_inventory_tab:
		"crafting":
			return "Crafting Menu: prototype recipes and future crafting actions."
		"character":
			return "Character View: armor, weapons, stats, and equipment slots."
	return "Backpack: items carried and on-person inventory."


func set_prompt(text: String) -> void:
	prompt_label.text = "Prompt: %s" % text


func set_last_result(text: String) -> void:
	result_label.text = "Last: %s" % text
