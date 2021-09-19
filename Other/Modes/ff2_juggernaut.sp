#pragma semicolon 1

#include <sourcemod>
#include <freak_fortress_2>
#include <freak_fortress_2_extras>
#include <freak_fortress_2_subplugin>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#include <sdktools>
#include <sdkhooks>
#include <ff2_ams>
#include <clients>
#include <cw3>
#include <dhooks>

#define ARG_LENGTH 256
 
bool PRINT_DEBUG_INFO = true;
bool PRINT_DEBUG_SPAM = false;

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_FILE_LENGTH 128
#define MAX_MATERIAL_FILE_LENGTH 128
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_EFFECT_NAME_LENGTH 48
#define MAX_ENTITY_CLASSNAME_LENGTH 48
#define MAX_CENTER_TEXT_LENGTH 128
#define MAX_HUD_TEXT_LEGNTH 256
#define MAX_RANGE_STRING_LENGTH 66
#define MAX_HULL_STRING_LENGTH 197
#define MAX_ATTACHMENT_NAME_LENGTH 48
#define HEX_OR_DEC_STRING_LENGTH 12 // max -2 billion is 11 chars + null termination
#define MAX_SPAWNS 48
#define MAX_ARENA_CONTROLPOINTS 2

#define NOPE_AVI "vo/engineer_no01.mp3" // DO NOT DELETE FROM FUTURE PACKS
#define INVALID_ENTREF 0

int MercTeam = view_as<int>(TFTeam_Red);
int BossTeam = view_as<int>(TFTeam_Blue);

bool RoundInProgress = false;
bool PluginActiveThisRound = false;
int BossClientIndex;
int BossIndex;


public Plugin myinfo=
{
	name="Freak Fortress 2 Juggernaut",
	author="Original: Spyro. Just Spyro.",
	description="I have a fuckin headache.",
	version="1.0",
};


#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)

#define MAX_PICKUPS 6
char Pickups[MAX_PICKUPS][48] =
{
    "item_ammopack_small",
    "item_ammopack_medium",
    "item_ammopack_full",
    "item_healthkit_small",
    "item_healthkit_medium",
    "item_healthkit_full"
};

bool JuggernautModeEnabled;

ConVar cvarForceJuggEnabled;
bool JuggernautModeForceEnabled = false;


#define JUG_PARAMS_STRING "juggernaut_paramaters"
#define JUG_FLAG_IGNORE_RANDOMCLASS_SUICIDES 0x0001
#define JUG_FLAG_ENABLE_MERC_SPAWNPROTECTION 0x0002
#define JUG_FLAG_MERCS_SPAWN_IN_RANDOM_LOCATIONS 0x0004
#define JUG_FLAG_MERCS_IMMUNE_TO_ENVIROMENTDAMAGE_ONSPAWN 0x0008
//internals
int FF2Jugg_ConnectedMercPlayers = 0;
int FF2Jugg_CurHaleKills[MAX_PLAYERS_ARRAY];
int FF2Jugg_CurMercDeaths[MAX_PLAYERS_ARRAY]; 
float FF2Jugg_MercRespawnsAt[MAX_PLAYERS_ARRAY];
bool FF2Jugg_MercSpawnProtectionEnabled[MAX_PLAYERS_ARRAY];
bool FF2Jugg_MercIsSpawnProtected[MAX_PLAYERS_ARRAY];
bool FF2Jugg_MercIsDamageHooked[MAX_PLAYERS_ARRAY];
TFClassType FF2Jugg_MercCurClass[MAX_PLAYERS_ARRAY];
float FF2Jugg_SpawnPos[MAX_SPAWNS][3];
//float FF2Jugg_HPPackPos[MAX_PICKUPS][3];
//float FF2Jugg_AmmoPackPos[MAX_PICKUPS][3];
//float FF2Jugg_ControlPointPos[MAX_SPAWNS][3];


//args
float FF2Jugg_HaleHPMult[MAX_PLAYERS_ARRAY] = 3.0;
float FF2Jugg_HaleRageMult[MAX_PLAYERS_ARRAY] = 0.3;
int FF2Jugg_CurHaleMaxKills[MAX_PLAYERS_ARRAY] = 75;

