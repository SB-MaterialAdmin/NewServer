void MACreateMenu()
{
	g_mReasonBMenu = new Menu(MenuHandler_MenuBReason);
	g_mReasonBMenu.ExitBackButton = true;
	
	g_mReasonMMenu = new Menu(MenuHandler_MenuMReason);
	g_mReasonMMenu.ExitBackButton = true;

	g_mHackingMenu = new Menu(MenuHandler_MenuHacking);
	g_mHackingMenu.ExitBackButton = true;
	
	
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu aTopMenus = TopMenu.FromHandle(aTopMenu);

	if (aTopMenus == g_tmAdminMenu)
		return;

	g_tmAdminMenu = aTopMenus;
	
	TopMenuObject CategoryId = g_tmAdminMenu.AddCategory("materialadmin", Handle_materialadmin, "materialadmin", ADMFLAG_GENERIC);

	if (CategoryId == INVALID_TOPMENUOBJECT)
		return;
	
	g_tmAdminMenu.AddItem("ma_target_online", Handle_MenuTargetOnline, CategoryId, "ma_target_online", ADMFLAG_GENERIC);
	g_tmAdminMenu.AddItem("ma_target_offline", Handle_MenuTargetOffline, CategoryId, "ma_target_offline", ADMFLAG_GENERIC);
	g_tmAdminMenu.AddItem("ma_target_list", Handle_MenuTargetList, CategoryId, "ma_target_list", ADMFLAG_GENERIC);
	g_tmAdminMenu.AddItem("ma_setting", Handle_MenuSetting, CategoryId, "ma_setting", ADMFLAG_ROOT);
#if SETTINGADMIN
	g_tmAdminMenu.AddItem("ma_setting_admin", Handle_MenuSettingAdmin, CategoryId, "ma_setting_admin", ADMFLAG_ROOT);
#endif
}

public void Handle_materialadmin(Handle topmenu, TopMenuAction action, TopMenuObject topobj_id, int iClient, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption: 	FormatEx(buffer, maxlength, "%T", "AdminMenu_Main", iClient);
		case TopMenuAction_DisplayTitle: 	FormatEx(buffer, maxlength, "%T:", "AdminMenu_Main", iClient);
	}
}

public void Handle_MenuTargetOnline(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int iClient, char[] sBuffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, maxlength, "%T", "OnlineTitle", iClient);
		case TopMenuAction_SelectOption: 
		{
			g_aUserId[iClient].Clear();
			ShowTargetOnline(iClient);
		}
	}
}

public void Handle_MenuTargetOffline(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int iClient, char[] sBuffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, maxlength, "%T", "OfflineTitle", iClient);
		case TopMenuAction_SelectOption: BdTargetOffline(iClient);
	}
}

public void Handle_MenuTargetList(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int iClient, char[] sBuffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, maxlength, "%T", "ListTitle", iClient);
		case TopMenuAction_SelectOption: 
		{
			g_aUserId[iClient].Clear();
			ShowTargetList(iClient);
		}
	}
}

public void Handle_MenuSetting(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int iClient, char[] sBuffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, maxlength, "%T", "SettingTitle", iClient);
		case TopMenuAction_SelectOption: ShowSetting(iClient);
	}
}

#if SETTINGADMIN
public void Handle_MenuSettingAdmin(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int iClient, char[] sBuffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption: FormatEx(sBuffer, maxlength, "%T", "SettingAdminTitle", iClient);
		case TopMenuAction_SelectOption: ShowSettingAdmin(iClient);
	}
}
#endif

void ShowSetting(int iClient)
{
	Menu Mmenu = new Menu(MenuHandler_Setting);
	Mmenu.SetTitle("%T:", "SettingTitle", iClient);
	
	char sTitle[128];
	FormatEx(sTitle, sizeof(sTitle), "%T", "ReheshAdmin", iClient);
	Mmenu.AddItem("", sTitle);
	FormatEx(sTitle, sizeof(sTitle), "%T", "ClearHistory", iClient);
	Mmenu.AddItem("", sTitle);
	FormatEx(sTitle, sizeof(sTitle), "%T", "ReloadConfig", iClient);
	Mmenu.AddItem("", sTitle);
	FormatEx(sTitle, sizeof(sTitle), "%T", "ReloadConnect", iClient);
	Mmenu.AddItem("", sTitle);
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_Setting(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				g_tmAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			switch(iSlot)
			{
				case 0:
				{
					g_bReshashAdmin = true;
				#if MADEBUG
					LogToFile(g_sLogAction, "Rehash Admin menu.");
				#endif
					AdminHash();
					PrintToChat2(iClient, "%T",  "ReheshAdminOk", iClient);
				}
				case 1:
				{
					ClearHistories();
					PrintToChat2(iClient, "%T", "Clear history", iClient);
				}
				case 2:
				{
					ReadConfig();
					PrintToChat2(iClient, "%T",  "Reload config", iClient);
				}
				case 3: ConnectBd(BDCONNECT_MENU, iClient);
			}
			ShowSetting(iClient);
		}
	}
	
	return 0;
}

