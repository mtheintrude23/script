local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local req = (syn and syn.request) or (http and http.request) or http_request or request

local CONFIG = {
    WEBHOOK_URL = "https://discord.com/api/webhooks/1483471565130825791/-LjvHco3PqatsN5KAmDW96yktGJr9gKj-2E6wqL5EWZzOK8UHSEzQo2FF4vSGcaNIcGD",
    WEBHOOK_ENABLED = true,
    WEBHOOK_COOLDOWN = 5,
}

local WEATHER_INFO = {
    ["Clear"]         = { color = 0x88CCFF, desc = "Clear skies. Normal growth speed.",                              muts = "None" },
    ["Sunny"]         = { color = 0xFFDD55, desc = "Sunny weather. Crop growth speed **+25%**.",                     muts = "None" },
    ["Cloudy"]        = { color = 0xAAAAAA, desc = "Cloudy. Slightly affected growth times.",                        muts = "None" },
    ["Windy"]         = { color = 0x88DDDD, desc = "Windy conditions. Growth speed **+5%**.",                        muts = "None" },
    ["Fog"]           = { color = 0x999999, desc = "Foggy weather. Slower growth but chance of Foggy mutation.",     muts = "Foggy <2.0x" },
    ["Foggy"]         = { color = 0x999999, desc = "Foggy weather. Slower growth but chance of Foggy mutation.",     muts = "Foggy <2.0x" },
    ["Rain"]          = { color = 0x4488FF, desc = "Rainy weather. Crops get watered passively. Growth speed **+15%**.", muts = "Flooded <2.0x" },
    ["Heavy Rain"]    = { color = 0x2244AA, desc = "Heavy rain floods crops. Growth speed **+30%**.",                muts = "Soaked <2.0x | Ancient 7.5x (Boss)" },
    ["Snow"]          = { color = 0xFFFFFF, desc = "Snow falling. Growth speed **-50%**.",                           muts = "Snowy 2.0x | Chilled <2.0x" },
    ["Sandstorm"]     = { color = 0xDD9944, desc = "A raging sandstorm. Growth speed **-30%**.",                     muts = "Sandy 2.5x" },
    ["Storm"]         = { color = 0x554477, desc = "Thunderstorm! Lightning strikes. Growth speed **+50%**.",        muts = "Shocked 4.5x" },
    ["Acid Rain"]     = { color = 0x44FF22, desc = "Acid rain damages unprotected crops.",                           muts = "Toxic (TBA)" },
    ["Mowis"]         = { color = 0x66FF99, desc = "Rare event. Growth speed **+75%**.",                             muts = "Unknown" },
    ["Starfall"]      = { color = 0xFFCCFF, desc = "Starfall 🌠 Rare meteorites shower down. Growth speed **+25%**.",muts = "Starstruck 6.5x" },
    ["Meteor"]        = { color = 0xFF5500, desc = "Meteor Shower ☄️ Epic admin meteorites arrive.",                muts = "Meteoric 10x" },
    ["Tsunami"]       = { color = 0x2288CC, desc = "Tsunami 🌊 A massive wave approaches.",                          muts = "Tidal 2.0x" },
    ["DJ Kine"]       = { color = 0xFF00FF, desc = "Music party event — growth speed **+100%**!",                    muts = "Party 11.5x" },
    ["Beam Clash"]    = { color = 0xFF6688, desc = "Beams clash in the sky.",                                        muts = "Salad 10x | Banned 10x" },
    ["Black Hole"]    = { color = 0x111111, desc = "A cosmic black hole appears.",                                   muts = "Nova 6.5x" },
    ["Strange Weather"]= { color = 0x886699, desc = "Strange weather follows a boss defeat or Admin event.",         muts = "Strange 2.0x" },
    ["StrangeWeather"] = { color = 0x886699, desc = "Strange weather follows a boss defeat or Admin event.",         muts = "Strange 2.0x" },
}
local WEATHER_FALLBACK = { color = 0x888888, desc = "Special weather event.", muts = "Unknown" }

local WEATHER_WHITELIST = {
    "Clear","Sunny","Cloudy","Windy","Fog","Foggy","Rain","Snow",
    "Sandstorm","Storm","Starfall","Meteor","Tsunami","Heavy Rain",
    "Acid Rain","Mowis","DJ Kine","Beam Clash","Black Hole","StrangeWeather","Strange Weather",
}

local function ts() return os.date("[%H:%M:%S]") end

