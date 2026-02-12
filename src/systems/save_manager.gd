extends Node

var save_path: String = "user://savegame.json"
const SAVE_VERSION = 1

# ── Public API ──

func save_game(runtime_state: Dictionary, game_state: Node = null) -> bool:
	var data = _build_save_dict(runtime_state, game_state if game_state else GameState)
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Could not open save file for writing")
		return false
	file.store_string(json_string)
	file.close()
	return true

func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("SaveManager: Could not open save file for reading")
		return {}
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(json_string)
	if err != OK:
		push_error("SaveManager: JSON parse error: %s" % json.get_error_message())
		return {}
	var data = json.data
	if not data is Dictionary:
		push_error("SaveManager: Save data is not a Dictionary")
		return {}
	return data

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

# ── Build Save Dictionary ──

func _build_save_dict(runtime_state: Dictionary, gs_node: Node) -> Dictionary:
	var data: Dictionary = {}
	data["version"] = SAVE_VERSION
	data["timestamp"] = int(Time.get_unix_time_from_system())

	# GameState fields
	data["game_state"] = {
		"money": gs_node.money,
		"reputation": gs_node.reputation,
		"skills": gs_node.skills.duplicate(),
		"ai_tools": gs_node.ai_tools.duplicate(),
		"office_unlocked": gs_node.office_unlocked,
		"claimed_easter_eggs": gs_node.claimed_easter_eggs.duplicate(),
		"desk_capacity": gs_node.desk_capacity,
	}

	# Consultants
	data["consultants"] = []
	for c in gs_node.consultants:
		data["consultants"].append(_serialize_consultant(c))

	# Active assignments
	data["active_assignments"] = []
	for a in gs_node.active_assignments:
		data["active_assignments"].append(_serialize_assignment(a))

	# Active rentals
	data["active_rentals"] = []
	for r in gs_node.active_rentals:
		data["active_rentals"].append(_serialize_rental(r))

	# Runtime state from main.gd
	data["game_started"] = runtime_state.get("game_started", true)

	# Multi-tab state
	var tabs_data = runtime_state.get("tabs")
	if tabs_data is Array:
		data["tabs"] = tabs_data
	data["focused_index"] = runtime_state.get("focused_index", 0)

	return data

# ── Restore from Save Dictionary ──

func apply_save(data: Dictionary, game_state: Node = null) -> Dictionary:
	if data.is_empty():
		return {}

	var gs_node = game_state if game_state else GameState

	# Restore GameState fields
	var gs = data.get("game_state", {})
	gs_node.money = gs.get("money", 0.0)
	gs_node.reputation = gs.get("reputation", 0.0)
	gs_node.skills = gs.get("skills", {}).duplicate()
	gs_node.ai_tools = gs.get("ai_tools", {}).duplicate()
	gs_node.office_unlocked = gs.get("office_unlocked", false)
	gs_node.claimed_easter_eggs = gs.get("claimed_easter_eggs", {}).duplicate()
	gs_node.desk_capacity = int(gs.get("desk_capacity", 4))

	# Restore consultants
	gs_node.consultants.clear()
	for cd in data.get("consultants", []):
		gs_node.consultants.append(_deserialize_consultant(cd))

	# Restore active assignments (reconstruct consultant references)
	gs_node.active_assignments.clear()
	for ad in data.get("active_assignments", []):
		var assignment = _deserialize_assignment(ad, gs_node.consultants)
		if assignment:
			gs_node.active_assignments.append(assignment)

	# Restore active rentals
	gs_node.active_rentals.clear()
	for rd in data.get("active_rentals", []):
		var rental = _deserialize_rental(rd, gs_node.consultants)
		if rental:
			gs_node.active_rentals.append(rental)

	# Build runtime state dict for main.gd to consume
	var runtime: Dictionary = {}
	runtime["game_started"] = data.get("game_started", true)

	# Multi-tab state
	if data.has("tabs"):
		runtime["tabs"] = data.get("tabs", [])
		runtime["focused_index"] = int(data.get("focused_index", 0))
	else:
		# Backward compat: old single-contract saves
		var contract_data = data.get("active_contract")
		runtime["active_contract"] = _deserialize_contract(contract_data) if contract_data else null
		runtime["tasks_remaining"] = int(data.get("tasks_remaining", 0))
		runtime["difficulty_modifier"] = float(data.get("difficulty_modifier", 1.0))
		runtime["coding_loop"] = data.get("coding_loop")

	return runtime

