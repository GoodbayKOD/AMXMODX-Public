#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <reapi>

#pragma compress 1

#define g_pMaxPlayers   	MaxClients
#define nullptr         	0
#define MAX_ROUND_KILLS		100

const PDATA_SAFE = 2;

enum (+= 500) 
{
	TASK_HELLO_AGAIN,
	TASK_CHECK_KILL,
	TASK_SHOWHUD
}

// CS Teams
enum
{
	FM_CS_TEAM_UNASSIGNED = 0,
	FM_CS_TEAM_T,
	FM_CS_TEAM_CT,
	FM_CS_TEAM_SPECTATOR
}

enum _:MAX_GAME_TEAMS
{
	GAME_TEAM_NONE = 0,
	GAME_TEAM_T,
	GAME_TEAM_CT
}

enum _:MAX_SPECIAL_KILLS
{
	KILL_1 = 0,
	KILL_2,
	KILL_3,
	KILL_4,
	KILL_FIRST,
	KILL_HEGRENADE,
	KILL_HEADSHOT,
	KILL_KNIFE
}

enum _:MAX_KILL_SOUND
{
	SND_KILL_1 = 0,
	SND_KILL_2,
	SND_KILL_3,
	SND_KILL_4,
	SND_KILL_FIRSTBLOOD,
	SND_KILL_GRENADE,
	SND_KILL_HEADSHOT,
	SND_KILL_KNIFE
}

new const GameSounds_PlayerKill[MAX_KILL_SOUND][28] = 
{
	"eg/tdm/vox/kill_1.wav",
	"eg/tdm/vox/kill_2.wav",
	"eg/tdm/vox/kill_3.wav",
	"eg/tdm/vox/kill_4.wav",
	"eg/tdm/vox/firstblood.wav",
	"eg/tdm/vox/grenade.wav",
	"eg/tdm/vox/headshot.wav",
	"eg/tdm/vox/knife.wav"
}

enum _:MAX_GAME_EVENT
{
	ROUND_START,
	ROUND_END
}
new g_iRoundState = ROUND_START;

new g_bSlashing, g_bIsConnected, g_bIsAlive;

new g_iKills[33], g_iSpecialKills[33];
new Float:g_fLastKill[33];

new g_iScore[MAX_GAME_TEAMS];

new Float:g_fPlayerDamage[33];
new g_pPlayerScore[33], g_pPlayerTeam[33];

new Float:g_fGameTime;
new cvar_forcespawn;

// Cvars
new g_pCvarMaxKills;

// Forwads 
new g_fwSpawn;

// Bit Handlers
#define flag_get(%1,%2)					(%1 & (1 << (%2 & 31)))
#define flag_set(%1,%2)					%1 |= (1 << (%2 & 31))
#define flag_unset(%1,%2)				%1 &= ~(1 << (%2 & 31))

// Client Macro
#define is_user_valid_connected(%1)		(1 <= %1 <= g_pMaxPlayers && flag_get(g_bIsConnected, %1))
#define is_user_valid_alive(%1)			(1 <= %1 <= g_pMaxPlayers && flag_get(g_bIsAlive, %1))
#define is_user_valid(%1)				(1 <= %1 <= g_pMaxPlayers)

public plugin_precache()
{
	new i, szBuffer[127];

	for(i = 0; i < MAX_KILL_SOUND; i++)
	{
		formatex(szBuffer, charsmax(szBuffer), "sound/%s", GameSounds_PlayerKill[i]);
		precache_generic(szBuffer);
	}

	// Prevent some entities from spawning
	g_fwSpawn = register_forward(FM_Spawn, "fw_Spawn_Pre", false);
}

