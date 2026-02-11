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
