script_name("kent checker")
script_version("1.0.0")

local encoding = require("encoding")
encoding.default = "CP1251"
local u8 = encoding.UTF8

local inicfg = require 'inicfg'
local cjson = require("cjson")

-- GitHub update system
local GITHUB_REPO = "watersonc/kentchecker"
local GITHUB_RAW_URL = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/main/kentchecker.lua"
local GITHUB_API_URL = "https://api.github.com/repos/" .. GITHUB_REPO .. "/releases/latest"

local CONFIG_FILE = "friends.ini"
local DEFAULT_CONFIG = {
    version = {
        current = "1.0.0"
    },
    colors = {
        aqua = "0xAEEEEE",
        warning = "0xFFFACD",
        red = "0xFFB6C1",
        text = "0xFFF8F8FF",
        bg = "0x90E0FFFF"
    },
    commands = {
        list = "klist",
        update = "kupd",
        add = "kadd",
        reload = "kreload"
    },
    update = {
        enabled = true,
        auto_check = true
    },
    friends = {}
}

local config = {}
local kents = {}
local isListVisible = false
local FONT
local screenW, screenH = getScreenResolution()
local posX = screenW * 0.25
local posY = screenH * 0.5

-- Helper to convert string color to number
local function parseColor(str)
    if type(str) == "number" then return str end
    if type(str) ~= "string" then return 0xFFFFFFFF end
    if str:sub(1,2) == "0x" or str:sub(1,2) == "0X" then
        return tonumber(str)
    end
    return tonumber(str) or 0xFFFFFFFF
end

-- Load or create config
local function loadConfig()
    local success, err = pcall(function()
        if not doesFileExist(CONFIG_FILE) then
            inicfg.save(DEFAULT_CONFIG, CONFIG_FILE)
        end
        config = inicfg.load(nil, CONFIG_FILE)
        for section, values in pairs(DEFAULT_CONFIG) do
            if not config[section] then config[section] = {} end
            for k, v in pairs(values) do
                if config[section][k] == nil then
                    config[section][k] = v
                end
            end
        end
        inicfg.save(config, CONFIG_FILE)
    end)
    
    if not success then
        -- ���� �� ������� ��������� ������, ���������� �������� �� ���������
        config = DEFAULT_CONFIG
        if isSampAvailable() then
            sampAddChatMessage("������ �������� ������������, ������������ �������� �� ���������", COLOR_WARNING)
        end
    end
end

loadConfig()

-- Color constants from config
local COLOR_AQUA    = parseColor(config.colors.aqua)
local COLOR_WARNING = parseColor(config.colors.warning)
local COLOR_RED     = parseColor(config.colors.red)
local COLOR_TEXT    = parseColor(config.colors.text)
local COLOR_BG      = parseColor(config.colors.bg)

-- Command names from config
local CMD_LIST   = config.commands.list or "klist"
local CMD_UPDATE = config.commands.update or "kupd"
local CMD_ADD    = config.commands.add or "kadd"
local CMD_RELOAD = config.commands.reload or "kreload"

-- Friends list is stored in config.friends (as a table of [nick]=true)
local function reloadKents()
    kents = {}
    collectgarbage("collect")
    if config.friends then
        for nick, v in pairs(config.friends) do
            if v == true or v == "true" or v == 1 or v == "1" then
                kents[nick] = true
            end
        end
    end
    local count = 0
    for _ in pairs(kents) do count = count + 1 end
    if isSampAvailable() then
        sampAddChatMessage("��������� ������: " .. tostring(count), COLOR_AQUA)
    end
end

-- ������� greet ����� ������� � main() ����� �������� SAMP
local function greet()
    local info = ("%s %s by watersonc loaded!"):format(thisScript().name, config.version.current)
    sampAddChatMessage(info, COLOR_AQUA)
    sampAddChatMessage("- /"..CMD_LIST.." - ������ ������", COLOR_WARNING)
    sampAddChatMessage("- /"..CMD_UPDATE.." - ��������� ����������", COLOR_WARNING)
    sampAddChatMessage("- /"..CMD_UPDATE.." confirm - ���������� ����������", COLOR_WARNING)
    sampAddChatMessage("- /"..CMD_ADD.." [id|���] - �������� �����", COLOR_WARNING)
    sampAddChatMessage("- /"..CMD_RELOAD.." - ������������� ������ ������", COLOR_WARNING)
    if config.update.enabled and config.update.auto_check then
        sampAddChatMessage("�������� ���������� ��� ����� �� ������ ��������", COLOR_AQUA)
    end
