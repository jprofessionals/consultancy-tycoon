extends PanelContainer

# Multi-tab state
var tabs: Array = []  # Array of CodingTab
var _focused_index: int = -1
var click_power: float = 1.0

# Backward-compatible property: returns focused tab's coding_loop
var coding_loop: CodingLoop:
	get:
		if _focused_index >= 0 and _focused_index < tabs.size():
			return tabs[_focused_index].coding_loop
		return _idle_loop

# Fallback loop for when no tabs exist
var _idle_loop: CodingLoop = CodingLoop.new()

@onready var code_display: RichTextLabel
@onready var progress_bar: ProgressBar
@onready var status_label: Label
@onready var task_label: Label
@onready var review_panel: VBoxContainer
@onready var conflict_panel: HBoxContainer
@onready var notification_area: PanelContainer
@onready var keyboard_panel: PanelContainer
var _tab_bar: HBoxContainer
var _tab_bar_container: PanelContainer

var _key_buttons: Array[Button] = []
var _key_buttons_by_label: Dictionary = {}
var _keyboard_enabled: bool = false
var _combo_sequence: Array[String] = []
const _COMBO_TARGET = ["CTRL", "ALT", "DEL"]

# Stuck tab flash timing
var _stuck_flash_timer: float = 0.0

# Review change suggestions to show in code
const REVIEW_CHANGES = [
	["    # TODO: add null check here", "    if token == null:", "        return false"],
	["    # FIXME: missing error handling", "    try:", "        result = process()", "    except Error:", "        log.error(\"Failed\")"],
	["    # BUG: off-by-one error", "    for i in range(0, len - 1):  # was len"],
	["    # REVIEW: use constant instead", "    var TIMEOUT = 30  # was hardcoded 60"],
	["    # FIX: sanitize input first", "    value = value.strip_edges()", "    value = value.replace(\";\", \"\")"],
	["    # CHANGED: wrong variable name", "    var user_id = get_current_user()  # was 'uid'"],
]

func _ready():
	_build_ui()
	_connect_signals()

func _process(_delta: float):
	if tabs.size() <= 1:
		return
	# Pulse stuck tab buttons red
	_stuck_flash_timer += _delta
	var alpha = 0.4 + 0.4 * abs(sin(_stuck_flash_timer * 3.0))
	for i in range(_tab_bar.get_child_count()):
		var btn = _tab_bar.get_child(i) as Button
		if i < tabs.size() and tabs[i].stuck:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.8, 0.2, 0.2, alpha)
			style.set_corner_radius_all(3)
			btn.add_theme_stylebox_override("normal", style)
		elif i != _focused_index:
			btn.remove_theme_stylebox_override("normal")

func _unhandled_input(event: InputEvent):
	if not is_visible_in_tree():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _focused_index < 0:
		return

	var loop = coding_loop
	var keycode = event.keycode

	# Tab switching: Ctrl+1-9
	if event.ctrl_pressed and keycode >= KEY_1 and keycode <= KEY_9:
		var tab_idx = keycode - KEY_1
		if tab_idx < tabs.size():
			_switch_to_tab(tab_idx)
			get_viewport().set_input_as_handled()
		return

	# Shift+R → submit for review
	if keycode == KEY_R and event.shift_pressed:
		if loop.state == CodingLoop.State.REVIEWING:
			_do_review()
			_flash_key_by_label("ENTER")
			get_viewport().set_input_as_handled()
		return

	# Arrow keys → merge conflict resolution
	if loop.state == CodingLoop.State.CONFLICT:
		if keycode == KEY_LEFT:
			loop.resolve_conflict("left")
			get_viewport().set_input_as_handled()
			return
		elif keycode == KEY_RIGHT:
			loop.resolve_conflict("right")
			get_viewport().set_input_as_handled()
			return

	# Regular typing keys → write/fix code
	var label = _keycode_to_label(keycode)
	if label == "":
		return

	_check_combo(label)

	if loop.state == CodingLoop.State.WRITING:
		loop.perform_click(click_power)
		_flash_key_by_label(label)
		get_viewport().set_input_as_handled()
	elif loop.state == CodingLoop.State.FIXING:
		loop.perform_click(click_power)
		_flash_key_by_label(label)
		get_viewport().set_input_as_handled()

