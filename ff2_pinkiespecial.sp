#pragma semicolon 1
#pragma tabsize 0

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <drain_over_time>
#include <drain_over_time_subplugin>
#include <tf2attributes>
#include <ff2_dynamic_defaults>
#include <tf2>


// text string limits
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_FILE_LENGTH 128
#define MAX_MATERIAL_FILE_LENGTH 128
#define MAX_EFFECT_NAME_LENGTH 48
#define MAX_ENTITY_CLASSNAME_LENGTH 48
#define MAX_CENTER_TEXT_LENGTH 128
#define MAX_HULL_STRING_LENGTH 197
#define MAX_ATTACHMENT_NAME_LENGTH 48
#define COLOR_BUFFER_SIZE 12
#define HEX_OR_DEC_STRING_LENGTH 12 // max -2 billion is 11 chars + null termination

#define NOPE_AVI "vo/engineer_no01.mp3" // DO NOT DELETE FROM FUTURE PACKS
#define INVALID_ENTREF INVALID_ENT_REFERENCE

enum // Collision_Group_t in const.h
{
	COLLISION_GROUP_NONE  = 0,
	COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	COLLISION_GROUP_PLAYER,
	COLLISION_GROUP_BREAKABLE_GLASS,
	COLLISION_GROUP_VEHICLE,
	COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
										// TF2, this filters out other players and CBaseObjects
	COLLISION_GROUP_NPC,			// Generic NPC group
	COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	COLLISION_GROUP_PROJECTILE,		// Projectiles!
	COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	COLLISION_GROUP_PASSABLE_DOOR,	// ** sarysa TF2 note: Must be scripted, not passable on physics prop (Doors that the player shouldn't collide with)
	COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	COLLISION_GROUP_PUSHAWAY,		// ** sarysa TF2 note: I could swear the collision detection is better for this than NONE. (Nonsolid on client and server, pushaway in player code)

	COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_COLLISION_GROUP
};
 
#define DEFAULT_PROPBUFF_MODEL "models/items/medkit_small_bday.mdl"

#define DEFAULT_PROP_COLOR_BLUE {0,0,255,255} //Red, Blue, Green, Alpha in case you forgot.
#define DEFAULT_PROP_COLOR_RED {255,0,0,255} 
#define DEFAULT_PROP_COLOR_GREEN {0,255,0,255} 
#define DEFAULT_PROP_COLOR_VIOLET {138,43,226,255}
#define DEFAULT_COLOR {255,255,255,255}

#define DEFAULT_CONDITION_GREEN TFCond_DefenseBuffed
#define DEFAULT_CONDITION_BLUE TFCond_MegaHeal
#define DEFAULT_CONDITION_RED TFCond_SpeedBuffAlly
#define DEFAULT_CONDITION_VIOLET TFCond_RuneResist

#define DEFAULT_PICKUP_SOUND "vs_ponyville/pinkie/pinkiepie_pickup.mp3"


#define MAX_PROPS 20

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

#define ARG_LENGTH 256
int BossIndex = 0;
int BossTeam = view_as<int>(TFTeam_Blue);
int MercTeam = view_as<int>(TFTeam_Red);

bool RoundInProgress = false;
bool PluginActiveThisRound = false;

bool PRINT_DEBUG_INFO = false;
bool PRINT_DEBUG_SPAM = false;
bool DEBUG_FORCE_RAGE = false;

#define PLUGIN_VERSION "1.0"
public Plugin myinfo = {
	name = "VSPR Pinkie pie experimental changes",
	author = "Spyro. Just Spyro.",
	version = PLUGIN_VERSION,
}

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)

//Passive: Cupcake props that give buffs to the bossteam only when picked up. Dropped by slain players.
#define PPB_STRING "passive_prop_buff"
#define MAX_CONDITIONS 10
//Flags
#define PPB_FLAG_USE_DEFAULT_PROPMODEL 0x0001
#define PPB_FLAG_USE_DEFAULT_PROP_CONDS 0x0002
#define PPB_FLAG_USE_DEFAULT_PROP_PICKUPSOUND 0x0004

#define PPB_FLAG_ENFORCE_ONE_PROP_ONDEATH 0x0008
#define PPB_FLAG_PROPS_NEVER_EXPIRE 0x0010
#define PPB_FLAG_EXCLUDE_SUICIDES 0x0020
#define PPB_FLAG_EXCLUDE_DEADRINGER_DEATH 0x0040
#define PPB_FLAG_ENFORCE_ONE_BUFF_ACTIVE 0x0080

#define PPB_FLAG_ALLOW_MINIONS_TO_PICKUP 0x0100
#define PPB_FLAG_PROP_SPAWNS_IMMOBILE 0x0200
#define PPB_FLAG_MODEL_SCALES_WITH_RADIUS 0x0400

//Internals
bool PPB_ActiveThisRound;
bool PPB_CanUse[MAX_PLAYERS_ARRAY];
bool PPB_BossBuffedByCupcake[MAX_PLAYERS_ARRAY];

//Prop internals

//Prop buff type names
#define PPB_TYPE_LIME 1
#define PPB_TYPE_BLUEBERRY 2
#define PPB_TYPE_HOTSAUCE 3
#define PPB_TYPE_RASPBERRY 4
#define PPB_ACTIVATION_TIME 1.1
int PPBP_EntRef[MAX_PROPS];
float PPBP_ActivateAt[MAX_PROPS];
//int PPBP_Owner[MAX_PROPS];
int PPBP_Type[MAX_PROPS];
float PPBP_CollisionTestAt[MAX_PROPS];
float PPBP_StopPropMovementAt[MAX_PROPS];

//Arguments
bool PPB_IsEnabled[MAX_PLAYERS_ARRAY];

char PPB_Model[MAX_MODEL_FILE_LENGTH]; 
char PPB_PickupSound[MAX_SOUND_FILE_LENGTH]; 

