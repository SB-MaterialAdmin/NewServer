#pragma semicolon 1
//#pragma tabsize 0

#include <sourcemod>
#include <materialadmin>
#include <sdktools>
#include <regex>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <basecomm>

#pragma newdecls required

#define MAX_STEAMID_LENGTH 	32
#define MAX_IP_LENGTH 		64
#define CS_TEAM_NONE		0	// No team yet. 
#define CS_TEAM_SPECTATOR	1	// Spectators.
#define CS_TEAM_T 			2	// Terrorists.
#define CS_TEAM_CT			3	// Counter-Terrorists.

#define TYPE_STEAM 	AuthId_Steam2 // вид стим
#define FORMAT_TIME NULL_STRING	// формат времени показывающий игроку при бане, NULL_STRING = sm_datetime_format
#define SETTINGADMIN 		1	// функция управления админами.

#define	BDCONNECT			0
#define	BDCONNECT_ADMIN		1
#define	BDCONNECT_COM		2
#define	BDCONNECT_MENU		3

char g_sTarget[MAXPLAYERS+1][4][256];
#define TNAME 		0 	// Name
#define TIP 		1	// ip
#define TSTEAMID 	2 	// steam
#define TREASON 	3 	// Reason

int g_iTarget[MAXPLAYERS+1][2];
#define TTIME 	0	// time
#define TTYPE 	1	// type selkt

int g_iTargetType[MAXPLAYERS+1];
#define TYPE_BAN		1
#define TYPE_BANIP		2
#define TYPE_ADDBAN		3
#define TYPE_UNBAN		4
#define TYPE_GAG		5
#define TYPE_MUTE		6
#define TYPE_SILENCE	7
#define TYPE_UNGAG		8
#define TYPE_UNMUTE		9
#define TYPE_UNSILENCE	10

int g_iTargenMuteTime[MAXPLAYERS+1];
char g_sTargetMuteReason[MAXPLAYERS+1][256],
	g_sTargetMuteSteamAdmin[MAXPLAYERS+1][MAX_STEAMID_LENGTH],
	g_sNameReples[2][MAX_NAME_LENGTH];

int g_iTargetMuteType[MAXPLAYERS+1];
#define TYPEMUTE 		1	// мут
#define TYPEGAG 		2  	// чат
#define TYPESILENCE 	3	// мут и чат

