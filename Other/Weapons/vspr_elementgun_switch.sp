#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#include <sdkhooks>
#include <sdktools>
#include <cw3-attributes>
#include <tf2items>

#define MIN			512.0
#define PLUGIN_VERSION "1.0"
#define SLOTS_MAX               7
#define FAR_FUTURE 100000000.0
#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

public Plugin:myinfo = {
    name = "VSPR Element Gun",
    author = "Spyro. Just Spyro.",
    description = "A Borderlands 2 weapon that does element stuff",
    version = "1.0",
    url = "",
};

new BossTeam = _:TFTeam_Blue;
new MercTeam = _:TFTeam_Red;

bool DebugModeEG[MAXPLAYERS+1];
bool ElementMode[MAXPLAYERS+1];

//Modes on the gun
bool FireMode[MAXPLAYERS+1];
bool CorrosiveMode[MAXPLAYERS+1];
bool EletricMode[MAXPLAYERS+1];
bool ExplosiveMode[MAXPLAYERS+1];
//Default mode selected
bool DefaultElement[MAXPLAYERS+1];
int DefaultElementMode[MAXPLAYERS+1];

Handle modehud;

//Relating to the selection button
int ModeSelection[MAXPLAYERS+1];
int SelectionButton[MAXPLAYERS+1];
new SelectionCycleKey[MAXPLAYERS+1];
bool SelectKeyDown[MAXPLAYERS+1];

public OnPluginStart()
{
	RegAdminCmd("sm_elementtest", CMDInitElementMode, ADMFLAG_KICK);
	modehud = CreateHudSynchronizer();
}

public Action OnPlayerRunCmd(int iClient, &buttons, &impulse)
{
  if (IsValidClient(iClient))
  {
	  //Special attack key will be used to switch modes. There is no reverse selection key for now. 
	if (ElementMode[iClient])	 
	{
		ElementMode_Tick(iClient, buttons);
	}
  }

	return Plugin_Continue;
}

public Action CMDInitElementMode(int client, args)
{
	EnableDefaultElement(client);
	return Plugin_Continue;
}

public void ElementGunFailsafe(int iClient)
{
	/* Freak situation but putting this here just in case. If the mode integer somehow goes negative 
	or is still 0 after initalizing, automatically default back to 1.
	*/
	if (ModeSelection[iClient] == 0 || ModeSelection[iClient] < 1)
	{
        if (DebugModeEG[iClient])
        {
		    PrintToChat(iClient, "Warning: Mode selection should not be zero. Setting to 1.");
        }
		ModeSelection[iClient] = 1;
		//sanity
        CorrosiveMode[iClient] = false;
        ExplosiveMode[iClient] = false;
        FireMode[iClient] = false;
		EletricMode[iClient] = true;
        EletricElement(iClient);
	}
}

EGM_GetActionKey(int iClient, int argIdx)
{
	new keyIdx = argIdx;
	if (keyIdx == 1) //Special attack
    {
        if (DebugModeEG[iClient])
        {
            PrintToChat(iClient, "Key index set to 1, Special Attack key is used to switch modes");
        }
		return IN_ATTACK3;
    }
	else if (keyIdx == 2) //Action Key
    {
        if (DebugModeEG[iClient])
        {
            PrintToChat(iClient, "Key index set to 2, Action key is used to switch modes. MAKE SURE NO ITEMS ARE IN ACTION SLOT!");
        }
        return IN_USE;
    }
	if (DebugModeEG[iClient])
    {
        PrintToChat(iClient, "Warning: No mode selection key specified. Defaulting to 'Alt-Fire (Attack2)'");
        return IN_ATTACK2;
    }	
	return IN_ATTACK2; // no key, implied is "call for medic"
}



public void ElementMode_Tick(int iClient, buttons)
{
	new bool:selKeyDown = (buttons & SelectionCycleKey[iClient]) != 0;
    if (selKeyDown && !SelectKeyDown[iClient])
	{
		ModeSelection[iClient]++;
        if (DebugModeEG[iClient])
        {
            PrintToChat(iClient, "Mode Selection:%d", ModeSelection[iClient]);
        }
        ModeSelection[iClient] %= 5;
        ElementGunFailsafe(iClient);
        ElementModeSelection(iClient);
        //When all the modes have been cycled through, return to the default mode of 1.
	}
	SelectKeyDown[iClient] = selKeyDown;
}

