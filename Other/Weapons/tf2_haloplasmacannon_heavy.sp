#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#include <sdkhooks>
#include <dhooks>
#include <cw3-attributes>
#include <cw3-extras>
#include <tf2items>
#include <cw3>

#pragma semicolon 1
#pragma tabsize 0

#define MIN			512.0
#define PLUGIN_VERSION "1.0"
#define WEAPON_SLOTS_MAX  7
#define FAR_FUTURE 100000000.0
#define MAX_SOUND_FILE_LENGTH 128
#define MAX_MODEL_FILE_LENGTH 128

//int MercTeam = view_as<int>(TFTeam_Red);
//int BossTeam = view_as<int>(TFTeam_Blue);

public Plugin myinfo = {
    name = "The Type-52 plasma cannon",
    author = "Spyro. Just Spyro.",
    description = "Plasma cannon for heavyweapons guy",
    version = PLUGIN_VERSION,
    url = ""
};


#define SOUND_OVERHEAT "weapons/halo/plasmacannon/overheated_plasmacannon.wav"

int g_iWeapOwner[MAXPLAYERS+1];
int g_iOwnerSlot[WEAPON_SLOTS_MAX];
int g_iClient;
int g_iSlot;

Handle g_SDKCallMGWindDown, g_SDKCallMGRingFire;
DynamicDetour dtMinigunSharedAttack;

#define MINIGUN_HEAT_HUD_X -1.0
#define MINIGUN_HEAT_HUD_Y 0.70
#define MINIGUN_HUD_INTERVAL 0.2
#define MINIGUN_HEAT_SEGMENTS 28
CW3Weapon PlasmaCannon;
bool bUsingThisPlugin[MAXPLAYERS+1];
Handle MinigunHUD;
enum struct Internals
{
    int iShotsFired;
    bool bIsOverHeated;
    bool bVentButtonDown;
    float flUpdateHUDAt;
    float flOverheatDecaysAt;
    float flCooldownEndsAt;
    void ClearVars()
    {
        this.iShotsFired = 0;
        this.bIsOverHeated = false;
        this.bVentButtonDown = false;
        this.flUpdateHUDAt = FAR_FUTURE;
        this.flOverheatDecaysAt = FAR_FUTURE;
        this.flCooldownEndsAt = FAR_FUTURE;
    }
}

Internals WeapInternals[MAXPLAYERS+1][WEAPON_SLOTS_MAX];

enum struct Attributes
{
    float flProjDmg;
    int iShotsToOverheat;
    float flOverheatDecayTime;
    float flOverheatCDTime;
    int iOverheatDecayRate;
    float flBoltSpeed;
    float flDmgResist;

    void ClearVars()
    {
        this.flProjDmg = 0.0; 
        this.flBoltSpeed = 0.0;

        this.iShotsToOverheat = 0;
        this.iOverheatDecayRate = 0;
        this.flOverheatDecayTime = 0.0;
        this.flOverheatCDTime = 0.0;
        this.flDmgResist = 0.0;
    }
}

Attributes WeapAttribs[MAXPLAYERS+1][WEAPON_SLOTS_MAX];


public void OnPluginStart()
{
    LogMessage("[PLASMACANNON] Starting attribute plugin for type 52 plasma cannon");
    DHookMinigun();

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsValidClient2(iClient))
        continue;

        //PrintToConsoleAll("[PLASMACANNON] Hooking client %d think....", iClient);
        bUsingThisPlugin[iClient] = false;
        SDKHook(iClient, SDKHook_PostThinkPost, OnClientPostThinkPost);
    }

    MinigunHUD = CreateHudSynchronizer();
    //PrintToConsoleAll("[PLASMACANNON] All plugin paramaters set!");
}

public void OnMapStart()
{
    PrecacheSound(SOUND_OVERHEAT, true);
    //PrintToConsoleAll("[PLASMACANNON] Sound precached...");
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
}

/**
 * So! Dhooks! A useful but dangerous feature! In this plugin, Dhooks is used to detect the firing of the Minigun. 
 * Now, you might think, "Why don't I just use TF2_CalcIsAttackCritical() to detect minigun fire?" 
 * Two reasons: One is that CalcIsAttackCritical does not have a pre hook function to do things the frame before the weapon is fired
 * (which is needed for this plugin), and the second reason is that in the case of the minigun, CalcIsAttackCritical 
 *  will fire several times while the minigun is spinning up before it actually fires, which I do not want.
 */
