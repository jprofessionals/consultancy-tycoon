# Merge Conflict Rework Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the binary left/right merge conflict coin-flip with a realistic three-panel merge flow where players auto-merge non-conflicting lines, then resolve individual conflict chunks by choosing local, remote, or both.

**Architecture:** New `MergeConflict` data class holds base lines + conflict chunks. `MergeConflictFactory` generates conflicts (algorithmic for easy, curated for hard). CodingLoop gains chunk-by-chunk resolution. IDE shows LOCAL | RESULT | REMOTE panels with keyboard shortcuts (Ctrl+A/L/R/B).

**Tech Stack:** Godot 4.6, GDScript, GUT v9.5.0 for tests.

---

### Task 1: MergeConflict data class

**Files:**
- Create: `src/data/merge_conflict.gd`
- Test: `test/unit/test_merge_conflict.gd`

**Step 1: Write the failing test**

Create `test/unit/test_merge_conflict.gd`:

```gdscript
extends GutTest

func test_conflict_chunk_creation():
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["var x = 1"]
	chunk.remote_lines = ["var x = 2"]
	chunk.correct_resolution = "local"
	assert_eq(chunk.local_lines, ["var x = 1"])
	assert_eq(chunk.remote_lines, ["var x = 2"])
	assert_eq(chunk.correct_resolution, "local")

func test_merge_conflict_creation():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["func foo():", "    pass"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["    var x = 1"]
	chunk.remote_lines = ["    var x = 2"]
	chunk.correct_resolution = ""
	conflict.chunks = [chunk]
	conflict.chunk_positions = [1]
	assert_eq(conflict.base_lines.size(), 2)
	assert_eq(conflict.chunks.size(), 1)

func test_merge_conflict_all_resolved():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = ""
	conflict.chunks = [chunk]
	conflict.chunk_positions = [0]
	assert_false(conflict.all_resolved())
	conflict.resolve_chunk(0, "local")
	assert_true(conflict.all_resolved())

func test_resolve_chunk_tracks_choice():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = "remote"
	conflict.chunks = [chunk]
	conflict.chunk_positions = [0]
	conflict.resolve_chunk(0, "local")
	assert_eq(conflict.resolutions[0], "local")
	assert_true(conflict.has_wrong_resolution())

func test_correct_resolution_no_wrong():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = "remote"
	conflict.chunks = [chunk]
	conflict.chunk_positions = [0]
	conflict.resolve_chunk(0, "remote")
	assert_false(conflict.has_wrong_resolution())

func test_any_resolution_valid_when_empty_correct():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = ""
	conflict.chunks = [chunk]
	conflict.chunk_positions = [0]
	conflict.resolve_chunk(0, "local")
	assert_false(conflict.has_wrong_resolution())
	conflict.resolve_chunk(0, "both")
	assert_false(conflict.has_wrong_resolution())

func test_get_merged_lines():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1", "line2", "line3"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local_a"]
	chunk.remote_lines = ["remote_a"]
	chunk.correct_resolution = ""
	conflict.chunks = [chunk]
	conflict.chunk_positions = [1]
	conflict.resolve_chunk(0, "both")
	var merged = conflict.get_merged_lines()
	assert_eq(merged, ["line1", "local_a", "remote_a", "line2", "line3"])

func test_get_merged_lines_local_only():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1", "line2"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local_a"]
	chunk.remote_lines = ["remote_a"]
	chunk.correct_resolution = ""
	conflict.chunks = [chunk]
	conflict.chunk_positions = [1]
	conflict.resolve_chunk(0, "local")
	var merged = conflict.get_merged_lines()
	assert_eq(merged, ["line1", "local_a", "line2"])

func test_multiple_chunks():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1", "line2", "line3"]
	var chunk1 = ConflictChunk.new()
	chunk1.local_lines = ["local_1"]
	chunk1.remote_lines = ["remote_1"]
	chunk1.correct_resolution = ""
	var chunk2 = ConflictChunk.new()
	chunk2.local_lines = ["local_2"]
	chunk2.remote_lines = ["remote_2"]
	chunk2.correct_resolution = "both"
	conflict.chunks = [chunk1, chunk2]
	conflict.chunk_positions = [0, 2]
	conflict.resolve_chunk(0, "remote")
	conflict.resolve_chunk(1, "both")
	assert_true(conflict.all_resolved())
	var merged = conflict.get_merged_lines()
	assert_eq(merged, ["remote_1", "line1", "line2", "local_2", "remote_2", "line3"])

func test_auto_merged_flag():
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	conflict.chunks = []
	conflict.chunk_positions = []
	assert_false(conflict.auto_merged)
	conflict.auto_merged = true
	assert_true(conflict.auto_merged)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_merge_conflict.gd`
