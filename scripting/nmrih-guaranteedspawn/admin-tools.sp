
#include <guaranteedspawn>
#include <adminmenu>

#define ADMFLAG_GIVESPAWN ADMFLAG_CHEATS

TopMenu hTopMenu;

void AdminTools_OnPluginStart()
{
	LoadTranslations("guaranteedspawn.phrases");
	LoadTranslations("common.phrases");

	RegAdminCmd("sm_givespawn", Command_GiveSpawn, ADMFLAG_GIVESPAWN);
	RegAdminCmd("sm_removespawn", Command_RemoveSpawn, ADMFLAG_GIVESPAWN);
	
	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if (topmenu == hTopMenu) {
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Find the "Player Commands" category */
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_givespawn", AdminMenu_GiveSpawn, player_commands, "sm_givespawn", ADMFLAG_GIVESPAWN);
		hTopMenu.AddItem("sm_removespawn", AdminMenu_RemoveSpawn, player_commands, "sm_removespawn", ADMFLAG_GIVESPAWN);
	}
}

void AdminMenu_GiveSpawn(TopMenu topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Give spawn to player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayGiveSpawnMenu(param);
	}
}

void AdminMenu_RemoveSpawn(TopMenu topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Remove spawn from player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayRemoveSpawnMenu(param);
	}
}

void GiveSpawn(int client, int target)
{
	GS_SetCanSpawn(target, true);
	LogAction(client, target, "\"%L\" gave a spawn to \"%L\"", client, target);
}

void RemoveSpawn(int client, int target)
{
	GS_SetCanSpawn(target, false);
	LogAction(client, target, "\"%L\" removed spawn from \"%L\"", client, target);
}

void DisplayGiveSpawnMenu(int client)
{
	Menu menu = new Menu(MenuHandler_GiveSpawn);
	
	char buffer[100];
	Format(buffer, sizeof(buffer), "%T:", "Give spawn to player", client);
	menu.SetTitle(buffer);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, false); 

	if (menu.ItemCount <= 0)
	{
		PrintToChat(client, "[SM] %t", "No targets available");
		delete menu;
		hTopMenu.Display(client, TopMenuPosition_LastCategory);
		return;
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayRemoveSpawnMenu(int client)
{
	Menu menu = new Menu(MenuHandler_RemoveSpawn);
	
	char buffer[100];
	Format(buffer, sizeof(buffer), "%T:", "Remove spawn from player", client);
	menu.SetTitle(buffer);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, false);

	if (menu.ItemCount <= 0)
	{
		PrintToChat(client, "[SM] %t", "No targets available");
		delete menu;
		hTopMenu.Display(client, TopMenuPosition_LastCategory);
		return;
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_GiveSpawn(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(target, name, sizeof(name));
			
			GiveSpawn(param1, target);
			ShowActivity2(param1, "[SM] ", "%t", "Gave spawn to target", "_s", name);
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayGiveSpawnMenu(param1);
		}
	}

	return 0;
}

int MenuHandler_RemoveSpawn(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(target, name, sizeof(name));
			
			RemoveSpawn(param1, target);
			ShowActivity2(param1, "[SM] ", "%t", "Removed spawn from target", "_s", name);
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayRemoveSpawnMenu(param1);
		}
	}

	return 0;
}

Action Command_GiveSpawn(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_givespawn <#userid|name>");
		return Plugin_Handled;
	}

	char arg[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_DEAD,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		GiveSpawn(client, target_list[i]);
	}
	
	if (tn_is_ml)
	{
		ShowActivity2(client, "[SM] ", "%t", "Gave spawn to target", target_name);
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Gave spawn to target", "_s", target_name);
	}
	
	return Plugin_Handled;
}

Action Command_RemoveSpawn(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_removespawn <#userid|name>");
		return Plugin_Handled;
	}

	char arg[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_DEAD,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		RemoveSpawn(client, target_list[i]);
	}
	
	if (tn_is_ml)
	{
		ShowActivity2(client, "[SM] ", "%t", "Removed spawn from target", target_name);
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "Removed spawn from target", "_s", target_name);
	}
	
	return Plugin_Handled;
}