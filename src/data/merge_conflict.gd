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
