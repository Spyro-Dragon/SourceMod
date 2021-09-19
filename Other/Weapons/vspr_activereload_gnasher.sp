#pragma semicolon 1
#pragma tabsize 0

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
#define WEAPON_SLOTS_MAX  7
#define FAR_FUTURE 100000000.0
#define MAX_SOUND_FILE_LENGTH 128
#define MAX_MODEL_FILE_LENGTH 128

new MercTeam = _:TFTeam_Red;
new BossTeam = _:TFTeam_Blue;

public Plugin myinfo = {
    name = "VSPR Attributes:Active Reload",
    author = "Original:IvoryPal This plugin: Spyro. Just Spyro.",
    description = "The active reload system for gears of war weapons.",
    version = PLUGIN_VERSION,
    url = ""
};


#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

#define SOUND_AR_FAIL "sound/vspr/marcus/dammit.mp3"
#define SOUND_AR_PERFECT "sound/vspr/marcus/noice.mp3"

bool DebugModeG[MAX_PLAYERS_ARRAY]; //For debugging
bool PRINT_SERVER_DEBUG_INFO = true; //Use if you cant use the actual attribute

//Internal variables

//Active reload internals
//#define ACTIVE_RELOAD_HUD_INTERVAL 0.05 Might not need this
bool ACTIVE_RELOAD_ENABLED;
Handle ActiveReloadHud;
bool HUD_WEAPON_RELOADING;
float AR_UpdateHudAt = 1.0;
bool hooked[MAX_PLAYERS_ARRAY];
bool Reloading[MAX_PLAYERS_ARRAY];
bool ARReloadKeyDown[MAX_PLAYERS_ARRAY];
bool ARSpecialKeyDown[MAX_PLAYERS_ARRAY];
bool ARBonusState[MAX_PLAYERS_ARRAY];
bool ARJammedState[MAX_PLAYERS_ARRAY];
float CurReload[MAX_PLAYERS_ARRAY];
//These are internal until further notice.
float BuffDuration[MAX_PLAYERS_ARRAY];
float JamFrequency[MAX_PLAYERS_ARRAY];
float JamDuration[MAX_PLAYERS_ARRAY];
int ARPassFail[MAX_PLAYERS_ARRAY];


// Attribute values

//Active reload attributes
bool HasActiveReload[MAX_PLAYERS_ARRAY];
bool ARFailSound[MAX_PLAYERS_ARRAY]; 
bool ARPerfectSound[MAX_PLAYERS_ARRAY];
//float ActiveReloadDecay[MAX_PLAYERS_ARRAY];

//Gnasher Attributes SoonTM
bool GibOnKillSound[MAX_PLAYERS_ARRAY];


// Plugin start

public void OnPluginStart()
{
	RegAdminCmd("sm_reloadhook_gnasher", CMDHookReload, ADMFLAG_KICK);
    ActiveReloadHud = CreateHudSynchronizer();
}

public void OnMapStart()
{
    PrecacheSound(SOUND_AR_FAIL, true);
    PrecacheSound(SOUND_AR_PERFECT, true);
}

public Action CMDHookReload(int client, int args)
{
	hooked[client] = !hooked[client];
	HookReloadGnasher(client);
}

public void PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client))
    {
		if (hooked[client])
        {
            HookReloadGnasher(client);
        }
    }
}


public void HookReloadGnasher(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEdict(weapon))
	{
		SDKHook(weapon, SDKHook_Reload, WeaponReload);
        ARPassFail[client] = 0;
		//TF2Attrib_SetByName(weapon, "reload time increased", 5.0);
	}
    if (DebugModeG[client])
    {
        PrintToChatAll("hooked weapon reload");
    }
	
}

public void UnHookReloadGnasher(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEdict(weapon) || !IsLivingPlayer(client))
	{
		SDKUnhook(weapon, SDKHook_Reload, WeaponReload);
	}
    if (DebugModeG[client])
	PrintToChat(client, "unhooked weapon reload");
}

