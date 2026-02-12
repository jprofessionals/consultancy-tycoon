extends RefCounted
class_name CodingLoop

enum State { IDLE, WRITING, REVIEWING, FIXING, CONFLICT, COMPLETE }

var state: State = State.IDLE
var progress: float = 0.0
var current_task: CodingTask = null
var review_changes_needed: int = 0
var merge_conflict: MergeConflict = null

signal state_changed(new_state: State)
signal progress_changed(new_progress: float)
signal review_result(approved: bool, comment: String)
signal merge_conflict_started(conflict: MergeConflict)
signal merge_auto_merged()
signal merge_chunk_resolved(chunk_index: int, was_correct: bool)
signal task_done(task: CodingTask)

var _conflict_factory: MergeConflictFactory = MergeConflictFactory.new()

func start_task(task: CodingTask) -> void:
	current_task = task
	progress = 0.0
	merge_conflict = null
	_set_state(State.WRITING)

func perform_click(click_power: float) -> void:
	if state == State.WRITING:
		progress += click_power / current_task.total_clicks
		progress_changed.emit(progress)
		if progress >= 1.0:
			progress = 1.0
			_advance_from_writing()
	elif state == State.FIXING:
		review_changes_needed -= 1
		if review_changes_needed <= 0:
			_advance_from_writing()

func _advance_from_writing() -> void:
	_set_state(State.REVIEWING)

func resolve_review(approved: bool) -> void:
	if state != State.REVIEWING:
		return
	if approved:
		_check_for_conflict()
	else:
		review_changes_needed = randi_range(1, 3)
		review_result.emit(false, "Changes requested (%d fixes needed)" % review_changes_needed)
		_set_state(State.FIXING)

func _check_for_conflict() -> void:
	var conflict_chance = current_task.get_conflict_chance()
	if randf() < conflict_chance:
		_set_state(State.CONFLICT)
		_setup_conflict()
	else:
		_complete_task()

func _setup_conflict() -> void:
	var tier = current_task.difficulty
	merge_conflict = _conflict_factory.generate(clampi(tier, 1, 5))
	merge_conflict_started.emit(merge_conflict)

func auto_merge() -> void:
	if state != State.CONFLICT or merge_conflict == null:
		return
	merge_conflict.auto_merged = true
	merge_auto_merged.emit()

func resolve_merge_chunk(resolution: String) -> void:
	if state != State.CONFLICT or merge_conflict == null:
		return
	if not merge_conflict.auto_merged:
		return
	var idx = merge_conflict.get_next_unresolved_index()
	if idx < 0:
		return
	merge_conflict.resolve_chunk(idx, resolution)
	var chunk: ConflictChunk = merge_conflict.chunks[idx]
	var was_correct = chunk.correct_resolution == "" or resolution == chunk.correct_resolution
	merge_chunk_resolved.emit(idx, was_correct)
	if merge_conflict.all_resolved():
		if merge_conflict.has_wrong_resolution():
			review_changes_needed = merge_conflict.get_wrong_count()
			_set_state(State.FIXING)
		else:
			_complete_task()

func _complete_task() -> void:
	_set_state(State.COMPLETE)
	task_done.emit(current_task)

func force_complete() -> void:
	_set_state(State.COMPLETE)
	task_done.emit(current_task)
	reset()

func reset() -> void:
	state = State.IDLE
	progress = 0.0
	current_task = null
	merge_conflict = null

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)
