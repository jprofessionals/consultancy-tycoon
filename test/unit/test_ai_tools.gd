extends GutTest

var manager: AiToolManager
var state: Node

func before_each():
	manager = load("res://src/logic/ai_tool_manager.gd").new()
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func test_has_four_tools():
	var tools = manager.get_all_tools()
	assert_eq(tools.size(), 4, "Should have 4 AI tools")

func test_tool_has_required_fields():
	var tools = manager.get_all_tools()
	var tool = tools[0]
	assert_ne(tool.id, "", "Tool should have id")
	assert_ne(tool.name, "", "Tool should have name")
	assert_gt(tool.base_cost, 0.0, "Tool should have positive cost")
	assert_gt(tool.max_tier, 0, "Tool should have max tier")

func test_get_tool_by_id():
	var auto_writer = manager.get_tool("auto_writer")
	assert_not_null(auto_writer)
	assert_eq(auto_writer.name, "Auto-Writer")

func test_get_tool_nonexistent():
	var result = manager.get_tool("nonexistent")
	assert_null(result)

func test_upgrade_with_enough_money():
	state.money = 5000.0
	var auto_writer = manager.get_tool("auto_writer")
	var result = manager.try_upgrade(auto_writer, state)
	assert_true(result, "Should upgrade with enough money")
	assert_eq(state.get_ai_tool_tier("auto_writer"), 1)

func test_upgrade_deducts_money():
	state.money = 5000.0
	var auto_writer = manager.get_tool("auto_writer")
	manager.try_upgrade(auto_writer, state)
	assert_lt(state.money, 5000.0, "Money should decrease after upgrade")

func test_cannot_upgrade_without_money():
	state.money = 0.0
	var auto_writer = manager.get_tool("auto_writer")
	var result = manager.try_upgrade(auto_writer, state)
	assert_false(result, "Should not upgrade without money")
	assert_eq(state.get_ai_tool_tier("auto_writer"), 0)

func test_cannot_exceed_max_tier():
	state.money = 999999.0
	var tool = manager.get_tool("merge_resolver")  # max_tier = 4
	for i in range(tool.max_tier + 3):
		manager.try_upgrade(tool, state)
	assert_eq(state.get_ai_tool_tier(tool.id), tool.max_tier)

func test_cost_scales_with_tier():
	var auto_writer = manager.get_tool("auto_writer")
	var cost_t0 = auto_writer.get_cost_for_tier(0)
	var cost_t1 = auto_writer.get_cost_for_tier(1)
	assert_gt(cost_t1, cost_t0, "Higher tier should cost more")

func test_reliability_increases_with_tier():
	var auto_writer = manager.get_tool("auto_writer")
	var rel_t1 = auto_writer.get_reliability_at_tier(1)
	var rel_t3 = auto_writer.get_reliability_at_tier(3)
	assert_gt(rel_t3, rel_t1, "Higher tier should be more reliable")

func test_cooldown_decreases_with_tier():
	var auto_writer = manager.get_tool("auto_writer")
	var cd_t1 = auto_writer.get_cooldown_at_tier(1)
	var cd_t3 = auto_writer.get_cooldown_at_tier(3)
	assert_lt(cd_t3, cd_t1, "Higher tier should have shorter cooldown")

func test_runner_does_nothing_when_idle():
	var runner = load("res://src/logic/ai_tool_runner.gd").new(manager)
	state.set_ai_tool_tier("auto_writer", 3)
	var tab = CodingTab.new()
	# Loop is IDLE, runner should not crash or change state
	runner.tick(1.0, [tab], 0, state)
	assert_eq(tab.coding_loop.state, CodingLoop.State.IDLE)

func test_runner_progresses_writing():
	seed(42)
	var runner = load("res://src/logic/ai_tool_runner.gd").new(manager)
	state.set_ai_tool_tier("auto_writer", 5)  # High tier = high reliability
	var tab = CodingTab.new()
	var task = load("res://src/data/coding_task.gd").new()
	task.total_clicks = 5
	tab.coding_loop.start_task(task)
	# Tick enough times for cooldown to expire and auto_writer to act
	for i in range(30):
		runner.tick(1.0, [tab], 0, state)
	# Progress should have advanced (auto_writer clicked at least once)
	assert_gt(tab.coding_loop.progress, 0.0, "Copilot should have made some progress")

func test_ai_merger_auto_merges_and_resolves_chunks():
	state.money = 999999.0
	var merge_tool = manager.get_tool("merge_resolver")
	for i in range(merge_tool.max_tier):
		manager.try_upgrade(merge_tool, state)
	var tab = CodingTab.new()
	var task = load("res://src/data/coding_task.gd").new()
	task.difficulty = 1
	task.total_clicks = 1
	tab.coding_loop.start_task(task)
	tab.coding_loop.state = CodingLoop.State.CONFLICT
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = "local"
	conflict.chunks = [chunk]
	conflict.chunk_positions = [0]
	tab.coding_loop.merge_conflict = conflict
	var runner = load("res://src/logic/ai_tool_runner.gd").new(manager)
	for i in range(10):
		runner.tick(1.0, [tab], 0, state)
	assert_ne(tab.coding_loop.state, CodingLoop.State.CONFLICT,
		"AI should have resolved the conflict")
