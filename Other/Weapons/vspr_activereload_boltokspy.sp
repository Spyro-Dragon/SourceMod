#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#include <sdkhooks>
#include <sdktools>
#include <cw3-attributes>
#include <tf2items>
#include <cw3>

#define MIN			512.0
#define PLUGIN_VERSION "1.75"
#define SLOTS_MAX  7
#define FAR_FUTURE 100000000.0


public Plugin:myinfo = {
    name = "VSPR Attributes:Active Reload",
    author = "Original:IvoryPal This plugin: Spyro. Just Spyro.",
    description = "The active reload system for gears of war weapons.",
    version = PLUGIN_VERSION,
    url = ""
};

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

bool DebugModeBS[MAX_PLAYERS_ARRAY];

// Weapon specific values
bool hooked[MAX_PLAYERS_ARRAY];
bool Reloading[MAX_PLAYERS_ARRAY];

// Attribute values
bool HasActiveReload[MAXPLAYERS + 1];
float CurReload[MAX_PLAYERS_ARRAY];
//float AddOrRemoveAmmoDelay[MAX_PLAYERS_ARRAY];
float ActiveReloadDecay[MAX_PLAYERS_ARRAY];



// Plugin start

public OnPluginStart()
{
	RegAdminCmd("sm_reloadhook_boltok_spy", CMDHookReload, ADMFLAG_KICK);
}

public OnMapStart()
{
    PrecacheSound("vspr/pinkiepie/pinkie_honk.mp3");
}

public Action:CMDHookReload(int client, int args)
{
	hooked[client] = !hooked[client];
	HookReloadBoltokSpy(client);
}

public void PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client))
    {
		if (hooked[client])
		HookReloadBoltokSpy(client);
    }
}


public void HookReloadBoltokSpy(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(weapon))
	{
		SDKHook(weapon, SDKHook_Reload, WeaponReload);
        TF2Attrib_RemoveByName(client, "reload time increased");
		//TF2Attrib_SetByName(weapon, "reload time increased", 5.0);
	}
    if (DebugModeBS[client])
    {
        PrintToChat(client, "hooked weapon reload");
    }
	
}

public void UnHookReloadBoltokSpy(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(weapon))
	{
		SDKUnhook(weapon, SDKHook_Reload, WeaponReload);
	}
    if (DebugModeBS[client])
    {
	    PrintToChat(client, "unhooked weapon reload");
    }
}

public void RemoveWeaponClipAmmo(int client)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (IsValidEntity(weapon))
	{
        if (DebugModeBS[client])
        {
            PrintToChat(client, "Weapon clip emptied.");
        }
        SetClip_Weapon(weapon, 0);
    }

}

public void FillWeaponClipAmmo(int client)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (IsValidEntity(weapon))
	{
        if (DebugModeBS[client])
        {
            PrintToChat(client, "Weapon clip filled.");
        }
        SetClip_Weapon(weapon, 1);  
    }
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    int ARPassFail = 0;
	if (IsValidClient(client))
    {
		if (Reloading[client] && HasActiveReload[client] && buttons & IN_ATTACK3)
        {
            if (GetEngineTime()+2.9 >= CurReload[client] >= GetEngineTime())
            {
                if (DebugModeBS[client])
                {
                    PrintToChat(client, "Perfect Reload!");
                }
                ARPassFail = 2;
                CurReload[client] = FAR_FUTURE;
                Reloading[client] = false;
            }
            else if ((GetEngineTime()+2.5 >= CurReload[client] >= GetEngineTime()+2.1) || CurReload[client] <= GetEngineTime())
            {
                if (DebugModeBS[client])
                {
                    PrintToChat(client, "FAIL!");
                }
                CreateTimer(6.5, ReHookReload, client, TIMER_FLAG_NO_MAPCHANGE);
                ARPassFail = 1;
                CurReload[client] = FAR_FUTURE;
                Reloading[client] = false;
            }
        }
        switch(ARPassFail)
        {
            case 1:
            {
                CW3_EquipItemByName(client, "The Boltok (Spy)");
                TF2_AddCondition(client, TFCond_MarkedForDeath, 2.0); 
                RemoveWeaponClipAmmo(client);
                UnHookReloadBoltokSpy(client);
                TF2Attrib_SetByName(client, "reload time increased", 1.50);
                ARPassFail = 0;
            }
            case 2:
            {
                CW3_EquipItemByName(client, "The Boltok (Spy)");
                TF2Attrib_SetByName(client, "headshot damage increase", 2.75); 
                TF2Attrib_SetByName(client, "damage bonus", 1.75);
                UnHookReloadBoltokSpy(client);
                CreateTimer(7.5, RemoveDamageBuffs, client, TIMER_FLAG_NO_MAPCHANGE);
                ARPassFail = 0;
            }
        }
	}
	return Plugin_Continue;
}


