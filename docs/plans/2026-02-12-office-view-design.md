# Office View Design — Phase 1 Desk View

## Overview

Replace the current tab-based navigation (IDE/Contracts/Skills) with a first-person desk view. The player looks at their desk and interacts with objects to access game systems. The perspective evolves across game phases:

1. **Phase 1 (Clicker)**: First-person desk view — solo dev at their desk
2. **Phase 2 (Semi-idle)**: Side-view diorama — see the whole office, walk to coffee machine
3. **Phase 3 (Management)**: Top-down — manage the floor, assign hires to contracts

This document covers Phase 1 only.

## Desk Layout

Fixed 2D scene, no camera movement. Bottom-to-top (near-to-far on desk):

- **Bottom**: Keyboard grid (existing clicker mechanic, only interactive when sitting at computer)
- **Left**: Coffee mug (decorative), stack of programming books (click to open skills)
- **Center**: Monitor on stand — shows idle desktop, click to zoom into IDE
- **Right**: Phone on desk — glows when contracts available, click to open bidding overlay
- **Background**: Wall with shelf, plant. Monitor shows email notification badge for random events.

## Interactions

### Monitor (IDE)
- Click monitor to "sit down" — view zooms into the monitor via tween
- Monitor bezel stays visible as frame around the IDE
- Click bezel edge or "stand up" button to zoom back out
- Keyboard grid becomes active only when zoomed in

### Phone (Contracts)
- Glows/animates when new contract offers arrive
- Click opens bidding panel as overlay on top of desk view
- Accept contract → phone closes, monitor shows task ready
- Close overlay to return to desk

### Books (Skills)
- Click book stack to open skill/course panel as overlay
- Browse and purchase skills, close to return to desk
- Skills can also be accessed via a browser tab when zoomed into monitor

### Email (Random Events)
- Red notification badge on monitor visible from desk view
- Badge number grows as events accumulate
- Click opens email client overlay with random events:
  - Recruiter message (+reputation)
  - Stack Overflow viral answer (free skill XP)
  - Rush job offer (2x pay, 2x difficulty)
  - Tax season (pay money)
  - Conference invite (pay to attend, get skill boost)

## Technical Approach

### Scene Structure
- `OfficeView` (Node2D) — root of the desk scene
  - `DeskBackground` (Sprite2D/ColorRect) — desk surface and wall
  - `Monitor` (Area2D + Sprite2D) — clickable, zoom target
  - `Phone` (Area2D + Sprite2D) — clickable, glow animation
  - `Books` (Area2D + Sprite2D) — clickable
  - `CoffeeMug` (Sprite2D) — decorative
  - `EmailBadge` (Label/Sprite2D) — notification counter on monitor

### Main Scene Changes
- `main.gd` becomes the office orchestrator instead of tab switcher
- Office view is the default scene (replaces tab nav)
- IDE, bidding, skills panels become overlays managed by main
- Camera2D handles the zoom transition to monitor

### Zoom Transition
- Camera2D tweens position and zoom to focus on monitor area
- ~0.3s ease-in-out transition
- IDE content renders inside the monitor's screen area
- Reverse tween to zoom back out

### Overlays
- Phone/books/email open panels as CanvasLayer overlays
- Semi-transparent background behind overlay to dim desk
- Close button or click-outside to dismiss

### Art
- Start with simple ColorRect/polygon shapes for desk, monitor, objects
- Can be replaced with proper sprites later
- Distinct colors per interactive object for clarity

## What Changes

- `src/main.gd` — rewrite from tab switcher to office orchestrator
- `src/main.tscn` — new scene structure with office view
- New: `src/office/office_view.gd` — desk scene with clickable objects
- New: `src/office/office_view.tscn` — desk scene layout
- `src/ide/ide_interface.gd` — no changes, becomes overlay content
- `src/ui/bidding_panel.gd` — no changes, becomes overlay content
- `src/ui/skill_panel.gd` — no changes, becomes overlay content
- New: `src/data/random_event.gd` — event data model
- New: `src/ui/email_panel.gd` — email overlay UI
- `src/autoload/event_bus.gd` — add random event signals

## Not In Scope
- Phase 2/3 perspective changes (future work)
- Animated sprites or pixel art (use placeholders)
- Coffee mug interaction
- Sound effects
