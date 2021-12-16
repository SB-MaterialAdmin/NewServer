//получение айпи и порта сервера
void InsertServerInfo()
{
    int iPieces[4], 
        iLongIP;
    
    iLongIP = FindConVar("hostip").IntValue;
    iPieces[0] = (iLongIP >> 24) & 0x000000FF;
    iPieces[1] = (iLongIP >> 16) & 0x000000FF;
    iPieces[2] = (iLongIP >> 8) & 0x000000FF;
    iPieces[3] = iLongIP & 0x000000FF;
    FormatEx(g_sServerIP, sizeof(g_sServerIP), "%d.%d.%d.%d", iPieces[0], iPieces[1], iPieces[2], iPieces[3]);

    FindConVar("hostport").GetString(g_sServerPort, sizeof(g_sServerPort));
}

void GetColor(char[] sBuffer, int iMaxlin)
{
	static const char sColorT[][] =  {"#1",   "#2",   "#3",   "#4",   "#5",   "#6",   "#7",   "#8",   "#9",   "#10", "#OB",   "#OC",  "#OE",  "#0A"},
					  sColorC[][] =  {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E", "\x0A"};
					  
	for(int i = 0; i < 13; i++)
		ReplaceString(sBuffer, iMaxlin, sColorT[i], sColorC[i]);
}

void PrintToChat2(int iClient, const char[] sMesag, any ...)
{
	static const char sNameD[][] = {"name1", "name2"};
	char sBufer[4096];
	VFormat(sBufer, sizeof(sBufer), sMesag, 3);
	
	// del name 
	if (g_sNameReples[0][0])
		ReplaceString(sBufer, sizeof(sBufer), g_sNameReples[0], sNameD[0]);
	if (g_sNameReples[1][0])
		ReplaceString(sBufer, sizeof(sBufer), g_sNameReples[1], sNameD[1]);
	
	Format(sBufer, sizeof(sBufer), "%T %s", "prifix", iClient, sBufer);

	GetColor(sBufer, sizeof(sBufer));
	
	// add name 
	ReplaceString(sBufer, sizeof(sBufer), sNameD[0], g_sNameReples[0]);
	ReplaceString(sBufer, sizeof(sBufer), sNameD[1], g_sNameReples[1]);
	
	if (!IsClientInGame(iClient))
		return;

	// TODO: move to global variable and calculate once.
	char szChatPrefix[4];
	if (GetUserMessageType() == UM_Protobuf)
	{
		strcopy(szChatPrefix, sizeof(szChatPrefix), " \x01");
	}
	else
	{
		strcopy(szChatPrefix, sizeof(szChatPrefix), "\x01");
	}

	// В сраной CS:GO `\n` не работает, как везде. Вместо переносов, красит текст. Так что сделаем немного хитрее.
	// Эта реализация пока что не поддерживает перенос и прошлого активного цвета.
	int iPos = 0;
	int iNextPos = 0;
	do
	{
		if ((iNextPos = FindCharInString(sBufer[iPos], '\n')) != -1)
		{
			sBufer[iPos+iNextPos] = 0;
			iNextPos += iPos;
		}

		PrintToChat(iClient, "%s%s", szChatPrefix, sBufer[iPos]);
		if (iNextPos == -1)
		{
			break;
		}

		iPos = iNextPos + 1;
	}
	while (sBufer[iPos] != 0);
}

void ShowAdminAction(int iClient, const char[] sMesag, any ...)
{
	if (!g_iShowAdminAction)
		return;

	char sBufer[256],
		 sName[MAX_NAME_LENGTH],
		 sNameShow[MAX_NAME_LENGTH];

	switch(g_iShowAdminAction)
	{
		case 1: strcopy(sNameShow, sizeof(sNameShow), "Admin");
		case 2: 
		{
			if (iClient)
				GetClientName(iClient, sName, sizeof(sName));
			else
				strcopy(sNameShow, sizeof(sNameShow), "Server");
		}
		case 3: 
		{
			if (iClient)
				GetClientName(iClient, sName, sizeof(sName));
			else
				return;
		}
	}
 
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (g_iShowAdminAction == 2 && !iClient || g_iShowAdminAction == 1)
				FormatEx(sName, sizeof(sName), "%T", sNameShow, i);
			strcopy(g_sNameReples[1], sizeof(g_sNameReples[]), sName);
			SetGlobalTransTarget(i);
			VFormat(sBufer, sizeof(sBufer), sMesag, 3);
			ReplaceString(sBufer, sizeof(sBufer), "name", sName);
			PrintToChat2(i, "%s", sBufer);
		}
	}
}
//-----------------------------------------------------------------------------
bool CheckAdminFlags(int iClient, int iFlag)
{
	if (GetUserFlagBits(iClient) & (ADMFLAG_ROOT | iFlag))
		return true;
	else
		return false;
}

bool IsImune(int iAdminImun, int iTargetImun)
{
	switch(g_iCvar_ImmunityMode)
	{
		case 1:
		{
			if (iAdminImun < iTargetImun)
				return false;
		}
		case 2: 
		{
			if (iAdminImun <= iTargetImun)
				return false;
		}
		case 3: 
		{
			if (!iAdminImun && !iTargetImun)
				return true;
			else if (iAdminImun <= iTargetImun)
				return false;
		}
	}
	return true;
}