//меню выбора игрока офлайн
public void ShowTargetOffline(Database db, DBResultSet dbRs, const char[] sError, any iClient)
{
	if(!dbRs || sError[0])
	{
		LogError("Error loading offline (%s)", sError);
		return;
	}

	if(!(iClient = GetClientOfUserId(iClient)))
		return;
	
	Menu Mmenu = new Menu(MenuHandler_OfflineList);
	Mmenu.SetTitle("%T:", "SelectPlayerTitle", iClient);
	char sTitle[256];

	if (dbRs.RowCount)
	{
		char sName[MAX_NAME_LENGTH],
			 sSteamID[MAX_STEAMID_LENGTH],
			 sID[12],
			 sTime[64];

		while(dbRs.FetchRow())
		{
			dbRs.FetchString(0, sID, sizeof(sID));
			dbRs.FetchString(1, sSteamID, sizeof(sSteamID));
			dbRs.FetchString(2, sName, sizeof(sName));
			FormatTime(sTime, sizeof(sTime), g_sOffFormatTime, dbRs.FetchInt(3));
			
			FormatEx(sTitle, sizeof(sTitle), "%s", g_sOffMenuItems);
			
			ReplaceString(sTitle, sizeof(sTitle), "{NICK}", sName);
			ReplaceString(sTitle, sizeof(sTitle), "{STEAMID}", sSteamID);
			ReplaceString(sTitle, sizeof(sTitle), "{TIME}", sTime);

			AdminId AID = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
			if (AID == INVALID_ADMIN_ID || CanAdminTarget(GetUserAdmin(iClient), AID))
				Mmenu.AddItem(sID, sTitle);
		#if MADEBUG
			LogToFile(g_sLogAction,"Menu: %s, %s - %s", sID, sSteamID, sTitle);
		#endif
		}
	}
	else
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "No players history", iClient);
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);	
	}
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_OfflineList(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				g_tmAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			char sID[12];
			Mmenu.GetItem(iSlot, sID, sizeof(sID));
			
			g_bOnileTarget[iClient] = false;
		#if MADEBUG
			LogToFile(g_sLogAction, "Menu select BanList: %s", sID);
		#endif
			
			BdGetInfoOffline(iClient, StringToInt(sID));
		}
	}
	
	return 0;
}
// online
void ShowTargetOnline(int iClient)
{
	char sTitle[192];
	bool bIsClien = false;
	int iTarget;
	int iSpecMode = GetEntProp(iClient, Prop_Send, "m_iObserverMode");
	
	Menu Mmenu = new Menu(MenuHandler_OnlineList);
	Mmenu.SetTitle("%T:", "SelectPlayerTitle", iClient);
	
	if (g_iMassBan == 2)
	{
		if (CheckAdminFlags(iClient, ADMFLAG_ROOT))
		{
			FormatEx(sTitle, sizeof(sTitle), "%T", "All", iClient);
			Mmenu.AddItem("-1", sTitle);
		}

		if(g_iGameTyp == GAMETYP_TF2)
			FormatEx(sTitle, sizeof(sTitle), "%T", "Blue", iClient);
		else
			FormatEx(sTitle, sizeof(sTitle), "%T", "CT", iClient);
		Mmenu.AddItem("-2", sTitle);
			
		if(g_iGameTyp == GAMETYP_TF2)
			FormatEx(sTitle, sizeof(sTitle), "%T", "Red", iClient);
		else
			FormatEx(sTitle, sizeof(sTitle), "%T", "T", iClient);
		Mmenu.AddItem("-3", sTitle);
	}

	if (g_iMassBan)
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "Clients", iClient);
		if (g_aUserId[iClient].Length != 0)
			Mmenu.AddItem("0", sTitle);
		else
			Mmenu.AddItem("0", sTitle, ITEMDRAW_DISABLED);
	}
	
	if ((g_iGameTyp == GAMETYP_CCS34) && iSpecMode == 3 || iSpecMode == 4 || (g_iGameTyp != GAMETYP_CCS34) && iSpecMode == 5) // 3 тока для ксс 34
	{
		iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
		if ((iTarget > 0 && iTarget < MaxClients) && !IsFakeClient(iTarget) && CheckAdminImune(iClient, iTarget))
		{
			AdminMenuAddClients(Mmenu, iClient, iTarget, g_iMassBan);
			bIsClien = true;
		}
	}
	else
		iTarget = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && i != iTarget && CheckAdminImune(iClient, i))
		{
			AdminMenuAddClients(Mmenu, iClient, i, g_iMassBan);
			bIsClien = true;
		}
	}
	
	if (!bIsClien)
	{
		if(g_iMassBan)
			Mmenu.RemoveAllItems();

		FormatEx(sTitle, sizeof(sTitle), "%T", "no target", iClient);
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	}
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