float FF2Jugg_MercTeamRespawnRespawnTime[MAX_PLAYERS_ARRAY] = 10.0;

bool FF2Jugg_ForceRandomMercClassOnDeath[MAX_PLAYERS_ARRAY] = true;
bool FF2Jugg_ForceRandomMercClassOnNumberDeaths[MAX_PLAYERS_ARRAY] = false;

int FF2Jugg_DeathsBeforeRandClassChange[MAX_PLAYERS_ARRAY] = 3;

int FF2Jugg_Flags[MAX_PLAYERS_ARRAY];


public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy); // for non-arena maps
	HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy); // for non-arena maps

    cvarForceJuggEnabled = CreateConVar("ff2_enable_nexthale_juggernaut", "0", "Enable Juggernaut Mode for this hale?", _, true, 0.0, true, 1.0);
	cvarForceJuggEnabled.AddChangeHook(ConVar_ForceEnableJuggernaut);

    for (int iBoss = 1; iBoss <= MAX_PLAYERS; iBoss++)
    {
        if (GetClientTeam(iBoss) != BossTeam)
        continue;

        if (FF2_HasAbility(iBoss, this_plugin_name, JUG_PARAMS_STRING))
        {
            Menu_JuggEnableOption(iBoss);   
        } 
        else
        {
            continue;
        }
    }
}

public void ConVar_ForceEnableJuggernaut(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!!StringToInt(newValue))
    {
        JuggernautModeForceEnabled = true;
    }
	else
    {
        JuggernautModeForceEnabled = false;
    }	
}

public Action Menu_JuggEnableOption(int client)
{
	Menu JuggOptionMenu = new Menu(Menu_JuggOption, MENU_ACTIONS_ALL);
	JuggOptionMenu.SetTitle("Hale has juggernaut mode. Enable Juggernaut Mode for this round?");
	JuggOptionMenu.AddItem("yes", "Yes");
	JuggOptionMenu.AddItem("no", "No");
	JuggOptionMenu.Display(client, 60);
	return Plugin_Handled;
}

public int Menu_JuggOption(Menu menu, MenuAction action, int client, int param1)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param1, info, sizeof(info));
			if (StrEqual(info, "yes"))
            {
                JuggernautModeForceEnabled = true;
            }
			if(StrEqual(info, "no"))
			{
			    JuggernautModeForceEnabled = false;
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}


//According to Ivory Pal, this should prevent arena fron ending when all mercs are dead
bool g_ShouldEndRound;
int g_SetWinningTeamOffset;
int g_SetWinningTeamHook;
Handle hWinning;
public void OnMapStart()
{
    g_ShouldEndRound = true;
    GameData data = new GameData("tf2-roundend.games");
    if (!data)
    { 
        if (PRINT_DEBUG_INFO)
        {
            PrintToConsoleAll("[Mapstart] tf2-roundend.games GameData not found. Plugin setting to fail state.");
        }
        SetFailState("Could not find Gamedata 'tf2-roundend.games', cannot continue!");   
    }
    g_SetWinningTeamOffset = data.GetOffset("SetWinningTeam");
    hWinning = DHookCreate(g_SetWinningTeamOffset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, Defuse_SetWinningTeam);
	LogMessage("SetWinningTeam successfully hooked");
    DHookAddParam(hWinning, HookParamType_Int);
    DHookAddParam(hWinning, HookParamType_Int);
    DHookAddParam(hWinning, HookParamType_Bool);
    DHookAddParam(hWinning, HookParamType_Bool);
    DHookAddParam(hWinning, HookParamType_Bool);
    DHookAddParam(hWinning, HookParamType_Bool);
	g_SetWinningTeamHook = DHookGamerules(hWinning, false, Defuse_UnloadSetWinningTeam);
    delete data;
}

public MRESReturn Defuse_SetWinningTeam(Handle hParams)
{
    if (!g_ShouldEndRound)
    {
        return MRES_Supercede;
    }

    return MRES_Ignored;
}

