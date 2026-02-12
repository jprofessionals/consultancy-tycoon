extends Control

signal back_to_desk_requested
signal contract_board_clicked
signal hiring_board_clicked
signal staff_roster_clicked
signal inbox_clicked
signal consultant_clicked(consultant: ConsultantData)

# Layout constants
const DESK_SIZE = Vector2(80, 60)
const DESK_SPACING = Vector2(130, 120)
const DESK_COLUMNS = 8
const WALL_TOP = 50.0       # Below HUD overlay
const WALL_HEIGHT = 60.0
const DESK_AREA_TOP = 190.0  # Room between wall and first desk row
const MAX_DESKS = 24
const DESK_BASE_COST = 500.0  # Cost multiplied by current capacity

# Isometric tile dimensions (from floorFull_SE.png)
const TILE_W = 208.0
const HALF_W = 104.0
const TILE_H = 152.0
const HALF_H = 76.0
const GRID_COLS = 8
const GRID_ROWS = 4

# Preloaded isometric textures (used in _build_desks which runs on purchase)
const DESK_TEX = preload("res://assets/kenney-furniture/isometric/desk_SE.png")
const CHAIR_TEX = preload("res://assets/kenney-furniture/isometric/chairDesk_SE.png")
const MONITOR_TEX = preload("res://assets/kenney-furniture/isometric/computerScreen_SE.png")

# Colors
const FLOOR_COLOR = Color(0.22, 0.24, 0.26)
const WALL_COLOR = Color(0.25, 0.27, 0.3)
const DESK_COLOR = Color(0.35, 0.3, 0.25)
const DOOR_COLOR = Color(0.45, 0.33, 0.22)
const DOOR_FRAME_COLOR = Color(0.35, 0.25, 0.18)
const WHITEBOARD_COLOR = Color(0.85, 0.87, 0.85)
const SCREEN_COLOR = Color(0.12, 0.15, 0.22)
const CLIPBOARD_COLOR = Color(0.55, 0.45, 0.3)
const INBOX_COLOR = Color(0.3, 0.35, 0.45)
const LOCKED_DOOR_COLOR = Color(0.3, 0.28, 0.25)
const OBJECT_LABEL_COLOR = Color(0.15, 0.15, 0.15)

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


const REF_W = 1152.0
const REF_H = 648.0

func _get_vp() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(REF_W, REF_H)


func _cart_to_iso(col: int, row: int, origin: Vector2) -> Vector2:
	return Vector2(
		origin.x + (col - row) * HALF_W,
		origin.y + (col + row) * HALF_H
	)


func _get_grid_origin(vp: Vector2) -> Vector2:
	var grid_pixel_w = (GRID_COLS + GRID_ROWS) * HALF_W
	return Vector2(
		(vp.x - grid_pixel_w) / 2.0 + GRID_ROWS * HALF_W,
		40.0
	)


func _ready():
	_build_office()


func _build_office():
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vp = _get_vp()
	var origin = _get_grid_origin(vp)

	# Floor tiles
	var floor_tex = load("res://assets/kenney-furniture/isometric/floorFull_SE.png")
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var iso_pos = _cart_to_iso(col, row, origin)
			var tile = TextureRect.new()
			tile.texture = floor_tex
			tile.position = iso_pos
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tile)

	# Back wall along row 0 (skip col 0 — doorway goes there)
	var wall_tex = load("res://assets/kenney-furniture/isometric/wall_SE.png")
	for col in range(1, GRID_COLS):
		var iso_pos = _cart_to_iso(col, 0, origin)
		var wall_sprite = TextureRect.new()
		wall_sprite.texture = wall_tex
		# Wall sits on top of the floor tile, offset vertically
		wall_sprite.position = iso_pos + Vector2(50, -110)
		wall_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wall_sprite)

	# === DECORATIONS ===
	var bookcase_tex = load("res://assets/kenney-furniture/isometric/bookcaseOpen_SE.png")
	var bookcase = TextureRect.new()
	bookcase.texture = bookcase_tex
	bookcase.position = _cart_to_iso(GRID_COLS - 1, 0, origin) + Vector2(60, -100)
	bookcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bookcase)

	var plant_tex = load("res://assets/kenney-furniture/isometric/pottedPlant_SE.png")
	var plant = TextureRect.new()
	plant.texture = plant_tex
	plant.position = _cart_to_iso(GRID_COLS - 2, 0, origin) + Vector2(80, -60)
	plant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plant)

	# === WALL OBJECTS ===
	_build_wall_objects()

	# === DESKS ===
	_build_desks()


