# TSCN Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move all programmatic UI layout from `_build_ui()` into .tscn scene files so layouts can be edited visually in the Godot editor.

**Architecture:** Each .tscn file gets a full static node tree. Scripts use `@onready var foo = %Foo` (unique name `%` syntax) to bind references. Dynamic content (card lists, consultant sprites) stays in code. Signal connections for static buttons use `_ready()`. Since canvas_items stretch mode is active, all positions use the reference resolution 1152x648.

**Tech Stack:** Godot 4.6, GDScript, GUT v9.5.0

**Important context:**
- `UITheme` (`src/ui/ui_theme.gd`) provides `create_panel_style()`, `create_card_style()`, `create_close_button()`, `style_button()`, and color/size constants. StyleBoxFlat overrides are applied in code since .tscn doesn't support custom StyleBoxFlat inline easily — keep these in `_ready()`.
- All panels emit `close_requested` signal when close button is pressed.
- Dynamic card creation methods (`_create_contract_card()`, `_create_consultant_row()`, etc.) stay in code — they add children to container nodes defined in the .tscn.
- The management_office uses isometric Kenney sprites — wall/floor/decoration nodes go to .tscn, desks and consultant sprites stay dynamic.

---

### Task 1: HUD

The simplest migration — 6 labels in an HBoxContainer, no dynamic content.

**Files:**
- Modify: `src/ui/hud.tscn`
- Modify: `src/ui/hud.gd`

**Step 1: Rewrite hud.tscn with full node tree**

Replace the minimal .tscn with a full scene. The root `HUD` (PanelContainer) contains an HBoxContainer with 6 Labels. Each label that the script needs gets `unique_name_in_owner = true` so the script can reference it with `%Name`.

Node tree:
```
HUD (PanelContainer)
  └─ HBox (HBoxContainer, separation=24)
      ├─ MoneyLabel (Label, font_size=20, text="$0")
      ├─ ReputationLabel (Label, font_size=20, text="Rep: 0")
      ├─ AiLabel (Label, font_size=14, font_color=#6699b3e6, text="")
      ├─ TeamLabel (Label, font_size=14, font_color=#b39966, text="")
      ├─ StuckLabel (Label, font_size=14, font_color=#e64d4d, text="")
      └─ TaskLabel (Label, size_flags_horizontal=EXPAND_FILL, horizontal_alignment=RIGHT, text="")
```

**Step 2: Update hud.gd**

- Replace `var money_label: Label` etc. with `@onready var money_label: Label = %MoneyLabel` (6 labels)
- Delete `_build_ui()` entirely
- Move StyleBoxFlat panel override to `_ready()` (before signal connections)
- Keep all other methods unchanged

**Step 3: Run tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`
Expected: All 176 tests pass (HUD is not unit tested, tests don't touch UI nodes)

**Step 4: Commit**

```bash
git add src/ui/hud.tscn src/ui/hud.gd
git commit -m "refactor: migrate HUD layout to .tscn"
```

---

### Task 2: Bidding Panel

**Files:**
- Modify: `src/ui/bidding_panel.tscn`
- Modify: `src/ui/bidding_panel.gd`

**Step 1: Read bidding_panel.gd to understand exact structure**

Read the full file to map out the node tree and identify which nodes are static vs dynamic.

**Step 2: Rewrite bidding_panel.tscn**

Node tree:
```
BiddingPanel (PanelContainer, custom_minimum_size=500x400)
  └─ VBox (VBoxContainer, separation=8)
      ├─ Header (HBoxContainer)
      │   ├─ Title (Label, text="Available Contracts", font_size=18)
      │   └─ CloseBtn (Button, text="X", custom_minimum_size=32x32)
      └─ ContractList (VBoxContainer)  ← dynamic cards added here
