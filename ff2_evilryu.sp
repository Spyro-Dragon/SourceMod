// no warranty blah blah don't sue blah blah doing this for fun blah blah...

#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <drain_over_time>
#include <drain_over_time_subplugin>
#include <tf2attributes>
#include <tf2items>
#include <ff2_dynamic_defaults>
#include <tf2>
#include <cw3>
#include <cw3-attributes>


#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

 
bool DEBUG_FORCE_RAGE = true;
#define ARG_LENGTH 256
 
bool PRINT_DEBUG_INFO = true;
bool PRINT_DEBUG_SPAM = false;

#define NOPE_AVI "vo/engineer_no01.mp3" // DO NOT DELETE FROM FUTURE PACKS
#define INVALID_ENTREF 0

// text string limits
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
#define MAX_HOMING_ARRAY 2048

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

int MercTeam = view_as<int>(TFTeam_Red);
int BossTeam = view_as<int>(TFTeam_Blue);

bool RoundInProgress = false;
bool PluginActiveThisRound = false;
int BossIndex = -1;

public Plugin myinfo = {
	name = "VSPR: Evil Ryu Raging Demon",
	author = "Spyro. Just Spyro.",
	version = "1.0",
}

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)



//Evil Ryu AbilitySelect
#define EA_STRING "evilryu_abilityselect"
#define EA_HUD_UPDATE_INTERVAL 0.6
#define EA_NUM_ABILITES 2
//Internals
bool EA_ActiveThisRound;
bool EA_SelButtonDown[MAX_PLAYERS_ARRAY];
Handle EA_SyncHud;
float EA_UpdateHudAt[MAX_PLAYERS_ARRAY];

int EA_SelButton[MAX_PLAYERS_ARRAY];
int EA_CurSelection[MAX_PLAYERS_ARRAY];
int EA_CurAbility[MAX_PLAYERS_ARRAY];

//Arguments
int EA_SelectButtonIndex[MAX_PLAYERS_ARRAY];
char EA_ButtonHUDMessage[MAX_CENTER_TEXT_LENGTH];
int EA_AbilityCount[MAX_PLAYERS_ARRAY];
bool EA_CanSelectInAir[MAX_PLAYERS_ARRAY];



//Raging Demon
#define DEFAULT_RD_DAMAGEPERHIT 13.0
#define DEFAULT_RD_MAXHITS 15
#define DEFAULT_RD_HITINTERVAL 0.4
#define DEFAULT_RD_TARGRANGE 800.0

#define DEFAULT_RD_INITSOUND "vspr/evilryu/evilryu_rd_init.mp3"
#define DEFAULT_RD_HITSOUND "vspr/evilryu/evilryu_rd_hit.mp3"

#define DEFAULT_RD_HITFLASH_EFFNAME "drg_cow_explosioncore_charged"
#define DEFAULT_RD_INIT_EFFNAME "drg_cow_explosioncore_normal_blue"




#define RD_STRING "rage_raging_demon"
//flags
#define RD_FLAG_USE_DEFAULT_VALUES 0x0001
#define RD_FLAG_INFLICTOR_DAMAGEIMMUNE 0x0002
#define RD_FLAG_INFLICTOR_DAMAGERESISTANT 0x0004
#define RD_FLAG_VICTIM_STUNNED 0x0008
#define RD_FLAG_DAMAGE_UBERED_TARGETS 0x00010


//Internals
bool RD_ActiveThisRound;
bool RD_CanUse[MAX_PLAYERS_ARRAY];
bool RD_IsActive[MAX_PLAYERS_ARRAY];

bool RD_VictimAffected[MAX_PLAYERS_ARRAY];

int RD_HitsInflicted[MAX_PLAYERS_ARRAY];
float RD_NextHitAt[MAX_PLAYERS_ARRAY];
float RD_NextHitPartiEffAt[MAX_PLAYERS_ARRAY];

//#define MAX_EFFECTS 10
int RD_HitEffect_EntRef1[MAX_PLAYERS_ARRAY];
int RD_HitEffect_EntRef2[MAX_PLAYERS_ARRAY];
int RD_HitEffect_EntRef3[MAX_PLAYERS_ARRAY];
bool RD_VictimHasFlashEffects[MAX_PLAYERS_ARRAY];
bool RD_IsAllowedToStrike[MAX_PLAYERS_ARRAY];


//Arguments
int RD_MaxHits[MAX_PLAYERS_ARRAY];

float RD_MaxRange[MAX_PLAYERS_ARRAY];
float RD_DamagePerHit[MAX_PLAYERS_ARRAY];
float RD_DamageInterval[MAX_PLAYERS_ARRAY];

char RD_HitEffectName[MAX_EFFECT_NAME_LENGTH];
char RD_InitEffectName[MAX_EFFECT_NAME_LENGTH];
char RD_InitSound[MAX_SOUND_FILE_LENGTH];
char RD_HitSound[MAX_SOUND_FILE_LENGTH];

int RD_Flags[MAX_PLAYERS_ARRAY];


//Fireball Hadouken
#define FH_ABILITYINDEX 1
#define DEFAULT_FH_PROJSPEED 1280.0
#define DEFAULT_FH_PROJDAMAGE 165.0
#define DEFAULT_FH_RAGECOST 40.0
#define DEFAULT_FH_CASTDELAY 0.55
#define DEFAULT_FH_PROJ_ENTNAME "tf_projectile_spellfireball"
#define DEFAULT_FH_PROJ_CLASSNAME "CTFProjectile_SpellFireball"
#define DEFAULT_FH_CASTSOUND "vspr/evilryu/evilryu-hadouken.mp3"

#define FH_STRING "dot_fireball_hadouken"

//flags
#define FH_FLAG_USE_DEFAULT_VALUES 0x0001
#define FH_FLAG_USER_INVULN_WHILE_CASTING 0x0002
#define FH_FLAG_USER_DAMAGE_RESISTANT_WHILE_CASTING 0x0004
#define FH_FLAG_USER_KNOCKBACKIMMUNE_WHILE_CASTING 0x0008

bool FH_ActiveThisRound;
bool FH_CanUse[MAX_PLAYERS_ARRAY];

bool FH_IsCasting[MAX_PLAYERS_ARRAY];

//Arguments
float FH_RageCost[MAX_PLAYERS_ARRAY];
float FH_ProjSpeed[MAX_PLAYERS_ARRAY];
float FH_ProjFireDelayTime[MAX_PLAYERS_ARRAY];

char FH_CastSound[MAX_SOUND_FILE_LENGTH];
char FH_ProjEntName[MAX_ENTITY_CLASSNAME_LENGTH];
char FH_ProjClassName[MAX_ENTITY_CLASSNAME_LENGTH];

int FH_Flags[MAX_PLAYERS_ARRAY];





//Metsu Hadouken
#define MH_ABILITYINDEX 2
#define DEFAULT_MH_PROJSPEED 900.0
#define DEFAULT_MH_PROJDAMAGE 65.0
#define DEFAULT_MH_RAGECOST 60.0
#define DEFAULT_MH_CASTDELAY 0.9
#define DEFAULT_MH_PROJ_ENTNAME "tf_projectile_lightningorb"
#define DEFAULT_MH_PROJ_CLASSNAME "CTFProjectile_SpellLightningOrb"
#define DEFAULT_MH_CASTSOUND1 "vspr/evilryu/evilryu-metsucharge.mp3" 
#define DEFAULT_MH_CASTSOUND2 "vspr/evilryu/evilryu-metsufire.mp3" 

#define MH_STRING "dot_metsu_hadouken"

//flags
#define MH_FLAG_USE_DEFAULT_VALUES 0x0001
#define MH_FLAG_USER_INVULN_WHILE_CASTING 0x0002
#define MH_FLAG_USER_DAMAGE_RESISTANT_WHILE_CASTING 0x0004
#define MH_FLAG_USER_KNOCKBACKIMMUNE_WHILE_CASTING 0x0008

//internals
bool MH_ActiveThisRound;
bool MH_CanUse[MAX_PLAYERS_ARRAY];

bool MH_IsCasting[MAX_PLAYERS_ARRAY];

//Arguments
float MH_RageCost[MAX_PLAYERS_ARRAY];
float MH_ProjSpeed[MAX_PLAYERS_ARRAY];
float MH_ProjFireDelayTime[MAX_PLAYERS_ARRAY];

char MH_CastSoundCharge[MAX_SOUND_FILE_LENGTH];
char MH_CastSoundFire[MAX_SOUND_FILE_LENGTH];
char MH_ProjEntName[MAX_ENTITY_CLASSNAME_LENGTH];
char MH_ProjClassName[MAX_ENTITY_CLASSNAME_LENGTH];

int MH_Flags[MAX_PLAYERS_ARRAY];




/**
 * METHODS REQUIRED BY ff2 subplugin
 */
