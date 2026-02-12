# Kenney Furniture Kit Art Integration Design

## Overview

Replace flat ColorRect-based office scenes with Kenney Furniture Kit (CC0) sprite assets. Personal office uses Side renders, management office uses Isometric renders in a proper isometric tile grid. Characters remain programmatic — they're the primary candidate for AI-generated art later.

## Asset Source

- **Kenney Furniture Kit** v1.0 — 140 objects, CC0 license
- Download: https://kenney.nl/assets/furniture-kit
- Side renders (front-facing) for personal office
- Isometric renders (4 angles, using SE) for management office

## 1. Personal Office — Side Renders

Keep the side-view perspective. Replace each ColorRect with its Kenney Side render.

### Asset Mapping

| Current ColorRect | Kenney Side Asset | Size | Notes |
|---|---|---|---|
| Monitor (bezel + screen) | `computerScreen.png` | 71x71 | Screen area for IDE overlay |
| Desk surface | `desk.png` | 116x51 | Scaled to fill desk area |
| Books stack | `books.png` | 26x27 side | Skills |
| Laptop | `laptop.png` | 50x52 side | AI tools |
| Coffee mug | `kitchenCoffeeMachine.png` | 35x43 side | Decorative |
| Plant + shelf | `pottedPlant.png` | 28x85 side | Wall decoration |
| Bookcase | `bookcaseOpen.png` | 67x140 side | Behind desk or on wall |
| Door | Keep programmatic | — | AI-art candidate |
| Phone | Keep programmatic | — | AI-art candidate |

### Implementation

- Keep `_build_ui()` structure with viewport-relative positions
- Replace `ColorRect.new()` with `TextureRect.new()` loading Kenney PNGs
- Use `TextureRect.stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`
- Wall and desk surface backgrounds remain as ColorRects (large flat areas)
- Sprites layer on top of backgrounds
- Monitor sprite keeps transparent Button overlay for clicks
- Door and phone remain programmatic — AI-art candidates

## 2. Management Office — Full Isometric Tile Grid

Rebuild as a proper isometric grid using Kenney Isometric renders.

### Tile System

- Floor tile: `floorFull_SE.png` (208x152)
- Half-tile: `HALF_W = 104, HALF_H = 76`
- Cart-to-iso transform:
  - `iso_x = origin_x + (col - row) * HALF_W`
  - `iso_y = origin_y + (col + row) * HALF_H`
- Origin centered in viewport

### Asset Mapping

| Element | Kenney Isometric Asset | Notes |
|---|---|---|
| Floor | `floorFull_SE.png` (208x152) | Tiled grid |
| Back wall | `wall_SE.png` (109x212) | Along back row |
| Door (back) | `wallDoorway_SE.png` | Door to personal office |
| Desk | `desk_SE.png` (116x122) | Per consultant |
| Monitor on desk | `computerScreen_SE.png` (47x59) | Composited on desk |
| Chair at desk | `chairDesk_SE.png` (60x97) | Composited at desk |
| Empty desk | `desk_SE.png` only | No chair/monitor |
| Bookcase | `bookcaseOpen_SE.png` | Decoration |
| Plant | `pottedPlant_SE.png` | Decoration |

### Wall Objects (Stay Programmatic)

Whiteboard (contracts), hiring screen, staff clipboard, inbox tray, locked teams door — no Kenney equivalents. These stay as programmatic ColorRect/Label with hover effects. Secondary AI-art candidates.

### Consultant Sprites (Stay Programmatic)

Colored circles + name labels positioned at desk iso coordinates. Primary AI-art candidate for later.

## 3. Asset Organization

```
assets/
  kenney-furniture/
    side/
      desk.png
      computerScreen.png
      laptop.png
      books.png
      bookcaseOpen.png
      pottedPlant.png
      kitchenCoffeeMachine.png
      chairDesk.png
    isometric/
      floorFull_SE.png
      wall_SE.png
      wallDoorway_SE.png
      desk_SE.png
      computerScreen_SE.png
      chairDesk_SE.png
      bookcaseOpen_SE.png
      pottedPlant_SE.png
  LICENSE.txt
```

Only copy assets we actually use — not the entire 560-file kit.

## 4. AI-Art Candidates (Later)

After the Kenney integration, these remain programmatic and are candidates for custom AI-generated art:

**Primary:**
- Consultant character sprites (colored circles → isometric people)

**Secondary:**
- Personal office door
- Personal office phone
- Management wall objects (whiteboard, screen, clipboard, inbox, locked door)
- Custom desk/monitor variants to replace Kenney if desired

## 5. Migration Steps

1. Copy selected Kenney assets into `assets/kenney-furniture/`
2. Personal office: replace ColorRect objects with TextureRect sprites
3. Management office: rebuild with isometric tile grid + desk composites
4. Run `godot --headless --import` to register new assets
5. Test both offices visually