local lastWebhookTime = 0
local currentWeather = { status = "None", duration = 0 }



-- Send Discord Webhook
local function sendWeatherWebhook(weather)
    if not CONFIG.WEBHOOK_ENABLED or not req then return end
    if CONFIG.WEBHOOK_URL:find("PASTE") then return end
    
    if tick() - lastWebhookTime < CONFIG.WEBHOOK_COOLDOWN then return end
    lastWebhookTime = tick()

    local wStatus = weather and weather.status or "None"
    
    local wInfo
    if wStatus == "None" then
        wInfo = {
            color = 0x55FF55, 
            desc = "The skies are clear. Normal weather has returned.", 
            muts = "None"
        }
    else
        wInfo = WEATHER_INFO[wStatus] or WEATHER_FALLBACK
    end

    local embedTitle = wStatus == "None" and "🌤️ Weather Cleared" or "Weather Update — " .. wStatus
    local durStr = wStatus == "None" and "--" or "5 minutes"

    local ok, err = pcall(req, {
        Url = CONFIG.WEBHOOK_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            ["username"] = "Garden Weather",
            ["avatar_url"] = "https://cdn-icons-png.flaticon.com/512/3234/3234972.png",
            ["embeds"] = {{
                ["title"] = embedTitle,
                ["description"] = wInfo.desc,
                ["color"] = wInfo.color,
                ["fields"] = {
                    { ["name"] = "Mutations", ["value"] = wInfo.muts, ["inline"] = true },
                    { ["name"] = "Duration", ["value"] = durStr, ["inline"] = true },
                },
                ["footer"] = { 
                    ["text"] = "Garden Horizons Weather Monitor",
                    ["icon_url"] = "https://cdn-icons-png.flaticon.com/512/3234/3234972.png" 
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }},
        }),
    })
    if ok then
        print(ts() .. " [WeatherBot] Discord OK: " .. wStatus)
    else
        print(ts() .. " [WeatherBot] Discord Error: " .. tostring(err))
    end
end

local function onWeatherChange(wName, wDuration)
    -- Ignore completely empty or unknown names
    if not wName or wName == "" or wName == "None" or wName == "Unknown" then
        if currentWeather.status ~= "None" then
            print(ts() .. " [WeatherBot] Weather ended -> Resetting to None")
            currentWeather.status = "None"
            currentWeather.duration = 0
            sendWeatherWebhook(currentWeather)
        end
        return
    end

    -- Skip if it's identical to what we already track
    if wName == currentWeather.status then
        currentWeather.duration = wDuration
        return
    end

    -- Accept new valid weather
    currentWeather.status = wName
    currentWeather.duration = wDuration

    print(ts() .. string.format(" [WeatherBot] New weather detected: %s", wName))
    sendWeatherWebhook(currentWeather)
end

local function hookWeatherRemotes()
    local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    if not remotes then return print("[WeatherBot] RemoteEvents not found!") end

    for _, rem in pairs(remotes:GetChildren()) do
        if rem:IsA("RemoteEvent") and rem.Name:lower():find("weather") then
            rem.OnClientEvent:Connect(function(...)
                local args = {...}
                local ok, encoded = pcall(function() return HttpService:JSONEncode(args) end)
                if not ok then return end
                
                -- Filter out pure visual updates
                if encoded:find("VisualEffect") or encoded:find("Particle") or encoded:find("Lightning") then return end

                local wName = ""
                local wDur = 0
                
                for _, arg in ipairs(args) do
                    if type(arg) == "table" then
                        wName = arg.Name or arg.name or arg.WeatherType or arg.Type or arg.id or arg.Id or arg.status or wName
                        wDur = arg.Duration or arg.duration or arg.Time or arg.time or wDur
                    elseif type(arg) == "string" then
                        for _, clean in ipairs(WEATHER_WHITELIST) do
                            if arg:lower() == clean:lower() then 
                                wName = clean 
                                break 
                            end
                        end
                    elseif type(arg) == "number" and arg > 10 then
                        wDur = arg
                    end
                end
                onWeatherChange(wName, wDur)
            end)
            print("[WeatherBot] Hooked weather remote: " .. rem.Name)
        end
    end
end

-- Wait for game to initialize then start
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    task.wait(1)
    
    print("====================================")
    print("🌤️ Garden Horizons WeatherBot loaded")
    print("====================================")
    
    hookWeatherRemotes()
end)

-- Anti AFK
local VirtualUser = game:GetService("VirtualUser")
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)