int PPB_MinToSpawn[MAX_PLAYERS_ARRAY]; 
int PPB_MaxToSpawn[MAX_PLAYERS_ARRAY];
int PPB_ConditionForGreen[MAX_PLAYERS_ARRAY];
int PPB_ConditionForBlue[MAX_PLAYERS_ARRAY];
int PPB_ConditionForViolet[MAX_PLAYERS_ARRAY];
int PPB_ConditionForRed[MAX_PLAYERS_ARRAY];

float PPB_BuffDuration[MAX_PLAYERS_ARRAY]; 
float PPB_PropDuration[MAX_PLAYERS_ARRAY];
float PPB_ObjRadius[MAX_PLAYERS_ARRAY]; 
float PPB_ObjHeight[MAX_PLAYERS_ARRAY]; 

int PPB_Flags[MAX_PLAYERS_ARRAY];

//DOT: Force everyone to laugh! (Including yourself.)
#define DFL_STRING "dot_global_laugh"
#define DFL_FLAG_BOSS_DOES_NOT_LAUGH 0x0001
#define DFL_FLAG_UBERED_PLAYERS_NOT_AFFECTED 0x0002
#define DFL_FLAG_BOSS_KNOCKBACK_IMMUNE_DURING_TAUNT 0x0004
#define DFL_FLAG_ALLOW_SPEED_BUFF_AFTER_LAUGH 0x0008
bool DFL_ActiveThisRound;
bool DFL_CanUse[MAX_PLAYERS_ARRAY];

float DFL_LaughDuration[MAX_PLAYERS_ARRAY];
float DFL_BossLaughDurationOffset[MAX_PLAYERS_ARRAY];

bool DFL_AffectsMinions[MAX_PLAYERS_ARRAY];
bool DFL_DisablesSentries[MAX_PLAYERS_ARRAY];
float DFL_SentryDisabledDuration[MAX_PLAYERS_ARRAY];

int DFL_Flags[MAX_PLAYERS_ARRAY];


/**
 * METHODS REQUIRED BY ff2 subplugin
 */
PrintRageWarning()
{
	PrintToConsoleAll("*********************************************************************");
	PrintToConsoleAll("*                             WARNING                               *");
	PrintToConsoleAll("*       DEBUG_FORCE_RAGE in ff2_pinkiespecial.sp is set to true!    *");
	PrintToConsoleAll("*  Any admin can use the 'rage' command to use rages in this pack!  *");
	PrintToConsoleAll("*  This is only for test servers. Disable this on your live server. *");
	PrintToConsoleAll("*********************************************************************");
}
 
#define CMD_FORCE_RAGE "rage"
public OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy); // for non-arena maps
	HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy); // for non-arena maps
	if (DEBUG_FORCE_RAGE)
	{
		PrintRageWarning();
		RegAdminCmd(CMD_FORCE_RAGE, CmdForceRage, ADMFLAG_GENERIC);
	}
	RegisterForceTaunt();
}

public void OnMapStart()
{
	PrecacheSound(DEFAULT_PICKUP_SOUND, true);
	PrecacheModel(DEFAULT_PROPBUFF_MODEL);
}



public Action Event_RoundStart(Handle hEvent, const char[] name, bool dontBroadcast)
{
    RoundInProgress = true;
	PluginActiveThisRound = false;

    //Ability global inits 
    PPB_ActiveThisRound = false;
    DFL_ActiveThisRound = false;

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

        //Ability client inits here
        PPB_CanUse[clientIdx] = false;
		PPB_BossBuffedByCupcake[clientIdx] = false;
        DFL_CanUse[clientIdx] = false;
        //RCS_CanUse[clientIdx] = false;
		

        int bossIdx = FF2_GetBossIndex(clientIdx);
		if (FF2_GetBossIndex(clientIdx) < 0) 
		{
			BossIndex = -1;
			if (PRINT_DEBUG_SPAM)
			{
				PrintToChatAll("[OnRoundStart]: ERROR: boss index is invalid!");
			}
			continue;
		}

        //Ability arguments here
        if (FF2_HasAbility(bossIdx, this_plugin_name, PPB_STRING))
		{
			PluginActiveThisRound = true;
			PPB_ActiveThisRound = true;
			PPB_CanUse[clientIdx] = true;
			BossIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

            PPB_IsEnabled[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PPB_STRING, 1) == 1;

            ReadModel(bossIdx, PPB_STRING, 2, PPB_Model);
            ReadSound(bossIdx, PPB_STRING, 3, PPB_PickupSound);

            PPB_MinToSpawn[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PPB_STRING, 4);
            PPB_MaxToSpawn[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PPB_STRING, 5);
            PPB_ConditionForGreen[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PPB_STRING, 6);
            PPB_ConditionForBlue[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PPB_STRING, 7);
            PPB_ConditionForViolet[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PPB_STRING, 8);
            PPB_ConditionForRed[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PPB_STRING, 9);

            PPB_BuffDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PPB_STRING, 10); 
            PPB_PropDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PPB_STRING, 11);
            PPB_ObjRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PPB_STRING, 12); 
            PPB_ObjHeight[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PPB_STRING, 13);

			PPB_Flags[clientIdx] = ReadHexOrDecString(bossIdx, PPB_STRING, 14);
        }
		else 
		{
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[Roundstart PPB] Warning: No abilites added. Check config file.");
			}
		}

        if (FF2_HasAbility(bossIdx, this_plugin_name, DFL_STRING))
		{
			PluginActiveThisRound = true;
			DFL_ActiveThisRound = true;
			DFL_CanUse[clientIdx] = true;
			BossIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

			DFL_LaughDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DFL_STRING, 1);
			DFL_BossLaughDurationOffset[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DFL_STRING, 2);

			DFL_AffectsMinions[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DFL_STRING, 3) == 1;
			DFL_DisablesSentries[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DFL_STRING, 4) == 1;
			DFL_SentryDisabledDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DFL_STRING, 5);

			DFL_Flags[clientIdx] = ReadHexOrDecString(bossIdx, DFL_STRING, 6);
        }
		else 
		{
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[Roundstart DFL] Warning: No abilites added. Check config file.");
			}
		}
    }

    if (PPB_ActiveThisRound)
	{
		for (int cupcake = 0; cupcake < MAX_PROPS; cupcake++)
		{
			PPBP_EntRef[cupcake] = INVALID_ENTREF;
            PPBP_Type[cupcake] = -1;
		}
	}


	CreateTimer(0.3, Timer_PostRoundStartInits, _, TIMER_FLAG_NO_MAPCHANGE);
}





