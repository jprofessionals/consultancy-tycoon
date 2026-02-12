extends RefCounted
class_name BiddingSystem

const CLIENT_NAMES = [
	"FinApp", "HealthBase", "ShopStream", "DataPulse", "CloudNine",
	"LogiTrack", "PayRight", "SecureNet", "DevFlow", "MetricHub",
	"TaskForge", "CodeBridge", "SyncWave", "BuildStack", "ApiNest",
]

const PROJECT_TYPES = [
	"REST API refactor", "payment integration", "auth system overhaul",
	"dashboard rebuild", "database migration", "CI/CD pipeline setup",
	"search feature", "notification service", "analytics module",
	"performance optimization", "security audit fixes", "mobile API",
]

const SKILL_POOL = ["javascript", "python", "rust", "go", "devops", "frameworks"]

func calculate_bid_chance(contract: ClientContract, player_skills: Dictionary) -> float:
	if contract.required_skills.is_empty():
		return 0.9

	var total_gap: float = 0.0
	var skill_count: int = 0
	for skill_id in contract.required_skills:
		var required = contract.required_skills[skill_id]
		var player_level = player_skills.get(skill_id, 0)
		total_gap += maxf(required - player_level, 0)
		skill_count += 1

	if skill_count == 0:
		return 0.9

	var avg_gap = total_gap / skill_count
	return clampf(0.9 - avg_gap * 0.25, 0.05, 0.95)

func get_difficulty_modifier(contract: ClientContract, player_skills: Dictionary) -> float:
	var total_gap: float = 0.0
	for skill_id in contract.required_skills:
		var required = contract.required_skills[skill_id]
		var player_level = player_skills.get(skill_id, 0)
		total_gap += maxf(required - player_level, 0)
	return 1.0 + total_gap * 0.3

func _generate_contract(tier: int, task_multiplier: float = 1.0) -> ClientContract:
	var contract = ClientContract.new()
	contract.client_name = CLIENT_NAMES[randi() % CLIENT_NAMES.size()]
	contract.project_description = PROJECT_TYPES[randi() % PROJECT_TYPES.size()]
	contract.tier = tier
	var base_tasks = contract.tier * 15 + randi_range(9, 36)
	if contract.tier <= 2:
		base_tasks = base_tasks / 2
	base_tasks = int(base_tasks * task_multiplier)
	contract.task_count = base_tasks
	contract.payout_per_task = contract.tier * 25.0 + randf_range(0, contract.tier * 15.0)
	var num_skills = randi_range(1, mini(2, SKILL_POOL.size()))
	var shuffled = SKILL_POOL.duplicate()
	shuffled.shuffle()
	for j in range(num_skills):
		contract.required_skills[shuffled[j]] = randi_range(1, contract.tier * 2)
	contract.duration = 120.0 - contract.tier * 15.0
	return contract

func generate_contracts(count: int, reputation: float) -> Array[ClientContract]:
	var contracts: Array[ClientContract] = []
	var max_tier = clampi(int(reputation / 20.0) + 1, 1, 4)
	for i in range(count):
		var tier = clampi(randi_range(1, max_tier), 1, 4)
		contracts.append(_generate_contract(tier))
	return contracts

func generate_personal_contracts(count: int, reputation: float) -> Array[ClientContract]:
	var contracts: Array[ClientContract] = []
	var max_tier = clampi(int(reputation / 20.0) + 1, 1, 2)
	for i in range(count):
		var tier = clampi(randi_range(1, max_tier), 1, 2)
		contracts.append(_generate_contract(tier))
	return contracts

func generate_management_contracts(count: int, reputation: float) -> Array[ClientContract]:
	var contracts: Array[ClientContract] = []
	var max_tier = clampi(int(reputation / 20.0) + 1, 2, 4)
	for i in range(count):
		var tier = clampi(randi_range(2, max_tier), 2, 4)
		contracts.append(_generate_contract(tier, 1.5))
	return contracts

func attempt_bid(contract: ClientContract, player_skills: Dictionary) -> bool:
	var chance = calculate_bid_chance(contract, player_skills)
	return randf() < chance
