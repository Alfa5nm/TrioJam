# TrioJam

Placeholder Godot 4 project for a three-person game-jam team.

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
