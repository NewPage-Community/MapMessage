#pragma newdecls required // let's go new syntax! 

KeyValues g_hKvChat;
KeyValues g_hKvDump;

Handle g_hTimer;

int g_iCountDown;
char g_szPath[128];
char g_szDump[128];
char g_szMap[128];
char g_szLastChat[256];
char g_szNumberStr[8];
char g_szChatStr_CN[256];
char g_szChatStr_EN[256];

public Plugin myinfo = 
{
    name        = "Map Chat Translations",
    author      = "Kyle 'Kxnrl' FranKiss - fix by Gunslinger",
    description = "",
    version     = "1.1",
    url         = ""
};

public void OnPluginStart()
{
    RegServerCmd("sm_reloadchat", Command_Reload);
        
    HookEventEx("round_start", Event_RoundStart, EventHookMode_Post);
    HookEventEx("round_end", Event_RoundEnd, EventHookMode_Post);

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
    if(g_hKvChat != null)
        delete g_hKvChat;

    FormatEx(g_szPath, 128, "cfg/sourcemod/map-translations/%s.cfg", g_szMap);

    g_hKvChat = new KeyValues("Chat");

    if(!FileExists(g_szPath))
        g_hKvChat.ImportFromFile(g_szPath);
    else
        g_hKvChat.ExportToFile(g_szPath);
    
    g_hKvChat.Rewind();
    
    //Dump
    if(g_hKvDump != null)
    {
        if(!g_hKvDump.GotoFirstSubKey(true))
            DeleteFile(g_szDump);

        delete g_hKvDump;
    }

    BuildPath(Path_SM, g_szDump, 128, "data/mapdump/%s.cfg", g_szMap);

    g_hKvDump = new KeyValues("Chat");

    if(!FileExists(g_szDump))
        g_hKvDump.ImportFromFile(g_szDump);
    else
        g_hKvDump.ExportToFile(g_szDump);
    
    g_hKvDump.Rewind();
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if(client != 0)
        return Plugin_Continue;

    if(strcmp(sArgs, g_szLastChat) == 0)
        return Plugin_Handled;

    strcopy(g_szLastChat, 256, sArgs);

    char szChat[256], szTran[256];
    strcopy(szChat, 256, sArgs);
    TrimString(szChat);
    StripQuotes(szChat);
    ReplaceChar(szChat, 256);

    if(g_hKvChat == null)
        LoadTranslationFile();

    if(!g_hKvChat.JumpToKey(szChat))
    {
        g_hKvChat.JumpToKey(szChat, true);
        g_hKvChat.SetString("trans", szChat);
        g_hKvChat.Rewind();
        g_hKvChat.ExportToFile(g_szPath);
        g_hKvChat.JumpToKey(szChat);

        DumpChat(szChat);
    }

    if(g_hKvChat.GetNum("blocked", 0) == 1)
    {
        g_hKvChat.Rewind();
        return Plugin_Handled;
    }

    g_hKvChat.GetString("trans", szTran, 256, szChat);

    char szCommand[128];
    g_hKvChat.GetString("command", szCommand, 128, "none");

    if(strcmp(szCommand, "none") != 0)
        ServerCommand(szCommand);

    if(CheckingCountDown(sArgs, szChat, szTran))
        return Plugin_Handled;

    for(int i = 1; i <= MaxClients; ++i)
        if(IsClientInGame(i))
            PrintToChat(i, "[\x05地图提示\x01] \x02%s", sChinese(i) ? szTran : szChat);

    g_hKvChat.Rewind();

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

        for(int i = 1; i <= MaxClients; ++i)
            if(IsClientInGame(i))
            PrintToChat(i, "[\x05地图提示\x01] \x02%s", sChinese(i) ? szText[1] : szText[0]);
    }
    else
    {
        ClearTimer(g_hTimer);

        PrintToChatAll("[\x05地图提示\x01] \x02*** GoGoGo ***");
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
    g_hKvDump.Rewind();
    g_hKvDump.JumpToKey(szChat, true);
    g_hKvDump.SetString("trans", szChat);
    g_hKvDump.Rewind();
    g_hKvDump.ExportToFile(g_szDump);
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
