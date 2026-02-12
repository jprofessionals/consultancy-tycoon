extends PanelContainer

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
	# Background style — flush to edges, semi-transparent dark, bottom border
	var bg = StyleBoxFlat.new()
	bg.bg_color = UITheme.HUD_BG
	bg.set_corner_radius_all(0)
	bg.border_color = UITheme.BORDER
	bg.border_width_bottom = 1
	bg.content_margin_left = 16
	bg.content_margin_right = 16
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8
	add_theme_stylebox_override("panel", bg)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	add_child(hbox)

	money_label = Label.new()
	money_label.text = "$0"
	money_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(money_label)

	reputation_label = Label.new()
	reputation_label.text = "Rep: 0"
	reputation_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(reputation_label)

	ai_label = Label.new()
	ai_label.text = ""
	ai_label.add_theme_font_size_override("font_size", UITheme.BODY)
	ai_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
	hbox.add_child(ai_label)

	team_label = Label.new()
	team_label.text = ""
	team_label.add_theme_font_size_override("font_size", UITheme.BODY)
	team_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	hbox.add_child(team_label)

	stuck_label = Label.new()
	stuck_label.text = ""
	stuck_label.add_theme_font_size_override("font_size", UITheme.BODY)
	stuck_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	hbox.add_child(stuck_label)

	task_label = Label.new()
	task_label.text = ""
	task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(task_label)

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