public void DHookMinigun()
{
    GameData hGameConf = LoadGameConfigFile("tf2.cattr_starterpack");
    if (!hGameConf) 
    {
        SetFailState("Failed to load gamedata (tf2.cattr_starterpack).");
    }
    
    dtMinigunSharedAttack = DynamicDetour.FromConf(hGameConf, "CTFMinigun::SharedAttack()");
    bool mgAttackPreHooked = dtMinigunSharedAttack.Enable(Hook_Pre, OnMinigunAttackPre);
    bool mgAttackPostHooked = dtMinigunSharedAttack.Enable(Hook_Post, OnMinigunAttackPost);

    if (!mgAttackPreHooked || !mgAttackPostHooked) //Thse hooks are mandatory. Don't use the plugin if we can't hook them for any reason.
    {
        SetFailState("Failed to hook pre or post CTFMinigun::SharedAttack(). Plugin cannot continue.");
    }
    
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFMinigun::WindDown()");
    g_SDKCallMGWindDown = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFMinigun::RingOfFireAttack()");
    g_SDKCallMGRingFire = EndPrepSDKCall();
    
    delete hGameConf;
}

/*
* Attribute processing
*/ 
public Action CW3_OnAddAttribute(int slot, int client, const char[] attrib, const char[] plugin, const char[] value, bool whileActive)
{
    /*
	if (!StrEqual(plugin, "vsprattribs")) 
    return Plugin_Continue;
    */


    Action action = Plugin_Continue;

    //I like to have a "special" attribute that is required and used to confirm the plugin is in fact being used.
    //This saves me the trouble of putting the functions in every single attribute if statement.
    if (StrEqual(attrib, "Plasma Cannon", false)) 
    {
        bUsingThisPlugin[client] = true;
        g_iWeapOwner[client] = client;
        g_iOwnerSlot[slot] = slot;
        g_iClient = g_iWeapOwner[client];
        g_iSlot = g_iOwnerSlot[slot];
        //PrintToConsoleAll("Weapon client is %d, and their slot is %d. The client should be %d, and slot should be %d", g_iWeapOwner[client], g_iOwnerSlot[slot], client, slot);
        WeapInternals[client][slot].bVentButtonDown = (GetClientButtons(client) & IN_RELOAD) != 0;
        WeapInternals[client][slot].flUpdateHUDAt = GetEngineTime();
        action = Plugin_Handled;
    }

    if (StrEqual(attrib, "Damage per projectile", false))
    {
        WeapAttribs[client][slot].flProjDmg = PlasmaCannon.GetValueF(value, 20.0);
        //PrintToChat(client, "Damage set to %.1f", PlasmaCannon.GetValueF(value));
        action = Plugin_Handled;
    }

    if (StrEqual(attrib, "Shots to overheat", false))
    {
        bUsingThisPlugin[client] = true;

        WeapAttribs[client][slot].iShotsToOverheat = PlasmaCannon.GetValueI(value, 150);
        //PrintToChat(client, "Overheat set to %d", WeapAttribs[client][slot].iShotsToOverheat);
        action = Plugin_Handled;
    }

    if (StrEqual(attrib, "Overheat decay rate", false))
    {
        bUsingThisPlugin[client] = true;
        WeapAttribs[client][slot].iOverheatDecayRate = PlasmaCannon.GetValueI(value, 8);
        //PrintToChat(client, "Overheat set");
        action = Plugin_Handled;
    }

    if (StrEqual(attrib, "Overheat decay time", false))
    {
        WeapAttribs[client][slot].flOverheatDecayTime = PlasmaCannon.GetValueF(value, 1.5);
        action = Plugin_Handled;
    }

    if (StrEqual(attrib, "Overheat cooldown time"))
    {
        WeapAttribs[client][slot].flOverheatCDTime = PlasmaCannon.GetValueF(value, 7.0);
        action = Plugin_Handled;
    }


      
    return action;
}

public void CW3_OnWeaponRemoved(int slot, int client)
{
    if (bUsingThisPlugin[client])
    {
        WeapAttribs[client][slot].ClearVars();
        WeapInternals[client][slot].ClearVars();
    }
}


