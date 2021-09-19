#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#include <cw3-attributes>
#include <tf2items>


#define MIN			512.0
#define PLUGIN_VERSION "1.0"
#define SLOTS_MAX               7
#define FAR_FUTURE 100000000.0


public Plugin:myinfo = {
    name = "VSPR Beam Rifle",
    author = "Spyro. Just Spyro.",
    description = "AKA, the type 40 particle beam rifle",
    version = PLUGIN_VERSION,
    url = "",
};

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

bool hooked[MAX_PLAYERS_ARRAY]; //Internal, for testing.
bool DebugMode[MAX_PLAYERS_ARRAY]; //Attrib "Enable debug mode" for testing
bool WeaponHasOverHeat[MAX_PLAYERS_ARRAY]; //Attrib "Weapon has overheat"
bool HeatVentButtonIndex[MAX_PLAYERS_ARRAY]; //Attrib "Set heat vent button"

//Internal
bool HeatVentButton[MAX_PLAYERS_ARRAY];
bool HeatVentButtonDown[MAX_PLAYERS_ARRAY];


//Internal
bool RifleOverheated[MAX_PLAYERS_ARRAY];
int DamageBonusInterval[MAX_PLAYERS_ARRAY];
int OverheatShots[MAX_PLAYERS_ARRAY];
int AmmoShots[MAX_PLAYERS_ARRAY];

float PerShotAmmoDecay[MAX_PLAYERS_ARRAY];
float PerShotAmmoDecayIncrease[MAX_PLAYERS_ARRAY];

float PerHitDamageBonus[MAX_PLAYERS_ARRAY];
float PerHitDamageBonusIncrease[MAX_PLAYERS_ARRAY];


//bool ZoomLevelTwo[MAX_PLAYERS_ARRAY]; How tf am i going to implement this?

Handle overheathud;
Handle g_DHookPrimaryAttack;

public OnPluginStart()
{
    for (new i = 1; i <= MaxClients; i++)
  	{
    		if (!IsClientInGame(i)) continue;
    		OnClientPutInServer(i);
  	}
	RegAdminCmd("sm_beamrifletest", CMDInitBeamRifle, ADMFLAG_KICK);
    //g_DHookPrimaryAttack = DHookCreateFromConf(hGameConf, "CTFWeaponBase::PrimaryAttack()");
	overheathud = CreateHudSynchronizer();
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}



public Action OnPlayerRunCmd(int iClient, &buttons, &impulse)
{
    if (hooked[iClient])
    {
        HeatVentButton[iClient] = (buttons & IN_ATTACK3) != 0;
    }
}

public Action CMDInitBeamRifle(int client, int args)
{
	hooked[client] = !hooked[client];
	BeamRifleAmmoDamage(client);
}

