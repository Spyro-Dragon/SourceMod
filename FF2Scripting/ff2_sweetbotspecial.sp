// no warranty blah blah don't sue blah blah doing this for fun blah blah...

#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <tf2attributes>
#include <ff2_dynamic_defaults>
#include <tf2>
#include <cw3>
#include <cw3-attributes>


#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required

/**
    SWEETIE BOT TIME!!!! FEAR ME MODE!!!
 */
 
bool DEBUG_FORCE_RAGE = false;
#define ARG_LENGTH 256
 
bool PRINT_DEBUG_INFO = false;
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
int BossIndex;

Handle gravscale;

public Plugin myinfo = {
	name = "VSPR: Sweetie Bot upgrade",
	author = "Spyro. Just Spyro.",
	version = "1.0",
}

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)

/*
 *Everything used for the combat mode special rage.
*/

#define DEFAULT_FF2_WEAPON "SB Energy Baton 0"
#define ROCKETATTACK_WEAPON "SB Rocket Baton 1"
#define IONCANNON_WEAPON "SB IonCannon Baton 2"



//DEFAULT VALUES SO SETTING ARGUMENTS ISNT A PAIN

//Sounds
#define DEFAULT_SOUND_COMBATMODE "hl1/fvox/activated.wav"
#define DEFAULT_SOUND_SCANNING "vs_ponyville/sweetiebot/sweetbot_cmscan.mp3"
#define DEFAULT_SOUND_AMMO_DEPLETED "hl1/fvox/ammo_depleted.wav"
#define DEFAULT_TRANSFORM_SOUND "vs_ponyville/sweetiebot/robot_transform1.mp3" 
#define DEFAULT_ROCKET_FIRINGSOUND "weapons/sentry_rocket.wav"
#define DEFAULT_IONCANNON_FIRINGSOUND "weapons/cow_mangler_main_shot.wav"
#define DEFAULT_IONCANNON_CHARGINGSOUND "vs_ponyville/sweetiebot/beam_charge.mp3"
#define SOUND_SHOCK "sound/ambient/energy/zap1.wav"

//transition model
#define DEFAULT_INITAL_MODEL "models/noname/sweetiebot/sweetiebot.mdl"
#define DEFAULT_COMBAT_MODE_MODEL "models/noname/sweetiebot/sweetiebot_guns2.mdl"
//model attachments
#define DEFAULT_ROCKET_SPAWNATTACHMENT "rocketgroup1;rocketgroup2"
#define DEFAULT_ATTACHMENT_LOCATEREF "crutgun_firstperson" 
#define DEFAULT_IONCANNON_SPAWNATTACHMENT "beamcannon"


//Transition effects
#define DEFAULT_TRANSITION_EFFNAME "ghost_smoke"
#define COMBATMODE_TARGETLASERS_EFFNAME "laser_sight_beam"

//sentry rockets
#define SENTRYROCKET_CLASS "CTFProjectile_SentryRocket"
#define SENTRYROCKET_ENTITY "tf_projectile_sentryrocket"
#define ROCKETTYPE_SENTRY 1

//normal rockets
#define DEFAULT_ROCKET_CLASS "CTFProjectile_Rocket"
#define DEFAULT_ROCKET_ENTITY "tf_projectile_rocket"
#define ROCKETTYPE_DEFAULT 2

//ion cannon
#define ENERGY_SHOT_CLASS "CTFProjectile_EnergyBall"
#define ENERGY_SHOT_ENTITY "tf_projectile_energy_ball"
#define DEFAULT_IONCANNON_EFFNAME "bomb_vortex_skull"
#define ROCKETTYPE_IONCANNON 3



/*
*default values for the rage
*/

//controls
#define DEFAULT_ROCKET_FIRE_BUTTON IN_RELOAD
#define DEFAULT_IONCANNON_FIRE_BUTTON IN_ATTACK2

//max values
#define DEFAULT_MAX_ENERGY 100.0
#define DEFAULT_MAX_ROCKETS 24
#define DEFAULT_MAX_DURATION 15.5

#define DEFAULT_ROCKETFIRE_INTERVAL 0.35
#define DEFAULT_IONCANNON_RECHARGE_TIME 1.7

//consumption/damage values

//rockets
#define DEFAULT_ROCKETS_CONSUMPTION 4
#define DEFAULT_ROCKETS_PLAYERDAMAGE 96.0
#define DEFAULT_ROCKETS_PROJSPEED 1375.0

//ion cannon
#define DEFAULT_IONCANNON_CONSUMPTION 50.0
#define DEFAULT_IONCANNON_DAMAGE 117.0
#define DEFAULT_IONCANNON_PROJSPEED 1250.0
#define DEFAULT_IONCANNON_CHARGEDURATION 1.2

/* I want to try something with Cw3 before trying to deal with this.
#define DEFAULT_MICROMISSILES_BUILDINGDAMAGE 80
#define DEFAULT_ARMORPIERCING_BUILDINGDAMAGE 300
*/





//rage
#define CM_STRING "rage_combat_mode"
#define CM_MAX_ATTACHMENT_POINTS 10
#define MAX_ATTACHMENT_NAME_LENGTH 48
#define CM_ROCKET_POINTS_STR_LENGTH ((CM_MAX_ATTACHMENT_POINTS * (MAX_ATTACHMENT_NAME_LENGTH+1)) + 1)
//flags
#define CM_FLAG_USE_DEFAULT_VALUES 0x0001
#define CM_FLAG_RANDOM_DEFENSIVE_CONDITIONS 0x0002
#define CM_FLAG_ROCKETS_USE_SMART_TARGETING_NOVIEW 0x0004 //NOT TO BE CONFUSED WITH LOCK ON
#define CM_FLAG_ROCKETS_USE_SMART_TARGETING_VIEWREQUIRED 0x0008
#define CM_FLAG_DAMAGE_AIRBLASTING_PYROS 0x0010
#define CM_FLAG_IMMOBILE_CHARGING 0x0020

//Internals
bool CM_ActiveThisRound;
bool CM_CanUse[MAX_PLAYERS_ARRAY];

bool CM_IsActive[MAX_PLAYERS_ARRAY];

/*
bool CM_AbilitySelectKeyDown[MAX_PLAYERS_ARRAY];
bool CM_ModeSelectKeyDown[MAX_PLAYERS_ARRAY];
*/

int CM_LocateParticle_EntRef[MAX_PLAYERS_ARRAY];
int CM_IonCannonCharge_EntRef[MAX_PLAYERS_ARRAY];

int CM_CurTarget[MAX_PLAYERS_ARRAY];
int CM_CurrentWeapon[MAX_PLAYERS_ARRAY];

int CM_RocketFireButton[MAX_PLAYERS_ARRAY];
int CM_IonCannonFireButton[MAX_PLAYERS_ARRAY];

bool CM_RocketFireKeyDown[MAX_PLAYERS_ARRAY];
bool CM_IonCannonFireKeyDown[MAX_PLAYERS_ARRAY];

bool CM_CanFireRockets[MAX_PLAYERS_ARRAY];
bool CM_CanFireIonCannon[MAX_PLAYERS_ARRAY];
bool CM_IonCannonRecharging[MAX_PLAYERS_ARRAY];

int CM_CurRockets[MAX_PLAYERS_ARRAY];
float CM_CurEnergy[MAX_PLAYERS_ARRAY];

int CM_AttachmentEntRef[MAX_PLAYERS_ARRAY][CM_MAX_ATTACHMENT_POINTS]; 
int CM_CurrentAttachmentIdx[MAX_PLAYERS_ARRAY];
int CM_TotalAttachments[MAX_PLAYERS_ARRAY]; 
int CM_IonAttachmentEntRef[MAX_PLAYERS_ARRAY]; // internal, related to arg6

//Handle combat_synchud;
Handle rockets_synchud;
Handle energy_synchud;
Handle ioncannon_statushud;


//arguments
char CM_OriginalModel[MAX_MODEL_FILE_LENGTH];
char CM_TransitionModel[MAX_MODEL_FILE_LENGTH];
char CM_TransitionSound[MAX_SOUND_FILE_LENGTH];
char CM_RocketsFiringSound[MAX_SOUND_FILE_LENGTH];
char CM_IonCannonFiringSound[MAX_SOUND_FILE_LENGTH];
char CM_IonCannonChargingSound[MAX_SOUND_FILE_LENGTH];

bool CM_EnableTargetingLasers[MAX_PLAYERS_ARRAY];
bool CM_RocketIsSentry[MAX_PLAYERS_ARRAY];

int CM_RocketFireKey[MAX_PLAYERS_ARRAY];
int CM_IonCannonFireKey[MAX_PLAYERS_ARRAY];

float CM_Duration[MAX_PLAYERS_ARRAY];
int CM_MaxRockets[MAX_PLAYERS_ARRAY];
float CM_MaxEnergy[MAX_PLAYERS_ARRAY];

