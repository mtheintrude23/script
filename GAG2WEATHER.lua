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
-- MOON STYLES
-- ========================================================
local moonStyle = {
    ["Bloodmoon"]    = { color = 10027008, icon = "🔴", rare = true,  chance = "2%",  des = "A crimson moon that applies the Bloodlit mutation to nearby plants." },
    ["Goldmoon"]     = { color = 16766720, icon = "🌕", rare = true,  chance = "13%", des = "Spawns Golden Seeds and may grant Midas or turn nearby plants golden." },
    ["Rainbow Moon"] = { color = 10040063, icon = "🌈", rare = true,  chance = "6%",  des = "Spawns Rainbow Seeds and may grant Star-Powered, turn nearby plants rainbow, or spawn a Rainbow Pet." },
    ["Mega Moon"]    = { color = 255,      icon = "🌑", rare = true,  chance = "2%",  des = "A massive silver moon that spawns Mega Seeds randomly." },
    ["Moon"]         = { color = 1973021,  icon = "🌙", rare = false, chance = "79%", des = "Dark skybox, players can steal plants." },
    ["Day"]          = { color = 16765952, icon = "☀️", rare = false, chance = "",    des = "" },
    ["Sunset"]       = { color = 16744272, icon = "🌅", rare = false, chance = "",    des = "" },
}

-- ========================================================
-- HTTP SEND
-- ========================================================
local function sendRequest(body)
    local reqFunc = nil

    if typeof(http) == "table" and typeof(http.request) == "function" then
        reqFunc = function()
            local ok1, res1 = pcall(function()
                return http.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
            end)
            if ok1 then return res1 end
            return http.request({ url = WEBHOOK_URL, method = "POST", headers = { ["Content-Type"] = "application/json" }, body = body })
        end
    elseif typeof(request) == "function" then
        reqFunc = function()
            return request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end
    elseif typeof(http_request) == "function" then
        reqFunc = function()
            return http_request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end
    elseif syn and typeof(syn.request) == "function" then
        reqFunc = function()
            return syn.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end
    end

    if not reqFunc then
        return false, "No HTTP request function available in this executor."
    end

    local ok, result = pcall(reqFunc)

    if not ok then
        return false, "Request threw an error: " .. tostring(result)
    end

    if typeof(result) == "table" then
        local status = result.StatusCode or result.status
        local success = result.Success
        if success == false then
            return false, "Request failed: " .. tostring(result.StatusMessage or result.Body or "unknown error")
        end
        if status and (status < 200 or status >= 300) then
            return false, "HTTP " .. tostring(status) .. ": " .. tostring(result.Body or result.StatusMessage or "")
        end
    end

    return true, result
end

local function sendWebhook(payload)
    return sendRequest(HttpService:JSONEncode(payload))
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

    local ok, err = sendWebhook({
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
    if ok then
        print("[WEATHER] Sent -> " .. weatherName)
    else
        warn("[WEATHER] FAILED to send -> " .. weatherName .. " | " .. tostring(err))
    end
end

-- ========================================================
-- SEND MOON EVENT
-- ========================================================
local function sendMoonWebhook(moonName)
    local style = moonStyle[moonName] or { color = 16777215, icon = "🌙", rare = false, chance = "", des = "" }

    local now = os.time()
    local cycleTotal = 600
    local nightDuration = 120
    local posInCycle = now % cycleTotal
    local nightStart = 480
    local nightEnd = cycleTotal
    local secondsLeftInNight = nightEnd - posInCycle
    if secondsLeftInNight < 0 then secondsLeftInNight = 0 end
    local endUnix = now + secondsLeftInNight

    local endsField = "<t:" .. endUnix .. ":R> (<t:" .. endUnix .. ":F>)"
    local desc = style.des ~= "" and style.des or "No description."
    local chanceText = style.chance ~= "" and ("Spawn chance: **" .. style.chance .. "**") or ""

    local titlePrefix = style.rare and "Rare Moon" or "Moon Phase"

    local ok, err = sendWebhook({
        embeds = {{
            title       = style.icon .. " " .. titlePrefix .. ": " .. moonName .. "!",
            description = "**Description:** " .. desc .. (chanceText ~= "" and ("\n" .. chanceText) or ""),
            color       = style.color,
            fields      = {
                { name = "🌙 Night Ends:", value = endsField, inline = false },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer    = { text = "Grow a Garden 2 | Moon Monitor" },
        }}
    })
    if ok then
        print("[MOON] Sent -> " .. moonName)
    else
        warn("[MOON] FAILED to send -> " .. moonName .. " | " .. tostring(err))
    end
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

    for _, entry in ipairs(weatherDataList) do
        if WeatherValues:GetAttribute(entry.Name .. "_Playing") then
            local endUnix = WeatherValues:GetAttribute(entry.Name .. "_EndTime") or 0
            sendWeatherWebhook(entry.Name, endUnix)
        end
    end
end

-- ========================================================
-- MONITOR MOON via workspace.ActiveWeather attribute
-- BỎ DAY VÀ MOON (NIGHT THƯỜNG), CHỈ GỬI RARE MOON
-- ========================================================
local lastMoon = workspace:GetAttribute("ActiveWeather")

-- Check on start
if lastMoon and lastMoon ~= "Day" and lastMoon ~= "Moon" and lastMoon ~= "Sunset" then
    sendMoonWebhook(lastMoon)
end

workspace:GetAttributeChangedSignal("ActiveWeather"):Connect(function()
    local current = workspace:GetAttribute("ActiveWeather")
    if current and current ~= lastMoon then
        lastMoon = current
        
        -- Chỉ gửi webhook nếu KHÔNG phải Day, Night (Moon) hoặc Sunset
        if current ~= "Day" and current ~= "Moon" and current ~= "Sunset" then
            sendMoonWebhook(current)
        end
    end
end)

-- Also watch ActivePhase to catch night start
workspace:GetAttributeChangedSignal("ActivePhase"):Connect(function()
    local phase = workspace:GetAttribute("ActivePhase")
    if phase == "Night" then
        task.wait(1)
        local current = workspace:GetAttribute("ActiveWeather")
        if current and current ~= lastMoon then
            lastMoon = current
            
            -- Chống lặp và bỏ Day/Moon
            if current ~= "Day" and current ~= "Moon" and current ~= "Sunset" then
                sendMoonWebhook(current)
            end
        end
    end
end)

print("[WEATHER] Monitor running — watching weather events + rare moons only!")