func _keycode_to_label(keycode: int) -> String:
	match keycode:
		KEY_Q: return "Q"
		KEY_W: return "W"
		KEY_E: return "E"
		KEY_R: return "R"
		KEY_T: return "T"
		KEY_Y: return "Y"
		KEY_U: return "U"
		KEY_I: return "I"
		KEY_O: return "O"
		KEY_P: return "P"
		KEY_A: return "A"
		KEY_S: return "S"
		KEY_D: return "D"
		KEY_F: return "F"
		KEY_G: return "G"
		KEY_H: return "H"
		KEY_J: return "J"
		KEY_K: return "K"
		KEY_L: return "L"
		KEY_Z: return "Z"
		KEY_X: return "X"
		KEY_C: return "C"
		KEY_V: return "V"
		KEY_B: return "B"
		KEY_N: return "N"
		KEY_M: return "M"
		KEY_SPACE: return "SPACE"
		KEY_ENTER, KEY_KP_ENTER: return "ENTER"
		KEY_DELETE, KEY_BACKSPACE: return "DEL"
		KEY_CTRL: return "CTRL"
		KEY_ALT: return "ALT"
	return ""

func _flash_key_by_label(label: String):
	var btn = _key_buttons_by_label.get(label)
	if btn:
		_flash_key(btn)
	else:
		# Fallback: flash a random key
		if not _key_buttons.is_empty():
			_flash_key(_key_buttons[randi() % _key_buttons.size()])

func _build_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title bar
	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)
	var title = Label.new()
	title.text = "  CONSULTANCY IDE v1.0"
	title.add_theme_font_size_override("font_size", 14)
	title_bar.add_child(title)

	# Tab bar (hidden when <= 1 tab)
	_tab_bar_container = PanelContainer.new()
	_tab_bar_container.visible = false
	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = Color(0.12, 0.12, 0.15)
	tab_style.set_content_margin_all(4)
	tab_style.set_corner_radius_all(3)
	_tab_bar_container.add_theme_stylebox_override("panel", tab_style)
	vbox.add_child(_tab_bar_container)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	_tab_bar_container.add_child(_tab_bar)

	# Task label
	task_label = Label.new()
	task_label.text = "No active task"
	vbox.add_child(task_label)

	# Status
	status_label = Label.new()
	status_label.text = "IDLE"
	vbox.add_child(status_label)

	# Notification area (review/conflict — above code, away from keyboard)
	notification_area = PanelContainer.new()
	notification_area.visible = false
	var notif_style = StyleBoxFlat.new()
	notif_style.bg_color = Color(0.2, 0.22, 0.25)
	notif_style.set_content_margin_all(8)
	notif_style.set_corner_radius_all(4)
	notification_area.add_theme_stylebox_override("panel", notif_style)
	vbox.add_child(notification_area)

	var notif_vbox = VBoxContainer.new()
	notif_vbox.add_theme_constant_override("separation", 6)
	notification_area.add_child(notif_vbox)

	# Review panel (inside notification area)
	review_panel = VBoxContainer.new()
	review_panel.visible = false
	notif_vbox.add_child(review_panel)

	# Conflict panel (inside notification area)
	conflict_panel = HBoxContainer.new()
	conflict_panel.visible = false
	notif_vbox.add_child(conflict_panel)

	# Code display
	code_display = RichTextLabel.new()
	code_display.bbcode_enabled = true
	code_display.custom_minimum_size = Vector2(0, 200)
	code_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_display.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(code_display)

	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.step = 0.01
	progress_bar.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(progress_bar)

	# Keyboard grid (clickable anywhere in the panel)
	_build_keyboard(vbox)

