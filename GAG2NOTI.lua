local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========================================================
-- WEBHOOK CONFIG
-- ========================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1524750327268507729/r3RIbRq6cSiQ8fErJVddbOojbtK65HuqZ4oGVA1Y-Lj7iOR6eja_5RWuHpQyn5pK2Ftv" -- Thay link webhook của bạn vào đây

-- ========================================================
-- SUPPORT FUNCTIOM
-- ========================================================
local function stripRichText(str)
    return (str:gsub("<[^>]+>", ""))
end

local function sendRequest(body)
    local reqFunc = nil

    if typeof(http) == "table" and typeof(http.request) == "function" then
        reqFunc = function()
            local ok1, res1 = pcall(function()
                return http.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
            end)
            if ok1 then return res1 end
            return http.request({ url = WEBHOOK_URL, method = "POST", headers = { ["Content-Type"] = "application/json" }, body = body })
        end
    elseif typeof(request) == "function" then
        reqFunc = function() return request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) end
    elseif typeof(http_request) == "function" then
        reqFunc = function() return http_request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) end
    elseif syn and typeof(syn.request) == "function" then
        reqFunc = function() return syn.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) end
    end

    if not reqFunc then return false, "No HTTP function found" end

    local ok, result = pcall(reqFunc)
    if not ok then return false, "Request threw error: " .. tostring(result) end
    if typeof(result) == "table" then
        local status = result.StatusCode or result.status
        if status and (status < 200 or status >= 300) then
            return false, "HTTP " .. tostring(status) .. ": " .. tostring(result.Body or result.StatusMessage or "")
        end
    end
    return true, result
end

local function sendWebhook(content)
    local payload = HttpService:JSONEncode({
        content = content
    })
    return sendRequest(payload)
end

-- ========================================================
-- LOGIC SEEK NOTIFICATION
-- ========================================================
local Networking = require(ReplicatedStorage.SharedModules.Networking)

local function onNotification(...)
    local args = {...}

    local rawText = nil
    
    for _, arg in ipairs(args) do
        if type(arg) == "string" and #arg > 0 then
            rawText = arg
            break
        end
    end

    if rawText then
        local cleanText = stripRichText(rawText)
        print("[NOTIFICATION HOOK]:", cleanText)
        
        local ok, err = sendWebhook("🔔 **New Notification:**\n" .. cleanText)
        if ok then
            print("[WEBHOOK] Sent successfully!")
        else
            warn("[WEBHOOK] Failed to send:", err)
        end
    end
end

pcall(function()
    Networking.Notification.OnClientEvent:Connect(onNotification)
    print("[✅ HOOKED] Networking.Notification.OnClientEvent")
end)

pcall(function()
    local NotifyFolder = ReplicatedStorage:WaitForChild("Notify", 5)
    if NotifyFolder then
        local NotifyEvent = NotifyFolder:WaitForChild("Event", 5)
        if NotifyEvent then
            NotifyEvent.Event:Connect(onNotification)
            print("[✅ HOOKED] ReplicatedStorage.Notify.Event")
        end
    end
end)

task.spawn(function()
    task.wait(3)
    local ok, err = sendWebhook("🟢 **Notification Hook Script is running!**")
    if ok then
        print("[WEBHOOK] Test message sent successfully!")
    else
        warn("[WEBHOOK] Test failed:", err)
    end
end)
