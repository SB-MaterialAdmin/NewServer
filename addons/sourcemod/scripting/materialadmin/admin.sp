public void OnRebuildAdminCache(AdminCachePart acPart)
{
	if (g_bReshashAdmin)
	{
		return;
	}

	switch(acPart)
	{
		case AdminCache_Overrides: 	ReadOverrides();
		case AdminCache_Groups: 	ReadGroups();
		case AdminCache_Admins: 	ReadUsers();
	}
}
//-----------------------------------------------------------------------------------------------------
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
#if MADEBUG
	LogToFile(g_sLogAdmin, "Group '%s' (%x) => created/finded in admin cache", szName, iGID);
#endif

	// 2. Immunity.
	int iImmunity;
	if (!hFile.ReadInt32(iImmunity))
	{
		return false;
	}

	SetAdmGroupImmunityLevel(iGID, iImmunity);
#if MADEBUG
	LogToFile(g_sLogAdmin, "Group %x => immunity %d", iGID, iImmunity);
#endif

	// 3. Admin Flags.
	int iAdminFlags;
	if (!hFile.ReadInt32(iAdminFlags))
	{
		return false;
	}

	SetupAdminGroupFlagsFromBits(iGID, iAdminFlags);
#if MADEBUG
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
#if MADEBUG
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
#if MADEBUG
	LogToFile(g_sLogAdmin, "Group %x => read override text '%s'", iGID, szOverrideText);
#endif

	// 2. Override type + override rule.
	OverrideType eType;
	OverrideRule eRule;
	if (!hFile.ReadUint8(view_as<int>(eType)) || !hFile.ReadUint8(view_as<int>(eRule)))
	{
		return false;
	}
#if MADEBUG
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

#if MADEBUG
	LogToFile(g_sLogAdmin, "Admin '%s' (%x) => created/finded in admin cache", szName, iAID);
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

#if MADEBUG
	LogToFile(g_sLogAdmin, "Admin '%s' (%x) => setup immunity (%d) and flags (%b)", szName, iAID, iImmunity, iFlags);
#endif

	// 5. Setup administrator group (if required).
	if (!UTIL_ReadFileString(hFile, szData, sizeof(szData)))
	{
		return false;
	}

#if MADEBUG
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

#if MADEBUG
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
	if (!hFile.ReadInt32(iExpiresAfter))
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
	FormatEx(szAdminId, sizeof(szAdminId), "%d", iAID);

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

#if MADEBUG
	LogToFile(g_sLogAdmin, "Admin %x => read web flags (%d / %d)", iAID, iCanUnmuteUnban, iCanManageAdmins);
#endif

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
			g_tAdminBanTimeMax.Clear();
			g_tAdminMuteTimeMax.Clear();
			g_tWebFlagSetingsAdmin.Clear();
			g_tWebFlagUnBanMute.Clear();
			g_tAdminsExpired.Clear();

			Internal__ReadAdmins(hAdmins);
		}

		hAdmins.Close();
	}

	// Clean internal cache.
	g_tGroupBanTimeMax.Clear();
	g_tGroupMuteTimeMax.Clear();

	// Fire permissions checks.
	if (g_bReshashAdmin)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsClientAuthorized(i) && !IsFakeClient(i))
			{
#if MADEBUG
				LogToFile(g_sLogAdmin, "ReadUsers(): triggering OnClientPostAdminCheck() for %L...", i);
#endif

				RunAdminCacheChecks(i);
				NotifyPostAdminCheck(i);
			}
		}
		g_bReshashAdmin = false;
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
#if MADEBUG
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