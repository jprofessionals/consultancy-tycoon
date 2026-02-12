extends Control

signal back_to_desk_requested
signal contract_board_clicked
signal hiring_board_clicked
signal staff_roster_clicked
signal inbox_clicked
signal consultant_clicked(consultant: ConsultantData)

# Layout constants
const DESK_SIZE = Vector2(80, 60)
const DESK_SPACING = Vector2(120, 100)
const DESK_COLUMNS = 4
const WALL_HEIGHT = 60.0
const DESK_AREA_TOP = 100.0

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
]

var _desk_nodes: Array = []
var _consultant_sprites: Array = []
var _chat_timer: float = 0.0
const CHAT_INTERVAL = 4.0


func _ready():
	_build_office()


func _build_office():
	# Floor background
	var floor_bg = ColorRect.new()
	floor_bg.color = FLOOR_COLOR
	floor_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floor_bg)

	# Wall strip at top
	var wall = ColorRect.new()
	wall.color = WALL_COLOR
	wall.position = Vector2(0, 0)
	wall.size = Vector2(1152, WALL_HEIGHT)
	add_child(wall)

	# Wall base molding
	var molding = ColorRect.new()
	molding.color = Color(0.3, 0.32, 0.35)
	molding.position = Vector2(0, WALL_HEIGHT - 4)
	molding.size = Vector2(1152, 4)
	add_child(molding)

	# === WALL OBJECTS ===
	_build_wall_objects()

	# === DESKS ===
	_build_desks()


func _build_wall_objects():
	var wall_y = 5.0
	var obj_height = WALL_HEIGHT - 14.0
	var spacing = 1152.0 / 6.0

	# 1) "Back to Desk" door (left side)
	var door_ctrl = _create_interactive_object(
		"Back to Desk", Vector2(spacing * 0.3, wall_y), Vector2(90, obj_height),
		DOOR_COLOR, Color(0.85, 0.78, 0.65)
	)
	door_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			back_to_desk_requested.emit()
	)

	# Door frame around it
	var frame = ColorRect.new()
	frame.color = DOOR_FRAME_COLOR
	frame.position = door_ctrl.position - Vector2(4, 4)
	frame.size = door_ctrl.size + Vector2(8, 8)
	frame.z_index = -1
	add_child(frame)

	# Door handle
	var handle = ColorRect.new()
	handle.color = Color(0.75, 0.65, 0.30)
	handle.position = Vector2(door_ctrl.position.x + 72, door_ctrl.position.y + obj_height * 0.5 - 4)
	handle.size = Vector2(6, 12)
	add_child(handle)

	# 2) "Contracts" whiteboard (center-left)
	var board_ctrl = _create_interactive_object(
		"Contracts", Vector2(spacing * 1.2, wall_y), Vector2(110, obj_height),
		WHITEBOARD_COLOR, OBJECT_LABEL_COLOR
	)
	board_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			contract_board_clicked.emit()
	)

	# Whiteboard border
	var board_border = ColorRect.new()
	board_border.color = Color(0.4, 0.38, 0.36)
	board_border.position = board_ctrl.position - Vector2(3, 3)
	board_border.size = board_ctrl.size + Vector2(6, 6)
	board_border.z_index = -1
	add_child(board_border)

	# 3) "Hiring" screen (center)
	var hire_ctrl = _create_interactive_object(
		"Hiring", Vector2(spacing * 2.2, wall_y), Vector2(100, obj_height),
		SCREEN_COLOR, Color(0.4, 0.7, 0.9)
	)
	hire_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hiring_board_clicked.emit()
	)

	# Screen bezel
	var screen_bezel = ColorRect.new()
	screen_bezel.color = Color(0.18, 0.18, 0.20)
	screen_bezel.position = hire_ctrl.position - Vector2(3, 3)
	screen_bezel.size = hire_ctrl.size + Vector2(6, 6)
	screen_bezel.z_index = -1
	add_child(screen_bezel)

	# 4) "Staff" clipboard (center-right)
	var staff_ctrl = _create_interactive_object(
		"Staff", Vector2(spacing * 3.2, wall_y), Vector2(80, obj_height),
		CLIPBOARD_COLOR, Color(0.9, 0.85, 0.75)
	)
	staff_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			staff_roster_clicked.emit()
	)

	# Clipboard clip
	var clip = ColorRect.new()
	clip.color = Color(0.6, 0.55, 0.45)
	clip.position = Vector2(staff_ctrl.position.x + 25, staff_ctrl.position.y - 5)
	clip.size = Vector2(30, 10)
	add_child(clip)

	# 5) "Inbox" (right)
	var inbox_ctrl = _create_interactive_object(
		"Inbox", Vector2(spacing * 4.1, wall_y), Vector2(80, obj_height),
		INBOX_COLOR, Color(0.7, 0.8, 0.95)
	)
	inbox_ctrl.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			inbox_clicked.emit()
	)

	# 6) Locked "Teams" door (far right)
	var locked_ctrl = _create_interactive_object(
		"Teams", Vector2(spacing * 5.0, wall_y), Vector2(90, obj_height),
		LOCKED_DOOR_COLOR, Color(0.5, 0.48, 0.45)
	)

	# Lock icon label
	var lock_label = Label.new()
	lock_label.text = "Locked"
	lock_label.add_theme_font_size_override("font_size", 9)
	lock_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
	lock_label.position = Vector2(locked_ctrl.position.x + 22, locked_ctrl.position.y + obj_height - 14)
	add_child(lock_label)

	# Locked door frame
	var locked_frame = ColorRect.new()
	locked_frame.color = Color(0.28, 0.22, 0.18)
	locked_frame.position = locked_ctrl.position - Vector2(4, 4)
	locked_frame.size = locked_ctrl.size + Vector2(8, 8)
	locked_frame.z_index = -1
	add_child(locked_frame)


