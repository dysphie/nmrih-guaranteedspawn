/** Double-include prevention */
#if defined _guaranteedspawn_included_
  #endinput
#endif
#define _guaranteedspawn_included_

enum GSMethod
{
	GSMethod_Checkpoint,
	GSMethod_Nearby
}

/**
 * Called when a client is about to spawn via their guaranteed spawn
 *
 * @param client      Entity index of the spawning client.
 * @param method      Method by which they're spawning
 * @return            Plugin_Handled to prevent spawning
 */
forward Action GS_OnGuaranteedSpawn(int client, GSMethod method);