float CM_RocketFireInterval[MAX_PLAYERS_ARRAY];
float CM_IonCannonRechargeDuration[MAX_PLAYERS_ARRAY];
int CM_RocketsConsumption[MAX_PLAYERS_ARRAY];
float CM_RocketsProjectileSpeed[MAX_PLAYERS_ARRAY];
float CM_RocketsPlayerDmg[MAX_PLAYERS_ARRAY];

float CM_IonCannonChargeDuration[MAX_PLAYERS_ARRAY];
float CM_IonCannonConsumption[MAX_PLAYERS_ARRAY];
float CM_IonCannonDamage[MAX_PLAYERS_ARRAY];
float CM_IonCannonProjSpeed[MAX_PLAYERS_ARRAY];

int CM_Flags[MAX_PLAYERS_ARRAY];

//Water electrocution
#define PWE_STRING "passive_water_electrocution"
#define PWE_BUILDING_SPARKEFFECT "buildingdamage_spark2"
#define MAX_WATER_BUILDINGS 20
#define PWE_ELECTROCUTE_INTERVAL 0.85
//flags
#define PWE_FLAG_AFFECTS_UBERED_PLAYERS 0x0001
#define PWE_FLAG_DISABLES_ENERGY_WEAPONS 0x0002
#define PWE_FLAG_DISABLES_SUBMERGED_BUILDINGS 0x0004
#define PWE_FLAG_JARATEMILK_ELECTROCUTE_ONTOUCH 0x0008

//internals
bool PWE_ActiveThisRound;
bool PWE_CanUse[MAX_PLAYERS_ARRAY];

bool PWE_IsBossInWater[MAX_PLAYERS_ARRAY];
bool PWE_IsVictimInWater[MAX_PLAYERS_ARRAY];

bool PWE_IsVictimBeingShocked[MAX_PLAYERS_ARRAY];
float PWE_DamagePlayerAt[MAX_PLAYERS_ARRAY];


// arguments
bool PWE_IsEnabled[MAX_PLAYERS_ARRAY];

float PWE_DamageRadius[MAX_PLAYERS_ARRAY];
float PWE_DamagePerFrame[MAX_PLAYERS_ARRAY];

bool PWE_SlowAffectedPlayers[MAX_PLAYERS_ARRAY];
float PWE_SlowAmount[MAX_PLAYERS_ARRAY];

int PWE_Flags[MAX_PLAYERS_ARRAY];




/**
 * METHODS REQUIRED BY ff2 subplugin
 */
void PrintRageWarning()
{
	PrintToConsoleAll("*********************************************************************");
	PrintToConsoleAll("*                             WARNING                               *");
	PrintToConsoleAll("*       DEBUG_FORCE_RAGE in ff2_Sweetiebotspecial.sp is set to true!*");
	PrintToConsoleAll("*  Any admin can use the 'rage' command to use rages in this pack!  *");
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
	if (DEBUG_FORCE_RAGE)
	{
		PrintRageWarning();
		RegAdminCmd(CMD_FORCE_RAGE, CmdForceRage, ADMFLAG_GENERIC);
	}
	//combat_synchud = CreateHudSynchronizer();
	energy_synchud = CreateHudSynchronizer();
	rockets_synchud = CreateHudSynchronizer();
	ioncannon_statushud = CreateHudSynchronizer();
	gravscale = FindConVar("sv_gravity");
}


public void OnMapStart()
{
	PrecacheSound(DEFAULT_SOUND_AMMO_DEPLETED, true);
	PrecacheSound(DEFAULT_SOUND_COMBATMODE, true);
	PrecacheSound(DEFAULT_SOUND_SCANNING, true);
	PrecacheSound(DEFAULT_ROCKET_FIRINGSOUND, true);
	PrecacheSound(DEFAULT_IONCANNON_FIRINGSOUND, true);
	PrecacheSound(DEFAULT_IONCANNON_CHARGINGSOUND, true);
	PrecacheSound(DEFAULT_TRANSFORM_SOUND, true);
	PrecacheSound(SOUND_SHOCK, true);

	PrecacheModel(DEFAULT_COMBAT_MODE_MODEL);
	PrecacheModel(DEFAULT_INITAL_MODEL);
}



public Action Event_RoundStart(Handle hEvent, const char[] name, bool dontBroadcast)
{
    RoundInProgress = true;
	PluginActiveThisRound = false;

    //Ability global inits 
    CM_ActiveThisRound = false;
    PWE_ActiveThisRound = false;


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

        //Combat mode
        CM_CanUse[clientIdx] = false;
		CM_IsActive[clientIdx] = false;

        CM_RocketFireKeyDown[clientIdx] = false;
        CM_IonCannonFireKeyDown[clientIdx] = false;

		CM_CanFireRockets[clientIdx] = false;
		CM_CanFireIonCannon[clientIdx] = false;
		CM_IonCannonRecharging[clientIdx] = false;

        CM_RocketFireInterval[clientIdx] = 0.0;
		CM_CurrentAttachmentIdx[clientIdx] = 0;
		CM_IonAttachmentEntRef[clientIdx] = INVALID_ENTREF;
		CM_IonCannonCharge_EntRef[clientIdx] = INVALID_ENTREF;
		CM_LocateParticle_EntRef[clientIdx] = INVALID_ENTREF;
		CM_TotalAttachments[clientIdx] = 1; 
		CM_CurrentWeapon[clientIdx] = 0;

		CM_CurRockets[clientIdx] = 0;
		CM_CurEnergy[clientIdx] = 0.0;

		CM_CurTarget[clientIdx] = INVALID_ENTREF;

        //Water electrocution
        PWE_CanUse[clientIdx] = false;
        PWE_IsEnabled[clientIdx] = false;
        PWE_IsBossInWater[clientIdx] = false;
        PWE_IsVictimInWater[clientIdx] = false;
        PWE_DamagePlayerAt[clientIdx] = FAR_FUTURE;
		

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


		if (FF2_HasAbility(bossIdx, this_plugin_name, CM_STRING))
		{
			CM_ActiveThisRound = true;
			PluginActiveThisRound = true;
			CM_CanUse[clientIdx] = true;
			BossIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

			ReadModel(bossIdx, CM_STRING, 1, CM_OriginalModel);
			ReadModel(bossIdx, CM_STRING, 2, CM_TransitionModel);
			ReadSound(bossIdx, CM_STRING, 3, CM_TransitionSound);
			ReadSound(bossIdx, CM_STRING, 4, CM_RocketsFiringSound);
			ReadSound(bossIdx, CM_STRING, 5, CM_IonCannonFiringSound);
			ReadSound(bossIdx, CM_STRING, 6, CM_IonCannonChargingSound);

			CM_EnableTargetingLasers[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CM_STRING, 7) == 1;
			CM_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 8);

            CM_RocketIsSentry[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CM_STRING, 9) == 1;

            CM_RocketFireKey[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CM_STRING, 10);
            CM_IonCannonFireKey[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CM_STRING, 11);

			CM_MaxRockets[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CM_STRING, 12);
			CM_MaxEnergy[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 13);

			CM_RocketFireInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 14);
			CM_IonCannonRechargeDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 15);

			CM_RocketsConsumption[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CM_STRING, 16);
			CM_RocketsProjectileSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 17);
			CM_RocketsPlayerDmg[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 18);
			
			CM_IonCannonChargeDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 19);
			CM_IonCannonConsumption[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 20);
			CM_IonCannonDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 21);
			CM_IonCannonProjSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CM_STRING, 22);

			CM_Flags[clientIdx] = ReadHexOrDecString(bossIdx, CM_STRING, 23);
		}


        if (FF2_HasAbility(bossIdx, this_plugin_name, PWE_STRING))
		{
		    PWE_ActiveThisRound = true;
			PluginActiveThisRound = true;
			PWE_CanUse[clientIdx] = true;
			BossIndex = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

            PWE_IsEnabled[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PWE_STRING, 1) == 1;

            PWE_DamageRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PWE_STRING, 2);
            PWE_DamagePerFrame[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PWE_STRING, 3);

            PWE_SlowAffectedPlayers[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PWE_STRING, 4) == 1;
            PWE_SlowAmount[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PWE_STRING, 5);

            PWE_Flags[clientIdx] = ReadHexOrDecString(bossIdx, PWE_STRING, 6);
        }

    }
	CreateTimer(0.3, Timer_PostRoundStartInits, _, TIMER_FLAG_NO_MAPCHANGE);
}


