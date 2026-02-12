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

	# Wall shelf (decorative)
	var shelf = ColorRect.new()
	shelf.color = Color(0.45, 0.32, 0.22)
	shelf.position = Vector2(vp.x * (50.0 / REF_W), vp.y * (120.0 / REF_H))
	shelf.size = Vector2(180, 12)
	add_child(shelf)

	# Plant on shelf
	var pot = ColorRect.new()
	pot.color = Color(0.55, 0.35, 0.20)
	pot.position = Vector2(vp.x * (110.0 / REF_W), vp.y * (90.0 / REF_H))
	pot.size = Vector2(30, 30)
	add_child(pot)
	var leaves = ColorRect.new()
	leaves.color = Color(0.25, 0.55, 0.30)
	leaves.position = Vector2(vp.x * (100.0 / REF_W), vp.y * (60.0 / REF_H))
	leaves.size = Vector2(50, 35)
	add_child(leaves)

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

	# === MONITOR (center) ===
	# Monitor stand
	var stand_base = ColorRect.new()
	stand_base.color = Color(0.20, 0.20, 0.22)
	stand_base.position = Vector2(mon_x + mon_w * 0.315, desk_y + 20)
	stand_base.size = Vector2(100, 12)
	add_child(stand_base)
	var stand_neck = ColorRect.new()
	stand_neck.color = Color(0.22, 0.22, 0.24)
	stand_neck.position = Vector2(mon_x + mon_w * 0.465, desk_y - 10)
	stand_neck.size = Vector2(30, 35)
	add_child(stand_neck)

	# Monitor bezel (dark frame)
	var bezel = ColorRect.new()
	bezel.color = Color(0.12, 0.12, 0.14)
	bezel.position = Vector2(monitor_rect.position.x - 12, monitor_rect.position.y - 12)
	bezel.size = Vector2(monitor_rect.size.x + 24, monitor_rect.size.y + 24)
	add_child(bezel)

	# Monitor screen (lighter)
	var screen = ColorRect.new()
	screen.color = Color(0.15, 0.18, 0.22)
	screen.position = monitor_rect.position
	screen.size = monitor_rect.size
	add_child(screen)

	# Screen content - idle desktop text
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

	# === PHONE (right side of desk) ===
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

	# === BOOKS (left side of desk) ===
	var books_x = vp.x * (150.0 / REF_W)
	var books_base_y = vp.y * (420.0 / REF_H)

	# Book stack (3 books)
	var book_colors = [Color(0.2, 0.3, 0.6), Color(0.6, 0.25, 0.2), Color(0.2, 0.5, 0.3)]
	for i in 3:
		var book = ColorRect.new()
		book.color = book_colors[i]
		book.position = Vector2(books_x, books_base_y - i * 18)
		book.size = Vector2(120, 16)
		add_child(book)

	# Books label
	var books_label = Label.new()
	books_label.text = "Skills"
	books_label.add_theme_font_size_override("font_size", 12)
	books_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	books_label.position = Vector2(books_x + 35, books_base_y + 20)
	add_child(books_label)

	# Books click button
	var books_btn = Button.new()
	books_btn.flat = true
	books_btn.position = Vector2(books_x - 10, desk_y + 20)
	books_btn.size = Vector2(140, 90)
	books_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	books_btn.pressed.connect(func(): books_clicked.emit())
	add_child(books_btn)

	# === COFFEE MUG (decorative, left of monitor) ===
	var mug_x = vp.x * (320.0 / REF_W)
	var mug_y = vp.y * (390.0 / REF_H)

	var mug_body = ColorRect.new()
	mug_body.color = Color(0.85, 0.85, 0.82)
	mug_body.position = Vector2(mug_x, mug_y)
	mug_body.size = Vector2(30, 35)
	add_child(mug_body)

	# Mug handle
	var mug_handle = ColorRect.new()
	mug_handle.color = Color(0.85, 0.85, 0.82)
	mug_handle.position = Vector2(mug_x + 30, mug_y + 8)
	mug_handle.size = Vector2(10, 18)
	add_child(mug_handle)

	# Coffee surface
	var coffee = ColorRect.new()
	coffee.color = Color(0.35, 0.22, 0.12)
	coffee.position = Vector2(mug_x + 2, mug_y + 2)
	coffee.size = Vector2(26, 6)
	add_child(coffee)

	# === LAPTOP (between books and coffee mug — AI Tools) ===
	var laptop_x = vp.x * (660.0 / REF_W)
	var laptop_base_y = vp.y * (400.0 / REF_H)

	# Laptop base
	var laptop_base = ColorRect.new()
	laptop_base.color = Color(0.28, 0.28, 0.30)
	laptop_base.position = Vector2(laptop_x, laptop_base_y)
	laptop_base.size = Vector2(100, 60)
	add_child(laptop_base)

	# Laptop screen (angled up)
	var laptop_screen = ColorRect.new()
	laptop_screen.color = Color(0.10, 0.14, 0.22)
	laptop_screen.position = Vector2(laptop_x + 5, laptop_base_y - 45)
	laptop_screen.size = Vector2(90, 48)
	add_child(laptop_screen)

	# Laptop screen bezel
	var laptop_bezel = ColorRect.new()
	laptop_bezel.color = Color(0.22, 0.22, 0.24)
	laptop_bezel.position = Vector2(laptop_x + 2, laptop_base_y - 48)
	laptop_bezel.size = Vector2(96, 52)
	laptop_bezel.z_index = -1
	add_child(laptop_bezel)

	# Laptop label
	var laptop_label = Label.new()
	laptop_label.text = "AI Tools"
	laptop_label.add_theme_font_size_override("font_size", 11)
	laptop_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	laptop_label.position = Vector2(laptop_x + 20, laptop_base_y - 32)
	add_child(laptop_label)

	# Laptop click button
	var laptop_btn = Button.new()
	laptop_btn.flat = true
	laptop_btn.position = Vector2(laptop_x, laptop_base_y - 48)
	laptop_btn.size = Vector2(100, 110)
	laptop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	laptop_btn.pressed.connect(func(): laptop_clicked.emit())
	add_child(laptop_btn)

	# === DOOR (on the wall — Hiring / Office) ===
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
