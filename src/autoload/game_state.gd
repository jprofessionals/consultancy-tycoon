extends Node

var money: float = 0.0
var reputation: float = 0.0
var skills: Dictionary = {}
var ai_tools: Dictionary = {}  # tool_id -> tier (int, 0 = not owned)
var office_unlocked: bool = false
var consultants: Array = []  # Array of ConsultantData
var active_assignments: Array = []  # Array of ConsultantAssignment
var claimed_easter_eggs: Dictionary = {}  # easter_egg_id -> true
var desk_capacity: int = 4
var active_rentals: Array = []  # Array of ConsultantRental
var total_money_earned: float = 0.0
var total_manual_tasks_completed: int = 0
var player_name: String = ""

func _get_event_bus() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() else null

func add_money(amount: float) -> void:
	money += amount
	if amount > 0:
		total_money_earned += amount
	var bus = _get_event_bus()
	if bus:
		bus.money_changed.emit(money)

func spend_money(amount: float) -> bool:
	if money < amount:
		return false
	money -= amount
	var bus = _get_event_bus()
	if bus:
		bus.money_changed.emit(money)
	return true

func increment_manual_tasks() -> void:
	total_manual_tasks_completed += 1

func add_reputation(amount: float) -> void:
	reputation += amount
	var bus = _get_event_bus()
	if bus:
		bus.reputation_changed.emit(reputation)

func get_skill_level(skill_id: String) -> int:
	return skills.get(skill_id, 0)

func set_skill_level(skill_id: String, level: int) -> void:
	skills[skill_id] = level
	var bus = _get_event_bus()
	if bus:
		bus.skill_purchased.emit(skill_id)

func get_ai_tool_tier(tool_id: String) -> int:
	return ai_tools.get(tool_id, 0)

func set_ai_tool_tier(tool_id: String, tier: int) -> void:
	ai_tools[tool_id] = tier
	var bus = _get_event_bus()
	if bus:
		bus.ai_tool_upgraded.emit(tool_id, tier)

func unlock_office() -> bool:
	if office_unlocked:
		return false
	office_unlocked = true
	var bus = _get_event_bus()
	if bus:
		bus.office_unlocked.emit()
	return true

func add_consultant(consultant: ConsultantData) -> void:
	consultants.append(consultant)
	var bus = _get_event_bus()
	if bus:
		bus.consultant_hired.emit(consultant)

func remove_consultant(consultant: ConsultantData) -> void:
	consultants.erase(consultant)
	var bus = _get_event_bus()
	if bus:
		bus.consultant_left.emit(consultant)

func add_assignment(assignment: ConsultantAssignment) -> void:
	active_assignments.append(assignment)

func remove_assignment(assignment: ConsultantAssignment) -> void:
	active_assignments.erase(assignment)

func get_total_salary() -> float:
	var total: float = 0.0
	for c in consultants:
		total += c.salary
	return total

func add_rental(rental: ConsultantRental) -> void:
	active_rentals.append(rental)

func remove_rental(rental: ConsultantRental) -> void:
	active_rentals.erase(rental)

func get_max_staff() -> int:
	return desk_capacity * 3

func can_hire() -> bool:
	return consultants.size() < get_max_staff()

func get_consultants_by_location(loc: int) -> Array:
	var result: Array = []
	for c in consultants:
		if c.location == loc:
			result.append(c)
	return result

func get_available_consultants() -> Array:
	var result: Array = []
	for c in consultants:
		if c.is_available():
			result.append(c)
	return result
