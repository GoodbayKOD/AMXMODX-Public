#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <xs> 
#include <reapi>

#define nulltpr 0

// Square macro
#define Math_Square(%1)     (%1 * %1)

// Some constants
const ITEM_TEAM = EV_INT_skin;
const Float:DEVICE_HEALTH = 5.0;

new const ServerFiles_Device[] = "models/metalarena/alice_device.mdl";

public plugin_precache()
{
    precache_model(ServerFiles_Device);
}

public plugin_init()
{
    register_plugin("MetalArena Totem", "1.0", "Goodbay");

    register_clcmd("device", "clcmd_device");
}

public clcmd_device(const pPlayer)
{
	if(!is_user_alive(pPlayer))
		return PLUGIN_HANDLED;

	/*if(g_hClass[pPlayer] != CLASS_ALICE)
	{
		client_print_color(pPlayer, print_team_default, "%s %L", g_szPrefix, LANG_PLAYER, "PRINT_ONLY_ALICE");
		return PLUGIN_HANDLED;
	}*/

	Entity_DeviceSpawn(pPlayer);
	return PLUGIN_HANDLED;
}

public fw_Device_Think(const pEntity)
{
    if(!is_valid_ent(pEntity))
        return;

    static Float:fGameTime;
    fGameTime = get_gametime();

    entity_set_float(pEntity, EV_FL_nextthink, fGameTime + 0.1);

    if(entity_get_int(pEntity, EV_INT_sequence) == 0)
    {
        if(!Math_AnimEnded(pEntity, 0.7, 30.0))
            return;

        Entity_SetSequence(pEntity, 1);
    }

    static Float:fDelay;
    fDelay = entity_get_float(pEntity, EV_FL_fuser1);

    if(fDelay <= fGameTime)
    {
        static pPlayer, pTeam;
        pTeam = entity_get_int(pEntity, ITEM_TEAM);

        static Float:vOrigin[3], Float:vPlayerOrigin[3];
        entity_get_vector(pEntity, EV_VEC_origin, vOrigin);

        static Float:fHealth, Float:fMaxHealth, Float:fDistance;

        for(pPlayer = 1; pPlayer <= MaxClients; pPlayer++)
        {
            // Not alive || not same team
            if(!is_user_alive(pPlayer) || (pTeam && (get_member(pPlayer, m_iTeam) == pTeam)))
                continue;

            entity_get_vector(pPlayer, EV_VEC_origin, vPlayerOrigin);

            fDistance = xs_vec_sqdistance(vOrigin, vPlayerOrigin);

            if(fDistance > Math_Square(250.0))
                continue;

            fHealth     = entity_get_float(pPlayer, EV_FL_health);
            fMaxHealth  = entity_get_float(pPlayer, EV_FL_max_health);

            if(fHealth >= fMaxHealth)
                continue;

            entity_set_float(pPlayer, EV_FL_health, floatmin(fHealth + DEVICE_HEALTH, fMaxHealth));
        }

        // Next delay
        entity_set_float(pEntity, EV_FL_fuser1, fGameTime + 0.85);
    }
}

stock Entity_DeviceSpawn(const pPlayer)
{
    new Float:vOrigin[3], Float:vPlane[3];
    entity_get_vector(pPlayer, EV_VEC_origin, vOrigin);
    entity_get_vector(pPlayer, EV_VEC_view_ofs, vPlane);
        
    xs_vec_add(vOrigin, vPlane, vOrigin);

    new pEntity = Breakable_Init(ServerFiles_Device, MOVETYPE_TOSS, "2", Float:{ -13.0, -6.4, -1.0 }, Float:{ 13.0, 6.4, 50.0}, vOrigin, SOLID_BBOX);

    if(pEntity)
    {
        entity_set_string(pEntity, EV_SZ_classname, "totem_alice");

        entity_set_float(pEntity, EV_FL_health, 250.0);
        entity_set_float(pEntity, EV_FL_nextthink, get_gametime() + 0.1);

        entity_set_int(pEntity, ITEM_TEAM, get_member(pPlayer, m_iTeam));
        entity_set_edict(pEntity, EV_ENT_owner, pPlayer);

        SetThink(pEntity, "fw_Device_Think");
        Entity_SetSequence(pEntity, 0);
    }
}

stock Breakable_Init(const szModel[], const iMovement, const szMaterial[2], const Float:vMins[3], const Float:vMaxs[3], const Float:vOrigin[3], const iSolid = SOLID_BBOX)
{
    static pEntity;
    pEntity = create_entity("func_breakable");

    if(pEntity)
    {
        DispatchKeyValue(pEntity, "material", szMaterial);
        DispatchSpawn(pEntity);
        
        entity_set_model(pEntity, szModel);

        entity_set_int(pEntity, EV_INT_solid, iSolid);
        entity_set_int(pEntity, EV_INT_movetype, iMovement);
        
        entity_set_size(pEntity, vMins, vMaxs);
        entity_set_origin(pEntity, vOrigin);
    }

    return pEntity;
}

stock Math_AnimEnded(const pEntity, Float:fAnimDuration, Float:fFramesPerSecond) 
{
    if((get_gametime() - entity_get_float(pEntity, EV_FL_animtime)) < (fAnimDuration * fFramesPerSecond) / (entity_get_float(pEntity, EV_FL_framerate) * fFramesPerSecond)) 
		return false;
    
    return true;
}

stock Entity_SetSequence(const pEntity, const iSequence, const Float:fFrameRate = 1.0)
{
	entity_set_float(pEntity, EV_FL_animtime, get_gametime());
	entity_set_float(pEntity, EV_FL_framerate, fFrameRate);

	entity_set_int(pEntity, EV_INT_sequence, iSequence);
}
