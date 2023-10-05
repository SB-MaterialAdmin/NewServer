#include <sdktools_voice>
#include <materialadmin>

#define SHOW_AMOUNT 3.0

bool g_bShowText[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Material Admin No Voice", 
	author = "Bloomstorm", 
	description = "Check if client has mute and display it to him.", 
	version = MAVERSION, 
	url = "https://github.com/CrazyHackGUT/SB_Material_Design/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("manovoice.phrases");
}

public OnClientPutInServer(int client)
{
	g_bShowText[client] = false;
}

public void OnClientSpeaking(int client)
{
	if (!g_bShowText[client] && (MAGetClientMuteType(client) == 1 || MAGetClientMuteType(client) == 3))
	{
		g_bShowText[client] = true;
		CreateTimer(SHOW_AMOUNT, Timer_ShowText, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		
		SetHudTextParams(-1.0, -1.0, SHOW_AMOUNT, 0, 255, 127, 255, 1);
		
		ShowHudText(client, -1, "%T", "No voice");
	}
}

public Action Timer_ShowText(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client <= 0)
		return Plugin_Stop;
	g_bShowText[client] = false;
	return Plugin_Stop;
}