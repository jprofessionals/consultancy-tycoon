# Graphics Quality & Screen Scaling Design

## Overview

Upgrade the visual quality from flat ColorRect-based scenes to illustrated isometric art, and make the game scale responsively with the browser window.

## 1. Responsive Screen Scaling

### Godot Project Settings

- `display/window/stretch/mode` = `"canvas_items"` — UI scales proportionally with window
- `display/window/stretch/aspect` = `"expand"` — fills extra space instead of black bars
- Base viewport stays 1152x648 as the design resolution

### Code Changes

- **Personal office** (`desk_scene.gd`): replace hardcoded pixel positions with viewport-relative positioning. Objects scale and reposition when the window is larger than 1152x648.
- **Management office** (`management_office.gd`): desk grid anchors to available space. Wall objects distribute evenly across width.
- **IDE interface** (`ide_interface.gd`): when zoomed in, use full-rect anchors so the IDE fills the entire viewport. More screen = more visible code.
- **HUD** (`hud.gd`): anchor top-center, expand horizontally with viewport.
- **Overlay panels**: already use PanelContainer — ensure they center in viewport rather than at fixed coordinates.

### Principle

The base 1152x648 design stays the same. Extra space on wider/taller screens gets used rather than wasted. The IDE benefits most.

## 2. Personal Office — Isometric Illustrated

### Current State

Side-view scene built from ~30 ColorRect nodes: desk, monitor, phone, books, laptop, mug, door, shelf, plant.

### Target

An illustrated isometric office room viewed from ~30 degrees. Warm, inviting, with natural depth.

### Scene Structure

- Replace programmatic `_build_ui()` with a `.tscn` scene using `Sprite2D` / `TextureRect` nodes referencing image assets.
- Base layer: single **background illustration** showing the isometric room (desk surface, wall, floor).
- Interactive objects layered on top as individual sprites, each with a clickable `Button` overlay — same signal-driven pattern as current code.

### Art Assets

| File | Description |
|------|-------------|
| `personal_bg.png` | Isometric room background (~1152x648) |
| `monitor.png` | Desk monitor with bezel, dark screen area for IDE overlay |
| `phone.png` | Desk phone |
| `books.png` | Stack of skill books |
| `laptop.png` | AI tools laptop |
| `coffee_mug.png` | Decorative mug |
| `door.png` | Wall door with frame and handle |
| `shelf_plant.png` | Wall shelf with plant |

### Depth Illusion

- **Drop shadows**: semi-transparent dark ellipse under each desk object, offset a few pixels.
- **Mouse parallax**: background shifts 1-2px opposite to cursor, desk objects shift 3-4px. Very subtle but adds life.
- **Size perspective**: objects closer to viewer (front of desk) slightly larger and warmer-toned.

### Monitor/IDE Integration

The monitor sprite has a dark screen area. When the player "sits down," the IDE UI overlays full-viewport on top (same zoom tween as now, but filling the full expanded viewport).

## 3. Management Office — Isometric Top-Down

### Current State

Flat top-down view with ColorRect desks on dark floor, wall objects along top strip.

### Target

Isometric office floor with visible desk depth, staggered rows, and an isometric back wall.

### Layout Changes

- Floor: isometric grid with repeating floor tiles.
- Desks: isometric rectangles with visible sides/legs.
- Back wall: isometric wall segment with visible face and top edge.
- Wall objects: isometric sprites hung on or placed against the wall.
- Desk rows stagger in isometric projection — back rows higher on screen and slightly smaller, front rows lower and larger.

### Art Assets

| File | Description |
|------|-------------|
| `floor_tile.png` | Repeatable isometric floor tile |
| `wall.png` | Back wall segment |
| `desk.png` | Isometric desk with monitor |
| `desk_empty.png` | Empty desk for "buy desk" slots |
| `whiteboard.png` | Contracts board on wall |
| `wall_screen.png` | Hiring screen on wall |
| `clipboard.png` | Staff roster clipboard |
| `inbox_tray.png` | Management inbox |
| `door_back.png` | Door back to personal office |
| `door_locked.png` | Locked teams door |

