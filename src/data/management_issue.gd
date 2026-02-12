extends Resource
class_name ManagementIssue

var id: String = ""
var title: String = ""
var description: String = ""
var affected_consultant_id: String = ""
var choices: Array = []
# Each choice: { "label": String, "effects": Array }
# Effects: { "type": "morale_change"|"fire"|"add_money"|"spend_money", "amount": float, "target": String }

static func create(p_id: String, p_title: String, p_desc: String, p_consultant_id: String, p_choices: Array) -> ManagementIssue:
	var issue = ManagementIssue.new()
	issue.id = p_id
	issue.title = p_title
	issue.description = p_desc
	issue.affected_consultant_id = p_consultant_id
	issue.choices = p_choices
	return issue