Expected: FAIL (classes don't exist)

**Step 3: Write MergeConflict and ConflictChunk**

Create `src/data/merge_conflict.gd`:

```gdscript
extends RefCounted
class_name MergeConflict

var base_lines: Array = []          # shared/non-conflicting context lines
var chunks: Array = []              # Array of ConflictChunk
var chunk_positions: Array = []     # line index in base where each chunk is inserted BEFORE
var resolutions: Array = []         # player's choice per chunk: "local", "remote", "both", or ""
var auto_merged: bool = false       # whether auto-merge has been performed

func resolve_chunk(chunk_index: int, resolution: String) -> void:
	while resolutions.size() <= chunk_index:
		resolutions.append("")
	resolutions[chunk_index] = resolution

func all_resolved() -> bool:
	if chunks.size() == 0:
		return true
	if resolutions.size() < chunks.size():
		return false
	for r in resolutions:
		if r == "":
			return false
	return true

func get_next_unresolved_index() -> int:
	for i in range(chunks.size()):
		if i >= resolutions.size() or resolutions[i] == "":
			return i
	return -1

func has_wrong_resolution() -> bool:
	for i in range(chunks.size()):
		var chunk: ConflictChunk = chunks[i]
		if chunk.correct_resolution == "":
			continue  # any choice is valid
		if i < resolutions.size() and resolutions[i] != "" and resolutions[i] != chunk.correct_resolution:
			return true
	return false

func get_wrong_count() -> int:
	var count = 0
	for i in range(chunks.size()):
		var chunk: ConflictChunk = chunks[i]
		if chunk.correct_resolution == "":
			continue
		if i < resolutions.size() and resolutions[i] != "" and resolutions[i] != chunk.correct_resolution:
			count += 1
	return count

func get_merged_lines() -> Array:
	var result: Array = []
	var base_idx = 0
	for ci in range(chunks.size()):
		var pos = chunk_positions[ci]
		# Add base lines up to this chunk's insertion point
		while base_idx < pos and base_idx < base_lines.size():
			result.append(base_lines[base_idx])
			base_idx += 1
		# Add resolved chunk lines
		if ci < resolutions.size() and resolutions[ci] != "":
			var chunk: ConflictChunk = chunks[ci]
			match resolutions[ci]:
				"local":
					result.append_array(chunk.local_lines)
				"remote":
					result.append_array(chunk.remote_lines)
				"both":
					result.append_array(chunk.local_lines)
					result.append_array(chunk.remote_lines)
	# Add remaining base lines
	while base_idx < base_lines.size():
		result.append(base_lines[base_idx])
		base_idx += 1
	return result

func get_local_display_lines() -> Array:
	var result: Array = []
	var base_idx = 0
	for ci in range(chunks.size()):
		var pos = chunk_positions[ci]
		while base_idx < pos and base_idx < base_lines.size():
			result.append({"text": base_lines[base_idx], "type": "base"})
			base_idx += 1
		for line in chunks[ci].local_lines:
			result.append({"text": line, "type": "conflict", "chunk_index": ci})
	while base_idx < base_lines.size():
		result.append({"text": base_lines[base_idx], "type": "base"})
		base_idx += 1
	return result

func get_remote_display_lines() -> Array:
	var result: Array = []
	var base_idx = 0
	for ci in range(chunks.size()):
		var pos = chunk_positions[ci]
		while base_idx < pos and base_idx < base_lines.size():
			result.append({"text": base_lines[base_idx], "type": "base"})
			base_idx += 1
		for line in chunks[ci].remote_lines:
			result.append({"text": line, "type": "conflict", "chunk_index": ci})
	while base_idx < base_lines.size():
		result.append({"text": base_lines[base_idx], "type": "base"})
		base_idx += 1
	return result
```

Create `src/data/conflict_chunk.gd`:

```gdscript
extends RefCounted
class_name ConflictChunk

var local_lines: Array = []
var remote_lines: Array = []
var correct_resolution: String = ""   # "local", "remote", "both", or "" (any valid)
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_merge_conflict.gd`
Expected: all PASS

**Step 5: Commit**

```bash
git add src/data/merge_conflict.gd src/data/conflict_chunk.gd test/unit/test_merge_conflict.gd
git commit -m "feat: add MergeConflict and ConflictChunk data classes with tests"
```

---

### Task 2: MergeConflictFactory — algorithmic generation

**Files:**
- Create: `src/data/merge_conflict_factory.gd`
- Test: `test/unit/test_merge_conflict.gd` (append tests)

**Step 1: Write the failing tests**

Append to `test/unit/test_merge_conflict.gd`:

```gdscript
# ── Factory Tests ──

func test_factory_generates_conflict_for_tier_1():
	var factory = MergeConflictFactory.new()
	var conflict = factory.generate(1)
	assert_gt(conflict.base_lines.size(), 0, "Should have base lines")
	assert_eq(conflict.chunks.size(), 1, "Tier 1 should have 1 chunk")
	assert_eq(conflict.chunks[0].correct_resolution, "", "Tier 1 chunk should accept any resolution")

func test_factory_generates_more_chunks_for_higher_tier():
	var factory = MergeConflictFactory.new()
	# Run multiple times to test range (1-2 chunks for tier 2)
	var found_multi = false
	for i in range(20):
		var conflict = factory.generate(3)
		if conflict.chunks.size() > 1:
			found_multi = true
			break
	assert_true(found_multi, "Higher tiers should sometimes have multiple chunks")

func test_factory_tier3_has_tricky_chunks():
	var factory = MergeConflictFactory.new()
	var found_tricky = false
	for i in range(20):
		var conflict = factory.generate(4)
		for chunk in conflict.chunks:
			if chunk.correct_resolution != "":
				found_tricky = true
				break
		if found_tricky:
			break
	assert_true(found_tricky, "High tier should have tricky chunks with correct answers")

func test_factory_chunk_positions_are_valid():
	var factory = MergeConflictFactory.new()
	var conflict = factory.generate(3)
	for pos in conflict.chunk_positions:
		assert_true(pos >= 0 and pos <= conflict.base_lines.size(),
			"Chunk position should be within base_lines range")

func test_factory_local_and_remote_differ():
	var factory = MergeConflictFactory.new()
	var conflict = factory.generate(2)
	for chunk in conflict.chunks:
		assert_ne(chunk.local_lines, chunk.remote_lines, "Local and remote should differ")
```

**Step 2: Run test to verify new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_merge_conflict.gd`
Expected: new factory tests FAIL

**Step 3: Implement MergeConflictFactory**

Create `src/data/merge_conflict_factory.gd`:

```gdscript
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

	# If we need more chunks than markers, add at random positions
	while chunk_insert_lines.size() < num_chunks:
		var pos = randi_range(1, max(clean_base.size() - 1, 1))
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
```

**Step 4: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_merge_conflict.gd`
Expected: all PASS

**Step 5: Commit**

```bash
git add src/data/merge_conflict_factory.gd test/unit/test_merge_conflict.gd
git commit -m "feat: add MergeConflictFactory with algorithmic and curated conflicts"
```

---

### Task 3: Refactor CodingLoop for chunk-based merge resolution

**Files:**
- Modify: `src/logic/coding_loop.gd`
- Modify: `test/unit/test_coding_loop.gd`

**Step 1: Write the failing tests**

Update the conflict tests in `test/unit/test_coding_loop.gd`. Replace `test_conflict_resolution` and `test_wrong_conflict_pick_adds_penalty`, and add new tests:

```gdscript
func test_conflict_has_merge_conflict_data():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	loop._setup_conflict()
	assert_not_null(loop.merge_conflict, "Should have merge_conflict set")
	assert_gt(loop.merge_conflict.chunks.size(), 0, "Should have at least one chunk")

func test_auto_merge_sets_flag():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	loop._setup_conflict()
	loop.auto_merge()
	assert_true(loop.merge_conflict.auto_merged)

func test_resolve_single_chunk_completes():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	loop._setup_conflict()
	loop.auto_merge()
	# Tier 1 = 1 chunk, any resolution valid
	loop.resolve_merge_chunk("local")
	assert_eq(loop.state, loop.State.COMPLETE)

func test_wrong_chunk_resolution_causes_fixing():
	var task = CodingTask.new()
	task.difficulty = 5
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	# Manually set up a conflict with a tricky chunk
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = "remote"
	conflict.chunks = [chunk]
	conflict.chunk_positions = [0]
	loop.merge_conflict = conflict
	loop.auto_merge()
	loop.resolve_merge_chunk("local")  # wrong choice
	assert_eq(loop.state, loop.State.FIXING)
	assert_gt(loop.review_changes_needed, 0)

func test_resolve_merge_chunk_advances_to_next():
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	loop.start_task(task)
	loop.state = loop.State.CONFLICT
	# Set up 2 easy chunks
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1", "line2"]
	var chunk1 = ConflictChunk.new()
	chunk1.local_lines = ["l1"]
	chunk1.remote_lines = ["r1"]
	chunk1.correct_resolution = ""
	var chunk2 = ConflictChunk.new()
	chunk2.local_lines = ["l2"]
	chunk2.remote_lines = ["r2"]
	chunk2.correct_resolution = ""
	conflict.chunks = [chunk1, chunk2]
	conflict.chunk_positions = [0, 1]
	loop.merge_conflict = conflict
	loop.auto_merge()
	loop.resolve_merge_chunk("local")
	# Still in CONFLICT because chunk2 unresolved
	assert_eq(loop.state, loop.State.CONFLICT)
	loop.resolve_merge_chunk("remote")
	assert_eq(loop.state, loop.State.COMPLETE)
```

**Step 2: Run test to verify new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_coding_loop.gd`
Expected: new tests FAIL (merge_conflict, auto_merge, resolve_merge_chunk don't exist)

**Step 3: Refactor CodingLoop**

Modify `src/logic/coding_loop.gd`:

- Replace `conflict_correct_side: String = ""` with `merge_conflict: MergeConflict = null`
- Replace `conflict_appeared` signal with `merge_conflict_started(conflict: MergeConflict)`
- Add signals: `merge_auto_merged()`, `merge_chunk_resolved(chunk_index: int, was_correct: bool)`
- Replace `_setup_conflict()` to use `MergeConflictFactory`
- Replace `resolve_conflict(chosen_side)` with `auto_merge()` and `resolve_merge_chunk(resolution: String)`
- `resolve_merge_chunk` resolves the next unresolved chunk. After all resolved: if `has_wrong_resolution()` → FIXING, else → COMPLETE

Full updated file:

```gdscript
extends RefCounted
class_name CodingLoop

enum State { IDLE, WRITING, REVIEWING, FIXING, CONFLICT, COMPLETE }

var state: State = State.IDLE
var progress: float = 0.0
var current_task: CodingTask = null
var review_changes_needed: int = 0
var merge_conflict: MergeConflict = null

signal state_changed(new_state: State)
signal progress_changed(new_progress: float)
signal review_result(approved: bool, comment: String)
signal merge_conflict_started(conflict: MergeConflict)
signal merge_auto_merged()
signal merge_chunk_resolved(chunk_index: int, was_correct: bool)
signal task_done(task: CodingTask)

var _conflict_factory: MergeConflictFactory = MergeConflictFactory.new()

func start_task(task: CodingTask) -> void:
	current_task = task
	progress = 0.0
	merge_conflict = null
	_set_state(State.WRITING)

func perform_click(click_power: float) -> void:
	if state == State.WRITING:
		progress += click_power / current_task.total_clicks
		progress_changed.emit(progress)
		if progress >= 1.0:
			progress = 1.0
			_advance_from_writing()
	elif state == State.FIXING:
		review_changes_needed -= 1
		if review_changes_needed <= 0:
			_advance_from_writing()

func _advance_from_writing() -> void:
	_set_state(State.REVIEWING)

func resolve_review(approved: bool) -> void:
	if state != State.REVIEWING:
		return
	if approved:
		_check_for_conflict()
	else:
		review_changes_needed = randi_range(1, 3)
		review_result.emit(false, "Changes requested (%d fixes needed)" % review_changes_needed)
		_set_state(State.FIXING)

func _check_for_conflict() -> void:
	var conflict_chance = current_task.get_conflict_chance()
	if randf() < conflict_chance:
		_set_state(State.CONFLICT)
		_setup_conflict()
	else:
		_complete_task()

func _setup_conflict() -> void:
	var tier = current_task.difficulty
	merge_conflict = _conflict_factory.generate(clampi(tier, 1, 5))
	merge_conflict_started.emit(merge_conflict)

func auto_merge() -> void:
	if state != State.CONFLICT or merge_conflict == null:
		return
	merge_conflict.auto_merged = true
	merge_auto_merged.emit()

func resolve_merge_chunk(resolution: String) -> void:
	if state != State.CONFLICT or merge_conflict == null:
		return
	if not merge_conflict.auto_merged:
		return
	var idx = merge_conflict.get_next_unresolved_index()
	if idx < 0:
		return
	merge_conflict.resolve_chunk(idx, resolution)
	var chunk: ConflictChunk = merge_conflict.chunks[idx]
	var was_correct = chunk.correct_resolution == "" or resolution == chunk.correct_resolution
	merge_chunk_resolved.emit(idx, was_correct)
	# Check if all done
	if merge_conflict.all_resolved():
		if merge_conflict.has_wrong_resolution():
			review_changes_needed = merge_conflict.get_wrong_count()
			_set_state(State.FIXING)
		else:
			_complete_task()

func _complete_task() -> void:
	_set_state(State.COMPLETE)
	task_done.emit(current_task)

func force_complete() -> void:
	_set_state(State.COMPLETE)
	task_done.emit(current_task)
	reset()

func reset() -> void:
	state = State.IDLE
	progress = 0.0
	current_task = null
	merge_conflict = null

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)
```

**Step 4: Update old conflict tests**

Remove the two old tests (`test_conflict_resolution`, `test_wrong_conflict_pick_adds_penalty`) from `test/unit/test_coding_loop.gd` and keep the new ones from Step 1.

**Step 5: Run tests to verify all pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_coding_loop.gd`
Expected: all PASS

