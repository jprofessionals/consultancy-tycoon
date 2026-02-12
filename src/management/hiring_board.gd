extends PanelContainer

signal close_requested

var consultant_manager: ConsultantManager = ConsultantManager.new()
var job_market: Array = []

var _scroll_container: ScrollContainer
var _card_list: VBoxContainer
var _capacity_label: Label

func _ready():
	custom_minimum_size = Vector2(600, 450)
	_apply_panel_style()
	_build_ui()

func _apply_panel_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

func _build_ui():
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "Hiring — Job Market"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Capacity label
	_capacity_label = Label.new()
	_capacity_label.add_theme_font_size_override("font_size", 13)
	_capacity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_capacity_label)

	# Scroll area
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll_container)

	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list.add_theme_constant_override("separation", 6)
	_scroll_container.add_child(_card_list)

	# Refresh Market button
	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh Market"
	refresh_btn.pressed.connect(func(): refresh())
	vbox.add_child(refresh_btn)

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
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.2)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)

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
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
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