func _build_keyboard(parent: VBoxContainer):
	keyboard_panel = PanelContainer.new()
	var kb_style = StyleBoxFlat.new()
	kb_style.bg_color = Color(0.15, 0.15, 0.18)
	kb_style.set_content_margin_all(8)
	kb_style.set_corner_radius_all(4)
	keyboard_panel.add_theme_stylebox_override("panel", kb_style)
	keyboard_panel.gui_input.connect(_on_keyboard_panel_input)
	parent.add_child(keyboard_panel)

	var kb_vbox = VBoxContainer.new()
	kb_vbox.add_theme_constant_override("separation", 4)
	keyboard_panel.add_child(kb_vbox)

	var rows = [
		["Q","W","E","R","T","Y","U","I","O","P","DEL"],
		["A","S","D","F","G","H","J","K","L","ENTER"],
		["Z","X","C","V","B","N","M"],
	]

	for i in rows.size():
		var row_container = HBoxContainer.new()
		row_container.add_theme_constant_override("separation", 4)
		row_container.alignment = BoxContainer.ALIGNMENT_CENTER
		kb_vbox.add_child(row_container)

		for key_label in rows[i]:
			var btn = _create_key_button(key_label)
			if key_label == "ENTER":
				btn.custom_minimum_size = Vector2(60, 36)
			elif key_label == "DEL":
				btn.custom_minimum_size = Vector2(44, 36)
			row_container.add_child(btn)
			_key_buttons.append(btn)

	# Bottom row: Ctrl, Alt, Space
	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 4)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	kb_vbox.add_child(bottom_row)

	for key_label in ["CTRL", "ALT"]:
		var btn = _create_key_button(key_label)
		btn.custom_minimum_size = Vector2(50, 36)
		bottom_row.add_child(btn)
		_key_buttons.append(btn)

	var space_btn = _create_key_button("SPACE")
	space_btn.custom_minimum_size = Vector2(200, 36)
	bottom_row.add_child(space_btn)
	_key_buttons.append(space_btn)

func _create_key_button(key_label: String) -> Button:
	var btn = Button.new()
	btn.text = key_label
	btn.custom_minimum_size = Vector2(36, 36)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.pressed.connect(_on_key_pressed.bind(btn, key_label))
	_key_buttons_by_label[key_label] = btn
	return btn

func _on_keyboard_panel_input(event: InputEvent):
	if not _keyboard_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_action_pressed()
		# Flash a random key for visual feedback
		var random_btn = _key_buttons[randi() % _key_buttons.size()]
		_flash_key(random_btn)

func _on_key_pressed(btn: Button, key_label: String):
	if not _keyboard_enabled:
		return
	_check_combo(key_label)
	_on_action_pressed()
	_flash_key(btn)

func _flash_key(btn: Button):
	var highlight_style = StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.4, 0.6, 0.9, 0.8)
	highlight_style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", highlight_style)

	var timer = get_tree().create_timer(0.15)
	timer.timeout.connect(func(): btn.remove_theme_stylebox_override("normal"))

func _check_combo(key_label: String):
	var next_expected = _COMBO_TARGET[_combo_sequence.size()] if _combo_sequence.size() < _COMBO_TARGET.size() else ""
	if key_label == next_expected:
		_combo_sequence.append(key_label)
		if _combo_sequence.size() == _COMBO_TARGET.size():
			_combo_sequence.clear()
			_trigger_bsod()
	else:
		_combo_sequence.clear()
		# Check if this key starts the combo
		if key_label == _COMBO_TARGET[0]:
			_combo_sequence.append(key_label)

func _trigger_bsod():
	var already_claimed = GameState.claimed_easter_eggs.get("bsod", false)

	var bsod = ColorRect.new()
	bsod.color = Color(0.0, 0.0, 0.7)
	bsod.set_anchors_preset(Control.PRESET_FULL_RECT)
	bsod.z_index = 100
	get_tree().root.add_child(bsod)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bsod.add_child(center)

	var text_vbox = VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 16)
	center.add_child(text_vbox)

	var title = Label.new()
	title.text = ":(  Your PC ran into a problem"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	text_vbox.add_child(title)

	var info = Label.new()
	if already_claimed:
		info.text = "CONSULTANCY_TYCOON_EXCEPTION\n\nNice try, but you already found this one!\n\nRestarting in 3 seconds..."
	else:
		info.text = "CONSULTANCY_TYCOON_EXCEPTION\n\nJust kidding! Here's $500 for finding this.\n\nRestarting in 3 seconds..."
		GameState.add_money(500.0)
		GameState.claimed_easter_eggs["bsod"] = true
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color.WHITE)
	text_vbox.add_child(info)

	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func(): bsod.queue_free())

func _connect_signals():
	EventBus.ai_tool_acted.connect(_on_ai_tool_acted)

# ── Tab Management ──

func add_tab(tab: CodingTab) -> int:
	tabs.append(tab)
	_connect_tab_signals(tab)
	var idx = tabs.size() - 1
	if _focused_index < 0:
		_focused_index = idx
	_rebuild_tab_bar()
	return idx