**Step 6: Commit**

```bash
git add src/logic/coding_loop.gd test/unit/test_coding_loop.gd
git commit -m "refactor: replace binary merge conflict with chunk-based MergeConflict resolution"
```

---

### Task 4: Update AI tool runner for new merge system

**Files:**
- Modify: `src/logic/ai_tool_runner.gd`
- Modify: `test/unit/test_ai_tools.gd` (if conflict tests exist)

**Step 1: Write the failing test**

Add to `test/unit/test_ai_tools.gd`:

```gdscript
func test_ai_merger_auto_merges_and_resolves_chunks():
	# Setup: a tab in CONFLICT state with merge_conflict data
	var state = _create_test_state()
	state.ai_tools["merge_resolver"] = 1
	var tab = CodingTab.new()
	var task = CodingTask.new()
	task.difficulty = 1
	task.total_clicks = 1
	tab.coding_loop.start_task(task)
	tab.coding_loop.state = CodingLoop.State.CONFLICT
	# Give it a simple merge conflict
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1"]
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = "local"
	conflict.chunks = [chunk]
	conflict.chunk_positions = [0]
	tab.coding_loop.merge_conflict = conflict
	var runner = AiToolRunner.new()
	# Tick enough times for cooldown to expire and action to happen
	for i in range(10):
		runner.tick(1.0, [tab], 0, state)
	# AI should have auto-merged and resolved the chunk
	assert_ne(tab.coding_loop.state, CodingLoop.State.CONFLICT,
		"AI should have resolved the conflict")
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_ai_tools.gd`
Expected: FAIL

