#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <xs>

const Float:MEDIO_OFFSET = 60.0;        // Palito del medio
const Float:LADOS_OFFSET = 40.0;        // Palidos de los lados
const Float:RADIO_DETECCION = 100.0;    // Rango de deteccion

// Color de los palitos
new const COLOR_BEAM[3] = {0, 255, 0};

#define Zone_Class "tucabezona"

#define is_user_valid(%1)				(1 <= %1 <= get_maxplayers())

new g_pLaserBeam;

public plugin_precache()
{
    register_plugin("Marcador", "1.0", "Goodbay");

    g_pLaserBeam = precache_model("sprites/laserbeam.spr");
}

public plugin_init()
{
    register_think(Zone_Class, "fw_Zone_Think");

    register_clcmd("say /linea", "clcmd_zone");
    register_clcmd("say /borrar", "clcmd_zonedel");
}

public clcmd_zone(const pPlayer)
{
    if(!is_user_alive(pPlayer))
        return PLUGIN_HANDLED;

    if(Server_CreateZone(pPlayer))
        client_print_color(pPlayer, pPlayer, "^4[JB]^1 Creaste un marcador");
    else
        client_print_color(pPlayer, pPlayer, "^4[JB]^1 No se pudo crear el marcador");

    return PLUGIN_HANDLED;
}

public clcmd_zonedel(const pPlayer)
{
    if(!is_user_alive(pPlayer))
        return PLUGIN_HANDLED;

    new pEntity = find_ent_by_owner(-1, Zone_Class, pPlayer);

    if(pEntity)
    {
        client_print_color(pPlayer, pPlayer, "^4[JB]^1 Borraste un marcador");
        remove_entity(pEntity);
    }
    else
    {
        client_print_color(pPlayer, pPlayer, "^4[JB]^1 No se pudo borrar el marcador");
    }

    return PLUGIN_HANDLED; 
}

public fw_Zone_Think(const pEntity)
{
    if(!is_valid_ent(pEntity))
        return;

    static pPlayer;
    pPlayer = entity_get_edict(pEntity, EV_ENT_owner);

    if(!pPlayer || !is_user_alive(pPlayer))
    {
        remove_entity(pEntity);
        return;
    }

    static Float:vOrigin[3], iCount, iPlayer;
    entity_get_vector(pEntity, EV_VEC_origin, vOrigin);

    iPlayer = -1;
    iCount = 0;

    while((iPlayer = find_ent_in_sphere(iPlayer, vOrigin, RADIO_DETECCION)) != 0)
    {
        // Not valid
        if(!is_user_valid(iPlayer))
            break;

        if(!is_user_alive(iPlayer))
            continue;

        iCount++;
    }

    set_hudmessage(0, 255, 0, -1.0, 0.35, .holdtime = 0.1);
    show_hudmessage(pPlayer, "[ Marcador: %d ]", iCount);

    // Esto no tocar
    GameFX_DrawLaser(
        vOrigin[0], 
        vOrigin[1], 
        vOrigin[2] + MEDIO_OFFSET, 
        vOrigin[0], 
        vOrigin[1], 
        vOrigin[2], 
        COLOR_BEAM, 
        200
        );

    GameFX_DrawLaser(
        vOrigin[0] + LADOS_OFFSET, 
        vOrigin[1], 
        vOrigin[2], 
        vOrigin[0] - LADOS_OFFSET, 
        vOrigin[1], 
        vOrigin[2], 
        COLOR_BEAM, 
        200
        );

    GameFX_DrawLaser(
        vOrigin[0], 
        vOrigin[1] + LADOS_OFFSET, 
        vOrigin[2], 
        vOrigin[0], 
        vOrigin[1] - LADOS_OFFSET, 
        vOrigin[2], 
        COLOR_BEAM, 
        200);

    entity_set_float(pEntity, EV_FL_nextthink, get_gametime() + 0.1);
}

stock Server_CreateZone(const pPlayer)
{
    new Float:vCursor[3];
    Math_GetAimOrigin(pPlayer, vCursor);

    new pEntity = create_entity("info_target");

    if(pEntity)
    {
        entity_set_string(pEntity, EV_SZ_classname, Zone_Class);

        entity_set_int(pEntity, EV_INT_movetype, MOVETYPE_NONE);
        entity_set_edict(pEntity, EV_ENT_owner, pPlayer);

        entity_set_origin(pEntity, vCursor);

        // Editor
        entity_set_float(pEntity, EV_FL_nextthink, get_gametime() + 0.1);
    }

    return pEntity;
}

public Math_GetAimOrigin(const pPlayer, Float:vOutput[3])
{
    new Float:vOrigin[3], Float:vPlane[3], Float:vForward[3], Float:vEnd[3], Float:vStart[3];

    // Punto de mira
    entity_get_vector(pPlayer, EV_VEC_origin, vOrigin);
    entity_get_vector(pPlayer, EV_VEC_view_ofs, vPlane);

    xs_vec_add(vOrigin, vPlane, vStart);

    entity_get_vector(pPlayer, EV_VEC_v_angle, vPlane);
    angle_vector(vPlane, ANGLEVECTOR_FORWARD, vForward);

    // Pa adelante
    xs_vec_add_scaled(vStart, vForward, 9999.0, vEnd);

    new hTrace = create_tr2();

    // Trace
    engfunc(EngFunc_TraceLine, vStart, vEnd, DONT_IGNORE_MONSTERS, pPlayer, hTrace);
    get_tr2(hTrace, TR_vecEndPos, vOutput);
    free_tr2(hTrace);
    return 1;
}

stock GameFX_DrawLaser(Float:vStart1, Float:vStart2, Float:vStart3, Float:vEnd1, Float:vEnd2, Float:vEnd3, const iColors[3], iAlpha = 200, pPlayer = 0)
{
	message_begin_f((pPlayer ? MSG_ONE_UNRELIABLE : MSG_BROADCAST), SVC_TEMPENTITY, .player = pPlayer);
	write_byte(TE_BEAMPOINTS)
	write_coord_f(vStart1) // x
	write_coord_f(vStart2) // y
	write_coord_f(vStart3) // z
	write_coord_f(vEnd1) // x axis
	write_coord_f(vEnd2) // y axis
	write_coord_f(vEnd3) // z axis
	write_short(g_pLaserBeam) // sprite
	write_byte(0)			// starting frame
	write_byte(0)			// frame rate in 0.1's
	write_byte(1)		// life in 0.1's
	write_byte(10)		// line width in 0.1's
	write_byte(0)		// noise
	write_byte(iColors[0])		// R
	write_byte(iColors[1])		// G
	write_byte(iColors[2])		// B
	write_byte(iAlpha)		// brightness
	write_byte(10)		// scroll speed in 0.1's
	message_end()
}
