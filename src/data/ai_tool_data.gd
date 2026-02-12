extends Resource
class_name AiToolData

var id: String = ""
var name: String = ""
var description: String = ""
var target_state: String = ""  # "writing", "reviewing", "conflict", "ci"
var base_cost: float = 1000.0
var cost_multiplier: float = 2.2
var max_tier: int = 5
var base_cooldown: float = 5.0  # seconds between actions
var base_reliability: float = 0.4  # chance of success at tier 1

func get_cost_for_tier(current_tier: int) -> float:
	return base_cost * pow(cost_multiplier, current_tier)

func get_reliability_at_tier(tier: int) -> float:
	# Tier 1 = base, each tier adds ~12% up to ~95%
	return clampf(base_reliability + (tier - 1) * 0.12, 0.0, 0.95)

func get_cooldown_at_tier(tier: int) -> float:
	# Gets faster with tiers: 5s -> 4s -> 3.2s -> 2.6s -> 2.1s
	return base_cooldown * pow(0.8, tier - 1)
