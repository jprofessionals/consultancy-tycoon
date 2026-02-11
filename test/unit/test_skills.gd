extends GutTest

var manager

func before_each():
	manager = load("res://src/logic/skill_manager.gd").new()

func test_get_available_skills():
	var skills = manager.get_all_skills()
	assert_gt(skills.size(), 0, "Should have skills defined")

func test_skill_has_required_fields():
	var skills = manager.get_all_skills()
	var skill = skills[0]
	assert_ne(skill.id, "", "Skill should have id")
	assert_ne(skill.name, "", "Skill should have name")
	assert_gt(skill.cost, 0.0, "Skill should have positive cost")
	assert_gt(skill.max_level, 0, "Skill should have max level")

func test_can_purchase_with_enough_money():
	var state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)
	state.money = 500.0
	var skills = manager.get_all_skills()
	var result = manager.try_purchase(skills[0], state)
	assert_true(result, "Should be able to purchase with enough money")

func test_cannot_purchase_without_money():
	var state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)
	state.money = 0.0
	var skills = manager.get_all_skills()
	var result = manager.try_purchase(skills[0], state)
	assert_false(result, "Should not purchase without money")

func test_purchase_increases_skill_level():
	var state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)
	state.money = 500.0
	var skills = manager.get_all_skills()
	manager.try_purchase(skills[0], state)
	assert_eq(state.get_skill_level(skills[0].id), 1)

func test_cannot_exceed_max_level():
	var state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)
	state.money = 99999.0
	var skills = manager.get_all_skills()
	var skill = skills[0]
	for i in range(skill.max_level + 3):
		manager.try_purchase(skill, state)
	assert_eq(state.get_skill_level(skill.id), skill.max_level)

func test_click_power_calculation():
	var state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)
	var base_power = manager.calculate_click_power(state)
	state.set_skill_level("coding_speed", 3)
	var boosted_power = manager.calculate_click_power(state)
	assert_gt(boosted_power, base_power, "Skill should increase click power")