int GetImmuneAdmin(int iClient)
{
	if (!iClient || !IsClientInGame(iClient))
		return 0;

	AdminId idAdmin = GetUserAdmin(iClient);
	if (idAdmin == INVALID_ADMIN_ID)
		return 0;
	
	int iAdminImun = idAdmin.ImmunityLevel;
	int iCount = idAdmin.GroupCount;
	int iGroupImun,
		iImune = 0;

	if (iCount)
	{
		for (int i = 0; i < iCount; i++)
		{
			char sNameGroup[64];
			GroupId idGroup = idAdmin.GetGroup(i, sNameGroup, sizeof(sNameGroup));
			iGroupImun = idGroup.ImmunityLevel;
			if (iImune < iAdminImun && iImune < iGroupImun)
			{
				if (iAdminImun >= iGroupImun)
					iImune = iAdminImun;
				else
					iImune = iGroupImun;
			}
			else if (iImune < iGroupImun)
				iImune = iGroupImun;
		}
	}
	else
		return iAdminImun;

	return iImune;
}

bool CheckAdminImune(int iAdminClient, int iAdminTarget)
{
	if (!iAdminClient && iAdminTarget)
		return true;
	
	if (iAdminClient == iAdminTarget)
	{
		if(g_bActionOnTheMy)
			return true;
		else
			return false;
	}

	AdminId idAdminTarget = GetUserAdmin(iAdminTarget);
	if (idAdminTarget != INVALID_ADMIN_ID && g_iCvar_ImmunityMode != 0)
	{
		if (GetUserFlagBits(iAdminClient) & ADMFLAG_ROOT && GetUserFlagBits(iAdminTarget) & ADMFLAG_ROOT)
			return false;
		
		int iTargetImun = GetImmuneAdmin(iAdminTarget);
		int iAdminImun = GetImmuneAdmin(iAdminClient);
	#if MADEBUG
		if (IsClientInGame(iAdminClient) && IsClientInGame(iAdminTarget))
			LogToFile(g_sLogAction, "CheckAdminImune: (admin %N - %d)  (target %N - %d)", iAdminClient, iAdminImun, iAdminTarget, iTargetImun);
		else
			LogToFile(g_sLogAction, "CheckAdminImune: (admin %d - %d)  (target %d - %d)", iAdminClient, iAdminImun, iAdminTarget, iTargetImun);
	#endif
	
		if (!IsImune(iAdminImun, iTargetImun))
			return false;
	}
	return true;
}

bool IsUnMuteUnBan(int iAdmin, char[] sSteamID)
{
	char sAdmin_SteamID[MAX_STEAMID_LENGTH];
	if (iAdmin && IsClientInGame(iAdmin) && IsClientAuthorized(iAdmin))
		GetClientAuthId(iAdmin, TYPE_STEAM, sAdmin_SteamID, sizeof(sAdmin_SteamID));
	else // от сервера
	{
	#if MADEBUG
		LogToFile(g_sLogAction, "IsUnMuteUnBan: (admin server)  (target %s)", sSteamID);
	#endif
		return true;
	}
	
	if (!g_bUnMuteUnBan)
		return true;

	int iFlag = GetAdminWebFlag(iAdmin, 0);
	
#if MADEBUG
	LogToFile(g_sLogAction, "IsUnMuteUnBan: (admin %s flag %d)  (target %s)", sAdmin_SteamID, iFlag, sSteamID);
#endif
	
	if (iFlag == 1 || iFlag == 5)
		return true;
	else if (iFlag == 6)
	{
		if (StrEqual(sAdmin_SteamID[8], sSteamID[8]))
			return true;
	}
	
	return false;
}

int GetAdminMaxTime(int iClient)
{
	char sAdminID[12];
	int iMaxTime;
	
	AdminId idAdmin = GetUserAdmin(iClient);
	FormatEx(sAdminID, sizeof(sAdminID), "%d", idAdmin);
	
	if (g_iTargetType[iClient] <= TYPE_ADDBAN)
	{
		if (g_tAdminBanTimeMax.GetValue(sAdminID, iMaxTime))
			return iMaxTime;
	}
	else
	{
		if (g_tAdminMuteTimeMax.GetValue(sAdminID, iMaxTime))
			return iMaxTime;
	}
	return -1;
}
//----------------------------------------------------------------------------------------------
// Веб флаги
int GetAdminWebFlag(int iClient, int iTipe)
{
	if (!iClient)
		return 0;

	char sAdminID[12];
	int iFlag;
	AdminId idAdmin = GetUserAdmin(iClient);
	FormatEx(sAdminID, sizeof(sAdminID), "%d", idAdmin);
	
	if (iTipe)
	{
		if (g_tWebFlagSetingsAdmin.GetValue(sAdminID, iFlag))
			return iFlag;
	}
	else
	{
		if (g_tWebFlagUnBanMute.GetValue(sAdminID, iFlag))
			return iFlag;
	}

	return 0; // нет прав
}

#if SETTINGADMIN
void ResetFlagAddAdmin(int iClient)
{
	for (int i = 0; i < 21; i++)
	{
		if (i < 4)
			g_bAdminAdd[iClient][i] = false;
		g_bAddAdminFlag[iClient][i] = false;
	}
}
#endif
//-------------------------------------------------------------------------------
void MAGetCmdArg1(int iClient, char[] sBuffer, char[] sArg, int iMaxLin)
{
	int iLen;
	
	if ((iLen = BreakString(sBuffer, sArg, iMaxLin)) == -1)
	{
		iLen = 0;
		sBuffer[0] = '\0';
	}
	
	strcopy(g_sTarget[iClient][TREASON], sizeof(g_sTarget[][]), sBuffer[iLen]);
}

bool MAGetCmdArg2(int iClient, char[] sBuffer, char[] sArg, int iMaxLin)
{
	char sTime[56];	
	int iLen,
		iTotelLen;
	
	if ((iLen = BreakString(sBuffer, sArg, iMaxLin)) == -1)
		return false;
	
	if (g_iMassBan < 2 && (GetTypeClient(sArg) >= -3))
	{
		ReplyToCommand(iClient, "%sUsage: No Access to #all|#ct|#t|#blue|#red", MAPREFIX);
		return false;
	}

	iTotelLen += iLen;
	if ((iLen = BreakString(sBuffer[iTotelLen], sTime, sizeof(sTime))) != -1)
		iTotelLen += iLen;
	else
	{
		iTotelLen = 0;
		sBuffer[0] = '\0';
	}

	g_iTarget[iClient][TTIME] = StringToInt(sTime);
	strcopy(g_sTarget[iClient][TREASON], sizeof(g_sTarget[][]), sBuffer[iTotelLen]);
	return true;
}

