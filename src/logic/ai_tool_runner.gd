extends RefCounted
class_name AiToolRunner

var _cooldowns: Dictionary = {}  # tool_id -> remaining seconds
var _tool_manager: AiToolManager

func _init(tool_manager: AiToolManager = null):
	_tool_manager = tool_manager if tool_manager else AiToolManager.new()

func tick(delta: float, coding_loop: CodingLoop, state: Node) -> void:
	if coding_loop.state == CodingLoop.State.IDLE or coding_loop.state == CodingLoop.State.COMPLETE:
		return

	for tool in _tool_manager.get_all_tools():
		var tier = state.get_ai_tool_tier(tool.id)
		if tier <= 0:
			continue

		# Update cooldown
		var remaining = _cooldowns.get(tool.id, 0.0) - delta
		if remaining > 0:
			_cooldowns[tool.id] = remaining
			continue

		# Reset cooldown
		_cooldowns[tool.id] = tool.get_cooldown_at_tier(tier)

		# Try to act based on current coding_loop state
		_try_act(tool, tier, coding_loop, state)

func _try_act(tool: AiToolData, tier: int, coding_loop: CodingLoop, state: Node) -> void:
	var success = randf() < tool.get_reliability_at_tier(tier)
	var bus = _get_event_bus(state)

	match tool.target_state:
		"writing":
			var clicks = 1 + tier  # Tier 1 = 2 clicks, tier 5 = 6 clicks per action
			if coding_loop.state == CodingLoop.State.WRITING:
				if success:
					for i in range(clicks):
						if coding_loop.state == CodingLoop.State.WRITING:
							coding_loop.perform_click(1.0)
				if bus:
					bus.ai_tool_acted.emit(tool.id, "write", success)
			elif coding_loop.state == CodingLoop.State.FIXING:
				if success:
					coding_loop.perform_click(1.0)
				if bus:
					bus.ai_tool_acted.emit(tool.id, "fix", success)
		"reviewing":
			if coding_loop.state == CodingLoop.State.REVIEWING:
				if success:
					coding_loop.resolve_review(true)
				else:
					coding_loop.resolve_review(false)
				if bus:
					bus.ai_tool_acted.emit(tool.id, "review", success)
		"conflict":
			if coding_loop.state == CodingLoop.State.CONFLICT:
				if success:
					coding_loop.resolve_conflict(coding_loop.conflict_correct_side)
				else:
					# Pick wrong side
					var wrong_side = "right" if coding_loop.conflict_correct_side == "left" else "left"
					coding_loop.resolve_conflict(wrong_side)
				if bus:
					bus.ai_tool_acted.emit(tool.id, "conflict", success)
		"ci":
			# CI fixer passively boosts — handled elsewhere via tier check
			pass

func get_ci_fixer_bonus(state: Node) -> float:
	var tier = state.get_ai_tool_tier("ci_fixer")
	if tier <= 0:
		return 0.0
	var tool = _tool_manager.get_tool("ci_fixer")
	if not tool:
		return 0.0
	return tool.get_reliability_at_tier(tier) * 0.3

func _get_event_bus(state: Node) -> Node:
	if state.has_method("_get_event_bus"):
		return state._get_event_bus()
	return null
