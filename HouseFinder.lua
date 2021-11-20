script_name("House Finder") 
script_author("Und3X")
script_version("0.2.0")
script_moonloader(20)
script_url("github.com/Und3X/HouseFinder")

-- Load libraries
local moonloader = require "moonloader"
local encoding = require "encoding"
local sampev = require "samp.events"
local sound_state = require "moonloader".audiostream_state

-- Default config structure
local SETTINGS = {
    AUTO_ENABLE = false,
    AUTO_ENTER = false,
    AUTO_BUY = false,
    SEND_DISTANCE = false
}

-- Glogal variables

local TAG = "{00CEF5}[HF]{FFFFFF}: "
local ENABLED = false
local ENTER = false
local ALARM_SOUND = loadAudioStream("moonloader\\HouseFinder\\audio\\alert.mp3")
local ALARM = true
local DIALOG_ID = 9195
local POINTS = {}
local HOUSES = {}

-- Load default settings
if not doesDirectoryExist("moonloader\\HouseFinder") then
    createDirectory("moonloader\\HouseFinder")
end
if not doesFileExist("moonloader\\HouseFinder\\settings.json") then
    settings_file = io.open("moonloader\\HouseFinder\\settings.json", "w")
    settings_file:write(encodeJson(SETTINGS))
    settings_file:close()
else
-- Load settings
    settings_file = io.open("moonloader\\HouseFinder\\settings.json", "r")
    SETTINGS = decodeJson(settings_file:read())
    settings_file:close()
end

-- Check exists files
if not doesFileExist("moonloader\\HouseFinder\\audio\\alert.mp3") then ALARM = false end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end
    repeat wait(0) until sampGetCurrentServerName() ~= "SA-MP"
    repeat wait(0) until sampGetCurrentServerName():find("Samp%-Rp.Ru") or sampGetCurrentServerName():find("SRP")

    -- !!!ONLY SRP SUPPORT!!!
    -- Check support server
    server = sampGetCurrentServerName():gsub("|", "")
    server =
        (server:find("02") and "Two" or
        (server:find("Revolution") and "Revolution" or
        (server:find("Legacy") and "Legacy" or 
        (server:find("Classic") and "Classic" or ""))))
    if server == "" then
        thisScript():unload()
    end

    ENABLED = SETTINGS.AUTO_ENABLE

    sampAddChatMessage("{00CEF5}House Finder " .. thisScript().version .. "{ffffff} загружен. Автор {00CEF5}Und3X{ffffff}. VK: {00CEF5}vk.com/und3x_mod",0xffffff)
    sampAddChatMessage(TAG .. "Состояние скрипта: "..(ENABLED and "{00FF00}включен{FFFFFF}" or "{FF0000}выключен{FFFFFF}"),0xffffff)
    sampAddChatMessage(TAG .. "Для "..(SETTINGS.AUTO_ENABLE and "{FF0000}выключения{FFFFFF}" or "{00FF00}включения{FFFFFF}").." скрипта введите {00CEF5}/hf",0xffffff)
    sampAddChatMessage(TAG .. "Меню настроек скрипта можно вызвать командой {00CEF5}/hf set",0xffffff)

    -- Register commands
    sampRegisterChatCommand("hf", cmd_settings)

    while true do
        wait(0)
        if SETTINGS.AUTO_ENTER and ENABLED then doCheckDistanceToPoint() end
    end
end

-- Commands
function cmd_settings(param)
    if param == "set" then
        local menu_items = {
            "Параметр\tЗначение\n",
            "{FFFFFF}Авто-включение при входе\t"..(SETTINGS.AUTO_ENABLE and "{00FF00}Включено{FFFFFF}" or "{FF0000}Выключено{FFFFFF}").."\n",
            "{FFFFFF}Автоматический вход в дом\t"..(SETTINGS.AUTO_ENTER and "{00FF00}Включено{FFFFFF}" or "{FF0000}Выключено{FFFFFF}").."\n",
            "{FFFFFF}Авто-покупка дома\t"..(SETTINGS.AUTO_BUY and "{00FF00}Включено{FFFFFF}" or "{FF0000}Выключено{FFFFFF}").."\n",
            "{FFFFFF}Сообщать дистанцию до дома\t"..(SETTINGS.SEND_DISTANCE and "{00FF00}Включено{FFFFFF}" or "{FF0000}Выключено{FFFFFF}").."\n",
            "______________________________\n",
            "{FFFFFF}Автор: {00CEF5}Und3X{FFFFFF}\n",
            "{FFFFFF}VK: {00CEF5}vk.com/und3x_mod{FFFFFF}\n"
        }
        menu = ""
        for key, value in pairs(menu_items) do
            menu = menu .. value .. "\n"
        end
        sampShowDialog(DIALOG_ID,"..::"..thisScript().name.." "..thisScript().version.." by Und3X::..", menu, "Сохранить", "Закрыть", 5)
        lua_thread.create(thread_cmd_settings)
    else
        ENABLED = not ENABLED
        sampAddChatMessage(TAG .. "Скрипт "..(ENABLED and "{00FF00}включен{FFFFFF}" or "{FF0000}выключен{FFFFFF}"),0xffffff)
    end