int GetTypeClient(char[] sArg)
{
	if (StrEqual(sArg, "#all"))
		return -1;
	else if (StrEqual(sArg, "#ct") || StrEqual(sArg, "#blue"))
		return -2;
	else if (StrEqual(sArg, "#t") || StrEqual(sArg, "#red"))
		return -3;
	else if (sArg[0] == '#')
		return -4;
	else
		return -5;
}

bool ValidTime(int iClient)
{
	if (iClient)
	{
		int iMaxTime = GetAdminMaxTime(iClient);
	#if MADEBUG
		LogToFile(g_sLogAction,"valid time: time %d, max %d.", g_iTarget[iClient][TTIME], iMaxTime);
	#endif
		
		/*
			-1 - всё разрешено
			0  - можно всё но не на всегда
			1... - больше этого времени не разрешено, навсегда тоже не разрешено
		*/
		if (iMaxTime > -1)
		{
			if (!iMaxTime && !g_iTarget[iClient][TTIME])
			{
				ReplyToCommand(iClient, "%s%T", MAPREFIX, "No Access time 0", iClient);
				return false;
			}
			else if (iMaxTime && g_iTarget[iClient][TTIME] > iMaxTime)
			{
				ReplyToCommand(iClient, "%s%T", MAPREFIX, "No Access max time", iClient, iMaxTime);
				return false;
			}
		}
	}

	if (g_iTargetType[iClient] <= TYPE_ADDBAN && g_iTarget[iClient][TTIME] < 0)
	{
		if (iClient)
			ReplyToCommand(iClient, "%s%T", MAPREFIX, "Invalid time", iClient, 0);
		else
			ReplyToCommand(iClient, "%sUsage: [time] invalid", MAPREFIX);
		return false;
	}
	else if (g_iTarget[iClient][TTIME] < -1)
	{
		if (iClient)
			ReplyToCommand(iClient, "%s%T", MAPREFIX, "Invalid time", iClient, -1);
		else
			ReplyToCommand(iClient, "%sUsage: [time] invalid", MAPREFIX);
		return false;
	}
	else if (!g_iTarget[iClient][TTIME] && iClient && !CheckAdminFlags(iClient, ADMFLAG_UNBAN))
	{
		ReplyToCommand(iClient, "%s%T", MAPREFIX, "No Access unban time 0", iClient);
		return false;
	}
	return true;
}

int ValidSteam(const char[] sSteamID)
{
	if (!strncmp(sSteamID, "[U:", 3))
		return 1;
	else if (!strncmp(sSteamID, "STEAM_", 6))
		return 2;

	return 0;
}

// взято с этого плагина https://forums.alliedmods.net/showpost.php?p=2353704&postcount=10
void ConvecterSteam3ToSteam2(char[] sSteamID)
{
	char sParts[3][10];
	
	ReplaceString(sSteamID, MAX_STEAMID_LENGTH, "[", "");
	ReplaceString(sSteamID, MAX_STEAMID_LENGTH, "]", "");
	ExplodeString(sSteamID, ":", sParts, sizeof(sParts), sizeof(sParts[]));

	int iUniverse = StringToInt(sParts[1]);
	int iSteamid32 = StringToInt(sParts[2]);

	if (iUniverse == 1)
		Format(sSteamID, MAX_STEAMID_LENGTH, "STEAM_%d:%d:%d", 0, iSteamid32 & (1 << 0), iSteamid32 >>> 1);
	else
		Format(sSteamID, MAX_STEAMID_LENGTH, "STEAM_%d:%d:%d", iUniverse, iSteamid32 & (1 << 0), iSteamid32 >>> 1);
}

bool GetSteamAuthorized(int iClient, char[] sSteam)
{
	if (iClient && IsClientAuthorized(iClient))
	{
		GetClientAuthId(iClient, TYPE_STEAM, sSteam, MAX_STEAMID_LENGTH);
		return true;
	}
		
	return false;
}

