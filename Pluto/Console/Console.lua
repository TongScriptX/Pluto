-- console.lua
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

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

-- 性能优化配置
local UPDATE_THROTTLE = 0.05 -- UI更新节流时间（秒）
local MAX_VISIBLE_LOGS = 50 -- 最大可见日志数

-- 保存日志（按时间顺序存储）
local logHistory = {}
local pendingLogs = {} -- 待处理的日志队列
local lastUpdateTime = 0
local isUpdating = false
local nextLayoutOrder = 0 -- 使用递增的LayoutOrder而不是更新所有子项

-- 对象池（重用TextLabel）
local textLabelPool = {}
local function getLabel()
    if #textLabelPool > 0 then
        local label = table.remove(textLabelPool)
        label.Visible = true
        return label
    end
    return Instance.new("TextLabel")
end

local function returnLabel(label)
    label.Visible = false
    label.Parent = nil
    table.insert(textLabelPool, label)
end

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

-- 批量更新UI（优化：减少LayoutOrder更新）
local function updateUI()
    if isUpdating then return end
    isUpdating = true
    
    -- 处理待处理的日志
    for _, logData in ipairs(pendingLogs) do
        local msg, msgType = logData.msg, logData.msgType
        
        -- 添加到历史记录
        table.insert(logHistory, ("[%s] %s"):format(msgType.Name, msg))

        local line = getLabel()
        line.Size = UDim2.new(1, -10, 0, 0)
        line.AutomaticSize = Enum.AutomaticSize.Y
        line.BackgroundTransparency = 1
        line.TextColor3 = getColor(msgType)
        line.TextXAlignment = Enum.TextXAlignment.Left
        line.Font = Enum.Font.Code
        line.TextSize = 14
        line.Text = ("[%s] %s"):format(msgType.Name, msg)
        line.TextWrapped = true
        line.LayoutOrder = nextLayoutOrder
        nextLayoutOrder = nextLayoutOrder + 1
        
        line.Parent = ui.Scroll
    end
    
    -- 清空待处理队列
    pendingLogs = {}
    
    -- 限制可见日志数量（只删除超出限制的旧日志，不更新LayoutOrder）
    local children = ui.Scroll:GetChildren()
    local visibleCount = 0
    local textLabels = {}
    
    -- 收集所有TextLabel
    for _, child in ipairs(children) do
        if child:IsA("TextLabel") and child.Visible then
            table.insert(textLabels, child)
            visibleCount = visibleCount + 1
        end
    end
    
    -- 如果超过最大可见数量，删除最旧的
    if visibleCount > MAX_VISIBLE_LOGS then
        -- 按LayoutOrder排序（最小的最旧）
        table.sort(textLabels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        
        -- 删除超出限制的旧日志
        for i = 1, visibleCount - MAX_VISIBLE_LOGS do
            returnLabel(textLabels[i])
        end
    end
    
    isUpdating = false
    lastUpdateTime = tick()
end

-- 添加日志到队列
local function appendLog(msg, msgType)
    table.insert(pendingLogs, {msg = msg, msgType = msgType})
    
    -- 检查是否需要更新UI
    local currentTime = tick()
    if currentTime - lastUpdateTime >= UPDATE_THROTTLE then
        updateUI()
    end
end

-- 监听消息
local conn = LogService.MessageOut:Connect(function(msg, msgType)
    appendLog(msg, msgType)
end)

-- 清除旧日志
LogService:ClearOutput()

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
    -- 按时间顺序拼接日志（从早到晚）
    local output = table.concat(logHistory, "\n")
    local success = trySetClipboard(output)
    if success then
        ui.Notice.Text = "✅ 日志已复制并清空"
    else
        ui.Notice.Text = "⚠️ 无法自动复制，请手动复制文本"
    end

    -- 清空日志
    logHistory = {}
    pendingLogs = {}
    
    -- 返回所有标签到对象池
    for _, child in ipairs(ui.Scroll:GetChildren()) do
        if child:IsA("TextLabel") then
            returnLabel(child)
        end
    end
    
    nextLayoutOrder = 0
end)

-- 点击清空按钮
ui.ClearBtn.MouseButton1Click:Connect(function()
    logHistory = {}
    pendingLogs = {}
    
    -- 返回所有标签到对象池
    for _, child in ipairs(ui.Scroll:GetChildren()) do
        if child:IsA("TextLabel") then
            returnLabel(child)
        end
    end
    
    nextLayoutOrder = 0
    ui.Notice.Text = "🗑️ 日志已清空"
end)

-- 定期更新UI（确保待处理的日志被处理）
spawn(function()
    while true do
        task.wait(UPDATE_THROTTLE)
        if #pendingLogs > 0 then
            updateUI()
        end
    end
end)