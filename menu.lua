-- UNISONO_MULTITOOL_REMOTE_PAYLOAD
-- ============================================================
--  Unisono Multi-Tool v1.3.2 — HTTP Loader Edition
--  Оригинальная менюшка сохранена; whitelist и логи синхронизируются
--  между клиентами без пользовательского серверного Lua.
-- ============================================================
if SERVER then return end

local SCRIPT_VERSION = "v1.3.2-http-loader"
local ADMIN_STEAMID  = "STEAM_0:0:620984262"
local REMOTE_SCRIPT_URL = "https://raw.githubusercontent.com/Hunteralook/unisono_multitool_loader/main/menu.lua"

-- ==================== 1. КОНФИГ ====================
local WhitelistData = {}
local WHITELIST_RETRY_INTERVAL = 5
local whitelist_retry_timer = "Whitelist_Retry_" .. tostring(math.random(10000, 99999))
local whitelist_loaded_successfully = false
local whitelist_retry_count = 0
local WHITELIST_MAX_RETRIES = 3
local WHITELIST_REFRESH_INTERVAL = 45
local WHITELIST_REFRESH_TIMER = "UnisonoMT_ClientWhitelistRefresh"
local CLIENT_DATA_DIR = "unisono_multitool"
local LOCAL_WHITELIST_PATH = CLIENT_DATA_DIR .. "/whitelist_cache.json"
local LOCAL_USAGE_LOG_PATH = CLIENT_DATA_DIR .. "/usage_logs_local.txt"
local ADMIN_USAGE_LOG_PATH = CLIENT_DATA_DIR .. "/peer_usage_logs.json"
local CLIENT_TOKEN_PATH = CLIENT_DATA_DIR .. "/github_auth.json"
local LEGACY_CLIENT_TOKEN_PATH = CLIENT_DATA_DIR .. "/github_token.txt"
local ADMIN_INIT_TIMER = "UnisonoMT_ClientIdentityInit"

