extends CanvasLayer
class_name DebugHud

signal craft_recipe_requested(recipe)
signal use_item_requested(item_id)
signal equip_item_requested(item_id)

const SLOT_SIZE = Vector2(44, 44)
const GRID_COLUMNS = 8

@onready var root_margin = $MarginContainer
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var inventory_label = $MarginContainer/VBoxContainer/InventoryLabel
@onready var prompt_label = $MarginContainer/VBoxContainer/PromptLabel
@onready var result_label = $MarginContainer/VBoxContainer/ResultLabel

var hp_fill
var hp_text
var xp_fill
var xp_text
var inv_button
var dbg_button
var overlay
var panel
var left_label
var center_label
var grid
var detail_label
var primary_button
var secondary_button
var tab_backpack
var tab_crafting
var tab_character

var dbg_overlay
var dbg_panel
var dbg_lines_label

var gs = null
var active_tab = "backpack"
var selected_item_index = 0
var selected_recipe_index = 0
var backpack_lines = PackedStringArray()
var character_lines = PackedStringArray()
var inventory_counts = {}

var item_defs = {
	"starter_hatchet":{"name":"Starter Hatchet","icon":"H","type":"tool / weapon","slot":"main_hand","description":"A rough starter hatchet. Useful for gathering and basic fighting.","damage_dice":"1d4","damage_bonus":1,"usable":false,"equippable":true},
	"weathered_timber":{"name":"Weathered Timber","icon":"W","type":"resource","slot":"","description":"Old timber gathered from the world. Used for primitive crafting.","usable":false,"equippable":false},
	"torch_kit":{"name":"Torch Kit","icon":"T","type":"utility","slot":"","description":"A simple torch kit for light and survival crafting chains.","usable":false,"equippable":false},
	"timber_foundation":{"name":"Timber Foundation","icon":"F","type":"building","slot":"","description":"A primitive building foundation for the future housing/building system.","usable":false,"equippable":false},
	"starter_bandage":{"name":"Simple Bandage","icon":"+","type":"consumable","slot":"","description":"A crude bandage. Restores a small amount of HP.","usable":true,"equippable":false},
	"camp_marker":{"name":"Camp Marker","icon":"C","type":"utility","slot":"","description":"A placeholder camp object for future housing and rest systems.","usable":false,"equippable":false},
	"rusty_sword":{"name":"Rusty Sword","icon":"S","type":"weapon","slot":"main_hand","description":"A battered sword from a dungeon chest. Better than a hatchet in combat.","damage_dice":"1d8","damage_bonus":4,"usable":false,"equippable":true},
	"plain_clothes":{"name":"Plain Clothes","icon":"A","type":"armor","slot":"armor","description":"Basic starter clothing. No real protection yet.","usable":false,"equippable":true},
	"ancient_coin":{"name":"Ancient Coin","icon":"O","type":"currency","slot":"","description":"A small coin from the dungeon. Used later for vendors and markets.","usable":false,"equippable":false}
}

var recipes = [
	{"id":"craft_torch_kit","icon":"T","name":"Torch Kit","category":"Survival / Primitive","description":"A basic torch kit for dark places.","requirements":{"weathered_timber":1},"output_item_id":"torch_kit","output_quantity":2},
	{"id":"timber_foundation","icon":"F","name":"Timber Foundation","category":"Building / Primitive","description":"A rough timber floor piece.","requirements":{"weathered_timber":8},"output_item_id":"timber_foundation","output_quantity":1},
	{"id":"starter_bandage","icon":"+","name":"Simple Bandage","category":"Consumable / Primitive","description":"Restores a small amount of HP.","requirements":{"weathered_timber":2},"output_item_id":"starter_bandage","output_quantity":1},
	{"id":"camp_marker","icon":"C","name":"Camp Marker","category":"Utility / Primitive","description":"Placeholder camp object for future housing/rest.","requirements":{"weathered_timber":5,"torch_kit":1},"output_item_id":"camp_marker","output_quantity":1}
]

func _ready():
	gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_signal("runtime_state_changed"):
		gs.connect("runtime_state_changed", Callable(self, "_refresh_from_gamestate"))
	root_margin.offset_top = 88
	root_margin.offset_right = -105
	_build_bars()
	_build_button()
	_build_dbg_button()
	_build_inventory_panel()
	_build_debug_panel()
	_refresh_from_gamestate()
	_update_view()

