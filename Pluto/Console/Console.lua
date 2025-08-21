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

-- 清除旧日志
LogService:ClearOutput()

local output = ""

-- 根据类型获取颜色
local function getColor(msgType)
    if msgType == Enum.MessageType.MessageOutput then
        return Color3.fromRGB(255, 255, 255) -- 白色
    elseif msgType == Enum.MessageType.MessageWarning then
        return Color3.fromRGB(255, 215, 0) -- 黄色
    elseif msgType == Enum.MessageType.MessageError then
        return Color3.fromRGB(255, 69, 58) -- 红色
    else
        return Color3.fromRGB(200, 200, 200) -- 默认灰
    end
end

-- 在TextLabel中追加一行彩色文本
local function appendLog(msg, msgType)
    output ..= ("[%s] %s\n"):format(msgType.Name, msg)

    local line = Instance.new("TextLabel")
    line.Size = UDim2.new(1, 0, 0, 20)
    line.BackgroundTransparency = 1
    line.TextColor3 = getColor(msgType)
    line.TextXAlignment = Enum.TextXAlignment.Left
    line.Font = Enum.Font.Code
    line.TextSize = 14
    line.Text = ("[%s] %s"):format(msgType.Name, msg)
    line.Parent = ui.LogContainer -- 假设UI里有一个ScrollingFrame叫LogContainer
end

-- 监听消息
local conn = LogService.MessageOut:Connect(function(msg, msgType)
    appendLog(msg, msgType)
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
    local success = trySetClipboard(output)
    if success then
        ui.Notice.Text = "✅ 日志已复制并清空"
    else
        ui.Notice.Text = "⚠️ 无法自动复制，请手动复制文本"
    end

    -- 清空日志
    output = ""
    for _, child in ipairs(ui.LogContainer:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end)