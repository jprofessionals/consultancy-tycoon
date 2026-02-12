extends PanelContainer

var bidding_system: BiddingSystem = BiddingSystem.new()
var active_contracts: Array[ClientContract] = []
var contract_list: VBoxContainer

signal contract_accepted(contract: ClientContract, difficulty_modifier: float)
signal close_requested

func _ready():
	_build_ui()

func _build_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "Available Contracts"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	contract_list = VBoxContainer.new()
	contract_list.add_theme_constant_override("separation", 4)
	vbox.add_child(contract_list)

func refresh_contracts():
	active_contracts = bidding_system.generate_contracts(3, GameState.reputation)
	_display_contracts()

func _display_contracts():
	for child in contract_list.get_children():
		child.queue_free()

	for contract in active_contracts:
		var card = _create_contract_card(contract)
		contract_list.add_child(card)

func _create_contract_card(contract: ClientContract) -> PanelContainer:
	var card = PanelContainer.new()
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label = Label.new()
	name_label.text = "%s — %s" % [contract.client_name, contract.project_description]
	info.add_child(name_label)

	var details_label = Label.new()
	var tier_names = ["", "Freelance", "Short-term", "Retainer", "SaaS"]
	var skills_text = ", ".join(contract.required_skills.keys()) if not contract.required_skills.is_empty() else "none"
	details_label.text = "%s | %d tasks | $%.0f/task | Skills: %s" % [
		tier_names[contract.tier], contract.task_count,
		contract.payout_per_task, skills_text
	]
	details_label.add_theme_font_size_override("font_size", 12)
	info.add_child(details_label)

	var bid_chance = bidding_system.calculate_bid_chance(contract, GameState.skills)
	var chance_label = Label.new()
	chance_label.text = "%.0f%% chance" % (bid_chance * 100)
	hbox.add_child(chance_label)

	var bid_btn = Button.new()
	bid_btn.text = "Bid"
	bid_btn.pressed.connect(func(): _on_bid(contract))
	hbox.add_child(bid_btn)

	return card

func _on_bid(contract: ClientContract):
	var success = bidding_system.attempt_bid(contract, GameState.skills)
	if success:
		var diff_mod = bidding_system.get_difficulty_modifier(contract, GameState.skills)
		active_contracts.erase(contract)
		_display_contracts()
		contract_accepted.emit(contract, diff_mod)
	else:
		active_contracts.erase(contract)
		_display_contracts()