public Action Timer_PostRoundStartInits(Handle timer)
{
	// hale suicided
	if (!RoundInProgress)
		return Plugin_Handled;


	if (PPB_ActiveThisRound && PPB_CanUse[BossIndex])
	{
		if (PPB_IsEnabled[BossIndex])
		{
			HookEvent("player_death", PPB_OnKillOrDeath, EventHookMode_Pre);
			if (PRINT_DEBUG_INFO)
			PrintToChatAll("[PPB Init]: Player_Death is now hooked.");
		}
	}

	return Plugin_Handled;
}





public Action Event_RoundEnd(Handle eEvent, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;
	if (DFL_ActiveThisRound)
	{
		DFL_ActiveThisRound = false;
    }   

	if (PPB_ActiveThisRound)
	{
		PPB_Cleanup();
		PPB_ActiveThisRound = false;
	}

    PluginActiveThisRound = false;
	return Plugin_Handled;
}

public PPB_Cleanup()
{
	// unhook player death
	UnhookEvent("player_death", PPB_OnKillOrDeath, EventHookMode_Pre);
	if (PRINT_DEBUG_INFO)
	PrintToChatAll("Player_death unhooked.");
	

	//Clean all these cupckes or they might leak between rounds.
	for (int cupcake = 0; cupcake < MAX_PROPS; cupcake++)
	{
		if (PPBP_EntRef[cupcake] == INVALID_ENTREF)
		continue;

		Timer_RemoveEntity(null, PPBP_EntRef[cupcake]);
		PPBP_EntRef[cupcake] = INVALID_ENTREF;
		PPBP_Type[cupcake] = -1;
	}
}



public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, status) //not sure what type status is?
{
	if (strcmp(plugin_name, this_plugin_name) != 0)
		return Plugin_Continue;
	else if (!RoundInProgress || !PluginActiveThisRound) // don't execute these rages with 0 players alive
		return Plugin_Continue;


	//She has no rages right now. What do I even do here?

    return Plugin_Continue;
}


public Action CmdForceRage(int user, int argsInt)
{
	// get actual args
	char unparsedArgs[ARG_LENGTH];
	int userBoss = GetClientOfUserId(FF2_GetBossUserId(user));
	GetCmdArgString(unparsedArgs, ARG_LENGTH);
	
	// gotta do this
	PrintRageWarning();

	if (!strcmp("laugh", unparsedArgs))
	{
		PrintToConsole(user, "Activating Global Laugh. HAHAHAHAHAHAHA!!!");
		OnDOTAbilityActivated(userBoss);
		return Plugin_Handled;
	}

	if (!strcmp("cupcakes", unparsedArgs))
	{
		PrintToConsole(user, "Yummy cupcakes. Yum.");
		float userPos[3];
		GetClientAbsOrigin(userBoss, userPos);
		PPB_SpawnPropOnVictimDeath(userBoss, userPos);
		return Plugin_Handled;
	}

    PrintToConsole(user, "[Pinkiepie Changes] Rage not found: %s", unparsedArgs);
	return Plugin_Continue;
}



/**
 * DOTs
 */
void DOTPostRoundStartInit()
{
	if (!RoundInProgress)
	{
		PrintToChatAll("DOTPostRoundStartInit() called when the round is over?! Shouldn't be possible!");
		return;
	}
	
	// nothing to do
}
 
void OnDOTAbilityActivated(int clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	if (DFL_CanUse[clientIdx])
	{
		bool willWork = true;
		
		if ((GetEntityFlags(clientIdx) & FL_ONGROUND) == 0)
		willWork = false;

		else if (GetEntityFlags(clientIdx) & (FL_INWATER | FL_SWIM))
		willWork = false;
		
		else if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		willWork = false;
			
		if (!willWork)
		{
			PrintCenterText(clientIdx, "You must be on level ground, not stunned, and not taunting to execute force laugh!");
			CancelDOTAbilityActivation(clientIdx);
			return;
		}
		else
		{
			DOT_GlobalLaugh(clientIdx, DFL_LaughDuration[clientIdx], DFL_BossLaughDurationOffset[clientIdx]);
		}
	}
	else 
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("DFL is somehow not active, rage will not execute.");
		}
	}
}

Action OnDOTAbilityTick(int clientIdx, int tickCount)
{	
	if (!PluginActiveThisRound)
	return;
	//Nothing to do

	//suppress warning
	if (clientIdx || tickCount) { }
	
}

void OnDOTAbilityDeactivated(clientIdx)
{
	if (!PluginActiveThisRound || !IsLivingPlayer(clientIdx)) 
		return;

	//Nothing to do.
	
}

void OnDOTUserDeath(int clientIdx, isInGame)
{
	if (clientIdx || isInGame) 
	{ 
		for (int hahaVictim = 1; hahaVictim < MAX_PLAYERS; hahaVictim++)
		{
			if (GetClientTeam(hahaVictim) != MercTeam)
			continue;

			StopLaughingVictim(null, hahaVictim);
		}
	}
}


/**
 * DOT Force Laugh
 */

