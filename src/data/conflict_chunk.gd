extends RefCounted
class_name ConflictChunk

var local_lines: Array = []
var remote_lines: Array = []
var correct_resolution: String = ""   # "local", "remote", "both", or "" (any valid)
