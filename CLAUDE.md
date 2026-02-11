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

### Logic (pure classes, no Node dependency)
- **CodingLoop** (`src/logic/coding_loop.gd`) — State machine: IDLE → WRITING → REVIEWING → (FIXING/CONFLICT) → COMPLETE. Core gameplay engine.
- **BiddingSystem** (`src/logic/bidding_system.gd`) — Generates contracts, calculates bid success chance and difficulty modifiers.
- **SkillManager** (`src/logic/skill_manager.gd`) — Manages 7 skills, handles purchases, calculates stat bonuses (click power, review bonus, bid bonus).
- **TaskFactory** (`src/data/task_factory.gd`) — Generates random CodingTask instances scaled by tier.

### UI Scenes
- **Main** (`src/main.tscn`) — Root scene. View switching (IDE/Contracts/Skills), contract flow orchestration, HUD.
- **IDEInterface** (`src/ide/ide_interface.tscn`) — Fake IDE with code display, progress bar, review comments, merge conflict picker.
- **BiddingPanel** (`src/ui/bidding_panel.tscn`) — Shows contract offers with bid chance and bid buttons. Emits `contract_accepted` signal.
- **SkillPanel** (`src/ui/skill_panel.tscn`) — Skill purchase UI with dynamic pricing.
- **HUD** (`src/ui/hud.tscn`) — Money, reputation, task info display. Listens to EventBus signals.

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

Current test coverage: 36 tests across game state, coding task, coding loop, bidding system, and skill system.

## Game Design

Full design document: `docs/plans/2026-02-11-game-design.md`
Phase 1 implementation plan: `docs/plans/2026-02-11-phase1-mvp.md`