public void InitActiveReload(int client)
{
    if (IsLivingPlayer(client))
    {
        //ClientCommand(client, "hud_fastswitch 1");
        ARReloadKeyDown[client] = (GetClientButtons(client) & IN_RELOAD) != 0;
        ARSpecialKeyDown[client] = (GetClientButtons(client) & IN_ATTACK3) != 0;
        BuffDuration[client] = 8.7;
        JamFrequency[client] = 7.0;
        JamDuration[client] = 12.5;
        PrintToChat(client, "Active Reload initalized. Attributes that wouldnt work are now hopefully set.");
        //ClientCommand(client, "slot2");
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary));
        CreateTimer(1.46, HookReloadDelay, client, TIMER_FLAG_NO_MAPCHANGE);
    }
    else if (!IsLivingPlayer(client) || !HasActiveReload[client])
    UnHookReloadGnasher(client);
}

public Action HookReloadDelay(Handle hTimer, any client)
{
	if (IsValidEntity(client))
	{
		HookReloadGnasher(client);
	}
	
	return Plugin_Continue;
}

public Action WeaponReload(int weapon)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    //CreateTimer(6.25, SetClipToMaxDelay, weapon, TIMER_FLAG_NO_MAPCHANGE);
    if (ARBonusState[owner] || ARJammedState[owner]) //If bonuses or gun jam is active, Return.
    {
        if (DebugModeG[owner])
        {
            PrintToChat(owner, "[Active Reload]: Weapon is jammed or in bonus state. WeaponReload action will not fully fire.");
        }
        return Plugin_Continue;
    }

    if (Reloading[owner] && HUD_WEAPON_RELOADING) //Check if owner is already reloading. If they are, return.
    {
        if (DebugModeG[owner])
        {
            PrintToChat(owner, "Error: Already reloading. WeaponReload action will not fully fire.");
        }
        return Plugin_Continue;
    }
    else if (!Reloading[owner] && !HUD_WEAPON_RELOADING) 
    {
        CurReload[owner] = GetEngineTime()+6.2;
        Reloading[owner] = true;
        HUD_WEAPON_RELOADING = true;
        CreateTimer(AR_UpdateHudAt, AR_Timer, owner, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(6.1, WeaponReloadTimer, owner, TIMER_FLAG_NO_MAPCHANGE);
        if (DebugModeG[owner])
        {
            PrintToChat(owner, "Reloading. Active Reload ready to execute.");
        }
        return Plugin_Continue;
    }
    if (DebugModeG[owner])
    {
        PrintToChat(owner, "Reloading action fired but Active Reload will not execute.");
    }
    return Plugin_Continue;
}

public Action WeaponReloadTimer(Handle hTimer, any owner)
{
    if (!Reloading[owner])
    {
        if (DebugModeG[owner])
        {
            PrintToChat(owner, "[Reload Timer]: Weapon reload state is already false. Reload timer returning.");
        }
        return Plugin_Handled;
    }

	if (IsLivingPlayer(owner) && Reloading[owner])
	{
        if (DebugModeG[owner])
        {
            PrintToChat(owner, "[Reload Timer]: Weapon reload state now set to false. Reload on weapon has completed.");
        }
		Reloading[owner] = false;
        HUD_WEAPON_RELOADING = false;
	}
	return Plugin_Continue;
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client))
    {
        if (HasActiveReload[client])
        {
            EmptyClipThenReload(client, buttons);
            AR_RunCmd(client, buttons);
        }
	}
	return Plugin_Continue;
}

