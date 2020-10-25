enum GroupState
{
	GroupState_None,
	GroupState_Groups,
	GroupState_InGroup,
	GroupState_Overrides,
}

enum GroupPass
{
	GroupPass_Invalid,
	GroupPass_First,
	GroupPass_Second,
}

static GroupId g_idGroup = INVALID_GROUP_ID;
static GroupState g_iGroupState = GroupState_None;
static GroupPass g_iGroupPass = GroupPass_Invalid;


static char g_sCurAuth[64],
	g_sCurIdent[64],
	g_sCurName[64],
	g_sCurPass[64];
static int g_iCurFlags,
	g_iCurImmunity,
	g_iCurExpire,
	g_iWebFlagSetingsAdmin,
	g_iWebFlagUnBanMute;

public void OnRebuildAdminCache(AdminCachePart acPart)
{
	switch(acPart)
	{
		case AdminCache_Overrides: 	ReadOverrides();
		case AdminCache_Groups: 	ReadGroups();
		case AdminCache_Admins: 	ReadUsers();
	}
}
//-----------------------------------------------------------------------------------------------------
public SMCResult ReadGroups_NewSection(SMCParser smc, const char[] sName, bool opt_quotes)
{
	if (g_iGroupState == GroupState_None)
	{
		if (StrEqual(sName, "groups", false))
			g_iGroupState = GroupState_Groups;
	} 
	else if (g_iGroupState == GroupState_Groups)
	{
	#if MADEBUG
		if ((g_idGroup = CreateAdmGroup(sName)) == INVALID_GROUP_ID)
		{
			if ((g_idGroup = FindAdmGroup(sName)) == INVALID_GROUP_ID)
				LogToFile(g_sLogAdmin, "Find & Create no group (%s)", sName);
			else
				LogToFile(g_sLogAdmin, "Find yes group (grup %d, %s)", g_idGroup, sName);
		}
		else
			LogToFile(g_sLogAdmin, "Create yes group (grup %d, %s)", g_idGroup, sName);
	#else
		if ((g_idGroup = CreateAdmGroup(sName)) == INVALID_GROUP_ID)
			g_idGroup = FindAdmGroup(sName);
	#endif
		g_iGroupState = GroupState_InGroup;
	} 
	else if (g_iGroupState == GroupState_InGroup)
	{
		if (StrEqual(sName, "overrides", false))
			g_iGroupState = GroupState_Overrides;
	} 
	
	return SMCParse_Continue;
}