func remove_tab(index: int):
	if index < 0 or index >= tabs.size():
		return
	var tab = tabs[index]
	_disconnect_tab_signals(tab)
	tabs.remove_at(index)
	# Adjust focused index
	if tabs.is_empty():
		_focused_index = -1
		_show_idle_state()
	elif _focused_index >= tabs.size():
		_focused_index = tabs.size() - 1
		_restore_tab_visual(_focused_index)
	elif _focused_index == index:
		_focused_index = mini(_focused_index, tabs.size() - 1)
		_restore_tab_visual(_focused_index)
	_rebuild_tab_bar()

func _switch_to_tab(index: int):
	if index < 0 or index >= tabs.size() or index == _focused_index:
		return
	_focused_index = index
	var tab = tabs[index]
	# Clear stuck when player focuses the tab
	if tab.stuck:
		tab.stuck = false
		var bus = _get_event_bus()
		if bus:
			bus.tab_unstuck.emit(index)
	_restore_tab_visual(index)
	_rebuild_tab_bar()

func get_focused_index() -> int:
	return _focused_index

func get_stuck_count() -> int:
	var count = 0
	for tab in tabs:
		if tab.stuck:
			count += 1
	return count

func start_task_on_tab(tab: CodingTab, task: CodingTask):
	tab.code_snippet = FakeCode.get_random_snippet()
	tab.lines_revealed = 0
	tab.coding_loop.start_task(task)
	# Only update display if this is the focused tab
	var idx = tabs.find(tab)
	if idx == _focused_index:
		code_display.text = ""
		progress_bar.value = 0.0
		task_label.text = "Task: " + task.title
		_update_ui()

func _restore_tab_visual(index: int):
	if index < 0 or index >= tabs.size():
		return
	var tab = tabs[index]
	# Rebuild code display from tab's visual state
	code_display.text = ""
	for i in range(tab.lines_revealed):
		if i < tab.code_snippet.size():
			code_display.append_text(_syntax_highlight(tab.code_snippet[i]) + "\n")
	progress_bar.value = tab.coding_loop.progress
	if tab.coding_loop.current_task:
		task_label.text = "Task: " + tab.coding_loop.current_task.title
	else:
		task_label.text = tab.get_tab_label()
	_update_ui()

func _show_idle_state():
	code_display.text = ""
	progress_bar.value = 0.0
	task_label.text = "No active task"
	status_label.text = "IDLE — Go to Contracts to find work"
	_set_keyboard_enabled(false)
	notification_area.visible = false
	review_panel.visible = false
	conflict_panel.visible = false

func _rebuild_tab_bar():
	# Clear existing buttons
	for child in _tab_bar.get_children():
		child.queue_free()
	# Show tab bar only when more than 1 tab
	_tab_bar_container.visible = tabs.size() > 1
	for i in range(tabs.size()):
		var tab = tabs[i]
		var btn = Button.new()
		btn.text = tab.get_tab_label()
		btn.custom_minimum_size = Vector2(100, 28)
		btn.add_theme_font_size_override("font_size", 12)
		if i == _focused_index:
			btn.disabled = true
		btn.pressed.connect(_switch_to_tab.bind(i))
		_tab_bar.add_child(btn)

# ── Tab Signal Routing ──

func _connect_tab_signals(tab: CodingTab):
	tab.coding_loop.state_changed.connect(_on_tab_state_changed.bind(tab))
	tab.coding_loop.progress_changed.connect(_on_tab_progress_changed.bind(tab))
	tab.coding_loop.conflict_appeared.connect(_on_tab_conflict_appeared.bind(tab))
	tab.coding_loop.task_done.connect(_on_tab_task_done.bind(tab))

func _disconnect_tab_signals(tab: CodingTab):
	if tab.coding_loop.state_changed.is_connected(_on_tab_state_changed):
		tab.coding_loop.state_changed.disconnect(_on_tab_state_changed)
	if tab.coding_loop.progress_changed.is_connected(_on_tab_progress_changed):
		tab.coding_loop.progress_changed.disconnect(_on_tab_progress_changed)
	if tab.coding_loop.conflict_appeared.is_connected(_on_tab_conflict_appeared):
		tab.coding_loop.conflict_appeared.disconnect(_on_tab_conflict_appeared)
	if tab.coding_loop.task_done.is_connected(_on_tab_task_done):
		tab.coding_loop.task_done.disconnect(_on_tab_task_done)

func _is_focused_tab(tab: CodingTab) -> bool:
	if _focused_index < 0 or _focused_index >= tabs.size():
		return false
	return tabs[_focused_index] == tab

