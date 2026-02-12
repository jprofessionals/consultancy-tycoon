extends GutTest

var manager: EventManager
var state: Node

func before_each():
	manager = EventManager.new()
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func test_initial_no_pending_events():
	assert_eq(manager.get_unread_count(), 0)

func test_generate_event_returns_random_event():
	var event = manager.generate_event()
	assert_not_null(event)
	assert_true(event is RandomEvent)
	assert_true(event.title.length() > 0)

func test_generate_event_adds_to_pending():
	manager.generate_event()
	assert_eq(manager.get_unread_count(), 1)
	manager.generate_event()
	assert_eq(manager.get_unread_count(), 2)

func test_event_has_choices():
	var event = manager.generate_event()
	assert_true(event.choices.size() >= 1)

func test_apply_choice_add_money():
	var event = RandomEvent.create("test", "Test", "Desc", [
		{ "label": "Get paid", "effects": [{ "type": "add_money", "amount": 500.0 }] }
	])
	manager.pending_events.append(event)
	manager.apply_choice(event, 0, state)
	assert_eq(state.money, 500.0)

func test_apply_choice_spend_money():
	state.add_money(1000.0)
	var event = RandomEvent.create("test", "Test", "Desc", [
		{ "label": "Pay up", "effects": [{ "type": "spend_money", "amount": 200.0 }] }
	])
	manager.pending_events.append(event)
	manager.apply_choice(event, 0, state)
	assert_eq(state.money, 800.0)

func test_apply_choice_add_reputation():
	var event = RandomEvent.create("test", "Test", "Desc", [
		{ "label": "Gain rep", "effects": [{ "type": "add_reputation", "amount": 15.0 }] }
	])
	manager.pending_events.append(event)
	manager.apply_choice(event, 0, state)
	assert_eq(state.reputation, 15.0)

func test_apply_choice_removes_from_pending():
	var event = manager.generate_event()
	assert_eq(manager.get_unread_count(), 1)
	manager.apply_choice(event, 0, state)
	assert_eq(manager.get_unread_count(), 0)

func test_apply_choice_multiple_effects():
	state.add_money(500.0)
	var event = RandomEvent.create("test", "Test", "Desc", [
		{ "label": "Both", "effects": [
			{ "type": "spend_money", "amount": 100.0 },
			{ "type": "add_reputation", "amount": 20.0 }
		] }
	])
	manager.pending_events.append(event)
	manager.apply_choice(event, 0, state)
	assert_eq(state.money, 400.0)
	assert_eq(state.reputation, 20.0)

func test_apply_invalid_choice_index():
	var event = RandomEvent.create("test", "Test", "Desc", [
		{ "label": "Only choice", "effects": [{ "type": "add_money", "amount": 100.0 }] }
	])
	manager.pending_events.append(event)
	manager.apply_choice(event, 5, state)
	assert_eq(state.money, 0.0)

func test_clear_events():
	manager.generate_event()
	manager.generate_event()
	manager.clear_events()
	assert_eq(manager.get_unread_count(), 0)