**Step 3: Update AI tool runner conflict handling**

In `src/logic/ai_tool_runner.gd`, replace the `"conflict"` match arm (lines 74-87):

```gdscript
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
						# Pick correct resolution (or random if no correct answer)
						if chunk.correct_resolution != "":
							coding_loop.resolve_merge_chunk(chunk.correct_resolution)
						else:
							var options = ["local", "remote", "both"]
							coding_loop.resolve_merge_chunk(options[randi() % 3])
					else:
						# Pick wrong resolution
						if chunk.correct_resolution != "":
							var wrong_options = ["local", "remote", "both"]
							wrong_options.erase(chunk.correct_resolution)
							coding_loop.resolve_merge_chunk(wrong_options[randi() % wrong_options.size()])
						else:
							# No correct answer, any choice is fine, just pick one
							var options = ["local", "remote", "both"]
							coding_loop.resolve_merge_chunk(options[randi() % 3])
						if not is_focused:
							tab.stuck = true
							if bus:
								bus.tab_stuck.emit(tab_index)
				acted = true
				if bus:
					bus.ai_tool_acted.emit(tool.id, "conflict", success)
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_ai_tools.gd`
Expected: all PASS

**Step 5: Commit**

```bash
git add src/logic/ai_tool_runner.gd test/unit/test_ai_tools.gd
git commit -m "feat: update AI merge resolver for chunk-based conflict resolution"
```