### Coordinate Transform

The desk grid positioning in `_build_desks()` converts from flat cartesian to isometric coordinates:

```
iso_x = (cart_x - cart_y) * tile_width / 2
iso_y = (cart_x + cart_y) * tile_height / 2
```

### Interaction Model

Unchanged — click wall objects for overlay panels, click consultant sprites for details. Overlay panels remain programmatic UI.

## 4. Consultant Character Sprites

### Current State

Colored circle (from name hash) + name label + state label. ~30x60px per consultant.

### Target

Small isometric figures, readable at desk scale (~30x50px). Think Kairosoft or Two Point Hospital style — distinct silhouettes and colors.

### Modular Composite System

Each consultant sprite is assembled from layers on a sprite sheet:

- **Body base**: ~4 variants (sitting-working, sitting-idle, sitting-training, away-silhouette)
- **Hair/head**: ~8 color/style variants
- **Accessories**: ~4 options tied to state (laptop for working, book for training, headphones for idle, coffee for break)

### Deterministic Appearance

`ConsultantData.name.hash()` already drives color. Extend to select:
- Hair style index: `hash % 8`
- Accessory preference: derived from trait or secondary hash bits

Same consultant always looks the same across sessions.

### Sprite Sheet Layout

Single `consultant_sheet.png` with rows for body poses and columns for hair/accessory variants. Use `AtlasTexture` with `region_rect` to pick the right combination at runtime.

### Animation (Minimal)

- **Idle**: 2-frame breathing bob (1px vertical shift, ~1s loop)
- **Training**: 2-3 frame page-flip or typing motion
- No walk cycles — consultants don't move between positions on screen

### Chat Bubbles

Stay as-is — programmatic `PanelContainer` with text, floating above the sprite. Already work well.

## 5. Asset Pipeline

### Directory Structure

```
assets/
  office/
    personal_bg.png
    monitor.png
    phone.png
    books.png
    laptop.png
    coffee_mug.png
    shelf_plant.png
    door.png
  management/
    floor_tile.png
    wall.png
    desk.png
    desk_empty.png
    whiteboard.png
    wall_screen.png
    clipboard.png
    inbox_tray.png
    door_back.png
    door_locked.png
  characters/
    consultant_sheet.png
    shadow.png
  ui/
    panel_shadow.png
```

### Generation Workflow

1. Generate base art with AI image tools — consistent isometric office style, ~30 degree angle, flat shading with soft shadows.
2. Clean up in image editor: fix edges, ensure consistent palette, make backgrounds transparent.
3. Import into Godot — configure texture filter per asset (nearest for pixel-crisp, linear for smooth).
4. Godot auto-generates `.import` settings.

### Texture Settings

- Office backgrounds: linear filter, no mipmaps
- Character sprites: nearest filter for crisp edges at small sizes
- UI shadows: linear filter for smooth gradients

## 6. Migration Strategy

Each step is independently shippable and testable.

### Step 1: Screen Scaling

Configure Godot stretch mode. Adapt hardcoded positions in desk_scene.gd, management_office.gd, ide_interface.gd, and hud.gd to be viewport-relative. No art assets needed — immediate improvement.

### Step 2: Personal Office Art

Replace ColorRects with sprites one object at a time. Scene works with a mix of sprites and rectangles during transition. Background first, then monitor, then remaining objects.

### Step 3: Management Office Art

Same incremental replacement. Floor tiles and wall first, then desks, then wall objects.

### Step 4: Character Sprites

Replace colored circles with sprite sheet figures. Build the modular composite system. Test with 1-2 variants first, expand to full set.

### Step 5: Polish Pass

Add mouse parallax to personal office. Add drop shadows. Subtle idle animations on characters. Ensure consistent lighting direction across all assets.
