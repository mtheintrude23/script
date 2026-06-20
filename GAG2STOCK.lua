local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local stockValues = ReplicatedStorage:WaitForChild("StockValues")

-- ========================================================
-- CẤU HÌNH WEBHOOK (Thay link của bạn vào đây)
-- ========================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1483471565130825791/-LjvHco3PqatsN5KAmDW96yktGJr9gKj-2E6wqL5EWZzOK8UHSEzQo2FF4vSGcaNIcGD"

-- Nếu muốn giấu link khi share script, xóa dòng trên và mở khóa dòng dưới:
-- local WEBHOOK_URL = getgenv().DISCORD_WEBHOOK
-- ========================================================

if not WEBHOOK_URL or WEBHOOK_URL == "" or WEBHOOK_URL == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
    warn("❌ Chưa điền link Webhook Discord vào đầu script kìa bor!")
    return
end

local shopConfigs = {
    SeedShop = { title = "Seed Shop Restocked", color = 3066993 },
    CrateShop = { title = "Crates Shop Restocked", color = 15844367 },
    GearShop = { title = "Gear Shop Restocked", color = 3447003 }
}

local function sendWebhook(embed)
    local payload = HttpService:JSONEncode({
        embeds = { embed }
    })
    
    local successReq, err = pcall(function()
        -- Ưu tiên dùng hàm request của Executor, nếu không có thì dùng HttpService thuần
        local requestFunc = syn and syn.request or http and http.request or request or http_request
        if requestFunc then
            return requestFunc({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        else
            return HttpService:PostAsync(WEBHOOK_URL, payload)
        end
    end)
    
    if successReq then
        print("⚡ [GỬI LIỀN] Đã push embed cho: " .. embed.title)
    else
        warn("❌ Lỗi khi gửi Webhook: ", err)
    end
end

local function processSingleShopAndPush(shopName)
    local config = shopConfigs[shopName]
    if not config then return end
    
    local shopFolder = stockValues:FindFirstChild(shopName)
    if not shopFolder then return end
    
    local itemsFolder = shopFolder:FindFirstChild("Items")
    if not itemsFolder then return end
    
    local fields = {}
    
    for _, child in ipairs(itemsFolder:GetChildren()) do
        if string.find(child.ClassName, "Value") and child.Value > 0 then
            table.insert(fields, {
                name = child.Name,
                value = "x" .. tostring(child.Value),
                inline = false
            })
        end
    end
    
    if #fields > 0 then
        local embed = {
            title = config.title,
            description = "A new rotation of stock is available.",
            color = config.color,
            fields = fields,
            timestamp = DateTime.now():ToIsoDate(),
            footer = {
                text = "Grow a Garden 2"
            }
        }
        sendWebhook(embed)
    end
end

local pendingUpdates = {}

local function queueShopUpdate(shopName)
    if pendingUpdates[shopName] then return end
    pendingUpdates[shopName] = true
    
    task.defer(function()
        processSingleShopAndPush(shopName)
        pendingUpdates[shopName] = false
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
                            queueShopUpdate(shopName)
                        end)
                    end
                end
                
                itemsFolder.ChildAdded:Connect(function(child)
                    if string.find(child.ClassName, "Value") then
                        child.Changed:Connect(function()
                            queueShopUpdate(shopName)
                        end)
                        queueShopUpdate(shopName)
                    end
                end)
            end
        end
    end
    print("🚀 [System]: I've enabled the STOCK SCHEDULE mode (Send immediately when value changes)! ")
end

-- Quét phát đầu tiên khi kích hoạt script
for shopName, _ in pairs(shopConfigs) do
    processSingleShopAndPush(shopName)
    task.wait(0.2)
end

startListening()

