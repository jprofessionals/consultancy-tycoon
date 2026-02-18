extends Control

enum DeskState { DESK, ZOOMED_TO_MONITOR, OVERLAY_OPEN }

var state: DeskState = DeskState.DESK
var desk_scene: Control
var hud: PanelContainer
var ide: PanelContainer
var bidding_panel: PanelContainer
var skill_panel: PanelContainer
var email_panel: PanelContainer
var ai_tool_panel: PanelContainer
var task_factory: TaskFactory = TaskFactory.new()
var skill_manager: SkillManager = SkillManager.new()
var event_manager: EventManager = EventManager.new()

# Management scene
var management_office: Control
var management_layer: CanvasLayer
var management_overlay_layer: CanvasLayer
var management_dimmer: ColorRect
var _management_current_overlay: Control = null
var _in_management: bool = false

# Management UI panels
var contract_board: PanelContainer
var hiring_board: PanelContainer
var staff_roster: PanelContainer
var management_inbox: PanelContainer

# Rental extension queue
var _pending_extensions: Array = []

# AI + Consultant systems
var ai_tool_runner: AiToolRunner = AiToolRunner.new()
var ai_tool_manager: AiToolManager = AiToolManager.new()
var consultant_manager: ConsultantManager = ConsultantManager.new()

# Layers
var hud_layer: CanvasLayer
var ide_layer: CanvasLayer
var overlay_layer: CanvasLayer
var welcome_layer: CanvasLayer
var dimmer: ColorRect
var stand_up_btn: Button

# Timers
var contract_offer_timer: Timer
var event_timer: Timer
var salary_timer: Timer
var autosave_timer: Timer

# Management issues queue (flows through email panel)
var _pending_issues: Array = []

# Currently shown overlay panel
var _current_overlay: Control = null

# Pause/save menu
var pause_layer: CanvasLayer = null
var _pause_open: bool = false

# Game started flag (suppress _process before start)
var _game_started: bool = false

func _ready():
	_build_desk()
	_build_hud_layer()
	_build_ide_layer()
	_build_overlay_layer()
	_build_management_layer()
	_build_welcome_layer()
	_connect_signals()
	_setup_timers()

func _process(delta: float):
	if not _game_started or _pause_open:
		return

	# AI tool runner ticks all active tabs
	if not ide.tabs.is_empty():
		ai_tool_runner.tick(delta, ide.tabs, ide.get_focused_index(), GameState)
		hud.update_stuck_count(ide.get_stuck_count())

	# Consultant assignment ticking
	var completed = consultant_manager.tick_assignments(delta, GameState)
	for assignment in completed:
		EventBus.assignment_completed.emit(assignment)
		hud.update_team_info(GameState.consultants.size(), GameState.active_assignments.size())

	# Training ticking
	consultant_manager.tick_training(delta, GameState)

	# Rental ticking
	var completed_rentals = consultant_manager.tick_rentals(delta, GameState)
	for rental in completed_rentals:
		EventBus.rental_completed.emit(rental)

	# Check for rental extension opportunities
	var new_extensions = consultant_manager.check_rental_extensions(GameState)
	for rental in new_extensions:
		_pending_extensions.append(rental)
		EventBus.rental_extension_available.emit(rental)

	# Update desk attention indicator in management view
	if _in_management:
		var has_attention = desk_scene.phone_glow.visible or event_manager.get_unread_count() > 0 or ide.get_stuck_count() > 0
		management_office.set_desk_attention(has_attention)

	# Management issue generation
	if not GameState.consultants.is_empty():
		var issue = consultant_manager.try_generate_issue(GameState)
		if issue:
			_pending_issues.append(issue)
			EventBus.management_issue.emit(issue)

	# Auto-expire old management issues and random events
	_expire_old_messages()

# ── Scene Construction ──

