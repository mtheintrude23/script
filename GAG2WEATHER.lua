local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========================================================
-- WEBHOOK CONFIG
-- ========================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1485854014431297677/o-yBaZrpDraynVuE88XHQNNBIp_W9avOSxPqxIDBTN8HLm7YvKdVZTHCPZsYloLZiElz"
-- ========================================================

local rawModule = require(ReplicatedStorage.SharedModules.WeatherData)
local weatherDataList = rawModule.Data or {}

local function stripRichText(str)
    return (str:gsub("<[^>]+>", ""))
end

local function getWeatherInfo(weatherName)
    for _, entry in ipairs(weatherDataList) do
        if entry.Name == weatherName then
            return entry
        end
    end
    return {}
end

-- ========================================================
-- WEATHER STYLES (rain/storm events)
-- ========================================================
local weatherStyle = {
    ["Rain"]      = { color = 3447003,  icon = "🌧️" },
    ["Lightning"] = { color = 16776960, icon = "⚡" },
    ["Rainbow"]   = { color = 16711935, icon = "🌈" },
    ["Snowfall"]  = { color = 65535,    icon = "❄️" },
    ["Starfall"]  = { color = 10181046, icon = "💫" },
    ["Aurora"]    = { color = 5763719,  icon = "🌌" },
    ["Clear"]     = { color = 16753920, icon = "☀️" },
}

-- ========================================================
-- MOON STYLES (from TimeCycleData)
-- Only notify rare moons, skip normal Moon
-- ========================================================
local moonStyle = {
    ["Bloodmoon"]    = { color = 10027008, icon = "🔴", rare = true,  chance = "2%",  des = "A mysterious crimson moon rises. and applied bloodlit mutations." },
    ["Goldmoon"]     = { color = 16766720, icon = "🌕", rare = true,  chance = "13%", des = "A golden moon illuminates the garden and drop gold seeds." },
    ["Rainbow Moon"] = { color = 10040063, icon = "🌈", rare = true,  chance = "6%",  des = "A colorful rainbow moon shines and drop rainbow seeds." },
    ["Mega Moon"]    = { color = 255,      icon = "🌑", rare = true,  chance = "2%",  des = "Spawns mega seeds randomly." },
    ["Moon"]         = { color = 1973021,  icon = "🌙", rare = false, chance = "79%", des = "Dark skybox, players can steal plants." },
    ["Day"]          = { color = 16765952, icon = "☀️", rare = false, chance = "",    des = "" },
    ["Sunset"]       = { color = 16744272, icon = "🌅", rare = false, chance = "",    des = "" },
}

-- ========================================================
-- HTTP SEND
-- ========================================================
local function sendRequest(body)
    pcall(function()
        if typeof(http) == "table" and typeof(http.request) == "function" then
            http.request({ url = WEBHOOK_URL, method = "POST", headers = { ["Content-Type"] = "application/json" }, body = body })
        elseif typeof(request) == "function" then
            request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif typeof(http_request) == "function" then
            http_request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif syn and typeof(syn.request) == "function" then
            syn.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end
    end)
end

local function sendWebhook(payload)
    sendRequest(HttpService:JSONEncode(payload))
end

