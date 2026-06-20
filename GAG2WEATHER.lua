local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========================================================
-- CẤU HÌNH LINK WEBHOOK DISCORD CỦA ÔNG
-- ========================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1483471565130825791/-LjvHco3PqatsN5KAmDW96yktGJr9gKj-2E6wqL5EWZzOK8UHSEzQo2FF4vSGcaNIcGD0"
-- ========================================================

-- Tự động lấy cấu hình thời tiết từ Module tĩnh của game
local weatherModule = game:FindFirstChild("WeatherData", true)
local weatherDataList = weatherModule and require(weatherModule) or {}

-- Bảng màu + Icon ứng với từng loại thời tiết xuất hiện trong ảnh dump
local weatherStyle = {
    ["Rain"] = { color = 3447003, icon = "🌧️" },
    ["Lightning"] = { color = 16776960, icon = "⚡" },
    ["Rainbow"] = { color = 16711935, icon = "🌈" },
    ["Snowfall"] = { color = 65535, icon = "❄️" },
    ["Starfall"] = { color = 10181046, icon = "💫" },
    ["Aurora"] = { color = 5763719, icon = "🌌" },
    ["Clear"] = { color = 16753920, icon = "☀️" }
}

-- Hàm xử lý đóng gói Embed và gửi thẳng về Discord
local function sendWeatherWebhook(weatherName)
    -- Tìm info mô tả từ module tĩnh
    local info = weatherDataList[weatherName] or {}
    local desc = info.Description or "No special effects active."
    local duration = info.Last and (tostring(info.Last) .. "s") or "Unknown"
    
    local style = weatherStyle[weatherName] or { color = 16777215, icon = "🌤️" }

    local embed = {
        title = style.icon .. " Thời Tiết Thay Đổi: " .. weatherName,
        description = "**Hiệu ứng:** " .. desc,
        color = style.color,
        fields = {
            { name = "⏱️ Kéo dài", value = duration, inline = true }
        },
        timestamp = DateTime.now():ToIsoDate(),
        footer = { text = "Grow a Garden 2 | Weather Monitor" }
    }

    local payload = HttpService:JSONEncode({ embeds = { embed } })
    
    pcall(function()
        local requestFunc = syn and syn.request or http and http.request or request or http_request
        if requestFunc then
            requestFunc({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        else
            HttpService:PostAsync(WEBHOOK_URL, payload)
        end
    end)
    print("📢 [WEATHER]: Đã gửi thông báo thời tiết -> " .. weatherName)
end

-- ========================================================
-- BỘ TỰ ĐỘNG KHÓA MỤC TIÊU (LẮNG NGHE SỰ KIỆN ĐỔI THỜI TIẾT)
-- ========================================================
task.spawn(function()
    local sampleWeathers = {"Rain", "Lightning", "Rainbow", "Snowfall", "Starfall", "Aurora", "Clear"}
    local liveValueObject = nil

    -- Quét nhanh tìm cục StringValue lưu trạng thái thời tiết thực tế trong game
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("StringValue") then
            for _, name in ipairs(sampleWeathers) do
                if v.Value == name or string.find(string.lower(v.Name), "weather") then
                    liveValueObject = v
                    break
                end
            end
        end
        if liveValueObject then break end
    end

    if liveValueObject then
        print("🎯 Đã cắm mắt rình thời tiết tại: " .. liveValueObject:GetFullName())
        
        local lastWeather = liveValueObject.Value
        if lastWeather ~= "" then sendWeatherWebhook(lastWeather) end
        
        -- Event-driven: Cứ đổi giá trị là bắn ngay lập tức, không delay 1 giây nào
        liveValueObject.Changed:Connect(function(newWeather)
            if newWeather ~= lastWeather and newWeather ~= "" then
                lastWeather = newWeather
                sendWeatherWebhook(newWeather)
            end
        end)
    else
        warn("⚠️ Không tìm thấy StringValue thời tiết nào. Đang dùng chế độ quét sơ cua qua ReplicatedStorage Attribute...")
        local lastAttr = ""
        ReplicatedStorage.AttributeChanged:Connect(function(attrName)
            if string.find(string.lower(attrName), "weather") then
                local current = ReplicatedStorage:GetAttribute(attrName)
                if current and current ~= lastAttr and current ~= "" then
                    lastAttr = current
                    sendWeatherWebhook(current)
                end
            end
        end)
    end
end)

