extends PanelContainer

signal close_requested
signal choice_made(event: RandomEvent, choice_index: int)

@onready var event_list: VBoxContainer = %EventList
@onready var no_mail_label: Label = %NoMailLabel
@onready var _close_btn: Button = %CloseBtn

func _ready():
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	UITheme.style_button(_close_btn)
	_close_btn.pressed.connect(func(): close_requested.emit())

func display_events(events: Array):
	for child in event_list.get_children():
		child.queue_free()

	if events.is_empty():
		no_mail_label = Label.new()
		no_mail_label.text = "No new messages."
		no_mail_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		no_mail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		event_list.add_child(no_mail_label)
		return

	for event in events:
		var card = _create_event_card(event)
		event_list.add_child(card)

func _create_event_card(event: RandomEvent) -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())

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
	desc_label.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
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
