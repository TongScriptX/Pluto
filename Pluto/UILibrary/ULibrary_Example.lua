-- MainScript.lua: 示例 UI 模板
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- 加载 UI 库
local success, UILibrary = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"))()
end)
if not success or not UILibrary then
    error("Failed to load PlutoUILibrary: " .. tostring(UILibrary))
end

-- 获取当前玩家
local player = Players.LocalPlayer
if not player then
    error("Unable to get current player")
end

-- 配置
local config = {
    webhookUrl = "",
    notifyCurrency = false,
    notifyLeaderboard = false,
    leaderboardKick = false,
    notificationInterval = 60,
    targetCurrencyEnabled = false,
    targetCurrency = 0,
    currentTheme = "Dark"
}

-- 主题定义
local THEME_DARK = {
    Primary = Color3.fromRGB(63, 81, 181),
    Background = Color3.fromRGB(30, 30, 30),
    SecondaryBackground = Color3.fromRGB(46, 46, 46),
    Accent = Color3.fromRGB(92, 107, 192),
    Text = Color3.fromRGB(255, 255, 255),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54),
    Font = Enum.Font.Gotham
}

local THEME_LIGHT = {
    Primary = Color3.fromRGB(33, 150, 243),
    Background = Color3.fromRGB(245, 245, 245),
    SecondaryBackground = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(100, 181, 246),
    Text = Color3.fromRGB(33, 33, 33),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54),
    Font = Enum.Font.Gotham
}

-- 创建主窗口
local mainFrame, screenGui, tabBar, leftFrame, rightFrame = UILibrary:CreateWindow()
if not mainFrame then
    error("Failed to create main window")
end
UILibrary:MakeDraggable(mainFrame)
print("Main Window Created")

-- 悬浮按钮
local toggleButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "O"
})
print("Floating Button Created")

-- 主题切换按钮
local themeButton = UILibrary:CreateButton(mainFrame, {
    Text = "Switch to Light Theme",
    Callback = function()
        if config.currentTheme == "Dark" then
            UILibrary:SetTheme(THEME_LIGHT)
            config.currentTheme = "Light"
            themeButton.Text = "Switch to Dark Theme"
            UILibrary:Notify({ Title = "Theme Changed", Text = "Switched to Light Theme", Duration = 3 })
        else
            UILibrary:SetTheme(THEME_DARK)
            config.currentTheme = "Dark"
            themeButton.Text = "Switch to Light Theme"
            UILibrary:Notify({ Title = "Theme Changed", Text = "Switched to Dark Theme", Duration = 3 })
        end
        print("Theme Switched to:", config.currentTheme)
    end
})

-- 左侧区域：信息展示
local infoCard = UILibrary:CreateCard(leftFrame, { Height = 100 })
local gameStatusLabel = UILibrary:CreateLabel(infoCard, { Text = "Game Status: Running" })
local onlineTimeLabel = UILibrary:CreateLabel(infoCard, { Text = "Online Time: 0:00:00", Position = UDim2.new(0, 5, 0, 25) })
local currencyLabel = UILibrary:CreateLabel(infoCard, { Text = "Currency: 0", Position = UDim2.new(0, 5, 0, 45) })
print("Info Card Created")

-- 右侧区域：Notifications 标签页
local notifyTab, notifyContent = UILibrary:CreateTab(tabBar, rightFrame, {
    Text = "Notifications",
    Active = true
})

-- Webhook 配置卡片
local webhookCard = UILibrary:CreateCard(notifyContent, { Height = 60 })
local webhookLabel = UILibrary:CreateLabel(webhookCard, { Text = "Webhook URL" })
local webhookInput = UILibrary:CreateTextBox(webhookCard, {
    PlaceholderText = "Enter Webhook URL",
    OnFocusLost = function()
        config.webhookUrl = webhookInput.Text
        if config.webhookUrl:match("^https?://") then
            UILibrary:Notify({ Title = "Webhook Set", Text = "Webhook URL updated", Duration = 3 })
        else
            UILibrary:Notify({ Title = "Error", Text = "Invalid Webhook URL", Duration = 3 })
        end
        print("Webhook URL Set:", config.webhookUrl)
    end
})