public Action Timer_PostRoundStartInits(Handle timer)
{
	int clientIdx = BossIndex;
	bool defaultSettings = (CM_Flags[clientIdx] & CM_FLAG_USE_DEFAULT_VALUES) != 0;
	int controlValue_R = (defaultSettings ? DEFAULT_ROCKET_FIRE_BUTTON : CM_GetFireKey(CM_RocketFireKey[clientIdx]));
	int controlValue_IC = (defaultSettings ? DEFAULT_IONCANNON_FIRE_BUTTON : CM_GetFireKey(CM_IonCannonFireKey[clientIdx]));
	// hale suicided
	if (!RoundInProgress)
		return Plugin_Handled;

    if (CM_ActiveThisRound)
    {
        CM_WeaponSwap(BossIndex, 3);
        CM_RocketFireButton[clientIdx] = controlValue_R;
        CM_IonCannonFireButton[clientIdx] = controlValue_IC;

        CM_IonCannonFireKeyDown[clientIdx] = (GetClientButtons(clientIdx) & CM_RocketFireButton[clientIdx]) != 0;
		CM_RocketFireKeyDown[clientIdx] = (GetClientButtons(clientIdx) & CM_IonCannonFireButton[clientIdx]) != 0;

		if (CM_Flags[BossIndex] & CM_FLAG_DAMAGE_AIRBLASTING_PYROS)
		{
			HookEvent("object_deflected", CM_IC_OnDeflect, EventHookMode_Pre);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[RoundStart] object_deflected hooked. Pyro airblast flag is active");
			}
		}
    }

    if (PWE_IsEnabled[BossIndex])
    {
        PWE_DamagePlayerAt[BossIndex] = GetEngineTime();
		if (PWE_Flags[BossIndex] & PWE_FLAG_DISABLES_SUBMERGED_BUILDINGS)
		{
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[PWE]: Diable buildings flag active.");
			}
			CreateTimer(2.0, PWE_FindAndDisableSentry, _, TIMER_REPEAT);
		}

		if (PWE_Flags[BossIndex] & PWE_FLAG_JARATEMILK_ELECTROCUTE_ONTOUCH)
		{
			SDKHook(BossIndex, SDKHook_StartTouch, PWE_JarateMilk_OnTouch);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[PWE]: PlayerTouch hooked.");
			}
		}
    }

	return Plugin_Handled;
}


public Action Event_RoundEnd(Handle eEvent, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;
	if (CM_ActiveThisRound)
	{
		CM_ActiveThisRound = false;
		if (CM_Flags[BossIndex] & CM_FLAG_DAMAGE_AIRBLASTING_PYROS)
		{
			UnhookEvent("object_deflected", CM_IC_OnDeflect, EventHookMode_Pre);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[RoundEnd] object_deflected unhooked. Pyro airblast flag is active");
			}
		}
    }   

    if (PWE_ActiveThisRound)
    {
        PWE_ActiveThisRound = false;
		if (PWE_Flags[BossIndex] & PWE_FLAG_JARATEMILK_ELECTROCUTE_ONTOUCH)
		{
			SDKUnhook(BossIndex, SDKHook_StartTouch, PWE_JarateMilk_OnTouch);
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[PWE]: PlayerTouch unhooked.");
			}
		}
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
	return Plugin_Continue;


	if (!strcmp(ability_name, CM_STRING))
	{
		CM_Initalize(clientBoss);
	}

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

	if (!strcmp("FEARMEINSTEAD", unparsedArgs))
	{
		CM_Initalize(userBoss);
		PrintToChat(user, "LOVE ME WORLD!!! OR ELSE!!!");
		return Plugin_Handled;
    }


    PrintToChat(user, "[SweetieBot]: Rage not found: %s", unparsedArgs);
	return Plugin_Continue;
}

//Hello console spam my old friend....
public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, float vel[3], float vAng[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	float curTime = GetEngineTime();
	if (!PluginActiveThisRound || !RoundInProgress)
	return Plugin_Continue;

	if (CM_ActiveThisRound && CM_CanUse[clientIdx])
	{
        if (CM_IsActive[clientIdx])
        {
            CM_RunCmd(clientIdx, buttons);
            CM_HUDRocketsTick(curTime);
            CM_HUDEnergyTick(curTime);
			CM_HUDIonStatusTick(curTime);
        }
	}

	return Plugin_Continue;
}

public void OnGameFrame()
{
    float curTime = GetEngineTime();
	if (PWE_ActiveThisRound && PWE_IsEnabled[BossIndex])
	{
		PWE_Tick(curTime);
	}
}


int CM_GetFireKey(int keyIdx)
{
    if (keyIdx == 1)
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("Reload key (Default R) used to fire this ability.");
        }
        return IN_RELOAD;
    }
    else if (keyIdx == 2)
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("Alt-fire key (Attack2, default MOUSE2) used to fire this ability.");
        }
        return IN_ATTACK2;
    }
    else if (keyIdx == 3)
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("Special Attack key (Attacke, default MIDDLE MOUSE) used to fire this ability.");
        }
        return IN_ATTACK3;
    }
    else if (keyIdx == 4)
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("Action slot key (Use key, default V) used to fire this ability.");
        }
        return IN_USE;
    }
    else
    {
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("No key specified for this ability. Defaulting to reload key/default keys.");
        }
    }

    return IN_RELOAD;
}

//HUD related stuffs are managed within the next two functions.

//These HUD functions manages rockets and energy abilites
public void CM_HUDRocketsTick(float curTime)
{ 
	if (!RoundInProgress || !CM_ActiveThisRound)
	return;

	float updateStatusHudAt = curTime;
    if (curTime >= updateStatusHudAt)
    {
        if (!CM_IsActive[BossIndex])
        {
            ShowSyncHudText(BossIndex, rockets_synchud, "");
            return;
        }

		if (CM_CurRockets[BossIndex] > 0)
		{
			SetHudTextParams(0.71, 0.84, 0.02, 0, 200, 100, 255, 0, 6.0, 0.1, 0.2); //X, Y, Red, Blue, Green, Alpha, Effect (1- fade 2-blink), effect time, fade in time, fadeout time.) 
			ShowSyncHudText(BossIndex, rockets_synchud, "Rockets Remaining:[%d]", CM_CurRockets[BossIndex]);
		}
		else if (CM_CurRockets[BossIndex] <= 0)
		{
			CM_CurRockets[BossIndex] = 0;
			SetHudTextParams(0.71, 0.84, 0.02, 200, 0, 20, 255, 0, 6.0, 0.1, 0.2); //X, Y, Red, Blue, Green, Alpha, Effect (1- fade 2-blink), effect time, fade in time, fadeout time.) 
			ShowSyncHudText(BossIndex, rockets_synchud, "Rockets Remaining:[DEPLETED]");
		}
    }
    updateStatusHudAt = curTime;
}

public void CM_HUDEnergyTick(float curTime)
{ 
    if (!RoundInProgress || !CM_ActiveThisRound)
	return;
    
    float updateEnergyHudAt = curTime;
    if (curTime >= updateEnergyHudAt)
    {
        if (!CM_IsActive[BossIndex])
        {
            ShowSyncHudText(BossIndex, energy_synchud, "");
            return;
        }

		if (CM_CurEnergy[BossIndex] > 0.0)
		{
			SetHudTextParams(0.71, 0.71, 0.03, 0, 160, 90, 255, 0, 6.0, 0.1, 0.2); 
        	ShowSyncHudText(BossIndex, energy_synchud, "Energy Remaining:[%.1f]", CM_CurEnergy[BossIndex]);
		}
		else if (CM_CurEnergy[BossIndex] <= 0.0)
		{
			CM_CurEnergy[BossIndex] = 0.0;
			SetHudTextParams(0.71, 0.71, 0.03, 175, 15, 10, 255, 0, 6.0, 0.1, 0.2); 
        	ShowSyncHudText(BossIndex, energy_synchud, "Energy Remaining:[DEPLETED]");
		} 
    }
    updateEnergyHudAt = curTime;
}

public void CM_HUDIonStatusTick(float curTime)
{ 
    if (!RoundInProgress || !CM_ActiveThisRound)
	return;
    
    float updateIonHudAt = curTime;
	static char ionCannonStatus[16];
    if (curTime >= updateIonHudAt)
    {
        if (!CM_IsActive[BossIndex])
        {
            ShowSyncHudText(BossIndex, ioncannon_statushud, "");
            return;
        }

		if (CM_CurEnergy[BossIndex] <= 0.0)
		{
			ShowSyncHudText(BossIndex, ioncannon_statushud, "");
			return;
		}

		if (CM_CanFireIonCannon[BossIndex])
		{
			SetHudTextParams(0.71, 0.77, 0.03, 0, 160, 90, 255, 0, 6.0, 0.1, 0.2); 
			Format(ionCannonStatus, sizeof(ionCannonStatus), "READY TO FIRE");
		}
		else 
		{
			SetHudTextParams(0.71, 0.77, 0.03, 175, 10, 10, 255, 0, 6.0, 0.1, 0.2); 
			Format(ionCannonStatus, sizeof(ionCannonStatus), "RECHARGING...");
		}

        ShowSyncHudText(BossIndex, ioncannon_statushud, "Ion Cannon Status:[%s]", ionCannonStatus);
    }
    updateIonHudAt = curTime;
}



