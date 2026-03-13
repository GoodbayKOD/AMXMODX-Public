#include <amxmodx>
#include <engine>
#include <reapi>
#include <dg>

#define hat_class		"cosmetic"

new const Costume_Models[] = "models/dg/gg/costumes_base.mdl";
new g_iCostume[33];
new g_pEnable;

enum _:m_hCostumes
{
    m_szCostumeName[32],
    bool:m_bCostumeVIP
}

new const Server_Costumes[][] =
{
    {   "Lobo",                 false   },
    {   "Auriculares",          false   },
    {   "Hongo",                false   },
    {   "Capucha Racista",      false   },
    {   "Luffy",                false   },
    {   "Vikingo",              false   },
    {   "DJ",                   true    },
    {   "Espartano",            true    },
    {   "Superman",             true    },
    {   "Púa Venenosa",         true    },
    {   "Gasparin",             true    },
}

public plugin_precache()
{
    g_pEnable = create_cvar("gg_costume", "1", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY, "<habilitar>");

    if(get_pcvar_num(g_pEnable))
        precache_model(Costume_Models);
}

public plugin_init()
{
    register_plugin("[DRUNK GG] Cosmeticos", "1.0", "LeMua / Goodbay");

    if(!get_pcvar_num(g_pEnable))
        return;

    RegisterHookChain(RG_CBasePlayer_Spawn, "fw_Player_Spawn_Post", true);
    register_clcmd("say /hats", "clcmd_hats");
}

public client_putinserver(pPlayer)
    g_iCostume[pPlayer] = -1;

public client_disconnected(pPlayer, bool:bDrop, szMessage[], iMaxLen)
    g_iCostume[pPlayer] = -1;

public clcmd_hats(const pPlayer)
{
    if(!is_user_alive(pPlayer))
    {
        client_print_color(pPlayer, pPlayer, "^4[GG]^1 Necesitas estar vivo");
        return PLUGIN_HANDLED;
    }

    show_menu_costumes(pPlayer);
    return PLUGIN_HANDLED;
}

public fw_Player_Spawn_Post(const pPlayer)
{
    if(!is_user_alive(pPlayer))
        return;

    if(g_iCostume[pPlayer] != -1)
    {
        Player_RemoveCostume(pPlayer);
        Player_SetCostume(pPlayer, g_iCostume[pPlayer]);
    }
}

public show_menu_costumes(const pPlayer)
{
    new pMenu = menu_create("Selecciona un Cosmetico:", "menu_costumes");
    new i, len, szMenu[128], bool:bVip;
    new iAccess = dg_get_user_access(pPlayer);

    for(i = 0; i < sizeof(Server_Costumes); i++)
    {
        len = 0;
        bVip = Server_Costumes[i][m_bCostumeVIP];

        // Start
        len = formatex(szMenu, charsmax(szMenu), "\%c%s", (bVip && iAccess < ACCESS_VIP) ? "d" : "w", Server_Costumes[i][m_szCostumeName]);

        if(bVip)
            len += copy(szMenu[len], charsmax(szMenu) - len, " \rVIP");

        if(g_iCostume[pPlayer] == i)
            len += copy(szMenu[len], charsmax(szMenu) - len, " \y(Actual)");

        // Add
        menu_additem(pMenu, szMenu);
    }

    menu_setprop(pMenu, MPROP_NEXTNAME, "Siguiente");
    menu_setprop(pMenu, MPROP_BACKNAME, "Anterior");
    menu_setprop(pMenu, MPROP_EXITNAME, "Salir");

    menu_display(pPlayer, pMenu);
}

public menu_costumes(const pPlayer, const pMenu, const pKey)
{
    menu_destroy(pMenu);

    if(pKey == MENU_EXIT || !is_user_connected(pPlayer))
        return PLUGIN_HANDLED;

    new iAccess = dg_get_user_access(pPlayer);

    // Not VIP
    if(Server_Costumes[pKey][m_bCostumeVIP] && (iAccess < ACCESS_VIP))
    {
        client_print_color(pPlayer, pPlayer, "^4[GG]^1 Necesitas ser ^4VIP o mayor^1 para equipar este sombrero");
        return PLUGIN_HANDLED;
    }

    // Already equiped
    if(g_iCostume[pPlayer] == pKey)
    {
        client_print_color(pPlayer, pPlayer, "^4[GG]^1 Ya tienes equipado el sombrero:^4 %s", Server_Costumes[pKey][m_szCostumeName]);
        return PLUGIN_HANDLED;
    }

    g_iCostume[pPlayer] = pKey;
    Player_SetCostume(pPlayer, pKey);

    client_print_color(pPlayer, pPlayer, "^4[GG]^1 Te equipaste el sombrero: %s", Server_Costumes[pKey][m_szCostumeName])
    return PLUGIN_HANDLED;
}

stock Player_SetCostume(const pFollow, const pBody)
{
    new iEntity = rg_create_entity("info_target");

    if(iEntity)
    {
        entity_set_string(iEntity, EV_SZ_classname, hat_class);
        entity_set_model(iEntity, Costume_Models);

        entity_set_int(iEntity, EV_INT_movetype, MOVETYPE_FOLLOW);

        entity_set_edict(iEntity, EV_ENT_owner, pFollow);
        entity_set_edict(iEntity, EV_ENT_aiment, pFollow);        

        entity_set_int(iEntity, EV_INT_body, pBody);
    }

    return iEntity;
}

stock Player_RemoveCostume(const pPlayer)
{
	new pEntity = MaxClients;

	while((pEntity = find_ent_by_owner(pEntity, hat_class, pPlayer)) != 0)
	{
		remove_entity(pEntity);
		return 1;
	}

	return 0;
}