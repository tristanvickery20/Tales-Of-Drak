extends CanvasLayer
class_name DebugHud

## RPG HUD foundation.
##
## Phase 1 HUD:
## - player HP bar
## - BG3/ARK-inspired inventory shell
## - Backpack item inspector with USE/EQUIP
## - ARK-style crafting icon grid with CRAFT
## - Character tab shows equipment/progression lines

signal craft_recipe_requested(recipe: Dictionary)
signal use_item_requested(item_id: String)
signal equip_item_requested(item_id: String)

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
var _primary_action_button: Button
var _secondary_action_button: Button
var _center_panel_label: Label
var _right_grid: GridContainer
var _right_detail_label: Label
var _active_inventory_tab: String = "backpack"
var _selected_recipe_index: int = 0
var _selected_backpack_index: int = 0
var _player_hp_current: int = 50
var _player_hp_max: int = 50
var _backpack_lines: PackedStringArray = []
var _crafting_lines: PackedStringArray = []
var _character_lines: PackedStringArray = []
var _character_summary_text: String = "Character"
var _inventory_counts: Dictionary = {}
var _crafting_recipes: Array = []


func _ready() -> void:
	root_margin.offset_top = 58.0
	root_margin.offset_right = -100.0
	for label in [title_label, inventory_label, prompt_label, result_label]:
		label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_seed_default_recipes()
	_build_player_health_bar()
	_build_inventory_button()
	_build_inventory_panel()
	set_player_health(_player_hp_current, _player_hp_max)
	_update_inventory_view()


func _seed_default_recipes() -> void:
	_crafting_recipes = [
		{"id":"craft_torch_kit","icon":"🔥","name":"Torch Kit","category":"Survival / Primitive","description":"A basic torch kit for light in dark places.","stats":PackedStringArray(["Utility: Light source","Stack: prototype"]),"requirements":{"weathered_timber":1},"output_item_id":"torch_kit","output_quantity":2},
		{"id":"timber_foundation","icon":"▧","name":"Timber Foundation","category":"Building / Primitive","description":"A rough timber floor piece for early shelter building.","stats":PackedStringArray(["Structure","Placement: ground snap"]),"requirements":{"weathered_timber":8},"output_item_id":"timber_foundation","output_quantity":1},
		{"id":"starter_bandage","icon":"+","name":"Simple Bandage","category":"Consumable / Primitive","description":"A crude bandage that restores a little HP.","stats":PackedStringArray(["Use: restores HP","Consumable"]),"requirements":{"weathered_timber":2},"output_item_id":"starter_bandage","output_quantity":1},
		{"id":"camp_marker","icon":"⌂","name":"Camp Marker","category":"Utility / Primitive","description":"A placeholder camp object for future rest and housing systems.","stats":PackedStringArray(["Utility","Prototype only"]),"requirements":{"weathered_timber":5,"torch_kit":1},"output_item_id":"camp_marker","output_quantity":1},
	]


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
	_hp_fill.color = Color(0.85, 0.02, 0.02, 0.96)
	_hp_fill.position = Vector2(HP_FILL_MARGIN, HP_FILL_MARGIN)
	_hp_fill.size = Vector2(HP_BAR_SIZE.x - HP_FILL_MARGIN * 2.0, HP_BAR_SIZE.y - HP_FILL_MARGIN * 2.0)
	back.add_child(_hp_fill)

	_hp_text = Label.new()
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 17)
	_hp_text.anchor_right = 1.0
	_hp_text.anchor_bottom = 1.0
	back.add_child(_hp_text)


func _build_inventory_button() -> void:
	_inventory_button = Button.new()
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
	_inventory_overlay.visible = false
	_inventory_overlay.color = Color(0.0, 0.0, 0.0, 0.32)
	_inventory_overlay.anchor_right = 1.0
	_inventory_overlay.anchor_bottom = 1.0
	_inventory_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inventory_overlay)

	_inventory_panel = PanelContainer.new()
	_inventory_panel.visible = false
	_inventory_panel.anchor_left = 0.04
	_inventory_panel.anchor_top = 0.08
	_inventory_panel.anchor_right = 0.96
	_inventory_panel.anchor_bottom = 0.88
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
	left_panel.custom_minimum_size = Vector2(230, 260)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.055, 0.045, 0.74), Color(0.42, 0.28, 0.16, 0.95), 8))
	columns.add_child(left_panel)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	_left_panel_label = _make_text_block()
	_primary_action_button = Button.new()
	_primary_action_button.custom_minimum_size = Vector2(170, 36)
	_primary_action_button.add_theme_font_size_override("font_size", 15)
	_primary_action_button.pressed.connect(_on_primary_action_pressed)
	_secondary_action_button = Button.new()
	_secondary_action_button.custom_minimum_size = Vector2(170, 34)
	_secondary_action_button.add_theme_font_size_override("font_size", 14)
	_secondary_action_button.pressed.connect(_on_secondary_action_pressed)
	left_box.add_child(_left_panel_label)
	left_box.add_child(_primary_action_button)
	left_box.add_child(_secondary_action_button)
	left_panel.add_child(_wrap_margin(left_box))

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
	_parse_inventory_counts()
	inventory_label.text = "Backpack: empty" if lines.is_empty() else "Backpack: %d item type(s)" % lines.size()
	_update_inventory_view()