void GetClientToBd(int iClient, int iTyp, const char[] sArg = "")
{
	switch(iTyp)
	{
		case 0:
		{
			int iTarget;
			int iMaxTarget = g_aUserId[iClient].Length;
			Transaction hTxn = new Transaction();

			for (int i = 0; i < iMaxTarget; i++)
			{
				iTarget = GetClientOfUserId(g_aUserId[iClient].Get(i));
				if(iTarget)
				{
					if (iMaxTarget > 1)
						DoCreateDB(iClient, iTarget, 1, hTxn);
					else
						DoCreateDB(iClient, iTarget);
				}
				else
					PrintToChat2(iClient, "%T", "No Client Game", iClient);
			}
			
			if (iMaxTarget > 1)
				CreateDB(0, 0, _, 2, hTxn);
			else
				delete hTxn;
		}
		case -1:
		{
			if (CheckAdminFlags(iClient, ADMFLAG_ROOT))
			{
				Transaction hTxn = new Transaction();

				for (int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && !IsFakeClient(i) && CheckAdminImune(iClient, i))
						DoCreateDB(iClient, i, 1, hTxn);
				}
				
				CreateDB(0, 0, _, 2, hTxn);
			}
			else
			{
				if(iClient)
					ReplyToCommand(iClient, "%s%T", MAPREFIX, "No Access all", iClient);
				else
					ReplyToCommand(iClient, "%sSelect all players allowed Admins with flag ROOT.", MAPREFIX);
			}
		}
		case -2:
		{
			Transaction hTxn = new Transaction();

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT && !IsFakeClient(i) && CheckAdminImune(iClient, i))
					DoCreateDB(iClient, i, 1, hTxn);
			}
			
			CreateDB(0, 0, _, 2, hTxn);
		}
		case -3:
		{
			Transaction hTxn = new Transaction();

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && !IsFakeClient(i) && CheckAdminImune(iClient, i))
					DoCreateDB(iClient, i, 1, hTxn);
			}
			
			CreateDB(0, 0, _, 2, hTxn);
		}
		case -4:
		{
			
			int iUserId = StringToInt(sArg[1]);
		#if MADEBUG
			LogToFile(g_sLogAction,"Command get target: UserId %d.", iUserId);
		#endif
			int iTarget = GetClientOfUserId(iUserId);
			if (iTarget && !IsFakeClient(iTarget))
			{
				if(CheckAdminImune(iClient, iTarget))
					DoCreateDB(iClient, iTarget);
				else
				{
					if (iClient)
						ReplyToCommand(iClient, "%s%T", MAPREFIX, "No admin", iClient);
					else
						ReplyToCommand(iClient, "%sThis Admin immunity.", MAPREFIX);
				}
			}
			else
			{
				if (iClient)
					ReplyToCommand(iClient, "%s%T", MAPREFIX, "No matching client", iClient);
				else
					ReplyToCommand(iClient, "%sNo matching client was found.", MAPREFIX);
			}
		}
		case -5:
		{
			char sTargetName[MAX_TARGET_LENGTH];
			int iTargetList[MAXPLAYERS], iTargetCount;
			bool bTnIsMl;
			if ((iTargetCount = ProcessTargetString(
						sArg, 
						iClient, 
						iTargetList, 
						MAXPLAYERS, 
						COMMAND_FILTER_NO_BOTS, 
						sTargetName, 
						MAX_TARGET_LENGTH, 
						bTnIsMl)) <= 0)
			{
				ReplyToTargetError(iClient, iTargetCount);
				return;
			}

			if (bTnIsMl)
			{
				if (g_iMassBan < 2)
				{
					ReplyToCommand(iClient, "%sUsage: No Access to mass select", MAPREFIX);
					return;
				}
				Transaction hTxn = new Transaction();

				for (int i = 0; i < iTargetCount; i++)
				{
					if (IsFakeClient(iTargetList[i]))
						continue;
					if (CheckAdminImune(iClient, iTargetList[i]))
						DoCreateDB(iClient, iTargetList[i], 1, hTxn);
					else
					{
						if (iClient)
							ReplyToCommand(iClient, "%s%T", MAPREFIX, "No admin", iClient);
						else
							ReplyToCommand(iClient, "%sThis Admin immunity.", MAPREFIX);
					}
				}
				
				CreateDB(0, 0, _, 2, hTxn);
			}
			else
			{
				if (CheckAdminImune(iClient, iTargetList[0]))
					DoCreateDB(iClient, iTargetList[0]);
				else
				{
					if (iClient)
						ReplyToCommand(iClient, "%s%T", MAPREFIX, "No admin", iClient);
					else
						ReplyToCommand(iClient, "%sThis Admin immunity.", MAPREFIX);
				}
			}
		}
	}
}

int FindTargetSteam(char[] sSteamID)
{
	char sSteamIDs[MAX_STEAMID_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			GetClientAuthId(i, TYPE_STEAM, sSteamIDs, sizeof(sSteamIDs));
			if(StrEqual(sSteamID[8], sSteamIDs[8]))
				return i;
		}
	}
	return 0;
}

int FindTargetIp(char[] sIp)
{
	char sIps[MAX_IP_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			GetClientIP(i, sIps, sizeof(sIps));
			if(StrEqual(sIp, sIps))
				return i;
		}
	}
	return 0;
}
//---------------------------------------------------------------------------------------------
public void ConVarChange_Alltalk(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bCvar_Alltalk = convar.BoolValue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (g_iTargetMuteType[i] == TYPEMUTE || g_iTargetMuteType[i] == TYPESILENCE)
				SetClientListeningFlags(i, VOICE_MUTED);
			else if (g_bCvar_Alltalk)
				SetClientListeningFlags(i, VOICE_NORMAL);
			else if (g_iGameTyp != GAMETYP_CSGO && !IsPlayerAlive(i))
			{
				if (g_iCvar_Deadtalk == 0)
					SetClientListeningFlags(i, VOICE_NORMAL);
				else if (g_iCvar_Deadtalk == 1)
					SetClientListeningFlags(i, VOICE_LISTENALL);
				else if (g_iCvar_Deadtalk == 2)
					SetClientListeningFlags(i, VOICE_TEAM);
			}
		}
	}
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char sName[256];
	convar.GetName(sName, sizeof(sName));
	if (StrEqual(sName, "sm_immunity_mode"))
		g_iCvar_ImmunityMode = convar.IntValue;
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (g_iTargetMuteType[i] == TYPEMUTE || g_iTargetMuteType[i] == TYPESILENCE)
					SetClientListeningFlags(i, VOICE_MUTED);
			}
		}
	}
}

