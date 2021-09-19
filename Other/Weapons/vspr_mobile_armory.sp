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


public Plugin:myinfo = {
    name = "VSPR Mobile Armory",
    author = "Spyro. Just Spyro.",
    description = "Dispenser tied to soldier's back",
    version = "1.0",
    url = "",
};

new MercTeam = _:TFTeam_Red;
new BossTeam = _:TFTeam_Blue;

bool hooked[MAXPLAYERS+1];

//Levels on the banner
bool LevelOneReady[MAXPLAYERS+1];

bool LevelTwoReady[MAXPLAYERS+1];
bool LevelTwoBegin[MAXPLAYERS+1];

bool LevelThreeReady[MAXPLAYERS+1];
bool LevelThreeBegin[MAXPLAYERS+1];

bool LevelOneActive[MAXPLAYERS+1];
bool LevelTwoActive[MAXPLAYERS+1];
bool LevelThreeActive[MAXPLAYERS+1];

bool DeleteDispenser[MAXPLAYERS+1];

//banner buttons
bool BannerButtonEnabled[MAXPLAYERS+1];
bool BannerButton[MAXPLAYERS+1];

//banner damage requirements
float BannerTotalDamage[MAXPLAYERS+1];
float LevelOneDamage[MAXPLAYERS+1];
float LevelTwoDamage[MAXPLAYERS+1];
float LevelThreeDamage[MAXPLAYERS+1];

Handle levelhud;

public OnPluginStart()
{
	RegAdminCmd("sm_bannertest", CMDInitBannerTest, ADMFLAG_KICK);
	levelhud = CreateHudSynchronizer();
}


public Action CMDInitBannerTest(int client, int args)
{
	hooked[client] = !hooked[client];
	HookActiveWeapon(client);
}

public Action OnPlayerRunCmd(int iClient, &buttons, &impulse)
{
if (hooked[iClient])
{
  if (IsValidClient(iClient))
  {
	BannerButton[iClient] = (buttons & IN_ATTACK) != 0;
  }
  if (BannerButtonEnabled[iClient] && BannerButton[iClient])
  {
    BannerButtonEnabled[iClient] = false;
    LevelTwoBegin[iClient] = false;
    LevelOneReady[iClient] = false;
    LevelThreeBegin[iClient] = false;
    LevelTwoReady[iClient] = false;
    LevelThreeReady[iClient] = false;
    BannerTotalDamage[iClient] = 0.0;
    if (BannerButton[iClient] && LevelOneReady[iClient])
    {
        BannerActiveBuffs(iClient);
        //SDKUnhook(iClient, SDKHook_OnTakeDamageAlive, OnTakeDamage);
        LevelOneActive[iClient] = true;
        //for sanity
        LevelTwoActive[iClient] = false;
        LevelThreeActive[iClient] = false;
    }
    else if (BannerButton[iClient] && LevelTwoReady[iClient])
    {
        BannerActiveBuffs(iClient);
        //SDKUnhook(iClient, SDKHook_OnTakeDamageAlive, OnTakeDamage);
        LevelOneActive[iClient] = false;
        LevelTwoActive[iClient] = true;
        LevelThreeActive[iClient] = false;
    }
    else if (BannerButton[iClient] && LevelThreeReady[iClient])
    {
        BannerActiveBuffs(iClient);
        //SDKUnhook(iClient, SDKHook_OnTakeDamageAlive, OnTakeDamage);
        LevelOneActive[iClient] = false;
        LevelTwoActive[iClient] = false;
        LevelThreeActive[iClient] = true;
    }
  }
}

}

public void HookActiveWeapon(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(weapon))
	{
        SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		TF2Attrib_SetByName(weapon, "health regen", 6.0);
        TF2Attrib_SetByName(weapon, "ammo regen", 1.25);
        TF2Attrib_SetByName(weapon, "health from packs decreased", 0.65);
        TF2Attrib_SetByName(weapon, "health from healers reduced", 0.6);
        BannerTotalDamage[client] = 0.0;
        LevelOneDamage[client] = 450.0;
        LevelTwoDamage[client] = 250.0;
        LevelThreeDamage[client] = 200.0;
	}
	PrintToChat(client, "weapon hooked: Stats applied.");
}

public void BannerActiveBuffs(int client)
{
    if (LevelOneActive[client])
    {
        PrintToChat(client, "Level One Activated");
        AttachDispenser(client, 1, 30.0);
        CreateTimer(10.0, LevelOneDuration, client, TIMER_FLAG_NO_MAPCHANGE);
    }
    else if (LevelTwoActive[client] && !LevelOneActive[client])
    {
        PrintToChat(client, "Level Two Activated");
        AttachDispenser(client, 2, 30.0);
        CreateTimer(13.0, LevelTwoDuration, client, TIMER_FLAG_NO_MAPCHANGE);
    }
    else if ((LevelThreeActive[client] && !LevelTwoActive[client] && !LevelOneActive[client]))
    {
        PrintToChat(client, "Level Three Activated");
        AttachDispenser(client, 3, 30.0);
        CreateTimer(16.0, LevelTwoDuration, client, TIMER_FLAG_NO_MAPCHANGE);
    }


}


