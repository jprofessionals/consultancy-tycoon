# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Consultancy Tycoon is an idle/incremental game where you grow from a solo freelance developer into a consulting empire. Built with **Godot 4.6** using **GDScript**. GL Compatibility rendering, Jolt Physics.

## Development Commands

```bash
# Run the game
godot --path /home/lars/Prosjekter/consultancy-tycoon

# Run tests (GUT v9.5.0)
godot --headless -s addons/gut/gut_cmdln.gd

# Re-register class_name declarations after adding new ones
godot --headless --import

# Open in Godot editor
godot --path /home/lars/Prosjekter/consultancy-tycoon --editor
```

## Architecture

### Autoloads (registered in project.godot)
- **EventBus** (`src/autoload/event_bus.gd`) — Signal hub for decoupled communication. All cross-system signals go here.
- **GameState** (`src/autoload/game_state.gd`) — Global state: money, reputation, skills dictionary. Emits EventBus signals on mutation.

### Data Models (Resource classes)
- **CodingTask** (`src/data/coding_task.gd`) — A single coding task with difficulty, payout, click requirements, review/conflict chance calculations.
- **ClientContract** (`src/data/client_contract.gd`) — A client contract with tier, task count, payout, skill requirements.
- **SkillData** (`src/data/skill_data.gd`) — A purchasable skill with exponential cost scaling.
- **MergeConflict** (`src/data/merge_conflict.gd`) — Multi-chunk merge conflict with base lines, conflict chunks, resolution tracking, merged output.
- **ConflictChunk** (`src/data/conflict_chunk.gd`) — Single conflict hunk: local lines, remote lines, optional correct resolution.
- **MergeConflictFactory** (`src/data/merge_conflict_factory.gd`) — Generates merge conflicts: algorithmic (easy, any-valid) + curated (tricky, one correct answer). Tier-scaled chunk count.
- **ConsultantData** (`src/data/consultant_data.gd`) — Consultant with skills, salary, trait, morale, location (IN_OFFICE/REMOTE/ON_PROJECT/ON_RENTAL), training state.
- **ConsultantRental** (`src/data/consultant_rental.gd`) — A rental placement with duration, rate, extension window tracking.
- **ConsultantAssignment** (`src/data/consultant_assignment.gd`) — A team project assignment with progress tracking.

### Logic (pure classes, no Node dependency)
- **CodingLoop** (`src/logic/coding_loop.gd`) — State machine: IDLE → WRITING → REVIEWING → (FIXING/CONFLICT) → COMPLETE. Core gameplay engine.
- **BiddingSystem** (`src/logic/bidding_system.gd`) — Generates contracts (personal tier 1-2, management tier 2+), calculates bid success chance and difficulty modifiers.
- **SkillManager** (`src/logic/skill_manager.gd`) — Manages 7 skills, handles purchases, calculates stat bonuses (click power, review bonus, bid bonus).
- **TaskFactory** (`src/data/task_factory.gd`) — Generates random CodingTask instances scaled by tier.
- **ConsultantManager** (`src/logic/consultant_manager.gd`) — Hiring, training (passive/active), rentals, assignments, salary, management issues.

### Personal Office (side-view)
- **Main** (`src/main.tscn`) — Root scene. Scene switching between personal office and management office, HUD, timers.
- **DeskScene** (`src/office/desk_scene.tscn`) — Side-view desk with clickable objects (monitor, phone, books, email, laptop, door).
- **IDEInterface** (`src/ide/ide_interface.tscn`) — Fake IDE with code display, progress bar, review comments, three-panel merge view (LOCAL|RESULT|REMOTE).
- **BiddingPanel** (`src/ui/bidding_panel.tscn`) — Shows personal contract offers (tier 1-2) with bid chance and bid buttons.
- **SkillPanel** (`src/ui/skill_panel.tscn`) — Skill purchase UI with dynamic pricing.
- **HUD** (`src/ui/hud.tscn`) — Money, reputation, task info display. Listens to EventBus signals.

### Management Office (top-down, unlocked via door)
- **ManagementOffice** (`src/management/management_office.tscn`) — Top-down office floor with desk grid, consultant sprites, chat bubbles, interactive wall objects.
- **ContractBoard** (`src/management/contract_board.tscn`) — Projects (tier 2+) and rental offers. Assign consultants.
- **HiringBoard** (`src/management/hiring_board.tscn`) — Job market, candidate cards, hire buttons. Staff capped at 3x desk capacity.
- **StaffRoster** (`src/management/staff_roster.tscn`) — All consultants with status, training controls, remote toggle, fire button.
- **ManagementInbox** (`src/management/management_inbox.tscn`) — Rental extension notifications and management issues.

### Key Patterns
- **Logic/UI separation** — Logic classes extend RefCounted, take state as parameters, are fully testable. UI scenes reference autoloads directly.
- **Programmatic UI** — All UI is built in `_build_ui()` methods from minimal .tscn files. No complex scene trees.
- **Signal-driven** — EventBus for global events, CodingLoop has its own signals for UI binding.
- **GameState in tests** — Tests create standalone GameState instances (not the autoload). GameState uses `_get_event_bus()` helper that returns null safely in test environments.

## Testing

Tests use GUT v9.5.0. Test files in `test/unit/`, prefixed with `test_`, extend `GutTest`.

```bash
# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd

# Config in .gutconfig.json
```

Current test coverage: 176 tests across game state, coding task, coding loop, merge conflicts, bidding system, skill system, consultant state, rentals, training, contract tiers, and save/load.

## Game Design

Full design document: `docs/plans/2026-02-11-game-design.md`
Phase 1 implementation plan: `docs/plans/2026-02-11-phase1-mvp.md`
Management rework design: `docs/plans/2026-02-12-management-rework-design.md`
Merge conflict rework design: `docs/plans/2026-02-12-merge-rework-design.md`
