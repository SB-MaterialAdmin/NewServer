SMCParser
	g_smcConfigParser,
	g_smcTimeReasonParser;

enum ConfigState
{
	ConfigState_Non,
	ConfigState_Time,
	ConfigState_Reason_Ban,
	ConfigState_Reason_Hacking,
	ConfigState_Reason_Mute
};

ConfigState g_iConfigState = ConfigState_Non;

//получение значений конфига
void ReadConfig()
{
	g_bServerIDVerified = false;

	if (g_smcTimeReasonParser == null) {
		g_smcTimeReasonParser = new SMCParser();
	}

	g_smcTimeReasonParser.OnEnterSection = NewSectionReason;
	g_smcTimeReasonParser.OnKeyValue = KeyValueReason;
	g_smcTimeReasonParser.OnLeaveSection = EndSection;

	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/materialadmin/time_reason.cfg");

	if (g_mReasonMMenu) {
		g_mReasonMMenu.RemoveAllItems();
	}

	if (g_mReasonBMenu) {
		g_mReasonBMenu.RemoveAllItems();
	}

	if (g_mHackingMenu) {
		g_mHackingMenu.RemoveAllItems();
	}

	g_tMenuTime.Clear();
	g_aTimeMenuSorting.Clear();

	if (!FileExists(sConfigFile)) {
		LogToFile(g_sLogConfig, "Can not find %s", sConfigFile);
		SetFailState("%sCan not find %s", MAPREFIX, sConfigFile);
	}

	g_iConfigState = ConfigState_Non;

	int iLine;
	SMCError err = g_smcTimeReasonParser.ParseFile(sConfigFile, iLine);
	if (err != SMCError_Okay) {
		char sError[256];
		g_smcTimeReasonParser.GetErrorString(err, sError, sizeof(sError));

		LogToFile(g_sLogConfig, "Could not parse file (line %d, file \"%s\"):", iLine, sConfigFile);
		LogToFile(g_sLogConfig, "Parser encountered error: %s", sError);
	}

	if (!g_mReasonMMenu.ItemCount) {
		SetFailState("%sFor file \"%s\" no reason \"MuteReasons\"", MAPREFIX, sConfigFile);
	}

	if (!g_mReasonBMenu.ItemCount) {
		SetFailState("%sFor file \"%s\" no reason \"BanReasons\"", MAPREFIX, sConfigFile);
	}

	if (!g_mHackingMenu.ItemCount) {
		SetFailState("%sFor file \"%s\" no reason \"HackingReasons\"", MAPREFIX, sConfigFile);
	}

	if (!g_tMenuTime.Size) {
		SetFailState("%sFor file \"%s\" no time \"Time\"", MAPREFIX, sConfigFile);
	}

	if (g_smcConfigParser == null) {
		g_smcConfigParser = new SMCParser();
	}

	g_smcConfigParser.OnEnterSection = NewSectionConfig;
	g_smcConfigParser.OnKeyValue = KeyValueConfig;
	g_smcConfigParser.OnLeaveSection = EndSection;

	g_hSettings.Clear();
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/materialadmin/config.cfg");

	if (!FileExists(sConfigFile)) {
		LogToFile(g_sLogConfig, "Can not find %s", sConfigFile);
		SetFailState("%sCan not find %s", MAPREFIX, sConfigFile);
	}

	err = g_smcConfigParser.ParseFile(sConfigFile, iLine);
	if (err != SMCError_Okay) {
		char sError[256];
		g_smcConfigParser.GetErrorString(err, sError, sizeof(sError));

		LogToFile(g_sLogConfig, "Could not parse file (line %d, file \"%s\"):", iLine, sConfigFile);
		LogToFile(g_sLogConfig, "Parser encountered error: %s", sError);
	} else {
		VerifyServerID();
	}
}

public SMCResult NewSectionConfig(SMCParser Smc, const char[] sName, bool bOpt_quotes)
{
	return SMCParse_Continue;
}