public void ElementModeSelection(int iClient)
{
    switch(ModeSelection[iClient])
    {
        case 1:
        {
            CorrosiveMode[iClient] = false;
            ExplosiveMode[iClient] = false;
            FireMode[iClient] = false;
            EletricMode[iClient] = true;
            EletricElement(iClient);
        }
        case 2:
        {
            CorrosiveMode[iClient] = false;
            ExplosiveMode[iClient] = true;
            FireMode[iClient] = false;
            EletricMode[iClient] = false;
            ExplosiveElement(iClient);
        }
        case 3:
        {
            CorrosiveMode[iClient] = true;
            ExplosiveMode[iClient] = false;
            FireMode[iClient] = false;
            EletricMode[iClient] = false;
            CorrosiveElement(iClient);
        }
        case 4:
        {
            FireModeSet(iClient);
            CorrosiveMode[iClient] = false;
            ExplosiveMode[iClient] = false;
            FireMode[iClient] = true;
            EletricMode[iClient] = false;  
        }
    }

    return;
}


public void EnableDefaultElement(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(weapon))
	{
        if (DefaultElement[client])
        {
            switch(DefaultElementMode[client])
            {
                case 1:
                {
                    TF2Attrib_SetByName(weapon, "override projectile type", 13.0);
                    CorrosiveMode[client] = false;
                    ExplosiveMode[client] = false;
                    FireMode[client] = false;
                    EletricMode[client] = true;
                    ModeSelection[client] = 1;
                }
                case 2:
                {
                    TF2Attrib_SetByName(weapon, "override projectile type", 2.0);
		            TF2Attrib_SetByName(weapon, "mod mini-crit airborne", 1.0);
		            TF2Attrib_SetByName(weapon, "Blast radius increased", 2.5);
		            TF2Attrib_SetByName(weapon, "self dmg push force decreased", 0.5);
                    CorrosiveMode[client] = false;
                    ExplosiveMode[client] = true;
                    FireMode[client] = false;
                    EletricMode[client] = false;
                    ModeSelection[client] = 2;
                }
                case 3:
                {
                    TF2Attrib_SetByName(weapon, "dmg pierces resists absorbs", 1.0);
		            TF2Attrib_SetByName(weapon, "bleeding duration", 9.0);
                    CorrosiveMode[client] = true;
                    ExplosiveMode[client] = false;
                    FireMode[client] = false;
                    EletricMode[client] = false;
                    ModeSelection[client] = 3;
                }
                case 4:
                {
                    //SDKHook(client, SDKHook_OnTakeDamage, FireElementOTD);
                    FireModeSet(client);
                    CorrosiveMode[client] = false;
                    ExplosiveMode[client] = false;
                    FireMode[client] = true;
                    EletricMode[client] = false;
                    ModeSelection[client] = 4;
                }
            }
        }

        else if (!DefaultElement[client] || DefaultElementMode[client] == 0 || DefaultElementMode[client] == 5)
        {
            TF2Attrib_SetByName(weapon, "override projectile type", 13.0);
            CorrosiveMode[client] = false;
            ExplosiveMode[client] = false;
            FireMode[client] = false;
            EletricMode[client] = true;
            ModeSelection[client] = 1;
        }
	}

    if (DebugModeEG[client])
	PrintToChat(client, "weapon hooked: element mode set to default");
}

