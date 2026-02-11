extends GutTest

var loop

func before_each():
	loop = load("res://src/logic/coding_loop.gd").new()

func test_initial_state_is_idle():
	assert_eq(loop.state, loop.State.IDLE)

func test_start_task_enters_writing():
	var task = CodingTask.new()
	task.total_clicks = 5
	loop.start_task(task)
	assert_eq(loop.state, loop.State.WRITING)

func test_click_increases_progress():
	var task = CodingTask.new()
	task.total_clicks = 10
	loop.start_task(task)
	loop.perform_click(1.0)
	assert_gt(loop.progress, 0.0)

func test_writing_completes_at_full_progress():
	var task = CodingTask.new()
	task.total_clicks = 3
	task.difficulty = 1
	loop.start_task(task)
	# Force past writing phase
	for i in range(5):
		loop.perform_click(1.0)
	assert_ne(loop.state, loop.State.WRITING, "Should have left WRITING state")

func test_click_power_affects_progress():
	var task = CodingTask.new()
	task.total_clicks = 10
	loop.start_task(task)
	loop.perform_click(1.0)
	var normal_progress = loop.progress

	loop.reset()
	loop.start_task(task)
	loop.perform_click(3.0)
	assert_gt(loop.progress, normal_progress, "Higher click power = more progress")

func test_complete_task_returns_to_idle():
	var task = CodingTask.new()
	task.total_clicks = 1
	task.difficulty = 1
	loop.start_task(task)
	# Force completion through all phases
	loop.force_complete()
	assert_eq(loop.state, loop.State.IDLE)

func test_review_approved_skips_to_merge_check():
	var task = CodingTask.new()
	task.total_clicks = 1
	task.difficulty = 1
	loop.start_task(task)
	# Force to review state
	loop.progress = 1.0
	loop._advance_from_writing()
	assert_eq(loop.state, loop.State.REVIEWING)
	# Simulate approval
	loop.resolve_review(true)
	# Should be in CONFLICT check or COMPLETE
	assert_true(
		loop.state == loop.State.CONFLICT or loop.state == loop.State.COMPLETE,
		"After review approval should check for conflict or complete"
	)

func test_review_rejected_stays_in_review():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.progress = 1.0
	loop._advance_from_writing()
	loop.resolve_review(false)
	assert_eq(loop.state, loop.State.FIXING, "Rejection should enter FIXING state")

func test_conflict_resolution():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	loop._setup_conflict()
	var correct = loop.conflict_correct_side
	loop.resolve_conflict(correct)
	assert_eq(loop.state, loop.State.COMPLETE)

func test_wrong_conflict_pick_adds_penalty():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	loop._setup_conflict()
	var wrong = "right" if loop.conflict_correct_side == "left" else "left"
	loop.resolve_conflict(wrong)
	assert_eq(loop.state, loop.State.FIXING, "Wrong pick should require fixing")