public SMCResult KeyValueConfig(SMCParser Smc, const char[] sKey, const char[] sValue, bool bKey_quotes, bool bValue_quotes)
{
	if (!sKey[0] || !sValue[0]) {
		return SMCParse_Continue;
	}

	g_hSettings.SetString(sKey, sValue, true);

	if (!strcmp("DatabasePrefix", sKey, false)) {
		strcopy(g_sDatabasePrefix, sizeof(g_sDatabasePrefix), sValue);
	} else if (!strcmp("Website", sKey, false)) {
		strcopy(g_sWebsite, sizeof(g_sWebsite), sValue);
	} else if (!strcmp("OffTimeFormat", sKey, false))  {
		strcopy(g_sOffFormatTime, sizeof(g_sOffFormatTime), sValue);
	} else if (!strcmp("BanFlagPermanent", sKey, false)) {
		strcopy(g_sBanFlagPermanent, sizeof(g_sBanFlagPermanent), sValue);
	} else if (!strcmp("OffMenuNast", sKey, false)) {
		strcopy(g_sOffMenuItems, sizeof(g_sOffMenuItems), sValue);
	} else if (!strcmp("Addban", sKey, false)) {
		g_bAddBan = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("Unban", sKey, false)) {
		g_bUnBan = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("OffMapClear", sKey, false)) {
		g_bOffMapClear = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("Report", sKey, false)) {
		g_bReport = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("BanSayPanel", sKey, false)) {
		g_bBanSayPanel = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("ActionOnTheMy", sKey, false)) {
		g_bActionOnTheMy = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("ServerBanTyp", sKey, false)) {
		g_bServerBanTyp = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("SourceSleuth", sKey, false)) {
		g_bSourceSleuth = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("UnMuteUnBan", sKey, false)) {
		g_bUnMuteUnBan = (!StringToInt(sValue)) ? false : true;
	} else if (!strcmp("MassBan", sKey, false)) {
		g_iMassBan = StringToInt(sValue);
	} else if (!strcmp("ServerBanTime", sKey, false)) {
		g_iServerBanTime = StringToInt(sValue);
	} else if (!strcmp("ServerID", sKey, false)) {
		g_iServerID = StringToInt(sValue);
	} else if (!strcmp("OffMaxPlayers", sKey, false)) {
		g_iOffMaxPlayers = StringToInt(sValue);
	} else if (!strcmp("RetryTime", sKey, false)) {
		g_fRetryTime = StringToFloat(sValue);
	} else if (!strcmp("ShowAdminAction", sKey, false)) {
		g_iShowAdminAction = StringToInt(sValue);
	} else if (!strcmp("BasecommTime", sKey, false)) {
		g_iBasecommTime = StringToInt(sValue);
	} else if (!strcmp("BanTypMenu", sKey, false)) {
		g_iBanTypMenu = StringToInt(sValue);
	} else if (!strcmp("IgnoreBanServer", sKey, false)) {
		g_iIgnoreBanServer = StringToInt(sValue);
	} else if (!strcmp("IgnoreMuteServer", sKey, false)) {
		g_iIgnoreMuteServer = StringToInt(sValue);
	} else if (!strcmp("AdminUpdateCache", sKey, false)) {
		g_iAdminUpdateCache = StringToInt(sValue);
	} else if (!strcmp("UseDatabaseFix", sKey, false)) {
		g_bUseDatabaseFix = (sValue[0] != '0');
	} else if (!strcmp("IgnoreFlagOfflineBan", sKey, false)) {
		g_iIgnoreFlagOfflineBan = ReadFlagString(sValue);
	}

#if MADEBUG
	LogToFile(g_sLogConfig, "Loaded config. key \"%s\", value \"%s\"", sKey, sValue);
#endif

	return SMCParse_Continue;
}

public SMCResult NewSectionReason(SMCParser Smc, const char[] sName, bool bOpt_quotes)
{
	if (sName[0]) {
		if (!strcmp("MuteReasons", sName, false)) {
			g_iConfigState = ConfigState_Reason_Mute;
		} else if (!strcmp("BanReasons", sName, false)) {
			g_iConfigState = ConfigState_Reason_Ban;
		} else if (!strcmp("HackingReasons", sName, false)) {
			g_iConfigState = ConfigState_Reason_Hacking;
		} else if (!strcmp("Time", sName, false)) {
			g_iConfigState = ConfigState_Time;
		} else {
			g_iConfigState = ConfigState_Non;
		}

		#if MADEBUG
			LogToFile(g_sLogConfig, "Loaded config. name %s", sName);
		#endif
	}

	return SMCParse_Continue;
}

public SMCResult KeyValueReason(SMCParser Smc, const char[] sKey, const char[] sValue, bool bKey_quotes, bool bValue_quotes)
{
	if (!sKey[0] || !sValue[0]) {
		return SMCParse_Continue;
	}

	switch (g_iConfigState) {
		case ConfigState_Reason_Mute: {
			g_mReasonMMenu.AddItem(sKey, sValue);

			#if MADEBUG
				LogToFile(g_sLogConfig, "Loaded mute reason. key \"%s\", display_text \"%s\"", sKey, sValue);
			#endif
		}
		case ConfigState_Reason_Ban: {
			g_mReasonBMenu.AddItem(sKey, sValue);

			#if MADEBUG
				LogToFile(g_sLogConfig, "Loaded ban reason. key \"%s\", display_text \"%s\"", sKey, sValue);
			#endif
		}
		case ConfigState_Reason_Hacking: {
			g_mHackingMenu.AddItem(sKey, sValue);

			#if MADEBUG
				LogToFile(g_sLogConfig, "Loaded hacking reason. key \"%s\", display_text \"%s\"", sKey, sValue);
			#endif
		}
		case ConfigState_Time: {
			g_aTimeMenuSorting.Push(StringToInt(sKey));
			g_tMenuTime.SetString(sKey, sValue, false);

			#if MADEBUG
				LogToFile(g_sLogConfig, "Loaded time. key \"%s\", display_text \"%s\"", sKey, sValue);
			#endif
		}
	}

	return SMCParse_Continue;
}

public SMCResult EndSection(SMCParser Smc)
{
	return SMCParse_Continue;
}
