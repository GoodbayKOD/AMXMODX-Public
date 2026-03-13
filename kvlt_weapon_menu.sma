#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <fun>

// This define is declared in some .inc of the reapi (I use regame, I had to adapt all this to a pure .dll)
// From there you delete it
#if !defined BIT
    #define BIT(%1)         (1<<(%1))
#endif

#define nullptr    0

// Player team offset
const m_iPlayerTeam = 114;
const MAX_RANDOMIZE = 10;

// CS Teams
enum _:MAX_CS_TEAMS
{
	FM_CS_TEAM_UNASSIGNED = 0,
	FM_CS_TEAM_T,
	FM_CS_TEAM_CT,
	FM_CS_TEAM_SPECTATOR
}

// Max BP ammo for weapons
new const MAX_BPAMMO[] = { -1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 100, 120,
			30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100, 8 }

// Weapon entity names
new const Weapon_Entity_Names[][] = 
{ 
	"", 
	"weapon_p228", 
	"", 
	"weapon_scout", 
	"weapon_hegrenade", 
	"weapon_xm1014", 
	"weapon_c4", 
	"weapon_mac10",
	"weapon_aug", 
	"weapon_smokegrenade", 
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
	"weapon_flashbang", 
	"weapon_deagle", 
	"weapon_sg552",
	"weapon_ak47", 
	"weapon_knife", 
	"weapon_p90" 
}

enum _:m_hCategory
{
    CAT_SHOTGUN = 0,
    CAT_SMG,
    CAT_RIFLE,
    CAT_SNIPER,
    CAT_MACHINEGUN,
    CAT_TACTICAL
}

enum _:m_hCategoryData
{
    m_szCategoryName[42],
    m_bCategoryBitsum
}

new const Weapon_Menu_Categories[m_hCategory][m_hCategoryData] =
{//     Name                Bitsum
    {   "Shotguns",         CSW_ALL_SHOTGUNS        },
    {   "SMGs",             CSW_ALL_SMGS            },
    {   "Rifles",           CSW_ALL_RIFLES          },
    {   "Snipers",          CSW_ALL_SNIPERRIFLES    },
    {   "Machine Guns",     CSW_ALL_MACHINEGUNS     },
    {   "Tactical",         CSW_SHIELDGUN           }
}

// structure data
enum _:m_hWeaponData
{
    m_szWeaponName[42],
    m_iWeaponCSW,
    m_bWeaponTeam
}

// For better organization, separate structures (Primary, Secondary, Other)
new const Weapons_Primary[][m_hWeaponData] =
{//     Name            Base                Team
    {   "M3",           CSW_M3,             BIT(FM_CS_TEAM_T) | BIT(FM_CS_TEAM_CT)      },
    {   "XM1014",       CSW_XM1014,         BIT(FM_CS_TEAM_T) | BIT(FM_CS_TEAM_CT)      },

    {   "Mac-10",       CSW_MAC10,          BIT(FM_CS_TEAM_T)                           },
    {   "TMP",          CSW_TMP,            BIT(FM_CS_TEAM_CT)                          },
    {   "MP5-Navy",     CSW_MP5NAVY,        BIT(FM_CS_TEAM_CT) | BIT(FM_CS_TEAM_T)      },
    {   "P90",          CSW_P90,            BIT(FM_CS_TEAM_CT) | BIT(FM_CS_TEAM_T)      },
    {   "UMP45",        CSW_UMP45,          BIT(FM_CS_TEAM_CT) | BIT(FM_CS_TEAM_T)      },

    {   "Galil",        CSW_GALIL,          BIT(FM_CS_TEAM_T)                           },
    {   "Famas",        CSW_FAMAS,          BIT(FM_CS_TEAM_CT)                          },
    {   "Aug",          CSW_AUG,            BIT(FM_CS_TEAM_CT)                          },
    {   "AK-47",        CSW_AK47,           BIT(FM_CS_TEAM_T)                           },
    {   "M4A1",         CSW_M4A1,           BIT(FM_CS_TEAM_CT)                          },
    {   "Krieg 552",    CSW_SG552,          BIT(FM_CS_TEAM_T)                           },
    {   "Krieg 550",    CSW_SG550,          BIT(FM_CS_TEAM_CT)                          },
    {   "D3/AU-1",      CSW_G3SG1,          BIT(FM_CS_TEAM_T)                           },
    {   "Scout",        CSW_SCOUT,          BIT(FM_CS_TEAM_CT) | BIT(FM_CS_TEAM_T)      },
    {   "AWP",          CSW_AWP,            BIT(FM_CS_TEAM_CT) | BIT(FM_CS_TEAM_T)      },

    {   "M249",         CSW_M249,           BIT(FM_CS_TEAM_CT) | BIT(FM_CS_TEAM_T)      },
    {   "Shield",       CSW_SHIELDGUN,      BIT(FM_CS_TEAM_CT)                          }
}
new g_pPrimary[33];

