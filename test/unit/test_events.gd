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

# ── Expiry ──

func test_random_event_not_expired_when_fresh():
	var event = RandomEvent.create("test", "Test", "Desc", [])
	assert_false(event.is_expired(event.created_at + 10.0), "Fresh event should not be expired")

func test_random_event_expired_after_timeout():
	var event = RandomEvent.create("test", "Test", "Desc", [])
	assert_true(event.is_expired(event.created_at + RandomEvent.EXPIRY_TIME + 1.0), "Old event should be expired")

func test_management_issue_not_expired_when_fresh():
	var issue = ManagementIssue.create("test", "Test", "Desc", "c1", [])
	assert_false(issue.is_expired(issue.created_at + 10.0), "Fresh issue should not be expired")

func test_management_issue_expired_after_timeout():
	var issue = ManagementIssue.create("test", "Test", "Desc", "c1", [])
	assert_true(issue.is_expired(issue.created_at + ManagementIssue.EXPIRY_TIME + 1.0), "Old issue should be expired")

func test_management_issue_choices_are_positive():
	var cm = ConsultantManager.new()
	var c = ConsultantData.new()
	c.id = "test_pos"
	c.name = "Test Dev"
	c.skills = {"python": 2}
	c.salary = 500.0
	c.trait_id = "fast"
	c.morale = 0.5
	state.consultants.append(c)
	# Force issue generation by calling internal method
	for template in cm._issue_templates:
		for choice in template["choices"]:
			for effect in choice["effects"]:
				if effect["type"] == "morale_change":
					assert_gt(effect["amount"], 0.0, "All morale effects should be positive: %s" % choice["label"])
