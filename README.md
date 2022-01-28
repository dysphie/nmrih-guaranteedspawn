# [NMRiH] Guaranteed Spawn
Grants a spawn to late-joined players who have never spawned in the current round.

[AlliedModders thread](https://forums.alliedmods.net/showthread.php?t=335238)

## Usage:
- Press use (E) while spectating a teammate to spawn next to them. 
  - Note: This option expects player collisions to be off `sv_max_separation_force 0`
- Press use (E) while in freecam to spawn at a checkpoint

<img src="https://user-images.githubusercontent.com/11559683/142298367-6d55cbab-b9b8-45fc-98be-920642b1f8da.png" data-canonical-src="https://gyazo.com/eb5c5741b6a9a16c692170a41a49c858.png" width="70%" height="70%" />


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