new const Weapons_Secondary[][m_hWeaponData] =
{//     Name            Base                Team
    {   "Glock18",      CSW_GLOCK18,        BIT(FM_CS_TEAM_T) | BIT(FM_CS_TEAM_CT)      },
    {   "USP45",        CSW_USP,            BIT(FM_CS_TEAM_T) | BIT(FM_CS_TEAM_CT)      },
    {   "P228",         CSW_P228,           BIT(FM_CS_TEAM_T) | BIT(FM_CS_TEAM_CT)      },
    {   "Deagle",       CSW_DEAGLE,         BIT(FM_CS_TEAM_T) | BIT(FM_CS_TEAM_CT)      },
    {   "Dual Elites",  CSW_ELITE,          BIT(FM_CS_TEAM_T)                           },
    {   "Fiveseven",    CSW_FIVESEVEN,      BIT(FM_CS_TEAM_CT)                          }
}
new g_pSecondary[33];

// enum to do weapons procurement checks
enum _:m_hMaxSlot
{
    SLOT_NONE = 0,
    SLOT_SECONDARY,
    SLOT_PRIMARYs
}

new const Weapon_Slot_Name[m_hMaxSlot][] =
{
    "None",
    "Secondary",
    "Primary"
}
new g_bBuyed;

// Cvars
new g_vCategorize, g_vShield, g_vGrayed;

// Bitflagsa
new g_bNotAgain;
new bool:g_bHamBot;

enum _:MAX_BUFFER_DATA
{
    DATA_1 = 0,
    DATA_2,
    DATA_3
}
new g_iBuffer[MAX_BUFFER_DATA];

// Bithandlers
#define flag_get(%1,%2)						(%1 & (1 << (%2 & 31)))
#define flag_set(%1,%2)						%1 |= (1 << (%2 & 31))
#define flag_unset(%1,%2)					%1 &= ~(1 << (%2 & 31))

public plugin_init()
{
    // Don't change, only plugin name.
    // NOTE: Can be changed version and author (add, not delete mine) if major changes were made to the menu, not edits
    register_plugin("Weapon Menu", "1.0", "Goodbay");

    // Create the cvars
    bind_pcvar_num(create_cvar("kvlt_menu_categorize", "0", FCVAR_SERVER, "Categorizes the weapons according to their type", true, .has_max = true, .max_val = 1.0), g_vCategorize);
    bind_pcvar_num(create_cvar("kvlt_menu_shield", "0",     FCVAR_SERVER, "Enables shields for CTs", true, .has_max = true, .max_val = 1.0), g_vShield);
    bind_pcvar_num(create_cvar("kvlt_menu_grayed", "1",     FCVAR_SERVER, "1 Unavailable weapons/options will be grayed out - 0 Will be ignored from the menu and will not be displayed", true, .has_max = true, .max_val = 1.0), g_vGrayed);

    RegisterHam(Ham_Spawn, "player", "fw_Player_Spawn_Post", true);

    // Command's
    register_clcmd("say /guns", "clcmd_buymenu");
}

public client_putinserver(pPlayer)
{
    if(is_user_bot(pPlayer))
    {
        if(!g_bHamBot && get_cvar_num("bot_quota"))
        {
            // Set a task to let the private data initialize
			set_task(0.1, "Register_BotHooks", pPlayer);
        }

        if(is_user_alive(pPlayer))
            fw_Player_Spawn_Post(pPlayer);
    }
    else
    {
        // Reset previous weapons
        g_pPrimary[pPlayer] = -1;
        g_pSecondary[pPlayer] = -1;

        flag_unset(g_bNotAgain, pPlayer);
    }
}

