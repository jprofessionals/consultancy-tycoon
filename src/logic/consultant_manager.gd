extends RefCounted
class_name ConsultantManager

const FIRST_NAMES = [
	"Alex", "Jordan", "Sam", "Casey", "Morgan", "Riley", "Taylor", "Quinn",
	"Avery", "Jamie", "Reese", "Dakota", "Sage", "Drew", "Blake", "Emery",
]

const LAST_NAMES = [
	"Chen", "Patel", "Kim", "Garcia", "Nguyen", "Mueller", "Tanaka", "Silva",
	"Okafor", "Larsson", "Roy", "Nowak", "Ferreira", "Khan", "Ivanov", "Park",
]

const OFFICE_UNLOCK_COST: float = 10000.0
const BASE_ASSIGNMENT_SPEED: float = 0.15  # progress per second per consultant
const ISSUE_CHANCE_PER_TICK: float = 0.0005  # ~every 30 min at 1 tick/sec
const PASSIVE_SKILL_RATE: float = 0.001  # XP per second per existing skill (very slow)
const ACTIVE_TRAINING_RATE: float = 0.01  # XP per second for active training (10x passive)
const REMOTE_PENALTY: float = 0.7  # 70% effectiveness for remote consultants
const TRAINING_COST_PER_SEC: float = 0.1  # $ per second of active training

var _issue_templates: Array[Dictionary] = []

func _init():
	_build_issue_templates()

func generate_job_market(count: int, reputation: float) -> Array:
	var market: Array = []
	for i in range(count):
		market.append(_generate_consultant(reputation))
	return market

func _generate_consultant(reputation: float) -> ConsultantData:
	var c = ConsultantData.new()
	c.id = str(randi())
	c.name = FIRST_NAMES[randi() % FIRST_NAMES.size()] + " " + LAST_NAMES[randi() % LAST_NAMES.size()]

	var traits = ConsultantData.TRAITS.keys()
	c.trait_id = traits[randi() % traits.size()]

	# Skills scale with reputation
	var skill_pool = ["javascript", "python", "devops", "frameworks", "coding_speed", "code_quality"]
	var num_skills = randi_range(1, 3)
	skill_pool.shuffle()
	for j in range(num_skills):
		var max_level = clampi(int(reputation / 15.0) + 1, 1, 5)
		c.skills[skill_pool[j]] = randi_range(1, max_level)

	# Salary scales with skills and trait
	var total_skill: int = 0
	for level in c.skills.values():
		total_skill += level
	c.salary = 300.0 + total_skill * 80.0 + randf_range(-50, 50)

	c.morale = clampf(0.6 + randf() * 0.4, 0.0, 1.0)
	return c

func get_hire_cost(consultant: ConsultantData) -> float:
	return consultant.salary  # 1x salary as hire fee

func try_hire(consultant: ConsultantData, state: Node) -> bool:
	var cost = get_hire_cost(consultant)
	if not state.spend_money(cost):
		return false
	state.add_consultant(consultant)
	return true

func create_assignment(contract: ClientContract, team: Array, state: Node) -> ConsultantAssignment:
	var assignment = ConsultantAssignment.new()
	assignment.contract = contract
	assignment.consultants = team
	state.add_assignment(assignment)
	return assignment

func tick_assignments(delta: float, state: Node) -> Array:
	# Returns array of completed assignments
	var completed: Array = []
	for assignment in state.active_assignments.duplicate():
		if assignment.is_complete():
			continue
		var speed = assignment.get_team_speed(BASE_ASSIGNMENT_SPEED)
		assignment.current_task_progress += speed * delta
		if assignment.current_task_progress >= 1.0:
			assignment.current_task_progress = 0.0
			assignment.current_task_index += 1
			var earnings = assignment.get_earnings_per_task()
			state.add_money(earnings)
			if assignment.is_complete():
				completed.append(assignment)
				state.remove_assignment(assignment)
				state.add_reputation(assignment.contract.tier * 2.0)
	return completed

func try_generate_issue(state: Node) -> ManagementIssue:
	if state.consultants.is_empty():
		return null
	if randf() > ISSUE_CHANCE_PER_TICK:
		return null
	var consultant = state.consultants[randi() % state.consultants.size()]
	return _generate_issue(consultant)