local safePrefixes = {"UpdateUI_", "RenderMatrix_", "CalcViewOffset_", "ProcessNet_"}
local function GenSafeHook() return safePrefixes[math.random(1, #safePrefixes)] .. tostring(math.random(10000, 99999)) end

local hook_ESP       = GenSafeHook()
local hook_Star      = GenSafeHook()
local hook_Shader    = GenSafeHook()
local hook_Key       = GenSafeHook()
local hook_RGB       = GenSafeHook()
local hook_Stats     = GenSafeHook()
local hook_Notes3D   = GenSafeHook()
local hook_Notes3D_HUD = GenSafeHook()

local ESP_Enabled = false
local ESP_MaxDistance = 1100
local ESP_FontFamily = "Calibri"
local ESP_FontSize = 30
local ESPFontName = "ESP_Font_Calibri_30"
local Menu_FontFamily = "Calibri"
local Menu_FontSize = 20
local MenuFontName = "Menu_Font_Calibri_20"
local Physgun_RainbowEnabled = false
local QMenu_RainbowEnabled = false
local QMenu_CustomColor = nil
_G.QMenu_PaintMode = "full"
local ActiveShader = nil
local ActiveParams = {}
local ActiveShaderIndex = 1
local ShaderStates = {}

local PEER_PROTOCOL_PREFIX = "__UMT_P2P_V1__"
local PEER_CHUNK_SIZE = 72
local PEER_MAX_PARTS = 180
local PEER_SEND_INTERVAL = 0.28
local PEER_ASSEMBLY_TIMEOUT = 15
local PEER_CHAT_HOOK = "UnisonoMT_ClientPeerChat"
local PEER_SEND_TIMER = "UnisonoMT_ClientPeerSend"
local PEER_CLEANUP_TIMER = "UnisonoMT_ClientPeerCleanup"
local PEER_LOG_TIMER = "UnisonoMT_ClientPeerLogs"
local ADMIN_LOG_SYNC_TIMER = "UnisonoMT_ClientLogSync"

local SessionStats = {
    sessionStart = CurTime(), kills = 0, deaths = 0,
    damageTaken = 0, damageDealt = 0, distanceTraveled = 0,
    jumps = 0, lastPos = Vector(0,0,0), onGround = true,
}
local MapNotes = {}
local MapNotes_NextID = 1
local starField = {}
local function InitStarField()
    starField = {}
    for i = 1, 150 do
        starField[i] = { x = math.random(0, ScrW()), y = math.random(0, ScrH()),
            size = math.random(2,4), speed = math.random(60,120),
            phase = math.random()*2*math.pi, alphaBase = math.random(150,255) }
    end
end
InitStarField()

-- ==================== 2. ШРИФТЫ ====================
surface.CreateFont("Unisono_ULXTitle", { font = "Tahoma", size = 16, weight = 600, antialias = true })
surface.CreateFont("Unisono_ULXBtn",   { font = "Tahoma", size = 14, weight = 500, antialias = true })
surface.CreateFont("Unisono_ULXStatus", { font = "Tahoma", size = 13, weight = 500, antialias = true })
surface.CreateFont("Unisono_Mono",      { font = "Consolas", size = 12, weight = 400, antialias = true })
surface.CreateFont("Notes3D_Font",      { font = "Calibri", size = 20, weight = 800, antialias = true })
surface.CreateFont("Notes3D_Font_Small",{ font = "Calibri", size = 15, weight = 600, antialias = true })

local function CreateESPFont(family, size)
    ESP_FontFamily = family or "Calibri"
    ESP_FontSize = size or 30
    ESPFontName = "ESP_Font_" .. ESP_FontFamily .. "_" .. ESP_FontSize
    surface.CreateFont(ESPFontName, { font = ESP_FontFamily, size = ESP_FontSize, weight = 800, antialias = true })
end
CreateESPFont(ESP_FontFamily, ESP_FontSize)

local function CreateMenuFont(family, size)
    Menu_FontFamily = family or "Calibri"
    Menu_FontSize = size or 20
    MenuFontName = "Menu_Font_" .. Menu_FontFamily .. "_" .. Menu_FontSize
    surface.CreateFont(MenuFontName, { font = Menu_FontFamily, size = Menu_FontSize, weight = 800, antialias = true })
end
CreateMenuFont(Menu_FontFamily, Menu_FontSize)

-- ==================== 3. ЦВЕТА ====================
local ESP_RoleColors = {
    assistant = Color(255,255,0), media = Color(0,255,255),
    helper = Color(255,255,150), moder_m = Color(255,105,180),
    moder = Color(255,20,147), admin_m = Color(255,100,100),
    admin = Color(255,0,0), admin_s = Color(200,0,0),
    headadmin = Color(255,50,50), gamemaster_nov = Color(150,255,150),
    gamemaster_m = Color(100,255,100), gamemaster = Color(0,255,0),
    gamemaster_s = Color(0,200,0), headgamemaster = Color(0,150,0),
    visor_m = Color(100,100,255), visor = Color(50,50,255),
    visor_s = Color(0,0,200), supervisor = Color(0,0,255),
    headmaster = Color(148,0,211), vicecurator = Color(178,34,34),
    curator = Color(139,0,0), techadmin = "rainbow",
    spectator = Color(150,150,150), manager_m = Color(255,140,0),
    owner = "rainbow_letters",
}
local ESP_Layout = {
    Nick = { enabled = true, side = "right" },
    HP = { enabled = true, side = "right" },
    Armor = { enabled = true, side = "right" },
    Rank = { enabled = true, side = "bottom" },
}

-- ==================== 4. ТЕМЫ ULX МЕНЮ ====================
local CurrentULXTheme = "dark"

local ULXThemes = {
    dark = {
        name = "Космос (Dark)",
        bg = Color(45,45,45), panel = Color(55,55,55),
        content = Color(60,60,60), text = Color(220,220,220),
        btn = Color(70,70,70), btnHover = Color(90,90,90),
        btnText = Color(255,255,255), header = Color(35,35,35),
        headerText = Color(200,200,200), border = Color(80,80,80),
        status = Color(0,150,150), statusText = Color(255,255,255),
        accent = Color(0,200,100),
    },
    light = {
        name = "Светлая",
        bg = Color(220,220,220), panel = Color(235,235,235),
        content = Color(245,245,245), text = Color(50,50,50),
        btn = Color(100,170,255), btnHover = Color(130,190,255),
        btnText = Color(255,255,255), header = Color(200,200,200),
        headerText = Color(60,60,60), border = Color(180,180,180),
        status = Color(0,180,180), statusText = Color(255,255,255),
        accent = Color(0,150,255),
    },
    transparent = {
        name = "Прозрачная",
        bg = Color(30,30,30,200), panel = Color(40,40,40,220),
        content = Color(50,50,50,200), text = Color(220,220,220),
        btn = Color(60,60,60,200), btnHover = Color(80,80,80,220),
        btnText = Color(255,255,255), header = Color(25,25,25,200),
        headerText = Color(200,200,200), border = Color(100,100,100,100),
        status = Color(0,150,150,200), statusText = Color(255,255,255),
        accent = Color(100,200,255),
    },
    purple = {
        name = "Фиолетовая",
        bg = Color(30,10,45), panel = Color(45,15,65),
        content = Color(50,20,70), text = Color(230,210,255),
        btn = Color(80,30,120), btnHover = Color(110,50,160),
        btnText = Color(255,255,255), header = Color(20,5,35),
        headerText = Color(220,200,255), border = Color(100,50,140),
        status = Color(120,40,180), statusText = Color(255,255,255),
        accent = Color(180,80,255),
    },
    green = {
        name = "Матрица",
        bg = Color(5,20,5), panel = Color(10,35,10),
        content = Color(15,40,15), text = Color(200,255,200),
        btn = Color(20,80,20), btnHover = Color(30,120,30),
        btnText = Color(200,255,200), header = Color(5,25,5),
        headerText = Color(180,255,180), border = Color(0,100,0),
        status = Color(0,120,0), statusText = Color(200,255,200),
        accent = Color(0,255,100),
    },
    hacker = {
        name = "Хакер",
        bg = Color(5,5,5), panel = Color(10,10,10),
        content = Color(12,12,12), text = Color(0,255,65),
        btn = Color(15,30,15), btnHover = Color(25,60,25),
        btnText = Color(0,255,0), header = Color(5,10,5),
        headerText = Color(0,255,65), border = Color(0,80,0),
        status = Color(0,100,0), statusText = Color(0,255,65),
        accent = Color(0,255,0),
    },
}

local function GetTheme() return ULXThemes[CurrentULXTheme] or ULXThemes.dark end
local function ThemeCol(key, fallback)
    local t = GetTheme()
    return t[key] or fallback or Color(255,255,255)
end

-- ==================== 5. УТИЛИТЫ ====================
local function Notify(msg, err)
    notification.AddLegacy("[Мульти-тул] " .. msg, err and 1 or 0, 4)
    surface.PlaySound(err and "buttons/button10.wav" or "buttons/button14.wav")
end
local function HasAccess(sid, feat)
    if sid == ADMIN_STEAMID then return true end
    if not WhitelistData[sid] then return false end
    return WhitelistData[sid][feat] == true
end
local function SafeRemoveHook(ev, name) if name then hook.Remove(ev, name) end end
local function GetRoleColor(ply)
    local ug = ply:GetUserGroup() or "user"
    local col = ESP_RoleColors[ug]
    if not col then return Color(0,255,0) end
    if col == "rainbow" then return HSVToColor((CurTime()*100)%360, 1, 1) end
    if col == "rainbow_letters" then return Color(255,215,0) end
    return col
end
local function DrawRainbowLetters(text, font, startX, y, colors)
    surface.SetFont(font)
    local totalW = 0
    for i = 1, #text do totalW = totalW + surface.GetTextSize(text:sub(i,i)) end
    local curX = startX - totalW/2
    for i = 1, #text do
        local ch = text:sub(i,i)
        draw.SimpleText(ch, font, curX, y, colors[(i-1) % #colors + 1], TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        curX = curX + surface.GetTextSize(ch)
    end
end
local function FormatTime(sec)
    local h = math.floor(sec/3600)
    local m = math.floor((sec%3600)/60)
    local s = math.floor(sec%60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function IsWhitelistAdmin()
    local lp = LocalPlayer()
    return IsValid(lp) and lp:SteamID() == ADMIN_STEAMID
end

local function IsValidSteamID(steamID)
    return isstring(steamID) and string.match(steamID, "^STEAM_%d:%d:%d+$") ~= nil
end

local function BuildUsageRow(action, detail, source)
    local lp = LocalPlayer()
    return {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        unix = os.time(),
        steamid = IsValid(lp) and lp:SteamID() or "UNKNOWN",
        steamid64 = IsValid(lp) and lp:SteamID64() or "0",
        nick = IsValid(lp) and lp:Nick() or "UNKNOWN",
        action = tostring(action or "unknown"),
        detail = tostring(detail or ""),
        map = game.GetMap() or "unknown",
        source = source or "game-client",
    }
end

local function AppendLocalUsageLog(row)
    file.CreateDir("unisono_multitool")
    file.Append(LOCAL_USAGE_LOG_PATH, (util.TableToJSON(row, false) or "{}") .. "\n")
end

local QueuePeerLog = nil
local AppendAdminUsageLog = nil
local SyncAdminLogsToGist = nil

local function LogFeatureUsage(action, detail)
    action = string.sub(tostring(action or "unknown"), 1, 64)
    detail = string.sub(tostring(detail or ""), 1, 256)
    local row = BuildUsageRow(action, detail, IsWhitelistAdmin() and "admin-client" or "game-client")
    AppendLocalUsageLog(row)

    if IsWhitelistAdmin() and AppendAdminUsageLog then
        AppendAdminUsageLog(row)
        return
    end

    if QueuePeerLog then QueuePeerLog(action, detail) end
end

-- ==================== 6. ВАЙТЛИСТ ====================
local GIST_ID = "d09a1f52dd890d0bdf2245ad4e187db4"
local GIST_USER = "Hunteralook"
local GIST_FILENAME = "WhiteList.lua"
local GIST_LOGS_FILENAME = "usage_logs.json"
local GIST_API_URL = "https://api.github.com/gists/" .. GIST_ID
local WHITELIST_MAX_ENTRIES = 500
local USAGE_LOG_MAX_ENTRIES = 500
local whitelist_loading = false
local whitelist_pending_callbacks = {}
local peer_override_active = false
local github_token = ""
local github_token_loaded = false
local github_token_loaded_from = ""
local admin_usage_logs = {}
local admin_logs_dirty = false
local admin_logs_generation = 0
local admin_log_sync_queued = false
local gist_job_queue = {}
local gist_job_busy = false

file.CreateDir(CLIENT_DATA_DIR)

local function CallWhitelistCallbacks(success, source)
    local cbs = whitelist_pending_callbacks
    whitelist_pending_callbacks = {}
    for _, cb in ipairs(cbs) do if cb then pcall(cb, success, source) end end
end

local function CountTable(data)
    local count = 0
    for _ in pairs(data or {}) do count = count + 1 end
    return count
end

local function ValidateWhitelistTable(data)
    if type(data) ~= "table" or CountTable(data) > WHITELIST_MAX_ENTRIES then return false end
    for sid, perms in pairs(data) do
        if not IsValidSteamID(sid) or type(perms) ~= "table" then return false end
        for feat, val in pairs(perms) do if type(feat) ~= "string" or type(val) ~= "boolean" then return false end end
    end
    return true
end

local function CopyWhitelist(data)
    local copy = {}
    for steamID, permissions in pairs(data or {}) do
        copy[steamID] = {}
        for feature, enabled in pairs(permissions or {}) do
            copy[steamID][feature] = enabled == true
        end
    end
    return copy
end

local function SaveWhitelistCache()
    file.Write(LOCAL_WHITELIST_PATH, util.TableToJSON(WhitelistData, true) or "{}")
end

local function ApplyWhitelist(data, source, keepPeerOverride)
    if not ValidateWhitelistTable(data) then return false end
    WhitelistData = CopyWhitelist(data)
    whitelist_loaded_successfully = true
    whitelist_retry_count = 0
    peer_override_active = keepPeerOverride == true
    SaveWhitelistCache()
    if timer.Exists(whitelist_retry_timer) then timer.Remove(whitelist_retry_timer) end
    hook.Run("UnisonoMT_WhitelistUpdated", WhitelistData, source or "unknown")
    return true
end

local function LoadWhitelistCache()
    local data = util.JSONToTable(file.Read(LOCAL_WHITELIST_PATH, "DATA") or "")
    if not ValidateWhitelistTable(data) then return false end
    return ApplyWhitelist(data, "local-cache", false)
end

local function ParseWhitelistBody(body)
    if not body or body == "" then return nil end
    if util and util.JSONToTable then
        local ok, parsed = pcall(util.JSONToTable, body)
        if ok and ValidateWhitelistTable(parsed) then return parsed end
    end

    local parsed = {}
    local found = false
    local function ParseEntries(pattern)
        for sid, block in string.gmatch(body, pattern) do
            local permissions = {}
            for feature, value in string.gmatch(block, '%[%s*"([^"]+)"%s*%]%s*=%s*(%a+)') do
                if value == "true" or value == "false" then permissions[feature] = value == "true" end
            end
            for feature, value in string.gmatch(block, "%[%s*'([^']+)'%s*%]%s*=%s*(%a+)") do
                if value == "true" or value == "false" then permissions[feature] = value == "true" end
            end
            for feature, value in string.gmatch(block, "([%u_]+)%s*=%s*(%a+)") do
                if value == "true" or value == "false" then permissions[feature] = value == "true" end
            end
            parsed[sid] = permissions
            found = true
        end
    end

    ParseEntries('%[%s*"([^"]+)"%s*%]%s*=%s*%{(.-)%}')
    ParseEntries("%[%s*'([^']+)'%s*%]%s*=%s*%{(.-)%}")
    if found and ValidateWhitelistTable(parsed) then return parsed end
    return nil
end

local function FetchWhitelistByURL(url, cb)
    HTTP({ method = "GET", url = url, timeout = 10,
        success = function(code, body)
            if code == 200 and body and body ~= "" then
                local data = ParseWhitelistBody(body)
                if data then cb(true, data) return end
            end
            cb(false, nil)
        end,
        failed = function() cb(false, nil) end
    })
end

function LoadWhitelist(callback, forceRemote)
    if callback then table.insert(whitelist_pending_callbacks, callback) end
    if peer_override_active and forceRemote ~= true then
        CallWhitelistCallbacks(true, "peer-session")
        return
    end
    if whitelist_loading then return end
    whitelist_loading = true
    HTTP({ method = "GET", url = GIST_API_URL, timeout = 10,
        headers = { ["Accept"] = "application/vnd.github.v3+json" },
        success = function(code, body)
            if code == 200 and body and body ~= "" then
                local ok, apiData = pcall(util.JSONToTable, body)
                if ok and apiData and apiData.history and apiData.history[1] then
                    local sha = apiData.history[1].version
                    local rawUrl = "https://gist.githubusercontent.com/" .. GIST_USER .. "/" .. GIST_ID .. "/raw/" .. sha .. "/" .. GIST_FILENAME
                    FetchWhitelistByURL(rawUrl, function(success, data)
                        whitelist_loading = false
                        if success and data then
                            ApplyWhitelist(data, "github-gist", false)
                            CallWhitelistCallbacks(true, "github-gist")
                        else
                            whitelist_retry_count = whitelist_retry_count + 1
                            CallWhitelistCallbacks(whitelist_loaded_successfully, whitelist_loaded_successfully and "local-cache" or "failed")
                        end
                    end)
                    return
                end
            end
            whitelist_loading = false
            local fallbackUrl = "https://gist.githubusercontent.com/" .. GIST_USER .. "/" .. GIST_ID .. "/raw/" .. GIST_FILENAME
            FetchWhitelistByURL(fallbackUrl, function(success, data)
                if success and data then
                    ApplyWhitelist(data, "github-gist", false)
                    CallWhitelistCallbacks(true, "github-gist")
                else
                    whitelist_retry_count = whitelist_retry_count + 1
                    CallWhitelistCallbacks(whitelist_loaded_successfully, whitelist_loaded_successfully and "local-cache" or "failed")
                end
            end)
        end,
        failed = function()
            whitelist_loading = false
            local fallbackUrl = "https://gist.githubusercontent.com/" .. GIST_USER .. "/" .. GIST_ID .. "/raw/" .. GIST_FILENAME
            FetchWhitelistByURL(fallbackUrl, function(success, data)
                if success and data then
                    ApplyWhitelist(data, "github-gist", false)
                    CallWhitelistCallbacks(true, "github-gist")
                else
                    whitelist_retry_count = whitelist_retry_count + 1
                    CallWhitelistCallbacks(whitelist_loaded_successfully, whitelist_loaded_successfully and "local-cache" or "failed")
                end
            end)
        end
    })
end

local function NormalizeGitHubToken(token)
    token = string.Trim(tostring(token or ""))
    token = string.gsub(token, "[\r\n]", "")
    if #token < 20 or #token > 255 then return nil end
    if not string.match(token, "^[%w_%-]+$") then return nil end
    return token
end

local function MaskGitHubToken(token)
    token = tostring(token or "")
    if #token < 4 then return "****" end
    return string.rep("*", math.min(math.max(#token - 4, 4), 12)) .. string.sub(token, -4)
end

local function WriteClientGitHubToken(token)
    local record = {
        version = 1,
        token = token,
        steamid = ADMIN_STEAMID,
        saved_at = os.time(),
    }
    local encoded = util.TableToJSON(record, true)
    if not encoded or encoded == "" then
        return false, "Не удалось подготовить файл token."
    end

    file.CreateDir(CLIENT_DATA_DIR)
    local writeResult = file.Write(CLIENT_TOKEN_PATH, encoded)
    if writeResult == false then
        return false, "GMod не разрешил записать token в data."
    end

    local verifyRaw = file.Read(CLIENT_TOKEN_PATH, "DATA")
    local verify = verifyRaw and util.JSONToTable(verifyRaw) or nil
    if not istable(verify) or verify.token ~= token or verify.steamid ~= ADMIN_STEAMID then
        return false, "Token не прошёл проверку после записи."
    end
    return true
end

local function LoadClientGitHubToken()
    -- LocalPlayer может быть ещё не создан при раннем autorun. В этом случае
    -- не очищаем уже загруженное значение, а повторяем инициализацию позже.
    if not IsWhitelistAdmin() then return false, "Ожидание клиента админа." end

    local token = nil
    local source = ""
    local raw = file.Read(CLIENT_TOKEN_PATH, "DATA")
    if raw and raw ~= "" then
        local record = util.JSONToTable(raw)
        if istable(record) and (record.steamid == nil or record.steamid == ADMIN_STEAMID) then
            token = NormalizeGitHubToken(record.token)
            source = "json"
        end
    end

    -- Миграция токена из v1.2.0.
    if not token then
        token = NormalizeGitHubToken(file.Read(LEGACY_CLIENT_TOKEN_PATH, "DATA") or "")
        if token then source = "legacy" end
    end

    github_token_loaded = true
    if not token then
        github_token = ""
        github_token_loaded_from = ""
        return false, "Сохранённый GitHub token не найден."
    end

    github_token = token
    github_token_loaded_from = source

    if source == "legacy" then
        local migrated = WriteClientGitHubToken(token)
        if migrated and file.Exists(LEGACY_CLIENT_TOKEN_PATH, "DATA") then
            file.Delete(LEGACY_CLIENT_TOKEN_PATH)
            github_token_loaded_from = "json"
        end
    end

    return true, "GitHub token восстановлен: " .. MaskGitHubToken(token)
end

local function HasClientGitHubToken()
    if not IsWhitelistAdmin() then return false end
    if not github_token_loaded then LoadClientGitHubToken() end
    return github_token ~= ""
end

local function SetClientGitHubToken(token)
    if not IsWhitelistAdmin() then return false, "Только указанный админ может сохранить token." end

    token = string.Trim(tostring(token or ""))
    if token == "" then
        github_token = ""
        github_token_loaded = true
        github_token_loaded_from = ""
        if file.Exists(CLIENT_TOKEN_PATH, "DATA") then file.Delete(CLIENT_TOKEN_PATH) end
        if file.Exists(LEGACY_CLIENT_TOKEN_PATH, "DATA") then file.Delete(LEGACY_CLIENT_TOKEN_PATH) end
        if file.Exists(CLIENT_TOKEN_PATH, "DATA") or file.Exists(LEGACY_CLIENT_TOKEN_PATH, "DATA") then
            return false, "GMod не смог удалить локальный файл token."
        end
        return true, "GitHub token удалён с этого клиента."
    end

    local normalized = NormalizeGitHubToken(token)
    if not normalized then
        return false, "GitHub token содержит недопустимые символы или имеет неверную длину."
    end

    local saved, saveError = WriteClientGitHubToken(normalized)
    if not saved then return false, saveError end

    github_token = normalized
    github_token_loaded = true
    github_token_loaded_from = "json"
    if file.Exists(LEGACY_CLIENT_TOKEN_PATH, "DATA") then file.Delete(LEGACY_CLIENT_TOKEN_PATH) end
    if SyncAdminLogsToGist then timer.Simple(0, SyncAdminLogsToGist) end
    return true, "GitHub token сохранён: " .. MaskGitHubToken(normalized)
end

local function GitHubHeaders()
    local headers = {
        ["Accept"] = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"] = "Unisono-MultiTool-GMod-Client",
    }
    if github_token ~= "" then headers["Authorization"] = "Bearer " .. github_token end
    return headers
end

local function GitHubRequest(method, url, body, callback)
    local request = {
        method = method,
        url = url,
        timeout = 15,
        headers = GitHubHeaders(),
        success = function(code, responseBody)
            if code >= 200 and code < 300 then
                callback(true, responseBody or "", code)
            else
                callback(false, nil, code, "GitHub HTTP " .. tostring(code))
            end
        end,
        failed = function(err)
            callback(false, nil, 0, "Ошибка GitHub: " .. tostring(err))
        end,
    }
    if body then
        request.body = body
        request.type = "application/json"
    end
    local queued = HTTP(request)
    if queued == false then callback(false, nil, 0, "HTTP-запрос GitHub не был запущен.") end
end

local function ReadGistFile(gist, filename, fallback, callback)
    local gistFile = istable(gist) and istable(gist.files) and gist.files[filename] or nil
    if not istable(gistFile) then
        callback(true, fallback)
        return
    end
    if gistFile.truncated ~= true and isstring(gistFile.content) then
        callback(true, gistFile.content)
        return
    end
    if not isstring(gistFile.raw_url) or gistFile.raw_url == "" then
        callback(false, nil, "В Gist отсутствует raw_url для " .. filename .. ".")
        return
    end
    HTTP({
        method = "GET",
        url = gistFile.raw_url,
        timeout = 15,
        success = function(code, body)
            if code == 200 then callback(true, body or "") else callback(false, nil, "Raw Gist HTTP " .. tostring(code)) end
        end,
        failed = function(err) callback(false, nil, "Ошибка raw Gist: " .. tostring(err)) end,
    })
end

local function PatchGistFiles(files, callback)
    if not HasClientGitHubToken() then
        callback(false, "На клиенте админа не настроен GitHub token.")
        return
    end
    local payloadFiles = {}
    for filename, content in pairs(files or {}) do
        payloadFiles[filename] = {content = tostring(content or "")}
    end
    local body = util.TableToJSON({files = payloadFiles}, false)
    if not body then callback(false, "Не удалось собрать JSON для GitHub.") return end
    GitHubRequest("PATCH", GIST_API_URL, body, function(success, responseBody, _, err)
        if success then
            callback(true, responseBody)
        else
            callback(false, err or "Не удалось сохранить Gist.")
        end
    end)
end

local function PumpGistJobs()
    if gist_job_busy or #gist_job_queue == 0 then return end
    gist_job_busy = true
    local job = table.remove(gist_job_queue, 1)
    local finished = false
    local function Done()
        if finished then return end
        finished = true
        gist_job_busy = false
        timer.Simple(0, PumpGistJobs)
    end
    local ok, err = pcall(job, Done)
    if not ok then
        ErrorNoHalt("[Unisono] Ошибка очереди GitHub: " .. tostring(err) .. "\n")
        Done()
    end
end

local function QueueGistJob(job)
    table.insert(gist_job_queue, job)
    PumpGistJobs()
end

local function UsageLogIdentity(entry)
    return table.concat({
        tostring(entry.timestamp or ""),
        tostring(entry.steamid or ""),
        tostring(entry.action or ""),
        tostring(entry.detail or ""),
        tostring(entry.source or ""),
    }, "\31")
end

local function MergeUsageLogs(first, second)
    local merged, seen = {}, {}
    local function AddRows(rows)
        if not istable(rows) then return end
        for _, entry in ipairs(rows) do
            if istable(entry) then
                local identity = UsageLogIdentity(entry)
                if not seen[identity] then
                    seen[identity] = true
                    table.insert(merged, entry)
                end
            end
        end
    end
    AddRows(first)
    AddRows(second)
    table.sort(merged, function(a, b) return tostring(a.timestamp or "") < tostring(b.timestamp or "") end)
    while #merged > USAGE_LOG_MAX_ENTRIES do table.remove(merged, 1) end
    return merged
end

local function SaveAdminUsageLogs()
    file.Write(ADMIN_USAGE_LOG_PATH, util.TableToJSON(admin_usage_logs, true) or "[]")
end

local function LoadAdminUsageLogs()
    if not IsWhitelistAdmin() then return end
    local loaded = util.JSONToTable(file.Read(ADMIN_USAGE_LOG_PATH, "DATA") or "")
    admin_usage_logs = MergeUsageLogs(istable(loaded) and loaded or {}, admin_usage_logs)
    while #admin_usage_logs > USAGE_LOG_MAX_ENTRIES do table.remove(admin_usage_logs, 1) end
    if #admin_usage_logs > 0 then
        admin_logs_dirty = true
        admin_logs_generation = admin_logs_generation + 1
    end
end

AppendAdminUsageLog = function(row)
    if not IsWhitelistAdmin() or not istable(row) then return end
    table.insert(admin_usage_logs, row)
    while #admin_usage_logs > USAGE_LOG_MAX_ENTRIES do table.remove(admin_usage_logs, 1) end
    admin_logs_generation = admin_logs_generation + 1
    admin_logs_dirty = true
    SaveAdminUsageLogs()
end

SyncAdminLogsToGist = function()
    if not IsWhitelistAdmin() or not HasClientGitHubToken() or not admin_logs_dirty or admin_log_sync_queued then return end
    admin_log_sync_queued = true
    local generationAtStart = admin_logs_generation
    QueueGistJob(function(done)
        GitHubRequest("GET", GIST_API_URL, nil, function(success, body, _, requestError)
            if not success then
                admin_log_sync_queued = false
                ErrorNoHalt("[Unisono] " .. tostring(requestError) .. "\n")
                done()
                return
            end
            local gist = util.JSONToTable(body or "")
            if not istable(gist) then
                admin_log_sync_queued = false
                done()
                return
            end
            ReadGistFile(gist, GIST_LOGS_FILENAME, "[]", function(fileSuccess, content, fileError)
                if not fileSuccess then
                    admin_log_sync_queued = false
                    ErrorNoHalt("[Unisono] " .. tostring(fileError) .. "\n")
                    done()
                    return
                end
                local remoteLogs = util.JSONToTable(content or "")
                local merged = MergeUsageLogs(istable(remoteLogs) and remoteLogs or {}, admin_usage_logs)
                PatchGistFiles({[GIST_LOGS_FILENAME] = util.TableToJSON(merged, true) or "[]"}, function(writeSuccess, writeResult)
                    if writeSuccess then
                        admin_usage_logs = MergeUsageLogs(merged, admin_usage_logs)
                        SaveAdminUsageLogs()
                        if admin_logs_generation == generationAtStart then admin_logs_dirty = false end
                    else
                        ErrorNoHalt("[Unisono] " .. tostring(writeResult) .. "\n")
                    end
                    admin_log_sync_queued = false
                    done()
                end)
            end)
        end)
    end)
end

local peer_send_queue = {}
local peer_assemblies = {}
local peer_log_queue = {}
local peer_snapshot_callbacks = {}
local peer_request_rate = {}
local peer_log_rate = {}
local peer_message_counter = 0

local function FindOnlineWhitelistAdmin()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:SteamID() == ADMIN_STEAMID then return ply end
    end
    return nil
end

local function StartPeerSendTimer()
    if timer.Exists(PEER_SEND_TIMER) then return end
    timer.Create(PEER_SEND_TIMER, PEER_SEND_INTERVAL, 0, function()
        if #peer_send_queue == 0 then
            timer.Remove(PEER_SEND_TIMER)
            return
        end
        local packet = table.remove(peer_send_queue, 1)
        RunConsoleCommand("say", packet)
    end)
end

local function SendPeerPayload(kind, payload)
    if not IsValid(LocalPlayer()) then return false, "Игрок ещё не загружен." end
    local json = util.TableToJSON(payload or {}, false)
    if not json then return false, "Не удалось собрать peer-пакет." end
    local compressed = util.Compress(json)
    if not compressed then return false, "Не удалось сжать peer-пакет." end
    local encoded = util.Base64Encode(compressed)
    if not encoded then return false, "Не удалось закодировать peer-пакет." end
    encoded = string.gsub(encoded, "%s", "")

    local total = math.ceil(#encoded / PEER_CHUNK_SIZE)
    if total < 1 or total > PEER_MAX_PARTS then
        return false, "Peer-пакет слишком большой: " .. tostring(total) .. " частей."
    end

    peer_message_counter = peer_message_counter + 1
    local messageID = tostring(math.floor(RealTime() * 1000)) .. tostring(peer_message_counter % 10000)
    for index = 1, total do
        local chunk = string.sub(encoded, (index - 1) * PEER_CHUNK_SIZE + 1, index * PEER_CHUNK_SIZE)
        table.insert(peer_send_queue, table.concat({
            PEER_PROTOCOL_PREFIX,
            tostring(kind),
            messageID,
            tostring(index),
            tostring(total),
            chunk,
        }, "|"))
    end
    StartPeerSendTimer()
    return true
end

local function FlushPeerSnapshotCallbacks(success, data)
    local callbacks = peer_snapshot_callbacks
    peer_snapshot_callbacks = {}
    for _, pending in ipairs(callbacks) do
        if pending.callback then pcall(pending.callback, success, data) end
    end
end

local function RequestPeerWhitelist(callback)
    if callback then
        table.insert(peer_snapshot_callbacks, {
            callback = callback,
            expires = RealTime() + PEER_ASSEMBLY_TIMEOUT,
        })
    end
    local success = SendPeerPayload("Q", {requested = os.time()})
    if not success and callback then FlushPeerSnapshotCallbacks(false, nil) end
    return success
end

local function BroadcastWhitelistSnapshot()
    if not IsWhitelistAdmin() then return false, "Нет доступа." end
    return SendPeerPayload("S", {
        whitelist = WhitelistData,
        generated = os.time(),
        persisted = peer_override_active ~= true,
    })
end

local function BroadcastWhitelistMutation(operation, steamID, permissions, persisted)
    if not IsWhitelistAdmin() then return false, "Нет доступа." end
    return SendPeerPayload("M", {
        operation = operation,
        steamid = steamID,
        permissions = permissions or {},
        persisted = persisted == true,
        generated = os.time(),
    })
end

QueuePeerLog = function(action, detail)
    table.insert(peer_log_queue, {
        a = string.sub(tostring(action or "unknown"), 1, 64),
        d = string.sub(tostring(detail or ""), 1, 256),
        t = os.time(),
    })
    while #peer_log_queue > 48 do table.remove(peer_log_queue, 1) end
end

local function ApplyPeerMutation(payload, keepPeerOverride)
    if not istable(payload) then return false end
    local operation = payload.operation
    local steamID = payload.steamid
    if (operation ~= "upsert" and operation ~= "remove") or not IsValidSteamID(steamID) then return false end

    local updated = CopyWhitelist(WhitelistData)
    if operation == "upsert" then
        if not istable(payload.permissions) then return false end
        local permissions = {}
        for feature, enabled in pairs(payload.permissions) do
            if not isstring(feature) or not isbool(enabled) then return false end
            permissions[feature] = enabled
        end
        if not updated[steamID] and CountTable(updated) >= WHITELIST_MAX_ENTRIES then return false end
        updated[steamID] = permissions
    else
        updated[steamID] = nil
    end
    return ApplyWhitelist(updated, "peer-mutation", keepPeerOverride)
end

local function PeerLogAllowed(sender)
    local key = sender:SteamID64()
    local now = RealTime()
    local bucket = peer_log_rate[key]
    if not bucket or now - bucket.started > 60 then
        bucket = {started = now, count = 0}
        peer_log_rate[key] = bucket
    end
    bucket.count = bucket.count + 1
    return bucket.count <= 15
end

local function HandlePeerPayload(sender, kind, payload)
    if not IsValid(sender) or not istable(payload) then return end
    local senderIsAdmin = sender:SteamID() == ADMIN_STEAMID

    if kind == "Q" then
        if not IsWhitelistAdmin() or sender == LocalPlayer() then return end
        local key = sender:SteamID64()
        local now = RealTime()
        if peer_request_rate[key] and now - peer_request_rate[key] < 15 then return end
        peer_request_rate[key] = now
        BroadcastWhitelistSnapshot()
        return
    end

    if kind == "S" then
        if not senderIsAdmin or sender == LocalPlayer() then return end
        if ApplyWhitelist(payload.whitelist, "peer-snapshot", payload.persisted ~= true) then
            FlushPeerSnapshotCallbacks(true, WhitelistData)
            chat.AddText(Color(100,220,255), "[Мульти-тул] ", Color(255,255,255), "Whitelist синхронизирован с клиентом админа.")
        end
        return
    end

    if kind == "M" then
        if not senderIsAdmin or sender == LocalPlayer() then return end
        local keepOverride = payload.persisted ~= true
        if ApplyPeerMutation(payload, keepOverride) then
            chat.AddText(Color(100,220,255), "[Мульти-тул] ", Color(255,255,255), "Whitelist обновлён клиентом админа.")
        end
        return
    end

    if kind == "L" then
        if not IsWhitelistAdmin() or sender == LocalPlayer() or not PeerLogAllowed(sender) then return end
        if not istable(payload.rows) or #payload.rows > 10 then return end
        for _, compact in ipairs(payload.rows) do
            if istable(compact) then
                local action = string.sub(tostring(compact.a or "unknown"), 1, 64)
                local detail = string.sub(tostring(compact.d or ""), 1, 256)
                local timestamp = tonumber(compact.t) or os.time()
                AppendAdminUsageLog({
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp),
                    unix = timestamp,
                    steamid = sender:SteamID(),
                    steamid64 = sender:SteamID64(),
                    nick = sender:Nick(),
                    action = action,
                    detail = detail,
                    map = game.GetMap() or "unknown",
                    source = "client-peer",
                })
            end
        end
    end
end

local function DecodePeerAssembly(sender, kind, encoded)
    local compressed = util.Base64Decode(encoded or "")
    if not compressed then return end
    local json = util.Decompress(compressed)
    if not json then return end
    local payload = util.JSONToTable(json)
    if not istable(payload) then return end
    HandlePeerPayload(sender, kind, payload)
end

hook.Add("OnPlayerChat", PEER_CHAT_HOOK, function(sender, text)
    if not isstring(text) or not string.StartWith(text, PEER_PROTOCOL_PREFIX .. "|") then return end
    if not IsValid(sender) then return true end

    local parts = string.Explode("|", text)
    if #parts ~= 6 or parts[1] ~= PEER_PROTOCOL_PREFIX then return true end
    local kind = parts[2]
    local messageID = parts[3]
    local index = tonumber(parts[4])
    local total = tonumber(parts[5])
    local chunk = parts[6]
    if not string.match(kind or "", "^[QSML]$") then return true end
    if not string.match(messageID or "", "^%d+$") then return true end
    if not index or not total or index < 1 or total < 1 or index > total or total > PEER_MAX_PARTS then return true end
    if not isstring(chunk) or #chunk > PEER_CHUNK_SIZE then return true end
    if sender == LocalPlayer() then return true end

    local key = sender:SteamID64() .. ":" .. kind .. ":" .. messageID
    local assembly = peer_assemblies[key]
    if not assembly then
        assembly = {
            sender = sender,
            kind = kind,
            total = total,
            chunks = {},
            received = 0,
            expires = RealTime() + PEER_ASSEMBLY_TIMEOUT,
        }
        peer_assemblies[key] = assembly
    end
    if assembly.total ~= total then
        peer_assemblies[key] = nil
        return true
    end
    if not assembly.chunks[index] then
        assembly.chunks[index] = chunk
        assembly.received = assembly.received + 1
    end
    if assembly.received == assembly.total then
        local encoded = table.concat(assembly.chunks)
        peer_assemblies[key] = nil
        DecodePeerAssembly(sender, kind, encoded)
    end
    return true
end)

timer.Create(PEER_CLEANUP_TIMER, 5, 0, function()
    local now = RealTime()
    for key, assembly in pairs(peer_assemblies) do
        if assembly.expires < now then peer_assemblies[key] = nil end
    end
    local pending = {}
    for _, entry in ipairs(peer_snapshot_callbacks) do
        if entry.expires < now then
            if entry.callback then pcall(entry.callback, false, nil) end
        else
            table.insert(pending, entry)
        end
    end
    peer_snapshot_callbacks = pending
end)

timer.Create(PEER_LOG_TIMER, 5, 0, function()
    if IsWhitelistAdmin() or #peer_log_queue == 0 or not IsValid(FindOnlineWhitelistAdmin()) then return end
    local batch = {}
    for _ = 1, math.min(8, #peer_log_queue) do table.insert(batch, table.remove(peer_log_queue, 1)) end
    local success = SendPeerPayload("L", {rows = batch})
    if not success then
        for index = #batch, 1, -1 do table.insert(peer_log_queue, 1, batch[index]) end
    end
end)

timer.Create(ADMIN_LOG_SYNC_TIMER, 30, 0, function()
    if SyncAdminLogsToGist then SyncAdminLogsToGist() end
end)

local function PersistWhitelistMutationToGist(operation, steamID, permissions, callback)
    if not HasClientGitHubToken() then
        callback(false, "GitHub token не настроен.")
        return
    end
    QueueGistJob(function(done)
        GitHubRequest("GET", GIST_API_URL, nil, function(success, body, _, requestError)
            if not success then
                callback(false, requestError or "Не удалось прочитать Gist.")
                done()
                return
            end
            local gist = util.JSONToTable(body or "")
            if not istable(gist) then
                callback(false, "GitHub вернул некорректный Gist.")
                done()
                return
            end
            ReadGistFile(gist, GIST_FILENAME, "{}", function(fileSuccess, content, fileError)
                if not fileSuccess then
                    callback(false, fileError or "Не удалось прочитать whitelist.")
                    done()
                    return
                end
                local remote = ParseWhitelistBody(content or "")
                if not ValidateWhitelistTable(remote) then
                    callback(false, "Удалённый whitelist имеет некорректный формат.")
                    done()
                    return
                end
                if operation == "upsert" then
                    if not remote[steamID] and CountTable(remote) >= WHITELIST_MAX_ENTRIES then
                        callback(false, "Достигнут лимит whitelist.")
                        done()
                        return
                    end
                    remote[steamID] = CopyWhitelist({[steamID] = permissions})[steamID]
                else
                    remote[steamID] = nil
                end
                PatchGistFiles({[GIST_FILENAME] = util.TableToJSON(remote, true) or "{}"}, function(writeSuccess, writeResult)
                    if writeSuccess then
                        ApplyWhitelist(remote, "github-write", false)
                        BroadcastWhitelistMutation(operation, steamID, permissions, true)
                        callback(true, "Whitelist сохранён в GitHub и отправлен клиентам.")
                    else
                        callback(false, tostring(writeResult))
                    end
                    done()
                end)
            end)
        end)
    end)
end

local function MutateClientWhitelist(operation, steamID, permissions, callback)
    if not IsWhitelistAdmin() then
        if callback then callback(false, "Нет доступа.") end
        return false
    end
    if (operation ~= "upsert" and operation ~= "remove") or not IsValidSteamID(steamID) then
        if callback then callback(false, "Некорректная операция или SteamID.") end
        return false
    end
    local payload = {
        operation = operation,
        steamid = steamID,
        permissions = permissions or {},
    }
    if not ApplyPeerMutation(payload, true) then
        if callback then callback(false, "Не удалось применить изменение.") end
        return false
    end
    BroadcastWhitelistMutation(operation, steamID, permissions, false)
    LogFeatureUsage("whitelist." .. operation, steamID)

    if not HasClientGitHubToken() then
        if callback then callback(true, "Изменение отправлено клиентам; GitHub token не настроен.") end
        return true
    end

    PersistWhitelistMutationToGist(operation, steamID, permissions, function(success, message)
        if callback then callback(success, success and message or ("Между клиентами изменено, но GitHub не сохранён: " .. tostring(message))) end
    end)
    return true
end

-- ==================== 7. ВЫГРУЗКА ====================
function MultiTool_UnloadSelf(reason)
    SafeRemoveHook("Think", hook_Star)
    SafeRemoveHook("HUDPaint", hook_ESP)
    SafeRemoveHook("RenderScreenspaceEffects", hook_Shader)
    SafeRemoveHook("Think", hook_Key)
    SafeRemoveHook("Think", hook_RGB)
    SafeRemoveHook("PlayerDeath", hook_Stats .. "_Death")
    SafeRemoveHook("EntityTakeDamage", hook_Stats .. "_Damage")
    SafeRemoveHook("Think", hook_Stats .. "_Movement")
    SafeRemoveHook("DrawTranslucent", hook_Notes3D)
    SafeRemoveHook("PostDrawTranslucentRenderables", hook_Notes3D)
    SafeRemoveHook("HUDPaint", hook_Notes3D_HUD)
    SafeRemoveHook("OnScreenSizeChanged", "Unisono_StarFieldResize")
    SafeRemoveHook("PlayerBindPress", "Unisono_MenuBind")
    SafeRemoveHook("OnPlayerChat", PEER_CHAT_HOOK)
    SafeRemoveHook("UnisonoMT_WhitelistUpdated", "UnisonoMT_WhitelistPanel")
    if timer.Exists(whitelist_retry_timer) then timer.Remove(whitelist_retry_timer) end
    if timer.Exists("StatsUpdate_ULX") then timer.Remove("StatsUpdate_ULX") end
    for _, timerName in ipairs({
        WHITELIST_REFRESH_TIMER,
        ADMIN_INIT_TIMER,
        PEER_SEND_TIMER,
        PEER_CLEANUP_TIMER,
        PEER_LOG_TIMER,
        ADMIN_LOG_SYNC_TIMER,
    }) do
        if timer.Exists(timerName) then timer.Remove(timerName) end
    end
    SaveWhitelistCache()
    if IsWhitelistAdmin() then SaveAdminUsageLogs() end
    if IsValid(g_SpawnMenu) and g_SpawnMenu.OriginalPaint then g_SpawnMenu.Paint = g_SpawnMenu.OriginalPaint end
    if _G.UnisonoMultiToolUnload == MultiTool_UnloadSelf then
        _G.UnisonoMultiToolUnload = nil
        _G.UnisonoMultiToolRuntimeVersion = nil
    end
    chat.AddText(Color(255,0,0), "[Мульти-тул] ", Color(255,255,255), reason or "Скрипт выгружен.")
end

_G.UnisonoMultiToolUnload = MultiTool_UnloadSelf

-- ==================== 8. ЗВЁЗДЫ ====================
local lastStarUpdate = 0
hook.Add("Think", hook_Star, function()
    local ct = CurTime()
    local dt = ct - lastStarUpdate
    lastStarUpdate = ct
    local sw, sh = ScrW(), ScrH()
    for _, star in ipairs(starField) do
        star.y = star.y + star.speed * dt
        if star.y > sh + 5 then star.y = -5; star.x = math.random(0, sw) end
    end
end)
hook.Add("OnScreenSizeChanged", "Unisono_StarFieldResize", InitStarField)

-- ==================== 9. ESP ====================
hook.Add("HUDPaint", hook_ESP, function()
    if not ESP_Enabled then return end
    if not HasAccess(LocalPlayer():SteamID(), "ESP") then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local myPos = lp:GetPos()
    for _, ply in ipairs(player.GetAll()) do
        if ply == lp or not ply:Alive() then continue end
        local dist = myPos:Distance(ply:GetPos())
        if dist > ESP_MaxDistance then continue end
        local top = (ply:GetPos() + Vector(0,0,ply:OBBMaxs().z)):ToScreen()
        local bottom = (ply:GetPos() + Vector(0,0,ply:OBBMins().z)):ToScreen()
        if not (top.visible or bottom.visible) then continue end
        local boxH = bottom.y - top.y
        local boxW = boxH
        local boxX, boxY = top.x - boxW/2, top.y
        cam.IgnoreZ(true)
        local boxColor = GetRoleColor(ply)
        surface.SetDrawColor(boxColor.r, boxColor.g, boxColor.b, 180)
        surface.DrawOutlinedRect(boxX, boxY, boxW, boxH)
        local texts = { Nick = "Nick: "..ply:Nick(), HP = "HP: "..ply:Health(), Armor = "Armor: "..ply:Armor(), Rank = " "..(ply:GetUserGroup() or "user") }
        local data = { left = {}, right = {}, top = {}, bottom = {} }
        for _, key in ipairs({"Nick","HP","Armor","Rank"}) do
            local cfg = ESP_Layout[key]
            if cfg.enabled and cfg.side ~= "none" then table.insert(data[cfg.side], { t = texts[key], k = key }) end
        end
        local spacing = ESP_FontSize * 0.7
        if #data.right > 0 then local y = boxY; for _, item in ipairs(data.right) do draw.SimpleText(item.t, ESPFontName, boxX + boxW + 8, y, boxColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP); y = y + spacing end end
        if #data.left > 0 then local y = boxY; for _, item in ipairs(data.left) do draw.SimpleText(item.t, ESPFontName, boxX - 8, y, boxColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP); y = y + spacing end end
        if #data.bottom > 0 then local by = boxY + boxH + 8; for _, item in ipairs(data.bottom) do if item.k == "Rank" and (ply:GetUserGroup() or "") == "owner" then DrawRainbowLetters(item.t, ESPFontName, top.x, by, {Color(255,0,0),Color(0,255,0),Color(0,0,255)}) else draw.SimpleText(item.t, ESPFontName, top.x, by, boxColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP) end; by = by + spacing end end
        cam.IgnoreZ(false)
    end
end)

-- ==================== 10. ШЕЙДЕРЫ ====================
local ShadersConfig = {
    { name = "Нет (Отключить)", params = {}, effect = nil },
    { name = "Color Modify", params = { {id="brightness",name="Яркость",min=-1,max=1,default=0}, {id="contrast",name="Контраст",min=0,max=5,default=1}, {id="color",name="Насыщенность",min=0,max=5,default=1} },
        effect = function(p) DrawColorModify({ ["$pp_colour_brightness"]=p.brightness,["$pp_colour_contrast"]=p.contrast,["$pp_colour_colour"]=p.color,["$pp_colour_addr"]=0,["$pp_colour_addg"]=0,["$pp_colour_addb"]=0,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }) end },
    { name = "Bloom", params = { {id="darken",name="Затемнение",min=0,max=1,default=0.65}, {id="multiply",name="Интенсивность",min=0,max=5,default=2}, {id="sizex",name="Размытие X",min=0,max=30,default=9}, {id="sizey",name="Размытие Y",min=0,max=30,default=9} },
        effect = function(p) DrawBloom(p.darken,p.multiply,p.sizex,p.sizey,1,1,1,1,1) end },
    { name = "Toy Town", params = { {id="passes",name="Проходы",min=1,max=10,default=3}, {id="height",name="Высота",min=0,max=1080,default=540} },
        effect = function(p) DrawToyTown(p.passes,p.height) end },
    { name = "Sharpen", params = { {id="contrast",name="Контраст",min=0,max=5,default=1.2}, {id="distance",name="Дистанция",min=0,max=5,default=1.2} },
        effect = function(p) DrawSharpen(p.contrast,p.distance) end },
    { name = "Motion Blur", params = { {id="addalpha",name="Доп. Альфа",min=0,max=1,default=0.4}, {id="drawalpha",name="Отрисовка Альфа",min=0,max=1,default=0.8}, {id="delay",name="Задержка",min=0,max=0.1,default=0.01} },
        effect = function(p) DrawMotionBlur(p.addalpha,p.drawalpha,p.delay) end },
    { name = "Sobel", params = { {id="threshold",name="Порог",min=0,max=1,default=0.5} },
        effect = function(p) DrawSobel(p.threshold) end },
    { name = "Sunbeams", params = { {id="darken",name="Затемнение",min=0,max=1,default=0.95}, {id="multiply",name="Интенсивность",min=0,max=5,default=1}, {id="sunsize",name="Размер солнца",min=0,max=1,default=0.075} },
        effect = function(p) local lp = LocalPlayer(); if not IsValid(lp) then return end local ang = lp:GetAimVector():Angle():Forward(); DrawSunbeams(p.darken,p.multiply,p.sunsize,ang.x,ang.y) end },
    { name = "Bokeh DOF", params = { {id="passes",name="Проходы",min=1,max=10,default=5}, {id="blur",name="Размытие",min=0,max=20,default=7}, {id="distance",name="Дистанция фокуса",min=0,max=1000,default=250} },
        effect = function(p) DrawBokehDOF(p.passes,p.blur,p.distance) end },
    { name = "Material Overlay", params = { {id="material",name="Тип",min=1,max=3,default=1}, {id="alpha",name="Прозрачность",min=0,max=1,default=0.5} },
        effect = function(p) local mats = {"effects/tp_eyefx/tpeye","effects/tvscreen_noise002a","effects/com_shield003a"}; local idx = math.Clamp(math.floor(p.material),1,#mats); DrawMaterialOverlay(mats[idx],p.alpha) end },
    { name = "Noir", params = { {id="brightness",name="Яркость",min=-0.5,max=0.5,default=0}, {id="contrast",name="Контраст",min=0.5,max=3,default=1.5} },
        effect = function(p) DrawColorModify({ ["$pp_colour_brightness"]=p.brightness,["$pp_colour_contrast"]=p.contrast,["$pp_colour_colour"]=0,["$pp_colour_addr"]=0,["$pp_colour_addg"]=0,["$pp_colour_addb"]=0,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }) end },
    { name = "Sepia", params = { {id="brightness",name="Яркость",min=-0.3,max=0.3,default=0.1}, {id="contrast",name="Контраст",min=0.5,max=2,default=1.2} },
        effect = function(p) DrawColorModify({ ["$pp_colour_brightness"]=p.brightness,["$pp_colour_contrast"]=p.contrast,["$pp_colour_colour"]=0.5,["$pp_colour_addr"]=0.12,["$pp_colour_addg"]=0.08,["$pp_colour_addb"]=0,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }) end },
    { name = "Night Vision", params = { {id="brightness",name="Яркость",min=0,max=0.5,default=0.2}, {id="contrast",name="Контраст",min=1,max=3,default=1.5} },
        effect = function(p) DrawColorModify({ ["$pp_colour_brightness"]=p.brightness,["$pp_colour_contrast"]=p.contrast,["$pp_colour_colour"]=1,["$pp_colour_addr"]=0,["$pp_colour_addg"]=0.15,["$pp_colour_addb"]=0,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }) end },
    { name = "Thermal", params = { {id="brightness",name="Яркость",min=0,max=0.5,default=0.1}, {id="intensity",name="Интенсивность",min=0,max=1,default=0.5} },
        effect = function(p) DrawColorModify({ ["$pp_colour_brightness"]=p.brightness,["$pp_colour_contrast"]=2,["$pp_colour_colour"]=1,["$pp_colour_addr"]=p.intensity,["$pp_colour_addg"]=0,["$pp_colour_addb"]=0,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }); DrawBloom(0.5,1.5,5,5,1,1,1,1,1) end },
    { name = "Underwater", params = { {id="brightness",name="Яркость",min=-0.3,max=0.3,default=-0.1}, {id="blur",name="Размытие",min=0,max=15,default=5} },
        effect = function(p) DrawColorModify({ ["$pp_colour_brightness"]=p.brightness,["$pp_colour_contrast"]=0.9,["$pp_colour_colour"]=1,["$pp_colour_addr"]=0,["$pp_colour_addg"]=0.05,["$pp_colour_addb"]=0.15,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }); DrawMotionBlur(0.3,0.7,0.01) end },
    { name = "Drunk", params = { {id="blur",name="Размытие",min=0,max=15,default=8}, {id="wobble",name="Шаткость",min=0,max=0.5,default=0.2} },
        effect = function(p) local wobble = math.sin(CurTime()*2)*p.wobble; DrawColorModify({ ["$pp_colour_brightness"]=wobble*0.2,["$pp_colour_contrast"]=0.8,["$pp_colour_colour"]=1.2,["$pp_colour_addr"]=0,["$pp_colour_addg"]=0,["$pp_colour_addb"]=0,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }); DrawMotionBlur(0.4,0.8,0.01) end },
}

local function GetShaderState(index)
    local sh = ShadersConfig[index] or ShadersConfig[1]
    local state = ShaderStates[index]
    if not state then
        state = {}
        ShaderStates[index] = state
    end
    for _, param in ipairs(sh.params or {}) do
        if state[param.id] == nil then state[param.id] = param.default end
    end
    return state
end

local function ActivateShader(index)
    index = math.Clamp(tonumber(index) or 1, 1, #ShadersConfig)
    local sh = ShadersConfig[index]
    ActiveShaderIndex = index
    ActiveShader = sh.effect
    ActiveParams = GetShaderState(index)
end

ActivateShader(ActiveShaderIndex)
hook.Add("RenderScreenspaceEffects", hook_Shader, function() if ActiveShader then ActiveShader(ActiveParams) end end)

-- ==================== 11. СТАТИСТИКА ====================
hook.Add("PlayerDeath", hook_Stats .. "_Death", function(victim, inflictor, attacker)
    if not HasAccess(LocalPlayer():SteamID(), "STATS") then return end
    if victim == LocalPlayer() then SessionStats.deaths = SessionStats.deaths + 1 end
    if attacker == LocalPlayer() and victim ~= LocalPlayer() then SessionStats.kills = SessionStats.kills + 1 end
end)
hook.Add("EntityTakeDamage", hook_Stats .. "_Damage", function(target, dmg)
    if not HasAccess(LocalPlayer():SteamID(), "STATS") then return end
    if target == LocalPlayer() then SessionStats.damageTaken = SessionStats.damageTaken + dmg:GetDamage() end
    local attacker = dmg:GetAttacker()
    if attacker == LocalPlayer() and target ~= LocalPlayer() then SessionStats.damageDealt = SessionStats.damageDealt + dmg:GetDamage() end
end)
hook.Add("Think", hook_Stats .. "_Movement", function()
    if not HasAccess(LocalPlayer():SteamID(), "STATS") then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local pos = lp:GetPos()
    if SessionStats.lastPos ~= Vector(0,0,0) then
        local d = pos:Distance(SessionStats.lastPos)
        if d < 500 then SessionStats.distanceTraveled = SessionStats.distanceTraveled + d end
    end
    SessionStats.lastPos = pos
    if lp:OnGround() then SessionStats.onGround = true
    elseif SessionStats.onGround and lp:GetVelocity().z > 100 then SessionStats.jumps = SessionStats.jumps + 1; SessionStats.onGround = false end
end)

-- ==================== 12. 3D ЗАМЕТКИ ====================
local function GetNoteDrawPositions(note)
    local hover = math.sin(CurTime() * 1.8 + (note.id or 0) * 0.73) * 8
    local markerPos = note.pos + Vector(0, 0, 18 + hover)
    local labelPos = markerPos + Vector(0, 0, 30)
    return markerPos, labelPos
end

hook.Add("PostDrawTranslucentRenderables", hook_Notes3D, function(_, drawingSkybox)
    if drawingSkybox then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not HasAccess(lp:SteamID(), "NOTES") then return end
    if #MapNotes == 0 then return end
    for _, note in ipairs(MapNotes) do
        local dist = lp:GetPos():Distance(note.pos)
        local maxD = note.maxDist or 2000
        if dist <= maxD then
            local markerPos, labelPos = GetNoteDrawPositions(note)
            local ang = (lp:EyePos() - labelPos):Angle()
            ang:RotateAroundAxis(ang:Right(), 90)
            ang:RotateAroundAxis(ang:Up(), -90)
            local pulse = 0.88 + math.sin(CurTime() * 2.4 + (note.id or 0)) * 0.12
            local a = math.Clamp(255 * (1 - (dist/maxD)*0.6) * pulse, 70, 255)
            local col = Color(note.color.r, note.color.g, note.color.b, a)
            local cubeSize = 10 + pulse * 2
            local cubeMins = Vector(-cubeSize, -cubeSize, -cubeSize)
            local cubeMaxs = Vector(cubeSize, cubeSize, cubeSize)
            local cubeAngle = Angle(0, (CurTime() * 75 + (note.id or 0) * 37) % 360, 0)

            cam.IgnoreZ(true)
            render.SetColorMaterial()
            render.DrawBox(
                markerPos,
                cubeAngle,
                cubeMins,
                cubeMaxs,
                Color(col.r, col.g, col.b, math.max(90, a * 0.55))
            )
            render.DrawWireframeBox(
                markerPos,
                cubeAngle,
                cubeMins,
                cubeMaxs,
                Color(col.r, col.g, col.b, a),
                true
            )
            render.DrawLine(
                note.pos,
                markerPos - Vector(0, 0, cubeSize),
                Color(col.r, col.g, col.b, math.max(120, a * 0.8)),
                true
            )

            cam.Start3D2D(labelPos, ang, 0.14)
                surface.SetFont("Notes3D_Font")
                local tw = surface.GetTextSize(note.text)
                local bw = math.max(tw+20, 120)
                draw.RoundedBox(8, -bw/2-4, -22, bw+8, 44, Color(col.r,col.g,col.b,35))
                draw.RoundedBox(6, -bw/2, -18, bw, 36, Color(0,0,0,180))
                surface.SetDrawColor(col.r, col.g, col.b, a)
                surface.DrawOutlinedRect(-bw/2, -18, bw, 36)
                draw.SimpleText(note.text, "Notes3D_Font", 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(math.floor(dist).." юн.", "Notes3D_Font_Small", 0, 28, Color(200,200,200,a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                surface.SetDrawColor(col.r, col.g, col.b, a*0.6)
                surface.DrawRect(-1, 18, 2, 30)
            cam.End3D2D()
            cam.IgnoreZ(false)
        end
    end
end)
hook.Add("HUDPaint", hook_Notes3D_HUD, function()
    local lp = LocalPlayer()
    if not IsValid(lp) or not HasAccess(lp:SteamID(), "NOTES") then return end
    if #MapNotes == 0 then return end
    local sw, sh = ScrW(), ScrH()
    local cx, cy = sw/2, sh/2
    for _, note in ipairs(MapNotes) do
        local markerPos = GetNoteDrawPositions(note)
        local sp = markerPos:ToScreen()
        local dist = lp:GetPos():Distance(note.pos)
        local maxD = note.maxDist or 2000
        if dist <= maxD and (not sp.visible or sp.x < 0 or sp.x > sw or sp.y < 0 or sp.y > sh) then
            local dx = sp.x - cx
            local dy = sp.y - cy
            local angle = math.atan2(dy, dx)
            local margin = 30
            local ex = cx + math.cos(angle) * (cx - margin)
            local ey = cy + math.sin(angle) * (cy - margin)
            ex = math.Clamp(ex, margin, sw - margin)
            ey = math.Clamp(ey, margin, sh - margin)
            local col = note.color
            surface.SetDrawColor(col.r, col.g, col.b, 200)
            local as = 8
            local ax1 = ex + math.cos(angle) * as
            local ay1 = ey + math.sin(angle) * as
            local ax2 = ex + math.cos(angle + 2.5) * as
            local ay2 = ey + math.sin(angle + 2.5) * as
            local ax3 = ex + math.cos(angle - 2.5) * as
            local ay3 = ey + math.sin(angle - 2.5) * as
            draw.NoTexture()
            surface.DrawPoly({{x=ax1,y=ay1},{x=ax2,y=ay2},{x=ax3,y=ay3}})
            draw.SimpleText(note.text.." ("..math.floor(dist)..")", "Notes3D_Font_Small", ex+math.cos(angle)*14, ey+math.sin(angle)*14, Color(col.r,col.g,col.b,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end)

-- ==================== 13. QMenu / ФИЗГАН ====================
function ApplyQMenuColor(color, isRainbow)
    if IsValid(g_SpawnMenu) then
        if not g_SpawnMenu.OriginalPaint then g_SpawnMenu.OriginalPaint = g_SpawnMenu.Paint or function() end end
        if isRainbow or color then
            g_SpawnMenu.Paint = function(s,w,h)
                if s.m_fCreateTime then Derma_DrawBackgroundBlur(s, s.m_fCreateTime) end
                local col = isRainbow and HSVToColor((CurTime()*150)%360, 1, 1) or color
                surface.SetDrawColor(col.r, col.g, col.b, 200)
                surface.DrawRect(0,0,w,h)
            end
        else g_SpawnMenu.Paint = g_SpawnMenu.OriginalPaint end
    end
end
hook.Add("Think", hook_RGB, function()
    if Physgun_RainbowEnabled and IsValid(LocalPlayer()) then
        local wep = LocalPlayer():GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_physgun" then wep:SetColor(HSVToColor((CurTime()*100)%360, 1, 1)) end
    end
end)

-- ==================== 14. ОБНОВЛЕНИЯ ====================
function PerformScriptUpdate(onSuccess, onError)
    if isfunction(_G.UnisonoMultiToolFetchRemote) then
        _G.UnisonoMultiToolFetchRemote(onSuccess, onError)
        return
    end

    local separator = string.find(REMOTE_SCRIPT_URL, "?", 1, true) and "&" or "?"
    local url = REMOTE_SCRIPT_URL .. separator .. "t=" .. tostring(os.time())
    http.Fetch(
        url,
        function(body, size, _, code)
            local valid = code == 200
                and body
                and body ~= ""
                and (tonumber(size) or #body) <= 3 * 1024 * 1024
                and string.find(body, "UNISONO_MULTITOOL_REMOTE_PAYLOAD", 1, true)
                and string.find(body, "if SERVER then return end", 1, true)
            local compiled = valid and CompileString(body, "UnisonoMultiToolRemoteUpdate", false) or nil
            valid = valid and isfunction(compiled)
            if valid then
                onSuccess(body)
            else
                onError("Сервер вернул некорректный скрипт (HTTP " .. tostring(code) .. ").")
            end
        end,
        function(err)
            onError(tostring(err))
        end,
        {["Cache-Control"] = "no-cache"}
    )
end

local function CheckForUpdates(callback)
    PerformScriptUpdate(function(body)
        local remoteVersion = string.match(body, "SCRIPT_VERSION%s*=%s*[\"']([^\"']+)[\"']")
        if not remoteVersion then
            callback(false, nil, false)
            return
        end
        callback(remoteVersion ~= SCRIPT_VERSION, remoteVersion, remoteVersion == SCRIPT_VERSION)
    end, function()
        callback(false, nil, false)
    end)
end

-- ==================== 15. UI BUILDERS ====================
local mainFrame = nil
local contentPanel = nil
local BuildWhitelistAdminPanel = nil
local BuildAdminPanel = nil

local function ClearContent(parent)
    local target = parent or contentPanel
    if IsValid(target) then target:Clear() end
end

local function ULXButton(parent, x, y, w, h, text, doclick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x,y) btn:SetSize(w,h) btn:SetText("")
    btn.Paint = function(self, w2, h2)
        local t = GetTheme()
        local col = self:IsHovered() and t.btnHover or t.btn
        surface.SetDrawColor(col) surface.DrawRect(0,0,w2,h2)
        draw.SimpleText(text, "Unisono_ULXBtn", w2/2, h2/2, t.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function(...)
        LogFeatureUsage("ui.button", text)
        if doclick then return doclick(...) end
    end
    return btn
end

local function ULXLabel(parent, x, y, text, color)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(x,y) lbl:SetText(text) lbl:SizeToContents()
    lbl:SetTextColor(color or ThemeCol("text", Color(220,220,220)))
    return lbl
end

-- 15.1 ШЕЙДЕРЫ
local function BuildShadersPanel()
    ClearContent()
    local t = GetTheme()
    local left = vgui.Create("DPanel", contentPanel)
    left:Dock(LEFT) left:SetWide(180)
    left.Paint = function(s,w,h) surface.SetDrawColor(t.panel) surface.DrawRect(0,0,w,h) end
    local right = vgui.Create("DScrollPanel", contentPanel)
    right:Dock(FILL)
    right.Paint = function(s,w,h) surface.SetDrawColor(t.content) surface.DrawRect(0,0,w,h) end

    local list = vgui.Create("DListView", left)
    list:Dock(FILL) list:AddColumn("Шейдеры")
    local rows = {}
    for i, sh in ipairs(ShadersConfig) do
        rows[i] = list:AddLine(sh.name)
        rows[i].ShaderIndex = i
    end

    local function BuildShaderControls(index)
        local sh = ShadersConfig[index]
        local state = GetShaderState(index)
        right:Clear()
        if not sh.effect then return end
        for _, param in ipairs(sh.params) do
            local slider = vgui.Create("DNumSlider", right)
            slider:Dock(TOP) slider:DockMargin(10,10,10,0)
            slider:SetText(param.name) slider:SetMin(param.min) slider:SetMax(param.max)
            slider:SetDecimals(2) slider:SetValue(state[param.id])
            slider.Label:SetTextColor(t.text)
            slider.OnValueChanged = function(_, val)
                state[param.id] = val
                if ActiveShaderIndex == index then ActiveParams = state end
            end
        end
    end

    list.OnRowSelected = function(lst, idx, pnl)
        ActivateShader(pnl.ShaderIndex)
        BuildShaderControls(pnl.ShaderIndex)
        LogFeatureUsage("shader.select", ShadersConfig[pnl.ShaderIndex].name)
    end

    list:SelectItem(rows[ActiveShaderIndex] or rows[1])
end

-- 15.2 ШРИФТЫ
local function BuildFontPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Настройки шрифтов")
    ULXButton(contentPanel, 20, 60, 200, 30, "Шрифт ESP", function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(300,130) dlg:Center() dlg:SetTitle("Шрифт ESP") dlg:MakePopup()
        local f = vgui.Create("DTextEntry", dlg) f:SetPos(10,30) f:SetSize(280,25) f:SetText(ESP_FontFamily)
        local s = vgui.Create("DNumSlider", dlg) s:SetPos(10,60) s:SetSize(280,30) s:SetText("Размер") s:SetMin(12) s:SetMax(60) s:SetDecimals(0) s:SetValue(ESP_FontSize)
        ULXButton(dlg, 100, 95, 100, 25, "Применить", function() CreateESPFont(f:GetValue(), math.floor(s:GetValue())); dlg:Close() end)
    end)
    ULXButton(contentPanel, 20, 100, 200, 30, "Шрифт Меню", function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(300,130) dlg:Center() dlg:SetTitle("Шрифт Меню") dlg:MakePopup()
        local f = vgui.Create("DTextEntry", dlg) f:SetPos(10,30) f:SetSize(280,25) f:SetText(Menu_FontFamily)
        local s = vgui.Create("DNumSlider", dlg) s:SetPos(10,60) s:SetSize(280,30) s:SetText("Размер") s:SetMin(12) s:SetMax(60) s:SetDecimals(0) s:SetValue(Menu_FontSize)
        ULXButton(dlg, 100, 95, 100, 25, "Применить", function() CreateMenuFont(f:GetValue(), math.floor(s:GetValue())); dlg:Close() end)
    end)
end

-- 15.3 ФИЗГАН
local function BuildPhysgunPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Физган")
    ULXButton(contentPanel, 20, 60, 220, 30, "Выдать физган", function() RunConsoleCommand("gm_giveswep","weapon_physgun") Notify("Физган выдан") end)
    local btnRainbow
    btnRainbow = ULXButton(contentPanel, 20, 100, 220, 30, "Радужный: ВЫКЛ", function()
        Physgun_RainbowEnabled = not Physgun_RainbowEnabled
        btnRainbow.Paint = function(self,w2,h2)
            local th = GetTheme()
            local col = self:IsHovered() and th.btnHover or th.btn
            surface.SetDrawColor(col) surface.DrawRect(0,0,w2,h2)
            draw.SimpleText("Радужный: "..(Physgun_RainbowEnabled and "ВКЛ" or "ВЫКЛ"), "Unisono_ULXBtn", w2/2, h2/2, th.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        Notify(Physgun_RainbowEnabled and "Включён" or "Выключен")
    end)
end

-- 15.4 СКРИПТЫ
local function BuildScriptsPanel(parent)
    local panel = parent or contentPanel
    ClearContent(panel)
    if not IsWhitelistAdmin() then
        ULXLabel(panel, 20, 20, "Нет доступа к настройкам скриптов.", Color(220,70,70))
        return
    end

    ULXLabel(panel, 20, 20, "Клиентские настройки")
    local options = {
        {"Показывать хитбоксы", "gmod_drawhitboxes"},
        {"Режим разработчика", "developer"},
        {"Показать FPS", "cl_showfps"},
        {"Отключить тени", "r_shadows"},
    }
    local y = 60
    for _, opt in ipairs(options) do
        local cv = GetConVar(opt[2])
        ULXLabel(panel, 20, y, opt[1])
        local chk = vgui.Create("DCheckBox", panel)
        chk:SetPos(220, y+2)
        chk:SetChecked(cv and cv:GetBool() or false)
        chk.OnChange = function(self, val)
            LogFeatureUsage("cvar.change", opt[2] .. "=" .. (val and "1" or "0"))
            local ok, err = pcall(function() if cv then cv:SetBool(val) end end)
            if not ok then Notify("Команда заблокирована сервером: "..opt[2], true)
            else Notify(opt[1]..": "..(val and "ВКЛ" or "ВЫКЛ")) end
        end
        y = y + 35
    end
    ULXLabel(panel, 20, y+10, "Примечание: если галочка не сохраняется — сервер блокирует CVAR.", ThemeCol("text"))
end

-- 15.5 ЛОКАЛЬНАЯ КОНСОЛЬ
local function BuildConsolePanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 10, "Локальная консоль (Lua + Клиентские команды)")
    local output = vgui.Create("RichText", contentPanel)
    output:SetPos(20, 35) output:SetSize(560, 300)
    output:SetVerticalScrollbarEnabled(true)
    function output:PerformLayout()
        self:SetFontInternal("Unisono_Mono")
        self:SetBGColor(Color(30, 30, 30, 220))
    end

    local function LogToConsole(col, text)
        if not IsValid(output) then return end
        output:InsertColorChange(col.r, col.g, col.b, col.a or 255)
        output:AppendText(tostring(text) .. "\n")
        if output.GotoTextEnd then output:GotoTextEnd() end
    end

    local function PrintLocalConsoleHelp()
        LogToConsole(Color(0,255,255), "Доступные встроенные команды:")
        LogToConsole(Color(210,210,210), "!stopsound — выполнить stopsound")
        LogToConsole(Color(210,210,210), "!off — выключить скрипт")
        LogToConsole(Color(210,210,210), "!update — обновить скрипт с GitHub")
        LogToConsole(Color(210,210,210), "!version — показать и проверить версию")
        LogToConsole(Color(210,210,210), "!help — показать этот список")
        LogToConsole(Color(210,210,210), "!reloadwhitelist / !wlreload — перезагрузить whitelist")
        if IsWhitelistAdmin() then
            LogToConsole(Color(255,255,0), "!whitelist — открыть управление whitelist")
        end
    end

    LogToConsole(Color(0,255,255), "=== Локальная RichText-консоль " .. SCRIPT_VERSION .. " ===")
    LogToConsole(Color(150,150,150), "Введите Lua-код или клиентскую команду.")
    LogToConsole(Color(150,150,150), "Пример Lua: print(LocalPlayer():Nick())")
    LogToConsole(Color(150,150,150), "Пример Cmd: cl_showfps 1")
    PrintLocalConsoleHelp()

    local mode = "lua"
    local btnMode
    btnMode = ULXButton(contentPanel, 20, 345, 100, 24, "Режим: Lua", function()
        mode = (mode == "lua") and "cmd" or "lua"
        btnMode.Paint = function(self, w2, h2)
            local th = GetTheme()
            local col = self:IsHovered() and th.btnHover or th.btn
            surface.SetDrawColor(col) surface.DrawRect(0,0,w2,h2)
            draw.SimpleText("Режим: "..(mode == "lua" and "Lua" or "Cmd"), "Unisono_ULXBtn", w2/2, h2/2, th.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)

    local input = vgui.Create("DTextEntry", contentPanel)
    input:SetPos(130, 345) input:SetSize(360, 24)
    input:SetPlaceholderText("Введите код...")

    local function ExecuteConsoleInput()
        local cmd = string.Trim(input:GetValue())
        if cmd == "" then return end
        input:SetText("")
        local command = string.lower(cmd)
        LogFeatureUsage("console.execute", string.StartWith(command, "!") and command or mode)

        if command == "!help" then
            PrintLocalConsoleHelp()
            return
        end

        if command == "!version" then
            LogToConsole(Color(100,200,255), "Текущая версия: " .. SCRIPT_VERSION)
            LogToConsole(Color(255,255,0), "Проверка обновлений...")
            CheckForUpdates(function(hasUpdate, remoteVersion, isLatest)
                if hasUpdate then
                    LogToConsole(Color(255,165,0), "Доступно обновление: " .. tostring(remoteVersion))
                    LogToConsole(Color(100,255,100), "Используйте !update для установки.")
                elseif isLatest then
                    LogToConsole(Color(0,255,0), "Установлена последняя версия.")
                else
                    LogToConsole(Color(255,100,100), "Не удалось проверить обновления.")
                end
            end)
            return
        end

        if command == "!whitelist" then
            if not IsWhitelistAdmin() then
                LogToConsole(Color(255,0,0), "У вас нет доступа к этой команде.")
                return
            end
            LogToConsole(Color(0,255,0), "Открываю Admin → Whitelist.")
            if BuildAdminPanel then BuildAdminPanel("whitelist") end
            return
        end

        if command == "!reloadwhitelist" or command == "!wlreload" then
            LogToConsole(Color(255,255,0), "Загрузка whitelist из GitHub и запрос клиенту админа...")
            whitelist_retry_count = 0
            peer_override_active = false
            LoadWhitelist(function(success, source)
                LogToConsole(
                    success and Color(0,255,0) or Color(255,165,0),
                    success and ("Whitelist загружен: " .. tostring(source) .. ".") or "Не удалось загрузить whitelist."
                )
            end, true)
            RequestPeerWhitelist(function(success)
                if success then LogToConsole(Color(0,255,0), "Получена клиентская синхронизация от админа.") end
            end)
            return
        end

        if command == "!update" then
            LogToConsole(Color(255,255,0), "Обновление скрипта с GitHub...")
            PerformScriptUpdate(function(body)
                LogToConsole(Color(0,255,0), "Скрипт скачан. Перезапуск...")
                MultiTool_UnloadSelf("Старая версия выгружена перед обновлением.")
                if IsValid(mainFrame) then mainFrame:Close() end
                RunString(body, "Multitool_Updater", false)
            end, function(err)
                LogToConsole(Color(255,0,0), "Ошибка обновления: " .. tostring(err))
            end)
            return
        end

        if command == "!stopsound" then
            RunConsoleCommand("stopsound")
            LogToConsole(Color(0,255,0), "[OK] Выполнено: stopsound")
            return
        end

        if command == "!off" then
            LogToConsole(Color(255,140,0), "Скрипт будет выключен.")
            MultiTool_UnloadSelf("Скрипт успешно выгружен через !off.")
            if IsValid(mainFrame) then mainFrame:Close() end
            return
        end

        LogToConsole(Color(255,255,0), "> " .. cmd)

        if mode == "lua" then
            local func = CompileString("return " .. cmd, "LocalConsole", false)
            if type(func) == "string" then func = CompileString(cmd, "LocalConsole", false) end
            if type(func) == "function" then
                local originalPrint = print
                local customEnv = setmetatable({
                    print = function(...)
                        local values = {...}
                        local parts = {}
                        for i, value in ipairs(values) do parts[i] = tostring(value) end
                        LogToConsole(Color(210,210,210), table.concat(parts, " "))
                        originalPrint(...)
                    end,
                }, {__index = _G})
                setfenv(func, customEnv)
                local ok, ret = pcall(func)
                if ok then
                    if ret ~= nil then
                        LogToConsole(Color(210,210,210), tostring(ret))
                    else
                        LogToConsole(Color(0,255,0), "[OK]")
                    end
                else
                    LogToConsole(Color(255,50,50), "[ERROR] " .. tostring(ret))
                end
            else
                LogToConsole(Color(255,50,50), "[SYNTAX ERROR] " .. tostring(func))
            end
        else
            local ok, err = pcall(function() LocalPlayer():ConCommand(cmd) end)
            if ok then
                LogToConsole(Color(0,255,0), "[CMD] Отправлено")
            else
                LogToConsole(Color(255,50,50), "[BLOCKED] " .. tostring(err))
            end
        end
    end

    input.OnEnter = ExecuteConsoleInput
    ULXButton(contentPanel, 500, 345, 80, 24, "Выполнить", ExecuteConsoleInput)

    ULXButton(contentPanel, 20, 380, 120, 24, "Очистить", function() output:SetText("") end)
end

-- 15.6 УПРАВЛЕНИЕ WHITELIST
BuildWhitelistAdminPanel = function(parent)
    local panel = parent or contentPanel
    ClearContent(panel)
    if not IsWhitelistAdmin() then
        ULXLabel(panel, 20, 20, "Нет доступа к управлению whitelist.", Color(220,70,70))
        return
    end

    local panelWidth = math.max(panel:GetWide(), 320)
    local panelHeight = math.max(panel:GetTall(), 360)
    local innerWidth = panelWidth - 20
    local listHeight = math.max(150, panelHeight - 210)
    local entryY = 36 + listHeight + 10
    local permissionsY = entryY + 32
    local actionsY = permissionsY + 34
    local hintY = actionsY + 36
    local footerY = hintY + 26
    local gap = 10
    local actionWidth = math.floor((innerWidth - gap * 2) / 3)
    local actionX1 = 10
    local actionX2 = actionX1 + actionWidth + gap
    local actionX3 = actionX2 + actionWidth + gap
    local actionWidth3 = panelWidth - 10 - actionX3

    LoadClientGitHubToken()
    local status = ULXLabel(panel, 12, 10, "Клиентская синхронизация готова.")
    local list = vgui.Create("DListView", panel)
    list:SetPos(10, 36) list:SetSize(innerWidth, listHeight)
    list:AddColumn("SteamID")
    list:AddColumn("Доступные функции")

    local steamEntry = vgui.Create("DTextEntry", panel)
    steamEntry:SetPos(10, entryY) steamEntry:SetSize(math.min(270, innerWidth), 24)
    steamEntry:SetPlaceholderText("STEAM_0:0:123456789")

    local permissionOrder = {"ESP", "NOTES", "STATS", "NOT_WORKING"}
    local permissionLabels = {
        ESP = "ESP",
        NOTES = "3D Заметки",
        STATS = "Статистика",
        NOT_WORKING = "!Не работает!",
    }
    local permissionBoxes = {}
    local permissionWidth = math.floor(innerWidth / #permissionOrder)

    for i, feature in ipairs(permissionOrder) do
        local box = vgui.Create("DCheckBoxLabel", panel)
        box:SetPos(10 + (i-1) * permissionWidth, permissionsY)
        box:SetSize(permissionWidth - 4, 22)
        box:SetText(permissionLabels[feature])
        box:SetTextColor(ThemeCol("text"))
        box:SetChecked(true)
        box:SizeToContents()
        permissionBoxes[feature] = box
    end

    local function SetStatus(text, isError)
        if not IsValid(status) then return end
        status:SetText(text)
        status:SetTextColor(isError and Color(220,70,70) or Color(80,220,130))
        status:SizeToContents()
    end

    local function PermissionSummary(perms)
        local enabled = {}
        for _, feature in ipairs(permissionOrder) do
            if perms[feature] == true then table.insert(enabled, permissionLabels[feature]) end
        end
        return #enabled > 0 and table.concat(enabled, ", ") or "без функций"
    end

    local function RefreshWhitelist(data)
        if not IsValid(list) then return end
        list:Clear()
        local ids = {}
        for steamID in pairs(data or {}) do table.insert(ids, steamID) end
        table.sort(ids)
        for _, steamID in ipairs(ids) do
            local perms = data[steamID]
            local line = list:AddLine(steamID, PermissionSummary(perms))
            line.SteamID = steamID
            line.Permissions = perms
        end
    end

    list.OnRowSelected = function(_, _, line)
        if not IsValid(line) then return end
        steamEntry:SetText(line.SteamID or "")
        for _, feature in ipairs(permissionOrder) do
            permissionBoxes[feature]:SetChecked(line.Permissions and line.Permissions[feature] == true)
        end
    end

    ULXButton(panel, actionX1, actionsY, actionWidth, 26, "Добавить / обновить", function()
        local steamID = string.Trim(steamEntry:GetValue())
        if not IsValidSteamID(steamID) then
            SetStatus("Некорректный SteamID.", true)
            return
        end

        local permissions = {}
        for _, feature in ipairs(permissionOrder) do
            permissions[feature] = permissionBoxes[feature]:GetChecked() == true
        end

        SetStatus("Отправка клиентам...")
        MutateClientWhitelist("upsert", steamID, permissions, function(success, message)
            SetStatus(message, not success)
        end)
    end)

    ULXButton(panel, actionX2, actionsY, actionWidth, 26, "Удалить", function()
        local steamID = string.Trim(steamEntry:GetValue())
        if not IsValidSteamID(steamID) then
            SetStatus("Выберите строку или введите SteamID.", true)
            return
        end
        SetStatus("Удаление и отправка клиентам...")
        MutateClientWhitelist("remove", steamID, {}, function(success, message)
            SetStatus(message, not success)
            if not WhitelistData[steamID] then steamEntry:SetText("") end
        end)
    end)

    ULXButton(panel, actionX3, actionsY, actionWidth3, 26, "Перезагрузить", function()
        SetStatus("GitHub + запрос клиенту админа...")
        peer_override_active = false
        LoadWhitelist(function(success, source)
            if success then
                RefreshWhitelist(WhitelistData)
                SetStatus("Whitelist загружен: " .. tostring(source) .. ".")
            else
                SetStatus("GitHub недоступен; ожидается peer-ответ.", true)
            end
        end, true)
        RequestPeerWhitelist(function(success, data)
            if success then
                RefreshWhitelist(data)
                SetStatus("Получен whitelist клиента админа.")
            end
        end)
    end)

    local hint = ULXLabel(panel, 10, hintY, "Изменения сразу идут клиентам; GitHub сохраняется при настроенном token.")
    hint:SetTextColor(ThemeCol("text"))

    ULXButton(panel, actionX1, footerY, actionWidth, 24, HasClientGitHubToken() and "GitHub token: ЕСТЬ" or "Настроить GitHub token", function()
        local dialog = vgui.Create("DFrame")
        dialog:SetSize(440, 160)
        dialog:Center()
        dialog:SetTitle("GitHub token — сохраняется в GMod data")
        dialog:MakePopup()

        local tokenStatus = ULXLabel(
            dialog,
            12,
            34,
            HasClientGitHubToken()
                and ("Token восстановлен: " .. MaskGitHubToken(github_token))
                or "Вставьте token с правом Gists: read/write."
        )
        local tokenEntry = vgui.Create("DTextEntry", dialog)
        tokenEntry:SetPos(12, 58)
        tokenEntry:SetSize(416, 24)
        if isfunction(tokenEntry.SetTextHidden) then
            tokenEntry:SetTextHidden(true)
        end
        tokenEntry:SetPlaceholderText(
            HasClientGitHubToken()
                and ("Сохранён " .. MaskGitHubToken(github_token) .. "; новый ввод заменит его")
                or "github_pat_... или ghp_..."
        )

        ULXButton(dialog, 12, 94, 128, 26, "Сохранить", function()
            local success, message = SetClientGitHubToken(tokenEntry:GetValue())
            tokenStatus:SetText(message)
            tokenStatus:SetTextColor(success and Color(80,220,130) or Color(220,70,70))
            tokenStatus:SizeToContents()
            if success then
                timer.Simple(0.6, function()
                    if IsValid(dialog) then dialog:Close() end
                    if IsValid(panel) and IsValid(list) then BuildWhitelistAdminPanel(panel) end
                end)
            end
        end)
        ULXButton(dialog, 150, 94, 128, 26, "Удалить token", function()
            local success, message = SetClientGitHubToken("")
            tokenStatus:SetText(message)
            tokenStatus:SetTextColor(success and Color(80,220,130) or Color(220,70,70))
            tokenStatus:SizeToContents()
            if success and IsValid(panel) and IsValid(list) then BuildWhitelistAdminPanel(panel) end
        end)
        ULXButton(dialog, 288, 94, 140, 26, "Закрыть", function() dialog:Close() end)
    end)

    ULXButton(panel, actionX2, footerY, actionWidth, 24, "Синхр. всем клиентам", function()
        local success, message = BroadcastWhitelistSnapshot()
        SetStatus(success and "Снимок whitelist отправляется клиентам." or tostring(message), not success)
    end)

    ULXButton(panel, actionX3, footerY, actionWidth3, 24, "Логи → GitHub", function()
        if not HasClientGitHubToken() then
            SetStatus("Сначала настройте GitHub token.", true)
            return
        end
        SyncAdminLogsToGist()
        SetStatus("Логи поставлены в очередь GitHub.")
    end)

    hook.Add("UnisonoMT_WhitelistUpdated", "UnisonoMT_WhitelistPanel", function(data)
        if not IsValid(panel) then
            hook.Remove("UnisonoMT_WhitelistUpdated", "UnisonoMT_WhitelistPanel")
            return
        end
        RefreshWhitelist(data)
    end)

    RefreshWhitelist(WhitelistData)
    SetStatus(
        HasClientGitHubToken()
            and "Peer-синхронизация + запись GitHub готовы."
            or "Peer-синхронизация готова; GitHub token не настроен.",
        false
    )
end

-- 15.7 Q-МЕНЮ
local function BuildQMenuPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Цвет Q-меню")
    local mixer = vgui.Create("DColorMixer", contentPanel)
    mixer:SetPos(20,50) mixer:SetSize(300,180)
    mixer:SetPalette(true) mixer:SetAlphaBar(false) mixer:SetWangs(true)
    mixer:SetColor(QMenu_CustomColor or Color(100,150,200))

    ULXButton(contentPanel, 20, 240, 140, 26, "Применить цвет", function()
        QMenu_CustomColor = mixer:GetColor(); QMenu_RainbowEnabled = false; ApplyQMenuColor(QMenu_CustomColor, false); Notify("Цвет применён") end)
    ULXButton(contentPanel, 170, 240, 140, 26, "Радужный", function()
        QMenu_RainbowEnabled = true; ApplyQMenuColor(nil, true); Notify("Радужный режим") end)
    ULXButton(contentPanel, 20, 275, 290, 26, "Сброс", function()
        QMenu_RainbowEnabled = false; QMenu_CustomColor = nil
        if IsValid(g_SpawnMenu) and g_SpawnMenu.OriginalPaint then g_SpawnMenu.Paint = g_SpawnMenu.OriginalPaint end
        Notify("Сброшено") end)
end

local function SendSafeChatCommand(cmd)
    local safeTimer = GenSafeHook()
    LogFeatureUsage("chat.command", cmd)
    timer.Create(safeTimer, 0.1, 1, function()
        RunConsoleCommand("say", cmd)
    end)
end

-- 15.8 ЧАТ
local function BuildChatPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Настройки чата")
    ULXLabel(contentPanel, 20, 60, "Размер текста:")
    local s1 = vgui.Create("DNumSlider", contentPanel)
    s1:SetPos(20,80) s1:SetSize(400,30) s1:SetText("") s1:SetMin(12) s1:SetMax(24) s1:SetDecimals(0) s1:SetValue(18)
    s1.OnValueChanged = function(_,v) surface.CreateFont("Unisono_ChatFont", {font="Roboto", size=v, weight=400, antialias=true}) end

    ULXLabel(contentPanel, 20, 130, "Прозрачность фона:")
    local s2 = vgui.Create("DNumSlider", contentPanel)
    s2:SetPos(20,150) s2:SetSize(400,30) s2:SetText("") s2:SetMin(0) s2:SetMax(255) s2:SetDecimals(0) s2:SetValue(255)

    ULXLabel(contentPanel, 20, 205, "Встроенные чат-команды")
    ULXButton(contentPanel, 20, 235, 200, 30, "!admin", function()
        SendSafeChatCommand("!admin")
    end)
    ULXButton(contentPanel, 20, 275, 200, 30, "!unadmin", function()
        SendSafeChatCommand("!unadmin")
    end)
    ULXButton(contentPanel, 20, 315, 200, 30, "!give [ПЕЧЕНЬКА]", function()
        SendSafeChatCommand("!give @ weapon_dalgonabox")
    end)
end

-- 15.9 3D ЗАМЕТКИ
local function BuildNotesPanel()
    ClearContent()
    if not HasAccess(LocalPlayer():SteamID(), "NOTES") then
        ULXLabel(contentPanel, 20, 20, "Нет доступа к 3D Заметкам!", Color(200,50,50)) return
    end

    local addPanel = vgui.Create("DPanel", contentPanel)
    addPanel:SetPos(10,10) addPanel:SetSize(560,130)
    addPanel.Paint = function(s,w,h)
        local t = GetTheme()
        surface.SetDrawColor(t.panel) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(t.border) surface.DrawOutlinedRect(0,0,w,h)
    end

    ULXLabel(addPanel, 8, 5, "+ Новая заметка")
    ULXLabel(addPanel, 8, 26, "Текст:")
    local entryText = vgui.Create("DTextEntry", addPanel) entryText:SetPos(70,24) entryText:SetSize(480,22) entryText:SetPlaceholderText("Введите текст заметки...")

    ULXLabel(addPanel, 8, 52, "Дальность:")
    local sliderDist = vgui.Create("DNumSlider", addPanel)
    sliderDist:SetPos(80,48) sliderDist:SetSize(470,22)
    sliderDist:SetText("") sliderDist:SetMin(100) sliderDist:SetMax(5000)
    sliderDist:SetDecimals(0) sliderDist:SetValue(2000)

    ULXLabel(addPanel, 8, 78, "Цвет:")
    local selectedColor = Color(0,220,255)
    local colorPreview = vgui.Create("DButton", addPanel)
    colorPreview:SetPos(70,76) colorPreview:SetSize(50,20) colorPreview:SetText("")
    colorPreview.Paint = function(s,w,h)
        surface.SetDrawColor(selectedColor.r,selectedColor.g,selectedColor.b,255)
        surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(180,180,180) surface.DrawOutlinedRect(0,0,w,h)
    end
    colorPreview.DoClick = function()
        local picker = vgui.Create("DFrame") picker:SetSize(260,220) picker:Center()
        picker:SetTitle("Цвет заметки") picker:MakePopup()
        local mixer = vgui.Create("DColorMixer", picker)
        mixer:SetPos(10,30) mixer:SetSize(240,140) mixer:SetColor(selectedColor)
        ULXButton(picker, 80, 180, 100, 24, "OK", function() selectedColor = mixer:GetColor() picker:Close() end)
    end

    local presetColors = {Color(0,220,255),Color(255,80,80),Color(80,255,80),Color(255,220,0),Color(220,80,255),Color(255,160,0)}
    for i, pc in ipairs(presetColors) do
        local pb = vgui.Create("DButton", addPanel)
        pb:SetPos(125+(i-1)*26,76) pb:SetSize(20,20) pb:SetText("")
        local pcLocal = pc
        pb.Paint = function(s,w,h)
            surface.SetDrawColor(pcLocal.r,pcLocal.g,pcLocal.b,255) surface.DrawRect(0,0,w,h)
            if selectedColor == pcLocal then surface.SetDrawColor(50,50,50) surface.DrawOutlinedRect(0,0,w,h) end
        end
        pb.DoClick = function() selectedColor = pcLocal end
    end

    local scroll = vgui.Create("DScrollPanel", contentPanel)
    scroll:SetPos(10,150) scroll:SetSize(560,340)
    scroll.Paint = function(s,w,h) surface.SetDrawColor(GetTheme().content) surface.DrawRect(0,0,w,h) end

    local function RefreshNotesList()
        scroll:Clear()
        if #MapNotes == 0 then
            local lbl = vgui.Create("DLabel", scroll)
            lbl:SetPos(0,10) lbl:SetSize(560,20) lbl:SetText("Нет заметок. Добавьте первую!")
            lbl:SetTextColor(ThemeCol("text")) lbl:SetContentAlignment(5)
            return
        end
        for i, note in ipairs(MapNotes) do
            local row = vgui.Create("DPanel", scroll)
            row:SetPos(2,(i-1)*50+2) row:SetSize(546,46)
            local noteLocal = note; local iLocal = i
            row.Paint = function(s,w,h)
                local c = noteLocal.color
                draw.RoundedBox(4,0,0,w,h,Color(c.r*0.15,c.g*0.15,c.b*0.15,200))
                surface.SetDrawColor(c.r,c.g,c.b,120) surface.DrawOutlinedRect(0,0,w,h)
                surface.SetDrawColor(c.r,c.g,c.b,220) surface.DrawRect(0,0,4,h)
            end
            local lblNum = vgui.Create("DLabel", row)
            lblNum:SetPos(8,12) lblNum:SetSize(20,20) lblNum:SetText("#"..iLocal)
            lblNum:SetTextColor(Color(noteLocal.color.r,noteLocal.color.g,noteLocal.color.b,255))
            local lblText = vgui.Create("DLabel", row)
            lblText:SetPos(32,4) lblText:SetSize(200,18) lblText:SetText(noteLocal.text)
            lblText:SetTextColor(Color(255,255,255))
            local posStr = string.format("X:%.0f Y:%.0f Z:%.0f", noteLocal.pos.x, noteLocal.pos.y, noteLocal.pos.z)
            local lblPos = vgui.Create("DLabel", row)
            lblPos:SetPos(32,24) lblPos:SetSize(200,16) lblPos:SetText(posStr)
            lblPos:SetTextColor(Color(180,180,180))
            local lblDist = vgui.Create("DLabel", row)
            lblDist:SetPos(240,4) lblDist:SetSize(100,16) lblDist:SetText("Дальн.: "..(noteLocal.maxDist or 2000))
            lblDist:SetTextColor(Color(150,200,255))
            local lp = LocalPlayer()
            local dtm = IsValid(lp) and math.floor(lp:GetPos():Distance(noteLocal.pos)) or 0
            local lblToMe = vgui.Create("DLabel", row)
            lblToMe:SetPos(240,24) lblToMe:SetSize(100,16) lblToMe:SetText("До вас: "..dtm.." юн.")
            lblToMe:SetTextColor(Color(200,255,200))

            ULXButton(row, 350, 4, 50, 18, "Коп.", function()
                SetClipboardText(string.format("%.0f %.0f %.0f", noteLocal.pos.x, noteLocal.pos.y, noteLocal.pos.z))
                Notify("Координаты скопированы") end)
            ULXButton(row, 405, 4, 50, 18, "Удал.", function()
                table.remove(MapNotes, iLocal) RefreshNotesList() Notify("Заметка удалена") end)
            ULXButton(row, 350, 24, 105, 18, "Переимен.", function()
                local dlg = vgui.Create("DFrame") dlg:SetSize(300,90) dlg:Center() dlg:SetTitle("Редактировать") dlg:MakePopup()
                local e = vgui.Create("DTextEntry", dlg) e:SetPos(10,30) e:SetSize(280,22) e:SetText(noteLocal.text)
                ULXButton(dlg, 90, 60, 120, 22, "Сохранить", function()
                    local nt = string.Trim(e:GetValue())
                    if nt ~= "" then noteLocal.text = nt; RefreshNotesList(); dlg:Close() end end)
            end)
        end
    end

    ULXButton(addPanel, 8, 104, 240, 22, "Поставить здесь", function()
        local text = string.Trim(entryText:GetValue())
        if text == "" then Notify("Введите текст!", true) return end
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        table.insert(MapNotes, { id=MapNotes_NextID, pos=lp:GetPos()+Vector(0,0,30), text=text,
            color=Color(selectedColor.r,selectedColor.g,selectedColor.b), maxDist=math.floor(sliderDist:GetValue()) })
        MapNotes_NextID = MapNotes_NextID + 1
        entryText:SetText("") RefreshNotesList()
        Notify("Заметка добавлена")
    end)
    ULXButton(addPanel, 258, 104, 240, 22, "Поставить по прицелу", function()
        local text = string.Trim(entryText:GetValue())
        if text == "" then Notify("Введите текст!", true) return end
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local tr = util.TraceLine({ start=lp:EyePos(), endpos=lp:EyePos()+lp:GetAimVector()*5000, filter=lp, mask=MASK_SOLID_BRUSHONLY })
        local hitPos = tr.Hit and tr.HitPos or (lp:EyePos()+lp:GetAimVector()*500)
        table.insert(MapNotes, { id=MapNotes_NextID, pos=hitPos+Vector(0,0,10), text=text,
            color=Color(selectedColor.r,selectedColor.g,selectedColor.b), maxDist=math.floor(sliderDist:GetValue()) })
        MapNotes_NextID = MapNotes_NextID + 1
        entryText:SetText("") RefreshNotesList()
        Notify("Заметка по прицелу добавлена")
    end)

    local btnClearAll = ULXButton(contentPanel, 10, 500, 150, 24, "Удалить все", function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(300,100) dlg:Center() dlg:SetTitle("Подтверждение") dlg:MakePopup()
        ULXLabel(dlg, 20, 30, "Удалить ВСЕ заметки?")
        ULXButton(dlg, 40, 60, 100, 24, "Да", function() MapNotes = {} RefreshNotesList() dlg:Close() Notify("Все заметки удалены") end)
        ULXButton(dlg, 160, 60, 100, 24, "Отмена", function() dlg:Close() end)
    end)

    RefreshNotesList()
end

-- 15.9 СТАТИСТИКА
local function BuildStatsPanel()
    ClearContent()
    if not HasAccess(LocalPlayer():SteamID(), "STATS") then
        ULXLabel(contentPanel, 20, 20, "Нет доступа к статистике!", Color(200,50,50)) return
    end

    local scroll = vgui.Create("DScrollPanel", contentPanel)
    scroll:Dock(FILL) scroll:DockMargin(10,10,10,50)
    scroll.Paint = function(s,w,h)
        local t = GetTheme()
        surface.SetDrawColor(t.content) surface.DrawRect(0,0,w,h)
    end

    local function UpdateStats()
        scroll:Clear()
        local t = GetTheme()
        local tm = CurTime() - SessionStats.sessionStart
        local data = {
            {"Время сессии:", FormatTime(tm)},
            {"Убийств:", tostring(SessionStats.kills)},
                        {"Смертей:", tostring(SessionStats.deaths)},
            {"K/D:", SessionStats.deaths > 0 and string.format("%.2f", SessionStats.kills/SessionStats.deaths) or tostring(SessionStats.kills)},
            {"Получено урона:", string.format("%.0f", SessionStats.damageTaken)},
            {"Нанесено урона:", string.format("%.0f", SessionStats.damageDealt)},
            {"Пройдено:", string.format("%.0f м", SessionStats.distanceTraveled/52.5)},
            {"Прыжков:", tostring(SessionStats.jumps)},
        }
        for _, row in ipairs(data) do
            local p = vgui.Create("DPanel", scroll)
            p:Dock(TOP) p:DockMargin(2,1,2,1) p:SetHeight(26)
            p.Paint = function(s,w,h)
                surface.SetDrawColor(t.panel) surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(t.border) surface.DrawOutlinedRect(0,0,w,h)
            end
            local l = vgui.Create("DLabel", p)
            l:SetPos(10,3) l:SetSize(200,20) l:SetText(row[1])
            l:SetTextColor(t.text)
            local v = vgui.Create("DLabel", p)
            v:SetPos(220,3) v:SetSize(200,20) v:SetText(row[2])
            v:SetTextColor(t.accent)
        end
    end
    UpdateStats()

    local bp = vgui.Create("DPanel", contentPanel)
    bp:Dock(BOTTOM) bp:SetHeight(40) bp.Paint = function() end
    ULXButton(bp, 10, 5, 100, 28, "Сброс", function()
        SessionStats = { sessionStart=CurTime(), kills=0, deaths=0, damageTaken=0, damageDealt=0, distanceTraveled=0, jumps=0, lastPos=LocalPlayer():GetPos(), onGround=true }
        UpdateStats() Notify("Статистика сброшена") end)
    ULXButton(bp, 120, 5, 100, 28, "Обновить", UpdateStats)

    timer.Create("StatsUpdate_ULX", 1, 0, function()
        if IsValid(contentPanel) and contentPanel:IsVisible() then UpdateStats() else timer.Remove("StatsUpdate_ULX") end
    end)
end

-- 15.10 OOPS
local function BuildOopsPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Сброс настроек")
    local y = 60
    local function AddReset(text, fn)
        ULXButton(contentPanel, 20, y, 300, 28, text, function()
            local dlg = vgui.Create("DFrame") dlg:SetSize(320,100) dlg:Center()
            dlg:SetTitle("Подтверждение") dlg:MakePopup()
            ULXLabel(dlg, 20, 30, "Сбросить "..text.."?")
            ULXButton(dlg, 40, 60, 100, 24, "Да", function() fn() dlg:Close() Notify(text.." сброшены") end)
            ULXButton(dlg, 180, 60, 100, 24, "Отмена", function() dlg:Close() end)
        end)
        y = y + 38
    end
    AddReset("Все настройки", function()
        ESP_Enabled = false; ESP_MaxDistance = 1100
        ShaderStates = {}; ActiveShaderIndex = 1; ActivateShader(1)
        Physgun_RainbowEnabled = false; QMenu_RainbowEnabled = false; QMenu_CustomColor = nil
        MapNotes = {}; MapNotes_NextID = 1
        SessionStats = { sessionStart=CurTime(), kills=0, deaths=0, damageTaken=0, damageDealt=0, distanceTraveled=0, jumps=0, lastPos=Vector(0,0,0), onGround=true }
        if IsValid(g_SpawnMenu) and g_SpawnMenu.OriginalPaint then g_SpawnMenu.Paint = g_SpawnMenu.OriginalPaint end
    end)
    AddReset("Только ESP", function() ESP_Enabled = false; ESP_MaxDistance = 1100 end)
    AddReset("Только шейдеры", function() ShaderStates = {}; ActiveShaderIndex = 1; ActivateShader(1) end)
    AddReset("Только заметки", function() MapNotes = {}; MapNotes_NextID = 1 end)
end

-- 15.11 ТЕМЫ
local function BuildThemesPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Настройка темы")
    local themes = {
        {key="dark", name="Космос (Dark)"},
        {key="light", name="Светлая"},
        {key="transparent", name="Прозрачная"},
        {key="purple", name="Фиолетовая"},
        {key="green", name="Матрица"},
        {key="hacker", name="Хакер"},
    }
    local y = 60
    for _, theme in ipairs(themes) do
        ULXButton(contentPanel, 20, y, 300, 28, theme.name, function()
            CurrentULXTheme = theme.key
            if IsValid(mainFrame) then mainFrame:InvalidateLayout(true) end
            Notify("Тема '"..theme.name.."' применена к меню")
        end)
        y = y + 34
    end
    ULXLabel(contentPanel, 20, y+10, "Тема применяется ко всему интерфейсу мульти-тула.", ThemeCol("text"))
end

-- 15.12 ESP (!Не работает!)
local function BuildESPPanel()
    ClearContent()
    if not HasAccess(LocalPlayer():SteamID(), "NOT_WORKING") then
        ULXLabel(contentPanel, 20, 20, "Нет доступа к '!Не работает!'!", Color(200,50,50)) return
    end
    ULXLabel(contentPanel, 20, 20, "ESP / Wallhack")
    local btnToggle = ULXButton(contentPanel, 20, 60, 200, 28, "Вкл / Выкл ESP", function()
        ESP_Enabled = not ESP_Enabled
        Notify(ESP_Enabled and "ESP Включён" or "ESP Выключен")
    end)
    ULXButton(contentPanel, 20, 100, 200, 28, "Дальность: "..ESP_MaxDistance, function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(250,80) dlg:Center() dlg:SetTitle("Дальность ESP") dlg:MakePopup()
        local e = vgui.Create("DTextEntry", dlg) e:SetPos(10,35) e:SetSize(150,22) e:SetText(tostring(ESP_MaxDistance)) e:SetNumeric(true)
        ULXButton(dlg, 170, 35, 60, 22, "OK", function()
            local v = tonumber(e:GetValue())
            if v and v >= 200 then ESP_MaxDistance = v dlg:Close() Notify("Дальность: "..v) end end)
    end)
    ULXButton(contentPanel, 20, 140, 200, 28, "Настройка цветов", function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(280,400) dlg:Center() dlg:SetTitle("Цвета рангов") dlg:MakePopup()
        local sc = vgui.Create("DScrollPanel", dlg) sc:SetPos(5,30) sc:SetSize(270,320)
        local roles = {}
        for k,v in pairs(ESP_RoleColors) do if type(v) ~= "string" then table.insert(roles,k) end end
        table.sort(roles)
        for i, role in ipairs(roles) do
            local row = vgui.Create("DButton", sc) row:SetText("") row:SetPos(0,(i-1)*28) row:SetSize(270,26)
            row.Paint = function(s,w,h)
                local c = ESP_RoleColors[role]
                surface.SetDrawColor(c.r,c.g,c.b,255) surface.DrawRect(1,1,12,h-2)
                draw.SimpleText(role, "Unisono_ULXBtn", 18, h/2, Color(50,50,50), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            row.DoClick = function()
                local p = vgui.Create("DFrame") p:SetSize(260,220) p:Center() p:SetTitle("Цвет: "..role) p:MakePopup()
                local m = vgui.Create("DColorMixer", p) m:SetPos(10,30) m:SetSize(240,140) m:SetColor(ESP_RoleColors[role])
                ULXButton(p, 80, 180, 100, 24, "OK", function() ESP_RoleColors[role] = m:GetColor() p:Close() end)
            end
        end
    end)
    ULXButton(contentPanel, 20, 180, 200, 28, "Редактор бокса", function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(350,220) dlg:Center() dlg:SetTitle("Редактор бокса ESP") dlg:MakePopup()
        local yOff = 30
        for _, elem in ipairs({"Nick","HP","Armor","Rank"}) do
            ULXLabel(dlg, 20, yOff, elem..":")
            local combo = vgui.Create("DComboBox", dlg)
            combo:SetPos(120,yOff) combo:SetSize(150,22)
            combo:SetValue(ESP_Layout[elem].side)
            combo:AddChoice("Слева","left") combo:AddChoice("Справа","right")
            combo:AddChoice("Сверху","top") combo:AddChoice("Снизу","bottom")
            combo:AddChoice("Отключено","none")
            combo.OnSelect = function(p,idx,val,data)
                ESP_Layout[elem].side = data
                ESP_Layout[elem].enabled = (data ~= "none")
            end
            yOff = yOff + 40
        end
    end)
end

-- 15.13 ИССЛЕДОВАТЕЛЬ СЕРВЕРА
local function BuildServerExplorerPanel(parent)
    local panel = parent or contentPanel
    ClearContent(panel)
    if not IsWhitelistAdmin() then
        ULXLabel(panel, 20, 20, "Нет доступа к Исследователю.", Color(220,70,70))
        return
    end

    local panelWidth = math.max(panel:GetWide(), 360)
    local panelHeight = math.max(panel:GetTall(), 300)
    local outputWidth = panelWidth - 40
    local inputY = panelHeight - 64
    local footerY = panelHeight - 34
    local outputHeight = math.max(180, inputY - 45)
    local inputWidth = math.max(180, math.floor(outputWidth * 0.5))
    local searchX = 20 + inputWidth + 10
    local scanX = searchX + 100
    local scanWidth = math.max(120, panelWidth - scanX - 20)

    ULXLabel(panel, 20, 10, "Исследователь сервера — поиск функций, хуков и оружия")

    local output = vgui.Create("RichText", panel)
    output:SetPos(20, 35) output:SetSize(outputWidth, outputHeight)
    output:SetVerticalScrollbarEnabled(true)
    function output:PerformLayout()
        self:SetFontInternal("Unisono_Mono")
        self:SetBGColor(Color(30, 30, 30, 220))
    end

    local function AppendExplorer(text, color)
        if not IsValid(output) then return end
        local col = color or Color(210, 210, 210)
        output:InsertColorChange(col.r, col.g, col.b, col.a or 255)
        output:AppendText(tostring(text or ""))
        if output.GotoTextEnd then output:GotoTextEnd() end
    end

    AppendExplorer("[Исследователь сервера v1.0.0]\n", Color(0, 220, 255))
    AppendExplorer("Введите ключевое слово для поиска.\n")
    AppendExplorer("Примеры: physgun, color, rainbow, SetColor, Think, Move, Deploy, Holster\n\n", Color(160, 160, 160))

    local input = vgui.Create("DTextEntry", panel)
    input:SetPos(20, inputY) input:SetSize(inputWidth, 22)
    input:SetPlaceholderText("Ключевое слово...")

    local function ScanAndPrint(keyword)
        keyword = string.lower(keyword or "")
        if keyword == "" then return "Введите ключевое слово!\n" end
        local results = {}
        local function add(cat, name, info)
            table.insert(results, string.format("[%s] %s | %s", cat, name, info or ""))
        end

        -- 1. Глобальные функции _G
        for k, v in pairs(_G) do
            if type(v) == "function" and string.find(string.lower(tostring(k)), keyword, 1, true) then
                add("GLOBAL", tostring(k), "function")
            end
        end

        -- 2. Хуки
        local hookTable = hook.GetTable()
        for event, hooks in pairs(hookTable) do
            if string.find(string.lower(event), keyword, 1, true) then
                for name, func in pairs(hooks) do
                    add("HOOK", event.." -> "..tostring(name), type(func))
                end
            else
                for name, func in pairs(hooks) do
                    if string.find(string.lower(tostring(name)), keyword, 1, true) then
                        add("HOOK", event.." -> "..tostring(name), type(func))
                    end
                end
            end
        end

        -- 3. Метатаблицы
        local metas = {Entity = FindMetaTable("Entity"), Weapon = FindMetaTable("Weapon"), Player = FindMetaTable("Player")}
        for metaName, meta in pairs(metas) do
            if meta then
                for k, v in pairs(meta) do
                    if type(v) == "function" and string.find(string.lower(tostring(k)), keyword, 1, true) then
                        add("META:"..metaName, tostring(k), "function")
                    end
                end
            end
        end

        -- 4. Оружие (особенно физган)
        local weps = weapons.GetList()
        for _, wep in ipairs(weps) do
            if wep.ClassName and string.find(string.lower(wep.ClassName), keyword, 1, true) then
                add("WEAPON", wep.ClassName, wep.PrintName or "")
                if wep.ClassName == "weapon_physgun" then
                    for k, v in pairs(wep) do
                        if type(v) == "function" then
                            add("  PHYSGUN_FN", tostring(k), "function")
                        end
                    end
                end
            end
        end

        -- 5. Таймеры
        for k, v in pairs(timer.GetTable() or {}) do
            if string.find(string.lower(tostring(k)), keyword, 1, true) then
                add("TIMER", tostring(k), "")
            end
        end

        if #results == 0 then return "Ничего не найдено по запросу '"..keyword.."'\n" end
        table.sort(results)
        return "=== Найдено "..#results.." результатов ===\n"..table.concat(results, "\n").."\n"
    end

    local function RunExplorerSearch()
        AppendExplorer(ScanAndPrint(input:GetValue()), Color(210, 230, 255))
    end

    input.OnEnter = RunExplorerSearch
    ULXButton(panel, searchX, inputY, 90, 22, "Поиск", RunExplorerSearch)

    ULXButton(panel, scanX, inputY, scanWidth, 22, "Сканировать физган", function()
        local txt = "\n=== СКАНИРОВАНИЕ ФИЗГАНА ===\n"
        local pg = weapons.Get("weapon_physgun")
        if not pg then
            txt = txt .. "weapon_physgun не найден в weapons.Get!\n"
        else
            txt = txt .. "ClassName: "..tostring(pg.ClassName).."\n"
            txt = txt .. "PrintName: "..tostring(pg.PrintName or "N/A").."\n"
            txt = txt .. "Base: "..tostring(pg.Base or "N/A").."\n\n"
            txt = txt .. "=== Функции физгана ===\n"
            local funcs = {}
            for k, v in pairs(pg) do
                if type(v) == "function" then table.insert(funcs, tostring(k)) end
            end
            table.sort(funcs)
            for _, fn in ipairs(funcs) do
                txt = txt .. "  function: "..fn.."\n"
            end
            txt = txt .. "\n=== Все поля физгана ===\n"
            local all = {}
            for k, v in pairs(pg) do table.insert(all, tostring(k).." ("..type(v)..")") end
            table.sort(all)
            for _, line in ipairs(all) do
                txt = txt .. "  "..line.."\n"
            end
        end
        txt = txt .. "\n=== Хуки с 'phys' ===\n"
        local ht = hook.GetTable()
        for event, hooks in pairs(ht) do
            for name, func in pairs(hooks) do
                local n = string.lower(tostring(name))
                local e = string.lower(tostring(event))
                if string.find(n, "phys", 1, true) or string.find(e, "phys", 1, true) then
                    txt = txt .. "  "..event.." -> "..tostring(name).." ("..type(func)..")\n"
                end
            end
        end
        AppendExplorer(txt, Color(255, 220, 120))
    end)

    ULXButton(panel, 20, footerY, 120, 22, "Очистить", function() output:SetText("") end)
    ULXButton(panel, 150, footerY, 120, 22, "Список хуков", function()
        local txt = "\n=== ВСЕ ХУКИ ===\n"
        local ht = hook.GetTable()
        local events = {}
        for event, _ in pairs(ht) do table.insert(events, event) end
        table.sort(events)
        for _, event in ipairs(events) do
            txt = txt .. "\n["..event.."]\n"
            local names = {}
            for name, _ in pairs(ht[event]) do table.insert(names, tostring(name)) end
            table.sort(names)
            for _, name in ipairs(names) do
                txt = txt .. "  "..name.."\n"
            end
        end
        AppendExplorer(txt, Color(180, 255, 180))
    end)
end

-- 15.14 ADMIN
BuildAdminPanel = function(initialSection)
    ClearContent()
    if not IsWhitelistAdmin() then
        ULXLabel(contentPanel, 20, 20, "Вкладка Admin доступна только указанному админу.", Color(220,70,70))
        return
    end

    hook.Remove("UnisonoMT_WhitelistUpdated", "UnisonoMT_WhitelistPanel")

    local tabBar = vgui.Create("DPanel", contentPanel)
    tabBar:SetPos(10, 10)
    tabBar:SetSize(556, 30)
    tabBar.Paint = function(_, w, h)
        local t = GetTheme()
        surface.SetDrawColor(t.panel)
        surface.DrawRect(0, 0, w, h)
    end

    local adminContent = vgui.Create("DPanel", contentPanel)
    adminContent:SetPos(10, 48)
    adminContent:SetSize(556, 430)
    adminContent.Paint = function(_, w, h)
        local t = GetTheme()
        surface.SetDrawColor(t.content)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(t.border)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    local activeSection = nil
    local tabButtons = {}
    local ShowSection = nil

    local function BuildWhitelistCommandPanel()
        ClearContent(adminContent)
        if not IsWhitelistAdmin() then
            ULXLabel(adminContent, 20, 20, "Нет доступа к команде !whitelist.", Color(220,70,70))
            return
        end

        ULXLabel(adminContent, 20, 20, "Админская команда !whitelist")
        local description = vgui.Create("DLabel", adminContent)
        description:SetPos(20, 55)
        description:SetSize(510, 70)
        description:SetWrap(true)
        description:SetText(
            "Команда открывает внутриигровое управление whitelist. " ..
            "Она работает только у SteamID, указанного в ADMIN_STEAMID, " ..
            "и перенаправляет сюда: Admin → Whitelist."
        )
        description:SetTextColor(ThemeCol("text"))

        ULXButton(adminContent, 20, 140, 220, 30, "Выполнить !whitelist", function()
            if not IsWhitelistAdmin() then
                Notify("Нет доступа к !whitelist.", true)
                return
            end
            LogFeatureUsage("admin.command", "!whitelist")
            ShowSection("whitelist")
        end)
    end

    ShowSection = function(section)
        if not IsValid(adminContent) then return end
        if not IsWhitelistAdmin() then
            ClearContent(adminContent)
            ULXLabel(adminContent, 20, 20, "Доступ Admin потерян.", Color(220,70,70))
            return
        end

        hook.Remove("UnisonoMT_WhitelistUpdated", "UnisonoMT_WhitelistPanel")
        activeSection = section

        if section == "scripts" then
            BuildScriptsPanel(adminContent)
        elseif section == "command" then
            BuildWhitelistCommandPanel()
        elseif section == "explorer" then
            BuildServerExplorerPanel(adminContent)
        else
            activeSection = "whitelist"
            BuildWhitelistAdminPanel(adminContent)
        end

        for _, button in pairs(tabButtons) do
            if IsValid(button) then button:InvalidateLayout(true) end
        end
    end

    local tabs = {
        {key = "whitelist", label = "Whitelist", width = 120},
        {key = "scripts", label = "Скрипты", width = 120},
        {key = "command", label = "!whitelist", width = 120},
        {key = "explorer", label = "Исследователь", width = 178},
    }
    local x = 0
    for _, tab in ipairs(tabs) do
        local key = tab.key
        local label = tab.label
        local width = tab.width
        local button = ULXButton(tabBar, x, 0, width, 30, label, function()
            ShowSection(key)
        end)
        button.Paint = function(self, w, h)
            local t = GetTheme()
            local col
            if activeSection == key then
                col = t.status
            else
                col = self:IsHovered() and t.btnHover or t.btn
            end
            surface.SetDrawColor(col)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText(label, "Unisono_ULXBtn", w / 2, h / 2, t.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tabButtons[key] = button
        x = x + width + 6
    end

    ShowSection(initialSection or "whitelist")
end

-- ==================== 16. ГЛАВНОЕ МЕНЮ ====================
function ToggleMenu()
    if IsValid(mainFrame) then
        if mainFrame:IsVisible() then mainFrame:Close() else mainFrame:SetVisible(true) mainFrame:MakePopup() end
        return
    end

    mainFrame = vgui.Create("DFrame")
    mainFrame:SetSize(780, 560)
    mainFrame:Center()
    mainFrame:SetTitle("Unisono Multi-Tool — "..SCRIPT_VERSION)
    mainFrame:SetDraggable(true) mainFrame:SetSizable(false)
    mainFrame:ShowCloseButton(true) mainFrame:MakePopup()

    mainFrame.Paint = function(self, w, h)
        local t = GetTheme()
        surface.SetDrawColor(t.bg) surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(t.header) surface.DrawRect(0, 0, w, 28)
        surface.SetDrawColor(t.border) surface.DrawLine(0, 28, w, 28)
        draw.SimpleText("Unisono Multi-Tool", "Unisono_ULXTitle", 10, 14, t.headerText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local leftPanel = vgui.Create("DPanel", mainFrame)
    leftPanel:SetPos(8, 36) leftPanel:SetSize(180, 488)
    leftPanel.Paint = function(s,w,h)
        local t = GetTheme()
        surface.SetDrawColor(t.panel) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(t.border) surface.DrawOutlinedRect(0,0,w,h)
    end

    contentPanel = vgui.Create("DPanel", mainFrame)
    contentPanel:SetPos(196, 36) contentPanel:SetSize(576, 488)
    contentPanel.Paint = function(s,w,h)
        local t = GetTheme()
        surface.SetDrawColor(t.content) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(t.border) surface.DrawOutlinedRect(0,0,w,h)
    end

    local categories = {
        {"!Не работает!",  BuildESPPanel},
        {"Шейдеры",        BuildShadersPanel},
        {"Настройки шрифта", BuildFontPanel},
        {"Физган",         BuildPhysgunPanel},
        {"Локальная консоль", BuildConsolePanel},
        {"Q Меню (Цвет)",  BuildQMenuPanel},
        {"Чат",            BuildChatPanel},
        {"3D Заметки",     BuildNotesPanel},
        {"Статистика",     BuildStatsPanel},
        {"Темы",           BuildThemesPanel},
        {"Oops",           BuildOopsPanel},
        {"Обновить скрипт!", function()
            Notify("Скачивание обновления...")
            PerformScriptUpdate(function(body)
                Notify("Успешно! Перезагрузка...")
                MultiTool_UnloadSelf("Старая версия выгружена перед обновлением.")
                if IsValid(mainFrame) then mainFrame:Close() end
                RunString(body, "Multitool_Updater", false)
            end, function(err) Notify("Ошибка: "..tostring(err), true) end)
        end},
    }

    if IsWhitelistAdmin() then
        table.insert(categories, 5, {"Admin", BuildAdminPanel})
    end

    local y = 6
    for _, cat in ipairs(categories) do
        local name, builder = cat[1], cat[2]
        local btn = vgui.Create("DButton", leftPanel)
        btn:SetPos(6, y) btn:SetSize(168, 28) btn:SetText("")
        btn.Paint = function(self, w2, h2)
            local t = GetTheme()
            local col = self:IsHovered() and t.btnHover or t.btn
            surface.SetDrawColor(col) surface.DrawRect(0,0,w2,h2)
            draw.SimpleText(name, "Unisono_ULXBtn", w2/2, h2/2, t.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            surface.PlaySound("buttons/button9.wav")
            LogFeatureUsage("menu.category", name)
            builder()
        end
        y = y + 32
    end

    local statusBar = vgui.Create("DPanel", mainFrame)
    statusBar:SetPos(0, 532) statusBar:SetSize(780, 24)
    statusBar.Paint = function(s,w,h)
        local t = GetTheme()
        surface.SetDrawColor(t.status) surface.DrawRect(0,0,w,h)
        draw.SimpleText("Unisono Multi-Tool | Бинд: F1 | Тема: "..t.name.." | "..SCRIPT_VERSION, "Unisono_ULXStatus", 8, h/2, t.statusText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(os.date("%H:%M:%S"), "Unisono_ULXStatus", w-8, h/2, t.statusText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    BuildShadersPanel()
    LogFeatureUsage("menu.open", SCRIPT_VERSION)
end

-- ==================== 17. БИНД И ЗАГРУЗКА ====================
concommand.Add("unisono_menu", ToggleMenu)

hook.Add("PlayerBindPress", "Unisono_MenuBind", function(ply, bind, pressed)
    if bind == "gm_showhelp" and pressed then ToggleMenu() return true end
end)

local function MultiTool_StartWhitelistAutoload()
    local function TryLoadWhitelist()
        LoadWhitelist(function(success, source)
            if success then
                chat.AddText(Color(0,255,0), "[Мульти-тул] ", Color(255,255,255), "Whitelist загружен: "..tostring(source)..".")
                return
            end
            if whitelist_retry_count < WHITELIST_MAX_RETRIES then
                chat.AddText(Color(255,180,0), "[Мульти-тул] ", Color(255,255,255), "Whitelist не загрузился. Повтор "..whitelist_retry_count.."/"..WHITELIST_MAX_RETRIES.." через "..WHITELIST_RETRY_INTERVAL.." сек.")
                timer.Create(whitelist_retry_timer, WHITELIST_RETRY_INTERVAL, 1, TryLoadWhitelist)
            else chat.AddText(Color(255,0,0), "[Мульти-тул] ", Color(255,255,255), "Whitelist не удалось загрузить.") end
        end)
    end
    timer.Simple(1, TryLoadWhitelist)
end

LoadWhitelistCache()
MultiTool_StartWhitelistAutoload()

local function InitializeClientIdentityStorage()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp.SteamID or lp:SteamID() == "STEAM_ID_PENDING" then
        return false
    end

    if IsWhitelistAdmin() then
        local loaded, message = LoadClientGitHubToken()
        LoadAdminUsageLogs()
        if loaded then
            print("[Unisono] " .. tostring(message))
            SyncAdminLogsToGist()
        end
    else
        RequestPeerWhitelist()
    end
    return true
end

timer.Create(ADMIN_INIT_TIMER, 1, 0, function()
    if InitializeClientIdentityStorage() then timer.Remove(ADMIN_INIT_TIMER) end
end)
if InitializeClientIdentityStorage() and timer.Exists(ADMIN_INIT_TIMER) then
    timer.Remove(ADMIN_INIT_TIMER)
end

timer.Create(WHITELIST_REFRESH_TIMER, WHITELIST_REFRESH_INTERVAL, 0, function()
    if not peer_override_active then LoadWhitelist(nil, false) end
end)

_G.UnisonoMultiToolRuntimeVersion = SCRIPT_VERSION

chat.AddText(Color(100,200,255), "[Мульти-тул] ", Color(255,255,255), "Unisono Multi-Tool "..SCRIPT_VERSION.." загружен через HTTP. Бинд: F1")
print("[Unisono] Multi-Tool "..SCRIPT_VERSION.." loaded (Client Peer Edition, no custom server Lua).")
