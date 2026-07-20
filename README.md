# TrioJam

Godot 4 narrative side-scroller for a three-person game-jam team.

## First scene: Fire Exit

The current main scene is a cinematic 2.5D fire-exit stairwell based on the team's layout sketch.

- Move with `A` and `D`, or the Left and Right arrow keys.
- Press `E` or `Space` to confirm and interact.
- Press `R` at any time to restart.

The scene includes switchback stair collisions, cinematic camera framing, foreground parallax, generated environment and character art, an animated four-frame walk cycle, normal maps, dynamic practical lights, ambient dust, contextual UI, interaction beats, and fall recovery.

The original generated runtime assets and their derived normal maps are stored under `assets/art/`. Keep replacement art aligned to the existing 16:9 composition and atlas regions.

## Current vertical slice

The connected playable sequence is now:

1. `Scene0` — climb the fire-exit stairwell and enter the rooftop door.
2. `Scene1` — cross the rooftop, execute the plan, and shoulder the makeshift rifle.
3. `Scene2` — aim through the scope, reject non-target office workers, and identify the smoking official on the balcony.
4. `Broadcast Interface` — construct the government-mandated Cause / Conflict / Outcome report from the shooting.

Scene2 uses mouse movement to aim and the left mouse button to fire. Its scope mask deliberately leaves the peripheral view visible at lower opacity.

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
