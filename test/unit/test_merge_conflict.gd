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
