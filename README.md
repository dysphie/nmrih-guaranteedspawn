# [NMRiH] Guaranteed Spawn
Grants a spawn to late-joined players who have never spawned in the current round.

**This does not grant infinite respawns**

[AlliedModders thread](https://forums.alliedmods.net/showthread.php?t=335238)

## Usage:
- Press use (E) while spectating a teammate to spawn next to them. 
  - Note: This option expects player collisions to be off `sv_max_separation_force 0`
- Press use (E) while in freecam to spawn at a checkpoint

![image](https://user-images.githubusercontent.com/11559683/177451357-2ceaaa95-8f88-4aa0-bf02-f8d6cb664f4f.png)


Players are tracked internally so you cannot exploit the feature by reconnecting. 

## Installation
- [Install Sourcemod](https://wiki.alliedmods.net/Installing_sourcemod)
- Install [DHooks2](https://github.com/peace-maker/DHooks2/releases) if running Sourcemod older than 1.11.6820
- Grab the latest zip from the [releases](https://github.com/dysphie/nmrih-guaranteedspawn/releases) section.
- Extract the contents into `addons/sourcemod`
- Refresh the plugin list (`sm plugins refresh` or `sm plugins load nmrih-guaranteedspawn` in server console)


## CVars

CVars are saved to `cfg/sourcemod/plugin.guaranteedspawn.txt`

- `sm_gspawn_allow_nearby` [1/0] (Default: 1)
  - Toggles spawning next to a teammate by pressing E on them while spectating

- `sm_gspawn_allow_checkpoint` [1/0] (Default: 1)
  - Toggles spawning at checkpoints by pressing E while on freecam (or when `sm_gspawn_allow_checkpoint` is unavailable)

## Translations

- You can translate the messages by editing `translations/guaranteedspawn.phrases.txt`
