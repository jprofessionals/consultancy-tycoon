# Screen Scaling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the game scale responsively with the browser window using Godot's stretch system, so the IDE fills the whole screen and scenes adapt to any aspect ratio.

**Architecture:** Set `canvas_items` stretch mode with `expand` aspect. The base viewport stays 1152x648 as the design resolution. When the browser window is larger, the viewport expands — elements repositioned relative to viewport size fill the extra space. All hardcoded 1152/648 pixel references become dynamic.

**Tech Stack:** Godot 4.6, GDScript, GL Compatibility renderer, Web export

---

### Task 1: Configure Godot stretch settings

**Files:**
- Modify: `project.godot:18-22`

**Step 1: Add stretch configuration to project.godot**

Add these lines under the existing `[display]` section:

```gdscript
# In project.godot, replace the [display] section:
[display]

window/size/viewport_width=1152
window/size/viewport_height=648
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

This makes Godot scale all Control nodes with the window and expand the viewport when the window is larger than 16:9.

**Step 2: Run the game to verify stretch mode works**

Run: `godot --path /home/lars/Prosjekter/consultancy-tycoon`
Expected: Game launches. Resizing the window scales content. Extra space appears at edges.

**Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: enable canvas_items stretch mode with expand aspect"
```

---

### Task 2: Make desk scene viewport-relative

**Files:**
- Modify: `src/office/desk_scene.gd` (full rewrite of `_build_ui()` and `zoom_to_monitor()`)

The desk scene currently uses ~30 hardcoded pixel positions assuming 1152x648. With `expand` aspect, the viewport can be wider or taller. All positions must derive from the actual viewport size.

**Step 1: Add viewport-relative layout helper**

At the top of `desk_scene.gd`, add a helper that returns the current viewport size. All positions will be calculated as ratios of this.

```gdscript
# Design-time reference size (all ratios calculated from this)
const REF_W = 1152.0
const REF_H = 648.0

func _get_vp() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(REF_W, REF_H)
```

**Step 2: Rewrite `_build_ui()` to use viewport-relative positions**

Replace all hardcoded positions with proportional calculations. The pattern is:
- `x_pos = vp.x * (original_x / 1152.0)`
- `y_pos = vp.y * (original_y / 648.0)`
- Widths that span the full viewport use `vp.x` instead of `1152`

Key position mappings (original → ratio):
- Wall: `(0, 0)` size `(1152, 380)` → `(0, 0)` size `(vp.x, vp.y * 0.586)`
- Desk surface: `(0, 350)` size `(1152, 298)` → `(0, vp.y * 0.54)` size `(vp.x, vp.y * 0.46)`
- Monitor bezel: `(364, 68)` size `(424, 324)` → centered horizontally, `vp.y * 0.105` from top
- Monitor screen: `(376, 80)` size `(400, 300)` → centered, inside bezel
- Phone: `(870, 380)` → `(vp.x * 0.755, vp.y * 0.586)`
- Books: `(150, 384)` → `(vp.x * 0.13, vp.y * 0.593)`
- Coffee mug: `(320, 390)` → `(vp.x * 0.278, vp.y * 0.602)`
- Laptop: `(660, 352)` → `(vp.x * 0.573, vp.y * 0.543)`
- Door: `(980, 100)` → `(vp.x * 0.85, vp.y * 0.154)`

Rewrite `_build_ui()`:

```gdscript
func _build_ui():
	var vp = _get_vp()
	var wall_h = vp.y * 0.586
	var desk_y = vp.y * 0.54
	var desk_edge_h = 6.0

	# Wall background
	var wall = ColorRect.new()
	wall.color = Color(0.25, 0.27, 0.30)
	wall.position = Vector2.ZERO
	wall.size = Vector2(vp.x, wall_h)
	add_child(wall)

	# Wall shelf
	var shelf = ColorRect.new()
	shelf.color = Color(0.45, 0.32, 0.22)
	shelf.position = Vector2(vp.x * 0.043, vp.y * 0.185)
	shelf.size = Vector2(180, 12)
	add_child(shelf)

	# Plant on shelf
	var pot = ColorRect.new()
	pot.color = Color(0.55, 0.35, 0.20)
	pot.position = Vector2(vp.x * 0.095, vp.y * 0.139)
	pot.size = Vector2(30, 30)
	add_child(pot)
	var leaves = ColorRect.new()
	leaves.color = Color(0.25, 0.55, 0.30)
	leaves.position = Vector2(vp.x * 0.087, vp.y * 0.093)
	leaves.size = Vector2(50, 35)
	add_child(leaves)

	# Desk surface
	var desk = ColorRect.new()
	desk.color = Color(0.42, 0.30, 0.20)
	desk.position = Vector2(0, desk_y)
	desk.size = Vector2(vp.x, vp.y - desk_y)
	add_child(desk)

	# Desk edge highlight
	var desk_edge = ColorRect.new()
	desk_edge.color = Color(0.48, 0.35, 0.24)
	desk_edge.position = Vector2(0, desk_y)
	desk_edge.size = Vector2(vp.x, desk_edge_h)
	add_child(desk_edge)

	# === MONITOR (center) ===
	var mon_w = 400.0
	var mon_h = 300.0
	var mon_x = (vp.x - mon_w) * 0.5
	var mon_y = vp.y * 0.123
	monitor_rect = Rect2(mon_x, mon_y, mon_w, mon_h)

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

	# Monitor bezel
	var bezel = ColorRect.new()
	bezel.color = Color(0.12, 0.12, 0.14)
	bezel.position = Vector2(mon_x - 12, mon_y - 12)
	bezel.size = Vector2(mon_w + 24, mon_h + 24)
	add_child(bezel)

	# Monitor screen
	var screen = ColorRect.new()
	screen.color = Color(0.15, 0.18, 0.22)
	screen.position = monitor_rect.position
	screen.size = monitor_rect.size
	add_child(screen)

	# Screen content text
	var screen_text = Label.new()
	screen_text.text = "Click to sit down..."
	screen_text.add_theme_font_size_override("font_size", 16)
	screen_text.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	screen_text.position = monitor_rect.position + Vector2(120, 130)
	add_child(screen_text)

	# Monitor click button
	var monitor_btn = Button.new()
	monitor_btn.flat = true
	monitor_btn.position = monitor_rect.position
	monitor_btn.size = monitor_rect.size
	monitor_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	monitor_btn.pressed.connect(func(): monitor_clicked.emit())
	add_child(monitor_btn)

	# Email badge
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
	var phone_x = vp.x * 0.755
	var phone_y = desk_y + 30
	var phone_body = ColorRect.new()
	phone_body.color = Color(0.18, 0.18, 0.20)
	phone_body.position = Vector2(phone_x, phone_y)
	phone_body.size = Vector2(100, 160)
	add_child(phone_body)

	var phone_screen = ColorRect.new()
	phone_screen.color = Color(0.12, 0.15, 0.20)
	phone_screen.position = Vector2(phone_x + 8, phone_y + 15)
	phone_screen.size = Vector2(84, 110)
	add_child(phone_screen)

	phone_glow = ColorRect.new()
	phone_glow.color = Color(0.3, 0.8, 0.4, 0.6)
	phone_glow.position = Vector2(phone_x + 8, phone_y + 130)
	phone_glow.size = Vector2(84, 6)
	phone_glow.visible = false
	add_child(phone_glow)

	var phone_label = Label.new()
	phone_label.text = "Contracts"
	phone_label.add_theme_font_size_override("font_size", 12)
	phone_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	phone_label.position = Vector2(phone_x + 18, phone_y + 50)
	add_child(phone_label)

	phone_btn = Button.new()
	phone_btn.flat = true
	phone_btn.position = Vector2(phone_x, phone_y)
	phone_btn.size = Vector2(100, 160)
	phone_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	phone_btn.pressed.connect(func(): phone_clicked.emit())
	add_child(phone_btn)

	# === BOOKS (left side of desk) ===
	var books_x = vp.x * 0.13
	var books_y = desk_y + 35
	var book_colors = [Color(0.2, 0.3, 0.6), Color(0.6, 0.25, 0.2), Color(0.2, 0.5, 0.3)]
	for i in 3:
		var book = ColorRect.new()
		book.color = book_colors[i]
		book.position = Vector2(books_x, books_y + 35 - i * 18)
		book.size = Vector2(120, 16)
		add_child(book)

	var books_label = Label.new()
	books_label.text = "Skills"
	books_label.add_theme_font_size_override("font_size", 12)
	books_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	books_label.position = Vector2(books_x + 35, books_y + 55)
	add_child(books_label)

	var books_btn = Button.new()
	books_btn.flat = true
	books_btn.position = Vector2(books_x - 10, desk_y + 20)
	books_btn.size = Vector2(140, 90)
	books_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	books_btn.pressed.connect(func(): books_clicked.emit())
	add_child(books_btn)

	# === COFFEE MUG ===
	var mug_x = vp.x * 0.278
	var mug_y = desk_y + 40
	var mug_body = ColorRect.new()
	mug_body.color = Color(0.85, 0.85, 0.82)
	mug_body.position = Vector2(mug_x, mug_y)
	mug_body.size = Vector2(30, 35)
	add_child(mug_body)

	var mug_handle = ColorRect.new()
	mug_handle.color = Color(0.85, 0.85, 0.82)
	mug_handle.position = Vector2(mug_x + 30, mug_y + 8)
	mug_handle.size = Vector2(10, 18)
	add_child(mug_handle)

	var coffee = ColorRect.new()
	coffee.color = Color(0.35, 0.22, 0.12)
	coffee.position = Vector2(mug_x + 2, mug_y + 2)
	coffee.size = Vector2(26, 6)
	add_child(coffee)

	# === LAPTOP (AI Tools) ===
	var laptop_x = vp.x * 0.573
	var laptop_y = desk_y + 50
	var laptop_base = ColorRect.new()
	laptop_base.color = Color(0.28, 0.28, 0.30)
	laptop_base.position = Vector2(laptop_x, laptop_y)
	laptop_base.size = Vector2(100, 60)
	add_child(laptop_base)

	var laptop_screen = ColorRect.new()
	laptop_screen.color = Color(0.10, 0.14, 0.22)
	laptop_screen.position = Vector2(laptop_x + 5, laptop_y - 45)
	laptop_screen.size = Vector2(90, 48)
	add_child(laptop_screen)

	var laptop_bezel = ColorRect.new()
	laptop_bezel.color = Color(0.22, 0.22, 0.24)
	laptop_bezel.position = Vector2(laptop_x + 2, laptop_y - 48)
	laptop_bezel.size = Vector2(96, 52)
	laptop_bezel.z_index = -1
	add_child(laptop_bezel)

	var laptop_label = Label.new()
	laptop_label.text = "AI Tools"
	laptop_label.add_theme_font_size_override("font_size", 11)
	laptop_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	laptop_label.position = Vector2(laptop_x + 20, laptop_y - 32)
	add_child(laptop_label)

	var laptop_btn = Button.new()
	laptop_btn.flat = true
	laptop_btn.position = Vector2(laptop_x, laptop_y - 48)
	laptop_btn.size = Vector2(100, 110)
	laptop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	laptop_btn.pressed.connect(func(): laptop_clicked.emit())
	add_child(laptop_btn)

	# === DOOR ===
	var door_x = vp.x * 0.85
	var door_y = vp.y * 0.154
	var door_frame = ColorRect.new()
	door_frame.color = Color(0.35, 0.25, 0.18)
	door_frame.position = Vector2(door_x, door_y)
	door_frame.size = Vector2(110, 254)
	add_child(door_frame)

	var door_body = ColorRect.new()
	door_body.color = Color(0.45, 0.33, 0.22)
	door_body.position = Vector2(door_x + 5, door_y + 5)
	door_body.size = Vector2(100, 244)
	add_child(door_body)

	var door_handle = ColorRect.new()
	door_handle.color = Color(0.75, 0.65, 0.30)
	door_handle.position = Vector2(door_x + 90, door_y + 130)
	door_handle.size = Vector2(8, 20)
	add_child(door_handle)

	var door_label = Label.new()
	door_label.text = "Team"
	door_label.add_theme_font_size_override("font_size", 13)
	door_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	door_label.position = Vector2(door_x + 35, door_y + 100)
	add_child(door_label)

	var door_btn = Button.new()
	door_btn.flat = true
	door_btn.position = Vector2(door_x, door_y)
	door_btn.size = Vector2(110, 254)
	door_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	door_btn.pressed.connect(func(): door_clicked.emit())
	add_child(door_btn)
```