func _on_tab_state_changed(_new_state: CodingLoop.State, tab: CodingTab):
	if _is_focused_tab(tab):
		_update_ui()

func _on_tab_progress_changed(new_progress: float, tab: CodingTab):
	if _is_focused_tab(tab):
		progress_bar.value = new_progress
		_sync_code_to_progress(new_progress, tab)

func _on_tab_conflict_appeared(left_code: String, right_code: String, tab: CodingTab):
	if _is_focused_tab(tab):
		_show_conflict_ui(left_code, right_code, tab)

func _on_tab_task_done(task: CodingTask, tab: CodingTab):
	GameState.add_money(task.payout)
	GameState.add_reputation(task.difficulty * 1.0)
	if _is_focused_tab(tab):
		status_label.text = "COMPLETE — Earned $%.0f" % task.payout
		notification_area.visible = false
		review_panel.visible = false
		conflict_panel.visible = false
	EventBus.tab_task_done.emit(task, tab)

# ── Actions ──

func _on_action_pressed():
	if _focused_index < 0:
		return
	var loop = coding_loop
	match loop.state:
		CodingLoop.State.WRITING:
			loop.perform_click(click_power)
		CodingLoop.State.REVIEWING:
			pass  # handled by approve button in notification area
		CodingLoop.State.FIXING:
			loop.perform_click(click_power)
		CodingLoop.State.IDLE:
			pass  # handled externally (bidding system starts tasks)

func _sync_code_to_progress(progress: float, tab: CodingTab = null):
	if tab == null:
		if _focused_index >= 0 and _focused_index < tabs.size():
			tab = tabs[_focused_index]
		else:
			return
	if tab.code_snippet.is_empty():
		return
	var target_lines = ceili(progress * tab.code_snippet.size())
	while tab.lines_revealed < target_lines and tab.lines_revealed < tab.code_snippet.size():
		var line = tab.code_snippet[tab.lines_revealed]
		var colored = _syntax_highlight(line)
		if _is_focused_tab(tab):
			code_display.append_text(colored + "\n")
		tab.lines_revealed += 1

func _syntax_highlight(line: String) -> String:
	var result = line
	# Keywords
	for kw in ["func", "var", "return", "if", "else", "for", "class", "async", "await", "const"]:
		result = result.replace(kw + " ", "[color=#569cd6]" + kw + "[/color] ")
	# Strings
	var string_regex = RegEx.new()
	string_regex.compile("\"[^\"]*\"")
	for m in string_regex.search_all(result):
		result = result.replace(m.get_string(), "[color=#ce9178]" + m.get_string() + "[/color]")
	return result

func _do_review():
	if _focused_index < 0:
		return
	var loop = coding_loop
	var reject_chance = loop.current_task.get_review_reject_chance()
	# Player skill reduces reject chance
	var skill_modifier = GameState.get_skill_level("code_quality") * 0.05
	var approved = randf() > (reject_chance - skill_modifier)
	loop.resolve_review(approved)
	if approved:
		_show_review_comment("[color=#4ec9b0]Reviewer:[/color] LGTM! Approved.")
	else:
		_inject_review_changes()
		_show_review_comment("[color=#f44747]Reviewer:[/color] Changes requested. Please fix the highlighted code.")

func _inject_review_changes():
	var change = REVIEW_CHANGES[randi() % REVIEW_CHANGES.size()]
	code_display.append_text("\n")
	for line in change:
		code_display.append_text("[color=#f4a460]" + line + "[/color]\n")

func _show_review_comment(text: String):
	for child in review_panel.get_children():
		child.queue_free()
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text
	label.fit_content = true
	label.custom_minimum_size = Vector2(0, 40)
	review_panel.add_child(label)
	review_panel.visible = true
	notification_area.visible = true

func _show_conflict_ui(left_code: String, right_code: String, tab: CodingTab):
	conflict_panel.visible = true
	notification_area.visible = true
	for child in conflict_panel.get_children():
		child.queue_free()

	var left_btn = Button.new()
	left_btn.text = "Accept Local\n" + left_code
	left_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_btn.pressed.connect(func(): tab.coding_loop.resolve_conflict("left"))
	conflict_panel.add_child(left_btn)

	var right_btn = Button.new()
	right_btn.text = "Accept Remote\n" + right_code
	right_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_btn.pressed.connect(func(): tab.coding_loop.resolve_conflict("right"))
	conflict_panel.add_child(right_btn)

