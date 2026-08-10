#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

float g_vSaferoomPos[3];
float g_vCallerPos[3];
float g_vCallerAng[3];
int g_iCallerUserId = 0;
bool g_bSaferoomSet = false;
bool g_bTransitionStarted = false;
bool g_bAnnouncedThisMap = false;

public Plugin myinfo = 
{
    name        = "[L4D2] Defib Simulator",
    author      = "star_k",
    description = "Teleports team to saferoom and closes the door, then defibs caller upon map_transition.",
    version     = "67",
    url         = ""
};

public void OnPluginStart()
{
    RegAdminCmd("sm_saferoom", Command_SetSaferoom, ADMFLAG_CHANGEMAP, "Sets the saferoom target destination.");
    RegAdminCmd("sm_defib", Command_Defib, ADMFLAG_CHANGEMAP, "Executes saferoom transition and defibs caller.");
    RegAdminCmd("sm_forcedefib", Command_ForceDefib, ADMFLAG_CHANGEMAP, "Forces saferoom transition and defibs caller without checking for doors.");

    HookEvent("map_transition", Event_MapTransition, EventHookMode_Pre);
    HookEvent("player_activate", Event_PlayerActivate, EventHookMode_Post);
}

public void OnMapStart()
{
    g_bSaferoomSet = false;
    g_bAnnouncedThisMap = false;

    ConVar cvarAfk = FindConVar("director_afk_timeout");
    if (cvarAfk != null)
    {
        cvarAfk.SetInt(42069);
    }
}

public void Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
    {
        if (!g_bAnnouncedThisMap)
        {
            g_bAnnouncedThisMap = true;
            CreateTimer(1.0, Timer_AnnouncePlugin, userid);
        }
    }
}

public Action Timer_AnnouncePlugin(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client))
    {
        PrintToChat(client, "[Defib] 'director_afk_timeout' is set to 42069 for Defib Simulator.");
        PrintToChat(client, "[Defib] Use !saferoom to set saferoom point, !defib to simulate defib.");
        PrintToChat(client, "[Defib] Ensure at least one human player is in the server so map_transition can start.");
    }
    return Plugin_Stop;
}

public Action Command_SetSaferoom(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
    {
        ReplyToCommand(client, "[Defib] Command must be used in the chat.");
        return Plugin_Handled;
    }

    GetClientAbsOrigin(client, g_vSaferoomPos);
    g_bSaferoomSet = true;

    ReplyToCommand(client, "[Defib] Saferoom checkpoint set to: %.1f, %.1f, %.1f", g_vSaferoomPos[0], g_vSaferoomPos[1], g_vSaferoomPos[2]);
    return Plugin_Handled;
}

public Action Command_Defib(int client, int args)
{
    return ExecuteTransitionSequence(client, false);
}

public Action Command_ForceDefib(int client, int args)
{
    return ExecuteTransitionSequence(client, true);
}

Action ExecuteTransitionSequence(int client, bool bForce)
{
    if (client <= 0 || !IsClientInGame(client))
    {
        ReplyToCommand(client, "[Defib] Command must be used in the chat.");
        return Plugin_Handled;
    }

    if (!g_bSaferoomSet)
    {
        ReplyToCommand(client, "[Defib] You must set the saferoom checkpoint first using !saferoom inside the saferoom!");
        return Plugin_Handled;
    }

    // Check if there is at least one human player in the game
    bool bHasHumanPlayer = false;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            bHasHumanPlayer = true;
            break;
        }
    }

    if (!bHasHumanPlayer)
    {
        ReplyToCommand(client, "[Defib] Error: No human player detected in server. Map transition will not start with only just bots!");
        return Plugin_Handled;
    }

    int changelevel = FindEntityByClassname(-1, "info_changelevel");
    if (changelevel == -1)
    {
        changelevel = FindEntityByClassname(-1, "trigger_changelevel");
    }

    if (changelevel == -1 || !IsValidEntity(changelevel))
    {
        ReplyToCommand(client, "[Defib] Error: Could not find the saferoom door to close. Please close the door manually and use !forcedefib instead.");
        return Plugin_Handled;
    }

    // 1. Save caller details and position
    g_iCallerUserId = GetClientUserId(client);
    GetClientAbsOrigin(client, g_vCallerPos);
    GetClientAbsAngles(client, g_vCallerAng);

    // 2. Teleport ALL OTHER survivors to saferoom
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && i != client)
        {
            if (GetEntProp(i, Prop_Send, "m_isIncapacitated", 1))
            {
                SetEntProp(i, Prop_Send, "m_isIncapacitated", 0);
            }
            
            TeleportEntity(i, g_vSaferoomPos, NULL_VECTOR, NULL_VECTOR);
        }
    }

    // 3. Lock checkpoint doors (Skipped completely when using !forcedefib)
    if (!bForce)
    {
        int door = -1;
        while ((door = FindEntityByClassname(door, "prop_door_rotating_checkpoint")) != -1)
        {
            if (IsValidEntity(door))
            {
                AcceptEntityInput(door, "Close");
                AcceptEntityInput(door, "Lock");
            }
        }
    }

    // 4. Set director_no_death_check 0 before handling caller death (to make sure the map transition will happen)
    ConVar cvarNoDeathCheck = FindConVar("director_no_death_check");
    if (cvarNoDeathCheck != null)
    {
        cvarNoDeathCheck.SetInt(0);
    }

    // 5. Kill caller if alive
    if (IsPlayerAlive(client))
    {
        ForcePlayerSuicide(client);
    }

    // 6. Reset transition flag & start 3-second check timer
    g_bTransitionStarted = false;
    CreateTimer(3.0, Timer_CheckTransition, GetClientUserId(client));

    // 7. Fire map change transition to trigger map_transition event
    AcceptEntityInput(changelevel, "Enable");
    AcceptEntityInput(changelevel, "ChangeLevel");

    ShowActivity2(client, "[Defib] ", bForce ? "Force triggered saferoom transition!" : "Triggered saferoom transition!");
    return Plugin_Handled;
}

public Action Timer_CheckTransition(Handle timer, int userid)
{
    if (!g_bTransitionStarted)
    {
        int client = GetClientOfUserId(userid);
        if (client > 0 && IsClientInGame(client))
        {
            PrintToChat(client, "[Defib] 3 seconds passed. Did you !saferoom the right spot?");
        }
    }
    return Plugin_Stop;
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
    g_bTransitionStarted = true;

    if (g_iCallerUserId == 0) return;

    int client = GetClientOfUserId(g_iCallerUserId);
    if (client > 0 && IsClientInGame(client))
    {
        // Execute instant defib revive via VScript on map_transition hook
        char vscript[128];
        Format(vscript, sizeof(vscript), "GetPlayerFromUserID(%d).ReviveByDefib()", g_iCallerUserId);
        ExecuteVScriptDirect(vscript);

        // Restore position outside
        TeleportEntity(client, g_vCallerPos, g_vCallerAng, NULL_VECTOR);
    }

    g_iCallerUserId = 0;
}

void ExecuteVScriptDirect(const char[] code)
{
    int logic = FindEntityByClassname(-1, "logic_script");
    if (logic == -1)
    {
        logic = CreateEntityByName("logic_script");
        DispatchSpawn(logic);
    }
    
    SetVariantString(code);
    AcceptEntityInput(logic, "RunScriptCode");
}