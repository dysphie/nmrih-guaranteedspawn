#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#define MAXPLAYERS_NMRIH 9

#define STEAMID_LEN 21
#define GAME_TYPE_NMO 0
#define GAME_TYPE_NMS 1
#define ROUND_STATE_ONGOING 3
#define PLAYER_STATE_ACTIVE 0

public Plugin myinfo = {
    name        = "[NMRiH] Guaranteed Spawn",
    author      = "Dysphie",
    description = "Grants a spawn to players who've never spawned in the active round",
    version     = "1.0.0",
    url         = "https://github.com/dysphie/nmrih-guaranteedspawn"
};


enum {
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_POI,		// PASSTIME point of interest - game objective, big fight, anything interesting; added in the middle of the enum due to tons of hard-coded "<ROAMING" enum compares
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES,
};

Handle sdkSpawnPlayer;

float nextHintTime[MAXPLAYERS_NMRIH+1] = {-1.0, ...};
float spawnShieldTime[MAXPLAYERS_NMRIH+1] = {-1.0, ...};

// Tracks entity indexes spawned this round
bool spawnedThisRound[MAXPLAYERS_NMRIH+1] = { false, ...}; 

 // Tracks steam IDs spawned this round
ArrayList steamSpawnedThisRound;

int spawningPlayer = -1;
DynamicHook fnGetPlayerSpawnSpot;

int gameType;
int gameState;

Handle hudSync;

int numSpawnpoints = 0;

ConVar cvAllowDefault;
ConVar cvAllowNearby;

int offs_SpawnEnabled = -1;

bool lateloaded = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	lateloaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("guaranteedspawn.phrases");

	cvAllowDefault = CreateConVar("sm_gspawn_allow_checkpoint", "1");
	cvAllowNearby = CreateConVar("sm_gspawn_allow_nearby", "1");

	GameData gamedata = new GameData("guaranteedspawn.games");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CNMRiH_Player::Spawn");
	sdkSpawnPlayer = EndPrepSDKCall();
	if (!sdkSpawnPlayer)
	{
		SetFailState("Failed to set up SDKCall for CNMRiH_Player::Spawn");
	}

	offs_SpawnEnabled = gamedata.GetOffset("CNMRiH_PlayerSpawn::m_bEnabled");
	if (offs_SpawnEnabled == -1)
	{
		SetFailState("Failed to get offset to CNMRiH_PlayerSpawn::m_bEnabled");
	}

	int offs_GetPlayerSpawnSpot = gamedata.GetOffset("CGameRules::GetPlayerSpawnSpot");
	if (offs_GetPlayerSpawnSpot == -1) 
	{
		SetFailState("Failed to get offset to CGameRules::GetPlayerSpawnSpot");
	}

	delete gamedata;

	fnGetPlayerSpawnSpot = new DynamicHook(offs_GetPlayerSpawnSpot, HookType_GameRules, ReturnType_CBaseEntity, ThisPointer_Ignore);
	fnGetPlayerSpawnSpot.AddParam(HookParamType_CBaseEntity);   // CBasePlayer *, player

	steamSpawnedThisRound = new ArrayList(ByteCountToCells(STEAMID_LEN));

	hudSync = CreateHudSynchronizer();
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("nmrih_reset_map", OnMapReset, EventHookMode_PostNoCopy);
	HookEvent("state_change", OnStateChange);

	HookEntityOutput("info_player_nmrih", "OnEnable", OnSpawnpointEnabled);
	HookEntityOutput("info_player_nmrih", "OnDisable", OnSpawnpointDisabled);

	if (lateloaded)
	{	
		int e = -1;
		while ((e = FindEntityByClassname(e, "info_player_nmrih")) != -1)
		{
			OnSpawnpointSpawned(e);
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				OnPlayerSpawned(i);
			}
		}

		// HACK: Make IsRoundOnGoing return true since we can't fetch the real state rn
		gameState = ROUND_STATE_ONGOING;
		gameType = GAME_TYPE_NMO;
	}

	CreateTimer(0.2, NotifyDead, _, TIMER_REPEAT);
}

public void OnMapStart()
{
    fnGetPlayerSpawnSpot.HookGamerules(Hook_Pre, Detour_GetPlayerSpawnSpot);
}

/**
 * CBasePlayer::Spawn calls CGameRules::GetPlayerSpawnSpot and if it returns 0
 * it sends the player back to observer mode. We bypass that by giving it a valid entity.
 * It's not used so we can just pass it any valid entity, like the player
 */
MRESReturn Detour_GetPlayerSpawnSpot(DHookReturn ret)
{
	if (spawningPlayer != -1)
	{	
		ret.Value = spawningPlayer;
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

public void OnClientAuthorized(int client)
{
	nextHintTime[client] = -1.0;
	spawnedThisRound[client] = false;

	char steamid[STEAMID_LEN];
	if (GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid)))
	{
		if (steamSpawnedThisRound.FindString(steamid) != -1)
		{
			spawnedThisRound[client] = true;
		}	
	}
}

void OnMapReset(Event event, const char[] name, bool silent)
{
	steamSpawnedThisRound.Clear();
	for (int i = 1; i <= MaxClients; i++) 
	{
		spawnedThisRound[i] = false;
	}
}

