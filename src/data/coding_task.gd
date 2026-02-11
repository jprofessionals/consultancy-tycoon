extends Resource
class_name CodingTask

var title: String = ""
var description: String = ""
var difficulty: int = 1  # 1-10
var payout: float = 0.0
var total_clicks: int = 10
var required_skills: Dictionary = {}  # skill_id -> min_level

func get_review_reject_chance() -> float:
	return clampf(0.1 + difficulty * 0.08, 0.1, 0.9)

func get_conflict_chance() -> float:
	return clampf(difficulty * 0.06, 0.0, 0.5)