void AdminMenuAddClients(Menu Mmenu, int iClient, int iTarget, int iMassBan)
{
	char sTitle[256],
		sBuffer[256],
		sOption[32];
	int iUserId = GetClientUserId(iTarget);
	IntToString(iUserId, sOption, sizeof(sOption));

	if(iMassBan)
	{
		if (g_aUserId[iClient] != null)
		{
			int iPos = g_aUserId[iClient].FindValue(iUserId);
			if (iPos > -1)
				FormatEx(sBuffer, sizeof(sBuffer), "[v] %N (%d)", iTarget, iUserId);
			else
				FormatEx(sBuffer, sizeof(sBuffer), "[ ] %N (%d)", iTarget, iUserId);
		}
		else
			FormatEx(sBuffer, sizeof(sBuffer), "[ ] %N (%d)", iTarget, iUserId);
	}
	else
		FormatEx(sBuffer, sizeof(sBuffer), "%N (%d)", iTarget, iUserId);
	
	switch(g_iTargetMuteType[iTarget])
	{
		case 0: 			FormatEx(sTitle, sizeof(sTitle), "[ ]%s", sBuffer);
		case TYPEMUTE: 		FormatEx(sTitle, sizeof(sTitle), "[m]%s", sBuffer);
		case TYPEGAG: 		FormatEx(sTitle, sizeof(sTitle), "[g]%s", sBuffer);
		case TYPESILENCE: 	FormatEx(sTitle, sizeof(sTitle), "[s]%s", sBuffer);
	}
	
#if MADEBUG
	LogToFile(g_sLogAction,"add client menu: admin %N -  %s %s", iClient, (GetUserAdmin(iTarget) == INVALID_ADMIN_ID)?"target":"admin target", sTitle);
#endif

	Mmenu.AddItem(sOption, sTitle);
}

public int MenuHandler_OnlineList(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				g_tmAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			char sOption[32];
			Mmenu.GetItem(iSlot, sOption, sizeof(sOption));

			g_iTarget[iClient][TTYPE] = StringToInt(sOption);
			
			if (g_iTarget[iClient][TTYPE] > 0)
			{
				int iPos = g_aUserId[iClient].FindValue(g_iTarget[iClient][TTYPE]);
				if (iPos > -1)
					g_aUserId[iClient].Erase(iPos);
				else
					g_aUserId[iClient].Push(g_iTarget[iClient][TTYPE]);
				
				if(g_iMassBan)
					ShowTargetOnline(iClient);
				else
				{
					g_iTarget[iClient][TTYPE] = 0;
					g_bOnileTarget[iClient] = true;
					ShowTypeMenu(iClient);
				}
			}
			else
			{
				g_bOnileTarget[iClient] = true;
				ShowTypeMenu(iClient);
			}
		}
	}
	
	return 0;
}

void ShowTypeMenu(int iClient)
{
	char sTitle[192];

	Menu Mmenu = new Menu(MenuHandler_MenuType);
	Mmenu.SetTitle("%T:", "SetTitle", iClient);
	
	FormatEx(sTitle, sizeof(sTitle), "%T", "SetBan", iClient); // ban
	Mmenu.AddItem(NULL_STRING, sTitle, IsBanAvailable(iClient) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	FormatEx(sTitle, sizeof(sTitle), "%T", "SetMute", iClient); // mute
	Mmenu.AddItem(NULL_STRING, sTitle, IsAnyCommTypeAvailable(iClient) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuType(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				g_tmAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			switch(iSlot)
			{
				case 0: 
				{
					if (!g_iBanTypMenu)
						ShowTypeBanMenu(iClient);
					else
					{
						g_iTargetType[iClient] = g_iBanTypMenu;
						ShowTimeMenu(iClient);
					}
				}
				case 1: 
				{
					if(g_bOnileTarget[iClient])
						ShowTypeMuteMenu(iClient);
					else
						BdGetMuteType(iClient, 0);
				}
			}
		}
	}
	
	return 0;
}

void ShowTypeBanMenu(int iClient)
{
	char sTitle[192];

	Menu Mmenu = new Menu(MenuHandler_MenuTypeBan);
	Mmenu.SetTitle("%T:", "SetTitle", iClient);

	FormatEx(sTitle, sizeof(sTitle), "%T", "Steam", iClient); // steam
	Mmenu.AddItem(NULL_STRING, sTitle, GetItemDrawModeByPermission(iClient, MA_BAN_STEAM));

	FormatEx(sTitle, sizeof(sTitle), "%T", "Ip", iClient); // ip
	Mmenu.AddItem(NULL_STRING, sTitle, GetItemDrawModeByPermission(iClient, MA_BAN_IP));

	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuTypeBan(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				g_tmAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			switch(iSlot)
			{
				case 0: g_iTargetType[iClient] = TYPE_BAN;
				case 1: g_iTargetType[iClient] = TYPE_BANIP;
			}
			ShowTimeMenu(iClient);
		}
	}
	
	return 0;
}