#if SETTINGADMIN
char g_sAddAdminInfo[MAXPLAYERS+1][4][256];
#define ADDNAME 	0	// ник
#define ADDSTEAM 	1	// стим
#define ADDFLAG 	3	// флаг
int g_iAddAdmin[MAXPLAYERS+1][2];
#define ADDTIME 	0	// время админки
bool g_bAddAdminFlag[MAXPLAYERS+1][21];
#define MFLAG_ROOT			0	// 	"z"  root
#define MFLAG_GENERIC		1	// 	"b"	 Generic admin, required for admins
#define MFLAG_RESERVATION	2	// 	"a"	 Reserved slots
#define MFLAG_KICK			3	//	"c"	 Kick other players
#define MFLAG_BAN			4	//	"d"	 Banning other players
#define MFLAG_UNBAN			5	// 	"e"	 Removing bans
#define MFLAG_SLAY			6	//	"f"	 Slaying other players
#define MFLAG_CHANGEMAP		7	//	"g"	 Changing the map
#define MFLAG_CONVARS		8	//	"h"	 Changing cvars
#define MFLAG_CONFIG		9	//	"i"	 Changing configs
#define MFLAG_CHAT			10	//	"j"	 Special chat privileges
#define MFLAG_VOTE			11	//	"k"	 Voting
#define MFLAG_PASSWORD		12	//	"l"	 Password the server
#define MFLAG_RCON			13	//	"m"	 Remote console
#define MFLAG_CHEATS		14	//	"n"	 Change sv_cheats and related commands
#define MFLAG_CUSTOM1		15	//	"o"
#define MFLAG_CUSTOM2		16	//	"p"
#define MFLAG_CUSTOM3		17	//	"q"
#define MFLAG_CUSTOM4		18	//	"r"
#define MFLAG_CUSTOM5		19	//	"s"
#define MFLAG_CUSTOM6		20	//	"t"
char g_sAddAdminFlag[][] = {"z", "b", "a", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t"};
bool g_bAdminAdd[MAXPLAYERS+1][4];
#define ADDIMUN 	1	// имун
#define ADDPASS 	2	// пароль
#define ADDMENU 	3 	// меню
#endif

int	g_iServerID = -1,
	g_iOffMaxPlayers,
	g_iShowAdminAction,
	g_iServerBanTime,
	g_iBasecommTime,
	g_iMassBan,
	g_iBanTypMenu,
	g_iIgnoreBanServer,
	g_iIgnoreMuteServer,
	g_iAdminUpdateCache,
	g_iIgnoreFlagOfflineBan = ADMFLAG_BAN, // the default value
	g_iTargetReport[MAXPLAYERS+1]; // репорт юзер

bool g_bServerIDVerified = false;

Database g_dSQLite = null,
	g_dDatabase = null;
	
ArrayList g_aUserId[MAXPLAYERS+1],
	g_aTimeMenuSorting;
StringMap g_tAdminsExpired,
	g_tGroupBanTimeMax,
	g_tGroupMuteTimeMax,
	g_tAdminBanTimeMax,
	g_tAdminMuteTimeMax,
	g_tWebFlagSetingsAdmin,
	g_tWebFlagUnBanMute,
	g_tMenuTime;

bool g_bCvar_Alltalk;
int g_iCvar_ImmunityMode,
	g_iCvar_Deadtalk;
	
Handle g_hTimerMute[MAXPLAYERS+1],
	g_hTimerGag[MAXPLAYERS+1],
	g_hTimerBekap;
	
float g_fRetryTime = 60.0;

TopMenu g_tmAdminMenu;
Menu g_mReasonBMenu,
	g_mReasonMMenu,
	g_mHackingMenu;

char g_sServerIP[32], 
	g_sServerPort[8],
	g_sOffFormatTime[56],
	g_sOffMenuItems[128],
	g_sBanFlagPermanent[12],
	g_sWebsite[256],
	g_sDatabasePrefix[10] = "sb";
	
char g_sLogAdmin[256],
	g_sLogConfig[256],
	g_sLogDateBase[256],
	g_sLogAction[256];
	
bool g_bSayReason[MAXPLAYERS+1],
	g_bSayReasonReport[MAXPLAYERS+1],
	g_bOffMapClear,
	g_bAddBan,
	g_bUnBan,
	g_bReport,
	g_bBanSayPanel,
	g_bActionOnTheMy,
	g_bLalod,
	g_bReshashAdmin,
	g_bServerBanTyp,
	g_bSourceSleuth,
	g_bUnMuteUnBan,
	g_bNewConnect[MAXPLAYERS+1],
	g_bOnileTarget[MAXPLAYERS+1],
	g_bReportReason[MAXPLAYERS+1],
	g_bBanClientConnect[MAXPLAYERS+1];
	
// Admin KeyValues
char g_sGroupsLoc[128],
	g_sAdminsLoc[128],
	g_sOverridesLoc[128];
	
StringMap	g_hSettings;

int g_iGameTyp;
#define GAMETYP_CCS 	1 //css
#define GAMETYP_CCS34 	2 //css 34
#define GAMETYP_TF2 	3 //tf2
#define GAMETYP_CSGO 	4 //csgo
#define GAMETYP_l4d 	5 //Left4Dead
#define GAMETYP_l4d2 	6 //Left4Dead2

bool	g_bUseDatabaseFix = true; // default value, if we don't have this parameter in configuration file.

#define BINARY__MA_GROUPS_HEADER	0x4E414752
#define BINARY__MA_ADMINS_HEADER	0x4D414144
#define BINARY__MA_OVERRIDES_HEADER	0x4D414F56

#include "materialadmin/config.sp"
#include "materialadmin/admin.sp"
#include "materialadmin/menu.sp"
#include "materialadmin/function.sp"
#include "materialadmin/commands.sp"
#include "materialadmin/database.sp"
#include "materialadmin/native.sp"

public Plugin myinfo = 
{
	name = "Material Admin",
	author = "Material Admin Dev Team",
	description = "For to sm 1.9",
	version = MAVERSION,
	url = "https://github.com/SB-MaterialAdmin/NewServer"
};

#if defined GIT_COMMIT_ABBREVIATEDHASH
#if defined __TRAVIS
stock const char	g_szCompilerHost[]	= "Travis (CI)";
#else
stock const char	g_szCompilerHost[]	= "Unknown";
#endif

stock const char	g_szStartDelimter[]	= "------------------------------ [ Material Admin ] ------------------------------"; // by default, 80 symbols per line.
#endif

public void OnPluginStart() 
{
	LoadTranslations("materialadmin.phrases");
	LoadTranslations("common.phrases");

#if defined GIT_COMMIT_ABBREVIATEDHASH
	PrintToServer(g_szStartDelimter);
	PrintToServer("-> Build date:  " ... __DATE__ ... " " ... __TIME__);
	PrintToServer("-> Compiled on: %s", g_szCompilerHost);
	PrintToServer("-> Commit hash: " ... GIT_COMMIT_FULLHASH);
	PrintToServer("-> Version:     " ... MACOREVERSION);
	PrintToServer(g_szStartDelimter);
#endif

	switch(GetEngineVersion())
	{
		case Engine_CSS: 			g_iGameTyp = GAMETYP_CCS;
		case Engine_SourceSDK2006: 	g_iGameTyp = GAMETYP_CCS34;
		case Engine_CSGO: 			g_iGameTyp = GAMETYP_CSGO;
		case Engine_TF2: 			g_iGameTyp = GAMETYP_TF2;
		case Engine_Left4Dead: 		g_iGameTyp = GAMETYP_l4d;
		case Engine_Left4Dead2: 	g_iGameTyp = GAMETYP_l4d2;
	}

	RegComands();

	char sPath[56];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/materialadmin");
	if(!DirExists(sPath))
		CreateDirectory(sPath, 511);
	BuildPath(Path_SM, g_sGroupsLoc,sizeof(g_sGroupsLoc),"data/materialadmin/groups.bin");
	BuildPath(Path_SM, g_sAdminsLoc,sizeof(g_sAdminsLoc),"data/materialadmin/admins.bin");
	BuildPath(Path_SM, g_sOverridesLoc, sizeof(g_sOverridesLoc), "data/materialadmin/overrides.bin");
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/materialadmin");
	if(!DirExists(sPath))
		CreateDirectory(sPath, 511);

	LogOn();
	
	for (int i = 1; i <= MAXPLAYERS; i++)
		g_aUserId[i] = new ArrayList(ByteCountToCells(12));

	g_aTimeMenuSorting = new ArrayList(ByteCountToCells(12));
	g_tAdminsExpired = new StringMap();
	g_tGroupBanTimeMax = new StringMap();
	g_tGroupMuteTimeMax = new StringMap();
	g_tAdminBanTimeMax = new StringMap();
	g_tAdminMuteTimeMax = new StringMap();
	g_tWebFlagSetingsAdmin = new StringMap();
	g_tWebFlagUnBanMute = new StringMap();
	g_tMenuTime = new StringMap();
	g_hSettings = new StringMap();
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

	MACreateMenu();
	ReadConfig();
	MAConnectDB();

	// After start, force rehashing for correct logging all existing admins, if this is late loading.
	g_bReshashAdmin = true;
}

/*public void OnPluginEnd()
{
	
}*/

public void OnConfigsExecuted()
{
	char sFileName[200],
		sNewFileName[200];
	BuildPath(Path_SM, sFileName, sizeof(sFileName), "plugins/basebans.smx");
	if(FileExists(sFileName))
	{
		BuildPath(Path_SM, sNewFileName, sizeof(sNewFileName), "plugins/disabled/basebans.smx");
		ServerCommand("sm plugins unload basebans");
		if(FileExists(sNewFileName))
			DeleteFile(sNewFileName);
		RenameFile(sNewFileName, sFileName);
		LogToFile(g_sLogAction, "plugins/basebans.smx was unloaded and moved to plugins/disabled/basebans.smx");
	}
	
	BuildPath(Path_SM, sFileName, sizeof(sFileName), "plugins/basecomm.smx");
	if(FileExists(sFileName))
	{
		BuildPath(Path_SM, sNewFileName, sizeof(sNewFileName), "plugins/disabled/basecomm.smx");
		ServerCommand("sm plugins unload basecomm");
		if(FileExists(sNewFileName))
			DeleteFile(sNewFileName);
		RenameFile(sNewFileName, sFileName);
		LogToFile(g_sLogAction, "plugins/basecomm.smx was unloaded and moved to plugins/disabled/basecomm.smx");
	}
	
	BuildPath(Path_SM, sFileName, sizeof(sFileName), "plugins/ma_adminmenu.smx");
	if(FileExists(sFileName))
	{
		BuildPath(Path_SM, sFileName, sizeof(sFileName), "plugins/adminmenu.smx");
		if(FileExists(sFileName))
		{
			BuildPath(Path_SM, sNewFileName, sizeof(sNewFileName), "plugins/disabled/adminmenu.smx");
			ServerCommand("sm plugins unload adminmenu");
			if(FileExists(sNewFileName))
				DeleteFile(sNewFileName);
			RenameFile(sNewFileName, sFileName);
			LogToFile(g_sLogAction, "plugins/adminmenu.smx was unloaded and moved to plugins/disabled/adminmenu.smx");
		}
	}
	
	BuildPath(Path_SM, sFileName, sizeof(sFileName), "plugins/sourcecomms.smx");
	if(FileExists(sFileName))
	{
		BuildPath(Path_SM, sNewFileName, sizeof(sNewFileName), "plugins/disabled/sourcecomms.smx");
		ServerCommand("sm plugins unload sourcecomms");
		if(FileExists(sNewFileName))
			DeleteFile(sNewFileName);
		RenameFile(sNewFileName, sFileName);
		LogToFile(g_sLogAction, "plugins/sourcecomms.smx was unloaded and moved to plugins/disabled/sourcecomms.smx");
	}
	
	BuildPath(Path_SM, sFileName, sizeof(sFileName), "plugins/sourcebans.smx");
	if(FileExists(sFileName))
	{
		BuildPath(Path_SM, sNewFileName, sizeof(sNewFileName), "plugins/disabled/sourcebans.smx");
		ServerCommand("sm plugins unload sourcebans");
		if(FileExists(sNewFileName))
			DeleteFile(sNewFileName);
		RenameFile(sNewFileName, sFileName);
		LogToFile(g_sLogAction, "plugins/sourcebans.smx was unloaded and moved to plugins/disabled/sourcebans.smx");
	}
	
	if (g_bLalod)
	{
		LogOn();
		ReadConfig();
		if (g_iAdminUpdateCache && g_dDatabase != null)
			AdminHash();
		/*if (g_iAdminUpdateCache)
			ConnectBd(BDCONNECT_ADMIN, 0);
		else
			ConnectBd(BDCONNECT, 0);*/
	}
	else
	{
		FireOnConfigSetting();
		g_bLalod = true;
	}
	
	if(g_bOffMapClear) 
		ClearHistories();
	
	CheckBekapTime();
}

public void OnClientAuthorized(int iClient, const char[] sSteamID)
{
	if (sSteamID[0] == 'B' || sSteamID[9] == 'L' || g_bNewConnect[iClient] || g_iGameTyp != GAMETYP_CSGO) 
		return;

	CheckClientBan(iClient);
}

public Action OnClientPreAdminCheck(int iClient)
{
#if MADEBUG
	LogToFile(g_sLogAdmin, "OnClientPreAdminCheck(): %L (in admincache updating cycle? %s)", iClient, g_bReshashAdmin ? "Yes" : "No");
#endif

	return g_bReshashAdmin ?
		Plugin_Handled :
		Plugin_Continue;
}

public void OnClientPostAdminCheck(int iClient)
{
#if MADEBUG
	LogToFile(g_sLogAdmin, "OnClientPostAdminCheck(): %L (in admincache updating cycle? %s)", iClient, g_bReshashAdmin ? "Yes" : "No");
#endif

	if (!IsClientInGame(iClient) || IsFakeClient(iClient)) 
		return;

	if(!g_bNewConnect[iClient])
	{
		if (g_iGameTyp != GAMETYP_CSGO)
		{
			if (g_dDatabase != null)
				CheckClientBan(iClient);
			else
			{
				char sSteamID[MAX_STEAMID_LENGTH];
				GetClientAuthId(iClient, TYPE_STEAM, sSteamID, sizeof(sSteamID));
				CheckClientAdmin(iClient, sSteamID);
			}
		}
	}
	else
	{	
		if (g_iTargetMuteType[iClient] == TYPEMUTE || g_iTargetMuteType[iClient] == TYPESILENCE)
			FunMute(iClient);
	}
}

public void Event_PlayerDisconnect(Event eEvent, const char[] sEName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

	if (!iClient || IsFakeClient(iClient) || g_bBanClientConnect[iClient]) 
	{
		eEvent.BroadcastDisabled = true;
		return;
	}

#if SETTINGADMIN
	ResetFlagAddAdmin(iClient);
#endif
	g_bNewConnect[iClient] = false;
	g_bSayReason[iClient] = false;
	g_bSayReasonReport[iClient] = false;
	g_bReportReason[iClient] = false;
	g_iTargetMuteType[iClient] = 0;
	g_sTargetMuteReason[iClient][0] = '\0';
	g_sTargetMuteSteamAdmin[iClient][0] = '\0';
	g_iTargenMuteTime[iClient] = 0;
	KillTimerMute(iClient);
	KillTimerGag(iClient);
	
	char sSteamID[MAX_STEAMID_LENGTH];
	if (!GetSteamAuthorized(iClient, sSteamID))
		return;
	
	if(g_iIgnoreFlagOfflineBan && !((GetUserFlagBits(iClient) & g_iIgnoreFlagOfflineBan) == g_iIgnoreFlagOfflineBan))
	{
		char sName[MAX_NAME_LENGTH],
		sIP[MAX_IP_LENGTH];

		GetClientName(iClient, sName, sizeof(sName));
		GetClientIP(iClient, sIP, sizeof(sIP));
		SetOflineInfo(sSteamID, sName, sIP);

	#if MADEBUG
		char sTime[64];
		FormatTime(sTime, sizeof(sTime), g_sOffFormatTime, GetTime());
		LogToFile(g_sLogAction, "New: %s %s - %s ; %s.", sName, sSteamID, sIP, sTime);
	#endif
	}
	/*else
	{
		if (ChekBD(g_dDatabase, "BDSetActivityAdmin"))
			BDSetActivityAdmin(iClient, sSteamID);
	}*/
}