---

### Task 5: Update save/load for new merge state

**Files:**
- Modify: `src/systems/save_manager.gd`
- Modify: `test/unit/test_save_load.gd`

**Step 1: Write the failing test**

Add to `test/unit/test_save_load.gd`:

```gdscript
func test_serialize_coding_loop_with_merge_conflict():
	var save_mgr = SaveManager.new()
	var loop = CodingLoop.new()
	var task = CodingTask.new()
	task.title = "Test"
	task.difficulty = 2
	task.total_clicks = 5
	loop.start_task(task)
	loop.state = CodingLoop.State.CONFLICT
	var conflict = MergeConflict.new()
	conflict.base_lines = ["line1", "line2"]
	conflict.auto_merged = true
	var chunk = ConflictChunk.new()
	chunk.local_lines = ["local"]
	chunk.remote_lines = ["remote"]
	chunk.correct_resolution = "local"
	conflict.chunks = [chunk]
	conflict.chunk_positions = [1]
	conflict.resolutions = ["local"]
	loop.merge_conflict = conflict
	var data = save_mgr.serialize_coding_loop(loop)
	assert_true(data.has("merge_conflict"))
	# Deserialize
	var loop2 = CodingLoop.new()
	save_mgr.deserialize_coding_loop(loop2, data)
	assert_not_null(loop2.merge_conflict)
	assert_eq(loop2.merge_conflict.base_lines, ["line1", "line2"])
	assert_eq(loop2.merge_conflict.chunks.size(), 1)
	assert_eq(loop2.merge_conflict.resolutions, ["local"])
	assert_true(loop2.merge_conflict.auto_merged)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_save_load.gd`
Expected: FAIL

**Step 3: Update SaveManager**

