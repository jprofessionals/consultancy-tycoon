extends RefCounted
class_name CodingTab

var coding_loop: CodingLoop = CodingLoop.new()
var contract: ClientContract = null
var task_index: int = 0
var total_tasks: int = 0
var difficulty_modifier: float = 1.0
var stuck: bool = false

# Per-tab visual state
var code_snippet: Array = []
var lines_revealed: int = 0

func get_tab_label() -> String:
	if contract:
		return "%s (%d/%d)" % [contract.client_name, task_index + 1, total_tasks]
	return "Empty"

func is_contract_done() -> bool:
	return task_index >= total_tasks
