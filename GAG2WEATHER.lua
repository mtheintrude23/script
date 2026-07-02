local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========================================================
-- WEBHOOK CONFIG (Updated to use Lewisakura Proxy)
-- ========================================================
local WEBHOOK_URL = "https://webhook.lewisakura.moe/api/webhooks/1485854014431297677/o-yBaZrpDraynVuE88XHQNNBIp_W9avOSxPqxIDBTN8HLm7YvKdVZTHCPZsYloLZiElz"
-- ========================================================

local SharedModules = ReplicatedStorage:WaitForChild("SharedModules", 10)
local WeatherDataModule = SharedModules and SharedModules:WaitForChild("WeatherData", 10)
local rawModule = WeatherDataModule and require(WeatherDataModule) or {}
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
-- WEATHER STYLES
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
    ["Bloodmoon"]    = { color = 10027008, icon = "🔴", rare = true,  chance = "2%",  des = "A mysterious crimson moon rises. and applied bloodlit mutations." },
    ["Goldmoon"]     = { color = 16766720, icon = "🌕", rare = true,  chance = "13%", des = "A golden moon illuminates the garden and drop gold seeds." },
    ["Rainbow Moon"] = { color = 10040063, icon = "🌈", rare = true,  chance = "6%",  des = "A colorful rainbow moon shines and drop rainbow seeds." },
    ["Mega Moon"]    = { color = 255,      icon = "🌑", rare = true,  chance = "2%",  des = "Spawns mega seeds randomly." },
    ["Moon"]         = { color = 1973021,  icon = "🌙", rare = false, chance = "79%", des = "Dark skybox, players can steal plants." },
    ["Day"]          = { color = 16765952, icon = "☀️", rare = false, chance = "",    des = "" },
    ["Sunset"]       = { color = 16744272, icon = "🌅", rare = false, chance = "",    des = "" },
}

-- ========================================================
-- HTTP SEND (Supports both Game Server and Executors)
-- ========================================================
local function sendRequest(body)
    local success, response = pcall(function()
        -- Handle native Roblox server requests
        if not syn and typeof(request) ~= "function" and typeof(http_request) ~= "function" then
            return HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end
        
        -- Handle Executor environment requests (if applicable)
        if typeof(http) == "table" and typeof(http.request) == "function" then
            return http.request({ url = WEBHOOK_URL, method = "POST", headers = { ["Content-Type"] = "application/json" }, body = body })
        elseif typeof(request) == "function" then
            return request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif typeof(http_request) == "function" then
            http_request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end
    end)

    if not success then
        warn("[WEBHOOK ERROR] Failed to send via Proxy: " .. tostring(response))
        return false
    end
    return true
end

local function sendWebhook(payload)
    return sendRequest(HttpService:JSONEncode(payload))
end

-- ========================================================
-- SEND WEATHER EVENT
-- ========================================================
local function sendWeatherWebhook(weatherName, endTimeUnix)
    local info  = getWeatherInfo(weatherName)
    local desc  = info.Description and stripRichText(info.Description) or "No description."
    local style = weatherStyle[weatherName] or { color = 16777215, icon = "🌤️" }

    local endsField = "Unknown"
    if endTimeUnix and endTimeUnix > 0 then
        endsField = "<t:" .. math.floor(endTimeUnix) .. ":R> (<t:" .. math.floor(endTimeUnix) .. ":F>)"
    end

    local payload = {
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
    }

    if sendWebhook(payload) then
        print("[WEATHER] Successfully sent via Proxy -> " .. weatherName)
    end
end

-- ========================================================
-- SEND MOON EVENT
-- ========================================================
local function sendMoonWebhook(moonName)
    local style = moonStyle[moonName]
    if not style or not style.rare then return end

    local now = os.time()
    local cycleTotal = 600
    local posInCycle = now % cycleTotal
    local nightEnd = cycleTotal
    local secondsLeftInNight = nightEnd - posInCycle
    if secondsLeftInNight < 0 then secondsLeftInNight = 0 end
    local endUnix = now + secondsLeftInNight

    local endsField = "<t:" .. endUnix .. ":R> (<t:" .. endUnix .. ":F>)"
    local desc = style.des ~= "" and style.des or "No description."
    local chanceText = style.chance ~= "" and ("Spawn chance: **" .. style.chance .. "**") or ""

    local payload = {
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
    }

    if sendWebhook(payload) then
        print("[MOON] Successfully sent via Proxy -> " .. moonName)
    end
end

-- ========================================================
-- MONITORING
-- ========================================================
local WeatherValues = ReplicatedStorage:WaitForChild("WeatherValues", 10)
if not WeatherValues then
    warn("[ERROR] WeatherValues folder not found in ReplicatedStorage")
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

    -- Initial check for already active weather
    for _, entry in ipairs(weatherDataList) do
        if WeatherValues:GetAttribute(entry.Name .. "_Playing") then
            local endUnix = WeatherValues:GetAttribute(entry.Name .. "_EndTime") or 0
            sendWeatherWebhook(entry.Name, endUnix)
        end
    end
end

local rareMoons = { "Bloodmoon", "Goldmoon", "Rainbow Moon", "Mega Moon" }
local function isRareMoon(name)
    for _, m in ipairs(rareMoons) do if m == name then return true end end
    return false
end

local lastMoon = workspace:GetAttribute("ActiveWeather")
if lastMoon and isRareMoon(lastMoon) then sendMoonWebhook(lastMoon) end

workspace:GetAttributeChangedSignal("ActiveWeather"):Connect(function()
    local current = workspace:GetAttribute("ActiveWeather")
    if current and current ~= lastMoon then
        lastMoon = current
        if isRareMoon(current) then sendMoonWebhook(current) end
    end
end)

workspace:GetAttributeChangedSignal("ActivePhase"):Connect(function()
    if workspace:GetAttribute("ActivePhase") == "Night" then
        task.wait(1) -- Allow server buffer time to assign ActiveWeather
        local current = workspace:GetAttribute("ActiveWeather")
        if current and isRareMoon(current) then
            lastMoon = current
            sendMoonWebhook(current)
        end
    end
end)

print("[WEATHER] Monitor running stably on Server environment...")
