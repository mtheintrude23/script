--[[
    Script dò dữ liệu shop / seed / gear / crates trong game Grow A Garden 2
    Yêu cầu executor hỗ trợ: getgc, getloadedmodules, debug.getconstants, hookfunction, v.v.
    Chạy script này và quan sát output ở console (F9).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Hàm tiện ích: in đẹp bảng (tránh lỗi circular reference)
local function printTable(t, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. " = {")
            printTable(v, indent + 1)
            print(prefix .. "}")
        else
            print(prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

-- 1. Quét tất cả RemoteEvent và RemoteFunction có tên liên quan
print("===== Đang quét Remotes liên quan =====")
local keywords = {"shop", "stock", "seed", "gear", "crate", "inventory", "item", "buy", "purchase"}
local foundRemotes = {}

for _, obj in pairs(game:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        local lowerName = obj.Name:lower()
        for _, kw in ipairs(keywords) do
            if lowerName:find(kw) then
                table.insert(foundRemotes, obj)
                break
            end
        end
    end
end

print("Tìm thấy " .. #foundRemotes .. " remote phù hợp:")
for _, r in ipairs(foundRemotes) do
    print("  " .. r:GetFullName() .. " [" .. r.ClassName .. "]")
end

-- 2. Thử invoke các RemoteFunction (có thể trả về dữ liệu)
print("\n===== Thử invoke RemoteFunction =====")
for _, remote in ipairs(foundRemotes) do
    if remote:IsA("RemoteFunction") then
        -- Thử nhiều kiểu tham số khác nhau
        local testArgs = {
            {},                     -- không tham số
            {""},                   -- string rỗng
            {0},                    -- số 0
            {LocalPlayer},          -- player
            {"Shop"},               -- tên shop
            {"Seeds"},              -- loại
            {"Gears"},
            {"Crates"},
        }
        for _, args in ipairs(testArgs) do
            local success, result = pcall(function()
                return remote:InvokeServer(unpack(args))
            end)
            if success then
                print("Gọi " .. remote.Name .. "(" .. table.concat(args, ", ") .. ") =>")
                if type(result) == "table" then
                    printTable(result, 1)
                else
                    print("  " .. tostring(result))
                end
            else
                -- Có thể lỗi do sai tham số, bỏ qua
            end
        end
    end
end

-- 3. Dùng getgc() để tìm bảng chứa dữ liệu shop trong bộ nhớ
if getgc then
    print("\n===== Quét bộ nhớ (getgc) tìm dữ liệu shop =====")
    local foundData = false
    for _, v in pairs(getgc()) do
        if type(v) == "table" then
            local hasShop = rawget(v, "Shop") or rawget(v, "shop") or rawget(v, "Store")
            local hasSeeds = rawget(v, "Seeds") or rawget(v, "seeds")
            local hasGears = rawget(v, "Gears") or rawget(v, "gears")
            local hasCrates = rawget(v, "Crates") or rawget(v, "crates")
            if hasShop or hasSeeds or hasGears or hasCrates then
                print("Tìm thấy bảng nghi ngờ chứa dữ liệu shop:")
                printTable(v)
                foundData = true
                break -- Bỏ break nếu muốn quét hết
            end
        end
    end
    if not foundData then
        print("Không tìm thấy bảng shop rõ ràng trong bộ nhớ.")
    end
else
    print("\nExecutor không hỗ trợ getgc, bỏ qua bước quét bộ nhớ.")
end

-- 4. Phân tích các ModuleScript đã nạp (dành cho executor mạnh)
if getloadedmodules then
    print("\n===== Quét loaded modules tìm constants =====")
    for _, module in ipairs(getloadedmodules()) do
        local success, constants = pcall(debug.getconstants, module)
        if success and constants then
            for _, c in ipairs(constants) do
                if type(c) == "string" then
                    local lower = c:lower()
                    if lower:find("seed") or lower:find("gear") or lower:find("crate") or lower:find("shop") then
                        print("Module: " .. module.Name .. " chứa chuỗi: " .. c)
                    end
                end
            end
        end
    end
else
    print("\nExecutor không hỗ trợ getloadedmodules.")
end

-- 5. Hook vào các RemoteEvent để xem dữ liệu khi server gửi về client
print("\n===== Cài hook vào Remotes để bắt dữ liệu từ server =====")
for _, remote in ipairs(foundRemotes) do
    if remote:IsA("RemoteEvent") then
        -- Hook sự kiện OnClientEvent
        local success, err = pcall(function()
            local oldSignal = remote.OnClientEvent
            local hooked = hookfunction(remote.OnClientEvent, function(...)
                local args = {...}
                print("RemoteEvent " .. remote.Name .. " nhận từ server:", unpack(args))
                -- Gọi hàm gốc
                return oldSignal(...)
            end)
        end)
        if not success then
            print("Không thể hook " .. remote.Name .. ": " .. tostring(err))
        end
    end
end

print("\n===== Hoàn tất cài đặt. Hãy mở shop trong game để thấy dữ liệu được in ra. =====")