void PrintRageWarning()
{
	PrintToConsoleAll("*********************************************************************");
	PrintToConsoleAll("*                             WARNING                               *");
	PrintToConsoleAll("*       DEBUG_FORCE_RAGE in ff2_evilryu.sp is set to true!          *");
	PrintToConsoleAll("*  The boss can use the 'rage' command and other worded commands    *");
	PrintToConsoleAll("*				to use rages in this pack!   					   *");
	PrintToConsoleAll("*  This is only for test servers. Disable this on your live server. *");
	PrintToConsoleAll("*********************************************************************");
}
 
#define CMD_FORCE_RAGE "rage"
public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy); // for non-arena maps
	HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy); // for non-arena maps
    RegisterForceTaunt();
	EA_SyncHud = CreateHudSynchronizer();
	if (DEBUG_FORCE_RAGE)
	{
		PrintRageWarning();
		RegAdminCmd(CMD_FORCE_RAGE, CmdForceRage, ADMFLAG_GENERIC);
	}
}

public void OnMapStart()
{
	PrecacheSound(DEFAULT_RD_HITSOUND, true);
	PrecacheSound(DEFAULT_RD_INITSOUND, true);
	PrecacheSound(DEFAULT_FH_CASTSOUND, true);
	PrecacheSound(DEFAULT_MH_CASTSOUND1, true);
	PrecacheSound(DEFAULT_MH_CASTSOUND2, true);
}


public Action Event_RoundStart(Handle hEvent, const char[] name, bool dontBroadcast)
{
    RoundInProgress = true;
	PluginActiveThisRound = false;
    RD_ActiveThisRound = false;
	FH_ActiveThisRound = false;
	MH_ActiveThisRound = false;
	EA_ActiveThisRound = false;

    for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
        //Ability global inits 
		EA_CurAbility[clientIdx] = 1;
		EA_CurSelection[clientIdx] = 1;
		EA_SelButtonDown[clientIdx] = false;
		EA_CanSelectInAir[clientIdx] = false;
		EA_UpdateHudAt[clientIdx] = FAR_FUTURE;

        RD_CanUse[clientIdx] = false;
        RD_IsActive[clientIdx] = false;
        RD_VictimAffected[clientIdx] = false;
		RD_VictimHasFlashEffects[clientIdx] = false;
		RD_IsAllowedToStrike[clientIdx] = false;
		RD_HitEffect_EntRef1[clientIdx] = INVALID_ENTREF;
		RD_HitEffect_EntRef2[clientIdx] = INVALID_ENTREF;
		RD_HitEffect_EntRef3[clientIdx] = INVALID_ENTREF;
        RD_HitsInflicted[clientIdx] = 0;
        RD_NextHitAt[clientIdx] = FAR_FUTURE;
        RD_NextHitPartiEffAt[clientIdx] = FAR_FUTURE;

		FH_CanUse[clientIdx] = false;
		FH_IsCasting[clientIdx] = false;

		MH_CanUse[clientIdx] = false;
		MH_IsCasting[clientIdx] = false;
		
        
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

        int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0) 
		{
			if (PRINT_DEBUG_SPAM)
			{
				PrintToChatAll("[OnRoundStart]: ERROR: boss index is invalid!");
			}
			continue;
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, EA_STRING))
		{
		    EA_ActiveThisRound = true;
			PluginActiveThisRound = true;
			BossIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

			EA_SelectButtonIndex[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, EA_STRING, 1);
			ReadCenterText(bossIdx, EA_STRING, 2, EA_ButtonHUDMessage);
			EA_CanSelectInAir[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, EA_STRING, 3) == 1;
			EA_AbilityCount[clientIdx] = EA_NUM_ABILITES;
			EA_SelButton[clientIdx] = EA_GetSelKey(EA_SelectButtonIndex[clientIdx]);
			EA_SelButtonDown[clientIdx] = (GetClientButtons(clientIdx) & EA_SelButton[clientIdx]) != 0;
		}

        if (FF2_HasAbility(bossIdx, this_plugin_name, RD_STRING))
		{
		    RD_ActiveThisRound = true;
			PluginActiveThisRound = true;
			RD_CanUse[clientIdx] = true;
			BossIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

            RD_MaxHits[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RD_STRING, 1);

            RD_MaxRange[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RD_STRING, 2);
            RD_DamagePerHit[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RD_STRING, 3);

            RD_DamageInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RD_STRING, 4);


            FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RD_STRING, 5, RD_HitEffectName, MAX_EFFECT_NAME_LENGTH);
            FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RD_STRING, 6, RD_InitEffectName, MAX_EFFECT_NAME_LENGTH);

            ReadSound(bossIdx, RD_STRING, 7, RD_InitSound);
			ReadSound(bossIdx, RD_STRING, 8, RD_HitSound);

            RD_Flags[clientIdx] = ReadHexOrDecString(bossIdx, RD_STRING, 9);
        }

		if (FF2_HasAbility(bossIdx, this_plugin_name, FH_STRING))
		{
		    FH_ActiveThisRound = true;
			PluginActiveThisRound = true;
			FH_CanUse[clientIdx] = true;
			BossIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

			FH_RageCost[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FH_STRING, 1);
			FH_ProjSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FH_STRING, 2);
			FH_ProjFireDelayTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FH_STRING, 3);

			ReadSound(bossIdx, FH_STRING, 4, FH_CastSound);
			FH_ProjEntName[clientIdx] = FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, FH_STRING, 5, FH_ProjEntName, MAX_ENTITY_CLASSNAME_LENGTH);
			FH_ProjClassName[clientIdx] = FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, FH_STRING, 6, FH_ProjEntName, MAX_ENTITY_CLASSNAME_LENGTH);

			FH_Flags[clientIdx] = ReadHexOrDecString(bossIdx, FH_STRING, 7);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, MH_STRING))
		{
		    MH_ActiveThisRound = true;
			PluginActiveThisRound = true;
			MH_CanUse[clientIdx] = true;
			BossIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

			MH_RageCost[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MH_STRING, 1);
			MH_ProjSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MH_STRING, 2);
			MH_ProjFireDelayTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MH_STRING, 3);

			ReadSound(bossIdx, MH_STRING, 4, MH_CastSoundCharge);
			ReadSound(bossIdx, MH_STRING, 5, MH_CastSoundFire);
			MH_ProjEntName[clientIdx] = FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MH_STRING, 6, MH_ProjEntName, MAX_ENTITY_CLASSNAME_LENGTH);
			MH_ProjClassName[clientIdx] = FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MH_STRING, 7, MH_ProjEntName, MAX_ENTITY_CLASSNAME_LENGTH);

			MH_Flags[clientIdx] = ReadHexOrDecString(bossIdx, MH_STRING, 8);
		}
    }	
}




public Action Event_RoundEnd(Handle eEvent, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;

	if (EA_ActiveThisRound)
	{
		EA_ActiveThisRound = false;
	}

	if (FH_ActiveThisRound)
	{
		FH_ActiveThisRound = false;
	}

	if (MH_ActiveThisRound)
	{
		MH_ActiveThisRound = false;
	}

    if (RD_ActiveThisRound)
    {
        RD_ActiveThisRound = false;
    }
	
    PluginActiveThisRound = false;
    return Plugin_Continue;
}

public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, int status) //not sure what type status is?
{
	int clientBoss = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	if (strcmp(plugin_name, this_plugin_name) != 0)
	return Plugin_Continue;

	else if (!RoundInProgress || !PluginActiveThisRound) // don't execute these rages with 0 players alive
	return Plugin_Handled;

    if (RD_ActiveThisRound && RD_CanUse[clientBoss])
    {
		RagingDemon_Init(clientBoss);
    }


    return Plugin_Continue;
}

public int FF2_PreAbility(int bossIdx, const char[] pluginame, const char[] ability_name, int slot, bool &enabled)
{
}


/**
 * DOTs
 */
void DOTPostRoundStartInit()
{
	if (!RoundInProgress)
	{
		PrintToConsoleAll("DOTPostRoundStartInit() called when the round is over?! Shouldn't be possible!");
		return;
	}
	
	// nothing to do
}
 
void OnDOTAbilityActivated(int clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	
	int bossIdx = FF2_GetBossIndex(clientIdx);
	int meleeWeapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
	int clientBoss = clientIdx;
	bool defaultCostFH = (FH_Flags[clientIdx] & FH_FLAG_USE_DEFAULT_VALUES) != 0;
	bool defaultCostMH = (MH_Flags[clientIdx] & MH_FLAG_USE_DEFAULT_VALUES) != 0;
	float rageCostFH = (defaultCostFH ? DEFAULT_FH_RAGECOST : FH_RageCost[clientIdx]);
	float rageCostMH = (defaultCostMH ? DEFAULT_MH_RAGECOST : MH_RageCost[clientIdx]);
	switch (EA_CurAbility[clientBoss])
	{
		case FH_ABILITYINDEX:
		{
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("Boss current rage: %.1f", FF2_GetBossCharge(bossIdx, 0));
			}
			if (FF2_GetBossCharge(bossIdx, 0) < rageCostFH)
			{
				PrintCenterText(clientBoss, "You dont have enough rage!!! (%.1f required)", rageCostFH);
				ForceDOTAbilityDeactivation(clientIdx);
				return;
			}
			else if (FF2_GetBossCharge(bossIdx, 0) >= rageCostFH)
			{
				TF2Attrib_SetByName(meleeWeapon, "gesture speed increase", 3.50);
				Fireball_Hadouken_Init(clientBoss);
				FF2_SetBossCharge(bossIdx, 0, (FF2_GetBossCharge(bossIdx, 0) - rageCostFH));
			}
		}

		case MH_ABILITYINDEX:
		{
			if (FF2_GetBossCharge(bossIdx, 0) < rageCostMH)
			{
				PrintCenterText(clientBoss, "You dont have enough rage!!! (%.1f required)", rageCostMH);
				ForceDOTAbilityDeactivation(clientIdx);
				return;
			}
			else if (FF2_GetBossCharge(bossIdx, 0) >= rageCostMH)
			{ 
				TF2Attrib_SetByName(meleeWeapon, "gesture speed increase", 1.75);
				Metsu_Orb_Init(clientBoss);
				FF2_SetBossCharge(bossIdx, 0, (FF2_GetBossCharge(bossIdx, 0) - rageCostMH));
			}
		}		
	}
}

