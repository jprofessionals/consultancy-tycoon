extends PanelContainer

signal close_requested

var consultant_manager: ConsultantManager = ConsultantManager.new()
var job_market: Array = []

@onready var _card_list: VBoxContainer = %CardList
@onready var _capacity_label: Label = %CapacityLabel
@onready var _close_btn: Button = %CloseBtn
@onready var _refresh_btn: Button = %RefreshBtn

func _ready():
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	UITheme.style_button(_close_btn)
	_close_btn.pressed.connect(func(): close_requested.emit())
	_refresh_btn.pressed.connect(func(): refresh())

func refresh():
	job_market = consultant_manager.generate_job_market(4, GameState.reputation)
	_update_capacity_label()
	_rebuild_cards()

func _update_capacity_label():
	var current = GameState.consultants.size()
	var max_staff = GameState.get_max_staff()
	var desks = GameState.desk_capacity
	_capacity_label.text = "Staff: %d / %d (Desks: %d)" % [current, max_staff, desks]

func _rebuild_cards():
	for child in _card_list.get_children():
		child.queue_free()

	for candidate in job_market:
		var card = _create_candidate_card(candidate)
		_card_list.add_child(card)

func _create_candidate_card(candidate: ConsultantData) -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Name + trait
	var name_label = Label.new()
	name_label.text = "%s — %s" % [candidate.name, candidate.get_trait_label()]
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Skills
	if not candidate.skills.is_empty():
		var skill_parts: Array = []
		for skill_id in candidate.skills:
			skill_parts.append("%s Lv%d" % [skill_id, candidate.skills[skill_id]])
		var skills_label = Label.new()
		skills_label.text = "Skills: %s" % ", ".join(skill_parts)
		skills_label.add_theme_font_size_override("font_size", 12)
		skills_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
		vbox.add_child(skills_label)

	# Salary + hire fee
	var hire_cost = consultant_manager.get_hire_cost(candidate)
	var cost_label = Label.new()
	cost_label.text = "Salary: $%.0f/period | Hire fee: $%.0f" % [candidate.salary, hire_cost]
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	vbox.add_child(cost_label)

	# Hire button
	var btn_row = HBoxContainer.new()
	vbox.add_child(btn_row)

	var hire_btn = Button.new()
	var already_hired = false
	for c in GameState.consultants:
		if c.id == candidate.id:
			already_hired = true
			break

	if already_hired:
		hire_btn.text = "Hired"
		hire_btn.disabled = true
	elif not GameState.can_hire():
		hire_btn.text = "Full"
		hire_btn.disabled = true
	else:
		hire_btn.text = "Hire ($%.0f)" % hire_cost
		hire_btn.pressed.connect(_on_hire.bind(candidate, hire_btn))

	btn_row.add_child(hire_btn)
	return card

func _on_hire(candidate: ConsultantData, btn: Button):
	var success = consultant_manager.try_hire(candidate, GameState)
	if success:
		btn.text = "Hired"
		btn.disabled = true
		_update_capacity_label()
		# Disable other hire buttons if at capacity
		if not GameState.can_hire():
			_rebuild_cards()
