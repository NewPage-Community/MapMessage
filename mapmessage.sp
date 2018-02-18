#include <clientprefs>

#pragma newdecls required // let's go new syntax! 

Handle g_hKvChat;
Handle g_hKvDump;
Handle g_hTimer;

int g_iCountDown;
char g_szPath[128];
char g_szDump[128];
char g_szMap[128];
char g_szLastChat[256];
char g_szNumberStr[8];
char g_szChatStr_CN[256];
char g_szChatStr_EN[256];

Handle hSync;

public Plugin myinfo = 
{
    name        = "Map Chat Translations",
    author      = "Kyle",
    description = "",
    version     = "1.0",
    url         = "https://02.ditf.moe ? https://ump45.moe"
};

public void OnPluginStart()
{
    RegServerCmd("sm_reloadchat", Command_Reload);
    
    hSync = CreateHudSynchronizer();
    
    HookEventEx("round_start", Event_RoundStart, EventHookMode_Post);
    HookEventEx("round_end", Event_RoundEnd, EventHookMode_Post);

    //LoadTranslations("ze.phrases");

    char szPath[128];
    FormatEx(szPath, 128, "cfg/sourcemod/map-translations");
    if(!DirExists(szPath))
        CreateDirectory(szPath, 511);

    BuildPath(Path_SM, szPath, 128, "data/mapdump");
    if(!DirExists(szPath))
        CreateDirectory(szPath, 511);
}

public void OnMapStart()
{
    GetCurrentMap(g_szMap, 128);
    LoadTranslationFile();
    g_hTimer = INVALID_HANDLE;
}

public void OnMapEnd()
{
    ClearTimer(g_hTimer);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ClearTimer(g_hTimer);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    ClearTimer(g_hTimer);
}

public Action Command_Reload(int args)
{
    LoadTranslationFile();
    PrintToServer("Reload Translations of %s successful!", g_szMap);
    return Plugin_Handled;
}

void LoadTranslationFile()
{
    //Chat
    if(g_hKvChat != INVALID_HANDLE)
        CloseHandle(g_hKvChat);

    FormatEx(g_szPath, 128, "cfg/sourcemod/map-translations/%s.cfg", g_szMap);

    g_hKvChat = CreateKeyValues("Chat");

    if(!FileExists(g_szPath))
        KeyValuesToFile(g_hKvChat, g_szPath);
    else
        FileToKeyValues(g_hKvChat, g_szPath);
    
    KvRewind(g_hKvChat);
    
    //Dump
    if(g_hKvDump != INVALID_HANDLE)
    {
        if(!KvGotoFirstSubKey(g_hKvDump, true))
            DeleteFile(g_szDump);
        
        CloseHandle(g_hKvDump);
    }

    BuildPath(Path_SM, g_szDump, 128, "data/mapdump/%s.cfg", g_szMap);

    g_hKvDump = CreateKeyValues("Chat");

    if(!FileExists(g_szDump))
        KeyValuesToFile(g_hKvDump, g_szDump);
    else
        FileToKeyValues(g_hKvDump, g_szDump);
    
    KvRewind(g_hKvDump);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if(client != 0)
        return Plugin_Continue;

    if(StrEqual(sArgs, g_szLastChat))
        return Plugin_Handled;

    strcopy(g_szLastChat, 256, sArgs);

    char szChat[256], szTran[256];
    strcopy(szChat, 256, sArgs);
    TrimString(szChat);
    StripQuotes(szChat);
    ReplaceChar(szChat, 256);

    if(g_hKvChat == INVALID_HANDLE)
        LoadTranslationFile();

    if(!KvJumpToKey(g_hKvChat, szChat))
    {
        KvJumpToKey(g_hKvChat, szChat, true);
        KvSetString(g_hKvChat, "trans", szChat);
        KvRewind(g_hKvChat);
        KeyValuesToFile(g_hKvChat, g_szPath);
        KvJumpToKey(g_hKvChat, szChat);
        
        DumpChat(szChat);
    }

    if(KvGetNum(g_hKvChat, "blocked", 0) == 1)
    {
        KvRewind(g_hKvChat);
        return Plugin_Handled;
    }

    KvGetString(g_hKvChat, "trans", szTran, 256, szChat);

    char szCommand[128];
    KvGetString(g_hKvChat, "command", szCommand, 128, "none");

    if(!StrEqual(szCommand, "none"))
        ServerCommand(szCommand);

    if(CheckingCountDown(sArgs, szChat, szTran))
        return Plugin_Handled;

    if(g_hTimer != INVALID_HANDLE)
    {
        static Handle hSync2;
        if(hSync2 == INVALID_HANDLE)
            hSync2 = CreateHudSynchronizer();
        SetHudTextParams(-1.0, 0.745, 8.0, 9, 255, 9, 255, 0, 30.0, 0.0, 0.0);
        for(int i = 1; i <= MaxClients; ++i)
            if(IsClientInGame(i))
                ShowSyncHudText(i, hSync2, sChinese(i) ? szTran : szChat);
    }
    else
    {
        SetHudTextParams(0.160500, 0.066000, 8.0, 9, 255, 9, 255, 0, 30.0, 0.0, 0.0);
        for(int i = 1; i <= MaxClients; ++i)
            if(IsClientInGame(i))
                ShowSyncHudText(i, hSync, sChinese(i) ? szTran : szChat);
    }

    KvRewind(g_hKvChat);

    return Plugin_Handled;
}

