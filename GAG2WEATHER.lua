local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========================================================
-- WEBHOOK CONFIG
-- ========================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1485854014431297677/o-yBaZrpDraynVuE88XHQNNBIp_W9avOSxPqxIDBTN8HLm7YvKdVZTHCPZsYloLZiElz"
-- ========================================================

-- WeatherData is at ReplicatedStorage.SharedModules.WeatherData
-- Module returns { Data = { {Name, Last, Description, ...}, ... } }
local rawModule = require(ReplicatedStorage.SharedModules.WeatherData)
local weatherDataList = rawModule.Data or {}

-- Strip Roblox <font color="..."> rich text tags for plain Discord text
local function stripRichText(str)
    return (str:gsub("<[^>]+>", ""))
end

-- Search WeatherData array by Name field
local function getWeatherInfo(weatherName)
    for _, entry in ipairs(weatherDataList) do
        if entry.Name == weatherName then
            return entry
        end
    end
    return {}
end

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
-- SEND WEBHOOK
-- endTimeUnix: unix timestamp from WeatherValues attribute {Name}_EndTime
-- ========================================================
local function sendWeatherWebhook(weatherName, endTimeUnix)
    local info  = getWeatherInfo(weatherName)
    local desc  = info.Description and stripRichText(info.Description) or "No description."
    local style = weatherStyle[weatherName] or { color = 16777215, icon = "🌤️" }

    local endsField
    if endTimeUnix and endTimeUnix > 0 then
        -- <t:UNIX:R> = relative "in 4 minutes", <t:UNIX:F> = full date/time
        endsField = "<t:" .. math.floor(endTimeUnix) .. ":R> (<t:" .. math.floor(endTimeUnix) .. ":F>)"
    else
        endsField = "Unknown"
    end

    local embed = {
        title       = style.icon .. " Weather Changed: " .. weatherName,
        description = "**Description:** " .. desc,
        color       = style.color,
        fields      = {
            {
                name   = "⏳ Ends:",
                value  = endsField,
                inline = false
            },
        },
        timestamp = DateTime.now():ToIsoDate(),
        footer    = { text = "Grow a Garden 2 | Weather Monitor" },
    }

    local payload = HttpService:JSONEncode({ embeds = { embed } })

    pcall(function()
        local requestFunc = syn and syn.request
            or http and http.request
            or (typeof(request) == "function" and request)
            or (typeof(http_request) == "function" and http_request)

        if requestFunc then
            requestFunc({
                Url     = WEBHOOK_URL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = payload,
            })
        else
            HttpService:PostAsync(WEBHOOK_URL, payload)
        end
    end)

    print("📢 [WEATHER] Sent -> " .. weatherName .. " | Ends: " .. tostring(endTimeUnix))
end

-- ========================================================
-- MONITOR WeatherValues via ATTRIBUTES
-- Game uses: WeatherValues attribute "Rain_Playing" (bool), "Rain_EndTime" (unix)
-- Source confirmed from WeatherController decompile:
--   v_u_7:GetAttribute(p_u_32 .. "_Playing")
--   v_u_7:GetAttribute(p_u_11 .. "_EndTime")
-- ========================================================
local WeatherValues = ReplicatedStorage:WaitForChild("WeatherValues", 10)

if not WeatherValues then
    warn("❌ ReplicatedStorage.WeatherValues not found")
    return
end

-- Hook attribute changes for a specific weather name
local function hookWeather(weatherName)
    local playingAttr = weatherName .. "_Playing"
    local endTimeAttr = weatherName .. "_EndTime"

    WeatherValues:GetAttributeChangedSignal(playingAttr):Connect(function()
        local isPlaying = WeatherValues:GetAttribute(playingAttr)
        if isPlaying then
            local endUnix = WeatherValues:GetAttribute(endTimeAttr) or 0
            sendWeatherWebhook(weatherName, endUnix)
        end
    end)

    print("✅ Hooked attribute: " .. playingAttr)
end

-- Hook all weathers from WeatherData module
for _, entry in ipairs(weatherDataList) do
    hookWeather(entry.Name)
end

-- Check immediately if any weather is already active on script start
for _, entry in ipairs(weatherDataList) do
    local isPlaying = WeatherValues:GetAttribute(entry.Name .. "_Playing")
    if isPlaying then
        local endUnix = WeatherValues:GetAttribute(entry.Name .. "_EndTime") or 0
        sendWeatherWebhook(entry.Name, endUnix)
    end
end

print("🌦️ Weather Monitor running — listening to WeatherValues attributes...")
    playingVal.Changed:Connect(function(isPlaying)
        if isPlaying then
            local endUnix = (endTimeVal and endTimeVal.Value > 0) and endTimeVal.Value or 0
            sendWeatherWebhook(folder.Name, endUnix)
        end
    end)

    print("✅ Hooked: " .. folder.Name)
end

-- Hook all existing folders
for _, child in ipairs(WeatherValues:GetChildren()) do
    if child:IsA("Folder") then
        hookWeatherFolder(child)
    end
end

-- Hook any folders added later
WeatherValues.ChildAdded:Connect(function(child)
    if child:IsA("Folder") then
        hookWeatherFolder(child)
    end
end)

-- Check immediately if any weather is already active on script start
for _, folder in ipairs(WeatherValues:GetChildren()) do
    if folder:IsA("Folder") then
        local playingVal = folder:FindFirstChild("Playing")
        local endTimeVal = folder:FindFirstChild("EndTime")
        if playingVal and playingVal.Value == true then
            local endUnix = (endTimeVal and endTimeVal.Value > 0) and endTimeVal.Value or 0
            sendWeatherWebhook(folder.Name, endUnix)
        end
    end
end

print("🌦️ Weather Monitor running — listening to WeatherValues...")