/*
*OnGameFrame/OnPlayerRunCmd
*/
public void OnGameFrame()
{
    float curTime = GetEngineTime();
    
    if (bUsingThisPlugin[g_iClient] && curTime >= WeapInternals[g_iClient][g_iSlot].flUpdateHUDAt && IsWeaponSlotActive(g_iClient, TFWeaponSlot_Primary))
    {
        int exactHeat[2];
        exactHeat[0] = WeapInternals[g_iClient][g_iSlot].iShotsFired;
        exactHeat[1] = WeapAttribs[g_iClient][g_iSlot].iShotsToOverheat;

        char heatSegments[MINIGUN_HEAT_SEGMENTS+1], HUDInfo[64];
        int segmentsRemaining = RoundFloat(WeapInternals[g_iClient][g_iSlot].iShotsFired * MINIGUN_HEAT_SEGMENTS / float(exactHeat[1]));
        for (int iHeat = 0; iHeat < MINIGUN_HEAT_SEGMENTS; iHeat++)
        {
            heatSegments[iHeat] = segmentsRemaining > 0 ? '|' : ':';
            segmentsRemaining--;
        }
        heatSegments[MINIGUN_HEAT_SEGMENTS] = 0;
        if (!WeapInternals[g_iClient][g_iSlot].bIsOverHeated)
        {
            int quarterHeat = RoundFloat(float(exactHeat[1]) * 0.25),
                halfHeat = RoundFloat(float(exactHeat[1]) * 0.5),
                threeQuartersHeat = RoundFloat(float(exactHeat[1]) * 0.75);
            if (exactHeat[0] <= quarterHeat) //Text green when less than or at 25% heat
            {
                SetHudTextParams(MINIGUN_HEAT_HUD_X, MINIGUN_HEAT_HUD_Y, MINIGUN_HUD_INTERVAL + 0.05, 25, 215, 175, 255);
            }
            else if (exactHeat[0] <= halfHeat) //Text yellow when over 25% and less than or at 50%
            {
                SetHudTextParams(MINIGUN_HEAT_HUD_X, MINIGUN_HEAT_HUD_Y, MINIGUN_HUD_INTERVAL + 0.05, 225, 215, 75, 255);
            }
            else if (exactHeat[0] <= threeQuartersHeat) //Text orange when over 50% and less than or at 75%
            {
                SetHudTextParams(MINIGUN_HEAT_HUD_X, MINIGUN_HEAT_HUD_Y, MINIGUN_HUD_INTERVAL + 0.05, 255, 165, 10, 255);
            }
            else if (exactHeat[0] > threeQuartersHeat) //Text red when over 75% heat.
            {
                SetHudTextParams(MINIGUN_HEAT_HUD_X, MINIGUN_HEAT_HUD_Y, MINIGUN_HUD_INTERVAL + 0.05, 225, 15, 15, 255);
            }

            Format(HUDInfo, sizeof(HUDInfo), "(HEAT)[%s][%d/%d]", heatSegments, exactHeat[0], exactHeat[1]);
        }
        else
        {
            SetHudTextParams(MINIGUN_HEAT_HUD_X, MINIGUN_HEAT_HUD_Y, 0.5, 255, 50, 25, 255, 1, 7.0, 0.5, 0.5);
            Format(HUDInfo, sizeof(HUDInfo), "[OVERHEATED]");
            ShowSyncHudText(g_iClient, MinigunHUD, "%s", HUDInfo);
            WeapInternals[g_iClient][g_iSlot].flUpdateHUDAt = curTime + 1.0;
            return;
        }
        ShowSyncHudText(g_iClient, MinigunHUD, "%s", HUDInfo);
        WeapInternals[g_iClient][g_iSlot].flUpdateHUDAt = curTime + MINIGUN_HUD_INTERVAL;
    }
}


public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (g_iClient != clientIdx)
    return Plugin_Continue;

    Action cmdResult = Plugin_Continue;

    if (bUsingThisPlugin[clientIdx])
    {
        cmdResult = CmdVentMinigun(clientIdx, buttons); 
    }

    return cmdResult;
}

