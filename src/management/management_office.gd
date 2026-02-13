extends Control

signal back_to_desk_requested
signal contract_board_clicked
signal hiring_board_clicked
signal staff_roster_clicked
signal inbox_clicked
signal consultant_clicked(consultant: ConsultantData)

# Layout constants
const MAX_DESKS = 18
const DESK_BASE_COST = 500.0  # Cost multiplied by current capacity

# Isometric scale (0.5 = half native size so the grid fits the viewport)
const ISO_SCALE = 0.5
const TILE_W = 208.0 * ISO_SCALE   # 104
const HALF_W = 104.0 * ISO_SCALE   # 52
const TILE_H = 152.0 * ISO_SCALE   # 76
const HALF_H = 76.0 * ISO_SCALE    # 38
const GRID_COLS = 6
const GRID_ROWS = 4
const GRID_ORIGIN = Vector2(472, 158)

# Preloaded isometric textures (used in _build_desks which runs on purchase)
const DESK_TEX = preload("res://assets/kenney-furniture/isometric/desk_SE.png")
const CHAIR_TEX = preload("res://assets/kenney-furniture/isometric/chairDesk_SE.png")
const MONITOR_TEX = preload("res://assets/kenney-furniture/isometric/computerScreen_SE.png")
const FURNITURE_SCALE = 0.7  # Scale down desk items to leave room between desks

# Chat bubble messages
const CHAT_MESSAGES = [
	"JavaScript really sucks",
	"I hate weak typing",
	"Who wrote this code... oh wait, it was me",
	"It works on my machine",
	"Tabs > spaces, fight me",
	"LGTM, ship it",
	"This should only take 5 minutes...",
	"Have you tried turning it off and on again?",
	"git push --force, what could go wrong?",
	"I don't always test my code, but when I do, I do it in production",
	"99 bugs on the wall, fix one, 127 bugs on the wall",
	"It's not a bug, it's a feature",
	"Works on my machine, ship it",
	"sudo make me a sandwich",
	"There are 10 types of people...",
	"// TODO: fix this later",
	"Copy paste is the best design pattern",
	"Stackoverflow is my co-pilot",
	"The code review will be quick, they said",
	"My code compiled on the first try... I'm scared",
	"Who needs documentation anyway?",
	"I'll refactor this tomorrow",
	"Merge conflict? Just accept both",
	"rm -rf node_modules, pray, npm install",
	"Why is this a 2000-line function",
	"The tests pass if you don't run them",
	"I should have been a plumber",
	"Segfault? In MY code?",
	"Let me just add one more dependency...",
	"CSS is not a real language",
	"Have you tried deleting your cache?",
	"I don't need types, I have confidence",
	"That's a feature, not a memory leak",
	"Just wrap it in a try-catch",
	"Who approved this PR?",
	"Deploying on a Friday, wish me luck",
	"The sprint is going great (narrator: it was not)",
	"My regex works, I have no idea why",
	"undefined is not a function",
	"The real bug was the friends we made along the way",
	"git blame says it was me. Impossible.",
	"I could fix this, or I could rewrite everything",
	"Senior developer = professional Googler",
	"This code is self-documenting (it's not)",
	"I'll add tests after the deadline",
	"Premature optimization? Never heard of her",
	"My Docker container is 4GB and I don't know why",
	"The database is just a big JSON file, right?",
	"Who needs sleep when you have deadlines",
	"I love Monday morning deployments",
	"The client changed the requirements again",
	"This meeting could have been a Slack message",
	"The build is broken. Again.",
	"I'm in this codebase and I don't like it",
	"One does not simply merge to main",
	"Ah yes, the classic off-by-one error",
	"printf debugging is an art form",
	"NaN !== NaN makes perfect sense",
	"There's always a relevant xkcd",
	"The cloud is just someone else's computer",
	"I see dead code",
	"Why is prod different from staging?",
	"The backlog is a graveyard of good ideas",
	"Microservices were a mistake",
	"Please don't touch that file, nobody knows how it works",
	"It compiled, that means it's correct, right?",
	"Error 418: I'm a teapot",
	"I spent 6 hours on a missing semicolon",
	"AI wrote this code. I take no responsibility.",
	"Left pad incident, never forget",
	"Inheritance is just shared suffering",
	"My IDE uses more RAM than the app",
	"Nullable? Everything is nullable.",
	"The real MVP is the undo button",
	"Writing code is easy, reading code is hard",
	"I'm not lazy, I'm energy efficient",
	"You had me at 'Hello, World!'",
	"The intern pushed to production",
	"Kubernetes? I barely know her",
	"This PR has been open for 47 days",
	"My terminal is cooler than your GUI",
	"I use vim btw",
	"This looks like a job for another abstraction layer",
	"The only constant is change. And magic numbers.",
	"Thread.sleep(1000) should fix the race condition",
	"Callbacks inside callbacks inside callbacks...",
	"var x = x || 'I give up'",
	"The best code is no code",
	"I speak fluent Stack Overflow",
	"Java: write once, debug everywhere",
	"Python would be one line. Just saying.",
	"PHP is alive and I have feelings about that",
	"Everything is a string if you're brave enough",
	"Agile is just chaos with a Sprint name",
	"DNS. It's always DNS.",
	"chmod 777, security is overrated",
	"SELECT * FROM problems",
	"If it hurts, do it more often (CI/CD wisdom)",
	"The bug is in the dependency. Probably.",
	"I hate YAML indentation more than Python's",
	"The standup took 45 minutes today",
	"Our tech debt has tech debt",
	"Nullable reference exception, my old friend",
	"The spec says 'TBD' in 14 places",
	"I don't always use regex, but when I do, .*",
	"TypeScript: JavaScript with a helmet",
	"The API returns 200 OK with an error message",
	"Hotfix on top of a hotfix on top of a hotfix",
	"Looks like someone forgot to gitignore .env",
	"The frontend is fine. It's the backend. Probably.",
	"Running migrations in prod, hold my coffee",
	"I understood recursion after I understood recursion",
	"goto considered harmful, but tempting",
	"The cache invalidation problem strikes again",
	"Naming things is the hardest problem in CS",
	"Why did I make this a singleton?",
	"The linter has opinions and they are wrong",
	"My code works, don't ask me how",
	"That's not legacy code, it's vintage",
	"I love the smell of fresh commits in the morning",
]