func _build_desk():
	desk_scene = load("res://src/office/desk_scene.tscn").instantiate()
	add_child(desk_scene)
	desk_scene.monitor_clicked.connect(_on_monitor_clicked)
	desk_scene.phone_clicked.connect(_on_phone_clicked)
	desk_scene.books_clicked.connect(_on_books_clicked)
	desk_scene.email_clicked.connect(_on_email_clicked)
	desk_scene.laptop_clicked.connect(_on_laptop_clicked)
	desk_scene.door_clicked.connect(_on_door_clicked)

func _build_hud_layer():
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	hud = load("res://src/ui/hud.tscn").instantiate()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_layer.add_child(hud)

func _build_ide_layer():
	ide_layer = CanvasLayer.new()
	ide_layer.layer = 15
	ide_layer.visible = false
	add_child(ide_layer)

	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ide_layer.add_child(container)

	ide = load("res://src/ide/ide_interface.tscn").instantiate()
	ide.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(ide)

	# Stand Up button (bottom-right of IDE)
	stand_up_btn = Button.new()
	stand_up_btn.text = "Stand Up"
	stand_up_btn.custom_minimum_size = Vector2(120, 40)
	stand_up_btn.add_theme_font_size_override("font_size", 14)
	stand_up_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stand_up_btn.position = Vector2(-136, -56)
	stand_up_btn.pressed.connect(_on_stand_up)
	container.add_child(stand_up_btn)

func _build_overlay_layer():
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	overlay_layer.visible = false
	add_child(overlay_layer)

	# Dimmer background
	dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.gui_input.connect(_on_dimmer_input)
	overlay_layer.add_child(dimmer)

	# Center container for overlay panels
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(center)

	# Pre-instantiate panels (hidden, reparented when shown)
	bidding_panel = load("res://src/ui/bidding_panel.tscn").instantiate()
	bidding_panel.visible = false
	center.add_child(bidding_panel)

	skill_panel = load("res://src/ui/skill_panel.tscn").instantiate()
	skill_panel.visible = false
	center.add_child(skill_panel)

	email_panel = load("res://src/ui/email_panel.tscn").instantiate()
	email_panel.visible = false
	center.add_child(email_panel)

	ai_tool_panel = load("res://src/ui/ai_tool_panel.tscn").instantiate()
	ai_tool_panel.visible = false
	center.add_child(ai_tool_panel)

func _build_management_layer():
	management_layer = CanvasLayer.new()
	management_layer.layer = 5
	management_layer.visible = false
	add_child(management_layer)

	management_office = load("res://src/management/management_office.tscn").instantiate()
	management_office.set_anchors_preset(Control.PRESET_FULL_RECT)
	management_layer.add_child(management_office)

	management_overlay_layer = CanvasLayer.new()
	management_overlay_layer.layer = 25
	management_overlay_layer.visible = false
	add_child(management_overlay_layer)

	management_dimmer = ColorRect.new()
	management_dimmer.color = Color(0, 0, 0, 0.5)
	management_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	management_dimmer.gui_input.connect(_on_management_dimmer_input)
	management_overlay_layer.add_child(management_dimmer)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	management_overlay_layer.add_child(center)

	contract_board = load("res://src/management/contract_board.tscn").instantiate()
	contract_board.visible = false
	center.add_child(contract_board)

	hiring_board = load("res://src/management/hiring_board.tscn").instantiate()
	hiring_board.visible = false
	center.add_child(hiring_board)

	staff_roster = load("res://src/management/staff_roster.tscn").instantiate()
	staff_roster.visible = false
	center.add_child(staff_roster)

	management_inbox = load("res://src/management/management_inbox.tscn").instantiate()
	management_inbox.visible = false
	center.add_child(management_inbox)

