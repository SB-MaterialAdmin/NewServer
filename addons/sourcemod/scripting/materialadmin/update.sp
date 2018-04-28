void UpdateVersion()
{
	LogMessage("Try retrieve latest version...");
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, "https://raw.githubusercontent.com/SB-MaterialAdmin/NewServer/master/updates.version");

	if (hRequest != null)
	{
		if (SteamWorks_SetHTTPCallbacks(hRequest, OnRequestFinished) == false || SteamWorks_SendHTTPRequest(hRequest) == false) 
		{
			delete hRequest;
			LogMessage("Failed create request!");
		}
	}
	else
		LogMessage("Failed create descriptor on request!");
}

public int OnRequestFinished(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode) 
{
	if (eStatusCode != k_EHTTPStatusCode200OK) 
	{
		LogMessage("Failed request: Code %d", eStatusCode);
		delete hRequest;
		return;
	}

	if (SteamWorks_GetHTTPResponseBodyCallback(hRequest, OnRequestReceived) == false) 
	{
		LogMessage("Failed receive request body on custom callback!");
		delete hRequest;
		return;
	}

	delete hRequest;
}

public int OnRequestReceived(const char[] sData) 
{
	if (!StrEqual(sData, MAVERSION, false))
	{
		LogMessage("New version update %s %s", sData, MAUPDATE);
		DataPack dPack = new DataPack();
		dPack.WriteString(sData);
		CreateTimer(10.0, TimerUpdate, dPack);
	}
	else
		LogMessage("Version no update");
}

public Action TimerUpdate(Handle timer, any data)
{
	DataPack dPack = view_as<DataPack>(data);
	dPack.Reset();
	char sBuffer[25];
	dPack.ReadString(sBuffer, sizeof(sBuffer));
	delete dPack;
	
	PrintToChatAdmin("%t", "Update Version", sBuffer, MAUPDATE);
}