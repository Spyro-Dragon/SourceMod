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
#define SLOTS_MAX  7
#define FAR_FUTURE 100000000.0
#define MAX_SOUND_FILE_LENGTH 128
#define MAX_MODEL_FILE_LENGTH 128


public Plugin:myinfo = {
    name = "VSPR Attributes:Active Reload",
    author = "Original:IvoryPal This plugin: Spyro. Just Spyro.",
    description = "The active reload system for gears of war weapons.",
    version = PLUGIN_VERSION,
    url = ""
};

#define SOUND_DMG_SLASH "weapons/cleaver_hit_03.wav"
#define SOUND_SLASH_YELL "sound/vspr/marcus/retroslashyell.mp3"
#define SOUND_CHARGE_YELL "sound/vspr/marcus/retroyell.mp3"
#define SOUND_AR_FAIL "sound/vspr/marcus/dammit.mp3"
#define SOUND_AR_PERFECT "sound/vspr/marcus/noice.mp3"

new bool:PRINT_SERVER_DEBUG_INFO = true; //Use if you cant use the actual attribute

new MercTeam = _:TFTeam_Red;
//new BossTeam = _:TFTeam_Blue;

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

//For debugging
bool DebugModeL[MAX_PLAYERS_ARRAY];

//Internal attributes. (Not set by cw3 but work with cw3 attributes to make the weapon function)

//Active reload internals
bool hooked[MAX_PLAYERS_ARRAY];
bool Reloading[MAX_PLAYERS_ARRAY];
bool ARReloadKeyDown[MAX_PLAYERS_ARRAY];
bool ARBonusState[MAX_PLAYERS_ARRAY];
bool ARJammedState[MAX_PLAYERS_ARRAY];
float CurReload[MAX_PLAYERS_ARRAY];

//Retro Charge internals
bool RetroChargeActive[MAX_PLAYERS_ARRAY];
int RetroChargeActionKey[MAX_PLAYERS_ARRAY];
bool RCActionKeyDown[MAX_PLAYERS_ARRAY];
//These are internal until further notice.
float BuffDuration[MAX_PLAYERS_ARRAY];
float JamFrequency[MAX_PLAYERS_ARRAY];
float JamDuration[MAX_PLAYERS_ARRAY];

bool RCIsReady[MAX_PLAYERS_ARRAY];
bool RCIsMovespeedCond[MAX_PLAYERS_ARRAY];

bool EnableClassicBladeAltFire[MAX_PLAYERS_ARRAY];
bool RCCanSlash[MAX_PLAYERS_ARRAY];



// Attribute values set by cw3

//Active reload attributes
bool HasActiveReload[MAX_PLAYERS_ARRAY];
bool ARFailSound[MAX_PLAYERS_ARRAY]; 
bool ARPerfectSound[MAX_PLAYERS_ARRAY];
//float ActiveReloadDecay[MAX_PLAYERS_ARRAY]; SoonTM

//Retro charge attributes
bool RetroChargeEnabled[MAX_PLAYERS_ARRAY];

int RetroChargeMode[MAX_PLAYERS_ARRAY];
int RetroChargeActionKeyIndex[MAX_PLAYERS_ARRAY];

float RCSpeedBuffDuration[MAX_PLAYERS_ARRAY];
float RCCooldown[MAX_PLAYERS_ARRAY];

bool RCYellEnabled[MAX_PLAYERS_ARRAY];
float RCImpactDamage[MAX_PLAYERS_ARRAY];
float RCSlashInterval[MAX_PLAYERS_ARRAY];

bool EnableBladeBleed[MAX_PLAYERS_ARRAY];
float BladeBleedDuration[MAX_PLAYERS_ARRAY];


// Plugin start

public void OnPluginStart()
{
	RegAdminCmd("sm_reloadhook_lancer", CMDHookReload, ADMFLAG_KICK);
}

public void OnMapStart()
{
    PrecacheSound(SOUND_DMG_SLASH, true);
    PrecacheSound(SOUND_SLASH_YELL, true);
    PrecacheSound(SOUND_CHARGE_YELL, true);
    PrecacheSound(SOUND_AR_FAIL, true);
    PrecacheSound(SOUND_AR_PERFECT, true);
    
}