void OnDOTAbilityDeactivated(int clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	//suppress warning
	if (clientIdx) { }
}

void OnDOTUserDeath(int clientIdx, int isInGame)
{
	// suppress warning
	if (clientIdx || isInGame) { }
}

Action OnDOTAbilityTick(int clientIdx, int tickCount)
{	
	// suppress warning
	if (tickCount || clientIdx) { }
}

//Hello console spam my old friend....
public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, float vel[3], float vAng[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	float curTime = GetEngineTime();
	if (!PluginActiveThisRound || !RoundInProgress)
	return Plugin_Continue;

	if (EA_ActiveThisRound)
	{
		EA_UpdateHudAt[BossIndex] = curTime;
		EA_SelAbility_RunCmd(clientIdx, buttons);
	}

	return Plugin_Continue;
}

public void OnGameFrame()
{
	if (!RoundInProgress)
	return;

	float curTime = GetEngineTime();
	if (EA_ActiveThisRound)
	{
		EA_HudTick(curTime);
	}
}


public void EA_SelAbility_RunCmd(int bossIdx, int buttons)
{
	if (!RoundInProgress)
	return;

	bool isOnGround = (GetEntityFlags(bossIdx) & FL_ONGROUND) != 0;
	bool isSwimming = (GetEntityFlags(bossIdx) & FL_SWIM) != 0;
	bool selButtonDown = (buttons & EA_SelButton[bossIdx]) != 0;
	if (selButtonDown && !EA_SelButtonDown[bossIdx])
	{
		if (!isOnGround && !isSwimming && !EA_CanSelectInAir[BossIndex])
		{
			if (PRINT_DEBUG_SPAM)
			{
				PrintToConsoleAll("[EA_RunCmd] Ability selection disabled while in the air.");
			}
			return;
		}
		EA_CurSelection[bossIdx]++;
		if (EA_CurSelection[bossIdx] > EA_NUM_ABILITES)
		{
			EA_CurSelection[bossIdx] = 1;
		}
		EA_CurAbility[bossIdx] = EA_CurSelection[bossIdx];
		//EA_UpdateHudAt[BossIndex] = GetEngineTime();
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Current Selection: %d", EA_CurSelection[bossIdx]);
			PrintToChatAll("Current Ability: %d", EA_CurAbility[bossIdx]);
			PrintToChatAll("Ability Count: %d", EA_AbilityCount[BossIndex]);
		}
	}
	EA_SelButtonDown[bossIdx] = selButtonDown;
}

public void EA_HudTick(float curTime)
{
	if (!RoundInProgress)
	return;

	static char curAbilityText[MAX_HUD_TEXT_LEGNTH];
	static char switchButtonText[MAX_CENTER_TEXT_LENGTH];
	EA_UpdateHudAt[BossIndex] = curTime;	
	if (EA_UpdateHudAt[BossIndex] <= curTime)
	{
		switchButtonText = EA_ButtonHUDMessage;
		switch (EA_CurAbility[BossIndex])
		{
			case FH_ABILITYINDEX:
			{
				Format(curAbilityText, sizeof(curAbilityText), "FIRE HADOUKEN(40)");
				SetHudTextParams(-1.0, 0.77, 0.2, 255, 50, 0, 255, 0, 6.0, 0.1, 0.2); 
			}

			case MH_ABILITYINDEX:
			{
				Format(curAbilityText, sizeof(curAbilityText), "METSU HADOUKEN(60)");
				SetHudTextParams(-1.0, 0.77, 0.2, 0, 30, 120, 255, 0, 6.0, 0.1, 0.2); 
			}
		}	
		ShowSyncHudText(BossIndex, EA_SyncHud, "CURRENT ABILITY AND COST:[%s][%s]", curAbilityText, switchButtonText);
	}
}


public Action CmdForceRage(int user, int argsInt)
{
    Action iReturn = Plugin_Continue;
    if (!RoundInProgress)
    iReturn = Plugin_Handled;

	// get actual args
	char unparsedArgs[ARG_LENGTH];
	int userBoss = GetClientOfUserId(FF2_GetBossUserId(0));
	int userBossIndex = FF2_GetBossIndex(user);
	GetCmdArgString(unparsedArgs, ARG_LENGTH);
	
	// gotta do this
	PrintRageWarning();
	if (userBossIndex <= -1 || !PluginActiveThisRound)
	{
		PrintToConsole(user, "[EvilRyu] Error: You must be the boss this plugin is associated with to use this rage.");
		iReturn = Plugin_Handled;
	}


	if (!strcmp("ragingdemon", unparsedArgs))
	{
		PrintToConsole(user, "Activating Raging Demon");
		RagingDemon_Init(userBoss);
		iReturn = Plugin_Handled;
	}
	
	if (!strcmp("firehadouken", unparsedArgs))
	{
		PrintToConsole(user, "Activating Fire Hadouken");
		Fireball_Hadouken_Init(userBoss);
		iReturn = Plugin_Handled;
	}

	if (!strcmp("metsuorb", unparsedArgs))
	{
		PrintToConsole(user, "Activating Metsu Hadouken Orb");
		Metsu_Orb_Init(userBoss);
		iReturn = Plugin_Handled;
	}
	

    PrintToConsole(user, "[EvilRyu] Rage not found: %s", unparsedArgs);
    return iReturn;
}

int EA_GetSelKey(int keyIdx)
{
    if (keyIdx == 1)
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[SwitchAbilites] Alt-fire key (Attack2, default MOUSE2) used to switch between abilites.");
        }
        return IN_ATTACK2;
    }
    else if (keyIdx == 2)
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[SwitchAbilites] Special Attack key (Attack3, default MIDDLE MOUSE) used to switch between abilites.");
        }
        return IN_ATTACK3;
    }
    else if (keyIdx == 3)
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[SwitchAbilites] Use key (unknown) used to switch abilites.");
        }
        return IN_USE;
    }
    else
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[SwitchAbilites] No key specified for switching abilites. Defaulting to Special Attack key.");
        }
    }

    return IN_ATTACK3;
}


