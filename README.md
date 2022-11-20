# [NMRiH] Guaranteed Spawn
Grants a spawn to late-joined players who have never spawned in the current round.
Spawns are remembered so you can't exploit this by reconnecting. 

[AlliedModders thread](https://forums.alliedmods.net/showthread.php?t=335238)

## Usage:
- Press use (default: E) while spectating a teammate to spawn next to them. 
  - Note: This option expects player collisions to be off `sv_max_separation_force 0`
- Press use (default: E) while in freecam to spawn at a checkpoint

![image](https://user-images.githubusercontent.com/11559683/177451357-2ceaaa95-8f88-4aa0-bf02-f8d6cb664f4f.png)


## Installation
- [Install Sourcemod 1.11 or higher](https://wiki.alliedmods.net/Installing_sourcemod)
- Grab the latest zip from the [releases](https://github.com/dysphie/nmrih-guaranteedspawn/releases) section.
- Extract the contents into `addons/sourcemod`
- Refresh the plugin list (`sm plugins refresh` or `sm plugins load nmrih-guaranteedspawn` in server console)


## CVars

CVars are saved to `cfg/sourcemod/plugin.guaranteedspawn.txt`

- `sm_gspawn_allow_nearby` [1/0] (Default: 1)
  - Toggles spawning next to a teammate by pressing E on them while spectating

- `sm_gspawn_allow_checkpoint` [1/0] (Default: 0)
  - Toggles spawning at checkpoints by pressing E while on freecam

- `sm_gspawn_remember_steamid` [1/0] (Default: 1)
  - Toggles tracking spawned players by SteamID64

- `sm_gspawn_remember_ip` [1/0] (Default: 1)
  - Toggles tracking spawned players by IP

- `sm_gspawn_spec_target_on_join` [1/0] (Default: 1)
  - Defaults newjoiners to spectating a teammate upon joining the server, if nearby spawning is enabled.

- `sm_gspawn_spec_target_mode` [1/2] (Default: 2)
  - Camera to use if we are making newjoiners spectate a teammate on join. 1 = First person, 2 = Third person.

- `sm_gspawn_hide_seconds` [0.0 to 5.0] (Default: 1.2)
  - Hides spawned players for this many seconds, prevents spooking teammates by spawning right on their face

## Admin Commands

Commands can also be accessed via the `sm_admin` -> `Player Commands`

- `sm_givespawn <target>` - Allows the target player(s) to spawn via use (default: E)
- `sm_removespawn <target>` - Revokes the ability for target player(s) to spawn via use (default: E)

See [how to target](https://wiki.alliedmods.net/Admin_commands_(sourcemod)#How_to_Target)

## Translations

- You can translate the messages by editing `translations/guaranteedspawn.phrases.txt`