public plugin_init()
{
	register_plugin("[EvoGames] Team Deathmatch", "1.0", "Goodbay");

	unregister_forward(FM_Spawn, g_fwSpawn);

	// Weapons
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fw_Knife_Attack_Pre", false);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fw_Knife_Attack_Post", true);

	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fw_Knife_Attack_Pre", false);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fw_Knife_Attack_Post", true);

	// Round
	RegisterHookChain(RG_CSGameRules_CheckWinConditions, "fw_CheckWinConditions_Pre", false);
	RegisterHookChain(RG_CSGameRules_FPlayerCanRespawn, "fw_PlayerCanRespawn_Pre", false);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "fw_Round_FreezeEnd_Pre", false);

	RegisterHookChain(RG_CSGameRules_RestartRound, "fw_Round_Restart_Post", true);

	// Player
	RegisterHookChain(RG_CBasePlayer_Killed, "fw_Player_Killed_Pre", false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "fw_Player_Spawn_Post", true);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "fw_Player_TakeDamage_Pre", false);

	g_pCvarMaxKills = register_cvar("tdm_max_kills", "120");
	cvar_forcespawn = get_cvar_pointer("mp_forcerespawn");

	// Message hooks
	register_message(get_user_msgid("RoundTime"), "message_roundtime");

	// Unset Freezetime
	set_member_game(m_iIntroRoundTime, 0);
	set_member_game(m_bFreezePeriod, false);
	
	// Alter Start game
	set_member_game(m_bGameStarted, true);
}

public client_putinserver(pPlayer)
{
	// Update flags
	flag_set(g_bIsConnected, pPlayer);

	g_iKills[pPlayer] = 0;
	g_iSpecialKills[pPlayer] = 0;

	g_fLastKill[pPlayer] = 0.0;

	set_task(1.0, "Player_BaseHUD", pPlayer + TASK_SHOWHUD, _, _, "b");
	set_task(random_float(20.0, 30.0), "Player_Hello", pPlayer + TASK_HELLO_AGAIN);
}

public Player_Hello(const taskid)
{
	static pPlayer;
	pPlayer = taskid - TASK_HELLO_AGAIN;

	client_print_color(pPlayer, pPlayer, "^3[^4EG^3]^1 Bienvenido al servidor:^3 Team Deathmatch");
	client_print_color(pPlayer, pPlayer, "^3[^4EG^3]^1 Desarrollado por:^3 Goodbay");
}

public client_disconnected(pPlayer, bool:bDrop, szMessage[], maxlen)
{
	remove_task(pPlayer + TASK_SHOWHUD);
	remove_task(pPlayer + TASK_CHECK_KILL);

	// Update flags
	flag_unset(g_bIsConnected, pPlayer);

	g_iKills[pPlayer] = 0;
	g_iSpecialKills[pPlayer] = 0;

	g_fLastKill[pPlayer] = 0.0;
}

