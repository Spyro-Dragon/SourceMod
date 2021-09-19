#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#include <sdkhooks>
#include <sdktools>
#include <cw3-attributes>
#include <freak_fortress_2>
#include <tf2items>

#define MIN			512.0
#define PLUGIN_VERSION "1.0"
#define SLOTS_MAX               7
#define FAR_FUTURE 100000000.0


public Plugin:myinfo = {
    name = "VSPR Immobile Sentry",
    author = "Spyro. Just Spyro.",
    description = "Heavy decided to rip off an enemy sentrygun barrel. Now its his new weapon",
    version = "1.0",
    url = "",
};


#define MAX_ENTITY_CLASSNAME_LENGTH 48
new MercTeam = _:TFTeam_Red;
new BossTeam = _:TFTeam_Blue;

bool hooked[MAXPLAYERS+1];

//Dispenser buffs
bool HeavyNearDispenser[MAXPLAYERS+1];
float AccuracyBonusDisp[MAXPLAYERS+1];
float DamageBonusDisp[MAXPLAYERS+1];
float FirerateBonusDisp[MAXPLAYERS+1];

//Sentry Rocket rage
float SentryRocketRage[MAXPLAYERS+1];
bool SentryRocketButton[MAXPLAYERS+1];
bool RageAltFireReady[MAXPLAYERS+1];


public OnPluginStart()
{
	RegAdminCmd("sm_immobilesentry", CMDInitImmobSentry, ADMFLAG_KICK);
}

public Action CMDInitImmobSentry(int client, int args)
{
	hooked[client] = !hooked[client];
	HookActiveWeapon(client);
}

public void HookActiveWeapon(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(weapon))
	{
        SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
		TF2Attrib_SetByName(weapon, "aiming movespeed decreased", 0.01);
        TF2Attrib_SetByName(weapon, "spunup_push_force_immunity", 1.0);
		TF2Attrib_SetByName(weapon, "reduced_healing_from_medics", 0.25);
        TF2Attrib_SetByName(weapon, "maxammo metal increased", 2.5);
        TF2Attrib_SetByName(weapon, "mod use metal ammo type", 1.0);
        TF2Attrib_SetByName(weapon, "rocket specialist", 1.0);
	}
	PrintToChat(client, "weapon hooked: Debuffs applied.");
    PrintToChat(client, "Stand next to dispenser to see if healing buffs work");
}

public Action OnPlayerRunCmd(int iClient, &buttons, &impulse)
{
        if(RageAltFireReady[iClient])
        {
            SentryRocketButton[iClient] = (buttons & IN_RELOAD) != 0;
        }
        if (SentryRocketButton[iClient] && RageAltFireReady[iClient])
        {
            CreateSentryRocket(iClient, 150.0, 200.0);
            SentryRocketRage[iClient] = 0.0;
            return Plugin_Continue;
        }
    return Plugin_Continue;
}

public Action:HookDispenserBuffs(int iClient)
{
    //new team = GetClientTeam(client);
    //for(new iClient = 1; iClient <= MaxClients; iClient++)
    
    int weapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
    if(IsClientInGame(iClient) && HeavyNearDispenser[iClient] && GetClientTeam(iClient) == MercTeam)
    {
        PrintToServer("Healing %i", iClient);
        PrintToChat(iClient, "Near dispenser.");
        TF2Attrib_SetByName(weapon, "weapon spread bonus", 0.65);
        TF2Attrib_SetByName(weapon, "fire rate bonus", 0.7);
        if (!HeavyNearDispenser[iClient])
        {
            PrintToChat(iClient, "Not near dispenser.");
            TF2Attrib_RemoveByName(weapon, "weapon spread bonus");
            TF2Attrib_RemoveByName(weapon, "fire rate bonus");
            return Plugin_Continue;
        }
    }
    return Plugin_Continue;
}

public void OnEntityCreated(entity, const String:classname[])
{
    if(StrEqual(classname, "dispenser_touch_trigger", false))
    {
        CreateTimer(0.0, delay, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action:delay(Handle:timer, any:EntRef)
{
    new entity = EntRefToEntIndex(EntRef);

    if(entity <= MaxClients)
    {
        return;
    }

    SDKHookEx(entity, SDKHook_StartTouchPost, StartTouchPost);
    SDKHookEx(entity, SDKHook_EndTouchPost, EndTouchPost);
}

public void StartTouchPost(entity, int iClient)
{
    if( 0 <  iClient <= MaxClients)
    {
        new ent = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
        new team = GetEntProp(ent, Prop_Send, "m_iTeamNum");

        if(team == GetClientTeam(iClient))
        {
            HeavyNearDispenser[iClient] = true;
        }
    }
}

public void EndTouchPost(entity, iClient)
{
    if( 0 < iClient <= MaxClients)
    {
        HeavyNearDispenser[iClient] = false;
    }
} 


public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
        if(client == attacker && client == MercTeam || client != BossTeam) 
        {
           SentryRocketRage[attacker] += 15.7;
           if (SentryRocketRage[attacker] >= 300.0)
           {
               PrintToChat(attacker, "rocket ready");
               RageAltFireReady[attacker] = true;
               SentryRocketRage[attacker] = 300.0;
           }
        }
}

public void CreateSentryRocket(int client, Float:untweakedDamage, Float:untweakedSpeed)
{
    new Float:speed = untweakedSpeed;
	new Float:damage = fixDamageForFF2(untweakedDamage);
    new String:classname[MAX_ENTITY_CLASSNAME_LENGTH] = "CTFProjectile_Rocket";
    new String:ragerocket[MAX_ENTITY_CLASSNAME_LENGTH] = "tf_projectile_sentryrocket";

    new rocket = CreateEntityByName(ragerocket);
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[vspr_immobilesentry] Error: Invalid entity %s. Won't spawn rocket. Goddammit Spyro, get back to scripting", rocket);
        PrintToChat(client, "Error: invalid rocket entity. Check console");
		return;
	}

 
	static Float:spawnPosition[3];
    GetEntPropVector(client, Prop_Data, "m_vecOrigin", spawnPosition);
    spawnPosition[2] += 70.0;
	

    static Float:spawnAngles[3];
    GetClientEyeAngles(client, spawnAngles);

    static Float:spawnVelocity[3];
	GetAngleVectors(spawnAngles, spawnVelocity, NULL_VECTOR, NULL_VECTOR);
	spawnVelocity[0] *= speed;
	spawnVelocity[1] *= speed;
	spawnVelocity[2] *= speed;

    TeleportEntity(rocket, spawnPosition, spawnAngles, spawnVelocity);
		SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropInfo(classname, "m_iDeflected") + 4, damage, true); // credit to voogru
	SetEntProp(rocket, Prop_Send, "m_nSkin", 2); // set skin to red team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", client);
	SetVariantInt(MercTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(MercTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);

    // to get stats from the user's primary weapon
    SetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher", GetPlayerWeaponSlot(client, TFWeaponSlot_Primary));
	SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetPlayerWeaponSlot(client, TFWeaponSlot_Primary));
}


stock Float:fixDamageForFF2(Float:damage)
{
	if (damage <= 160.0)
		return damage / 3.0;
	return damage;
}

stock bool:IsLivingPlayer(client)
{
	if (client <= 0 || client >= MaxClients)
		return false;
		
	return IsClientInGame(client) && IsPlayerAlive(client);
}