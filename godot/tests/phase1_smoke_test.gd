extends SceneTree

const GAMESTATE_PATH := "res://scripts/systems/game_state.gd"

var gs = null
var failures = 0
var total = 0

func _init():
	_run_all_tests()
	quit(0 if failures == 0 else 1)

func _run_all_tests():
	print("=== PHASE 1 SMOKE TEST ===")

	_test_script_loadable()
	if gs == null:
		print("FATAL: GameState script could not be loaded. Aborting.")
		return

	_test_instantiate()
	if gs == null:
		print("FATAL: GameState could not be instantiated. Aborting.")
		return

	_test_ensure_runtime_state()
	_test_craft_bandage()
	_test_equip_hatchet()
	_test_damage_player()
	_test_add_chest_loot()
	_test_equip_sword()
	_test_inventory_lines()
	_test_character_view_lines()

	print("---")
	if failures == 0:
		print("PHASE 1 SMOKE TEST: PASS (%d/%d)" % [total, total])
	else:
		print("PHASE 1 SMOKE TEST: FAIL (%d failures in %d tests)" % [failures, total])

func _check(label: String, condition: bool, detail := ""):
	total += 1
	if condition:
		print("  PASS: %s" % label)
	else:
		failures += 1
		var msg = "  FAIL: %s" % label
		if detail != "":
			msg += "  -- %s" % detail
		print(msg)

func _test_script_loadable():
	var script = load(GAMESTATE_PATH)
	_check("GameState script loadable from %s" % GAMESTATE_PATH, script != null)

func _test_instantiate():
	var script = load(GAMESTATE_PATH)
	if script == null:
		gs = null
		_check("GameState instantiated", false, "script was null")
		return
	gs = script.new()
	root.add_child(gs)
	_check("GameState instantiated and added to root", gs != null)

func _test_ensure_runtime_state():
	gs.ensure_runtime_state()
	var hp = int(gs.current_hp)
	var hatch = int(gs.get_item_count("starter_hatchet"))
	var timber = int(gs.get_item_count("weathered_timber"))
	var torch = int(gs.get_item_count("torch_kit"))
	var main_hand = str(gs.equipment.get("main_hand", ""))

	_check("HP > 1", hp > 1, "HP = %d" % hp)
	_check("starter_hatchet x1", hatch == 1, "count = %d" % hatch)
	_check("weathered_timber x10", timber == 10, "count = %d" % timber)
	_check("torch_kit x1", torch == 1, "count = %d" % torch)
	_check("equipment.main_hand = starter_hatchet", main_hand == "starter_hatchet", "main_hand = '%s'" % main_hand)

func _test_craft_bandage():
	var timber_before = int(gs.get_item_count("weathered_timber"))
	var bandage_before = int(gs.get_item_count("starter_bandage"))

	var recipe = {"id":"starter_bandage","name":"Simple Bandage","requirements":{"weathered_timber":2},"output_item_id":"starter_bandage","output_quantity":1}
	var result = gs.craft_recipe(recipe)

	var timber_after = int(gs.get_item_count("weathered_timber"))
	var bandage_after = int(gs.get_item_count("starter_bandage"))

	_check("craft_recipe returns ok", bool(result.get("ok", false)), str(result))
	_check("Weathered Timber consumed x2", timber_after == timber_before - 2, "%d -> %d" % [timber_before, timber_after])
	_check("Simple Bandage added x1", bandage_after == bandage_before + 1, "%d -> %d" % [bandage_before, bandage_after])

func _test_equip_hatchet():
	var result = gs.equip_item("starter_hatchet")
	var main_hand = str(gs.equipment.get("main_hand", ""))
	_check("equip_item('starter_hatchet') ok", bool(result.get("ok", false)), str(result))
	_check("main_hand = starter_hatchet", main_hand == "starter_hatchet", "main_hand = '%s'" % main_hand)

func _test_damage_player():
	var hp_before = int(gs.current_hp)
	var result = gs.damage_player(5, "test")
	var hp_after = int(gs.current_hp)
	_check("damage_player returns ok", bool(result.get("ok", false)), str(result))
	_check("HP reduced by 5", hp_after == hp_before - 5, "%d -> %d (expected %d -> %d)" % [hp_before, hp_after, hp_before, hp_before - 5])

func _test_add_chest_loot():
	var sword_before = int(gs.get_item_count("rusty_sword"))
	var coin_before = int(gs.get_item_count("ancient_coin"))

	gs.add_item("rusty_sword", 1)
	gs.add_item("ancient_coin", 5)

	var sword_after = int(gs.get_item_count("rusty_sword"))
	var coin_after = int(gs.get_item_count("ancient_coin"))

	_check("rusty_sword added x1", sword_after - sword_before == 1, "%d -> %d" % [sword_before, sword_after])
	_check("ancient_coin added x5", coin_after - coin_before == 5, "%d -> %d" % [coin_before, coin_after])

func _test_equip_sword():
	var result = gs.equip_item("rusty_sword")
	var main_hand = str(gs.equipment.get("main_hand", ""))
	_check("equip_item('rusty_sword') ok", bool(result.get("ok", false)), str(result))
	_check("main_hand = rusty_sword", main_hand == "rusty_sword", "main_hand = '%s'" % main_hand)

func _test_inventory_lines():
	var lines = gs.get_inventory_lines()
	var has_items = lines.size() > 0
	_check("get_inventory_lines returns items", has_items, "%d lines returned" % lines.size())
	if has_items:
		var joined = " | ".join(lines)
		_check("inventory contains starter_hatchet", "starter_hatchet" in joined, joined)
		_check("inventory contains weathered_timber", "weathered_timber" in joined, joined)
		_check("inventory contains rusty_sword", "rusty_sword" in joined, joined)
		_check("inventory contains ancient_coin", "ancient_coin" in joined, joined)

func _test_character_view_lines():
	var lines = gs.get_character_view_lines()
	var has_lines = lines.size() > 0
	_check("get_character_view_lines returns lines", has_lines, "%d lines returned" % lines.size())
	if has_lines:
		var joined = " | ".join(lines)
		_check("character view contains HP", "HP" in joined, joined)
		_check("character view contains XP", "XP" in joined, joined)
		_check("character view contains main hand", "main_hand" in joined.to_lower(), joined)
