# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Kill Caesar is a Godot 4.6.1 game (GDScript). It is a single-product repo with no backend, database, or external services. See `README.md` for project structure and contributor guidelines.

### Running the game

- **Engine**: Godot 4.6.1 is installed at `/usr/local/bin/godot`
- **Run GUI**: `Xvfb :99 -screen 0 1600x900x24 &` then `DISPLAY=:99 godot` from the project root
- **Import only (headless)**: `godot --headless --import` — reimports assets without opening the editor
- The main scene is `scenes/ui/main_menu.tscn`; pressing F5 or running `godot` with no flags launches it

### Validating GDScript

There is no separate linter or test framework. Validate scripts with:

```
godot --headless --check-only --script <path-to-file.gd>
```

Run on all files:

```
find . -name "*.gd" -exec godot --headless --check-only --script {} \;
```

### Online multiplayer

The game uses Godot's `ENetMultiplayerPeer` for P2P networking. The `NetworkManager` is registered as an autoload in `project.godot`. Architecture: host runs all game logic authoritatively; clients send actions via RPC, host validates and broadcasts state snapshots. Empty seats are filled by AI. Key files: `scripts/network/network_manager.gd`, `scripts/network/online_setup.gd`, `scripts/network/lobby.gd`.

### Known caveats in Cloud VMs

- **Audio**: Godot logs PulseAudio/ALSA errors because Cloud VMs have no sound card. These are harmless — the engine falls back to a dummy audio driver.
- **xdotool clicks**: Synthetic mouse events from `xdotool` are not reliably picked up by Godot on Xvfb. Use the `computerUse` subagent for GUI interaction, or use keyboard navigation (Tab + Enter).
- **GPU rendering**: The VM uses Mesa llvmpipe (software rendering). The game renders correctly but may be slower than on real hardware.
- **imagemagick `import`**: Useful for quick screenshots: `DISPLAY=:99 import -window root screenshot.png`