bool CheckingCountDown(const char[] sArgs, const char[] szChat, const char[] szTran)
{
    char buffer[256], buffer2[256];
    bool numeric = false;
    strcopy(buffer, 256, sArgs);
    StripQuotes(buffer);
    for(int i=1; i < strlen(buffer); i++)
    {
        if(IsCharNumeric(buffer[i]))
        {
            if(!numeric)
                Format(buffer2, 256, "");
            numeric = true;
            Format(buffer2, 256, "%s%c",buffer2, buffer[i]);
        }
        else if(IsCharSpace(buffer[i]))
            continue;
        else if(numeric)
        {
            if((buffer[i] == 's' || buffer[i] == 'S') && (strlen(buffer) <= i+1 || buffer[i+1] == 'e' || buffer[i+1] == 'E' || IsCharSpace(buffer[i+1]) || buffer[i+1] == '!' || buffer[i+1] == '*'))
            {
                g_iCountDown = StringToInt(buffer2);
                strcopy(g_szNumberStr, 32, buffer2);
                strcopy(g_szChatStr_EN, 256, szChat);
                strcopy(g_szChatStr_CN, 256, szTran);
                BroadcastCountDown();
                ClearTimer(g_hTimer);
                g_hTimer = CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT);
                return true;
            }
            numeric = false;
        }
        else
            numeric = false;
    }
    
    return false;
}

public Action Timer_CountDown(Handle timer)
{
    g_iCountDown--;
    BroadcastCountDown();
}

void BroadcastCountDown()
{
    if(g_iCountDown > 0) 
    {
        char szText[2][256];
        FormatEx(szText[0], 256, "%s", g_szChatStr_EN);
        FormatEx(szText[1], 256, "%s", g_szChatStr_CN);
        ReplaceCountdownNumber(szText[0], 256);
        ReplaceCountdownNumber(szText[1], 256);
        SetHudTextParams(0.160500, 0.066000, 5.0, 238, 0, 0, 255, 0, 30.0, 0.0, 0.0);
        
        for(int client = 1; client <= MaxClients; ++client)
        if(IsClientInGame(client))
            ShowSyncHudText(client, hSync, sChinese(client) ? szText[1] : szText[0]);
    }
    else
    {
        char szText[256];
        ClearTimer(g_hTimer);
        FormatEx(szText, 128, "*** GoGoGo ***", g_iCountDown);
        SetHudTextParams(0.160500, 0.066000, 5.0, 0, 255, 0, 255, 0, 30.0, 0.0, 0.0);
        
        for(int client = 1; client <= MaxClients; ++client)
        if(IsClientInGame(client))
            ShowSyncHudText(client, hSync, szText);

        Handle pb = StartMessageAll("Fade");
        PbSetInt(pb, "duration", 168);
        PbSetInt(pb, "hold_time", 168);
        PbSetInt(pb, "flags", 0x0001|0x0010);
        PbSetColor(pb, "clr", {0, 240, 0, 100});
        EndMessage();
    }
}

void ReplaceCountdownNumber(char[] message, int maxLen)
{
    char number[16];
    Format(number, 16, "%d", g_iCountDown);
    ReplaceString(message, maxLen, g_szNumberStr, number, false);
}

void ReplaceChar(char[] buffer, int maxLen)
{
    if(buffer[0] == '@')
        strcopy(buffer, maxLen, buffer[1]);
    ReplaceString(buffer, maxLen, "\\", "＼", false);
    ReplaceString(buffer, maxLen, "/", "／", false);
}

void DumpChat(const char[] szChat)
{
    KvRewind(g_hKvDump);
    KvJumpToKey(g_hKvDump, szChat, true);
    KvSetString(g_hKvDump, "trans", szChat);
    KvRewind(g_hKvDump);
    KeyValuesToFile(g_hKvDump, g_szDump);

    //char escape[512], query[1024];
    //MG_MySQL_GetDatabase().Escape(szChat, escape, 512);
    //FormatEx(query, 1024, "INSERT IGNORE INTO dxg_mapchat VALUES ('%s', '%s', '%s', null, 0, 0);", g_szMap, escape, escape);
    //MG_MySQL_SaveDatabase(query);
}

bool sChinese(int client)
{
    int iLang = GetClientLanguage(client);
    return (iLang == 23 || iLang == 27);
}

void ClearTimer(Handle &timer)
{
	if(timer != INVALID_HANDLE)
	{
		KillTimer(timer);
		timer = INVALID_HANDLE;
	}
}