func _build_welcome_layer():
	welcome_layer = CanvasLayer.new()
	welcome_layer.layer = 100
	add_child(welcome_layer)

	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome_layer.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(content)

	var title = Label.new()
	title.text = "CONSULTANCY TYCOON"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "From Solo Freelancer to Consulting Empire"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	content.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	content.add_child(spacer)

	var desc = Label.new()
	desc.text = "Bid on contracts. Write code. Survive code reviews.\nLevel up your skills and grow your reputation.\nCan you build the ultimate consulting firm?"
	desc.add_theme_font_size_override("font_size", 14)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	content.add_child(desc)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	content.add_child(spacer2)

	if SaveManager.has_save():
		var continue_btn = Button.new()
		continue_btn.text = "Continue"
		continue_btn.custom_minimum_size = Vector2(200, 50)
		continue_btn.add_theme_font_size_override("font_size", 18)
		continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		continue_btn.pressed.connect(_on_start_game.bind(true))
		content.add_child(continue_btn)

	var start_btn = Button.new()
	start_btn.text = "New Game"
	start_btn.custom_minimum_size = Vector2(200, 50)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(_on_start_game.bind(false))
	content.add_child(start_btn)

	var dev_btn = Button.new()
	dev_btn.text = "Dev Save"
	dev_btn.custom_minimum_size = Vector2(200, 40)
	dev_btn.add_theme_font_size_override("font_size", 14)
	dev_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	dev_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dev_btn.pressed.connect(func():
		SaveManager.create_test_save()
		_on_start_game(true)
	)
	content.add_child(dev_btn)

func _connect_signals():
	bidding_panel.contract_accepted.connect(_on_contract_accepted)
	bidding_panel.close_requested.connect(_hide_overlay)
	skill_panel.close_requested.connect(_hide_overlay)
	email_panel.close_requested.connect(_hide_overlay)
	email_panel.choice_made.connect(_on_email_choice)
	ai_tool_panel.close_requested.connect(_hide_overlay)
	EventBus.tab_task_done.connect(_on_tab_task_done)
	EventBus.skill_purchased.connect(func(_id): _update_click_power())
	EventBus.ai_tool_upgraded.connect(func(_tid, _tier): _update_ai_status())

	# Management office signals
	management_office.back_to_desk_requested.connect(_switch_to_personal)
	management_office.contract_board_clicked.connect(func():
		contract_board.refresh()
		_show_management_overlay(contract_board)
	)
	management_office.hiring_board_clicked.connect(func():
		hiring_board.refresh()
		_show_management_overlay(hiring_board)
	)
	management_office.staff_roster_clicked.connect(func():
		staff_roster.refresh()
		_show_management_overlay(staff_roster)
	)
	management_office.inbox_clicked.connect(func():
		management_inbox.set_notifications(_pending_extensions, _pending_issues)
		_show_management_overlay(management_inbox)
	)
	contract_board.close_requested.connect(_hide_management_overlay)
	hiring_board.close_requested.connect(_hide_management_overlay)
	staff_roster.close_requested.connect(_hide_management_overlay)
	management_inbox.close_requested.connect(_hide_management_overlay)
	contract_board.consultant_assigned.connect(_on_management_assign)
	contract_board.consultant_placed_on_rental.connect(_on_management_rental)
	staff_roster.fire_consultant.connect(_on_fire_consultant)
	staff_roster.train_consultant.connect(_on_train_consultant)
	staff_roster.stop_training_consultant.connect(_on_stop_training)
	staff_roster.set_remote.connect(_on_set_remote)
	management_inbox.extension_accepted.connect(_on_rental_extension_accepted)
	management_inbox.issue_choice_made.connect(_on_management_issue_choice)

func _setup_timers():
	contract_offer_timer = Timer.new()
	contract_offer_timer.wait_time = 30.0
	contract_offer_timer.autostart = false
	contract_offer_timer.timeout.connect(func():
		bidding_panel.refresh_contracts()
		desk_scene.set_phone_glowing(true)
	)
	add_child(contract_offer_timer)

	event_timer = Timer.new()
	event_timer.wait_time = 90.0
	event_timer.autostart = false
	event_timer.timeout.connect(_on_event_timer)
	add_child(event_timer)

	salary_timer = Timer.new()
	salary_timer.wait_time = 120.0  # 2 min real time
	salary_timer.autostart = false
	salary_timer.timeout.connect(_on_salary_timer)
	add_child(salary_timer)

	autosave_timer = Timer.new()
	autosave_timer.wait_time = 60.0
	autosave_timer.autostart = false
	autosave_timer.timeout.connect(_on_autosave)
	add_child(autosave_timer)