public void AR_RunCmd(int bClient, int buttons)
{
    bool bSpecialDown = (buttons & IN_ATTACK3) != 0;
    bool bSpecialPressed = (bSpecialDown && !ARSpecialKeyDown[bClient]);

    // Active reload will be delayed by 0.5s to prevent the reload key from being held down too long initially... Could possibly work? ~ Ivory.
    //This section is mainly Ivory Pal's doing. And what a pal he is for helping me solve this. And going the extra mile to explain it. ~ Spyro. Just Spyro.
    //I will explain the tidbits I added to enchance his work.
    if (Reloading[bClient] && HasActiveReload[bClient] && bSpecialPressed)
    {
        // GetEngineTime()+5.1 creates a 1.0s delay from GetEngineTime()+6.1 | 6.1 - 5.1 = 1.0 delay ~ Ivory
        if (GetEngineTime()+5.1 >= CurReload[bClient] >= GetEngineTime()) // 1s delay before a reload can be considered perfect ~ Ivory
        {
            //If an active reload is executed right, bonus state will be set to true. 
            //During bonus state, no further active reloads can be attempted. ~ Spyro.
            ARBonusState[bClient] = true; 
            if (DebugModeG[bClient])
            PrintToChat(bClient, "Perfect Reload!");
            if (ARFailSound[bClient] && TF2_GetPlayerClass(bClient) == TFClass_Soldier)
            {
                char soundperfect[MAX_SOUND_FILE_LENGTH];
                Format(soundperfect, sizeof(soundperfect), SOUND_AR_PERFECT);
                EmitSoundToClient(bClient, soundperfect, SNDCHAN_AUTO, 80);
            }
            ARPassFail[bClient] = 2; //Set variable for switch case. ~ Spyro.
            CurReload[bClient] = FAR_FUTURE; // Reset Timer ~ Ivory
            Reloading[bClient] = false; //Reload state reset to false.
            RequestFrame(Frame_PassFail, bClient);
        }
        // We make sure the reload has been active for at least 0.5s |GetEngineTime() + 5.6| before checking for a fail ~ Ivory
        // If they do not press reload in time, or press too early, it fails ~ Ivory
        else if ((GetEngineTime()+5.6 >= CurReload[bClient] >= GetEngineTime()+5.1) || CurReload[bClient] <= GetEngineTime())
        {
            //If an active reload is executed wrong, jammed state will be set to true. 
            //Just like bonus state, no further active reloads can be attempted while this is true. ~ Spyro.
            ARJammedState[bClient] = true;
            if (DebugModeG[bClient])
            PrintToChat(bClient, "Fail."); 
            if (ARPerfectSound[bClient] && TF2_GetPlayerClass(bClient) == TFClass_Soldier)
            {
                char soundfail[MAX_SOUND_FILE_LENGTH];
                Format(soundfail, sizeof(soundfail), SOUND_AR_FAIL);
                EmitSoundToClient(bClient, soundfail, SNDCHAN_AUTO, 80);
            }
            ARPassFail[bClient] = 1; //Set variable for switch case. ~ Spyro.
            CurReload[bClient] = FAR_FUTURE; // Reset Timer ~ Ivory
            Reloading[bClient] = false; //Reload state reset to false. ~ Spyro.
            RequestFrame(Frame_PassFail, bClient);
        }
    }
    ARSpecialKeyDown[bClient] = bSpecialDown;
}

void Frame_PassFail(int iClient)
{
    JamBonus_Invoke(ARPassFail[iClient], iClient);
}

public void JamBonus_Invoke(int gPassFail, int client)
{
    if (!IsClientInGame(client))
    return;

    switch(gPassFail)
    {
        //Depending on if active reload was sucessful or not, one of these switch cases will execute. ~ Spyro.
        case 1: //Perfect reload
        {
            ARGunJam(client);
            CreateTimer(JamDuration[client], ResetJammedState, client, TIMER_FLAG_NO_MAPCHANGE); //Timers are good. Fuck that GetEngineTime bullshit.
            TF2_AddCondition(client, TFCond_MarkedForDeath, 2.0); //Mark them for death for two seconds. Use -1.0 for infinite.
            TF2Attrib_SetByName(client, "reload time increased", 1.88); //Tempoarily increase reload time.
            gPassFail = 0; //Reset switch case variable.
        }
        case 2: //Failed reload
        {
            ARFillClip(client);
            ARMiniCritBuff(client);
            TF2Attrib_SetByName(client, "damage bonus", 1.25); //Tempoarily buff damage.
            CreateTimer(BuffDuration[client], RemoveBuffs, client, TIMER_FLAG_NO_MAPCHANGE);
            gPassFail = 0; //Reset switch case variable.
        }
    }
    HUD_WEAPON_RELOADING = false;
}



public Action AR_Timer(Handle timer)
{
    if (!HUD_WEAPON_RELOADING)
    {
        return Plugin_Handled;
    }

    if (ACTIVE_RELOAD_ENABLED)
    {
        AR_HUD_Update();
    }

    return Plugin_Continue;
}