func set_inventory_tabs(backpack_lines: PackedStringArray, crafting_lines: PackedStringArray, character_lines: PackedStringArray) -> void:
	_backpack_lines = backpack_lines
	_crafting_lines = crafting_lines
	_character_lines = character_lines
	_selected_backpack_index = clamp(_selected_backpack_index, 0, max(0, _backpack_lines.size() - 1))
	_parse_inventory_counts()
	inventory_label.text = "Backpack: empty" if backpack_lines.is_empty() else "Backpack: %d item type(s)" % backpack_lines.size()
	_update_inventory_view()


func set_crafting_recipes(recipes: Array) -> void:
	_crafting_recipes = recipes
	_selected_recipe_index = clamp(_selected_recipe_index, 0, max(0, _crafting_recipes.size() - 1))
	_update_inventory_view()


func set_character_view(lines: PackedStringArray) -> void:
	_character_lines = lines
	_update_inventory_view()


func _parse_inventory_counts() -> void:
	_inventory_counts.clear()
	for line in _backpack_lines:
		var parsed := _parse_backpack_line(line)
		if not str(parsed.get("item_id", "")).is_empty():
			_inventory_counts[str(parsed["item_id"])] = int(parsed.get("quantity", 0))


func _parse_backpack_line(line: String) -> Dictionary:
	var clean := String(line).strip_edges()
	var parts := clean.split(" x")
	if parts.size() >= 2:
		return {"item_id": String(parts[0]).strip_edges(), "quantity": int(String(parts[1]).strip_edges())}
	return {"item_id": clean, "quantity": 1}


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
	_update_action_buttons()


func _update_action_buttons() -> void:
	if _primary_action_button == null or _secondary_action_button == null:
		return
	_primary_action_button.visible = false
	_secondary_action_button.visible = false
	if _active_inventory_tab == "crafting" and not _crafting_recipes.is_empty():
		var recipe: Dictionary = _crafting_recipes[clamp(_selected_recipe_index, 0, _crafting_recipes.size() - 1)]
		var craftable := _recipe_is_craftable(recipe)
		_primary_action_button.visible = true
		_primary_action_button.disabled = not craftable
		_primary_action_button.text = "CRAFT" if craftable else "MISSING MATERIALS"
		_primary_action_button.modulate = Color(0.45, 1.0, 0.45, 1.0) if craftable else Color(1.0, 0.38, 0.32, 0.75)
	elif _active_inventory_tab == "backpack" and not _backpack_lines.is_empty():
		var item_id := _selected_item_id()
		var def := GameState.get_item_definition(item_id)
		_primary_action_button.visible = bool(def.get("usable", false))
		_primary_action_button.disabled = not bool(def.get("usable", false))
		_primary_action_button.text = "USE"
		_primary_action_button.modulate = Color(0.65, 0.9, 1.0, 1.0)
		_secondary_action_button.visible = bool(def.get("equippable", false))
		_secondary_action_button.disabled = not bool(def.get("equippable", false))
		_secondary_action_button.text = "EQUIP"
		_secondary_action_button.modulate = Color(0.9, 0.78, 1.0, 1.0)


func _on_primary_action_pressed() -> void:
	if _active_inventory_tab == "crafting":
		if _crafting_recipes.is_empty():
			return
		var recipe: Dictionary = _crafting_recipes[clamp(_selected_recipe_index, 0, _crafting_recipes.size() - 1)]
		if _recipe_is_craftable(recipe):
			craft_recipe_requested.emit(recipe)
	elif _active_inventory_tab == "backpack":
		var item_id := _selected_item_id()
		if not item_id.is_empty():
			use_item_requested.emit(item_id)


