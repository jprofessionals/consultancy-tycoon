extends Control

enum View { IDE, BIDDING, SKILLS }

var current_view: View = View.BIDDING
var ide: PanelContainer
var bidding_panel: PanelContainer
var skill_panel: PanelContainer
var hud: HBoxContainer
var nav_bar: HBoxContainer
var task_factory: TaskFactory = TaskFactory.new()
var skill_manager: SkillManager = SkillManager.new()

# Active contract tracking
var active_contract: ClientContract = null
var tasks_remaining: int = 0
var difficulty_modifier: float = 1.0
var contract_offer_timer: Timer

func _ready():
	_build_layout()
	_connect_signals()
	_setup_contract_timer()
	_show_view(View.BIDDING)
	bidding_panel.refresh_contracts()

func _build_layout():
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# HUD
	hud = load("res://src/ui/hud.tscn").instantiate()
	vbox.add_child(hud)

	# Nav bar
	nav_bar = HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(nav_bar)

	var ide_btn = Button.new()
	ide_btn.text = "IDE"
	ide_btn.pressed.connect(func(): _show_view(View.IDE))
	nav_bar.add_child(ide_btn)

	var bid_btn = Button.new()
	bid_btn.text = "Contracts"
	bid_btn.pressed.connect(func(): _show_view(View.BIDDING))
	nav_bar.add_child(bid_btn)

	var skill_btn = Button.new()
	skill_btn.text = "Skills"
	skill_btn.pressed.connect(func(): _show_view(View.SKILLS))
	nav_bar.add_child(skill_btn)

	# Content area
	var content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# IDE
	ide = load("res://src/ide/ide_interface.tscn").instantiate()
	ide.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(ide)

	# Bidding panel
	bidding_panel = load("res://src/ui/bidding_panel.tscn").instantiate()
	bidding_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(bidding_panel)

	# Skill panel
	skill_panel = load("res://src/ui/skill_panel.tscn").instantiate()
	skill_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(skill_panel)

func _connect_signals():
	bidding_panel.contract_accepted.connect(_on_contract_accepted)
	ide.coding_loop.task_done.connect(_on_task_completed)
	EventBus.skill_purchased.connect(func(_id): _update_click_power())

func _setup_contract_timer():
	contract_offer_timer = Timer.new()
	contract_offer_timer.wait_time = 30.0
	contract_offer_timer.autostart = true
	contract_offer_timer.timeout.connect(func(): bidding_panel.refresh_contracts())
	add_child(contract_offer_timer)

func _show_view(view: View):
	current_view = view
	ide.visible = view == View.IDE
	bidding_panel.visible = view == View.BIDDING
	skill_panel.visible = view == View.SKILLS
	if view == View.SKILLS:
		skill_panel.refresh()

func _on_contract_accepted(contract: ClientContract, diff_mod: float):
	active_contract = contract
	tasks_remaining = contract.task_count
	difficulty_modifier = diff_mod
	_update_click_power()
	_start_next_task()
	_show_view(View.IDE)

func _start_next_task():
	if tasks_remaining <= 0:
		_on_contract_finished()
		return
	var tier = active_contract.tier
	var task = task_factory.generate_task(tier)
	task.payout = active_contract.payout_per_task
	# Apply difficulty modifier from skill gap
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
		# Small delay before next task
		var delay = get_tree().create_timer(1.5)
		delay.timeout.connect(_start_next_task)
	else:
		_on_contract_finished()

func _on_contract_finished():
	active_contract = null
	hud.set_task_info("Contract complete! Find a new one.")
	_show_view(View.BIDDING)
	bidding_panel.refresh_contracts()

func _update_click_power():
	ide.set_click_power(skill_manager.calculate_click_power(GameState))