public Defuse_UnloadSetWinningTeam(hookid)
{
}

public Action Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
    //global inits
    RoundInProgress = true;
	PluginActiveThisRound = false;
    JuggernautModeEnabled = false;

    if (JuggernautModeEnabled)
    {
        PluginActiveThisRound = true;
    }

    for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		if (!IsValidClient(clientIdx) || GetClientTeam(clientIdx) != BossTeam) 
		{
			if (PRINT_DEBUG_SPAM)
			{
				if (GetClientTeam(clientIdx) != BossTeam)
				{
					PrintToChatAll("[OnRoundStart]: ERROR: client is on wrong team!");
					continue;
				}

				if (!IsValidClient(clientIdx))
				{
					PrintToChatAll("[OnRoundStart]: ERROR: client is invalid!!!");
					continue;
				}
			}
			continue;
        }

        //client inits
        FF2Jugg_CurHaleKills[clientIdx] = 0;
        FF2Jugg_CurMercDeaths[clientIdx] = 0; 
        FF2Jugg_MercRespawnsAt[clientIdx] = FAR_FUTURE;
        FF2Jugg_MercSpawnProtectionEnabled[clientIdx] = false;
        FF2Jugg_MercIsSpawnProtected[clientIdx] = false;
        FF2Jugg_MercCurClass[clientIdx] = TFClass_Unknown;

        int bossIdx = FF2_GetBossIndex(clientIdx);
        if (FF2_GetBossIndex(clientIdx) < 0) 
        {
            BossClientIndex = -1;
            BossIndex = -1;
            if (PRINT_DEBUG_SPAM)
            {
                PrintToChatAll("[OnRoundStart]: ERROR: boss index is invalid!");
            }
            continue;
        }
        else if (FF2_GetBossIndex(clientIdx) > 0)
        {
            BossClientIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
            BossIndex = bossIdx;
        }

        if (FF2_HasAbility(bossIdx, this_plugin_name, JUG_PARAMS_STRING))
        {
            PluginActiveThisRound = true;
            g_ShouldEndRound = false;
            BossClientIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

            if (JuggernautModeForceEnabled)
            {
                JuggernautModeEnabled = true;
            }
            else
            {
                JuggernautModeEnabled = FF2_GetAbilityArgument(bossIdx, this_plugin_name, JUG_PARAMS_STRING, 1) == 1;
            }

            FF2Jugg_HaleHPMult[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, JUG_PARAMS_STRING, 2);
            FF2Jugg_HaleRageMult[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, JUG_PARAMS_STRING, 3);
            FF2Jugg_CurHaleMaxKills[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, JUG_PARAMS_STRING, 4);

            FF2Jugg_MercTeamRespawnRespawnTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, JUG_PARAMS_STRING, 5);

            FF2Jugg_ForceRandomMercClassOnDeath[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, JUG_PARAMS_STRING, 6) == 1;
            FF2Jugg_ForceRandomMercClassOnNumberDeaths[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, JUG_PARAMS_STRING, 7) == 1;

            FF2Jugg_DeathsBeforeRandClassChange[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, JUG_PARAMS_STRING, 8);

            FF2Jugg_Flags[clientIdx] = ReadHexOrDecString(bossIdx, JUG_PARAMS_STRING, 9);

            MultiplyHaleHealth(BossIndex);
            DecreaseHaleRageCost(BossIndex);
        }
    }

    CreateTimer(0.3, Timer_PostRoundInits, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

    


public Action Timer_PostRoundInits(Handle timer)
{
	// hale suicided
	if (!RoundInProgress)
	return Plugin_Handled;

    float bRespawnTime = FF2Jugg_MercTeamRespawnRespawnTime[BossClientIndex];
    int bMaxKills = FF2Jugg_CurHaleMaxKills[BossClientIndex];
	if (JuggernautModeEnabled)
	{
        SetDefaultRespawnTime(bRespawnTime);
        if (PRINT_DEBUG_INFO)
        {
            PrintToConsoleAll("[JuggPostInits]: Hale needs %d kills to win.", bMaxKills);
        }
        if (FF2Jugg_Flags[BossClientIndex] & JUG_FLAG_ENABLE_MERC_SPAWNPROTECTION)
        {
            FF2Jugg_MercSpawnProtectionEnabled[BossClientIndex] = true;
        }
        HookEvent("player_death", JuggMode_OnMercDeath, EventHookMode_Pre);

        if (FF2Jugg_Flags[BossClientIndex] & JUG_FLAG_MERCS_IMMUNE_TO_ENVIROMENTDAMAGE_ONSPAWN)
        {
            if (PRINT_DEBUG_INFO)
            {
                PrintToConsoleAll("[JuggPostInits]: Enviroment immunity flag active, hooking mercs for taking damage.");
            }
            for (int hMerc = 1; hMerc <= MAX_PLAYERS; hMerc++)
            {
                if (!IsValidClient(hMerc))
                {
                    continue;
                }

                if (GetClientTeam(hMerc) != MercTeam)
                {
                    continue;
                }

                if (FF2Jugg_MercIsDamageHooked[hMerc])
                {
                    continue;
                }

                SDKHook(hMerc, SDKHook_OnTakeDamage, JUG_OnTakeDamage);
                FF2Jugg_MercIsDamageHooked[hMerc] = true;
            }
        }
	}
    else
    {
        g_ShouldEndRound = true;
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[JuggPostInits]: Juggernaut mode is not enabled. Stopping Plugin from continuing.");
        }
        return Plugin_Stop;
    }

	return Plugin_Handled;
}