In `src/systems/save_manager.gd`, modify `serialize_coding_loop` to replace `conflict_correct_side` with `merge_conflict`:

```gdscript
func serialize_coding_loop(loop: CodingLoop) -> Dictionary:
	if loop.state == CodingLoop.State.IDLE or loop.current_task == null:
		return {}
	var data = {
		"state": loop.state,
		"progress": loop.progress,
		"review_changes_needed": loop.review_changes_needed,
		"current_task": _serialize_task(loop.current_task),
	}
	if loop.merge_conflict != null:
		data["merge_conflict"] = _serialize_merge_conflict(loop.merge_conflict)
	return data

func deserialize_coding_loop(loop: CodingLoop, d: Dictionary) -> void:
	if d.is_empty():
		loop.reset()
		return
	var task = _deserialize_task(d.get("current_task", {}))
	loop.current_task = task
	loop.progress = float(d.get("progress", 0.0))
	loop.review_changes_needed = int(d.get("review_changes_needed", 0))
	loop.merge_conflict = null
	if d.has("merge_conflict"):
		loop.merge_conflict = _deserialize_merge_conflict(d["merge_conflict"])
	loop.state = int(d.get("state", CodingLoop.State.IDLE))

func _serialize_merge_conflict(conflict: MergeConflict) -> Dictionary:
	var chunks_data = []
	for chunk in conflict.chunks:
		chunks_data.append({
			"local_lines": chunk.local_lines,
			"remote_lines": chunk.remote_lines,
			"correct_resolution": chunk.correct_resolution,
		})
	return {
		"base_lines": conflict.base_lines,
		"chunks": chunks_data,
		"chunk_positions": conflict.chunk_positions,
		"resolutions": conflict.resolutions,
		"auto_merged": conflict.auto_merged,
	}

func _deserialize_merge_conflict(d: Dictionary) -> MergeConflict:
	var conflict = MergeConflict.new()
	conflict.base_lines = Array(d.get("base_lines", []))
	conflict.chunk_positions = Array(d.get("chunk_positions", []))
	conflict.resolutions = Array(d.get("resolutions", []))
	conflict.auto_merged = bool(d.get("auto_merged", false))
	for cd in d.get("chunks", []):
		var chunk = ConflictChunk.new()
		chunk.local_lines = Array(cd.get("local_lines", []))
		chunk.remote_lines = Array(cd.get("remote_lines", []))
		chunk.correct_resolution = str(cd.get("correct_resolution", ""))
		conflict.chunks.append(chunk)
	return conflict
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_save_load.gd`
Expected: all PASS

**Step 5: Commit**

```bash
git add src/systems/save_manager.gd test/unit/test_save_load.gd
git commit -m "feat: update save/load for MergeConflict serialization"
```

---

### Task 6: Three-panel merge UI in IDE

**Files:**
- Modify: `src/ide/ide_interface.gd`

This is the UI task — no unit tests (visual), but verify by running the game.

**Step 1: Add merge view nodes to `_build_ui()`**

After the `conflict_panel` creation (around line 332), add the three-panel merge view:

```gdscript
# Merge view (three columns: LOCAL | RESULT | REMOTE)
var merge_view = HBoxContainer.new()
merge_view.visible = false
merge_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
merge_view.add_theme_constant_override("separation", 4)
vbox.add_child(merge_view)
# Store reference
_merge_view = merge_view

# LOCAL panel
var local_panel = _build_merge_column("LOCAL")
merge_view.add_child(local_panel)
_merge_local_display = local_panel.get_node("Content")

# RESULT panel (center)
var result_panel = _build_merge_column("RESULT")
merge_view.add_child(result_panel)
_merge_result_display = result_panel.get_node("Content")

# REMOTE panel
var remote_panel = _build_merge_column("REMOTE")
merge_view.add_child(remote_panel)
_merge_remote_display = remote_panel.get_node("Content")
```

Add helper to build each column:

```gdscript
func _build_merge_column(title: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12)
	style.set_content_margin_all(6)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(label)
	var content = RichTextLabel.new()
	content.name = "Content"
	content.bbcode_enabled = true
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
	content.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(content)
	return panel
```

Add new member variables at the top of the class:

```gdscript
var _merge_view: HBoxContainer
var _merge_local_display: RichTextLabel
var _merge_result_display: RichTextLabel
var _merge_remote_display: RichTextLabel
```

**Step 2: Update `_show_conflict_ui` for merge view**

Replace `_show_conflict_ui` entirely:

```gdscript
func _show_conflict_ui(_left_unused, _right_unused, tab: CodingTab):
	# Hide old conflict_panel, show merge view
	conflict_panel.visible = false
	var conflict = tab.coding_loop.merge_conflict
	if conflict == null:
		return
	_merge_view.visible = true
	code_display.visible = false
	notification_area.visible = true
	_populate_merge_panels(conflict)
	_update_merge_status(conflict)

func _populate_merge_panels(conflict: MergeConflict):
	_merge_local_display.text = ""
	_merge_remote_display.text = ""
	_merge_result_display.text = ""
	var current_chunk = conflict.get_next_unresolved_index()
	# LOCAL panel
	for entry in conflict.get_local_display_lines():
		if entry["type"] == "conflict":
			var ci = entry["chunk_index"]
			var color = _get_chunk_color(ci, current_chunk, conflict)
			_merge_local_display.append_text("[color=%s]%s[/color]\n" % [color, entry["text"]])
		else:
			_merge_local_display.append_text(_syntax_highlight(entry["text"]) + "\n")
	# REMOTE panel
	for entry in conflict.get_remote_display_lines():
		if entry["type"] == "conflict":
			var ci = entry["chunk_index"]
			var color = _get_chunk_color(ci, current_chunk, conflict)
			_merge_remote_display.append_text("[color=%s]%s[/color]\n" % [color, entry["text"]])
		else:
			_merge_remote_display.append_text(_syntax_highlight(entry["text"]) + "\n")
	# RESULT panel — show resolved lines so far
	if conflict.auto_merged:
		_update_result_panel(conflict)

func _get_chunk_color(chunk_index: int, current_chunk_index: int, conflict: MergeConflict) -> String:
	if chunk_index < conflict.resolutions.size() and conflict.resolutions[chunk_index] != "":
		return "#4ec9b0"  # resolved — green
	elif chunk_index == current_chunk_index:
		return "#f4a460"  # current — orange/highlight
	else:
		return "#f44747"  # unresolved — red

func _update_result_panel(conflict: MergeConflict):
	_merge_result_display.text = ""
	var merged = conflict.get_merged_lines()
	for line in merged:
		_merge_result_display.append_text(_syntax_highlight(line) + "\n")
	# If not all resolved, show placeholder for remaining
	var next = conflict.get_next_unresolved_index()
	if next >= 0:
		_merge_result_display.append_text("\n[color=#666666]<<< unresolved conflict >>>[/color]\n")

func _update_merge_status(conflict: MergeConflict):
	if not conflict.auto_merged:
		_show_merge_notification("MERGE CONFLICT — Press [b]Ctrl+A[/b] to auto-merge")
	else:
		var remaining = 0
		for i in range(conflict.chunks.size()):
			if i >= conflict.resolutions.size() or conflict.resolutions[i] == "":
				remaining += 1
		if remaining > 0:
			_show_merge_notification("%d conflict%s remaining — [b]Ctrl+L[/b] local  [b]Ctrl+R[/b] remote  [b]Ctrl+B[/b] both" % [remaining, "s" if remaining > 1 else ""])
		else:
			_show_merge_notification("[color=#4ec9b0]All conflicts resolved![/color]")

func _show_merge_notification(text: String):
	for child in review_panel.get_children():
		child.queue_free()
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text
	label.fit_content = true
	label.custom_minimum_size = Vector2(0, 32)
	review_panel.add_child(label)
	review_panel.visible = true
	notification_area.visible = true
```

**Step 3: Add keyboard shortcuts in `_unhandled_input`**

In the `_unhandled_input` method, replace the existing arrow-key conflict handling (lines 196-204) with:

```gdscript
	# Merge conflict shortcuts
	if loop.state == CodingLoop.State.CONFLICT and loop.merge_conflict != null:
		if event.ctrl_pressed:
			if keycode == KEY_A and not loop.merge_conflict.auto_merged:
				loop.auto_merge()
				_on_merge_auto_merged()
				get_viewport().set_input_as_handled()
				return
			elif keycode == KEY_L and loop.merge_conflict.auto_merged:
				_resolve_current_chunk("local")
				get_viewport().set_input_as_handled()
				return
			elif keycode == KEY_R and loop.merge_conflict.auto_merged:
				_resolve_current_chunk("remote")
				get_viewport().set_input_as_handled()
				return
			elif keycode == KEY_B and loop.merge_conflict.auto_merged:
				_resolve_current_chunk("both")
				get_viewport().set_input_as_handled()
				return
		return  # Don't process other keys during conflict
```

Add helpers:

```gdscript
func _on_merge_auto_merged():
	if _focused_index < 0 or _focused_index >= tabs.size():
		return
	var conflict = tabs[_focused_index].coding_loop.merge_conflict
	if conflict:
		_populate_merge_panels(conflict)
		_update_merge_status(conflict)

func _resolve_current_chunk(resolution: String):
	if _focused_index < 0 or _focused_index >= tabs.size():
		return
	var loop = coding_loop
	loop.resolve_merge_chunk(resolution)
	var conflict = loop.merge_conflict
	if conflict and loop.state == CodingLoop.State.CONFLICT:
		_populate_merge_panels(conflict)
		_update_merge_status(conflict)
	elif loop.state != CodingLoop.State.CONFLICT:
		# Conflict resolved (complete or fixing) — switch back to normal view
		_hide_merge_view()
```