public Register_BotHooks(const pBot)
{
    if(g_bHamBot || !is_user_connected(pBot) || !get_cvar_num("bot_quota"))
        return;
        
    RegisterHamFromEntity(Ham_Spawn, pBot, "fw_Player_Spawn_Post", true);
    g_bHamBot = true;
}

public clcmd_buymenu(const pPlayer)
{
    if(!is_user_alive(pPlayer))
        return PLUGIN_HANDLED;

    // If the player uses the command, we deactivate the option don't ask again
    if(flag_get(g_bNotAgain, pPlayer))
    {
        flag_unset(g_bNotAgain, pPlayer);
        client_print_color(pPlayer, pPlayer, "^4[Weapon Menu]^1 Don't ask again option disabled");
    }
    
    // Show the selection menu
    show_menu_select(pPlayer);
    return PLUGIN_HANDLED;
}

public fw_Player_Spawn_Post(const pPlayer)
{
    if(!is_user_alive(pPlayer))
        return;

    strip_user_weapons(pPlayer);

    if(is_user_bot(pPlayer))
    {
        // Give random weapons
        new i, bPlayerTeam = BIT(Player_GetTeam(pPlayer));

        for(i = 0; i < sizeof(Weapons_Primary) - 2; i++)
        {
            if((Weapons_Primary[i][m_bWeaponTeam] & bPlayerTeam) && !random_num(0, MAX_RANDOMIZE))
                break;
        }

        new iWeaponID = Weapons_Primary[i][m_iWeaponCSW];

        give_item(pPlayer, Weapon_Entity_Names[iWeaponID]);
        cs_set_user_bpammo(pPlayer, iWeaponID, MAX_BPAMMO[iWeaponID]);

        for(i = 0; i < sizeof(Weapons_Secondary) - 2; i++)
        {
            if((Weapons_Secondary[i][m_bWeaponTeam] & bPlayerTeam) && !random_num(0, MAX_RANDOMIZE))
                break;
        }

        iWeaponID = Weapons_Secondary[i][m_iWeaponCSW];

        if(iWeaponID == CSW_ELITE && !(bPlayerTeam & Weapons_Secondary[i][m_bWeaponTeam]))
            iWeaponID = CSW_GLOCK18;

        give_item(pPlayer, Weapon_Entity_Names[iWeaponID]);
        cs_set_user_bpammo(pPlayer, iWeaponID, MAX_BPAMMO[iWeaponID]);

        give_item(pPlayer, Weapon_Entity_Names[CSW_HEGRENADE]);
        give_item(pPlayer, Weapon_Entity_Names[CSW_SMOKEGRENADE]);
        give_item(pPlayer, Weapon_Entity_Names[CSW_FLASHBANG]);
    }
    else
    {
        if(flag_get(g_bNotAgain, pPlayer))
        {
            Player_PreviousWeapons(pPlayer);
            return;
        }

        // Reset bought weapons
        flag_unset(g_bBuyed, pPlayer);
        show_menu_select(pPlayer);  
    }
}

public show_menu_select(const pPlayer)
{
    if(flag_get(g_bNotAgain, pPlayer))
        return;

    new hMenu = menu_create("Weapons Menu", "menu_select");

    menu_additem(hMenu, "Select Weapons");
    menu_additem(hMenu, "Select Previous");
    menu_additem(hMenu, "Select Previous + Don't Ask Again");

    menu_display(pPlayer, hMenu);
}

public menu_select(const pPlayer, const pMenu, const pItem)
{
    // Select exit | not alive
    if(pItem == MENU_EXIT || !is_user_alive(pPlayer))
    {
        menu_destroy(pMenu);
        return PLUGIN_HANDLED;
    }
        
    if(!pItem)
    {
        // Go to select weapon
        show_menu_weapons(pPlayer);
    }
    else
    {
        // 2 option, Select previous, can be 0 if the player has no weapons to reselect
        if(!Player_PreviousWeapons(pPlayer))
        {
            menu_display(pPlayer, pMenu);
            return PLUGIN_HANDLED;
        }
        // 3 option, + Don't Ask Again, since in theory you should have given the weapons in the above check, we only activate not to ask again if it is option 3
        else if(pItem == 2)
        {
            flag_set(g_bNotAgain, pPlayer);
        }
    }

    menu_destroy(pMenu);
    return PLUGIN_HANDLED;
}