public Action Event_RoundEnd(Event eEvent, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;

    if (JuggernautModeEnabled)
    {
        JuggernautModeEnabled = false;
        g_ShouldEndRound = true;
        UnhookEvent("player_death", JuggMode_OnMercDeath, EventHookMode_Pre);
        if (FF2Jugg_Flags[BossClientIndex] & JUG_FLAG_MERCS_IMMUNE_TO_ENVIROMENTDAMAGE_ONSPAWN)
        {
            if (PRINT_DEBUG_INFO)
            {
                PrintToConsoleAll("[PostInits]:Enviroment immunity flag active, unhooking mercs for taking damage.");
            }
            for (int hMerc = 1; hMerc <= MAX_PLAYERS; hMerc++)
            {
                if (!IsValidClient(hMerc))
                {
                    continue;
                }

                if (GetClientTeam(hMerc) != MercTeam)
                {
                    continue;
                }

                if (!FF2Jugg_MercIsDamageHooked[hMerc])
                {
                    continue;
                }

                SDKUnhook(hMerc, SDKHook_OnTakeDamage, JUG_OnTakeDamage);
                FF2Jugg_MercIsDamageHooked[hMerc] = false;
            }
        }
    }

    if (JuggernautModeForceEnabled)
    {
        JuggernautModeForceEnabled = false;
    }
    
    PluginActiveThisRound = false;

    return Plugin_Continue;
}


public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, int status) 
{
    if (strcmp(plugin_name, this_plugin_name) == 0)
    {
        return Plugin_Continue;
        //Nothing to do since no rages here. This funtion is here so errors dont pop up
    }	

    return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
    if (JuggernautModeEnabled && RoundInProgress)
    {
        CreateTimer(10.0, Timer_RespawnMerc, client, TIMER_FLAG_NO_MAPCHANGE);
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[ClientConnect] Merc has connected during juggernaut round. Respawning him in 10 seconds.");
        }
    }

    for (int iClient = 1; iClient <= MAX_PLAYERS; iClient++)
  	{
		if (!IsClientInGame(iClient) || !IsValidClient(iClient))
        {
           continue; 
        } 

        if (GetClientTeam(iClient) != MercTeam)
        {
            continue;
        }

        FF2Jugg_ConnectedMercPlayers++;
  	}
}

