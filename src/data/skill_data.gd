extends Resource
class_name SkillData

var id: String = ""
var name: String = ""
var description: String = ""
var category: String = ""  # "language", "framework", "soft_skill"
var cost: float = 100.0
var cost_multiplier: float = 1.8  # each level costs more
var max_level: int = 5

func get_cost_for_level(current_level: int) -> float:
	return cost * pow(cost_multiplier, current_level)
