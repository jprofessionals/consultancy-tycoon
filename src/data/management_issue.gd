extends Resource
class_name ManagementIssue

const EXPIRY_TIME: float = 120.0  # seconds before auto-expiring

var id: String = ""
var title: String = ""
var description: String = ""
var affected_consultant_id: String = ""
var choices: Array = []
var created_at: float = 0.0
# Each choice: { "label": String, "effects": Array }
# Effects: { "type": "morale_change"|"fire"|"add_money"|"spend_money", "amount": float, "target": String }

func is_expired(current_time: float) -> bool:
	return current_time - created_at >= EXPIRY_TIME

static func create(p_id: String, p_title: String, p_desc: String, p_consultant_id: String, p_choices: Array) -> ManagementIssue:
	var issue = ManagementIssue.new()
	issue.id = p_id
	issue.title = p_title
	issue.description = p_desc
	issue.affected_consultant_id = p_consultant_id
	issue.choices = p_choices
	issue.created_at = Time.get_ticks_msec() / 1000.0
	return issue