func _generate_issue(consultant: ConsultantData) -> ManagementIssue:
	var template = _issue_templates[randi() % _issue_templates.size()]
	var desc = template["description"].replace("{name}", consultant.name)
	return ManagementIssue.create(
		template["id"],
		template["title"].replace("{name}", consultant.name),
		desc,
		consultant.id,
		template["choices"]
	)

func apply_issue_choice(issue: ManagementIssue, choice_index: int, state: Node) -> void:
	if choice_index < 0 or choice_index >= issue.choices.size():
		return
	var choice = issue.choices[choice_index]
	var consultant: ConsultantData = null
	for c in state.consultants:
		if c.id == issue.affected_consultant_id:
			consultant = c
			break
	for effect in choice["effects"]:
		match effect["type"]:
			"morale_change":
				if consultant:
					consultant.morale = clampf(consultant.morale + effect["amount"], 0.0, 1.0)
			"spend_money":
				state.spend_money(effect["amount"])
			"add_money":
				state.add_money(effect["amount"])
			"fire":
				if consultant:
					state.remove_consultant(consultant)

func pay_salaries(state: Node) -> float:
	var total = state.get_total_salary()
	if total > 0:
		state.spend_money(total)
	return total

func tick_training(delta: float, state: Node) -> void:
	for c in state.consultants:
		if not c.is_trainable():
			continue
		var location_mult = REMOTE_PENALTY if c.location == ConsultantData.Location.REMOTE else 1.0
		if c.training_skill != "":
			var xp = ACTIVE_TRAINING_RATE * delta * location_mult
			_add_skill_xp(c, c.training_skill, xp)
			state.spend_money(TRAINING_COST_PER_SEC * delta)
		else:
			for skill_id in c.skills:
				var xp = PASSIVE_SKILL_RATE * delta * location_mult
				_add_skill_xp(c, skill_id, xp)

func _add_skill_xp(c: ConsultantData, skill_id: String, xp: float) -> void:
	var current = float(c.skills.get(skill_id, 0))
	c.skills[skill_id] = current + xp

func start_training(c: ConsultantData, skill_id: String) -> bool:
	if not c.is_trainable():
		return false
	c.training_skill = skill_id
	return true

func stop_training(c: ConsultantData) -> void:
	c.training_skill = ""

func _build_issue_templates():
	_issue_templates = [
		{
			"id": "burnout",
			"title": "{name} is Burning Out",
			"description": "{name} has been working long hours. A little attention now could go a long way.",
			"choices": [
				{"label": "Give a bonus (-$200)", "effects": [{"type": "spend_money", "amount": 200.0}, {"type": "morale_change", "amount": 0.3}]},
				{"label": "Encouraging words", "effects": [{"type": "morale_change", "amount": 0.1}]},
			]
		},
		{
			"id": "raise_demand",
			"title": "{name} Wants a Raise",
			"description": "{name} thinks they deserve a raise after landing a big contract. Responding positively could boost morale.",
			"choices": [
				{"label": "Grant raise (-$300)", "effects": [{"type": "spend_money", "amount": 300.0}, {"type": "morale_change", "amount": 0.25}]},
				{"label": "Promise future review", "effects": [{"type": "morale_change", "amount": 0.1}]},
			]
		},
		{
			"id": "conflict_colleagues",
			"title": "Team Conflict",
			"description": "{name} is having conflicts with another team member. Stepping in could help.",
			"choices": [
				{"label": "Mediate (-$100)", "effects": [{"type": "spend_money", "amount": 100.0}, {"type": "morale_change", "amount": 0.2}]},
				{"label": "Quick chat", "effects": [{"type": "morale_change", "amount": 0.1}]},
			]
		},
		{
			"id": "good_work",
			"title": "{name} Delivered Great Work",
			"description": "{name} went above and beyond on the last project. A reward could keep the momentum going.",
			"choices": [
				{"label": "Bonus (-$250)", "effects": [{"type": "spend_money", "amount": 250.0}, {"type": "morale_change", "amount": 0.3}]},
				{"label": "Public recognition", "effects": [{"type": "morale_change", "amount": 0.15}]},
			]
		},
	]