public void RagingDemon_Init(int bossIdx)
{
    if (!RoundInProgress || !RD_ActiveThisRound)
    return;

    
	bool valuesDefault = (RD_Flags[BossIndex] & RD_FLAG_USE_DEFAULT_VALUES) != 0;
    bool isHaleOnGround = (GetEntityFlags(bossIdx) & FL_ONGROUND) != 0;
	
    int primary = -1;
	char initSound[MAX_SOUND_FILE_LENGTH];
	char initParticle[MAX_EFFECT_NAME_LENGTH];
	float maxRange;
	float hitInterval;
	float bossEyePos[3];

	if (TF2_IsPlayerInCondition(bossIdx, TFCond_Taunting) && !RD_IsActive[bossIdx])
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[RD_Init] Error: Hale was already taunting when rage executed. Refunding rage.");
		}

		PrintCenterText(bossIdx, "You must not already be taunting to use this rage!! Refunding rage!");
		CreateTimer(0.5, Timer_RefundRage, BossIndex, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

    if (isHaleOnGround)
    {
		for (int rdTarget = 1; rdTarget <= MAX_PLAYERS; rdTarget++)
		{
			bool isTargetOnGround = (GetEntityFlags(rdTarget) & FL_ONGROUND) != 0;
			int validTargets = 0;
			if (!IsLivingPlayer(rdTarget))
			continue;

			if (GetClientTeam(rdTarget) != MercTeam)
			continue;

			if (!isTargetOnGround)
			continue;


			maxRange = (valuesDefault ? DEFAULT_RD_TARGRANGE : RD_MaxRange[bossIdx]);
			hitInterval = (valuesDefault ? DEFAULT_RD_HITINTERVAL : RD_DamageInterval[bossIdx]);
			initParticle = (valuesDefault ? DEFAULT_RD_INIT_EFFNAME : RD_InitEffectName);
			if (IsPlayerInRangeOfPlayer(bossIdx, rdTarget, maxRange) && isTargetOnGround)
			{
				validTargets++;
				SetEntityMoveType(rdTarget, MOVETYPE_NONE);
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("[RD_Init] Victim immoblized");
				}
				if (RD_Flags[BossIndex] & RD_FLAG_VICTIM_STUNNED)
				{
					TF2_StunPlayer(rdTarget, 7.0, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT, bossIdx);
				}
				
				SetEntityMoveType(bossIdx, MOVETYPE_NONE);
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("[RD_Init] Hale immobilized");
				}

				RD_IsActive[bossIdx] = true;
				RD_VictimAffected[rdTarget] = true;
				RD_NextHitAt[BossIndex] = hitInterval;

				if (RD_Flags[BossIndex] & RD_FLAG_INFLICTOR_DAMAGEIMMUNE)
				{
					TF2_AddCondition(bossIdx, TFCond_Ubercharged, -1.0);
					RequestFrame(Add_Megaheal, bossIdx);
					if (PRINT_DEBUG_INFO)
					{
						PrintToChatAll("[RD_Init] Ubering boss");
					}
				}
				
				if (RD_Flags[BossIndex] & RD_FLAG_INFLICTOR_DAMAGERESISTANT)
				{
					TF2_AddCondition(bossIdx, TFCond_RuneResist, -1.0);
					if (PRINT_DEBUG_INFO)
					{
						PrintToChatAll("[RD_Init] Boss resistant.");
					}
				}

				primary = CW3_EquipItemByName(bossIdx, "Rainblower_For_Taunt");
				GetClientEyePosition(bossIdx, bossEyePos);
				if (IsValidEntity(primary))
				{
					//SetEntPropEnt(bossIdx, Prop_Send, "m_hActiveWeapon", primary);
					GetClientEyePosition(bossIdx, bossEyePos);
					AttachParticle(bossIdx, initParticle, bossEyePos);
					FakeClientCommand(bossIdx, "taunt");
					initSound = (valuesDefault ? DEFAULT_RD_INITSOUND : RD_InitSound);
					if (strlen(initSound) > 3)
					{
						EmitSoundToAll(initSound);
						if (PRINT_DEBUG_INFO)
						{
							PrintToChatAll("[RD_Init] Emitting inital sound");
						}
					}
					TF2_AddCondition(BossIndex, TFCond_Gas, 2.2);
					TF2_IgnitePlayer(BossIndex, BossIndex, 2.2);
					CreateTimer(1.2, AllowStrike, _, TIMER_FLAG_NO_MAPCHANGE);
					CreateTimer(RD_NextHitAt[BossIndex], PlayHitSound, _, TIMER_REPEAT);
					CreateTimer(RD_NextHitAt[BossIndex], RD_HitPlayer, rdTarget, TIMER_REPEAT);
					CreateTimer(0.2, CreateFlashEffects, rdTarget, TIMER_REPEAT);
					if (PRINT_DEBUG_INFO)
					{
						PrintToChatAll("Timer created for hitting player, %d", rdTarget);
					}
				}
				else
				{
					if (PRINT_DEBUG_INFO)
					{
						PrintToChatAll("[RD_Init] Rainblower entity is not valid. Rage cannot execute without it.");
					}
					SetEntityMoveType(rdTarget, MOVETYPE_WALK);
					SetEntityMoveType(bossIdx, MOVETYPE_WALK);
					TF2_RemoveCondition(bossIdx, TFCond_Ubercharged);
					TF2_RemoveCondition(bossIdx, TFCond_RuneResist);
					TF2_RemoveCondition(bossIdx, TFCond_MegaHeal);
					return;
				}
			} 
			else if (!IsPlayerInRangeOfPlayer(BossIndex, rdTarget, maxRange))
			{
				validTargets--;
				if (validTargets <= 0)
				{
					validTargets = 0;
					PrintCenterText(bossIdx, "No players found! Refunding rage!");
					CreateTimer(0.5, Timer_RefundRage, BossIndex, TIMER_FLAG_NO_MAPCHANGE);
					break;
				}
				continue;
			} 
		}

	}
	else
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[RD_Init] Error: Hale was not on ground when rage executed. Refunding rage.");
		}

		PrintCenterText(bossIdx, "You must be on the ground to use this rage!! Refunding rage!");
		CreateTimer(0.5, Timer_RefundRage, BossIndex, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

}

void Add_Megaheal(int bossIdx)
{
	TF2_AddCondition(bossIdx, TFCond_MegaHeal, -1.0, bossIdx);
}


public void DeleteFog()
{
	int iFog = -1;
	while ((iFog = FindEntityByClassname(iFog, "env_fog_controller")) != -1)
	{	
		CreateTimer(1.25, Timer_DeleteFog, iFog, TIMER_FLAG_NO_MAPCHANGE);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[DeleteFog] Deleting fog");
		}
		iFog = -1;
		break;
	}
	return;
}

public Action Timer_RefundRage(Handle timer, any bossIdx)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	FF2_SetBossCharge(FF2_GetBossIndex(bossIdx), 0, 100.0);
	DeleteFog();
	
	return Plugin_Handled;
}

public Action AllowStrike(Handle timer)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	RD_IsAllowedToStrike[BossIndex] = true;
	return Plugin_Continue;
}

public Action PlayHitSound(Handle timer)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	if (!RD_IsActive[BossIndex])
	return Plugin_Handled;

	if (!RD_IsAllowedToStrike[BossIndex])
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Cannot strike yet!");
		}
		return Plugin_Continue;
	}

	static char hitSound[MAX_SOUND_FILE_LENGTH];
	bool defaultValues = (RD_Flags[BossIndex] & RD_FLAG_USE_DEFAULT_VALUES) != 0;
	hitSound = (defaultValues ? DEFAULT_RD_HITSOUND : RD_HitSound);
	if (strlen(hitSound) > 3)
	{
		PseudoAmbientSound(BossIndex, hitSound, 2, 4000.0, false, false, 0.6);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Emitting hitsound");
		}
		return Plugin_Stop;
	}

	return Plugin_Handled;
}

public Action CreateFlashEffects(Handle timer, any rdTarget)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	if (!RD_IsActive[BossIndex])
	return Plugin_Handled;

	if (IsLivingPlayer(rdTarget) && RD_IsAllowedToStrike[BossIndex])
	{
		RD_FlashEffects(rdTarget);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Creating explosion effects around target.");
		}
	}
	else if (!RD_IsAllowedToStrike[BossIndex])
	{
		return Plugin_Continue;
	}
	

	return Plugin_Continue;
}

public Action RD_HitPlayer(Handle timer, any rdTarget)
{
    if (!RoundInProgress || !PluginActiveThisRound)
    return Plugin_Handled;

	if (!RD_IsActive[BossIndex])
	return Plugin_Handled;

	if (!RD_IsAllowedToStrike[BossIndex])
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Cannot strike yet!");
		}
		return Plugin_Continue;
	}

    bool defaultValues = (RD_Flags[BossIndex] & RD_FLAG_USE_DEFAULT_VALUES) != 0;
    float hitDamage;
    int maxHits;
	
	hitDamage = (defaultValues ? DEFAULT_RD_DAMAGEPERHIT : RD_DamagePerHit[BossIndex]);
	maxHits = (defaultValues ? DEFAULT_RD_MAXHITS : RD_MaxHits[BossIndex]);
    if (RD_VictimAffected[rdTarget] && RD_IsActive[BossIndex])
	{
		if (!TF2_IsPlayerInCondition(rdTarget, TFCond_Ubercharged))
		{
			SDKHooks_TakeDamage(rdTarget, BossIndex, BossIndex, hitDamage, DMG_CLUB | DMG_PREVENT_PHYSICS_FORCE, -1);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("Dealt %.1f damage to non-ubered player", hitDamage);
			}
		}
		else if (TF2_IsPlayerInCondition(rdTarget, TFCond_Ubercharged) && RD_Flags[BossIndex] & RD_FLAG_DAMAGE_UBERED_TARGETS)
		{
			SDKHooks_TakeDamage(rdTarget, BossIndex, BossIndex, hitDamage, DMG_CLUB | DMG_PREVENT_PHYSICS_FORCE, -1);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("Dealt %.1f damage to ubered player", hitDamage);
			}
		}
		
		RD_HitsInflicted[rdTarget]++;
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Hits inflicted: %d", RD_HitsInflicted[rdTarget]);
		}
	}

	if (RD_HitsInflicted[rdTarget] >= maxHits)
	{
		RD_EndRage(BossIndex, rdTarget);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Hits exeeded max hits, ending rage.");
		}
		if (IsLivingPlayer(rdTarget))
		{
			RD_VictimAffected[rdTarget] = false;
			SetEntityMoveType(rdTarget, MOVETYPE_WALK);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("Victim allowed to walk if they're still alive.");
			}
		}
		return Plugin_Handled;
	}

    return Plugin_Continue;    
}