func _build_desks():
	_desk_nodes.clear()
	var desk_count: int = GameState.desk_capacity
	var grid_start = Vector2(80, DESK_AREA_TOP)

	for i in desk_count:
		var col = i % DESK_COLUMNS
		var row = i / DESK_COLUMNS
		var pos = grid_start + Vector2(col * DESK_SPACING.x, row * DESK_SPACING.y)

		# Desk shadow
		var shadow = ColorRect.new()
		shadow.color = Color(0.15, 0.16, 0.18, 0.5)
		shadow.position = pos + Vector2(4, 4)
		shadow.size = DESK_SIZE
		add_child(shadow)

		# Desk surface
		var desk = ColorRect.new()
		desk.color = DESK_COLOR
		desk.position = pos
		desk.size = DESK_SIZE
		add_child(desk)

		# Desk edge highlight
		var edge = ColorRect.new()
		edge.color = Color(0.4, 0.35, 0.28)
		edge.position = pos
		edge.size = Vector2(DESK_SIZE.x, 3)
		add_child(edge)

		# Desk number label
		var num_label = Label.new()
		num_label.text = str(i + 1)
		num_label.add_theme_font_size_override("font_size", 10)
		num_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.38))
		num_label.position = pos + Vector2(3, DESK_SIZE.y - 16)
		add_child(num_label)

		_desk_nodes.append({"rect": desk, "position": pos, "index": i})


func refresh():
	# Clear existing consultant sprites
	for sprite_data in _consultant_sprites:
		if is_instance_valid(sprite_data["node"]):
			sprite_data["node"].queue_free()
	_consultant_sprites.clear()

	var in_office = GameState.get_consultants_by_location(ConsultantData.Location.IN_OFFICE)
	var away_consultants = _get_away_consultants()

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


func _create_consultant_sprite(consultant: ConsultantData, desk_pos: Vector2, _desk_index: int):
	var container = Control.new()
	container.position = desk_pos + Vector2(DESK_SIZE.x * 0.5 - 15, -40)
	container.size = Vector2(30, 60)
	add_child(container)

	# Head (colored circle approximation as ColorRect)
	var head = ColorRect.new()
	head.color = _get_consultant_color(consultant)
	head.position = Vector2(0, 0)
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
	container.position = desk_pos + Vector2(5, -20)
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
		if c.location != ConsultantData.Location.IN_OFFICE:
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

	# Create chat bubble
	var bubble = Label.new()
	bubble.text = message
	bubble.add_theme_font_size_override("font_size", 10)
	bubble.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	bubble.position = Vector2(35, -25)

	# Bubble background using a panel-like approach via a ColorRect behind the label
	var bubble_bg = ColorRect.new()
	bubble_bg.color = Color(0.2, 0.22, 0.28, 0.9)
	bubble_bg.position = Vector2(30, -30)
	bubble_bg.size = Vector2(message.length() * 6.5 + 16, 22)
	bubble_bg.z_index = 10

	bubble.z_index = 11

	sprite_node.add_child(bubble_bg)
	sprite_node.add_child(bubble)

	# Tween: wait 2.5s, fade out over 0.5s, then remove
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(bubble_bg, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(bubble):
			bubble.queue_free()
		if is_instance_valid(bubble_bg):
			bubble_bg.queue_free()
	)


func _create_interactive_object(label_text: String, pos: Vector2, obj_size: Vector2, bg_color: Color, text_color: Color) -> ColorRect:
	var bg = ColorRect.new()
	bg.color = bg_color
	bg.position = pos
	bg.size = obj_size
	bg.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(bg)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", text_color)
	# Center text in the object
	label.position = pos + Vector2(
		(obj_size.x - label_text.length() * 7.0) * 0.5,
		(obj_size.y - 14) * 0.5
	)
	add_child(label)

	return bg
