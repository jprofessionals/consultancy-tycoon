# Kenney Art Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace flat ColorRect office objects with Kenney Furniture Kit sprites. Personal office uses Side renders, management office uses full isometric tile grid with Isometric renders.

**Architecture:** TextureRect nodes replace ColorRect nodes, loading PNGs from `assets/kenney-furniture/`. Personal office keeps side-view with sprite overlays. Management office rebuilt as isometric grid with cart-to-iso coordinate transform. Programmatic characters and missing objects (door, phone, wall items) remain unchanged.

**Tech Stack:** Godot 4.6, GDScript, Kenney Furniture Kit (CC0), TextureRect, Sprite2D

---

### Task 1: Personal office — replace desk objects with Kenney Side sprites

**Files:**
- Modify: `src/office/desk_scene.gd`

**Context:** The personal office `_build_ui()` creates ~30 ColorRect nodes for wall, desk, monitor, phone, books, laptop, mug, plant, door. Assets are at `res://assets/kenney-furniture/side/`. The current code uses viewport-relative positions with `_get_vp()`.

**Step 1: Replace monitor ColorRects with TextureRect**

In `_build_ui()`, find the monitor section (bezel + screen ColorRects). Replace with:

```gdscript
# Monitor — Kenney computerScreen sprite
var monitor_tex = TextureRect.new()
monitor_tex.texture = preload("res://assets/kenney-furniture/side/computerScreen.png")
monitor_tex.position = Vector2(mon_x - 10, mon_y - 10)
monitor_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
monitor_tex.custom_minimum_size = Vector2(mon_w + 20, mon_h + 20)
monitor_tex.size = Vector2(mon_w + 20, mon_h + 20)
add_child(monitor_tex)
```

Remove the old bezel and screen ColorRects. Keep the screen_text label, email_badge, and monitor_btn overlay — they layer on top.

**Step 2: Replace desk surface with desk sprite**

The wall and desk surface ColorRects stay as backgrounds (they fill the full width). But add the Kenney desk sprite centered on the desk area:

```gdscript
# Desk furniture — Kenney desk sprite (centered under monitor)
var desk_tex = TextureRect.new()
desk_tex.texture = preload("res://assets/kenney-furniture/side/desk.png")
desk_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
var desk_sprite_w = 400.0
var desk_sprite_h = 180.0
desk_tex.position = Vector2((vp.x - desk_sprite_w) / 2.0, desk_y - 30)
desk_tex.custom_minimum_size = Vector2(desk_sprite_w, desk_sprite_h)
desk_tex.size = Vector2(desk_sprite_w, desk_sprite_h)
add_child(desk_tex)
```

**Step 3: Replace books with Kenney bookcase sprite**

Replace the 3 book ColorRects with:

```gdscript
var books_tex = TextureRect.new()
books_tex.texture = preload("res://assets/kenney-furniture/side/bookcaseOpen.png")
books_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
books_tex.custom_minimum_size = Vector2(80, 170)
books_tex.size = Vector2(80, 170)
books_tex.position = Vector2(books_x, desk_y - 130)
add_child(books_tex)
```

Keep the "Skills" label and books_btn click area.

**Step 4: Replace laptop with Kenney laptop sprite**

Replace laptop base/screen/bezel ColorRects with:

```gdscript
var laptop_tex = TextureRect.new()
laptop_tex.texture = preload("res://assets/kenney-furniture/side/laptop.png")
laptop_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
laptop_tex.custom_minimum_size = Vector2(100, 100)
laptop_tex.size = Vector2(100, 100)
laptop_tex.position = Vector2(laptop_x, laptop_y - 45)
add_child(laptop_tex)
```

Keep "AI Tools" label and laptop_btn.

**Step 5: Replace coffee mug with Kenney coffee machine sprite**

Replace mug body/handle/coffee ColorRects with:

```gdscript
var mug_tex = TextureRect.new()
mug_tex.texture = preload("res://assets/kenney-furniture/side/kitchenCoffeeMachine.png")
mug_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
mug_tex.custom_minimum_size = Vector2(50, 60)
mug_tex.size = Vector2(50, 60)
mug_tex.position = Vector2(mug_x, mug_y - 20)
add_child(mug_tex)
```

