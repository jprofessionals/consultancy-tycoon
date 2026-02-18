extends PanelContainer

signal leaderboard_pressed
signal profile_pressed

@onready var money_label: Label = %MoneyLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var task_label: Label = %TaskLabel
@onready var ai_label: Label = %AiLabel
@onready var team_label: Label = %TeamLabel
@onready var stuck_label: Label = %StuckLabel
@onready var leaderboard_btn: Button = %LeaderboardBtn
@onready var profile_btn: Button = %ProfileBtn

func _ready():
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

	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	leaderboard_btn.pressed.connect(func(): leaderboard_pressed.emit())
	profile_btn.pressed.connect(func(): profile_pressed.emit())
	_on_money_changed(GameState.money)
	_on_reputation_changed(GameState.reputation)

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