var _desk_nodes: Array = []
var _desk_node_visuals: Array = []  # all desk-related nodes for rebuild
var _buy_desk_btn: Button
var _consultant_sprites: Array = []
var _chat_timer: float = 0.0
const CHAT_INTERVAL = 4.0
var _back_door: TextureRect
var _back_door_label: Label


func _cart_to_iso(col: int, row: int, origin: Vector2) -> Vector2:
	return Vector2(
		origin.x + (col - row) * HALF_W,
		origin.y + (col + row) * HALF_H
	)


func _make_iso_sprite(texture: Texture2D, pos: Vector2, extra_scale: float = 1.0) -> TextureRect:
	var tex_rect = TextureRect.new()
	tex_rect.texture = texture
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var s = ISO_SCALE * extra_scale
	var w = texture.get_width() * s
	var h = texture.get_height() * s
	tex_rect.custom_minimum_size = Vector2(w, h)
	tex_rect.size = Vector2(w, h)
	tex_rect.position = pos
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex_rect


func _ready():
	_back_door = %BackDoor
	_back_door_label = %BackDoorLabel

	# Connect door click
	_back_door.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			back_to_desk_requested.emit()
	)

	# Connect wall object clicks
	%ContractsObj.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			contract_board_clicked.emit()
	)
	%HiringObj.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hiring_board_clicked.emit()
	)
	%StaffObj.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			staff_roster_clicked.emit()
	)
	%InboxObj.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			inbox_clicked.emit()
	)

	# Wall object hover effects
	_setup_hover(%ContractsObj, Color(0.85, 0.87, 0.85))
	_setup_hover(%HiringObj, Color(0.12, 0.15, 0.22))
	_setup_hover(%StaffObj, Color(0.55, 0.45, 0.3))
	_setup_hover(%InboxObj, Color(0.3, 0.35, 0.45))

	_build_desks()


func _setup_hover(obj: ColorRect, base_color: Color):
	obj.mouse_entered.connect(func(): obj.color = base_color.lightened(0.15))
	obj.mouse_exited.connect(func(): obj.color = base_color)