// Entity Spawn Forward
public fw_Spawn_Pre(const pEntity)
{
    // Invalid entity
    if(!is_valid_ent(pEntity))
        return FMRES_IGNORED;

    new const Rule_RemovedEntities[][] =
    {	"func_bomb_target", "info_bomb_target", "hostage_entity", 
		"monster_scientist", "func_hostage_rescue", "info_hostage_rescue", 
		"info_vip_start", "func_vip_safetyzone", "func_escapezone", 
		"game_player_equip", "player_weaponstrip"
    }

	// Get classname
    new szClassName[32], iEnt;
    entity_get_string(pEntity, EV_SZ_classname, szClassName, charsmax(szClassName));

    for(; iEnt < sizeof Rule_RemovedEntities; iEnt++)
    {		
        if(!equal(szClassName, Rule_RemovedEntities[iEnt]))
            continue;

        remove_entity(pEntity);
        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public fw_Round_FreezeEnd_Pre()
{
	// Freeze time exists
	if(get_member_game(m_iIntroRoundTime))
		set_cvar_num("mp_freezetime", 0);
	
}

public fw_Round_Restart_Post()
{
	if(g_iRoundState == ROUND_END)
		server_cmd("amx_map cs_assault");

	g_iRoundState = ROUND_START;

	g_iScore[GAME_TEAM_CT] 	= 0;
	g_iScore[GAME_TEAM_T] 	= 0;
}

public fw_CheckWinConditions_Pre()
{
	// Block
	return HC_SUPERCEDE;
}

public fw_PlayerCanRespawn_Pre(const pPlayer)
{
	SetHookChainReturn(ATYPE_INTEGER, true);
	return HC_SUPERCEDE;
}

public fw_Knife_Attack_Pre(const pEntity)
{
	// Set
	flag_set(g_bSlashing, get_member(pEntity, m_pPlayer));
}

public fw_Knife_Attack_Post(const pEntity)
{
	// Unset
	flag_unset(g_bSlashing, get_member(pEntity, m_pPlayer));
}

public fw_Player_Killed_Pre(const pVictim, const pAttacker, const iShouldGib)
{
	// Unset
	flag_unset(g_bIsAlive, pVictim);

	// Respawn Bar time
	GameFX_BarTime(pVictim, get_pcvar_num(cvar_forcespawn));

	new iHitGroup = get_member(pVictim, m_LastHitGroup);

	// Slashing
	if(flag_get(g_bSlashing, pAttacker))
	{
		g_iSpecialKills[pAttacker] = KILL_KNIFE;
	}
	else
	{
		if(iHitGroup != HIT_GENERIC)
		{
			if(iHitGroup == HIT_HEAD)
				g_iSpecialKills[pAttacker] = KILL_HEADSHOT;
		}
	}

	g_fGameTime = get_gametime();

	if(g_fLastKill[pAttacker] <= g_fGameTime && g_iKills[pAttacker] >= 1)
	{
		// Restart
		g_iKills[pAttacker] = nullptr;
	}

	g_fLastKill[pAttacker] = g_fGameTime + 4.0;

	g_iKills[pAttacker] = clamp(g_iKills[pAttacker] + 1, 0, 4);
	Player_CheckKill(pAttacker);

	// Score
	g_iScore[g_pPlayerTeam[pAttacker]]++;
	g_pPlayerScore[pAttacker]++;

	CheckRoundWin();
}

public CheckRoundWin()
{
	// Round is end?
	if(g_iRoundState == ROUND_END)
		return;
		
	new WinStatus:iTeamWinner = WINSTATUS_DRAW, iMaxKills = get_pcvar_num(g_pCvarMaxKills);

	if(g_iScore[GAME_TEAM_T] >= iMaxKills)
	{
		iTeamWinner = WINSTATUS_TERRORISTS;
	}
	else if(g_iScore[GAME_TEAM_CT] >= iMaxKills)
	{
		iTeamWinner = WINSTATUS_CTS;
	}

	// Not changes...
	if(iTeamWinner == WINSTATUS_DRAW)
		return;

	new ScenarioEventEndRound:iEvent = (iTeamWinner == WINSTATUS_CTS ? ROUND_CTS_WIN : ROUND_TERRORISTS_WIN);

	// Now end
	g_iRoundState = ROUND_END;

	// Force end round
	rg_round_end(5.0, iTeamWinner, iEvent, iTeamWinner == WINSTATUS_CTS ? "Ganan los Anti-Terroristas" : "Ganan los Terroristas");
}

public fw_Player_Spawn_Post(const pPlayer)
{
	if(!is_user_alive(pPlayer))
		return;

	new pTeam = Player_GetTeam(pPlayer);
	new pGameTeam;

	switch(pTeam)
	{
		case FM_CS_TEAM_CT:
		{
			pGameTeam = GAME_TEAM_CT;
		}
		case FM_CS_TEAM_T:
		{
			pGameTeam = GAME_TEAM_T;
		}	
	}

	g_pPlayerTeam[pPlayer] = pGameTeam;
	
	// Set
	flag_set(g_bIsAlive, pPlayer);
}

public fw_Player_TakeDamage_Pre(const iVictim, const iInflictor, const iAttacker, Float:fDamage, iDamageBit)
{
	if(iVictim == iAttacker || !is_user_valid_connected(iAttacker) || !rg_is_player_can_takedamage(iVictim, iAttacker))
		return HC_CONTINUE;

	g_fPlayerDamage[iAttacker] += fDamage;
	return HC_CONTINUE;
}

public message_roundtime(const msg_id, const msg_dest, const msg_entity)
{
	set_msg_arg_int(1, ARG_SHORT, get_timeleft());
}

Player_CheckKill(const pAttacker)
{
	// Not alive
	if(!flag_get(g_bIsAlive, pAttacker))
		return;

	new iKills = g_iKills[pAttacker], iColor[3];

	if(iKills == 1)
	{
		if(g_iSpecialKills[pAttacker] != nullptr)
		{
			remove_task(pAttacker + TASK_CHECK_KILL);
			set_task(0.1, "Player_CheckSpecialKill", pAttacker + TASK_CHECK_KILL);
			return;
		}
	}

	switch(iKills)
	{
		case 0..1:
			iColor = {0, 180, 255};
		case 2:
			iColor = {90, 245, 80};
		case 3:
			iColor = {255, 130, 0};
		case 4:
			iColor = {255, 30, 30};
		default:
			return;
	}

	new const Rules_PlayerKills[][] =
	{
		"",
		"Doble",
		"Triple",
		"Cuadruple"
	}

	// Hud notice
	set_dhudmessage(iColor[0], iColor[1], iColor[2], -1.0, 0.2, 1, 1.0, 1.0);
	show_dhudmessage(pAttacker, "\ /^n-- + --^n/ \^nAsesinato %s", Rules_PlayerKills[iKills - 1]);

	Player_PlayWAV(pAttacker, GameSounds_PlayerKill[iKills - 1]);

	// Another necessary check
	if(g_iSpecialKills[pAttacker] != nullptr)
	{
		remove_task(pAttacker + TASK_CHECK_KILL);
		set_task(1.2, "Player_CheckSpecialKill", pAttacker + TASK_CHECK_KILL);
	}
}

public Player_BaseHUD(const taskid)
{
	static pPlayer;
	pPlayer = taskid - TASK_SHOWHUD;

	set_dhudmessage(255, 255, 255, -1.0, 0.01, 0, 0.0, 1.0);
	show_dhudmessage(pPlayer, "[%03d] TR [%d] CT [%03d]^n[ KILLS ]", g_iScore[GAME_TEAM_T], get_pcvar_num(g_pCvarMaxKills), g_iScore[GAME_TEAM_CT]);

	if(flag_get(g_bIsAlive, pPlayer))
	{
		// Show player hud | Users alive, Damage & Health
		set_dhudmessage(220, 185, 113, 0.87, 0.80, 1, 1.0, 1.0);
		show_dhudmessage(pPlayer, "[Puntos] %i^n[Daño] %i", g_pPlayerScore[pPlayer], floatround(g_fPlayerDamage[pPlayer]));		
	}
}

public Player_CheckSpecialKill(const taskid)
{
	new pAttacker = (taskid - TASK_CHECK_KILL);

	if(!flag_get(g_bIsAlive, pAttacker))
		return;

	new iSpecialKill = g_iSpecialKills[pAttacker], iColor[3];

	// Filter color
	switch(iSpecialKill)
	{
		case KILL_HEADSHOT:
			iColor = {255, 180, 0};
		case KILL_KNIFE:
			iColor = {0, 127, 255};
		case KILL_HEGRENADE:
			iColor = {255, 127, 255};
	}

	new const Rules_SpecialKills[][] =
	{
		"Granada",
		"Humillacion",
		"Headshot"
	}

	// Hud notice
	set_dhudmessage(iColor[0], iColor[1], iColor[2], -1.0, 0.2, 1, 1.0, 1.0);
	show_dhudmessage(pAttacker, "\ /^n-- + --^n/ \^n%s", Rules_SpecialKills[MAX_SPECIAL_KILLS - iSpecialKill]);

	Player_PlayWAV(pAttacker, GameSounds_PlayerKill[iSpecialKill]);

    // Reset
	g_iSpecialKills[pAttacker] = nullptr;
}

// Get User Team
stock Player_GetTeam(const pPlayer)
{
	// Prevent server crash if entity's private data not initalized
	if(pev_valid(pPlayer) != PDATA_SAFE)
		return FM_CS_TEAM_UNASSIGNED;
	
	return get_member(pPlayer, m_iTeam);
}

stock Player_PlayWAV(const pPlayer, const szSound[])
	client_cmd(pPlayer, "spk ^"%s^"", szSound);

stock Player_PlayMP3(const pPlayer, const szSound[])
	client_cmd(pPlayer, "mp3 play ^"%s^"", szSound);

stock GameFX_BarTime(const pPlayer, const iSeconds)
{
    static iMsgBarTime; 
    
    if(!iMsgBarTime)
        iMsgBarTime = get_user_msgid("BarTime");
    
    message_begin(MSG_ONE, iMsgBarTime, _, pPlayer)
    write_byte(iSeconds)
    write_byte(0)
    message_end()
}