public void FireModeSet(int iClient)
{
    int weapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
    if (IsValidClient(iClient) && FireMode[iClient] || IsValidClient(iClient) && ModeSelection[iClient] == 4)
	{
        if (DebugModeEG[iClient])
        {
            PrintToChat(iClient, "Fire Mode selected");
        }
        char hudtext[12];
        Format(hudtext, sizeof(hudtext), "Fire Mode");
        //in case sourcemod hud doesnt work
        ShowSyncHudText(iClient, modehud, "MODE:%s", hudtext);
        //Remove all other attributes from all other modes
        TF2Attrib_RemoveByName(weapon, "Blast radius increased");	
		TF2Attrib_RemoveByName(weapon, "mod mini-crit airborne");
		TF2Attrib_RemoveByName(weapon, "self dmg push force decreased");
        TF2Attrib_RemoveByName(weapon, "mod stun waist high airborne");
        TF2Attrib_RemoveByName(weapon, "dmg pierces resists absorbs");
		TF2Attrib_RemoveByName(weapon, "bleeding duration");

        //Since this mode only uses ignite on hit, only set it so it fires bullets.
        TF2Attrib_SetByName(weapon, "override projectile type", 6.0);
        TF2Attrib_SetByName(weapon, "damage bonus", 15.0);
        TF2Attrib_SetByName(weapon, "weapon spread bonus", 0.1);
        SDKHook(iClient, SDKHook_OnTakeDamageAlive, FireElementOTD);
    }
}


