extends Control

## Stage 14 Character Creator Shell
##
## Landscape-first D&D-style creator:
## - Human / Elf / Dwarf
## - Fighter / Warlock / Wizard
## - subclass auto-pairs for now
## - simple stat preview
## - starts the existing test world with selected character stored in GameState

const TEST_WORLD_SCENE := "res://scenes/test_world/test_world.tscn"

const SPECIES_OPTIONS := [
	{
		"id": "human",
		"name": "Human",
		"summary": "+1 to all ability scores. Adaptable and reliable.",
		"bonuses": {"STR": 1, "DEX": 1, "CON": 1, "INT": 1, "WIS": 1, "CHA": 1},
	},
	{
		"id": "elf",
		"name": "Elf",
		"summary": "+2 DEX. Keen senses and graceful movement.",
		"bonuses": {"DEX": 2},
	},
	{
		"id": "dwarf",
		"name": "Dwarf",
		"summary": "+2 CON. Tough, sturdy, and resilient.",
		"bonuses": {"CON": 2},
	},
]

const CLASS_OPTIONS := [
	{
		"id": "fighter",
		"name": "Fighter",
		"subclass_id": "champion",
		"subclass_name": "Champion",
		"summary": "Martial frontline class. Strong basic attacks and simple durability.",
		"bonuses": {"STR": 1, "CON": 1},
	},
	{
		"id": "warlock",
		"name": "Warlock",
		"subclass_id": "fiend_pact",
		"subclass_name": "Fiend Pact",
		"summary": "Charisma caster with dark pact flavor. Combat tuning comes later.",
		"bonuses": {"CHA": 1, "CON": 1},
	},
	{
		"id": "wizard",
		"name": "Wizard",
		"subclass_id": "evocation",
		"subclass_name": "Evocation",
		"summary": "Intelligence caster focused on direct arcane damage later.",
		"bonuses": {"INT": 1, "WIS": 1},
	},
]

@onready var name_input: LineEdit = $Root/Panel/Margin/Columns/Left/NameInput
@onready var species_buttons: VBoxContainer = $Root/Panel/Margin/Columns/Left/SpeciesButtons
@onready var class_buttons: VBoxContainer = $Root/Panel/Margin/Columns/Middle/ClassButtons
@onready var preview_label: Label = $Root/Panel/Margin/Columns/Right/PreviewPanel/PreviewMargin/PreviewLabel
@onready var start_button: Button = $Root/Panel/Margin/Columns/Right/StartButton

var selected_species_index := 0
var selected_class_index := 0
var species_button_refs: Array[Button] = []
var class_button_refs: Array[Button] = []


func _ready() -> void:
	_build_buttons()
	name_input.text = "Adventurer"
	name_input.text_changed.connect(func(_text: String) -> void: _update_preview())
	start_button.pressed.connect(_start_adventure)
	_update_preview()


func _build_buttons() -> void:
	for i in range(SPECIES_OPTIONS.size()):
		var option: Dictionary = SPECIES_OPTIONS[i]
		var btn := Button.new()
		btn.text = option["name"]
		btn.custom_minimum_size = Vector2(190, 42)
		btn.pressed.connect(_select_species.bind(i))
		species_buttons.add_child(btn)
		species_button_refs.append(btn)

	for i in range(CLASS_OPTIONS.size()):
		var option: Dictionary = CLASS_OPTIONS[i]
		var btn := Button.new()
		btn.text = "%s\n%s" % [option["name"], option["subclass_name"]]
		btn.custom_minimum_size = Vector2(210, 54)
		btn.pressed.connect(_select_class.bind(i))
		class_buttons.add_child(btn)
		class_button_refs.append(btn)


func _select_species(index: int) -> void:
	selected_species_index = index
	_update_preview()


func _select_class(index: int) -> void:
	selected_class_index = index
	_update_preview()


func _update_preview() -> void:
	for i in range(species_button_refs.size()):
		species_button_refs[i].modulate = Color(0.25, 0.75, 1.0, 1.0) if i == selected_species_index else Color(1, 1, 1, 0.85)
	for i in range(class_button_refs.size()):
		class_button_refs[i].modulate = Color(0.65, 0.45, 1.0, 1.0) if i == selected_class_index else Color(1, 1, 1, 0.85)

	var species: Dictionary = SPECIES_OPTIONS[selected_species_index]
	var clazz: Dictionary = CLASS_OPTIONS[selected_class_index]
	var stats := _calculate_preview_stats(species, clazz)
	var character_name := name_input.text.strip_edges()
	if character_name.is_empty():
		character_name = "Adventurer"

	preview_label.text = "Name: %s\nRace: %s\nClass: %s\nSubclass: %s\n\n%s\n\n%s\n\nStats\n%s\n\nNext: appearance, spell lists, and real class-specific abilities." % [
		character_name,
		species["name"],
		clazz["name"],
		clazz["subclass_name"],
		species["summary"],
		clazz["summary"],
		_format_stats(stats),
	]


func _calculate_preview_stats(species: Dictionary, clazz: Dictionary) -> Dictionary:
	var stats := {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10}
	for source in [species.get("bonuses", {}), clazz.get("bonuses", {})]:
		for key in source.keys():
			stats[key] = int(stats.get(key, 10)) + int(source[key])
	return stats


func _format_stats(stats: Dictionary) -> String:
	return "STR %d | DEX %d | CON %d\nINT %d | WIS %d | CHA %d" % [
		stats["STR"], stats["DEX"], stats["CON"],
		stats["INT"], stats["WIS"], stats["CHA"],
	]


func _start_adventure() -> void:
	var species: Dictionary = SPECIES_OPTIONS[selected_species_index]
	var clazz: Dictionary = CLASS_OPTIONS[selected_class_index]
	var selection := {
		"character_name": name_input.text,
		"species_id": species["id"],
		"species_name": species["name"],
		"class_id": clazz["id"],
		"class_name": clazz["name"],
		"subclass_id": clazz["subclass_id"],
		"subclass_name": clazz["subclass_name"],
	}
	if GameState != null:
		GameState.set_character(selection)
	get_tree().call_deferred("change_scene_to_file", TEST_WORLD_SCENE)
