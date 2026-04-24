extends CanvasLayer
class_name DebugHud

## RPG HUD foundation.
##
## Adds:
## - top-left red player HP bar with centered HP number
## - compact prompt/result readout
## - top-right inventory button
## - tabbed inventory shell: Backpack / Crafting / Character

const HUD_FONT_SIZE: int = 18
const HP_BAR_SIZE: Vector2 = Vector2(230, 34)
const HP_FILL_MARGIN: float = 4.0

@onready var root_margin: MarginContainer = $MarginContainer
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var inventory_label: Label = $MarginContainer/VBoxContainer/InventoryLabel
@onready var prompt_label: Label = $MarginContainer/VBoxContainer/PromptLabel
@onready var result_label: Label = $MarginContainer/VBoxContainer/ResultLabel

var _hp_fill: ColorRect
var _hp_text: Label
var _inventory_button: Button
var _inventory_panel: PanelContainer
var _backpack_label: Label
var _crafting_label: Label
var _character_label: Label
var _player_hp_current: int = 1
var _player_hp_max: int = 1
var _backpack_lines: PackedStringArray = []
var _crafting_lines: PackedStringArray = []
var _character_lines: PackedStringArray = []


func _ready() -> void:
	root_margin.offset_top = 58.0
	for label in [title_label, inventory_label, prompt_label, result_label]:
		label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_player_health_bar()
	_build_inventory_button()
	_build_inventory_panel()
	set_player_health(_player_hp_current, _player_hp_max)
	set_inventory_tabs(PackedStringArray(), PackedStringArray(), PackedStringArray())


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
	add_child(frame)

	var back := ColorRect.new()
	back.name = "HealthBack"
	back.color = Color(0.08, 0.01, 0.01, 0.92)
	back.custom_minimum_size = HP_BAR_SIZE
	frame.add_child(back)

	_hp_fill = ColorRect.new()
	_hp_fill.name = "HealthFill"
	_hp_fill.color = Color(0.82, 0.03, 0.03, 0.96)
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
	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.visible = false
	_inventory_panel.anchor_left = 1.0
	_inventory_panel.anchor_top = 0.0
	_inventory_panel.anchor_right = 1.0
	_inventory_panel.anchor_bottom = 0.0
	_inventory_panel.offset_left = -360.0
	_inventory_panel.offset_top = 58.0
	_inventory_panel.offset_right = -12.0
	_inventory_panel.offset_bottom = 320.0
	_inventory_panel.custom_minimum_size = Vector2(348, 260)
	add_child(_inventory_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_inventory_panel.add_child(margin)

	var tabs := TabContainer.new()
	margin.add_child(tabs)

	_backpack_label = _make_tab_label("Backpack")
	_crafting_label = _make_tab_label("Crafting")
	_character_label = _make_tab_label("Character")
	tabs.add_child(_backpack_label)
	tabs.add_child(_crafting_label)
	tabs.add_child(_character_label)


func _make_tab_label(tab_name: String) -> Label:
	var label := Label.new()
	label.name = tab_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.text = "(empty)"
	return label


func _toggle_inventory_panel() -> void:
	_inventory_panel.visible = not _inventory_panel.visible


func set_player_health(current_hp: int, max_hp: int) -> void:
	_player_hp_current = max(0, current_hp)
	_player_hp_max = max(1, max_hp)
	var ratio := clamp(float(_player_hp_current) / float(_player_hp_max), 0.0, 1.0)
	if _hp_fill != null:
		_hp_fill.size.x = (HP_BAR_SIZE.x - HP_FILL_MARGIN * 2.0) * ratio
	if _hp_text != null:
		_hp_text.text = "%d / %d" % [_player_hp_current, _player_hp_max]


func set_character_summary(display_name: String, class_id: String) -> void:
	title_label.text = "%s (%s)" % [display_name, class_id]
	_character_lines = PackedStringArray([title_label.text])
	_update_inventory_tabs_text()


func set_inventory_summary(lines: PackedStringArray) -> void:
	_backpack_lines = lines
	if lines.is_empty():
		inventory_label.text = "Backpack: empty"
	else:
		inventory_label.text = "Backpack: %d item type(s)" % lines.size()
	_update_inventory_tabs_text()


func set_inventory_tabs(backpack_lines: PackedStringArray, crafting_lines: PackedStringArray, character_lines: PackedStringArray) -> void:
	_backpack_lines = backpack_lines
	_crafting_lines = crafting_lines
	_character_lines = character_lines
	if backpack_lines.is_empty():
		inventory_label.text = "Backpack: empty"
	else:
		inventory_label.text = "Backpack: %d item type(s)" % backpack_lines.size()
	_update_inventory_tabs_text()


func set_crafting_summary(lines: PackedStringArray) -> void:
	_crafting_lines = lines
	_update_inventory_tabs_text()


func set_character_view(lines: PackedStringArray) -> void:
	_character_lines = lines
	_update_inventory_tabs_text()


func _update_inventory_tabs_text() -> void:
	if _backpack_label != null:
		_backpack_label.text = _format_tab_text("Backpack + On Person", _backpack_lines)
	if _crafting_label != null:
		_crafting_label.text = _format_tab_text("Crafting Menu", _crafting_lines)
	if _character_label != null:
		_character_label.text = _format_tab_text("Character / Equipment", _character_lines)


func _format_tab_text(header: String, lines: PackedStringArray) -> String:
	if lines.is_empty():
		return "%s\n\n(empty)" % header
	return "%s\n\n- %s" % [header, "\n- ".join(lines)]


func set_prompt(text: String) -> void:
	prompt_label.text = "Prompt: %s" % text


func set_last_result(text: String) -> void:
	result_label.text = "Last: %s" % text
