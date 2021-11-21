#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#include <guaranteedspawn>

#define STATE_ACTIVE 0

#define OBS_MODE_IN_EYE 4
#define OBS_MODE_CHASE 5
#define OBS_MODE_POI 6

public Plugin myinfo = 
{
	name = "[NMRiH] Guaranteed Spawn",
	author = "Dysphie",
	description = "Grants a spawn to players who've never spawned in the active round",
	version = "1.0.8",
	url = "https://github.com/dysphie/nmrih-guaranteedspawn"
};

bool lateloaded;
StringMap steamSpawned;
bool indexSpawned[MAXPLAYERS+1] = { false, ... };
int offs_SpawnEnabled = -1;
ArrayList spawnpoints;
Handle hudSync;

GlobalForward spawnFwd;

int numSpawnpoints;

int spawningPlayer = -1;
DynamicHook fnGetPlayerSpawnSpot;
Handle sdkSpawnPlayer;
Handle sdkStateTrans;

ConVar cvNearby;
ConVar cvStatic;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	lateloaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("guaranteedspawn.phrases");
	DoGamedataStuff();

	hudSync = CreateHudSynchronizer();
	steamSpawned = new StringMap();
	spawnpoints = new ArrayList();

	cvStatic = CreateConVar("sm_gspawn_allow_checkpoint", "1");
	cvNearby = CreateConVar("sm_gspawn_allow_nearby", "1");

	HookEvent("nmrih_reset_map", OnMapReset, EventHookMode_PostNoCopy);
	RegAdminCmd("debug_spawn_history", Cmd_SpawnHistory, ADMFLAG_ROOT);
	RegAdminCmd("debug_spawnpoints", Cmd_SpawnPoints, ADMFLAG_ROOT);

	AddCommandListener(OnSpecUpdate, "spec_next");
	AddCommandListener(OnSpecUpdate, "spec_prev");
	AddCommandListener(OnSpecUpdate, "spec_mode");

	AutoExecConfig(true, "plugin.guaranteedspawn");

	if (lateloaded)
	{
		int e = -1;
		while ((e = FindEntityByClassname(e, "info_player_nmrih")) != -1)
		{
			spawnpoints.Push(EntIndexToEntRef(e));
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i)) 
			{
				OnClientPutInServer(i);
			}
		}
	}

	spawnFwd = new GlobalForward("GS_OnGuaranteedSpawn", ET_Event, Param_Cell, Param_Cell);
	CreateTimer(5.0, UpdateHints, _, TIMER_REPEAT);
}

void DoGamedataStuff()
{
	GameData gamedata = new GameData("guaranteedspawn.games");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CNMRiH_Player::Spawn");
	sdkSpawnPlayer = EndPrepSDKCall();
	if (!sdkSpawnPlayer)
	{
		SetFailState("Failed to set up SDKCall for CNMRiH_Player::Spawn");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CSDKPlayer::State_Transition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkStateTrans = EndPrepSDKCall();
	if (!sdkStateTrans)
		SetFailState("Failed to set up SDKCall for CSDKPlayer::State_Transition");

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

	fnGetPlayerSpawnSpot = new DynamicHook(offs_GetPlayerSpawnSpot, HookType_GameRules, ReturnType_CBaseEntity, ThisPointer_Ignore);
	fnGetPlayerSpawnSpot.AddParam(HookParamType_CBaseEntity);   // CBasePlayer *, player

	delete gamedata;
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

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "info_player_nmrih"))
	{
		spawnpoints.Push(EntIndexToEntRef(entity));
	}
}

int CountAvailableSpawnpoints()
{
	int count = 0;
	int maxSpawnpoints = spawnpoints.Length;
	int i = 0;
	while (i < maxSpawnpoints)
	{
		int entity = EntRefToEntIndex(spawnpoints.Get(i));
		if (entity == -1)
		{
			spawnpoints.Erase(i);
			maxSpawnpoints--;
		}
		else
		{
			if (IsSpawnpointEnabled(entity))
			{
				count++;
			}
			i++;
		}
	}

	return count;
}

Action Cmd_SpawnHistory(int client, int args)
{
	StringMapSnapshot snap = steamSpawned.Snapshot();

	for (int i = 0; i < snap.Length; i++)
	{
		char steamID[21];
		snap.GetKey(i, steamID, sizeof(steamID));
		ReplyToCommand(client, "STEAM: %s", steamID);
	}

	delete snap;

	for (int i = 1; i <= MaxClients; i++) 
	{
		if (indexSpawned[i] && IsClientInGame(i)) 
		{
			ReplyToCommand(client, "INDEX: %d (%N)", i, i);
		}
	}
	return Plugin_Handled;
}

Action Cmd_SpawnPoints(int client, int args)
{
	for (int i = 0; i < spawnpoints.Length; i++)
	{
		int ref = spawnpoints.Get(i);
		int index = EntRefToEntIndex(ref);
		bool enabled = index != -1 && IsSpawnpointEnabled(index);
		ReplyToCommand(client, "SPAWNPOINT: %d (%d) [Enabled: %d]", ref, index, enabled);
	}
	return Plugin_Handled;
}

