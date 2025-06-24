local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- 加载 UI 库
local UILibrary
local success, result = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
    local response = game:HttpGet(url)
    if response and #response > 1000 then
        return response
    else
        error("Invalid or empty response from HttpGet")
    end
end)

if success and result then
    local success2, module = pcall(loadstring(result))
    if success2 and module then
        UILibrary = module
        print("[Init]: PlutoUILibrary loaded successfully")
    else
        error("[Init]: Failed to execute PlutoUILibrary: " .. tostring(module))
    end
else
    warn("[Init]: HttpGet failed, attempting local load")
    local success3, localModule = pcall(function()
        return require(game.StarterPlayerScripts.PlutoUILibrary)
    end)
    if success3 and localModule then
        UILibrary = localModule
        print("[Init]: Local PlutoUILibrary loaded successfully")
    else
        error("[Init]: Failed to load PlutoUILibrary locally: " .. tostring(localModule))
    end
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

-- 设置初始主题
UILibrary:SetTheme(THEME_DARK)

-- 创建主窗口
local window = UILibrary:CreateUIWindow()
if not window or not window.MainFrame or not window.ScreenGui or not window.Sidebar or not window.TitleLabel or not window.MainPage then
    error("[Init]: Failed to create main window")
end
UILibrary:MakeDraggable(window.MainFrame)

-- 悬浮按钮
local toggleButton = UILibrary:CreateFloatingButton(window.ScreenGui, {
    MainFrame = window.MainFrame,
    Text = "T"
})

-- 创建标签页
local function createTabSafe(text, active)
    local tabButton, content = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
        Text = text,
        Active = active
    })
    if tabButton and content then
        return tabButton, content
    else
        warn("[Tab]: Failed to create tab: " .. text)
        return nil, nil
    end
end

-- 主页
local homeTab, homeContent = createTabSafe("Home", true)
if homeContent then
    local infoCard = UILibrary:CreateCard(homeContent, { IsMultiElement = true })
    if infoCard then
        local gameStatusLabel = UILibrary:CreateLabel(infoCard, { Text = "Game Status: Running" })
        local onlineTimeLabel = UILibrary:CreateLabel(infoCard, { Text = "Online Time: 0:00:00", Position = UDim2.new(0, UILibrary.UI_STYLES.Padding, 0, UILibrary.UI_STYLES.Padding + UILibrary.UI_STYLES.LabelHeight) })
        local currencyLabel = UILibrary:CreateLabel(infoCard, { Text = "Currency: 0", Position = UDim2.new(0, UILibrary.UI_STYLES.Padding, 0, UILibrary.UI_STYLES.Padding + 2 * UILibrary.UI_STYLES.LabelHeight) })
    end
end

-- 主要功能
local featuresTab, featuresContent = createTabSafe("Features", false)
if featuresContent then
    local webhookCard = UILibrary:CreateCard(featuresContent, { IsMultiElement = false })
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
            end
        })
    end

    local togglesCard = UILibrary:CreateCard(featuresContent, { IsMultiElement = true })
    if togglesCard then
        local notifyCurrencyToggle = UILibrary:CreateToggle(togglesCard, {
            Text = "Notify Currency",
            DefaultState = config.notifyCurrency,
            Callback = function(state)
                config.notifyCurrency = state
                UILibrary:Notify({ Title = "Config Updated", Text = "Notify Currency: " .. (state and "On" or "Off"), Duration = 3 })
            end
        })
        local notifyLeaderboardToggle = UILibrary:CreateToggle(togglesCard, {
            Text = "Notify Leaderboard",
            DefaultState = config.notifyLeaderboard,
            Callback = function(state)
                config.notifyLeaderboard = state
                UILibrary:Notify({ Title = "Config Updated", Text = "Notify Leaderboard: " .. (state and "On" or "Off"), Duration = 3 })
            end
        })
        local leaderboardKickToggle = UILibrary:CreateToggle(togglesCard, {
            Text = "Leaderboard Kick",
            DefaultState = config.leaderboardKick,
            Callback = function(state)
                config.leaderboardKick = state
                UILibrary:Notify({ Title = "Config Updated", Text = "Leaderboard Kick: " .. (state and "On" or "Off"), Duration = 3 })
            end
        })
    end

    local testNotifyButton = UILibrary:CreateButton(featuresContent, {
        Text = "Test Notification",
        Callback = function()
            UILibrary:Notify({ Title = "Test Success", Text = "This is a test notification!", Duration = 3 })
        end
    })