**Step 4: Hide merge view when leaving conflict state**

```gdscript
func _hide_merge_view():
	if _merge_view:
		_merge_view.visible = false
	code_display.visible = true
```

Call `_hide_merge_view()` at the top of `_update_ui()` to ensure it's always hidden when not in conflict state.

**Step 5: Update `_update_ui()` CONFLICT case**

In the `_update_ui` match block, update the CONFLICT case:

```gdscript
		CodingLoop.State.CONFLICT:
			if loop.merge_conflict:
				if not loop.merge_conflict.auto_merged:
					status_label.text = "MERGE CONFLICT — Ctrl+A to auto-merge"
				else:
					status_label.text = "MERGE CONFLICT — Ctrl+L/R/B to resolve"
			_set_keyboard_enabled(false)
			notification_area.visible = true
```

**Step 6: Update `_connect_tab_signals` and signal handlers**

Replace `conflict_appeared` with `merge_conflict_started`:

```gdscript
func _connect_tab_signals(tab: CodingTab):
	tab.coding_loop.state_changed.connect(_on_tab_state_changed.bind(tab))
	tab.coding_loop.progress_changed.connect(_on_tab_progress_changed.bind(tab))
	tab.coding_loop.merge_conflict_started.connect(_on_tab_merge_conflict_started.bind(tab))
	tab.coding_loop.task_done.connect(_on_tab_task_done.bind(tab))

func _disconnect_tab_signals(tab: CodingTab):
	if tab.coding_loop.state_changed.is_connected(_on_tab_state_changed):
		tab.coding_loop.state_changed.disconnect(_on_tab_state_changed)
	if tab.coding_loop.progress_changed.is_connected(_on_tab_progress_changed):
		tab.coding_loop.progress_changed.disconnect(_on_tab_progress_changed)
	if tab.coding_loop.merge_conflict_started.is_connected(_on_tab_merge_conflict_started):
		tab.coding_loop.merge_conflict_started.disconnect(_on_tab_merge_conflict_started)
	if tab.coding_loop.task_done.is_connected(_on_tab_task_done):
		tab.coding_loop.task_done.disconnect(_on_tab_task_done)
```

Replace `_on_tab_conflict_appeared`:

```gdscript
func _on_tab_merge_conflict_started(conflict: MergeConflict, tab: CodingTab):
	if _is_focused_tab(tab):
		_show_conflict_ui(null, null, tab)
```

**Step 7: Update `_on_ai_tool_acted` conflict case**

```gdscript
		"conflict":
			if success:
				_show_review_comment("[color=#4ec9b0]Merge Resolver:[/color] Resolved correctly!")
			else:
				_show_review_comment("[color=#f44747]Merge Resolver:[/color] Picked wrong resolution...")
			# Refresh merge view if visible
			if _merge_view and _merge_view.visible and _focused_index >= 0:
				var conflict = coding_loop.merge_conflict
				if conflict and coding_loop.state == CodingLoop.State.CONFLICT:
					_populate_merge_panels(conflict)
					_update_merge_status(conflict)
				elif coding_loop.state != CodingLoop.State.CONFLICT:
					_hide_merge_view()
```

**Step 8: Run the game and test manually**

Run: `godot --path /home/lars/Prosjekter/consultancy-tycoon`

Test: Start a contract with high difficulty (tier 3+), write code, get review approved, trigger a merge conflict. Verify:
- Three-panel view appears
- Ctrl+A auto-merges
- Ctrl+L/R/B resolves chunks
- Wrong pick on tricky chunk sends to FIXING

**Step 9: Commit**

```bash
git add src/ide/ide_interface.gd
git commit -m "feat: three-panel merge UI with Ctrl+A/L/R/B keyboard shortcuts"
```

---

### Task 7: Run all tests and fix any regressions

**Files:**
- Possibly: any files with test failures

**Step 1: Run full test suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

**Step 2: Fix any failures**

Common things to check:
- `test_save_load.gd`: old references to `conflict_correct_side` need updating
- `test_multi_tab.gd`: if it sets up conflict state directly
- `test_events.gd`: if it checks conflict signals

**Step 3: Commit fixes**

```bash
git add -A
git commit -m "fix: resolve test regressions from merge conflict rework"
```

---

### Task 8: Update CLAUDE.md and memory

**Step 1: Update CLAUDE.md** to document the new merge system briefly.

**Step 2: Update memory** with the new architecture notes.

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for merge conflict rework"
```
