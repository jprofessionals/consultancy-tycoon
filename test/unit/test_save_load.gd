extends GutTest

var save_mgr: Node
var state: Node

const TEST_SAVE_PATH = "user://test_savegame.json"

func before_each():
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)
	save_mgr = load("res://src/systems/save_manager.gd").new()
	save_mgr.save_path = TEST_SAVE_PATH
	add_child_autofree(save_mgr)

func after_each():
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

func _runtime(tabs: Array = [], focused: int = 0) -> Dictionary:
	return {"game_started": true, "tabs": save_mgr.serialize_tabs(tabs), "focused_index": focused}

# ── Round-trip: GameState fields ──

func test_round_trip_money_and_reputation():
	state.money = 12345.67
	state.reputation = 42.5
	save_mgr.save_game(_runtime(), state)

	state.money = 0.0
	state.reputation = 0.0

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_almost_eq(state.money, 12345.67, 0.01, "Money should be restored")
	assert_almost_eq(state.reputation, 42.5, 0.01, "Reputation should be restored")

func test_round_trip_skills():
	state.skills = {"javascript": 3, "python": 2, "devops": 1}
	save_mgr.save_game(_runtime(), state)

	state.skills = {}

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_eq(state.skills.get("javascript"), 3)
	assert_eq(state.skills.get("python"), 2)
	assert_eq(state.skills.get("devops"), 1)

func test_round_trip_ai_tools():
	state.ai_tools = {"auto_writer": 2, "auto_reviewer": 1}
	save_mgr.save_game(_runtime(), state)

	state.ai_tools = {}

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_eq(state.ai_tools.get("auto_writer"), 2)
	assert_eq(state.ai_tools.get("auto_reviewer"), 1)

func test_round_trip_office_unlocked():
	state.office_unlocked = true
	save_mgr.save_game(_runtime(), state)

	state.office_unlocked = false

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_true(state.office_unlocked, "Office unlocked should be restored")

func test_round_trip_easter_eggs():
	state.claimed_easter_eggs = {"bsod": true}
	save_mgr.save_game(_runtime(), state)

	state.claimed_easter_eggs = {}

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_true(state.claimed_easter_eggs.get("bsod", false), "Easter eggs should be restored")

# ── Consultants ──

func test_round_trip_consultants():
	var c = ConsultantData.new()
	c.id = "save_test_1"
	c.name = "Save Tester"
	c.skills = {"javascript": 3, "python": 1}
	c.salary = 750.0
	c.trait_id = "fast"
	c.morale = 0.85
	state.consultants.append(c)

	save_mgr.save_game(_runtime(), state)

	state.consultants.clear()

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_eq(state.consultants.size(), 1, "Should restore 1 consultant")
	var restored = state.consultants[0]
	assert_eq(restored.id, "save_test_1")
	assert_eq(restored.name, "Save Tester")
	assert_eq(restored.skills.get("javascript"), 3)
	assert_almost_eq(restored.salary, 750.0, 0.01)
	assert_eq(restored.trait_id, "fast")
	assert_almost_eq(restored.morale, 0.85, 0.01)

# ── Assignments with consultant reference reconstruction ──

func test_round_trip_assignments_reconstruct_refs():
	var c1 = ConsultantData.new()
	c1.id = "ref_test_1"
	c1.name = "Ref Tester"
	c1.skills = {"python": 2}
	c1.salary = 500.0
	c1.trait_id = "careful"
	c1.morale = 1.0
	state.consultants.append(c1)

	var contract = ClientContract.new()
	contract.client_name = "RefCo"
	contract.project_description = "Ref project"
	contract.tier = 2
	contract.task_count = 3
	contract.payout_per_task = 150.0

	var assignment = ConsultantAssignment.new()
	assignment.contract = contract
	assignment.consultants = [c1]
	assignment.current_task_index = 1
	assignment.current_task_progress = 0.5
	state.active_assignments.append(assignment)

	save_mgr.save_game(_runtime(), state)

	state.consultants.clear()
	state.active_assignments.clear()

	var data = save_mgr.load_game()
	save_mgr.apply_save(data, state)

	assert_eq(state.active_assignments.size(), 1, "Should restore 1 assignment")
	var restored_a = state.active_assignments[0]
	assert_eq(restored_a.contract.client_name, "RefCo")
	assert_eq(restored_a.current_task_index, 1)
	assert_almost_eq(restored_a.current_task_progress, 0.5, 0.01)
	assert_eq(restored_a.consultants.size(), 1)
	assert_eq(restored_a.consultants[0].id, "ref_test_1")
	assert_true(restored_a.consultants[0] == state.consultants[0], "Should be same object reference")

# ── Tabs ──

func test_round_trip_tabs():
	var contract = ClientContract.new()
	contract.client_name = "TabCo"
	contract.project_description = "Tab project"
	contract.tier = 2
	contract.task_count = 5
	contract.payout_per_task = 200.0

	var tab = CodingTab.new()
	tab.contract = contract
	tab.task_index = 2
	tab.total_tasks = 5
	tab.difficulty_modifier = 1.3

	var task = CodingTask.new()
	task.title = "Tab Task"
	task.difficulty = 4
	task.payout = 200.0
	task.total_clicks = 15
	tab.coding_loop.current_task = task
	tab.coding_loop.state = CodingLoop.State.WRITING
	tab.coding_loop.progress = 0.4

	save_mgr.save_game(_runtime([tab], 0), state)

	var data = save_mgr.load_game()
	var restored = save_mgr.apply_save(data, state)

	assert_true(restored.has("tabs"), "Should have tabs key")
	var tabs = save_mgr.deserialize_tabs(restored["tabs"])
	assert_eq(tabs.size(), 1, "Should restore 1 tab")
	var rt = tabs[0]
	assert_eq(rt.contract.client_name, "TabCo")
	assert_eq(rt.task_index, 2)
	assert_eq(rt.total_tasks, 5)
	assert_almost_eq(rt.difficulty_modifier, 1.3, 0.01)
	assert_eq(rt.coding_loop.state, CodingLoop.State.WRITING)
	assert_almost_eq(rt.coding_loop.progress, 0.4, 0.01)
	assert_eq(rt.coding_loop.current_task.title, "Tab Task")