public void DOT_GlobalLaugh(int bossIdx, float laughDuration, float laughDurationOffset)
{
	 float offsetDuration = (laughDuration - (laughDurationOffset + 0.1));
	 if (!RoundInProgress)
	 {
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[DOT Global Laugh]: NO ACTIVE ROUND DETECTED AAAAAAAAAAAAAH!!!");
		}
        return;
	 }
	 //Should be easy to do. Just check living players on both sides, force both sides to laugh, end Pinkie's laugh before theirs.
	 //To be on the safe side, i'm going to make it so they laugh repeatidly to deal with shorter laugh taunt cycles.

	if (IsPlayerAlive(bossIdx))
	{
		if ((DFL_Flags[bossIdx] & DFL_FLAG_BOSS_DOES_NOT_LAUGH) == 0)
		{
			ServerCommand("sm_taunt_force @all 463");
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[ForceLaugh] Focing all players to taunt.");
			}
			if (DFL_Flags[BossIndex] & DFL_FLAG_BOSS_KNOCKBACK_IMMUNE_DURING_TAUNT)
			{
				TF2_AddCondition(BossIndex, DEFAULT_CONDITION_BLUE, offsetDuration);
			}
			SetEntityMoveType(BossIndex, MOVETYPE_NONE);
			CreateTimer(offsetDuration, StopLaughingBoss, _, TIMER_FLAG_NO_MAPCHANGE);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[ForceLaugh] Timer for hale created");
			}
			for (int hahaVictim = 1; hahaVictim < MAX_PLAYERS; hahaVictim++)
			{
				if (GetClientTeam(hahaVictim) != MercTeam)
				continue;

				if (!IsLivingPlayer(hahaVictim))
				continue;

				CreateTimer(laughDuration, StopLaughingVictim, hahaVictim, TIMER_FLAG_NO_MAPCHANGE);
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("[ForceLaugh] Timer for victim, %d created.", hahaVictim);
				}
			}
		}
		else if (DFL_AffectsMinions[bossIdx])
		{
			for (int hahaMinion = 1; hahaMinion < MAX_PLAYERS; hahaMinion++)
			{
				int minionIdx = GetClientUserId(hahaMinion);
				if (GetClientTeam(hahaMinion) != BossTeam)
				continue;

				if (DFL_ActiveThisRound && IsLivingPlayer(bossIdx))
				{
					if (IsLivingPlayer(hahaMinion) && FF2_GetBossIndex(hahaMinion) <= -1)
					{
						ServerCommand("sm_taunt_force #%d 463", minionIdx);
						if (PRINT_DEBUG_INFO)
						{
							PrintToChatAll("[ForceLaugh] Timer for minion, %d created.", hahaMinion);
						}
						CreateTimer(offsetDuration, StopLaughingPinkies, hahaMinion, TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
			ServerCommand("sm_taunt_force @red 463");
			for (int hahaVictim = 1; hahaVictim < MAX_PLAYERS; hahaVictim++)
			{
				if (GetClientTeam(hahaVictim) != MercTeam)
				continue;

				CreateTimer(laughDuration, StopLaughingVictim, hahaVictim, TIMER_FLAG_NO_MAPCHANGE);
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("[ForceLaugh] Timer for victim, %d created.", hahaVictim);
				}
			}
		}
		else
		{
			ServerCommand("sm_taunt_force @red 463");
			for (int haVictim = 1; haVictim < MAX_PLAYERS; haVictim++)
			{
				if (GetClientTeam(haVictim) != MercTeam)
				continue;

				CreateTimer(laughDuration, StopLaughingVictim, haVictim, TIMER_FLAG_NO_MAPCHANGE);
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("[ForceLaugh] Timer for victim, %d created.", haVictim);
				}
			}
		}

		if (DFL_DisablesSentries[bossIdx])
		{
			int sentry = -1;
			float stryDisabledTime = 0.0;
			if (DFL_SentryDisabledDuration[bossIdx] <= 0.0)
			{
				stryDisabledTime = offsetDuration;
			}
			else
			{
				stryDisabledTime = DFL_SentryDisabledDuration[bossIdx];
			}
			while ((sentry = FindEntityByClassname(sentry, "obj_sentrygun")) != -1)
			{
				float sentryPos[3];
				float sentryPosNoZ[3];
				GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPos);
				GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPosNoZ);
				sentryPosNoZ[2] = 0.0;
				DSSG_PerformStunFromCoords(bossIdx, sentryPos, 1.0, stryDisabledTime);
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("[ForceLaugh] Sentry, %d tickled into disabled", sentry);
				}
			}
		}
	}
}


public Action StopLaughingVictim(Handle timer, any hahaVictim)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	if (IsLivingPlayer(hahaVictim))
	{
		if (TF2_IsPlayerInCondition(hahaVictim, TFCond_Taunting))
		TF2_RemoveCondition(hahaVictim, TFCond_Taunting);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[ForceLaugh] Victim, %d is no longer laughing.", hahaVictim);
		}
	}
	
	return Plugin_Continue;
}

public Action StopLaughingPinkies(Handle timer, any hahaMinion)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	if (IsLivingPlayer(hahaMinion))
	{
		if (TF2_IsPlayerInCondition(hahaMinion, TFCond_Taunting))
		TF2_RemoveCondition(hahaMinion, TFCond_Taunting);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[ForceLaugh] Minion, %d is no longer laughing.", hahaMinion);
		}
	}

	return Plugin_Continue;
}

public Action StopLaughingBoss(Handle timer)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	if (IsLivingPlayer(BossIndex))
	{
		if (TF2_IsPlayerInCondition(BossIndex, TFCond_Taunting))
		TF2_RemoveCondition(BossIndex, TFCond_Taunting);
		SetEntityMoveType(BossIndex, MOVETYPE_WALK);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[ForceLaugh] Hale is no longer laughing.");
		}

		if (DFL_Flags[BossIndex] & DFL_FLAG_ALLOW_SPEED_BUFF_AFTER_LAUGH)
		{
			TF2_AddCondition(BossIndex, TFCond_SpeedBuffAlly, 3.2);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[ForceLaugh] Hale has been granted speed buff.");
			}
		}
	}
	return Plugin_Continue;
}



public void OnGameFrame()
{
	float curTime = GetEngineTime();
	if (!PluginActiveThisRound || !RoundInProgress)
	return;

	if (PPB_CanUse[BossIndex])
	{
		if (PPB_IsEnabled[BossIndex])
		{
			PPB_ThinkTick(curTime);
		}
	}
}


/**
 * Passive Prop Pickup Buff
 */
