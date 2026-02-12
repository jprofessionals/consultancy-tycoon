extends HBoxContainer

var money_label: Label
var reputation_label: Label
var task_label: Label
var ai_label: Label
var team_label: Label
var stuck_label: Label

func _ready():
	_build_ui()
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	_on_money_changed(GameState.money)
	_on_reputation_changed(GameState.reputation)

func _build_ui():
	add_theme_constant_override("separation", 24)

	money_label = Label.new()
	money_label.text = "$0"
	money_label.add_theme_font_size_override("font_size", 20)
	add_child(money_label)

	reputation_label = Label.new()
	reputation_label.text = "Rep: 0"
	reputation_label.add_theme_font_size_override("font_size", 20)
	add_child(reputation_label)

	ai_label = Label.new()
	ai_label.text = ""
	ai_label.add_theme_font_size_override("font_size", 14)
	ai_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
	add_child(ai_label)

	team_label = Label.new()
	team_label.text = ""
	team_label.add_theme_font_size_override("font_size", 14)
	team_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	add_child(team_label)

	stuck_label = Label.new()
	stuck_label.text = ""
	stuck_label.add_theme_font_size_override("font_size", 14)
	stuck_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	add_child(stuck_label)

	task_label = Label.new()
	task_label.text = ""
	task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(task_label)

func _on_money_changed(amount: float):
	money_label.text = "$%.0f" % amount

func _on_reputation_changed(amount: float):
	reputation_label.text = "Rep: %.0f" % amount

func set_task_info(text: String):
	task_label.text = text

func update_ai_info(active_tools: int):
	if active_tools > 0:
		ai_label.text = "AI: %d active" % active_tools
	else:
		ai_label.text = ""

func update_team_info(consultant_count: int, assignment_count: int):
	if consultant_count > 0:
		team_label.text = "Team: %d (%d jobs)" % [consultant_count, assignment_count]
	else:
		team_label.text = ""

func update_stuck_count(count: int):
	if count > 0:
		stuck_label.text = "STUCK: %d" % count
	else:
		stuck_label.text = ""