public Action:WeaponReload(int weapon)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    //CreateTimer(6.25, SetClipToMaxDelay, weapon, TIMER_FLAG_NO_MAPCHANGE);
    if (!Reloading[owner])
    {
        CurReload[owner] = GetEngineTime()+3.0;
        Reloading[owner] = true;
    }
    if (DebugModeBS[owner])
    {
        PrintToChat(owner, "reloading");
    }
}

/*
public Action:SetClipToMaxDelay(Handle:hTimer, any:weapon)
{
	if (IsValidEntity(weapon))
	{
		SetClip_Weapon(weapon, 8);
	}
	
	return Plugin_Continue;
}
*/

public Action:ReHookReload(Handle:hTimer, any:client)
{
	if (IsValidEntity(client))
	{
		HookReloadBoltokSpy(client);
	}
	
	return Plugin_Continue;
}

public Action:RemoveDamageBuffs(Handle:hTimer, any:client)
{
	if (IsValidEntity(client))
	{
		TF2Attrib_RemoveByName(client, "headshot damage increase"); 
        TF2Attrib_RemoveByName(client, "damage bonus");
        if (DebugModeBS[client])
        {
            PrintToChat(client, "damage buffs removed");
        }
        HookReloadBoltokSpy(client);
	}
	
	return Plugin_Continue;
}


stock SetClip_Weapon(weapon, newClip)
{
	new iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
	SetEntData(weapon, iAmmoTable, newClip, 4, true);
}

stock SetViewmodelAnimation(client, sequence)
{
    new ent = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
    if (!IsValidEdict(ent)) return;
    SetEntProp(ent, Prop_Send, "m_nSequence", sequence);
} 



// Attribute processing
public Action:CW3_OnAddAttribute(slot, client, const String:attrib[], const String:plugin[], const String:value[], bool:whileActive)
{
    /*
	if (!StrEqual(plugin, "vsprattribs")) 
    return Plugin_Continue;
    */

  new Action:action;
  if (StrEqual(attrib, "Enable debug mode"))
  {
    DebugModeBS[client] = true;
    PrintToChat(client, "Debug mode enabled. Check chat while using weapon");
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "Has Spy Active Reload Boltok"))
  {
    HasActiveReload[client] = true;
    HookReloadBoltokSpy(client);
    PrintToChat(client, "ActiveReload");
    action = Plugin_Handled;
  }
  /*
  if (StrEqual(attrib, "Active Reload default time"))
  {
    ActiveReloadDefaultTime[client] = StringToFloat(value);
    action = Plugin_Handled;
  }
  
  if (StrEqual(attrib, "Active Reload time decay"))
  {
    ActiveReloadDecay[client] = StringToFloat(value);
    action = Plugin_Handled;
  }
  */
  return action;
}




// Variable resets
public CW3_OnWeaponRemoved(slot, client)
{
    DebugModeBS[client] = false;
    HasActiveReload[client] = false;
    UnHookReloadBoltokSpy(client);
   //ActiveReloadDefaultTime[client] = 0.0;
    //ActiveReloadDecay[client] = 0.0;
}