public void ConVarChange_Deadtalk(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_iGameTyp == GAMETYP_CSGO)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (g_iTargetMuteType[i] == TYPEMUTE || g_iTargetMuteType[i] == TYPESILENCE)
					SetClientListeningFlags(i, VOICE_MUTED);
			}
		}
	}
	else
	{
		g_iCvar_Deadtalk = convar.IntValue;
		if (g_iCvar_Deadtalk)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (g_iTargetMuteType[i] == TYPEMUTE || g_iTargetMuteType[i] == TYPESILENCE)
						SetClientListeningFlags(i, VOICE_MUTED);
					else if (g_bCvar_Alltalk)
						SetClientListeningFlags(i, VOICE_NORMAL);
					else if (!IsPlayerAlive(i))
					{
						if (g_iCvar_Deadtalk == 1)
							SetClientListeningFlags(i, VOICE_LISTENALL);
						else if (g_iCvar_Deadtalk == 2)
							SetClientListeningFlags(i, VOICE_TEAM);
					}
				}
			}
		}
		else
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (g_iTargetMuteType[i] == TYPEMUTE || g_iTargetMuteType[i] == TYPESILENCE)
						SetClientListeningFlags(i, VOICE_MUTED);
					else
						SetClientListeningFlags(i, VOICE_NORMAL);
				}
			}
		}
	}
}

public void Event_PlayerSpawn(Event eEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	
	if (iClient)
	{
		if (g_iTargetMuteType[iClient] == TYPEMUTE || g_iTargetMuteType[iClient] == TYPESILENCE)
			SetClientListeningFlags(iClient, VOICE_MUTED);
		else
			SetClientListeningFlags(iClient, VOICE_NORMAL);
	}
}

public void Event_PlayerDeath(Event eEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	
	if (!iClient)
		return;	
	
	if (g_iTargetMuteType[iClient] == TYPEMUTE || g_iTargetMuteType[iClient] == TYPESILENCE)
	{
		SetClientListeningFlags(iClient, VOICE_MUTED);
		return;
	}
	
	if (g_bCvar_Alltalk)
	{
		SetClientListeningFlags(iClient, VOICE_NORMAL);
		return;
	}

	if (g_iCvar_Deadtalk == 1)
		SetClientListeningFlags(iClient, VOICE_LISTENALL);
	else if (g_iCvar_Deadtalk == 2)
		SetClientListeningFlags(iClient, VOICE_TEAM);
}
//--------------------------------------------------------------------------------------------------------
void CheckClientAdmin(int iClient, char[] sSteamID)
{
	g_bNewConnect[iClient] = true;
	
	AdminId idAdmin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if (idAdmin != INVALID_ADMIN_ID)
	{
		int iExpire = GetAdminExpire(idAdmin);
		if (iExpire)
		{
			if(iExpire > GetTime())
			{
				DataPack dPack = new DataPack();
				dPack.WriteCell(GetClientUserId(iClient));
				dPack.WriteCell(iExpire);
				CreateTimer(15.0, TimerAdminExpire, dPack);
			}
			else
			{
			#if MADEBUG
				LogToFile(g_sLogAdmin, "RemoveAdmin expire: admin id %d, steam %s", idAdmin, sSteamID);
			#endif
				RemoveAdmin(idAdmin);
			}
		}
	}
	else
		DelOflineInfo(sSteamID);	
}
//---------------------------------------------------------------------------------------------------------
//временная админка
public Action TimerAdminExpire(Handle timer, any data)
{
	DataPack dPack = view_as<DataPack>(data);
	dPack.Reset();
	int iClient = GetClientOfUserId(dPack.ReadCell());
	int iExpire = dPack.ReadCell();
	delete dPack;
	
	if(!iClient)
		return Plugin_Stop;

	char sLength[128];
	int iLength = iExpire - GetTime();
	FormatVrema(iClient, iLength, sLength, sizeof(sLength));
	if(IsClientInGame(iClient))
		PrintToChat2(iClient, "%T", "Admin Expire", iClient, sLength);
	
	return Plugin_Stop;
}

void AddAdminExpire(AdminId idAdmin, int iExpire)
{
	char sAdminID[12];
	FormatEx(sAdminID, sizeof(sAdminID), "%d", idAdmin);
#if MADEBUG
	LogToFile(g_sLogAdmin, "Add Admin Expire: admin id %d, expire %d", idAdmin, iExpire);
#endif
	g_tAdminsExpired.SetValue(sAdminID, iExpire, false);
}

int GetAdminExpire(AdminId idAdmin)
{
	char sAdminID[12];
	int iExpire;
	FormatEx(sAdminID, sizeof(sAdminID), "%d", idAdmin);
	if (g_tAdminsExpired.GetValue(sAdminID, iExpire))
	{
	#if MADEBUG
		LogToFile(g_sLogAdmin, "Get Admin Expire: admin id %d, expire %d", idAdmin, iExpire);
	#endif
		return iExpire;
	}

#if MADEBUG
	LogToFile(g_sLogAdmin, "Get Admin Expire: admin id %d, expire 0", idAdmin);
#endif
	return 0;
}
//--------------------------------------------------------------------------------------------------
void FormatVrema(int iClient, int iLength, char[] sLength, int iLens)
{
	if (iLength == -1)
		FormatEx(sLength, iLens, "%T", "temporarily", iClient);
	else if (iLength == 0)
		FormatEx(sLength, iLens, "%T", "Permanent", iClient);
	else
	{
		int iDays = iLength / (60 * 60 * 24);
		int iHours = (iLength - (iDays * (60 * 60 * 24))) / (60 * 60);
		int iMinutes = (iLength - (iDays * (60 * 60 * 24)) - (iHours * (60 * 60))) / 60;
		int iSec = (iLength - (iDays * (60 * 60 * 24)) - (iHours * (60 * 60)) - (iMinutes * 60));
		int iLen = 0;
	#if MADEBUG
		if (iClient && IsClientInGame(iClient))
			LogToFile(g_sLogAction, "format time (%N)  %d: days %d, hours %d, minutes %d, sec %d", iClient, iLength, iDays, iHours, iMinutes, iSec);
		else
			LogToFile(g_sLogAction, "format time (%d)  %d: days %d, hours %d, minutes %d, sec %d", iClient, iLength, iDays, iHours, iMinutes, iSec);
	#endif
		if(iDays) iLen += Format(sLength[iLen], iLens - iLen, "%d %T", iDays, "Days", iClient);
		if(iHours) iLen += Format(sLength[iLen], iLens - iLen, "%s%d %T", iDays ? " " : "", iHours, "Hours", iClient);
		if(iMinutes) iLen += Format(sLength[iLen], iLens - iLen, "%s%d %T", (iDays || iHours) ? " " : "", iMinutes, "Minutes", iClient);
		if(iSec) iLen += Format(sLength[iLen], iLens - iLen, "%s%d %T", (iDays || iHours || iMinutes) ? " " : "", iSec, "Sec", iClient);
	}
}
//------------------------------------------------------------------------------------------------------
// работа с мутами
void UnMute(int iClient)
{
	if (g_iTargetMuteType[iClient] == TYPESILENCE)
		g_iTargetMuteType[iClient] = TYPEGAG;
	else if (g_iTargetMuteType[iClient] == TYPEMUTE)
		g_iTargetMuteType[iClient] = 0;

	FunMute(iClient);
	KillTimerMute(iClient);

#if MADEBUG
	if (iClient && IsClientInGame(iClient))
		LogToFile(g_sLogAction, "un mute: %N type %d", iClient, g_iTargetMuteType[iClient]);
	else
		LogToFile(g_sLogAction, "un mute: %d type %d", iClient, g_iTargetMuteType[iClient]);
#endif
}

