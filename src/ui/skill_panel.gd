extends PanelContainer

var skill_manager: SkillManager = SkillManager.new()
var skill_list: VBoxContainer

signal close_requested

func _ready():
	_build_ui()
	refresh()

func _build_ui():
	add_theme_stylebox_override("panel", UITheme.create_panel_style())

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.NORMAL)
	add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "Skills & Certifications"
	title.add_theme_font_size_override("font_size", UITheme.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = UITheme.create_close_button()
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	skill_list = VBoxContainer.new()
	skill_list.add_theme_constant_override("separation", UITheme.TIGHT)
	vbox.add_child(skill_list)

func refresh():
	for child in skill_list.get_children():
		child.queue_free()

	for skill in skill_manager.get_all_skills():
		var row = _create_skill_row(skill)
		skill_list.add_child(row)

func _create_skill_row(skill: SkillData) -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.NORMAL)
	card.add_child(row)

	var current_level = GameState.get_skill_level(skill.id)

	var name_label = Label.new()
	name_label.text = "%s (Lv %d/%d)" % [skill.name, current_level, skill.max_level]
	name_label.add_theme_font_size_override("font_size", UITheme.BODY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = skill.description
	desc_label.add_theme_font_size_override("font_size", UITheme.SMALL)
	desc_label.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_label)

	var buy_btn = Button.new()
	UITheme.style_button(buy_btn)
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

	return card