func _build_desks():
	# Clear previous desk visuals
	for node in _desk_node_visuals:
		if is_instance_valid(node):
			node.queue_free()
	_desk_node_visuals.clear()
	_desk_nodes.clear()

	var desk_count: int = GameState.desk_capacity
	var origin = GRID_ORIGIN

	for i in desk_count:
		var col = i % GRID_COLS
		var row = 1 + i / GRID_COLS  # Row 0 is the wall, desks start at row 1
		var iso_pos = _cart_to_iso(col, row, origin)

		# Chair (behind desk, z_index -1) — scaled down, flipped to match grid
		var chair = _make_iso_sprite(CHAIR_TEX, iso_pos + Vector2(38, 2), FURNITURE_SCALE)
		chair.flip_h = true
		chair.z_index = -1
		add_child(chair)
		_desk_node_visuals.append(chair)

		# Desk surface — scaled down, flipped
		var desk = _make_iso_sprite(DESK_TEX, iso_pos + Vector2(26, 15), FURNITURE_SCALE)
		desk.flip_h = true
		add_child(desk)
		_desk_node_visuals.append(desk)

		# Monitor on desk — scaled down, flipped
		var monitor = _make_iso_sprite(MONITOR_TEX, iso_pos + Vector2(38, 2), FURNITURE_SCALE)
		monitor.flip_h = true
		add_child(monitor)
		_desk_node_visuals.append(monitor)

		# Desk number label
		var num_label = Label.new()
		num_label.text = str(i + 1)
		num_label.add_theme_font_size_override("font_size", 9)
		num_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.38))
		num_label.position = iso_pos + Vector2(42, 30)
		num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(num_label)
		_desk_node_visuals.append(num_label)

		_desk_nodes.append({"position": iso_pos, "index": i, "chair": chair, "monitor": monitor})

	# Buy Desk button (after last desk position)
	if _buy_desk_btn and is_instance_valid(_buy_desk_btn):
		_buy_desk_btn.queue_free()
	_buy_desk_btn = null

	if desk_count < MAX_DESKS:
		var next_col = desk_count % GRID_COLS
		var next_row = 1 + desk_count / GRID_COLS
		var btn_iso = _cart_to_iso(next_col, next_row, origin)

		_buy_desk_btn = Button.new()
		var btn_size = Vector2(55, 35)
		_buy_desk_btn.custom_minimum_size = btn_size
		_buy_desk_btn.position = btn_iso + Vector2(26, 15)
		_buy_desk_btn.size = btn_size
		_update_buy_desk_label()
		_buy_desk_btn.pressed.connect(_on_buy_desk)
		add_child(_buy_desk_btn)


func _get_desk_cost() -> float:
	return DESK_BASE_COST * GameState.desk_capacity


func _update_buy_desk_label():
	if _buy_desk_btn:
		_buy_desk_btn.add_theme_font_size_override("font_size", 10)
		_buy_desk_btn.text = "+ Desk\n$%.0f" % _get_desk_cost()
		_buy_desk_btn.disabled = GameState.money < _get_desk_cost()


func _on_buy_desk():
	var cost = _get_desk_cost()
	if not GameState.spend_money(cost):
		return
	GameState.desk_capacity += 1
	_build_desks()
	refresh()


func set_desk_attention(attention: bool) -> void:
	if _back_door:
		_back_door.modulate = Color(1.5, 0.5, 0.5) if attention else Color.WHITE


func refresh():
	# Update buy desk button affordability
	_update_buy_desk_label()

	# Clear existing consultant sprites
	for sprite_data in _consultant_sprites:
		if is_instance_valid(sprite_data["node"]):
			sprite_data["node"].queue_free()
	_consultant_sprites.clear()

	var in_office = GameState.get_consultants_by_location(ConsultantData.Location.IN_OFFICE)
	var away_consultants = _get_away_consultants()
	var occupied_count = mini(in_office.size() + away_consultants.size(), _desk_nodes.size())

	# Place in-office consultants at desks
	for i in in_office.size():
		if i >= _desk_nodes.size():
			break
		var consultant: ConsultantData = in_office[i]
		var desk_data = _desk_nodes[i]
		var desk_pos: Vector2 = desk_data["position"]
		_create_consultant_sprite(consultant, desk_pos, i)

	# Mark empty desks with away consultant names
	var away_index = in_office.size()
	for ac in away_consultants:
		if away_index >= _desk_nodes.size():
			break
		var desk_data = _desk_nodes[away_index]
		var desk_pos: Vector2 = desk_data["position"]
		_create_away_label(ac, desk_pos)
		away_index += 1

	# Show chair/monitor only on occupied desks, hide on empty ones
	for i in _desk_nodes.size():
		var desk_data = _desk_nodes[i]
		var is_occupied = i < occupied_count
		if is_instance_valid(desk_data["chair"]):
			desk_data["chair"].visible = is_occupied
		if is_instance_valid(desk_data["monitor"]):
			desk_data["monitor"].visible = is_occupied