void ShowTypeMuteMenu(int iClient)
{
	char sTitle[192];

	Menu Mmenu = new Menu(MenuHandler_MenuTypeMute);
	Mmenu.SetTitle("%T:", "SetTitle", iClient);
	
	if(g_bOnileTarget[iClient])
	{
		if (g_aUserId[iClient].Length == 1)
		{
			int iTarget = GetClientOfUserId(g_aUserId[iClient].Get(0));
			MenuTypeAdd(iClient, iTarget, Mmenu);
		}
		else
		{
			FormatEx(sTitle, sizeof(sTitle), "%T", "Mute", iClient); // мут
			Mmenu.AddItem(NULL_STRING, sTitle, GetItemDrawModeByPermission(iClient, MA_MUTE));

			FormatEx(sTitle, sizeof(sTitle), "%T", "Gag", iClient); // чат
			Mmenu.AddItem(NULL_STRING, sTitle, GetItemDrawModeByPermission(iClient, MA_GAG));
			
			FormatEx(sTitle, sizeof(sTitle), "%T", "Silence", iClient); // силенце
			Mmenu.AddItem(NULL_STRING, sTitle, GetItemDrawModeByPermission(iClient, MA_SILENCE));

			FormatEx(sTitle, sizeof(sTitle), "%T", "unMute", iClient); // ун мут
			Mmenu.AddItem(NULL_STRING, sTitle, GetItemDrawModeByPermission(iClient, MA_UNMUTE));
			
			FormatEx(sTitle, sizeof(sTitle), "%T", "unGag", iClient); // ун чат
			Mmenu.AddItem(NULL_STRING, sTitle, GetItemDrawModeByPermission(iClient, MA_UNGAG));

			FormatEx(sTitle, sizeof(sTitle), "%T", "unSilence", iClient); // ун силенце
			Mmenu.AddItem(NULL_STRING, sTitle, GetItemDrawModeByPermission(iClient, MA_UNSILENCE));
		}
	}
	else
		MenuTypeAdd(iClient, 0, Mmenu);
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

void MenuTypeAdd(int iClient, int iTarget, Menu Mmenu)
{
	bool bMut;
	if (g_iTargetMuteType[iTarget] > 0)
		bMut = IsUnMuteUnBan(iClient, g_sTargetMuteSteamAdmin[iTarget]);
	
	
	char sTitle[192],
		 sBuffer[25];
		
	FormatEx(sBuffer, sizeof(sBuffer), "%i %b", iTarget, bMut);
	FormatEx(sTitle, sizeof(sTitle), "%T", "Mute", iClient); // мут
	if(!g_iTargetMuteType[iTarget] || g_iTargetMuteType[iTarget] == TYPEGAG && !bMut || g_iTargetMuteType[iTarget] && bMut)
		Mmenu.AddItem(sBuffer, sTitle, GetItemDrawModeByPermission(iClient, MA_MUTE));
	else
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);

	FormatEx(sTitle, sizeof(sTitle), "%T", "Gag", iClient); // чат
	if(!g_iTargetMuteType[iTarget] || g_iTargetMuteType[iTarget] == TYPEMUTE && !bMut || g_iTargetMuteType[iTarget] && bMut)
		Mmenu.AddItem(sBuffer, sTitle, GetItemDrawModeByPermission(iClient, MA_GAG));
	else
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);

	FormatEx(sTitle, sizeof(sTitle), "%T", "Silence", iClient); // силенце
	if(!g_iTargetMuteType[iTarget] || g_iTargetMuteType[iTarget] && bMut)
		Mmenu.AddItem(sBuffer, sTitle, GetItemDrawModeByPermission(iClient, MA_SILENCE));
	else
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);

	FormatEx(sTitle, sizeof(sTitle), "%T", "unMute", iClient); // ун мут
	if(g_iTargetMuteType[iTarget] == TYPEMUTE && bMut || g_iTargetMuteType[iTarget] == TYPESILENCE && bMut)
		Mmenu.AddItem("", sTitle, GetItemDrawModeByPermission(iClient, MA_UNMUTE));
	else
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);

	FormatEx(sTitle, sizeof(sTitle), "%T", "unGag", iClient); // ун чат
	if(g_iTargetMuteType[iTarget] == TYPEGAG && bMut || g_iTargetMuteType[iTarget] == TYPESILENCE && bMut)
		Mmenu.AddItem("", sTitle, GetItemDrawModeByPermission(iClient, MA_UNGAG));
	else
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);

	FormatEx(sTitle, sizeof(sTitle), "%T", "unSilence", iClient); // ун силенце
	if(g_iTargetMuteType[iTarget] == TYPESILENCE && bMut)
		Mmenu.AddItem("", sTitle, GetItemDrawModeByPermission(iClient, MA_UNSILENCE));
	else
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
}

public int MenuHandler_MenuTypeMute(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				g_tmAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			switch(iSlot)
			{
				case 0: g_iTargetType[iClient] = TYPE_MUTE;
				case 1: g_iTargetType[iClient] = TYPE_GAG;
				case 2: g_iTargetType[iClient] = TYPE_SILENCE;
				case 3: g_iTargetType[iClient] = TYPE_UNMUTE;
				case 4: g_iTargetType[iClient] = TYPE_UNGAG;
				case 5: g_iTargetType[iClient] = TYPE_UNSILENCE;
			}

			if (iSlot > 2)
			{
				g_sTarget[iClient][TREASON][0] = '\0';
				OnlineClientSet(iClient);
			}
			else
			{
				char sOption[25],
				sTemp[2][12];
				Mmenu.GetItem(iSlot, sOption, sizeof(sOption));
			#if MADEBUG
				LogToFile(g_sLogAction,"Menu select TypeMute: Option %s", sOption);
			#endif
				ExplodeString(sOption, " ", sTemp, 2, 12);
				int iTarget = StringToInt(sTemp[0]);
				int iUn = StringToInt(sTemp[1]);
				
				if (g_iTargetMuteType[iTarget] > 0 && !iUn)
				{
					g_sTarget[iClient][TREASON] = g_sTargetMuteReason[iTarget];
					g_iTarget[iClient][TTIME] = g_iTargenMuteTime[iTarget]/60;
					OnlineClientSet(iClient);
				}
				else
					ShowTimeMenu(iClient);
			}

		#if MADEBUG
			LogToFile(g_sLogAction,"Menu select TypeMute: slot %i , type %d", iSlot, g_iTargetType[iClient]);
		#endif
		}
	}
	
	return 0;
}