func _refresh_from_gamestate():
	if gs == null:
		gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if gs.has_method("ensure_runtime_state"):
		gs.ensure_runtime_state()
	set_player_health(gs.current_hp, gs.max_hp)
	set_progression(gs.level, gs.xp, gs.xp_to_next)
	set_character_summary(gs.character_name, "%s %s" % [gs.species_name, gs.class_name])
	if gs.has_method("get_inventory_lines") and gs.has_method("get_character_view_lines"):
		set_inventory_tabs(gs.get_inventory_lines(), PackedStringArray(), gs.get_character_view_lines())

func _panel_style(bg, border, radius = 8):
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _build_bars():
	var hp_frame = PanelContainer.new()
	hp_frame.anchor_left = 0
	hp_frame.anchor_top = 0
	hp_frame.anchor_right = 0
	hp_frame.anchor_bottom = 0
	hp_frame.offset_left = 12
	hp_frame.offset_top = 10
	hp_frame.offset_right = 242
	hp_frame.offset_bottom = 42
	hp_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.04,0,0,0.95), Color(0.7,0.1,0.08,1), 6))
	add_child(hp_frame)
	var hp_inner = Control.new()
	hp_inner.custom_minimum_size = Vector2(230, 32)
	hp_frame.add_child(hp_inner)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.86,0.02,0.02,0.96)
	hp_fill.position = Vector2(4,4)
	hp_fill.size = Vector2(222,24)
	hp_inner.add_child(hp_fill)
	hp_text = Label.new()
	hp_text.anchor_right = 1
	hp_text.anchor_bottom = 1
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 16)
	hp_inner.add_child(hp_text)

	var xp_frame = PanelContainer.new()
	xp_frame.anchor_left = 0
	xp_frame.anchor_top = 0
	xp_frame.anchor_right = 0
	xp_frame.anchor_bottom = 0
	xp_frame.offset_left = 12
	xp_frame.offset_top = 46
	xp_frame.offset_right = 242
	xp_frame.offset_bottom = 68
	xp_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.01,0.015,0.04,0.95), Color(0.2,0.35,0.8,1), 5))
	add_child(xp_frame)
	var xp_inner = Control.new()
	xp_inner.custom_minimum_size = Vector2(230,22)
	xp_frame.add_child(xp_inner)
	xp_fill = ColorRect.new()
	xp_fill.color = Color(0.08,0.35,1,0.95)
	xp_fill.position = Vector2(3,3)
	xp_fill.size = Vector2(1,16)
	xp_inner.add_child(xp_fill)
	xp_text = Label.new()
	xp_text.anchor_right = 1
	xp_text.anchor_bottom = 1
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_text.add_theme_font_size_override("font_size", 12)
	xp_inner.add_child(xp_text)

func _build_button():
	inv_button = Button.new()
	inv_button.text = "INV"
	inv_button.anchor_left = 1
	inv_button.anchor_right = 1
	inv_button.offset_left = -92
	inv_button.offset_top = 12
	inv_button.offset_right = -12
	inv_button.offset_bottom = 50
	inv_button.pressed.connect(_toggle_inventory)
	add_child(inv_button)

func _build_dbg_button():
	dbg_button = Button.new()
	dbg_button.text = "DBG"
	dbg_button.anchor_left = 1
	dbg_button.anchor_right = 1
	dbg_button.offset_left = -92
	dbg_button.offset_top = 56
	dbg_button.offset_right = -12
	dbg_button.offset_bottom = 94
	dbg_button.pressed.connect(_toggle_debug_panel)
	add_child(dbg_button)

