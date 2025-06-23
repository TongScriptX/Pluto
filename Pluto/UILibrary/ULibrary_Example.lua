-- MainScript.lua: 示例 UI 模板
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- 加载 UI 库
local UILibrary
local success, result = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
    local response = game:HttpGet(url)
    print("[Init]: HttpGet Response Length:", #response)
    print("[Init]: HttpGet Response Preview:", string.sub(response, 1, 100))
    return response
end)

if success and result then
    local success2, module = pcall(function()
        local loaded = loadstring(result)
        if not loaded then
            error("loadstring returned nil")
        end
        return loaded()
    end)
    if success2 and module then
        UILibrary = module
        print("[Init]: PlutoUILibrary loaded successfully")
    else
        error("[Init]: Failed to execute PlutoUILibrary: " .. tostring(module))
    end
else
    error("[Init]: Failed to fetch PlutoUILibrary: " .. tostring(result))
end

-- 获取当前玩家
local player = Players.LocalPlayer
if not player then
    error("[Init]: Unable to get current player")
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
    Font = Enum.Font.Roboto
}

local THEME_LIGHT = {
    Primary = Color3.fromRGB(33, 150, 243),
    Background = Color3.fromRGB(245, 245, 245),
    SecondaryBackground = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(100, 181, 246),
    Text = Color3.fromRGB(33, 33, 33),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54),
    Font = Enum.Font.Roboto
}

-- 创建主窗口
local mainFrame, screenGui, sidebar, titleLabel, mainPage
local success, a, b, c, d, e = pcall(UILibrary.CreateWindow, UILibrary)
if success then
    mainFrame, screenGui, sidebar, titleLabel, mainPage = a, b, c, d, e
    if not mainFrame or not screenGui or not sidebar or not titleLabel or not mainPage then
        error("[Init]: CreateWindow returned incomplete values")
    end
    UILibrary:MakeDraggable(mainFrame)
    print("[Init]: Main Window Created: Size =", mainFrame.Size, "Position =", mainFrame.Position)
else
    error("[Init]: Failed to create main window: " .. tostring(a))
end

-- 悬浮按钮
local toggleButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "O"
})
if not toggleButton then
    warn("[Init]: Floating Button Creation Failed")
else
    print("[Init]: Floating Button Created")
end

-- 创建标签页
local function createTabSafe(text, active)
    local success, tabButton, content = pcall(function()
        return UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
            Text = text,
            Active = active
        })
    end)
    if success and tabButton and content then
        return tabButton, content
    else
        warn("[Tab]: Failed to create tab: " .. text .. ", Error: " .. tostring(tabButton or content))
        return nil, nil
    end
end

-- 主页
local homeTab, homeContent = createTabSafe("Home", true)
if homeTab and homeContent then
    local infoCard = UILibrary:CreateCard(homeContent, { Height = 80 })
    if infoCard then
        local gameStatusLabel = UILibrary:CreateLabel(infoCard, { Text = "Game Status: Running" })
        local onlineTimeLabel = UILibrary:CreateLabel(infoCard, { Text = "Online Time: 0:00:00", Position = UDim2.new(0, 5, 0, 20) })
        local currencyLabel = UILibrary:CreateLabel(infoCard, { Text = "Currency: 0", Position = UDim2.new(0, 5, 0, 35) })
        print("[Init]: Home Tab Created")
    else
        warn("[Init]: Failed to create Home tab card")
    end
else
    warn("[Init]: Home Tab Creation Failed")
end

-- 主要功能
local featuresTab, featuresContent = createTabSafe("Features", false)
if featuresTab and featuresContent then
    local webhookCard = UILibrary:CreateCard(featuresContent, { Height = 50 })
    if webhookCard then
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
                print("[Webhook]: URL Set:", config.webhookUrl)
            end
        })
    end

    local togglesCard = UILibrary:CreateCard(featuresContent, { Height = 80 })
    if togglesCard then
        local notifyCurrencyToggle = UILibrary:CreateToggle(togglesCard, {
            Text = "Notify Currency",
            DefaultState = config.notifyCurrency,
            Callback = function(state)
                config.notifyCurrency = state
                UILibrary:Notify({ Title = "Config Updated", Text = "Notify Currency: " .. (state and "On" or "Off"), Duration = 3 })
                print("[Toggle]: Notify Currency Set:", state)
            end
        })
        local notifyLeaderboardToggle = UILibrary:CreateToggle(togglesCard, {
            Text = "Notify Leaderboard",
            DefaultState = config.notifyLeaderboard,
            Callback = function(state)
                config.notifyLeaderboard = state
                UILibrary:Notify({ Title = "Config Updated", Text = "Notify Leaderboard: " .. (state and "On" or "Off"), Duration = 3 })
                print("[Toggle]: Notify Leaderboard Set:", state)
            end
        })
        local leaderboardKickToggle = UILibrary:CreateToggle(togglesCard, {
            Text = "Leaderboard Kick",
            DefaultState = config.leaderboardKick,
            Callback = function(state)
                config.leaderboardKick = state
                UILibrary:Notify({ Title = "Config Updated", Text = "Leaderboard Kick: " .. (state and "On" or "Off"), Duration = 3 })
                print("[Toggle]: Leaderboard Kick Set:", state)
            end
        })
    end

    local testNotifyButton = UILibrary:CreateButton(featuresContent, {
        Text = "Test Notification",
        Callback = function()
            UILibrary:Notify({ Title = "Test Success", Text = "This is a test notification!", Duration = 3 })
            print("[Button]: Test Notification Triggered")
        end
    })
    print("[Init]: Features Tab Created")
