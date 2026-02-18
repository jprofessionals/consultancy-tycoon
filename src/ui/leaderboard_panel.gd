extends PanelContainer

signal close_requested

var _entry_list: VBoxContainer
var _player_row: HBoxContainer
var _loading_label: Label

func _ready():
	custom_minimum_size = Vector2(600, 500)
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	_build_ui()

func _build_ui():
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.NORMAL)
	add_child(vbox)

	# Header row: title + close button
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "LEADERBOARD"
	title.add_theme_font_size_override("font_size", UITheme.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = UITheme.create_close_button()
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Column headers
	var col_headers = _create_row("RANK", "NAME", "SCORE")
	for child in col_headers.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", UITheme.BODY)
			child.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(col_headers)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", UITheme.TIGHT)
	vbox.add_child(sep)

	# Scrollable entry list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_entry_list = VBoxContainer.new()
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.add_theme_constant_override("separation", UITheme.TIGHT)
	scroll.add_child(_entry_list)

	_loading_label = Label.new()
	_loading_label.text = "Loading..."
	_loading_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_list.add_child(_loading_label)

	# Bottom separator + pinned player row
	var bottom_sep = HSeparator.new()
	bottom_sep.add_theme_constant_override("separation", UITheme.TIGHT)
	vbox.add_child(bottom_sep)

	_player_row = _create_row("—", "You", "—")
	_player_row.visible = false
	# Highlight player row
	var player_card = PanelContainer.new()
	player_card.add_theme_stylebox_override("panel", UITheme.create_card_style())
	player_card.add_child(_player_row)
	vbox.add_child(player_card)

func refresh():
	_loading_label.visible = true
	# Clear previous entries (keep loading label)
	for child in _entry_list.get_children():
		if child != _loading_label:
			child.queue_free()
	_player_row.visible = false

	if not CloudManager.leaderboard_fetched.is_connected(_on_leaderboard_data):
		CloudManager.leaderboard_fetched.connect(_on_leaderboard_data, CONNECT_ONE_SHOT)
	CloudManager.fetch_leaderboard()

func _on_leaderboard_data(data: Dictionary):
	_loading_label.visible = false

	var entries = data.get("entries", [])
	for entry in entries:
		var rank_str = "#%d" % int(entry.get("rank", 0))
		var name_str = str(entry.get("display_name", "???"))
		var score_str = _format_score(entry.get("score", 0.0))
		var row = _create_row(rank_str, name_str, score_str)
		_entry_list.add_child(row)

	# Pinned player row
	var player_rank = data.get("player_rank")
	var player_score = data.get("player_score")
	if player_rank != null:
		_player_row.visible = true
		_update_row(_player_row, "#%d" % int(player_rank), GameState.player_name, _format_score(player_score if player_score != null else 0.0))
	else:
		_player_row.visible = false

func _create_row(rank_text: String, name_text: String, score_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.NORMAL)

	var rank_label = Label.new()
	rank_label.text = rank_text
	rank_label.custom_minimum_size = Vector2(60, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", UITheme.BODY)
	row.add_child(rank_label)

	var name_label = Label.new()
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", UITheme.BODY)
	name_label.clip_text = true
	row.add_child(name_label)

	var score_label = Label.new()
	score_label.text = score_text
	score_label.custom_minimum_size = Vector2(100, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", UITheme.BODY)
	row.add_child(score_label)

	return row

func _update_row(row: HBoxContainer, rank_text: String, name_text: String, score_text: String):
	var children = row.get_children()
	if children.size() >= 3:
		children[0].text = rank_text
		children[1].text = name_text
		children[2].text = score_text

func _format_score(value) -> String:
	var score = float(value)
	if score >= 1_000_000:
		return "%.1fM" % (score / 1_000_000.0)
	elif score >= 1_000:
		return "%.1fK" % (score / 1_000.0)
	else:
		return "%.0f" % score
