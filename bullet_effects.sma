#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>

#define nullptr             0
#define TASK_EFFECT         0042225
#define TASK_FREEZE         0042226

#define ADMIN_FIRE		ADMIN_MAP
#define ADMIN_ICE		ADMIN_CHAT
#define ADMIN_POISON	ADMIN_LEVEL_D

// Screenfade constants
const UNIT_SECOND 		= (1<<12);
const FFADE_IN 			= 0x0000;
const FFADE_STAYOUT 	= 0x0004;

// Avaible admin access for bullet effect
const BITSUM_ADMIN_BULLETS = ADMIN_POISON | ADMIN_ICE | ADMIN_FIRE

// Effect values (you can change it)
const POISON_COUNT              = 3;        // Damage count of Poison
const FIRE_COUNT                = 3;        // Damage count of Fire

const Float:POISON_INTERVAL     = 0.7;      // Interval of Poison damage
const Float:FIRE_INTERVAL       = 1.0;      // Interval of Fire damage
const Float:FROZEN_TIME         = 2.5;      // Time duration of the Frozen state
const Float:POISON_DAMAGE       = 10.0;     // Damage per interval of Poison
const Float:FIRE_DAMAGE         = 5.0;      // Damage per interval of Fire
const Float:EFFECT_CHANCE       = 27.5;     // Shoot a bullet with effect chance (is a Float Percent)

// List of weapons with bullet effect
new const WEAPONENTNAMES[][] = 
{ 
	"weapon_p228", 
	"weapon_scout", 
	"weapon_xm1014", 
	"weapon_c4", 
	"weapon_mac10",
	"weapon_aug", 
	"weapon_elite", 
	"weapon_fiveseven", 
	"weapon_ump45", 
	"weapon_sg550",
	"weapon_galil", 
	"weapon_famas", 
	"weapon_usp", 
	"weapon_glock18", 
	"weapon_awp", 
	"weapon_mp5navy", 
	"weapon_m249",
	"weapon_m3", 
	"weapon_m4a1", 
	"weapon_tmp", 
	"weapon_g3sg1", 
	"weapon_deagle", 
	"weapon_sg552",
	"weapon_ak47", 
	"weapon_p90" 
}

// Max bullet effects
enum _:MAX_EFFECTS
{
    B_EFFECT_NONE = 0,
    B_EFFECT_FIRE,
    B_EFFECT_POISON,
    B_EFFECT_ICE
}
new g_pPlayerEffect[33], g_pAccessEffect[33];
new g_bAttacking, g_bGetVectors;

// Bit handlers
#define flag_get(%1,%2)						(%1 & (1 << (%2 & 31)))
#define flag_set(%1,%2)						%1 |= (1 << (%2 & 31))
#define flag_unset(%1,%2)					%1 &= ~(1 << (%2 & 31))

// Macros
#define is_user_valid(%1)                   (1 <= %1 <= MaxClients)
#define is_user_valid_alive(%1)				(1 <= %1 <= MaxClients && is_user_alive(%1))
#define is_user_valid_connected(%1)			(1 <= %1 <= MaxClients && is_user_connected(%1))

#define Entity_Instance(%1)             	((%1 == -1) ? 0 : %1)

// Some arrays and vars
new Float:g_vEnd[3], Float:g_vOrigin[3];
new g_pHit;
new g_iDamageCount[MAX_EFFECTS][33];

// Indexed
new g_pFlameIndex, g_pGlassGib;

// Message ID
new g_msgScreenFade;

public plugin_precache()
{
    g_pFlameIndex   = precache_model("sprites/fire.spr");
    g_pGlassGib     = precache_model("models/glassgibs.mdl");
}

public plugin_init()
{
    register_plugin("Bullet Effects", "1.0", "Goodbay");

    new i;

    // Iter in weapon struct
    for(i = 0; i < sizeof(WEAPONENTNAMES); i++)
    {
        RegisterHam(Ham_Weapon_PrimaryAttack, WEAPONENTNAMES[i], "fw_Weapon_PrimaryAttack_Pre", false);
        RegisterHam(Ham_Weapon_PrimaryAttack, WEAPONENTNAMES[i], "fw_Weapon_PrimaryAttack_Post", true);
    }

    // Removing effect when Victim it's killed
    RegisterHookChain(RG_CBasePlayer_Killed, "fw_Player_Killed_Pre", true);
    RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "fw_Player_ResetMaxSpeed_Pre", false);

    // Here i cache the vectors and hit entity
    register_forward(FM_TraceLine, "fw_TraceLine_Post", true);

    // Message ID
    g_msgScreenFade = get_user_msgid("ScreenFade");
}

