#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#define ENG_NULLET          -1
#define nullptr             0
#define g_pMaxPlayers       MaxClients

new g_szMapName[32];

// Bitflags
#define flag_get(%1,%2) 	        (%1 & (1 << (%2 & 31)))
#define flag_set(%1,%2) 	        %1 |= (1 << (%2 & 31))
#define flag_unset(%1,%2) 	        %1 &= ~(1 << (%2 & 31))

public plugin_precache()
{
    register_plugin("Map Config", "1.0", "Goodbay");

    get_mapname(g_szMapName, charsmax(g_szMapName));
    strtolower(g_szMapName);

    Map_LoadConfig();
}

public Map_LoadConfig()
{
    new szPath[126];
    formatex(szPath, charsmax(szPath), "addons/amxmodx/configs/maps/%s.cfg", g_szMapName);

    if(!file_exists(szPath))
    {
        server_print("Failed to load map config file");
        return 0;
    }

    new szLineData[192], szKey[64], szValue[128], szFogColor[24], szFogDensity[18];
    new iFile = fopen(szPath, "rt"), iWea;

    while(iFile && !feof(iFile))
    {
        fgets(iFile, szLineData, charsmax(szLineData));
        trim(szLineData);

        iWea++;
        server_print("loop %d", iWea);
        
        if(!szLineData[0] || szLineData[0] == ';')
            continue;

        strtok(szLineData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
        trim(szKey);
        trim(szValue);

        if(equal(szKey, "light_flag") && szValue[0] != EOS)
        {
            set_lights(szValue);
            continue;
        }

        if(equal(szKey, "sky_name") && szValue[0] != EOS)
        {
            set_cvar_string("sv_skyname", szValue);
            continue;
        }

        if(equal(szKey, "snow")) 	
        {
            if(!find_ent_by_class(MaxClients, "env_snow"))
                create_entity("env_snow");

            continue;
        }
        
        if(equal(szKey, "rain")) 
        {
            if(!find_ent_by_class(MaxClients, "env_rain"))
                create_entity("env_rain");

            continue;
        }

        if(equal(szKey, "fog_color"))
        {
            copy(szFogColor, charsmax(szFogColor), szValue);
            continue;
        }
            
        if(equal(szKey, "fog_density")) 
        {
            copy(szFogDensity, charsmax(szFogDensity), szValue);
            continue;
        }
    }

    if(iFile) 
        fclose(iFile);

    if(szFogColor[0] != EOS && szFogDensity[0] != EOS)
    {
        new iEntity = create_entity("env_fog");

        if(iEntity)
        {
            DispatchKeyValue(iEntity, "density", szFogDensity);
            DispatchKeyValue(iEntity, "rendercolor", szFogColor);

            DispatchSpawn(iEntity);            
        }
    }

    return 1;
}