public show_menu_weapons(const pPlayer)
{
    new pSlot = flag_get(g_bBuyed, pPlayer) ? SLOT_PRIMARY : SLOT_SECONDARY;

    // No weapons to select from (already got them all)
    if(pSlot == -1)
    {
        client_print_color(pPlayer, pPlayer, "^4[Weapon Menu]^1 You have selected all your weapons");
        return;
    }

    new szTitle[42], hMenu, iMaxLoop;

    // Menu title & handler
    formatex(szTitle, charsmax(szTitle), "Select %s", Weapon_Slot_Name[pSlot]);
    hMenu = menu_create(szTitle, "menu_weapons");

    // Filter maxloop by slot
    switch(pSlot)
    {
        case SLOT_PRIMARY:
            iMaxLoop = (g_vCategorize ? m_hCategory : sizeof(Weapons_Primary));
        case SLOT_SECONDARY:
            iMaxLoop = sizeof(Weapons_Secondary);
    }

    new i, szItem[42];
    new bPlayerTeam = BIT(Player_GetTeam(pPlayer)), bCheck, szName[24];

    g_iBuffer[DATA_1] = pSlot;

    // Iterate in the previously set max loop 
    for(i = 0; i < iMaxLoop; i++)
    {
        bCheck = 1;

        switch(pSlot)
        {
            case SLOT_PRIMARY:
            {
                // Is primary categorized
                if(g_vCategorize)
                {
                    // Set the respective check and name
                    if(i == CAT_TACTICAL)
                        bCheck = (g_vShield && (bPlayerTeam & BIT(FM_CS_TEAM_CT)));

                    copy(szName, charsmax(szName), Weapon_Menu_Categories[i]);
                }
                else
                {
                    bCheck = (Weapons_Primary[i][m_bWeaponTeam] & bPlayerTeam);
                    copy(szName, charsmax(szName), Weapons_Primary[i][m_szWeaponName]);
                }
            }
            case SLOT_SECONDARY:
            {
                bCheck = (Weapons_Secondary[i][m_bWeaponTeam] & bPlayerTeam);
                copy(szName, charsmax(szName), Weapons_Secondary[i][m_szWeaponName]);
            }
            default: // JIC avoid errors
                continue;
        }

        // If the grayed option is not activated, filter the loop
        if(!g_vGrayed && !bCheck)
            continue;

        // Cache the selected item
        g_iBuffer[DATA_2] = i;
        
        // Format the menu item and add it
        formatex(szItem, charsmax(szItem), "\%c%s", bCheck ? "w" : "d", szName);
        menu_additem(hMenu, szItem, g_iBuffer);
    }

    menu_display(pPlayer, hMenu);
}