public void RD_FlashEffects(int victim)
{
	if (!RoundInProgress)
	return;

	bool defaultParticle = (RD_Flags[BossIndex] & RD_FLAG_USE_DEFAULT_VALUES) != 0;
	static char hitParticle[MAX_EFFECT_NAME_LENGTH];
	int effectFlash1 = -1;
	int effectFlash2 = -1;
	int effectFlash3 = -1;
	float randOffset1, randOffset2, randOffset3;
	
	randOffset1 = GetRandomFloat(2.0, 15.0);
	randOffset2 = GetRandomFloat(2.0, 20.0);
	randOffset3 = GetRandomFloat(2.0, 30.0);
	hitParticle = (defaultParticle ? DEFAULT_RD_HITFLASH_EFFNAME : RD_HitEffectName);
	effectFlash1 = AttachParticleOffset(victim, hitParticle, randOffset1, randOffset2, randOffset3);
	effectFlash2 = AttachParticleOffset(victim, hitParticle, randOffset1, randOffset2, randOffset3);
	effectFlash3 = AttachParticleOffset(victim, hitParticle, randOffset1, randOffset2, randOffset3);
	if (PRINT_DEBUG_INFO)
	{
		PrintToChatAll("[FlashEffects] Particles created and attached for raging demon hits.");
	}


	if (IsValidEntity(effectFlash1) && IsValidEntity(effectFlash2) && IsValidEntity(effectFlash3))
	{
		CreateTimer(0.4, Timer_RemoveEntity, EntIndexToEntRef(effectFlash1), TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(0.4, Timer_RemoveEntity, EntIndexToEntRef(effectFlash2), TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(0.4, Timer_RemoveEntity, EntIndexToEntRef(effectFlash3), TIMER_FLAG_NO_MAPCHANGE);	
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[FlashEffects] Particles ent refs stored and are now queued for removal.");
		}
	}
	else 
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[FlashEffects] One or more of the particles are invalid! Particle(s) will not show!");
		}
		return;
	}
}

public void RD_EndRage(int bossIdx, int rdVictim)
{
	if (!RoundInProgress || !PluginActiveThisRound)
	return;

	RD_NextHitAt[bossIdx] = FAR_FUTURE;
    RD_HitsInflicted[rdVictim] = 0;

	SetEntityMoveType(bossIdx, MOVETYPE_WALK);
	CreateTimer(2.1, Remove_Uber, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.2, Remove_Megaheal, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
	if (TF2_IsPlayerInCondition(bossIdx, TFCond_RuneResist))
	{
		TF2_RemoveCondition(bossIdx, TFCond_RuneResist);
	}
	RD_IsActive[bossIdx] = false;
	RD_IsAllowedToStrike[BossIndex] = false;
	TF2_RemoveWeaponSlot(BossIndex, 0);
	SetEntPropEnt(BossIndex, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(BossIndex, TFWeaponSlot_Melee));
	if (PRINT_DEBUG_INFO)
	{
		PrintToChatAll("Raging Demon ended.");
	}
}







//Fireball Hadouken
public void Fireball_Hadouken_Init(int bossIdx)
{
	if (!RoundInProgress || !FH_ActiveThisRound)
	return;

	bool defaultValues = (FH_Flags[BossIndex] & FH_FLAG_USE_DEFAULT_VALUES) != 0;
    bool isHaleGrounded = (GetEntityFlags(bossIdx) & FL_ONGROUND) != 0;
	float castDelay;
	float lingeringBuffDuration;
	float rageRefund;
	float curRage = FF2_GetBossCharge(FF2_GetBossIndex(bossIdx), 0);

	if (TF2_IsPlayerInCondition(bossIdx, TFCond_Taunting) && !FH_IsCasting[bossIdx])
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[FH_Rage] Hale is taunting, cancelling and refunding rage.");
		}
		PrintCenterText(bossIdx, "You must not already be taunting to use this ability!!!");

		rageRefund = (defaultValues ? DEFAULT_FH_RAGECOST : FH_RageCost[bossIdx]); 
		FF2_SetBossCharge(FF2_GetBossIndex(bossIdx), 0, (curRage + rageRefund));
		return;
	}

	if (isHaleGrounded)
	{
		castDelay = (defaultValues ? DEFAULT_FH_CASTDELAY : FH_ProjFireDelayTime[bossIdx]);
		lingeringBuffDuration = castDelay + 1.3;
		if (FH_Flags[bossIdx] & FH_FLAG_USER_INVULN_WHILE_CASTING)
		{
			TF2_AddCondition(bossIdx, TFCond_Ubercharged, -1.0, bossIdx);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[Fireball Hadouken] Ubering Hale (Hidden)");
			}
		}
		
		if (FH_Flags[bossIdx] & FH_FLAG_USER_KNOCKBACKIMMUNE_WHILE_CASTING)
		{
			RequestFrame(Add_Megaheal, bossIdx);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[Fireball Hadouken] Hale immune to knockback");
			}
		}

		if (FH_Flags[bossIdx] & FH_FLAG_USER_DAMAGE_RESISTANT_WHILE_CASTING)
		{
			TF2_AddCondition(bossIdx, TFCond_DefenseBuffMmmph, lingeringBuffDuration);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[Fireball Hadouken] Hale given 75% damage resistance.");
			}
		}

		FH_IsCasting[bossIdx] = true;
		FakeClientCommand(bossIdx, "taunt");
		CreateTimer(castDelay, Shoot_FireBall, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
	}
	else 
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[FH_Rage] Hale is not on ground. Cancelling and refunding rage.");
		}
		PrintCenterText(bossIdx, "You must be on the ground to use this ability!!!");

		rageRefund = (defaultValues ? DEFAULT_FH_RAGECOST : FH_RageCost[bossIdx]); 
		int boIndex = FF2_GetBossIndex(bossIdx);
		FF2_SetBossCharge(boIndex, 0, (curRage + rageRefund));
		return;
	}
}

public Action Remove_Megaheal(Handle timer, any bossIdx)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	if (TF2_IsPlayerInCondition(bossIdx, TFCond_MegaHeal))
	{
		TF2_RemoveCondition(bossIdx, TFCond_MegaHeal);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[FH_Rage] Removed megaheal.");
		}
	}

	return Plugin_Continue;
}

public Action Remove_Uber(Handle timer, any bossIdx)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	if (TF2_IsPlayerInCondition(bossIdx, TFCond_Ubercharged))
	{
		TF2_RemoveCondition(bossIdx, TFCond_Ubercharged);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[FH_Rage] Removed uber");
		}
	}

	return Plugin_Continue;
}

public Action Shoot_FireBall(Handle timer, any bossIdx)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	bool defaultVal = (FH_Flags[BossIndex] & FH_FLAG_USE_DEFAULT_VALUES) != 0;
	float projSpeed;
	char projEnt[MAX_ENTITY_CLASSNAME_LENGTH];
	char projClassName[MAX_ENTITY_CLASSNAME_LENGTH];
	static char castSound[MAX_SOUND_FILE_LENGTH];
	if (FH_IsCasting[bossIdx])
	{
		projSpeed = (defaultVal ? DEFAULT_FH_PROJSPEED : FH_ProjSpeed[bossIdx]);
		projEnt = (defaultVal ? DEFAULT_FH_PROJ_ENTNAME : FH_ProjEntName);
		projClassName = (defaultVal ? DEFAULT_FH_PROJ_ENTNAME : FH_ProjClassName);
		castSound = (defaultVal ? DEFAULT_FH_CASTSOUND : FH_CastSound);
		if (strlen(castSound) > 3)
		{
			EmitSoundToAll(castSound);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("Playing Fireball Hadouken sound.");
			}
		}
		ShootProjectile(bossIdx, projSpeed, projEnt, projClassName);
		CreateTimer(1.5, Remove_Uber, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(1.6, Remove_Megaheal, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[FH_Rage] Firing fireball projectile.");
		}
		FH_IsCasting[bossIdx] = false;
	}


	return Plugin_Continue;
}