func _on_secondary_action_pressed() -> void:
	if _active_inventory_tab == "backpack":
		var item_id := _selected_item_id()
		if not item_id.is_empty():
			equip_item_requested.emit(item_id)


func _build_left_panel_text() -> String:
	if _active_inventory_tab == "crafting":
		return _build_selected_recipe_details()
	if _active_inventory_tab == "backpack":
		return _build_selected_item_details()
	return "\n".join(_character_lines)


func _build_center_panel_text() -> String:
	if _active_inventory_tab == "crafting":
		return "CRAFTING\n\nSelect a recipe icon.\n\nDesktop: hover or click.\niPhone: tap an icon.\n\nCRAFT consumes materials and adds output to backpack."
	if _active_inventory_tab == "backpack":
		return "BACKPACK\n\nTap an item to inspect it.\n\nUsable items show USE.\nEquippable items show EQUIP.\n\nQuantities update live."
	return "CHARACTER\n\n[ Head ]\n\n[ Chest ]     [ Hands ]\n\n[ Main Hand ]   [ Off Hand ]\n\n[ Legs ]\n\n[ Boots ]\n\nEquipment lines update from GameState."


func _rebuild_grid() -> void:
	for child in _right_grid.get_children():
		child.queue_free()
	if _active_inventory_tab == "crafting":
		_rebuild_crafting_grid()
		return
	if _active_inventory_tab == "backpack":
		_rebuild_backpack_grid()
		return
	_rebuild_character_grid()


func _rebuild_backpack_grid() -> void:
	for i in range(40):
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.add_theme_font_size_override("font_size", 17)
		if i < _backpack_lines.size():
			var parsed := _parse_backpack_line(_backpack_lines[i])
			var item_id := str(parsed.get("item_id", ""))
			var qty := int(parsed.get("quantity", 0))
			slot.text = "%s\n%d" % [GameState.get_item_icon(item_id), qty]
			slot.tooltip_text = GameState.get_item_name(item_id)
			slot.pressed.connect(_select_backpack_item.bind(i))
			slot.mouse_entered.connect(_select_backpack_item.bind(i))
			slot.add_theme_stylebox_override("normal", _slot_style(i == _selected_backpack_index, Color(0.06, 0.08, 0.08, 0.82)))
		else:
			slot.text = ""
			slot.disabled = true
			slot.add_theme_stylebox_override("normal", _make_panel_style(Color(0.025, 0.025, 0.028, 0.38), Color(0.14, 0.14, 0.16, 0.45), 3))
		_right_grid.add_child(slot)


func _rebuild_character_grid() -> void:
	for i in range(40):
		var slot := Label.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 10)
		slot.add_theme_stylebox_override("normal", _make_panel_style(Color(0.08, 0.07, 0.055, 0.78), Color(0.28, 0.22, 0.14, 0.95), 3))
		if i < _character_lines.size():
			slot.text = _slot_text(_character_lines[i])
		_right_grid.add_child(slot)


func _rebuild_crafting_grid() -> void:
	for i in range(40):
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.add_theme_font_size_override("font_size", 20)
		if i < _crafting_recipes.size():
			var recipe: Dictionary = _crafting_recipes[i]
			slot.text = str(recipe.get("icon", "?"))
			slot.tooltip_text = str(recipe.get("name", "Recipe"))
			slot.pressed.connect(_select_crafting_recipe.bind(i))
			slot.mouse_entered.connect(_select_crafting_recipe.bind(i))
			slot.add_theme_stylebox_override("normal", _recipe_slot_style(i, false))
			if not _recipe_is_craftable(recipe):
				slot.modulate = Color(0.72, 0.72, 0.72, 0.9)
		else:
			slot.text = ""
			slot.disabled = true
			slot.add_theme_stylebox_override("normal", _make_panel_style(Color(0.025, 0.025, 0.028, 0.38), Color(0.14, 0.14, 0.16, 0.45), 3))
		_right_grid.add_child(slot)


func _slot_style(selected: bool, bg: Color) -> StyleBoxFlat:
	return _make_panel_style(bg, Color(0.95, 0.82, 0.3, 1.0) if selected else Color(0.28, 0.22, 0.14, 0.95), 3)


