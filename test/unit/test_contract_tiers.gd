extends GutTest

var bidding: BiddingSystem

func before_each():
	bidding = BiddingSystem.new()

func test_personal_contracts_are_tier_1_and_2():
	var contracts = bidding.generate_personal_contracts(10, 80.0)
	for c in contracts:
		assert_lte(c.tier, 2, "Personal contracts should be tier 1-2")

func test_management_contracts_are_tier_2_and_above():
	var contracts = bidding.generate_management_contracts(10, 80.0)
	for c in contracts:
		assert_gte(c.tier, 2, "Management contracts should be tier 2+")

func test_management_contracts_have_more_tasks():
	var personal = bidding.generate_personal_contracts(20, 80.0)
	var management = bidding.generate_management_contracts(20, 80.0)
	var avg_personal = 0.0
	for c in personal:
		avg_personal += c.task_count
	avg_personal /= personal.size()
	var avg_management = 0.0
	for c in management:
		avg_management += c.task_count
	avg_management /= management.size()
	assert_gt(avg_management, avg_personal, "Management contracts should have more tasks")

func test_existing_generate_contracts_still_works():
	var contracts = bidding.generate_contracts(5, 50.0)
	assert_eq(contracts.size(), 5)