# ── Game Start ──

func _on_start_game(load_save: bool = false):
	welcome_layer.queue_free()
	welcome_layer = null
	_game_started = true
	if load_save:
		var data = SaveManager.load_game()
		var runtime = SaveManager.apply_save(data)
		_apply_runtime_state(runtime)
	bidding_panel.refresh_contracts()
	desk_scene.set_phone_glowing(true)
	contract_offer_timer.start()
	event_timer.start()
	salary_timer.start()
	autosave_timer.start()
	# Update HUD after load
	hud.update_team_info(GameState.consultants.size(), GameState.active_assignments.size())
	_update_ai_status()

func _unhandled_input(event: InputEvent):
	if not _game_started:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _pause_open:
			_close_pause_menu()
		elif _in_management:
			if _management_current_overlay:
				_hide_management_overlay()
			else:
				_switch_to_personal()
		elif state == DeskState.OVERLAY_OPEN:
			_hide_overlay()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()

# ── Save / Load ──

func _collect_runtime_state() -> Dictionary:
	var runtime: Dictionary = {}
	runtime["game_started"] = _game_started
	runtime["tabs"] = SaveManager.serialize_tabs(ide.tabs)
	runtime["focused_index"] = ide.get_focused_index()
	return runtime

func _apply_runtime_state(runtime: Dictionary) -> void:
	if runtime.is_empty():
		return

	# Tab-based restore
	var tabs_data = runtime.get("tabs")
	if tabs_data is Array and not tabs_data.is_empty():
		ide.reset_to_idle()
		var restored_tabs = SaveManager.deserialize_tabs(tabs_data)
		for tab in restored_tabs:
			ide.add_tab(tab)
		var focus_idx = int(runtime.get("focused_index", 0))
		if focus_idx >= 0 and focus_idx < ide.tabs.size():
			ide._switch_to_tab(focus_idx)
		elif not ide.tabs.is_empty():
			ide._restore_tab_visual(0)
		_update_hud_task_info()

	# Backward compat: old saves with single active_contract
	elif runtime.get("active_contract") != null:
		ide.reset_to_idle()
		var contract = runtime["active_contract"]
		var tab = CodingTab.new()
		tab.contract = contract
		tab.total_tasks = contract.task_count
		tab.task_index = contract.task_count - int(runtime.get("tasks_remaining", 0))
		tab.difficulty_modifier = float(runtime.get("difficulty_modifier", 1.0))
		var loop_data = runtime.get("coding_loop")
		if loop_data is Dictionary and not loop_data.is_empty():
			SaveManager.deserialize_coding_loop(tab.coding_loop, loop_data)
		ide.add_tab(tab)
		ide._restore_tab_visual(0)
		_update_hud_task_info()

	_update_click_power()

# ── Pause Menu ──

