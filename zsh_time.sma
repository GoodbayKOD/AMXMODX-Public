#include <amxmodx>
#include <engine>
#include <reapi>

#define Time_Entity     "time_ent"
#define nullptr         0

// Some constants for the entity
const TIME_STATE = EV_INT_iuser1;
const TIME_ROUND = EV_INT_iuser2;

// Here you can add or remove flags as you wish
new const Light_Style[][] = 
{ 
    "q", "p", "o", "n", 
    "m", "l", "k", "j", 
    "i", "h", "g", "f", 
    "e", "d", "c", "b" 
};

// A global variable to identify whether it's day or night
enum _:MAX_TIME_STATE
{
    TIME_DAY,
    TIME_NIGHT
}
new g_iTime = TIME_DAY;

public plugin_init()
{
    register_plugin("LeLucezzzzzzzzzzzzzzz", "1.0", "Goodbay");

    register_think(Time_Entity, "fw_Time_Think");

    // Testing commands
    register_clcmd("say /day", "clcmd_goday");
    register_clcmd("say /night", "clcmd_gonight");
}

public clcmd_goday(const pPlayer)
{
    // It becomes day
    client_print_color(pPlayer, pPlayer, "^4[ZSH]^1 Time set to ^3Day");

    g_iTime = TIME_DAY;
    Create_Time(sizeof(Light_Style) - 1); // we pass the size of the flags array as the value
}

public clcmd_gonight(const pPlayer)
{
    // It becomes night
    client_print_color(pPlayer, pPlayer, "^4[ZSH]^1 Time set to ^3Night");

    g_iTime = TIME_NIGHT;
    Create_Time(nullptr); // we set it to 0 so that the flags increase
}

public fw_Time_Think(const pEntity)
{
    if(!is_valid_ent(pEntity))
        return;

    new iRoundTime = entity_get_int(pEntity, TIME_ROUND);

    set_lights(Light_Style[iRoundTime]);
    client_print_color(nullptr, print_team_default, "^4[ZSH]^1 Lighting level: ^4%s", Light_Style[iRoundTime]); // Print Test

    // Don't touch anything here
    if((g_iTime == TIME_DAY && iRoundTime <= nullptr) || (g_iTime == TIME_NIGHT && iRoundTime >= (sizeof(Light_Style) - 1)))
    {
        remove_entity(pEntity);
        return;
    }

    new Float:fGameTime = get_gametime();

    // Don't touch anything here either
    entity_set_int(pEntity, TIME_ROUND, (g_iTime == TIME_NIGHT) ? (iRoundTime + 1) : (iRoundTime - 1));

    // Here you can change the interval at which each flag changes
    // If you decrease by 0.x, change the new variables to static
    entity_set_float(pEntity, EV_FL_nextthink, fGameTime + 1.1);
}

stock Create_Time(const iRoundTime)
{
    new pEntity = rg_create_entity("info_target");

    if(pEntity)
    {
        entity_set_string(pEntity, EV_SZ_classname, Time_Entity);

        new Float:fGameTime = get_gametime();

        // If you don't want to use a global variable, you can add an int
        // To store whether it's day or night (I recommend using the variable)
        entity_set_int(pEntity, TIME_ROUND, iRoundTime);

        // Leave this as is
        entity_set_float(pEntity, EV_FL_nextthink, fGameTime + 0.000001);
    }

    return pEntity;
}