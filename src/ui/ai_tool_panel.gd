extends PanelContainer

var ai_tool_manager: AiToolManager = AiToolManager.new()
var tool_list: VBoxContainer

signal close_requested

func _ready():
	_build_ui()
	refresh()

func _build_ui():
	custom_minimum_size = Vector2(520, 400)
	add_theme_stylebox_override("panel", UITheme.create_panel_style())

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.NORMAL)
	add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "AI Development Tools"
	title.add_theme_font_size_override("font_size", UITheme.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = UITheme.create_close_button()
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	var desc = Label.new()
	desc.text = "AI tools automate parts of your coding workflow. Higher tiers are faster and more reliable."
	desc.add_theme_font_size_override("font_size", UITheme.SMALL)
	desc.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	tool_list = VBoxContainer.new()
	tool_list.add_theme_constant_override("separation", 6)
	vbox.add_child(tool_list)

func refresh():
	for child in tool_list.get_children():
		child.queue_free()

	for tool in ai_tool_manager.get_all_tools():
		var row = _create_tool_row(tool)
		tool_list.add_child(row)

func _create_tool_row(tool: AiToolData) -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var current_tier = GameState.get_ai_tool_tier(tool.id)

	var name_label = Label.new()
	name_label.text = "%s (Tier %d/%d)" % [tool.name, current_tier, tool.max_tier]
	name_label.add_theme_font_size_override("font_size", 15)
	info.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = tool.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	info.add_child(desc_label)

	if current_tier > 0:
		var stats_label = Label.new()
		var reliability = tool.get_reliability_at_tier(current_tier) * 100
		var cooldown = tool.get_cooldown_at_tier(current_tier)
		stats_label.text = "Reliability: %.0f%% | Speed: %.1fs" % [reliability, cooldown]
		stats_label.add_theme_font_size_override("font_size", 11)
		stats_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.5))
		info.add_child(stats_label)

	var buy_btn = Button.new()
	if current_tier >= tool.max_tier:
		buy_btn.text = "MAX"
		buy_btn.disabled = true
	else:
		var price = tool.get_cost_for_tier(current_tier)
		buy_btn.text = "%s $%.0f" % ["Buy" if current_tier == 0 else "Upgrade", price]
		buy_btn.pressed.connect(func():
			ai_tool_manager.try_upgrade(tool, GameState)
			refresh()
		)
	buy_btn.custom_minimum_size = Vector2(120, 36)
	hbox.add_child(buy_btn)

	return card