end

-- Events
function sampev.onCreatePickup(id, model, pickupType, position)
    if ENABLED then
        if model == 1273 then
            local X, Y, Z = getCharCoordinates(PLAYER_PED)
            local P = createCheckpoint(2, position.x, position.y, position.z, position.x, position.y, position.z, 3)
            local distance = string.format(math.ceil(getDistanceBetweenCoords3d(X,Y,Z,position.x, position.y, position.z)))
            sampAddChatMessage(TAG .. "{00FF00}Дом найден{FFFFFF}! Метка установлена. "..(SETTINGS.SEND_DISTANCE and "Дистанция: {00CEF5}")..distance.."{FFFFFF} м." or "", 0xFFFFFF)
            if ALARM then setAudioStreamState(ALARM_SOUND, sound_state.PLAY) end
            table.insert(POINTS, id, P)
            table.insert(HOUSES, id, position)
        end
    end
end

function sampev.onSendPickedUpPickup(id)
    deleteCheckpoint(POINTS[id])
    table.remove(POINTS, id)
    table.remove(HOUSES, id)
end

function sampev.onDestroyPickup(id)
    if POINTS[id] ~= nil then
        deleteCheckpoint(POINTS[id])
        table.remove(HOUSES, id)
        table.remove(POINTS, id)
        sampAddChatMessage(TAG .. "{FF0000}Вы покинули зону отрисовки{FFFFFF}! Метка убрана.", 0xFFFFFF)
    end
end

function sampev.onSetInterior(id)
    if SETTINGS.AUTO_ENTER and id == 0 then
        ENTER = true
        lua_thread.create(function()
            wait(5000)
            ENTER = false
        end)
    end
    if SETTINGS.AUTO_BUY and id ~= 0 then
        if ENTER then
            lua_thread.create(function()
                wait(600)
                sampSendChat("/buyhouse")
            end)
        end
    end
end

function sampev.onServerMessage(color, message)
    if message:find("^ Поздравляем с покупкой!$") then
        sampAddChatMessage(TAG .. "{00FF00}Поздравляем с покупкой госа{FFFFFF}! Поиск выключен!", 0xFFFFFF)
        ENABLED = false
        return false
    end
end

-- Threads
function thread_cmd_settings()
    while sampIsDialogActive(DIALOG_ID) do
        wait(0)
    end
    local result, button, list, input = sampHasDialogRespond(DIALOG_ID)
    if result then
        if button == 1 then
            local menu_item = tonumber(list)
            if menu_item == 0 then
                SETTINGS.AUTO_ENABLE = not SETTINGS.AUTO_ENABLE
                save_settings()
                cmd_settings("set")
            elseif menu_item == 1 then
                SETTINGS.AUTO_ENTER = not SETTINGS.AUTO_ENTER
                save_settings()
                cmd_settings("set")
            elseif menu_item == 2 then
                SETTINGS.AUTO_BUY = not SETTINGS.AUTO_BUY
                save_settings()
                cmd_settings("set")
            elseif menu_item == 3 then
                SETTINGS.SEND_DISTANCE = not SETTINGS.SEND_DISTANCE
                save_settings()
                cmd_settings("set")
            elseif menu_item == 6 then
                setClipboardText("https://vk.com/und3x_mod")
                sampAddChatMessage(TAG .. "Ссылка скопирована в буффер обмена!",0xffffff)
                cmd_settings("set")
            else
                cmd_settings("set")
            end
        end
    end
end

-- Procedures
function doCheckDistanceToPoint()
    local X, Y, Z = getCharCoordinates(PLAYER_PED)
    for id, value in pairs(HOUSES) do
        local distance = getDistanceBetweenCoords3d(X,Y,Z, HOUSES[id].x, HOUSES[id].y, HOUSES[id].z)
        if distance < 2.5 then
            if not ENTER then
                ENTER = true
                lua_thread.create(function()
                    sampSendChat("/enter")
                    wait(600)
                    ENTER = false
                end)
            end
        end
    end
end

-- Functions
function save_settings()
    settings_file = io.open("moonloader\\HouseFinder\\settings.json", "w")
    settings_file:write(encodeJson(SETTINGS))
    settings_file:close()
end