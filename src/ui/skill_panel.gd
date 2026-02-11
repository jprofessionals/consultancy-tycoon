extends PanelContainer

var skill_manager: SkillManager = SkillManager.new()
var skill_list: VBoxContainer

func _ready():
	_build_ui()
	refresh()

func _build_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Skills & Certifications"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	skill_list = VBoxContainer.new()
	skill_list.add_theme_constant_override("separation", 4)
	vbox.add_child(skill_list)

func refresh():
	for child in skill_list.get_children():
		child.queue_free()

	for skill in skill_manager.get_all_skills():
		var row = _create_skill_row(skill)
		skill_list.add_child(row)

func _create_skill_row(skill: SkillData) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var current_level = GameState.get_skill_level(skill.id)

	var name_label = Label.new()
	name_label.text = "%s (Lv %d/%d)" % [skill.name, current_level, skill.max_level]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = skill.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_label)

	var buy_btn = Button.new()
	if current_level >= skill.max_level:
		buy_btn.text = "MAX"
		buy_btn.disabled = true
	else:
		var price = skill.get_cost_for_level(current_level)
		buy_btn.text = "Buy $%.0f" % price
		buy_btn.pressed.connect(func():
			skill_manager.try_purchase(skill, GameState)
			refresh()
		)
	row.add_child(buy_btn)

	return row