end

local function onlineKents()
    local result = {"������ � ����:"}
    for pid = 0, 1000 do
        if sampIsPlayerConnected(pid) then
            local nick = sampGetPlayerNickname(pid)
            if kents[nick] then
                table.insert(result, ("[%d] %s"):format(pid, nick))
            end
        end
    end
    if #result == 1 then
        return "������ ��� � ����"
    end
    return table.concat(result, "\n")
end

local function showKentList()
    local msg = onlineKents()
    sampAddChatMessage(msg, COLOR_AQUA)
end

local function toggleKentList()
    isListVisible = not isListVisible
    if isListVisible then
        sampAddChatMessage("����� ������ �������", COLOR_AQUA)
    else
        sampAddChatMessage("����� ������ ��������", COLOR_AQUA)
    end
end

local function addKent(param)
    if not param or param == "" then
        sampAddChatMessage("�������������: /"..CMD_ADD.." [id|���]", COLOR_WARNING)
        return
    end

    local nick = nil
    local id = tonumber(param)
    if id then
        if not sampIsPlayerConnected(id) then
            sampAddChatMessage("����� � ����� ID �� ������!", COLOR_RED)
            return
        end
        nick = sampGetPlayerNickname(id)
    else
        nick = param
        local found = false
        for pid = 0, 1000 do
            if sampIsPlayerConnected(pid) then
                local playerNick = sampGetPlayerNickname(pid)
                if playerNick:lower() == nick:lower() then
                    nick = playerNick
                    found = true
                    break
                end
            end
        end
        if not found then
            nick = param
        end
    end

    nick = nick:gsub("%s+", "")
    if nick == "" then
        sampAddChatMessage("������������ ���!", COLOR_RED)
        return
    end

    if kents[nick] then
        sampAddChatMessage("���� ���� ��� ���� � ������!", COLOR_WARNING)
        return
    end

    config.friends[nick] = true
    inicfg.save(config, CONFIG_FILE)
    sampAddChatMessage("���� '" .. nick .. "' ��������!", COLOR_AQUA)
    reloadKents()
end

local function checkForUpdates()
    local requests = require("requests")
    local currentVersion = config.version.current or "1.0.0"
    
    local success, response = pcall(function()
        return requests.get(GITHUB_API_URL)
    end)
    
    if not success or not response or response.status_code ~= 200 then
        sampAddChatMessage("�� ������� ��������� ����������", COLOR_WARNING)
        return false, nil
    end
    
    local success2, data = pcall(function()
        return cjson.decode(response.text)
    end)
    
    if not success2 or not data or not data.tag_name then
        sampAddChatMessage("������ ��� ��������� ���������� �� �����������", COLOR_RED)
        return false, nil
    end
    
    local latestVersion = data.tag_name:gsub("v", "")
    if latestVersion > currentVersion then
        return true, latestVersion, data.html_url
    end
    return false, latestVersion
end

