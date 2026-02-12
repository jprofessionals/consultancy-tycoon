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

func test_conflict_has_merge_conflict_data():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	loop._setup_conflict()
	assert_not_null(loop.merge_conflict, "Should have merge_conflict set")
	assert_gt(loop.merge_conflict.chunks.size(), 0, "Should have at least one chunk")

func test_auto_merge_sets_flag():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	loop._setup_conflict()
	loop.auto_merge()
	assert_true(loop.merge_conflict.auto_merged)

func test_resolve_single_chunk_completes():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	loop._setup_conflict()
	loop.auto_merge()
	# Tier 1 = 1 chunk, any resolution valid
	loop.resolve_merge_chunk("local")
	assert_eq(loop.state, loop.State.COMPLETE)

func test_wrong_chunk_resolution_causes_fixing():
	var task = CodingTask.new()
	task.difficulty = 5
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	# Manually set up a conflict with a tricky chunk
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = "remote"
	conflict.chunks = [chunk]
	conflict.chunk_positions = [0]
	loop.merge_conflict = conflict
	loop.auto_merge()
	loop.resolve_merge_chunk("local")  # wrong choice
	assert_eq(loop.state, loop.State.FIXING)
	assert_gt(loop.review_changes_needed, 0)

func test_resolve_merge_chunk_advances_to_next():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	# Set up 2 easy chunks
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1", "line2"]
	var chunk1 = ConflictChunk.new()
	chunk1.local_lines = ["l1"]
	chunk1.remote_lines = ["r1"]
	chunk1.correct_resolution = ""
	var chunk2 = ConflictChunk.new()
	chunk2.local_lines = ["l2"]
	chunk2.remote_lines = ["r2"]
	chunk2.correct_resolution = ""
	conflict.chunks = [chunk1, chunk2]
	conflict.chunk_positions = [0, 1]
	loop.merge_conflict = conflict
	loop.auto_merge()
	loop.resolve_merge_chunk("local")
	# Still in CONFLICT because chunk2 unresolved
	assert_eq(loop.state, loop.State.CONFLICT)
	loop.resolve_merge_chunk("remote")
	assert_eq(loop.state, loop.State.COMPLETE)
