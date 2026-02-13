# TSCN Migration Design

Move all programmatic UI layout from `_build_ui()` methods into .tscn scene files for visual editing in the Godot editor.

## Approach

**Pattern:** Static node trees move to .tscn files. Scripts use `@onready` to bind references. Dynamic content (card lists, consultant sprites) stays in code but gets added to container nodes defined in the .tscn.

**Viewport scaling:** Since canvas_items stretch mode is enabled, all positions use the reference resolution (1152x648). Delete all `_get_vp()` viewport-relative math.

**No functional changes.** The game should look and behave identically after migration. This is a pure structural refactor.

## File Breakdown

### Simple Panels (8 files)

All follow the same shell: PanelContainer → VBoxContainer → header (HBoxContainer with title Label + close Button) → ScrollContainer → VBoxContainer (card list). Scripts keep `refresh()` methods that clear and repopulate the card list VBoxContainer.

| File | Static .tscn nodes | Dynamic (stays in code) |
|---|---|---|
| `bidding_panel.gd` | Header, title, close btn, card_list container | Contract cards via `refresh_contracts()` |
| `skill_panel.gd` | Header, title, close btn, skill_list container | Skill rows via `refresh()` |
| `ai_tool_panel.gd` | Header, title, close btn, description label, tool_list container | Tool rows via `refresh()` |
| `email_panel.gd` | Header, title, close btn, scroll, no_mail_label, event_list container | Event cards via `display_events()` |
| `management_inbox.gd` | Header, title, close btn, scroll, empty_label, card_list container | Extension/issue cards via `set_notifications()` |
| `staff_roster.gd` | Header, title, close btn, summary_label, scroll, card_list container | Consultant rows via `refresh()` |
| `hiring_board.gd` | Header, title, close btn, capacity_label, scroll, card_list container, refresh btn | Candidate cards via `refresh()` |
| `contract_board.gd` | Header, title, close btn, tab buttons (Projects/Rentals), scroll, card_list container | Project/rental cards via `_refresh_list()` |

### HUD

`hud.gd` — Entirely static. HBoxContainer with 6 labels (money, reputation, ai, team, stuck, task). All nodes in .tscn, `_build_ui()` deleted completely.

### IDE Interface

`ide_interface.gd` — Mostly static layout:

**.tscn nodes:**
- MarginContainer → VBoxContainer (main layout)
- Title bar (HBoxContainer + Label)
- Tab bar container (PanelContainer + HBoxContainer) — starts hidden
- Task label, status label
- Notification area (PanelContainer → VBoxContainer → review_panel + conflict_panel)
- Code display (RichTextLabel)
- Merge view (VBoxContainer → HBoxContainer with 3 columns, each PanelContainer → VBoxContainer → Label + RichTextLabel)
- Merge button bar (4 buttons: Auto-Merge, Local, Remote, Both)
- Progress bar
- Keyboard panel (PanelContainer → VBoxContainer → 4 HBoxContainer rows with key Buttons)

**Stays in code:**
- Tab bar buttons (rebuilt dynamically when tabs change)
- Review comment content (dynamic RichTextLabel)
- Code display content (populated during gameplay)
- Merge panel content (populated during conflicts)
- Key button flash animations
- BSOD easter egg overlay

### Desk Scene

`desk_scene.gd` — Side-view office with furniture sprites at fixed positions.

**.tscn nodes (all at reference resolution 1152x648):**
- Wall background (ColorRect)
- Shelf + plant sprite
- Desk surface + edge highlight
- Chair sprite (z_index -1)
- Desk furniture sprite
- Monitor: stand base, stand neck, bezel, screen, screen text label
- Monitor click button (flat Button over screen area)
- Email badge button (top-right of monitor)
- Contracts board: frame, body, glow indicator, label, click button
- Bookcase sprite + skills label + click button
- Coffee shelf + coffee machine sprite
- Laptop: bezel, screen, base, label, click button
- Door: frame, body, handle, label, click button

**Stays in code:**
- `monitor_rect` computed from node positions (for zoom calculation)
- Zoom tween animations
- Signal connections (button pressed → signal emit)
- Email badge style (StyleBoxFlat with rounded corners, red background)

### Management Office

`management_office.gd` — Isometric top-down scene.

**.tscn nodes:**
- Background ColorRect
- Floor tiles (rows 1-3, fixed grid)
- Wall sprites (row 0)
- Doorway sprite + back label
- Wall objects: Contracts, Hiring, Staff, Inbox, Teams (locked)
- Decorations: bookcase, plant

**Stays in code:**
- Desk sprites (count depends on `GameState.desk_capacity`)
- Consultant sprites (count/position depends on staff)
- Chat bubbles (timed, random)
- Buy desk button (conditional)
- `refresh()` rebuilding consultant visuals

## Migration Order

1. HUD (simplest, 6 labels)
2. Simple panels (8 files, same pattern)
3. IDE interface (complex but well-structured)
4. Desk scene (fixed-position sprites)
5. Management office (isometric grid, most dynamic)

## Script Changes

For each file:
1. Replace `var foo: Label` with `@onready var foo: Label = %Foo` (using unique name syntax)
2. Delete `_build_ui()` method entirely (or reduce to dynamic-only parts)
3. Delete `_get_vp()` if present
4. Connect button signals in .tscn (where possible) or in `_ready()`
5. Remove `REF_W`/`REF_H` constants if no longer needed

## Testing

- Run existing 176 tests (they don't depend on UI layout)
- Manual visual check: launch game, verify all screens look identical
- Verify all clickable objects still emit signals
- Verify zoom animations still work on desk scene
