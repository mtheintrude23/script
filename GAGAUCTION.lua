local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networking = require(ReplicatedStorage.SharedModules.Networking)
local Auctioneer = require(ReplicatedStorage.SharedModules.Auctioneer)

-- ========================================================
-- CONFIG
-- ========================================================
-- API endpoint that receives the auction data as JSON.
-- Fill in your real URL (e.g. http://node1.minet.vn:25960/api/ghz/auction)
local API_URL = "http://node1.minet.vn:25960/api/ghz/auction"
-- ========================================================

if not API_URL or API_URL == "" or API_URL == "YOUR_API_URL_HERE" then
    warn("⚠️ API_URL is not set — auction data will only print to console, not push.")
end

local function serverNow()
    local ok, t = pcall(function()
        return workspace:GetServerTimeNow()
    end)
    if ok then
        return t
    end
    return os.time()
end

-- lotId -> lot table (from manifest.lots)
local currentLots = {}
-- lotId -> remaining stock quantity (from the stock table)
local currentStock = {}
-- Board-level refresh timer info (from manifest), used to compute nextUpdateAt
local rollIntervalSeconds = 0
local rollWindowUnix = 0
local timerShiftSeconds = 0

-- ── HTTP helper for the API push ──
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

local function printAuctions()
    local now = serverNow()
    print(("📋 Auction Snapshot @ %d"):format(now))

    local count = 0
    for _, _ in pairs(currentLots) do
        count = count + 1
    end

    if count == 0 then
        print("  (no active lots)")
        return
    end

    for lotId, lot in pairs(currentLots) do
        local price = Auctioneer.CurrentPrice(lot, now)
        local name = Auctioneer.DisplayName(lot)
        local stockLeft = currentStock[lotId]
        local active = Auctioneer.IsActive(lot, now, stockLeft)

        local stockText
        if lot.stockQuantity == nil then
            stockText = "Unlimited"
        else
            stockText = tostring(stockLeft or lot.stockQuantity)
        end

        local expiresIn = math.max(0, (lot.expiresAt or now) - now)

        print(string.format(
            "  [%s] %s | Price: %d | Stock: %s | Active: %s | ExpiresIn: %ds | TickEvery: %ss | DecrementPct: %s%% | StartPrice: %s | MinPrice: %s",
            tostring(lotId), name, price, stockText, tostring(active), expiresIn,
            tostring(lot.decrementIntervalSeconds), tostring(lot.decrementPercent),
            tostring(lot.startPrice), tostring(lot.minPrice)
        ))
    end
end

-- ── Figure out when the next full board refresh happens ──
local function computeNextUpdateAt(now)
    if rollWindowUnix > 0 and rollIntervalSeconds > 0 then
        return rollWindowUnix + rollIntervalSeconds + timerShiftSeconds
    end
    -- Fallback: soonest expiresAt among current lots
    local soonest = nil
    for _, lot in pairs(currentLots) do
        if lot.expiresAt and (soonest == nil or lot.expiresAt < soonest) then
            soonest = lot.expiresAt
        end
    end
    return soonest or now
end

-- ── Build the JSON payload (Option A: flat array of lots) ──
-- Pushed once per restock, so "price"/"stock" here ARE the starting
-- values for this cycle — labeled accordingly so the API/consumer
-- doesn't confuse them with a live/decayed value.
local function buildApiPayload(now)
    local lotsArray = {}

    for lotId, lot in pairs(currentLots) do
        local startingPrice = Auctioneer.CurrentPrice(lot, now)
        local name = Auctioneer.DisplayName(lot)
        local startingStock = currentStock[lotId] or lot.stockQuantity
        local active = Auctioneer.IsActive(lot, now, currentStock[lotId])

        table.insert(lotsArray, {
            lotId = lotId,
            name = name,
            category = lot.category,
            amount = lot.count or 1,
            startingPrice = startingPrice,
            minPrice = lot.minPrice,
            decrementPercent = lot.decrementPercent,
            decrementIntervalSeconds = lot.decrementIntervalSeconds,
            rolledAt = lot.rolledAt,
            startingStockCount = startingStock,
            stockQuantity = lot.stockQuantity,
            active = active,
            expiresAt = lot.expiresAt,
            robuxPrice = lot.robuxPrice,
        })
    end

    -- restockId identifies this specific restock cycle. Using rollWindowUnix
    -- because it stays constant for the whole cycle (unlike "now", which
    -- changes every call) — so the consumer can tell "new restock" apart
    -- from "duplicate/retry of the same push" just by comparing this id.
    local restockId = rollWindowUnix > 0 and rollWindowUnix or now

    return {
        restockId = restockId,
        reportedAt = now,
        nextUpdateAt = computeNextUpdateAt(now),
        lots = lotsArray,
    }
end

local function pushUpdate()
    local now = serverNow()
    local payload = buildApiPayload(now)
    local ok, err = httpPostJson(API_URL, payload)
    if ok then
        print(("🚀 [API] Auction data pushed (restockId=%s, %d lots)."):format(tostring(payload.restockId), #payload.lots))
    else
        warn("❌ [API] Push failed: ", err)
    end
end

local function onSnapshot(snapshot)
    if typeof(snapshot) ~= "table" then return end

    currentLots = {}
    local manifest = snapshot.manifest
    if typeof(manifest) == "table" and typeof(manifest.lots) == "table" then
        for _, lot in ipairs(manifest.lots) do
            if typeof(lot) == "table" and typeof(lot.lotId) == "string" then
                currentLots[lot.lotId] = lot
            end
        end
    end

    if typeof(snapshot.stock) == "table" then
        currentStock = snapshot.stock
    end

    if typeof(snapshot.rollIntervalSeconds) == "number" and snapshot.rollIntervalSeconds > 0 then
        rollIntervalSeconds = snapshot.rollIntervalSeconds
    end
    if typeof(snapshot.rollWindowUnix) == "number" and snapshot.rollWindowUnix > 0 then
        rollWindowUnix = snapshot.rollWindowUnix
    end
    if typeof(snapshot.timerShiftSeconds) == "number" then
        timerShiftSeconds = snapshot.timerShiftSeconds
    end

    printAuctions()

    -- Only push if this snapshot actually has lots — avoid pushing junk
    -- data to the API for the empty broadcasts that happen between restocks.
    local hasLots = false
    for _, _ in pairs(currentLots) do
        hasLots = true
        break
    end

    if hasLots then
        pushUpdate()
    else
        print("⏭️ Skipping push — snapshot has no active lots (between restocks).")
    end
end

-- ── Build a small payload for a single sold-out event ──
local function buildSoldOutPayload(lotId, lot, now)
    local restockId = rollWindowUnix > 0 and rollWindowUnix or now
    return {
        restockId = restockId,
        event = "soldOut",
        lotId = lotId,
        name = Auctioneer.DisplayName(lot),
        soldOutAt = now,
    }
end

local function pushSoldOut(lotId, lot)
    local now = serverNow()
    local payload = buildSoldOutPayload(lotId, lot, now)
    local ok, err = httpPostJson(API_URL, payload)
    if ok then
        print(("🛑 [API] Sold-out event pushed for %s (%s)."):format(payload.name, lotId))
    else
        warn("❌ [API] Sold-out push failed: ", err)
    end
end

local function onStockUpdate(update)
    if typeof(update) ~= "table" then return end
    if typeof(update.stock) == "table" then
        local previousStock = currentStock
        currentStock = update.stock

        -- Detect lots that just transitioned from >0 stock to <=0 (sold out)
        for lotId, lot in pairs(currentLots) do
            local before = previousStock[lotId]
            local after = currentStock[lotId]
            local wasInStock = before == nil or before > 0
            local nowSoldOut = after ~= nil and after <= 0
            if wasInStock and nowSoldOut then
                pushSoldOut(lotId, lot)
            end
        end

        printAuctions()
    end
end

-- Listen for live updates
Networking.Auctioneer.Snapshot.OnClientEvent:Connect(onSnapshot)
Networking.Auctioneer.StockUpdate.OnClientEvent:Connect(onStockUpdate)

-- Confirmed via diagnostics: this game's Networking module uses the "Red"
-- networking library. RequestSnapshot:Fire() doesn't reliably yield/return
-- data when called from an external script — BUT the passive
-- Snapshot.OnClientEvent listener (connected above) already receives real
-- broadcasts from the server on its own (e.g. on the next restock cycle).
print("👂 Listening passively for the next Auctioneer restock broadcast...")

-- Confirmed via diagnostics: this game's Networking module uses a custom
-- buffer-based "Packet" system. Manually forcing RequestSnapshot:Fire()
-- triggers real internal serialization errors ("buffer access out of
-- bounds"), meaning the request isn't being constructed correctly from
-- here — likely because the official client sends some session/auth state
-- this script doesn't have. Reverse-engineering that protocol further
-- isn't worth the risk (malformed packets, anti-cheat flags, etc).
--
-- The good news: the passive Snapshot.OnClientEvent listener (connected
-- above) already receives REAL data from the server on its own — no
-- manual request needed. It'll fire automatically on the next restock.
print("👂 Listening passively for the next Auctioneer restock broadcast...")