func _recipe_slot_style(index: int, _is_hover: bool) -> StyleBoxFlat:
	if index >= _crafting_recipes.size():
		return _make_panel_style(Color(0.025, 0.025, 0.028, 0.38), Color(0.14, 0.14, 0.16, 0.45), 3)
	var recipe: Dictionary = _crafting_recipes[index]
	var border := Color(0.15, 0.95, 0.55, 0.95) if _recipe_is_craftable(recipe) else Color(0.75, 0.18, 0.14, 0.95)
	if index == _selected_recipe_index:
		border = Color(0.95, 0.82, 0.3, 1.0)
	return _make_panel_style(Color(0.04, 0.09, 0.11, 0.82), border, 3)


func _select_crafting_recipe(index: int) -> void:
	if index < 0 or index >= _crafting_recipes.size():
		return
	_selected_recipe_index = index
	_update_inventory_view()


func _select_backpack_item(index: int) -> void:
	if index < 0 or index >= _backpack_lines.size():
		return
	_selected_backpack_index = index
	_update_inventory_view()


func _selected_item_id() -> String:
	if _backpack_lines.is_empty():
		return ""
	var parsed := _parse_backpack_line(_backpack_lines[clamp(_selected_backpack_index, 0, _backpack_lines.size() - 1)])
	return str(parsed.get("item_id", ""))


func _recipe_is_craftable(recipe: Dictionary) -> bool:
	var reqs: Dictionary = recipe.get("requirements", {})
	for item_id in reqs.keys():
		if int(_inventory_counts.get(item_id, 0)) < int(reqs[item_id]):
			return false
	return true


func _build_selected_recipe_details() -> String:
	if _crafting_recipes.is_empty():
		return "ENGRAM: NONE\n\nNo known recipes."
	_selected_recipe_index = clamp(_selected_recipe_index, 0, _crafting_recipes.size() - 1)
	var recipe: Dictionary = _crafting_recipes[_selected_recipe_index]
	var lines := PackedStringArray()
	lines.append("ENGRAM: %s / %s" % [str(recipe.get("name", "Recipe")).to_upper(), str(recipe.get("category", "Primitive"))])
	lines.append("")
	lines.append(str(recipe.get("description", "No description.")))
	lines.append("")
	for stat in recipe.get("stats", PackedStringArray()):
		lines.append(str(stat))
	lines.append("")
	lines.append("Creates: %s x%d" % [GameState.get_item_name(str(recipe.get("output_item_id", recipe.get("id", "item")))), int(recipe.get("output_quantity", 1))])
	lines.append("")
	lines.append("Crafting Requirements")
	var reqs: Dictionary = recipe.get("requirements", {})
	for item_id in reqs.keys():
		var owned := int(_inventory_counts.get(item_id, 0))
		var required := int(reqs[item_id])
		var marker := "✓" if owned >= required else "✗"
		lines.append("%s %s: %d / %d" % [marker, GameState.get_item_name(str(item_id)), owned, required])
	lines.append("")
	lines.append("Status: %s" % ("CRAFTABLE" if _recipe_is_craftable(recipe) else "MISSING MATERIALS"))
	return "\n".join(lines)


func _build_selected_item_details() -> String:
	if _backpack_lines.is_empty():
		return "BACKPACK\n\nNo items."
	var item_id := _selected_item_id()
	var def := GameState.get_item_definition(item_id)
	var lines := PackedStringArray()
	lines.append("ITEM: %s" % str(def.get("name", item_id)).to_upper())
	lines.append("Type: %s" % str(def.get("type", "unknown")))
	lines.append("Qty: %d" % int(_inventory_counts.get(item_id, 0)))
	lines.append("")
	lines.append(str(def.get("description", "No description.")))
	lines.append("")
	if int(def.get("damage_bonus", 0)) != 0:
		lines.append("Damage Bonus: +%d" % int(def.get("damage_bonus", 0)))
	if int(def.get("heal_amount", 0)) > 0:
		lines.append("Heals: %d HP" % int(def.get("heal_amount", 0)))
	if bool(def.get("equippable", false)):
		lines.append("Equips to: %s" % str(def.get("slot", "slot")))
	return "\n".join(lines)


func _slot_text(line: String) -> String:
	var clean := line.replace("weathered_", "").replace("starter_", "")
	return clean if clean.length() <= 10 else clean.substr(0, 9)


func _build_right_detail_text() -> String:
	match _active_inventory_tab:
		"crafting": return "Crafting: select an icon, check materials, then press CRAFT."
		"character": return "Character View: armor, weapons, stats, XP, and equipment slots."
	return "Backpack: select an item, then USE or EQUIP if available."


func set_prompt(text: String) -> void:
	prompt_label.text = "Prompt: %s" % text


func set_last_result(text: String) -> void:
	result_label.text = "Last: %s" % text
