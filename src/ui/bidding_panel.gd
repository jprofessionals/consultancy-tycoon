extends PanelContainer

var bidding_system: BiddingSystem = BiddingSystem.new()
var active_contracts: Array[ClientContract] = []

@onready var contract_list: VBoxContainer = %ContractList
@onready var _close_btn: Button = %CloseBtn

signal contract_accepted(contract: ClientContract, difficulty_modifier: float)
signal close_requested

func _ready():
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	UITheme.style_button(_close_btn)
	_close_btn.pressed.connect(func(): close_requested.emit())

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
	card.add_theme_stylebox_override("panel", UITheme.create_card_style())

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UITheme.RELAXED)
	card.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label = Label.new()
	name_label.text = "%s — %s" % [contract.client_name, contract.project_description]
	name_label.add_theme_font_size_override("font_size", UITheme.BODY)
	info.add_child(name_label)

	var details_label = Label.new()
	var tier_names = ["", "Freelance", "Short-term", "Retainer", "SaaS"]
	var skills_text = ", ".join(contract.required_skills.keys()) if not contract.required_skills.is_empty() else "none"
	details_label.text = "%s | %d tasks | $%.0f/task | Skills: %s" % [
		tier_names[contract.tier], contract.task_count,
		contract.payout_per_task, skills_text
	]
	details_label.add_theme_font_size_override("font_size", UITheme.SMALL)
	details_label.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	info.add_child(details_label)

	var bid_chance = bidding_system.calculate_bid_chance(contract, GameState.skills)
	var chance_label = Label.new()
	chance_label.text = "%.0f%% chance" % (bid_chance * 100)
	chance_label.add_theme_font_size_override("font_size", UITheme.SMALL)
	hbox.add_child(chance_label)

	var bid_btn = Button.new()
	bid_btn.text = "Bid"
	UITheme.style_button(bid_btn)
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