void KillTimerMute(int iClient)
{
	if(g_hTimerMute[iClient])
	{
		KillTimer(g_hTimerMute[iClient]);
		g_hTimerMute[iClient] = null;
	}
}

public Action TimerMute(Handle timer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!iClient)
		return Plugin_Stop;

#if MADEBUG
		LogToFile(g_sLogAction, "timer mute end: %N", iClient);
#endif
	g_hTimerMute[iClient] = null;
	UnMute(iClient);
		
	return Plugin_Stop;
}

void UnGag(int iClient)
{
	if (g_iTargetMuteType[iClient] == TYPESILENCE)
		g_iTargetMuteType[iClient] = TYPEMUTE;
	else if (g_iTargetMuteType[iClient] == TYPEGAG)
		g_iTargetMuteType[iClient] = 0;

	KillTimerGag(iClient);

#if MADEBUG
	if (iClient && IsClientInGame(iClient))
		LogToFile(g_sLogAction, "un gag: %N type %d", iClient, g_iTargetMuteType[iClient]);
	else
		LogToFile(g_sLogAction, "un gag: %d type %d", iClient, g_iTargetMuteType[iClient]);
#endif
}

void KillTimerGag(int iClient)
{
	if(g_hTimerGag[iClient])
	{
		KillTimer(g_hTimerGag[iClient]);
		g_hTimerGag[iClient] = null;
	}
}

public Action TimerGag(Handle timer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	
	if (!iClient)
		return Plugin_Stop;
		
#if MADEBUG
	LogToFile(g_sLogAction, "timer gag end: %N", iClient);
#endif
	g_hTimerGag[iClient] = null;
	UnGag(iClient);

	return Plugin_Stop;
}

void UnSilence(int iClient)
{
	g_iTargetMuteType[iClient] = 0;
	KillTimerGag(iClient);
	KillTimerMute(iClient);
	FunMute(iClient);
#if MADEBUG
	if (iClient && IsClientInGame(iClient))
		LogToFile(g_sLogAction, "un silence: %N type %d", iClient, g_iTargetMuteType[iClient]);
	else
		LogToFile(g_sLogAction, "un silence: %d type %d", iClient, g_iTargetMuteType[iClient]);
#endif
}

void AddGag(int iClient, int iTime)
{
	if(g_iTargetMuteType[iClient] == 0)
		g_iTargetMuteType[iClient] = TYPEGAG;
	else if (g_iTargetMuteType[iClient] == TYPEMUTE)
	{
		AddSilence(iClient, iTime);
		return;
	}

	KillTimerGag(iClient);
	if (iTime > 0 && iTime < 86400)
	{
		if(!g_hTimerGag[iClient])
			g_hTimerGag[iClient] = CreateTimer(float(iTime), TimerGag, GetClientUserId(iClient));
	}
	
#if MADEBUG
	if (iClient && IsClientInGame(iClient))
		LogToFile(g_sLogAction, "add gag: %N type %d, time %d", iClient, g_iTargetMuteType[iClient], iTime);
	else
		LogToFile(g_sLogAction, "add gag: %d type %d, time %d", iClient, g_iTargetMuteType[iClient], iTime);
#endif
}

void AddMute(int iClient, int iTime)
{
	if(g_iTargetMuteType[iClient] == 0)
		g_iTargetMuteType[iClient] = TYPEMUTE;
	else if (g_iTargetMuteType[iClient] == TYPEGAG)
	{
		AddSilence(iClient, iTime);
		return;
	}

	KillTimerMute(iClient);
	FunMute(iClient);
	if (iTime > 0 && iTime < 86400)
	{
		if(!g_hTimerMute[iClient])
			g_hTimerMute[iClient] = CreateTimer(float(iTime), TimerMute, GetClientUserId(iClient));
	}

#if MADEBUG
	if (iClient && IsClientInGame(iClient))
		LogToFile(g_sLogAction, "add mute: %N type %d, time %d", iClient, g_iTargetMuteType[iClient], iTime);
	else
		LogToFile(g_sLogAction, "add mute: %d type %d, time %d", iClient, g_iTargetMuteType[iClient], iTime);
#endif
}