```

All nodes the script references get `unique_name_in_owner = true`.

**Step 3: Update bidding_panel.gd**

- Add `@onready var contract_list: VBoxContainer = %ContractList`
- Add `@onready var _close_btn: Button = %CloseBtn`
- Delete `_build_ui()`
- In `_ready()`: apply `UITheme.create_panel_style()` to self, `UITheme.style_button(_close_btn)`, connect `_close_btn.pressed` → `close_requested.emit()`
- Keep `refresh_contracts()` and `_create_contract_card()` unchanged

**Step 4: Run tests and commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/ui/bidding_panel.tscn src/ui/bidding_panel.gd
git commit -m "refactor: migrate bidding panel layout to .tscn"
```

---

### Task 3: Skill Panel

Same pattern as bidding panel.

**Files:**
- Modify: `src/ui/skill_panel.tscn`
- Modify: `src/ui/skill_panel.gd`

**Step 1: Read skill_panel.gd, rewrite .tscn**

Node tree:
```
SkillPanel (PanelContainer, custom_minimum_size=500x400)
  └─ VBox (VBoxContainer, separation=8)
      ├─ Header (HBoxContainer)
      │   ├─ Title (Label, text="Skills & Certifications", font_size=18)
      │   └─ CloseBtn (Button, text="X", custom_minimum_size=32x32)
      └─ SkillList (VBoxContainer)  ← dynamic skill rows added here
```

**Step 2: Update skill_panel.gd**

- `@onready var skill_list = %SkillList`, `@onready var _close_btn = %CloseBtn`
- Delete `_build_ui()`, apply styles and connect close in `_ready()`

**Step 3: Run tests and commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/ui/skill_panel.tscn src/ui/skill_panel.gd
git commit -m "refactor: migrate skill panel layout to .tscn"
```

---

### Task 4: AI Tool Panel

**Files:**
- Modify: `src/ui/ai_tool_panel.tscn`
- Modify: `src/ui/ai_tool_panel.gd`

**Step 1: Read ai_tool_panel.gd, rewrite .tscn**

Node tree:
```
AiToolPanel (PanelContainer, custom_minimum_size=500x450)
  └─ VBox (VBoxContainer, separation=8)
      ├─ Header (HBoxContainer)
      │   ├─ Title (Label, text="AI Development Tools", font_size=18)
      │   └─ CloseBtn (Button, text="X", custom_minimum_size=32x32)
      ├─ Description (Label, autowrap=WORD_OR_CHAR, text=<description text>, font_color=UITheme.TEXT_MUTED)
      └─ ToolList (VBoxContainer)
```

**Step 2: Update ai_tool_panel.gd, run tests, commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/ui/ai_tool_panel.tscn src/ui/ai_tool_panel.gd
git commit -m "refactor: migrate AI tool panel layout to .tscn"
```

---

### Task 5: Email Panel

**Files:**
- Modify: `src/ui/email_panel.tscn`
- Modify: `src/ui/email_panel.gd`

**Step 1: Read email_panel.gd, rewrite .tscn**

Node tree:
```
EmailPanel (PanelContainer, custom_minimum_size=500x400)
  └─ VBox (VBoxContainer, separation=8)
      ├─ Header (HBoxContainer)
      │   ├─ Title (Label, text="Inbox", font_size=20)
      │   └─ CloseBtn (Button, text="X", custom_minimum_size=32x32)
      └─ Scroll (ScrollContainer, custom_minimum_size=0x300, size_flags_vertical=EXPAND_FILL)
          └─ EventList (VBoxContainer, separation=8)
```

Note: `no_mail_label` is added dynamically inside EventList when empty (in `display_events()`), so it stays in code.

**Step 2: Update email_panel.gd, run tests, commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/ui/email_panel.tscn src/ui/email_panel.gd
git commit -m "refactor: migrate email panel layout to .tscn"
```

---

### Task 6: Management Inbox

**Files:**
- Modify: `src/management/management_inbox.tscn`
- Modify: `src/management/management_inbox.gd`

**Step 1: Read management_inbox.gd, rewrite .tscn**

Node tree:
```
ManagementInbox (PanelContainer, custom_minimum_size=550x400)
  └─ VBox (VBoxContainer, separation=8)
      ├─ Header (HBoxContainer)
      │   ├─ Title (Label, text="Management Inbox", font_size=18)
      │   └─ CloseBtn (Button, text="X", custom_minimum_size=32x32)
      └─ Scroll (ScrollContainer, size_flags_vertical=EXPAND_FILL)
          └─ CardList (VBoxContainer, separation=8)
