extends RefCounted
class_name MergeConflictFactory

# Algorithmic conflict variations: [base_line, local_variant, remote_variant]
const EASY_VARIANTS = [
	["    var timeout = 30", "    var timeout = 60", "    var timeout = 45"],
	["    var retries = 3", "    var retries = 5", "    var retries = 10"],
	["    var name = \"service\"", "    var name = \"api_service\"", "    var name = \"main_service\""],
	["    var port = 8080", "    var port = 3000", "    var port = 9090"],
	["    var max_size = 100", "    var max_size = 200", "    var max_size = 500"],
	["    var debug = false", "    var debug = true", "    var debug = false"],
	["    var level = \"info\"", "    var level = \"debug\"", "    var level = \"warn\""],
	["    var cache_ttl = 3600", "    var cache_ttl = 7200", "    var cache_ttl = 1800"],
	["    var batch_size = 50", "    var batch_size = 100", "    var batch_size = 25"],
	["    var pool_size = 5", "    var pool_size = 10", "    var pool_size = 8"],
	["    return process(data)", "    return validate(data)", "    return transform(data)"],
	["    emit_signal(\"updated\")", "    emit_signal(\"changed\")", "    emit_signal(\"refreshed\")"],
	["    var delay = 1.0", "    var delay = 0.5", "    var delay = 2.0"],
	["    print(\"Starting...\")", "    Logger.info(\"Starting...\")", "    push_warning(\"Starting...\")"],
	["    var mode = \"standard\"", "    var mode = \"fast\"", "    var mode = \"safe\""],
]

# Curated tricky conflicts: {local: [...], remote: [...], correct: "local"/"remote"/"both"}
const TRICKY_CONFLICTS = [
	{
		"local": ["    if token == null:", "        return false", "    return validate(token)"],
		"remote": ["    return validate(token)"],
		"correct": "local",
	},
	{
		"local": ["    file.close()", "    return data"],
		"remote": ["    return data"],
		"correct": "local",
	},
	{
		"local": ["    process(item)"],
		"remote": ["    if item != null:", "        process(item)"],
		"correct": "remote",
	},
	{
		"local": ["    db.execute(query)"],
		"remote": ["    db.begin_transaction()", "    db.execute(query)", "    db.commit()"],
		"correct": "remote",
	},
	{
		"local": ["    var hash = password.md5_text()"],
		"remote": ["    var hash = password.sha256_text()"],
		"correct": "remote",
	},
	{
		"local": ["    mutex.lock()", "    var val = shared_data[key]", "    mutex.unlock()"],
		"remote": ["    var val = shared_data[key]"],
		"correct": "local",
	},
	{
		"local": ["    velocity += gravity * delta"],
		"remote": ["    velocity += gravity"],
		"correct": "local",
	},
	{
		"local": ["    for item in items:", "        results.append(process(item))"],
		"remote": ["    results = items.map(func(i): return process(i))"],
		"correct": "remote",
	},
	{
		"local": ["    Logger.info(\"User %s logged in\" % user.name)"],
		"remote": ["    validate_session(user)"],
		"correct": "both",
	},
	{
		"local": ["    cache.invalidate(key)"],
		"remote": ["    db.update(key, value)"],
		"correct": "both",
	},
	{
		"local": ["    assert(index >= 0)", "    return items[index]"],
		"remote": ["    if index < 0:", "        return null", "    return items[index]"],
		"correct": "remote",
	},
	{
		"local": ["    timer.stop()"],
		"remote": ["    timer.stop()", "    timer.queue_free()"],
		"correct": "remote",
	},
	{
		"local": ["    emit_signal(\"health_changed\", new_health)"],
		"remote": ["    update_health_bar(new_health)"],
		"correct": "both",
	},
	{
		"local": ["    if not input.is_empty():", "        return parse(input)"],
		"remote": ["    return parse(input)"],
		"correct": "local",
	},
	{
		"local": ["    result = snapped(result, 0.01)"],
		"remote": ["    result = round(result * 100) / 100"],
		"correct": "local",
	},
]

