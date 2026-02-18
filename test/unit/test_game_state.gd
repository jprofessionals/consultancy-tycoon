extends GutTest

var state: Node

func before_each():
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func test_initial_money_is_zero():
	assert_eq(state.money, 0.0)

func test_add_money():
	state.add_money(100.0)
	assert_eq(state.money, 100.0)

func test_spend_money_success():
	state.add_money(200.0)
	var result = state.spend_money(150.0)
	assert_true(result)
	assert_eq(state.money, 50.0)

func test_spend_money_insufficient():
	state.add_money(50.0)
	var result = state.spend_money(100.0)
	assert_false(result)
	assert_eq(state.money, 50.0)

func test_initial_reputation_is_zero():
	assert_eq(state.reputation, 0.0)

func test_add_reputation():
	state.add_reputation(10.0)
	assert_eq(state.reputation, 10.0)

func test_initial_total_money_earned_is_zero():
	assert_eq(state.total_money_earned, 0.0)

func test_add_money_tracks_total_earned():
	state.add_money(100.0)
	state.add_money(50.0)
	assert_eq(state.total_money_earned, 150.0)

func test_spending_does_not_reduce_total_earned():
	state.add_money(200.0)
	state.spend_money(100.0)
	assert_eq(state.total_money_earned, 200.0)

func test_negative_add_money_does_not_track_earned():
	state.add_money(100.0)
	state.add_money(-50.0)
	assert_eq(state.total_money_earned, 100.0)

func test_initial_manual_tasks_completed_is_zero():
	assert_eq(state.total_manual_tasks_completed, 0)

func test_increment_manual_tasks():
	state.increment_manual_tasks()
	state.increment_manual_tasks()
	assert_eq(state.total_manual_tasks_completed, 2)

func test_initial_player_name_empty():
	assert_eq(state.player_name, "")

func test_get_score_components():
	state.total_money_earned = 10000.0
	state.reputation = 20.0
	state.skills = {"javascript": 3, "python": 2}
	state.ai_tools = {"auto_writer": 2, "auto_reviewer": 1}
	state.total_manual_tasks_completed = 10
	var c1 = ConsultantData.new()
	c1.id = "score_1"
	state.consultants.append(c1)
	var c2 = ConsultantData.new()
	c2.id = "score_2"
	state.consultants.append(c2)

	var components = state.get_score_components()

	assert_almost_eq(components["total_money_earned"], 10000.0, 0.01)
	assert_almost_eq(components["reputation"], 20.0, 0.01)
	assert_eq(components["skill_levels_sum"], 5)
	assert_eq(components["consultants_count"], 2)
	assert_eq(components["ai_tool_tiers_sum"], 3)
	assert_eq(components["manual_tasks_completed"], 10)