```

`_empty_label` is shown conditionally inside CardList, stays in code.

**Step 2: Update management_inbox.gd, run tests, commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/management/management_inbox.tscn src/management/management_inbox.gd
git commit -m "refactor: migrate management inbox layout to .tscn"
```

---

### Task 7: Staff Roster

**Files:**
- Modify: `src/management/staff_roster.tscn`
- Modify: `src/management/staff_roster.gd`

**Step 1: Read staff_roster.gd, rewrite .tscn**

Node tree:
```
StaffRoster (PanelContainer, custom_minimum_size=600x450)
  └─ VBox (VBoxContainer, separation=8)
      ├─ Header (HBoxContainer)
      │   ├─ Title (Label, text="Staff Roster", font_size=18)
      │   └─ CloseBtn (Button, text="X", custom_minimum_size=32x32)
      ├─ SummaryLabel (Label, font_size=14, font_color=UITheme.TEXT_MUTED)
      └─ Scroll (ScrollContainer, size_flags_vertical=EXPAND_FILL)
          └─ CardList (VBoxContainer, separation=8)
```

**Step 2: Update staff_roster.gd, run tests, commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/management/staff_roster.tscn src/management/staff_roster.gd
git commit -m "refactor: migrate staff roster layout to .tscn"
```

---

### Task 8: Hiring Board

**Files:**
- Modify: `src/management/hiring_board.tscn`
- Modify: `src/management/hiring_board.gd`

**Step 1: Read hiring_board.gd, rewrite .tscn**

Node tree:
```
HiringBoard (PanelContainer, custom_minimum_size=600x450)
  └─ VBox (VBoxContainer, separation=8)
      ├─ Header (HBoxContainer)
      │   ├─ Title (Label, text="Hiring — Job Market", font_size=18)
      │   └─ CloseBtn (Button, text="X", custom_minimum_size=32x32)
      ├─ CapacityLabel (Label, font_size=14, font_color=UITheme.TEXT_MUTED)
      ├─ Scroll (ScrollContainer, size_flags_vertical=EXPAND_FILL)
      │   └─ CardList (VBoxContainer, separation=8)
      └─ RefreshBtn (Button, text="Refresh Market", custom_minimum_size=0x36)
```

**Step 2: Update hiring_board.gd, run tests, commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/management/hiring_board.tscn src/management/hiring_board.gd
git commit -m "refactor: migrate hiring board layout to .tscn"
```

---

### Task 9: Contract Board

**Files:**
- Modify: `src/management/contract_board.tscn`
- Modify: `src/management/contract_board.gd`

**Step 1: Read contract_board.gd, rewrite .tscn**

Node tree:
```
ContractBoard (PanelContainer, custom_minimum_size=600x450)
  └─ VBox (VBoxContainer, separation=8)
      ├─ Header (HBoxContainer)
      │   ├─ Title (Label, text="Contract Board", font_size=18)
      │   └─ CloseBtn (Button, text="X", custom_minimum_size=32x32)
      ├─ TabRow (HBoxContainer, separation=4)
      │   ├─ ProjectsBtn (Button, text="Projects", custom_minimum_size=100x32)
      │   └─ RentalsBtn (Button, text="Rentals", custom_minimum_size=100x32)
      └─ Scroll (ScrollContainer, size_flags_vertical=EXPAND_FILL)
          └─ CardList (VBoxContainer, separation=8)
```