else
    warn("[Init]: Features Tab Creation Failed")
end

-- 设置
local settingsTab, settingsContent = createTabSafe("Settings", false)
if settingsTab and settingsContent then
    local intervalCard = UILibrary:CreateCard(settingsContent, { Height = 50 })
    if intervalCard then
        local intervalLabel = UILibrary:CreateLabel(intervalCard, { Text = "Notification Interval (s)" })
        local intervalInput = UILibrary:CreateTextBox(intervalCard, {
            PlaceholderText = "Enter interval",
            Text = tostring(config.notificationInterval),
            OnFocusLost = function()
                local num = tonumber(intervalInput.Text)
                if num and num > 0 then
                    config.notificationInterval = num
                    UILibrary:Notify({ Title = "Config Updated", Text = "Interval set to " .. num .. " s", Duration = 3 })
                else
                    intervalInput.Text = tostring(config.notificationInterval)
                    UILibrary:Notify({ Title = "Error", Text = "Invalid interval", Duration = 3 })
                end
                print("[TextBox]: Notification Interval Set:", config.notificationInterval)
            end
        })
    end

    local targetCurrencyCard = UILibrary:CreateCard(settingsContent, { Height = 60 })
    if targetCurrencyCard then
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
                print("[Toggle]: Target Currency Set:", state)
            end
        })
        local targetCurrencyLabel = UILibrary:CreateLabel(targetCurrencyCard, {
            Text = "Target Currency Amount",
            Position = UDim2.new(0, 5, 0, 20)
        })
        local targetCurrencyInput = UILibrary:CreateTextBox(targetCurrencyCard, {
            PlaceholderText = "Enter amount",
            Text = tostring(config.targetCurrency),
            Position = UDim2.new(0, 5, 0, 35),
            OnFocusLost = function()
                local num = tonumber(targetCurrencyInput.Text)
                if num and num > 0 then
                    config.targetCurrency = num
                    UILibrary:Notify({ Title = "Config Updated", Text = "Target Currency set to " .. num, Duration = 3 })
                else
                    targetCurrencyInput.Text = tostring(config.targetCurrency)
                    UILibrary:Notify({ Title = "Error", Text = "Invalid amount", Duration = 3 })
                end
                print("[TextBox]: Target Currency Amount Set:", config.targetCurrency)
            end
        })
    end

    local themeButton = UILibrary:CreateButton(settingsContent, {
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
            print("[Button]: Theme Switched to:", config.currentTheme)
        end
    })
    print("[Init]: Settings Tab Created")
else
    warn("[Init]: Settings Tab Creation Failed")
end

-- 其他
local othersTab, othersContent = createTabSafe("Others", false)
if othersTab and othersContent then
    local placeholderCard = UILibrary:CreateCard(othersContent, { Height = 50 })
    if placeholderCard then
        local placeholderLabel = UILibrary:CreateLabel(placeholderCard, { Text = "More features coming soon!" })
    end
    print("[Init]: Others Tab Created")
else
    warn("[Init]: Others Tab Creation Failed")
end

-- 作者
local authorTab, authorContent = createTabSafe("Author", false)
if authorTab and authorContent then
    local authorInfo = UILibrary:CreateAuthorInfo(authorContent, {
        Text = "Author: YourName\nVersion: 1.0.0",
        SocialText = "Join Discord",
        SocialCallback = function()
            UILibrary:Notify({ Title = "Discord", Text = "Discord link copied to clipboard!", Duration = 3 })
            print("[Button]: Discord Link Clicked")
        end
    })
    print("[Init]: Author Tab Created")
else
    warn("[Init]: Author Tab Creation Failed")
end

-- 模拟在线时间更新
if homeContent and onlineTimeLabel then
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
end

-- 初始通知
UILibrary:Notify({
    Title = "UI Loaded",
    Text = "Example UI template loaded successfully!",
    Duration = 3
})
print("[Init]: UI Initialization Complete")
