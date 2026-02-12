extends Resource
class_name ConsultantAssignment

var contract: ClientContract
var consultants: Array = []  # Array of ConsultantData
var current_task_index: int = 0
var current_task_progress: float = 0.0

func get_total_tasks() -> int:
	return contract.task_count if contract else 0

func is_complete() -> bool:
	return current_task_index >= get_total_tasks()

func get_team_speed(base_speed: float) -> float:
	if consultants.is_empty():
		return 0.0
	var total_speed: float = 0.0
	for c in consultants:
		var skill_match = c.get_skill_match(contract.required_skills)
		total_speed += base_speed * c.get_speed_multiplier() * skill_match
	# Synergy bonus from team players
	var synergy = _calculate_synergy()
	return total_speed * (1.0 + synergy)

func _calculate_synergy() -> float:
	if consultants.size() <= 1:
		return 0.0
	var synergy: float = 0.0
	for c in consultants:
		synergy += c.get_synergy_bonus()
	return synergy

func get_earnings_per_task() -> float:
	# Team earns 70% of player rate
	return contract.payout_per_task * 0.7 if contract else 0.0
