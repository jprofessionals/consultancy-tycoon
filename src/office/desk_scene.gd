extends Control

signal monitor_clicked
signal phone_clicked
signal books_clicked
signal email_clicked
signal laptop_clicked
signal door_clicked

const REF_W = 1152.0
const REF_H = 648.0

var email_badge: Button
var phone_btn: Button
var phone_glow: ColorRect
var _is_zoomed: bool = false

# Monitor area for zoom calculation (computed dynamically in _build_ui)
var monitor_rect: Rect2

func _get_vp() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(REF_W, REF_H)

func _ready():
	_build_ui()

func _build_ui():
	var vp = _get_vp()

	# Compute monitor_rect dynamically: centered horizontally, 400x300, top at ~12.3% of viewport height
	var mon_w = 400.0
	var mon_h = 300.0
	var mon_x = (vp.x - mon_w) / 2.0
	var mon_y = vp.y * (80.0 / REF_H)
	monitor_rect = Rect2(mon_x, mon_y, mon_w, mon_h)

	# Desk surface Y position (~54% of viewport height)
	var desk_y = vp.y * (350.0 / REF_H)

	# Wall background (upper portion)
	var wall = ColorRect.new()
	wall.color = Color(0.25, 0.27, 0.30)
	wall.position = Vector2(0, 0)
	wall.size = Vector2(vp.x, vp.y * (380.0 / REF_H))
	add_child(wall)

	# === PLANT (on wall, replaces shelf + pot + leaves) ===
	var plant_tex = TextureRect.new()
	plant_tex.texture = preload("res://assets/kenney-furniture/side/pottedPlant.png")
	plant_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var plant_scale = 1.6
	var plant_w = 28.0 * plant_scale
	var plant_h = 85.0 * plant_scale
	plant_tex.custom_minimum_size = Vector2(plant_w, plant_h)
	plant_tex.size = Vector2(plant_w, plant_h)
	plant_tex.position = Vector2(vp.x * (100.0 / REF_W), vp.y * (40.0 / REF_H))
	plant_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plant_tex)

	# Desk surface (lower portion)
	var desk = ColorRect.new()
	desk.color = Color(0.42, 0.30, 0.20)
	desk.position = Vector2(0, desk_y)
	desk.size = Vector2(vp.x, vp.y - desk_y)
	add_child(desk)

	# Desk edge highlight
	var desk_edge = ColorRect.new()
	desk_edge.color = Color(0.48, 0.35, 0.24)
	desk_edge.position = Vector2(0, desk_y)
	desk_edge.size = Vector2(vp.x, 6)
	add_child(desk_edge)

	# === DESK FURNITURE SPRITE (centered under monitor, on top of desk surface) ===
	var desk_sprite = TextureRect.new()
	desk_sprite.texture = preload("res://assets/kenney-furniture/side/desk.png")
	desk_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var desk_spr_scale = 3.5
	var desk_spr_w = 116.0 * desk_spr_scale
	var desk_spr_h = 51.0 * desk_spr_scale
	desk_sprite.custom_minimum_size = Vector2(desk_spr_w, desk_spr_h)
	desk_sprite.size = Vector2(desk_spr_w, desk_spr_h)
	desk_sprite.position = Vector2((vp.x - desk_spr_w) / 2.0, desk_y - desk_spr_h * 0.15)
	desk_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(desk_sprite)

	# === DESK CHAIR (decorative, behind desk) ===
	var chair_tex = TextureRect.new()
	chair_tex.texture = preload("res://assets/kenney-furniture/side/chairDesk.png")
	chair_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var chair_scale = 2.2
	var chair_w = 60.0 * chair_scale
	var chair_h = 97.0 * chair_scale
	chair_tex.custom_minimum_size = Vector2(chair_w, chair_h)
	chair_tex.size = Vector2(chair_w, chair_h)
	chair_tex.position = Vector2((vp.x - chair_w) / 2.0, desk_y - chair_h * 0.35)
	chair_tex.z_index = -1
	chair_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chair_tex)

	# === MONITOR (center, sprite replaces bezel + screen ColorRects) ===
	var monitor_tex = TextureRect.new()
	monitor_tex.texture = preload("res://assets/kenney-furniture/side/computerScreen.png")
	monitor_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Scale the 71x71 sprite to fill the monitor_rect area (use height as guide)
	var mon_sprite_scale = mon_h / 71.0
	var mon_sprite_w = 71.0 * mon_sprite_scale
	var mon_sprite_h = 71.0 * mon_sprite_scale
	monitor_tex.custom_minimum_size = Vector2(mon_sprite_w, mon_sprite_h)
	monitor_tex.size = Vector2(mon_sprite_w, mon_sprite_h)
	# Center the sprite over the monitor_rect area
	monitor_tex.position = Vector2(
		mon_x + (mon_w - mon_sprite_w) / 2.0,
		mon_y + (mon_h - mon_sprite_h) / 2.0
	)
	monitor_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(monitor_tex)

	# Screen content - idle desktop text (kept as-is)
	var screen_text = Label.new()
	screen_text.text = "Click to sit down..."
	screen_text.add_theme_font_size_override("font_size", 16)
	screen_text.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	screen_text.position = monitor_rect.position + Vector2(120, 130)
	add_child(screen_text)

	# Monitor click button (transparent, over screen)
	var monitor_btn = Button.new()
	monitor_btn.flat = true
	monitor_btn.position = monitor_rect.position
	monitor_btn.size = monitor_rect.size
	monitor_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	monitor_btn.pressed.connect(func(): monitor_clicked.emit())
	add_child(monitor_btn)

	# Email badge (top-right of monitor)
	email_badge = Button.new()
	email_badge.text = "0"
	email_badge.position = Vector2(monitor_rect.position.x + monitor_rect.size.x - 40, monitor_rect.position.y + 8)
	email_badge.size = Vector2(32, 28)
	email_badge.visible = false
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.85, 0.2, 0.2)
	badge_style.set_corner_radius_all(6)
	badge_style.set_content_margin_all(2)
	email_badge.add_theme_stylebox_override("normal", badge_style)
	email_badge.add_theme_stylebox_override("hover", badge_style)
	email_badge.add_theme_font_size_override("font_size", 13)
	email_badge.add_theme_color_override("font_color", Color.WHITE)
	email_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	email_badge.pressed.connect(func(): email_clicked.emit())
	add_child(email_badge)

	# === PHONE (right side of desk) — stays as ColorRects ===
	var phone_x = vp.x * (870.0 / REF_W)
	var phone_y = vp.y * (380.0 / REF_H)

	# Phone body
	var phone_body = ColorRect.new()
	phone_body.color = Color(0.18, 0.18, 0.20)
	phone_body.position = Vector2(phone_x, phone_y)
	phone_body.size = Vector2(100, 160)
	add_child(phone_body)

	# Phone screen
	var phone_screen = ColorRect.new()
	phone_screen.color = Color(0.12, 0.15, 0.20)
	phone_screen.position = Vector2(phone_x + 8, phone_y + 15)
	phone_screen.size = Vector2(84, 110)
	add_child(phone_screen)

	# Phone glow indicator (visible when contracts available)
	phone_glow = ColorRect.new()
	phone_glow.color = Color(0.3, 0.8, 0.4, 0.6)
	phone_glow.position = Vector2(phone_x + 8, phone_y + 130)
	phone_glow.size = Vector2(84, 6)
	phone_glow.visible = false
	add_child(phone_glow)

	# Phone label
	var phone_label = Label.new()
	phone_label.text = "Contracts"
	phone_label.add_theme_font_size_override("font_size", 12)
	phone_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	phone_label.position = Vector2(phone_x + 18, phone_y + 50)
	add_child(phone_label)

	# Phone click button
	phone_btn = Button.new()
	phone_btn.flat = true
	phone_btn.position = Vector2(phone_x, phone_y)
	phone_btn.size = Vector2(100, 160)
	phone_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	phone_btn.pressed.connect(func(): phone_clicked.emit())
	add_child(phone_btn)

	# === BOOKCASE (left side of desk, replaces book stack) ===
	var books_x = vp.x * (150.0 / REF_W)
	var books_base_y = vp.y * (420.0 / REF_H)

	var bookcase_tex = TextureRect.new()
	bookcase_tex.texture = preload("res://assets/kenney-furniture/side/bookcaseOpen.png")
	bookcase_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var bookcase_scale = 1.5
	var bookcase_w = 67.0 * bookcase_scale
	var bookcase_h = 140.0 * bookcase_scale
	bookcase_tex.custom_minimum_size = Vector2(bookcase_w, bookcase_h)
	bookcase_tex.size = Vector2(bookcase_w, bookcase_h)
	# Position so the bottom of the bookcase sits on the desk area
	bookcase_tex.position = Vector2(books_x - 10, books_base_y - bookcase_h + 40)
	bookcase_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bookcase_tex)

	# Books label (kept)
	var books_label = Label.new()
	books_label.text = "Skills"
	books_label.add_theme_font_size_override("font_size", 12)
	books_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	books_label.position = Vector2(books_x + 35, books_base_y + 20)
	add_child(books_label)

	# Books click button (kept)
	var books_btn = Button.new()
	books_btn.flat = true
	books_btn.position = Vector2(books_x - 10, desk_y + 20)
	books_btn.size = Vector2(140, 90)
	books_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	books_btn.pressed.connect(func(): books_clicked.emit())
	add_child(books_btn)

	# === COFFEE MACHINE (decorative, left of monitor, replaces mug) ===
	var mug_x = vp.x * (320.0 / REF_W)
	var mug_y = vp.y * (390.0 / REF_H)

	var coffee_tex = TextureRect.new()
	coffee_tex.texture = preload("res://assets/kenney-furniture/side/kitchenCoffeeMachine.png")
	coffee_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var coffee_scale = 1.8
	var coffee_w = 35.0 * coffee_scale
	var coffee_h = 43.0 * coffee_scale
	coffee_tex.custom_minimum_size = Vector2(coffee_w, coffee_h)
	coffee_tex.size = Vector2(coffee_w, coffee_h)
	coffee_tex.position = Vector2(mug_x - 5, mug_y - coffee_h + 40)
	coffee_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coffee_tex)

	# === LAPTOP (right of monitor on desk — AI Tools) ===
	var laptop_x = vp.x * (660.0 / REF_W)
	var laptop_base_y = vp.y * (400.0 / REF_H)

	var laptop_tex = TextureRect.new()
	laptop_tex.texture = preload("res://assets/kenney-furniture/side/laptop.png")
	laptop_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var laptop_scale = 2.0
	var laptop_w = 50.0 * laptop_scale
	var laptop_h = 52.0 * laptop_scale
	laptop_tex.custom_minimum_size = Vector2(laptop_w, laptop_h)
	laptop_tex.size = Vector2(laptop_w, laptop_h)
	laptop_tex.position = Vector2(laptop_x, laptop_base_y - laptop_h + 55)
	laptop_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(laptop_tex)

	# Laptop label (kept)
	var laptop_label = Label.new()
	laptop_label.text = "AI Tools"
	laptop_label.add_theme_font_size_override("font_size", 11)
	laptop_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	laptop_label.position = Vector2(laptop_x + 20, laptop_base_y - 32)
	add_child(laptop_label)

	# Laptop click button (kept)
	var laptop_btn = Button.new()
	laptop_btn.flat = true
	laptop_btn.position = Vector2(laptop_x, laptop_base_y - 48)
	laptop_btn.size = Vector2(100, 110)
	laptop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	laptop_btn.pressed.connect(func(): laptop_clicked.emit())
	add_child(laptop_btn)

	# === DOOR (on the wall — stays as ColorRects) ===
	var door_x = vp.x * (980.0 / REF_W)
	var door_y = vp.y * (100.0 / REF_H)

	# Door frame
	var door_frame = ColorRect.new()
	door_frame.color = Color(0.35, 0.25, 0.18)
	door_frame.position = Vector2(door_x, door_y)
	door_frame.size = Vector2(110, 254)
	add_child(door_frame)

	# Door body
	var door_body = ColorRect.new()
	door_body.color = Color(0.45, 0.33, 0.22)
	door_body.position = Vector2(door_x + 5, door_y + 5)
	door_body.size = Vector2(100, 244)
	add_child(door_body)

	# Door handle
	var door_handle = ColorRect.new()
	door_handle.color = Color(0.75, 0.65, 0.30)
	door_handle.position = Vector2(door_x + 90, door_y + 130)
	door_handle.size = Vector2(8, 20)
	add_child(door_handle)

	# Door label
	var door_label = Label.new()
	door_label.text = "Team"
	door_label.add_theme_font_size_override("font_size", 13)
	door_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	door_label.position = Vector2(door_x + 35, door_y + 100)
	add_child(door_label)

	# Door click button
	var door_btn = Button.new()
	door_btn.flat = true
	door_btn.position = Vector2(door_x, door_y)
	door_btn.size = Vector2(110, 254)
	door_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	door_btn.pressed.connect(func(): door_clicked.emit())
	add_child(door_btn)

func set_email_badge_count(n: int):
	if n <= 0:
		email_badge.visible = false
	else:
		email_badge.visible = true
		email_badge.text = str(n)

func set_phone_glowing(on: bool):
	phone_glow.visible = on

func zoom_to_monitor() -> Tween:
	_is_zoomed = true
	# Calculate zoom so monitor fills viewport
	var viewport_size = _get_vp()
	var monitor_center = monitor_rect.position + monitor_rect.size / 2.0
	var target_scale = 2.5
	pivot_offset = monitor_center
	var target_pos = position + (viewport_size / 2.0 - monitor_center) * target_scale + monitor_center - monitor_center * target_scale

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), 0.3)
	tween.parallel().tween_property(self, "position", target_pos, 0.3)
	return tween

func zoom_to_desk() -> Tween:
	_is_zoomed = false
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.parallel().tween_property(self, "position", Vector2.ZERO, 0.3)
	return tween
