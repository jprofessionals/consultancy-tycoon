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
const ISSUE_CHANCE_PER_TICK: float = 0.002  # ~every 8 min at 1 tick/sec

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

func _build_issue_templates():
	_issue_templates = [
		{
			"id": "burnout",
			"title": "{name} is Burning Out",
			"description": "{name} has been working long hours and morale is dropping. What do you do?",
			"choices": [
				{"label": "Give a bonus (-$200)", "effects": [{"type": "spend_money", "amount": 200.0}, {"type": "morale_change", "amount": 0.3}]},
				{"label": "Push through", "effects": [{"type": "morale_change", "amount": -0.2}]},
			]
		},
		{
			"id": "raise_demand",
			"title": "{name} Wants a Raise",
			"description": "{name} thinks they deserve a raise after landing a big contract. They might leave if you refuse.",
			"choices": [
				{"label": "Grant raise (-$300)", "effects": [{"type": "spend_money", "amount": 300.0}, {"type": "morale_change", "amount": 0.2}]},
				{"label": "Refuse", "effects": [{"type": "morale_change", "amount": -0.3}]},
			]
		},
		{
			"id": "conflict_colleagues",
			"title": "Team Conflict",
			"description": "{name} is having conflicts with another team member. Productivity is suffering.",
			"choices": [
				{"label": "Mediate (costs time)", "effects": [{"type": "morale_change", "amount": 0.15}]},
				{"label": "Ignore it", "effects": [{"type": "morale_change", "amount": -0.15}]},
			]
		},
		{
			"id": "poached",
			"title": "{name} Got Poached!",
			"description": "A competitor offered {name} a better deal. They're leaving unless you counter-offer.",
			"choices": [
				{"label": "Counter-offer (-$500)", "effects": [{"type": "spend_money", "amount": 500.0}, {"type": "morale_change", "amount": 0.25}]},
				{"label": "Let them go", "effects": [{"type": "fire", "amount": 0}]},
			]
		},
	]