//меню выбора времени
void ShowTimeMenu(int iClient)
{
	char sTitle[128],
		 sValue[12];
	int iTime;

	Menu Mmenu = new Menu(MenuHandler_MenuTime);
	Mmenu.SetTitle("%T:", "SelectTimeTitle", iClient);
	
	int iMaxTime = GetAdminMaxTime(iClient);
	
	#if MADEBUG
		LogToFile(g_sLogAction,"Menu Time: max time %d", iMaxTime);
	#endif
	
	for (int i = 0; i < g_aTimeMenuSorting.Length; i++)
	{
		iTime = g_aTimeMenuSorting.Get(i);

		if (g_iTargetType[iClient] < TYPE_ADDBAN && iTime == -1 || g_iTargetType[iClient] < TYPE_ADDBAN && !iTime && !CheckAdminFlags(iClient, ReadFlagString(g_sBanFlagPermanent)) || iMaxTime > -1 && !iTime)
		{
		#if MADEBUG
			LogToFile(g_sLogAction,"Menu Time: no time %d", iTime);
		#endif
			continue;
		}
		
		if ((!iMaxTime && iMaxTime < iTime) || (!iMaxTime && iTime == -1) || (iTime <= iMaxTime || iMaxTime == -1))
		{
		#if MADEBUG
			LogToFile(g_sLogAction,"Menu Time: yes time %d", iTime);
		#endif
			IntToString(iTime, sValue, sizeof(sValue));
			if(g_tMenuTime.GetString(sValue, sTitle, sizeof(sTitle)))
			{
			#if MADEBUG
				LogToFile(g_sLogAction,"Menu Time: add time %s - %s", sValue, sTitle);
			#endif
				Mmenu.AddItem(sValue, sTitle);
			}
		}
	}
	
	if (!Mmenu.ItemCount)
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "No time", iClient);
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	}

	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuTime(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
			{
				if (g_bOnileTarget[iClient])
				{
					g_aUserId[iClient].Clear();
					ShowTargetOnline(iClient);
				}
				else
					BdTargetOffline(iClient);
			}
		}
		case MenuAction_Select:
		{
			char sInfo[12];
			Mmenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			g_iTarget[iClient][TTIME] = StringToInt(sInfo);
		#if MADEBUG
			LogToFile(g_sLogAction,"Menu select time: %s", sInfo);
		#endif

			if(g_iTargetType[iClient] <= TYPE_BANIP)
			{
				g_bReportReason[iClient] = false;
				ShowBanReasonMenu(iClient);
			}
			else
				ShowMuteReasonMenu(iClient);
		}
	}
	
	return 0;
}

void ShowMuteReasonMenu(int iClient)
{
	g_mReasonMMenu.SetTitle("%T:", "SelectReasonTitle", iClient);
	g_mReasonMMenu.Display(iClient, MENU_TIME_FOREVER);
}

//меню выбора причины бана
void ShowBanReasonMenu(int iClient)
{
	g_mReasonBMenu.SetTitle("%T:", "SelectReasonTitle", iClient);
	g_mReasonBMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuBReason(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
			{
				if (g_bReportReason[iClient])
					ReportMenu(iClient);
				else
					ShowTimeMenu(iClient);
			}
		}
		case MenuAction_Select:
		{
			char sInfo[256];
			Mmenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			if(StrEqual("Hacking", sInfo))
			{
				ShowHackingMenu(iClient);
				return 0;
			}
			if(StrEqual("Own Reason", sInfo))
			{
				PrintToChat2(iClient, "%T", "Say reason", iClient);
				if (g_bReportReason[iClient])
					g_bSayReasonReport[iClient] = true;
				else
					g_bSayReason[iClient] = true;
				return 0;
			}
			
		#if MADEBUG
			LogToFile(g_sLogAction,"Menu select reason: %s", sInfo);
		#endif
		
			if (g_bReportReason[iClient])
				SetBdReport(iClient, sInfo);
			else
			{
				strcopy(g_sTarget[iClient][TREASON], sizeof(g_sTarget[][]), sInfo);
				OnlineClientSet(iClient);
			}
		}
	}
	
	return 0;
}

public int MenuHandler_MenuMReason(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				ShowTimeMenu(iClient);
		}
		case MenuAction_Select:
		{
			char sInfo[256];
			Mmenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			if(StrEqual("Own Reason", sInfo))
			{
				PrintToChat2(iClient, "%T", "Say reason", iClient);
				g_bSayReason[iClient] = true;
				return 0;
			}
			strcopy(g_sTarget[iClient][TREASON], sizeof(g_sTarget[][]), sInfo);
		#if MADEBUG
			LogToFile(g_sLogAction,"Menu select reason: %s", sInfo);
		#endif
			OnlineClientSet(iClient);
		}
	}
	
	return 0;
}