void FunMute(int iClient)
{
	if (g_iTargetMuteType[iClient] == TYPEMUTE || g_iTargetMuteType[iClient] == TYPESILENCE)
		SetClientListeningFlags(iClient, VOICE_MUTED);
	else if (g_iGameTyp != GAMETYP_CSGO && IsClientInGame(iClient) && !IsPlayerAlive(iClient) && g_iCvar_Deadtalk)
	{
		if (g_iCvar_Deadtalk == 1)
			SetClientListeningFlags(iClient, VOICE_LISTENALL);
		else if (g_iCvar_Deadtalk == 2)
			SetClientListeningFlags(iClient, VOICE_TEAM);
	}
	else
		SetClientListeningFlags(iClient, VOICE_NORMAL);
}

void AddSilence(int iClient, int iTime)
{
	g_iTargetMuteType[iClient] = TYPESILENCE;
	FunMute(iClient);
	KillTimerMute(iClient);
	KillTimerGag(iClient);
	if (iTime > 0 && iTime < 86400)
	{
		if(!g_hTimerMute[iClient])
			g_hTimerMute[iClient] = CreateTimer(float(iTime), TimerMute, GetClientUserId(iClient));
		if(!g_hTimerGag[iClient])
			g_hTimerGag[iClient] = CreateTimer(float(iTime), TimerGag, GetClientUserId(iClient));
	}

#if MADEBUG
	if (iClient && IsClientInGame(iClient))
		LogToFile(g_sLogAction, "add silence: %N type %d, time %d", iClient, g_iTargetMuteType[iClient], iTime);
	else
		LogToFile(g_sLogAction, "add silence: %d type %d, time %d", iClient, g_iTargetMuteType[iClient], iTime);
#endif
}
//----------------------------------------------------------------------------------------------
void KillTimerBekap()
{
	if (g_hTimerBekap != null)
	{
		KillTimer(g_hTimerBekap);
		g_hTimerBekap = null;
		SentBekapInBd();
	}
}

public Action TimerBekap(Handle timer, any data)
{
#if MADEBUG
	LogToFile(g_sLogDateBase, "TimerBekap");
#endif
	ConnectBd(BDCONNECT, 0);
	return Plugin_Continue;
}
//--------------------------------------------------------------------------------------------------
void CreateSayBanned(char[] sAdminName, int iClient, int iCreated, int iTime, char[] sLength, char[] sReason)
{
	char sCreated[128];
	FormatTime(sCreated, sizeof(sCreated), FORMAT_TIME, iCreated);

	if(g_bBanSayPanel && g_iGameTyp != GAMETYP_CSGO)
	{
		char sEnds[128];
		if(!iTime)
			FormatEx(sEnds, sizeof(sEnds), "%T", "No ends", iClient);
		else
			FormatTime(sEnds, sizeof(sEnds), FORMAT_TIME, iCreated + iTime);
		CreateTeaxtDialog(iClient, "%T", "Banned Admin panel", iClient, sAdminName, sReason, sCreated, sEnds, sLength, g_sWebsite);
	}
	else
	{
		if (iClient && IsClientInGame(iClient))
			KickClient(iClient, "%T", "Banned Admin", iClient, sAdminName, sReason, sCreated, sLength, g_sWebsite);
	}
}

void CreateTeaxtDialog(int iClient, const char[] sMesag, any ...)
{
	char sTitle[125],
		sText[1025];
	VFormat(sText, sizeof(sText), sMesag, 3);
	KeyValues kvKey = new KeyValues("text");
	kvKey.SetNum("time", 200);
	FormatEx(sTitle, sizeof(sTitle), "%T", "Title Banned", iClient);
	kvKey.SetString("title", sTitle);
	kvKey.SetNum("level", 0);
	kvKey.SetString("msg", sText);
	if (iClient && IsClientInGame(iClient))
	{
	#if MADEBUG
		LogToFile(g_sLogAction, "CreateTeaxtDialog %N", iClient);
	#endif
		CreateDialog(iClient, kvKey, DialogType_Text);
		CreateTimer(0.2, TimerKick, GetClientUserId(iClient));
	}
	delete kvKey;
}

public Action TimerKick(Handle timer, any iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient)
		KickClient(iClient, "%T", "Banneds", iClient);
		
	return Plugin_Continue;
}

public Action TimerBan(Handle timer, any data)
{
	DataPack dPack = view_as<DataPack>(data);
	dPack.Reset();
	char sBuffer[MAX_IP_LENGTH];
	dPack.ReadString(sBuffer, sizeof(sBuffer));
	delete dPack;

	if (g_iServerBanTime < 1)
	{
		if (g_bServerBanTyp)
			ServerCommand("banid %d %s", g_iServerBanTime, sBuffer);
		else
			ServerCommand("addip %d %s", g_iServerBanTime, sBuffer);
	
#if MADEBUG
		if (g_bServerBanTyp)
			LogToFile(g_sLogAction, "banid %d %s", g_iServerBanTime, sBuffer);
		else
			LogToFile(g_sLogAction, "addip %d %s", g_iServerBanTime, sBuffer);
#endif
	}

	return Plugin_Continue;
}
//-------------------------------------------------------------------------------------------------------------
void LogOn()
{
	char sTime[64],
		sBuffer[64];
	FormatTime(sTime, sizeof(sTime), "%Y%m%d");
	
	FormatEx(sBuffer, sizeof(sBuffer), "logs/materialadmin/LogAdmin_%s.log", sTime);
	BuildPath(Path_SM, g_sLogAdmin, sizeof(g_sLogAdmin), sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "logs/materialadmin/LogConfig_%s.log", sTime);
	BuildPath(Path_SM, g_sLogConfig, sizeof(g_sLogConfig), sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "logs/materialadmin/LogDateBase_%s.log", sTime);
	BuildPath(Path_SM, g_sLogDateBase, sizeof(g_sLogDateBase), sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "logs/materialadmin/LogAction_%s.log", sTime);
	BuildPath(Path_SM, g_sLogAction, sizeof(g_sLogAction), sBuffer);
	
#if MADEBUG
	LogToFile(g_sLogAdmin, "plugin version %s game %i", MAVERSION, g_iGameTyp);
	LogToFile(g_sLogConfig, "plugin version %s game %i", MAVERSION, g_iGameTyp);
	LogToFile(g_sLogDateBase, "plugin version %s game %i", MAVERSION, g_iGameTyp);
	LogToFile(g_sLogAction, "plugin version %s game %i", MAVERSION, g_iGameTyp);
#endif
}

