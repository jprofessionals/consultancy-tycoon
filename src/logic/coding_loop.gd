extends RefCounted
class_name CodingLoop

enum State { IDLE, WRITING, REVIEWING, FIXING, CONFLICT, COMPLETE }

var state: State = State.IDLE
var progress: float = 0.0
var current_task: CodingTask = null
var review_changes_needed: int = 0
var conflict_correct_side: String = ""

signal state_changed(new_state: State)
signal progress_changed(new_progress: float)
signal review_result(approved: bool, comment: String)
signal conflict_appeared(left_code: String, right_code: String)
signal task_done(task: CodingTask)

func start_task(task: CodingTask) -> void:
	current_task = task
	progress = 0.0
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
	conflict_correct_side = "left" if randi() % 2 == 0 else "right"
	conflict_appeared.emit("<<<< LOCAL\nvar result = validate()", "<<<< REMOTE\nvar result = check()")

func resolve_conflict(chosen_side: String) -> void:
	if state != State.CONFLICT:
		return
	if chosen_side == conflict_correct_side:
		_complete_task()
	else:
		review_changes_needed = 1
		_set_state(State.FIXING)

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

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)