public Action CMDHookReload(int client, int args)
{
	hooked[client] = !hooked[client];
	HookReloadLancer(client);
}

public void PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client))
    {
		if (hooked[client])
		HookReloadLancer(client);
    }
}


public void HookReloadLancer(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEdict(weapon))
	{
		SDKHook(weapon, SDKHook_Reload, WeaponReload);
		//TF2Attrib_SetByName(weapon, "reload time increased", 5.0);
	}
    if (DebugModeL[client])
	PrintToChat(client, "hooked weapon reload");
}

public void UnHookReloadLancer(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEdict(weapon) || !IsLivingPlayer(client))
	{
		SDKUnhook(weapon, SDKHook_Reload, WeaponReload);
	}
    if (DebugModeL[client])
	PrintToChat(client, "unhooked weapon reload");
}

public void InitActiveReload(int client)
{
    if (IsLivingPlayer(client))
    {
        //ClientCommand(client, "hud_fastswitch 1");
        ARReloadKeyDown[client] = false;
        BuffDuration[client] = 8.7;
        JamFrequency[client] = 7.0;
        JamDuration[client] = 12.5;
        PrintToChat(client, "Active Reload initalized. Attributes that wouldnt work are now hopefully set.");
        ClientCommand(client, "slot2");
        CreateTimer(1.46, HookReloadDelay, client, TIMER_FLAG_NO_MAPCHANGE);
    }
    else if (!IsLivingPlayer(client) || !HasActiveReload[client])
    UnHookReloadLancer(client);
}

public Action HookReloadDelay(Handle:hTimer, any:client)
{
	if (IsValidEntity(client))
	{
		HookReloadLancer(client);
	}
	
	return Plugin_Continue;
}

public Action WeaponReload(int weapon)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    //CreateTimer(6.25, SetClipToMaxDelay, weapon, TIMER_FLAG_NO_MAPCHANGE);
    if (ARBonusState[owner] || ARJammedState[owner]) //If bonuses or gun jam is active, Return.
    {
        if (DebugModeL[owner])
        {
            PrintToChat(owner, "[Active Reload]: Weapon is jammed or in bonus state. WeaponReload action will not fully fire.");
        }
        return Plugin_Continue;
    }

    if (Reloading[owner]) //Check if owner is already reloading. If they are, return.
    {
        if (DebugModeL[owner])
        {
            PrintToChat(owner, "Error: Already reloading. WeaponReload action will not fully fire.");
        }
        return Plugin_Continue;
    }
    else if (!Reloading[owner]) 
    {
        CurReload[owner] = GetEngineTime()+3.0;
        Reloading[owner] = true;
        CreateTimer(6.88, WeaponReloadTimer, owner, TIMER_FLAG_NO_MAPCHANGE);
        if (DebugModeL[owner])
        {
            PrintToChat(owner, "Reloading. Active Reload ready to execute.");
        }
        return Plugin_Continue;
    }
    if (DebugModeL[owner])
    {
        PrintToChat(owner, "Reloading action fired but Active Reload will not execute.");
    }
    return Plugin_Continue;
}

