extends Resource
class_name ConsultantData

enum Location { IN_OFFICE, REMOTE, ON_PROJECT, ON_RENTAL }

var id: String = ""
var name: String = ""
var skills: Dictionary = {}  # skill_id -> level
var salary: float = 500.0  # per pay period
var trait_id: String = ""  # "fast", "careful", "social", "lazy"
var morale: float = 1.0  # 0.0-1.0, affects productivity
var location: Location = Location.IN_OFFICE
var training_skill: String = ""  # empty = not training

const TRAITS = {
	"fast": {"speed_mult": 1.3, "quality_mult": 0.85, "label": "Fast Worker"},
	"careful": {"speed_mult": 0.8, "quality_mult": 1.2, "label": "Perfectionist"},
	"social": {"speed_mult": 1.0, "quality_mult": 1.0, "synergy_bonus": 0.15, "label": "Team Player"},
	"lazy": {"speed_mult": 0.7, "quality_mult": 0.9, "label": "Slacker"},
}

func get_speed_multiplier() -> float:
	var trait_data = TRAITS.get(trait_id, {})
	return trait_data.get("speed_mult", 1.0) * morale

func get_quality_multiplier() -> float:
	var trait_data = TRAITS.get(trait_id, {})
	return trait_data.get("quality_mult", 1.0)

func get_synergy_bonus() -> float:
	var trait_data = TRAITS.get(trait_id, {})
	return trait_data.get("synergy_bonus", 0.0)

func get_trait_label() -> String:
	var trait_data = TRAITS.get(trait_id, {})
	return trait_data.get("label", "Normal")

func get_skill_match(required_skills: Dictionary) -> float:
	if required_skills.is_empty():
		return 1.0
	var total_match: float = 0.0
	var count: int = 0
	for skill_id in required_skills:
		var required = required_skills[skill_id]
		var have = skills.get(skill_id, 0)
		total_match += clampf(float(have) / maxf(required, 1), 0.0, 1.5)
		count += 1
	return total_match / maxf(count, 1)

func is_available() -> bool:
	return location == Location.IN_OFFICE or location == Location.REMOTE

func is_trainable() -> bool:
	return location == Location.IN_OFFICE or location == Location.REMOTE
