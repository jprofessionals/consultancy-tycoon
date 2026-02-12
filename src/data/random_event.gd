class_name RandomEvent
extends Resource

const EXPIRY_TIME: float = 180.0  # seconds before auto-expiring

var id: String
var title: String
var description: String
var choices: Array = []
var created_at: float = 0.0
# Each choice: { "label": String, "effects": Array }
# Each effect: { "type": "add_money"|"spend_money"|"add_reputation", "amount": float }

func is_expired(current_time: float) -> bool:
	return current_time - created_at >= EXPIRY_TIME

static func create(p_id: String, p_title: String, p_description: String, p_choices: Array) -> RandomEvent:
	var event = RandomEvent.new()
	event.id = p_id
	event.title = p_title
	event.description = p_description
	event.choices = p_choices
	event.created_at = Time.get_ticks_msec() / 1000.0
	return event