**Step 3: Update `zoom_to_monitor()` and `zoom_to_desk()` to use dynamic viewport size**

```gdscript
func zoom_to_monitor() -> Tween:
	_is_zoomed = true
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
```

**Step 4: Run the game and test**

Run: `godot --path /home/lars/Prosjekter/consultancy-tycoon`
Expected: Desk scene fills any window size. Monitor centered. All objects proportionally placed. Zoom-to-monitor still works.

**Step 5: Run existing tests to ensure no regressions**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All 176 tests pass (desk_scene.gd has no unit tests — changes are visual only).

**Step 6: Commit**

```bash
git add src/office/desk_scene.gd
git commit -m "feat: make desk scene viewport-relative for responsive scaling"
```

---

### Task 3: Make management office viewport-relative

**Files:**
- Modify: `src/management/management_office.gd`

The management office has three areas of hardcoded positions:
1. Wall strip and wall objects — reference `1152` width
2. Desk grid — uses `DESK_AREA_TOP` and `DESK_SPACING` constants
3. Consultant sprites — positioned relative to desks

**Step 1: Add viewport helper and update wall objects**

Same pattern as desk scene. Add `_get_vp()` helper. Replace `1152` with `vp.x` for wall, molding, and wall object spacing.

In `_build_office()`, replace:
```gdscript
wall.size = Vector2(1152, WALL_HEIGHT)
```
With:
```gdscript
var vp = _get_vp()
wall.size = Vector2(vp.x, WALL_HEIGHT)
```

