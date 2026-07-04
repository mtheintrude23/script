local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-------------------------------------------------
-- CẤU HÌNH WEBHOOK / API
-------------------------------------------------
local WEBHOOK_URL = "https://discord.com/api/webhooks/1522976371779833876/gP7rTiS61XchHLMuzNpzzwygUzB4zTCiJV-CwLpPHz3FXQeLXoPBJ4bdizRkJOYgtfIq"
local API_URL = "http://node1.minet.vn:25960/api/fruit-price" 

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
-- HTTP REQUESTS (DÙNG API EXECUTOR + BẮT LỖI CHI TIẾT)
-------------------------------------------------
local function httpPost(url, payload)
    task.spawn(function()
        local jsonPayload = nil
        local encodeOk, encodeErr = pcall(function()
            jsonPayload = HttpService:JSONEncode(payload)
        end)

        if not encodeOk or not jsonPayload then
            warn("[❌ FruitStock] JSON Encode Failed:", encodeErr)
            return
        end

        local requestFunc = http_request or request or http.request or syn.request or fluxus.request
        
        if requestFunc then
            local success, response = pcall(function()
                return requestFunc({
                    Url = url,
                    Method = "POST",
                    Body = jsonPayload,
                    Headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
            end)

            if success and response then
                if response.StatusCode and response.StatusCode >= 200 and response.StatusCode < 300 then
                    print("[✅ FruitStock] Pushed successfully to:", "| Status:", response.StatusCode)
                else
                    warn("[❌ FruitStock] Server rejected request for:", url, "| Status:", response.StatusCode or "Unknown")
                    -- In ra lý do server từ chối (rất quan trọng để debug 400 Bad Request)
                    warn("[❌ Server Response Body]:", response.Body or "No body")
                end
            else
                warn("[❌ FruitStock] Executor HTTP Failed for", url)
                warn("[❌ Error Details]:", response or "Unknown error")
            end
        else
            warn("[❌ FruitStock] No executor HTTP function found!")
        end
    end)
end

-------------------------------------------------
-- PUSH DATA TO API
-------------------------------------------------
local function pushToAPI(fruitList, snapshot, serverOffset)
    if not API_URL or API_URL == "" then return end
    
    local payload = {
        reportedAt = os.time() + serverOffset,
        lastRefreshAt = snapshot.lastRefreshUnix or 0,
        nextRefreshAt = snapshot.nextRefreshUnix or 0,
        cycleSeconds = snapshot.cycleSeconds or 0,
        fruits = fruitList
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
        local line = string.format("**%s** | `Base: %d` | `%s`", fruit.name, fruit.value, fruit.multiplierText)
        -- Bỏ link ảnh vào text (Discord không nhận rbxassetid làm URL nên chỉ để text cho đẹp)
        if fruit.image ~= "" then
            line = line .. string.format(" | [🖼 IMG](%s)", fruit.image)
        end
        
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
        -- KHÔNG KHỞI TẠO fields = {} ĐỂ TRÁNH JSON ENCODE BIẾN NÓ THÀNH OBJECT {}
        description = "Next refresh: <t:" .. tostring(nextRefresh) .. ":R> (`" .. tostring(nextRefresh) .. "`)"
    }

    -- Xóa hoàn toàn Thumbnail vì Discord không chấp nhận link rbxassetid://, sẽ gây lỗi 400
    -- if #fruitList > 0 and fruitList[1].image ~= "" then
    --     embed.thumbnail = { url = fruitList[1].image }
    -- end

    -- Khởi tạo mảng fields CHỈ KHI CÓ DATA
    local hasFields = false
    if #megaBigItems > 0 or #normalItems > 0 then
        embed.fields = {}
        hasFields = true
    end

    if #megaBigItems > 0 then
        addFieldsSafe(embed, "Mega / Big Fruits", "✨", megaBigItems)
    end

    if #normalItems > 0 then
        addFieldsSafe(embed, "Normal Fruits", "🥚", normalItems)
    end

    -- Đẩy đi
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

print("[🌱 FruitStock] API & Webhook Pusher (v3 Fix 400 Error) loaded!")