func test_round_trip_multiple_tabs():
	var tab1 = CodingTab.new()
	tab1.contract = ClientContract.new()
	tab1.contract.client_name = "Alpha"
	tab1.total_tasks = 3
	tab1.task_index = 1

	var tab2 = CodingTab.new()
	tab2.contract = ClientContract.new()
	tab2.contract.client_name = "Beta"
	tab2.total_tasks = 4
	tab2.task_index = 0
	tab2.stuck = true

	save_mgr.save_game(_runtime([tab1, tab2], 1), state)

	var data = save_mgr.load_game()
	var restored = save_mgr.apply_save(data, state)

	var tabs = save_mgr.deserialize_tabs(restored["tabs"])
	assert_eq(tabs.size(), 2)
	assert_eq(tabs[0].contract.client_name, "Alpha")
	assert_eq(tabs[1].contract.client_name, "Beta")
	assert_true(tabs[1].stuck, "Stuck flag should be preserved")
	assert_eq(restored["focused_index"], 1)

func test_round_trip_coding_loop():
	var loop = CodingLoop.new()
	var task = CodingTask.new()
	task.title = "Save Test Task"
	task.description = "Testing save"
	task.difficulty = 5
	task.payout = 200.0
	task.total_clicks = 20
	loop.current_task = task
	loop.state = CodingLoop.State.WRITING
	loop.progress = 0.6
	loop.review_changes_needed = 0

	var loop_data = save_mgr.serialize_coding_loop(loop)
	assert_false(loop_data.is_empty(), "Should serialize non-idle loop")

	var new_loop = CodingLoop.new()
	save_mgr.deserialize_coding_loop(new_loop, loop_data)

	assert_eq(new_loop.state, CodingLoop.State.WRITING)
	assert_almost_eq(new_loop.progress, 0.6, 0.01)
	assert_not_null(new_loop.current_task)
	assert_eq(new_loop.current_task.title, "Save Test Task")
	assert_eq(new_loop.current_task.difficulty, 5)
	assert_almost_eq(new_loop.current_task.payout, 200.0, 0.01)

# ── Backward compatibility ──

func test_backward_compat_old_save_format():
	# Simulate an old save with active_contract instead of tabs
	var old_data: Dictionary = {
		"version": 1,
		"timestamp": 12345,
		"game_state": {
			"money": 5000.0,
			"reputation": 10.0,
			"skills": {},
			"ai_tools": {},
			"office_unlocked": false,
			"claimed_easter_eggs": {},
		},
		"consultants": [],
		"active_assignments": [],
		"active_contract": {
			"client_name": "OldCo",
			"project_description": "Old project",
			"tier": 2,
			"task_count": 4,
			"payout_per_task": 100.0,
			"required_skills": {},
			"duration": 60.0,
		},
		"tasks_remaining": 2,
		"difficulty_modifier": 1.5,
		"coding_loop": null,
		"game_started": true,
	}
	# Write the old-format save directly
	var json_string = JSON.stringify(old_data, "\t")
	var file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(json_string)
	file.close()

	var data = save_mgr.load_game()
	var restored = save_mgr.apply_save(data, state)

	# Should fall back to old format
	assert_not_null(restored.get("active_contract"), "Old save should restore active_contract")
	assert_eq(restored["active_contract"].client_name, "OldCo")
	assert_eq(restored["tasks_remaining"], 2)
	assert_almost_eq(restored["difficulty_modifier"], 1.5, 0.01)

# ── Edge cases ──

func test_load_empty_returns_empty():
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	var data = save_mgr.load_game()
	assert_true(data.is_empty(), "Should return empty dict when no save exists")

func test_has_save_false_when_no_file():
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	assert_false(save_mgr.has_save())

func test_has_save_true_after_save():
	save_mgr.save_game(_runtime(), state)
	assert_true(save_mgr.has_save())

func test_delete_save():
	save_mgr.save_game(_runtime(), state)
	assert_true(save_mgr.has_save())
	save_mgr.delete_save()
	assert_false(save_mgr.has_save())

func test_idle_coding_loop_serializes_empty():
	var loop = CodingLoop.new()
	var data = save_mgr.serialize_coding_loop(loop)
	assert_true(data.is_empty(), "Idle loop should serialize to empty dict")

func test_empty_tabs_round_trip():
	save_mgr.save_game(_runtime(), state)

	var data = save_mgr.load_game()
	var restored = save_mgr.apply_save(data, state)

	# With empty tabs, no active_contract key either
	assert_false(restored.has("active_contract"), "Empty tabs save should not have active_contract")

func test_save_version_present():
	save_mgr.save_game(_runtime(), state)

	var data = save_mgr.load_game()
	assert_eq(data.get("version"), 1, "Save version should be 1")
	assert_true(data.has("timestamp"), "Should have timestamp")