public void PPB_SpawnPropOnVictimDeath(int clientIdx, float victimDeathLocation[3])
{
	if (!PluginActiveThisRound) //Stop everything, round over
    {
		if (PRINT_DEBUG_INFO)
        PrintToChatAll("[Prop Pickup Spawn]: NO PLUGIN DETECTED!!!! AAAAAAAAAAAAAH!!!");
        return;
    }
    float cupcakeRadius = PPB_ObjRadius[clientIdx];
    float cupcakeHeight = PPB_ObjHeight[clientIdx];
    float modelScaleValue = ((cupcakeRadius + cupcakeHeight) / 100.0) * 1.2;
		
	int firstCupcake = 0;
	int randomSpawn = GetRandomInt(PPB_MinToSpawn[clientIdx], PPB_MaxToSpawn[clientIdx]);
	int spawnCount = 0;
    if (PPB_Flags[clientIdx] & PPB_FLAG_ENFORCE_ONE_PROP_ONDEATH)
    {
        spawnCount = 1;
        if (PRINT_DEBUG_INFO)
        PrintToChatAll("[Prop Pickup Spawn]: One cupcake per customer! No exceptions! (Spawncount enforced to 1)");
    }
    else
    {
        spawnCount = randomSpawn;
        if (PRINT_DEBUG_INFO)
        PrintToChatAll("[Prop Pickup Spawn]: RNG is funny! This time the spawncount is %d", spawnCount);
    }

	for (int cake = 0; cake < spawnCount; cake++)
	{
		for (; firstCupcake <= MAX_PROPS; firstCupcake++)
		{
            // do nothing if max props have been reached
			if (firstCupcake == MAX_PROPS)
            {
                if (PRINT_DEBUG_INFO)
                PrintToChatAll("[Prop Pickup Loop]: Too many cupcakes!!! No more will spawn now!!! Pinkie sad!");
                break;
            }
			if (PPBP_EntRef[firstCupcake] == INVALID_ENTREF)
            {
                if (PRINT_DEBUG_INFO)
                PrintToChatAll("[Prop Pickup Loop]: The cupcake is invalid!!! NOT AGAIN!!!");
				break;
            }
		}
		
		// no more available to spawn
		if (firstCupcake == MAX_PROPS)
        {
			if (PRINT_DEBUG_INFO)
			PrintToChatAll("[Prop Pickup Spawn]: Max props exceeded!");
			break;
        }

		//create the cupcake. set inital velocity and stuff
		victimDeathLocation[2] += 30.0;
		static float velocity[3];
        if (PPB_Flags[clientIdx] & PPB_FLAG_PROP_SPAWNS_IMMOBILE)
        {
            velocity[0] = 0.0;
            velocity[1] = 0.0;
            velocity[2] = 0.0;
        }
        else 
        {
            velocity[0] = GetRandomFloat(20.0, 70.0);
            velocity[1] = GetRandomFloat(20.0, 70.0);
            velocity[2] = 325.0;
        }

		int cupcake = CreateEntityByName("prop_physics_override");
		if (!IsValidEntity(cupcake))
        {
            if (PRINT_DEBUG_INFO)
            PrintToChatAll("[Prop Pickup Spawn]: Invalid entity! Pickup will not spawn!!");
            return;
        }
	
		// tweak the model (note, its validity has already been verified)
        if (PPB_Flags[clientIdx] & PPB_FLAG_USE_DEFAULT_PROPMODEL)
        {
            PrecacheModel(DEFAULT_PROPBUFF_MODEL);
            SetEntityModel(cupcake, DEFAULT_PROPBUFF_MODEL);
			if (PRINT_DEBUG_INFO)
        	PrintToChatAll("[Prop Pickup Spawn]: Cupcake is a cupcake. DUH!!! (Model set BTW)");
        }
        else if (strlen(PPB_Model) > 3)
        {
            PrecacheModel(PPB_Model);
            SetEntityModel(cupcake, PPB_Model);
			if (PRINT_DEBUG_INFO)
        	PrintToChatAll("[Prop Pickup Spawn]: Specified model set. (Model set BTW)");
        }

		// spawn and move it
		DispatchSpawn(cupcake);
		TeleportEntity(cupcake, victimDeathLocation, view_as<float>({ 0.0, 0.0, 0.0 }), velocity);
        if (PPB_Flags[clientIdx] & PPB_FLAG_MODEL_SCALES_WITH_RADIUS)
        {
            SetEntPropFloat(cupcake, Prop_Send, "m_flModelScale", modelScaleValue);
			if (PRINT_DEBUG_INFO)
        	PrintToChatAll("[Prop Pickup Spawn]: Model scale set to %f", modelScaleValue);
        }
		
        SetEntProp(cupcake, Prop_Data, "m_takedamage", 0);
        // collision, movetype, and scale
        SetEntProp(cupcake, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
		if (PRINT_DEBUG_INFO)
        PrintToChatAll("[Prop Pickup Spawn]: Model is now debris");
        

        //recolor it and set its type based on which type of cupcake it will be.
        int cupcakeType = GetRandomInt(PPB_TYPE_LIME, PPB_TYPE_RASPBERRY);
        switch(cupcakeType)
        {
            case 1: 
            {
                SetEntityColor(cupcake, DEFAULT_PROP_COLOR_GREEN);
                PPBP_Type[firstCupcake] = PPB_TYPE_LIME;
                if (PRINT_DEBUG_INFO)
                PrintToChatAll("[Prop Pickup Spawn]: Cupcake type of this one should be lime! (Green!)");
            }
            
            case 2: 
            {
                SetEntityColor(cupcake, DEFAULT_PROP_COLOR_BLUE);
                PPBP_Type[firstCupcake] = PPB_TYPE_BLUEBERRY;
                if (PRINT_DEBUG_INFO)
                PrintToChatAll("[Prop Pickup Spawn]: Cupcake type of this one should be blueberry! (Blue!)");
            }

            case 3: 
            {
                SetEntityColor(cupcake, DEFAULT_PROP_COLOR_RED);
                PPBP_Type[firstCupcake] = PPB_TYPE_HOTSAUCE;
                if (PRINT_DEBUG_INFO)
                PrintToChatAll("[Prop Pickup Spawn]: Cupcake type of this one should be hot sauce! (Red!)");
            }
        

            case 4: 
            {
                SetEntityColor(cupcake, DEFAULT_PROP_COLOR_VIOLET);
                PPBP_Type[firstCupcake] = PPB_TYPE_RASPBERRY;
                if (PRINT_DEBUG_INFO)
                PrintToChatAll("[Prop Pickup Spawn]: Cupcake type of this one should be raspberry! (Violet!)");
            }
        }
		

		// keep track of this prop
		PPBP_EntRef[firstCupcake] = EntIndexToEntRef(cupcake);
		PPBP_CollisionTestAt[firstCupcake] = PPBP_ActivateAt[firstCupcake] = GetEngineTime() + PPB_ACTIVATION_TIME;
		//PPBP_Owner[firstCupcake] = clientIdx;
        if (PPB_Flags[clientIdx] & PPB_FLAG_PROP_SPAWNS_IMMOBILE)
        {
            PPBP_StopPropMovementAt[firstCupcake] = GetEngineTime() + 1.0;
			if (PRINT_DEBUG_INFO)
            PrintToChatAll("[Prop Pickup Spawn]: Movement immobile stop time set");
        }
        else 
        {
            PPBP_StopPropMovementAt[firstCupcake] = GetEngineTime() + 2.0;
			if (PRINT_DEBUG_INFO)
            PrintToChatAll("[Prop Pickup Spawn]: Movement stop time set");
        }
		
	}
	
}

public void PPB_RemoveObject(int cupcake)
{
	Timer_RemoveEntity(null, PPBP_EntRef[cupcake]);
	PPBP_EntRef[cupcake] = INVALID_ENTREF;
	
	for (int cakeIdx = cupcake; cakeIdx < MAX_PROPS - 1; cakeIdx++)
	{
		PPBP_EntRef[cakeIdx] = PPBP_EntRef[cakeIdx + 1];
        PPBP_Type[cakeIdx] = PPBP_Type[cakeIdx + 1];
		PPBP_ActivateAt[cakeIdx] = PPBP_ActivateAt[cakeIdx + 1];
		//PPBP_Owner[cakeIdx] = PPBP_Owner[cakeIdx + 1];
		PPBP_CollisionTestAt[cakeIdx] = PPBP_CollisionTestAt[cakeIdx + 1];
		PPBP_StopPropMovementAt[cakeIdx] = PPBP_StopPropMovementAt[cakeIdx + 1];
	}
	
	PPBP_EntRef[MAX_PROPS-1] = INVALID_ENTREF;
    PPBP_Type[MAX_PROPS-1] = -1;
	
	if (PRINT_DEBUG_INFO)
    PrintToChatAll("[Prop Pickup Spawn]: Cupcake despawned. I hope.");
	
}

public void PPB_ThinkTick(float curTime)
{
	if (!RoundInProgress)
	return;

	bool defaultSound = (PPB_Flags[BossIndex] & PPB_FLAG_USE_DEFAULT_PROP_PICKUPSOUND) != 0;
	char pickupSound[MAX_SOUND_FILE_LENGTH];
	// perform collision tests, remove dead objects if they exist...
	for (int icake = MAX_PROPS - 1; icake >= 0; icake--)
	{
        int buffType = PPBP_Type[icake];
		if (PPBP_EntRef[icake] == INVALID_ENTREF)
		{
			if (PRINT_DEBUG_SPAM)
			{
				PrintToChatAll("Cupcake prop entref is invalid.");
			}
			continue;
		}

        if (PPBP_Type[icake] == -1)
        {
			if (PRINT_DEBUG_SPAM)
			{
				PrintToChatAll("Cupcake prop type is -1. It did not store properly.");
			}
			continue;
		}
        
		int cupCake = EntRefToEntIndex(PPBP_EntRef[icake]);
		if (!IsValidEntity(cupCake) || !IsLivingPlayer(BossIndex))
		{
			PPB_RemoveObject(icake);
			continue;
		}
		
		if (curTime >= PPBP_ActivateAt[icake] && curTime >= PPBP_CollisionTestAt[icake])
		{
			// test the owner's position
			//int clientIdx = PPBP_Owner[icake];
			static float ownerPos[3];
			static float cupcakePos[3];
			GetClientAbsOrigin(BossIndex, ownerPos);
			GetEntPropVector(cupCake, Prop_Send, "m_vecOrigin", cupcakePos);

			if (PRINT_DEBUG_SPAM)
			{
				PrintToChatAll("The cupcake is now active. Try to pick it up.");
			}

			int fireDuration = 0;
			if (CylinderCollision(cupcakePos, ownerPos, PPB_ObjRadius[BossIndex], cupcakePos[2] - 83.0, cupcakePos[2] + PPB_ObjHeight[BossIndex]))
			{
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("Clynder collision test has passed.");
				}
	
				if (PPB_Flags[BossIndex] & PPB_FLAG_ENFORCE_ONE_BUFF_ACTIVE && PPB_BossBuffedByCupcake[BossIndex])
				{
					if (PRINT_DEBUG_INFO)
            		PrintToChatAll("[Prop Pickup Buff]: Boss is being buffed already! One buff per cupcake! You cannot pick this up now!");
					return;
				}

				// apply conditions based on cupcake type.
				int BossID = GetClientUserId(BossIndex);
				switch (buffType)
                {
                    case PPB_TYPE_LIME: 
                    {
                        if (PPB_Flags[BossIndex] & PPB_FLAG_USE_DEFAULT_PROP_CONDS)
                        {
                            TF2_AddCondition(BossIndex, DEFAULT_CONDITION_GREEN, -1.0);
							if (PRINT_DEBUG_INFO)
            				PrintToChatAll("[Prop Pickup Buff]: Default Lime buff applied. Yum.");
                        }
                        else
                        {
                            TF2_AddCondition(BossIndex, TFCond:PPB_ConditionForGreen[BossIndex], -1.0);
							if (PRINT_DEBUG_INFO)
            				PrintToChatAll("[Prop Pickup Buff]: Lime buff applied. Yum.");
                        }
                    }

                    case PPB_TYPE_BLUEBERRY: 
                    {
						if (PPB_Flags[BossIndex] & PPB_FLAG_USE_DEFAULT_PROP_CONDS)
						{
							TF2_AddCondition(BossIndex, DEFAULT_CONDITION_BLUE);
							if (PRINT_DEBUG_INFO)
            				PrintToChatAll("[Prop Pickup Buff]: Default Blueberry buff applied. Yum.");
						}
						else
						{
							TF2_AddCondition(BossIndex, TFCond:PPB_ConditionForBlue[BossIndex], -1.0);
							if (PRINT_DEBUG_INFO)
            				PrintToChatAll("[Prop Pickup Buff]: Blueberry buff applied. Yum.");
						} 
                    }

                    case PPB_TYPE_HOTSAUCE: 
                    {
						fireDuration = RoundToCeil(PPB_BuffDuration[BossIndex] + 2.0);
						if (PPB_Flags[BossIndex] & PPB_FLAG_USE_DEFAULT_PROP_CONDS)
						{
							TF2_AddCondition(BossIndex, DEFAULT_CONDITION_RED);
							if (PRINT_DEBUG_INFO)
            				PrintToChatAll("[Prop Pickup Buff]: Default HotSauce buff applied. SPICY!!!");
						}
						else
						{
							TF2_AddCondition(BossIndex, TFCond:PPB_ConditionForRed[BossIndex], -1.0);
							if (PRINT_DEBUG_INFO)
            				PrintToChatAll("[Prop Pickup Buff]: HotSauce buff applied. SPICY!!!");
						} 
						TF2Attrib_SetByName(BossIndex, "dmg taken from fire increased", 1.35);
						if (PRINT_DEBUG_INFO)
            			PrintToChatAll("[Prop Pickup Buff]: Fire debuff added! Owie!");
						ServerCommand("sm_forcertd #%d 49 %d", BossID, fireDuration);
						
						if (PRINT_DEBUG_INFO)
            			PrintToChatAll("[Prop Pickup Buff]: Spicy fire breath!!!");
                    }

                    case PPB_TYPE_RASPBERRY: 
                    {
						if (PPB_Flags[BossIndex] & PPB_FLAG_USE_DEFAULT_PROP_CONDS)
						{
							TF2_AddCondition(BossIndex, DEFAULT_CONDITION_VIOLET);
							if (PRINT_DEBUG_INFO)
            				PrintToChatAll("[Prop Pickup Buff]: Raspberry bubblegum!!!");
						}
						else
						{
							TF2_AddCondition(BossIndex, TFCond:PPB_ConditionForViolet[BossIndex], -1.0);
							if (PRINT_DEBUG_INFO)
            				PrintToChatAll("[Prop Pickup Buff]: Raspberry!!!");
						} 
                    }
                }

				/*oh hey, nothing went wrong. play the mapwide sound.*/ 
				pickupSound = (defaultSound ? DEFAULT_PICKUP_SOUND : PPB_PickupSound);
				if (strlen(pickupSound) > 3)
				{
					PseudoAmbientSound(BossIndex, pickupSound, 3);
					if (PRINT_DEBUG_INFO)
					{
						PrintToChatAll("Pickup sound emitted. I think.");
					}
				}

				PPB_BossBuffedByCupcake[BossIndex] = true;
                CreateTimer(PPB_BuffDuration[BossIndex], RemovePropBuffs, BossIndex, TIMER_FLAG_NO_MAPCHANGE);
				
				// this prop has been spent...
				PPB_RemoveObject(icake);
				continue;
			}
			
			PPBP_CollisionTestAt[icake] = curTime + 0.01;
		}
		
		if (curTime >= PPBP_StopPropMovementAt[icake])
		{
			PPBP_StopPropMovementAt[icake] = FAR_FUTURE;
			SetEntityMoveType(icake, MOVETYPE_NONE);
		}
	}
}