**Step 6: Replace plant+shelf with Kenney potted plant sprite**

Replace pot/leaves/shelf ColorRects with:

```gdscript
var plant_tex = TextureRect.new()
plant_tex.texture = preload("res://assets/kenney-furniture/side/pottedPlant.png")
plant_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
plant_tex.custom_minimum_size = Vector2(50, 150)
plant_tex.size = Vector2(50, 150)
plant_tex.position = Vector2(vp.x * 0.087, vp.y * 0.02)
add_child(plant_tex)
```

**Step 7: Replace monitor stand with Kenney chair sprite (decorative)**

The monitor stand (base + neck) can be replaced or kept as-is. Optionally add the desk chair behind the desk:

```gdscript
var chair_tex = TextureRect.new()
chair_tex.texture = preload("res://assets/kenney-furniture/side/chairDesk.png")
chair_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
chair_tex.custom_minimum_size = Vector2(60, 100)
chair_tex.size = Vector2(60, 100)
chair_tex.position = Vector2((vp.x - 60) / 2.0, desk_y - 60)
chair_tex.z_index = -1  # Behind desk
add_child(chair_tex)
```

**Step 8: Keep door and phone as ColorRects**

The door and phone have no Kenney equivalent. Leave them as programmatic ColorRects. They are AI-art candidates for later.

**Step 9: Run tests and verify**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All 176 tests pass.

**Step 10: Commit**

```bash
git add src/office/desk_scene.gd
git commit -m "feat: replace personal office ColorRects with Kenney furniture sprites"
```

---

### Task 2: Management office — build isometric tile grid

**Files:**
- Modify: `src/management/management_office.gd`

**Context:** The management office `_build_office()` currently creates a flat top-down view with ColorRect floor, wall strip, and wall objects. We're replacing this with a proper isometric grid using Kenney Isometric renders.

**Step 1: Add isometric constants and helper**

Add at the top of the script, alongside existing constants:

```gdscript
# Isometric tile dimensions (from floorFull_SE.png: 208x152)
const TILE_W = 208.0
const HALF_W = 104.0
const TILE_H = 152.0
const HALF_H = 76.0

# Grid dimensions
const GRID_COLS = 8
const GRID_ROWS = 4

func _cart_to_iso(col: int, row: int, origin: Vector2) -> Vector2:
    return Vector2(
        origin.x + (col - row) * HALF_W,
        origin.y + (col + row) * HALF_H
    )
```

**Step 2: Rewrite `_build_office()` — floor tiles**

Replace the floor_bg ColorRect + wall ColorRect + molding ColorRect with isometric floor tiles:

```gdscript
func _build_office():
    var vp = _get_vp()
    # Origin: center the grid in viewport
    var grid_pixel_w = (GRID_COLS + GRID_ROWS) * HALF_W
    var grid_pixel_h = (GRID_COLS + GRID_ROWS) * HALF_H
    var origin = Vector2(
        (vp.x - grid_pixel_w) / 2.0 + GRID_ROWS * HALF_W,
        40.0  # Below HUD
    )

    # Dark background behind tiles
    var bg = ColorRect.new()
    bg.color = Color(0.12, 0.13, 0.16)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    # Floor tiles
    var floor_tex = preload("res://assets/kenney-furniture/isometric/floorFull_SE.png")
    for row in GRID_ROWS:
        for col in GRID_COLS:
            var pos = _cart_to_iso(col, row, origin)
            var tile = TextureRect.new()
            tile.texture = floor_tex
            tile.position = pos
            tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
            add_child(tile)
```

**Step 3: Add back wall tiles along row 0**

```gdscript
    # Back wall tiles along row 0
    var wall_tex = preload("res://assets/kenney-furniture/isometric/wall_SE.png")
    for col in GRID_COLS:
        var pos = _cart_to_iso(col, 0, origin)
        var wall = TextureRect.new()
        wall.texture = wall_tex
        wall.position = pos + Vector2(0, -wall_tex.get_size().y + TILE_H)
        wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(wall)
```