public void BeamRifleAmmoDamage(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    DHookEntity(g_DHookPrimaryAttack, true, weapon, .callback = OnPrimaryAttackPost);
    DHookEntity(g_DHookPrimaryAttack, false, weapon, .callback = OnPrimaryAttackPre);
    float ammoPenaltyInitMult = (PerShotAmmoDecay[client] + PerShotAmmoDecayIncrease[client]);
    float ammoPenaltyMult = (PerShotAmmoDecayIncrease[client] + PerShotAmmoDecayIncrease[client]);
    float damageBonusInitMult = (PerHitDamageBonus[client] + PerHitDamageBonusIncrease[client])
    
	if (IsValidEntity(weapon))
	{
        TF2Attrib_SetByName(weapon, "headshot damage increase", 1.75);
        TF2Attrib_SetByName(weapon, "sniper crit no scope", 1.0);
        TF2Attrib_SetByName(weapon, "maxammo primary increased", 4.0);
        TF2Attrib_SetByName(weapon, "mod ammo per shot", 5.0);
        TF2Attrib_SetByName(weapon, "sniper fires tracer", 1.0);
        TF2Attrib_SetByName(weapon, "SRifle Charge rate decreased", 0.01);
        if (AmmoShots[client] == 0 || AmmoShots[client] < 1)
        {
            TF2Attrib_RemoveByName(weapon, "mod ammo per shot");
            TF2Attrib_SetByName(weapon, "mod ammo per shot", PerShotAmmoDecay[client]);
            PrintToChat(client, "Shots: 0. Ammo consumption: 5");
        } 
        else if (AmmoShots[client] == 1)
        {
            TF2Attrib_RemoveByName(weapon, "mod ammo per shot");
            TF2Attrib_SetByName(weapon, "mod ammo per shot", ammoPenaltyInitMult);
            PrintToChat(client, "Shots: 1. Ammo consumption: %i", ammoPenaltyInitMult);
        }
        else if (AmmoShots[client] == 2)
        {
            TF2Attrib_RemoveByName(weapon, "mod ammo per shot");
            TF2Attrib_SetByName(weapon, "mod ammo per shot", ammoPenaltyMult);
            PrintToChat(client, "Shots: 2. Ammo consumption: %i", ammoPenaltyMult);
        }
        else if (AmmoShots[client] == 3)
        {
            TF2Attrib_RemoveByName(weapon, "mod ammo per shot");
            TF2Attrib_SetByName(weapon, "mod ammo per shot", ammoPenaltyMult);
            PrintToChat(client, "Shots: 3. Ammo consumption: %i", ammoPenaltyMult);
        }



        if (DamageBonusInterval[client] == 0 || DamageBonusInterval[client] < 1)
        {
            TF2Attrib_RemoveByName(weapon, "damage bonus");
            PrintToChat(client, "hits: 0. Damage Bonus: None");
        }
        else if (DamageBonusInterval[client] == 1)
        {
            TF2Attrib_SetByName(weapon, "damage bonus", 1.25);
            PrintToChat(client, "hits: 1. Damage Bonus: 25%");
        }
        else if (DamageBonusInterval[client] == 2)
        {
            TF2Attrib_RemoveByName(weapon, "damage bonus");
            TF2Attrib_SetByName(weapon, "damage bonus", 1.50);
            PrintToChat(client, "hits: 2. Damage Bonus: 50%");
        }
        else if (DamageBonusInterval[client] == 3)
        {
            TF2Attrib_RemoveByName(weapon, "damage bonus");
            TF2Attrib_SetByName(weapon, "damage bonus", 1.75);
            PrintToChat(client, "hits: 3. Damage Bonus: 75%");
        }
        
        if (RifleOverheated[client])
        {
            TF2_IgnitePlayer(client, client, 2.7);
        }

	}
	PrintToChat(client, "weapon hooked: base stats applied");
}

VentButton_GetActionKey(int iClient, int argIdx)
{
	new keyIdx = argIdx;
	if (keyIdx == 1) //Alt-Fire
    {
        if (DebugMode[iClient])
        {
            PrintToChat(iClient, "Key index set to 1, Special Attack key is used to retro charge.");
        }
		return IN_ATTACK2;
    }
	else if (keyIdx == 2) //Action Key
    {
        if (DebugMode[iClient])
        {
            PrintToChat(iClient, "Key index set to 2, Action key is used to retro charge.");
            PrintToChat(iClient, "WARNING: MAKE SURE NO ITEMS ARE IN ACTION SLOT!");
        }
        return IN_USE;
    }
    else if (keyIdx == 3) //Special attack key
    {
        if (DebugMode[iClient])
        {
            PrintToChat(iClient, "Key index set to 3, 'Alt-Fire (Attack2)' is used to retro charge.");
        }
        return IN_ATTACK3;
    }
	else if (DebugMode[iClient])
    {
        PrintToChat(iClient, "Warning: No mode selection key specified. Defaulting to 'Alt-Fire (Attack2)'");
        return IN_ATTACK2;
    }	
	return IN_ATTACK2; // no key, implied is "call for medic"
}



