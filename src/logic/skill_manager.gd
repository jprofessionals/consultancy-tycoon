extends RefCounted
class_name SkillManager

var _skills: Array[SkillData] = []

func _init():
	_define_skills()

func _define_skills():
	_skills.append(_make_skill("coding_speed", "Coding Speed", "Write code faster — more progress per click", "soft_skill", 50.0, 5))
	_skills.append(_make_skill("code_quality", "Code Quality", "Fewer review rejections", "soft_skill", 75.0, 5))
	_skills.append(_make_skill("javascript", "JavaScript", "Unlocks web development contracts", "language", 100.0, 5))
	_skills.append(_make_skill("python", "Python", "Unlocks data and backend contracts", "language", 100.0, 5))
	_skills.append(_make_skill("devops", "DevOps", "Reduces CI failure chance", "framework", 150.0, 5))
	_skills.append(_make_skill("frameworks", "Frameworks", "Unlocks higher-tier contracts", "framework", 120.0, 5))
	_skills.append(_make_skill("negotiation", "Negotiation", "Better bidding success rates", "soft_skill", 80.0, 3))

func _make_skill(id: String, skill_name: String, desc: String, cat: String, base_cost: float, max_lvl: int) -> SkillData:
	var s = SkillData.new()
	s.id = id
	s.name = skill_name
	s.description = desc
	s.category = cat
	s.cost = base_cost
	s.max_level = max_lvl
	return s

func get_all_skills() -> Array[SkillData]:
	return _skills

func try_purchase(skill: SkillData, state: Node) -> bool:
	var current_level = state.get_skill_level(skill.id)
	if current_level >= skill.max_level:
		return false
	var price = skill.get_cost_for_level(current_level)
	if not state.spend_money(price):
		return false
	state.set_skill_level(skill.id, current_level + 1)
	return true

func calculate_click_power(state: Node) -> float:
	return 1.0 + state.get_skill_level("coding_speed") * 0.3

func calculate_review_bonus(state: Node) -> float:
	return state.get_skill_level("code_quality") * 0.05

func calculate_bid_bonus(state: Node) -> float:
	return state.get_skill_level("negotiation") * 0.08