int GetFixedClientName(int iClient, char[] szBuffer, int iMaxLength) {
  char sName[MAX_NAME_LENGTH * 2 + 1];
  GetClientName(iClient, sName, sizeof(sName));

  for (int i = 0, len = strlen(sName), CharBytes; i < len;) {
    if ((CharBytes = GetCharBytes(sName[i])) == 4){
      len -= 4;
      for (int u = i; u <= len; u++) {
        sName[u] = sName[u+4];
      }
    } else {
      i += CharBytes;
    }
  }

  return strcopy(szBuffer, iMaxLength, sName);
}

stock bool IsBanTypeAvailable(int iClient, int iType)
{
	char szCommand[16];
	int iFlag;
	switch (iType)
	{
		case MA_BAN_STEAM:				strcopy(szCommand, sizeof(szCommand), "sm_ban"), iFlag = ADMFLAG_BAN;
		case MA_BAN_IP: 				strcopy(szCommand, sizeof(szCommand), "sm_banip"), iFlag = ADMFLAG_BAN;

		case MA_GAG:					strcopy(szCommand, sizeof(szCommand), "sm_gag"), iFlag = ADMFLAG_CHAT;
		case MA_MUTE:					strcopy(szCommand, sizeof(szCommand), "sm_mute"), iFlag = ADMFLAG_CHAT;
		case MA_SILENCE:				strcopy(szCommand, sizeof(szCommand), "sm_silence"), iFlag = ADMFLAG_CHAT;
		case MA_UNGAG:					strcopy(szCommand, sizeof(szCommand), "sm_ungag"), iFlag = ADMFLAG_CHAT;
		case MA_UNMUTE:					strcopy(szCommand, sizeof(szCommand), "sm_unmute"), iFlag = ADMFLAG_CHAT;
		case MA_UNSILENCE:				strcopy(szCommand, sizeof(szCommand), "sm_unsilence"), iFlag = ADMFLAG_CHAT;

		default:	ThrowError("Unknown ban type");
	}

	return CheckCommandAccess(iClient, szCommand, iFlag);
}

stock int GetItemDrawModeByPermission(int iClient, int iType)
{
	return IsBanTypeAvailable(iClient, iType) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
}

stock bool IsBanAvailable(int iClient)
{
	return IsBanTypeAvailable(iClient, MA_BAN_STEAM) ||
		IsBanTypeAvailable(iClient, MA_BAN_IP);
}

stock bool IsAnyCommTypeAvailable(int iClient)
{
	return (
		IsBanTypeAvailable(iClient, MA_GAG) ||
		IsBanTypeAvailable(iClient, MA_MUTE) ||
		IsBanTypeAvailable(iClient, MA_SILENCE)
	);
}

stock void VerifyServerID()
{
	if (g_bServerIDVerified)
	{
		return;
	}

	if (g_iServerID == -1)
	{
		if (g_dDatabase != null)
		{
			FetchServerIdDynamically();
		}

		return;
	}

	g_bServerIDVerified = true;
	RequestFrame(FireOnConfigSettingLate);
}

static void FireOnConfigSettingLate(any dontUsed)
{
	FireOnConfigSetting();
}

public void OnClientDisconnect_Post(int iClient)
{
	KillTimerMute(iClient);
	KillTimerGag(iClient);
}

GroupId FindOrCreateAdminGroup(const char[] szName)
{
	GroupId iGroup = FindAdmGroup(szName);
	if (iGroup == INVALID_GROUP_ID)
	{
		iGroup = CreateAdmGroup(szName);
	}

	return iGroup;
}

void SetupAdminGroupFlagsFromBits(GroupId iGroup, int iFlags)
{
	int iFlag;
	AdminFlag eFlag;
	for (int iFlagId = 0; iFlagId < AdminFlags_TOTAL; ++iFlagId)
	{
		iFlag = (1 << iFlagId);
		if (iFlags & iFlag)
		{
			BitToFlag(iFlag, eFlag);
			SetAdmGroupAddFlag(iGroup, eFlag, true);
		}
	}
}

void SetupAdminFlagsFromBits(AdminId iAdmin, int iFlags)
{
	int iFlag;
	AdminFlag eFlag;
	for (int iFlagId = 0; iFlagId < AdminFlags_TOTAL; ++iFlagId)
	{
		iFlag = (1 << iFlagId);
		if (iFlags & iFlag)
		{
			BitToFlag(iFlag, eFlag);
			SetAdminFlag(iAdmin, eFlag, true);
		}
	}
}

void UTIL_WriteFileString(File hFile, const char[] szString)
{
	hFile.WriteInt8(strlen(szString));
	hFile.WriteString(szString, false);
}

bool UTIL_ReadFileString(File hFile, char[] szBuffer, int iBufferLength)
{
	int iValueLength;
	if (!hFile.ReadUint8(iValueLength))
	{
		return false;
	}

	if (iValueLength >= iBufferLength)
	{
		return false;
	}

	if (iValueLength == 0)
	{
		szBuffer[0] = 0;
		return true;
	}

	int iReadBytes = hFile.ReadString(szBuffer, iBufferLength, iValueLength);
	if (iReadBytes == iBufferLength)
	{
		iReadBytes--;
	}

	szBuffer[iReadBytes] = 0;
	return (iReadBytes == iValueLength);
}
