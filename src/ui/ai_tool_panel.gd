extends PanelContainer

var ai_tool_manager: AiToolManager = AiToolManager.new()
var tool_list: VBoxContainer

signal close_requested

func _ready():
	_build_ui()
	refresh()

func _build_ui():
	custom_minimum_size = Vector2(520, 400)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.25, 0.35, 0.55)
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

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "AI Development Tools"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	var desc = Label.new()
	desc.text = "AI tools automate parts of your coding workflow. Higher tiers are faster and more reliable."
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
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
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.18, 0.22)
	card_style.set_content_margin_all(10)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

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
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
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