public menu_weapons(const pPlayer, const pMenu, const pItem)
{
    // Select exit | not alive
    if(pItem == MENU_EXIT || !is_user_alive(pPlayer))
    {
        if(flag_get(g_bBuyed, pPlayer))
        {
            give_item(pPlayer, "weapon_knife");
            give_item(pPlayer, Weapon_Entity_Names[CSW_HEGRENADE]);
            give_item(pPlayer, Weapon_Entity_Names[CSW_SMOKEGRENADE]);
            give_item(pPlayer, Weapon_Entity_Names[CSW_FLASHBANG]);
        }

        menu_destroy(pMenu);
        return PLUGIN_HANDLED;
    }

    // Memo:
    // 0 = slot
    // 1 = item

    menu_item_getinfo(pMenu, pItem, _, g_iBuffer, charsmax(g_iBuffer));

    switch(g_iBuffer[DATA_1])
    {
        case SLOT_PRIMARY:
        {
            // Is primary categorized (Get back the Categorize in case of change before select the item)
            if(g_vCategorize)
            {
                // Set the respective check and name
                if(g_iBuffer[DATA_2] == CAT_TACTICAL)
                {
                    if(!g_vShield)
                    {
                        client_print_color(pPlayer, pPlayer, "^4[Weapon Menu]^1 Shields are disabled");

                        menu_display(pPlayer, pMenu);
                        return PLUGIN_HANDLED;
                    }

                    if(!(BIT(Player_GetTeam(pPlayer)) & BIT(FM_CS_TEAM_CT)))
                    {
                        client_print_color(pPlayer, pPlayer, "^4[Weapon Menu]^1 Only for CTs");

                        menu_display(pPlayer, pMenu);
                        return PLUGIN_HANDLED;
                    }
                }

                // Show the weapons
                show_menu_weapons_info(pPlayer, g_iBuffer[DATA_2]);  
            }
            else
            {
                new bPlayerTeam = BIT(Player_GetTeam(pPlayer));

                // Not team of the weapon
                if(!(Weapons_Primary[g_iBuffer[DATA_2]][m_bWeaponTeam] & bPlayerTeam))
                {
                    client_print_color(pPlayer, pPlayer, "^4[Weapon Menu]^1 This weapon is not enabled for your team");

                    menu_display(pPlayer, pMenu);
                    return PLUGIN_HANDLED;
                }

                new iWeaponID = Weapons_Primary[g_iBuffer[DATA_2]][m_iWeaponCSW];

                if(iWeaponID == CSW_SHIELDGUN)
                    give_item(pPlayer, "weapon_shield");
                else
                {
                    // Give and check he bought it
                    give_item(pPlayer, Weapon_Entity_Names[iWeaponID]);
                    cs_set_user_bpammo(pPlayer, iWeaponID, MAX_BPAMMO[iWeaponID]);
                }

                flag_unset(g_bBuyed, pPlayer);
                g_pPrimary[pPlayer] = g_iBuffer[DATA_2];

                give_item(pPlayer, "weapon_knife");
                give_item(pPlayer, "nvgs");

                give_item(pPlayer, Weapon_Entity_Names[CSW_HEGRENADE]);
                give_item(pPlayer, Weapon_Entity_Names[CSW_SMOKEGRENADE]);
                give_item(pPlayer, Weapon_Entity_Names[CSW_FLASHBANG]);
            }
        }
        case SLOT_SECONDARY:
        {
            new bPlayerTeam = BIT(Player_GetTeam(pPlayer));

            if(!(Weapons_Secondary[g_iBuffer[DATA_2]][m_bWeaponTeam] & bPlayerTeam))
            {
                client_print_color(pPlayer, pPlayer, "^4[Weapon Menu]^1 This weapon is not enabled for your team");

                menu_display(pPlayer, pMenu);
                return PLUGIN_HANDLED;
            }

            strip_user_weapons(pPlayer);

            new iWeaponID = Weapons_Secondary[g_iBuffer[DATA_2]][m_iWeaponCSW];

            // Give and check he bought it
            give_item(pPlayer, Weapon_Entity_Names[iWeaponID]);
            cs_set_user_bpammo(pPlayer, iWeaponID, MAX_BPAMMO[iWeaponID]);

            flag_set(g_bBuyed, pPlayer);
            g_pSecondary[pPlayer] = g_iBuffer[DATA_2];
            g_pPrimary[pPlayer] = -1;

            show_menu_weapons(pPlayer);
        }
    }

    menu_destroy(pMenu);
    return PLUGIN_HANDLED;
}

public show_menu_weapons_info(const pPlayer, const iCategory)
{
    new szTitle[32], szItem[32], hMenu;

    // Menu title & handler
    formatex(szTitle, charsmax(szTitle), "Select Primary -> \d%s", Weapon_Menu_Categories[iCategory][m_szCategoryName]);
    hMenu = menu_create(szTitle, "menu_weapons_info");

    new bPlayerTeam = BIT(Player_GetTeam(pPlayer)), i;
    new iBitsum = Weapon_Menu_Categories[iCategory][m_bCategoryBitsum];

    for(i = 0; i < sizeof(Weapons_Primary); i++)
    {
        if(iCategory != CAT_TACTICAL)
        {
            // If the grayed option is not activated, filter the loop
            if(!(iBitsum & BIT(Weapons_Primary[i][m_iWeaponCSW])) || (!g_vGrayed && !(Weapons_Primary[i][m_bWeaponTeam] & bPlayerTeam)) || (Weapons_Primary[i][m_iWeaponCSW] == CSW_SHIELDGUN))
                continue;
        }
        else
        {
            if(Weapons_Primary[i][m_iWeaponCSW] != CSW_SHIELDGUN)
                continue;
        }

        // Cache the selected item
        g_iBuffer[DATA_1] = i;
        
        // Format the menu item and add it
        formatex(szItem, charsmax(szItem), "\%c%s", (Weapons_Primary[i][m_bWeaponTeam] & bPlayerTeam) ? "w" : "d", Weapons_Primary[i][m_szWeaponName]);
        menu_additem(hMenu, szItem, g_iBuffer);
    }

    menu_setprop(hMenu, MPROP_EXITNAME, "Back");
    menu_display(pPlayer, hMenu);
}