func _build_debug_panel():
	dbg_overlay = ColorRect.new()
	dbg_overlay.visible = false
	dbg_overlay.color = Color(0,0,0,0.32)
	dbg_overlay.anchor_right = 1
	dbg_overlay.anchor_bottom = 1
	dbg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dbg_overlay)

	dbg_panel = PanelContainer.new()
	dbg_panel.visible = false
	dbg_panel.anchor_left = 0.04
	dbg_panel.anchor_top = 0.08
	dbg_panel.anchor_right = 0.96
	dbg_panel.anchor_bottom = 0.92
	dbg_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02,0.015,0.01,0.95), Color(0.74,0.55,0.32,0.96), 10))
	add_child(dbg_panel)

	var dbg_margin = MarginContainer.new()
	dbg_margin.add_theme_constant_override("margin_left", 10)
	dbg_margin.add_theme_constant_override("margin_top", 8)
	dbg_margin.add_theme_constant_override("margin_right", 10)
	dbg_margin.add_theme_constant_override("margin_bottom", 10)
	dbg_panel.add_child(dbg_margin)

	var dbg_vbox = VBoxContainer.new()
	dbg_vbox.add_theme_constant_override("separation", 6)
	dbg_margin.add_child(dbg_vbox)

	var dbg_top = HBoxContainer.new()
	dbg_top.add_theme_constant_override("separation", 6)
	dbg_vbox.add_child(dbg_top)

	var dbg_title = Label.new()
	dbg_title.text = "Tales of Drak Debug Console"
	dbg_title.add_theme_font_size_override("font_size", 18)
	dbg_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbg_top.add_child(dbg_title)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_debug_panel)
	dbg_top.add_child(refresh_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_toggle_debug_panel)
	dbg_top.add_child(close_btn)

	var test_btn = Button.new()
	test_btn.text = "RUN PHASE 1 TEST"
	test_btn.pressed.connect(_run_phase1_test)
	dbg_vbox.add_child(test_btn)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbg_vbox.add_child(scroll)

	dbg_lines_label = Label.new()
	dbg_lines_label.add_theme_font_size_override("font_size", 12)
	dbg_lines_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	scroll.add_child(dbg_lines_label)

func _toggle_debug_panel():
	dbg_overlay.visible = not dbg_panel.visible
	dbg_panel.visible = not dbg_panel.visible
	if dbg_panel.visible:
		_refresh_debug_panel()

func _refresh_debug_panel():
	if dbg_lines_label == null:
		return
	var lines = PackedStringArray()
	if gs != null and gs.has_method("get_debug_lines"):
		var gs_lines = gs.get_debug_lines()
		lines.append_array(gs_lines)
	else:
		lines.append("GameState not found")
	lines.append("--- HUD State ---")
	lines.append("Selected item index: %d" % selected_item_index)
	lines.append("Selected recipe index: %d" % selected_recipe_index)
	lines.append("Active tab: %s" % active_tab)
	dbg_lines_label.text = "\n".join(lines)

func _build_inventory_panel():
	overlay = ColorRect.new()
	overlay.visible = false
	overlay.color = Color(0,0,0,0.32)
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	panel = PanelContainer.new()
	panel.visible = false
	panel.anchor_left = 0.04
	panel.anchor_top = 0.08
	panel.anchor_right = 0.96
	panel.anchor_bottom = 0.88
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025,0.018,0.014,0.86), Color(0.74,0.55,0.32,0.96), 10))
	add_child(panel)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var main = VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)
	margin.add_child(main)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	main.add_child(top)
	var title = Label.new()
	title.text = "Inventory / Character"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	tab_character = _tab("Character", "character")
	tab_backpack = _tab("Backpack", "backpack")
	tab_crafting = _tab("Crafting", "crafting")
	top.add_child(tab_character)
	top.add_child(tab_backpack)
	top.add_child(tab_crafting)
	var close = Button.new()
	close.text = "X"
	close.pressed.connect(_toggle_inventory)
	top.add_child(close)
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(cols)
	left_label = _add_column(cols, 230)
	center_label = _add_column(cols, 230)
	var right_panel = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(370, 260)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055,0.045,0.035,0.74), Color(0.42,0.28,0.16,0.95), 8))
	cols.add_child(right_panel)
	var right_margin = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 8)
	right_margin.add_theme_constant_override("margin_top", 8)
	right_margin.add_theme_constant_override("margin_right", 8)
	right_margin.add_theme_constant_override("margin_bottom", 8)
	right_panel.add_child(right_margin)
	var right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 6)
	right_margin.add_child(right_box)
	var showing = Label.new()
	showing.text = "Showing All"
	right_box.add_child(showing)
	grid = GridContainer.new()
	grid.columns = GRID_COLUMNS
	right_box.add_child(grid)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 14)
	right_box.add_child(detail_label)

func _add_column(parent, width):
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 260)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _panel_style(Color(0.06,0.045,0.035,0.74), Color(0.42,0.28,0.16,0.95), 8))
	parent.add_child(p)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	p.add_child(m)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	m.add_child(box)
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	box.add_child(label)
	if parent.get_child_count() == 1:
		primary_button = Button.new()
		primary_button.custom_minimum_size = Vector2(160, 34)
		primary_button.pressed.connect(_primary_action)
		secondary_button = Button.new()
		secondary_button.custom_minimum_size = Vector2(160, 34)
		secondary_button.pressed.connect(_secondary_action)
		box.add_child(primary_button)
		box.add_child(secondary_button)
	return label

