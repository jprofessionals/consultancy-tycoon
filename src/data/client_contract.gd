extends Resource
class_name ClientContract

var client_name: String = ""
var project_description: String = ""
var tier: int = 1  # 1=freelance, 2=short-term, 3=retainer, 4=SaaS
var task_count: int = 1
var payout_per_task: float = 25.0
var required_skills: Dictionary = {}  # skill_id -> min_level
var duration: float = 60.0  # seconds before offer expires

func get_total_value() -> float:
	return task_count * payout_per_task