//Transition models, and inital sounds go here.
public void CM_Initalize(int bossIdx)
{
    bool defaultValues = (CM_Flags[BossIndex] & CM_FLAG_USE_DEFAULT_VALUES) != 0;
    float combatDuration = (defaultValues ? DEFAULT_MAX_DURATION : (CM_Duration[bossIdx] + 1.0));
	int randomDefcons;
	char transformSound[MAX_SOUND_FILE_LENGTH];
	char clientSound[MAX_SOUND_FILE_LENGTH];
	//first set this to true.
	CM_IsActive[bossIdx] = true;

    //print center text
    PrintCenterText(BossIndex, "Combat Mode: ENGAGED");

	//Play transform sound
	transformSound = (defaultValues ? DEFAULT_TRANSFORM_SOUND : CM_TransitionSound);
	if (strlen(transformSound) > 3)
	{
		PseudoAmbientSound(bossIdx, transformSound, 2);
	}
	

	//Now start by changing the model
	if (CM_Flags[bossIdx] & CM_FLAG_USE_DEFAULT_VALUES)
	{
		SetVariantString(DEFAULT_COMBAT_MODE_MODEL);
		AcceptEntityInput(bossIdx, "SetCustomModel");
		SetEntProp(bossIdx, Prop_Send, "m_bUseClassAnimations", 1);
	}
	else if (strlen(CM_TransitionModel) > 3)
	{
		SetVariantString(CM_TransitionModel);
		AcceptEntityInput(bossIdx, "SetCustomModel");
		SetEntProp(bossIdx, Prop_Send, "m_bUseClassAnimations", 1);
	}

	// do the particle effect after model swap
	static char bestParticle[MAX_EFFECT_NAME_LENGTH];
	bestParticle = DEFAULT_TRANSITION_EFFNAME;
	if (!IsEmptyString(bestParticle))
	{
		static float bossPos[3];
		GetEntPropVector(bossIdx, Prop_Data, "m_vecOrigin", bossPos);
		bossPos[2] += 41.5;
		ParticleEffectAt(bossPos, bestParticle, 1.0);
	}

	//create attachments for the rockets. Ion cannon is done at the time of firing it.
	static char rocketAttachments[CM_ROCKET_POINTS_STR_LENGTH] = DEFAULT_ROCKET_SPAWNATTACHMENT;
	CM_TotalAttachments[bossIdx] = 0;
	static char splitAttachments[CM_MAX_ATTACHMENT_POINTS][MAX_ATTACHMENT_NAME_LENGTH];
	int strCount = ExplodeString(rocketAttachments, ";", splitAttachments, CM_MAX_ATTACHMENT_POINTS, MAX_ATTACHMENT_NAME_LENGTH);
	for (int attachment = 0; attachment < strCount && attachment < CM_MAX_ATTACHMENT_POINTS; attachment++)
	{
		if (!IsEmptyString(splitAttachments[attachment]))
		{
			int effect = AttachParticleToAttachment(bossIdx, DEFAULT_ATTACHMENT_LOCATEREF, splitAttachments[attachment]);
			if (IsValidEntity(effect))
			{
				CM_AttachmentEntRef[bossIdx][attachment] = EntIndexToEntRef(effect);
				CM_LocateParticle_EntRef[bossIdx] = EntIndexToEntRef(effect);
				CM_TotalAttachments[bossIdx]++;
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("[CM_Init]: Rocket attachments found:%d", CM_TotalAttachments[bossIdx]);
				}
			}
			else
            {
                CM_AttachmentEntRef[bossIdx][CM_TotalAttachments[bossIdx]] = INVALID_ENTREF;
            }	
		}
	}	

	if (CM_TotalAttachments[bossIdx] == 0)
	{
		CM_TotalAttachments[bossIdx] = 2;
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[CM_Init]: WARNING: No attachment points specified for ordinary rockets with rocket barrage. Will behave oddly.");
			PrintToChatAll("[CM_Init]: WARNING: Attachment points not specified. Defaulting to default value of %d total attachments.", CM_TotalAttachments[bossIdx]);
		}
	}
	

	//Play the inital sound for the client. Mapwide rage sounds already handled by FF2.
	clientSound = (defaultValues ? DEFAULT_SOUND_COMBATMODE : CM_TransitionSound);
	if (strlen(clientSound) > 3)
	{
		EmitSoundToClient(bossIdx, clientSound);
		CreateTimer(1.8, PlaySecondSoundAt, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
	}

	if (CM_Flags[bossIdx] & CM_FLAG_USE_DEFAULT_VALUES)
	{
		CM_CurRockets[bossIdx] = DEFAULT_MAX_ROCKETS;
		CM_CurEnergy[bossIdx] = DEFAULT_MAX_ENERGY;
	}
	else
	{
		CM_CurRockets[bossIdx] = CM_MaxRockets[bossIdx];
		CM_CurEnergy[bossIdx] = CM_MaxEnergy[bossIdx];
	}

	//Are we allowing random defensive conditions on this hale?
	if (CM_Flags[bossIdx] & CM_FLAG_RANDOM_DEFENSIVE_CONDITIONS)
	{
		randomDefcons = GetRandomInt(1, 4);
		switch (randomDefcons)
		{
			case 1: TF2_AddCondition(bossIdx, TFCond_DefenseBuffed, -1.0);

			case 2: TF2_AddCondition(bossIdx, TFCond_DefenseBuffed, -1.0);

			case 3: TF2_AddCondition(bossIdx, TFCond_RuneResist, -1.0);

			case 4: TF2_AddCondition(bossIdx, TFCond_DefenseBuffMmmph, -1.0);
		}

		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Random defensive, %d given to hale.", randomDefcons);
		}
	}

	///They are now allowed to fire rockets and ion cannon
	CM_CurrentAttachmentIdx[bossIdx] = 0;
	CM_CanFireRockets[bossIdx] = true;
	CM_CanFireIonCannon[bossIdx] = true;
	CM_IonCannonRecharging[bossIdx] = false;

	//Start the timer
	CreateTimer(combatDuration, Disable_Combatmode, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
}

public Action PlaySecondSoundAt(Handle hTimer, any bossIdx)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	char secondSound[MAX_SOUND_FILE_LENGTH];
	if (IsLivingPlayer(bossIdx))
	{
		if (CM_Flags[BossIndex] & CM_FLAG_USE_DEFAULT_VALUES)
		{
			secondSound = DEFAULT_SOUND_SCANNING;
			if (strlen(secondSound) > 3)
			{	
				EmitSoundToClient(bossIdx, secondSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
				if (PRINT_DEBUG_INFO)
				{
					PrintToChatAll("Playing second sound <scanning>");
				}
			}
		}
		else 
		{
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("Default values flag not set. Intended second sound will not play.");
			}
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public Action Disable_Combatmode(Handle hTimer, any bossIdx)
{
	bool valuesDefault = (CM_Flags[BossIndex] & CM_FLAG_USE_DEFAULT_VALUES) != 0;
	char revertSound[MAX_SOUND_FILE_LENGTH];
	if (!RoundInProgress || !CM_ActiveThisRound)
	return Plugin_Handled;

	//is it already disabled? Gotta be sure.
	if (!CM_IsActive[bossIdx])
	return Plugin_Continue;

	//first set this and other things to false. And set the two variables to 0.
	CM_IsActive[bossIdx] = false;
	CM_CanFireRockets[bossIdx] = false;
	CM_CanFireIonCannon[bossIdx] = false;
	CM_CurRockets[bossIdx] = 0;
	CM_CurEnergy[bossIdx] = 0.0;

	//Remove defensive conditions if flag is set and they have them.
	if (CM_Flags[bossIdx] & CM_FLAG_RANDOM_DEFENSIVE_CONDITIONS)
	{
		if (TF2_IsPlayerInCondition(bossIdx, TFCond_DefenseBuffed) || TF2_IsPlayerInCondition(bossIdx, TFCond_RuneResist) || TF2_IsPlayerInCondition(bossIdx, TFCond_DefenseBuffMmmph))
		{
			TF2_RemoveCondition(bossIdx, TFCond_DefenseBuffed);
			TF2_RemoveCondition(bossIdx, TFCond_RuneResist);
			TF2_RemoveCondition(bossIdx, TFCond_DefenseBuffMmmph);
		}
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Defensive buff removed.");
		}
	}

    //print center text
    PrintCenterText(BossIndex, "Combat Mode: DISENGAGED");

	//Give them back the stock ff2 melee
	CM_WeaponSwap(BossIndex, 3);

	//Play transform sound again
	revertSound = (valuesDefault ? DEFAULT_TRANSFORM_SOUND : CM_TransitionSound);
	if (strlen(revertSound) > 3)
	{
		PseudoAmbientSound(bossIdx, revertSound, 2);
	}

	//Now  change the model back
	if (CM_Flags[bossIdx] & CM_FLAG_USE_DEFAULT_VALUES)
	{
		SetVariantString(DEFAULT_INITAL_MODEL);
		AcceptEntityInput(bossIdx, "SetCustomModel");
		SetEntProp(bossIdx, Prop_Send, "m_bUseClassAnimations", 1);
	}
	else if (strlen(CM_OriginalModel) > 3)
	{
		SetVariantString(CM_OriginalModel);
		AcceptEntityInput(bossIdx, "SetCustomModel");
		SetEntProp(bossIdx, Prop_Send, "m_bUseClassAnimations", 1);
	}

	// do the particle effect after model swap
	static char bestParticle[MAX_EFFECT_NAME_LENGTH];
	bestParticle = DEFAULT_TRANSITION_EFFNAME;
	if (!IsEmptyString(bestParticle))
	{
		static float bossPos[3];
		GetEntPropVector(bossIdx, Prop_Data, "m_vecOrigin", bossPos);
		bossPos[2] += 41.5;
		ParticleEffectAt(bossPos, bestParticle, 1.0);
	}

	//Delete leftover particles
	Timer_RemoveEntity(null, CM_LocateParticle_EntRef[bossIdx]);
	Timer_RemoveEntity(null, CM_IonCannonCharge_EntRef[bossIdx]);
	CM_LocateParticle_EntRef[bossIdx] = INVALID_ENTREF;
	CM_IonCannonCharge_EntRef[bossIdx] = INVALID_ENTREF;

	return Plugin_Continue;
}


public void CM_WeaponSwap(int bossIdx, int weaponType)
{
	if (!RoundInProgress || !CM_ActiveThisRound)
	{
		CW3_EquipItemByName(bossIdx, "SB Stock Melee 0");
		return;
	}

	if (weaponType == CM_CurrentWeapon[bossIdx])
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[WeaponSwap]: Weapon type is already equipped. Returning...");
		}
		return;
	}

	if (IsPlayerAlive(bossIdx))
	{
		switch (weaponType)
		{
			case 1: CW3_EquipItemByName(bossIdx, ROCKETATTACK_WEAPON);

			case 2: CW3_EquipItemByName(bossIdx, IONCANNON_WEAPON);

			case 3: CW3_EquipItemByName(bossIdx, DEFAULT_FF2_WEAPON);
		}

		CM_CurrentWeapon[bossIdx] = weaponType;

        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[Weapon swap] Equipping weapon type %d", weaponType);
        }
	}
	else 
	{
        if (PRINT_DEBUG_INFO)
        {
            PrintToChatAll("[Weapon swap] Hale is dead, wha?");
        }
		return;
	}
}

