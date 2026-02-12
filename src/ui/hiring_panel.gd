extends PanelContainer

var consultant_manager: ConsultantManager = ConsultantManager.new()
var _job_market: Array = []
var _content: VBoxContainer
var _tab: String = "market"  # "market", "team", "assignments"

signal close_requested
signal assign_team_to_contract(consultants: Array)

func _ready():
	_build_ui()
	refresh()

func _build_ui():
	custom_minimum_size = Vector2(580, 450)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.13, 0.16)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.35, 0.3, 0.2)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "Team Management"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Tab buttons
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	vbox.add_child(tabs)

	for tab_id in ["market", "team", "assignments"]:
		var btn = Button.new()
		btn.text = tab_id.capitalize()
		btn.pressed.connect(_switch_tab.bind(tab_id))
		tabs.add_child(btn)

	# Content area
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_content)

func _switch_tab(tab_id: String):
	_tab = tab_id
	refresh()

func refresh():
	for child in _content.get_children():
		child.queue_free()

	if not GameState.office_unlocked:
		_show_unlock_prompt()
		return

	match _tab:
		"market":
			_show_market()
		"team":
			_show_team()
		"assignments":
			_show_assignments()

func _show_unlock_prompt():
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(vbox)

	var label = Label.new()
	label.text = "You need an office to hire a team."
	label.add_theme_font_size_override("font_size", 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var cost_label = Label.new()
	cost_label.text = "Office space: $%.0f" % ConsultantManager.OFFICE_UNLOCK_COST
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_label)

	var unlock_btn = Button.new()
	unlock_btn.text = "Unlock Office — $%.0f" % ConsultantManager.OFFICE_UNLOCK_COST
	unlock_btn.custom_minimum_size = Vector2(250, 44)
	unlock_btn.pressed.connect(func():
		if GameState.spend_money(ConsultantManager.OFFICE_UNLOCK_COST):
			GameState.unlock_office()
			refresh()
	)
	vbox.add_child(unlock_btn)

func _show_market():
	if _job_market.is_empty():
		_job_market = consultant_manager.generate_job_market(4, GameState.reputation)

	var info = Label.new()
	info.text = "Available candidates (refreshes with new contracts):"
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_content.add_child(info)

	for c in _job_market:
		_content.add_child(_create_candidate_card(c))

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh Market"
	refresh_btn.pressed.connect(func():
		_job_market = consultant_manager.generate_job_market(4, GameState.reputation)
		refresh()
	)
	_content.add_child(refresh_btn)

func _create_candidate_card(c: ConsultantData) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.17, 0.17, 0.21)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label = Label.new()
	name_label.text = "%s — %s" % [c.name, c.get_trait_label()]
	info.add_child(name_label)

	var skills_text = ", ".join(c.skills.keys().map(func(k): return "%s Lv%d" % [k, c.skills[k]]))
	var detail_label = Label.new()
	detail_label.text = "Skills: %s | Salary: $%.0f/period" % [skills_text, c.salary]
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	info.add_child(detail_label)

	var hire_btn = Button.new()
	var already_hired = false
	for existing in GameState.consultants:
		if existing.id == c.id:
			already_hired = true
			break
	if already_hired:
		hire_btn.text = "Hired"
		hire_btn.disabled = true
	else:
		var cost = consultant_manager.get_hire_cost(c)
		hire_btn.text = "Hire $%.0f" % cost
		hire_btn.pressed.connect(func():
			consultant_manager.try_hire(c, GameState)
			refresh()
		)
	hire_btn.custom_minimum_size = Vector2(100, 36)
	hbox.add_child(hire_btn)

	return card

func _show_team():
	if GameState.consultants.is_empty():
		var label = Label.new()
		label.text = "No consultants hired yet. Check the Market tab."
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_content.add_child(label)
		return

	var salary_label = Label.new()
	salary_label.text = "Total salary: $%.0f per pay period" % GameState.get_total_salary()
	salary_label.add_theme_font_size_override("font_size", 13)
	salary_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	_content.add_child(salary_label)

	for c in GameState.consultants:
		_content.add_child(_create_team_member_card(c))

func _create_team_member_card(c: ConsultantData) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.17, 0.17, 0.21)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label = Label.new()
	name_label.text = "%s — %s" % [c.name, c.get_trait_label()]
	info.add_child(name_label)

	var skills_text = ", ".join(c.skills.keys().map(func(k): return "%s Lv%d" % [k, c.skills[k]]))
	var detail_label = Label.new()
	detail_label.text = "Skills: %s | Morale: %.0f%% | Salary: $%.0f" % [skills_text, c.morale * 100, c.salary]
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	info.add_child(detail_label)

	var fire_btn = Button.new()
	fire_btn.text = "Fire"
	fire_btn.custom_minimum_size = Vector2(60, 32)
	fire_btn.pressed.connect(func():
		GameState.remove_consultant(c)
		refresh()
	)
	hbox.add_child(fire_btn)

	return card

func _show_assignments():
	if GameState.active_assignments.is_empty():
		var label = Label.new()
		label.text = "No active team assignments. Assign contracts from the Contracts panel."
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(label)
		return

	for assignment in GameState.active_assignments:
		_content.add_child(_create_assignment_card(assignment))

func _create_assignment_card(assignment: ConsultantAssignment) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.17, 0.17, 0.21)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "%s — %s" % [assignment.contract.client_name, assignment.contract.project_description]
	vbox.add_child(title_label)

	var team_names = ", ".join(assignment.consultants.map(func(c): return c.name))
	var team_label = Label.new()
	team_label.text = "Team: %s" % team_names
	team_label.add_theme_font_size_override("font_size", 12)
	team_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(team_label)

	var progress_label = Label.new()
	progress_label.text = "Task %d/%d (%.0f%% progress)" % [
		assignment.current_task_index + 1,
		assignment.get_total_tasks(),
		assignment.current_task_progress * 100
	]
	progress_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(progress_label)

	return card

func refresh_market():
	_job_market = consultant_manager.generate_job_market(4, GameState.reputation)
	if _tab == "market":
		refresh()