**Step 2: Update contract_board.gd, run tests, commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/management/contract_board.tscn src/management/contract_board.gd
git commit -m "refactor: migrate contract board layout to .tscn"
```

---

### Task 10: IDE Interface

The largest UI migration. The IDE has a deep node tree but it's all static layout.

**Files:**
- Modify: `src/ide/ide_interface.tscn`
- Modify: `src/ide/ide_interface.gd`

**Step 1: Read ide_interface.gd _build_ui() and _build_keyboard() carefully**

Map out every node and its properties. Pay attention to:
- MarginContainer margins (16 all sides)
- Tab bar container starts hidden
- Notification area starts hidden
- Merge view starts hidden
- Keyboard has 4 rows of buttons with specific labels and sizes
- Key buttons need to be collected into `_key_buttons` array and `_key_buttons_by_label` dict

**Step 2: Rewrite ide_interface.tscn**

Node tree (abbreviated — full tree is ~60 nodes):
```
IDEInterface (PanelContainer)
  └─ Margin (MarginContainer, margins=16)
      └─ VBox (VBoxContainer, separation=8)
          ├─ TitleBar (HBoxContainer)
          │   └─ TitleLabel (Label, text="  CONSULTANCY IDE v1.0", font_size=14)
          ├─ TabBarContainer (PanelContainer, visible=false)
          │   └─ TabBar (HBoxContainer, separation=4)
          ├─ TaskLabel (Label, text="No active task")
          ├─ StatusLabel (Label, text="IDLE")
          ├─ NotificationArea (PanelContainer, visible=false)
          │   └─ NotifVBox (VBoxContainer, separation=6)
          │       ├─ ReviewPanel (VBoxContainer, visible=false)
          │       └─ ConflictPanel (HBoxContainer, visible=false)
          ├─ CodeDisplay (RichTextLabel, bbcode=true, min_size=0x200, size_flags_v=EXPAND_FILL)
          ├─ MergeView (VBoxContainer, visible=false, size_flags_v=EXPAND_FILL)
          │   ├─ MergeColumns (HBoxContainer, size_flags_v=EXPAND_FILL, separation=4)
          │   │   ├─ LocalPanel (PanelContainer, size_flags_h=EXPAND_FILL)
          │   │   │   └─ LocalVBox (VBoxContainer)
          │   │   │       ├─ LocalTitle (Label, text="LOCAL", font_size=11, font_color=#99ccff)
          │   │   │       └─ MergeLocalDisplay (RichTextLabel, bbcode=true)
          │   │   ├─ ResultPanel (PanelContainer, size_flags_h=EXPAND_FILL)
          │   │   │   └─ ResultVBox (VBoxContainer)
          │   │   │       ├─ ResultTitle (Label, text="RESULT", font_size=11, font_color=#99ccff)
          │   │   │       └─ MergeResultDisplay (RichTextLabel, bbcode=true)
          │   │   └─ RemotePanel (PanelContainer, size_flags_h=EXPAND_FILL)
          │   │       └─ RemoteVBox (VBoxContainer)
          │   │           ├─ RemoteTitle (Label, text="REMOTE", font_size=11, font_color=#99ccff)
          │   │           └─ MergeRemoteDisplay (RichTextLabel, bbcode=true)
          │   └─ MergeBtnBar (HBoxContainer, separation=8, alignment=CENTER)
          │       ├─ MergeBtnAutomerge (Button, text="Auto-Merge (Ctrl+A)", min_size=160x36)
          │       ├─ MergeBtnLocal (Button, text="Accept Local (Ctrl+L)", min_size=160x36)
          │       ├─ MergeBtnRemote (Button, text="Accept Remote (Ctrl+R)", min_size=170x36)
          │       └─ MergeBtnBoth (Button, text="Accept Both (Ctrl+B)", min_size=160x36)
          ├─ ProgressBar (ProgressBar, min=0, max=1, step=0.01, min_size=0x24)
          └─ KeyboardPanel (PanelContainer)
              └─ KbVBox (VBoxContainer, separation=4)
                  ├─ Row1 (HBoxContainer, separation=4, alignment=CENTER)
                  │   └─ [Q,W,E,R,T,Y,U,I,O,P buttons (36x36), DEL button (44x36)]
                  ├─ Row2 (HBoxContainer, separation=4, alignment=CENTER)
                  │   └─ [A,S,D,F,G,H,J,K,L buttons (36x36), ENTER button (60x36)]
                  ├─ Row3 (HBoxContainer, separation=4, alignment=CENTER)
                  │   └─ [Z,X,C,V,B,N,M buttons (36x36)]
                  └─ Row4 (HBoxContainer, separation=4, alignment=CENTER)
                      └─ [CTRL (50x36), ALT (50x36), SPACE (200x36)]
```

**Step 3: Update ide_interface.gd**

- Replace all member vars with `@onready var X = %X` references
- Delete `_build_ui()` and `_build_keyboard()` entirely
- Delete `_build_merge_column()` (layout now in .tscn)
- Keep `_create_key_button()` — NO, buttons are now in .tscn. Instead, in `_ready()`:
  - Collect all key buttons from the keyboard rows into `_key_buttons` array
  - Build `_key_buttons_by_label` dict from button text
  - Connect each button's `pressed` signal
  - Connect keyboard panel `gui_input` signal
  - Connect merge buttons' `pressed` signals
- Move StyleBoxFlat overrides for tab bar container, notification area, keyboard panel, merge column panels to `_ready()`
- Keep all gameplay logic, signal handlers, visual update methods unchanged

**Step 4: Run tests and commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/ide/ide_interface.tscn src/ide/ide_interface.gd
git commit -m "refactor: migrate IDE interface layout to .tscn"
```

---

### Task 11: Desk Scene

**Files:**
- Modify: `src/office/desk_scene.tscn`
- Modify: `src/office/desk_scene.gd`

**Step 1: Rewrite desk_scene.tscn**

All positions use reference resolution 1152x648. Delete all `_get_vp()` viewport-relative math.

Node tree (key nodes with computed positions from reference resolution):
```
DeskScene (Control, full_rect)
  ├─ Wall (ColorRect, pos=0,0, size=1152x380, color=#404547)
  ├─ Shelf (ColorRect, pos=50,200, size=180x12, color=#73523a)
  ├─ PlantTex (TextureRect, texture=pottedPlant.png, scale=1.4)
  ├─ Desk (ColorRect, pos=0,350, size=1152x298, color=#6b4d33)
  ├─ DeskEdge (ColorRect, pos=0,350, size=1152x6, color=#7b593d)
  ├─ ChairTex (TextureRect, texture=chairDesk.png, z_index=-1, scale=1.4)
  ├─ DeskSprite (TextureRect, texture=desk.png, scale=2.2)
  ├─ StandBase (ColorRect, monitor stand)
  ├─ StandNeck (ColorRect, monitor stand)
  ├─ Bezel (ColorRect, monitor bezel)
  ├─ Screen (ColorRect, monitor screen)
  ├─ ScreenText (Label, text="Click to sit down...")
  ├─ MonitorBtn (Button, flat=true, over screen area)
  ├─ EmailBadge (Button, top-right of monitor)
  ├─ BoardFrame (ColorRect, contracts board frame)
  ├─ BoardBody (ColorRect, contracts board surface)
  ├─ PhoneGlow (ColorRect, glow indicator, visible=false)
  ├─ BoardLabel (Label, text="Contracts")
  ├─ PhoneBtn (Button, flat=true, over board area)
  ├─ BookcaseTex (TextureRect, texture=bookcaseOpen.png, scale=1.5)
  ├─ BooksLabel (Label, text="Skills")
  ├─ BooksBtn (Button, flat=true)
  ├─ CoffeeShelf (ColorRect)
  ├─ CoffeeTex (TextureRect, texture=kitchenCoffeeMachine.png, scale=1.2)
  ├─ LaptopBezel (ColorRect)
  ├─ LaptopScreen (ColorRect)
  ├─ LaptopBase (ColorRect)
  ├─ LaptopLabel (Label, text="AI Tools")
  ├─ LaptopBtn (Button, flat=true)
  ├─ DoorFrame (ColorRect)
  ├─ DoorBody (ColorRect)
  ├─ DoorHandle (ColorRect)
  ├─ DoorLabel (Label, text="Team")
  └─ DoorBtn (Button, flat=true)
```

Position calculations (from the viewport math at 1152x648):
- `mon_x = (1152 - 260) / 2 = 446`, `mon_y = 648 * (120/648) = 120`
- `desk_y = 648 * (350/648) = 350`
- Board: `board_x = 1152 * (820/1152) = 820`, `board_y = 648 * (80/648) = 80`
- Books: `books_x = 1152 * (150/1152) = 150`, `books_base_y = 648 * (420/648) = 420`
- Laptop: `laptop_x = 1152 * (680/1152) = 680`
- Door: `door_x = 1152 * (980/1152) = 980`, `door_y = 648 * (100/648) = 100`

**Step 2: Update desk_scene.gd**

- Delete `_build_ui()`, `_get_vp()`, `REF_W`, `REF_H` constants
- Add `@onready` for: `email_badge`, `phone_btn`, `phone_glow`
- Compute `monitor_rect` in `_ready()` from the MonitorBtn node's position/size (or hardcode `Rect2(446, 120, 260, 195)`)
- Connect button signals in `_ready()`: MonitorBtn→monitor_clicked, PhoneBtn→phone_clicked, etc.
- Keep zoom methods, `set_email_badge_count()`, `set_phone_glowing()` unchanged

**Step 3: Run tests and commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/office/desk_scene.tscn src/office/desk_scene.gd
git commit -m "refactor: migrate desk scene layout to .tscn"
```

---

### Task 12: Management Office

The most complex scene — isometric grid with dynamic desks and consultants.

**Files:**
- Modify: `src/management/management_office.tscn`
- Modify: `src/management/management_office.gd`

**Step 1: Read management_office.gd fully**

Understand `_build_office()`, `_build_wall_objects()`, `_build_desks()`, `refresh()`, tile grid constants, sprite positioning.

**Step 2: Identify static vs dynamic nodes**

Static (→ .tscn):
- Background ColorRect
- Floor tiles (rows 1-3, all columns)
- Wall sprites (row 0)
- Doorway sprite + back label
- Wall objects: Contracts, Hiring, Staff, Inbox, Teams (with their labels, sprites, click areas)
- Decorations (bookcase, plant)

Dynamic (stays in code):
- Desk sprites (`_build_desks()` — count depends on `GameState.desk_capacity`)
- Consultant sprites (rendered in `refresh()`)
- Chat bubbles
- Buy desk button
- Attention indicator on door

**Step 3: Rewrite management_office.tscn**

Place all static elements at their grid-computed positions. Wall objects need unique names for signal connections.

**Step 4: Update management_office.gd**

- Delete `_build_office()` and `_build_wall_objects()`
- Keep `_build_desks()` (dynamic) but rename to just have it called from `_ready()`
- `@onready` references for: back door, wall object buttons, decoration nodes
- Connect wall object click signals in `_ready()`
- Keep `refresh()`, `_build_desks()`, chat bubble system unchanged

**Step 5: Run tests and commit**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
git add src/management/management_office.tscn src/management/management_office.gd
git commit -m "refactor: migrate management office static layout to .tscn"
```

---

### Task 13: Final Verification

**Step 1: Run all tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Expected: All 176 tests pass.

**Step 2: Launch game and visual check**

```bash
godot --path /home/lars/Prosjekter/consultancy-tycoon
```

Verify:
- Welcome screen appears, buttons work
- Personal office: all furniture visible, clickable objects respond
- Monitor zoom works
- IDE displays correctly (keyboard, code area, progress bar)
- All overlay panels open/close (contracts, skills, email, AI tools)
- Management office door works
- Management office: wall objects clickable, desks visible, consultants render
- Management panels: contract board, hiring board, staff roster, inbox all work
- HUD shows money, reputation, updates correctly

**Step 3: Commit any fixes needed, then final commit**

```bash
git add -A
git commit -m "refactor: complete tscn migration — all UI layouts in scene files"
```
