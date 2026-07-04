

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-------------------------------------------------
-------------------------------------------------
local WEBHOOK_URL = "https://discord.com/api/webhooks/1522976371779833876/gP7rTiS61XchHLMuzNpzzwygUzB4zTCiJV-CwLpPHz3FXQeLXoPBJ4bdizRkJOYgtfIq"
local API_URL = "http://node1.minet.vn:25960/api/fruit-price" -- Đổi tên route cho khớp

-------------------------------------------------
-- MODULES
-------------------------------------------------
local Networking      = require(ReplicatedStorage.SharedModules.Networking)
local SellValueData   = require(ReplicatedStorage.SharedModules.SellValueData)
local SeedShopEnabled = require(ReplicatedStorage.SharedModules.SeedShopEnabled)
local FruitImages     = ReplicatedStorage.SharedModules.SeedData:WaitForChild("FruitImages")

-------------------------------------------------
-- HELPERS
-------------------------------------------------
local function getFruitImage(seedName)
    if not FruitImages then return "" end
    local imgObj = FruitImages:FindFirstChild(seedName)
    if imgObj and imgObj:IsA("StringValue") then
        return imgObj.Value
    end
    return ""
end

local function formatMultiplier(mult)
    local v = math.floor(mult * 100 + 0.5) / 100
    if v == math.floor(v) then return string.format("X%d", v) end
    return "X" .. string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
end

-------------------------------------------------
-- HTTP REQUESTS
-------------------------------------------------
local function httpPost(url, payload)
    task.spawn(function()
        pcall(function()
            HttpService:PostAsync(url, HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
        end)
    end)
end

-------------------------------------------------
-- PUSH DATA TO API
-------------------------------------------------
local function pushToAPI(fruitList, snapshot, serverOffset)
    if not API_URL or API_URL == "" then return end
    
    -- Chỉnh key khớp 100% với req.body của bạn
    local payload = {
        reportedAt = os.time() + serverOffset,
        lastRefreshAt = snapshot.lastRefreshUnix or 0,
        nextRefreshAt = snapshot.nextRefreshUnix or 0,
        cycleSeconds = snapshot.cycleSeconds or 0,
        entries = fruitList -- Đổi từ fruits thành entries
    }
    
    httpPost(API_URL, payload)
end

-------------------------------------------------
-- PUSH EMBED TO DISCORD WEBHOOK
-------------------------------------------------
local function addFieldsSafe(embed, tierName, emoji, items)
    if #items == 0 then return end
    local text = table.concat(items, "\n")
    
    if #text <= 1024 then
        table.insert(embed.fields, { name = emoji .. " " .. tierName, value = text, inline = false })
    else
        local chunk, chunkLen = {}, 0
        for _, line in ipairs(items) do
            if chunkLen + #line + 1 > 1024 then
                table.insert(embed.fields, { name = emoji .. " " .. tierName .. " (cont.)", value = table.concat(chunk, "\n"), inline = false })
                chunk, chunkLen = {}, 0
            end
            table.insert(chunk, line)
            chunkLen = chunkLen + #line + 1
        end
        if #chunk > 0 then
            table.insert(embed.fields, { name = emoji .. " " .. tierName, value = table.concat(chunk, "\n"), inline = false })
        end
    end
end

local function pushToWebhook(fruitList, snapshot)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end

    local megaBigItems = {}
    local normalItems = {}

    for _, fruit in ipairs(fruitList) do
        local line = string.format("**%s** | `Base: %d` | `%s` | [🖼 IMG](%s)", fruit.name, fruit.value, fruit.multiplierText, fruit.image)
        
        if fruit.tier == "mega" then
            table.insert(megaBigItems, 1, "🟣 " .. line)
        elseif fruit.tier == "big" then
            table.insert(megaBigItems, "🟡 " .. line)
        else
            table.insert(normalItems, "⚪ " .. line)
        end
    end

    local nextRefresh = snapshot.nextRefreshUnix or 0

    local embed = {
        title = "🌱 Fruit Stock Updated!",
        color = 5793266,
        fields = {},
        description = "Next refresh: <t:" .. tostring(nextRefresh) .. ":R> (`" .. tostring(nextRefresh) .. "`)"
    }

    if #fruitList > 0 and fruitList[1].image ~= "" then
        embed.thumbnail = { url = fruitList[1].image }
    end

    addFieldsSafe(embed, "Mega / Big Fruits", "✨", megaBigItems)
    addFieldsSafe(embed, "Normal Fruits", "🥚", normalItems)

    httpPost(WEBHOOK_URL, { embeds = { embed } })
end

-------------------------------------------------
-- HANDLE DATA FROM SERVER
-------------------------------------------------
local function onSnapshotReceived(snapshot)
    if typeof(snapshot) ~= "table" then return end
    local entries = snapshot.entries
    if typeof(entries) ~= "table" then return end

    local serverOffset = 0
    if typeof(snapshot.server_now_unix) == "number" then
        serverOffset = snapshot.server_now_unix - os.time()
    end

    local seeds = {}
    pcall(function()
        for seedName in SellValueData do
            if SeedShopEnabled.IsSeedEnabled(seedName) then
                table.insert(seeds, seedName)
            end
        end
    end)

    table.sort(seeds, function(a, b)
        local va = SellValueData[a] or 0
        local vb = SellValueData[b] or 0
        if va == vb then return a < b end
        return vb < va
    end)

    local fruitList = {}
    for _, seedName in ipairs(seeds) do
        local data = entries[seedName] or {}
        local mult = typeof(data.multiplier) == "number" and data.multiplier or 1
        local tier = typeof(data.tier) == "string" and data.tier or "normal"
        local sellValue = SellValueData[seedName] or 0

        table.insert(fruitList, {
            name = seedName,
            value = sellValue,
            multiplier = mult,
            multiplierText = formatMultiplier(mult),
            tier = tier,
            image = getFruitImage(seedName)
        })
    end

    -- Push lên API và Webhook
    pushToAPI(fruitList, snapshot, serverOffset)
    pushToWebhook(fruitList, snapshot)
end

-------------------------------------------------
-- SETUP & LISTENER
-------------------------------------------------
Networking.FruitStock.Snapshot.OnClientEvent:Connect(onSnapshotReceived)

local ok, result = pcall(function()
    return Networking.FruitStock.Request:Fire()
end)
if ok and result then
    onSnapshotReceived(result)
end

print("[🌱 FruitStock] API & Webhook Pusher is running silently!")