local function downloadUpdate()
    local requests = require("requests")
    sampAddChatMessage("�������� ����������...", COLOR_AQUA)
    
    local success, response = pcall(function()
        return requests.get(GITHUB_API_URL)
    end)
    
    if not success or not response or response.status_code ~= 200 then
        sampAddChatMessage("������ ��� ��������� ���������� �� ����������", COLOR_RED)
        return false
    end
    
    local success2, data = pcall(function()
        return cjson.decode(response.text)
    end)
    
    if not success2 or not data or not data.tag_name then
        sampAddChatMessage("������ ��� ��������� ���������� �� ����������", COLOR_RED)
        return false
    end
    
    local latestVersion = data.tag_name:gsub("v", "")
    
    local success3, scriptResponse = pcall(function()
        return requests.get(GITHUB_RAW_URL)
    end)
    
    if not success3 or not scriptResponse or scriptResponse.status_code ~= 200 then
        sampAddChatMessage("������ ��� �������� ����������", COLOR_RED)
        return false
    end
    
    -- ������� �����
    local backupName = "kentchecker_backup_" .. os.date("%Y%m%d_%H%M%S") .. ".lua"
    local currentContent = io.open(thisScript().path, "r")
    if currentContent then
        local content = currentContent:read("*all")
        currentContent:close()
        local backup = io.open(backupName, "w")
        if backup then
            backup:write(content)
            backup:close()
            sampAddChatMessage("������ �����: " .. backupName, COLOR_WARNING)
        end
    end
    
    -- ���������� ����� ������
    local file = io.open(thisScript().path, "w")
    if not file then
        sampAddChatMessage("������ ��� ������ �����", COLOR_RED)
        return false
    end
    file:write(scriptResponse.text)
    file:close()
    
    config.version.current = latestVersion
    inicfg.save(config, CONFIG_FILE)
    sampAddChatMessage("���������� ���������! ������ ��������� �� v" .. latestVersion, COLOR_AQUA)
    return true
end

local function updateCommand()
    local hasUpdate, latestVersion, downloadUrl = checkForUpdates()
    if hasUpdate then
        sampAddChatMessage("�������� ����������: v" .. latestVersion, COLOR_AQUA)
        sampAddChatMessage("�������: " .. (downloadUrl or "����������"), COLOR_WARNING)
        sampAddChatMessage("������� /" .. CMD_UPDATE .. " confirm ��� ���������", COLOR_WARNING)
        return
    else
        sampAddChatMessage("���������� �� �������", COLOR_AQUA)
        if latestVersion then
            sampAddChatMessage("������� ������: v" .. config.version.current .. " (���������: v" .. latestVersion .. ")", COLOR_WARNING)
        end
    end
end

local function confirmUpdate()
    if downloadUpdate() then
        sampAddChatMessage("������ ����� ����������� ����� 3 �������...", COLOR_AQUA)
        wait(3000)
        thisScript():reload()
    end
end

local function handleUpdateCommand(param)
    if param == "confirm" then
        confirmUpdate()
    else
        updateCommand()
    end
end

local function reloadFriendsCommand()
    reloadKents()
end

function main()
    while not isSampAvailable() do wait(3000) end
    FONT = renderCreateFont("Georgia", 8, 0)
    
    -- ��������� ������ ������ ����� ����������� � SAMP
    reloadKents()
    greet()

    -- ������������ ������� ��� GTA SAMP
    sampRegisterChatCommand(CMD_LIST, showKentList)
    sampRegisterChatCommand(CMD_UPDATE, handleUpdateCommand)
    sampRegisterChatCommand(CMD_ADD, addKent)
    sampRegisterChatCommand(CMD_RELOAD, reloadFriendsCommand)

    -- ���������� ������ ������ ��� �����
    showKentList()
    isListVisible = true

    -- �������� ���������� ��� �����
    if config.update.enabled and config.update.auto_check then
        wait(1000)
        local hasUpdate = checkForUpdates()
        if hasUpdate then
            sampAddChatMessage("�������� ����������! ������� /" .. CMD_UPDATE .. " ��� ���������", COLOR_AQUA)
        end
    end

    local lastServerCheck = ""

    while true do
        wait(0)

        -- �������� ���������� ��� ����������� � ������ �������
        if config.update.enabled and config.update.auto_check then
            local currentServer = sampGetCurrentServerAddress()
            if currentServer and currentServer ~= lastServerCheck then
                lastServerCheck = currentServer
                wait(2000)
                local hasUpdate = checkForUpdates()
                if hasUpdate then
                    sampAddChatMessage("�������� ����������! ������� /" .. CMD_UPDATE .. " ��� ���������", COLOR_AQUA)
                end
                -- ���������� ������ ������ ��� ����� �� ������
                showKentList()
                isListVisible = true
            end
        end

        -- ������ ������ ������ �� ������, ���� ��������
        if isListVisible then
            renderFontDrawText(FONT, onlineKents(), posX, posY, COLOR_TEXT, COLOR_BG)
        end
    end
end