public Action:LevelOneDuration(Handle:hTimer, any:client)
{
    if (LevelOneActive[client] && !LevelTwoActive[client] && !LevelThreeActive[client])
    {
        DeleteDispenser[client] = true;
        //SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
        LevelOneActive[client] = false;
    }
}

public Action:LevelTwoDuration(Handle:hTimer, any:client)
{
    if (LevelTwoActive[client] && !LevelOneActive[client] && !LevelThreeActive[client])
    {
        DeleteDispenser[client] = true;
        //SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
        LevelTwoActive[client] = false;
    }
}

public Action:LevelThreeDuration(Handle:hTimer, any:client)
{
    if (LevelThreeActive[client] && !LevelTwoActive[client] && !LevelOneActive[client])
    {
        DeleteDispenser[client] = true;
        //SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
        LevelThreeActive[client] = false;
    }
}


public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
        if (IsValidClient(client) && IsValidClient(attacker) && client == attacker)
	    {
           BannerTotalDamage[attacker] += 50.7;
           if (BannerTotalDamage[attacker] >= LevelOneDamage[attacker])
           {
               PrintToChat(attacker, "Level One Reached");
               BannerButtonEnabled[attacker] = true;
               LevelTwoBegin[attacker] = true;
               LevelOneReady[attacker] = true;
               BannerTotalDamage[attacker] = 0.0;
           }
           else if (LevelTwoBegin[attacker] && BannerButtonEnabled[attacker] && BannerTotalDamage[attacker] >= LevelTwoDamage[attacker])
           {
               PrintToChat(attacker, "Level Two Reached");
               LevelThreeBegin[attacker] = true;

               LevelTwoBegin[attacker] = false;
               LevelTwoReady[attacker] = true;

               LevelOneReady[attacker] = false;
               BannerTotalDamage[attacker] = 0.0;
           }
           else if (!LevelTwoBegin[attacker] && LevelThreeBegin[attacker] && BannerButtonEnabled[attacker] && BannerTotalDamage[attacker] >= LevelThreeDamage[attacker])
           {
               PrintToChat(attacker, "Level Three Reached");
               LevelThreeBegin[attacker] = false;
               LevelThreeReady[attacker] = true;
               LevelTwoReady[attacker] = false;
               BannerTotalDamage[attacker] = 0.0;
           }
        }
}



stock AttachDispenser(entity, int upgradelevel, Float:offset=0.0, bool:attach=true)
{
	new dispenser = CreateEntityByName("mapobj_cart_dispenser");
	new dispensertrigger = CreateEntityByName("dispenser_touch_trigger");
    new client = GetClientOfUserId(entity);

	if (!IsValidEntity(dispenser))
		return -1;

    if (!IsValidEntity(dispensertrigger))
    return -1;

    if (!IsValidClient(client))
		return -1;

	decl String:targetName[128];
    //decl int teamnum = 2;
	decl Float:position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2] += offset;
	TeleportEntity(dispenser, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);
	DispatchKeyValue(dispenser, "parentname", targetName);
    DispatchKeyValue(dispensertrigger, "parentname", targetName);
    DispatchKeyValue(dispensertrigger, "targetname", "DispenserBanner");

    SetVariantInt(MercTeam);
	AcceptEntityInput(dispenser, "TeamNum", -1, -1, 0);

    SetVariantString("spawnflags 14"); // invulnerable, ignore los check, and cant heal enemy/cloaked spies
	AcceptEntityInput(dispenser, "AddOutput");

    SetVariantString("touch_trigger DispenserBanner");
    AcceptEntityInput(dispenser, "AddOutput");

	DispatchSpawn(dispenser);
    DispatchSpawn(dispensertrigger);
	SetVariantString(targetName);
	if (attach)
	{
		SetEntPropEnt(dispenser, Prop_Send, "m_hOwnerEntity", entity);
        SetEntPropEnt(dispensertrigger, Prop_Send, "m_hOwnerEntity", entity);
        SetVariantInt(upgradelevel);
        AcceptEntityInput(dispenser, "SetDispenserLevel", dispenser, dispenser, 0);
	}
    if (DeleteDispenser[client])
    {
        AcceptEntityInput(dispenser, "Kill");
        AcceptEntityInput(dispensertrigger, "Kill");
        DeleteDispenser[client] = false;
    }
	ActivateEntity(dispenser);
    ActivateEntity(dispensertrigger);

	return dispenser;
}