public menu_weapons_info(const pPlayer, const pMenu, const pItem)
{
    // Select exit | not alive
    if(pItem == MENU_EXIT || !is_user_alive(pPlayer))
    {
        show_menu_weapons(pPlayer);

        menu_destroy(pMenu);
        return PLUGIN_HANDLED;
    }

    // Memo:
    // 0 = Item

    menu_item_getinfo(pMenu, pItem, _, g_iBuffer, charsmax(g_iBuffer));

    new bPlayerTeam = BIT(Player_GetTeam(pPlayer));
    new iWeapon = g_iBuffer[DATA_1];

    // Not team of the weapon
    if(!(Weapons_Primary[iWeapon][m_bWeaponTeam] & bPlayerTeam))
    {
        client_print_color(pPlayer, pPlayer, "^4[Weapon Menu]^1 This weapon is not enabled for your team");

        menu_display(pPlayer, pMenu);
        return PLUGIN_HANDLED;
    }

    new iWeaponID = Weapons_Primary[iWeapon][m_iWeaponCSW];

    if(iWeaponID == CSW_SHIELDGUN)
        give_item(pPlayer, "weapon_shield");
    else
    {
        // Give and check he bought it
        give_item(pPlayer, Weapon_Entity_Names[iWeaponID]);
        cs_set_user_bpammo(pPlayer, iWeaponID, MAX_BPAMMO[iWeaponID]);
    }

    flag_unset(g_bBuyed, pPlayer);
    g_pPrimary[pPlayer] = iWeapon;

    give_item(pPlayer, "weapon_knife");
    give_item(pPlayer, "nvgs");

    give_item(pPlayer, Weapon_Entity_Names[CSW_HEGRENADE]);
    give_item(pPlayer, Weapon_Entity_Names[CSW_SMOKEGRENADE]);
    give_item(pPlayer, Weapon_Entity_Names[CSW_FLASHBANG]);

    menu_destroy(pMenu);
    return PLUGIN_HANDLED;
}

stock Player_PreviousWeapons(const pPlayer)
{
    // if you do not have your 3 previous weapons, you may not repurchase
    if(g_pPrimary[pPlayer] == -1 && g_pSecondary[pPlayer] == -1)
    {
        client_print_color(pPlayer, pPlayer, "^4[Weapon Menu]^1 You need to select a weapon to repurchase");
        return 0;
    }

    strip_user_weapons(pPlayer);
    give_item(pPlayer, "weapon_knife");

    new iWeaponID;

    if(g_pPrimary[pPlayer] >= 0)
    {
        iWeaponID = Weapons_Primary[g_pPrimary[pPlayer]][m_iWeaponCSW];
        // Primary (Custom Item ID of the shield)
        if(iWeaponID == CSW_SHIELDGUN)
        {
            give_item(pPlayer, "weapon_shield");
        }
        else
        {
            give_item(pPlayer, Weapon_Entity_Names[iWeaponID]);
            cs_set_user_bpammo(pPlayer, iWeaponID, MAX_BPAMMO[iWeaponID]);
        }
    }

    if(g_pSecondary[pPlayer] >= 0)
    {
        // Secondary
        iWeaponID = Weapons_Secondary[g_pSecondary[pPlayer]][m_iWeaponCSW];

        give_item(pPlayer, Weapon_Entity_Names[iWeaponID]);
        cs_set_user_bpammo(pPlayer, iWeaponID, MAX_BPAMMO[iWeaponID]);
    }

    // Equipment
    give_item(pPlayer, Weapon_Entity_Names[CSW_HEGRENADE]);
    give_item(pPlayer, Weapon_Entity_Names[CSW_SMOKEGRENADE]);
    give_item(pPlayer, Weapon_Entity_Names[CSW_FLASHBANG]);
    return 1;
}

// Get User Team
stock Player_GetTeam(const pPlayer)
{
	// Prevent server crash if entity's private data not initalized
	if(pev_valid(pPlayer) != 2)
		return FM_CS_TEAM_UNASSIGNED;
	
	return get_pdata_int(pPlayer, m_iPlayerTeam);
}