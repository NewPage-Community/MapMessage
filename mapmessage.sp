#pragma semicolon 1
#pragma newdecls required

#include <sdktools>

int number;
Handle timers;
KeyValues kv;

public Plugin myinfo =
{
	name = "Map Message",
	description = "",
	author = "Gunslinger",
	version = "1.0",
	url = ""
};
 
public void OnPluginStart()
{
	AddCommandListener(SayConsole, "say");
	
	HookEvent("round_start", Resett);
}

public void OnMapStart()
{
	RefreshKV();
}

public Action Resett(Handle event, const char[]name, bool dontBroadcast)
{
	if(timers != INVALID_HANDLE)
	{
		KillTimer(timers);
		timers = INVALID_HANDLE;
	}
}
 
public Action SayConsole(int client, const char[] command, int args)
{
	if(client != 0)
		return Plugin_Continue;
	
	char buffer[255];
	GetCmdArgString(buffer, 255);

	kv.Rewind();
	
	if(kv.JumpToKey(buffer))
	{
		if(kv.GetNum("blocked", 0))
			return Plugin_Handled;
		
		char trans[255];
		kv.GetString("trans", trans, 255, "");
		PrintToChatAll("\x04[MAP] \x07%s", trans);

		number = kv.GetNum("countdown", 0);
		if(number != 0)
			CountDown();

		char mcommand[64];
		kv.GetString("command", mcommand, 255, "");
		if(mcommand[0])
			ServerCommand("%s", mcommand);
	}
	else
	{
		PrintToChatAll("\x04[MAP] \x07%s", buffer);

		char buffer2[255];
		StripQuotes(buffer);
		bool numeric = false;
	
		for(int i=1; i < strlen(buffer); i++)
		{
			if(IsCharNumeric(buffer[i]))
			{
				if(!numeric)
					Format(buffer2, 255, "");
				numeric = true;
				Format(buffer2, 255, "%s%c",buffer2, buffer[i]);
			}
			else if(IsCharSpace(buffer[i])) 
				continue;
			else if(numeric)
			{
				if((buffer[i] == 's' || buffer[i] == 'S') && (strlen(buffer) <= i+1 || buffer[i+1] == 'e' || buffer[i+1] == 'E' || IsCharSpace(buffer[i+1]) || buffer[i+1] == '!' || buffer[i+1] == '*'))
				{
					number = StringToInt(buffer2);
					CountDown();
					return Plugin_Continue;
				}
				numeric = false;
			}
			else 
				numeric = false;
		}	
	}
	return Plugin_Handled;
}

void RefreshKV()
{
	char map[128];
	GetCurrentMap(map, 128);

	char path[PLATFORM_MAX_PATH];
	Format(path, PLATFORM_MAX_PATH, "cfg/sourcemod/map-translation/%s.cfg", map);

	if(kv != INVALID_HANDLE) 
		CloseHandle(kv);
	
	kv = new KeyValues("Chat");
	kv.ImportFromFile(path);

	if(FileExists(path))
	{
		PrintToServer("[MapMessage] Can not find %s setting file", map);
	}
}


void CountDown()
{
	if(timers != INVALID_HANDLE)
	{
		KillTimer(timers);
		timers = INVALID_HANDLE;
	}
	timers = CreateTimer(1.0, Repeater, _, TIMER_REPEAT);
	PrintHintTextToAll("<font size='30' color='#FF0000'>剩下 %i 秒</font>", number);
}

public Action Repeater(Handle timer)
{
	number--;
	if(number <= 0)
	{
		PrintHintTextToAll("<font size='30' color='#FF0000'>倒计时结束!</font>");	
		if(timers != INVALID_HANDLE)
		{
			KillTimer(timers);
			timers = INVALID_HANDLE;
		}
		return;
	}
	PrintHintTextToAll("<font size='30' color='#FF0000'>剩下 %i 秒</font>", number);
}