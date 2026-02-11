extends HBoxContainer

var money_label: Label
var reputation_label: Label
var task_label: Label

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