**Step 4: Rewrite `_build_wall_objects()` — position along back wall**

Wall objects (door, contracts, hiring, staff, inbox, locked teams door) positioned at specific columns along row 0. Keep them as programmatic overlays but position using `_cart_to_iso()`:

```gdscript
func _build_wall_objects():
    var vp = _get_vp()
    var origin = _get_grid_origin(vp)

    # Door back to desk at col 0
    var door_pos = _cart_to_iso(0, 0, origin)
    var door_tex_node = TextureRect.new()
    door_tex_node.texture = preload("res://assets/kenney-furniture/isometric/wallDoorway_SE.png")
    door_tex_node.position = door_pos + Vector2(0, -160)
    door_tex_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    door_tex_node.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            back_to_desk_requested.emit()
    )
    add_child(door_tex_node)
    _back_door = door_tex_node

    # Remaining wall objects at cols 2, 3, 4, 5, 7 — keep as programmatic labels
    # Use _cart_to_iso to get positions, then create interactive objects at those positions
    var wall_obj_y_offset = -120.0
    var obj_h = 50.0

    # Contracts whiteboard at col 2
    var board_pos = _cart_to_iso(2, 0, origin) + Vector2(20, wall_obj_y_offset)
    var board_ctrl = _create_interactive_object("Contracts", board_pos, Vector2(80, obj_h), WHITEBOARD_COLOR, OBJECT_LABEL_COLOR)
    board_ctrl.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            contract_board_clicked.emit()
    )

    # Hiring screen at col 3
    var hire_pos = _cart_to_iso(3, 0, origin) + Vector2(20, wall_obj_y_offset)
    var hire_ctrl = _create_interactive_object("Hiring", hire_pos, Vector2(70, obj_h), SCREEN_COLOR, Color(0.4, 0.7, 0.9))
    hire_ctrl.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            hiring_board_clicked.emit()
    )

    # Staff clipboard at col 5
    var staff_pos = _cart_to_iso(5, 0, origin) + Vector2(20, wall_obj_y_offset)
    var staff_ctrl = _create_interactive_object("Staff", staff_pos, Vector2(60, obj_h), CLIPBOARD_COLOR, Color(0.9, 0.85, 0.75))
    staff_ctrl.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            staff_roster_clicked.emit()
    )

    # Inbox at col 6
    var inbox_pos = _cart_to_iso(6, 0, origin) + Vector2(20, wall_obj_y_offset)
    var inbox_ctrl = _create_interactive_object("Inbox", inbox_pos, Vector2(60, obj_h), INBOX_COLOR, Color(0.7, 0.8, 0.95))
    inbox_ctrl.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            inbox_clicked.emit()
    )

    # Locked teams door at col 7
    var locked_pos = _cart_to_iso(7, 0, origin) + Vector2(20, wall_obj_y_offset)
    var locked_ctrl = _create_interactive_object("Teams", locked_pos, Vector2(70, obj_h), LOCKED_DOOR_COLOR, Color(0.5, 0.48, 0.45))
    var lock_label = Label.new()
    lock_label.text = "Locked"
    lock_label.add_theme_font_size_override("font_size", 9)
    lock_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
    lock_label.position = locked_pos + Vector2(15, obj_h - 5)
    lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(lock_label)
```

**Step 5: Rewrite `_build_desks()` — isometric desk composites**

Replace flat ColorRect desks with Kenney isometric desk + chair + monitor composites:

```gdscript
func _build_desks():
    for node in _desk_node_visuals:
        if is_instance_valid(node):
            node.queue_free()
    _desk_node_visuals.clear()
    _desk_nodes.clear()

    var vp = _get_vp()
    var origin = _get_grid_origin(vp)
    var desk_count: int = GameState.desk_capacity
    var desk_tex = preload("res://assets/kenney-furniture/isometric/desk_SE.png")
    var chair_tex = preload("res://assets/kenney-furniture/isometric/chairDesk_SE.png")
    var screen_tex = preload("res://assets/kenney-furniture/isometric/computerScreen_SE.png")

    for i in desk_count:
        var col = i % GRID_COLS
        var row = 1 + i / GRID_COLS  # Row 0 is wall, desks start at row 1
        var pos = _cart_to_iso(col, row, origin)

        # Desk sprite
        var desk_node = TextureRect.new()
        desk_node.texture = desk_tex
        desk_node.position = pos + Vector2(45, 20)
        desk_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(desk_node)
        _desk_node_visuals.append(desk_node)

        # Chair sprite (behind desk)
        var chair_node = TextureRect.new()
        chair_node.texture = chair_tex
        chair_node.position = pos + Vector2(75, -10)
        chair_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
        chair_node.z_index = -1
        add_child(chair_node)
        _desk_node_visuals.append(chair_node)

        # Monitor sprite (on desk)
        var screen_node = TextureRect.new()
        screen_node.texture = screen_tex
        screen_node.position = pos + Vector2(70, -10)
        screen_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(screen_node)
        _desk_node_visuals.append(screen_node)

        # Desk number label
        var num_label = Label.new()
        num_label.text = str(i + 1)
        num_label.add_theme_font_size_override("font_size", 10)
        num_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.38))
        num_label.position = pos + Vector2(50, 85)
        num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(num_label)
        _desk_node_visuals.append(num_label)

        _desk_nodes.append({"position": pos, "index": i})

    # Buy desk button
    if _buy_desk_btn and is_instance_valid(_buy_desk_btn):
        _buy_desk_btn.queue_free()
    _buy_desk_btn = null

    if desk_count < MAX_DESKS:
        var next_col = desk_count % GRID_COLS
        var next_row = 1 + desk_count / GRID_COLS
        var btn_pos = _cart_to_iso(next_col, next_row, origin)
        _buy_desk_btn = Button.new()
        _buy_desk_btn.custom_minimum_size = Vector2(100, 60)
        _buy_desk_btn.position = btn_pos + Vector2(50, 30)
        _buy_desk_btn.size = Vector2(100, 60)
        _update_buy_desk_label()
        _buy_desk_btn.pressed.connect(_on_buy_desk)
        add_child(_buy_desk_btn)
```

**Step 6: Extract `_get_grid_origin()` helper**

```gdscript
func _get_grid_origin(vp: Vector2) -> Vector2:
    var grid_pixel_w = (GRID_COLS + GRID_ROWS) * HALF_W
    return Vector2(
        (vp.x - grid_pixel_w) / 2.0 + GRID_ROWS * HALF_W,
        40.0
    )
```

**Step 7: Update `_create_consultant_sprite()` for isometric positions**

Update consultant sprite positioning to use desk iso positions:

```gdscript
func _create_consultant_sprite(consultant, desk_pos, _desk_index):
    var container = Control.new()
    # Position above the desk in iso space
    container.position = desk_pos + Vector2(80, -40)
    container.size = Vector2(30, 60)
    add_child(container)
    # ... rest stays the same (head circle, name label, state label)
```

**Step 8: Update `_create_away_label()` for isometric positions**

```gdscript
func _create_away_label(consultant, desk_pos):
    var container = Control.new()
    container.position = desk_pos + Vector2(50, 10)
    # ... rest stays the same
```

**Step 9: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All 176 tests pass.

**Step 10: Commit**

```bash
git add src/management/management_office.gd
git commit -m "feat: rebuild management office with isometric Kenney tile grid"
```

---

### Task 3: Commit assets and design docs

**Files:**
- Add: `assets/kenney-furniture/` (already copied)
- Add: `docs/plans/2026-02-12-kenney-art-design.md`
- Add: `docs/plans/2026-02-12-kenney-art-plan.md`

**Step 1: Commit assets and docs**

```bash
git add assets/kenney-furniture/ docs/plans/2026-02-12-kenney-art-design.md docs/plans/2026-02-12-kenney-art-plan.md
git commit -m "feat: add Kenney furniture assets and art integration docs"
```