/*
* Bread and butter of this weapon
*/
public void OnEntityCreated(int spawnedEnt, const char[] entClassname)
{
    if (StrEqual(entClassname, "tf_projectile_rocket") && IsValidEntity(spawnedEnt))
    {
        RequestFrame(Frame_ChangeRocket, spawnedEnt);
    }
}


void Frame_ChangeRocket(int rocket)
{
    int owner = GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity");
    float rocketPos[3];
    if (owner == g_iClient)
    {
        //PrintToConsoleAll("Changing spawned rocket...");
        
        SetEntityModel(rocket, "models/weapons/w_models/w_baseball.mdl");
        SetEntPropFloat(rocket, Prop_Send, "m_flModelScale", 0.1);
        AttachParticle(rocket, "drg_cow_rockettrail_fire_blue");
        
        GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", rocketPos);
        rocketPos[2] -= 20.0; //Shift Z down
        TeleportEntity(rocket, rocketPos, NULL_VECTOR, NULL_VECTOR);
        //PrintToConsoleAll("Teleporting rocket....");
        HookProjectile(rocket);
    }
}

void HookProjectile(int rocket)
{
    SDKHook(rocket, SDKHook_Touch, PlasmaBolt_OnPlayerTouch);
}


public Action PlasmaBolt_OnPlayerTouch(int rocket, int victim)
{
    if (IsValidNPEnt(rocket))
	{
        int solFlags = GetEntProp(victim, Prop_Send, "m_usSolidFlags");

        bool victimIsClient = IsValidClient2(victim, true),
             victimIsEngieBuilding = (IsValidNPEnt(victim) && IsInstanceOf(victim, "obj_", true)),
             victimIsNotSolidObject = (!IsValidClient2(victim) && solFlags & view_as<int>(FSOLID_NOT_SOLID));

        if (victimIsNotSolidObject) //Check if object it hits is a non-solid entity, lest it vanish in thin air.
        {
            return Plugin_Continue;
        }
		if (victimIsClient)
		{
			if (GetClientTeam(g_iClient) != GetClientTeam(victim))
			{
				float damage = WeapAttribs[g_iClient][g_iSlot].flProjDmg;
                float playerPos[3], victimPos[3];

				//Setup distance between player and target
				GetEntPropVector(g_iClient, Prop_Data, "m_vecOrigin", playerPos);
				GetClientAbsOrigin(victim, victimPos);
				float distance = GetVectorDistance(playerPos, victimPos);

				//Slightly less standard hitscan rampup and falloff
				float dmgFalloffMod = ClampFloat((512.0 / distance), 1.4, 0.85);
				damage *= dmgFalloffMod;
				SDKHooks_TakeDamage(victim, rocket, g_iClient, damage, DMG_ENERGYBEAM);
			}
		}
        else if (victimIsEngieBuilding) //Damage buildings
        { 
            float boltDmg = WeapAttribs[g_iClient][g_iSlot].flProjDmg;
            SDKHooks_TakeDamage(victim, rocket, g_iClient, boltDmg, DMG_ENERGYBEAM);
            RemoveEntity(rocket);
            return Plugin_Handled;
        }
	}

    RemoveEntity(rocket);
	return Plugin_Handled; // prevent explosion
}

static bool s_bPrimaryAttackAvailable;
public MRESReturn OnMinigunAttackPre(int weapon) 
{
	float flNextPrimaryAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
	s_bPrimaryAttackAvailable = flNextPrimaryAttack <= GetGameTime();
}