public void AR_HUD_Update()
{
    char ARindicator[128];
    int reloadTick;
    if (!HUD_WEAPON_RELOADING || !ACTIVE_RELOAD_ENABLED) //If this becomes false during this, stop everything and get out.
    {
        if (PRINT_SERVER_DEBUG_INFO)
        {
            PrintToChatAll("[Reload HUD]: Weapon is not in active reload. Or lacks it. Disabling hud."); 
        }
        AR_UpdateHudAt = FAR_FUTURE;
        reloadTick = 0;
        return;
    }
    for (int MercUser = 1; MercUser < MAX_PLAYERS; MercUser++)
    {
        if (GetClientTeam(MercUser) == BossTeam || GetClientTeam(MercUser) != MercTeam || !IsLivingPlayer(MercUser))
        {
            if (PRINT_SERVER_DEBUG_INFO)
            {
                PrintToChatAll("[Reload HUD client loop]: User is on wrong team or dead. Skipping."); 
            }
            continue;
        }


        if (!IsUsingThisCustomWeapon(MercUser, 1))
        {
            if (PRINT_SERVER_DEBUG_INFO)
            {
                PrintToChatAll("[Reload HUD client loop]: User does not have the correct weapon. Skipping."); 
            }
            continue;
        }
        if (GetClientTeam(MercUser) == MercTeam)
        {
            if (DebugModeG[MercUser])
            {
                PrintToChat(MercUser, "[Reload HUD client loop]: User valid! Setting HUD...."); 
            }
            
            reloadTick++;
            reloadTick %= 9;
            if (PRINT_SERVER_DEBUG_INFO)
            {
                PrintToChatAll("[Reload HUD]: Reload tick added."); 
            }
            
            if (reloadTick == 1)
            {
                Format(ARindicator, sizeof(ARindicator), "|o----[]----|"); //After 1 second has passed..... 
            }
            else if (reloadTick == 2)
            {
                Format(ARindicator, sizeof(ARindicator), "|-o---[]---|"); //after 2 seconds
            }
            else if (reloadTick == 3)
            {
                Format(ARindicator, sizeof(ARindicator), "|--o--[]---|"); //3 seconds
            }
            else if (reloadTick == 4)
            {
                Format(ARindicator, sizeof(ARindicator), "|---o-[]---|"); //4 seconds 
            }
            else if (reloadTick == 5)
            {
                Format(ARindicator, sizeof(ARindicator), "|----[o]---|"); //5 seconds I think this is the perfect reload
            }
            else if (reloadTick == 6)
            {
                Format(ARindicator, sizeof(ARindicator), "|---[]--o--|"); //6 seconds 
            }
            else if (reloadTick == 7)
            {
                Format(ARindicator, sizeof(ARindicator), "|---[]--o--|"); //7 seconds
            }   

            SetHudTextParams(0.71, 0.84, 1.0, 0, 60, 200, 255, 0, 0.02, 0.01, 0.02);
            ShowSyncHudText(MercUser, ActiveReloadHud, " RELOAD ACTIVE\n[%s]", ARindicator);
        }
    }
    
}

public void EmptyClipThenReload(int client, int buttons)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    //Learned this from sarysa. Makes it so you press the key and this doesn't execute 7 billion times.
    //Otherwise it would be executing every frame. And that causes spam. Yuck.

    //The purpose of this is to force the gun to reload by emptying the clip.
    //It only works with the active reload attribute so no need to worry about it breaking reloads.
    bool reloadKeyDown = (buttons & IN_RELOAD) != 0;
    if (reloadKeyDown && !ARReloadKeyDown[client] && !Reloading[client])
	{
        SetClip_Weapon(weapon, 0);
    }
    ARReloadKeyDown[client] = reloadKeyDown;
}

public void ARMiniCritBuff(int client)
{
    //Give the minicrits
    if (IsLivingPlayer(client))
    {
        if (ARBonusState[client])
        {
            if (IsWeaponSlotActive(client, 1))
            {
                TF2_AddCondition(client, TFCond_Buffed, -1.0);
            }
        }
    }
}

public void ARFillClip(int client)
{
    //Now, I couldve just done SetClip earlier, but I wanted to make sure of a few things.
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEdict(weapon) || !IsLivingPlayer(client)) //Important check.
	{
        if (PRINT_SERVER_DEBUG_INFO)
        {
            PrintToChat(client, "[vspr_activereload_Gnasher]: Error: Weapon is invalid. Or Player is dead. Clip fill failed. Try again, Spyro.");
        }
        return;
    }
	else
	{
		SetClip_Weapon(weapon, 8);
	}
}

