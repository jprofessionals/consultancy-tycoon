extends PanelContainer

signal close_requested
signal choice_made(event: RandomEvent, choice_index: int)

var event_list: VBoxContainer
var no_mail_label: Label

func _ready():
	_build_ui()

func _build_ui():
	custom_minimum_size = Vector2(500, 400)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.14, 0.17)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "Inbox"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Scrollable event list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	event_list = VBoxContainer.new()
	event_list.add_theme_constant_override("separation", 8)
	event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(event_list)

	# Empty state
	no_mail_label = Label.new()
	no_mail_label.text = "No new messages."
	no_mail_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	no_mail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_list.add_child(no_mail_label)

func display_events(events: Array):
	for child in event_list.get_children():
		child.queue_free()

	if events.is_empty():
		no_mail_label = Label.new()
		no_mail_label.text = "No new messages."
		no_mail_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		no_mail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		event_list.add_child(no_mail_label)
		return

	for event in events:
		var card = _create_event_card(event)
		event_list.add_child(card)

func _create_event_card(event: RandomEvent) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.18, 0.18, 0.22)
	card_style.set_content_margin_all(12)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title_label = Label.new()
	title_label.text = event.title
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = event.description
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	for i in event.choices.size():
		var choice = event.choices[i]
		var btn = Button.new()
		btn.text = choice["label"]
		btn.pressed.connect(func(): choice_made.emit(event, i))
		btn_row.add_child(btn)

	return card
