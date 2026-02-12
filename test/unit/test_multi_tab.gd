extends GutTest

var manager: AiToolManager
var state: Node

func before_each():
	manager = AiToolManager.new()
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

# ── Tab Limit ──

func test_tab_limit_no_ai():
	assert_eq(manager.get_tab_limit(state), 1, "No AI = 1 tab")

func test_tab_limit_tier_1():
	state.set_ai_tool_tier("auto_writer", 1)
	assert_eq(manager.get_tab_limit(state), 2)

func test_tab_limit_tier_3():
	state.set_ai_tool_tier("auto_writer", 3)
	assert_eq(manager.get_tab_limit(state), 4)

func test_tab_limit_tier_5():
	state.set_ai_tool_tier("auto_writer", 5)
	assert_eq(manager.get_tab_limit(state), 6)

# ── Runner Ticks Multiple Tabs ──

func test_runner_ticks_multiple_tabs():
	seed(42)
	var runner = AiToolRunner.new(manager)
	state.set_ai_tool_tier("auto_writer", 5)

	var tab1 = CodingTab.new()
	var task1 = CodingTask.new()
	task1.total_clicks = 100
	tab1.coding_loop.start_task(task1)

	var tab2 = CodingTab.new()
	var task2 = CodingTask.new()
	task2.total_clicks = 100
	tab2.coding_loop.start_task(task2)

	# Tick many times so both tabs get attention
	for i in range(50):
		runner.tick(1.0, [tab1, tab2], 0, state)

	assert_gt(tab1.coding_loop.progress, 0.0, "Tab 1 should have progress")
	assert_gt(tab2.coding_loop.progress, 0.0, "Tab 2 should have progress")

# ── Stuck Tab Skipped ──

func test_stuck_tab_skipped_by_ai():
	seed(42)
	var runner = AiToolRunner.new(manager)
	state.set_ai_tool_tier("auto_writer", 5)

	var tab1 = CodingTab.new()
	tab1.stuck = true
	var task1 = CodingTask.new()
	task1.total_clicks = 10
	tab1.coding_loop.start_task(task1)

	var tab2 = CodingTab.new()
	var task2 = CodingTask.new()
	task2.total_clicks = 10
	tab2.coding_loop.start_task(task2)

	for i in range(20):
		runner.tick(1.0, [tab1, tab2], 1, state)

	assert_eq(tab1.coding_loop.progress, 0.0, "Stuck tab should have no progress")
	assert_gt(tab2.coding_loop.progress, 0.0, "Non-stuck tab should have progress")

# ── CodingTab ──

func test_coding_tab_label():
	var tab = CodingTab.new()
	var contract = ClientContract.new()
	contract.client_name = "Acme Corp"
	tab.contract = contract
	tab.task_index = 2
	tab.total_tasks = 5
	assert_eq(tab.get_tab_label(), "Acme Corp (3/5)")

func test_coding_tab_is_contract_done():
	var tab = CodingTab.new()
	tab.task_index = 0
	tab.total_tasks = 3
	assert_false(tab.is_contract_done())
	tab.task_index = 3
	assert_true(tab.is_contract_done())

func test_coding_tab_defaults():
	var tab = CodingTab.new()
	assert_false(tab.stuck)
	assert_eq(tab.task_index, 0)
	assert_eq(tab.total_tasks, 0)
	assert_not_null(tab.coding_loop)
	assert_eq(tab.coding_loop.state, CodingLoop.State.IDLE)