//Commands to deploy weapons are managed here.
public void CM_RunCmd(int bossIdx, int buttons)
{
	int rocketSpawn = -1;
	bool defaultValue = (CM_Flags[bossIdx] & CM_FLAG_USE_DEFAULT_VALUES) != 0;
	float fireNextRocketAt = (defaultValue ?  DEFAULT_ROCKETFIRE_INTERVAL : (CM_RocketFireInterval[bossIdx] + 0.2));
	if (!RoundInProgress || !CM_ActiveThisRound)
	return;

	if (!CM_IsActive[bossIdx])
	return; 
	
	if (CM_CurEnergy[bossIdx] == 0.0 && CM_CurRockets[bossIdx] == 0)
	{
		Disable_Combatmode(null, bossIdx);
	}
	
	bool ionCannonFireDown = (buttons & CM_IonCannonFireButton[bossIdx]) != 0;
    bool rocketFireDown = (buttons & CM_RocketFireButton[bossIdx]) != 0;
    if (rocketFireDown && !CM_RocketFireKeyDown[bossIdx] && CM_CanFireRockets[bossIdx])
    {
        bool useSentryRocket = CM_RocketIsSentry[bossIdx];
		int rocketType = 0;
        if (CM_CurRockets[bossIdx] > 0)
        {
            rocketSpawn = EntRefToEntIndex(CM_AttachmentEntRef[bossIdx][CM_CurrentAttachmentIdx[bossIdx]]);
			rocketType = (useSentryRocket ? ROCKETTYPE_SENTRY : ROCKETTYPE_DEFAULT);
            CM_WeaponSwap(bossIdx, 1);
            if (CM_Flags[bossIdx] & CM_FLAG_USE_DEFAULT_VALUES)
            {
                CM_CreateRocket(bossIdx, DEFAULT_ROCKETS_PLAYERDAMAGE, DEFAULT_ROCKETS_PROJSPEED, ROCKETTYPE_SENTRY, rocketSpawn);
				CM_CurRockets[bossIdx] -= DEFAULT_ROCKETS_CONSUMPTION;
            }
            else
            {
                CM_CreateRocket(bossIdx, CM_RocketsPlayerDmg[bossIdx], CM_RocketsProjectileSpeed[bossIdx], rocketType, rocketSpawn);
				CM_CurRockets[bossIdx] -= CM_RocketsConsumption[bossIdx];
            }
			CM_CurrentAttachmentIdx[bossIdx] = ((CM_CurrentAttachmentIdx[bossIdx] + 1) % CM_TotalAttachments[bossIdx]);
			CM_CanFireRockets[bossIdx] = false;
			CreateTimer(fireNextRocketAt, AllowRocketFire, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
        }
		else if (CM_CurRockets[bossIdx] <= 0)
		{
			CM_CurRockets[bossIdx] = 0;
			EmitSoundToClient(BossIndex, DEFAULT_SOUND_AMMO_DEPLETED);
			PrintCenterText(bossIdx, "Your rockets are depleted!!");
		}
    }
	CM_RocketFireKeyDown[bossIdx] = rocketFireDown;
        
    if (ionCannonFireDown && !CM_IonCannonFireKeyDown[bossIdx] && CM_CanFireIonCannon[bossIdx])
    {
        if (CM_CurEnergy[bossIdx] > 0.0)
        {
			CM_StartChargedShot(bossIdx);
			CM_CanFireIonCannon[bossIdx] = false;
        }
		else if (CM_CurEnergy[bossIdx] <= 0.0)
		{
			CM_CurEnergy[bossIdx] = 0.0;
			CM_CanFireIonCannon[BossIndex] = false;
			EmitSoundToClient(BossIndex, DEFAULT_SOUND_AMMO_DEPLETED);
			PrintCenterText(bossIdx, "Your energy is depleted!!");
		}
    }
    CM_IonCannonFireKeyDown[bossIdx] = ionCannonFireDown;  
}

public Action AllowRocketFire(Handle timer, any bossIdx)
{
	if (!RoundInProgress || !PluginActiveThisRound)
	return Plugin_Handled;

	if (!CM_IsActive[bossIdx])
	{
		CM_CanFireRockets[bossIdx] = false;
		return Plugin_Continue;
	}
	else
	{
		CM_CanFireRockets[bossIdx] = true;
	}

	return Plugin_Continue;
}


public void CM_StartChargedShot(int bossIdx)
{
	bool isDefault = (CM_Flags[bossIdx] & CM_FLAG_USE_DEFAULT_VALUES) != 0;
	float fireIonCannonAt = 0.0;
	char chargeSound[MAX_SOUND_FILE_LENGTH];
	if (!IsPlayerAlive(bossIdx))
	return;


	// change the player's weapon to the charged shot version
	CM_WeaponSwap(BossIndex, 2);

	//Now, first we get/re-get the attachment for the ion cannon
	//For Ion Cannon
	static char ionAttachment[MAX_ATTACHMENT_NAME_LENGTH];
	ionAttachment = DEFAULT_IONCANNON_SPAWNATTACHMENT;
	if (!IsEmptyString(ionAttachment))
	{
		int effect = AttachParticleToAttachment(bossIdx, DEFAULT_ATTACHMENT_LOCATEREF, ionAttachment);
		if (IsValidEntity(effect))
		{
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[CM_ChargedShot]: Attachment for ion cannon created!");
			}
			CM_IonAttachmentEntRef[bossIdx] = EntIndexToEntRef(effect);
		}
			
		else
		{
			if (PRINT_DEBUG_INFO)
			{
				PrintToChatAll("[CM_ChargedShot]: Attachment for ion cannon failed! Attachment for Ion cannon is 0!");
			}
			CM_IonAttachmentEntRef[bossIdx] = INVALID_ENTREF;
		}
			
	}
	else if (PRINT_DEBUG_INFO)
	{
		PrintToChatAll("[CM_ChargedShot]: WARNING: No attachment point specified for ion cannon. Will behave oddly.");
	}

	// hold user and set time for charged shot fire
	fireIonCannonAt = (isDefault ? DEFAULT_IONCANNON_CHARGEDURATION : (CM_IonCannonChargeDuration[bossIdx] + 0.1));
	CreateTimer(fireIonCannonAt, FireIonCannon, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
	if (CM_Flags[bossIdx] & CM_FLAG_IMMOBILE_CHARGING)
	{
		SetEntityMoveType(bossIdx, MOVETYPE_NONE);
	}
		
	// play the charging sound
	chargeSound = (isDefault ? DEFAULT_IONCANNON_CHARGINGSOUND : CM_IonCannonChargingSound);
	if (strlen(chargeSound) > 3)
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[CM_ChargedShot]: Playing charging sound.");
		}
		PseudoAmbientSound(bossIdx, chargeSound, 2);
	}
		
	// pull in the particle effect that denotes charging
	static char particleName[MAX_EFFECT_NAME_LENGTH];
	particleName = DEFAULT_IONCANNON_EFFNAME;

	static char attachment[MAX_ATTACHMENT_NAME_LENGTH];
	attachment = DEFAULT_IONCANNON_SPAWNATTACHMENT;
	
	// attach!
	int effect = -1;
	if (!IsEmptyString(attachment))
	{
		effect = AttachParticleToAttachment(bossIdx, particleName, attachment);
		CM_IonCannonCharge_EntRef[bossIdx] = EntIndexToEntRef(effect);
	}
	else
	{
		if (PRINT_DEBUG_INFO)
			PrintToChatAll("[CM_ChargedShot]: Particle name provided for charged shot but no attachment point specified. Defaulting to 80HU above origin.");

		effect = AttachParticle(bossIdx, particleName, 80.0);
		CM_IonCannonCharge_EntRef[bossIdx] = EntIndexToEntRef(effect);
	}

	//Queue particle removal.	
	CreateTimer(fireIonCannonAt, Timer_RemoveEntity, CM_IonCannonCharge_EntRef[bossIdx], TIMER_FLAG_NO_MAPCHANGE);		
}