public void OnClientDisconnect(int client)
{
    if (IsValidBoss(client) && JuggernautModeEnabled)
    {
        g_ShouldEndRound = true;
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[ClientDisconnect] Hale has disconnected, ending round.");
        }
        CreateTimer(0.3, Timer_EndRound_MercsWin, _, TIMER_FLAG_NO_MAPCHANGE);   
    }
    else if (GetClientTeam(client) == MercTeam)
    {
        FF2Jugg_ConnectedMercPlayers--;
        if (FF2Jugg_ConnectedMercPlayers <= 0)
        {
            FF2Jugg_ConnectedMercPlayers = 0;
            g_ShouldEndRound = true;
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("[ClientDisconnect] All mercs have disconnected. Ending round.");
            }
            CreateTimer(0.3, Timer_EndRound_HaleWin, _, TIMER_FLAG_NO_MAPCHANGE);  
        }
    }
}

public void MultiplyHaleHealth(int bossIdx)
{
    if (!JuggernautModeEnabled)
    return;

    int originalHaleHP = FF2_GetBossMaxHealth(bossIdx);
    float hpMult = FF2Jugg_HaleHPMult[BossClientIndex];
    int newHP = RoundToCeil(originalHaleHP *= hpMult);

    FF2_SetBossMaxHealth(bossIdx, newHP);
    FF2_SetBossHealth(bossIdx, newHP);
    if (PRINT_DEBUG_INFO)
    {
        PrintToChatAll("[MultHaleHP]: Hale health multiplied");
    }
    
}

public void DecreaseHaleRageCost(int bossIdx)
{
    if (!JuggernautModeEnabled)
    return;

    int originalHaleRageCost = FF2_GetBossRageDamage(bossIdx);
    float rageCostMult = FF2Jugg_HaleRageMult[BossClientIndex];
    int newRageCost = RoundToFloor(originalHaleRageCost *= rageCostMult);

    FF2_SetBossRageDamage(bossIdx, newRageCost);
    if (PRINT_DEBUG_INFO)
    {
        PrintToChatAll("[MultDecreaseRagecost]: Hale rage set to fraction.");
    }
}

public void SetDefaultRespawnTime(float rTime)
{
    if (!JuggernautModeEnabled)
    return;

    SetMercRespawnTime(rTime);
}

public void SetMercRespawnTime(float tValue)
{
    if (!JuggernautModeEnabled)
    return;

    float respawnTime = FF2Jugg_MercTeamRespawnRespawnTime[BossClientIndex];
    FF2Jugg_MercRespawnsAt[BossClientIndex] = respawnTime;
    if (PRINT_DEBUG_INFO)
    {
        PrintToConsoleAll("[PostInits]: Juggernaut mode confirmed enabled.");
        PrintToConsoleAll("[PostInits]: Setting merc respawn time to %.1f", respawnTime);
    }
}