func _open_pause_menu():
	_pause_open = true
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 90
	add_child(pause_layer)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(200, 40)
	resume_btn.pressed.connect(_close_pause_menu)
	vbox.add_child(resume_btn)

	var save_btn = Button.new()
	save_btn.text = "Save Game"
	save_btn.custom_minimum_size = Vector2(200, 40)
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)

	var load_btn = Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(200, 40)
	load_btn.pressed.connect(_on_load_pressed)
	load_btn.disabled = not SaveManager.has_save()
	vbox.add_child(load_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(200, 40)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

func _close_pause_menu():
	if pause_layer:
		pause_layer.queue_free()
		pause_layer = null
	_pause_open = false

func _on_autosave():
	if not _game_started:
		return
	var runtime = _collect_runtime_state()
	SaveManager.save_game(runtime)

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _game_started:
			var runtime = _collect_runtime_state()
			SaveManager.save_game(runtime)

func _on_quit_pressed():
	# Save before quitting
	var runtime = _collect_runtime_state()
	SaveManager.save_game(runtime)
	_close_pause_menu()
	if OS.has_feature("web"):
		_return_to_welcome()
	else:
		get_tree().quit()

func _return_to_welcome():
	_game_started = false
	autosave_timer.stop()
	contract_offer_timer.stop()
	event_timer.stop()
	salary_timer.stop()

	# Reset view state
	if state == DeskState.ZOOMED_TO_MONITOR:
		ide_layer.visible = false
	if state == DeskState.OVERLAY_OPEN:
		overlay_layer.visible = false
		if _current_overlay:
			_current_overlay.visible = false
		_current_overlay = null
	state = DeskState.DESK
	desk_scene.scale = Vector2.ONE
	desk_scene.position = Vector2.ZERO
	desk_scene.visible = true

	# Hide management
	if _in_management:
		management_layer.visible = false
		management_overlay_layer.visible = false
		_in_management = false

	# Rebuild welcome screen
	_build_welcome_layer()

func _on_save_pressed():
	var runtime = _collect_runtime_state()
	SaveManager.save_game(runtime)
	_close_pause_menu()

func _on_load_pressed():
	var data = SaveManager.load_game()
	if data.is_empty():
		_close_pause_menu()
		return
	var runtime = SaveManager.apply_save(data)
	_apply_runtime_state(runtime)
	# Reset to desk view
	if state == DeskState.ZOOMED_TO_MONITOR:
		ide_layer.visible = false
		state = DeskState.DESK
		desk_scene.zoom_to_desk()
	elif state == DeskState.OVERLAY_OPEN:
		_hide_overlay()
	hud.update_team_info(GameState.consultants.size(), GameState.active_assignments.size())
	_update_ai_status()
	_close_pause_menu()

# ── Desk Interactions ──

func _on_monitor_clicked():
	if state != DeskState.DESK:
		return
	state = DeskState.ZOOMED_TO_MONITOR
	var tween = desk_scene.zoom_to_monitor()
	tween.finished.connect(func(): ide_layer.visible = true)

func _on_stand_up():
	if state != DeskState.ZOOMED_TO_MONITOR:
		return
	ide_layer.visible = false
	state = DeskState.DESK
	desk_scene.zoom_to_desk()

func _on_phone_clicked():
	if state != DeskState.DESK:
		return
	desk_scene.set_phone_glowing(false)
	bidding_panel.refresh_contracts()
	_show_overlay(bidding_panel)

func _on_books_clicked():
	if state != DeskState.DESK:
		return
	skill_panel.refresh()
	_show_overlay(skill_panel)

func _on_email_clicked():
	if state != DeskState.DESK:
		return
	_refresh_email_display()
	_show_overlay(email_panel)

func _on_laptop_clicked():
	if state != DeskState.DESK:
		return
	ai_tool_panel.refresh()
	_show_overlay(ai_tool_panel)

func _on_door_clicked():
	if state != DeskState.DESK:
		return
	if not GameState.office_unlocked:
		return
	_switch_to_management()

# ── Overlay Management ──

func _show_overlay(panel: Control):
	state = DeskState.OVERLAY_OPEN
	_current_overlay = panel
	panel.visible = true
	overlay_layer.visible = true

func _hide_overlay():
	if state != DeskState.OVERLAY_OPEN:
		return
	if _current_overlay:
		_current_overlay.visible = false
	_current_overlay = null
	overlay_layer.visible = false
	state = DeskState.DESK

func _on_dimmer_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_overlay()

# ── Management Scene ──

func _switch_to_management():
	if not GameState.office_unlocked:
		return
	_in_management = true
	desk_scene.visible = false
	if state == DeskState.ZOOMED_TO_MONITOR:
		ide_layer.visible = false
	management_layer.visible = true
	management_office.refresh()

func _switch_to_personal():
	_in_management = false
	management_layer.visible = false
	management_overlay_layer.visible = false
	desk_scene.visible = true
	if state == DeskState.ZOOMED_TO_MONITOR:
		ide_layer.visible = true

func _show_management_overlay(panel: Control):
	_management_current_overlay = panel
	panel.visible = true
	management_overlay_layer.visible = true

func _hide_management_overlay():
	if _management_current_overlay:
		_management_current_overlay.visible = false
	_management_current_overlay = null
	management_overlay_layer.visible = false

func _on_management_dimmer_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_management_overlay()

# ── Contract Flow ──

func _on_contract_accepted(contract: ClientContract, diff_mod: float):
	_work_personally(contract, diff_mod)

func _work_personally(contract: ClientContract, diff_mod: float):
	# Check tab limit
	var tab_limit = ai_tool_manager.get_tab_limit(GameState)
	if ide.tabs.size() >= tab_limit:
		hud.set_task_info("Tab limit reached! Upgrade Auto-Writer for more tabs.")
		_hide_overlay()
		return

	var tab = CodingTab.new()
	tab.contract = contract
	tab.total_tasks = contract.task_count
	tab.task_index = 0
	tab.difficulty_modifier = diff_mod
	ide.add_tab(tab)
	_update_click_power()

	var has_ai = GameState.ai_tools.get("auto_writer", 0) > 0
	var all_tabs_full = ide.tabs.size() >= tab_limit
	if not has_ai or all_tabs_full:
		_hide_overlay()

	# Auto-zoom to monitor after accepting contract (skip if AI has free tabs)
	if state == DeskState.DESK and (not has_ai or all_tabs_full):
		_on_monitor_clicked()

	# Wait for zoom to finish, then start first task on this tab
	var timer = get_tree().create_timer(0.35)
	timer.timeout.connect(_start_next_task_on_tab.bind(tab))

func _start_next_task_on_tab(tab: CodingTab):
	if tab.is_contract_done():
		_on_tab_contract_finished(tab)
		return
	var tier = tab.contract.tier
	var task = task_factory.generate_task(tier)
	task.payout = tab.contract.payout_per_task
	task.difficulty = clampi(roundi(task.difficulty * tab.difficulty_modifier), 1, 10)
	task.total_clicks = roundi(task.total_clicks * tab.difficulty_modifier)
	_update_hud_task_info()
	ide.start_task_on_tab(tab, task)

func _on_tab_task_done(task: CodingTask, tab: CodingTab):
	# Track manual task completion (focused tab while at monitor)
	var tab_idx = ide.tabs.find(tab)
	if tab_idx == ide.get_focused_index() and state == DeskState.ZOOMED_TO_MONITOR:
		GameState.increment_manual_tasks()
	tab.task_index += 1
	if not tab.is_contract_done():
		var delay = get_tree().create_timer(1.5)
		delay.timeout.connect(_start_next_task_on_tab.bind(tab))
	else:
		_on_tab_contract_finished(tab)
	_update_hud_task_info()

func _on_tab_contract_finished(tab: CodingTab):
	var idx = ide.tabs.find(tab)
	if idx >= 0:
		ide.remove_tab(idx)
	if ide.tabs.is_empty():
		hud.set_task_info("Contract complete! Find a new one.")
		# Zoom back to desk if at monitor
		if state == DeskState.ZOOMED_TO_MONITOR:
			_on_stand_up()
	else:
		_update_hud_task_info()

func _update_hud_task_info():
	if ide.tabs.is_empty():
		hud.set_task_info("")
		return
	if ide.tabs.size() == 1:
		var tab = ide.tabs[0]
		hud.set_task_info("%s — Task %d/%d" % [
			tab.contract.client_name,
			tab.task_index + 1,
			tab.total_tasks
		])
	else:
		var active_count = ide.tabs.size()
		var stuck_count = ide.get_stuck_count()
		var info = "%d contracts active" % active_count
		if stuck_count > 0:
			info += " (%d stuck)" % stuck_count
		hud.set_task_info(info)

func _update_click_power():
	ide.set_click_power(skill_manager.calculate_click_power(GameState))

# ── AI Status ──

func _update_ai_status():
	var active_tools: int = 0
	for tool_id in GameState.ai_tools:
		if GameState.ai_tools[tool_id] > 0:
			active_tools += 1
	hud.update_ai_info(active_tools)

# ── Management Actions ──

func _on_management_assign(consultant: ConsultantData, contract: ClientContract):
	consultant.location = ConsultantData.Location.ON_PROJECT
	consultant.training_skill = ""
	consultant_manager.create_assignment(contract, [consultant], GameState)
	management_office.refresh()

func _on_management_rental(consultant: ConsultantData, offer: Dictionary):
	consultant_manager.place_on_rental(
		consultant, offer["client_name"], offer["rate_per_tick"], offer["duration"], GameState
	)
	management_office.refresh()

func _on_fire_consultant(consultant: ConsultantData):
	if not consultant.is_available():
		return
	GameState.remove_consultant(consultant)
	staff_roster.refresh()
	management_office.refresh()

func _on_train_consultant(consultant: ConsultantData, skill_id: String):
	consultant_manager.start_training(consultant, skill_id)
	staff_roster.refresh()
	management_office.refresh()

func _on_stop_training(consultant: ConsultantData):
	consultant_manager.stop_training(consultant)
	staff_roster.refresh()
	management_office.refresh()

func _on_set_remote(consultant: ConsultantData, remote: bool):
	if remote:
		consultant.location = ConsultantData.Location.REMOTE
	else:
		var in_office = GameState.get_consultants_by_location(ConsultantData.Location.IN_OFFICE).size()
		if in_office < GameState.desk_capacity:
			consultant.location = ConsultantData.Location.IN_OFFICE
	staff_roster.refresh()
	management_office.refresh()

func _on_rental_extension_accepted(rental: ConsultantRental):
	consultant_manager.extend_rental(rental, rental.total_duration)
	_pending_extensions.erase(rental)
	management_inbox.set_notifications(_pending_extensions, _pending_issues)

func _on_management_issue_choice(issue: ManagementIssue, choice_index: int):
	consultant_manager.apply_issue_choice(issue, choice_index, GameState)
	_pending_issues.erase(issue)
	management_inbox.set_notifications(_pending_extensions, _pending_issues)

# ── Random Events + Management Issues ──

func _on_event_timer():
	var event = event_manager.generate_event()
	desk_scene.set_email_badge_count(event_manager.get_unread_count())
	EventBus.random_event_received.emit(event)

func _on_email_choice(event: RandomEvent, choice_index: int):
	event_manager.apply_choice(event, choice_index, GameState)
	desk_scene.set_email_badge_count(event_manager.get_unread_count())
	_refresh_email_display()
	EventBus.random_event_resolved.emit(event)
	if event_manager.pending_events.is_empty():
		_hide_overlay()

func _refresh_email_display():
	email_panel.display_events(event_manager.pending_events.duplicate())

# ── Message Expiry ──

func _expire_old_messages():
	var now = Time.get_ticks_msec() / 1000.0
	var changed = false
	var j = event_manager.pending_events.size() - 1
	while j >= 0:
		if event_manager.pending_events[j].is_expired(now):
			event_manager.pending_events.remove_at(j)
			changed = true
		j -= 1
	if changed:
		desk_scene.set_email_badge_count(event_manager.get_unread_count())

# ── Salary Timer ──

func _on_salary_timer():
	if GameState.consultants.is_empty():
		return
	consultant_manager.pay_salaries(GameState)
