/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Admin Menu Plugin
 * Creates the base admin menu, for plugins to add items to.
 *
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma semicolon 1

#include <sourcemod>
#include <topmenus>

#undef REQUIRE_PLUGIN
#include <materialadmin>

//#pragma newdecls required

public Plugin myinfo = 
{
	name = "Admin Menu",
	author = "AlliedModders LLC",
	description = "Administration Menu for Material Admin",
	version = MAVERSION,
	url = "http://www.sourcemod.net/"
};

/** Material Admin Integration */
bool		g_bLoadWarns = false;
int			g_iWarnings[MAXPLAYERS + 1];
char		g_szDatabasePrefix[12] = "sb";
Database	g_hDatabase;
int			g_iServerID = -1;

/* Forwards */
Handle hOnAdminMenuReady = null;
Handle hOnAdminMenuCreated = null;

/* Menus */
TopMenu hAdminMenu;

/* Top menu objects */
TopMenuObject obj_playercmds = INVALID_TOPMENUOBJECT;
TopMenuObject obj_servercmds = INVALID_TOPMENUOBJECT;
TopMenuObject obj_votingcmds = INVALID_TOPMENUOBJECT;

#include "adminmenu/dynamicmenu.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetAdminTopMenu", __GetAdminTopMenu);
	CreateNative("AddTargetsToMenu", __AddTargetsToMenu);
	CreateNative("AddTargetsToMenu2", __AddTargetsToMenu2);
	RegPluginLibrary("adminmenu");
	return APLRes_Success;
}

public void MAOnConnectDatabase(Database db)
{
	g_hDatabase = db;
}

public void MAOnConfigSetting()
{
	if (!MAGetConfigSetting("DatabasePrefix", g_szDatabasePrefix))
		MALog(MA_LogConfig, "ma_checker: MAGetConfigSetting no");

	char szDummy[12];
	if (MAGetConfigSetting("LoadWarnCount", szDummy))
	{
		g_bLoadWarns = (szDummy[0] != '0');
	}

	if (MAGetConfigSetting("ServerID", szDummy))
	{
		g_iServerID = StringToInt(szDummy);
	}
}

public void OnClientAuthorized(int iClient, const char[] szEngineAuthId)
{
	/* Do not check bots nor check player with lan steamid. */
	if (szEngineAuthId[0] == 'B' || szEngineAuthId[9] == 'L' || szEngineAuthId[0] == '[')
		return;

	if (!g_hDatabase)
		return;
	
	if (!g_bLoadWarns)
		return;

	if (g_iServerID == -1)
	{
		// User doesn't setup Server ID.
		return;
	}

	char szQuery[768];
	g_hDatabase.Format(szQuery, sizeof(szQuery), "\
		SELECT \
			1 \
		FROM \
			`%s_warns` \
		WHERE \
		    `arecipient` = IFNULL((\
				SELECT \
					`admin_id` \
				FROM \
					`%s_admins_servers_groups` \
					INNER JOIN `%s_admins` \
						ON `%s_admins`.`aid` = `%s_admins_servers_groups`.`admin_id` \
				WHERE \
					( \
						`server_id` = %d \
						OR `srv_group_id` IN (\
							SELECT \
								`group_id` \
							FROM \
								`%s_servers_groups` \
							WHERE \
								`server_id` = %d\
						)\
					) \
					AND `authid` REGEXP '^STEAM_[0-9]:%s$' \
				\
			), 0) \
			AND (`expires` > UNIX_TIMESTAMP() OR `expires` = 0);", g_szDatabasePrefix, g_szDatabasePrefix, g_szDatabasePrefix, g_szDatabasePrefix, g_szDatabasePrefix, g_iServerID, g_szDatabasePrefix, g_iServerID, szEngineAuthId);
	g_hDatabase.Query(SQL_OnWarnsCountReceived, szQuery, GetClientUserId(iClient), DBPrio_Low);
}