# Base context lines to build conflict files around
const BASE_CONTEXTS = [
	["func process_request(request: Dictionary) -> Dictionary:", "    var response = {}", "    # --- chunk ---", "    return response"],
	["class DataProcessor:", "    var _data: Array = []", "", "    func run() -> void:", "        # --- chunk ---", "        _save_results()"],
	["func update(delta: float) -> void:", "    # --- chunk ---", "    _apply_state()"],
	["func handle_input(event: InputEvent) -> void:", "    if not event.is_pressed():", "        return", "    # --- chunk ---"],
	["func connect_to_server(url: String) -> Error:", "    var http = HTTPClient.new()", "    # --- chunk ---", "    return OK"],
	["func save_data(path: String) -> void:", "    var file = FileAccess.open(path, FileAccess.WRITE)", "    # --- chunk ---", "    file.close()"],
	["func calculate_score(player: Dictionary) -> float:", "    var base = player.get(\"level\", 1) * 10.0", "    # --- chunk ---", "    return base"],
	["func validate_form(fields: Dictionary) -> Array:", "    var errors = []", "    # --- chunk ---", "    return errors"],
]

func generate(tier: int) -> MergeConflict:
	var conflict = MergeConflict.new()

	# Pick a base context
	var ctx = BASE_CONTEXTS[randi() % BASE_CONTEXTS.size()].duplicate()

	# Determine number of chunks based on tier
	var num_chunks = _get_chunk_count(tier)

	# Find chunk insertion points (where "# --- chunk ---" markers are, or random positions)
	var chunk_insert_lines: Array = []
	var clean_base: Array = []
	for i in range(ctx.size()):
		if ctx[i].strip_edges() == "# --- chunk ---":
			chunk_insert_lines.append(clean_base.size())
		else:
			clean_base.append(ctx[i])

	# Cap num_chunks to available insertion positions (0..clean_base.size())
	var max_positions = clean_base.size() + 1  # can insert before any line or at end
	num_chunks = min(num_chunks, max_positions)

	# If we need more chunks than markers, add at random positions
	while chunk_insert_lines.size() < num_chunks:
		var pos = randi_range(0, clean_base.size())
		if pos not in chunk_insert_lines:
			chunk_insert_lines.append(pos)
	chunk_insert_lines.sort()

	# Only use as many as needed
	chunk_insert_lines = chunk_insert_lines.slice(0, num_chunks)

	conflict.base_lines = clean_base
	conflict.chunk_positions = chunk_insert_lines

	# Generate chunks
	var tricky_budget = _get_tricky_count(tier)
	for i in range(num_chunks):
		var chunk: ConflictChunk
		if tricky_budget > 0 and i >= num_chunks - tricky_budget:
			chunk = _make_tricky_chunk()
			tricky_budget -= 1
		else:
			chunk = _make_easy_chunk()
		conflict.chunks.append(chunk)

	return conflict

func _get_chunk_count(tier: int) -> int:
	match tier:
		1: return 1
		2: return randi_range(1, 2)
		3: return randi_range(2, 3)
		_: return randi_range(2, 4)

func _get_tricky_count(tier: int) -> int:
	match tier:
		1: return 0
		2: return randi_range(0, 1)
		3: return randi_range(1, 2)
		_: return randi_range(1, 3)

func _make_easy_chunk() -> ConflictChunk:
	var chunk = ConflictChunk.new()
	var variant = EASY_VARIANTS[randi() % EASY_VARIANTS.size()]
	chunk.local_lines = [variant[1]]
	chunk.remote_lines = [variant[2]]
	chunk.correct_resolution = ""  # any choice is fine
	return chunk

func _make_tricky_chunk() -> ConflictChunk:
	var chunk = ConflictChunk.new()
	var data = TRICKY_CONFLICTS[randi() % TRICKY_CONFLICTS.size()]
	chunk.local_lines = data["local"].duplicate()
	chunk.remote_lines = data["remote"].duplicate()
	chunk.correct_resolution = data["correct"]
	return chunk