public MRESReturn OnMinigunAttackPost(int weapon) 
{
	if (!s_bPrimaryAttackAvailable || GetEntProp(weapon, Prop_Send, "m_iWeaponState") != view_as<int>(MG_Firing) || !bUsingThisPlugin[g_iClient])
    {
		return MRES_Ignored;
	}

    //PrintToConsoleAll("Post minigun attack executing...client firing is %d", g_iClient);
	int overheatShots = WeapAttribs[g_iClient][g_iSlot].iShotsToOverheat;
    bool overheated = (WeapInternals[g_iClient][g_iSlot].iShotsFired >= overheatShots);
	float flCooldown = WeapAttribs[g_iClient][g_iSlot].flOverheatCDTime;
    WeapInternals[g_iClient][g_iSlot].iShotsFired++;
    //PrintToConsoleAll("Shots fired, %d out of %d", WeapInternals[g_iClient][g_iSlot].iShotsFired, WeapAttribs[g_iClient][g_iSlot].iShotsToOverheat);
    WeapInternals[g_iClient][g_iSlot].flOverheatDecaysAt = GetGameTime() + WeapAttribs[g_iClient][g_iSlot].flOverheatDecayTime;
    if (overheated)
    {
        PrintToChatAll("OVERHEAT!!!!");
        EmitSoundToClient(g_iClient, SOUND_OVERHEAT);
        PrintToChatAll("Emitting overheat sound...");
        OverheatWeapon(weapon, flCooldown);
        WeapInternals[g_iClient][g_iSlot].iShotsFired = overheatShots;
        WeapInternals[g_iClient][g_iSlot].bIsOverHeated = true;
        WeapInternals[g_iClient][g_iSlot].flOverheatDecaysAt = FAR_FUTURE;
        WeapInternals[g_iClient][g_iSlot].flCooldownEndsAt = (GetGameTime() + WeapAttribs[g_iClient][g_iSlot].flOverheatCDTime);
        SDKCall(g_SDKCallMGWindDown, weapon);
    }
	
	return MRES_Ignored;
}

public Action CmdVentMinigun(int client, int buttonCmd)
{
    if (!IsValidClient2(client))
    return Plugin_Handled;

    bool ventButtonHeld = (buttonCmd & IN_RELOAD) != 0,
         ventButtonReleased = (!ventButtonHeld && WeapInternals[client][g_iSlot].bVentButtonDown);
        
    if (ventButtonHeld)
    {
        WeapInternals[client][g_iSlot].flOverheatDecaysAt = GetGameTime();
        SDKCall(g_SDKCallMGRingFire); //Pls dont crash stuff.
    }

    if (ventButtonReleased || WeapInternals[g_iClient][g_iSlot].iShotsFired <= 0)
    {
        WeapInternals[g_iClient][g_iSlot].flOverheatDecaysAt = GetGameTime() + WeapAttribs[g_iClient][g_iSlot].flOverheatDecayTime;
    }

    return Plugin_Continue;
}

public void OnClientPostThinkPost(int client) 
{
    if (!bUsingThisPlugin[client])
    {
        return;
    }
	bool overheated = WeapInternals[g_iClient][g_iSlot].bIsOverHeated;
    bool hasHeat = (WeapInternals[g_iClient][g_iSlot].iShotsFired > 0);

    // no overheat to deal with
    if (WeapInternals[g_iClient][g_iSlot].iShotsFired <= 0) 
    {
        return;
    }
    
    // overheated -- don't do anything until it's cleared
    if (overheated) 
    {
        //PrintToConsoleAll("Cooling off...");
        if (GetGameTime() >= WeapInternals[g_iClient][g_iSlot].flCooldownEndsAt)
        {
            //PrintToConsoleAll("Weapon cooled off...");
            WeapInternals[g_iClient][g_iSlot].iShotsFired = 0;
            WeapInternals[g_iClient][g_iSlot].bIsOverHeated = false;
        }
        
        return;
    }
    
    // attempt to decay if we have some amount and we can start decreasing it

    if (hasHeat) 
    {
        if (GetGameTime() >= WeapInternals[g_iClient][g_iSlot].flOverheatDecaysAt)
        {
            //PrintToConsoleAll("Decaying heat....");
            WeapInternals[g_iClient][g_iSlot].iShotsFired -= WeapAttribs[g_iClient][g_iSlot].iOverheatDecayRate;
            if (WeapInternals[g_iClient][g_iSlot].iShotsFired < 0) 
            {
                WeapInternals[g_iClient][g_iSlot].iShotsFired = 0;
            }
            WeapInternals[g_iClient][g_iSlot].flOverheatDecaysAt = GetGameTime() + WeapAttribs[g_iClient][g_iSlot].flOverheatDecayTime;
        }
    }
}

public void OverheatWeapon(int weapon, float cooldown)
{
    float flCooldownEnd = GetGameTime() + cooldown;

    //PrintToChatAll("[OVERHEATWEAPON] Overheating weapon....");
    SetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack", flCooldownEnd);
    SetEntPropFloat(weapon, Prop_Data, "m_flNextSecondaryAttack", flCooldownEnd);
}