public void SQL_OnWarnsCountReceived(Database hDB, DBResultSet hResults, const char[] szError, int iClient)
{
	if ((iClient = GetClientOfUserId(iClient)) == 0)
	{
		return;
	}

	if (!hResults)
	{
		MALog(MA_LogDateBase, "Database failure when fetching warns count for %L: %s", iClient, szError);
		return;
	}

	g_iWarnings[iClient] = hResults.RowCount;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("adminmenu.phrases");
	LoadTranslations("materialadmin.phrases");
	
	hOnAdminMenuCreated = CreateGlobalForward("OnAdminMenuCreated", ET_Ignore, Param_Cell);
	hOnAdminMenuReady = CreateGlobalForward("OnAdminMenuReady", ET_Ignore, Param_Cell);

	RegAdminCmd("sm_admin", Command_DisplayMenu, ADMFLAG_GENERIC, "Displays the admin menu");
}

public void OnConfigsExecuted()
{
	char path[PLATFORM_MAX_PATH];
	char error[256];
	
	BuildPath(Path_SM, path, sizeof(path), "configs/adminmenu_sorting.txt");
	
	if (!hAdminMenu.LoadConfig(path, error, sizeof(error)))
	{
		LogError("Could not load admin menu config (file \"%s\": %s)", path, error);
		return;
	}
}

public void OnMapStart()
{
	ParseConfigs();
}

public void OnAllPluginsLoaded()
{
	hAdminMenu = new TopMenu(DefaultCategoryHandler);
	
	obj_playercmds = hAdminMenu.AddCategory("PlayerCommands", DefaultCategoryHandler);
	obj_servercmds = hAdminMenu.AddCategory("ServerCommands", DefaultCategoryHandler);
	obj_votingcmds = hAdminMenu.AddCategory("VotingCommands", DefaultCategoryHandler);
		
	BuildDynamicMenu();
	
	Call_StartForward(hOnAdminMenuCreated);
	Call_PushCell(hAdminMenu);
	Call_Finish();
	
	Call_StartForward(hOnAdminMenuReady);
	Call_PushCell(hAdminMenu);
	Call_Finish();
}

#if SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR == 7
public DefaultCategoryHandler(Handle:topmenu, 
						TopMenuAction:action,
						TopMenuObject:object_id,
						param,
						String:buffer[],
						maxlength)
#else
public void DefaultCategoryHandler(TopMenu topmenu, 
						TopMenuAction action,
						TopMenuObject object_id,
						int param,
						char[] buffer,
						int maxlength)
#endif
{
	if (action == TopMenuAction_DisplayTitle)
	{
		if (object_id == INVALID_TOPMENUOBJECT)
		{
			if (LibraryExists("materialadmin")) 
				GetCustomAdminMenuFormat(param, buffer, maxlength);
			else
				Format(buffer, maxlength, "%T:", "Admin Menu", param);
		}
		else if (object_id == obj_playercmds)
		{
			Format(buffer, maxlength, "%T:", "Player Commands", param);
		}
		else if (object_id == obj_servercmds)
		{
			Format(buffer, maxlength, "%T:", "Server Commands", param);
		}
		else if (object_id == obj_votingcmds)
		{
			Format(buffer, maxlength, "%T:", "Voting Commands", param);
		}
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == obj_playercmds)
		{
			Format(buffer, maxlength, "%T", "Player Commands", param);
		}
		else if (object_id == obj_servercmds)
		{
			Format(buffer, maxlength, "%T", "Server Commands", param);
		}
		else if (object_id == obj_votingcmds)
		{
			Format(buffer, maxlength, "%T", "Voting Commands", param);
		}
	}
}

public int __GetAdminTopMenu(Handle plugin, int numParams)
{
	return view_as<int>(hAdminMenu);
}

public int __AddTargetsToMenu(Handle plugin, int numParams)
{
	bool alive_only = false;
	
	if (numParams >= 4)
	{
		alive_only = GetNativeCell(4);
	}
	
	return UTIL_AddTargetsToMenu(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), alive_only);
}