public Action WeaponReloadTimer(Handle hTimer, any owner)
{
    if (!Reloading[owner])
    {
        if (DebugModeL[owner])
        {
            PrintToChat(owner, "[Reload Timer]: Weapon reload state is already false. Reload timer returning.");
        }
        return Plugin_Continue;
    }

	if (IsLivingPlayer(owner) && Reloading[owner])
	{
        if (DebugModeL[owner])
        {
            PrintToChat(owner, "[Reload Timer]: Weapon reload state now set to false. Reload on weapon has completed.");
        }
		Reloading[owner] = false;
	}
	return Plugin_Continue;
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    int ARPassFail = 0;
	if (IsValidClient(client))
    {
        if (RetroChargeEnabled[client])
        {
            if (RCIsMovespeedCond[client])
            {
                RCMoveSpeedTick(client, RCSpeedBuffDuration[client], RCCooldown[client], buttons);
            }
        }
        if (HasActiveReload[client])
        {
            EmptyClipThenReload(client, buttons);
        }
        // Active reload will be delayed by 0.5s to prevent the reload key from being held down too long initially... Could possibly work? ~ Ivory.
        //This section is mainly Ivory Pal's doing. And what a pal he is for helping me solve this. And going the extra mile to explain it. ~ Spyro. Just Spyro.
        //I will explain the tidbits I added to enchance his work.
		if (Reloading[client] && HasActiveReload[client] && buttons & IN_ATTACK3)
        {
            // GetEngineTime()+9.0 creates a 1.0s delay from GetEngineTime()+10.0 | 10.0 - 9.0 = 1.0 delay ~ Ivory
            if (GetEngineTime()+2.9 >= CurReload[client] >= GetEngineTime()) // 1s delay before a reload can be considered perfect ~ Ivory
            {
                //If an active reload is executed right, bonus state will be set to true. 
                //During bonus state, no further active reloads can be attempted. ~ Spyro.
                ARBonusState[client] = true; 
                if (DebugModeL[client])
                PrintToChat(client, "Perfect Reload!");
                if (ARFailSound[client] && TF2_GetPlayerClass(client) == TFClass_Soldier)
                {
                    char soundperfect[MAX_SOUND_FILE_LENGTH];
                    Format(soundperfect, sizeof(soundperfect), SOUND_AR_PERFECT);
                    EmitSoundToClient(client, soundperfect, SNDCHAN_AUTO, 128);
                }
                ARPassFail = 2; //Set variable for switch case. ~ Spyro.
                CurReload[client] = FAR_FUTURE; // Reset Timer ~ Ivory
                Reloading[client] = false; //Reload state reset to false.
            }
            // We make sure the reload has been active for at least 0.5s |GetEngineTime() + 9.5| before checking for a fail ~ Ivory
            else if ((GetEngineTime()+2.5 >= CurReload[client] >= GetEngineTime()+2.1) || CurReload[client] <= GetEngineTime())
            {
                //If an active reload is executed wrong, jammed state will be set to true. 
                //Just like bonus state, no further active reloads can be attempted while this is true. ~ Spyro.
                ARJammedState[client] = true;
                if (DebugModeL[client])
                PrintToChat(client, "Fail."); // If they do not press reload in time, or press too early, it fails ~ Ivory
                if (ARPerfectSound[client] && TF2_GetPlayerClass(client) == TFClass_Soldier)
                {
                    char soundfail[MAX_SOUND_FILE_LENGTH];
                    Format(soundfail, sizeof(soundfail), SOUND_AR_FAIL);
                    EmitSoundToClient(client, soundfail, SNDCHAN_AUTO, 128);
                }
                ARPassFail = 1; //Set variable for switch case. ~ Spyro.
                CurReload[client] = FAR_FUTURE; // Reset Timer ~ Ivory
                Reloading[client] = false; //Reload state reset to false. ~ Spyro.
            }
        }
        switch(ARPassFail)
        {
            //Depending on if active reload was sucessful or not, one of these switch cases will execute.
            case 1: //Perfect reload
            {
                ARGunJam(client);
                CreateTimer(JamDuration[client], ResetJammedState, client, TIMER_FLAG_NO_MAPCHANGE); //Timers are good. Fuck that GetEngineTime bullshit.
                TF2_AddCondition(client, TFCond_MarkedForDeath, 2.0); //Mark them for death for two seconds. Use -1.0 for infinite.
                TF2Attrib_SetByName(client, "reload time increased", 1.88); //Tempoarily increase reload time.
                ARPassFail = 0; //Reset switch case variable.
            }
            case 2: //Failed reload
            {
                ARFillClip(client);
                AddBuffRemoveHealing(client);
                TF2Attrib_SetByName(client, "damage bonus", 1.25); //Tempoarily buff damage.
                CreateTimer(BuffDuration[client], RemoveBuffs, client, TIMER_FLAG_NO_MAPCHANGE);
                ARPassFail = 0; //Reset switch case variable.
            }
        }
	}
	return Plugin_Continue;
}

