extends PanelContainer

signal close_requested
signal consultant_assigned(consultant: ConsultantData, contract: ClientContract)
signal consultant_placed_on_rental(consultant: ConsultantData, offer: Dictionary)

var bidding_system: BiddingSystem = BiddingSystem.new()
var consultant_manager: ConsultantManager = ConsultantManager.new()
var contracts: Array = []
var rental_offers: Array = []
var current_tab: String = "projects"

@onready var _card_list: VBoxContainer = %CardList
@onready var _projects_btn: Button = %ProjectsBtn
@onready var _rentals_btn: Button = %RentalsBtn
@onready var _close_btn: Button = %CloseBtn

func _ready():
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	UITheme.style_button(_close_btn)
	_close_btn.pressed.connect(func(): close_requested.emit())
	_projects_btn.pressed.connect(func(): _switch_tab("projects"))
	_rentals_btn.pressed.connect(func(): _switch_tab("rentals"))

func _switch_tab(tab: String):
	current_tab = tab
	_update_tab_buttons()
	_rebuild_cards()

func _update_tab_buttons():
	_projects_btn.disabled = (current_tab == "projects")
	_rentals_btn.disabled = (current_tab == "rentals")

func refresh():
	contracts = bidding_system.generate_management_contracts(4, GameState.reputation)
	rental_offers = consultant_manager.generate_rental_offers(3, GameState.reputation)
	_update_tab_buttons()
	_rebuild_cards()

func _rebuild_cards():
	for child in _card_list.get_children():
		child.queue_free()

	if current_tab == "projects":
		_build_project_cards()
	else:
		_build_rental_cards()

func _build_project_cards():
	var tier_names = ["", "Freelance", "Short-term", "Retainer", "SaaS"]
	for contract in contracts:
		var card = _create_card_container()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		# Client name + description
		var name_label = Label.new()
		name_label.text = "%s — %s" % [contract.client_name, contract.project_description]
		name_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_label)

		# Tier / tasks / payout info (at 70% rate)
		var team_rate = contract.payout_per_task * 0.7
		var details = Label.new()
		details.text = "%s | %d tasks | $%.0f/task (team 70%%) | Total: $%.0f" % [
			tier_names[contract.tier], contract.task_count,
			team_rate, contract.task_count * team_rate
		]
		details.add_theme_font_size_override("font_size", 12)
		details.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
		vbox.add_child(details)

		# Skill requirements
		if not contract.required_skills.is_empty():
			var skill_parts: Array = []
			for skill_id in contract.required_skills:
				skill_parts.append("%s Lv%d" % [skill_id, contract.required_skills[skill_id]])
			var skills_label = Label.new()
			skills_label.text = "Requires: %s" % ", ".join(skill_parts)
			skills_label.add_theme_font_size_override("font_size", 11)
			skills_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
			vbox.add_child(skills_label)

		# Assign buttons
		var available = GameState.get_available_consultants()
		if available.is_empty():
			var no_staff = Label.new()
			no_staff.text = "No available consultants"
			no_staff.add_theme_font_size_override("font_size", 11)
			no_staff.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
			vbox.add_child(no_staff)
		else:
			var btn_row = HBoxContainer.new()
			btn_row.add_theme_constant_override("separation", 4)
			vbox.add_child(btn_row)
			for c in available:
				var btn = Button.new()
				btn.text = "Assign %s" % c.name
				btn.pressed.connect(_on_assign_consultant.bind(c, contract))
				btn_row.add_child(btn)

		_card_list.add_child(card)

func _build_rental_cards():
	for offer in rental_offers:
		var card = _create_card_container()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		# Client name
		var name_label = Label.new()
		name_label.text = "%s — Consultant Rental" % offer["client_name"]
		name_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_label)

		# Rate / duration / estimated total
		var est_total = offer["rate_per_tick"] * offer["duration"]
		var details = Label.new()
		details.text = "$%.1f/sec | %.0fs duration | Est. total: $%.0f" % [
			offer["rate_per_tick"], offer["duration"], est_total
		]
		details.add_theme_font_size_override("font_size", 12)
		details.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
		vbox.add_child(details)

		# Skill requirements
		var required = offer.get("required_skills", {})
		if not required.is_empty():
			var skill_parts: Array = []
			for skill_id in required:
				skill_parts.append("%s Lv%d" % [skill_id, required[skill_id]])
			var skills_label = Label.new()
			skills_label.text = "Requires: %s" % ", ".join(skill_parts)
			skills_label.add_theme_font_size_override("font_size", 11)
			skills_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
			vbox.add_child(skills_label)

		# Send buttons for available consultants
		var available = GameState.get_available_consultants()
		if available.is_empty():
			var no_staff = Label.new()
			no_staff.text = "No available consultants"
			no_staff.add_theme_font_size_override("font_size", 11)
			no_staff.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
			vbox.add_child(no_staff)
		else:
			var btn_row = HBoxContainer.new()
			btn_row.add_theme_constant_override("separation", 4)
			vbox.add_child(btn_row)
			for c in available:
				var btn = Button.new()
				btn.text = "Send %s" % c.name
				btn.pressed.connect(_on_place_rental.bind(c, offer))
				btn_row.add_child(btn)

		_card_list.add_child(card)

func _create_card_container() -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())
	return card

func _on_assign_consultant(consultant: ConsultantData, contract: ClientContract):
	contracts.erase(contract)
	consultant_assigned.emit(consultant, contract)
	_rebuild_cards()

func _on_place_rental(consultant: ConsultantData, offer: Dictionary):
	rental_offers.erase(offer)
	consultant_placed_on_rental.emit(consultant, offer)
	_rebuild_cards()
