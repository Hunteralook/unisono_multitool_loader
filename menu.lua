-- UNISONO_MULTITOOL_REMOTE_PAYLOAD
-- ============================================================
--  Unisono Multi-Tool v1.7.4 — HTTP Loader Edition
--  Оригинальная менюшка сохранена; whitelist и логи синхронизируются
--  между клиентами без пользовательского серверного Lua.
-- ============================================================
if SERVER then return end

local SCRIPT_VERSION = "v1.7.4"
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
local PENDING_USAGE_LOG_PATH = CLIENT_DATA_DIR .. "/usage_logs_pending.json"
local ADMIN_USAGE_LOG_PATH = CLIENT_DATA_DIR .. "/peer_usage_logs.json"
local CLIENT_TOKEN_PATH = CLIENT_DATA_DIR .. "/github_auth.json"
local LEGACY_CLIENT_TOKEN_PATH = CLIENT_DATA_DIR .. "/github_token.txt"
local BODY_FX_CONFIG_PATH = CLIENT_DATA_DIR .. "/body_fx.json"
local PROCESSED_COMMANDS_PATH = CLIENT_DATA_DIR .. "/processed_client_commands.json"
local ADMIN_INIT_TIMER = "UnisonoMT_ClientIdentityInit"
local BODY_FX_SAVE_TIMER = "UnisonoMT_BodyFXSave"
local MENU_ESCAPE_HOOK = "UnisonoMT_MenuEscape"
local CLIENT_COMMAND_POLL_TIMER = "UnisonoMT_ClientCommandPoll"
local CLIENT_COMMAND_POLL_INTERVAL = 20
local CLIENT_COMMAND_MAX_ENTRIES = 100
local SaveProcessedClientCommands = nil

