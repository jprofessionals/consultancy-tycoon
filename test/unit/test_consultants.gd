extends GutTest

var manager: ConsultantManager
var state: Node

func before_each():
	manager = load("res://src/logic/consultant_manager.gd").new()
	state = load("res://src/autoload/game_state.gd").new()
	add_child_autofree(state)

func test_generate_job_market():
	var market = manager.generate_job_market(3, 50.0)
	assert_eq(market.size(), 3, "Should generate requested count")

func test_consultant_has_required_fields():
	var market = manager.generate_job_market(1, 50.0)
	var c = market[0]
	assert_ne(c.name, "", "Should have a name")
	assert_gt(c.salary, 0.0, "Should have positive salary")
	assert_gt(c.skills.size(), 0, "Should have at least one skill")

func test_hire_with_enough_money():
	state.money = 5000.0
	var market = manager.generate_job_market(1, 50.0)
	var c = market[0]
	var result = manager.try_hire(c, state)
	assert_true(result, "Should hire with enough money")
	assert_eq(state.consultants.size(), 1)

func test_hire_deducts_money():
	state.money = 5000.0
	var market = manager.generate_job_market(1, 50.0)
	var c = market[0]
	manager.try_hire(c, state)
	assert_lt(state.money, 5000.0, "Money should decrease after hire")

func test_cannot_hire_without_money():
	state.money = 0.0
	var market = manager.generate_job_market(1, 50.0)
	var c = market[0]
	var result = manager.try_hire(c, state)
	assert_false(result, "Should not hire without money")
	assert_eq(state.consultants.size(), 0)

func test_assignment_ticks_progress():
	state.money = 10000.0
	var c = ConsultantData.new()
	c.id = "test1"
	c.name = "Test Dev"
	c.skills = {"javascript": 3}
	c.salary = 500.0
	c.trait_id = "fast"
	c.morale = 1.0
	state.add_consultant(c)

	var contract = ClientContract.new()
	contract.client_name = "TestCo"
	contract.tier = 1
	contract.task_count = 1
	contract.payout_per_task = 100.0
	contract.required_skills = {"javascript": 1}

	var assignment = manager.create_assignment(contract, [c], state)
	assert_eq(state.active_assignments.size(), 1)

	# Tick until task completes
	var completed = []
	for i in range(100):
		completed = manager.tick_assignments(0.1, state)
		if not completed.is_empty():
			break
	assert_gt(completed.size(), 0, "Assignment should complete eventually")

func test_assignment_earns_money():
	var starting_money = 10000.0
	state.money = starting_money
	var c = ConsultantData.new()
	c.id = "test2"
	c.name = "Test Dev 2"
	c.skills = {"python": 3}
	c.salary = 500.0
	c.trait_id = "careful"
	c.morale = 1.0
	state.add_consultant(c)

	var contract = ClientContract.new()
	contract.client_name = "TestCo2"
	contract.tier = 1
	contract.task_count = 1
	contract.payout_per_task = 200.0
	contract.required_skills = {}

	manager.create_assignment(contract, [c], state)
	for i in range(100):
		manager.tick_assignments(0.1, state)
	# Should have earned 70% of 200 = 140
	assert_gt(state.money, starting_money, "Should have earned money from assignment")

func test_pay_salaries():
	state.money = 5000.0
	var c = ConsultantData.new()
	c.id = "test3"
	c.name = "Test Dev 3"
	c.salary = 800.0
	c.trait_id = "social"
	c.morale = 1.0
	state.add_consultant(c)

	var paid = manager.pay_salaries(state)
	assert_eq(paid, 800.0)
	assert_eq(state.money, 4200.0)

func test_consultant_skill_match():
	var c = ConsultantData.new()
	c.skills = {"javascript": 3, "python": 2}
	var match_score = c.get_skill_match({"javascript": 2})
	assert_gt(match_score, 1.0, "Should exceed 1.0 when overqualified")

func test_consultant_skill_match_empty():
	var c = ConsultantData.new()
	c.skills = {"javascript": 3}
	var match_score = c.get_skill_match({})
	assert_eq(match_score, 1.0, "Empty requirements should return 1.0")