public void EmptyClipThenReload(int client, int buttons)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    //Learned this from sarysa. Makes it so you have to press and release the key for it to work.
    //Otherwise it would be executing every frame. And that causes spam. Yuck.

    //The purpose of this is to force the gun to reload by emptying the clip.
    //It only works with the active reload attribute so no need to worry about it breaking reloads.
    new bool:reloadKeyDown = (buttons & IN_RELOAD) != 0;
    if (reloadKeyDown && !ARReloadKeyDown[client] && !Reloading[client])
	{
        SetClip_Weapon(weapon, 0);
    }
    ARReloadKeyDown[client] = reloadKeyDown;
}

public void AddBuffRemoveHealing(int client)
{
    //This is one of the few ways i found to tempoarily increase firing speed.
    //It gives the buffing effect from the Mannpower "King" powerup, but removes the healing. I only want the firerate.
    if (IsLivingPlayer(client))
    {
        TF2_AddCondition(client, TFCond_KingAura, -1.0);
        if (TF2_IsPlayerInCondition(client, TFCond_Healing))
        TF2_RemoveCondition(client, TFCond_Healing);
    }
}

public ARFillClip(int client)
{
    //Now, I couldve just done SetClip earlier, but I wanted to make sure of a few things.
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEdict(weapon) || !IsLivingPlayer(client)) //Important check.
	{
        if (PRINT_SERVER_DEBUG_INFO)
        {
            PrintToServer("[vspr_activereload_lancer]: Error: Weapon is invalid. Or Player is dead. Clip fill failed. Try again, Spyro.");
        }
        return;
    }
	else
	{
		SetClip_Weapon(weapon, 60);
	}
}

public ARGunJam(int client) 
{
    //This is a little bit of a doozy. It took me like, two weeks to get this shit right.
    //This works in conjunction with the "jammed state" from active reload.
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    //First, a random integer (number) is selected between 1 and whatever JamFrequency is. 
    int randomJam = GetRandomInt(1, RoundFloat(JamFrequency[client]));
    //This will be how a random time is picked. The number has 2.1 seconds added onto it.
    float randomJamCalc = randomJam + 2.1;
    if (IsLivingPlayer(client))
	{
        switch(randomJam) //Whichever random numer is selected, that is the case that is executed. I need to add more cases.
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
        if (DebugModeL[client])
        {
            PrintToChat(client, "[Gun jam]: Warning: Player is dead. Returning...");
        }
        return;
    }
}


public Action GunJamTimer(Handle:hTimer, any:weapon)
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


public Action ResetJammedState(Handle:hTimer, any:client)
{
    if (!IsLivingPlayer(client) || !ARJammedState[client]) //Just in case it somehow got set to false. Also if the player dies.
    if (DebugModeL[client])
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
        if (DebugModeL[client])
        {
            PrintToChat(client, "[Gun jam]: Jammed state reset to false and reload debuff removed.");
        }
    }
    return Plugin_Continue;
}

public Action RemoveBuffs(Handle:hTimer, any:client)
{
    if (!IsLivingPlayer(client) || !ARBonusState[client]) //Just in case it somehow got set to false. Also if the player dies.
    return Plugin_Continue;

	if (IsLivingPlayer(client))
	{
        //Remove all buffs set by the perfect reload.
        TF2Attrib_RemoveByName(client, "damage bonus");
		if (TF2_IsPlayerInCondition(client, TFCond_KingAura))
        TF2_RemoveCondition(client, TFCond_KingAura);
        if (DebugModeL[client])
        PrintToChat(client, "Active reload buffs removed");
        //Reset bonus state to false so active reload can be attempted again.
        ARBonusState[client] = false;
	}
	return Plugin_Continue;
}

public RC_Initialize(int client)
{
    for (new bossIdx = 1; bossIdx < MAX_PLAYERS; bossIdx++)
	{
        if (!IsLivingPlayer(bossIdx) /*|| !IsClientInGame(bossIdx)*/)
			continue;

        if (RetroChargeEnabled[client])
        {
            SDKHook(bossIdx, SDKHook_StartTouch, RC_OnStartTouch);
            if (DebugModeL[client])
            {
                PrintToChat(client, "Player_Touch hooked.");
            }
        }
        else if (!RetroChargeEnabled[client]) //Forgetting to set the damage is one thing, setting the damage negative is being cruel.
        {
            if (DebugModeL[client])
            {
                PrintToChat(client, "Error: Retro Charge is disabled. Player_Touch will not hook.");
            }
            break;
        }
    }

}

