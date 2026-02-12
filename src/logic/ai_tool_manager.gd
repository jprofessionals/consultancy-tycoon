extends RefCounted
class_name AiToolManager

var _tools: Array[AiToolData] = []

func _init():
	_define_tools()

func _define_tools():
	_tools.append(_make_tool("auto_writer", "Auto-Writer", "Auto-types code for you", "writing", 2000.0, 5, 5.0, 0.4))
	_tools.append(_make_tool("auto_reviewer", "Auto-reviewer", "Automatically submits code reviews", "reviewing", 1500.0, 5, 6.0, 0.45))
	_tools.append(_make_tool("merge_resolver", "Merge Resolver", "Picks the correct side in merge conflicts", "conflict", 1200.0, 4, 4.0, 0.35))
	_tools.append(_make_tool("ci_fixer", "CI Fixer", "Reduces CI failure chance", "ci", 1000.0, 4, 8.0, 0.5))

func _make_tool(id: String, tool_name: String, desc: String, target: String, base_cost: float, max_tier: int, cooldown: float, reliability: float) -> AiToolData:
	var t = AiToolData.new()
	t.id = id
	t.name = tool_name
	t.description = desc
	t.target_state = target
	t.base_cost = base_cost
	t.cost_multiplier = 2.2
	t.max_tier = max_tier
	t.base_cooldown = cooldown
	t.base_reliability = reliability
	return t

func get_all_tools() -> Array[AiToolData]:
	return _tools

func get_tool(tool_id: String) -> AiToolData:
	for t in _tools:
		if t.id == tool_id:
			return t
	return null

func try_upgrade(tool: AiToolData, state: Node) -> bool:
	var current_tier = state.get_ai_tool_tier(tool.id)
	if current_tier >= tool.max_tier:
		return false
	var price = tool.get_cost_for_tier(current_tier)
	if not state.spend_money(price):
		return false
	state.set_ai_tool_tier(tool.id, current_tier + 1)
	return true
