extends Node

var money: float = 0.0
var reputation: float = 0.0
var skills: Dictionary = {}

func _get_event_bus() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() else null

func add_money(amount: float) -> void:
	money += amount
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