public int __AddTargetsToMenu2(Handle plugin, int numParams)
{
	return UTIL_AddTargetsToMenu2(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public Action Command_DisplayMenu(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	hAdminMenu.CacheTitles = false;
	hAdminMenu.Display(client, TopMenuPosition_Start);
	return Plugin_Handled;
}

stock int UTIL_AddTargetsToMenu2(Menu menu, int source_client, int flags)
{
	char user_id[12];
	char name[MAX_NAME_LENGTH];
	char display[MAX_NAME_LENGTH+12];
	
	int num_clients;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsClientInKickQueue(i))
		{
			continue;
		}
		
		if (((flags & COMMAND_FILTER_NO_BOTS) == COMMAND_FILTER_NO_BOTS)
			&& IsFakeClient(i))
		{
			continue;
		}
		
		if (((flags & COMMAND_FILTER_CONNECTED) != COMMAND_FILTER_CONNECTED)
			&& !IsClientInGame(i))
		{
			continue;
		}
		
		if (((flags & COMMAND_FILTER_ALIVE) == COMMAND_FILTER_ALIVE) 
			&& !IsPlayerAlive(i))
		{
			continue;
		}
		
		if (((flags & COMMAND_FILTER_DEAD) == COMMAND_FILTER_DEAD)
			&& IsPlayerAlive(i))
		{
			continue;
		}
		
		if ((source_client && ((flags & COMMAND_FILTER_NO_IMMUNITY) != COMMAND_FILTER_NO_IMMUNITY))
			&& !CanUserTarget(source_client, i))
		{
			continue;
		}
		
		IntToString(GetClientUserId(i), user_id, sizeof(user_id));
		GetClientName(i, name, sizeof(name));
		Format(display, sizeof(display), "%s (%s)", name, user_id);
		menu.AddItem(user_id, display);
		num_clients++;
	}
	
	return num_clients;
}

stock int UTIL_AddTargetsToMenu(Menu menu, int source_client, bool in_game_only, bool alive_only)
{
	int flags = 0;
	
	if (!in_game_only)
	{
		flags |= COMMAND_FILTER_CONNECTED;
	}
	
	if (alive_only)
	{
		flags |= COMMAND_FILTER_ALIVE;
	}
	
	return UTIL_AddTargetsToMenu2(menu, source_client, flags);
}

void GetCustomAdminMenuFormat(int iClient, char[] sLength, int iLens)
{
	AdminId idAdmin = GetUserAdmin(iClient);
	int iExpire	= MAGetAdminExpire(idAdmin);
	if (iExpire)
	{
		int iTime = GetTime();
		if (iTime > iExpire)
		{
			CancelClientMenu(iClient, true);
		#if MADEBUG
			MALog(MA_LogAction, "adminmenu: Menu RemoveAdmin expire: admin id %d, name %N", idAdmin, iClient);
		#endif
			RemoveAdmin(idAdmin);
			return;
		}
		
		int iLength = iExpire - iTime;
		int iDays = iLength / (60 * 60 * 24);
		int iHours = (iLength - (iDays * (60 * 60 * 24))) / (60 * 60);
		int iMinutes = (iLength - (iDays * (60 * 60 * 24)) - (iHours * (60 * 60))) / 60;
		int iLen = 0;
		if(iDays) iLen += Format(sLength[iLen], iLens - iLen, "%d %T", iDays, "Days", iClient);
		if(iHours) iLen += Format(sLength[iLen], iLens - iLen, "%s%d %T", iDays ? " " : "", iHours, "Hours", iClient);
		if(iMinutes) iLen += Format(sLength[iLen], iLens - iLen, "%s%d %T", (iDays || iHours) ? " " : "", iMinutes, "Minutes", iClient);
		if(g_bLoadWarns) iLen += Format(sLength[iLen], iLens - iLen, "\n%T", "WarningCount", iClient, g_iWarnings[iClient]);
		
		Format(sLength, iLens, "%T:\n%s", "Admin Menu", iClient, sLength);
	}
	else
		Format(sLength, iLens, "%T:", "Admin Menu", iClient);
}