void OnStateChange(Event event, const char[] name, bool silent)
{
	gameType = event.GetInt("game_type");
	gameState = event.GetInt("state");
}

void Event_PlayerSpawn(Event event, const char[] name, bool silent)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && NMRiH_IsPlayerAlive(client))
	{
		OnPlayerSpawned(client);
	}
}

void OnPlayerSpawned(int client)
{	
	spawnedThisRound[client] = true;
	
	char steamid[STEAMID_LEN];
	if (GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid)))
	{
		steamSpawnedThisRound.PushString(steamid);	
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "info_player_nmrih"))
	{
		SDKHook(entity, SDKHook_Spawn, OnSpawnpointSpawned);
	}
}

public void OnEntityDestroyed(int entity)
{
	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));

	if (StrEqual(classname, "info_player_nmrih") && IsSpawnpointEnabled(entity))
	{
		numSpawnpoints--;
	}
}

Action OnSpawnpointSpawned(int spawnpoint)
{
	if (IsSpawnpointEnabled(spawnpoint)) 
	{
		numSpawnpoints++;
	}
	return Plugin_Continue;
}

void OnSpawnpointEnabled(const char[] output, int spawnpoint, int activator, float delay)
{
	if (IsSpawnpointEnabled(spawnpoint)) 
	{
		numSpawnpoints++;
	}
}

void OnSpawnpointDisabled(const char[] output, int spawnpoint, int activator, float delay)
{
	if (!IsSpawnpointEnabled(spawnpoint)) 
	{
		numSpawnpoints--;
	}
}

Action NotifyDead(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !CouldPlayerSpawn(i))
		{
			continue;
		}

		if (cvAllowNearby.BoolValue)
		{
			int target = GetRespawnTarget(i);
			if (target != -1)
			{
				ShowRespawnText(i, "%T", "Respawn At Teammate", target, i);
				continue;
			}
		}

		if (cvAllowDefault.BoolValue)
		{
			ShowRespawnText(i, "%T", "Respawn At Checkpoint", i);
			continue;
		}
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if ((buttons & IN_USE) && CouldPlayerSpawn(client))
	{
		if (cvAllowNearby.BoolValue)
		{
			int target = GetRespawnTarget(client);
			if (target != -1)
			{
				NearbySpawn(client, target);
				return Plugin_Continue;
			}
		}

		if (cvAllowDefault.BoolValue && numSpawnpoints > 0)
		{
			DefaultSpawn(client);
		}
	}

	return Plugin_Continue;
}

bool CouldPlayerSpawn(int client)
{
	if (spawnedThisRound[client] || !IsRoundOnGoing())
	{
		return false;
	}

	char authid[21];
	return GetClientAuthId(client, AuthId_SteamID64, authid, sizeof(authid)) && 
		steamSpawnedThisRound.FindString(authid) == -1;
}

bool IsRoundOnGoing()
{
	return gameState == ROUND_STATE_ONGOING && (gameType == GAME_TYPE_NMO || gameType == GAME_TYPE_NMS);
}

void ShowRespawnText(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);

	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);

	SetHudTextParams(-1.0, 0.01, 1.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, hudSync, buffer);
}

int GetRespawnTarget(int client)
{
	int obsMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
	if (obsMode == OBS_MODE_ROAMING || obsMode == OBS_MODE_DEATHCAM)
	{
		return -1;
	}

	int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	return (target != client && 0 < target <= MaxClients) ? target : -1;
}

void ForceSpawn(int client, float origin[3], float angles[3])
{
	spawningPlayer = client;
	SetEntProp(client, Prop_Send, "m_iPlayerState", 0);
	SDKCall(sdkSpawnPlayer, client);
	spawningPlayer = -1;	

	TeleportEntity(client, origin, angles, NULL_VECTOR);
}

void DefaultSpawn(int client)
{
	int e = -1;

	float pos[3], ang[3];
	int closestSpawn = -1;
	float leastDistance = 999999.9;

	while ((e = FindEntityByClassname(e, "info_player_nmrih")) != -1)
	{
		if (!IsSpawnpointEnabled(e)) {
			continue;
		}
		
		GetEntityPosition(e, pos);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (i != client && IsClientInGame(i) && NMRiH_IsPlayerAlive(i))
			{
				float teammatePos[3];
				GetClientAbsOrigin(i, teammatePos);

				float dist = GetVectorDistance(teammatePos, pos);
				if (dist < leastDistance)
				{
					closestSpawn = e;
					leastDistance = dist;
					GetEntityRotation(e, ang);
				}
			}
		}
	}

	if (closestSpawn != -1)
	{
		ForceSpawn(client, pos, ang);
	}
}

void GetEntityPosition(int entity, float pos[3])
{
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);
}

void GetEntityRotation(int entity, float angles[3])
{
	GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", angles);
}

bool NMRiH_IsPlayerAlive(int client)
{
	return IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_iPlayerState") == PLAYER_STATE_ACTIVE;
}


bool IsSpawnpointEnabled(int spawnpoint)
{
	return view_as<bool>(GetEntData(spawnpoint, offs_SpawnEnabled, 1));
}

void NearbySpawn(int client, int target)
{
	// TODO: Currently it just respawns inside the other player
	float pos[3], ang[3];
	GetClientAbsOrigin(target, pos);
	GetClientAbsAngles(target, ang);
	ForceSpawn(client, pos, ang);
}