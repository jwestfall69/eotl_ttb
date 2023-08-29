#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools_trace>
#include <sdktools_functions>
#include <tf2_stocks>
#include <clientprefs>

#define PLUGIN_AUTHOR  "ack"
#define PLUGIN_VERSION "0.5"

#define CONFIG_FILE     "configs/eotl_ttb.cfg"

public Plugin myinfo = {
	name = "eotl_ttb",
	author = PLUGIN_AUTHOR,
	description = "Ten Ton Brick Sound Bites",
	version = PLUGIN_VERSION,
	url = ""
};

enum struct PlayerState {
    bool enabled;
    int playCount;
}

StringMap g_smSoundBites;
StringMap g_smDescriptions;
ArrayList g_alShortNames;
float g_fLastPlay;
ConVar g_cvMaxPlayerPlays;
ConVar g_cvMinTime;
ConVar g_cvDebug;
Handle g_hClientCookies;
PlayerState g_PlayerStates[MAXPLAYERS + 1];


public void OnPluginStart() {
    LogMessage("version %s starting", PLUGIN_VERSION);
    RegConsoleCmd("sm_ttb", CommandTTB);

    g_cvMaxPlayerPlays = CreateConVar("eotl_ttb_max_player_plays", "2", "maximum number of times a player can play a ttb per map");
    g_cvMinTime  = CreateConVar("eotl_ttb_min_time", "10.0", "number of seconds that must pass before another ttb can be played");
    g_cvDebug = CreateConVar("eotl_ttb_debug", "0", "0/1 enable debug output", FCVAR_NONE, true, 0.0, true, 1.0);

    g_alShortNames = CreateArray(16);
    g_hClientCookies = RegClientCookie("ttb enabled", "ttb enabled", CookieAccess_Private);
}

public void OnMapStart() {
    g_smSoundBites = CreateTrie();
    g_smDescriptions = CreateTrie();
    g_alShortNames.Clear();

    g_fLastPlay = 0.0;
    for(int client = 1; client <= MaxClients; client++) {
        g_PlayerStates[client].playCount = 0;
        g_PlayerStates[client].enabled = false;
    }

    LoadConfig();
}

public void OnMapEnd() {
    CloseHandle(g_smSoundBites);
    CloseHandle(g_smDescriptions);
}

public void OnClientConnected(int client) {
    g_PlayerStates[client].playCount = 0;
    g_PlayerStates[client].enabled = false;
}

public void OnClientCookiesCached(int client) {
   LoadClientConfig(client);
}

public void OnClientPostAdminCheck(int client) {
    LoadClientConfig(client);
}

public Action CommandTTB(int client, int args) {
    char shortName[16];
    char soundFile[PLATFORM_MAX_PATH];

    if(args > 1) {
        PrintToChat(client, "\x01[\x03ttb\x01] Invalid syntax");
        return Plugin_Handled;
    }

    if(args == 0) {
        // pick random shortname
        // doing this in one lines seems to be less random?
        int rand = GetURandomInt();
        int index = rand % g_alShortNames.Length;
        g_alShortNames.GetString(index, shortName, sizeof(shortName));
    } else {
        GetCmdArg(1, shortName, sizeof(shortName));
        StringToLower(shortName);
    }

    // disable sounds for client if they !ttb disable
    if(StrEqual(shortName, "disable")) {
        if(!g_PlayerStates[client].enabled) {
            PrintToChat(client, "\x01[\x03ttb\x01] is already \x03disabled\x01 for you");
            return Plugin_Handled;
        }
        g_PlayerStates[client].enabled = false;
        SaveClientConfig(client);
        PrintToChat(client, "\x01[\x03ttb\x01] sounds are now \x03disabled\x01 for you");
        return Plugin_Handled;
    }

    // auto-enable if user ran any other !ttb based command
    if(!g_PlayerStates[client].enabled) {
        g_PlayerStates[client].enabled = true;
        SaveClientConfig(client);
        PrintToChat(client, "\x01[\x03ttb\x01] is now \x03enabled\x01 for you");
    }

    if(StrEqual(shortName, "list")) {
        StartMenu(client);
        return Plugin_Handled;
    }

    if(!g_smSoundBites.GetString(shortName, soundFile, sizeof(soundFile))) {
        PrintToChat(client, "\x01[\x03ttb\x01] error invalid soundbite %s, use \"!ttb list\" for a list or \"!ttb disable\" to disable sounds", shortName);
        return Plugin_Handled;
    }

    // see if the user is allowed to play a ttb
    if(g_PlayerStates[client].playCount >= g_cvMaxPlayerPlays.IntValue) {
        PrintToChat(client,"\x01[\x03ttb\x01] sorry you are limited to %d ttb's per map", g_cvMaxPlayerPlays.IntValue);
        return Plugin_Handled;
    }

    float timeDiff = GetGameTime() - g_fLastPlay;
    if(timeDiff < g_cvMinTime.FloatValue) {
        PrintToChat(client, "\x01[\x03ttb\x01] You must wait %.1f seconds before another ttb will be allowed", g_cvMinTime.FloatValue - timeDiff);
        return Plugin_Handled;
    }

    g_PlayerStates[client].playCount++;
    g_fLastPlay = GetGameTime();

    char description[32];
    g_smDescriptions.GetString(shortName, description, sizeof(description));
    PrintToChat(client, "\x01[\x03ttb\x01] Playing %s", description);
    LogDebug("Playing shortname: %s, file: %s, description: %s", shortName, soundFile, description);
    PlaySound(soundFile);
    return Plugin_Handled;
}

