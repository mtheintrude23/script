local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========================================================
-- CẤU HÌNH WEBHOOK
-- ========================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1483471565130825791/-LjvHco3PqatsN5KAmDW96yktGJr9gKj-2E6wqL5EWZzOK8UHSEzQo2FF4vSGcaNIcGD0"
-- ========================================================

-- Lấy description từ WeatherData module (nếu có)
local weatherModule = game:FindFirstChild("WeatherData", true)
local weatherDataList = weatherModule and require(weatherModule) or {}

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
-- GỬI WEBHOOK
-- endTimeUnix: số unix timestamp lấy từ EndTime value
-- ========================================================
local function sendWeatherWebhook(weatherName, endTimeUnix)
    local info  = weatherDataList[weatherName] or {}
    local desc  = info.Description or "Không có mô tả."
    local style = weatherStyle[weatherName] or { color = 16777215, icon = "🌤️" }

    -- Discord unix timestamp: <t:UNIX:R> = relative, <t:UNIX:F> = full datetime
    local endsField
    if endTimeUnix and endTimeUnix > 0 then
        endsField = "<t:" .. math.floor(endTimeUnix) .. ":R>  (`<t:" .. math.floor(endTimeUnix) .. ":F>`)"
    else
        endsField = "Không rõ"
    end

    local embed = {
        title       = style.icon .. .. weatherName,
        description = "**Description:** " .. desc,
        color       = style.color,
        fields      = {
            {
                name   = "Ends in:",
                value  = endsField,
                inline = false
            },
        },
        -- timestamp ISO dùng cho footer Discord (thời điểm gửi)
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

    print("📢 [WEATHER] Đã gửi -> " .. weatherName .. " | Ends: " .. tostring(endTimeUnix))
end

-- ========================================================
-- THEO DÕI WeatherValues
-- Mỗi Folder con = 1 loại thời tiết, có BoolValue "Playing" và NumberValue "EndTime"
-- ========================================================
local WeatherValues = ReplicatedStorage:WaitForChild("WeatherValues", 10)

if not WeatherValues then
    warn("❌ Không tìm thấy ReplicatedStorage.WeatherValues")
    return
end

-- Hàm gắn listener cho 1 weather folder
local function hookWeatherFolder(folder)
    local playingVal = folder:FindFirstChild("Playing")
    local endTimeVal = folder:FindFirstChild("EndTime")

    if not playingVal or not playingVal:IsA("BoolValue") then return end

    playingVal.Changed:Connect(function(isPlaying)
        if isPlaying then
            local endUnix = (endTimeVal and endTimeVal.Value > 0) and endTimeVal.Value or 0
            sendWeatherWebhook(folder.Name, endUnix)
        end
    end)

    print("✅ Đã hook: " .. folder.Name)
end

-- Hook tất cả folder hiện có
for _, child in ipairs(WeatherValues:GetChildren()) do
    if child:IsA("Folder") then
        hookWeatherFolder(child)
    end
end

-- Hook folder mới thêm sau (phòng game cập nhật thêm weather)
WeatherValues.ChildAdded:Connect(function(child)
    if child:IsA("Folder") then
        hookWeatherFolder(child)
    end
end)

-- Kiểm tra ngay lúc script chạy xem có weather nào đang Playing không
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

print("🌦️ Weather Monitor đang chạy — đang lắng nghe WeatherValues...")