void ShowHackingMenu(int iClient)
{
	g_mHackingMenu.SetTitle("%T - %s", "SelectReasonTitle", iClient, g_sTarget[iClient][TNAME]);
	g_mHackingMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuHacking(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				ShowBanReasonMenu(iClient);
		}
		case MenuAction_Select:
		{
			char sInfo[256];
			Mmenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			
		#if MADEBUG
			LogToFile(g_sLogAction,"Menu select hacking: %s", sInfo);
		#endif
		
			if (g_bReportReason[iClient])
				SetBdReport(iClient, sInfo);
			else
			{
				strcopy(g_sTarget[iClient][TREASON], sizeof(g_sTarget[][]), sInfo);
				OnlineClientSet(iClient);
			}
		}
	}
	
	return 0;
}

void OnlineClientSet(int iClient)
{
	if (g_bOnileTarget[iClient])
	{
	#if MADEBUG
		LogToFile(g_sLogAction,"Online client set: client %d, tip %d", iClient, g_iTarget[iClient][TTYPE]);
	#endif
		GetClientToBd(iClient, g_iTarget[iClient][TTYPE]);
	}
	else
	{
	#if MADEBUG
		LogToFile(g_sLogAction,"Offline client set: client %d", iClient);
	#endif
		CheckBanInBd(iClient, 0, 1, g_sTarget[iClient][TSTEAMID]);
	}
}

void ShowTargetList(int iClient)
{
	char sTitle[256];
	bool bIsClien = false;
	
	Menu Mmenu = new Menu(MenuHandler_TargetList);
	Mmenu.SetTitle("%T:", "SelectPlayerTitle", iClient);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_iTargetMuteType[i] > 0 && CheckAdminImune(iClient, i))
		{
			AdminMenuAddClients(Mmenu, iClient, i, 0);
			bIsClien = true;
		}
	}
	
	if (!bIsClien)
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "no target", iClient);
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	}
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_TargetList(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				g_tmAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			char sOption[32];
			Mmenu.GetItem(iSlot, sOption, sizeof(sOption));

			ShowListTipe(iClient, sOption);
		}
	}
	
	return 0;
}

void ShowListTipe(int iClient, char[] sOption)
{
	char sTitle[192];

	Menu Mmenu = new Menu(MenuHandler_ListTipe);
	Mmenu.SetTitle("%T:", "SetTitle", iClient);
	
	FormatEx(sTitle, sizeof(sTitle), "%T", "Show", iClient); // показ
	Mmenu.AddItem(sOption, sTitle);
	
	FormatEx(sTitle, sizeof(sTitle), "%T", "Run", iClient); // выполнить
	int iTarget = GetClientOfUserId(StringToInt(sOption));
	if (iTarget && IsUnMuteUnBan(iClient, g_sTargetMuteSteamAdmin[iTarget]))
		Mmenu.AddItem(sOption, sTitle);
	else
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_ListTipe(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				ShowTargetList(iClient);
		}
		case MenuAction_Select:
		{
			char sOption[32];
			Mmenu.GetItem(iSlot, sOption, sizeof(sOption));
			
			g_aUserId[iClient].Push(StringToInt(sOption));

			if (!iSlot)
				BDGetInfoMute(iClient, sOption);
			else
			{
				g_bOnileTarget[iClient] = true;
				ShowTypeMuteMenu(iClient);
			}
		}
	}
	
	return 0;
}