public void ARGunJam(int client) 
{
    //This is a little bit of a doozy. It took me like, two weeks to get this shit right.
    //This works in conjunction with the "jammed state" from active reload.
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    //First, a random integer (number) is selected between 1 and whatever JamFrequency is. 
    int randomJam = GetRandomInt(1, RoundFloat(JamFrequency[client]));
    //This will be how a random time is picked. The number has 2.1 seconds added onto it.
    float randomJamCalc = view_as<float>(randomJam) + 2.1;
    if (IsLivingPlayer(client))
	{
        switch(randomJam) //Whichever random number is selected, that is the case that is executed. I need to add more cases.
        {
            //Case number is the inital time which is then has 2.1 tacked onto it and that is the time that the gun will "jam"
            case 1:
            {
                CreateTimer(randomJamCalc, GunJamTimer, weapon, TIMER_FLAG_NO_MAPCHANGE);
            }
            case 2:
            {
                CreateTimer(randomJamCalc, GunJamTimer, weapon, TIMER_FLAG_NO_MAPCHANGE);
            }
            case 3:
            {
                CreateTimer(randomJamCalc, GunJamTimer, weapon, TIMER_FLAG_NO_MAPCHANGE);
            }
            case 4:
            {
                CreateTimer(randomJamCalc, GunJamTimer, weapon, TIMER_FLAG_NO_MAPCHANGE);
            }
            case 5:
            {
                CreateTimer(randomJamCalc, GunJamTimer, weapon, TIMER_FLAG_NO_MAPCHANGE);
            }
            case 6:
            {
                CreateTimer(randomJamCalc, GunJamTimer, weapon, TIMER_FLAG_NO_MAPCHANGE);
            }
            case 7:
            {
                CreateTimer(randomJamCalc, GunJamTimer, weapon, TIMER_FLAG_NO_MAPCHANGE);
            }
        }
       
    }
    else //Natrually if the player is dead, dont execute anything.
    {
        if (DebugModeG[client])
        {
            PrintToChat(client, "[Gun jam]: Warning: Player is dead. Returning...");
        }
        return;
    }
}


public Action GunJamTimer(Handle hTimer, any weapon)
{
    if (IsValidEdict(weapon))
	{
        //When the gun "jams", its ammo is removed, and the player has to reload with a slower reload speed.
		SetClip_Weapon(weapon, 0); 
        if (PRINT_SERVER_DEBUG_INFO)
        {
            PrintToChatAll("[Gun jam]: Weapon jammed!");
        }
	}
    else //Do nothing if the gun is somehow invalid.
    {
        if (PRINT_SERVER_DEBUG_INFO)
        {
            PrintToChatAll("[Gun jam]: Weapon invalid! FUCKING DAMMIT!!!");
        }
        return Plugin_Continue;
    }
	return Plugin_Continue;
}


public Action ResetJammedState(Handle hTimer, any client)
{
    if (!IsLivingPlayer(client) || !ARJammedState[client]) //Just in case it somehow got set to false. Also if the player dies.
    if (DebugModeG[client])
    {
        PrintToChat(client, "[Active Reload]: Player dead or jammed state already false somehow. Jammed state will not reset.");
        return Plugin_Continue;
    }

    if (IsLivingPlayer(client) && ARJammedState[client])
    {
        //Reset jammed state to false so active reload can be executed again.
        ARJammedState[client] = false;
        //Remove the decreased reload speed.
        TF2Attrib_RemoveByName(client, "reload time increased");
        if (DebugModeG[client])
        {
            PrintToChat(client, "[Gun jam]: Jammed state reset to false and reload debuff removed.");
        }
    }
    return Plugin_Continue;
}

public Action RemoveBuffs(Handle hTimer, any client)
{
    if (!IsLivingPlayer(client) || !ARBonusState[client]) //Just in case it somehow got set to false. Also if the player dies.
    return Plugin_Continue;

	if (IsLivingPlayer(client))
	{
        //Remove all buffs set by the perfect reload.
        TF2Attrib_RemoveByName(client, "damage bonus");
		if (TF2_IsPlayerInCondition(client, TFCond_Buffed))
        {
            TF2_RemoveCondition(client, TFCond_Buffed);
        }
        if (DebugModeG[client])
        {
            PrintToChat(client, "Active reload buffs removed");
        }
        //Reset bonus state to false so active reload can be attempted again.
        ARBonusState[client] = false;
	}
	return Plugin_Continue;
}

