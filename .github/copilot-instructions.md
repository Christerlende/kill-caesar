# Kill Caesar - GitHub Copilot Instructions

**Project**: Kill Caesar (Godot 4.6 Game)  
**Status**: Early-stage prototype  
**Engine**: Godot 4.6.1 (Forward Plus rendering, Jolt Physics)  
**Language**: GDScript  
**Development Environment**: VS Code + Godot Tools

## Core Principles

1. **Keep it simple** — This is a fresh project. Avoid over-architecting. Start with minimal game systems and expand incrementally.
2. **Separate concerns** — Keep game logic separate from UI logic (e.g., gameplay in `game/`, UI in `ui/`).
3. **Clear naming** — Use descriptive, self-documenting names for functions, variables, and files.
4. **Beginner-friendly** — Prioritize readable, maintainable GDScript over clever optimizations.
5. **Incremental changes** — Make small, focused changes. Test frequently in the Godot editor.

## 3D Game Development Focus

This project is configured for **3D game development**:
- **Physics**: Jolt Physics 3D engine (`3d/physics_engine="Jolt Physics"`)
- **Rendering**: D3D12 on Windows
- **Scope**: Game likely involves 3D mechanics and combat (based on "Kill Caesar" title)

**When suggesting features:**
- Default to 3D nodes (`Node3D`, `MeshInstance3D`, `CollisionShape3D`)
- Use 3D physics bodies for game objects
- Consider camera and mouse input for player control

## GDScript Conventions

### Naming & Style
- **Methods**: `snake_case` (e.g., `_ready()`, `take_damage()`)
- **Variables**: `snake_case` (e.g., `health_points`, `is_alive`)
- **Classes**: `PascalCase` (e.g., `Player`, `Enemy`)
- **Constants**: `CONSTANT_CASE` (e.g., `MAX_HEALTH`)
- **Lifecycle hooks**: Use standard Godot patterns (`_ready()`, `_process()`, `_physics_process()`)

### File Organization (Proposed)
```
kill-caesar/
├── scenes/
│   ├── player/
│   │   ├── player.tscn
│   │   └── player.gd
│   ├── enemies/
│   │   └── (enemy scenes)
│   └── ui/
│       └── (UI scenes)
├── scripts/
│   ├── game/
│   │   └── (game systems)
│   └── utils/
│       └── (helpers)
└── assets/
    └── (3D models, textures, sound)
```
*Implement folder structure as needed; start minimal.*

## Development Workflow

### Running the Game
1. Open Godot editor at `d:\Godot\Godot_v4.6.1-stable_win64.exe`
2. Open the project root (`d:\My Games\kill-caesar`)
3. Press **F5** to run, or click Play in the editor UI
4. Edit scripts in VS Code; Godot will auto-reload them

### Git & Version Control
- `.gitignore` is configured for Godot (excludes `.godot/`, `/android/`, etc.)
- **Important**: Commit `.tscn` and `.gd` files, not generated `.import` files
- Use clear commit messages (e.g., "Add player movement", "Implement enemy AI")

### Code Quality
- EditorConfig enforces UTF-8 and LF line endings
- Keep scripts under ~300 lines; split large systems into multiple files
- Use comments sparingly; prioritize clear code over commentary

## Common Patterns

### Signal-Based Communication
```gdscript
signal health_changed(new_health)

func take_damage(amount: int) -> void:
    health -= amount
    emit_signal("health_changed", health)
```

### Game Manager Pattern
Create a single-instance manager for game state if needed:
```gdscript
extends Node

var game_state = {}  # Simple dictionary for shared state
```

### Input Handling
Use Godot's Input system for player controls:
```gdscript
func _process(delta: float) -> void:
    if Input.is_action_pressed("ui_right"):
        move_right()
```

## Anti-Patterns to Avoid

❌ **Don't**: Store all game logic in one massive script  
✅ **Do**: Split into focused scene-based scripts

❌ **Don't**: Use tightly-coupled references (hardcoded node paths)  
✅ **Do**: Use signals or dependency injection for communication

❌ **Don't**: Ignore the editor — edit `.tscn` files directly  
✅ **Do**: Use Godot's visual editor for scene organization

❌ **Don't**: Commit generated files (`.import`, `.godot/`)  
✅ **Do**: Only commit source files (`.gd`, `.tscn`, `.gdshader`)

## Before Implementing Features

When you propose a new feature:
1. **Explain** which files will be created/modified
2. **Show** the scene structure (new nodes, hierarchy)
3. **Describe** how game systems will communicate (signals, managers)
4. **Keep changes small** — one feature per implementation

Example:
> **Feature: Player Movement**
> - Create `scenes/player/player.tscn` with a CharacterBody3D node
> - Create `scenes/player/player.gd` with input handling
> - Add WASD controls in `_process()` with velocity-based movement

## Data Structures & Inspection

Keep game data structures simple and inspectable in the Godot editor:

```gdscript
var player_stats = {
    "health": 100,
    "max_health": 100,
    "damage": 10
}
```

Rather than complex nested classes, use dictionaries or @export variables so designers can tweak values in the editor UI.

## Questions & Iteration

If any part of these instructions is unclear or needs expansion, ask. As the project grows, we can refine:
- Asset organization structure
- Specific game systems (combat, dialogue, levels)
- UI framework decisions
- Save/load patterns

---

**Last Updated**: 2026-03-12  
**Godot Version**: 4.6.1  
**Project Stage**: Early Prototype