func _tab(text, id):
	var b = Button.new()
	b.text = text
	b.pressed.connect(func(): active_tab = id; _update_view())
	return b

func _toggle_inventory():
	_refresh_from_gamestate()
	panel.visible = not panel.visible
	overlay.visible = panel.visible
	_update_view()

func set_player_health(current_hp, max_hp):
	var safe_max = max(1, int(max_hp))
	var safe_current = clamp(int(current_hp), 0, safe_max)
	if hp_fill != null: hp_fill.size.x = 222.0 * float(safe_current) / float(safe_max)
	if hp_text != null: hp_text.text = "%d / %d HP" % [safe_current, safe_max]

func set_progression(level, xp, xp_to_next):
	var safe_next = max(1, int(xp_to_next))
	var safe_xp = clamp(int(xp), 0, safe_next)
	if xp_fill != null: xp_fill.size.x = 224.0 * float(safe_xp) / float(safe_next)
	if xp_text != null: xp_text.text = "LV %d  XP %d/%d" % [int(level), safe_xp, safe_next]

func set_character_summary(display_name, class_id): title_label.text = "Character: %s (%s)" % [str(display_name), str(class_id)]
func set_inventory_summary(lines): set_inventory_tabs(lines, PackedStringArray(), character_lines)

func set_inventory_tabs(backpack, _crafting, character):
	backpack_lines = backpack
	character_lines = character
	selected_item_index = clamp(selected_item_index, 0, max(0, backpack_lines.size() - 1))
	_parse_counts()
	inventory_label.text = "Backpack: empty" if backpack_lines.is_empty() else "Backpack: %d item type(s)" % backpack_lines.size()
	_update_view()

func set_prompt(text): prompt_label.text = "Prompt: %s" % str(text)
func set_last_result(text): result_label.text = "Last: %s" % str(text)

func _parse_counts():
	inventory_counts.clear()
	for line in backpack_lines:
		var p = _parse_line(str(line))
		var id = str(p.get("item_id", ""))
		if id != "": inventory_counts[id] = int(p.get("quantity", 0))

func _parse_line(line):
	var parts = str(line).strip_edges().split(" x")
	if parts.size() >= 2:
		return {"item_id": str(parts[0]).strip_edges(), "quantity": int(str(parts[1]).strip_edges())}
	return {"item_id": str(line).strip_edges(), "quantity": 1}

func _update_view():
	if left_label == null: return
	for child in grid.get_children(): child.queue_free()
	if active_tab == "crafting": _show_crafting()
	elif active_tab == "character": _show_character()
	else: _show_backpack()

func _show_backpack():
	left_label.text = _item_details()
	center_label.text = "BACKPACK\n\nTap an item to inspect it.\n\nUsable items show USE.\nEquippable items show EQUIP."
	detail_label.text = "Backpack: selected item details appear on the left."
	for i in range(40):
		var slot = Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		if i < backpack_lines.size():
			var p = _parse_line(backpack_lines[i])
			var id = str(p.get("item_id", ""))
			slot.text = "%s\n%d" % [_item_icon(id), int(p.get("quantity", 0))]
			slot.pressed.connect(func(idx=i): selected_item_index = idx; _update_view())
		else:
			slot.disabled = true
		grid.add_child(slot)
	_update_action_buttons()

func _show_crafting():
	left_label.text = _recipe_details()
	center_label.text = "CRAFTING\n\nOnly recipe icons show in the grid.\nTap an icon to see requirements."
	detail_label.text = "Crafting: select recipe, then tap CRAFT under details."
	for i in range(40):
		var slot = Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		if i < recipes.size():
			var r = recipes[i]
			slot.text = str(r.get("icon", "?"))
			slot.pressed.connect(func(idx=i): selected_recipe_index = idx; _update_view())
		else:
			slot.disabled = true
		grid.add_child(slot)
	_update_action_buttons()