-- ========================================================
-- SEND WEATHER EVENT (Rain/Lightning etc)
-- ========================================================
local function sendWeatherWebhook(weatherName, endTimeUnix)
    local info  = getWeatherInfo(weatherName)
    local desc  = info.Description and stripRichText(info.Description) or "No description."
    local style = weatherStyle[weatherName] or { color = 16777215, icon = "🌤️" }

    local endsField = "Unknown"
    if endTimeUnix and endTimeUnix > 0 then
        endsField = "<t:" .. math.floor(endTimeUnix) .. ":R> (<t:" .. math.floor(endTimeUnix) .. ":F>)"
    end

    sendWebhook({
        embeds = {{
            title       = style.icon .. " Weather: " .. weatherName,
            description = "**Description:** " .. desc,
            color       = style.color,
            fields      = {
                { name = "⏳ Ends:", value = endsField, inline = false },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer    = { text = "Grow a Garden 2 | Weather Monitor" },
        }}
    })
    print("[WEATHER] Sent -> " .. weatherName)
end

-- ========================================================
-- SEND MOON EVENT
-- Only sends for rare moons (Bloodmoon, Goldmoon, Rainbow Moon, Mega Moon)
-- ========================================================
local function sendMoonWebhook(moonName)
    local style = moonStyle[moonName]
    if not style or not style.rare then return end

    -- Calculate night end time
    -- Night phase lasts 120s from TimeCycleData
    -- Day cycle total = 450+30+120 = 600s
    local now = os.time()
    local cycleTotal = 600
    local nightDuration = 120
    local posInCycle = now % cycleTotal
    -- Night starts at 480 (450+30), ends at 600
    local nightStart = 480
    local nightEnd = cycleTotal
    local secondsLeftInNight = nightEnd - posInCycle
    if secondsLeftInNight < 0 then secondsLeftInNight = 0 end
    local endUnix = now + secondsLeftInNight

    local endsField = "<t:" .. endUnix .. ":R> (<t:" .. endUnix .. ":F>)"
    local desc = style.des ~= "" and style.des or "No description."
    local chanceText = style.chance ~= "" and ("Spawn chance: **" .. style.chance .. "**") or ""

    sendWebhook({
        embeds = {{
            title       = style.icon .. " Rare Moon: " .. moonName .. "!",
            description = "**Description:** " .. desc .. (chanceText ~= "" and ("\n" .. chanceText) or ""),
            color       = style.color,
            fields      = {
                { name = "🌙 Night Ends:", value = endsField, inline = false },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer    = { text = "Grow a Garden 2 | Moon Monitor" },
        }}
    })
    print("[MOON] Sent -> " .. moonName)
end

-- ========================================================
-- MONITOR WeatherValues ATTRIBUTES (Rain/Lightning etc)
-- ========================================================
local WeatherValues = ReplicatedStorage:WaitForChild("WeatherValues", 10)
if not WeatherValues then
    warn("WeatherValues not found")
else
    local function hookWeather(weatherName)
        WeatherValues:GetAttributeChangedSignal(weatherName .. "_Playing"):Connect(function()
            if WeatherValues:GetAttribute(weatherName .. "_Playing") then
                local endUnix = WeatherValues:GetAttribute(weatherName .. "_EndTime") or 0
                sendWeatherWebhook(weatherName, endUnix)
            end
        end)
    end

    for _, entry in ipairs(weatherDataList) do
        hookWeather(entry.Name)
    end

    -- Check immediately if any weather already active
    for _, entry in ipairs(weatherDataList) do
        if WeatherValues:GetAttribute(entry.Name .. "_Playing") then
            local endUnix = WeatherValues:GetAttribute(entry.Name .. "_EndTime") or 0
            sendWeatherWebhook(entry.Name, endUnix)
        end
    end
end

-- ========================================================
-- MONITOR MOON via workspace.ActiveWeather attribute
-- TimeCycleController sets this each cycle
-- ========================================================
local rareMoons = { "Bloodmoon", "Goldmoon", "Rainbow Moon", "Mega Moon" }

local function isRareMoon(name)
    for _, m in ipairs(rareMoons) do
        if m == name then return true end
    end
    return false
end

local lastMoon = workspace:GetAttribute("ActiveWeather")

-- Check on start
if lastMoon and isRareMoon(lastMoon) then
    sendMoonWebhook(lastMoon)
end

workspace:GetAttributeChangedSignal("ActiveWeather"):Connect(function()
    local current = workspace:GetAttribute("ActiveWeather")
    if current and current ~= lastMoon then
        lastMoon = current
        if isRareMoon(current) then
            sendMoonWebhook(current)
        end
    end
end)

-- Also watch ActivePhase to catch night start
workspace:GetAttributeChangedSignal("ActivePhase"):Connect(function()
    local phase = workspace:GetAttribute("ActivePhase")
    if phase == "Night" then
        -- Re-check ActiveWeather when night starts
        task.wait(1) -- give server time to set ActiveWeather
        local current = workspace:GetAttribute("ActiveWeather")
        if current and isRareMoon(current) then
            lastMoon = current
            sendMoonWebhook(current)
        end
    end
end)

print("[WEATHER] Monitor running — watching weather events + rare moons...")