# ── Serialization Helpers ──

func _serialize_consultant(c: ConsultantData) -> Dictionary:
	return {
		"id": c.id,
		"name": c.name,
		"skills": c.skills.duplicate(),
		"salary": c.salary,
		"trait_id": c.trait_id,
		"morale": c.morale,
		"location": c.location,
		"training_skill": c.training_skill,
	}

func _deserialize_consultant(d: Dictionary) -> ConsultantData:
	var c = ConsultantData.new()
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", ""))
	c.skills = d.get("skills", {}).duplicate()
	c.salary = float(d.get("salary", 500.0))
	c.trait_id = str(d.get("trait_id", ""))
	c.morale = float(d.get("morale", 1.0))
	c.location = int(d.get("location", 0))
	c.training_skill = str(d.get("training_skill", ""))
	return c

func _serialize_contract(c: ClientContract) -> Dictionary:
	return {
		"client_name": c.client_name,
		"project_description": c.project_description,
		"tier": c.tier,
		"task_count": c.task_count,
		"payout_per_task": c.payout_per_task,
		"required_skills": c.required_skills.duplicate(),
		"duration": c.duration,
	}

func _deserialize_contract(d: Dictionary) -> ClientContract:
	var c = ClientContract.new()
	c.client_name = str(d.get("client_name", ""))
	c.project_description = str(d.get("project_description", ""))
	c.tier = int(d.get("tier", 1))
	c.task_count = int(d.get("task_count", 1))
	c.payout_per_task = float(d.get("payout_per_task", 25.0))
	c.required_skills = d.get("required_skills", {}).duplicate()
	c.duration = float(d.get("duration", 60.0))
	return c

func _serialize_task(t: CodingTask) -> Dictionary:
	return {
		"title": t.title,
		"description": t.description,
		"difficulty": t.difficulty,
		"payout": t.payout,
		"total_clicks": t.total_clicks,
		"required_skills": t.required_skills.duplicate(),
	}

func _deserialize_task(d: Dictionary) -> CodingTask:
	var t = CodingTask.new()
	t.title = str(d.get("title", ""))
	t.description = str(d.get("description", ""))
	t.difficulty = int(d.get("difficulty", 1))
	t.payout = float(d.get("payout", 0.0))
	t.total_clicks = int(d.get("total_clicks", 10))
	t.required_skills = d.get("required_skills", {}).duplicate()
	return t

func _serialize_assignment(a: ConsultantAssignment) -> Dictionary:
	var consultant_ids: Array = []
	for c in a.consultants:
		consultant_ids.append(c.id)
	return {
		"contract": _serialize_contract(a.contract) if a.contract else null,
		"consultant_ids": consultant_ids,
		"current_task_index": a.current_task_index,
		"current_task_progress": a.current_task_progress,
	}

func _deserialize_assignment(d: Dictionary, all_consultants: Array) -> ConsultantAssignment:
	var a = ConsultantAssignment.new()
	var contract_data = d.get("contract")
	if contract_data:
		a.contract = _deserialize_contract(contract_data)
	else:
		return null
	# Reconstruct consultant references by ID
	var ids = d.get("consultant_ids", [])
	for id in ids:
		for c in all_consultants:
			if c.id == str(id):
				a.consultants.append(c)
				break
	a.current_task_index = int(d.get("current_task_index", 0))
	a.current_task_progress = float(d.get("current_task_progress", 0.0))
	return a

func _serialize_rental(r: ConsultantRental) -> Dictionary:
	return {
		"consultant_id": r.consultant.id if r.consultant else "",
		"client_name": r.client_name,
		"rate_per_tick": r.rate_per_tick,
		"total_duration": r.total_duration,
		"duration_remaining": r.duration_remaining,
		"extension_offered": r.extension_offered,
	}