func _show_character():
	left_label.text = "CHARACTER\n\n" + "\n".join(character_lines)
	center_label.text = "CHARACTER VIEW\n\n[ Head ]\n\n[ Chest ]  [ Hands ]\n\n[ Main Hand ] [ Off Hand ]\n\n[ Legs ]\n\n[ Boots ]"
	detail_label.text = "Character: HP, XP, AC, weapons, armor, and progression."
	primary_button.visible = false
	secondary_button.visible = false
	for i in range(40):
		var l = Label.new()
		l.custom_minimum_size = SLOT_SIZE
		l.text = character_lines[i].substr(0, 9) if i < character_lines.size() else ""
		grid.add_child(l)

func _item_details():
	if backpack_lines.is_empty(): return "BACKPACK\n\nNo items."
	var id = str(_parse_line(backpack_lines[clamp(selected_item_index, 0, backpack_lines.size() - 1)]).get("item_id", ""))
	var d = _item_def(id)
	var text = "ITEM: %s\nType: %s\nQty: %d\n\n%s" % [str(d.get("name", id)).to_upper(), str(d.get("type", "unknown")), int(inventory_counts.get(id, 0)), str(d.get("description", "No description."))]
	var dice = str(d.get("damage_dice", ""))
	if dice != "":
		text += "\nDamage: %s" % dice
		var bonus = int(d.get("damage_bonus", 0))
		if bonus > 0:
			text += " +%d" % bonus
	return text

func _recipe_details():
	var r = recipes[clamp(selected_recipe_index, 0, recipes.size() - 1)]
	var output_id = str(r.get("output_item_id", r.get("id", "item")))
	var text = "ENGRAM: %s / %s\n\n%s\n\nCreates: %s x%d\n\nCrafting Requirements\n" % [str(r.get("name", "Recipe")).to_upper(), str(r.get("category", "Primitive")), str(r.get("description", "")), _item_name(output_id), int(r.get("output_quantity", 1))]
	for id in r.get("requirements", {}).keys():
		text += "%s: %d / %d\n" % [_item_name(str(id)), int(inventory_counts.get(str(id), 0)), int(r["requirements"][id])]
	return text

func _recipe_craftable(r):
	for id in r.get("requirements", {}).keys():
		if int(inventory_counts.get(str(id), 0)) < int(r["requirements"][id]): return false
	return true

func _update_action_buttons():
	primary_button.visible = false
	secondary_button.visible = false
	if active_tab == "crafting":
		var r = recipes[clamp(selected_recipe_index, 0, recipes.size() - 1)]
		primary_button.visible = true
		primary_button.disabled = not _recipe_craftable(r)
		primary_button.text = "CRAFT" if _recipe_craftable(r) else "MISSING MATERIALS"
	elif active_tab == "backpack" and not backpack_lines.is_empty():
		var id = str(_parse_line(backpack_lines[clamp(selected_item_index, 0, backpack_lines.size() - 1)]).get("item_id", ""))
		var d = _item_def(id)
		primary_button.visible = bool(d.get("usable", false))
		primary_button.text = "USE"
		secondary_button.visible = bool(d.get("equippable", false))
		secondary_button.text = "EQUIP"

func _primary_action():
	if active_tab == "crafting":
		_craft_direct(recipes[clamp(selected_recipe_index, 0, recipes.size() - 1)])
	elif active_tab == "backpack" and not backpack_lines.is_empty():
		_use_direct(str(_parse_line(backpack_lines[clamp(selected_item_index, 0, backpack_lines.size() - 1)]).get("item_id", "")))

func _secondary_action():
	if active_tab == "backpack" and not backpack_lines.is_empty():
		_equip_direct(str(_parse_line(backpack_lines[clamp(selected_item_index, 0, backpack_lines.size() - 1)]).get("item_id", "")))

func _craft_direct(recipe):
	if gs == null:
		craft_recipe_requested.emit(recipe)
		return
	var result = gs.craft_recipe(recipe)
	set_last_result(str(result.get("message", "Craft result.")))
	_refresh_from_gamestate()

func _use_direct(item_id):
	if gs == null:
		use_item_requested.emit(item_id)
		return
	var result = gs.use_item(item_id)
	set_last_result(str(result.get("message", "Used item.")))
	_refresh_from_gamestate()

func _equip_direct(item_id):
	if gs == null:
		equip_item_requested.emit(item_id)
		return
	var result = gs.equip_item(item_id)
	set_last_result(str(result.get("message", "Equip result.")))
	_refresh_from_gamestate()