public Action FireIonCannon(Handle timer, any clientIdx)
{
	int rocketSpawn = -1;
	bool settingsDefault = (CM_Flags[BossIndex] & CM_FLAG_USE_DEFAULT_VALUES) != 0;
	float rechargeAt = (settingsDefault ? DEFAULT_IONCANNON_RECHARGE_TIME : (CM_IonCannonRechargeDuration[clientIdx] + 1.0));
	if (!RoundInProgress || !PluginActiveThisRound)
	return Plugin_Handled;

	if (!CM_IsActive[clientIdx])
	{
		CM_CanFireIonCannon[clientIdx] = false;
		return Plugin_Continue;
	}

	rocketSpawn = EntRefToEntIndex(CM_IonAttachmentEntRef[clientIdx]);
	if (rocketSpawn <= INVALID_ENTREF)
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[FireIonCannon]: Warning: Attachment ent ref for ion cannon is invalid. Recheck code.");
		}
	}

	if (settingsDefault)
	{
		CM_CreateRocket(clientIdx, DEFAULT_IONCANNON_DAMAGE, DEFAULT_IONCANNON_PROJSPEED, ROCKETTYPE_IONCANNON, rocketSpawn);
		CM_CurEnergy[clientIdx] -= DEFAULT_IONCANNON_CONSUMPTION;
	}
	else
	{
		CM_CreateRocket(clientIdx, CM_IonCannonDamage[clientIdx], CM_IonCannonProjSpeed[clientIdx], ROCKETTYPE_IONCANNON, rocketSpawn);
		CM_CurEnergy[clientIdx] -= CM_IonCannonConsumption[clientIdx];
	}

	CM_IonCannonRecharging[clientIdx] = true;
	CreateTimer(rechargeAt, RechargeIonCannon, clientIdx, TIMER_FLAG_NO_MAPCHANGE);	
	

	if (CM_Flags[clientIdx] & CM_FLAG_IMMOBILE_CHARGING)
	{
		SetEntityMoveType(clientIdx, MOVETYPE_WALK);
	}

	return Plugin_Continue;
}

public Action RechargeIonCannon(Handle timer, any bossIdx)
{
	if (!RoundInProgress || !PluginActiveThisRound)
	return Plugin_Handled;

	if (!CM_IsActive[bossIdx])
	{
		CM_CanFireIonCannon[bossIdx] = false;
		return Plugin_Continue;
	}
	else
	{
		CM_CanFireIonCannon[bossIdx] = true;
		CM_IonCannonRecharging[bossIdx] = false;
		CM_IonAttachmentEntRef[bossIdx] = INVALID_ENTREF;
	}

	return Plugin_Continue;
}

public Action CM_IC_OnDeflect(Event event, const char[] name, bool dontBroadcast)
{
	if (!RoundInProgress)
	return Plugin_Handled;
	
	
	int airblaster = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(airblaster))
	{
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("[object_deflect action] Airblaster is not a valid client.");
		}
		return Plugin_Continue;
	}
		

	bool dmgDefault = (CM_Flags[BossIndex] & CM_FLAG_USE_DEFAULT_VALUES) != 0;
	float deflectDamage = ((dmgDefault ? DEFAULT_IONCANNON_DAMAGE : CM_IonCannonDamage[BossIndex]) + 30.0);
	if (CM_IsActive[BossIndex] && CM_IonCannonRecharging[BossIndex])
	{
		SDKHooks_TakeDamage(airblaster, BossIndex, BossIndex, deflectDamage, DMG_ENERGYBEAM | DMG_PREVENT_PHYSICS_FORCE, -1);
		if (PRINT_DEBUG_INFO)
		{
			PrintToChatAll("Dealt %.1f damage to victim, %d that attempted to airblast ion cannon shot.", deflectDamage, airblaster);
			for (int radiusVictim = 1; radiusVictim <= MAX_PLAYERS; radiusVictim++)
			{
				float victimPos[3], airblasterPos[3];
				if (IsValidClient(radiusVictim) && GetClientTeam(radiusVictim) == GetClientTeam(airblaster) && airblaster != radiusVictim)
				{
					float damage = deflectDamage;
					GetClientAbsOrigin(radiusVictim, victimPos);
					GetClientAbsOrigin(airblaster, airblasterPos);
					float dmgRadius = 134.1;
					if (IsPositionInRangeOfPosition(airblasterPos, victimPos, dmgRadius))
					{
						damage = (deflectDamage *= 1.5);
						SDKHooks_TakeDamage(radiusVictim, BossIndex, BossIndex, damage, DMG_ENERGYBEAM | DMG_PREVENT_PHYSICS_FORCE, -1);
						TF2_AddCondition(radiusVictim, TFCond_Sapped, 1.7, BossIndex);
						if (PRINT_DEBUG_INFO)
						{
							PrintToChatAll("Dealt %.1f damage to victim, %d that was standing too close to airblaster, %d", damage, radiusVictim, airblaster);
						}
					}
				}
			}
		}
	}

	return Plugin_Continue;
}


/* For now, stick with sweetie bot's attachments.
public void RB_GetEnergyAttachment(int clientIdx, char[] attachment)
{
	if (!RoundInProgress)
	return;

	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RB_STRING, 6, attachment, MAX_ATTACHMENT_NAME_LENGTH);
}
*/


