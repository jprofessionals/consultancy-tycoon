# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Consultancy-tycoon is a tycoon/management simulation game built with **Godot 4.6** using **GDScript**. The project uses GL Compatibility rendering and Jolt Physics for 3D physics.

## Development Commands

```bash
# Open project in Godot editor
godot --path /home/lars/Prosjekter/consultancy-tycoon

# Run the game from CLI (requires a main scene to be set)
godot --path /home/lars/Prosjekter/consultancy-tycoon --quit-after 0

# Run a specific scene
godot --path /home/lars/Prosjekter/consultancy-tycoon res://path/to/scene.tscn
```

No external build tools, package managers, or test frameworks are configured yet.

## Godot Project Configuration

- **Engine:** Godot 4.6
- **Language:** GDScript
- **Rendering:** GL Compatibility (mobile and desktop)
- **Physics:** Jolt Physics (3D)
- **Windows rendering:** D3D12

## Godot Conventions

- Scenes are `.tscn` files, resources are `.tres` files, scripts are `.gd` files
- The `.godot/` directory is auto-generated cache — never edit or commit it
- `project.godot` is the main config file; prefer editing via the Godot editor UI
- Global state uses autoload singletons registered in `project.godot` under `[autoload]`
- Node communication uses Godot's signal system (`signal`, `emit_signal`, `connect`)
- Use `@export` for editor-visible properties, `@onready` for node references