func _create_consultant_sprite(consultant: ConsultantData, desk_pos: Vector2, _desk_index: int):
	var container = Control.new()
	container.position = desk_pos + Vector2(40, -18)
	container.size = Vector2(25, 50)
	add_child(container)

	# Head (rounded to circle)
	var head = PanelContainer.new()
	var head_style = StyleBoxFlat.new()
	head_style.bg_color = _get_consultant_color(consultant)
	head_style.set_corner_radius_all(11)
	head.add_theme_stylebox_override("panel", head_style)
	head.position = Vector2(0, 0)
	head.custom_minimum_size = Vector2(22, 22)
	head.size = Vector2(22, 22)
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_child(head)

	# Make head clickable
	head.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			consultant_clicked.emit(consultant)
	)

	# Name label
	var name_label = Label.new()
	var first_name = consultant.name.split(" ")[0] if " " in consultant.name else consultant.name
	name_label.text = first_name
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	name_label.position = Vector2(-5, 24)
	container.add_child(name_label)

	# State label
	var state_label = Label.new()
	if consultant.training_skill != "":
		state_label.text = "Training"
		state_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
	else:
		state_label.text = "Idle"
		state_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	state_label.add_theme_font_size_override("font_size", 8)
	state_label.position = Vector2(-5, 35)
	container.add_child(state_label)

	_consultant_sprites.append({"node": container, "consultant": consultant})


func _create_away_label(consultant: ConsultantData, desk_pos: Vector2):
	var container = Control.new()
	container.position = desk_pos + Vector2(28, 12)
	container.size = Vector2(60, 16)
	add_child(container)

	var label = Label.new()
	var first_name = consultant.name.split(" ")[0] if " " in consultant.name else consultant.name
	label.text = "Out: " + first_name
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	container.add_child(label)

	_consultant_sprites.append({"node": container, "consultant": consultant})


func _get_away_consultants() -> Array:
	var away: Array = []
	for c in GameState.consultants:
		if c.location == ConsultantData.Location.ON_PROJECT or c.location == ConsultantData.Location.ON_RENTAL:
			away.append(c)
	return away


func _get_consultant_color(consultant: ConsultantData) -> Color:
	# Deterministic color from consultant name hash
	var h = consultant.name.hash()
	var r = 0.35 + fmod(abs(float(h % 100)) / 100.0, 0.4)
	var g = 0.35 + fmod(abs(float((h / 100) % 100)) / 100.0, 0.4)
	var b = 0.45 + fmod(abs(float((h / 10000) % 100)) / 100.0, 0.3)
	return Color(r, g, b)


func _process(delta: float):
	_chat_timer += delta
	if _chat_timer >= CHAT_INTERVAL:
		_chat_timer -= CHAT_INTERVAL
		_spawn_chat_bubble()


func _spawn_chat_bubble():
	# Only show bubbles for in-office consultant sprites
	var in_office_sprites: Array = []
	for sprite_data in _consultant_sprites:
		if is_instance_valid(sprite_data["node"]) and sprite_data["consultant"].location == ConsultantData.Location.IN_OFFICE:
			in_office_sprites.append(sprite_data)

	if in_office_sprites.is_empty():
		return

	var chosen = in_office_sprites[randi() % in_office_sprites.size()]
	var sprite_node: Control = chosen["node"]
	if not is_instance_valid(sprite_node):
		return

	var message = CHAT_MESSAGES[randi() % CHAT_MESSAGES.size()]

	# Create chat bubble with rounded background
	var bubble_panel = PanelContainer.new()
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.2, 0.22, 0.28, 0.9)
	bubble_style.set_corner_radius_all(6)
	bubble_style.border_color = Color(0.3, 0.32, 0.38, 0.6)
	bubble_style.set_border_width_all(1)
	bubble_style.content_margin_left = 8
	bubble_style.content_margin_right = 8
	bubble_style.content_margin_top = 3
	bubble_style.content_margin_bottom = 3
	bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	bubble_panel.position = Vector2(30, -30)
	bubble_panel.z_index = 10

	var bubble = Label.new()
	bubble.text = message
	bubble.add_theme_font_size_override("font_size", 10)
	bubble.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	bubble_panel.add_child(bubble)

	sprite_node.add_child(bubble_panel)

	# Tween: wait 2.5s, fade out over 0.5s, then remove
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(bubble_panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(bubble_panel):
			bubble_panel.queue_free()
	)