//Metsu Hadouken
public void Metsu_Orb_Init(int bossIdx)
{
	if (!RoundInProgress || !MH_ActiveThisRound)
	return;

	int boIndex = FF2_GetBossIndex(bossIdx);
	bool orbDefaultValues = (MH_Flags[BossIndex] & MH_FLAG_USE_DEFAULT_VALUES) != 0;
    bool haleIsOnGround = (GetEntityFlags(bossIdx) & FL_ONGROUND) != 0;
	float orbCastDelay;
	float orbBuffLingerDuration;
	float orbCurRage = FF2_GetBossCharge(boIndex, 0);
	float refundOrbRage;
	static char orbCastSound[MAX_SOUND_FILE_LENGTH];
	if (TF2_IsPlayerInCondition(bossIdx, TFCond_Taunting) && !MH_IsCasting[bossIdx])
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[MH_Rage] Hale is taunting, cancelling and refunding rage.");
		}
		PrintCenterText(bossIdx, "You must not already be taunting to use this ability!!!");

		refundOrbRage = (orbDefaultValues ? DEFAULT_MH_RAGECOST : MH_RageCost[bossIdx]); 
		FF2_SetBossCharge(boIndex, 0, (orbCurRage + refundOrbRage));
	}

	if (haleIsOnGround)
	{
		orbCastDelay = (orbDefaultValues ? DEFAULT_MH_CASTDELAY : MH_ProjFireDelayTime[bossIdx]);
		orbBuffLingerDuration = orbCastDelay + 0.3;
		if (MH_Flags[bossIdx] & MH_FLAG_USER_INVULN_WHILE_CASTING)
		{
			TF2_AddCondition(bossIdx, TFCond_Ubercharged, orbBuffLingerDuration);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[Metsu Orb] Ubering Hale");
			}
		}
		
		if (MH_Flags[bossIdx] & MH_FLAG_USER_KNOCKBACKIMMUNE_WHILE_CASTING)
		{
			RequestFrame(Add_Megaheal, bossIdx);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[Metsu Orb] Hale immune to knockback");
			}
		}

		if (MH_Flags[bossIdx] & MH_FLAG_USER_DAMAGE_RESISTANT_WHILE_CASTING)
		{
			TF2_AddCondition(bossIdx, TFCond_DefenseBuffMmmph, orbBuffLingerDuration);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[Metsu Orb] Hale given 75% damage resistance.");
			}
		}

		MH_IsCasting[bossIdx] = true;
		FakeClientCommand(BossIndex, "taunt");
		orbCastSound = (orbDefaultValues ? DEFAULT_MH_CASTSOUND1 : MH_CastSoundCharge);
		if (strlen(orbCastSound) > 3)
		{
			EmitSoundToAll(orbCastSound);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("Playing Metsu Hadouken sound.");
			}
		}
		CreateTimer(orbCastDelay, Shoot_MetsuOrb, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[MH_Rage] Hale is not on ground. Cancelling and refunding rage.");
		}
		PrintCenterText(bossIdx, "You must be on the ground to use this ability!!!");

		refundOrbRage = (orbDefaultValues ? DEFAULT_MH_RAGECOST : MH_RageCost[bossIdx]); 
		FF2_SetBossCharge(boIndex, 0, (orbCurRage + refundOrbRage));
		return;
	}
}

public Action Shoot_MetsuOrb(Handle timer, any bossIdx)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	bool valDefault = (MH_Flags[BossIndex] & MH_FLAG_USE_DEFAULT_VALUES) != 0;
	float orbSpeed;
	char orbEnt[MAX_ENTITY_CLASSNAME_LENGTH];
	char orbEntClass[MAX_ENTITY_CLASSNAME_LENGTH];
	static char orbFireSound[MAX_SOUND_FILE_LENGTH];
	if (MH_IsCasting[bossIdx])
	{
		orbSpeed = (valDefault ? DEFAULT_MH_PROJSPEED : MH_ProjSpeed[bossIdx]);
		orbEnt = (valDefault ? DEFAULT_MH_PROJ_ENTNAME : MH_ProjEntName);
		orbEntClass = (valDefault ? DEFAULT_MH_PROJ_CLASSNAME : MH_ProjClassName);
		ShootProjectile(bossIdx, orbSpeed, orbEnt, orbEntClass);
		orbFireSound = (valDefault ? DEFAULT_MH_CASTSOUND2 : MH_CastSoundFire);
		if (strlen(orbFireSound) > 3)
		{
			EmitSoundToAll(orbFireSound);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("Playing Metsu Hadouken sound.");
			}
		}
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Firing metsu orb projectile.");
		}
		CreateTimer(1.5, Remove_Uber, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(1.6, Remove_Megaheal, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
		MH_IsCasting[bossIdx] = false;
	}

	return Plugin_Continue;
}



int ShootProjectile(int iClient, float projSpeed, const char strEntname[MAX_ENTITY_CLASSNAME_LENGTH] = "", const char strEntClassname[MAX_ENTITY_CLASSNAME_LENGTH] = "")
{
	float flAng[3]; // original
	float flPos[3]; // original
	GetClientEyeAngles(iClient, flAng);
	GetClientEyePosition(iClient, flPos);
	
	int iSpell = CreateEntityByName(strEntname);
	
	if(!IsValidEntity(iSpell))
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[Shoot_Proj] Error: Projectile is invalid!");
		}
		return -1;
	}

	if(IsEmptyString(strEntClassname))
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[Shoot_Proj] Error: Classname must be set for projectile damage to be manipulated.");
		}
		return -1;
	}
		
	
	float flVel1[3];
	float flVel2[3];
	
	GetAngleVectors(flAng, flVel2, NULL_VECTOR, NULL_VECTOR);
	
	flVel1[0] = flVel2[0]*projSpeed; //Speed of a tf2 rocket is 1100.0 by default.
	flVel1[1] = flVel2[1]*projSpeed;
	flVel1[2] = flVel2[2]*projSpeed;
	
	SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iSpell, Prop_Send, "m_bCritical", false);
	SetEntProp(iSpell, Prop_Send, "m_nSkin", 1);
	//SetEntDataFloat(iSpell, FindSendPropInfo(strEntClassname, "m_iDeflected") + 4, projDamage, true);
	
	TeleportEntity(iSpell, flPos, flAng, NULL_VECTOR);
	
	SetVariantInt(BossTeam);
	AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0); 
	
	DispatchSpawn(iSpell);
	TeleportEntity(iSpell, NULL_VECTOR, NULL_VECTOR, flVel1);
	
	return iSpell;
}




Handle hPlayTaunt;
public void RegisterForceTaunt()
{
	GameData conf = new GameData("tf2.tauntem");
	if (!conf)
	{
		PrintToConsoleAll("[RegisterForceTaunt] Unable to load gamedata/tf2.tauntem.txt. Force taunt will not function.");
		return;
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	delete conf;
	hPlayTaunt = EndPrepSDKCall();
	if (hPlayTaunt == null)
	{
		SetFailState("[RegisterForceTaunt] Unable to initialize call to CTFPlayer::PlayTauntSceneFromItem. Need to get updated tf2.tauntem.txt method signatures. Force taunt will not function");
        PrintToConsoleAll("[RegisterForceTaunt] Unable to load gamedata/tf2.tauntem.txt. Force taunt will not function.");
		return;
	}
}




// stocks at the bottom.
public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	
	if (entid <= INVALID_ENTREF)
	return Plugin_Continue;

	if (IsValidEntity(entity))
	{
		RemoveEntity(entity);
	}

	return Plugin_Continue;
}

public Action Timer_DeleteFog(Handle timer, any fog)
{

	if(IsValidEntity(fog))
	{
		SetVariantString("");
		AcceptEntityInput(fog, "SetFogController");
	}
		
	AcceptEntityInput(fog, "Kill");
	return Plugin_Continue;
}


stock int AttachParticleOffset(int entity, const char[] particleType, float offset1=0.0, float offset2=0.0, float offset3=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
	return -1;

	static char targetName[128];
	float position[3];
	if (IsValidClient(entity))
	{
		GetClientAbsOrigin(entity, position);
	}
	else if (IsValidEntity(entity) || IsValidEdict(entity))
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	}
	else
	{
		return -1;
	}


	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);

	position[0] += offset1;
    position[1] += offset2;
	position[2] += offset3;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	SetVariantString(targetName);
	if (attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}


