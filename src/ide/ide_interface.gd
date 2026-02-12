extends PanelContainer

var coding_loop: CodingLoop = CodingLoop.new()
var current_snippet: Array = []
var lines_revealed: int = 0
var click_power: float = 1.0

@onready var code_display: RichTextLabel
@onready var progress_bar: ProgressBar
@onready var action_button: Button
@onready var status_label: Label
@onready var task_label: Label
@onready var review_panel: VBoxContainer
@onready var conflict_panel: HBoxContainer

func _ready():
	_build_ui()
	_connect_signals()

func _build_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title bar
	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)
	var title = Label.new()
	title.text = "  CONSULTANCY IDE v1.0"
	title.add_theme_font_size_override("font_size", 14)
	title_bar.add_child(title)

	# Task label
	task_label = Label.new()
	task_label.text = "No active task"
	vbox.add_child(task_label)

	# Status
	status_label = Label.new()
	status_label.text = "IDLE"
	vbox.add_child(status_label)

	# Code display
	code_display = RichTextLabel.new()
	code_display.bbcode_enabled = true
	code_display.custom_minimum_size = Vector2(0, 300)
	code_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_display.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(code_display)

	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.step = 0.01
	progress_bar.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(progress_bar)

	# Review panel (hidden by default)
	review_panel = VBoxContainer.new()
	review_panel.visible = false
	vbox.add_child(review_panel)

	# Conflict panel (hidden by default)
	conflict_panel = HBoxContainer.new()
	conflict_panel.visible = false
	vbox.add_child(conflict_panel)

	# Action button
	action_button = Button.new()
	action_button.text = "Write Code"
	action_button.custom_minimum_size = Vector2(0, 48)
	action_button.pressed.connect(_on_action_pressed)
	vbox.add_child(action_button)

func _connect_signals():
	coding_loop.state_changed.connect(_on_state_changed)
	coding_loop.progress_changed.connect(_on_progress_changed)
	coding_loop.conflict_appeared.connect(_on_conflict_appeared)
	coding_loop.task_done.connect(_on_task_done)

func start_task(task: CodingTask):
	current_snippet = FakeCode.get_random_snippet()
	lines_revealed = 0
	code_display.text = ""
	progress_bar.value = 0.0
	coding_loop.start_task(task)
	task_label.text = "Task: " + task.title
	_update_ui()

func _on_action_pressed():
	match coding_loop.state:
		CodingLoop.State.WRITING:
			coding_loop.perform_click(click_power)
			_reveal_code_line()
		CodingLoop.State.REVIEWING:
			_do_review()
		CodingLoop.State.FIXING:
			coding_loop.perform_click(click_power)
		CodingLoop.State.IDLE:
			pass  # handled externally (bidding system starts tasks)

func _reveal_code_line():
	if lines_revealed < current_snippet.size():
		var line = current_snippet[lines_revealed]
		var colored = _syntax_highlight(line)
		code_display.append_text(colored + "\n")
		lines_revealed += 1

func _syntax_highlight(line: String) -> String:
	var result = line
	# Keywords
	for kw in ["func", "var", "return", "if", "else", "for", "class", "async", "await", "const"]:
		result = result.replace(kw + " ", "[color=#569cd6]" + kw + "[/color] ")
	# Strings
	var string_regex = RegEx.new()
	string_regex.compile("\"[^\"]*\"")
	for m in string_regex.search_all(result):
		result = result.replace(m.get_string(), "[color=#ce9178]" + m.get_string() + "[/color]")
	return result

func _do_review():
	var reject_chance = coding_loop.current_task.get_review_reject_chance()
	# Player skill reduces reject chance
	var skill_modifier = GameState.get_skill_level("code_quality") * 0.05
	var approved = randf() > (reject_chance - skill_modifier)
	coding_loop.resolve_review(approved)
	if approved:
		_show_review_comment("[color=#4ec9b0]Reviewer:[/color] LGTM! Approved.")
	else:
		_show_review_comment("[color=#f44747]Reviewer:[/color] Changes requested. Please fix.")

func _show_review_comment(text: String):
	for child in review_panel.get_children():
		child.queue_free()
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text
	label.fit_content = true
	label.custom_minimum_size = Vector2(0, 40)
	review_panel.add_child(label)
	review_panel.visible = true

func _on_conflict_appeared(left_code: String, right_code: String):
	conflict_panel.visible = true
	for child in conflict_panel.get_children():
		child.queue_free()

	var left_btn = Button.new()
	left_btn.text = "Accept Local\n" + left_code
	left_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_btn.pressed.connect(func(): coding_loop.resolve_conflict("left"))
	conflict_panel.add_child(left_btn)

	var right_btn = Button.new()
	right_btn.text = "Accept Remote\n" + right_code
	right_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_btn.pressed.connect(func(): coding_loop.resolve_conflict("right"))
	conflict_panel.add_child(right_btn)

func _on_state_changed(new_state: CodingLoop.State):
	_update_ui()

func _on_progress_changed(new_progress: float):
	progress_bar.value = new_progress

func _on_task_done(task: CodingTask):
	GameState.add_money(task.payout)
	GameState.add_reputation(task.difficulty * 1.0)
	status_label.text = "COMPLETE — Earned $%.0f" % task.payout
	review_panel.visible = false
	conflict_panel.visible = false

func _update_ui():
	conflict_panel.visible = false
	review_panel.visible = false
	action_button.visible = true
	match coding_loop.state:
		CodingLoop.State.IDLE:
			status_label.text = "IDLE — Waiting for task"
			action_button.text = "Waiting..."
			action_button.disabled = true
		CodingLoop.State.WRITING:
			status_label.text = "WRITING CODE"
			action_button.text = "Write Code [Click!]"
			action_button.disabled = false
		CodingLoop.State.REVIEWING:
			status_label.text = "CODE REVIEW"
			action_button.text = "Submit for Review"
			action_button.disabled = false
			review_panel.visible = true
		CodingLoop.State.FIXING:
			status_label.text = "FIXING — %d changes remaining" % coding_loop.review_changes_needed
			action_button.text = "Fix Code [Click!]"
			action_button.disabled = false
		CodingLoop.State.CONFLICT:
			status_label.text = "MERGE CONFLICT — Pick a side"
			action_button.visible = false
			conflict_panel.visible = true
		CodingLoop.State.COMPLETE:
			action_button.text = "Complete!"
			action_button.disabled = true

func set_click_power(power: float):
	click_power = power