func _on_ai_tool_acted(tool_id: String, action: String, success: bool):
	# Only show visual feedback for the focused tab
	match action:
		"write":
			if success:
				_flash_ai_key()
			else:
				_flash_ai_key_fail()
		"fix":
			if success:
				_flash_ai_key()
		"review":
			if success:
				_show_review_comment("[color=#4ec9b0]Auto-reviewer:[/color] LGTM! Approved.")
			else:
				_inject_review_changes()
				_show_review_comment("[color=#f44747]Auto-reviewer:[/color] Changes requested.")
		"conflict":
			if success:
				_show_review_comment("[color=#4ec9b0]Merge Resolver:[/color] Resolved correctly!")
			else:
				_show_review_comment("[color=#f44747]Merge Resolver:[/color] Picked wrong side...")

func _flash_ai_key():
	if _key_buttons.is_empty():
		return
	var random_btn = _key_buttons[randi() % _key_buttons.size()]
	var highlight_style = StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.3, 0.8, 0.5, 0.8)
	highlight_style.set_corner_radius_all(3)
	random_btn.add_theme_stylebox_override("normal", highlight_style)
	var timer = get_tree().create_timer(0.12)
	timer.timeout.connect(func(): random_btn.remove_theme_stylebox_override("normal"))

func _flash_ai_key_fail():
	if _key_buttons.is_empty():
		return
	var random_btn = _key_buttons[randi() % _key_buttons.size()]
	var highlight_style = StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.8, 0.3, 0.3, 0.6)
	highlight_style.set_corner_radius_all(3)
	random_btn.add_theme_stylebox_override("normal", highlight_style)
	var timer = get_tree().create_timer(0.12)
	timer.timeout.connect(func(): random_btn.remove_theme_stylebox_override("normal"))

func _update_ui():
	conflict_panel.visible = false
	review_panel.visible = false
	notification_area.visible = false
	_set_keyboard_enabled(true)
	if _focused_index < 0 or _focused_index >= tabs.size():
		_show_idle_state()
		return
	var loop = coding_loop
	var has_ai_writer = GameState.get_ai_tool_tier("auto_writer") > 0
	var has_ai_reviewer = GameState.get_ai_tool_tier("auto_reviewer") > 0
	var has_ai_merger = GameState.get_ai_tool_tier("merge_resolver") > 0
	match loop.state:
		CodingLoop.State.IDLE:
			status_label.text = "IDLE — Go to Contracts to find work"
			_set_keyboard_enabled(false)
		CodingLoop.State.WRITING:
			if has_ai_writer:
				status_label.text = "WRITING CODE — Type or let Auto-Writer handle it"
			else:
				status_label.text = "WRITING CODE — Type to write"
		CodingLoop.State.REVIEWING:
			if has_ai_reviewer:
				status_label.text = "CODE REVIEW — Auto-reviewer handling..."
			else:
				status_label.text = "CODE REVIEW — Shift+R to submit"
			_set_keyboard_enabled(false)
			notification_area.visible = true
			review_panel.visible = true
			if not has_ai_reviewer:
				_show_review_button()
		CodingLoop.State.FIXING:
			status_label.text = "FIXING — %d changes remaining — Type to fix" % loop.review_changes_needed
		CodingLoop.State.CONFLICT:
			status_label.text = "MERGE CONFLICT — Left/Right arrow to pick a side"
			_set_keyboard_enabled(false)
			notification_area.visible = true
			conflict_panel.visible = true
		CodingLoop.State.COMPLETE:
			_set_keyboard_enabled(false)

func _show_review_button():
	for child in review_panel.get_children():
		child.queue_free()
	var approve_btn = Button.new()
	approve_btn.text = "Submit for Review"
	approve_btn.custom_minimum_size = Vector2(0, 40)
	approve_btn.pressed.connect(_do_review)
	review_panel.add_child(approve_btn)

func _set_keyboard_enabled(enabled: bool):
	_keyboard_enabled = enabled
	for btn in _key_buttons:
		btn.disabled = !enabled

func reset_to_idle():
	# Remove all tabs
	for tab in tabs.duplicate():
		var idx = tabs.find(tab)
		if idx >= 0:
			_disconnect_tab_signals(tab)
	tabs.clear()
	_focused_index = -1
	_show_idle_state()
	_rebuild_tab_bar()

func set_click_power(power: float):
	click_power = power

func _get_event_bus() -> Node:
	if is_inside_tree():
		return EventBus
	return null