public Action RC_OnStartTouch(int client, int victim)
{
    //Obviously, do nothing if they are dead.
	if (!IsLivingPlayer(client))
		return Plugin_Continue;
	if (!IsLivingPlayer(victim) || GetClientTeam(victim) == MercTeam)
		return Plugin_Continue;


    //We dont want them to constantly deal damage every tick when touching them. So they will be damaged in intervals.
    if (RetroChargeActive[client] && RCCanSlash[client])
    {
        if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
	    {
            SDKHooks_TakeDamage(victim, client, client, 0.0, DMG_SLASH, -1);
            if (DebugModeL[client])
            {
                PrintToChat(client, "It seems the target is a coward. I mean, they're ubered. No damage dealt.");
            }
        }

        if (RCYellEnabled[client] && TF2_GetPlayerClass(client) == TFClass_Soldier)
        {
            char sounddmgyell[MAX_SOUND_FILE_LENGTH];
            Format(sounddmgyell, sizeof(sounddmgyell), SOUND_SLASH_YELL);
            EmitSoundToAll(sounddmgyell, client, SNDCHAN_AUTO, 128);
        }
        char soundslash[MAX_SOUND_FILE_LENGTH];
        Format(soundslash, sizeof(soundslash), SOUND_DMG_SLASH);
        EmitSoundToAll(soundslash, client, SNDCHAN_AUTO, 128);
        SDKHooks_TakeDamage(victim, client, client, RCImpactDamage[client], DMG_SLASH, -1);
        RCCanSlash[client] = false;
        CreateTimer(RCSlashInterval[client], SlashInterval, client, TIMER_FLAG_NO_MAPCHANGE);
        if (DebugModeL[client])
        {
            PrintToChat(client, "Target damaged for %f points of damage.", RCImpactDamage[client]);
        }
        if (EnableBladeBleed[client]) //If bleed is enabled, they will bleed.
        {
            TF2_MakeBleed(victim, client, BladeBleedDuration[client]);
            if (DebugModeL[client])
            {
                PrintToChat(client, "Target bled for %f seconds", BladeBleedDuration[client]);
            }
        }
        else if (DebugModeL[client]) 
        {
            PrintToChat (client, "Warning: Bleed not enabled. Victim will not bleed.");
        }
    }
    
    return Plugin_Continue;
}

public Action SlashInterval(Handle:hTimer, any:client)
{
	if (IsValidEntity(client) && IsLivingPlayer(client))
	{
        RCCanSlash[client] = true;
        if (DebugModeL[client]) 
        {
            PrintToChat (client, "Weapon slash ready.");
        }
	}
    else if (!IsValidEntity(client) || !IsLivingPlayer(client)) //Not valid or not alive? We're outta here.
    {
        return Plugin_Continue;
    }
	return Plugin_Continue;
}



public void RCMoveSpeedTick(int iClient, float rcduration, float rccooldown, buttons)
{
    new bool:actKeyDown = (buttons & RetroChargeActionKey[iClient]) != 0;
    //Learned this from sarysa. Makes it so you have to press and release the key for it to work.
    //Otherwise it would be executing every frame. And that causes spam. Yuck.
    if (actKeyDown && !RCActionKeyDown[iClient] && RCIsReady[iClient])
	{
        RetroChargeActive[iClient] = true;
        RCIsReady[iClient] = false;
        CreateTimer(rcduration, RCModeDuration, iClient, TIMER_FLAG_NO_MAPCHANGE);
        if (RetroChargeActive[iClient])
        {
            if (DebugModeL[iClient])
            {
                PrintToChat(iClient, "Retro Charge mode activated.");
                if (RCIsMovespeedCond[iClient])
                PrintToChat(iClient, "Move speed buff condition applied.");
            }
            if (RCIsMovespeedCond[iClient]) //If you want a set tempoary speed buff applied, this is the cheaper way to go.
            {
                if (RCYellEnabled[iClient] && TF2_GetPlayerClass(iClient) == TFClass_Soldier)
                {
                    char soundcharge[MAX_SOUND_FILE_LENGTH];
                    Format(soundcharge, sizeof(soundcharge), SOUND_CHARGE_YELL);
                   EmitSoundToAll(soundcharge, iClient, SNDCHAN_AUTO, 128);
                }
                TF2_AddCondition(iClient, TFCond_SpeedBuffAlly, -1.0);
                CreateTimer(rcduration, RemoveSpeedBuff, iClient, TIMER_FLAG_NO_MAPCHANGE);
            }
        }
	}
	RCActionKeyDown[iClient] = actKeyDown;
}

