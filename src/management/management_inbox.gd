extends PanelContainer

signal close_requested
signal extension_accepted(rental: ConsultantRental)
signal issue_choice_made(issue: ManagementIssue, choice_index: int)

var _extensions: Array = []
var _issues: Array = []

@onready var _card_list: VBoxContainer = %CardList
@onready var _empty_label: Label = %EmptyLabel
@onready var _close_btn: Button = %CloseBtn
@onready var _scroll_container: ScrollContainer = %Scroll

func _ready():
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	UITheme.style_button(_close_btn)
	_close_btn.pressed.connect(func(): close_requested.emit())

func set_notifications(extensions: Array, issues: Array):
	_extensions = extensions
	_issues = issues
	refresh()

func get_notification_count() -> int:
	return _extensions.size() + _issues.size()

func refresh():
	_rebuild_cards()

func _rebuild_cards():
	for child in _card_list.get_children():
		child.queue_free()

	var has_items = not _extensions.is_empty() or not _issues.is_empty()
	_empty_label.visible = not has_items
	_scroll_container.visible = has_items

	# Extension cards
	for rental in _extensions:
		var card = _create_extension_card(rental)
		_card_list.add_child(card)

	# Issue cards
	for issue in _issues:
		var card = _create_issue_card(issue)
		_card_list.add_child(card)

func _create_extension_card(rental: ConsultantRental) -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Title
	var consultant_name = rental.consultant.name if rental.consultant else "Unknown"
	var title = Label.new()
	title.text = "Rental Extension — %s at %s" % [consultant_name, rental.client_name]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Description
	var desc = Label.new()
	desc.text = "The client wants to extend the rental. Current rate: $%.1f/sec" % rental.rate_per_tick
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var accept_btn = Button.new()
	accept_btn.text = "Accept Extension"
	accept_btn.pressed.connect(func():
		extension_accepted.emit(rental)
		_extensions.erase(rental)
		refresh()
	)
	btn_row.add_child(accept_btn)

	var decline_btn = Button.new()
	decline_btn.text = "Let it End"
	decline_btn.pressed.connect(func():
		_extensions.erase(rental)
		refresh()
	)
	btn_row.add_child(decline_btn)

	return card

func _create_issue_card(issue: ManagementIssue) -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = issue.title
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Description
	var desc = Label.new()
	desc.text = issue.description
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Choice buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	for i in range(issue.choices.size()):
		var choice = issue.choices[i]
		var btn = Button.new()
		btn.text = choice["label"]
		btn.pressed.connect(_on_issue_choice.bind(issue, i))
		btn_row.add_child(btn)

	return card

func _on_issue_choice(issue: ManagementIssue, choice_index: int):
	issue_choice_made.emit(issue, choice_index)
	_issues.erase(issue)
	refresh()
