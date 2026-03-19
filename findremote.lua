local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local CoreGui     = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ── GUI ─────────────────────────────────────────────────────────────────────
local uiLayer = (gethui and gethui()) or CoreGui
if uiLayer:FindFirstChild("GHZ_Finder_UI") then uiLayer.GHZ_Finder_UI:Destroy() end

local sg = Instance.new("ScreenGui"); sg.Name = "GHZ_Finder_UI"
sg.ResetOnSpawn = false; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = uiLayer

-- nền
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 340, 0, 460)
frame.Position = UDim2.new(0.5, -170, 0.5, -230)
frame.BackgroundColor3 = Color3.fromRGB(14, 17, 26)
frame.BackgroundTransparency = 0.04
frame.BorderSizePixel = 0
frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(80, 160, 255)
stroke.Thickness = 1.5; stroke.Parent = frame

-- title
local titleBar = Instance.new("Frame"); titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 55, 110); titleBar.BorderSizePixel = 0; titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
local titleLbl = Instance.new("TextLabel"); titleLbl.Size = UDim2.new(1, -36, 1, 0)
titleLbl.Position = UDim2.new(0, 8, 0, 0); titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🔍 GHZ Remote Finder"
titleLbl.TextColor3 = Color3.fromRGB(130, 200, 255); titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = titleBar

-- nút x
local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -32, 0, 2); closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel = 0; closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14; closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- status
local statusLbl = Instance.new("TextLabel"); statusLbl.Size = UDim2.new(1, -12, 0, 20)
statusLbl.Position = UDim2.new(0, 6, 0, 38); statusLbl.BackgroundTransparency = 1
statusLbl.Text = "⏳ Đang hook remotes..."; statusLbl.TextColor3 = Color3.fromRGB(255, 220, 80)
statusLbl.Font = Enum.Font.GothamMedium; statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left; statusLbl.Parent = frame

-- Instruction
local instrLbl = Instance.new("TextLabel"); instrLbl.Size = UDim2.new(1, -12, 0, 30)
instrLbl.Position = UDim2.new(0, 6, 0, 58); instrLbl.BackgroundTransparency = 1
instrLbl.Text = "💡 Script Find Remote 🎯"
instrLbl.TextColor3 = Color3.fromRGB(180, 180, 180); instrLbl.Font = Enum.Font.Gotham
instrLbl.TextSize = 10; instrLbl.TextXAlignment = Enum.TextXAlignment.Left
instrLbl.TextWrapped = true; instrLbl.Parent = frame

-- Divider
local div = Instance.new("Frame"); div.Size = UDim2.new(1, -12, 0, 1)
div.Position = UDim2.new(0, 6, 0, 92); div.BackgroundColor3 = Color3.fromRGB(50, 80, 120)
div.BorderSizePixel = 0; div.Parent = frame

-- Scrolling list
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -12, 0, 350); scroll.Position = UDim2.new(0, 6, 0, 96)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 160, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = frame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = scroll

local rowCount = 0
local function addRow(text, color, isBig)
    rowCount = rowCount + 1
    local row = Instance.new("TextLabel"); row.Size = UDim2.new(1, -8, 0, isBig and 36 or 20)
    row.BackgroundTransparency = 1; row.Text = text
    row.TextColor3 = color or Color3.fromRGB(210, 210, 210); row.Font = Enum.Font.Gotham
    row.TextSize = isBig and 11 or 10; row.TextXAlignment = Enum.TextXAlignment.Left
    row.TextWrapped = true; row.LayoutOrder = rowCount; row.Parent = scroll
end

-- ── KEYWORDS ────────────────────────────────────────────────────────────────
local STOCK_KEYWORDS = {"stock","seed","gear","shop","restock","item","quantity","supply","available","amount","market"}
local function isRelevant(str)
    local s = str:lower()
    for _, kw in ipairs(STOCK_KEYWORDS) do if s:find(kw) then return true end end
    return false
end

local function safeEncode(v)
    local ok, s = pcall(function() return HttpService:JSONEncode(v) end)
    return ok and s or tostring(v)
end

-- ── LIST ALL REMOTES ────────────────────────────────────────────────────────
local remoteList = {}
for _, v in pairs(game:GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
        table.insert(remoteList, v)
    end
end

statusLbl.Text = string.format("✅ Đã hook %d Remotes — Mở shop!", #remoteList)
addRow("── Tất cả Remotes ──", Color3.fromRGB(100, 120, 160))
for _, v in ipairs(remoteList) do
    local isRel = isRelevant(v:GetFullName())
    local prefix = isRel and "🔵 " or "   "
    local color  = isRel and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(150, 150, 150)
    addRow(prefix .. v:GetFullName(), color)
end
addRow("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", Color3.fromRGB(60, 80, 120))
addRow("🎯 Remotes ĐÃ NHẬN DATA Stock:", Color3.fromRGB(255, 220, 60), true)

-- ── HOOK ────────────────────────────────────────────────────────────────────
local found = {}
for _, v in ipairs(remoteList) do
    if v:IsA("RemoteEvent") then
        local path = v:GetFullName()
        v.OnClientEvent:Connect(function(...)
            local args   = { ... }
            local encoded = safeEncode(args)
            if isRelevant(encoded) or isRelevant(path) then
                if not found[path] then
                    found[path] = true
                    -- Hiện lên scrolling list
                    addRow("🎯 " .. path, Color3.fromRGB(80, 255, 120), true)
                    addRow("   Args: " .. encoded:sub(1, 120), Color3.fromRGB(180, 255, 180))
                    statusLbl.Text = "🎯 Tìm thấy! Xem danh sách bên dưới"
                    statusLbl.TextColor3 = Color3.fromRGB(80, 255, 80)
                    -- Tự cuộn xuống
                    task.wait(0.1)
                    scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
                end
            end
        end)
    end
end