public Action RemovePropBuffs(Handle hTimer, any clientIdx)
{
	if (PPB_ActiveThisRound && RoundInProgress)
	{
        if (PPB_Flags[clientIdx] & PPB_FLAG_USE_DEFAULT_PROP_CONDS)
        {
            if (TF2_IsPlayerInCondition(clientIdx, DEFAULT_CONDITION_GREEN))
            TF2_RemoveCondition(clientIdx, DEFAULT_CONDITION_GREEN);

            if (TF2_IsPlayerInCondition(clientIdx, DEFAULT_CONDITION_BLUE))
            TF2_RemoveCondition(clientIdx, DEFAULT_CONDITION_BLUE);

            if (TF2_IsPlayerInCondition(clientIdx, DEFAULT_CONDITION_RED))
            TF2_RemoveCondition(clientIdx, DEFAULT_CONDITION_RED);

            if (TF2_IsPlayerInCondition(clientIdx, DEFAULT_CONDITION_VIOLET))
            TF2_RemoveCondition(clientIdx, DEFAULT_CONDITION_VIOLET);
        }
        else
        {
            if (TF2_IsPlayerInCondition(clientIdx, TFCond:PPB_ConditionForGreen[clientIdx]))
            TF2_RemoveCondition(clientIdx, TFCond:PPB_ConditionForGreen[clientIdx]);

            if (TF2_IsPlayerInCondition(clientIdx, TFCond:PPB_ConditionForBlue[clientIdx]))
            TF2_RemoveCondition(clientIdx, TFCond:PPB_ConditionForBlue[clientIdx]);

            if (TF2_IsPlayerInCondition(clientIdx, TFCond:PPB_ConditionForRed[clientIdx]))
            TF2_RemoveCondition(clientIdx, TFCond:PPB_ConditionForRed[clientIdx]);

            if (TF2_IsPlayerInCondition(clientIdx, TFCond:PPB_ConditionForViolet[clientIdx]))
            TF2_RemoveCondition(clientIdx, TFCond:PPB_ConditionForViolet[clientIdx]);
        }
        TF2Attrib_RemoveByName(clientIdx, "dmg taken from fire increased");
		PPB_BossBuffedByCupcake[clientIdx] = false;

		if (PRINT_DEBUG_INFO)
        PrintToChatAll("[Prop Pickup Buff]: Aww the flavor wore off.");
    }
}