Same for molding and floor_bg (floor_bg already uses PRESET_FULL_RECT so it's fine).

**Step 2: Update `_build_wall_objects()` to use viewport width**

Change:
```gdscript
var spacing = 1152.0 / 6.0
```
To:
```gdscript
var vp = _get_vp()
var spacing = vp.x / 6.0
```

**Step 3: Update `_build_desks()` to center the desk grid**

Currently desks start at `Vector2(80, DESK_AREA_TOP)`. Center the grid horizontally within the viewport:

```gdscript
var vp = _get_vp()
var total_width = DESK_COLUMNS * DESK_SPACING.x
var grid_start = Vector2((vp.x - total_width) * 0.5, DESK_AREA_TOP)
```

**Step 4: Run the game and test management office**

Run: `godot --path /home/lars/Prosjekter/consultancy-tycoon`
Expected: Management office fills viewport width. Wall objects evenly spaced. Desk grid centered.

**Step 5: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All 176 tests pass.

**Step 6: Commit**

```bash
git add src/management/management_office.gd
git commit -m "feat: make management office viewport-relative for responsive scaling"
```

---

### Task 4: Verify IDE and overlays fill expanded viewport

**Files:**
- Review (may need small fixes): `src/main.gd`, `src/ide/ide_interface.gd`

The IDE and overlay panels are inside CanvasLayers with `PRESET_FULL_RECT` containers. They should automatically fill the expanded viewport. This task verifies and fixes any issues.

**Step 1: Check IDE layer setup in main.gd**

In `_build_ide_layer()` (main.gd:140-162), the container has `PRESET_FULL_RECT` and the IDE has `PRESET_FULL_RECT`. This should work. The "Stand Up" button uses `PRESET_BOTTOM_RIGHT` anchors, which should also adapt.

Verify by resizing the browser window while in the IDE view.

**Step 2: Check overlay CenterContainers**

In `_build_overlay_layer()` (main.gd:164-198), the dimmer and center container both use `PRESET_FULL_RECT`. Panels are inside a CenterContainer, so they'll center in whatever viewport size exists. This should work.

**Step 3: Verify welcome screen**

In `_build_welcome_layer()` (main.gd:242-304), the bg and center container use `PRESET_FULL_RECT`. Should work.

**Step 4: Run the game — test each screen at a non-16:9 window size**

Run: `godot --path /home/lars/Prosjekter/consultancy-tycoon`

Test checklist:
- [ ] Welcome screen centered in wide window
- [ ] Desk scene fills window, monitor centered
- [ ] Zoom to monitor — IDE fills entire window
- [ ] Stand up — back to desk, scene fills window
- [ ] Open phone/books/email/AI overlays — centered
- [ ] Switch to management office — fills window
- [ ] Open management overlays — centered
- [ ] HUD stretches full width at top

**Step 5: Fix any issues found (if needed)**

If the IDE PanelContainer doesn't have a background style that fills the expanded viewport, add:
```gdscript
# In ide_interface.gd _build_ui(), ensure the panel fills:
var bg_style = StyleBoxFlat.new()
bg_style.bg_color = Color(0.12, 0.13, 0.16)
add_theme_stylebox_override("panel", bg_style)
```

**Step 6: Commit (if changes were needed)**

```bash
git add src/main.gd src/ide/ide_interface.gd
git commit -m "fix: ensure IDE and overlays fill expanded viewport"
```

---

### Task 5: Web export and browser test

**Files:**
- No code changes — export and verify

**Step 1: Export for web**

Run: `godot --headless --export-release "Web" build/index.html`

**Step 2: Serve locally and test in browser**

Run: `python3 -m http.server 8080 -d build/` (or use the existing `serve.py`)

Open in browser at various window sizes:
- Narrow (800x600)
- Standard (1280x720)
- Wide (1920x1080)
- Ultra-wide (2560x1080)

**Step 3: Verify the canvas fills the browser window**

The export already has `canvas_resize_policy=2` (Adaptive), which means the canvas resizes with the browser. Combined with the stretch settings, the game should fill the window at any size.

**Step 4: Commit export if updated**

```bash
git add build/
git commit -m "chore: rebuild web export with responsive scaling"
```