func _item_def(item_id):
	item_id = str(item_id)
	if item_defs.has(item_id): return item_defs[item_id]
	return {"name":item_id.replace("_", " ").capitalize(), "icon":"?", "type":"unknown", "description":"No item details yet.", "usable":false, "equippable":false}

func _item_name(item_id): return str(_item_def(item_id).get("name", item_id))
func _item_icon(item_id): return str(_item_def(item_id).get("icon", "?"))

func _run_phase1_test():
	if gs == null:
		gs = get_node_or_null("/root/GameState")
	var results = PackedStringArray()
	results.append("=== PHASE 1 SELF TEST ===")
	if gs == null:
		results.append("GameState: FAIL — not found")
		dbg_lines_label.text = "\n".join(results)
		return
	results.append("GameState: OK")
	gs.ensure_runtime_state()

	var start_timber = gs.get_item_count("weathered_timber")
	var start_bandage = gs.get_item_count("starter_bandage")
	var bandage_recipe = {"id":"starter_bandage","name":"Simple Bandage","requirements":{"weathered_timber":2},"output_item_id":"starter_bandage","output_quantity":1}
	var craft_result = gs.craft_recipe(bandage_recipe)
	var end_timber = gs.get_item_count("weathered_timber")
	var end_bandage = gs.get_item_count("starter_bandage")

	if craft_result.get("ok", false):
		results.append("Craft Simple Bandage: PASS")
	else:
		results.append("Craft Simple Bandage: FAIL - %s" % craft_result.get("message", "unknown"))
	if end_timber == start_timber - 2:
		results.append("Weathered Timber consumed: PASS")
	else:
		results.append("Weathered Timber consumed: FAIL - timber stayed %d instead of %d" % [end_timber, start_timber - 2])
	if end_bandage == start_bandage + 1:
		results.append("Bandage added: PASS")
	else:
		results.append("Bandage added: FAIL - bandage %d instead of %d" % [end_bandage, start_bandage + 1])

	var equip_result = gs.equip_item("starter_hatchet")
	if equip_result.get("ok", false) and gs.equipment.get("main_hand", "") == "starter_hatchet":
		results.append("Equip Starter Hatchet: PASS")
	else:
		results.append("Equip Starter Hatchet: FAIL - %s, main_hand=%s" % [equip_result.get("message", ""), gs.equipment.get("main_hand", "")])

	var hp_before = int(gs.current_hp)
	var damage_result = gs.damage_player(5, "self_test_enemy")
	var hp_after = int(gs.current_hp)
	if damage_result.get("ok", false) and hp_after == hp_before - 5:
		results.append("Damage Player: PASS")
	else:
		results.append("Damage Player: FAIL - HP %d -> %d (expected -5)" % [hp_before, hp_after])

	var sword_before = gs.get_item_count("rusty_sword")
	var coin_before = gs.get_item_count("ancient_coin")
	gs.add_item("rusty_sword", 1)
	gs.add_item("ancient_coin", 5)
	var sword_after = gs.get_item_count("rusty_sword")
	var coin_after = gs.get_item_count("ancient_coin")
	if sword_after > sword_before and coin_after > coin_before:
		results.append("Chest Loot Added: PASS")
	else:
		results.append("Chest Loot Added: FAIL - sword %d->%d, coin %d->%d" % [sword_before, sword_after, coin_before, coin_after])

	gs.equip_item("rusty_sword")
	var main_hand = gs.equipment.get("main_hand", "")
	if main_hand == "rusty_sword":
		results.append("Equip Rusty Sword: PASS")
	else:
		results.append("Equip Rusty Sword: FAIL - main_hand=%s" % main_hand)

	var hatchet_bonus = int(gs.get_item_definition("starter_hatchet").get("damage_bonus", 0))
	var sword_bonus = gs.get_weapon_damage_bonus()
	if sword_bonus > hatchet_bonus:
		results.append("Weapon Bonus Increased: PASS")
	else:
		results.append("Weapon Bonus Increased: FAIL - sword bonus %d <= hatchet bonus %d" % [sword_bonus, hatchet_bonus])

	var all_pass = true
	for line in results:
		if "FAIL" in line:
			all_pass = false
			break
	if all_pass:
		results.append("Overall: PASS")
	else:
		results.append("Overall: FAIL")

	_refresh_from_gamestate()
	if not dbg_panel.visible:
		_toggle_debug_panel()
	dbg_lines_label.text = "\n".join(results)