void ShowInfoMuteMenu(int iClient, int iCreated, int iEnds, int iLength, char[] sReason, char[] sNameAdmin)
{
	if (!iClient || !IsClientInGame(iClient))
		return;

	if (g_aUserId[iClient].Length < 0) return;
	int iTarget = GetClientOfUserId(g_aUserId[iClient].Get(0));
	char sTitle[256],
		sBuffer[64];

	Menu Mmenu = new Menu(MenuHandler_InfoMute);
	if (iTarget)
		Mmenu.SetTitle("%T: %N", "ListInfoTitle", iClient, iTarget);
	else
		Mmenu.SetTitle("%T:", "ListInfoTitle", iClient);
	
	FormatEx(sTitle, sizeof(sTitle), "%T:\n%s", "Admin", iClient, sNameAdmin);
	Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	
	FormatVrema(iClient, iLength, sBuffer, sizeof(sBuffer));
	FormatEx(sTitle, sizeof(sTitle), "%T:\n%s", "Time", iClient, sBuffer);
	Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	
	if (sReason[0])
		FormatEx(sTitle, sizeof(sTitle), "%T:\n%s", "Reason", iClient, sReason);
	else
		FormatEx(sTitle, sizeof(sTitle), "%T:\n%T", "Reason", iClient, "No reason", iClient);
	Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	
	FormatTime(sBuffer, sizeof(sBuffer), g_sOffFormatTime, iCreated);
	FormatEx(sTitle, sizeof(sTitle), "%T:\n%s", "TimeCreated", iClient, sBuffer);
	Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	
	if (iLength > 0)
		FormatTime(sBuffer, sizeof(sBuffer), g_sOffFormatTime, iEnds);
	else
		FormatVrema(iClient, iLength, sBuffer, sizeof(sBuffer));
	FormatEx(sTitle, sizeof(sTitle), "%T:\n%s", "TimeEnds", iClient, sBuffer);
	Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_InfoMute(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
			{
				g_aUserId[iClient].Clear();
				ShowTargetList(iClient);
			}
		}
	}
	
	return 0;
}
//--------------------------------------------------------------------------------------------------
// репорт меню
void ReportMenu(int iClient)
{
	char sTitle[192],
		sOptions[12];
	Menu Mmenu = new Menu(MenuHandler_ReportMenu);
	Mmenu.SetTitle("%T:", "SelectPlayerTitle", iClient);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && i != iClient)
		{
			FormatEx(sTitle, sizeof(sTitle), "%N", i);
			IntToString(GetClientUserId(i), sOptions, sizeof(sOptions));
			Mmenu.AddItem(sOptions, sTitle);
		}
	}
	
	if(!Mmenu.ItemCount)
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "no target", iClient);
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	}
	Mmenu.ExitButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_ReportMenu(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Select:
		{
			char sInfo[12];
			Mmenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			
			g_iTargetReport[iClient] = StringToInt(sInfo);
			
			g_bReportReason[iClient] = true;
			ShowBanReasonMenu(iClient);
		}
	}
	
	return 0;
}
//---------------------------------------------------------------------------------------------------
// управление админами
#if SETTINGADMIN
void ShowSettingAdmin(int iClient)
{
	char sTitle[192];
	Menu Mmenu = new Menu(MenuHandler_SettingAdminMenu);
	Mmenu.SetTitle("%T:", "SettingAdminTitle", iClient);
	
	int iFlag = GetAdminWebFlag(iClient, 1);
	
	if (iFlag)
	{
		if (iFlag < 4)
		{
			FormatEx(sTitle, sizeof(sTitle), "%T", "add admin", iClient);
			if (g_dDatabase != null)
				Mmenu.AddItem("", sTitle);
			else
				Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
		}
		if (iFlag != 3)
		{
			FormatEx(sTitle, sizeof(sTitle), "%T", "del admin", iClient);
			if (g_dDatabase != null)
				Mmenu.AddItem("", sTitle);
			else
				Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
		}
	}
	else
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "No Access setting admin", iClient);
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	}
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_SettingAdminMenu(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack && g_tmAdminMenu)
				g_tmAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			switch(iSlot)
			{
				case 0: MenuAddAdmin(iClient);
				case 1: MenuDelAdmin(iClient);
			}
		}
	}
	
	return 0;
}

void MenuAddAdmin(int iClient)
{
	char sTitle[192],
		 sOption[12];
	int iUserId;
	Menu Mmenu = new Menu(MenuHandler_AddAdminMenu);
	Mmenu.SetTitle("%T:", "SetTitle", iClient);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && !CheckAdminFlags(i, ADMFLAG_GENERIC))
		{
			iUserId = GetClientUserId(i);
			IntToString(iUserId, sOption, sizeof(sOption));
			FormatEx(sTitle, sizeof(sTitle), "%N (%d)", i, iUserId);
			Mmenu.AddItem(sOption, sTitle);
		}
	}
	
	if(!Mmenu.ItemCount)
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "no target", iClient);
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	}
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_AddAdminMenu(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack)
				ShowSettingAdmin(iClient);
		}
		case MenuAction_Select:
		{
			char sInfo[12];
			Mmenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			
			int iTarget	= GetClientOfUserId(StringToInt(sInfo));
			if(iTarget && IsClientAuthorized(iTarget))
			{
				GetClientName(iTarget, g_sAddAdminInfo[iClient][ADDNAME], sizeof(g_sAddAdminInfo[][]));
				GetClientAuthId(iTarget, TYPE_STEAM, g_sAddAdminInfo[iClient][ADDSTEAM], sizeof(g_sAddAdminInfo[][]));
				BDCheckAdmins(iClient, 0);
			}
			else
				PrintToChat2(iClient, "%T", "Failed to player", iClient);
		}
	}
	
	return 0;
}

