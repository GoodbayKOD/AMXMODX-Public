#include <amxmodx>
#include <hamsandwich>
#include <engine>
#include <fakemeta>
#include <cstrike>
#include <json>

/* */
// This define is declared in some .inc of the reapi (I use regame, I had to adapt all this to a pure .dll)
// From there you delete

#if !defined BIT
    #define BIT(%1)         (1<<(%1))
#endif

// https://wiki.alliedmods.net/Category:CS_Class_List
const m_pPlayer = 41; // CBasePlayer
const m_flNextAttack = 83; // CBaseMonster
const m_fInReload = 54; // CBasePlayerWeapon

enum _:m_hReloadData
{
    m_iReloadWeaponID,
    m_iReloadAnim,
    Float:m_fReloadTime
}

// Pointer where we are going to store the weapon handler
new g_pReload[33];
new Array:g_aWeapons;

// Max Clip for weapons
new const MAXCLIP[] = { -1, 13, -1, 10, 1, 7, -1, 30, 30, 1, 30, 20, 25, 30, 35, 25, 12, 20, 10, 30, 100, 8, 30, 30, 20, 2, 7, 30, 30, -1, 50 };

public plugin_init()
{
    register_plugin("Custom Reload", "1.0", "Goodbay");

    g_aWeapons = ArrayCreate(m_hReloadData);
    Server_LoadWeapons();

    new i, bHandler, szWeaponName[24], pStructure[m_hReloadData];

    // Add weapon to the bit mask
    for(i = 0; i < ArraySize(g_aWeapons); i++)
    {
        ArrayGetArray(g_aWeapons, i, pStructure, m_hReloadData);
        bHandler |= BIT(pStructure[m_iReloadWeaponID]);
    }
      
    for(i = CSW_NONE + 1; i <= CSW_LAST_WEAPON; i++)
    {
        if(!(bHandler & BIT(i)))
            continue; // CSW is not use for now

        get_weaponname(i, szWeaponName, charsmax(szWeaponName));

        // Here we are going to obtain the reload data, a single loop.
        RegisterHam(Ham_Item_Deploy, szWeaponName, "fw_Weapon_Deploy_Post", true);

        // We are going to interfere in the default values of the weapon, so we will make the pre-call
        RegisterHam(Ham_Weapon_Reload, szWeaponName, "fw_Weapon_Reload_Pre", false);
        RegisterHam(Ham_Item_PostFrame, szWeaponName, "fw_Weapon_PostFrame");
    }   
}

public Server_LoadWeapons()
{
    new JSON:jFile = json_parse("scripts/weapon_reload.json", true);

    // File isn't json
    if(jFile == Invalid_JSON)
        return; // do nothing

    new pStructure[m_hReloadData], szName[24], JSON:jWeapon;

    // Iter in the array
    for(new i = 0; i < json_array_get_count(jFile); i++)
    {
        // Get the object handle from array
        jWeapon = json_array_get_value(jFile, i);

        // Get weaponname
        json_object_get_string(jWeapon, "weapon", szName, charsmax(szName));

        // Cache
        pStructure[m_iReloadWeaponID]   = get_weaponid(szName);
        pStructure[m_iReloadAnim]       = json_object_get_number(jWeapon, "reload_anim");
        pStructure[m_fReloadTime]       = Float:json_object_get_real(jWeapon, "reload_delay");

        // Push
        ArrayPushArray(g_aWeapons, pStructure, m_hReloadData);
    }

    // Print test
    server_print("Custom reload - Array size: %d", ArraySize(g_aWeapons));
}

public fw_Weapon_Deploy_Post(const pEntity)
{
    new pPlayer, iWeaponID, i, pStructure[m_hReloadData];
    pPlayer = get_pdata_cbase(pEntity, m_pPlayer);
    iWeaponID = cs_get_weapon_id(pEntity);

    // JIC
    g_pReload[pPlayer] = -1;

    for(i = 0; i < ArraySize(g_aWeapons); i++)
    {
        ArrayGetArray(g_aWeapons, i, pStructure, m_hReloadData);

        // Filter weaponid
        if(pStructure[m_iReloadWeaponID] != iWeaponID)
            continue;

        // Set and break the loop
        g_pReload[pPlayer] = i;
        break;
    }
}

public fw_Weapon_Reload_Pre(const pEntity)
{
    // Get player id
    new pPlayer = get_pdata_cbase(pEntity, m_pPlayer);

    // No custom reload
    if(g_pReload[pPlayer] == -1)
        return HAM_IGNORED; // Ignores

    new iWeapon = cs_get_weapon_id(pEntity);
    new iAmmo = cs_get_weapon_ammo(pEntity);

    // Has its maximum number of bullets or greater | no ammunition
    if(iAmmo >= MAXCLIP[iWeapon] || cs_get_user_bpammo(pPlayer, iWeapon) <= 0)
        return HAM_SUPERCEDE;

    // Do recharge without ammo
    if(!iAmmo)
        return HAM_IGNORED;

    new pStructure[m_hReloadData];
    ArrayGetArray(g_aWeapons, g_pReload[pPlayer], pStructure, m_hReloadData);

    new iAnim = pStructure[m_iReloadAnim];

    // Has silen
    if(cs_get_weapon_silen(pEntity))
    {
        switch(iWeapon)
        {
            case CSW_M4A1:
                iAnim = 16;
            case CSW_USP:
                iAnim = 18;
        }
    }

    Player_WeaponAnim(pPlayer, iAnim);
    
    // Delay and tell the engine that the gun is reloading
    set_pdata_float(pPlayer, m_flNextAttack, pStructure[m_fReloadTime]);
    set_pdata_int(pEntity, m_fInReload, 1);
    return HAM_SUPERCEDE;
}

stock Player_WeaponAnim(const pPlayer, const iAnim)
{
	// Play anim now
	entity_set_int(pPlayer, EV_INT_weaponanim, iAnim);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, pPlayer);
	write_byte(iAnim);
	write_byte(0);
	message_end();
}

/* */