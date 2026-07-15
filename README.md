# TrioJam

Placeholder Godot 4 project for a three-person game-jam team.

## Placeholder side-scroller

The current main scene is a playable Day 1 blockout:

- Move with `A` and `D`.
- Jump with `Space` or `W`.
- Press `E` near orange report markers to collect them.
- Deliver both reports to the City News building at the end of the level.
- Press `R` at any time to restart.

The blockout includes camera follow, reusable player movement, collisions, a platforming gap, fall recovery, report interactions, a locked objective, and a completion screen. Visuals are intentionally made from primitive shapes so art can be replaced independently.

## Open the project

Import `project.godot` from the Godot Project Manager, or run:

```powershell
& 'D:\Softwares\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --editor --path 'D:\Gamejam\TrioJam'
```

## Suggested ownership

- Member 1: gameplay code and reusable gameplay scenes
- Member 2: levels, world scenes, and UI
- Member 3: art, animation, audio, and integration

Avoid editing the same `.tscn` file at the same time. Build features as separate scenes, then instance them into the main or level scenes.

## Git rhythm

1. Pull before starting work.
2. Create a short-lived feature branch.
3. Commit small, working changes.
4. Pull and resolve conflicts before merging.
5. Push frequently during the jam.

Do not commit the `.godot/` cache directory. Consider Git LFS if the project gains large source-art, audio, or video files.