public Action PPB_OnKillOrDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!RoundInProgress || !PPB_ActiveThisRound)
	return Plugin_Handled;
	
    float victimDeathPos[3];
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int killer = GetClientOfUserId(event.GetInt("attacker"));
	bool isSuicide = victim == killer || !IsLivingPlayer(killer);

    if (GetClientTeam(victim) != MercTeam)
	return Plugin_Continue;

    if (PPB_IsEnabled[BossIndex])
    {
		if ((PPB_Flags[BossIndex] & PPB_FLAG_EXCLUDE_SUICIDES) && isSuicide)
		{
			return Plugin_Continue;
		}
		if (PPB_Flags[BossIndex] & PPB_FLAG_EXCLUDE_DEADRINGER_DEATH)
		{
			if ((event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) != 0)
			return Plugin_Continue;
		}
        GetClientAbsOrigin(victim, victimDeathPos);
        PPB_SpawnPropOnVictimDeath(BossIndex, victimDeathPos);
    }

	return Plugin_Continue;
}


// stocks at the bottom.
public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if (IsValidEntity(entity))
		RemoveEntity(entity);

	if (PRINT_DEBUG_INFO)
	PrintToChatAll("[RemoveEntity] Entity is destroyed.");
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

stock int AttachParticle(int entity, const char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	static float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
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

stock bool IsInstanceOf(int entity, const char[] desiredClassname)
{
	char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return strcmp(classname, desiredClassname) == 0;
}

stock int abs(x)
{
	return x < 0 ? -x : x;
}

stock float fabs(Float:x)
{
	return x < 0 ? -x : x;
}

stock int min(n1, n2)
{
	return n1 < n2 ? n1 : n2;
}

stock float fmin(Float:n1, Float:n2)
{
	return n1 < n2 ? n1 : n2;
}

stock int max(n1, n2)
{
	return n1 > n2 ? n1 : n2;
}

stock float fmax(Float:n1, Float:n2)
{
	return n1 > n2 ? n1 : n2;
}

stock float fsquare(Float:x)
{
	return x * x;
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

stock FindRandomPlayer(bool isBossTeam)
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
	float cylrange = GetVectorDistance(tmpVec1, tmpVec2, true);
	float distSquared = maxDistance * maxDistance;
	if (cylrange <= distSquared)
	{
		return true;
	}
	
	return false;
}

stock bool IsLivingPlayer(int clientIdx)
{
    if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
    return false;
	
	return IsPlayerAlive(clientIdx) && IsValidClient(clientIdx);
}


stock bool IsValidClient(int clientIdx, bool isPlayerAlive=false)
{
	if (clientIdx <= 0 || clientIdx > MaxClients) 
    return false;

	if(isPlayerAlive) 
    return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);

	return IsClientInGame(clientIdx);
}