public client_putinserver(pPlayer)
{
    new iFlags = get_user_flags(pPlayer);

    // Reset
    g_pAccessEffect[pPlayer] = (iFlags & BITSUM_ADMIN_BULLETS) ? ((iFlags & ADMIN_POISON) ? B_EFFECT_POISON : ((iFlags & ADMIN_FIRE) ? B_EFFECT_FIRE : B_EFFECT_ICE)) : B_EFFECT_NONE;
    g_pPlayerEffect[pPlayer] = B_EFFECT_NONE;
}

public client_disconnected(pPlayer)
{
    // Remove task jic
    remove_task(pPlayer + TASK_EFFECT);
}

public fw_Weapon_PrimaryAttack_Pre(const pEntity)
{   
    // No have bullets (PrimaryAttackPre is called everytime you are using IN_ATTACK)
    if(get_member(pEntity, m_Weapon_iClip) <= nullptr)
		return HAM_IGNORED;

    static pPlayer;
    pPlayer = get_member(pEntity, m_pPlayer);

    // Don't have bullet access effect | Check the chance
    if(g_pAccessEffect[pPlayer] == B_EFFECT_NONE || !(random_float(1.0, 100.0) <= EFFECT_CHANCE))
        return HAM_IGNORED,

    // Add the flags
    flag_set(g_bGetVectors, pPlayer);
    flag_set(g_bAttacking, pPlayer);
    return HAM_IGNORED;
}

public fw_Weapon_PrimaryAttack_Post(const pEntity)
{
    static pPlayer;
    pPlayer = get_member(pEntity, m_pPlayer);

    // Isn't attacking, so no have bullets or admin level
    if(!flag_get(g_bAttacking, pPlayer))
        return HAM_IGNORED;

    // Unset to the next call
    flag_unset(g_bAttacking, pPlayer);
    
    // Get some vectorial data
    static Float:vOrigin[3], Float:vPlane[3], Float:vVelocity[3];
    entity_get_vector(pPlayer, EV_VEC_origin, vOrigin);
    entity_get_vector(pPlayer, EV_VEC_view_ofs, vPlane);

    // Crosshair positon & send a scalar speed
    xs_vec_add(vOrigin, vPlane, vOrigin);
    Math_SpeedVector(vOrigin, g_vEnd, 3000.0, vVelocity);

    // Shoot the tracer
    if(is_user_valid_alive(g_pHit))
        Player_SetEffect(g_pHit, pPlayer);

    // A colored tracer
    GameFX_BeamTracer(vOrigin, vVelocity, 1, (BIT(g_pAccessEffect[pPlayer]) & BIT(B_EFFECT_POISON)) ? 2 : (BIT(g_pAccessEffect[pPlayer]) & BIT(B_EFFECT_FIRE)) ? 1 : 3, 3);
    return HAM_IGNORED;
}

public fw_Player_Killed_Pre(const pVictim, const pAttacker, const iGib)
{
    // Remove if has an effect
    if(g_pPlayerEffect[pVictim] != B_EFFECT_NONE)
        Player_RemoveEffect(pVictim);
}

public fw_Player_ResetMaxSpeed_Pre(const pPlayer)
{
    // Player is frozen
	if(g_pPlayerEffect[pPlayer] != B_EFFECT_ICE)
        return HC_CONTINUE;
	
	// Prevent for moving
	entity_set_float(pPlayer, EV_FL_maxspeed, 1.0);
	return HC_SUPERCEDE;
}

public fw_TraceLine_Post(const Float:vStart[3], const Float:vEnd[3], iMonsters, pIgnore, iTrace)
{
    if(iMonsters != DONT_IGNORE_MONSTERS || !is_user_valid_alive(pIgnore) || !flag_get(g_bAttacking, pIgnore) || !flag_get(g_bGetVectors, pIgnore))
        return FMRES_IGNORED;

    // Get end positon & hit entity instance
    get_tr2(iTrace, TR_vecEndPos, g_vEnd);
    g_pHit = Entity_Instance(get_tr2(iTrace, TR_pHit));

    flag_unset(g_bGetVectors, pIgnore);
    return FMRES_IGNORED;
}