//For the offensive rocket attacks and energy shot attack.
public void CM_CreateRocket(int clientIdx, float untweakedDamage, float untweakedSpeed, int rocketType, int spawnLocationEntity)
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	float speed = untweakedSpeed;
	float damage = untweakedDamage;
	bool valDefault = (CM_Flags[clientIdx] & CM_FLAG_USE_DEFAULT_VALUES) != 0;
	bool smartTargEnabled = ((CM_Flags[clientIdx] & CM_FLAG_ROCKETS_USE_SMART_TARGETING_NOVIEW) != 0);
    bool viewTargRequired = ((CM_Flags[clientIdx] & CM_FLAG_ROCKETS_USE_SMART_TARGETING_NOVIEW) == 0 && (CM_Flags[clientIdx] & CM_FLAG_ROCKETS_USE_SMART_TARGETING_VIEWREQUIRED) != 0);
	char bestSound[MAX_SOUND_FILE_LENGTH];
	char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	char entname[MAX_ENTITY_CLASSNAME_LENGTH];
    CM_CurTarget[clientIdx] = INVALID_ENTREF;
    switch (rocketType)
    {
        case ROCKETTYPE_SENTRY:
        {
            classname = SENTRYROCKET_CLASS;
            entname = SENTRYROCKET_ENTITY;
			bestSound = (valDefault ? DEFAULT_ROCKET_FIRINGSOUND : CM_RocketsFiringSound);
		}
        case ROCKETTYPE_DEFAULT:
        {
            classname = DEFAULT_ROCKET_CLASS;
		    entname = DEFAULT_ROCKET_ENTITY;
			bestSound = (valDefault ? DEFAULT_ROCKET_FIRINGSOUND : CM_RocketsFiringSound);
        }
        case ROCKETTYPE_IONCANNON:
        {
            classname = ENERGY_SHOT_CLASS;
		    entname = ENERGY_SHOT_ENTITY;
			bestSound = (valDefault ? DEFAULT_IONCANNON_FIRINGSOUND : CM_IonCannonFiringSound);
        }
    }

    int rocket = CreateEntityByName(entname);
	if (!IsValidEntity(rocket))
	{
		LogError("[CM_RocketSpawn] Error: Invalid entity %s. Won't spawn rocket. This is Ivory's fault.", entname);
		return;
	}
	
	// determine spawn position
	static float spawnPosition[3];
	if (IsValidEntity(spawnLocationEntity)) // by default, spawn on the attachment point
	{	
		GetEntPropVector(spawnLocationEntity, Prop_Data, "m_vecAbsOrigin", spawnPosition);
        //Ion cannon might need to be tweaked vertically a bit.
        if (rocketType == ROCKETTYPE_IONCANNON)
        {
            spawnPosition[2] -= 20.5;
        }
	}
	else // but if that fails, spawn on the player origin and offset the Z
	{
		GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", spawnPosition);
		spawnPosition[2] += 70.0;
	}
		
	// get angles for rockets
	static float spawnAngles[3];
	//static float predictionPos[3];
	if (smartTargEnabled && rocketType == ROCKETTYPE_SENTRY || rocketType == ROCKETTYPE_DEFAULT)
	{
		// Angle the rocket to a predicted players position if smart targeting is enabled and a valid player is in view.
		float eyePos[3];
		float eyeAngles[3];
		GetClientEyePosition(clientIdx, eyePos);
		GetClientEyeAngles(clientIdx, eyeAngles);

		float targPos[3];
        int iTarget = (viewTargRequired ? GetClientAimTarget(clientIdx, true) : SelectBestTarget(clientIdx, eyeAngles));
        GetClientAbsOrigin(iTarget, targPos);
        TryPredictPlayerPos(BossIndex, iTarget, targPos, eyePos, speed);
        eyePos[2] -= 41.3;
        spawnAngles = GetAngleToPoint(eyePos, targPos);
        if (!iTarget)
        {
            spawnAngles = eyeAngles;
        }
	}
	else if (!smartTargEnabled || rocketType == ROCKETTYPE_IONCANNON)
	{
		// angles are the user's eye angles if we do dummy targeting
		GetClientEyeAngles(clientIdx, spawnAngles);
	}
	
	// determine velocity
	float spawnVelocity[3];
	GetAngleVectors(spawnAngles, spawnVelocity, NULL_VECTOR, NULL_VECTOR);
	spawnVelocity[0] *= speed;
	spawnVelocity[1] *= speed;
	spawnVelocity[2] *= speed;
	
	// deploy! If its the energy shot there will be a delay before it spawns.
	TeleportEntity(rocket, spawnPosition, spawnAngles, spawnVelocity);
	if (rocketType != ROCKETTYPE_IONCANNON) // energy ball/cow mangaler shot does not have this prop, oddly enough
	{
		SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	}
	else if (rocketType == ROCKETTYPE_IONCANNON) //YES I KNOW I CAN JUST DO ELSE!! THIS IS JUST TO BE SURE!!!
	{
		SetEntProp(rocket, Prop_Send, "m_bChargedShot", true); // charged shot
	}
	SetEntDataFloat(rocket, FindSendPropInfo(classname, "m_iDeflected") + 4, damage, true); // credit to voogru
	
	SetEntProp(rocket, Prop_Send, "m_nSkin", 1); // set skin to blue team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// play the sound
	if (strlen(bestSound) > 3)
	{
		EmitAmbientSound(bestSound, spawnPosition, SOUND_FROM_WORLD);
		EmitAmbientSound(bestSound, spawnPosition, SOUND_FROM_WORLD);
	}
	
	// to get stats from the user's melee weapon
	SetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher", GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee));
	SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee));
}


