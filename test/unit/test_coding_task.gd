extends GutTest

func test_task_creation():
	var task = load("res://src/data/coding_task.gd").new()
	task.title = "Fix auth bug"
	task.difficulty = 2
	task.payout = 50.0
	task.total_clicks = 10
	assert_eq(task.title, "Fix auth bug")
	assert_eq(task.difficulty, 2)
	assert_eq(task.payout, 50.0)
	assert_eq(task.total_clicks, 10)

func test_task_review_chance_scales_with_difficulty():
	var task = load("res://src/data/coding_task.gd").new()
	task.difficulty = 1
	var easy_chance = task.get_review_reject_chance()
	task.difficulty = 5
	var hard_chance = task.get_review_reject_chance()
	assert_gt(hard_chance, easy_chance, "Harder tasks should have higher reject chance")

func test_task_conflict_chance_scales_with_difficulty():
	var task = load("res://src/data/coding_task.gd").new()
	task.difficulty = 1
	var easy_chance = task.get_conflict_chance()
	task.difficulty = 5
	var hard_chance = task.get_conflict_chance()
	assert_gt(hard_chance, easy_chance, "Harder tasks should have higher conflict chance")

func test_task_factory_generates_valid_task():
	var factory = load("res://src/data/task_factory.gd").new()
	var task = factory.generate_task(1)
	assert_ne(task.title, "", "Task should have a title")
	assert_gt(task.payout, 0.0, "Task should have positive payout")
	assert_gt(task.total_clicks, 0, "Task should require clicks")

func test_task_factory_harder_tiers_pay_more():
	var factory = load("res://src/data/task_factory.gd").new()
	var easy = factory.generate_task(1)
	var hard = factory.generate_task(5)
	assert_gt(hard.payout, easy.payout, "Higher tier should pay more")
