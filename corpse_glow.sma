#include <amxmodx>
#include <reapi>
#include <engine>

public plugin_init() 
{
    register_plugin("Glow Team Corpse", "1.0", "Goodbay");
    register_event("ClCorpse", "EV_ClCorpse", "a", "10=0");

    RegisterHookChain(RG_RoundEnd, "fw_RoundEnd_Post", true);

    RegisterHookChain(RG_CBasePlayer_Killed, "fw_Player_Killed_Post", true);
    RegisterHookChain(RG_CBasePlayer_Spawn, "fw_Player_Spawn_Post", true);
}

public EV_ClCorpse()
{
    new pPlayer = read_data(12);
    
    if(!pPlayer || !is_user_connected(pPlayer))d
        return;

    new pCorpse = create_entity("info_target");

    if(!pCorpse)
        return;

    new szModel[64];
    read_data(1, szModel, charsmax(szModel));

    entity_set_string(pCorpse, EV_SZ_classname, "fake_corpse");
    entity_set_model(pCorpse, fmt("models/player/%s/%s.mdl", szModel, szModel));

    entity_set_int(pCorpse, EV_INT_movetype, MOVETYPE_FLY);
    entity_set_int(pCorpse, EV_INT_solid, SOLID_TRIGGER);

    new Float:vOrigin[3], Float:vAngles[3];
    vOrigin[0] = read_data(2) / 128.0;
    vOrigin[1] = read_data(3) / 128.0;
    vOrigin[2] = read_data(4) / 128.0;

    vAngles[0] = float(read_data(5));
    vAngles[1] = float(read_data(6));
    vAngles[2] = float(read_data(7));

    entity_set_origin(pCorpse, vOrigin);
    entity_set_vector(pCorpse, EV_VEC_angles, vAngles);
    entity_set_size(pCorpse, Float:{-1.0, -1.0, -1.0}, Float:{1.0, 1.0, 1.0});

    entity_set_int(pCorpse, EV_INT_sequence, read_data(9));
    entity_set_float(pCorpse, EV_FL_frame, 255.0);

    new TeamName:iTeam = any:read_data(11), iColor[3];

    switch(iTeam)
    {
        case TEAM_TERRORIST:
            iColor[0] = 255;
        case TEAM_CT:
            iColor[2] = 255;
    }

    set_ent_rendering(pCorpse, kRenderFxGlowShell, iColor[0], iColor[1], iColor[2], kRenderNormal, 30);
}

public fw_RoundEnd_Post(WinStatus:iStatus, ScenarioEventEndRound:iEvent, Float:fDelay)
{
    // Delete the fake corpses
    remove_entity_name("fake_corpse");
}

public fw_Player_Killed_Post(const pVictim, const pAttacker, const iShouldGib)
{
    new iColor[3];
    new TeamName:iTeam = get_member(pVictim, m_iTeam);
    
    switch(iTeam)
    {
        case TEAM_TERRORIST:
            iColor[0] = 255;
        case TEAM_CT:
            iColor[2] = 255;
    }

    set_ent_rendering(pVictim, kRenderFxGlowShell, iColor[0], iColor[1], iColor[2], kRenderNormal, 30);
}

public fw_Player_Spawn_Post(const pPlayer)
{
    if(!is_user_alive(pPlayer))
        return;

    // Reset
    set_ent_rendering(pPlayer);
}