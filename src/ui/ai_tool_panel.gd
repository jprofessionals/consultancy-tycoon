extends PanelContainer

var ai_tool_manager: AiToolManager = AiToolManager.new()

@onready var tool_list: VBoxContainer = %ToolList
@onready var _close_btn: Button = %CloseBtn

signal close_requested

func _ready():
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	UITheme.style_button(_close_btn)
	_close_btn.pressed.connect(func(): close_requested.emit())
	refresh()

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