end

-- 设置
local settingsTab, settingsContent = createTabSafe("Settings", false)
if settingsContent then
    local intervalCard = UILibrary:CreateCard(settingsContent, { IsMultiElement = false })
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
            end
        })
    end

    local targetCurrencyCard = UILibrary:CreateCard(settingsContent, { IsMultiElement = true })
    if targetCurrencyCard then
        local targetCurrencyToggle, targetCurrencyState = UILibrary:CreateToggle(targetCurrencyCard, {
            Text = "Target Currency",
            DefaultState = config.targetCurrencyEnabled,
            Callback = function(state)
                if state and config.targetCurrency <= 0 then
                    config.targetCurrencyEnabled = false
                    targetCurrencyState = false
                    UILibrary:Notify({ Title = "Error", Text = "Set a valid target currency", Duration = 3 })
                    local thumb = targetCurrencyToggle:FindFirstChild("Thumb", true)
                    local track = targetCurrencyToggle:FindFirstChild("Track", true)
                    if thumb and track then
                        TweenService:Create(thumb, UILibrary.TWEEN_INFO_BUTTON, { Position = UDim2.new(0, 0, 0, -4) }):Play()
                        TweenService:Create(track, UILibrary.TWEEN_INFO_BUTTON, { BackgroundColor3 = UILibrary.THEME.Error }):Play()
                    end
                else
                    config.targetCurrencyEnabled = state
                    targetCurrencyState = state
                    UILibrary:Notify({ Title = "Config Updated", Text = "Target Currency: " .. (state and "On" or "Off"), Duration = 3 })
                end
            end
        })
        local targetCurrencyLabel = UILibrary:CreateLabel(targetCurrencyCard, {
            Text = "Target Currency Amount",
            Position = UDim2.new(0, UILibrary.UI_STYLES.Padding, 0, UILibrary.UI_STYLES.Padding + UILibrary.UI_STYLES.ButtonHeight)
        })
        local targetCurrencyInput = UILibrary:CreateTextBox(targetCurrencyCard, {
            PlaceholderText = "Enter amount",
            Text = tostring(config.targetCurrency),
            Position = UDim2.new(0, UILibrary.UI_STYLES.Padding, 0, UILibrary.UI_STYLES.Padding + 2 * UILibrary.UI_STYLES.ButtonHeight),
            OnFocusLost = function()
                local num = tonumber(targetCurrencyInput.Text)
                if num and num > 0 then
                    config.targetCurrency = num
                    UILibrary:Notify({ Title = "Config Updated", Text = "Target Currency set to " .. num, Duration = 3 })
                else
                    targetCurrencyInput.Text = tostring(config.targetCurrency)
                    UILibrary:Notify({ Title = "Error", Text = "Invalid amount", Duration = 3 })
                end
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
        end
    })
end

-- 其他
local othersTab, othersContent = createTabSafe("Others", false)
if othersContent then
    local placeholderCard = UILibrary:CreateCard(othersContent, { IsMultiElement = false })
    if placeholderCard then
        local placeholderLabel = UILibrary:CreateLabel(placeholderCard, { Text = "More features coming soon!" })
    end
end

-- 作者
local authorTab, authorContent = createTabSafe("Author", false)
if authorContent then
    local authorInfo = UILibrary:CreateAuthorInfo(authorContent, {
        Text = "Author: YourName\nVersion: 1.0.0",
        SocialText = "Join Discord",
        SocialCallback = function()
            UILibrary:Notify({ Title = "Discord", Text = "Discord link copied to clipboard!", Duration = 3 })
        end
    })
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