func _build_wall_objects():
	var vp = _get_vp()
	var origin = _get_grid_origin(vp)
	# Wall object vertical offset to sit on the wall above the floor
	var wall_obj_y_offset = -90.0

	# 1) "Back to Desk" door (col 0) — Kenney doorway sprite
	var door_iso = _cart_to_iso(0, 0, origin)
	var door_tex = load("res://assets/kenney-furniture/isometric/wallDoorway_SE.png")
	var door_sprite = TextureRect.new()
	door_sprite.texture = door_tex
	door_sprite.position = door_iso + Vector2(50, -110)
	door_sprite.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	door_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	door_sprite.z_index = 1
	add_child(door_sprite)
	_back_door = door_sprite

	# Door label
	var door_label = Label.new()
	door_label.text = "Back to Desk"
	door_label.add_theme_font_size_override("font_size", 11)
	door_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
	door_label.position = door_iso + Vector2(45, -120)
	door_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door_label.z_index = 2
	add_child(door_label)
	_back_door_label = door_label

	door_sprite.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			back_to_desk_requested.emit()
	)

	# 2) "Contracts" (col 2)
	var contracts_iso = _cart_to_iso(2, 0, origin)
	var board_ctrl = _create_interactive_object(
		"Contracts", contracts_iso + Vector2(55, wall_obj_y_offset), Vector2(100, 46),
		WHITEBOARD_COLOR, OBJECT_LABEL_COLOR
	)
	board_ctrl.z_index = 1
	board_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			contract_board_clicked.emit()
	)

	# 3) "Hiring" (col 3)
	var hiring_iso = _cart_to_iso(3, 0, origin)
	var hire_ctrl = _create_interactive_object(
		"Hiring", hiring_iso + Vector2(55, wall_obj_y_offset), Vector2(100, 46),
		SCREEN_COLOR, Color(0.4, 0.7, 0.9)
	)
	hire_ctrl.z_index = 1
	hire_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hiring_board_clicked.emit()
	)

	# 4) "Staff" (col 5)
	var staff_iso = _cart_to_iso(5, 0, origin)
	var staff_ctrl = _create_interactive_object(
		"Staff", staff_iso + Vector2(55, wall_obj_y_offset), Vector2(80, 46),
		CLIPBOARD_COLOR, Color(0.9, 0.85, 0.75)
	)
	staff_ctrl.z_index = 1
	staff_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			staff_roster_clicked.emit()
	)

	# 5) "Inbox" (col 6)
	var inbox_iso = _cart_to_iso(6, 0, origin)
	var inbox_ctrl = _create_interactive_object(
		"Inbox", inbox_iso + Vector2(55, wall_obj_y_offset), Vector2(80, 46),
		INBOX_COLOR, Color(0.7, 0.8, 0.95)
	)
	inbox_ctrl.z_index = 1
	inbox_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			inbox_clicked.emit()
	)

	# 6) Locked "Teams" (col 7)
	var teams_iso = _cart_to_iso(7, 0, origin)
	var locked_ctrl = _create_interactive_object(
		"Teams", teams_iso + Vector2(55, wall_obj_y_offset), Vector2(90, 46),
		LOCKED_DOOR_COLOR, Color(0.5, 0.48, 0.45)
	)
	locked_ctrl.z_index = 1

	# Lock icon label
	var lock_label = Label.new()
	lock_label.text = "Locked"
	lock_label.add_theme_font_size_override("font_size", 9)
	lock_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
	lock_label.position = Vector2(locked_ctrl.position.x + 22, locked_ctrl.position.y + 32)
	lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_label.z_index = 2
	add_child(lock_label)