stock int AttachParticle(int entity, const char[] particleType, float position[3], float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	position[2] += offset;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if (attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

// adapted from the above and Friagram's halloween 2013 (which standing alone did not work for me)
stock int AttachParticleToAttachment(int entity, const char[] particleType, const char[] attachmentPoint)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	
	SetVariantString(attachmentPoint);
	AcceptEntityInput(particle, "SetParentAttachment");

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

stock int SelectBestTarget(int client, float oAngles[3]) //Gets the closest visible target to the client
{
    float vecClientPos[3];
    GetClientEyePosition(client, vecClientPos);
    int target = INVALID_ENTREF;

    float vecTargetPos[3];
    float flClosestDistance = 8192.0;
    float vecVisiblePos[3];

    for (int iTarget = 1; iTarget <= MAX_PLAYERS; iTarget++)
    {
        if (iTarget == client)
            continue;

        if (!IsValidClient(iTarget))
            continue;

        GetClientEyePosition(iTarget, vecVisiblePos);
        vecVisiblePos[2] -= 40.0;

        float flDistance = GetVectorDistance(vecClientPos, vecVisiblePos);

        //PrintToChatAll("Checking Distance");
        if (flDistance < flClosestDistance)
        {
            //PrintToChatAll("Closest Target");
            if (CheckTrace(client, iTarget))
            {
                //PrintToChatAll("Found Target is not closest target");
                //fov = nearest;
                flClosestDistance = flDistance;
                vecTargetPos = vecVisiblePos;
                target = iTarget;
            }
        }
    }

    if (IsValidClient(target))
        return target;
    else
    {
        //PrintToChatAll("returned client");
        return client;
    }
}


stock bool CheckTrace(int attacker, int victim)
{
    //PrintToChat(attacker, "tracing for target.");
    bool result = false;
    float startingpos[3], targetpos[3];
    GetClientEyePosition(attacker, startingpos);

    GetClientEyePosition(victim, targetpos);
    Handle tracecheck = TR_TraceRayFilterEx(startingpos, targetpos, MASK_PLAYERSOLID, RayType_EndPoint, FilterSelf, attacker);
    if (TR_DidHit(tracecheck))
    {
        int ent = TR_GetEntityIndex(tracecheck);
        if(IsValidClient(ent) && ent == victim) //If target is visible and trace result is the target
        {
            //PrintToChatAll("Can see target");
            result = true;
        }
    }
    CloseHandle(tracecheck);
    return result;
}


stock void PseudoAmbientSound(int clientIdx, char[] soundPath, int count=1, float radius=1000.0, bool skipSelf=false, bool skipDead=false, float volumeFactor=1.0)
{
	float emitterPos[3];
	float listenerPos[3];
	GetClientEyePosition(clientIdx, emitterPos);
	for (int listener = 1; listener < MAX_PLAYERS; listener++)
	{
		if (!IsValidClient(listener))
			continue;
		else if (skipSelf && listener == clientIdx)
			continue;
		else if (skipDead && !IsLivingPlayer(listener))
			continue;
			
		// knowing virtually nothing about sound engineering, I'm kind of BSing this here...
		// but I'm pretty sure decibal dropoff is best done logarithmically.
		// so I'm doing that here.
		GetClientEyePosition(listener, listenerPos);
		float distance = GetVectorDistance(emitterPos, listenerPos);
		if (distance >= radius)
			continue;
		
		float logMe = (radius - distance) / (radius / 10.0);
		if (logMe <= 0.0) // just a precaution, since EVERYTHING tosses an exception in this game
			continue;
			
		float volume = Logarithm(logMe) * volumeFactor;
		if (volume <= 0.0)
			continue;
		else if (volume > 1.0)
		{
			PrintToServer("[sarysamods6] How the hell is volume greater than 1.0?");
			volume = 1.0;
		}
		
		for (int i = 0; i < count; i++)
			EmitSoundToClient(listener, soundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
	}
}

stock void ReadModel(int bossIdx, const char[] ability_name, int argInt, char[] modelFile)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		PrecacheModel(modelFile);
}

stock int ReadModelToInt(int bossIdx, const char[] ability_name, int argInt)
{
	static String:modelFile[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		return PrecacheModel(modelFile);
	return -1;
}

stock void ReadSound(int bossIdx, const char[] ability_name, int argInt, char[] soundFile)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		PrecacheSound(soundFile);
}

stock char ReadCenterText(int bossIdx, const char[] ability_name, int argInt, char centerText[MAX_CENTER_TEXT_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, MAX_CENTER_TEXT_LENGTH);
	ReplaceString(centerText, MAX_CENTER_TEXT_LENGTH, "\\n", "\n");
}
 
stock void PlaySoundLocal(int clientIdx, char[] soundPath, bool followPlayer = true, int repeat = 1)
{
	// play a speech sound that travels normally, local from the player.
	float playerPos[3];
	GetClientEyePosition(clientIdx, playerPos);
	//PrintToChatAll("eye pos=%f,%f,%f     sound=%s", playerPos[0], playerPos[1], playerPos[2], soundPath);
	for (int i = 1; i < repeat; i++)
	{
		if (IsValidClient(i))
		{
			EmitAmbientSound(soundPath, playerPos, followPlayer ? clientIdx : SOUND_FROM_WORLD);
		}
	}
}

public bool TraceRedPlayers(int entity, int contentsMask)
{
	if (IsLivingPlayer(entity) && GetClientTeam(entity) != BossTeam)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToChatAll("[sarysamods6] Hit player %d on trace.", entity);
		return true;
	}

	return false;
}

public bool TraceRedPlayersAndBuildings(int entity, int contentsMask)
{
	if (IsLivingPlayer(entity) && GetClientTeam(entity) != BossTeam)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods6] Hit player %d on trace.", entity);
		return true;
	}
	else if (IsValidEntity(entity))
	{
		static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(entity, classname, sizeof(classname));
		classname[4] = 0;
		if (!strcmp(classname, "obj_")) // all buildings start with this
			return true;
	}

	return false;
}

stock bool HasValidAimTarget(int client, float oAngles[3], float fov=10.0, float range)
{
    if (IsValidClient(client) && IsLivingPlayer(client))
    {
        float vAngles[3], vPos[3], nearest;
        float flClosestDistance = range;
		if (PRINT_DEBUG_INFO)
        PrintToChat(client, "Max range: %.1f", range);

        GetClientEyePosition(client, vPos);
        GetClientEyeAngles(client, vAngles);
        for (int target = 1; target <= MaxClients; target++)
        {
            if (IsValidClient(target))
            {
                float viPos[3];
                GetClientEyePosition(target, viPos);
                viPos[2] -= 40.0;
                nearest = GetFov(oAngles, CalcAngle(vPos, viPos));
                if (nearest > fov)
                    continue;

                float distance = GetVectorDistance(vPos, viPos);

                if (distance > range)
				{
					return false;
				}
				

                if (FloatAbs(fov - nearest) < 5)
                {
                    if (distance < flClosestDistance)
                    {
                        //PrintToChat(client, "client distance: %.1f", distance);
                        if (IsValidTarget(target, client, vPos))
                        {
                            fov = nearest;
                            flClosestDistance = distance;
                            CM_CurTarget[client] = target;
                            return true;
                        }
                    }
                }
                else if (nearest < fov)
                {
                    if (IsValidTarget(target, client, vPos))
                    {
                        fov = nearest;
                        flClosestDistance = distance;
                        CM_CurTarget[client] = target;
                        return true;
                    }
                }
            }
        }
    }

	CM_CurTarget[client] = INVALID_ENTREF;
    return false;
}

stock bool IsPositionInRangeOfPosition(float pos1[3], float pos2[3], float posRange)
{
    float range = posRange * 1.5;
    float distance = GetVectorDistance(pos1, pos2);
    if (distance <= range)
    {
       return true;
    }

	return false;
}

stock bool IsPlayerInRangeOfPosition(int client, float pos[3], float posRange)
{
    float range = posRange * 1.5;
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
    float distance = GetVectorDistance(clientPos, pos);
    if (distance <= range)
    {
       return true;
    }

	return false;
}


stock bool IsValidTarget(int target, int self, float vPos[3])
{
	if (target == self) return false;
	if (GetClientTeam(target) == GetClientTeam(self)) return false;
	float targpos[3];
	GetClientEyePosition(target, targpos);

	Handle trace = TR_TraceRayFilterEx(vPos, targpos, MASK_PLAYERSOLID, RayType_EndPoint, FilterSelf, self);
	if(TR_DidHit(trace))
	{
		int entity = TR_GetEntityIndex(trace);
		if (IsValidClient(entity) && IsLivingPlayer(entity))
		{
			CloseHandle(trace);
			return true;
		}
	}
	CloseHandle(trace);
	return false;
}

stock float CalcAngle(float src[3], float dst[3])
{
    float angles[3];
    float delta[3];
    SubtractVectors(dst, src, delta);

    GetVectorAngles(delta, angles);

    return angles;
}

//modified
stock float[] TryPredictPlayerPos(int clientIdx, int target, float TargetPlayerPos[3], float ClientPos[3], float ProjSpeed) //Try and aim where a target will be in the future
{
	if(!target || !IsValidClient(target) || !IsPlayerAlive(target))
    {
        return;
    }
    
    
	if (target != clientIdx)
	{
		float flDistance, flTravelTime, TargetVelocity[3];
		GetEntPropVector(target, Prop_Data, "m_vecVelocity", TargetVelocity);
		flDistance = GetVectorDistance(ClientPos, TargetPlayerPos);
		flTravelTime = flDistance / ProjSpeed;
		float gravity = GetConVarFloat(gravscale) / 100.0;
		gravity = TargetVelocity[2] > 0.0 ? -gravity : gravity;

		//Try and predict where the target will be when the projectile hits
		TargetPlayerPos[0] += TargetVelocity[0] * flTravelTime;
		TargetPlayerPos[1] += TargetVelocity[1] * flTravelTime;
		if (GetEntityFlags(target) & FL_ONGROUND)
        {
			TargetPlayerPos[2] += TargetVelocity[2] * flTravelTime;
        }
		else
		{
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("Air shot");
            }
            
            TargetPlayerPos[2] += TargetVelocity[2] * flTravelTime + (gravity + Pow(flTravelTime, 2.0)) - 10.0;
            
            //Check if target will hit a surface
            float target_curpos[3];
            GetClientAbsOrigin(target, target_curpos);
            Handle position_trace = TR_TraceRayFilterEx(target_curpos, TargetPlayerPos, MASK_PLAYERSOLID, RayType_EndPoint, FilterSelf, target);
            if (TR_DidHit(position_trace))
            {
                TR_GetEndPosition(TargetPlayerPos, position_trace); // If target will hit a surface, fire at that position
            }
            CloseHandle(position_trace);
		}
	}
}

stock float GetAngleToPoint(float origin[3], float target[3])
{
    float angles[3];
    float delta[3];

    SubtractVectors(target, origin, delta);
    GetVectorAngles(delta, angles);

    return angles;
}