stock bool IsValidBoss(int clientIdx)
{
	if (!IsLivingPlayer(clientIdx, false))
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

stock void SetEntityColor(int iEntity, int iColor[4])
{
	SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEntity, iColor[0], iColor[1], iColor[2], iColor[3]);
}

stock ReadHexOrDecInt(String:hexOrDecString[HEX_OR_DEC_STRING_LENGTH])
{
	if (StrContains(hexOrDecString, "0x") == 0)
	{
		new result = 0;
		for (new i = 2; i < 10 && hexOrDecString[i] != 0; i++)
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
		return StringToInt(hexOrDecString);
}

stock ReadHexOrDecString(bossIdx, const String:ability_name[], argIdx)
{
	static String:hexOrDecString[HEX_OR_DEC_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argIdx, hexOrDecString, HEX_OR_DEC_STRING_LENGTH);
	return ReadHexOrDecInt(hexOrDecString);
}


/**
 * Credit to FlaminSarge (DO NOT COPY THESE TO PACK9!)
 */
Handle hPlayTaunt;
public RegisterForceTaunt()
{
	Handle conf = LoadGameConfigFile("tf2.tauntem");
	if (conf == INVALID_HANDLE)
	{
		PrintToServer("[ForceLaugh] Unable to load gamedata/tf2.tauntem.txt. Guitar Hero DOT will not function.");
		return;
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	hPlayTaunt = EndPrepSDKCall();
	if (hPlayTaunt == INVALID_HANDLE)
	{
		SetFailState("[ForceLaugh] Unable to initialize call to CTFPlayer::PlayTauntSceneFromItem. Need to get updated tf2.tauntem.txt method signatures. Guitar Hero DOT will not function.");
		CloseHandle(conf);
		return;
	}
	CloseHandle(conf);
}

bool congaFailurePrintout = false;
public ForceUserToLaugh(int clientIdx)
{
	if (hPlayTaunt == INVALID_HANDLE)
		return; // return silently
		
	int itemdef = 463; // laugh?
	int ent = MakeCEIVEnt(clientIdx, itemdef);
	if (!IsValidEntity(ent))
	{
		if (!congaFailurePrintout)
		{
			PrintToServer("[ForceLaugh] Could not create shred alert taunt entity.");
			congaFailurePrintout = true;
		}
		return;
	}
	new Address:pEconItemView = GetEntityAddress(ent) + Address:FindSendPropInfo("CTFWearable", "m_Item");
	if (!pEconItemView)
	{
		if (!congaFailurePrintout)
		{
			PrintToServer("[ForceLaugh] Couldn't find CEconItemView for shred alert.");
			congaFailurePrintout = true;
		}
		AcceptEntityInput(ent, "Kill");
		return;
	}
	
	bool success = SDKCall(hPlayTaunt, clientIdx, pEconItemView);
	AcceptEntityInput(ent, "Kill");
	//PrintToServer("Conga entity is %d", ent);
	
	if (!success && PRINT_DEBUG_SPAM)
		PrintToServer("[ForceLaugh] Failed to force %d to shred alert.", clientIdx);
}

stock MakeCEIVEnt(int client, int itemdef)
{
	Handle hItem;
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