func _build_desks():
	# Clear previous desk visuals
	for node in _desk_node_visuals:
		if is_instance_valid(node):
			node.queue_free()
	_desk_node_visuals.clear()
	_desk_nodes.clear()

	var desk_count: int = GameState.desk_capacity
	var vp = _get_vp()
	var origin = _get_grid_origin(vp)

	for i in desk_count:
		var col = i % GRID_COLS
		var row = 1 + i / GRID_COLS  # Row 0 is the wall, desks start at row 1
		var iso_pos = _cart_to_iso(col, row, origin)

		# Chair (behind desk, z_index -1)
		var chair = TextureRect.new()
		chair.texture = CHAIR_TEX
		chair.position = iso_pos + Vector2(75, -10)
		chair.z_index = -1
		chair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chair)
		_desk_node_visuals.append(chair)

		# Desk surface
		var desk = TextureRect.new()
		desk.texture = DESK_TEX
		desk.position = iso_pos + Vector2(45, 20)
		desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(desk)
		_desk_node_visuals.append(desk)

		# Monitor on desk
		var monitor = TextureRect.new()
		monitor.texture = MONITOR_TEX
		monitor.position = iso_pos + Vector2(70, -10)
		monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(monitor)
		_desk_node_visuals.append(monitor)

		# Desk number label
		var num_label = Label.new()
		num_label.text = str(i + 1)
		num_label.add_theme_font_size_override("font_size", 10)
		num_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.38))
		num_label.position = iso_pos + Vector2(90, 50)
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
		_buy_desk_btn.custom_minimum_size = DESK_SIZE
		_buy_desk_btn.position = btn_iso + Vector2(45, 20)
		_buy_desk_btn.size = DESK_SIZE
		_update_buy_desk_label()
		_buy_desk_btn.pressed.connect(_on_buy_desk)
		add_child(_buy_desk_btn)


func _get_desk_cost() -> float:
	return DESK_BASE_COST * GameState.desk_capacity


func _update_buy_desk_label():
	if _buy_desk_btn:
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
	container.position = desk_pos + Vector2(80, -40)
	container.size = Vector2(30, 60)
	add_child(container)

	# Head (rounded to circle)
	var head = PanelContainer.new()
	var head_style = StyleBoxFlat.new()
	head_style.bg_color = _get_consultant_color(consultant)
	head_style.set_corner_radius_all(15)
	head.add_theme_stylebox_override("panel", head_style)
	head.position = Vector2(0, 0)
	head.custom_minimum_size = Vector2(30, 30)
	head.size = Vector2(30, 30)
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
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	name_label.position = Vector2(-5, 32)
	container.add_child(name_label)

	# State label
	var state_label = Label.new()
	if consultant.training_skill != "":
		state_label.text = "Training"
		state_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
	else:
		state_label.text = "Idle"
		state_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	state_label.add_theme_font_size_override("font_size", 9)
	state_label.position = Vector2(-5, 44)
	container.add_child(state_label)

	_consultant_sprites.append({"node": container, "consultant": consultant})


func _create_away_label(consultant: ConsultantData, desk_pos: Vector2):
	var container = Control.new()
	container.position = desk_pos + Vector2(50, 10)
	container.size = Vector2(DESK_SIZE.x, 20)
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


func _create_interactive_object(label_text: String, pos: Vector2, obj_size: Vector2, bg_color: Color, text_color: Color) -> ColorRect:
	var bg = ColorRect.new()
	bg.color = bg_color
	bg.position = pos
	bg.size = obj_size
	bg.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(bg)

	# Hover feedback — lighten on enter, restore on exit
	var base_color = bg_color
	bg.mouse_entered.connect(func(): bg.color = base_color.lightened(0.15))
	bg.mouse_exited.connect(func(): bg.color = base_color)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", text_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Center text in the object
	label.position = pos + Vector2(
		(obj_size.x - label_text.length() * 7.0) * 0.5,
		(obj_size.y - 14) * 0.5
	)
	add_child(label)

	return bg
