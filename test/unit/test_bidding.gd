extends GutTest

func test_contract_creation():
	var contract = load("res://src/data/client_contract.gd").new()
	contract.client_name = "FinApp"
	contract.project_description = "REST API refactor"
	contract.tier = 2
	contract.task_count = 5
	contract.required_skills = {"python": 2}
	assert_eq(contract.client_name, "FinApp")
	assert_eq(contract.tier, 2)

func test_bid_success_high_skill():
	var system = load("res://src/logic/bidding_system.gd").new()
	var contract = load("res://src/data/client_contract.gd").new()
	contract.required_skills = {"python": 2}
	var chance = system.calculate_bid_chance(contract, {"python": 5})
	assert_gt(chance, 0.7, "High skill should give high bid chance")

func test_bid_success_low_skill():
	var system = load("res://src/logic/bidding_system.gd").new()
	var contract = load("res://src/data/client_contract.gd").new()
	contract.required_skills = {"python": 5}
	var chance = system.calculate_bid_chance(contract, {"python": 1})
	assert_lt(chance, 0.4, "Low skill should give low bid chance")

func test_bid_success_no_skill():
	var system = load("res://src/logic/bidding_system.gd").new()
	var contract = load("res://src/data/client_contract.gd").new()
	contract.required_skills = {"python": 3}
	var chance = system.calculate_bid_chance(contract, {})
	assert_lt(chance, 0.2, "No matching skill should give very low chance")

func test_contract_difficulty_modifier():
	var system = load("res://src/logic/bidding_system.gd").new()
	var contract = load("res://src/data/client_contract.gd").new()
	contract.required_skills = {"python": 5}
	var modifier = system.get_difficulty_modifier(contract, {"python": 2})
	assert_gt(modifier, 1.0, "Underskilled should increase difficulty")

func test_generate_contracts():
	var system = load("res://src/logic/bidding_system.gd").new()
	var contracts = system.generate_contracts(3, 5.0)
	assert_eq(contracts.size(), 3)
	for c in contracts:
		assert_ne(c.client_name, "")
		assert_gt(c.task_count, 0)