local safePrefixes = {"UpdateUI_", "RenderMatrix_", "CalcViewOffset_", "ProcessNet_"}
local function GenSafeHook() return safePrefixes[math.random(1, #safePrefixes)] .. tostring(math.random(10000, 99999)) end

local RuntimeHooks = {
    ESP = GenSafeHook(),
    Star = GenSafeHook(),
    Shader = GenSafeHook(),
    Key = GenSafeHook(),
    RGB = GenSafeHook(),
    Stats = GenSafeHook(),
    Notes3D = GenSafeHook(),
    Notes3DHUD = GenSafeHook(),
    BodyFX = GenSafeHook(),
}

-- The skybox feature is kept in one table so the root Lua chunk stays well
-- below LuaJIT's 200-local limit.
local SkyboxFeature = {
    configPath = CLIENT_DATA_DIR .. "/skybox.json",
    saveTimer = "UnisonoMT_SkyboxSave",
    preDrawHook = GenSafeHook(),
    postDrawHook = GenSafeHook(),
    config = {
        enabled = false,
        sky = "painted",
        yaw = 0,
        brightness = 1,
    },
    presets = {
        {name = "GMod Painted", sky = "painted"},
        {name = "Ясный день", sky = "sky_day01_01"},
        {name = "Светлый день", sky = "sky_day01_04"},
        {name = "Облачный день", sky = "sky_day02_05"},
        {name = "Тёплый закат", sky = "sky_day02_09"},
        {name = "Сумерки", sky = "sky_day02_10"},
        {name = "Пыльное небо", sky = "sky_day03_06"},
        {name = "Северное сияние", sky = "sky_borealis01"},
        {name = "Пустошь", sky = "sky_wasteland02"},
    },
    suffixes = {"ft", "bk", "lf", "rt", "up", "dn"},
    materials = {},
    lastError = nil,
}

-- World lighting, local weather and the player trail are grouped into feature
-- tables so the root chunk does not approach LuaJIT's 200-local limit.
local VisualFeatures = {}

VisualFeatures.Atmosphere = {
    configPath = CLIENT_DATA_DIR .. "/world_lighting.json",
    saveTimer = "UnisonoMT_WorldLightingSave",
    screenHook = GenSafeHook(),
    worldFogHook = GenSafeHook(),
    skyFogHook = GenSafeHook(),
    config = {
        enabled = false,
        color = Color(255, 255, 255),
        tintStrength = 0.35,
        brightness = 0,
        contrast = 1,
        saturation = 1,
        nightMode = false,
        fogEnabled = false,
        fogColor = Color(155, 175, 195),
        fogStart = 250,
        fogEnd = 3500,
        fogDensity = 0.82,
    },
}

VisualFeatures.Weather = {
    configPath = CLIENT_DATA_DIR .. "/weather.json",
    saveTimer = "UnisonoMT_WeatherSave",
    thinkHook = GenSafeHook(),
    drawHook = GenSafeHook(),
    config = {
        enabled = false,
        weather = "rain",
        intensity = 1,
        radius = 900,
        wind = 1,
        lightning = true,
        indoorCheck = true,
    },
    presets = {
        rain = {
            name = "Дождь",
            mode = "rain",
            amount = 105,
            color = Color(145, 190, 235),
            screen = {brightness = -0.025, contrast = 0.98, saturation = 0.88, tint = Color(185, 210, 235)},
            fog = {color = Color(120, 145, 165), start = 450, finish = 4200, density = 0.64},
        },
        snow = {
            name = "Снег",
            mode = "snow",
            amount = 82,
            color = Color(235, 250, 255),
            screen = {brightness = 0.015, contrast = 0.97, saturation = 0.86, tint = Color(225, 240, 255)},
            fog = {color = Color(205, 220, 230), start = 350, finish = 3600, density = 0.7},
        },
        storm = {
            name = "Гроза",
            mode = "rain",
            amount = 145,
            color = Color(115, 165, 225),
            screen = {brightness = -0.11, contrast = 1.06, saturation = 0.7, tint = Color(150, 175, 220)},
            fog = {color = Color(70, 85, 110), start = 300, finish = 3000, density = 0.78},
        },
        ash = {
            name = "Пепел",
            mode = "ash",
            amount = 72,
            color = Color(155, 145, 135),
            screen = {brightness = -0.06, contrast = 0.96, saturation = 0.55, tint = Color(185, 150, 125)},
            fog = {color = Color(105, 90, 80), start = 280, finish = 2600, density = 0.76},
        },
        sand = {
            name = "Песчаная буря",
            mode = "sand",
            amount = 135,
            color = Color(225, 170, 95),
            screen = {brightness = 0.025, contrast = 1.04, saturation = 0.68, tint = Color(235, 185, 105)},
            fog = {color = Color(185, 135, 75), start = 110, finish = 1450, density = 0.9},
        },
    },
    order = {"rain", "snow", "storm", "ash", "sand"},
    particles = {},
    flash = 0,
    thunderAt = nil,
    nextLightning = 0,
    lastThink = CurTime(),
    nextRoofCheck = 0,
    indoors = false,
    materials = {
        streak = Material("trails/laser"),
        glow = Material("sprites/light_glow02_add"),
        smoke = Material("particle/particle_smokegrenade"),
    },
    thunderSounds = {
        "ambient/atmosphere/thunder1.wav",
        "ambient/atmosphere/thunder2.wav",
        "ambient/atmosphere/thunder3.wav",
    },
}

VisualFeatures.PlayerTrail = {
    configPath = CLIENT_DATA_DIR .. "/player_trail.json",
    saveTimer = "UnisonoMT_PlayerTrailSave",
    thinkHook = GenSafeHook(),
    drawHook = GenSafeHook(),
    config = {
        enabled = false,
        style = "fire",
        width = 14,
        lifetime = 1.4,
        density = 1,
        intensity = 1,
        particles = true,
        glow = true,
        throughWalls = false,
    },
    styles = {
        fire = {
            name = "Огонь",
            material = Material("trails/laser"),
            palette = {Color(255, 245, 145), Color(255, 145, 25), Color(235, 55, 12)},
            paletteSpeed = 8,
        },
        ice = {
            name = "Лёд",
            material = Material("trails/laser"),
            palette = {Color(220, 250, 255), Color(75, 175, 255)},
        },
        lightning = {
            name = "Молнии",
            material = Material("trails/electric"),
            palette = {Color(80, 165, 255), Color(80, 165, 255), Color(255, 255, 255)},
        },
        rainbow = {name = "Радуга", material = Material("trails/laser")},
        smoke = {
            name = "Дым",
            material = Material("particle/particle_smokegrenade"),
            color = Color(150, 155, 165),
        },
        footsteps = {name = "Светящиеся шаги", material = Material("sprites/light_glow02_add")},
    },
    order = {"fire", "ice", "lightning", "rainbow", "smoke", "footsteps"},
    points = {},
    footprints = {},
    lastSample = 0,
    lastPos = nil,
    lastFootPos = nil,
    footSide = 1,
    sampleCounter = 0,
    maxPoints = 80,
    maxFootprints = 36,
    coreMaterial = Material("sprites/physbeam"),
    glowMaterial = Material("sprites/light_glow02_add"),
}

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

local BodyFXConfig = {
    enabled = false,
    preset = "right_hand",
    style = "electric",
    color = Color(90, 180, 255),
    width = 10,
    lifetime = 0.9,
    length = 125,
    wiggle = 10,
    speed = 8,
    intensity = 1,
    particles = true,
    sourceGlow = true,
    dynamicLight = true,
    throughWalls = false,
}
local BodyFXTrails = {}
local BODY_FX_SAMPLE_INTERVAL = 1 / 40
local BODY_FX_MAX_POINTS = 64
local BodyFXGlowMaterial = Material("sprites/light_glow02_add")
local BodyFXCoreMaterial = Material("sprites/physbeam")
local BodyFXStyles = {
    electric = {
        name = "Электричество",
        material = Material("trails/electric"),
        noise = 1.0,
        sparks = true,
    },
    energy = {
        name = "Энергетическая лента",
        material = Material("trails/laser"),
        noise = 0.45,
    },
    rainbow = {
        name = "Радужная лента",
        material = Material("trails/laser"),
        noise = 0.65,
        rainbow = true,
    },
    plasma = {
        name = "Плазменная спираль",
        material = Material("trails/laser"),
        noise = 0.55,
        helix = true,
    },
    fire = {
        name = "Огненный след",
        material = Material("trails/laser"),
        noise = 1.15,
        lift = 0.3,
        embers = true,
        paletteSpeed = 8,
        palette = {
            Color(255, 245, 150),
            Color(255, 150, 30),
            Color(235, 55, 15),
        },
    },
    frost = {
        name = "Ледяные кристаллы",
        material = Material("trails/laser"),
        noise = 0.25,
        shards = true,
        paletteSpeed = 3,
        palette = {
            Color(245, 255, 255),
            Color(120, 225, 255),
            Color(45, 120, 255),
        },
    },
    void = {
        name = "Пустотная орбита",
        material = Material("trails/laser"),
        noise = 0.7,
        orbit = true,
        paletteSpeed = 4,
        palette = {
            Color(225, 90, 255),
            Color(110, 35, 230),
            Color(35, 10, 95),
        },
    },
    pulse = {
        name = "Импульсные кольца",
        material = Material("trails/laser"),
        noise = 0.12,
        rings = true,
        maxProgress = 0.55,
        tailAlpha = 0.45,
    },
    sparks = {
        name = "Искровой разряд",
        material = Material("trails/electric"),
        noise = 1.55,
        sparks = true,
        maxProgress = 0.65,
        tailAlpha = 0.55,
    },
}
local BodyFXBonePresets = {
    right_hand = {
        name = "Правая кисть",
        slots = {
            {"ValveBiped.Bip01_R_Hand", "ValveBiped.Anim_Attachment_RH"},
        },
    },
    left_hand = {
        name = "Левая кисть",
        slots = {
            {"ValveBiped.Bip01_L_Hand"},
        },
    },
    both_hands = {
        name = "Обе кисти",
        slots = {
            {"ValveBiped.Bip01_R_Hand", "ValveBiped.Anim_Attachment_RH"},
            {"ValveBiped.Bip01_L_Hand"},
        },
    },
    forearms = {
        name = "Оба предплечья",
        slots = {
            {"ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Elbow"},
            {"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Elbow"},
        },
    },
    head = {
        name = "Голова",
        slots = {
            {"ValveBiped.Bip01_Head1"},
        },
    },
    chest = {
        name = "Грудь",
        slots = {
            {"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine"},
        },
    },
    feet = {
        name = "Обе стопы",
        slots = {
            {"ValveBiped.Bip01_R_Foot"},
            {"ValveBiped.Bip01_L_Foot"},
        },
    },
    right_foot = {
        name = "Правая стопа",
        slots = {
            {"ValveBiped.Bip01_R_Foot"},
        },
    },
    left_foot = {
        name = "Левая стопа",
        slots = {
            {"ValveBiped.Bip01_L_Foot"},
        },
    },
    shoulders = {
        name = "Оба плеча",
        slots = {
            {"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Clavicle"},
            {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Clavicle"},
        },
    },
    elbows = {
        name = "Оба локтя",
        slots = {
            {"ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_UpperArm"},
            {"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_UpperArm"},
        },
    },
    knees = {
        name = "Оба колена",
        slots = {
            {"ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Thigh"},
            {"ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Thigh"},
        },
    },
    arms = {
        name = "Руки целиком",
        slots = {
            {"ValveBiped.Bip01_R_UpperArm"},
            {"ValveBiped.Bip01_R_Forearm"},
            {"ValveBiped.Bip01_R_Hand", "ValveBiped.Anim_Attachment_RH"},
            {"ValveBiped.Bip01_L_UpperArm"},
            {"ValveBiped.Bip01_L_Forearm"},
            {"ValveBiped.Bip01_L_Hand"},
        },
    },
    legs = {
        name = "Ноги целиком",
        slots = {
            {"ValveBiped.Bip01_R_Thigh"},
            {"ValveBiped.Bip01_R_Calf"},
            {"ValveBiped.Bip01_R_Foot"},
            {"ValveBiped.Bip01_L_Thigh"},
            {"ValveBiped.Bip01_L_Calf"},
            {"ValveBiped.Bip01_L_Foot"},
        },
    },
    spine = {
        name = "Позвоночник",
        slots = {
            {"ValveBiped.Bip01_Pelvis"},
            {"ValveBiped.Bip01_Spine"},
            {"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine1"},
            {"ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Neck1"},
        },
    },
    head_chest = {
        name = "Голова и грудь",
        slots = {
            {"ValveBiped.Bip01_Head1"},
            {"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine"},
        },
    },
    all_extremities = {
        name = "Кисти и стопы",
        slots = {
            {"ValveBiped.Bip01_R_Hand", "ValveBiped.Anim_Attachment_RH"},
            {"ValveBiped.Bip01_L_Hand"},
            {"ValveBiped.Bip01_R_Foot"},
            {"ValveBiped.Bip01_L_Foot"},
        },
    },
    full_body = {
        name = "Всё тело",
        slots = {
            {"ValveBiped.Bip01_Head1"},
            {"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine"},
            {"ValveBiped.Bip01_Pelvis"},
            {"ValveBiped.Bip01_R_Hand", "ValveBiped.Anim_Attachment_RH"},
            {"ValveBiped.Bip01_L_Hand"},
            {"ValveBiped.Bip01_R_Foot"},
            {"ValveBiped.Bip01_L_Foot"},
        },
    },
}

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
local PEER_LOG_QUEUE_MAX = 200

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

local function ClearBodyFXTrails()
    BodyFXTrails = {}
end

local function SaveBodyFXConfig()
    local color = BodyFXConfig.color or Color(90, 180, 255)
    local payload = {
        version = 2,
        enabled = BodyFXConfig.enabled == true,
        preset = BodyFXConfig.preset,
        style = BodyFXConfig.style,
        color = {
            r = math.Clamp(math.floor(tonumber(color.r) or 90), 0, 255),
            g = math.Clamp(math.floor(tonumber(color.g) or 180), 0, 255),
            b = math.Clamp(math.floor(tonumber(color.b) or 255), 0, 255),
        },
        width = BodyFXConfig.width,
        lifetime = BodyFXConfig.lifetime,
        length = BodyFXConfig.length,
        wiggle = BodyFXConfig.wiggle,
        speed = BodyFXConfig.speed,
        intensity = BodyFXConfig.intensity,
        particles = BodyFXConfig.particles == true,
        sourceGlow = BodyFXConfig.sourceGlow == true,
        dynamicLight = BodyFXConfig.dynamicLight == true,
        throughWalls = BodyFXConfig.throughWalls == true,
    }
    file.CreateDir(CLIENT_DATA_DIR)
    file.Write(BODY_FX_CONFIG_PATH, util.TableToJSON(payload, true) or "{}")
end

local function QueueBodyFXConfigSave()
    timer.Create(BODY_FX_SAVE_TIMER, 0.25, 1, SaveBodyFXConfig)
end

local function LoadBodyFXConfig()
    local raw = file.Read(BODY_FX_CONFIG_PATH, "DATA")
    local data = raw and util.JSONToTable(raw) or nil
    if not istable(data) then return false end

    if BodyFXBonePresets[data.preset] then BodyFXConfig.preset = data.preset end
    if BodyFXStyles[data.style] then BodyFXConfig.style = data.style end
    if istable(data.color) then
        BodyFXConfig.color = Color(
            math.Clamp(math.floor(tonumber(data.color.r) or 90), 0, 255),
            math.Clamp(math.floor(tonumber(data.color.g) or 180), 0, 255),
            math.Clamp(math.floor(tonumber(data.color.b) or 255), 0, 255)
        )
    end
    BodyFXConfig.width = math.Clamp(tonumber(data.width) or BodyFXConfig.width, 2, 30)
    BodyFXConfig.lifetime = math.Clamp(tonumber(data.lifetime) or BodyFXConfig.lifetime, 0.2, 2.5)
    BodyFXConfig.length = math.Clamp(tonumber(data.length) or BodyFXConfig.length, 20, 260)
    BodyFXConfig.wiggle = math.Clamp(tonumber(data.wiggle) or BodyFXConfig.wiggle, 0, 30)
    BodyFXConfig.speed = math.Clamp(tonumber(data.speed) or BodyFXConfig.speed, 1, 20)
    BodyFXConfig.intensity = math.Clamp(tonumber(data.intensity) or BodyFXConfig.intensity, 0.35, 2.25)
    BodyFXConfig.particles = data.particles ~= false
    BodyFXConfig.sourceGlow = data.sourceGlow ~= false
    BodyFXConfig.dynamicLight = data.dynamicLight ~= false
    BodyFXConfig.throughWalls = data.throughWalls == true
    BodyFXConfig.enabled = data.enabled == true
    return true
end

LoadBodyFXConfig()

-- ==================== 5.1 ЛОКАЛЬНЫЙ SKYBOX ====================
function SkyboxFeature.SanitizeSkyName(value)
    value = string.Trim(tostring(value or ""))
    if value == "" or #value > 64 then return nil end
    if not string.match(value, "^[%w_%-]+$") then return nil end
    return string.lower(value)
end

function SkyboxFeature.GetDisplayName(skyName)
    skyName = SkyboxFeature.SanitizeSkyName(skyName) or "painted"
    for _, preset in ipairs(SkyboxFeature.presets) do
        if preset.sky == skyName then
            return preset.name .. " (" .. preset.sky .. ")"
        end
    end
    return "Пользовательский (" .. skyName .. ")"
end

function SkyboxFeature.ResolveMaterials(skyName, forceRefresh)
    skyName = SkyboxFeature.SanitizeSkyName(skyName)
    if not skyName then return nil, "Некорректное имя skybox." end
    if forceRefresh then SkyboxFeature.materials[skyName] = nil end

    local cached = SkyboxFeature.materials[skyName]
    if cached then return cached.value, cached.error end

    local loaded = {}
    for _, suffix in ipairs(SkyboxFeature.suffixes) do
        local materialPath = "skybox/" .. skyName .. suffix
        local material = Material(materialPath)
        if not material or material:IsError() then
            local err = "Не найдена грань " .. materialPath .. "."
            SkyboxFeature.materials[skyName] = {error = err}
            SkyboxFeature.lastError = err
            return nil, err
        end
        loaded[suffix] = material
    end

    SkyboxFeature.materials[skyName] = {value = loaded}
    SkyboxFeature.lastError = nil
    return loaded
end

function SkyboxFeature.Save()
    local payload = {
        version = 1,
        enabled = SkyboxFeature.config.enabled == true,
        sky = SkyboxFeature.config.sky,
        yaw = math.Clamp(tonumber(SkyboxFeature.config.yaw) or 0, 0, 360),
        brightness = math.Clamp(tonumber(SkyboxFeature.config.brightness) or 1, 0.2, 1),
    }
    file.CreateDir(CLIENT_DATA_DIR)
    file.Write(SkyboxFeature.configPath, util.TableToJSON(payload, true) or "{}")
end

function SkyboxFeature.QueueSave()
    timer.Create(SkyboxFeature.saveTimer, 0.25, 1, SkyboxFeature.Save)
end

function SkyboxFeature.Load()
    local raw = file.Read(SkyboxFeature.configPath, "DATA")
    local data = raw and util.JSONToTable(raw) or nil
    if not istable(data) then return false end

    local skyName = SkyboxFeature.SanitizeSkyName(data.sky)
    if skyName then SkyboxFeature.config.sky = skyName end
    SkyboxFeature.config.yaw = math.Clamp(tonumber(data.yaw) or 0, 0, 360)
    SkyboxFeature.config.brightness = math.Clamp(tonumber(data.brightness) or 1, 0.2, 1)
    SkyboxFeature.config.enabled = data.enabled == true
    return true
end

function SkyboxFeature.Apply(skyName, yaw, brightness)
    skyName = SkyboxFeature.SanitizeSkyName(skyName)
    if not skyName then
        return false, "Имя может содержать только буквы, цифры, _ и -."
    end

    local materials, err = SkyboxFeature.ResolveMaterials(skyName, true)
    if not materials then return false, err end

    SkyboxFeature.config.sky = skyName
    SkyboxFeature.config.yaw = math.Clamp(tonumber(yaw) or SkyboxFeature.config.yaw, 0, 360)
    SkyboxFeature.config.brightness = math.Clamp(
        tonumber(brightness) or SkyboxFeature.config.brightness,
        0.2,
        1
    )
    SkyboxFeature.config.enabled = true
    SkyboxFeature.lastError = nil
    SkyboxFeature.QueueSave()
    return true, "Локальное небо применено."
end

function SkyboxFeature.Disable()
    SkyboxFeature.config.enabled = false
    SkyboxFeature.lastError = nil
    SkyboxFeature.QueueSave()
end

function SkyboxFeature.Reset()
    SkyboxFeature.config.enabled = false
    SkyboxFeature.config.sky = "painted"
    SkyboxFeature.config.yaw = 0
    SkyboxFeature.config.brightness = 1
    SkyboxFeature.materials = {}
    SkyboxFeature.lastError = nil
    SkyboxFeature.Save()
end

function SkyboxFeature.EnsureFaces()
    if SkyboxFeature.faces then return end
    local size = 1024
    SkyboxFeature.faces = {
        ft = {
            Vector(size, size, size),
            Vector(size, -size, size),
            Vector(size, -size, -size),
            Vector(size, size, -size),
        },
        bk = {
            Vector(-size, -size, size),
            Vector(-size, size, size),
            Vector(-size, size, -size),
            Vector(-size, -size, -size),
        },
        lf = {
            Vector(size, size, size),
            Vector(-size, size, size),
            Vector(-size, size, -size),
            Vector(size, size, -size),
        },
        rt = {
            Vector(-size, -size, size),
            Vector(size, -size, size),
            Vector(size, -size, -size),
            Vector(-size, -size, -size),
        },
        up = {
            Vector(-size, size, size),
            Vector(size, size, size),
            Vector(size, -size, size),
            Vector(-size, -size, size),
        },
        dn = {
            Vector(-size, -size, -size),
            Vector(size, -size, -size),
            Vector(size, size, -size),
            Vector(-size, size, -size),
        },
    }
end

function SkyboxFeature.Draw()
    if not SkyboxFeature.config.enabled then return false end

    local materials, err = SkyboxFeature.ResolveMaterials(SkyboxFeature.config.sky)
    if not materials then
        SkyboxFeature.lastError = err
        return false
    end

    SkyboxFeature.EnsureFaces()
    local eyeAngles = EyeAngles()
    local viewAngles = Angle(
        eyeAngles.p,
        eyeAngles.y + SkyboxFeature.config.yaw,
        eyeAngles.r
    )
    local brightness = math.Clamp(
        math.floor((tonumber(SkyboxFeature.config.brightness) or 1) * 255),
        0,
        255
    )
    local color = Color(brightness, brightness, brightness, 255)

    render.OverrideDepthEnable(true, false)
    render.SetLightingMode(2)
    render.CullMode(MATERIAL_CULLMODE_NONE or 2)
    cam.Start3D(vector_origin, viewAngles)
        for _, suffix in ipairs(SkyboxFeature.suffixes) do
            local face = SkyboxFeature.faces[suffix]
            render.SetMaterial(materials[suffix])
            render.DrawQuad(face[1], face[2], face[3], face[4], color)
        end
    cam.End3D()
    render.CullMode(MATERIAL_CULLMODE_CCW or 0)
    render.SetLightingMode(0)
    render.OverrideDepthEnable(false, false)
    return true
end

SkyboxFeature.Load()

hook.Add("PreDrawSkyBox", SkyboxFeature.preDrawHook, function()
    if SkyboxFeature.Draw() then return true end
end)

hook.Add("PostDraw2DSkyBox", SkyboxFeature.postDrawHook, function()
    if SkyboxFeature.config.enabled then SkyboxFeature.Draw() end
end)

-- ==================== 5.2 РЕДАКТОР ОСВЕЩЕНИЯ И ТУМАНА ====================
function VisualFeatures.Atmosphere.Save()
    local cfg = VisualFeatures.Atmosphere.config
    local worldColor = cfg.color or Color(255, 255, 255)
    local fogColor = cfg.fogColor or Color(155, 175, 195)
    local payload = {
        version = 1,
        enabled = cfg.enabled == true,
        color = {
            r = math.Clamp(math.floor(tonumber(worldColor.r) or 255), 0, 255),
            g = math.Clamp(math.floor(tonumber(worldColor.g) or 255), 0, 255),
            b = math.Clamp(math.floor(tonumber(worldColor.b) or 255), 0, 255),
        },
        tintStrength = math.Clamp(tonumber(cfg.tintStrength) or 0.35, 0, 1),
        brightness = math.Clamp(tonumber(cfg.brightness) or 0, -0.5, 0.5),
        contrast = math.Clamp(tonumber(cfg.contrast) or 1, 0.5, 2),
        saturation = math.Clamp(tonumber(cfg.saturation) or 1, 0, 2),
        nightMode = cfg.nightMode == true,
        fogEnabled = cfg.fogEnabled == true,
        fogColor = {
            r = math.Clamp(math.floor(tonumber(fogColor.r) or 155), 0, 255),
            g = math.Clamp(math.floor(tonumber(fogColor.g) or 175), 0, 255),
            b = math.Clamp(math.floor(tonumber(fogColor.b) or 195), 0, 255),
        },
        fogStart = math.Clamp(tonumber(cfg.fogStart) or 250, 0, 5000),
        fogEnd = math.Clamp(tonumber(cfg.fogEnd) or 3500, 128, 12000),
        fogDensity = math.Clamp(tonumber(cfg.fogDensity) or 0.82, 0.05, 1),
    }
    file.CreateDir(CLIENT_DATA_DIR)
    file.Write(VisualFeatures.Atmosphere.configPath, util.TableToJSON(payload, true) or "{}")
end

function VisualFeatures.Atmosphere.QueueSave()
    timer.Create(VisualFeatures.Atmosphere.saveTimer, 0.25, 1, VisualFeatures.Atmosphere.Save)
end

function VisualFeatures.Atmosphere.Load()
    local raw = file.Read(VisualFeatures.Atmosphere.configPath, "DATA")
    local data = raw and util.JSONToTable(raw) or nil
    if not istable(data) then return false end

    local cfg = VisualFeatures.Atmosphere.config
    if istable(data.color) then
        cfg.color = Color(
            math.Clamp(math.floor(tonumber(data.color.r) or 255), 0, 255),
            math.Clamp(math.floor(tonumber(data.color.g) or 255), 0, 255),
            math.Clamp(math.floor(tonumber(data.color.b) or 255), 0, 255)
        )
    end
    if istable(data.fogColor) then
        cfg.fogColor = Color(
            math.Clamp(math.floor(tonumber(data.fogColor.r) or 155), 0, 255),
            math.Clamp(math.floor(tonumber(data.fogColor.g) or 175), 0, 255),
            math.Clamp(math.floor(tonumber(data.fogColor.b) or 195), 0, 255)
        )
    end
    cfg.enabled = data.enabled == true
    cfg.tintStrength = math.Clamp(tonumber(data.tintStrength) or 0.35, 0, 1)
    cfg.brightness = math.Clamp(tonumber(data.brightness) or 0, -0.5, 0.5)
    cfg.contrast = math.Clamp(tonumber(data.contrast) or 1, 0.5, 2)
    cfg.saturation = math.Clamp(tonumber(data.saturation) or 1, 0, 2)
    cfg.nightMode = data.nightMode == true
    cfg.fogEnabled = data.fogEnabled == true
    cfg.fogStart = math.Clamp(tonumber(data.fogStart) or 250, 0, 5000)
    cfg.fogEnd = math.Clamp(tonumber(data.fogEnd) or 3500, 128, 12000)
    cfg.fogDensity = math.Clamp(tonumber(data.fogDensity) or 0.82, 0.05, 1)
    return true
end

function VisualFeatures.Atmosphere.Reset()
    VisualFeatures.Atmosphere.config = {
        enabled = false,
        color = Color(255, 255, 255),
        tintStrength = 0.35,
        brightness = 0,
        contrast = 1,
        saturation = 1,
        nightMode = false,
        fogEnabled = false,
        fogColor = Color(155, 175, 195),
        fogStart = 250,
        fogEnd = 3500,
        fogDensity = 0.82,
    }
    VisualFeatures.Atmosphere.Save()
end

function VisualFeatures.Atmosphere.GetFogConfig()
    local cfg = VisualFeatures.Atmosphere.config
    if cfg.fogEnabled then
        local startDistance = math.Clamp(tonumber(cfg.fogStart) or 250, 0, 5000)
        local endDistance = math.max(
            startDistance + 64,
            math.Clamp(tonumber(cfg.fogEnd) or 3500, 128, 12000)
        )
        return {
            color = cfg.fogColor or Color(155, 175, 195),
            start = startDistance,
            finish = endDistance,
            density = math.Clamp(tonumber(cfg.fogDensity) or 0.82, 0.05, 1),
        }
    end

    if VisualFeatures.Weather.config.indoorCheck and VisualFeatures.Weather.indoors then
        return nil
    end
    local preset = VisualFeatures.Weather.GetActivePreset and VisualFeatures.Weather.GetActivePreset() or nil
    if not preset or not preset.fog then return nil end
    local intensity = math.Clamp(tonumber(VisualFeatures.Weather.config.intensity) or 1, 0.2, 2)
    return {
        color = preset.fog.color,
        start = math.max(0, preset.fog.start / math.max(0.65, intensity)),
        finish = math.max(128, preset.fog.finish / math.max(0.72, intensity)),
        density = math.Clamp(preset.fog.density * (0.72 + intensity * 0.28), 0.05, 1),
    }
end

function VisualFeatures.Atmosphere.SetupFog(scale)
    local fog = VisualFeatures.Atmosphere.GetFogConfig()
    if not fog then return end

    scale = math.max(tonumber(scale) or 1, 0.001)
    local color = fog.color or Color(155, 175, 195)
    render.FogMode(MATERIAL_FOG_LINEAR)
    render.FogColor(color.r, color.g, color.b)
    render.FogStart(fog.start * scale)
    render.FogEnd(fog.finish * scale)
    render.FogMaxDensity(fog.density)
    return true
end

function VisualFeatures.Atmosphere.DrawPostProcess()
    local cfg = VisualFeatures.Atmosphere.config
    local weatherScreen = VisualFeatures.Weather.GetScreenAdjustment
        and VisualFeatures.Weather.GetScreenAdjustment()
        or nil
    local flash = math.Clamp(tonumber(VisualFeatures.Weather.flash) or 0, 0, 1)
    if not cfg.enabled and not cfg.nightMode and not weatherScreen and flash <= 0 then return end

    local brightness = cfg.enabled and (tonumber(cfg.brightness) or 0) or 0
    local contrast = cfg.enabled and (tonumber(cfg.contrast) or 1) or 1
    local saturation = cfg.enabled and (tonumber(cfg.saturation) or 1) or 1
    local addR, addG, addB = 0, 0, 0

    if cfg.enabled then
        local color = cfg.color or Color(255, 255, 255)
        local strength = math.Clamp(tonumber(cfg.tintStrength) or 0.35, 0, 1)
        addR = addR + ((color.r / 255) - 1) * 0.2 * strength
        addG = addG + ((color.g / 255) - 1) * 0.2 * strength
        addB = addB + ((color.b / 255) - 1) * 0.2 * strength
    end

    if cfg.nightMode then
        brightness = brightness - 0.18
        contrast = contrast * 1.08
        saturation = saturation * 0.72
        addR = addR - 0.035
        addG = addG - 0.018
        addB = addB + 0.006
    end

    if weatherScreen then
        local weatherIntensity = math.Clamp(tonumber(VisualFeatures.Weather.config.intensity) or 1, 0.2, 2)
        local tint = weatherScreen.tint or Color(255, 255, 255)
        brightness = brightness + (weatherScreen.brightness or 0) * weatherIntensity
        contrast = contrast * (1 + ((weatherScreen.contrast or 1) - 1) * weatherIntensity)
        saturation = saturation * (1 + ((weatherScreen.saturation or 1) - 1) * weatherIntensity)
        addR = addR + ((tint.r / 255) - 1) * 0.1 * weatherIntensity
        addG = addG + ((tint.g / 255) - 1) * 0.1 * weatherIntensity
        addB = addB + ((tint.b / 255) - 1) * 0.1 * weatherIntensity
    end

    brightness = brightness + flash * 0.42
    contrast = contrast * (1 + flash * 0.16)
    addR = addR + flash * 0.08
    addG = addG + flash * 0.09
    addB = addB + flash * 0.12

    DrawColorModify({
        ["$pp_colour_addr"] = math.Clamp(addR, -1, 1),
        ["$pp_colour_addg"] = math.Clamp(addG, -1, 1),
        ["$pp_colour_addb"] = math.Clamp(addB, -1, 1),
        ["$pp_colour_brightness"] = math.Clamp(brightness, -1, 1),
        ["$pp_colour_contrast"] = math.Clamp(contrast, 0.1, 3),
        ["$pp_colour_colour"] = math.Clamp(saturation, 0, 3),
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0,
    })
end

-- ==================== 5.3 ЛОКАЛЬНАЯ ПОГОДА ====================
function VisualFeatures.Weather.GetPreset()
    return VisualFeatures.Weather.presets[VisualFeatures.Weather.config.weather]
end

function VisualFeatures.Weather.GetActivePreset()
    if not VisualFeatures.Weather.config.enabled then return nil end
    return VisualFeatures.Weather.GetPreset()
end

function VisualFeatures.Weather.GetScreenAdjustment()
    local preset = VisualFeatures.Weather.GetActivePreset()
    return preset and preset.screen or nil
end

function VisualFeatures.Weather.Save()
    local cfg = VisualFeatures.Weather.config
    local payload = {
        version = 1,
        enabled = cfg.enabled == true,
        weather = VisualFeatures.Weather.presets[cfg.weather] and cfg.weather or "rain",
        intensity = math.Clamp(tonumber(cfg.intensity) or 1, 0.2, 2),
        radius = math.Clamp(tonumber(cfg.radius) or 900, 400, 1400),
        wind = math.Clamp(tonumber(cfg.wind) or 1, 0, 2),
        lightning = cfg.lightning ~= false,
        indoorCheck = cfg.indoorCheck ~= false,
    }
    file.CreateDir(CLIENT_DATA_DIR)
    file.Write(VisualFeatures.Weather.configPath, util.TableToJSON(payload, true) or "{}")
end

function VisualFeatures.Weather.QueueSave()
    timer.Create(VisualFeatures.Weather.saveTimer, 0.25, 1, VisualFeatures.Weather.Save)
end

function VisualFeatures.Weather.Load()
    local raw = file.Read(VisualFeatures.Weather.configPath, "DATA")
    local data = raw and util.JSONToTable(raw) or nil
    if not istable(data) then return false end

    local cfg = VisualFeatures.Weather.config
    cfg.enabled = data.enabled == true
    if VisualFeatures.Weather.presets[data.weather] then cfg.weather = data.weather end
    cfg.intensity = math.Clamp(tonumber(data.intensity) or 1, 0.2, 2)
    cfg.radius = math.Clamp(tonumber(data.radius) or 900, 400, 1400)
    cfg.wind = math.Clamp(tonumber(data.wind) or 1, 0, 2)
    cfg.lightning = data.lightning ~= false
    cfg.indoorCheck = data.indoorCheck ~= false
    return true
end

function VisualFeatures.Weather.Clear()
    VisualFeatures.Weather.particles = {}
    VisualFeatures.Weather.flash = 0
    VisualFeatures.Weather.thunderAt = nil
    VisualFeatures.Weather.nextLightning = 0
end

function VisualFeatures.Weather.Reset()
    VisualFeatures.Weather.config = {
        enabled = false,
        weather = "rain",
        intensity = 1,
        radius = 900,
        wind = 1,
        lightning = true,
        indoorCheck = true,
    }
    VisualFeatures.Weather.Clear()
    VisualFeatures.Weather.Save()
end

function VisualFeatures.Weather.SpawnParticle(preset, eyePosition)
    local cfg = VisualFeatures.Weather.config
    local radius = math.Clamp(tonumber(cfg.radius) or 900, 400, 1400)
    local mode = preset.mode
    local position
    if mode == "sand" then
        position = eyePosition + Vector(
            math.Rand(-radius, radius * 0.45),
            math.Rand(-radius, radius),
            math.Rand(-radius * 0.3, radius * 0.55)
        )
    else
        position = eyePosition + Vector(
            math.Rand(-radius, radius),
            math.Rand(-radius, radius),
            math.Rand(100, radius * 0.85)
        )
    end
    return {
        pos = position,
        phase = math.Rand(0, math.pi * 2),
        age = 0,
        life = math.Rand(2.2, 5.4),
        size = math.Rand(4, 10),
        velocity = Vector(0, 0, -100),
    }
end

function VisualFeatures.Weather.CheckRoof(lp, now)
    if not VisualFeatures.Weather.config.indoorCheck then
        VisualFeatures.Weather.indoors = false
        return
    end
    if now < VisualFeatures.Weather.nextRoofCheck then return end
    VisualFeatures.Weather.nextRoofCheck = now + 0.45
    local eyePosition = lp:EyePos()
    local trace = util.TraceLine({
        start = eyePosition,
        endpos = eyePosition + Vector(0, 0, 16000),
        filter = lp,
        mask = MASK_SOLID_BRUSHONLY or MASK_SOLID,
    })
    VisualFeatures.Weather.indoors = trace.Hit == true and trace.HitSky ~= true
end

function VisualFeatures.Weather.Update()
    local now = CurTime()
    local dt = math.Clamp(now - (VisualFeatures.Weather.lastThink or now), 0, 0.05)
    VisualFeatures.Weather.lastThink = now
    VisualFeatures.Weather.flash = math.max(0, (VisualFeatures.Weather.flash or 0) - dt * 2.8)

    local lp = LocalPlayer()
    local preset = VisualFeatures.Weather.GetActivePreset()
    if not IsValid(lp) or not preset then
        if #VisualFeatures.Weather.particles > 0 then VisualFeatures.Weather.particles = {} end
        VisualFeatures.Weather.thunderAt = nil
        VisualFeatures.Weather.nextLightning = 0
        return
    end

    VisualFeatures.Weather.CheckRoof(lp, now)
    local blockedByRoof = VisualFeatures.Weather.config.indoorCheck and VisualFeatures.Weather.indoors
    if blockedByRoof then
        if #VisualFeatures.Weather.particles > 0 then VisualFeatures.Weather.particles = {} end
    else
        local cfg = VisualFeatures.Weather.config
        local eyePosition = lp:EyePos()
        local intensity = math.Clamp(tonumber(cfg.intensity) or 1, 0.2, 2)
        local radius = math.Clamp(tonumber(cfg.radius) or 900, 400, 1400)
        local targetCount = math.Clamp(math.floor(preset.amount * intensity), 12, 220)
        while #VisualFeatures.Weather.particles < targetCount do
            table.insert(VisualFeatures.Weather.particles, VisualFeatures.Weather.SpawnParticle(preset, eyePosition))
        end
        while #VisualFeatures.Weather.particles > targetCount do
            table.remove(VisualFeatures.Weather.particles)
        end

        local wind = math.Clamp(tonumber(cfg.wind) or 1, 0, 2)
        local mode = preset.mode
        local maxDistanceSqr = (radius * 1.75) ^ 2
        for index, particle in ipairs(VisualFeatures.Weather.particles) do
            particle.age = particle.age + dt
            if mode == "rain" then
                local fallSpeed = cfg.weather == "storm" and -1250 or -920
                particle.velocity = Vector(90 * wind, 28 * wind, fallSpeed)
            elseif mode == "snow" then
                particle.velocity = Vector(
                    math.sin(now * 0.8 + particle.phase) * 42 * wind,
                    math.cos(now * 0.65 + particle.phase) * 34 * wind,
                    -78
                )
            elseif mode == "ash" then
                particle.velocity = Vector(
                    46 * wind + math.sin(now + particle.phase) * 24,
                    18 * wind + math.cos(now * 0.7 + particle.phase) * 20,
                    -28 + math.sin(now * 0.55 + particle.phase) * 13
                )
            else
                particle.velocity = Vector(
                    570 * math.max(0.2, wind),
                    165 * math.max(0.2, wind),
                    math.sin(now * 1.7 + particle.phase) * 24
                )
            end

            particle.pos = particle.pos + particle.velocity * dt
            local tooFar = particle.pos:DistToSqr(eyePosition) > maxDistanceSqr
            local tooLow = mode ~= "sand" and particle.pos.z < eyePosition.z - radius * 0.72
            if particle.age > particle.life or tooFar or tooLow then
                VisualFeatures.Weather.particles[index] = VisualFeatures.Weather.SpawnParticle(preset, eyePosition)
            end
        end
    end

    local isStorm = VisualFeatures.Weather.config.weather == "storm"
        and VisualFeatures.Weather.config.lightning
        and not blockedByRoof
    if isStorm then
        if VisualFeatures.Weather.nextLightning <= 0 then
            VisualFeatures.Weather.nextLightning = now + math.Rand(3.5, 7)
        elseif now >= VisualFeatures.Weather.nextLightning then
            VisualFeatures.Weather.flash = 1
            VisualFeatures.Weather.thunderAt = now + math.Rand(0.16, 0.52)
            VisualFeatures.Weather.nextLightning = now + math.Rand(5, 11)
        end
    else
        VisualFeatures.Weather.nextLightning = 0
        VisualFeatures.Weather.thunderAt = nil
    end

    if VisualFeatures.Weather.thunderAt and now >= VisualFeatures.Weather.thunderAt then
        VisualFeatures.Weather.thunderAt = nil
        local sounds = VisualFeatures.Weather.thunderSounds
        surface.PlaySound(sounds[math.random(1, #sounds)])
    end
end

function VisualFeatures.Weather.Draw()
    local preset = VisualFeatures.Weather.GetActivePreset()
    if not preset or (VisualFeatures.Weather.config.indoorCheck and VisualFeatures.Weather.indoors) then return end
    if #VisualFeatures.Weather.particles == 0 then return end

    local intensity = math.Clamp(tonumber(VisualFeatures.Weather.config.intensity) or 1, 0.2, 2)
    local mode = preset.mode
    local color = preset.color
    if mode == "rain" then
        render.SetMaterial(VisualFeatures.Weather.materials.streak)
        local length = (VisualFeatures.Weather.config.weather == "storm" and 76 or 52) * intensity
        local width = 0.9 + intensity * 0.85
        for _, particle in ipairs(VisualFeatures.Weather.particles) do
            local direction = particle.velocity:GetNormalized()
            render.DrawBeam(
                particle.pos,
                particle.pos - direction * length,
                width,
                0,
                1,
                Color(color.r, color.g, color.b, math.Clamp(105 + intensity * 55, 0, 220))
            )
        end
    elseif mode == "snow" then
        render.SetMaterial(VisualFeatures.Weather.materials.glow)
        for _, particle in ipairs(VisualFeatures.Weather.particles) do
            local pulse = 0.82 + math.sin(CurTime() * 2 + particle.phase) * 0.18
            local size = particle.size * pulse * (0.8 + intensity * 0.35)
            render.DrawSprite(particle.pos, size, size, Color(color.r, color.g, color.b, 205))
        end
    elseif mode == "ash" then
        render.SetMaterial(VisualFeatures.Weather.materials.smoke)
        for _, particle in ipairs(VisualFeatures.Weather.particles) do
            local progress = math.Clamp(particle.age / particle.life, 0, 1)
            local size = particle.size * (1.1 + progress * 1.8) * intensity
            render.DrawSprite(
                particle.pos,
                size,
                size,
                Color(color.r, color.g, color.b, math.floor(145 * (1 - progress * 0.45)))
            )
        end
    else
        render.SetMaterial(VisualFeatures.Weather.materials.streak)
        for _, particle in ipairs(VisualFeatures.Weather.particles) do
            local direction = particle.velocity:GetNormalized()
            render.DrawBeam(
                particle.pos,
                particle.pos - direction * (26 + intensity * 18),
                1.2 + intensity,
                0,
                1,
                Color(color.r, color.g, color.b, math.Clamp(90 + intensity * 48, 0, 210))
            )
        end
    end
end

-- ==================== 5.4 СЛЕД ЗА ИГРОКОМ ====================
function VisualFeatures.PlayerTrail.Save()
    local cfg = VisualFeatures.PlayerTrail.config
    local payload = {
        version = 1,
        enabled = cfg.enabled == true,
        style = VisualFeatures.PlayerTrail.styles[cfg.style] and cfg.style or "fire",
        width = math.Clamp(tonumber(cfg.width) or 14, 4, 32),
        lifetime = math.Clamp(tonumber(cfg.lifetime) or 1.4, 0.4, 4),
        density = math.Clamp(tonumber(cfg.density) or 1, 0.5, 2),
        intensity = math.Clamp(tonumber(cfg.intensity) or 1, 0.4, 2),
        particles = cfg.particles ~= false,
        glow = cfg.glow ~= false,
        throughWalls = cfg.throughWalls == true,
    }
    file.CreateDir(CLIENT_DATA_DIR)
    file.Write(VisualFeatures.PlayerTrail.configPath, util.TableToJSON(payload, true) or "{}")
end

function VisualFeatures.PlayerTrail.QueueSave()
    timer.Create(VisualFeatures.PlayerTrail.saveTimer, 0.25, 1, VisualFeatures.PlayerTrail.Save)
end

function VisualFeatures.PlayerTrail.Load()
    local raw = file.Read(VisualFeatures.PlayerTrail.configPath, "DATA")
    local data = raw and util.JSONToTable(raw) or nil
    if not istable(data) then return false end

    local cfg = VisualFeatures.PlayerTrail.config
    cfg.enabled = data.enabled == true
    if VisualFeatures.PlayerTrail.styles[data.style] then cfg.style = data.style end
    cfg.width = math.Clamp(tonumber(data.width) or 14, 4, 32)
    cfg.lifetime = math.Clamp(tonumber(data.lifetime) or 1.4, 0.4, 4)
    cfg.density = math.Clamp(tonumber(data.density) or 1, 0.5, 2)
    cfg.intensity = math.Clamp(tonumber(data.intensity) or 1, 0.4, 2)
    cfg.particles = data.particles ~= false
    cfg.glow = data.glow ~= false
    cfg.throughWalls = data.throughWalls == true
    return true
end

function VisualFeatures.PlayerTrail.Clear()
    VisualFeatures.PlayerTrail.points = {}
    VisualFeatures.PlayerTrail.footprints = {}
    VisualFeatures.PlayerTrail.lastSample = 0
    VisualFeatures.PlayerTrail.lastPos = nil
    VisualFeatures.PlayerTrail.lastFootPos = nil
    VisualFeatures.PlayerTrail.sampleCounter = 0
end

function VisualFeatures.PlayerTrail.Reset()
    VisualFeatures.PlayerTrail.config = {
        enabled = false,
        style = "fire",
        width = 14,
        lifetime = 1.4,
        density = 1,
        intensity = 1,
        particles = true,
        glow = true,
        throughWalls = false,
    }
    VisualFeatures.PlayerTrail.Clear()
    VisualFeatures.PlayerTrail.Save()
end

function VisualFeatures.PlayerTrail.AddFootprint(lp, now)
    local velocity = lp:GetVelocity()
    local planarSpeed = Vector(velocity.x, velocity.y, 0):Length()
    if not lp:OnGround() or planarSpeed < 45 then return end

    local origin = lp:GetPos()
    if VisualFeatures.PlayerTrail.lastFootPos
        and VisualFeatures.PlayerTrail.lastFootPos:DistToSqr(origin) < 784 then return end

    VisualFeatures.PlayerTrail.footSide = -VisualFeatures.PlayerTrail.footSide
    local sideOffset = lp:GetRight() * (VisualFeatures.PlayerTrail.footSide * 7)
    local traceStart = origin + sideOffset + Vector(0, 0, 18)
    local trace = util.TraceLine({
        start = traceStart,
        endpos = traceStart - Vector(0, 0, 72),
        filter = lp,
        mask = MASK_SOLID,
    })
    if not trace.Hit then return end

    local forward = lp:GetForward()
    forward.z = 0
    if forward:LengthSqr() < 0.001 then forward = Vector(1, 0, 0) else forward:Normalize() end
    table.insert(VisualFeatures.PlayerTrail.footprints, 1, {
        pos = trace.HitPos + trace.HitNormal * 0.8,
        normal = trace.HitNormal,
        forward = forward,
        time = now,
        side = VisualFeatures.PlayerTrail.footSide,
    })
    VisualFeatures.PlayerTrail.lastFootPos = Vector(origin.x, origin.y, origin.z)
    while #VisualFeatures.PlayerTrail.footprints > VisualFeatures.PlayerTrail.maxFootprints do
        table.remove(VisualFeatures.PlayerTrail.footprints)
    end
end

function VisualFeatures.PlayerTrail.AddPoint(lp, now)
    local density = math.Clamp(tonumber(VisualFeatures.PlayerTrail.config.density) or 1, 0.5, 2)
    if now - VisualFeatures.PlayerTrail.lastSample < 0.055 / density then return end

    local position = lp:GetPos() + Vector(0, 0, 34)
    if VisualFeatures.PlayerTrail.lastPos
        and VisualFeatures.PlayerTrail.lastPos:DistToSqr(position) > 160000 then
        VisualFeatures.PlayerTrail.Clear()
    end
    if VisualFeatures.PlayerTrail.lastPos
        and VisualFeatures.PlayerTrail.lastPos:DistToSqr(position) < 9 then return end

    VisualFeatures.PlayerTrail.sampleCounter = VisualFeatures.PlayerTrail.sampleCounter + 1
    table.insert(VisualFeatures.PlayerTrail.points, 1, {
        pos = Vector(position.x, position.y, position.z),
        time = now,
        right = lp:GetRight(),
        up = Vector(0, 0, 1),
        phase = VisualFeatures.PlayerTrail.sampleCounter * 0.79,
    })
    VisualFeatures.PlayerTrail.lastPos = Vector(position.x, position.y, position.z)
    VisualFeatures.PlayerTrail.lastSample = now
    while #VisualFeatures.PlayerTrail.points > VisualFeatures.PlayerTrail.maxPoints do
        table.remove(VisualFeatures.PlayerTrail.points)
    end
end

function VisualFeatures.PlayerTrail.Update()
    local lp = LocalPlayer()
    local cfg = VisualFeatures.PlayerTrail.config
    if not IsValid(lp)
        or not lp:Alive()
        or not cfg.enabled
        or not HasAccess(lp:SteamID(), "BODY_FX") then
        if #VisualFeatures.PlayerTrail.points > 0 or #VisualFeatures.PlayerTrail.footprints > 0 then
            VisualFeatures.PlayerTrail.Clear()
        end
        return
    end

    local now = CurTime()
    if cfg.style == "footsteps" then
        VisualFeatures.PlayerTrail.AddFootprint(lp, now)
    else
        VisualFeatures.PlayerTrail.AddPoint(lp, now)
    end

    local lifetime = math.Clamp(tonumber(cfg.lifetime) or 1.4, 0.4, 4)
    while VisualFeatures.PlayerTrail.points[#VisualFeatures.PlayerTrail.points]
        and now - VisualFeatures.PlayerTrail.points[#VisualFeatures.PlayerTrail.points].time > lifetime do
        table.remove(VisualFeatures.PlayerTrail.points)
    end
    while VisualFeatures.PlayerTrail.footprints[#VisualFeatures.PlayerTrail.footprints]
        and now - VisualFeatures.PlayerTrail.footprints[#VisualFeatures.PlayerTrail.footprints].time > lifetime do
        table.remove(VisualFeatures.PlayerTrail.footprints)
    end
end

function VisualFeatures.PlayerTrail.GetColor(styleKey, index, now)
    if styleKey == "rainbow" then
        return HSVToColor((now * 140 + index * 15) % 360, 1, 1)
    elseif styleKey == "footsteps" then
        return HSVToColor((now * 70 + index * 24) % 360, 0.75, 1)
    end
    local style = VisualFeatures.PlayerTrail.styles[styleKey] or {}
    if istable(style.palette) and #style.palette > 0 then
        local offset = math.floor(now * (style.paletteSpeed or 0))
        return style.palette[(index + offset - 1) % #style.palette + 1]
    end
    return style.color or color_white
end

function VisualFeatures.PlayerTrail.GetRenderPosition(point, styleKey, now, index)
    local lifetime = math.max(tonumber(VisualFeatures.PlayerTrail.config.lifetime) or 1.4, 0.01)
    local age = math.Clamp(now - point.time, 0, lifetime)
    local progress = math.Clamp(age / lifetime, 0, 1)
    local position = point.pos
    if styleKey == "fire" then
        position = position
            + point.up * (age * 34)
            + point.right * (math.sin(now * 8 + point.phase) * 5 * progress)
    elseif styleKey == "ice" then
        position = position + point.right * (math.sin(point.phase) * 2.5 * progress)
    elseif styleKey == "lightning" then
        position = position
            + point.right * (math.sin(now * 22 + point.phase) * 10 * progress)
            + point.up * (math.cos(now * 17 + index) * 6 * progress)
    elseif styleKey == "smoke" then
        position = position
            + point.up * (age * 28)
            + point.right * (math.sin(now * 2 + point.phase) * 12 * progress)
    end
    return position, 1 - progress, progress
end

function VisualFeatures.PlayerTrail.Draw()
    local lp = LocalPlayer()
    local cfg = VisualFeatures.PlayerTrail.config
    local style = VisualFeatures.PlayerTrail.styles[cfg.style]
    if not IsValid(lp)
        or not lp:Alive()
        or not cfg.enabled
        or not style
        or not HasAccess(lp:SteamID(), "BODY_FX") then return end

    local now = CurTime()
    local width = math.Clamp(tonumber(cfg.width) or 14, 4, 32)
    local intensity = math.Clamp(tonumber(cfg.intensity) or 1, 0.4, 2)
    local widthScale = math.sqrt(intensity)
    if cfg.throughWalls then cam.IgnoreZ(true) end

    if cfg.style == "footsteps" then
        render.SetMaterial(style.material)
        local lifetime = math.max(tonumber(cfg.lifetime) or 1.4, 0.01)
        for index, footprint in ipairs(VisualFeatures.PlayerTrail.footprints) do
            local fade = 1 - math.Clamp((now - footprint.time) / lifetime, 0, 1)
            local color = VisualFeatures.PlayerTrail.GetColor("footsteps", index, now)
            local rotation = footprint.forward:Angle().y
            render.DrawQuadEasy(
                footprint.pos,
                footprint.normal,
                width * 0.72 * widthScale,
                width * 1.55 * widthScale,
                Color(color.r, color.g, color.b, math.Clamp(math.floor(220 * fade * intensity), 0, 255)),
                rotation
            )
        end
    elseif cfg.style == "smoke" then
        render.SetMaterial(style.material)
        for index, point in ipairs(VisualFeatures.PlayerTrail.points) do
            if index % 2 == 1 then
                local position, fade, progress = VisualFeatures.PlayerTrail.GetRenderPosition(point, "smoke", now, index)
                local size = width * (0.75 + progress * 2.6) * widthScale
                render.DrawSprite(
                    position,
                    size,
                    size,
                    Color(145, 150, 160, math.Clamp(math.floor(120 * fade * intensity), 0, 255))
                )
            end
        end
    else
        render.SetMaterial(style.material)
        for index = 1, #VisualFeatures.PlayerTrail.points - 1 do
            local first = VisualFeatures.PlayerTrail.points[index]
            local second = VisualFeatures.PlayerTrail.points[index + 1]
            local posA, fadeA = VisualFeatures.PlayerTrail.GetRenderPosition(first, cfg.style, now, index)
            local posB, fadeB = VisualFeatures.PlayerTrail.GetRenderPosition(second, cfg.style, now, index + 1)
            local fade = math.min(fadeA, fadeB)
            local color = VisualFeatures.PlayerTrail.GetColor(cfg.style, index, now)
            render.DrawBeam(
                posA,
                posB,
                width * (0.35 + fade * 0.65) * widthScale,
                now * -1.5 + index * 0.05,
                now * -1.5 + (index + 1) * 0.05,
                Color(color.r, color.g, color.b, math.Clamp(math.floor(205 * fade * intensity), 0, 255))
            )

            if cfg.particles and cfg.style == "ice" and index % 5 == 0 then
                local shardDirection = first.right * math.sin(first.phase) + first.up * 0.65
                render.DrawBeam(
                    posA,
                    posA + shardDirection * width * 1.7,
                    math.max(1, width * 0.18),
                    0,
                    1,
                    Color(220, 250, 255, math.floor(180 * fade))
                )
            elseif cfg.particles and cfg.style == "lightning" and index % 4 == 0 then
                local sparkDirection = first.right * math.sin(now * 20 + first.phase)
                    + first.up * math.cos(now * 17 + first.phase)
                render.DrawBeam(
                    posA,
                    posA + sparkDirection * width * 1.45,
                    math.max(1, width * 0.13),
                    0,
                    1,
                    Color(225, 245, 255, math.floor(195 * fade))
                )
            end
        end

        render.SetMaterial(VisualFeatures.PlayerTrail.coreMaterial)
        for index = 1, #VisualFeatures.PlayerTrail.points - 1, 2 do
            local posA, fadeA = VisualFeatures.PlayerTrail.GetRenderPosition(
                VisualFeatures.PlayerTrail.points[index],
                cfg.style,
                now,
                index
            )
            local posB, fadeB = VisualFeatures.PlayerTrail.GetRenderPosition(
                VisualFeatures.PlayerTrail.points[index + 1],
                cfg.style,
                now,
                index + 1
            )
            local fade = math.min(fadeA, fadeB)
            local color = VisualFeatures.PlayerTrail.GetColor(cfg.style, index, now)
            render.DrawBeam(
                posA,
                posB,
                math.max(1, width * 0.22 * widthScale),
                0,
                1,
                Color(
                    math.floor((color.r + 255) * 0.5),
                    math.floor((color.g + 255) * 0.5),
                    math.floor((color.b + 255) * 0.5),
                    math.Clamp(math.floor(230 * fade * intensity), 0, 255)
                )
            )
        end

        if cfg.particles and cfg.style == "fire" then
            render.SetMaterial(VisualFeatures.PlayerTrail.glowMaterial)
            for index = 2, #VisualFeatures.PlayerTrail.points, 5 do
                local position, fade, progress = VisualFeatures.PlayerTrail.GetRenderPosition(
                    VisualFeatures.PlayerTrail.points[index],
                    "fire",
                    now,
                    index
                )
                local color = VisualFeatures.PlayerTrail.GetColor("fire", index + 1, now)
                local size = width * (0.35 + progress * 0.65) * widthScale
                render.DrawSprite(
                    position + Vector(0, 0, width * progress),
                    size,
                    size,
                    Color(color.r, color.g, color.b, math.floor(200 * fade))
                )
            end
        end
    end

    if cfg.glow then
        local sourcePosition
        local sourceColor
        if cfg.style == "footsteps" and VisualFeatures.PlayerTrail.footprints[1] then
            sourcePosition = VisualFeatures.PlayerTrail.footprints[1].pos
            sourceColor = VisualFeatures.PlayerTrail.GetColor("footsteps", 1, now)
        elseif VisualFeatures.PlayerTrail.points[1] then
            sourcePosition = VisualFeatures.PlayerTrail.points[1].pos
            sourceColor = VisualFeatures.PlayerTrail.GetColor(cfg.style, 1, now)
        end
        if sourcePosition and sourceColor then
            local light = DynamicLight(lp:EntIndex() * 64 + 29)
            if light then
                light.pos = sourcePosition
                light.r = sourceColor.r
                light.g = sourceColor.g
                light.b = sourceColor.b
                light.brightness = 1.1 * intensity
                light.decay = 650
                light.size = 95 + width * 4
                light.dietime = now + 0.08
            end
        end
    end

    if cfg.throughWalls then cam.IgnoreZ(false) end
end

VisualFeatures.Atmosphere.Load()
VisualFeatures.Weather.Load()
VisualFeatures.PlayerTrail.Load()

hook.Add("RenderScreenspaceEffects", VisualFeatures.Atmosphere.screenHook, VisualFeatures.Atmosphere.DrawPostProcess)
hook.Add("SetupWorldFog", VisualFeatures.Atmosphere.worldFogHook, function()
    return VisualFeatures.Atmosphere.SetupFog(1)
end)
hook.Add("SetupSkyboxFog", VisualFeatures.Atmosphere.skyFogHook, function(scale)
    return VisualFeatures.Atmosphere.SetupFog(scale)
end)
hook.Add("Think", VisualFeatures.Weather.thinkHook, VisualFeatures.Weather.Update)
hook.Add("PostDrawTranslucentRenderables", VisualFeatures.Weather.drawHook, function(_, drawingSkybox)
    if drawingSkybox then return end
    VisualFeatures.Weather.Draw()
end)
hook.Add("Think", VisualFeatures.PlayerTrail.thinkHook, VisualFeatures.PlayerTrail.Update)
hook.Add("PostDrawTranslucentRenderables", VisualFeatures.PlayerTrail.drawHook, function(_, drawingSkybox)
    if drawingSkybox then return end
    VisualFeatures.PlayerTrail.Draw()
end)

local function IsWhitelistAdmin()
    local lp = LocalPlayer()
    return IsValid(lp) and lp:SteamID() == ADMIN_STEAMID
end

local function IsValidSteamID(steamID)
    return isstring(steamID) and string.match(steamID, "^STEAM_%d:%d:%d+$") ~= nil
end

local function NormalizeUsageResult(result)
    result = string.lower(tostring(result or "success"))
    if result ~= "success" and result ~= "error" and result ~= "cancelled" and result ~= "info" then
        return "info"
    end
    return result
end

local usage_event_counter = 0

local function BuildUsageRow(action, detail, source, result, extra)
    local lp = LocalPlayer()
    usage_event_counter = usage_event_counter + 1
    local unixTime = os.time()
    local steamID64 = IsValid(lp) and lp:SteamID64() or "0"
    local safeAction = string.sub(tostring(action or "unknown"), 1, 64)
    local category = string.match(safeAction, "^([%w_%-]+)%.") or safeAction
    local serverName = "unknown"
    if isfunction(GetHostName) then
        serverName = string.sub(tostring(GetHostName() or "unknown"), 1, 96)
        if serverName == "" then serverName = "unknown" end
    end
    local row = {
        schema = 2,
        id = table.concat({
            steamID64,
            tostring(unixTime),
            tostring(math.floor(RealTime() * 1000)),
            tostring(usage_event_counter),
        }, "-"),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        unix = unixTime,
        steamid = IsValid(lp) and lp:SteamID() or "UNKNOWN",
        steamid64 = steamID64,
        nick = IsValid(lp) and lp:Nick() or "UNKNOWN",
        action = safeAction,
        category = string.sub(tostring(category or "unknown"), 1, 32),
        detail = string.sub(tostring(detail or ""), 1, 256),
        result = NormalizeUsageResult(result),
        map = game.GetMap() or "unknown",
        server = serverName,
        version = SCRIPT_VERSION,
        source = source or "game-client",
    }
    if istable(extra) and isstring(extra.command_id) and extra.command_id ~= "" then
        row.command_id = string.sub(extra.command_id, 1, 128)
    end
    return row
end

local function AppendLocalUsageLog(row)
    file.CreateDir("unisono_multitool")
    file.Append(LOCAL_USAGE_LOG_PATH, (util.TableToJSON(row, false) or "{}") .. "\n")
end

local QueuePeerLog = nil
local AppendAdminUsageLog = nil
local SyncAdminLogsToGist = nil

local function LogFeatureUsage(action, detail, result, extra)
    action = string.sub(tostring(action or "unknown"), 1, 64)
    detail = string.sub(tostring(detail or ""), 1, 256)
    local row = BuildUsageRow(
        action,
        detail,
        IsWhitelistAdmin() and "admin-client" or "game-client",
        result,
        extra
    )
    AppendLocalUsageLog(row)

    if IsWhitelistAdmin() and AppendAdminUsageLog then
        AppendAdminUsageLog(row)
        return row
    end

    if QueuePeerLog then QueuePeerLog(row) end
    return row
end

-- ==================== 6. ВАЙТЛИСТ ====================
local GIST_ID = "d09a1f52dd890d0bdf2245ad4e187db4"
local GIST_USER = "Hunteralook"
local GIST_FILENAME = "WhiteList.lua"
local GIST_LOGS_FILENAME = "usage_logs.json"
local GIST_COMMANDS_FILENAME = "client_commands.json"
local GIST_API_URL = "https://api.github.com/gists/" .. GIST_ID
local GIST_COMMANDS_RAW_URL = "https://gist.githubusercontent.com/" .. GIST_USER .. "/" .. GIST_ID .. "/raw/" .. GIST_COMMANDS_FILENAME
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
    if isstring(entry.id) and entry.id ~= "" then return entry.id end
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

local function SavePeerLogQueue()
    if IsWhitelistAdmin() then return end
    file.CreateDir(CLIENT_DATA_DIR)
    file.Write(PENDING_USAGE_LOG_PATH, util.TableToJSON(peer_log_queue, true) or "[]")
end

local function LoadPeerLogQueue()
    if IsWhitelistAdmin() then return end
    local loaded = util.JSONToTable(file.Read(PENDING_USAGE_LOG_PATH, "DATA") or "")
    if not istable(loaded) then return end
    for _, compact in ipairs(loaded) do
        if istable(compact) and isstring(compact.a) and tonumber(compact.t) then
            table.insert(peer_log_queue, {
                id = string.sub(tostring(compact.id or ""), 1, 128),
                a = string.sub(tostring(compact.a or "unknown"), 1, 64),
                d = string.sub(tostring(compact.d or ""), 1, 256),
                r = NormalizeUsageResult(compact.r),
                t = tonumber(compact.t) or os.time(),
                m = string.sub(tostring(compact.m or "unknown"), 1, 64),
                s = string.sub(tostring(compact.s or "unknown"), 1, 96),
                v = string.sub(tostring(compact.v or ""), 1, 64),
                c = string.sub(tostring(compact.c or ""), 1, 128),
            })
        end
    end
    while #peer_log_queue > PEER_LOG_QUEUE_MAX do table.remove(peer_log_queue, 1) end
end

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

QueuePeerLog = function(row)
    if not istable(row) then return end
    table.insert(peer_log_queue, {
        id = string.sub(tostring(row.id or ""), 1, 128),
        a = string.sub(tostring(row.action or "unknown"), 1, 64),
        d = string.sub(tostring(row.detail or ""), 1, 256),
        r = NormalizeUsageResult(row.result),
        t = tonumber(row.unix) or os.time(),
        m = string.sub(tostring(row.map or "unknown"), 1, 64),
        s = string.sub(tostring(row.server or "unknown"), 1, 96),
        v = string.sub(tostring(row.version or SCRIPT_VERSION), 1, 64),
        c = string.sub(tostring(row.command_id or ""), 1, 128),
    })
    while #peer_log_queue > PEER_LOG_QUEUE_MAX do table.remove(peer_log_queue, 1) end
    SavePeerLogQueue()
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
                    schema = 2,
                    id = string.sub(tostring(compact.id or ""), 1, 128),
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp),
                    unix = timestamp,
                    steamid = sender:SteamID(),
                    steamid64 = sender:SteamID64(),
                    nick = sender:Nick(),
                    action = action,
                    category = string.match(action, "^([%w_%-]+)%.") or action,
                    detail = detail,
                    result = NormalizeUsageResult(compact.r),
                    map = string.sub(tostring(compact.m or game.GetMap() or "unknown"), 1, 64),
                    server = string.sub(tostring(compact.s or "unknown"), 1, 96),
                    version = string.sub(tostring(compact.v or ""), 1, 64),
                    source = "client-peer",
                    command_id = string.sub(tostring(compact.c or ""), 1, 128),
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
    SavePeerLogQueue()
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
        LogFeatureUsage("whitelist." .. tostring(operation or "unknown"), "Нет доступа", "error")
        if callback then callback(false, "Нет доступа.") end
        return false
    end
    if (operation ~= "upsert" and operation ~= "remove") or not IsValidSteamID(steamID) then
        LogFeatureUsage("whitelist." .. tostring(operation or "unknown"), "Некорректный SteamID", "error")
        if callback then callback(false, "Некорректная операция или SteamID.") end
        return false
    end
    local payload = {
        operation = operation,
        steamid = steamID,
        permissions = permissions or {},
    }
    if not ApplyPeerMutation(payload, true) then
        LogFeatureUsage("whitelist." .. operation, steamID .. " • локальная ошибка", "error")
        if callback then callback(false, "Не удалось применить изменение.") end
        return false
    end
    BroadcastWhitelistMutation(operation, steamID, permissions, false)

    if not HasClientGitHubToken() then
        LogFeatureUsage("whitelist." .. operation, steamID .. " • только клиенты", "success")
        if callback then callback(true, "Изменение отправлено клиентам; GitHub token не настроен.") end
        return true
    end

    PersistWhitelistMutationToGist(operation, steamID, permissions, function(success, message)
        LogFeatureUsage(
            "whitelist." .. operation,
            steamID .. (success and " • GitHub + клиенты" or " • только клиенты"),
            success and "success" or "error"
        )
        if callback then callback(success, success and message or ("Между клиентами изменено, но GitHub не сохранён: " .. tostring(message))) end
    end)
    return true
end

-- ==================== 7. ВЫГРУЗКА ====================
function MultiTool_UnloadSelf(reason)
    SafeRemoveHook("Think", RuntimeHooks.Star)
    SafeRemoveHook("HUDPaint", RuntimeHooks.ESP)
    SafeRemoveHook("RenderScreenspaceEffects", RuntimeHooks.Shader)
    SafeRemoveHook("Think", RuntimeHooks.Key)
    SafeRemoveHook("Think", RuntimeHooks.RGB)
    SafeRemoveHook("PlayerDeath", RuntimeHooks.Stats .. "_Death")
    SafeRemoveHook("EntityTakeDamage", RuntimeHooks.Stats .. "_Damage")
    SafeRemoveHook("Think", RuntimeHooks.Stats .. "_Movement")
    SafeRemoveHook("DrawTranslucent", RuntimeHooks.Notes3D)
    SafeRemoveHook("PostDrawTranslucentRenderables", RuntimeHooks.Notes3D)
    SafeRemoveHook("HUDPaint", RuntimeHooks.Notes3DHUD)
    SafeRemoveHook("PostDrawTranslucentRenderables", RuntimeHooks.BodyFX)
    SafeRemoveHook("PreDrawSkyBox", SkyboxFeature.preDrawHook)
    SafeRemoveHook("PostDraw2DSkyBox", SkyboxFeature.postDrawHook)
    SafeRemoveHook("RenderScreenspaceEffects", VisualFeatures.Atmosphere.screenHook)
    SafeRemoveHook("SetupWorldFog", VisualFeatures.Atmosphere.worldFogHook)
    SafeRemoveHook("SetupSkyboxFog", VisualFeatures.Atmosphere.skyFogHook)
    SafeRemoveHook("Think", VisualFeatures.Weather.thinkHook)
    SafeRemoveHook("PostDrawTranslucentRenderables", VisualFeatures.Weather.drawHook)
    SafeRemoveHook("Think", VisualFeatures.PlayerTrail.thinkHook)
    SafeRemoveHook("PostDrawTranslucentRenderables", VisualFeatures.PlayerTrail.drawHook)
    SafeRemoveHook("OnScreenSizeChanged", "Unisono_StarFieldResize")
    SafeRemoveHook("PlayerBindPress", "Unisono_MenuBind")
    SafeRemoveHook("OnPauseMenuShow", MENU_ESCAPE_HOOK)
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
        BODY_FX_SAVE_TIMER,
        CLIENT_COMMAND_POLL_TIMER,
        SkyboxFeature.saveTimer,
        VisualFeatures.Atmosphere.saveTimer,
        VisualFeatures.Weather.saveTimer,
        VisualFeatures.PlayerTrail.saveTimer,
    }) do
        if timer.Exists(timerName) then timer.Remove(timerName) end
    end
    SaveWhitelistCache()
    SaveBodyFXConfig()
    SkyboxFeature.Save()
    VisualFeatures.Atmosphere.Save()
    VisualFeatures.Weather.Save()
    VisualFeatures.PlayerTrail.Save()
    if SaveProcessedClientCommands then SaveProcessedClientCommands() end
    ClearBodyFXTrails()
    VisualFeatures.Weather.Clear()
    VisualFeatures.PlayerTrail.Clear()
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
hook.Add("Think", RuntimeHooks.Star, function()
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
hook.Add("HUDPaint", RuntimeHooks.ESP, function()
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
hook.Add("RenderScreenspaceEffects", RuntimeHooks.Shader, function() if ActiveShader then ActiveShader(ActiveParams) end end)

-- ==================== 11. СТАТИСТИКА ====================
hook.Add("PlayerDeath", RuntimeHooks.Stats .. "_Death", function(victim, inflictor, attacker)
    if not HasAccess(LocalPlayer():SteamID(), "STATS") then return end
    if victim == LocalPlayer() then SessionStats.deaths = SessionStats.deaths + 1 end
    if attacker == LocalPlayer() and victim ~= LocalPlayer() then SessionStats.kills = SessionStats.kills + 1 end
end)
hook.Add("EntityTakeDamage", RuntimeHooks.Stats .. "_Damage", function(target, dmg)
    if not HasAccess(LocalPlayer():SteamID(), "STATS") then return end
    if target == LocalPlayer() then SessionStats.damageTaken = SessionStats.damageTaken + dmg:GetDamage() end
    local attacker = dmg:GetAttacker()
    if attacker == LocalPlayer() and target ~= LocalPlayer() then SessionStats.damageDealt = SessionStats.damageDealt + dmg:GetDamage() end
end)
hook.Add("Think", RuntimeHooks.Stats .. "_Movement", function()
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

hook.Add("PostDrawTranslucentRenderables", RuntimeHooks.Notes3D, function(_, drawingSkybox)
    if drawingSkybox then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not HasAccess(lp:SteamID(), "NOTES") then return end
    if #MapNotes == 0 then return end
    for _, note in ipairs(MapNotes) do
        local dist = lp:GetPos():Distance(note.pos)
        local maxD = note.maxDist or 2000
        if dist <= maxD then
            local markerPos, labelPos = GetNoteDrawPositions(note)
            local ang = (labelPos - lp:EyePos()):GetNormalized():Angle()
            ang = Angle(0, ang.y, 0)
            ang:RotateAroundAxis(ang:Up(), -90)
            ang:RotateAroundAxis(ang:Forward(), 90)
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
hook.Add("HUDPaint", RuntimeHooks.Notes3DHUD, function()
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

-- ==================== 12.5 ЭФФЕКТЫ НА ЧАСТЯХ ТЕЛА ====================
local function ResolveBodyFXBone(ply, candidates)
    for _, boneName in ipairs(candidates or {}) do
        local boneIndex = ply:LookupBone(boneName)
        if boneIndex then
            local pos = nil
            local matrix = ply:GetBoneMatrix(boneIndex)
            if matrix then pos = matrix:GetTranslation() end
            if not isvector(pos) then pos = ply:GetBonePosition(boneIndex) end
            if isvector(pos) then return pos, boneName end
        end
    end
    return nil, nil
end

local function AddBodyFXSample(state, ply, pos, now)
    if state.lastFrame == FrameNumber() then return end
    state.lastFrame = FrameNumber()
    if state.lastSample and now - state.lastSample < BODY_FX_SAMPLE_INTERVAL then return end

    if state.points[1] and state.points[1].pos:DistToSqr(pos) > 62500 then
        state.points = {}
    end

    state.sampleCounter = (state.sampleCounter or 0) + 1
    local velocity = ply:GetVelocity()
    local moveSpeed = velocity:Length()
    local driftDirection = moveSpeed > 40
        and velocity:GetNormalized() * -1
        or ply:GetForward() * -1
    local driftScale = moveSpeed > 40 and 0.28 or 1

    table.insert(state.points, 1, {
        pos = Vector(pos.x, pos.y, pos.z),
        time = now,
        direction = driftDirection,
        right = ply:GetRight(),
        up = Vector(0, 0, 1),
        driftScale = driftScale,
        phase = state.sampleCounter * 0.82,
    })
    state.lastSample = now

    while #state.points > BODY_FX_MAX_POINTS do
        table.remove(state.points)
    end
    while state.points[#state.points]
        and now - state.points[#state.points].time > BodyFXConfig.lifetime do
        table.remove(state.points)
    end
end

local function GetBodyFXRenderPoints(state, now, style)
    local output = {}
    local lifetime = math.max(BodyFXConfig.lifetime, 0.01)
    local maxProgress = math.Clamp(tonumber(style.maxProgress) or 1, 0.1, 1)
    for _, point in ipairs(state.points or {}) do
        local age = now - point.time
        if age <= lifetime then
            local progress = math.Clamp(age / lifetime, 0, 1)
            if progress <= maxProgress then
                local renderProgress = math.Clamp(progress / maxProgress, 0, 1)
                local fade = 1 - renderProgress
                local waveSize = BodyFXConfig.wiggle * renderProgress * (style.noise or 1)
                local phase = now * BodyFXConfig.speed + point.phase
                local wave = point.right * (math.sin(phase * 1.7) * waveSize)
                    + point.up * (math.cos(phase * 1.25) * waveSize * 0.7)
                local drift = point.direction
                    * (BodyFXConfig.length * renderProgress * (point.driftScale or 1))
                local lift = point.up
                    * (BodyFXConfig.length * renderProgress * (style.lift or 0))
                table.insert(output, {
                    pos = point.pos + drift + wave + lift,
                    fade = fade,
                    progress = renderProgress,
                    phase = phase,
                    right = point.right,
                    up = point.up,
                })
            end
        end
    end
    return output
end

local function GetBodyFXColor(style, segmentIndex, now)
    if style.rainbow then
        return HSVToColor((now * 150 + segmentIndex * 16) % 360, 1, 1)
    end
    if istable(style.palette) and #style.palette > 0 then
        local offset = math.floor(now * (style.paletteSpeed or 4))
        return style.palette[(segmentIndex + offset - 1) % #style.palette + 1]
    end
    return BodyFXConfig.color or Color(90, 180, 255)
end

local function DrawBodyFXTrail(state, lightIndex, now, style, renderStep, allowLight)
    local points = GetBodyFXRenderPoints(state, now, style)
    if #points == 0 then return end

    local intensity = math.Clamp(tonumber(BodyFXConfig.intensity) or 1, 0.35, 2.25)
    local widthScale = math.sqrt(intensity)
    local tailAlpha = math.Clamp(tonumber(style.tailAlpha) or 1, 0.1, 1)
    local step = math.max(math.floor(tonumber(renderStep) or 1), 1)
    local pulse = 0.88 + math.sin(now * 9 + lightIndex) * 0.12
    if #points >= 2 then
        render.SetMaterial(style.material)
        for i = 1, #points - step, step do
            local nextIndex = math.min(i + step, #points)
            local fade = math.min(points[i].fade, points[nextIndex].fade)
            local color = GetBodyFXColor(style, i, now)
            local alpha = math.Clamp(math.floor(220 * fade * fade * intensity * tailAlpha), 0, 255)
            local width = BodyFXConfig.width * (0.2 + fade * 0.8) * pulse * widthScale
            render.DrawBeam(
                points[i].pos,
                points[nextIndex].pos,
                width * 1.8,
                now * -2 + i * 0.08,
                now * -2 + nextIndex * 0.08,
                Color(color.r, color.g, color.b, alpha)
            )
        end

        render.SetMaterial(BodyFXCoreMaterial)
        for i = 1, #points - step, step do
            local nextIndex = math.min(i + step, #points)
            local fade = math.min(points[i].fade, points[nextIndex].fade)
            local color = GetBodyFXColor(style, i, now)
            local alpha = math.Clamp(math.floor(255 * fade * fade * intensity * tailAlpha), 0, 255)
            local width = BodyFXConfig.width * (0.12 + fade * 0.34) * pulse * widthScale
            render.DrawBeam(
                points[i].pos,
                points[nextIndex].pos,
                width,
                0,
                1,
                Color(
                    math.floor((color.r + 255) * 0.5),
                    math.floor((color.g + 255) * 0.5),
                    math.floor((color.b + 255) * 0.5),
                    alpha
                )
            )
        end

        if style.helix then
            render.SetMaterial(style.material)
            for strand = 0, 1 do
                for i = 1, #points - step, step do
                    local nextIndex = math.min(i + step, #points)
                    local first = points[i]
                    local second = points[nextIndex]
                    local phaseA = now * BodyFXConfig.speed * 1.8 + i * 0.72 + strand * math.pi
                    local phaseB = now * BodyFXConfig.speed * 1.8 + nextIndex * 0.72 + strand * math.pi
                    local radiusA = BodyFXConfig.width * first.fade * 1.15 * widthScale
                    local radiusB = BodyFXConfig.width * second.fade * 1.15 * widthScale
                    local offsetA = first.right * (math.cos(phaseA) * radiusA)
                        + first.up * (math.sin(phaseA) * radiusA)
                    local offsetB = second.right * (math.cos(phaseB) * radiusB)
                        + second.up * (math.sin(phaseB) * radiusB)
                    local color = GetBodyFXColor(style, i + strand, now)
                    render.DrawBeam(
                        first.pos + offsetA,
                        second.pos + offsetB,
                        BodyFXConfig.width * 0.42 * widthScale,
                        0,
                        1,
                        Color(color.r, color.g, color.b, math.floor(205 * first.fade))
                    )
                end
            end
        end

        if BodyFXConfig.particles and (style.sparks or style.shards) then
            render.SetMaterial(style.sparks and BodyFXCoreMaterial or style.material)
            local specialStep = math.max(step * (style.shards and 4 or 3), 3)
            for i = 2, math.min(#points, 28), specialStep do
                local point = points[i]
                local color = GetBodyFXColor(style, i + 1, now)
                local phase = now * BodyFXConfig.speed * 2.5 + i * 1.73 + lightIndex
                local side = point.right * math.sin(phase)
                    + point.up * math.cos(phase * 0.83)
                local branchSize = BodyFXConfig.width
                    * (style.shards and 2.8 or 2.1)
                    * point.fade
                    * intensity
                render.DrawBeam(
                    point.pos,
                    point.pos + side * branchSize,
                    BodyFXConfig.width * (style.shards and 0.24 or 0.16) * widthScale,
                    0,
                    1,
                    Color(color.r, color.g, color.b, math.floor(220 * point.fade))
                )
                if style.shards then
                    render.DrawBeam(
                        point.pos,
                        point.pos - side * branchSize * 0.65,
                        BodyFXConfig.width * 0.18 * widthScale,
                        0,
                        1,
                        Color(235, 250, 255, math.floor(175 * point.fade))
                    )
                end
            end
        end
    end

    local sourceColor = GetBodyFXColor(style, 1, now)
    local sourcePoint = points[1]

    if style.rings then
        render.SetMaterial(style.material)
        for ringIndex = 1, 2 do
            local ringProgress = (now * BodyFXConfig.speed * 0.35 + ringIndex * 0.5) % 1
            local ringRadius = BodyFXConfig.width
                * (1.2 + ringProgress * 4.5)
                * widthScale
            local ringAlpha = math.floor(230 * (1 - ringProgress) * intensity)
            for segment = 0, 15 do
                local angleA = segment * math.pi * 2 / 16
                local angleB = (segment + 1) * math.pi * 2 / 16
                local ringA = sourcePoint.pos
                    + sourcePoint.right * (math.cos(angleA) * ringRadius)
                    + sourcePoint.up * (math.sin(angleA) * ringRadius)
                local ringB = sourcePoint.pos
                    + sourcePoint.right * (math.cos(angleB) * ringRadius)
                    + sourcePoint.up * (math.sin(angleB) * ringRadius)
                render.DrawBeam(
                    ringA,
                    ringB,
                    math.max(1, BodyFXConfig.width * 0.2 * widthScale),
                    0,
                    1,
                    Color(sourceColor.r, sourceColor.g, sourceColor.b, math.Clamp(ringAlpha, 0, 255))
                )
            end
        end
    end

    if style.orbit then
        local orbitPoints = {}
        local orbitRadius = BodyFXConfig.width * 3.1 * widthScale
        for orbitIndex = 1, 3 do
            local angle = now * BodyFXConfig.speed * 0.85
                + orbitIndex * math.pi * 2 / 3
            orbitPoints[orbitIndex] = sourcePoint.pos
                + sourcePoint.right * (math.cos(angle) * orbitRadius)
                + sourcePoint.up * (math.sin(angle) * orbitRadius)
        end
        render.SetMaterial(style.material)
        for orbitIndex = 1, 3 do
            local nextIndex = orbitIndex % 3 + 1
            render.DrawBeam(
                orbitPoints[orbitIndex],
                orbitPoints[nextIndex],
                math.max(1, BodyFXConfig.width * 0.16 * widthScale),
                0,
                1,
                Color(sourceColor.r, sourceColor.g, sourceColor.b, 150)
            )
        end
        render.SetMaterial(BodyFXGlowMaterial)
        for orbitIndex = 1, 3 do
            local orbitColor = GetBodyFXColor(style, orbitIndex + 1, now)
            render.DrawSprite(
                orbitPoints[orbitIndex],
                BodyFXConfig.width * 1.15 * widthScale,
                BodyFXConfig.width * 1.15 * widthScale,
                Color(orbitColor.r, orbitColor.g, orbitColor.b, 220)
            )
        end
    end

    render.SetMaterial(BodyFXGlowMaterial)
    if BodyFXConfig.sourceGlow then
        render.DrawSprite(
            sourcePoint.pos,
            BodyFXConfig.width * 3.2 * widthScale,
            BodyFXConfig.width * 3.2 * widthScale,
            Color(
                sourceColor.r,
                sourceColor.g,
                sourceColor.b,
                math.Clamp(math.floor(235 * intensity), 0, 255)
            )
        )
    end
    if BodyFXConfig.particles then
        for i = 5, #points, 6 * step do
            local point = points[i]
            local pointColor = GetBodyFXColor(style, i, now)
            local size = BodyFXConfig.width * point.fade * 1.1 * widthScale
            render.DrawSprite(
                point.pos,
                size,
                size,
                Color(pointColor.r, pointColor.g, pointColor.b, math.floor(150 * point.fade))
            )
        end
    end
    if BodyFXConfig.particles and style.embers then
        for i = 2, math.min(#points, 26), math.max(3, step * 4) do
            local point = points[i]
            local emberColor = GetBodyFXColor(style, i + 2, now)
            local emberPhase = now * BodyFXConfig.speed + i * 2.17
            local emberPos = point.pos
                + point.right * (math.sin(emberPhase) * BodyFXConfig.width * 1.6)
                + point.up * (BodyFXConfig.width * (1.2 + point.progress * 4))
            local emberSize = math.max(1.5, BodyFXConfig.width * 0.48 * point.fade * widthScale)
            render.DrawSprite(
                emberPos,
                emberSize,
                emberSize,
                Color(emberColor.r, emberColor.g, emberColor.b, math.floor(210 * point.fade))
            )
        end
    end

    if BodyFXConfig.particles and style.rings then
        local burstCount = 6
        for burstIndex = 1, burstCount do
            local burstAngle = now * BodyFXConfig.speed
                + burstIndex * math.pi * 2 / burstCount
            local burstRadius = BodyFXConfig.width * 2.2 * widthScale
            local burstPos = sourcePoint.pos
                + sourcePoint.right * (math.cos(burstAngle) * burstRadius)
                + sourcePoint.up * (math.sin(burstAngle) * burstRadius)
            local burstSize = math.max(1.5, BodyFXConfig.width * 0.42 * widthScale)
            render.DrawSprite(
                burstPos,
                burstSize,
                burstSize,
                Color(sourceColor.r, sourceColor.g, sourceColor.b, 175)
            )
        end
    end

    if BodyFXConfig.dynamicLight and allowLight ~= false then
        local dlight = DynamicLight(lightIndex)
        if dlight then
            dlight.pos = sourcePoint.pos
            dlight.r = sourceColor.r
            dlight.g = sourceColor.g
            dlight.b = sourceColor.b
            dlight.brightness = 1.4 * intensity
            dlight.decay = 700
            dlight.size = (90 + BodyFXConfig.width * 5) * widthScale
            dlight.dietime = now + 0.08
        end
    end
end

hook.Add("PostDrawTranslucentRenderables", RuntimeHooks.BodyFX, function(_, drawingSkybox)
    if drawingSkybox then return end
    local lp = LocalPlayer()
    if not IsValid(lp)
        or not lp:Alive()
        or not BodyFXConfig.enabled
        or not HasAccess(lp:SteamID(), "BODY_FX") then
        if next(BodyFXTrails) ~= nil then ClearBodyFXTrails() end
        return
    end

    local preset = BodyFXBonePresets[BodyFXConfig.preset]
    local style = BodyFXStyles[BodyFXConfig.style]
    if not preset or not style then return end

    lp:SetupBones()
    local now = CurTime()
    if BodyFXConfig.throughWalls then cam.IgnoreZ(true) end

    for slotIndex, candidates in ipairs(preset.slots) do
        local pos, boneName = ResolveBodyFXBone(lp, candidates)
        if pos then
            local stateKey = tostring(BodyFXConfig.preset) .. ":" .. tostring(slotIndex)
            local state = BodyFXTrails[stateKey]
            if not state then
                state = {points = {}, boneName = boneName}
                BodyFXTrails[stateKey] = state
            end
            AddBodyFXSample(state, lp, pos, now)
            local renderStep = #preset.slots >= 6 and 2 or 1
            DrawBodyFXTrail(
                state,
                lp:EntIndex() * 32 + slotIndex,
                now,
                style,
                renderStep,
                slotIndex <= 4
            )
        end
    end

    if BodyFXConfig.throughWalls then cam.IgnoreZ(false) end
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
hook.Add("Think", RuntimeHooks.RGB, function()
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

-- ==================== 14.1. УПРАВЛЕНИЕ ВЕРСИЯМИ ====================
-- Панель может поставить в Gist только команду обновления. Произвольные
-- Lua/Cmd-команды намеренно не поддерживаются.
local processed_client_commands = {}
local processed_client_command_order = {}
local client_command_fetching = false

local function LoadProcessedClientCommands()
    processed_client_commands = {}
    processed_client_command_order = {}
    local rows = util.JSONToTable(file.Read(PROCESSED_COMMANDS_PATH, "DATA") or "")
    if not istable(rows) then return end
    for _, row in ipairs(rows) do
        local commandID = istable(row) and tostring(row.id or "") or tostring(row or "")
        if commandID ~= "" and #commandID <= 128 and not processed_client_commands[commandID] then
            processed_client_commands[commandID] = true
            table.insert(processed_client_command_order, commandID)
        end
    end
    while #processed_client_command_order > CLIENT_COMMAND_MAX_ENTRIES do
        local removed = table.remove(processed_client_command_order, 1)
        processed_client_commands[removed] = nil
    end
end

SaveProcessedClientCommands = function()
    local rows = {}
    for _, commandID in ipairs(processed_client_command_order) do
        table.insert(rows, {id = commandID})
    end
    file.CreateDir(CLIENT_DATA_DIR)
    file.Write(PROCESSED_COMMANDS_PATH, util.TableToJSON(rows, true) or "[]")
end

local function RememberProcessedClientCommands(commands)
    local changed = false
    for _, command in ipairs(commands or {}) do
        local commandID = tostring(command.id or "")
        if commandID ~= "" and not processed_client_commands[commandID] then
            processed_client_commands[commandID] = true
            table.insert(processed_client_command_order, commandID)
            changed = true
        end
    end
    while #processed_client_command_order > CLIENT_COMMAND_MAX_ENTRIES do
        local removed = table.remove(processed_client_command_order, 1)
        processed_client_commands[removed] = nil
        changed = true
    end
    if changed then SaveProcessedClientCommands() end
end

local function IsEligibleClientUpdateCommand(command, steamID, now)
    if not istable(command) then return false end
    local commandID = tostring(command.id or "")
    if commandID == "" or #commandID > 128 or not string.match(commandID, "^[%w%._%-]+$") then return false end
    if processed_client_commands[commandID] then return false end
    if tostring(command.action or "") ~= "client.force_update" then return false end
    if string.lower(tostring(command.issued_by or "")) ~= "hunteralook" then return false end

    local target = tostring(command.target or "")
    if target ~= "*" and target ~= steamID then return false end

    local createdUnix = tonumber(command.created_unix) or 0
    local expiresUnix = tonumber(command.expires_unix) or 0
    if createdUnix <= 0 or createdUnix > now + 300 then return false end
    if expiresUnix <= now or expiresUnix > createdUnix + 86400 then return false end
    return true
end

local function ExecuteClientUpdateCommand(command)
    local commandID = tostring(command.id or "")
    local issuedBy = string.sub(tostring(command.issued_by or "Hunteralook"), 1, 64)
    LogFeatureUsage(
        "client.update.received",
        "Принудительное обновление от " .. issuedBy,
        "info",
        {command_id = commandID}
    )
    chat.AddText(
        Color(100, 220, 255),
        "[Мульти-тул] ",
        Color(255, 255, 255),
        "Получена команда администратора на обновление клиента."
    )

    timer.Simple(0.75, function()
        if isfunction(_G.UnisonoMultiToolReload) then
            _G.UnisonoMultiToolReload()
            return
        end

        PerformScriptUpdate(function(body)
            LogFeatureUsage(
                "client.update.install",
                "Удалённая команда выполнена",
                "success",
                {command_id = commandID}
            )
            MultiTool_UnloadSelf("Старая версия выгружена по команде администратора.")
            RunString(body, "Multitool_RemoteUpdater", false)
        end, function(err)
            LogFeatureUsage(
                "client.update.install",
                string.sub(tostring(err), 1, 160),
                "error",
                {command_id = commandID}
            )
            Notify("Принудительное обновление не удалось: " .. tostring(err), true)
        end)
    end)
end

local function ProcessClientCommandList(commands)
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp.SteamID or lp:SteamID() == "STEAM_ID_PENDING" then return end
    if not istable(commands) or #commands > CLIENT_COMMAND_MAX_ENTRIES then return end

    local steamID = lp:SteamID()
    local now = os.time()
    local candidates = {}
    for _, command in ipairs(commands) do
        if IsEligibleClientUpdateCommand(command, steamID, now) then
            table.insert(candidates, command)
        end
    end
    if #candidates == 0 then return end

    table.sort(candidates, function(a, b)
        return (tonumber(a.created_unix) or 0) < (tonumber(b.created_unix) or 0)
    end)
    RememberProcessedClientCommands(candidates)
    ExecuteClientUpdateCommand(candidates[#candidates])
end

local function PollClientUpdateCommands()
    if client_command_fetching then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp.SteamID or lp:SteamID() == "STEAM_ID_PENDING" then return end

    client_command_fetching = true
    local separator = string.find(GIST_COMMANDS_RAW_URL, "?", 1, true) and "&" or "?"
    local url = GIST_COMMANDS_RAW_URL
        .. separator
        .. "t="
        .. tostring(os.time())
        .. "-"
        .. tostring(math.floor(SysTime() * 1000))
    http.Fetch(
        url,
        function(body, size, _, code)
            client_command_fetching = false
            if code ~= 200 or not isstring(body) or body == "" then return end
            if (tonumber(size) or #body) > 128 * 1024 then return end
            local commands = util.JSONToTable(body)
            ProcessClientCommandList(commands)
        end,
        function()
            client_command_fetching = false
        end,
        {["Cache-Control"] = "no-cache"}
    )
end

-- ==================== 15. UI BUILDERS ====================
-- Keep the entire menu UI in its own Lua function scope. Garry's Mod uses
-- LuaJIT/Lua 5.1, where one function may have at most 200 active locals.
-- Without this boundary, adding the client-version controls pushed the remote
-- chunk over that limit before ULXButton could be compiled.
local function InstallMenuUI()
local mainFrame = nil
local contentPanel = nil
local BuildWhitelistAdminPanel = nil
local BuildAdminPanel = nil
local menuEscapeConsumedUntil = 0

local function CloseMenuFromEscape()
    if not IsValid(mainFrame) or not mainFrame:IsVisible() then return false end

    menuEscapeConsumedUntil = RealTime() + 0.2
    mainFrame:Close()
    return true
end

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

    local suppressInitialSelectionLog = true
    list.OnRowSelected = function(lst, idx, pnl)
        ActivateShader(pnl.ShaderIndex)
        BuildShaderControls(pnl.ShaderIndex)
        if not suppressInitialSelectionLog then
            LogFeatureUsage("shader.select", ShadersConfig[pnl.ShaderIndex].name, "success")
        end
    end

    list:SelectItem(rows[ActiveShaderIndex] or rows[1])
    suppressInitialSelectionLog = false
end

-- 15.2 МИР: ОСВЕЩЕНИЕ, ПОГОДА И SKYBOX
local BuildWorldPanel = nil

local function BuildLightingWorldPanel(parent)
    ClearContent(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)
    local t = GetTheme()
    local cfg = VisualFeatures.Atmosphere.config

    ULXLabel(scroll, 16, 14, "Редактор освещения и тумана")

    local toggleButton
    toggleButton = ULXButton(scroll, 16, 42, 238, 30, "", function()
        cfg.enabled = not cfg.enabled
        VisualFeatures.Atmosphere.Save()
        LogFeatureUsage(
            "lighting.toggle",
            cfg.enabled and "Цветокоррекция включена" or "Цветокоррекция выключена",
            "success"
        )
        Notify(cfg.enabled and "Редактор освещения включён" or "Редактор освещения выключен")
    end)
    toggleButton.Paint = function(self, w, h)
        local theme = GetTheme()
        local color = cfg.enabled and theme.status or (self:IsHovered() and theme.btnHover or theme.btn)
        surface.SetDrawColor(color)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(
            "Освещение: " .. (cfg.enabled and "ВКЛ" or "ВЫКЛ"),
            "Unisono_ULXBtn",
            w / 2,
            h / 2,
            theme.btnText,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    ULXButton(scroll, 270, 42, 238, 30, "Сбросить освещение", function()
        VisualFeatures.Atmosphere.Reset()
        LogFeatureUsage("lighting.reset", "Освещение и пользовательский туман", "success")
        Notify("Освещение сброшено")
        timer.Simple(0, function()
            if IsValid(mainFrame) and BuildWorldPanel then BuildWorldPanel("lighting") end
        end)
    end)

    ULXLabel(scroll, 16, 86, "Цвет мира:")
    local colorButton = ULXButton(scroll, 148, 80, 360, 28, "", function()
        local dialog = vgui.Create("DFrame")
        dialog:SetSize(310, 275)
        dialog:Center()
        dialog:SetTitle("Цвет мира")
        dialog:MakePopup()

        local mixer = vgui.Create("DColorMixer", dialog)
        mixer:SetPos(10, 32)
        mixer:SetSize(290, 190)
        mixer:SetPalette(true)
        mixer:SetAlphaBar(false)
        mixer:SetWangs(true)
        mixer:SetColor(cfg.color)

        ULXButton(dialog, 105, 235, 100, 26, "Применить", function()
            local selected = mixer:GetColor()
            cfg.color = Color(selected.r, selected.g, selected.b)
            cfg.enabled = true
            VisualFeatures.Atmosphere.Save()
            LogFeatureUsage(
                "lighting.color",
                string.format("RGB %d, %d, %d", selected.r, selected.g, selected.b),
                "success"
            )
            dialog:Close()
        end)
    end)
    colorButton.Paint = function(self, w, h)
        local theme = GetTheme()
        local color = cfg.color or Color(255, 255, 255)
        surface.SetDrawColor(self:IsHovered() and theme.btnHover or theme.btn)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(color.r, color.g, color.b, 255)
        surface.DrawRect(6, 5, 36, h - 10)
        draw.SimpleText(
            string.format("RGB %d, %d, %d", color.r, color.g, color.b),
            "Unisono_ULXBtn",
            50,
            h / 2,
            theme.btnText,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    local function AddLightingSlider(y, title, key, minValue, maxValue, decimals)
        local slider = vgui.Create("DNumSlider", scroll)
        slider:SetPos(10, y)
        slider:SetSize(510, 34)
        slider:SetText(title)
        slider:SetMin(minValue)
        slider:SetMax(maxValue)
        slider:SetDecimals(decimals)
        slider:SetValue(cfg[key])
        slider.Label:SetTextColor(t.text)
        slider.OnValueChanged = function(_, value)
            cfg[key] = math.Clamp(value, minValue, maxValue)
            VisualFeatures.Atmosphere.QueueSave()
        end
    end

    AddLightingSlider(118, "Сила цвета", "tintStrength", 0, 1, 2)
    AddLightingSlider(154, "Яркость", "brightness", -0.5, 0.5, 2)
    AddLightingSlider(190, "Контраст", "contrast", 0.5, 2, 2)
    AddLightingSlider(226, "Насыщенность", "saturation", 0, 2, 2)

    local nightCheck = vgui.Create("DCheckBoxLabel", scroll)
    nightCheck:SetPos(16, 270)
    nightCheck:SetText("Ночной режим — затемнить мир и добавить холодный оттенок")
    nightCheck:SetTextColor(t.text)
    nightCheck:SetChecked(cfg.nightMode)
    nightCheck:SizeToContents()
    nightCheck.OnChange = function(_, checked)
        cfg.nightMode = checked == true
        VisualFeatures.Atmosphere.Save()
        LogFeatureUsage(
            "lighting.night",
            cfg.nightMode and "Ночной режим включён" or "Ночной режим выключен",
            "success"
        )
    end

    local fogCheck = vgui.Create("DCheckBoxLabel", scroll)
    fogCheck:SetPos(16, 302)
    fogCheck:SetText("Собственный локальный туман (имеет приоритет над погодой)")
    fogCheck:SetTextColor(t.text)
    fogCheck:SetChecked(cfg.fogEnabled)
    fogCheck:SizeToContents()
    fogCheck.OnChange = function(_, checked)
        cfg.fogEnabled = checked == true
        VisualFeatures.Atmosphere.Save()
        LogFeatureUsage(
            "lighting.fog",
            cfg.fogEnabled and "Пользовательский туман включён" or "Пользовательский туман выключен",
            "success"
        )
    end

    ULXLabel(scroll, 16, 342, "Цвет тумана:")
    local fogColorButton = ULXButton(scroll, 148, 336, 360, 28, "", function()
        local dialog = vgui.Create("DFrame")
        dialog:SetSize(310, 275)
        dialog:Center()
        dialog:SetTitle("Цвет тумана")
        dialog:MakePopup()

        local mixer = vgui.Create("DColorMixer", dialog)
        mixer:SetPos(10, 32)
        mixer:SetSize(290, 190)
        mixer:SetPalette(true)
        mixer:SetAlphaBar(false)
        mixer:SetWangs(true)
        mixer:SetColor(cfg.fogColor)

        ULXButton(dialog, 105, 235, 100, 26, "Применить", function()
            local selected = mixer:GetColor()
            cfg.fogColor = Color(selected.r, selected.g, selected.b)
            cfg.fogEnabled = true
            VisualFeatures.Atmosphere.Save()
            LogFeatureUsage(
                "lighting.fog",
                string.format("Цвет тумана RGB %d, %d, %d", selected.r, selected.g, selected.b),
                "success"
            )
            dialog:Close()
        end)
    end)
    fogColorButton.Paint = function(self, w, h)
        local theme = GetTheme()
        local color = cfg.fogColor or Color(155, 175, 195)
        surface.SetDrawColor(self:IsHovered() and theme.btnHover or theme.btn)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(color.r, color.g, color.b, 255)
        surface.DrawRect(6, 5, 36, h - 10)
        draw.SimpleText(
            string.format("RGB %d, %d, %d", color.r, color.g, color.b),
            "Unisono_ULXBtn",
            50,
            h / 2,
            theme.btnText,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    AddLightingSlider(374, "Начало тумана", "fogStart", 0, 5000, 0)
    AddLightingSlider(410, "Конец тумана", "fogEnd", 128, 12000, 0)
    AddLightingSlider(446, "Плотность тумана", "fogDensity", 0.05, 1, 2)

    local hint = vgui.Create("DLabel", scroll)
    hint:SetPos(16, 492)
    hint:SetSize(492, 42)
    hint:SetWrap(true)
    hint:SetText("Все изменения клиентские и сохраняются. Ночной режим, туман и цветокоррекция можно включать независимо.")
    hint:SetTextColor(Color(165, 180, 205))
    scroll:GetCanvas():SetTall(548)
end

local function BuildWeatherWorldPanel(parent)
    ClearContent(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)
    local t = GetTheme()
    local cfg = VisualFeatures.Weather.config

    ULXLabel(scroll, 16, 14, "Локальная погода вокруг игрока")

    local toggleButton
    toggleButton = ULXButton(scroll, 16, 42, 238, 30, "", function()
        cfg.enabled = not cfg.enabled
        VisualFeatures.Weather.Clear()
        VisualFeatures.Weather.Save()
        local preset = VisualFeatures.Weather.GetPreset()
        LogFeatureUsage(
            "weather.toggle",
            (cfg.enabled and "Включена" or "Выключена")
                .. " • " .. tostring(preset and preset.name or cfg.weather),
            "success"
        )
        Notify(cfg.enabled and "Локальная погода включена" or "Локальная погода выключена")
    end)
    toggleButton.Paint = function(self, w, h)
        local theme = GetTheme()
        local color = cfg.enabled and theme.status or (self:IsHovered() and theme.btnHover or theme.btn)
        surface.SetDrawColor(color)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(
            "Погода: " .. (cfg.enabled and "ВКЛ" or "ВЫКЛ"),
            "Unisono_ULXBtn",
            w / 2,
            h / 2,
            theme.btnText,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    ULXButton(scroll, 270, 42, 238, 30, "Очистить погоду", function()
        VisualFeatures.Weather.Reset()
        LogFeatureUsage("weather.reset", "Локальная погода", "success")
        Notify("Погода отключена и сброшена")
        timer.Simple(0, function()
            if IsValid(mainFrame) and BuildWorldPanel then BuildWorldPanel("weather") end
        end)
    end)

    ULXLabel(scroll, 16, 92, "Тип погоды:")
    local combo = vgui.Create("DComboBox", scroll)
    combo:SetPos(148, 86)
    combo:SetSize(360, 28)
    for _, key in ipairs(VisualFeatures.Weather.order) do
        local preset = VisualFeatures.Weather.presets[key]
        combo:AddChoice(preset.name, key, key == cfg.weather)
    end
    combo:SetValue((VisualFeatures.Weather.GetPreset() or {}).name or "Дождь")
    combo.OnSelect = function(_, _, _, key)
        if not VisualFeatures.Weather.presets[key] then return end
        cfg.weather = key
        VisualFeatures.Weather.Clear()
        VisualFeatures.Weather.Save()
        LogFeatureUsage("weather.type", VisualFeatures.Weather.presets[key].name, "success")
    end

    local function AddWeatherSlider(y, title, key, minValue, maxValue, decimals)
        local slider = vgui.Create("DNumSlider", scroll)
        slider:SetPos(10, y)
        slider:SetSize(510, 36)
        slider:SetText(title)
        slider:SetMin(minValue)
        slider:SetMax(maxValue)
        slider:SetDecimals(decimals)
        slider:SetValue(cfg[key])
        slider.Label:SetTextColor(t.text)
        slider.OnValueChanged = function(_, value)
            if decimals == 0 then value = math.Round(value) end
            cfg[key] = math.Clamp(value, minValue, maxValue)
            VisualFeatures.Weather.QueueSave()
        end
    end

    AddWeatherSlider(128, "Интенсивность", "intensity", 0.2, 2, 2)
    AddWeatherSlider(168, "Радиус вокруг игрока", "radius", 400, 1400, 0)
    AddWeatherSlider(208, "Сила ветра", "wind", 0, 2, 2)

    local lightningCheck = vgui.Create("DCheckBoxLabel", scroll)
    lightningCheck:SetPos(16, 256)
    lightningCheck:SetText("Локальный гром и вспышки для пресета «Гроза»")
    lightningCheck:SetTextColor(t.text)
    lightningCheck:SetChecked(cfg.lightning)
    lightningCheck:SizeToContents()
    lightningCheck.OnChange = function(_, checked)
        cfg.lightning = checked == true
        VisualFeatures.Weather.Save()
        LogFeatureUsage(
            "weather.option",
            cfg.lightning and "Гром и вспышки включены" or "Гром и вспышки выключены",
            "success"
        )
    end

    local roofCheck = vgui.Create("DCheckBoxLabel", scroll)
    roofCheck:SetPos(16, 288)
    roofCheck:SetText("Не рисовать осадки, когда над игроком есть крыша")
    roofCheck:SetTextColor(t.text)
    roofCheck:SetChecked(cfg.indoorCheck)
    roofCheck:SizeToContents()
    roofCheck.OnChange = function(_, checked)
        cfg.indoorCheck = checked == true
        VisualFeatures.Weather.nextRoofCheck = 0
        VisualFeatures.Weather.Save()
        LogFeatureUsage(
            "weather.option",
            cfg.indoorCheck and "Проверка крыши включена" or "Проверка крыши выключена",
            "success"
        )
    end

    local hint = vgui.Create("DLabel", scroll)
    hint:SetPos(16, 334)
    hint:SetSize(492, 58)
    hint:SetWrap(true)
    hint:SetText(
        "Доступны дождь, снег, гроза, пепел и песчаная буря. "
        .. "Погодный туман используется только пока пользовательский туман выключен."
    )
    hint:SetTextColor(Color(165, 180, 205))
    scroll:GetCanvas():SetTall(408)
end

local function BuildSkyboxWorldPanel(parent)
    ClearContent(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)
    local t = GetTheme()

    ULXLabel(scroll, 16, 14, "Локальная смена скайбокса")

    local description = vgui.Create("DLabel", scroll)
    description:SetPos(16, 38)
    description:SetSize(492, 38)
    description:SetWrap(true)
    description:SetText("Небо меняется только на этом клиенте. Остальные игроки продолжают видеть skybox карты.")
    description:SetTextColor(t.text)

    ULXLabel(scroll, 16, 86, "Готовый пресет:")
    local combo = vgui.Create("DComboBox", scroll)
    combo:SetPos(16, 108)
    combo:SetSize(492, 28)

    local selectedSky = SkyboxFeature.config.sky
    for _, preset in ipairs(SkyboxFeature.presets) do
        combo:AddChoice(
            preset.name .. "  •  " .. preset.sky,
            preset.sky,
            preset.sky == SkyboxFeature.config.sky
        )
    end

    ULXLabel(scroll, 16, 146, "Имя другого установленного skybox:")
    local customEntry = vgui.Create("DTextEntry", scroll)
    customEntry:SetPos(16, 168)
    customEntry:SetSize(492, 26)
    customEntry:SetText(SkyboxFeature.config.sky)
    customEntry:SetPlaceholderText("Например: sky_day01_01")

    combo.OnSelect = function(_, _, _, data)
        selectedSky = tostring(data or selectedSky)
        customEntry:SetText(selectedSky)
    end

    local yawSlider = vgui.Create("DNumSlider", scroll)
    yawSlider:SetPos(10, 204)
    yawSlider:SetSize(510, 38)
    yawSlider:SetText("Поворот по горизонту")
    yawSlider:SetMin(0)
    yawSlider:SetMax(360)
    yawSlider:SetDecimals(0)
    yawSlider:SetValue(SkyboxFeature.config.yaw)
    yawSlider.Label:SetTextColor(t.text)

    local brightnessSlider = vgui.Create("DNumSlider", scroll)
    brightnessSlider:SetPos(10, 246)
    brightnessSlider:SetSize(510, 38)
    brightnessSlider:SetText("Яркость")
    brightnessSlider:SetMin(0.2)
    brightnessSlider:SetMax(1)
    brightnessSlider:SetDecimals(2)
    brightnessSlider:SetValue(SkyboxFeature.config.brightness)
    brightnessSlider.Label:SetTextColor(t.text)

    local status = vgui.Create("DLabel", scroll)
    status:SetPos(16, 340)
    status:SetSize(492, 42)
    status:SetWrap(true)

    local function SetStatus(message, isError)
        if not IsValid(status) then return end
        status:SetText(message)
        status:SetTextColor(isError and Color(235, 90, 90) or Color(90, 225, 145))
    end

    local function ApplySelectedSky()
        local requestedSky = string.Trim(customEntry:GetValue())
        if requestedSky == "" then requestedSky = selectedSky end
        local ok, message = SkyboxFeature.Apply(
            requestedSky,
            yawSlider:GetValue(),
            brightnessSlider:GetValue()
        )
        if not ok then
            SetStatus("Не применено: " .. tostring(message), true)
            Notify(tostring(message), true)
            LogFeatureUsage("skybox.apply", tostring(requestedSky), "error")
            return
        end

        selectedSky = SkyboxFeature.config.sky
        customEntry:SetText(selectedSky)
        SetStatus(
            "Активно: " .. SkyboxFeature.GetDisplayName(selectedSky)
            .. " • поворот " .. tostring(math.floor(SkyboxFeature.config.yaw)) .. "°",
            false
        )
        Notify("Локальный skybox применён")
        LogFeatureUsage(
            "skybox.apply",
            SkyboxFeature.GetDisplayName(selectedSky)
                .. " • яркость " .. string.format("%.2f", SkyboxFeature.config.brightness),
            "success"
        )
    end

    ULXButton(scroll, 16, 296, 238, 30, "Применить локально", ApplySelectedSky)
    ULXButton(scroll, 270, 296, 238, 30, "Вернуть небо карты", function()
        local oldSky = SkyboxFeature.config.sky
        SkyboxFeature.Disable()
        SetStatus("Используется стандартное небо текущей карты.", false)
        Notify("Стандартное небо карты восстановлено")
        LogFeatureUsage("skybox.restore", SkyboxFeature.GetDisplayName(oldSky), "success")
    end)
    customEntry.OnEnter = ApplySelectedSky

    local hint = vgui.Create("DLabel", scroll)
    hint:SetPos(16, 394)
    hint:SetSize(492, 42)
    hint:SetWrap(true)
    hint:SetText("Пресеты используют установленные материалы GMod/Source; настройка сохраняется автоматически.")
    hint:SetTextColor(Color(170, 180, 195))

    if SkyboxFeature.config.enabled then
        local _, err = SkyboxFeature.ResolveMaterials(SkyboxFeature.config.sky)
        if err then
            SetStatus("Не удалось загрузить сохранённое небо: " .. err, true)
        else
            SetStatus("Активно: " .. SkyboxFeature.GetDisplayName(SkyboxFeature.config.sky), false)
        end
    else
        SetStatus("Используется стандартное небо текущей карты.", false)
    end
    scroll:GetCanvas():SetTall(452)
end

BuildWorldPanel = function(initialSection)
    ClearContent()
    local tabBar = vgui.Create("DPanel", contentPanel)
    tabBar:SetPos(10, 10)
    tabBar:SetSize(556, 30)
    tabBar.Paint = function(_, w, h)
        local t = GetTheme()
        surface.SetDrawColor(t.panel)
        surface.DrawRect(0, 0, w, h)
    end

    local worldContent = vgui.Create("DPanel", contentPanel)
    worldContent:SetPos(10, 48)
    worldContent:SetSize(556, 430)
    worldContent.Paint = function(_, w, h)
        local t = GetTheme()
        surface.SetDrawColor(t.content)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(t.border)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    local activeSection = nil
    local tabButtons = {}
    local builders = {
        lighting = BuildLightingWorldPanel,
        weather = BuildWeatherWorldPanel,
        skybox = BuildSkyboxWorldPanel,
    }
    local labels = {
        lighting = "Освещение",
        weather = "Погода",
        skybox = "Скайбокс",
    }
    local order = {"lighting", "weather", "skybox"}

    local function ShowSection(section)
        section = builders[section] and section or "lighting"
        activeSection = section
        builders[section](worldContent)
        for _, button in pairs(tabButtons) do
            if IsValid(button) then button:InvalidateLayout(true) end
        end
    end

    local x = 0
    for _, key in ipairs(order) do
        local sectionKey = key
        local label = labels[sectionKey]
        local button = ULXButton(tabBar, x, 0, 172, 30, label, function()
            ShowSection(sectionKey)
        end)
        button.Paint = function(self, w, h)
            local t = GetTheme()
            local color = activeSection == sectionKey
                and t.status
                or (self:IsHovered() and t.btnHover or t.btn)
            surface.SetDrawColor(color)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText(label, "Unisono_ULXBtn", w / 2, h / 2, t.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tabButtons[sectionKey] = button
        x = x + 178
    end

    ShowSection(initialSection or "lighting")
end

-- 15.3 ШРИФТЫ
local function BuildFontPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Настройки шрифтов")
    ULXButton(contentPanel, 20, 60, 200, 30, "Шрифт ESP", function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(300,130) dlg:Center() dlg:SetTitle("Шрифт ESP") dlg:MakePopup()
        local f = vgui.Create("DTextEntry", dlg) f:SetPos(10,30) f:SetSize(280,25) f:SetText(ESP_FontFamily)
        local s = vgui.Create("DNumSlider", dlg) s:SetPos(10,60) s:SetSize(280,30) s:SetText("Размер") s:SetMin(12) s:SetMax(60) s:SetDecimals(0) s:SetValue(ESP_FontSize)
        ULXButton(dlg, 100, 95, 100, 25, "Применить", function()
            local family = string.sub(string.Trim(f:GetValue()), 1, 64)
            local size = math.floor(s:GetValue())
            CreateESPFont(family, size)
            LogFeatureUsage("font.esp.apply", family .. " • " .. tostring(size) .. " px", "success")
            dlg:Close()
        end)
    end)
    ULXButton(contentPanel, 20, 100, 200, 30, "Шрифт Меню", function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(300,130) dlg:Center() dlg:SetTitle("Шрифт Меню") dlg:MakePopup()
        local f = vgui.Create("DTextEntry", dlg) f:SetPos(10,30) f:SetSize(280,25) f:SetText(Menu_FontFamily)
        local s = vgui.Create("DNumSlider", dlg) s:SetPos(10,60) s:SetSize(280,30) s:SetText("Размер") s:SetMin(12) s:SetMax(60) s:SetDecimals(0) s:SetValue(Menu_FontSize)
        ULXButton(dlg, 100, 95, 100, 25, "Применить", function()
            local family = string.sub(string.Trim(f:GetValue()), 1, 64)
            local size = math.floor(s:GetValue())
            CreateMenuFont(family, size)
            LogFeatureUsage("font.menu.apply", family .. " • " .. tostring(size) .. " px", "success")
            dlg:Close()
        end)
    end)
end

-- 15.4 ФИЗГАН
local function BuildPhysgunPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Физган")
    ULXButton(contentPanel, 20, 60, 220, 30, "Выдать физган", function()
        RunConsoleCommand("gm_giveswep", "weapon_physgun")
        LogFeatureUsage("physgun.give", "weapon_physgun", "success")
        Notify("Физган выдан")
    end)
    local btnRainbow
    btnRainbow = ULXButton(contentPanel, 20, 100, 220, 30, "Радужный: ВЫКЛ", function()
        Physgun_RainbowEnabled = not Physgun_RainbowEnabled
        btnRainbow.Paint = function(self,w2,h2)
            local th = GetTheme()
            local col = self:IsHovered() and th.btnHover or th.btn
            surface.SetDrawColor(col) surface.DrawRect(0,0,w2,h2)
            draw.SimpleText("Радужный: "..(Physgun_RainbowEnabled and "ВКЛ" or "ВЫКЛ"), "Unisono_ULXBtn", w2/2, h2/2, th.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        LogFeatureUsage(
            "physgun.rainbow",
            Physgun_RainbowEnabled and "Включён" or "Выключен",
            "success"
        )
        Notify(Physgun_RainbowEnabled and "Включён" or "Выключен")
    end)
end

-- 15.5 ЭФФЕКТЫ ТЕЛА И СЛЕД ИГРОКА
local BuildPlayerTrailPanel

local function BuildBodyFXPanel()
    ClearContent()
    local lp = LocalPlayer()
    if not IsValid(lp) or not HasAccess(lp:SteamID(), "BODY_FX") then
        ULXLabel(contentPanel, 20, 20, "Нет доступа к эффектам тела.", Color(220,70,70))
        return
    end

    local scroll = vgui.Create("DScrollPanel", contentPanel)
    scroll:Dock(FILL)
    ULXLabel(scroll, 20, 16, "Эффекты тела rawr >~<")
    local bodyTab = ULXButton(scroll, 286, 10, 118, 28, "На теле", function() end)
    bodyTab.Paint = function(_, w, h)
        local theme = GetTheme()
        surface.SetDrawColor(theme.status)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("На теле", "Unisono_ULXBtn", w / 2, h / 2, theme.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    ULXButton(scroll, 414, 10, 138, 28, "След игрока", function()
        BuildPlayerTrailPanel()
    end)

    local toggleButton
    toggleButton = ULXButton(scroll, 20, 46, 220, 30, "", function()
        BodyFXConfig.enabled = not BodyFXConfig.enabled
        ClearBodyFXTrails()
        SaveBodyFXConfig()
        local preset = BodyFXBonePresets[BodyFXConfig.preset]
        local style = BodyFXStyles[BodyFXConfig.style]
        LogFeatureUsage(
            "bodyfx.toggle",
            (BodyFXConfig.enabled and "Включён" or "Выключен")
                .. " • " .. tostring(preset and preset.name or BodyFXConfig.preset)
                .. " • " .. tostring(style and style.name or BodyFXConfig.style),
            "success"
        )
        Notify(BodyFXConfig.enabled and "Эффект тела включён" or "Эффект тела выключен")
    end)
    toggleButton.Paint = function(self, w, h)
        local t = GetTheme()
        local col = self:IsHovered() and t.btnHover or t.btn
        if BodyFXConfig.enabled then col = t.status end
        surface.SetDrawColor(col)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(
            "Эффект: " .. (BodyFXConfig.enabled and "ВКЛ" or "ВЫКЛ"),
            "Unisono_ULXBtn",
            w / 2,
            h / 2,
            t.btnText,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    ULXButton(scroll, 252, 46, 220, 30, "Очистить шлейф", function()
        ClearBodyFXTrails()
        LogFeatureUsage("bodyfx.clear", "История шлейфа очищена", "success")
        Notify("Шлейф очищен")
    end)

    local quickPresets = {
        lightning = {
            name = "Грозовые кулаки",
            preset = "both_hands", style = "electric", color = Color(80, 175, 255),
            width = 8, lifetime = 0.65, length = 115, wiggle = 18, speed = 15,
            intensity = 1.25, particles = true, sourceGlow = true, dynamicLight = true,
        },
        inferno = {
            name = "Инферно",
            preset = "all_extremities", style = "fire", color = Color(255, 120, 25),
            width = 13, lifetime = 1.15, length = 105, wiggle = 15, speed = 12,
            intensity = 1.55, particles = true, sourceGlow = true, dynamicLight = true,
        },
        frost_guard = {
            name = "Ледяной страж",
            preset = "arms", style = "frost", color = Color(110, 220, 255),
            width = 10, lifetime = 1.4, length = 135, wiggle = 6, speed = 5,
            intensity = 1.15, particles = true, sourceGlow = true, dynamicLight = true,
        },
        speedster = {
            name = "Сверхскорость",
            preset = "feet", style = "energy", color = Color(50, 210, 255),
            width = 11, lifetime = 1.05, length = 250, wiggle = 4, speed = 17,
            intensity = 1.35, particles = true, sourceGlow = true, dynamicLight = true,
        },
        cosmic = {
            name = "Космическая аура",
            preset = "full_body", style = "void", color = Color(165, 70, 255),
            width = 11, lifetime = 1.35, length = 90, wiggle = 10, speed = 7,
            intensity = 1.25, particles = true, sourceGlow = true, dynamicLight = false,
        },
        reactor = {
            name = "Импульсный реактор",
            preset = "head_chest", style = "pulse", color = Color(80, 255, 170),
            width = 9, lifetime = 0.75, length = 45, wiggle = 1, speed = 8,
            intensity = 1.45, particles = true, sourceGlow = true, dynamicLight = true,
        },
        plasma_core = {
            name = "Плазменное ядро",
            preset = "spine", style = "plasma", color = Color(255, 70, 220),
            width = 10, lifetime = 1.1, length = 100, wiggle = 8, speed = 11,
            intensity = 1.35, particles = true, sourceGlow = true, dynamicLight = true,
        },
        chaos = {
            name = "Хаотичный разряд",
            preset = "full_body", style = "sparks", color = Color(255, 70, 165),
            width = 7, lifetime = 0.65, length = 85, wiggle = 24, speed = 18,
            intensity = 1.25, particles = true, sourceGlow = true, dynamicLight = false,
        },
    }
    local quickPresetOrder = {
        "lightning", "inferno", "frost_guard", "speedster",
        "cosmic", "reactor", "plasma_core", "chaos",
    }

    ULXLabel(scroll, 20, 92, "Готовый пресет:")
    local quickCombo = vgui.Create("DComboBox", scroll)
    quickCombo:SetPos(165, 88)
    quickCombo:SetSize(307, 24)
    quickCombo:SetValue("Выбери готовый эффект")
    for _, key in ipairs(quickPresetOrder) do
        quickCombo:AddChoice(quickPresets[key].name, key)
    end
    quickCombo.OnSelect = function(_, _, _, key)
        local profile = quickPresets[key]
        if not profile then return end
        BodyFXConfig.enabled = true
        BodyFXConfig.preset = profile.preset
        BodyFXConfig.style = profile.style
        BodyFXConfig.color = Color(profile.color.r, profile.color.g, profile.color.b)
        BodyFXConfig.width = profile.width
        BodyFXConfig.lifetime = profile.lifetime
        BodyFXConfig.length = profile.length
        BodyFXConfig.wiggle = profile.wiggle
        BodyFXConfig.speed = profile.speed
        BodyFXConfig.intensity = profile.intensity
        BodyFXConfig.particles = profile.particles
        BodyFXConfig.sourceGlow = profile.sourceGlow
        BodyFXConfig.dynamicLight = profile.dynamicLight
        ClearBodyFXTrails()
        SaveBodyFXConfig()
        LogFeatureUsage(
            "bodyfx.preset",
            profile.name
                .. " • " .. BodyFXBonePresets[profile.preset].name
                .. " • " .. BodyFXStyles[profile.style].name,
            "success"
        )
        Notify("Пресет применён: " .. profile.name)
        timer.Simple(0, function()
            if IsValid(mainFrame) then BuildBodyFXPanel() end
        end)
    end

    ULXLabel(scroll, 20, 126, "Часть тела:")
    local presetCombo = vgui.Create("DComboBox", scroll)
    presetCombo:SetPos(165, 122)
    presetCombo:SetSize(307, 24)
    local presetOrder = {
        "right_hand", "left_hand", "both_hands", "forearms", "shoulders",
        "elbows", "head", "chest", "head_chest", "right_foot", "left_foot",
        "feet", "knees", "arms", "legs", "spine", "all_extremities", "full_body",
    }
    for _, key in ipairs(presetOrder) do
        presetCombo:AddChoice(BodyFXBonePresets[key].name, key)
    end
    presetCombo:SetValue(BodyFXBonePresets[BodyFXConfig.preset].name)
    presetCombo.OnSelect = function(_, _, _, key)
        if not BodyFXBonePresets[key] then return end
        BodyFXConfig.preset = key
        ClearBodyFXTrails()
        SaveBodyFXConfig()
        LogFeatureUsage("bodyfx.bone", BodyFXBonePresets[key].name, "success")
    end

    ULXLabel(scroll, 20, 160, "Стиль:")
    local styleCombo = vgui.Create("DComboBox", scroll)
    styleCombo:SetPos(165, 156)
    styleCombo:SetSize(307, 24)
    for _, key in ipairs({
        "electric", "energy", "rainbow", "plasma", "fire",
        "frost", "void", "pulse", "sparks",
    }) do
        styleCombo:AddChoice(BodyFXStyles[key].name, key)
    end
    styleCombo:SetValue(BodyFXStyles[BodyFXConfig.style].name)
    styleCombo.OnSelect = function(_, _, _, key)
        if not BodyFXStyles[key] then return end
        BodyFXConfig.style = key
        ClearBodyFXTrails()
        SaveBodyFXConfig()
        LogFeatureUsage("bodyfx.style", BodyFXStyles[key].name, "success")
    end

    ULXLabel(scroll, 20, 194, "Цвет основы:")
    local colorButton = ULXButton(scroll, 165, 190, 307, 26, "", function()
        local dialog = vgui.Create("DFrame")
        dialog:SetSize(300, 265)
        dialog:Center()
        dialog:SetTitle("Цвет эффекта")
        dialog:MakePopup()

        local mixer = vgui.Create("DColorMixer", dialog)
        mixer:SetPos(10, 32)
        mixer:SetSize(280, 185)
        mixer:SetPalette(true)
        mixer:SetAlphaBar(false)
        mixer:SetWangs(true)
        mixer:SetColor(BodyFXConfig.color)

        ULXButton(dialog, 100, 228, 100, 26, "Применить", function()
            local selected = mixer:GetColor()
            BodyFXConfig.color = Color(selected.r, selected.g, selected.b)
            SaveBodyFXConfig()
            LogFeatureUsage(
                "bodyfx.color",
                string.format("RGB %d, %d, %d", selected.r, selected.g, selected.b),
                "success"
            )
            dialog:Close()
        end)
    end)
    colorButton.Paint = function(self, w, h)
        local t = GetTheme()
        local c = BodyFXConfig.color
        surface.SetDrawColor(self:IsHovered() and t.btnHover or t.btn)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(c.r, c.g, c.b, 255)
        surface.DrawRect(6, 5, 34, h - 10)
        draw.SimpleText(
            string.format("RGB %d, %d, %d", c.r, c.g, c.b),
            "Unisono_ULXBtn",
            48,
            h / 2,
            t.btnText,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    local function AddBodyFXSlider(y, title, key, minValue, maxValue, decimals)
        local slider = vgui.Create("DNumSlider", scroll)
        slider:SetPos(14, y)
        slider:SetSize(500, 34)
        slider:SetText(title)
        slider:SetMin(minValue)
        slider:SetMax(maxValue)
        slider:SetDecimals(decimals)
        slider:SetValue(BodyFXConfig[key])
        slider.Label:SetTextColor(ThemeCol("text"))
        slider.OnValueChanged = function(_, value)
            if decimals == 0 then value = math.Round(value) end
            BodyFXConfig[key] = math.Clamp(value, minValue, maxValue)
            QueueBodyFXConfigSave()
        end
        return slider
    end

    AddBodyFXSlider(232, "Толщина", "width", 2, 30, 1)
    AddBodyFXSlider(270, "Время затухания", "lifetime", 0.2, 2.5, 2)
    AddBodyFXSlider(308, "Длина шлейфа", "length", 20, 260, 0)
    AddBodyFXSlider(346, "Изгиб / шум", "wiggle", 0, 30, 1)
    AddBodyFXSlider(384, "Скорость анимации", "speed", 1, 20, 1)
    AddBodyFXSlider(422, "Интенсивность", "intensity", 0.35, 2.25, 2)

    local function AddBodyFXCheck(y, text, key, action, enabledText, disabledText)
        local check = vgui.Create("DCheckBoxLabel", scroll)
        check:SetPos(20, y)
        check:SetText(text)
        check:SetTextColor(ThemeCol("text"))
        check:SetChecked(BodyFXConfig[key])
        check:SizeToContents()
        check.OnChange = function(_, checked)
            BodyFXConfig[key] = checked == true
            SaveBodyFXConfig()
            LogFeatureUsage(
                action,
                checked and enabledText or disabledText,
                "success"
            )
        end
    end

    AddBodyFXCheck(
        467,
        "Дополнительные частицы, искры и осколки",
        "particles",
        "bodyfx.option",
        "Дополнительные частицы включены",
        "Дополнительные частицы выключены"
    )
    AddBodyFXCheck(
        496,
        "Яркое свечение в точке крепления",
        "sourceGlow",
        "bodyfx.option",
        "Свечение кости включено",
        "Свечение кости выключено"
    )
    AddBodyFXCheck(
        525,
        "Освещать пространство вокруг кости",
        "dynamicLight",
        "bodyfx.light",
        "Динамический свет включён",
        "Динамический свет выключен"
    )
    AddBodyFXCheck(
        554,
        "Показывать эффект сквозь стены",
        "throughWalls",
        "bodyfx.visibility",
        "Сквозь стены",
        "Обычная глубина"
    )

    ULXLabel(
        scroll,
        20,
        590,
        "Эффект клиентский: его видишь ты. Лучше всего смотрится от третьего лица.",
        Color(165, 180, 205)
    )
    ULXLabel(
        scroll,
        20,
        613,
        "Огонь, лёд и пустота используют свои палитры; остальные — выбранный цвет.",
        Color(165, 180, 205)
    )
    ULXLabel(
        scroll,
        20,
        636,
        "На больших пресетах детализация автоматически снижается для стабильного FPS.",
        Color(165, 180, 205)
    )
    scroll:GetCanvas():SetTall(672)
end

-- 15.6 СЛЕД ЗА ИГРОКОМ
BuildPlayerTrailPanel = function()
    ClearContent()
    local lp = LocalPlayer()
    if not IsValid(lp) or not HasAccess(lp:SteamID(), "BODY_FX") then
        ULXLabel(contentPanel, 20, 20, "Нет доступа к следу игрока (право BODY_FX).", Color(220, 70, 70))
        return
    end

    local scroll = vgui.Create("DScrollPanel", contentPanel)
    scroll:Dock(FILL)
    local cfg = VisualFeatures.PlayerTrail.config
    local t = GetTheme()
    ULXLabel(scroll, 20, 16, "Эффекты тела rawr >~<")
    ULXButton(scroll, 286, 10, 118, 28, "На теле", function()
        BuildBodyFXPanel()
    end)
    local trailTab = ULXButton(scroll, 414, 10, 138, 28, "След игрока", function() end)
    trailTab.Paint = function(_, w, h)
        local theme = GetTheme()
        surface.SetDrawColor(theme.status)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("След игрока", "Unisono_ULXBtn", w / 2, h / 2, theme.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local toggleButton
    toggleButton = ULXButton(scroll, 20, 46, 158, 30, "", function()
        cfg.enabled = not cfg.enabled
        VisualFeatures.PlayerTrail.Clear()
        VisualFeatures.PlayerTrail.Save()
        local style = VisualFeatures.PlayerTrail.styles[cfg.style]
        LogFeatureUsage(
            "trail.toggle",
            (cfg.enabled and "Включён" or "Выключен")
                .. " • " .. tostring(style and style.name or cfg.style),
            "success"
        )
        Notify(cfg.enabled and "След игрока включён" or "След игрока выключен")
    end)
    toggleButton.Paint = function(self, w, h)
        local theme = GetTheme()
        local color = cfg.enabled and theme.status or (self:IsHovered() and theme.btnHover or theme.btn)
        surface.SetDrawColor(color)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(
            "След: " .. (cfg.enabled and "ВКЛ" or "ВЫКЛ"),
            "Unisono_ULXBtn",
            w / 2,
            h / 2,
            theme.btnText,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    ULXButton(scroll, 190, 46, 158, 30, "Очистить след", function()
        VisualFeatures.PlayerTrail.Clear()
        LogFeatureUsage("trail.clear", "История следа очищена", "success")
        Notify("След очищен")
    end)
    ULXButton(scroll, 360, 46, 158, 30, "Сбросить", function()
        VisualFeatures.PlayerTrail.Reset()
        LogFeatureUsage("trail.reset", "Настройки следа", "success")
        Notify("След игрока сброшен")
        timer.Simple(0, function()
            if IsValid(mainFrame) then BuildPlayerTrailPanel() end
        end)
    end)

    ULXLabel(scroll, 20, 96, "Стиль:")
    local combo = vgui.Create("DComboBox", scroll)
    combo:SetPos(150, 90)
    combo:SetSize(368, 28)
    for _, key in ipairs(VisualFeatures.PlayerTrail.order) do
        local style = VisualFeatures.PlayerTrail.styles[key]
        combo:AddChoice(style.name, key, key == cfg.style)
    end
    combo:SetValue((VisualFeatures.PlayerTrail.styles[cfg.style] or {}).name or "Огонь")
    combo.OnSelect = function(_, _, _, key)
        if not VisualFeatures.PlayerTrail.styles[key] then return end
        cfg.style = key
        VisualFeatures.PlayerTrail.Clear()
        VisualFeatures.PlayerTrail.Save()
        LogFeatureUsage("trail.style", VisualFeatures.PlayerTrail.styles[key].name, "success")
    end

    local function AddTrailSlider(y, title, key, minValue, maxValue, decimals)
        local slider = vgui.Create("DNumSlider", scroll)
        slider:SetPos(14, y)
        slider:SetSize(510, 36)
        slider:SetText(title)
        slider:SetMin(minValue)
        slider:SetMax(maxValue)
        slider:SetDecimals(decimals)
        slider:SetValue(cfg[key])
        slider.Label:SetTextColor(t.text)
        slider.OnValueChanged = function(_, value)
            cfg[key] = math.Clamp(value, minValue, maxValue)
            VisualFeatures.PlayerTrail.QueueSave()
        end
    end

    AddTrailSlider(132, "Толщина", "width", 4, 32, 1)
    AddTrailSlider(172, "Время затухания", "lifetime", 0.4, 4, 2)
    AddTrailSlider(212, "Плотность точек", "density", 0.5, 2, 2)
    AddTrailSlider(252, "Интенсивность", "intensity", 0.4, 2, 2)

    local function AddTrailCheck(y, text, key, enabledText, disabledText)
        local check = vgui.Create("DCheckBoxLabel", scroll)
        check:SetPos(20, y)
        check:SetText(text)
        check:SetTextColor(t.text)
        check:SetChecked(cfg[key])
        check:SizeToContents()
        check.OnChange = function(_, checked)
            cfg[key] = checked == true
            VisualFeatures.PlayerTrail.Save()
            LogFeatureUsage(
                "trail.option",
                checked and enabledText or disabledText,
                "success"
            )
        end
    end

    AddTrailCheck(
        302,
        "Дополнительные искры, осколки и огненные частицы",
        "particles",
        "Дополнительные частицы включены",
        "Дополнительные частицы выключены"
    )
    AddTrailCheck(
        332,
        "Локально освещать пространство у начала следа",
        "glow",
        "Свечение следа включено",
        "Свечение следа выключено"
    )
    AddTrailCheck(
        362,
        "Показывать след сквозь стены",
        "throughWalls",
        "След виден сквозь стены",
        "След учитывает глубину"
    )

    local hint = vgui.Create("DLabel", scroll)
    hint:SetPos(20, 406)
    hint:SetSize(500, 48)
    hint:SetWrap(true)
    hint:SetText(
        "Огонь, лёд, молнии, радуга и дым повторяют путь игрока. "
        .. "Светящиеся шаги ставятся попеременно на землю."
    )
    hint:SetTextColor(Color(165, 180, 205))
    scroll:GetCanvas():SetTall(470)
end

-- 15.7 СКРИПТЫ
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
            local ok, err = pcall(function()
                if not cv then error("CVar не найден") end
                cv:SetBool(val)
            end)
            LogFeatureUsage(
                "cvar.change",
                opt[2] .. "=" .. (val and "1" or "0"),
                ok and "success" or "error"
            )
            if not ok then
                Notify("Команда заблокирована сервером: "..opt[2], true)
            else
                Notify(opt[1]..": "..(val and "ВКЛ" or "ВЫКЛ"))
            end
        end
        y = y + 35
    end
    ULXLabel(panel, 20, y+10, "Примечание: если галочка не сохраняется — сервер блокирует CVAR.", ThemeCol("text"))
end

-- 15.7 ЛОКАЛЬНАЯ КОНСОЛЬ
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

        if command == "!help" then
            PrintLocalConsoleHelp()
            LogFeatureUsage("console.help", "Список встроенных команд", "success")
            return
        end

        if command == "!version" then
            LogToConsole(Color(100,200,255), "Текущая версия: " .. SCRIPT_VERSION)
            LogToConsole(Color(255,255,0), "Проверка обновлений...")
            CheckForUpdates(function(hasUpdate, remoteVersion, isLatest)
                if hasUpdate then
                    LogToConsole(Color(255,165,0), "Доступно обновление: " .. tostring(remoteVersion))
                    LogToConsole(Color(100,255,100), "Используйте !update для установки.")
                    LogFeatureUsage("update.check", "Доступна " .. tostring(remoteVersion), "info")
                elseif isLatest then
                    LogToConsole(Color(0,255,0), "Установлена последняя версия.")
                    LogFeatureUsage("update.check", "Установлена последняя версия", "success")
                else
                    LogToConsole(Color(255,100,100), "Не удалось проверить обновления.")
                    LogFeatureUsage("update.check", "Проверка не удалась", "error")
                end
            end)
            return
        end

        if command == "!whitelist" then
            if not IsWhitelistAdmin() then
                LogToConsole(Color(255,0,0), "У вас нет доступа к этой команде.")
                LogFeatureUsage("whitelist.open", "Нет доступа", "error")
                return
            end
            LogToConsole(Color(0,255,0), "Открываю Admin → Whitelist.")
            LogFeatureUsage("whitelist.open", "Открыта игровая панель", "success")
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
                LogFeatureUsage(
                    "whitelist.reload",
                    success and tostring(source) or "GitHub недоступен",
                    success and "success" or "error"
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
                LogFeatureUsage("update.install", "Обновление скачано", "success")
                MultiTool_UnloadSelf("Старая версия выгружена перед обновлением.")
                if IsValid(mainFrame) then mainFrame:Close() end
                RunString(body, "Multitool_Updater", false)
            end, function(err)
                LogToConsole(Color(255,0,0), "Ошибка обновления: " .. tostring(err))
                LogFeatureUsage("update.install", string.sub(tostring(err), 1, 160), "error")
            end)
            return
        end

        if command == "!stopsound" then
            RunConsoleCommand("stopsound")
            LogToConsole(Color(0,255,0), "[OK] Выполнено: stopsound")
            LogFeatureUsage("sound.stop", "stopsound", "success")
            return
        end

        if command == "!off" then
            LogToConsole(Color(255,140,0), "Скрипт будет выключен.")
            LogFeatureUsage("script.disable", "Команда !off", "success")
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
                LogFeatureUsage(
                    "console.lua",
                    "Локальная Lua-консоль; содержимое скрыто",
                    ok and "success" or "error"
                )
            else
                LogToConsole(Color(255,50,50), "[SYNTAX ERROR] " .. tostring(func))
                LogFeatureUsage("console.lua", "Ошибка синтаксиса; содержимое скрыто", "error")
            end
        else
            local ok, err = pcall(function() LocalPlayer():ConCommand(cmd) end)
            if ok then
                LogToConsole(Color(0,255,0), "[CMD] Отправлено")
            else
                LogToConsole(Color(255,50,50), "[BLOCKED] " .. tostring(err))
            end
            LogFeatureUsage(
                "console.command",
                "Клиентская команда; содержимое скрыто",
                ok and "success" or "error"
            )
        end
    end

    input.OnEnter = ExecuteConsoleInput
    ULXButton(contentPanel, 500, 345, 80, 24, "Выполнить", ExecuteConsoleInput)

    ULXButton(contentPanel, 20, 380, 120, 24, "Очистить", function() output:SetText("") end)
end

-- 15.8 УПРАВЛЕНИЕ WHITELIST
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

    local permissionOrder = {"ESP", "NOTES", "STATS", "BODY_FX", "NOT_WORKING"}
    local permissionLabels = {
        ESP = "ESP",
        NOTES = "3D Заметки",
        STATS = "Статистика",
        BODY_FX = "Эффекты тела",
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
            LogFeatureUsage(
                "whitelist.reload",
                success and tostring(source) or "GitHub недоступен",
                success and "success" or "error"
            )
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
            LogFeatureUsage(
                "github_token.save",
                "Локальное хранилище GMod; значение скрыто",
                success and "success" or "error"
            )
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
            LogFeatureUsage(
                "github_token.remove",
                "Локальное хранилище GMod",
                success and "success" or "error"
            )
            tokenStatus:SetText(message)
            tokenStatus:SetTextColor(success and Color(80,220,130) or Color(220,70,70))
            tokenStatus:SizeToContents()
            if success and IsValid(panel) and IsValid(list) then BuildWhitelistAdminPanel(panel) end
        end)
        ULXButton(dialog, 288, 94, 140, 26, "Закрыть", function() dialog:Close() end)
    end)

    ULXButton(panel, actionX2, footerY, actionWidth, 24, "Синхр. всем клиентам", function()
        local success, message = BroadcastWhitelistSnapshot()
        LogFeatureUsage(
            "whitelist.broadcast",
            success and "Снимок отправлен клиентам" or tostring(message),
            success and "success" or "error"
        )
        SetStatus(success and "Снимок whitelist отправляется клиентам." or tostring(message), not success)
    end)

    ULXButton(panel, actionX3, footerY, actionWidth3, 24, "Логи → GitHub", function()
        if not HasClientGitHubToken() then
            SetStatus("Сначала настройте GitHub token.", true)
            return
        end
        SyncAdminLogsToGist()
        LogFeatureUsage("logs.sync", "Поставлено в очередь GitHub", "info")
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

-- 15.9 Q-МЕНЮ
local function BuildQMenuPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Цвет Q-меню")
    local mixer = vgui.Create("DColorMixer", contentPanel)
    mixer:SetPos(20,50) mixer:SetSize(300,180)
    mixer:SetPalette(true) mixer:SetAlphaBar(false) mixer:SetWangs(true)
    mixer:SetColor(QMenu_CustomColor or Color(100,150,200))

    ULXButton(contentPanel, 20, 240, 140, 26, "Применить цвет", function()
        QMenu_CustomColor = mixer:GetColor()
        QMenu_RainbowEnabled = false
        ApplyQMenuColor(QMenu_CustomColor, false)
        LogFeatureUsage(
            "qmenu.color",
            string.format("RGB %d, %d, %d", QMenu_CustomColor.r, QMenu_CustomColor.g, QMenu_CustomColor.b),
            "success"
        )
        Notify("Цвет применён")
    end)
    ULXButton(contentPanel, 170, 240, 140, 26, "Радужный", function()
        QMenu_RainbowEnabled = true
        ApplyQMenuColor(nil, true)
        LogFeatureUsage("qmenu.rainbow", "Включён", "success")
        Notify("Радужный режим")
    end)
    ULXButton(contentPanel, 20, 275, 290, 26, "Сброс", function()
        QMenu_RainbowEnabled = false; QMenu_CustomColor = nil
        if IsValid(g_SpawnMenu) and g_SpawnMenu.OriginalPaint then g_SpawnMenu.Paint = g_SpawnMenu.OriginalPaint end
        LogFeatureUsage("qmenu.reset", "Стандартное оформление", "success")
        Notify("Сброшено")
    end)
end

local function SendSafeChatCommand(cmd)
    local safeTimer = GenSafeHook()
    LogFeatureUsage("chat.command", cmd, "success")
    timer.Create(safeTimer, 0.1, 1, function()
        RunConsoleCommand("say", cmd)
    end)
end

-- 15.10 ЧАТ
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

-- 15.11 3D ЗАМЕТКИ
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
                LogFeatureUsage("notes.copy_position", "Заметка #" .. tostring(noteLocal.id), "success")
                Notify("Координаты скопированы")
            end)
            ULXButton(row, 405, 4, 50, 18, "Удал.", function()
                table.remove(MapNotes, iLocal)
                LogFeatureUsage("notes.remove", "Заметка #" .. tostring(noteLocal.id), "success")
                RefreshNotesList()
                Notify("Заметка удалена")
            end)
            ULXButton(row, 350, 24, 105, 18, "Переимен.", function()
                local dlg = vgui.Create("DFrame") dlg:SetSize(300,90) dlg:Center() dlg:SetTitle("Редактировать") dlg:MakePopup()
                local e = vgui.Create("DTextEntry", dlg) e:SetPos(10,30) e:SetSize(280,22) e:SetText(noteLocal.text)
                ULXButton(dlg, 90, 60, 120, 22, "Сохранить", function()
                    local nt = string.Trim(e:GetValue())
                    if nt ~= "" then
                        noteLocal.text = nt
                        LogFeatureUsage("notes.rename", "Заметка #" .. tostring(noteLocal.id), "success")
                        RefreshNotesList()
                        dlg:Close()
                    else
                        LogFeatureUsage("notes.rename", "Пустое имя", "error")
                    end
                end)
            end)
        end
    end

    ULXButton(addPanel, 8, 104, 240, 22, "Поставить здесь", function()
        local text = string.Trim(entryText:GetValue())
        if text == "" then
            LogFeatureUsage("notes.create_here", "Пустой текст", "error")
            Notify("Введите текст!", true)
            return
        end
        local lp = LocalPlayer()
        if not IsValid(lp) then
            LogFeatureUsage("notes.create_here", "Игрок недоступен", "error")
            return
        end
        local noteID = MapNotes_NextID
        table.insert(MapNotes, { id=noteID, pos=lp:GetPos()+Vector(0,0,30), text=text,
            color=Color(selectedColor.r,selectedColor.g,selectedColor.b), maxDist=math.floor(sliderDist:GetValue()) })
        MapNotes_NextID = MapNotes_NextID + 1
        entryText:SetText("") RefreshNotesList()
        LogFeatureUsage("notes.create_here", "Заметка #" .. tostring(noteID), "success")
        Notify("Заметка добавлена")
    end)
    ULXButton(addPanel, 258, 104, 240, 22, "Поставить по прицелу", function()
        local text = string.Trim(entryText:GetValue())
        if text == "" then
            LogFeatureUsage("notes.create_aim", "Пустой текст", "error")
            Notify("Введите текст!", true)
            return
        end
        local lp = LocalPlayer()
        if not IsValid(lp) then
            LogFeatureUsage("notes.create_aim", "Игрок недоступен", "error")
            return
        end
        local tr = util.TraceLine({ start=lp:EyePos(), endpos=lp:EyePos()+lp:GetAimVector()*5000, filter=lp, mask=MASK_SOLID_BRUSHONLY })
        local hitPos = tr.Hit and tr.HitPos or (lp:EyePos()+lp:GetAimVector()*500)
        local noteID = MapNotes_NextID
        table.insert(MapNotes, { id=noteID, pos=hitPos+Vector(0,0,10), text=text,
            color=Color(selectedColor.r,selectedColor.g,selectedColor.b), maxDist=math.floor(sliderDist:GetValue()) })
        MapNotes_NextID = MapNotes_NextID + 1
        entryText:SetText("") RefreshNotesList()
        LogFeatureUsage("notes.create_aim", "Заметка #" .. tostring(noteID), "success")
        Notify("Заметка по прицелу добавлена")
    end)

    local btnClearAll = ULXButton(contentPanel, 10, 500, 150, 24, "Удалить все", function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(300,100) dlg:Center() dlg:SetTitle("Подтверждение") dlg:MakePopup()
        ULXLabel(dlg, 20, 30, "Удалить ВСЕ заметки?")
        ULXButton(dlg, 40, 60, 100, 24, "Да", function()
            local removedCount = #MapNotes
            MapNotes = {}
            LogFeatureUsage("notes.clear", "Удалено: " .. tostring(removedCount), "success")
            RefreshNotesList()
            dlg:Close()
            Notify("Все заметки удалены")
        end)
        ULXButton(dlg, 160, 60, 100, 24, "Отмена", function() dlg:Close() end)
    end)

    RefreshNotesList()
end

-- 15.12 СТАТИСТИКА
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
        LogFeatureUsage("stats.reset", "Статистика текущей сессии", "success")
        UpdateStats()
        Notify("Статистика сброшена")
    end)
    ULXButton(bp, 120, 5, 100, 28, "Обновить", UpdateStats)

    timer.Create("StatsUpdate_ULX", 1, 0, function()
        if IsValid(contentPanel) and contentPanel:IsVisible() then UpdateStats() else timer.Remove("StatsUpdate_ULX") end
    end)
end

-- 15.13 OOPS
local function BuildOopsPanel()
    ClearContent()
    ULXLabel(contentPanel, 20, 20, "Сброс настроек")
    local y = 60
    local function AddReset(text, action, fn)
        ULXButton(contentPanel, 20, y, 300, 28, text, function()
            local dlg = vgui.Create("DFrame") dlg:SetSize(320,100) dlg:Center()
            dlg:SetTitle("Подтверждение") dlg:MakePopup()
            ULXLabel(dlg, 20, 30, "Сбросить "..text.."?")
            ULXButton(dlg, 40, 60, 100, 24, "Да", function()
                fn()
                LogFeatureUsage(action, text, "success")
                dlg:Close()
                Notify(text.." сброшены")
            end)
            ULXButton(dlg, 180, 60, 100, 24, "Отмена", function() dlg:Close() end)
        end)
        y = y + 38
    end
    AddReset("Все настройки", "settings.reset_all", function()
        ESP_Enabled = false; ESP_MaxDistance = 1100
        ShaderStates = {}; ActiveShaderIndex = 1; ActivateShader(1)
        Physgun_RainbowEnabled = false; QMenu_RainbowEnabled = false; QMenu_CustomColor = nil
        BodyFXConfig.enabled = false
        BodyFXConfig.preset = "right_hand"
        BodyFXConfig.style = "electric"
        BodyFXConfig.color = Color(90, 180, 255)
        BodyFXConfig.width = 10
        BodyFXConfig.lifetime = 0.9
        BodyFXConfig.length = 125
        BodyFXConfig.wiggle = 10
        BodyFXConfig.speed = 8
        BodyFXConfig.intensity = 1
        BodyFXConfig.particles = true
        BodyFXConfig.sourceGlow = true
        BodyFXConfig.dynamicLight = true
        BodyFXConfig.throughWalls = false
        ClearBodyFXTrails()
        SaveBodyFXConfig()
        SkyboxFeature.Reset()
        VisualFeatures.Atmosphere.Reset()
        VisualFeatures.Weather.Reset()
        VisualFeatures.PlayerTrail.Reset()
        MapNotes = {}; MapNotes_NextID = 1
        SessionStats = { sessionStart=CurTime(), kills=0, deaths=0, damageTaken=0, damageDealt=0, distanceTraveled=0, jumps=0, lastPos=Vector(0,0,0), onGround=true }
        if IsValid(g_SpawnMenu) and g_SpawnMenu.OriginalPaint then g_SpawnMenu.Paint = g_SpawnMenu.OriginalPaint end
    end)
    AddReset("Только ESP", "esp.reset", function() ESP_Enabled = false; ESP_MaxDistance = 1100 end)
    AddReset("Только шейдеры", "shader.reset", function() ShaderStates = {}; ActiveShaderIndex = 1; ActivateShader(1) end)
    AddReset("Только мир", "world.reset", function()
        SkyboxFeature.Reset()
        VisualFeatures.Atmosphere.Reset()
        VisualFeatures.Weather.Reset()
    end)
    AddReset("Только след игрока", "trail.reset", VisualFeatures.PlayerTrail.Reset)
    AddReset("Только эффекты тела", "bodyfx.reset", function()
        BodyFXConfig.enabled = false
        BodyFXConfig.preset = "right_hand"
        BodyFXConfig.style = "electric"
        BodyFXConfig.color = Color(90, 180, 255)
        BodyFXConfig.width = 10
        BodyFXConfig.lifetime = 0.9
        BodyFXConfig.length = 125
        BodyFXConfig.wiggle = 10
        BodyFXConfig.speed = 8
        BodyFXConfig.intensity = 1
        BodyFXConfig.particles = true
        BodyFXConfig.sourceGlow = true
        BodyFXConfig.dynamicLight = true
        BodyFXConfig.throughWalls = false
        ClearBodyFXTrails()
        SaveBodyFXConfig()
    end)
    AddReset("Только заметки", "notes.clear", function() MapNotes = {}; MapNotes_NextID = 1 end)
end

-- 15.14 ТЕМЫ
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
            LogFeatureUsage("theme.apply", theme.name, "success")
            Notify("Тема '"..theme.name.."' применена к меню")
        end)
        y = y + 34
    end
    ULXLabel(contentPanel, 20, y+10, "Тема применяется ко всему интерфейсу мульти-тула.", ThemeCol("text"))
end

-- 15.15 ESP (!Не работает!)
local function BuildESPPanel()
    ClearContent()
    if not HasAccess(LocalPlayer():SteamID(), "NOT_WORKING") then
        ULXLabel(contentPanel, 20, 20, "Нет доступа к '!Не работает!'!", Color(200,50,50)) return
    end
    ULXLabel(contentPanel, 20, 20, "ESP / Wallhack")
    local btnToggle = ULXButton(contentPanel, 20, 60, 200, 28, "Вкл / Выкл ESP", function()
        ESP_Enabled = not ESP_Enabled
        LogFeatureUsage("esp.toggle", ESP_Enabled and "Включён" or "Выключен", "success")
        Notify(ESP_Enabled and "ESP Включён" or "ESP Выключен")
    end)
    ULXButton(contentPanel, 20, 100, 200, 28, "Дальность: "..ESP_MaxDistance, function()
        local dlg = vgui.Create("DFrame") dlg:SetSize(250,80) dlg:Center() dlg:SetTitle("Дальность ESP") dlg:MakePopup()
        local e = vgui.Create("DTextEntry", dlg) e:SetPos(10,35) e:SetSize(150,22) e:SetText(tostring(ESP_MaxDistance)) e:SetNumeric(true)
        ULXButton(dlg, 170, 35, 60, 22, "OK", function()
            local v = tonumber(e:GetValue())
            if v and v >= 200 then
                ESP_MaxDistance = v
                LogFeatureUsage("esp.distance", tostring(v), "success")
                dlg:Close()
                Notify("Дальность: "..v)
            else
                LogFeatureUsage("esp.distance", "Некорректное значение", "error")
            end
        end)
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
                ULXButton(p, 80, 180, 100, 24, "OK", function()
                    ESP_RoleColors[role] = m:GetColor()
                    LogFeatureUsage("esp.role_color", tostring(role), "success")
                    p:Close()
                end)
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
                LogFeatureUsage("esp.layout", elem .. "=" .. tostring(data), "success")
            end
            yOff = yOff + 40
        end
    end)
end

-- 15.16 ИССЛЕДОВАТЕЛЬ СЕРВЕРА
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
        if keyword == "" then return "Введите ключевое слово!\n", 0 end
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

        if #results == 0 then return "Ничего не найдено по запросу '"..keyword.."'\n", 0 end
        table.sort(results)
        return "=== Найдено "..#results.." результатов ===\n"..table.concat(results, "\n").."\n", #results
    end

    local function RunExplorerSearch()
        local text, count = ScanAndPrint(input:GetValue())
        AppendExplorer(text, Color(210, 230, 255))
        LogFeatureUsage("explorer.search", "Результатов: " .. tostring(count or 0), "success")
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
        LogFeatureUsage("explorer.physgun_scan", pg and "Физган найден" or "Физган не найден", pg and "success" or "error")
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
        LogFeatureUsage("explorer.hooks", "Событий: " .. tostring(#events), "success")
    end)
end

-- 15.17 ADMIN
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
            LogFeatureUsage("admin.command", "!whitelist", "success")
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
        if mainFrame:IsVisible() then
            mainFrame:Close()
        else
            mainFrame:SetVisible(true)
            mainFrame:MakePopup()
            LogFeatureUsage("menu.open", SCRIPT_VERSION, "success")
        end
        return
    end

    mainFrame = vgui.Create("DFrame")
    mainFrame:SetSize(780, 560)
    mainFrame:Center()
    mainFrame:SetTitle("Unisono Multi-Tool — "..SCRIPT_VERSION)
    mainFrame:SetDraggable(true) mainFrame:SetSizable(false)
    mainFrame:ShowCloseButton(true) mainFrame:MakePopup()
    mainFrame.OnKeyCodePressed = function(_, keyCode)
        if keyCode ~= KEY_ESCAPE then return end
        if not CloseMenuFromEscape() then return end

        timer.Simple(0, function()
            if gui.IsGameUIVisible() then gui.HideGameUI() end
        end)
    end

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
        {"Мир",             BuildWorldPanel},
        {"Настройки шрифта", BuildFontPanel},
        {"Физган",         BuildPhysgunPanel},
        {"Эффекты тела rawr >~<", BuildBodyFXPanel},
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
                LogFeatureUsage("update.install", "Обновление скачано", "success")
                Notify("Успешно! Перезагрузка...")
                MultiTool_UnloadSelf("Старая версия выгружена перед обновлением.")
                if IsValid(mainFrame) then mainFrame:Close() end
                RunString(body, "Multitool_Updater", false)
            end, function(err)
                LogFeatureUsage("update.install", string.sub(tostring(err), 1, 160), "error")
                Notify("Ошибка: "..tostring(err), true)
            end)
        end},
    }

    if IsWhitelistAdmin() then
        table.insert(categories, 6, {"Admin", BuildAdminPanel})
    end

    local y = 6
    for _, cat in ipairs(categories) do
        local name, builder = cat[1], cat[2]
        local btn = vgui.Create("DButton", leftPanel)
        btn:SetPos(6, y) btn:SetSize(168, 25) btn:SetText("")
        btn.Paint = function(self, w2, h2)
            local t = GetTheme()
            local col = self:IsHovered() and t.btnHover or t.btn
            surface.SetDrawColor(col) surface.DrawRect(0,0,w2,h2)
            draw.SimpleText(name, "Unisono_ULXBtn", w2/2, h2/2, t.btnText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            surface.PlaySound("buttons/button9.wav")
            builder()
        end
        y = y + 29
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
    LogFeatureUsage("menu.open", SCRIPT_VERSION, "success")
end

-- ==================== 17. БИНД И ЗАГРУЗКА ====================
concommand.Add("unisono_menu", ToggleMenu)

hook.Add("PlayerBindPress", "Unisono_MenuBind", function(ply, bind, pressed)
    if bind == "gm_showhelp" and pressed then ToggleMenu() return true end
end)

hook.Add("OnPauseMenuShow", MENU_ESCAPE_HOOK, function()
    if CloseMenuFromEscape() or RealTime() <= menuEscapeConsumedUntil then
        return false
    end
end)

end
InstallMenuUI()

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
        LoadPeerLogQueue()
        RequestPeerWhitelist()
    end
    LogFeatureUsage(
        "client.version",
        "Клиент готов • remote-update-v1",
        "info"
    )
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

LoadProcessedClientCommands()
timer.Create(CLIENT_COMMAND_POLL_TIMER, CLIENT_COMMAND_POLL_INTERVAL, 0, PollClientUpdateCommands)
timer.Simple(3, PollClientUpdateCommands)

_G.UnisonoMultiToolRuntimeVersion = SCRIPT_VERSION

chat.AddText(Color(100,200,255), "[Мульти-тул] ", Color(255,255,255), "Unisono Multi-Tool "..SCRIPT_VERSION.." загружен через HTTP. Бинд: F1")
print("[Unisono] Multi-Tool "..SCRIPT_VERSION.." loaded (Client Peer Edition, no custom server Lua).")