static bool s_bPrimaryAttackAvailable;
public MRESReturn OnPrimaryAttackPre(int weapon) 
{
	float flNextPrimaryAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
	s_bPrimaryAttackAvailable = flNextPrimaryAttack <= GetGameTime();
}

public MRESReturn OnPrimaryAttackPost(int iClient) 
{
    int weapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!s_bPrimaryAttackAvailable) 
    {
		return MRES_Ignored;
	}

	
        if (OverheatShots[iClient] < 3 || OverheatShots[iClient] == 0)
        {
            float curTime = GetEngineTime();
            new Float:OverHeatDecayInterval = curTime + 1.5;
            OverheatShots[iClient]++;
            AmmoShots[iClient]++;
            if (OverheatShots[iClient] >= 3)
            {
                RifleOverheated[iClient] = true;
            }
            if (curTime >= OverHeatDecayInterval || OverheatShots[iClient] > 3 || AmmoShots[iClient] > 3)
            {
                OverheatShots[iClient]--;
                AmmoShots[iClient]--;
            }
            if (OverheatShots[iClient] < 0 || AmmoShots[iClient] < 0) //freak situation
            {
                OverheatShots[iClient] = 0;
                AmmoShots[iClient] = 0;
            }
            if (HeatVentButton[iClient])
            {
                OverHeatDecay = 0.7;
            }
            if (RifleOverheated[iClient])
            {
                OverHeatDecay = 2.0;
            }
        }

        if (RifleOverheated[iClient]) 
        {
            float OverheatEndsAt = 3.0;
            HeatVentButton[iClient] = false;

            if (GetEngineTime() >= OverheatEndsAt)
            {
                RifleOverheated[iClient] = false;
                OverheatShots[iClient] = 0;
                AmmoShots[iClient] = 0;
                HeatVentButton[iClient] = (GetClientButtons(iClient) & IN_ATTACK3) != 0;
            }

            if (TF2_IsPlayerInCondition(iClient, TFCond_Zoomed))
            {
                TF2_RemoveCondition(iClient, TFCond_Zoomed);
            }
            SetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack", OverheatEndsAt);
            SetEntPropFloat(weapon, Prop_Data, "m_flNextSecondaryAttack", OverheatEndsAt);
        
            /*
            if (!PlayCustomOverheatSound(weapon)) {
                EmitGameSoundToAll("TFPlayer.FlameOut", .entity = weapon);
            }
            */
        }
	return MRES_Ignored;
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
    new Float:DamageBonusDecay = 0.75; //This is tempoary until i figure out how to reset it when you miss or hit another target.
    if(IsValidClient(attacker) && client == attacker)
    {
        DamageBonusInterval[client]++;
        if (DamageBonusInterval[client] > 3)
        {
            DamageBonusInterval[client] = 3;
        }
        if (DamageBonusInterval[client] < 0) //Another freak situation
        {
            DamageBonusInterval[client] = 0;
            PrintToChat(client, "Warning: Damage bonus integer somehow less than 0???");
        }
    }
    if(GetEngineTime() >= DamageBonusDecay)
    {
        DamageBonusInterval[client]--;
    }
}


public Action:CW3_OnAddAttribute(slot, client, const String:attrib[], const String:plugin[], const String:value[], bool:whileActive)
{
    /*
	if (!StrEqual(plugin, "vsprattribs")) 
    return Plugin_Continue;
    */
  new Action:action;
  if (StrEqual(attrib, "Enable debug mode"))
  {
    DebugMode[client] = true;
    PrintToChat(client, "Debug mode enabled. Check chat while using weapon");
  }






}


public CW3_OnWeaponRemoved(slot, client)
{
    DebugMode[client] = false;
    HasActiveReload[client] = false;
    UnHookReloadBoltok(client);
   //ActiveReloadDefaultTime[client] = 0.0;
    //ActiveReloadDecay[client] = 0.0;
}


stock bool:IsLivingPlayer(client)
{
	if (client <= 0 || client >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(client) && IsPlayerAlive(client);
}