public Action RCModeDuration(Handle:hTimer, any:iClient)
{
	if (IsValidEntity(iClient) && IsLivingPlayer(iClient))
	{
        if (DebugModeL[iClient])
        {
            PrintToChat(iClient, "Time's up. Retro Charge not active.");
        }
		RetroChargeActive[iClient] = false;
        CreateTimer(RCCooldown[iClient], RCModeCooldown, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
    else if (!IsValidEntity(iClient) || !IsLivingPlayer(iClient)) //Not valid or not alive? We're outta here.
    {
        return Plugin_Continue;
    }
	return Plugin_Continue;
}

public Action RCModeCooldown(Handle:hTimer, any:iClient)
{
    if (!IsLivingPlayer(iClient)) //Not valid or not alive? We're outta here.
    return Plugin_Continue;
    
	if (IsValidEntity(iClient) && IsLivingPlayer(iClient))
	{
        RCIsReady[iClient] = true;
        if (DebugModeL[iClient])
        {
            PrintToChat(iClient, "Retro Charge mode ready.");
        }
	}
	return Plugin_Continue;
}

public Action RemoveSpeedBuff(Handle:hTimer, any:iClient)
{
	if (IsValidEntity(iClient) && IsLivingPlayer(iClient))
	{
        if (TF2_IsPlayerInCondition(iClient, TFCond_SpeedBuffAlly))
        TF2_RemoveCondition(iClient, TFCond_SpeedBuffAlly);
        if (DebugModeL[iClient])
        {
            PrintToChat(iClient, "Speed buffs removed");
        }
	}
    else if (!IsValidEntity(iClient) || !IsLivingPlayer(iClient)) //Not valid or not alive? We're outta here.
    {
        return Plugin_Continue;
    }
	return Plugin_Continue;
}


RC_GetActionKey(int iClient, int argIdx)
{
	new keyIdx = argIdx;
	if (keyIdx == 1) //Alt-Fire
    {
        if (DebugModeL[iClient])
        {
            PrintToChat(iClient, "Key index set to 1, Alt-Fire (Attack2) key is used to retro charge.");
        }
		return IN_ATTACK2;
    }
	else if (keyIdx == 2) //Action Key
    {
        if (DebugModeL[iClient])
        {
            PrintToChat(iClient, "Key index set to 2, Action key is used to retro charge.");
            PrintToChat(iClient, "WARNING: MAKE SURE NO ITEMS ARE IN ACTION SLOT!");
        }
        return IN_USE;
    }
	else if (DebugModeL[iClient])
    {
        PrintToChat(iClient, "Warning: No mode selection key specified. Defaulting to 'Alt-Fire (Attack2)'");
        return IN_ATTACK2;
    }	
	return IN_ATTACK2; // no key, implied is "call for medic"
}



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
    DebugModeL[client] = true;
    PrintToChat(client, "Debug mode enabled. Check chat while using weapon");
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "Has Active Reload Lancer"))
  {
    HasActiveReload[client] = true;
    Reloading[client] = false;
    InitActiveReload(client);
    if (DebugModeL[client])
    {
        PrintToChat(client, "Active Reload enabled.");
    }
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "soldier reload failed voice"))
  {
    ARFailSound[client] = true;
    if (DebugModeL[client])
    {
        PrintToChat(client, "Soldier fail voice line enabled");
    }
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "soldier reload perfect voice"))
  {
    ARPerfectSound[client] = true;
    if (DebugModeL[client])
    {
        PrintToChat(client, "Soldier perfect voice line enabled");
    }
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "Enable retro charge"))
  {
    RetroChargeEnabled[client] = true;
    RC_Initialize(client);
    if (DebugModeL[client])
    {
        PrintToChat(client, "Retro charge enabled");
    }
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "Set retro charge mode"))
  {
    RetroChargeMode[client] = StringToInt(value);
    switch (RetroChargeMode[client])
    {
        case 1:
        {
            if (DebugModeL[client])
            {
                PrintToChat(client, "Retro charge mode is 1. Will set movespeed via speedboost condition.");
            }
            RCIsMovespeedCond[client] = true;
            RCIsReady[client] = true;
            RCCanSlash[client] = true;
        }
        case 2:
        {
            if (DebugModeL[client])
            {
                PrintToChat(client, "Retro charge mode is 2. Get within melee range and press alt-fire to use blade.");
            }
            EnableClassicBladeAltFire[client] = true;
            RCIsReady[client] = true;
            RCCanSlash[client] = true;
        }
    }
    if (DebugModeL[client])
    {
        PrintToChat(client, "Retro charge enabled. Retro charge mode set to %d", RetroChargeMode[client]);
    }
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "Retro charge activation key"))
  {
    RetroChargeActionKeyIndex[client] = StringToInt(value);
    RetroChargeActionKey[client] = RC_GetActionKey(client, RetroChargeActionKeyIndex[client]);
    action = Plugin_Handled;
  }
  
  if (StrEqual(attrib, "Retro charge impact damage"))
  {
    RCImpactDamage[client] = StringToFloat(value);
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "Enable retro charge bleed"))
  {
    EnableBladeBleed[client] = true;
    BladeBleedDuration[client] = 0.0;
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "RC bleed duration"))
  {
    BladeBleedDuration[client] = StringToFloat(value);
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "Enable retro charge soldier yell"))
  {
    RCYellEnabled[client] = true;
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "RC speed buff duration"))
  {
    RCSpeedBuffDuration[client] = StringToFloat(value);
    action = Plugin_Handled;
  }

  if (StrEqual(attrib, "RC cooldown duration"))
  {
    RCCooldown[client] = StringToFloat(value);
    action = Plugin_Handled;
  }
  if (StrEqual(attrib, "RC slash interval"))
  {
    RCSlashInterval[client] = StringToFloat(value);
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
    DebugModeL[client] = false;
    HasActiveReload[client] = false;
    Reloading[client] = false;
    ARReloadKeyDown[client] = false;
    UnHookReloadLancer(client);
    SDKUnhook(client, SDKHook_StartTouch, RC_OnStartTouch);
    TF2Attrib_RemoveByName(client, "reload time increased");
    ARPerfectSound[client] = false;
    ARFailSound[client] = false;
    EnableClassicBladeAltFire[client] = false;
    RCIsMovespeedCond[client] = false;
    RetroChargeMode[client] = 0;
    RCSpeedBuffDuration[client] = 0.0;
    RCImpactDamage[client] = 0.0;
    RCSlashInterval[client] = 0.0;
    EnableBladeBleed[client] = false;
    BladeBleedDuration[client] = 0.0;
    RCYellEnabled[client] = false;
   //ActiveReloadDefaultTime[client] = 0.0;
    //ActiveReloadDecay[client] = 0.0;
}

stock bool:IsModelMarcus(client, const String:model_name[])
{
	static model_name = String:modelFile[MAX_MODEL_FILE_LENGTH];
	GetClientModel(client);
	if ((StrContains(model_name, "marcus_soldier.mdl") >= 0))
		return true;
	return false;
}

stock GetWeaponSlot(client, weapon)
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

stock bool:IsWeaponSlotActive(iClient, iSlot)
{
    return GetPlayerWeaponSlot(iClient, iSlot) == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

stock bool:IsLivingPlayer(client)
{
	if (client <= 0 || client >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(client) && IsPlayerAlive(client);
}


stock bool:IsPlayerInRange(player, Float:position[3], Float:maxDistance)
{
	maxDistance *= maxDistance;
	
	static Float:playerPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", playerPos);
	return GetVectorDistance(position, playerPos, true) <= maxDistance;
}

stock GetWeaponIndex(iWeapon)
{
    return IsValidEnt(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}
stock GetIndexOfWeaponSlot(iClient, iSlot)
{
    return GetWeaponIndex(GetPlayerWeaponSlot(iClient, iSlot));
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