/*
public void InitGibVoice(int client)
{
    Do this gib yell shit later.

}
*/

// Attribute processing
public Action CW3_OnAddAttribute(slot, client, const String:attrib[], const String:plugin[], const String:value[], bool:whileActive)
{
    /*
	if (!StrEqual(plugin, "vsprattribs")) 
    return Plugin_Continue;
    */

  Action action;
  if (StrEqual(attrib, "Enable debug mode"))
  {
    DebugModeG[client] = true;
    if (DebugModeG[client])
    {
        PrintToChat(client, "Debug mode enabled. Check chat while using weapon");
    }
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "Has Active Reload Gnasher"))
  {
    HasActiveReload[client] = true;
    ACTIVE_RELOAD_ENABLED = true;
    HUD_WEAPON_RELOADING = false;
    Reloading[client] = false;
    InitActiveReload(client);
    if (DebugModeG[client])
    {
        PrintToChat(client, "Active Reload enabled.");
    }
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "soldier reload failed voice"))
  {
    ARFailSound[client] = true;
    if (DebugModeG[client])
    {
        PrintToChat(client, "Soldier fail voice line enabled");
    }
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "soldier reload perfect voice"))
  {
    ARPerfectSound[client] = true;
    if (DebugModeG[client])
    {
        PrintToChat(client, "Soldier perfect voice line enabled");
    }
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "Enable gib on kill yell"))
  {
    GibOnKillSound[client] = true;
    //HookEvent("player_death", OnGibKill, EventHookMode_Post);
    action = Plugin_Handled;
  }
  
  /*
  if (StrEqual(attrib, "Active Reload time decay"))
  {
    ActiveReloadDecay[client] = StringToFloat(value);
    action = Plugin_Handled;
  }
  */
  return action;
}



// Variable resets
public void CW3_OnWeaponRemoved(int slot, int client)
{
    DebugModeG[client] = false;
    HasActiveReload[client] = false;
    Reloading[client] = false;
    ARReloadKeyDown[client] = false;
    UnHookReloadGnasher(client);
    TF2Attrib_RemoveByName(client, "reload time increased");
    //UnhookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
    ARPerfectSound[client] = false;
    ARFailSound[client] = false;
    GibOnKillSound[client] = false;
   //ActiveReloadDefaultTime[client] = 0.0;
    //ActiveReloadDecay[client] = 0.0;
}


stock void SetClip_Weapon(int weapon, int newClip)
{
	int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
	SetEntData(weapon, iAmmoTable, newClip, 4, true);
}

stock void SetViewmodelAnimation(int client, int sequence)
{
    int ent = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
    if (!IsValidEdict(ent)) return;
    SetEntProp(ent, Prop_Send, "m_nSequence", sequence);
} 

stock bool IsLivingPlayer(int client)
{
	if (client <= 0 || client >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(client) && IsPlayerAlive(client);
}

stock int GetWeaponSlot(int client, int weapon)
{
	if(client <= 0 || client > MaxClients) return -1;

	for(new i = 0; i < SLOTS_MAX; i++)
	{
		if(weapon == GetPlayerWeaponSlot(client, i))
		{
			return i;
		}
	}
	return -1;
}

stock bool IsWeaponSlotActive(int iClient, int iSlot)
{
    return GetPlayerWeaponSlot(iClient, iSlot) == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

stock int GetIndexOfWeaponSlot(int iClient, int iSlot)
{
    return GetWeaponIndex(GetPlayerWeaponSlot(iClient, iSlot));
}

stock bool IsUsingThisCustomWeapon(int client, int slot)
{
    char weaponname[64];
    CW3_GetClientWeaponName(client, slot, weaponname, 64);
    if (StrEqual(weaponname, "The Gnasher (Scout)") || StrEqual(weaponname, "The Gnasher (Soldier)"))
    {
        return true;
    }
    else
    {
        return false;
    }
}