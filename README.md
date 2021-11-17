# [NMRiH] Guaranteed Spawn
Grants a spawn to late-joined players who have never spawned in the current round.

Usage:
- Press use (E) while spectating a teammate to spawn next to them
- Press use (E) while in freecam to spawn at a checkpoint

Players are tracked internally so you cannot exploit the feature by reconnecting. 

## CVars

CVars are saved to `cfg/sourcemod/plugin.guaranteedspawn.txt`

- `sm_gspawn_allow_nearby` [1/0]
  - Toggles spawning next to a teammate by pressing E on them while spectating

- `sm_gspawn_allow_checkpoint` [1/0]
  - Toggles spawning at checkpoints by pressing E while on freecam (or when `sm_gspawn_allow_checkpoint` is disabled)
