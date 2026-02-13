extends PanelContainer

signal close_requested
signal fire_consultant(consultant: ConsultantData)
signal train_consultant(consultant: ConsultantData, skill_id: String)
signal stop_training_consultant(consultant: ConsultantData)
signal set_remote(consultant: ConsultantData, remote: bool)

const COMMON_SKILLS = ["javascript", "python", "devops", "frameworks", "coding_speed", "code_quality"]

@onready var _card_list: VBoxContainer = %CardList
@onready var _summary_label: Label = %SummaryLabel
@onready var _close_btn: Button = %CloseBtn

func _ready():
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	UITheme.style_button(_close_btn)
	_close_btn.pressed.connect(func(): close_requested.emit())

func refresh():
	_update_summary()
	_rebuild_cards()

func _update_summary():
	var staff_count = GameState.consultants.size()
	var desks = GameState.desk_capacity
	var total_salary = GameState.get_total_salary()
	_summary_label.text = "Staff: %d | Desks: %d | Total salary: $%.0f/period" % [staff_count, desks, total_salary]

func _rebuild_cards():
	for child in _card_list.get_children():
		child.queue_free()

	for consultant in GameState.consultants:
		var card = _create_consultant_row(consultant)
		_card_list.add_child(card)

	if GameState.consultants.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No staff hired yet."
		empty_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		_card_list.add_child(empty_label)

func _create_consultant_row(c: ConsultantData) -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Name + trait
	var name_label = Label.new()
	name_label.text = "%s — %s" % [c.name, c.get_trait_label()]
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Skills with levels (showing decimal)
	if not c.skills.is_empty():
		var skill_parts: Array = []
		for skill_id in c.skills:
			var level = c.skills[skill_id]
			skill_parts.append("%s Lv%.1f" % [skill_id, level])
		var skills_label = Label.new()
		skills_label.text = "Skills: %s" % ", ".join(skill_parts)
		skills_label.add_theme_font_size_override("font_size", 12)
		skills_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
		vbox.add_child(skills_label)

	# Status line
	var status_label = Label.new()
	status_label.text = _get_status_text(c)
	status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(status_label)

	# Action buttons (only for available consultants)
	if c.is_available():
		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 4)
		vbox.add_child(btn_row)

		# Train toggle
		if c.training_skill != "":
			var stop_btn = Button.new()
			stop_btn.text = "Stop Training"
			stop_btn.pressed.connect(func(): stop_training_consultant.emit(c); refresh())
			btn_row.add_child(stop_btn)
		else:
			var train_btn = Button.new()
			train_btn.text = "Train..."
			train_btn.pressed.connect(func():
				var default_skill = _get_default_training_skill(c)
				train_consultant.emit(c, default_skill)
				refresh()
			)
			btn_row.add_child(train_btn)

		# Remote toggle
		if c.location == ConsultantData.Location.REMOTE:
			var office_btn = Button.new()
			office_btn.text = "Bring to Office"
			office_btn.pressed.connect(func(): set_remote.emit(c, false); refresh())
			btn_row.add_child(office_btn)
		else:
			var remote_btn = Button.new()
			remote_btn.text = "Send Remote"
			remote_btn.pressed.connect(func(): set_remote.emit(c, true); refresh())
			btn_row.add_child(remote_btn)

		# Fire button
		var fire_btn = Button.new()
		fire_btn.text = "Fire"
		fire_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		fire_btn.pressed.connect(func(): fire_consultant.emit(c); refresh())
		btn_row.add_child(fire_btn)

	return card

func _get_status_text(c: ConsultantData) -> String:
	match c.location:
		ConsultantData.Location.IN_OFFICE:
			if c.training_skill != "":
				return "📖 Training: %s" % c.training_skill
			return "📱 Idle (In Office)"
		ConsultantData.Location.REMOTE:
			if c.training_skill != "":
				return "🏠 Remote — Training: %s" % c.training_skill
			return "🏠 Remote..."
		ConsultantData.Location.ON_PROJECT:
			var info = _find_assignment_info(c)
			if info:
				return "💼 On Project: %s (Task %d/%d)" % [info["client"], info["current"], info["total"]]
			return "💼 On Project"
		ConsultantData.Location.ON_RENTAL:
			var info = _find_rental_info(c)
			if info:
				return "🏢 On Rental: %s (%.0f min left)" % [info["client"], info["remaining"] / 60.0]
			return "🏢 On Rental"
	return "Unknown"

func _find_assignment_info(c: ConsultantData) -> Variant:
	for assignment in GameState.active_assignments:
		for team_member in assignment.consultants:
			if team_member.id == c.id:
				return {
					"client": assignment.contract.client_name,
					"current": assignment.current_task_index + 1,
					"total": assignment.contract.task_count,
				}
	return null

func _find_rental_info(c: ConsultantData) -> Variant:
	for rental in GameState.active_rentals:
		if rental.consultant and rental.consultant.id == c.id:
			return {
				"client": rental.client_name,
				"remaining": rental.duration_remaining,
			}
	return null

func _get_default_training_skill(c: ConsultantData) -> String:
	# Pick the first common skill that the consultant doesn't have or has lowest level
	var best_skill = COMMON_SKILLS[0]
	var lowest_level: float = INF
	for skill_id in COMMON_SKILLS:
		var level = float(c.skills.get(skill_id, 0))
		if level < lowest_level:
			lowest_level = level
			best_skill = skill_id
	return best_skill
