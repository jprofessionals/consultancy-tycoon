class_name EventManager
extends RefCounted

var pending_events: Array = []
var _templates: Array[Dictionary] = []

func _init():
	_build_templates()

func _build_templates():
	_templates = [
		{
			"id": "recruiter_message",
			"title": "Recruiter Spotted Your Profile",
			"description": "A recruiter from a Fortune 500 company noticed your growing reputation. They want to feature you in their tech blog.",
			"choices": [
				{ "label": "Accept interview", "effects": [{ "type": "add_reputation", "amount": 15.0 }] },
				{ "label": "Politely decline", "effects": [] },
			]
		},
		{
			"id": "stackoverflow_viral",
			"title": "Stack Overflow Answer Went Viral",
			"description": "Your answer on 'How to center a div' has reached 10k upvotes. The community is impressed.",
			"choices": [
				{ "label": "Bask in the glory", "effects": [{ "type": "add_reputation", "amount": 10.0 }] },
			]
		},
		{
			"id": "rush_job",
			"title": "Rush Job Offer",
			"description": "A client needs an emergency hotfix deployed tonight. Double pay, but it won't be pretty.",
			"choices": [
				{ "label": "Take the job ($300)", "effects": [{ "type": "add_money", "amount": 300.0 }] },
				{ "label": "Need my sleep", "effects": [] },
			]
		},
		{
			"id": "tax_season",
			"title": "Tax Season",
			"description": "The taxman cometh. Time to pay your quarterly freelance taxes.",
			"choices": [
				{ "label": "Pay taxes (-$200)", "effects": [{ "type": "spend_money", "amount": 200.0 }] },
				{ "label": "Hire accountant (-$100, +rep)", "effects": [{ "type": "spend_money", "amount": 100.0 }, { "type": "add_reputation", "amount": 5.0 }] },
			]
		},
		{
			"id": "conference_invite",
			"title": "Conference Invitation",
			"description": "You've been invited to speak at DevConf 2026. Attending costs money but could boost your career.",
			"choices": [
				{ "label": "Attend (-$150, +20 rep)", "effects": [{ "type": "spend_money", "amount": 150.0 }, { "type": "add_reputation", "amount": 20.0 }] },
				{ "label": "Too busy", "effects": [] },
			]
		},
		{
			"id": "blog_viral",
			"title": "Blog Post Went Viral",
			"description": "Your blog post 'Why I Quit FAANG to Freelance' is trending on Hacker News. Clients are flooding in.",
			"choices": [
				{ "label": "Ride the wave", "effects": [{ "type": "add_reputation", "amount": 12.0 }, { "type": "add_money", "amount": 100.0 }] },
			]
		},
	]

func generate_event() -> RandomEvent:
	var template = _templates[randi() % _templates.size()]
	var event = RandomEvent.create(
		template["id"],
		template["title"],
		template["description"],
		template["choices"]
	)
	pending_events.append(event)
	return event

func get_unread_count() -> int:
	return pending_events.size()

func apply_choice(event: RandomEvent, choice_index: int, game_state: Node) -> void:
	if choice_index < 0 or choice_index >= event.choices.size():
		return
	var choice = event.choices[choice_index]
	for effect in choice["effects"]:
		match effect["type"]:
			"add_money":
				game_state.add_money(effect["amount"])
			"spend_money":
				game_state.spend_money(effect["amount"])
			"add_reputation":
				game_state.add_reputation(effect["amount"])
	pending_events.erase(event)

func clear_events() -> void:
	pending_events.clear()
