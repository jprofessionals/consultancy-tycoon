extends Control

enum DeskState { DESK, ZOOMED_TO_MONITOR, OVERLAY_OPEN }

var state: DeskState = DeskState.DESK
var desk_scene: Control
var hud: HBoxContainer
var ide: PanelContainer
var bidding_panel: PanelContainer
var skill_panel: PanelContainer
var email_panel: PanelContainer
var ai_tool_panel: PanelContainer
var hiring_panel: PanelContainer
var task_factory: TaskFactory = TaskFactory.new()
var skill_manager: SkillManager = SkillManager.new()
var event_manager: EventManager = EventManager.new()

# AI + Consultant systems
var ai_tool_runner: AiToolRunner = AiToolRunner.new()
var consultant_manager: ConsultantManager = ConsultantManager.new()

# Layers
var hud_layer: CanvasLayer
var ide_layer: CanvasLayer
var overlay_layer: CanvasLayer
var welcome_layer: CanvasLayer
var dimmer: ColorRect
var stand_up_btn: Button

# Active contract tracking
var active_contract: ClientContract = null
var tasks_remaining: int = 0
var difficulty_modifier: float = 1.0
var contract_offer_timer: Timer
var event_timer: Timer
var salary_timer: Timer

# Management issues queue (flows through email panel)
var _pending_issues: Array = []

# Team assignment picker state
var _team_assign_contract: ClientContract = null
var _team_assign_diff_mod: float = 1.0

# Currently shown overlay panel
var _current_overlay: Control = null

# Game started flag (suppress _process before start)
var _game_started: bool = false

func _ready():
	_build_desk()
	_build_hud_layer()
	_build_ide_layer()
	_build_overlay_layer()
	_build_welcome_layer()
	_connect_signals()
	_setup_timers()

func _process(delta: float):
	if not _game_started:
		return

	# AI tool runner auto-progresses the player's coding loop
	if ide.coding_loop.state != CodingLoop.State.IDLE and ide.coding_loop.state != CodingLoop.State.COMPLETE:
		ai_tool_runner.tick(delta, ide.coding_loop, GameState)

	# Consultant assignment ticking
	var completed = consultant_manager.tick_assignments(delta, GameState)
	for assignment in completed:
		EventBus.assignment_completed.emit(assignment)
		hud.update_team_info(GameState.consultants.size(), GameState.active_assignments.size())

	# Management issue generation (roughly every 8 min)
	if not GameState.consultants.is_empty():
		var issue = consultant_manager.try_generate_issue(GameState)
		if issue:
			_pending_issues.append(issue)
			desk_scene.set_email_badge_count(event_manager.get_unread_count() + _pending_issues.size())
			EventBus.management_issue.emit(issue)

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

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	hud_layer.add_child(margin)

	hud = load("res://src/ui/hud.tscn").instantiate()
	margin.add_child(hud)

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

	hiring_panel = load("res://src/ui/hiring_panel.tscn").instantiate()
	hiring_panel.visible = false
	center.add_child(hiring_panel)

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

	var start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(200, 50)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(_on_start_game)
	content.add_child(start_btn)

func _connect_signals():
	bidding_panel.contract_accepted.connect(_on_contract_accepted)
	bidding_panel.close_requested.connect(_hide_overlay)
	skill_panel.close_requested.connect(_hide_overlay)
	email_panel.close_requested.connect(_hide_overlay)
	email_panel.choice_made.connect(_on_email_choice)
	ai_tool_panel.close_requested.connect(_hide_overlay)
	hiring_panel.close_requested.connect(_hide_overlay)
	ide.coding_loop.task_done.connect(_on_task_completed)
	EventBus.skill_purchased.connect(func(_id): _update_click_power())
	EventBus.ai_tool_upgraded.connect(func(_tid, _tier): _update_ai_status())

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

# ── Game Start ──

func _on_start_game():
	welcome_layer.queue_free()
	welcome_layer = null
	_game_started = true
	bidding_panel.refresh_contracts()
	desk_scene.set_phone_glowing(true)
	contract_offer_timer.start()
	event_timer.start()
	salary_timer.start()

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
	hiring_panel.refresh()
	_show_overlay(hiring_panel)

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

# ── Contract Flow ──

func _on_contract_accepted(contract: ClientContract, diff_mod: float):
	# If office is unlocked and we have consultants, offer choice
	if GameState.office_unlocked and not GameState.consultants.is_empty():
		_show_contract_choice(contract, diff_mod)
	else:
		_work_personally(contract, diff_mod)

