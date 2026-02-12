class_name RandomEvent
extends Resource

var id: String
var title: String
var description: String
var choices: Array = []
# Each choice: { "label": String, "effects": Array }
# Each effect: { "type": "add_money"|"spend_money"|"add_reputation", "amount": float }

static func create(p_id: String, p_title: String, p_description: String, p_choices: Array) -> RandomEvent:
	var event = RandomEvent.new()
	event.id = p_id
	event.title = p_title
	event.description = p_description
	event.choices = p_choices
	return event