public Action JuggMode_OnMercDeath(Event event, const char[] eventName, bool dontBroadcast)
{
    if (!RoundInProgress || !JuggernautModeEnabled)
    return Plugin_Handled;


	int victim = GetClientOfUserId(event.GetInt("userid"));
    int killer = GetClientOfUserId(event.GetInt("attacker"));
    bool isSuicide = victim == killer || !IsLivingPlayer(killer);
    float respawnAt = FF2Jugg_MercRespawnsAt[BossClientIndex];
    bool randClassRespawn = FF2Jugg_ForceRandomMercClassOnDeath[BossClientIndex];
    bool numDeathsRandRespawn = FF2Jugg_ForceRandomMercClassOnNumberDeaths[BossClientIndex];
    bool randClassSuicidesIgnored = (FF2Jugg_Flags[BossClientIndex] & JUG_FLAG_IGNORE_RANDOMCLASS_SUICIDES) != 0;
    int deathsBeforeRandRespawn = FF2Jugg_DeathsBeforeRandClassChange[BossClientIndex];

    if (GetClientTeam(victim) == BossTeam && IsValidBoss(victim))
    { 
        g_ShouldEndRound = true;
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[OnMercDeath] Mercs have suceeded in killing the hale or the hale suicided before they attained the kills needed, ending round.");
        }
        
        CreateTimer(0.3, Timer_EndRound_MercsWin, _, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Handled;
    }

    if (GetClientTeam(victim) == MercTeam)
	{
		if (isSuicide)
        {
            if (randClassSuicidesIgnored && randClassRespawn)
            {
                FF2Jugg_MercCurClass[victim] = TF2_GetPlayerClass(victim);
                CreateTimer(respawnAt, Timer_RespawnMercSameClass, victim, TIMER_FLAG_NO_MAPCHANGE);
                if (PRINT_DEBUG_INFO)
                {
                    PrintToChatAll("[OnDeath] Merc has suicided. Disallowing random class change.");
                }
            }
            else if (randClassRespawn && !randClassSuicidesIgnored)
            {
                CreateTimer(respawnAt, Timer_RespawnMercRandomClass, victim, TIMER_FLAG_NO_MAPCHANGE);
                if (PRINT_DEBUG_INFO)
                {
                    PrintToChatAll("[OnDeath] Merc has suicided. Random class change allowed.");
                }
            }
            else 
            {
                CreateTimer(respawnAt, Timer_RespawnMerc, victim, TIMER_FLAG_NO_MAPCHANGE);
                if (PRINT_DEBUG_INFO)
                {
                    PrintToChatAll("[OnDeath] Merc has suicided. Death not added to hale counter.");
                }
            }
            
            return Plugin_Continue;
        }
        
		if ((event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) != 0)
        {
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("[OnDeath] Merc used dead ringer. Ignoring death...");
            }
            return Plugin_Continue; 
        }

        if (randClassRespawn)
        {
            CreateTimer(respawnAt, Timer_RespawnMercRandomClass, victim, TIMER_FLAG_NO_MAPCHANGE);
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("[OnDeath] Merc has died from boss or minions, respawning him as random class in %.1f seconds", respawnAt);
            }
        }
        else if (numDeathsRandRespawn)
        {
            if (FF2Jugg_CurMercDeaths[victim] == deathsBeforeRandRespawn)
            {
                if (PRINT_DEBUG_INFO)
                {
                    PrintToChatAll("[Death Counter] Merc has died %d times, resetting death counter and respawning merc as random class", deathsBeforeRandRespawn);
                }
                CreateTimer(respawnAt, Timer_RespawnMercRandomClass, victim, TIMER_FLAG_NO_MAPCHANGE);
                FF2Jugg_CurMercDeaths[victim] = 0;
            }
            else if (FF2Jugg_CurMercDeaths[victim] < deathsBeforeRandRespawn)
            {
                FF2Jugg_MercCurClass[victim] = TF2_GetPlayerClass(victim);
                if (PRINT_DEBUG_INFO)
                {
                    PrintToChatAll("[Death Counter RandRespawn] Merc has died %d times", FF2Jugg_CurMercDeaths[victim]);
                }
                CreateTimer(respawnAt, Timer_RespawnMercSameClass, victim, TIMER_FLAG_NO_MAPCHANGE);
            }
        }

		
        AddAndTrackMercKills(BossClientIndex, victim);
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[Death Counter] This is a debug test. Merc has died %d times now", FF2Jugg_CurMercDeaths[victim]);
        }
        
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[OnDeath] This is a debug test. Dead merc will respawn in %.1f seconds.", respawnAt);
        }
	}


    return Plugin_Continue;
}


public Action Timer_RespawnMerc(Handle timer, any victim)
{
    if (!RoundInProgress)
    return Plugin_Handled;

    RequestFrame(Delay_Respawn, victim);
    if (PRINT_DEBUG_INFO)
    {
        PrintToChatAll("[respawnmerc] Merc respawned.");
    }

    return Plugin_Continue;
}

public Action Timer_RespawnMercRandomClass(Handle timer, any victim)
{
    if (!RoundInProgress)
    return Plugin_Handled;

    int minClass = view_as<int>(TFClass_Scout);
    int maxClass = view_as<int>(TFClass_Engineer);

    int randClass = GetRandomInt(minClass, maxClass);

    TF2_SetPlayerClass(victim, view_as<TFClassType>(randClass), _, true);
    RequestFrame(Delay_Respawn, victim);
    if (PRINT_DEBUG_INFO)
    {
        PrintToChatAll("[respawnmerc] Merc respawned as random class %d.", randClass);
    }

    return Plugin_Continue;
}