public Action:FireElementOTD(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (IsValidClient(client) && IsValidClient(attacker) && (client != attacker))
	{
        if (FireMode[attacker] && GetClientTeam(client) == BossTeam && IsLivingPlayer(client))
        {
            TF2_IgnitePlayer(client, attacker, 7.75);
        }
        else if (!FireMode[attacker])
        {
           return Plugin_Continue;
        }
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

public void CorrosiveElement(int iClient)
{
	int weapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (IsValidClient(iClient) && CorrosiveMode[iClient] || IsValidClient(iClient) && ModeSelection[iClient] == 3)
	{
        char hudtext[12];
        Format(hudtext, sizeof(hudtext), "Corrosive Mode");
        //in case sourcemod hud doesnt work 
        if (DebugModeEG[iClient])
        {
            PrintToChat(iClient, "Corrosive Mode selected");
        }
        ShowSyncHudText(iClient, modehud, "MODE:3", hudtext);
        //Remove attributes from other modes frist
        TF2Attrib_RemoveByName(weapon, "Blast radius increased");	
		TF2Attrib_RemoveByName(weapon, "mod mini-crit airborne");
		TF2Attrib_RemoveByName(weapon, "self dmg push force decreased");
        TF2Attrib_RemoveByName(weapon, "mod stun waist high airborne");
        TF2Attrib_RemoveByName(weapon, "damage bonus");
        TF2Attrib_RemoveByName(weapon, "weapon spread bonus");
        //Set attributes for current mode
        TF2Attrib_SetByName(weapon, "override projectile type", 1.0);
		TF2Attrib_SetByName(weapon, "dmg pierces resists absorbs", 1.0);
		TF2Attrib_SetByName(weapon, "bleeding duration", 9.0);
	}
    /* This is now redundant but I might re-implemnt it in the future.
	else if (ModeSelection[iClient] != 3 || !CorrosiveMode[iClient])
	{
		TF2Attrib_RemoveByName(weapon, "dmg pierces resists absorbs");
		TF2Attrib_RemoveByName(weapon, "bleeding duration");	
	}
    */
}


public void ExplosiveElement(int iClient)
{
	int weapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (IsValidClient(iClient) && ExplosiveMode[iClient] || IsValidClient(iClient) && ModeSelection[iClient] == 2)
	{
        char hudtext[12];
        Format(hudtext, sizeof(hudtext), "Explosive Mode");
        //in case sourcemod hud doesnt work 
        if (DebugModeEG[iClient])
        {
            PrintToChat(iClient, "Explosive Mode selected");
        }
        ShowSyncHudText(iClient, modehud, "MODE:%s", hudtext);
        //Remove attributes from other modes first
        TF2Attrib_RemoveByName(weapon, "dmg pierces resists absorbs");
		TF2Attrib_RemoveByName(weapon, "bleeding duration");
        TF2Attrib_RemoveByName(weapon, "mod stun waist high airborne");
        TF2Attrib_RemoveByName(weapon, "weapon spread bonus");
        //Set attributes of current mode
		TF2Attrib_SetByName(weapon, "override projectile type", 2.0);
		TF2Attrib_SetByName(weapon, "mod mini-crit airborne", 1.0);
		TF2Attrib_SetByName(weapon, "Blast radius increased", 2.5);
		TF2Attrib_SetByName(weapon, "self dmg push force decreased", 0.5);
        TF2Attrib_SetByName(weapon, "damage bonus", 21.85); //2185% Damage bonus
	}

    /* This is now redundant but I might re-implemnt it in the future.
	else if (ModeSelection[iClient] != 2 || !ExplosiveMode[iClient])
	{
		TF2Attrib_RemoveByName(weapon, "override projectile type");
        TF2Attrib_SetByName(weapon, "override projectile type", 1.0);
		TF2Attrib_RemoveByName(weapon, "Blast radius increased");	
		TF2Attrib_RemoveByName(weapon, "mod mini-crit airborne");
		TF2Attrib_RemoveByName(weapon, "self dmg push force decreased");
	}
    */
}

public void EletricElement(int iClient)
{
	int weapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (IsValidClient(iClient) && EletricMode[iClient] || IsValidClient(iClient) && ModeSelection[iClient] == 1)
	{
        char hudtext[12];
        Format(hudtext, sizeof(hudtext), "Eletric Mode");
         //in case sourcemod hud doesnt work 
        if (DebugModeEG[iClient])
        {
            PrintToChat(iClient, "Eletric Mode selected");
        }
        ShowSyncHudText(iClient, modehud, "MODE:%s", hudtext);
        //Remove other mode attributes
        TF2Attrib_RemoveByName(weapon, "dmg pierces resists absorbs");
		TF2Attrib_RemoveByName(weapon, "bleeding duration");
        TF2Attrib_RemoveByName(weapon, "Blast radius increased");	
		TF2Attrib_RemoveByName(weapon, "mod mini-crit airborne");
		TF2Attrib_RemoveByName(weapon, "self dmg push force decreased");
        TF2Attrib_RemoveByName(weapon, "damage bonus");
        TF2Attrib_RemoveByName(weapon, "weapon spread bonus");
        //Set attributes for current mode
		TF2Attrib_SetByName(weapon, "override projectile type", 13.0);
		TF2Attrib_SetByName(weapon, "mod stun waist high airborne", 1.0);
	}

    /* This is now redundant but I might re-implemnt it in the future.
	else if (ModeSelection[iClient] != 1 || !EletricMode[iClient])
	{
		TF2Attrib_RemoveByName(weapon, "override projectile type");
        TF2Attrib_SetByName(weapon, "override projectile type", 1.0);
		TF2Attrib_RemoveByName(weapon, "mod stun waist high airborne");	
	}
    */
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
    DebugModeEG[client] = true;
    PrintToChat(client, "Debug mode enabled. Check chat while using this weapon.");
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "Element Mode Enabled"))
  {
    ElementMode[client] = true;
    PrintToChat(client, "Element Mode Enabled");
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "Enable default element"))
  {
    DefaultElement[client] = true;
    EnableDefaultElement(client);
    PrintToChat(client, "Default element enabled");
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "Set default element"))
  {
    DefaultElementMode[client] = StringToInt(value);
    PrintToChat(client, "Default element set to %d", DefaultElementMode[client]);
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "Set mode selection key"))
  {
    SelectionButton[client] = StringToInt(value);
    SelectionCycleKey[client] = EGM_GetActionKey(client, SelectionButton[client]);
    if (SelectionButton[client] == 1)
    {
     PrintToChat(client, "Selection mode key set to 1. Use Special Attack (attack3) to switch modes");
    }
    else if (SelectionButton[client] == 2)
    {
     PrintToChat(client, "Selection mode key set to 2. Use Action Slot Key to switch modes.");
     PrintToChat(client, "WARNING: Ensure no items are in your action slot before using this weapon.");
    }
    else if (SelectionButton[client] == 0)
    {
     PrintToChat(client, "Selection key not specified. Defaulting to Alt-Fire (attack2) key.");
    }
    action = Plugin_Handled;
  }

  return action;
}

//Variable reset
public CW3_OnWeaponRemoved(slot, client)
{
    DebugModeEG[client] = false;
    ElementMode[client] = false;
    DefaultElement[client] = false;
    DefaultElementMode[client] = 0;
    DebugModeEG[client] = false;
    SelectionButton[client] = 0;
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, FireElementOTD);
}


stock bool:IsLivingPlayer(clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);
}