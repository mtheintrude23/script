local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local stockValues = ReplicatedStorage:WaitForChild("StockValues")

-- ========================================================
-- CONFIG (fill in your own values here)
-- ========================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1483471565130825791/-LjvHco3PqatsN5KAmDW96yktGJr9gKj-2E6wqL5EWZzOK8UHSEzQo2FF4vSGcaNIcGD"

-- API endpoint that receives the raw JSON data directly (NOT a Discord webhook).
-- Put your real API URL here (e.g. http://node1.minet.vn:25960/api/ghz/stock)
local API_URL = "http://node1.minet.vn:25960/api/ghz/stock"

-- Set to false if you don't want the Discord notification anymore, only the API push
local SEND_WEBHOOK_NOTIFICATION = true
-- ========================================================

if not WEBHOOK_URL or WEBHOOK_URL == "" or WEBHOOK_URL == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
    warn("❌ Discord webhook URL is not set!")
    SEND_WEBHOOK_NOTIFICATION = false
end

if not API_URL or API_URL == "" or API_URL == "YOUR_API_URL_HERE" then
    warn("⚠️ API_URL is not set — the script will NOT push directly to the API, only send the webhook (if enabled).")
end

-- key = field name used in the payload sent to the API, label = display title, emoji for the embed
local shopConfigs = {
    SeedShop  = { key = "seeds", label = "🌱 Seeds Restocked",       color = 3066993 },
    GearShop  = { key = "gear",  label = "⚙️ Gear Stock Restocked",  color = 3447003 },
    CrateShop = { key = "props", label = "📦 Crates Stock",          color = 15844367 },
}

-- How long until the next restock, in milliseconds (used for "nextUpdateAt").
-- Adjust this to match the real in-game restock interval if it differs.
local NEXT_UPDATE_INTERVAL_MS = 5 * 60 * 1000 -- 5 minutes

-- Fixed order so the embed always displays Seeds -> Gear -> Crates
local SHOP_ORDER = { "SeedShop", "GearShop", "CrateShop" }

-- ── Shared HTTP helper for both the webhook and the API push ──
local function httpPostJson(url, bodyTable)
    if not url or url == "" or url:match("^YOUR_") then
        return false, "URL is not configured"
    end

    local payload = HttpService:JSONEncode(bodyTable)

    local ok, errOrRes = pcall(function()
        local requestFunc = syn and syn.request or http and http.request or request or http_request
        if requestFunc then
            return requestFunc({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        else
            return HttpService:PostAsync(url, payload)
        end
    end)

    return ok, errOrRes
end

-- ── Read all current items (Value > 0) for one shop ──
local function getShopItems(shopName)
    local items = {}

    local shopFolder = stockValues:FindFirstChild(shopName)
    if not shopFolder then return items end

    local itemsFolder = shopFolder:FindFirstChild("Items")
    if not itemsFolder then return items end

    for _, child in ipairs(itemsFolder:GetChildren()) do
        if string.find(child.ClassName, "Value") and child.Value > 0 then
            table.insert(items, { name = child.Name, value = child.Value })
        end
    end

    return items
end

-- ── Collect current data for all 3 shops ──
local function collectAllShops()
    local snapshot = {}
    for _, shopName in ipairs(SHOP_ORDER) do
        snapshot[shopName] = getShopItems(shopName)
    end
    return snapshot
end

-- ── Build a SINGLE combined embed, each shop as its own code-block section ──
local function buildCombinedEmbed(snapshot)
    local descParts = {}
    local hasAny = false

    for _, shopName in ipairs(SHOP_ORDER) do
        local config = shopConfigs[shopName]
        local items = snapshot[shopName]

        if items and #items > 0 then
            hasAny = true
            local lines = {}
            for _, item in ipairs(items) do
                table.insert(lines, item.name .. ": x" .. tostring(item.value))
            end
            table.insert(
                descParts,
                "**" .. config.label .. "**\n```\n" .. table.concat(lines, "\n") .. "\n```"
            )
        end
    end

    if not hasAny then return nil end

    return {
        title = "🛒 Stock Update",
        description = table.concat(descParts, "\n\n"),
        color = 5793266, -- neutral color for the combined embed
        timestamp = DateTime.now():ToIsoDate(),
        footer = { text = "Grow a Garden 2" }
    }
end

-- ── Build the JSON payload sent directly to the API ──
-- Matches the schema: { seeds: [{name, qty}], gear: [...], props: [...], reportedAt, nextUpdateAt }
-- reportedAt / nextUpdateAt are Unix timestamps in MILLISECONDS.
local function buildApiPayload(snapshot)
    local now = DateTime.now()
    local reportedAt = now.UnixTimestampMillis
    local nextUpdateAt = reportedAt + NEXT_UPDATE_INTERVAL_MS

    local payload = {
        reportedAt = reportedAt,
        nextUpdateAt = nextUpdateAt
    }

    for _, shopName in ipairs(SHOP_ORDER) do
        local config = shopConfigs[shopName]
        local items = snapshot[shopName]
        local list = {}
        for _, item in ipairs(items or {}) do
            table.insert(list, { name = item.name, qty = item.value })
        end
        payload[config.key] = list
    end

    return payload
end

-- ── Send out: 1 webhook embed (if enabled) + push JSON directly to the API ──
local function pushUpdate()
    local snapshot = collectAllShops()

    if SEND_WEBHOOK_NOTIFICATION then
        local embed = buildCombinedEmbed(snapshot)
        if embed then
            local ok, err = httpPostJson(WEBHOOK_URL, { embeds = { embed } })
            if ok then
                print("⚡ [Webhook] Combined embed sent.")
            else
                warn("❌ [Webhook] Send failed: ", err)
            end
        end
    end

    local apiPayload = buildApiPayload(snapshot)
    local ok, err = httpPostJson(API_URL, apiPayload)
    if ok then
        print("🚀 [API] Data pushed directly to the API.")
    else
        warn("❌ [API] Push failed: ", err)
    end
end

-- ── Wait until ALL 3 shops have changed at least once before pushing ──
-- (not just whichever shop happens to change first)
local changedShops = {}
for _, shopName in ipairs(SHOP_ORDER) do
    changedShops[shopName] = false
end

local pendingGlobalUpdate = false

local function allShopsChanged()
    for _, shopName in ipairs(SHOP_ORDER) do
        if not changedShops[shopName] then
            return false
        end
    end
    return true
end

local function resetChangedFlags()
    for _, shopName in ipairs(SHOP_ORDER) do
        changedShops[shopName] = false
    end
end

local function markShopChanged(shopName)
    changedShops[shopName] = true

    if pendingGlobalUpdate then return end
    if not allShopsChanged() then return end

    pendingGlobalUpdate = true
    -- small delay to catch any last-moment changes that land at the same time
    task.delay(0.5, function()
        pushUpdate()
        resetChangedFlags()
        pendingGlobalUpdate = false
    end)
end

local function startListening()
    for shopName, _ in pairs(shopConfigs) do
        local shopFolder = stockValues:FindFirstChild(shopName)
        if shopFolder then
            local itemsFolder = shopFolder:WaitForChild("Items", 5)
            if itemsFolder then
                for _, child in ipairs(itemsFolder:GetChildren()) do
                    if string.find(child.ClassName, "Value") then
                        child.Changed:Connect(function()
                            markShopChanged(shopName)
                        end)
                    end
                end

                itemsFolder.ChildAdded:Connect(function(child)
                    if string.find(child.ClassName, "Value") then
                        child.Changed:Connect(function()
                            markShopChanged(shopName)
                        end)
                        markShopChanged(shopName)
                    end
                end)
            end
        end
    end
    print("🚀 [System]: STOCK SCHEDULE mode enabled (waits for Seeds + Gear + Crates to all change, then pushes once)!")
end

-- Initial baseline push with whatever is currently in stock when the script starts
pushUpdate()

startListening()        description = table.concat(descParts, "\n\n"),
        color = 5793266,
        timestamp = DateTime.now():ToIsoDate(),
        footer = { text = "Grow a Garden 2" }
    }
end

-- ── Build API payload ──
local function buildApiPayload(snapshot)
    local now = DateTime.now()
    local reportedAt = now.UnixTimestampMillis
    local nextUpdateAt = reportedAt + NEXT_UPDATE_INTERVAL_MS

    local payload = {
        reportedAt = reportedAt,
        nextUpdateAt = nextUpdateAt
    }

    for _, shopName in ipairs(SHOP_ORDER) do
        local config = shopConfigs[shopName]
        local items = snapshot[shopName]
        local list = {}
        for _, item in ipairs(items or {}) do
            table.insert(list, { name = item.name, qty = item.value })
        end
        payload[config.key] = list
    end

    return payload
end

-- ── Send out webhook + API push ──
local function pushUpdate()
    local snapshot = collectAllShops()

    if SEND_WEBHOOK_NOTIFICATION then
        local embed = buildCombinedEmbed(snapshot)
        if embed then
            local ok, err = httpPostJson(WEBHOOK_URL, { embeds = { embed } })
            if ok then
                print("⚡ [Webhook] Combined embed sent.")
            else
                warn("❌ [Webhook] Send failed: ", err)
            end
        end
    end

    local apiPayload = buildApiPayload(snapshot)
    local ok, err = httpPostJson(API_URL, apiPayload)
    if ok then
        print("🚀 [API] Data pushed directly to the API.")
    else
        warn("❌ [API] Push failed: ", err)
    end
end

-- ============================================================
-- ✅ FIX: Trailing-edge debounce — reset timer mỗi thay đổi
-- ============================================================
local debounceThread = nil

local function requestPush()
    -- Hủy timer cũ nếu đang có, tạo timer mới
    if debounceThread then
        task.cancel(debounceThread)
    end

    debounceThread = task.delay(PUSH_DEBOUNCE_SECONDS, function()
        debounceThread = nil
        pushUpdate()
    end)
end
-- ============================================================

local function startListening()
    for shopName, _ in pairs(shopConfigs) do
        local shopFolder = stockValues:FindFirstChild(shopName)
        if shopFolder then
            local itemsFolder = shopFolder:WaitForChild("Items", 5)
            if itemsFolder then
                for _, child in ipairs(itemsFolder:GetChildren()) do
                    if string.find(child.ClassName, "Value") then
                        child.Changed:Connect(requestPush)
                    end
                end

                itemsFolder.ChildAdded:Connect(function(child)
                    if string.find(child.ClassName, "Value") then
                        child.Changed:Connect(requestPush)
                        requestPush()
                    end
                end)
            end
        end
    end
    print("🚀 [System]: LIVE PUSH mode enabled (trailing-edge debounce)!")
end

-- Initial baseline push
pushUpdate()

startListening()