public Action Timer_RespawnMercSameClass(Handle timer, any victim)
{
    if (!RoundInProgress)
    return Plugin_Handled;

    TF2_SetPlayerClass(victim, FF2Jugg_MercCurClass[victim], _, true);
    RequestFrame(Delay_Respawn, victim);
    if (PRINT_DEBUG_INFO)
    {
        if (FF2Jugg_ForceRandomMercClassOnNumberDeaths[BossClientIndex])
        {
            PrintToChatAll("[respawnmerc] Merc respawned. Class not changed due to random class respawn deaths not being reached.");
        }
        else
        {
            PrintToChatAll("[respawnmerc] Merc respawned as current class due to suicide."); 
        }
    }

    return Plugin_Continue;
}

void Delay_Respawn(any victim)
{
    if (!RoundInProgress)
    return;

    TF2_RespawnPlayer(victim);
    if (FF2Jugg_MercSpawnProtectionEnabled[BossClientIndex])
    {
        TF2_AddCondition(victim, TFCond_Bonked, 3.0);
        FF2Jugg_MercIsSpawnProtected[victim] = true;
        CreateTimer(3.5, Timer_RemoveSpawnProtectStatus, victim, TIMER_FLAG_NO_MAPCHANGE);
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[respawnmerc] Merc respawned and given 3 seconds of bonk");
        }
    }

    if (FF2Jugg_Flags[BossClientIndex] & JUG_FLAG_MERCS_SPAWN_IN_RANDOM_LOCATIONS)
    {
        FindSpawnPosition(victim);
    }
}

public Action Timer_RemoveSpawnProtectStatus(Handle timer, any victim)
{
    if (!RoundInProgress)
    return Plugin_Handled;

    FF2Jugg_MercIsSpawnProtected[victim] = false;
    if (PRINT_DEBUG_INFO)
    {
        PrintToChatAll("[RemoveSpawnProtect] Merc no longer considered spawn protected.");
    }

    return Plugin_Continue;
}


public void FindSpawnPosition(int iClient)
{
    if (PRINT_DEBUG_INFO)
    {
        PrintToChatAll("[TeleportMerc] Attempting to teleport Merc to random location on map...."); 
    }
    int SpawnLocationCount = 0;
    int entity;
    while ((entity = FindEntityByClassname(entity, "team_control_point")) != -1 && SpawnLocationCount < MAX_SPAWNS)
    {
        GetEntPropVector(entity, Prop_Data, "m_vecOrigin", FF2Jugg_SpawnPos[SpawnLocationCount]);
        FF2Jugg_SpawnPos[SpawnLocationCount][2] += 15.0;
        SpawnLocationCount++;
    }
    for (int iPickup = 0; iPickup < MAX_PICKUPS; iPickup++)
    {
        entity = 0;
        while ((entity = FindEntityByClassname(entity, Pickups[iPickup])) != -1 && SpawnLocationCount < MAX_SPAWNS)
        {
            GetEntPropVector(entity, Prop_Data, "m_vecOrigin", FF2Jugg_SpawnPos[SpawnLocationCount]);
            FF2Jugg_SpawnPos[SpawnLocationCount][2] += 5.0;
            SpawnLocationCount++;
        }
    }
    int RandomSpawn = GetRandomInt(0, SpawnLocationCount - 1);
    TeleportEntity(iClient, FF2Jugg_SpawnPos[RandomSpawn], NULL_VECTOR, NULL_VECTOR);

    if (PRINT_DEBUG_INFO)
    {
        PrintToChatAll("[TeleportMerc] Merc teleported to random spawn location.");  
    }
}

public Action JUG_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (IsLivingPlayer(attacker) || !IsLivingPlayer(victim))
    {
        return Plugin_Continue;
    }
	else if (!FF2Jugg_MercIsSpawnProtected[victim])
    {
        return Plugin_Continue;
    }
	
	
	TF2_RespawnPlayer(victim);
	damage = 0.0;
	damagetype |= DMG_PREVENT_PHYSICS_FORCE;
    if (PRINT_DEBUG_INFO)
    {
        PrintToChatAll("[SpawnProtect] Merc respawned due to taking enviromental damage while spawn protected.");
    }
	return Plugin_Changed;
}

