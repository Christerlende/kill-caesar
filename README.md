# Kill Caesar

A Godot 4.6 game — early-stage prototype.

**Engine:** Godot 4.6.1 (Forward Plus rendering, Jolt Physics)  
**Language:** GDScript  
**Development environment:** VS Code + Godot Tools extension

---

## Prerequisites

Before you start, make sure you have the following installed:

| Tool | Where to get it |
|------|----------------|
| [Git](https://git-scm.com/downloads) | git-scm.com |
| [VS Code](https://code.visualstudio.com/) | code.visualstudio.com |
| [Godot Tools extension](https://marketplace.visualstudio.com/items?itemName=geequlim.godot-tools) | VS Code Marketplace — search "Godot Tools" |
| [Godot 4.6.1](https://godotengine.org/download) | godotengine.org |

---

## Getting started

### 1 — Clone the repository

Open a terminal and run:

```bash
git clone https://github.com/Christerlende/kill-caesar.git
cd kill-caesar
```

### 2 — Open the folder in VS Code

```bash
code .
```

Or open VS Code, choose **File → Open Folder…**, and select the `kill-caesar` folder.

### 3 — Check out a branch

To switch to a specific branch (for example, a feature branch you or someone else has pushed to the remote):

**Option A — using the VS Code Source Control panel (recommended for beginners)**

1. Click the **Source Control** icon in the left sidebar (the branching icon, or press `Ctrl+Shift+G`).
2. Click the branch name shown in the bottom-left status bar (e.g. `main`).
3. A dropdown appears at the top of the screen listing all local and remote branches.
4. Type or scroll to find the branch you want to work on (for example `origin/feature/my-task`) and click it.
5. If prompted *"Would you like to create a local branch?"*, click **Create local branch** to create a local tracking branch.
6. You are now on that branch and can edit files normally.

**Option B — using the integrated terminal**

1. Open the terminal in VS Code with `` Ctrl+` ``.
2. Run:

```bash
git fetch origin
git checkout -b <local-branch-name> origin/<remote-branch-name>
```

Replace `<remote-branch-name>` with the name of the remote branch you want to track (for example `feature/my-task`), and `<local-branch-name>` with the name you want to use locally (often the same).

### 4 — Connect VS Code to the Godot editor

1. Open VS Code **Settings** (`Ctrl+,`) and search for `godotTools`.
2. Set **Godot Tools: Editor Path → Godot 4** to the path of your Godot executable, for example:
   ```
   d:\Godot\Godot_v4.6.1-stable_win64.exe
   ```
   *(This is already saved in `.vscode/settings.json` for this project, so it should work automatically.)*
3. Open Godot 4.6.1, choose **Import Project**, and point it at this folder.
4. From now on, edits you make to `.gd` files in VS Code are automatically picked up by the Godot editor.

---

## Running the game

1. Open the project in the Godot editor (see step 4 above).
2. Press **F5** (or click the **▶ Play** button) to run.

---

## Project structure

```
kill-caesar/
├── scenes/
│   ├── game.tscn          ← main game scene
│   └── ui/
│       ├── main_menu.tscn ← main menu (title screen)
│       ├── main_menu.gd
│       ├── game_ui.tscn   ← in-game HUD
│       └── themes/
│           └── main_theme.tres
├── scripts/
│   ├── data/              ← data models (Player, Policy, GameState, …)
│   ├── game/              ← game logic (GameManager)
│   └── ui/                ← UI controllers (game_ui.gd)
└── assets/                ← images, fonts, sounds (add here)
```

---

## Contributing

- Only commit source files (`.gd`, `.tscn`, `.gdshader`, `.tres`).
- Do **not** commit generated files (`.godot/`, `.import`).
- Use clear commit messages: `Add player movement`, `Fix election bug`, etc.
- Create feature branches off `main` and open a pull request when ready.