void MenuAddAdninFlag(int iClient)
{
	char sTitle[192],
		sOption[12];
	Menu Mmenu = new Menu(MenuHandler_AddAdninFlagMenu);
	Mmenu.SetTitle("%T:", "AddFlagAdminTitle", iClient);
	
	if (!g_bAdminAdd[iClient][ADDMENU])
	{
		FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_ROOT], "z flag", iClient);
		IntToString(MFLAG_ROOT, sOption, sizeof(sOption));
		Mmenu.AddItem(sOption, sTitle);

		FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_GENERIC], "b flag", iClient);
		IntToString(MFLAG_GENERIC, sOption, sizeof(sOption));
		Mmenu.AddItem(sOption, sTitle);
	}
	else
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "set flags", iClient);
		Mmenu.AddItem("-1", sTitle);
		if (!g_bAddAdminFlag[iClient][MFLAG_RESERVATION])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_RESERVATION], "a flag", iClient);
			IntToString(MFLAG_RESERVATION, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_KICK])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_KICK], "c flag", iClient);
			IntToString(MFLAG_KICK, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_BAN])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_BAN], "d flag", iClient);
			IntToString(MFLAG_BAN, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_UNBAN])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_UNBAN], "e flag", iClient);
			IntToString(MFLAG_UNBAN, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_SLAY])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_SLAY], "f flag", iClient);
			IntToString(MFLAG_SLAY, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CHANGEMAP])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CHANGEMAP], "g flag", iClient);
			IntToString(MFLAG_CHANGEMAP, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CONVARS])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CONVARS], "h flag", iClient);
			IntToString(MFLAG_CONVARS, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CONFIG])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CONFIG], "i flag", iClient);
			IntToString(MFLAG_CONFIG, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CHAT])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CHAT], "j flag", iClient);
			IntToString(MFLAG_CHAT, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_VOTE])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_VOTE], "k flag", iClient);
			IntToString(MFLAG_VOTE, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_PASSWORD])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_PASSWORD], "l flag", iClient);
			IntToString(MFLAG_PASSWORD, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_RCON])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_RCON], "m flag", iClient);
			IntToString(MFLAG_RCON, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CHEATS])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CHEATS], "n flag", iClient);
			IntToString(MFLAG_CHEATS, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CUSTOM1])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CUSTOM1], "o flag", iClient);
			IntToString(MFLAG_CUSTOM1, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CUSTOM2])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CUSTOM2], "p flag", iClient);
			IntToString(MFLAG_CUSTOM2, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CUSTOM3])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CUSTOM3], "q flag", iClient);
			IntToString(MFLAG_CUSTOM3, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CUSTOM4])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CUSTOM4], "r flag", iClient);
			IntToString(MFLAG_CUSTOM4, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CUSTOM5])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CUSTOM5], "s flag", iClient);
			IntToString(MFLAG_CUSTOM5, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
		if (!g_bAddAdminFlag[iClient][MFLAG_CUSTOM6])
		{
			FormatEx(sTitle, sizeof(sTitle), "%s - %T", g_sAddAdminFlag[MFLAG_CUSTOM6], "t flag", iClient);
			IntToString(MFLAG_CUSTOM6, sOption, sizeof(sOption));
			Mmenu.AddItem(sOption, sTitle);
		}
	}
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_AddAdninFlagMenu(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack)
				ShowSettingAdmin(iClient);
		}
		case MenuAction_Select:
		{
			char sInfo[12];
			Mmenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			
			int iNum = StringToInt(sInfo);
			if (iNum <= 0)
			{
				if (!iNum)
					g_bAddAdminFlag[iClient][iNum] = true;
				
				g_bAdminAdd[iClient][ADDIMUN] = true;
				PrintToChat2(iClient, "%T", "say imune", iClient);
			}
			else
			{
				g_bAdminAdd[iClient][ADDMENU] = true;
				g_bAddAdminFlag[iClient][iNum] = true;
				MenuAddAdninFlag(iClient);
			}
		}
	}
	
	return 0;
}

void MenuDelAdmin(int iClient)
{
	char sTitle[192],
		 sOption[12];
	int iUserId;
	Menu Mmenu = new Menu(MenuHandler_DelAdminMenu);
	Mmenu.SetTitle("%T:", "SetTitle", iClient);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && CheckAdminFlags(i, ADMFLAG_GENERIC))
		{
			iUserId = GetClientUserId(i);
			IntToString(iUserId, sOption, sizeof(sOption));
			FormatEx(sTitle, sizeof(sTitle), "%N (%d)", i, iUserId);
			Mmenu.AddItem(sOption, sTitle);
		}
	}
	
	if(!Mmenu.ItemCount)
	{
		FormatEx(sTitle, sizeof(sTitle), "%T", "no target", iClient);
		Mmenu.AddItem("", sTitle, ITEMDRAW_DISABLED);
	}
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_DelAdminMenu(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack)
				ShowSettingAdmin(iClient);
		}
		case MenuAction_Select:
		{
			char sInfo[12];
			Mmenu.GetItem(iSlot, sInfo, sizeof(sInfo));
			
			int iTarget	= GetClientOfUserId(StringToInt(sInfo));
			if(iTarget && IsClientAuthorized(iTarget))
			{
				GetClientName(iTarget, g_sAddAdminInfo[iClient][ADDNAME], sizeof(g_sAddAdminInfo[][]));
				GetClientAuthId(iTarget, TYPE_STEAM, g_sAddAdminInfo[iClient][ADDSTEAM], sizeof(g_sAddAdminInfo[][]));
				MenuDelAdminTyp(iClient);
			}
			else
				PrintToChat2(iClient, "%T", "Failed to player", iClient);
		}
	}
	
	return 0;
}
	
void MenuDelAdminTyp(int iClient)
{
	char sTitle[192];
	Menu Mmenu = new Menu(MenuHandler_DelAdminTypMenu);
	Mmenu.SetTitle("%T:", "DelAdminTitle", iClient);
	
	FormatEx(sTitle, sizeof(sTitle), "%T", "del all", iClient); // all
	Mmenu.AddItem("", sTitle);

	FormatEx(sTitle, sizeof(sTitle), "%T", "del server", iClient); // server
	Mmenu.AddItem("", sTitle);
	
	Mmenu.ExitBackButton = true;
	Mmenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_DelAdminTypMenu(Menu Mmenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel:
		{
			if (iSlot == MenuCancel_ExitBack)
				ShowSettingAdmin(iClient);
		}
		case MenuAction_Select:
		{
			if (!iSlot)
				BDCheckAdmins(iClient, 2);
			else
				BDCheckAdmins(iClient, 1);
		}
	}
	
	return 0;
}
#endif