public Player_SetEffect(const pVictim, const pAttacker)
{
    // Don't overlap effect (unbalanced)
    if(g_pPlayerEffect[pVictim] != B_EFFECT_NONE)
        return 0; 

    new Float:fInterval;
    new iColor[3], iParams[2];
    iParams[0] = pAttacker;

    // Filter by Attacker effect access
    switch(g_pAccessEffect[pAttacker])
    {
        case B_EFFECT_FIRE:
        {
            // Set interval & count damage
            fInterval                                   = FIRE_INTERVAL;
            g_iDamageCount[B_EFFECT_POISON][pVictim]    = FIRE_COUNT;

            entity_get_vector(pVictim, EV_VEC_origin, g_vOrigin);

            g_vOrigin[0] += random_float(-5.0, 5.0);
            g_vOrigin[1] += random_float(-5.0, 5.0);
            g_vOrigin[2] += random_float(-10.0, 10.0);

            // Flame sprite/
            GameFX_Sprite(g_pFlameIndex, g_vOrigin, random_num(5, 10), 200);
        }
        case B_EFFECT_POISON:
        {
            fInterval                                   = POISON_INTERVAL;
            g_iDamageCount[B_EFFECT_POISON][pVictim]    = POISON_COUNT;
        }
        case B_EFFECT_ICE:
        {
            fInterval = FROZEN_TIME;

            // Screenfade
            GameFX_ScreenFade(pVictim, 0, _, FFADE_STAYOUT, {0, 50, 200}, 100);

            // Prevent playe move
            entity_set_float(pVictim, EV_FL_gravity, ((entity_get_int(pVictim, EV_INT_flags) & FL_ONGROUND) ? 999999.9 : 0.000001));
            rg_reset_maxspeed(pVictim);
        }
    }

    // Set color and victim effect
    iColor[g_pAccessEffect[pAttacker] - 1] = 255;
    g_pPlayerEffect[pVictim] = g_pAccessEffect[pAttacker];

    // Render FX & task effect
    set_rendering(pVictim, kRenderFxGlowShell, iColor[0], iColor[1], iColor[2], kRenderNormal, 1);
    set_task(fInterval, "Player_Task_BulletEffect", TASK_EFFECT + pVictim, iParams, sizeof(iParams), "b");
    return 1;
}

public Player_RemoveEffect(const pPlayer)
{
    remove_task(TASK_EFFECT + pPlayer);
    set_rendering(pPlayer);

    new iEffect = g_pPlayerEffect[pPlayer];
    g_pPlayerEffect[pPlayer] = B_EFFECT_NONE;

    // Remove freeze
    if(iEffect == B_EFFECT_ICE)
    {
        // Restore speed & gravity
        rg_reset_maxspeed(pPlayer);

        entity_set_int(pPlayer, EV_INT_movetype, MOVETYPE_WALK);
        entity_set_float(pPlayer, EV_FL_gravity, 1.0);

        // Gradually remove screen's blue tint
        GameFX_ScreenFade(pPlayer, _, _, _, {0, 50, 200}, 100);

        // Glass shatter
        entity_get_vector(pPlayer, EV_VEC_origin, g_vOrigin);
        GameFX_BreakModel(g_pGlassGib, g_vOrigin, 24.0, 16, random_num(-50, 50), 10, 10, 25, BREAK_GLASS);
    }
}

public Player_Task_BulletEffect(const iParams[], const taskid)
{
    static pVictim;
    pVictim = (taskid - TASK_EFFECT);

    // Victim or attacker are not valid or alive
    if(!is_user_valid_alive(pVictim) || !is_user_valid_alive(iParams[0]))
    {
        remove_task(taskid);
        return;
    }

    if(g_pPlayerEffect[pVictim] != B_EFFECT_ICE)
    {
        // Apply damage effect
        rg_apply_damage(iParams[0], pVictim, (g_pPlayerEffect[pVictim] == B_EFFECT_POISON) ? POISON_DAMAGE : FIRE_DAMAGE, DMG_BURN);

        if(g_pPlayerEffect[pVictim] == B_EFFECT_FIRE)
        {
            entity_get_vector(pVictim, EV_VEC_origin, g_vOrigin);

            g_vOrigin[0] += random_float(-5.0, 5.0);
            g_vOrigin[1] += random_float(-5.0, 5.0);
            g_vOrigin[2] += random_float(-10.0, 10.0);

            // Flame sprite/
            GameFX_Sprite(g_pFlameIndex, g_vOrigin, random_num(5, 10), 200);
        }
        
        // Continue until the end of the Damage Count
        if(!(--g_iDamageCount[g_pPlayerEffect[pVictim]][pVictim] <= nullptr))
            return;
    }

    Player_RemoveEffect(pVictim);
}