func _deserialize_rental(d: Dictionary, all_consultants: Array) -> ConsultantRental:
	var r = ConsultantRental.new()
	r.client_name = str(d.get("client_name", ""))
	r.rate_per_tick = float(d.get("rate_per_tick", 1.0))
	r.total_duration = float(d.get("total_duration", 600.0))
	r.duration_remaining = float(d.get("duration_remaining", 600.0))
	r.extension_offered = bool(d.get("extension_offered", false))
	var cid = str(d.get("consultant_id", ""))
	for c in all_consultants:
		if c.id == cid:
			r.consultant = c
			break
	if not r.consultant:
		return null
	return r

# ── Coding Loop Serialization (used by main.gd) ──

func serialize_coding_loop(loop: CodingLoop) -> Dictionary:
	if loop.state == CodingLoop.State.IDLE or loop.current_task == null:
		return {}
	return {
		"state": loop.state,
		"progress": loop.progress,
		"review_changes_needed": loop.review_changes_needed,
		"conflict_correct_side": loop.conflict_correct_side,
		"current_task": _serialize_task(loop.current_task),
	}

func deserialize_coding_loop(loop: CodingLoop, d: Dictionary) -> void:
	if d.is_empty():
		loop.reset()
		return
	var task = _deserialize_task(d.get("current_task", {}))
	loop.current_task = task
	loop.progress = float(d.get("progress", 0.0))
	loop.review_changes_needed = int(d.get("review_changes_needed", 0))
	loop.conflict_correct_side = str(d.get("conflict_correct_side", ""))
	# Restore state directly (bypass _set_state to avoid emitting during load)
	loop.state = int(d.get("state", CodingLoop.State.IDLE))

# ── Multi-Tab Serialization ──

func serialize_tabs(tabs: Array) -> Array:
	var result: Array = []
	for tab in tabs:
		result.append(_serialize_tab(tab))
	return result

func deserialize_tabs(data: Array) -> Array:
	var result: Array = []
	for td in data:
		if td is Dictionary:
			result.append(_deserialize_tab(td))
	return result

func _serialize_tab(tab: CodingTab) -> Dictionary:
	return {
		"contract": _serialize_contract(tab.contract) if tab.contract else null,
		"task_index": tab.task_index,
		"total_tasks": tab.total_tasks,
		"difficulty_modifier": tab.difficulty_modifier,
		"stuck": tab.stuck,
		"coding_loop": serialize_coding_loop(tab.coding_loop),
	}

func _deserialize_tab(d: Dictionary) -> CodingTab:
	var tab = CodingTab.new()
	var contract_data = d.get("contract")
	if contract_data is Dictionary:
		tab.contract = _deserialize_contract(contract_data)
	tab.task_index = int(d.get("task_index", 0))
	tab.total_tasks = int(d.get("total_tasks", 0))
	tab.difficulty_modifier = float(d.get("difficulty_modifier", 1.0))
	tab.stuck = bool(d.get("stuck", false))
	var loop_data = d.get("coding_loop")
	if loop_data is Dictionary and not loop_data.is_empty():
		deserialize_coding_loop(tab.coding_loop, loop_data)
	return tab

# ── Testing Savegame Generator ──

func create_test_save() -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"game_state": {
			"money": 200000.0,
			"reputation": 50.0,
			"skills": {
				"javascript": 3,
				"python": 2,
				"devops": 1,
				"code_quality": 2,
			},
			"ai_tools": {
				"auto_writer": 2,
				"auto_reviewer": 1,
			},
			"office_unlocked": true,
			"claimed_easter_eggs": {},
		},
		"consultants": [
			{
				"id": "test_1",
				"name": "Alex Chen",
				"skills": {"javascript": 3, "python": 1},
				"salary": 500.0,
				"trait_id": "fast",
				"morale": 0.9,
			},
			{
				"id": "test_2",
				"name": "Sam Rivera",
				"skills": {"python": 2, "devops": 2},
				"salary": 600.0,
				"trait_id": "careful",
				"morale": 1.0,
			},
		],
		"active_assignments": [],
		"tabs": [],
		"focused_index": 0,
		"game_started": true,
	}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Could not create test save")
		return false
	file.store_string(json_string)
	file.close()
	return true