public void AddAndTrackMercKills(int bossIdx, int victim)
{
    if (!JuggernautModeEnabled)
    return;

    FF2Jugg_CurHaleKills[BossClientIndex]++;
    FF2Jugg_CurMercDeaths[victim]++;
    
    int curHaleKills = FF2Jugg_CurHaleKills[BossClientIndex];
    int curMaxKills = FF2Jugg_CurHaleMaxKills[BossClientIndex];
    if (PRINT_DEBUG_INFO)
    {
        PrintToConsoleAll("[MercKillTracker] Has gotten %d kills", curHaleKills);

    }

    if (curHaleKills >= curMaxKills)
    {
        curHaleKills = curMaxKills;
        g_ShouldEndRound = true;
        if (PRINT_DEBUG_INFO)
        {
            PrintToConsoleAll("[MercKillTracker] Hale has reached the required max kills of %d, ending round.", curMaxKills);
        }
        CreateTimer(0.3, Timer_EndRound_HaleWin, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_EndRound_HaleWin(Handle timer)
{
    if (!RoundInProgress)
    return Plugin_Handled;

    ForceTeamWin(BossTeam);

    return Plugin_Continue;
}


public Action Timer_EndRound_MercsWin(Handle timer)
{
    if (!RoundInProgress)
    return Plugin_Handled;

    ForceTeamWin(MercTeam);

    return Plugin_Continue;
}


///Stocks at bottom
void ForceTeamWin(int team)
{
	int iEnt = -1;
	iEnt = FindEntityByClassname(iEnt, "game_round_win");
	if (iEnt < 1)
	{
		iEnt = CreateEntityByName("game_round_win");
		if (IsValidEntity(iEnt))
        {
            DispatchSpawn(iEnt);
        }
	}
	SetVariantInt(team);
	AcceptEntityInput(iEnt, "SetTeam");
	AcceptEntityInput(iEnt, "RoundWin");
}

stock bool IsLivingPlayer(int clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
    {
        return false;
    }
		
	return IsValidClient(clientIdx) && IsPlayerAlive(clientIdx);
}

stock bool IsValidClient(int clientIdx, bool isPlayerAlive=false)
{
	if (clientIdx <= 0 || clientIdx > MAX_PLAYERS) 
    {
        return false;
    }
    
	if(isPlayerAlive) 
    {
        return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);
    }
    
	return IsClientInGame(clientIdx);
}

stock bool IsValidBoss(int bClient)
{
	if (!IsPlayerAlive(bClient))
	return false;
		
	return IsValidClient(bClient) && FF2_GetBossIndex(bClient) >= 0;
}



stock int ReadHexOrDecInt(char hexOrDecString[HEX_OR_DEC_STRING_LENGTH])
{
	if (StrContains(hexOrDecString, "0x") == 0)
	{
		int result = 0;
		for (int iHex = 2; iHex < 10 && hexOrDecString[iHex] != 0; iHex++)
		{
			result = result<<4;
				
			if (hexOrDecString[iHex] >= '0' && hexOrDecString[iHex] <= '9')
				result += hexOrDecString[iHex] - '0';
			else if (hexOrDecString[iHex] >= 'a' && hexOrDecString[iHex] <= 'f')
				result += hexOrDecString[iHex] - 'a' + 10;
			else if (hexOrDecString[iHex] >= 'A' && hexOrDecString[iHex] <= 'F')
				result += hexOrDecString[iHex] - 'A' + 10;
		}
		
		return result;
	}
	else
		return StringToInt(hexOrDecString);
}

stock int ReadHexOrDecString(int bossIdx, const char[] ability_name, int argIdx)
{
	char hexOrDecString[HEX_OR_DEC_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argIdx, hexOrDecString, HEX_OR_DEC_STRING_LENGTH);
	return ReadHexOrDecInt(hexOrDecString);
}