stock float GetNewAngleToTarget(float clientPos[3], float targetPos[3])
{
    float newAngle[3];
	float returnAngle[3];

	Handle angleTrace = TR_TraceRayFilterEx(clientPos, targetPos, MASK_PLAYERSOLID, RayType_Infinite, FilterSelf);
    if (TR_DidHit(angleTrace))
    {
        GetRayAngles(clientPos, targetPos, newAngle); // angle towards targeted position
        returnAngle = newAngle;
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[Trace rocket angle] Trace hit, angle found.");
        }
    }
    CloseHandle(angleTrace);

    if (PRINT_DEBUG_INFO)
    PrintToChatAll("SetAngle: TargetPos = %.1f, %.1f, %.1f", returnAngle[0], returnAngle[1], returnAngle[2]);

	return returnAngle;
}

public bool FilterSelf(int entity, int contentsMask, int client)
{
	//return entity > MAX_PLAYERS || !entity;
	if (entity == client)
	{
		return false;
	}
	return true;
}

stock bool IsPlayerInRangeOfEntity(int entity, int client, float entityradius)
{
    float entpos[3], clientpos[3];
    float range = entityradius * 1.2;
    GetClientAbsOrigin(client, clientpos);
    GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entpos);
    float distance = GetVectorDistance(entpos, clientpos);
    if (distance <= range)
    {
       return true;
    }

	if (entity == INVALID_ENTREF || !IsValidEntity(entity))
	{
		return false;
	}

	return false;
}

stock bool IsLivingPlayer(int clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
		return false;
		
	return IsValidClient(clientIdx) && IsPlayerAlive(clientIdx);
}


stock float GetFov(const float viewAngle[3], const float aimAngle[3])
{
    float ang[3], aim[3];

    GetAngleVectors(viewAngle, aim, NULL_VECTOR, NULL_VECTOR);
    GetAngleVectors(aimAngle, ang, NULL_VECTOR, NULL_VECTOR);

	return RadToDeg(ArcCosine(GetVectorDotProduct(aim, ang) / GetVectorLength(aim, true)));
}

stock bool IsInstanceOf(int entity, const char[] desiredClassname)
{
	char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return strcmp(classname, desiredClassname) == 0;
}

stock void CreateGlow(int client, bool complete=false)
{
  float position[3];
  GetClientEyePosition(ClientTarget[client], position);
  if (complete)
  {
    TE_SetupGlowSprite(position, g_tracksprite, 0.1, 5.0, 160);
    TE_SendToClient(client);
  }
  else
  {
    TE_SetupGlowSprite(position, g_tracksprite, 0.3, 4.0, 90);
    TE_SendToClient(client);
  }
}

stock float GetRayAngles(float startPoint[3], float endPoint[3], float angle[3])
{
	static float tmpVec[3];
	tmpVec[0] = endPoint[0] - startPoint[0];
	tmpVec[1] = endPoint[1] - startPoint[1];
	tmpVec[2] = endPoint[2] - startPoint[2];
	GetVectorAngles(tmpVec, angle);
}

stock bool IsValidClient2(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
	{
		return false;
	}
	if (IsClientSourceTV(iClient) || IsClientReplay(iClient))
	{
		return false;
	}
	if (IsFakeClient(iClient) && IsPlayerAlive(iClient))
	{
		return true;
	}
	return true;
}

stock float fixDamageForFF2(float damage)
{
	if (damage <= 160.0)
		return damage / 3.0;
	return damage;
}

stock bool IsPlayerInRangeOfPlayer(int client1, int client2, float clientradius)
{
    float client1pos[3], client2pos[3];
    float range = clientradius * 1.2;
    GetClientAbsOrigin(client1, client1pos);
    GetClientAbsOrigin(client2, client2pos);
    float distance = GetVectorDistance(client1pos, client2pos);
    if (distance <= range)
    {
       return true;
    }

	if (!IsValidClient(client1) || !IsValidClient(client2) || !IsPlayerAlive(client1) || !IsPlayerAlive(client2))
	{
		return false;
	}

	return false;
}

stock int FindRandomPlayer(bool isBossTeam)
{
	int player = -1;

	// first, get a player count for the team we care about
	int playerCount = 0;
	for (int clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;

		if ((isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) != BossTeam))
			playerCount++;
	}

	// ensure there's at least one living valid player
	if (playerCount <= 0)
		return -1;

	// now randomly choose our victim
	int rand = GetRandomInt(0, playerCount - 1);
	playerCount = 0;
	for (int clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;

		if ((isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) != BossTeam))
		{
			if (playerCount == rand) // needed if rand is 0
			{
				player = clientIdx;
				break;
			}
			playerCount++;
			if (playerCount == rand) // needed if rand is playerCount - 1, executes for all others except 0
			{
				player = clientIdx;
				break;
			}
		}
	}
	
	return player;
}

stock int ParticleEffectAt(float position[3], char[] effectName, float duration = 0.1)
{
	if (IsEmptyString(effectName))
		return -1; // nothing to display
		
	int particle = CreateEntityByName("info_particle_system");
	if (particle != -1)
	{
		TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "effect_name", effectName);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		if (duration > 0.0)
			CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
	}
	return particle;
}


stock bool CylinderCollision(float cylinderOrigin[3], float colliderOrigin[3], float maxDistance, float zMin, float zMax)
{
	if (colliderOrigin[2] < zMin || colliderOrigin[2] > zMax)
		return false;

	static float tmpVec1[3];
	tmpVec1[0] = cylinderOrigin[0];
	tmpVec1[1] = cylinderOrigin[1];
	tmpVec1[2] = 0.0;
	static float tmpVec2[3];
	tmpVec2[0] = colliderOrigin[0];
	tmpVec2[1] = colliderOrigin[1];
	tmpVec2[2] = 0.0;
	
	return GetVectorDistance(tmpVec1, tmpVec2, true) <= maxDistance * maxDistance;
}


stock bool IsValidBoss(int clientIdx)
{
	if (!IsLivingPlayer(clientIdx))
	return false;

	if (FF2_GetBossUserId(clientIdx) < 0)
	return false;
		
	return GetClientTeam(clientIdx) == BossTeam;
}

stock int GetAlivePlayerCount(TFTeam team)
{
	int alivePlayers = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;
		if(GetClientTeam(client) != view_as<int>(team))
			continue;
		alivePlayers++;
	}
	return alivePlayers;
}

stock int GetRandomDeadPlayer()
{
	int[] clients = new int[MaxClients+1];
	int clientCount;
	for(int deadIdx = 1; deadIdx <= MaxClients; deadIdx++)
	{
		if (deadIdx == view_as<int>(TFTeam_Spectator))
		continue;

		if(IsValidEdict(deadIdx) && (IsValidClient(deadIdx) || IsFakeClient(deadIdx)) && !IsPlayerAlive(deadIdx) && FF2_GetBossIndex(deadIdx) == -1 && (GetClientTeam(deadIdx) > 1))
		{
			clients[clientCount++] = deadIdx;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock void SetAmmo(int client, int wepslot, int newAmmo)
{
	int weapon = GetPlayerWeaponSlot(client, wepslot);
	if (!IsValidEntity(weapon) || !IsPlayerAlive(client))
	{
        ThrowError("Invalid Weapon or user is dead.");
		return;
	}
	if (IsValidEntity(weapon))
	{
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, newAmmo, 4, true);
	}
}

stock int MakeCEIVEnt(int client, int itemdef)
{
	static Handle hItem;
	if (hItem == INVALID_HANDLE)
	{
		hItem = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);
		TF2Items_SetClassname(hItem, "tf_wearable_vm");
		TF2Items_SetQuality(hItem, 6);
		TF2Items_SetLevel(hItem, 1);
		TF2Items_SetNumAttributes(hItem, 0);
	}
	TF2Items_SetItemIndex(hItem, itemdef);
	return TF2Items_GiveNamedItem(client, hItem);
}

stock void SetEntityColor(int iEntity, int iColor[4])
{
	SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEntity, iColor[0], iColor[1], iColor[2], iColor[3]);
}

stock int ReadHexOrDecInt(char hexOrDecString[HEX_OR_DEC_STRING_LENGTH])
{
	if (StrContains(hexOrDecString, "0x") == 0)
	{
		int result = 0;
		for (int i = 2; i < 10 && hexOrDecString[i] != 0; i++)
		{
			result = result<<4;
				
			if (hexOrDecString[i] >= '0' && hexOrDecString[i] <= '9')
				result += hexOrDecString[i] - '0';
			else if (hexOrDecString[i] >= 'a' && hexOrDecString[i] <= 'f')
				result += hexOrDecString[i] - 'a' + 10;
			else if (hexOrDecString[i] >= 'A' && hexOrDecString[i] <= 'F')
				result += hexOrDecString[i] - 'A' + 10;
		}
		
		return result;
	}
	else
	{
		return StringToInt(hexOrDecString);
	}
		
}

stock int ReadHexOrDecString(int bossIdx, const char[] ability_name, int argIdx)
{
	static char hexOrDecString[HEX_OR_DEC_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argIdx, hexOrDecString, HEX_OR_DEC_STRING_LENGTH);
	return ReadHexOrDecInt(hexOrDecString);
}