// play the sound for the clients that have ttb enabled
void PlaySound(const char [] soundFile) {
    int client;

    for(client = 1; client <= MaxClients; client++) {

        if(!IsClientInGame(client)) {
            continue;
        }

        if(IsFakeClient(client)) {
            continue;
        }

        if(!g_PlayerStates[client].enabled) {
            continue;
        }

        EmitSoundToClient(client, soundFile);
    }
}

void StartMenu(int client) {
    Menu menu = CreateMenu(HandleMenuInput);

    char shortName[16];
    char description[32];
    char menuString[64];

    for(int i = 0; i < g_alShortNames.Length;i++) {
        g_alShortNames.GetString(i, shortName, sizeof(shortName));
        g_smDescriptions.GetString(shortName, description, sizeof(description));
        Format(menuString, sizeof(menuString), "[%s] %s", shortName, description);

        menu.AddItem(shortName, menuString);
    }

    menu.SetTitle("Ten Ton Brick Sound Bites");
    menu.Display(client, 30);
}

// unclear what is expected to be returned, so using 0 for them all
int HandleMenuInput(Menu menu, MenuAction action, int client, int itemNum) {
    char shortName[64];
    char soundFile[PLATFORM_MAX_PATH];

    if (action == MenuAction_End) {
        delete menu;
        return 0;
    }

    if(action != MenuAction_Select) {
        return 0;
    }

    GetMenuItem(menu, itemNum, shortName, sizeof(shortName));
    if(!g_smSoundBites.GetString(shortName, soundFile, sizeof(soundFile))) {
        PrintToChat(client, "\x01[\x03ttb\x01] error invalid soundbite %s, use \"!ttb list\" for a list or \"!ttb disable\" to disable sounds", shortName);
        return 0;
    }

    // see if the user is allowed to play a ttb
    if(g_PlayerStates[client].playCount >= g_cvMaxPlayerPlays.IntValue) {
        PrintToChat(client,"\x01[\x03ttb\x01] sorry you are limited to %d ttb's per map", g_cvMaxPlayerPlays.IntValue);
        return 0;
    }

    float timeDiff = GetGameTime() - g_fLastPlay;
    if(timeDiff < g_cvMinTime.FloatValue) {
        PrintToChat(client, "\x01[\x03ttb\x01] You must wait %.1f seconds before another ttb will be allowed", g_cvMinTime.FloatValue - timeDiff);
        return 0;
    }

    g_PlayerStates[client].playCount++;
    g_fLastPlay = GetGameTime();

    char description[32];
    g_smDescriptions.GetString(shortName, description, sizeof(description));
    PrintToChat(client, "\x01[\x03ttb\x01] Playing %s", description);
    LogDebug("Playing shortname: %s, file: %s, description: %s", shortName, soundFile, description);
    PlaySound(soundFile);

    return 0;
}

void LoadConfig() {
    KeyValues cfg = CreateKeyValues("ttb");

    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), CONFIG_FILE);

    LogMessage("loading config file: %s", configFile);
    if(!FileToKeyValues(cfg, configFile)) {
        SetFailState("unable to load config file!");
        return;
    }

    char shortName[16];
    char description[32];
    char soundFile[PLATFORM_MAX_PATH];
    char downloadFile[PLATFORM_MAX_PATH];
    if(cfg.JumpToKey("soundBites")) {
        KvGotoFirstSubKey(cfg);
        do {

            cfg.GetSectionName(shortName, sizeof(shortName));
            cfg.GetString("description", description, sizeof(description));
            cfg.GetString("soundBite", soundFile, sizeof(soundFile));
            g_smSoundBites.SetString(shortName, soundFile);
            g_smDescriptions.SetString(shortName, description);
            g_alShortNames.PushString(shortName);

            Format(downloadFile, sizeof(downloadFile), "sound/%s", soundFile);
            AddFileToDownloadsTable(downloadFile);
            PrecacheSound(soundFile, true);
            LogMessage("loaded %s = %s with description %s", shortName, soundFile, description);
        } while(KvGotoNextKey(cfg));
    }
    CloseHandle(cfg);
}

void LoadClientConfig(int client) {

    if(IsFakeClient(client)) {
        return;
    }

    if(!IsClientInGame(client)) {
        return;
	}

    char enableState[6];
    GetClientCookie(client, g_hClientCookies, enableState, 6);
    if(StrEqual(enableState, "false")) {
        g_PlayerStates[client].enabled = false;
    } else {
        g_PlayerStates[client].enabled = true;
    }

    LogDebug("client %N has ttb %s", client, g_PlayerStates[client].enabled ? "enabled" : "disabled");
}

void SaveClientConfig(int client) {
    char enableState[6];
    if(g_PlayerStates[client].enabled) {
        Format(enableState, 6, "true");
    } else {
        Format(enableState, 6, "false");
    }

    LogDebug("client %N saving ttb as %s", client, g_PlayerStates[client].enabled ? "enabled" : "disabled");
    SetClientCookie(client, g_hClientCookies, enableState);
}

void StringToLower(char[] string) {
    int len = strlen(string);
    int i;

    for(i = 0;i < len;i++) {
        string[i] = CharToLower(string[i]);
    }
}

void LogDebug(char []fmt, any...) {

    if(!g_cvDebug.BoolValue) {
        return;
    }

    char message[128];
    VFormat(message, sizeof(message), fmt, 2);
    LogMessage(message);
}