public SMCResult ReadGroups_KeyValue(SMCParser smc, const char[] sKey, const char[] sValue, bool key_quotes, bool value_quotes)
{
	if (g_idGroup == INVALID_GROUP_ID)
		return SMCParse_Continue;

	AdminFlag admFlag;
	char sGroupID[12];
	FormatEx(sGroupID, sizeof(sGroupID), "%d", g_idGroup);
	int iValue = StringToInt(sValue);
	
	if (g_iGroupPass == GroupPass_First)
	{
		if (g_iGroupState == GroupState_InGroup)
		{
			if (StrEqual(sKey, "flags", false)) 
			{
				for (int i = 0; i < strlen(sValue); i++)
				{
					if (!FindFlagByChar(sValue[i], admFlag))
						continue;

 					g_idGroup.SetFlag(admFlag, true);
				}
			#if MADEBUG
				LogToFile(g_sLogAdmin, "Load group flag override (grup %d, %s %s)", g_idGroup, sKey, sValue);
			#endif
			}
			else if (StrEqual(sKey, "maxbantime", false))  
				g_tGroupBanTimeMax.SetValue(sGroupID, iValue, false);
			else if (StrEqual(sKey, "maxmutetime", false))  
				g_tGroupMuteTimeMax.SetValue(sGroupID, iValue, false);
			else if (StrEqual(sKey, "immunity", false))  
				PrintToServer("¯\\_(ツ)_/¯"); // TODO: try understand, for what reasons in SB implemented two passes for reading groups.
		} 
		else if (g_iGroupState == GroupState_Overrides)
		{
			OverrideRule overRule = Command_Deny;
			
			if (StrEqual(sValue, "allow", false))  
				overRule = Command_Allow;
			
			if (sKey[0] == '@')
 				g_idGroup.AddCommandOverride(sKey[1], Override_CommandGroup, overRule);
 			else
 				g_idGroup.AddCommandOverride(sKey, Override_Command, overRule);
			
		#if MADEBUG
			LogToFile(g_sLogAdmin, "Load group command override (group %d, %s, %s)", g_idGroup, sKey, sValue);
		#endif
		}
	}
	else if (g_iGroupPass == GroupPass_Second && g_iGroupState == GroupState_InGroup)
	{
		/* Check for immunity again, core should handle double inserts */
		if (StrEqual(sKey, "immunity", false))  
		{
			/* If it's a sValue we know about, use it */
			if (StrEqual(sValue, "*"))
 				g_idGroup.ImmunityLevel = 2;
			else if (StrEqual(sValue, "$"))
 				g_idGroup.ImmunityLevel = 1;
			else
			{
				int iLevel;
				if (StringToIntEx(sValue, iLevel))
 					g_idGroup.ImmunityLevel = iLevel;
				else
				{
					GroupId idGroup;
					if (sValue[0] == '@')
						idGroup = FindAdmGroup(sValue[1]);
					else
						idGroup = FindAdmGroup(sValue);
					
					if (idGroup != INVALID_GROUP_ID)
 						g_idGroup.AddGroupImmunity(idGroup);
					else
						LogToFile(g_sLogAdmin, "Unable to find group: \"%s\"", sValue);
				}
			}
		#if MADEBUG
			LogToFile(g_sLogAdmin, "Load group add immunity level (%d, %s, %s)", g_idGroup, sKey, sValue);
		#endif
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadGroups_EndSection(SMCParser smc)
{
	if (g_iGroupState == GroupState_Overrides)
		g_iGroupState = GroupState_InGroup;
	else if (g_iGroupState == GroupState_InGroup)
	{
		g_iGroupState = GroupState_Groups;
		g_idGroup = INVALID_GROUP_ID;
	} 
	else if (g_iGroupState == GroupState_Groups)
		g_iGroupState = GroupState_None;
	
	return SMCParse_Continue;
}

static bool Internal__ReadGroups(File hFile)
{
	while (!hFile.EndOfFile())
	{
		if (!Internal__ReadGroup(hFile))
		{
			return false;
		}
	}

	return true;
}

static bool Internal__ReadGroup(File hFile)
{
	// - Group Name
	// - Immunity
	// - Admin Flags
	// - Ban time limit (v2)
	// - Mute time limit (v2)
	// - Overrides count
	// - OVERRIDE_ENTRY (see Internal__ReadGroupOverride for more details)

	// 1. Group name.
	char szName[256];
	if (!UTIL_ReadFileString(hFile, szName, sizeof(szName)))
	{
		return false;
	}

	// 1.5. Create entry.
	GroupId iGID = FindOrCreateAdminGroup(szName);
#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Group '%s' (%x) => created/finded in admin cache", szName, iGID);
#endif

	// 2. Immunity.
	int iImmunity;
	if (!hFile.ReadInt32(iImmunity))
	{
		return false;
	}

	SetAdmGroupImmunityLevel(iGID, iImmunity);
#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Group %x => immunity %d", iGID, iImmunity);
#endif

	// 3. Admin Flags.
	int iAdminFlags;
	if (!hFile.ReadInt32(iAdminFlags))
	{
		return false;
	}

	SetupAdminGroupFlagsFromBits(iGID, iAdminFlags);
#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Group %x => setup admin flags %b", iGID, iAdminFlags);
#endif

	// 4. Limitations.
	Internal__ReadGroupLimitations(hFile, iGID);

	// 5. Overrides count.
	int iOverrides;
	if (!hFile.ReadUint16(iOverrides))
	{
		return false;
	}
#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Group %x => has %d overrides", iGID, iOverrides);
#endif

	for (int iOverrideId = 0; iOverrideId < iOverrides; ++iOverrideId)
	{
		if (!Internal__ReadGroupOverride(hFile, iGID))
		{
			return false;
		}
	}

	return true;
}

static void Internal__ReadGroupLimitations(File hFile, GroupId iGID)
{
	int iBanTime, iMuteTime;
	hFile.ReadInt32(iBanTime);
	hFile.ReadInt32(iMuteTime);

	char szGroupID[16];
	FormatEx(szGroupID, sizeof(szGroupID), "%d", iGID);

	g_tGroupBanTimeMax.SetValue(szGroupID, iBanTime, false);
	g_tGroupMuteTimeMax.SetValue(szGroupID, iMuteTime, false);
}

static bool Internal__ReadGroupOverride(File hFile, GroupId iGID)
{
	// - Override text length
	// - Override text
	// - Override type
	// - Override rule

	// 1. Override text length + override text.
	char szOverrideText[256];
	if (!UTIL_ReadFileString(hFile, szOverrideText, sizeof(szOverrideText)))
	{
		return false;
	}
#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Group %x => read override text '%s'", iGID, szOverrideText);
#endif

	// 2. Override type + override rule.
	OverrideType eType;
	OverrideRule eRule;
	if (!hFile.ReadUint8(view_as<int>(eType)) || !hFile.ReadUint8(view_as<int>(eRule)))
	{
		return false;
	}
#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Group %x => type %d, rule %d", iGID, eType, eRule);
#endif

	AddAdmGroupCmdOverride(iGID, szOverrideText, eType, eRule);

	return true;
}

void ReadGroups()
{
	File hGroups = OpenFile(g_sGroupsLoc, "rb");
	if (hGroups)
	{
		int iHeader;
		if (hGroups.ReadInt32(iHeader) && iHeader == BINARY__MA_GROUPS_HEADER)
		{
			Internal__ReadGroups(hGroups);
		}

		hGroups.Close();
	}

	FireOnFindLoadingAdmin(AdminCache_Groups);
}
//----------------------------------------------------------------------------------------------------
public SMCResult ReadUsers_NewSection(SMCParser smc, const char[] sName, bool opt_quotes)
{
	//if (!StrEqual(sName, "admins", false))

	strcopy(g_sCurName, sizeof(g_sCurName), sName);
	g_sCurAuth[0] = '\0';
	g_sCurIdent[0] = '\0';
	g_sCurPass[0] = '\0';
	g_aGroupArray.Clear();
	g_iCurFlags = 0;
	g_iCurImmunity = 0;
	g_iCurExpire = 0;
	g_iWebFlagSetingsAdmin = 0;
	g_iWebFlagUnBanMute = 0;
	
	return SMCParse_Continue;
}

public SMCResult ReadUsers_KeyValue(SMCParser smc, const char[] sKey, const char[] sValue, bool key_quotes, bool value_quotes)
{
	if (StrEqual(sKey, "auth", false))  
		strcopy(g_sCurAuth, sizeof(g_sCurAuth), sValue);
	else if (StrEqual(sKey, "identity", false))  
		strcopy(g_sCurIdent, sizeof(g_sCurIdent), sValue);
	else if (StrEqual(sKey, "password", false))  
		strcopy(g_sCurPass, sizeof(g_sCurPass), sValue);
	else if (StrEqual(sKey, "group", false))  
	{
		GroupId idGroup = FindAdmGroup(sValue);
		if (idGroup == INVALID_GROUP_ID)
			LogToFile(g_sLogAdmin, "Unknown group \"%s\"", sValue);
		else
		{
		#if MADEBUG
			LogToFile(g_sLogAdmin, "Admin %s group %s %d", g_sCurName, sValue, idGroup);
		#endif
			g_aGroupArray.Push(idGroup);
		}
	} 
	else if (StrEqual(sKey, "flags", false))  
	{
		AdminFlag admFlag;
		
		for (int i = 0; i < strlen(sValue); i++)
		{
			if (!FindFlagByChar(sValue[i], admFlag))
				LogToFile(g_sLogAdmin, "Invalid admFlag detected: %c", sValue[i]);
			else
				g_iCurFlags |= FlagToBit(admFlag);
		}
	} 
	else if (StrEqual(sKey, "immunity", false))  
	{
		if(sValue[0])
			g_iCurImmunity = StringToInt(sValue);
		else
			g_iCurImmunity = 0;
	}
	else if (StrEqual(sKey, "expire", false))  
	{
		if(sValue[0])
			g_iCurExpire = StringToInt(sValue);
		else
			g_iCurExpire = 0;
	}
	else if (StrEqual(sKey, "setingsadmin", false))  
	{
		if(sValue[0])
			g_iWebFlagSetingsAdmin = StringToInt(sValue);
		else
			g_iWebFlagSetingsAdmin = 0;
	}
	else if (StrEqual(sKey, "unbanmute", false))  
	{
		if(sValue[0])
			g_iWebFlagUnBanMute = StringToInt(sValue);
		else
			g_iWebFlagUnBanMute = 0;
	}
	
	return SMCParse_Continue;
}

public SMCResult ReadUsers_EndSection(SMCParser smc)
{
	if (g_sCurIdent[0] && g_sCurAuth[0])
	{
		if (!g_iCurExpire || g_iCurExpire > GetTime())
		{
		
			AdminFlag admFlags[26];
			AdminId idAdmin;
			
			if ((idAdmin = FindAdminByIdentity(g_sCurAuth, g_sCurIdent)) != INVALID_ADMIN_ID)
			{
			#if MADEBUG
				LogToFile(g_sLogAdmin, "Find admin %s yes (%d, auth %s, %s)", g_sCurName, idAdmin, g_sCurAuth, g_sCurIdent);
			#endif
			}
			else
			{
				idAdmin = CreateAdmin(g_sCurName);
			#if MADEBUG
				LogToFile(g_sLogAdmin, "Create new admin %s (%d, auth %s, %s)", g_sCurName, idAdmin, g_sCurAuth, g_sCurIdent);
			#endif
 				if (!idAdmin.BindIdentity(g_sCurAuth, g_sCurIdent))
				{
					RemoveAdmin(idAdmin);
					LogToFile(g_sLogAdmin, "Failed to bind auth \"%s\" to identity \"%s\"", g_sCurAuth, g_sCurIdent);
					return SMCParse_Continue;
				}
			}
			
		#if MADEBUG
			LogToFile(g_sLogAdmin, "Add admin %s expire %d", g_sCurName, g_iCurExpire);
		#endif
			AddAdminExpire(idAdmin, g_iCurExpire);
			
			
			GroupId idGroup;
			int iMaxBanTime,
				iMaxMuteTime,
				iBanTime,
				iMuteTime;
			char sGroupID[12],
				sAdminID[12];
			FormatEx(sAdminID, sizeof(sAdminID), "%d", idAdmin);
			int iGroupSize = g_aGroupArray.Length;
			if (!iGroupSize)
			{
				iMaxBanTime = -1;
				iMaxMuteTime = -1;
			}
			else
			{
				for (int i = 0; i < iGroupSize; i++)
				{
					idGroup = g_aGroupArray.Get(i);
					
					FormatEx(sGroupID, sizeof(sGroupID), "%d", idGroup);
					if (g_tGroupBanTimeMax.GetValue(sGroupID, iBanTime))
					{
						if (!iMaxBanTime)
							iMaxBanTime = iBanTime;
						else if (iBanTime < iMaxBanTime)
							iMaxBanTime = iBanTime;
					}
					else
						iMaxBanTime = -1;

					if (g_tGroupMuteTimeMax.GetValue(sGroupID, iMuteTime))
					{
						if (!iMaxMuteTime)
							iMaxMuteTime = iMuteTime;
						else if (iMuteTime < iMaxMuteTime)
							iMaxMuteTime = iMuteTime;
					}
					else
						iMaxMuteTime = -1;
						
				#if MADEBUG
					if (idAdmin.InheritGroup(idGroup))
						LogToFile(g_sLogAdmin, "Admin %s add group %d", g_sCurName, idGroup);
					else
						LogToFile(g_sLogAdmin, "Admin %s no add group %d", g_sCurName, idGroup);
				#else
					idAdmin.InheritGroup(idGroup);
				#endif
				}
			}
			g_tAdminBanTimeMax.SetValue(sAdminID, iMaxBanTime, false);
			g_tAdminMuteTimeMax.SetValue(sAdminID, iMaxMuteTime, false);

			g_tWebFlagSetingsAdmin.SetValue(sAdminID, g_iWebFlagSetingsAdmin, false);
			g_tWebFlagUnBanMute.SetValue(sAdminID, g_iWebFlagUnBanMute, false);

			if(g_sCurPass[0])
 				idAdmin.SetPassword(g_sCurPass);

			if (idAdmin.ImmunityLevel < g_iCurImmunity)
				idAdmin.ImmunityLevel = g_iCurImmunity;
			
			int iFlags = FlagBitsToArray(g_iCurFlags, admFlags, sizeof(admFlags));
			for (int i = 0; i < iFlags; i++)
 				idAdmin.SetFlag(admFlags[i], true);
			
		#if MADEBUG
			LogToFile(g_sLogAdmin, "Load yes admin (name %s, auth %s, ident %s, flag %d, imuni %d, expire %d, max ban time %d, max mute time %d, web flag setings %d, web flag un ban mute %d)", 
						g_sCurName, g_sCurAuth, g_sCurIdent, g_iCurFlags, g_iCurImmunity, g_iCurExpire, iMaxBanTime, iMaxMuteTime, g_iWebFlagSetingsAdmin, g_iWebFlagUnBanMute);
		#endif
		}
		else
		{
		#if MADEBUG
			LogToFile(g_sLogAdmin, "Load no admin (name %s, auth %s, ident %s, flag %d, imuni %d, expire %d, web flag setings %d, web flag un ban mute %d)", 
						g_sCurName, g_sCurAuth, g_sCurIdent, g_iCurFlags, g_iCurImmunity, g_iCurExpire, g_iWebFlagSetingsAdmin, g_iWebFlagUnBanMute);
		#endif
			LogToFile(g_sLogAdmin, "Failed to create admin %s", g_sCurName);
		}
	}
	
	return SMCParse_Continue;
}

static bool Internal__ReadAdmins(File hFile)
{
	while (!hFile.EndOfFile())
	{
		if (!Internal__ReadAdmin(hFile))
		{
			return false;
		}
	}

	return true;
}

static bool Internal__ReadAdmin(File hFile)
{
	// 1. Nickname.
	// 2. Authentication method (should be "steam").
	// 3. Authentication identifier (SteamID).
	// 4. Adminflags.
	// 5. Immunity.
	// 6. Group.
	// 7. Password.
	// 8. Web permissions.
	// 9. Expiration date.

	// 1. Nickname.
	char szData[256],
		szName[64];
	if (!UTIL_ReadFileString(hFile, szName, sizeof(szName)))
	{
		return false;
	}

	// 2. Continue read file (authentication method and identifier).
	char szAuthenticationProvider[16],
		szAuthenticationIdentifier[32];
	if (!UTIL_ReadFileString(hFile, szAuthenticationProvider, sizeof(szAuthenticationProvider)))
	{
		return false;
	}

	if (!UTIL_ReadFileString(hFile, szAuthenticationIdentifier, sizeof(szAuthenticationIdentifier)))
	{
		return false;
	}

	// 3. Try find administrator identifier by provider + identifier, or create new.
	AdminId iAID = FindAdminByIdentity(szAuthenticationProvider, szAuthenticationIdentifier);
	if (iAID == INVALID_ADMIN_ID)
	{
		iAID = CreateAdmin(szName);
		if (iAID == INVALID_ADMIN_ID)
		{
			return false;
		}

		if (!BindAdminIdentity(iAID, szAuthenticationProvider, szAuthenticationIdentifier))
		{
			return false;
		}
	}

#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Admin '%s' (%x) => created/finded in admin cache", szData, iAID);
#endif

	// 4. Setup administrator flags and immunity.
	int iFlags;
	if (!hFile.ReadInt32(iFlags))
	{
		return false;
	}

	int iImmunity;
	if (!hFile.ReadInt32(iImmunity))
	{
		return false;
	}

	SetupAdminFlagsFromBits(iAID, iFlags);
	SetAdminImmunityLevel(iAID, iImmunity);

#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Admin '%s' (%x) => setup immunity (%d) and flags (%b)", szName, iAID, iImmunity, iFlags);
#endif

	// 5. Setup administrator group (if required).
	if (!UTIL_ReadFileString(hFile, szData, sizeof(szData)))
	{
		return false;
	}

#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Admin '%s' (%x) => read group '%s'", szName, iAID, szData);
#endif

	int iBanTime = -1;
	int iMuteTime = -1;
	if (szData[0])
	{
		GroupId iGID = FindAdmGroup(szData);

		if (iGID == INVALID_GROUP_ID)
		{
			LogToFile(g_sLogAdmin, "Can't setup admin group for '%s' - group '%s' not found", szName, szData);
		}
		else
		{
			AdminInheritGroup(iAID, iGID);
			Internal__ReadAdminGroupLimitationsById(iGID, iBanTime, iMuteTime);
		}
	}
	Internal__SetupAdminLimitations(iAID, iBanTime, iMuteTime);

	// 6. Setup administrator password (if required).
	if (!UTIL_ReadFileString(hFile, szData, sizeof(szData)))
	{
		return false;
	}

#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Admin '%s' (%x) => read password '%s'", szName, iAID, szData);
#endif

	if (szData[0])
	{
		SetAdminPassword(iAID, szData);
	}

	// 7. Set up web permissions in cache (TODO).
	int iWebPermissions;
	if (!hFile.ReadInt32(iWebPermissions))
	{
		return false;
	}
	Internal__ReadAdmin_SetupWebPermissions(iAID, iWebPermissions);

	// 8. Read expiration date.
	int iExpiresAfter;
	if (!hFile.ReadInt32(iWebPermissions))
	{
		return false;
	}

	// If expiration date is reached - then delete admin entry.
	if (iExpiresAfter != 0 && iExpiresAfter < GetTime())
	{
		RemoveAdmin(iAID);
	}

	AddAdminExpire(iAID, iExpiresAfter);
	return true;
}

static void Internal__SetupAdminLimitations(AdminId iAID, int iBanTime, int iMuteTime)
{
	char szAdminID[16];
	FormatEx(szAdminID, sizeof(szAdminID), "%d", iAID);

	g_tAdminBanTimeMax.SetValue(szAdminID, iBanTime, false);
	g_tAdminMuteTimeMax.SetValue(szAdminID, iMuteTime, false);
}

static void Internal__ReadAdminGroupLimitationsById(GroupId iGID, int &iBanTime, int &iMuteTime)
{
	char szGroupID[16];
	FormatEx(szGroupID, sizeof(szGroupID), "%d", iGID);

	g_tGroupBanTimeMax.GetValue(szGroupID, iBanTime);
	g_tGroupMuteTimeMax.GetValue(szGroupID, iMuteTime);
}

static void Internal__ReadAdmin_SetupWebPermissions(AdminId iAID, int iWebPermissions)
{
	char szAdminId[16];
	FormatEx(szAdminId, sizeof(szAdminId), "%s", iAID);

	int iCanManageAdmins = 0;
	int iCanUnmuteUnban = 0;
	if (iWebPermissions & (1<<24))
	{
		iCanUnmuteUnban = 5;
		iCanManageAdmins = 2;
	}
	else
	{
		if (iWebPermissions & (1 << 26))
			iCanUnmuteUnban = 5; // all
		else if (iWebPermissions & (1 << 30))
			iCanUnmuteUnban = 6; // only own

		if ((iWebPermissions & (1<<1)) && (iWebPermissions & (1<<3)))
			iCanManageAdmins = 2; // add + delete
		else if (iWebPermissions & (1<<1))
			iCanManageAdmins = 3; // only add
		else if (iWebPermissions & (1<<3))
			iCanManageAdmins = 4; // only delete
	}

	g_tWebFlagSetingsAdmin.SetValue(szAdminId, iCanManageAdmins, false);
	g_tWebFlagUnBanMute.SetValue(szAdminId, iCanUnmuteUnban, false);
}

void ReadUsers()
{
	File hAdmins = OpenFile(g_sAdminsLoc, "rb");
	if (hAdmins)
	{
		int iHeader;
		if (hAdmins.ReadInt32(iHeader) && iHeader == BINARY__MA_ADMINS_HEADER)
		{
			Internal__ReadAdmins(hAdmins);
		}

		hAdmins.Close();
	}

	FireOnFindLoadingAdmin(AdminCache_Admins);
}
//-------------------------------------------------------------------------------------------

static bool Internal__ReadOverrides(File hFile)
{
	while (!hFile.EndOfFile())
	{
		if (!Internal__ReadOverride(hFile))
		{
			return false;
		}
	}

	return true;
}

static bool Internal__ReadOverride(File hFile)
{
	// - Value length
	// - Value
	// - Override type
	// - Required flags
	// 1, 2. Value length + value.
	char szValue[256];
	if (!UTIL_ReadFileString(hFile, szValue, sizeof(szValue)))
	{
		return false;
	}

	// 3. Override type.
	OverrideType eType;
	if (!hFile.ReadUint8(view_as<int>(eType)))
	{
		return false;
	}

	// 4. Admin Flags.
	int iAdminFlags;
	if (!hFile.ReadInt32(iAdminFlags))
	{
		return false;
	}

	AddCommandOverride(szValue, eType, iAdminFlags);
#if defined MADEBUG
	LogToFile(g_sLogAdmin, "Readed override '%s' (type %d) with flags %b", szValue, eType, iAdminFlags);
#endif

	return true;
}

void ReadOverrides()
{
	File hOverrides = OpenFile(g_sOverridesLoc, "rb");
	if (hOverrides)
	{
		int iHeader;
		if (hOverrides.ReadInt32(iHeader) && iHeader == BINARY__MA_OVERRIDES_HEADER)
		{
			Internal__ReadOverrides(hOverrides);
		}

		hOverrides.Close();
	}

	FireOnFindLoadingAdmin(AdminCache_Overrides);
}