// A simple stock for apply damage
stock rg_apply_damage(const pAttacker, const pVictim, const Float:fDamage, const bBitDamage = DMG_BULLET)
{
    rg_multidmg_clear();
    rg_multidmg_add(pAttacker, pVictim, fDamage, bBitDamage | DMG_NEVERGIB);
    rg_multidmg_apply(pAttacker, pAttacker);
}

// Compute velocity by 2 origins
stock Math_SpeedVector(const Float:vStartOrigin[3], const Float:vEndOrigin[3], const Float:fSpeed, Float:vVelocity[3])
{
    // Compute this
    xs_vec_sub(vEndOrigin, vStartOrigin, vVelocity);
    
    // Apply it with some strange math
    xs_vec_mul_scalar(vVelocity, floatsqroot(fSpeed * fSpeed / (vVelocity[0] * vVelocity[0] + vVelocity[1] * vVelocity[1] + vVelocity[2] * vVelocity[2])), vVelocity);
    return 1;
}

// Paleta de colores: 0 = Blanco | 1 = Rojo | 2 = Verde | 3 = Azul | 4 = CS | 5 = Dorado | 7 = Morado | El resto son caca
stock GameFX_BeamTracer(const Float:vOrigin[3], const Float:vVelocity[3], iLife = 1, iColor = 0, iLenght = 1)
{
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vOrigin);
	write_byte(TE_USERTRACER);
	write_coord_f(vOrigin[0]);   	 	// x
	write_coord_f(vOrigin[1]);    		// y
	write_coord_f(vOrigin[2]);    		// z
	write_coord_f(vVelocity[0]); 		// Velocity x
	write_coord_f(vVelocity[1]); 		// Velocity y
	write_coord_f(vVelocity[2]); 		// Velocity z
	write_byte(iLife);  				// Life
	write_byte(iColor);   				// Color 
	write_byte(iLenght);   				// Lenght * 10
	message_end();  
}

stock GameFX_Sprite(const iSprite, const Float:vOrigin[3], const iScale, const iAlpha)
{
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vOrigin);
	write_byte(TE_SPRITE); 					// TE id
	write_coord_f(vOrigin[0]); 				// x
	write_coord_f(vOrigin[1]); 				// y
	write_coord_f(vOrigin[2]); 				// z
	write_short(iSprite); 		            // sprite
	write_byte(iScale); 					// scale
	write_byte(iAlpha); 					// brightness
	message_end();
}

public GameFX_BreakModel(iModelIndex, const Float:vOrigin[3], const Float:fAdd, iSize, iVelocity, iVelRand, iCount, iLife, iFlags)
{
    if(iVelRand == -1)
        iVelRand = random_num(0, 10);
        
    message_begin_f(MSG_BROADCAST, SVC_TEMPENTITY, vOrigin);
    write_byte(TE_BREAKMODEL);
    write_coord_f(vOrigin[0]);
    write_coord_f(vOrigin[1]);
    write_coord_f(vOrigin[2] + fAdd);
    write_coord(iSize);                 // size x
    write_coord(iSize);                 // size y
    write_coord(iSize);                 // size z
    write_coord(iVelocity);             // velocity x
    write_coord(iVelocity);             // velocity y
    write_coord(iVelocity);             // velocity z
    write_byte(iVelRand);             	// random velocity
    write_short(iModelIndex);           // model index that you want to break
    write_byte(iCount);                 // count
    write_byte(iLife);                  // life
    write_byte(iFlags);                 // flags
    message_end(); 
}

stock GameFX_ScreenFade(const pPlayer, const iDuration = 1, const iHold = 0, iType = FFADE_IN, const iColor[3] = {0, 0, 0}, const iAlpha)
{
	message_begin(MSG_ONE_UNRELIABLE, g_msgScreenFade, _, pPlayer);		
	write_short(UNIT_SECOND * iDuration);	// fade lasts this long duration
	write_short(UNIT_SECOND * iHold);		// fade lasts this long hold time
	write_short(iType);						// fade type (in / out)
	write_byte(iColor[0]);					// fade red
	write_byte(iColor[1]);					// fade green
	write_byte(iColor[2]);					// fade blue
	write_byte(iAlpha);						// fade alpha
	message_end();
}