//Water electrocution
public void PWE_Tick(float curTime)
{
    if (!RoundInProgress || !PluginActiveThisRound)
    return;

    float shockRadius = PWE_DamageRadius[BossIndex];
    float frameDmg = PWE_DamagePerFrame[BossIndex];

    bool affectUber = (PWE_Flags[BossIndex] & PWE_FLAG_AFFECTS_UBERED_PLAYERS) != 0;

    bool disableEnergy = (PWE_Flags[BossIndex] & PWE_FLAG_DISABLES_ENERGY_WEAPONS) != 0;
    bool hasEnergyWeapon = false;
    int energyWeaponIdx = -1;
    int ActiveWeapon = -1;
	char shockSound[MAX_SOUND_FILE_LENGTH];
    if (GetEntityFlags(BossIndex) & (FL_SWIM | FL_INWATER))
	{
        PWE_IsBossInWater[BossIndex] = true;
        if (PRINT_DEBUG_SPAM)
        {
            PrintToConsoleAll("[PWE_Tick]: Hale, %d is in water!", BossIndex);
        }
    }
    else
    {
        PWE_IsBossInWater[BossIndex] = false;
        if (PRINT_DEBUG_SPAM)
        {
            PrintToConsoleAll("[PWE_Tick]: Hale, %d is no longer in water!", BossIndex);
        }
        return;
    }

    //If the hale is in water, start looking for other players in the water with the hale.
    for (int wVictim = 1; wVictim <= MAX_PLAYERS; wVictim++)
    {
        if (GetClientTeam(wVictim) != MercTeam)
        continue;

        if (!IsValidClient(wVictim) || !IsPlayerAlive(wVictim))
        continue;

        if (GetEntityFlags(wVictim) & (FL_SWIM | FL_INWATER))
        {
            PWE_IsVictimInWater[wVictim] = true;
            if (PRINT_DEBUG_SPAM)
            {
                PrintToConsoleAll("[PWE_Tick]: Merc, %d is in water!", wVictim);
            }
        }
        else
        {
            PWE_IsVictimInWater[wVictim] = false;
            if (PRINT_DEBUG_SPAM)
            {
                PrintToConsoleAll("[PWE_Tick]: Merc, %d is no longer in water!", wVictim);
            }
        }
        
        ActiveWeapon = GetEntPropEnt(wVictim, Prop_Send, "m_hActiveWeapon");
        energyWeaponIdx = GetEntProp(ActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
		shockSound = SOUND_SHOCK;
        if (IsPlayerInRangeOfPlayer(BossIndex, wVictim, shockRadius) && PWE_IsBossInWater[BossIndex] && PWE_IsVictimInWater[wVictim])
        {
            if (curTime >= PWE_DamagePlayerAt[BossIndex] && !TF2_IsPlayerInCondition(wVictim, TFCond_Ubercharged))
            {
                SDKHooks_TakeDamage(wVictim, BossIndex, BossIndex, frameDmg, DMG_SHOCK | DMG_PREVENT_PHYSICS_FORCE, -1);
				if (strlen(shockSound) > 3)
				{
					PseudoAmbientSound(wVictim, shockSound, 2);
					if (PRINT_DEBUG_INFO)
					{
						PrintToConsoleAll("Playing shock sound");
					}
				}
                PWE_IsVictimBeingShocked[wVictim] = true;
                TF2_AddCondition(wVictim, TFCond_Sapped, -1.0, BossIndex);
                if (PRINT_DEBUG_INFO)
                {
                    PrintToConsoleAll("[PWE_Tick]: Non-Ubered Merc, %d is being shocked for %.1f damage.", wVictim, frameDmg);
                }
            }
            else if (TF2_IsPlayerInCondition(wVictim, TFCond_Ubercharged) && affectUber && PWE_DamagePlayerAt[BossIndex] <= curTime)
            {
                SDKHooks_TakeDamage(wVictim, BossIndex, BossIndex, frameDmg, DMG_SHOCK | DMG_PREVENT_PHYSICS_FORCE, -1);
				if (strlen(shockSound) > 3)
				{
					PseudoAmbientSound(wVictim, shockSound, 2);
					if (PRINT_DEBUG_INFO)
					{
						PrintToConsoleAll("Playing shock sound");
					}
				}
                PWE_IsVictimBeingShocked[wVictim] = true;
                TF2_AddCondition(wVictim, TFCond_Sapped, -1.0, BossIndex);
                if (PRINT_DEBUG_INFO)
                {
                    PrintToConsoleAll("[PWE_Tick]: Ubered Merc, %d is being shocked for %.1f damage.", wVictim, frameDmg);
                }
            }
				

            if (disableEnergy)
            {
                switch (energyWeaponIdx)
                {
                    case 441: hasEnergyWeapon = true; //Cow mangaler

                    case 442: hasEnergyWeapon = true; //Righteous Bison

                    case 588: hasEnergyWeapon = true; //Pompson 6000

                    case 528: hasEnergyWeapon = true; //Short circuit

                    case 594: hasEnergyWeapon = true; //Phlogistinator

                    case 595: hasEnergyWeapon = true; //Manmelter

                    case 30665: hasEnergyWeapon = true; //Shooting star.

                    case 30666: hasEnergyWeapon = true; //C.A.P.P.E.R

                    case 30667: hasEnergyWeapon = true; //Batsaber, instead, these users take double damage if its equipped.
                }

                if (PRINT_DEBUG_INFO && hasEnergyWeapon)
                {
                    PrintToConsoleAll("[PWE_Tick]:Merc, %d has energy weapon, %d", wVictim, energyWeaponIdx);
                }

                if (hasEnergyWeapon)
                {
                    PWE_DisableEnergyWeapon(wVictim, energyWeaponIdx);
                    if (PRINT_DEBUG_INFO)
                    {
                        PrintToConsoleAll("[PWE_Tick]: Function PWE_Disableenergyweapon executed.");
                    }
                }
			}
			PWE_DamagePlayerAt[BossIndex] = PWE_ELECTROCUTE_INTERVAL;
		}
		else
        {
            PWE_IsVictimBeingShocked[wVictim] = false;
			TF2_RemoveCondition(wVictim, TFCond_Sapped);
            if (PRINT_DEBUG_SPAM)
            {
                PrintToConsoleAll("[PWE_Tick]:Victim, %d is no longer being shocked.", wVictim);
            }
        }
	}
}

public Action PWE_FindAndDisableSentry(Handle timer)
{
	if (!RoundInProgress || !PWE_ActiveThisRound)
	return Plugin_Handled;

	if (PRINT_DEBUG_SPAM)
	{
		PrintToChatAll("[Disable Sentry] Executing stun timer.");
	}

	float stunRadius = PWE_DamageRadius[BossIndex] * 1.2;
	float bossOrigin[3];
	GetEntPropVector(BossIndex, Prop_Data, "m_vecOrigin", bossOrigin);

	float bossPosNoZ[3];
	bossPosNoZ[0] = bossOrigin[0];
	bossPosNoZ[1] = bossOrigin[1];
	bossPosNoZ[2] = 0.0;

	if (PWE_IsBossInWater[BossIndex])
	{
		int sentry = -1;
		while ((sentry = FindEntityByClassname(sentry, "obj_sentrygun")) != -1)
		{
			float sentryPos[3];
			float sentryPosNoZ[3];
			GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPos);
			GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPosNoZ);
			sentryPosNoZ[2] = 0.0;
		
			if (GetVectorDistance(bossPosNoZ, sentryPosNoZ) <= stunRadius)
			{
				// modified on 2015-03-23, handing the stun job off to dynamic defaults
				DSSG_PerformStunFromCoords(BossIndex, sentryPos, 1.0, 2.0);
				if (PRINT_DEBUG_SPAM)
				{
					PrintToConsoleAll("[StunSentry] Stunning sentrygun");
				}
			}
			else
			{
				if (PRINT_DEBUG_SPAM)
				{
					PrintToConsoleAll("[StunSentry] No sentries found?");
				}
				return Plugin_Continue;
			}
		}
	}
	else
	{
		if (PRINT_DEBUG_SPAM)
		{
			PrintToChatAll("[Disable Sentry] Boss needs to be in water! Timer will not completely execute!");
			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}



public void PWE_DisableEnergyWeapon(int victim, int eWeaponIdx)
{
    if (!RoundInProgress || !CM_ActiveThisRound)
    return;

    if (!IsPlayerAlive(victim))
    return;

    if (PWE_IsVictimBeingShocked[victim])
    {
        //If they have the bison, pompson, or cow mangaler, take all the energy out of both. 
        if (eWeaponIdx == 441 || eWeaponIdx == 442 || eWeaponIdx == 588)
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iClip1", 0);
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("Removed clip on weapon, %d on victim %d because its an energy weapon.", eWeaponIdx, victim);
            }
        }

        //Now, id rather not take away all of an engineer's metal so i'll try to just make his short circuit inoperable by making the next attack FAR_FUTURE
        if (eWeaponIdx == 528)
        {
            //I think this is reset on weapon switch. Could be wrong.
            SetEntPropFloat(eWeaponIdx, Prop_Send, "m_flNextPrimaryAttack", FAR_FUTURE);
            SetEntPropFloat(eWeaponIdx, Prop_Send, "m_flNextSecondaryAttack", FAR_FUTURE);
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("Short Circuit on victim %d rendered non-fireable....I think...?", victim);
            }
        }

        //No phlog ammo for u, pyro.
        if (eWeaponIdx == 594)
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iAmmo", 0);
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("Ammo removed from phlogistinator on Pyro victim, %d", victim);
            }
        }

        //Manmelter is a bit weird. I'll see what Ivory has to say. (UPDATE: This might work.)
        if (eWeaponIdx == 595) 
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iClip1", 0);  
            SetEntProp(eWeaponIdx, Prop_Send, "m_iAmmo", 0); 
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("Manmelter disabled on player, %d", victim);
            }
        }

        //C.A.P.P.E.R and Shooting star
        if (eWeaponIdx == 30665) 
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iClip1", 0);  
            SetEntProp(eWeaponIdx, Prop_Send, "m_iAmmo", 0); 
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("Ammo removed from C.A.P.P.E.R on victim, %d", victim);
            }
        }

        if (eWeaponIdx == 30666) 
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iAmmo", 0); 
            if (PRINT_DEBUG_INFO)
            {
                PrintToChatAll("Ammo removed from shooting star on Sniper victim, %d", victim);
            }
        }

        //Batsaber has no ammo but def is an energy weapon, instead, have the users take double damage.
        if (eWeaponIdx == 30667) 
        {
            float doubleFrameDmg = PWE_DamagePerFrame[BossIndex] * 2.0;
            SDKHooks_TakeDamage(victim, BossIndex, BossIndex, doubleFrameDmg, DMG_SHOCK | DMG_PREVENT_PHYSICS_FORCE, -1);
        }
    }
    else //Restore energy weapons clips if they aren't being shocked anymore.
    {
        //Had to do these three seperately. All have different clip sizes on vspr.
        if (eWeaponIdx == 441) //Cow Mangaler
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iClip1", 4);
        }

        if (eWeaponIdx == 442) //Bison has 400 clip, wut?
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iClip1", 400);
        }

        if (eWeaponIdx == 588) //Pompson
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iClip1", 6);
        }

        //Allow the short circut to be fired again.
        if (eWeaponIdx == 528)
        {
            SetEntPropFloat(eWeaponIdx, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.3);
            SetEntPropFloat(eWeaponIdx, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 0.3);
        }

        //I dont want to just give them back all their ammo, so they get a small portion back
        if (eWeaponIdx == 30666) 
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iAmmo", 10); 
        }

        if (eWeaponIdx == 30665) 
        {
            SetEntProp(eWeaponIdx, Prop_Send, "m_iClip1", 12);  
            SetEntProp(eWeaponIdx, Prop_Send, "m_iAmmo", 100); 
        }
    }
}

public Action PWE_JarateMilk_OnTouch(int bossIdx, int victim)
{
	if (!RoundInProgress)
	return Plugin_Handled;

	if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
	return Plugin_Continue;

	float curTime = GetEngineTime();
	float touchDamage = PWE_DamagePerFrame[BossIndex];
	char touchShockSound[MAX_SOUND_FILE_LENGTH];
	if (TF2_IsPlayerInCondition(bossIdx, TFCond_Jarated) || TF2_IsPlayerInCondition(bossIdx, TFCond_Milked))
	{
		touchShockSound = SOUND_SHOCK;
		if (GetClientTeam(victim) == MercTeam && curTime >= PWE_DamagePlayerAt[BossIndex])
		{
			SDKHooks_TakeDamage(victim, BossIndex, BossIndex, touchDamage, DMG_SHOCK | DMG_PREVENT_PHYSICS_FORCE, -1);
			if (strlen(touchShockSound) > 3)
			{
				PseudoAmbientSound(victim, touchShockSound, 2);
				if (PRINT_DEBUG_INFO)
				{
					PrintToConsoleAll("Playing shock sound");
				}
			}
			TF2_AddCondition(victim, TFCond_Sapped, 1.5, BossIndex);
			if (TF2_IsPlayerInCondition(bossIdx, TFCond_Ubercharged) && PWE_Flags[BossIndex] & PWE_FLAG_AFFECTS_UBERED_PLAYERS)
			{
				SDKHooks_TakeDamage(victim, BossIndex, BossIndex, touchDamage, DMG_SHOCK | DMG_PREVENT_PHYSICS_FORCE, -1);
			}
		}
	}
	PWE_DamagePlayerAt[BossIndex] = PWE_ELECTROCUTE_INTERVAL;

	return Plugin_Continue;
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
	else
	{
		return Plugin_Continue;
	}

	return Plugin_Continue;
}


stock int AttachParticle(int entity, const char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	float position[3];
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