-- 通知开关卡片
local togglesCard = UILibrary:CreateCard(notifyContent, { Height = 100 })
local notifyCurrencyToggle = UILibrary:CreateToggle(togglesCard, {
    Text = "Notify Currency",
    DefaultState = config.notifyCurrency,
    Callback = function(state)
        config.notifyCurrency = state
        UILibrary:Notify({ Title = "Config Updated", Text = "Notify Currency: " .. (state and "On" or "Off"), Duration = 3 })
        print("Notify Currency Set:", state)
    end
})
local notifyLeaderboardToggle = UILibrary:CreateToggle(togglesCard, {
    Text = "Notify Leaderboard",
    DefaultState = config.notifyLeaderboard,
    Callback = function(state)
        config.notifyLeaderboard = state
        UILibrary:Notify({ Title = "Config Updated", Text = "Notify Leaderboard: " .. (state and "On" or "Off"), Duration = 3 })
        print("Notify Leaderboard Set:", state)
    end
})
local leaderboardKickToggle = UILibrary:CreateToggle(togglesCard, {
    Text = "Leaderboard Kick",
    DefaultState = config.leaderboardKick,
    Callback = function(state)
        config.leaderboardKick = state
        UILibrary:Notify({ Title = "Config Updated", Text = "Leaderboard Kick: " .. (state and "On" or "Off"), Duration = 3 })
        print("Leaderboard Kick Set:", state)
    end
})

-- 通知间隔卡片
local intervalCard = UILibrary:CreateCard(notifyContent, { Height = 60 })
local intervalLabel = UILibrary:CreateLabel(intervalCard, { Text = "Notification Interval (seconds)" })
local intervalInput = UILibrary:CreateTextBox(intervalCard, {
    PlaceholderText = "Enter interval",
    Text = tostring(config.notificationInterval),
    OnFocusLost = function()
        local num = tonumber(intervalInput.Text)
        if num and num > 0 then
            config.notificationInterval = num
            UILibrary:Notify({ Title = "Config Updated", Text = "Interval set to " .. num .. " seconds", Duration = 3 })
        else
            intervalInput.Text = tostring(config.notificationInterval)
            UILibrary:Notify({ Title = "Error", Text = "Invalid interval", Duration = 3 })
        end
        print("Notification Interval Set:", config.notificationInterval)
    end
})

-- 目标货币卡片
local targetCurrencyCard = UILibrary:CreateCard(notifyContent, { Height = 80 })
local targetCurrencyToggle = UILibrary:CreateToggle(targetCurrencyCard, {
    Text = "Target Currency",
    DefaultState = config.targetCurrencyEnabled,
    Callback = function(state)
        if state and config.targetCurrency <= 0 then
            config.targetCurrencyEnabled = false
            targetCurrencyToggle[2] = false
            UILibrary:Notify({ Title = "Error", Text = "Set a valid target currency", Duration = 3 })
        else
            config.targetCurrencyEnabled = state
            UILibrary:Notify({ Title = "Config Updated", Text = "Target Currency: " .. (state and "On" or "Off"), Duration = 3 })
        end
        print("Target Currency Enabled:", state)
    end
})
local targetCurrencyLabel = UILibrary:CreateLabel(targetCurrencyCard, {
    Text = "Target Currency Amount",
    Position = UDim2.new(0, 5, 0, 30)
})
local targetCurrencyInput = UILibrary:CreateTextBox(targetCurrencyCard, {
    PlaceholderText = "Enter amount",
    Text = tostring(config.targetCurrency),
    Position = UDim2.new(0, 5, 0, 50),
    OnFocusLost = function()
        local num = tonumber(targetCurrencyInput.Text)
        if num and num > 0 then
            config.targetCurrency = num
            UILibrary:Notify({ Title = "Config Updated", Text = "Target Currency set to " .. num, Duration = 3 })
        else
            targetCurrencyInput.Text = tostring(config.targetCurrency)
            UILibrary:Notify({ Title = "Error", Text = "Invalid amount", Duration = 3 })
        end
        print("Target Currency Amount Set:", config.targetCurrency)
    end
})

-- 测试通知按钮
local testNotifyButton = UILibrary:CreateButton(notifyContent, {
    Text = "Test Notification",
    Callback = function()
        UILibrary:Notify({ Title = "Test Success", Text = "This is a test notification!", Duration = 3 })
        print("Test Notification Triggered")
    end
})

-- 右侧区域：About 标签页
local aboutTab, aboutContent = UILibrary:CreateTab(tabBar, rightFrame, {
    Text = "About"
})

-- 作者信息
local authorInfo = UILibrary:CreateAuthorInfo(aboutContent, {
    Text = "Author: YourName\nVersion: 1.0.0",
    SocialText = "Join Discord",
    SocialCallback = function()
        UILibrary:Notify({ Title = "Discord", Text = "Discord link copied to clipboard!", Duration = 3 })
        print("Discord Link Clicked")
    end
})

-- 模拟在线时间更新
spawn(function()
    local startTime = os.time()
    while wait(1) do
        local elapsed = os.time() - startTime
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local seconds = elapsed % 60
        onlineTimeLabel.Text = string.format("Online Time: %02d:%02d:%02d", hours, minutes, seconds)
    end
end)

-- 初始通知
UILibrary:Notify({
    Title = "UI Loaded",
    Text = "Example UI template loaded successfully!",
    Duration = 3
})
print("UI Initialization Complete")
