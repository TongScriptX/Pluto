-- console.lua
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Console/ConsoleUI.lua"

-- Http请求获取UI代码
local success, uiCode = pcall(function()
    return game:HttpGet(url)
end)

if not success then
    warn("无法从GitHub加载UI代码")
    return
end

-- 运行UI代码，得到模块
local uiModule = loadstring(uiCode)()
local ui = uiModule.CreateUI(playerGui)

-- 配置
local MAX_VISIBLE_LOGS = 200
local DUPLICATE_MERGE_TIME = 1.5 -- 相同消息合并时间窗口（秒）

-- 保存日志
local logHistory = {}
local logCount = 0

-- 用于合并的临时存储
local lastLog = nil -- {msg, msgType, label, count, time}

-- 根据类型获取颜色
local function getColor(msgType)
    if msgType == Enum.MessageType.MessageOutput then
        return Color3.fromRGB(255, 255, 255)
    elseif msgType == Enum.MessageType.MessageWarning then
        return Color3.fromRGB(255, 215, 0)
    elseif msgType == Enum.MessageType.MessageError then
        return Color3.fromRGB(255, 69, 58)
    else
        return Color3.fromRGB(200, 200, 200)
    end
end

-- 获取当前时间字符串
local function getTimeString()
    local now = DateTime.now()
    return string.format("%02d:%02d:%02d", now.Hour, now.Minute, now.Second)
end

-- 添加日志
local function addLog(msg, msgType)
    local currentTime = tick()
    local timeStr = getTimeString()
    
    -- 添加到历史记录
    local historyText = string.format("[%s] [%s] %s", timeStr, msgType.Name, msg)
    table.insert(logHistory, historyText)
    
    -- 检查是否可以合并
    local canMerge = false
    if lastLog and lastLog.msg == msg and lastLog.msgType == msgType then
        if (currentTime - lastLog.time) <= DUPLICATE_MERGE_TIME and lastLog.label and lastLog.label.Parent then
            canMerge = true
        end
    end
    
    if canMerge then
        -- 合并到上一条
        lastLog.count = lastLog.count + 1
        lastLog.time = currentTime
        lastLog.label.Text = string.format("[%s] [%s x%d] %s", timeStr, msgType.Name, lastLog.count, msg)
    else
        -- 创建新行
        local line = Instance.new("TextLabel")
        line.Size = UDim2.new(1, -10, 0, 0)
        line.AutomaticSize = Enum.AutomaticSize.Y
        line.BackgroundTransparency = 1
        line.TextColor3 = getColor(msgType)
        line.TextXAlignment = Enum.TextXAlignment.Left
        line.Font = Enum.Font.Code
        line.TextSize = 14
        line.Text = string.format("[%s] [%s] %s", timeStr, msgType.Name, msg)
        line.TextWrapped = true
        line.Parent = ui.Scroll
        
        -- 更新最后日志
        lastLog = {
            msg = msg,
            msgType = msgType,
            label = line,
            count = 1,
            time = currentTime
        }
        
        logCount = logCount + 1
    end
    
    -- 限制日志数量
    local children = ui.Scroll:GetChildren()
    local labels = {}
    for _, child in ipairs(children) do
        if child:IsA("TextLabel") then
            table.insert(labels, child)
        end
    end
    
    if #labels > MAX_VISIBLE_LOGS then
        -- 删除最旧的（第一个子元素）
        for i = 1, #labels - MAX_VISIBLE_LOGS do
            if labels[i] then
                labels[i]:Destroy()
            end
        end
    end
end

-- 监听消息
LogService.MessageOut:Connect(function(msg, msgType)
    addLog(msg, msgType)
end)

-- 复制函数
local function trySetClipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    elseif syn and syn.set_clipboard then
        syn.set_clipboard(text)
        return true
    elseif clipboard and clipboard.set then
        clipboard.set(text)
        return true
    end
    return false
end

-- 点击复制按钮
ui.CopyBtn.MouseButton1Click:Connect(function()
    local output = table.concat(logHistory, "\n")
    local success = trySetClipboard(output)
    if success then
        ui.Notice.Text = "✅ 日志已复制并清空"
    else
        ui.Notice.Text = "⚠️ 无法自动复制"
    end

    logHistory = {}
    logCount = 0
    lastLog = nil
    
    for _, child in ipairs(ui.Scroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end)

-- 点击清空按钮
ui.ClearBtn.MouseButton1Click:Connect(function()
    logHistory = {}
    logCount = 0
    lastLog = nil
    
    for _, child in ipairs(ui.Scroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    ui.Notice.Text = "🗑️ 日志已清空"
end)