void OnMapReset(Event event, const char[] name, bool silent)
{
	ClearSpawnHistory();
}

void ClearSpawnHistory()
{
	steamSpawned.Clear();
	for (int i = 1; i <= MaxClients; i++) 
	{
		indexSpawned[i] = false;
	}	
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, OnClientPreThink);
}

public void OnClientPreThink(int client)
{
	if (!indexSpawned[client] && NMRiH_IsPlayerAlive(client))
	{
		OnPlayerFirstSpawn(client);
	}
}

public void OnClientDisconnect(int client)
{
	indexSpawned[client] = false;
}

void OnPlayerFirstSpawn(int client)
{
	indexSpawned[client] = true;

	char steamID[21];
	if (GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID)))
	{
		steamSpawned.SetValue(steamID, true);
	}
}

bool NMRiH_IsPlayerAlive(int client)
{
	return IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_iPlayerState") == STATE_ACTIVE;
}

bool IsSpawnpointEnabled(int spawnpoint)
{
	return view_as<bool>(GetEntData(spawnpoint, offs_SpawnEnabled, 1));
}

Action UpdateHints(Handle timer)
{
	numSpawnpoints = CountAvailableSpawnpoints();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!indexSpawned[i] && IsClientInGame(i)) 
		{
			UpdateHintForPlayer(i);
		}
	}
}

void UpdateHintForPlayer(int client)
{
	int target = GetSpawnTarget(client);
	if (target != -1)
	{
		if (target == 0)
		{
			ShowRespawnHint(client, "%t", "Respawn At Checkpoint");
		}
		else
		{
			ShowRespawnHint(client, "%t", "Respawn At Teammate", target);	
		}		
	}
}

void ShowRespawnHint(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);

	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);

	SetHudTextParams(-1.0, 0.01, 5.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, hudSync, buffer);
}

Action OnSpecUpdate(int client, const char[] command, int argc)
{
	if (0 < client <= MaxClients && !indexSpawned[client] && IsClientInGame(client))
	{
		RequestFrame(Frame_UpdateHintForClient, GetClientSerial(client));	
	}
}

void Frame_UpdateHintForClient(int serial)
{
	int client = GetClientFromSerial(serial);
	if (client)
	{
		UpdateHintForPlayer(client);
	}
}

int GetObserverTarget(int client)
{
	int obsMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
	if (obsMode == OBS_MODE_IN_EYE || obsMode == OBS_MODE_CHASE || obsMode == OBS_MODE_POI) 
	{
		int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		if (0 < target <= MaxClients)
		{
			return target;
		}
	}
	return -1;
}


public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if ((buttons & IN_USE))
	{
		int target = GetSpawnTarget(client);

		if (target == -1)
		{
			return Plugin_Continue;
		}
		if (target == 0)
		{
			DefaultSpawn(client);
		}
		else
		{
			NearbySpawn(client, target);
		}
	}

	return Plugin_Continue;
}

int GetSpawnTarget(int client)
{
	if (indexSpawned[client])
	{
		return -1;
	}
	
	char steamid[21];
	if (!GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid)))
	{
		return -1;
	}

	bool val;
	if (steamSpawned.GetValue(steamid, val) && val) {
		return -1;
	}

	
	if (cvNearby.BoolValue)
	{
		int obsTarget = GetObserverTarget(client);
		if (obsTarget != -1)
		{
			return obsTarget;
		}
	}

	if (numSpawnpoints && cvStatic.BoolValue)
	{
		return 0;
	}

	return -1;
}

void ForceSpawn(int client, float origin[3], float angles[3], GSMethod type)
{
	// Let other plugins know that we are about to force spawn
	Action result;
	Call_StartForward(spawnFwd);
	Call_PushCell(client);
	Call_PushCell(type);
	Call_Finish(result);

	// If everyone's okay with it, do it
	if (result == Plugin_Continue)
	{
		spawningPlayer = client;
		SDKCall(sdkStateTrans, client, STATE_ACTIVE);
		SDKCall(sdkSpawnPlayer, client);
		spawningPlayer = -1;
		TeleportEntity(client, origin, angles, NULL_VECTOR);
	}
}

void DefaultSpawn(int client)
{
	float pos[3], ang[3];
	int closestSpawn = -1;
	float leastDistance = 999999.9;

	int max = spawnpoints.Length;
	for (int s; s < max; s++)
	{
		int e = EntRefToEntIndex(spawnpoints.Get(s));
		if (e == -1 || !IsSpawnpointEnabled(e)) {
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
		ForceSpawn(client, pos, ang, GSMethod_Checkpoint);
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

void NearbySpawn(int client, int target)
{
	// TODO: Currently it just respawns inside the other player
	float pos[3], ang[3];
	GetClientAbsOrigin(target, pos);
	GetClientAbsAngles(target, ang);
	ForceSpawn(client, pos, ang, GSMethod_Nearby);
}