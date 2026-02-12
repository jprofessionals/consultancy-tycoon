extends RefCounted
class_name AiToolRunner

var _cooldowns: Dictionary = {}  # tool_id -> remaining seconds
var _tool_manager: AiToolManager

func _init(tool_manager: AiToolManager = null):
	_tool_manager = tool_manager if tool_manager else AiToolManager.new()

func tick(delta: float, tabs: Array, focused_index: int, state: Node) -> void:
	if tabs.is_empty():
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

		# Try to act on the first eligible tab
		for i in range(tabs.size()):
			var tab: CodingTab = tabs[i]
			if tab.stuck:
				continue
			var loop = tab.coding_loop
			if loop.state == CodingLoop.State.IDLE or loop.state == CodingLoop.State.COMPLETE:
				continue
			if _try_act(tool, tier, loop, i == focused_index, tab, i, state):
				break  # One action per tool per cooldown cycle

func _try_act(tool: AiToolData, tier: int, coding_loop: CodingLoop, is_focused: bool, tab: CodingTab, tab_index: int, state: Node) -> bool:
	var success = randf() < tool.get_reliability_at_tier(tier)
	var bus = _get_event_bus(state)
	var acted = false

	match tool.target_state:
		"writing":
			var clicks = 1 + tier
			if coding_loop.state == CodingLoop.State.WRITING:
				if success:
					for i in range(clicks):
						if coding_loop.state == CodingLoop.State.WRITING:
							coding_loop.perform_click(1.0)
				acted = true
				if bus:
					bus.ai_tool_acted.emit(tool.id, "write", success)
			elif coding_loop.state == CodingLoop.State.FIXING:
				if success:
					coding_loop.perform_click(1.0)
				acted = true
				if bus:
					bus.ai_tool_acted.emit(tool.id, "fix", success)
		"reviewing":
			if coding_loop.state == CodingLoop.State.REVIEWING:
				if success:
					coding_loop.resolve_review(true)
				else:
					coding_loop.resolve_review(false)
					if not is_focused:
						tab.stuck = true
						if bus:
							bus.tab_stuck.emit(tab_index)
				acted = true
				if bus:
					bus.ai_tool_acted.emit(tool.id, "review", success)
		"conflict":
			if coding_loop.state == CodingLoop.State.CONFLICT and coding_loop.merge_conflict != null:
				# Auto-merge if not yet done
				if not coding_loop.merge_conflict.auto_merged:
					coding_loop.auto_merge()
				# Resolve next unresolved chunk
				var idx = coding_loop.merge_conflict.get_next_unresolved_index()
				if idx >= 0:
					var chunk: ConflictChunk = coding_loop.merge_conflict.chunks[idx]
					if success:
						if chunk.correct_resolution != "":
							coding_loop.resolve_merge_chunk(chunk.correct_resolution)
						else:
							var options = ["local", "remote", "both"]
							coding_loop.resolve_merge_chunk(options[randi() % 3])
					else:
						if chunk.correct_resolution != "":
							var wrong_options = ["local", "remote", "both"]
							wrong_options.erase(chunk.correct_resolution)
							coding_loop.resolve_merge_chunk(wrong_options[randi() % wrong_options.size()])
						else:
							var options = ["local", "remote", "both"]
							coding_loop.resolve_merge_chunk(options[randi() % 3])
						if not is_focused:
							tab.stuck = true
							if bus:
								bus.tab_stuck.emit(tab_index)
				acted = true
				if bus:
					bus.ai_tool_acted.emit(tool.id, "conflict", success)
		"ci":
			pass

	return acted

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