func _show_contract_choice(contract: ClientContract, diff_mod: float):
	_team_assign_contract = contract
	_team_assign_diff_mod = diff_mod
	_hide_overlay()
	# Show a quick choice overlay
	var choice_panel = PanelContainer.new()
	var choice_style = StyleBoxFlat.new()
	choice_style.bg_color = Color(0.14, 0.14, 0.18)
	choice_style.set_content_margin_all(20)
	choice_style.set_corner_radius_all(8)
	choice_style.border_color = Color(0.3, 0.3, 0.35)
	choice_style.set_border_width_all(1)
	choice_panel.add_theme_stylebox_override("panel", choice_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	choice_panel.add_child(vbox)

	var label = Label.new()
	label.text = "How do you want to handle this contract?"
	label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(label)

	var contract_info = Label.new()
	contract_info.text = "%s — %s (%d tasks, $%.0f/task)" % [
		contract.client_name, contract.project_description,
		contract.task_count, contract.payout_per_task
	]
	contract_info.add_theme_font_size_override("font_size", 13)
	contract_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(contract_info)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var personal_btn = Button.new()
	personal_btn.text = "Work Personally (100% pay)"
	personal_btn.custom_minimum_size = Vector2(200, 40)
	personal_btn.pressed.connect(func():
		choice_panel.queue_free()
		_work_personally(_team_assign_contract, _team_assign_diff_mod)
	)
	btn_row.add_child(personal_btn)

	var team_btn = Button.new()
	team_btn.text = "Assign Team (70% pay)"
	team_btn.custom_minimum_size = Vector2(200, 40)
	team_btn.pressed.connect(func():
		choice_panel.queue_free()
		_assign_team(_team_assign_contract)
	)
	btn_row.add_child(team_btn)

	# Show in overlay layer
	state = DeskState.OVERLAY_OPEN
	_current_overlay = choice_panel
	overlay_layer.visible = true
	var center = overlay_layer.get_child(1)  # CenterContainer
	center.add_child(choice_panel)

func _work_personally(contract: ClientContract, diff_mod: float):
	active_contract = contract
	tasks_remaining = contract.task_count
	difficulty_modifier = diff_mod
	_update_click_power()
	_hide_overlay()
	# Auto-zoom to monitor after accepting contract
	_on_monitor_clicked()
	# Wait for zoom to finish, then start task
	var timer = get_tree().create_timer(0.35)
	timer.timeout.connect(_start_next_task)

func _assign_team(contract: ClientContract):
	# Assign all available consultants to this contract
	var team: Array = []
	for c in GameState.consultants:
		# Check if already on another assignment
		var busy = false
		for a in GameState.active_assignments:
			if c in a.consultants:
				busy = true
				break
		if not busy:
			team.append(c)
	if team.is_empty():
		# Fallback: no free consultants, work personally
		_work_personally(contract, _team_assign_diff_mod)
		return
	consultant_manager.create_assignment(contract, team, GameState)
	hud.update_team_info(GameState.consultants.size(), GameState.active_assignments.size())
	_hide_overlay()

func _start_next_task():
	if tasks_remaining <= 0:
		_on_contract_finished()
		return
	var tier = active_contract.tier
	var task = task_factory.generate_task(tier)
	task.payout = active_contract.payout_per_task
	task.difficulty = clampi(roundi(task.difficulty * difficulty_modifier), 1, 10)
	task.total_clicks = roundi(task.total_clicks * difficulty_modifier)
	hud.set_task_info("%s — Task %d/%d" % [
		active_contract.client_name,
		active_contract.task_count - tasks_remaining + 1,
		active_contract.task_count
	])
	ide.start_task(task)

func _on_task_completed(_task: CodingTask):
	tasks_remaining -= 1
	if tasks_remaining > 0:
		var delay = get_tree().create_timer(1.5)
		delay.timeout.connect(_start_next_task)
	else:
		_on_contract_finished()

func _on_contract_finished():
	active_contract = null
	hud.set_task_info("Contract complete! Find a new one.")
	ide.reset_to_idle()
	# Zoom back to desk
	if state == DeskState.ZOOMED_TO_MONITOR:
		_on_stand_up()

func _update_click_power():
	ide.set_click_power(skill_manager.calculate_click_power(GameState))

# ── AI Status ──

func _update_ai_status():
	var active_tools: int = 0
	for tool_id in GameState.ai_tools:
		if GameState.ai_tools[tool_id] > 0:
			active_tools += 1
	hud.update_ai_info(active_tools)

# ── Random Events + Management Issues ──

func _on_event_timer():
	var event = event_manager.generate_event()
	desk_scene.set_email_badge_count(event_manager.get_unread_count() + _pending_issues.size())
	EventBus.random_event_received.emit(event)

func _on_email_choice(event: RandomEvent, choice_index: int):
	# Check if this is a management issue disguised as an event
	var handled_issue = false
	for i in range(_pending_issues.size()):
		var issue = _pending_issues[i]
		if event.id == "mgmt_" + issue.id + "_" + issue.affected_consultant_id:
			consultant_manager.apply_issue_choice(issue, choice_index, GameState)
			_pending_issues.remove_at(i)
			handled_issue = true
			break

	if not handled_issue:
		event_manager.apply_choice(event, choice_index, GameState)

	desk_scene.set_email_badge_count(event_manager.get_unread_count() + _pending_issues.size())
	_refresh_email_display()
	EventBus.random_event_resolved.emit(event)
	if event_manager.pending_events.is_empty() and _pending_issues.is_empty():
		_hide_overlay()

func _refresh_email_display():
	# Merge random events and management issues into email display
	var all_events: Array = event_manager.pending_events.duplicate()
	for issue in _pending_issues:
		# Convert ManagementIssue to RandomEvent for display
		var event = RandomEvent.create(
			"mgmt_" + issue.id + "_" + issue.affected_consultant_id,
			"[Team] " + issue.title,
			issue.description,
			issue.choices
		)
		all_events.append(event)
	email_panel.display_events(all_events)

# ── Salary Timer ──

func _on_salary_timer():
	if GameState.consultants.is_empty():
		return
	consultant_manager.pay_salaries(GameState)
