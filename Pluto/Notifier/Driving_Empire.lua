local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- 加载 UI 模块
local uiLibUrl = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
local success, UILibrary = pcall(function()
    return loadstring(game:HttpGet(uiLibUrl))()
end)
if not success then
    error("Failed to load UI library: " .. tostring(UILibrary))
end

-- 获取当前玩家
local player = Players.LocalPlayer
if not player then
    error("Unable to get current player")
end
local userId = player.UserId
local username = player.Name

-- HTTP 请求配置
local http_request = syn and syn.request or http and http.request or http_request
if not http_request then
    error("HTTP requests not supported by this executor")
end

-- 配置文件
local configFile = "pluto_config.json"
local config = {
    webhookUrl = "",
    notifyCash = true,
    notifyLeaderboard = false,
    leaderboardKick = false,
    notificationInterval = 5,
    welcomeSent = false,
    targetCurrency = 0,
    enableTargetKick = false
}

-- 颜色定义
local PRIMARY_COLOR = 4149685 -- #3F51B5

-- 获取游戏信息
local gameName = "Unknown Game"
local success, info = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
if success and info then
    gameName = info.Name
end

-- 获取初始货币
local initialCurrency = 0
local function fetchCurrentCurrency()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local currency = leaderstats:FindFirstChild("Cash")
        if currency then
            return currency.Value
        end
    end
    UILibrary:Notify({ Title = "Error", Text = "Unable to find leaderstats or Cash", Duration = 5 })
    return nil
end
local success, currencyValue = pcall(fetchCurrentCurrency)
if success and currencyValue then
    initialCurrency = currencyValue
end

-- 反挂机
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- 保存配置
local function saveConfig()
    pcall(function()
        writefile(configFile, HttpService:JSONEncode(config))
        UILibrary:Notify({ Title = "Config Saved", Text = "Configuration saved to " .. configFile, Duration = 5 })
    end)
end

-- 加载配置
local function loadConfig()
    if isfile(configFile) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(configFile))
        end)
        if success then
            for k, v in pairs(result) do
                config[k] = v
            end
            UILibrary:Notify({ Title = "Config Loaded", Text = "Configuration loaded successfully", Duration = 5 })
        else
            UILibrary:Notify({ Title = "Config Error", Text = "Unable to parse config file", Duration = 5 })
            saveConfig()
        end
    else
        saveConfig()
    end
end
pcall(loadConfig)

-- 检查排行榜
local function fetchPlayerRank()
    local playerRank = nil
    local success, contentsPath = pcall(function()
        return game:GetService("Workspace"):WaitForChild("Game"):WaitForChild("Leaderboards"):WaitForChild("weekly_money"):WaitForChild("Screen"):WaitForChild("Leaderboard"):WaitForChild("Contents")
    end)
    if not success or not contentsPath then
        UILibrary:Notify({ Title = "Leaderboard Error", Text = "Unable to find leaderboard path", Duration = 5 })
        return nil
    end

    local rank = 1
    for _, userIdFolder in pairs(contentsPath:GetChildren()) do
        local userIdNum = tonumber(userIdFolder.Name)
        if userIdNum and userIdNum == userId then
            local placement = userIdFolder:FindFirstChild("Placement")
            if placement then
                playerRank = rank
                if placement:IsA("IntValue") then
                    rank = placement.Value
                end
                break
            end
        end
        rank = rank + 1
    end
    return playerRank
end

-- 下次通知时间
local function getNextNotificationTime()
    local currentTime = os.time()
    local intervalSeconds = config.notificationInterval * 60
    return os.date("%Y-%m-%d %H:%M:%S", currentTime + intervalSeconds)
end

-- 发送Webhook
local function dispatchWebhook(payload)
    if config.webhookUrl == "" then
        UILibrary:Notify({ Title = "Webhook Error", Text = "Webhook URL not set", Duration = 5 })
        return false
    end
    local payloadJson = HttpService:JSONEncode(payload)
    local success, res = pcall(function()
        return http_request({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payloadJson
        })
    end)
    if success then
        if res.StatusCode == 204 or res.code == 204 then
            UILibrary:Notify({ Title = "Webhook", Text = "Webhook sent successfully", Duration = 5 })
            return true
        else
            local errorMsg = "Webhook failed: " .. (res.StatusCode or res.code or "unknown") .. " " .. (res.Body or res.data or "")
            UILibrary:Notify({ Title = "Webhook Error", Text = errorMsg, Duration = 5 })
            return false
        end
    else
        UILibrary:Notify({ Title = "Webhook Error", Text = "Request failed: " .. tostring(res), Duration = 5 })
        return false
    end
end

-- 欢迎消息
local function sendWelcomeMessage()
    if config.welcomeSent then return end
    local payload = {
        embeds = {{
            title = "Welcome to Notifier",
            description = "**Game**: " .. gameName .. "\n**User**: " .. username,
            color = PRIMARY_COLOR,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "By: tongBlx" }
        }}
    }
    if dispatchWebhook(payload) then
        config.welcomeSent = true
        saveConfig()
    end
end

-- 创建主窗口
local window = UILibrary:CreateUIWindow()
local mainFrame = window.MainFrame
local screenGui = window.ScreenGui
local sidebar = window.Sidebar
local titleLabel = window.TitleLabel
local mainPage = window.MainPage

-- 悬浮按钮
local toggleButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "T"
})

-- 标签页：常规
local generalTab, generalContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "General",
    Active = true
})

-- 卡片：常规信息
local generalCard = UILibrary:CreateCard(generalContent, { IsMultiElement = true })
local gameLabel = UILibrary:CreateLabel(generalCard, {
    Text = "Game: " .. gameName,
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})
local earnedCurrencyLabel = UILibrary:CreateLabel(generalCard, {
    Text = "Earned Currency: 0",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 30)
})

-- 卡片：反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
local antiAfkLabel = UILibrary:CreateLabel(antiAfkCard, {
    Text = "Anti-AFK Enabled",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})

-- 标签页：通知
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "Notifications"
})

-- 卡片：Webhook 配置
local webhookCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
local webhookLabel = UILibrary:CreateLabel(webhookCard, {
    Text = "Webhook URL",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})
local webhookInput = UILibrary:CreateTextBox(webhookCard, {
    PlaceholderText = "Enter Webhook URL",
    Position = UDim2.new(0, 5, 0, 30),
    OnFocusLost = function()
        local oldUrl = config.webhookUrl
        config.webhookUrl = webhookInput.Text
        if config.webhookUrl ~= "" and config.webhookUrl ~= oldUrl then
            sendWelcomeMessage()
        end
        UILibrary:Notify({ Title = "Webhook Updated", Text = "Webhook URL saved", Duration = 5 })
        saveConfig()
    end
})
webhookInput.Text = config.webhookUrl
print("Webhook Input Created:", webhookInput.Parent and "Configured" or "No parent")

-- 卡片：通知货币变化
local currencyNotifyCard = UILibrary:CreateCard(notifyContent)
local toggleCurrency = UILibrary:CreateToggle(currencyNotifyCard, {
    Text = "Notify Currency Changes",
    DefaultState = config.notifyCash,
    Callback = function(state)
        config.notifyCash = state
        UILibrary:Notify({ Title = "Config Updated", Text = "Notify currency changes: " .. (state and "On" or "Off"), Duration = 5 })
        saveConfig()
    end
})
print("Currency Toggle Created:", toggleCurrency.Parent and "Parent exists" or "No parent")

-- 卡片：通知排行榜状态
local leaderboardNotifyCard = UILibrary:CreateCard(notifyContent)
local toggleLeaderboard = UILibrary:CreateToggle(leaderboardNotifyCard, {
    Text = "Notify Leaderboard",
    DefaultState = config.notifyLeaderboard,
    Callback = function(state)
        config.notifyLeaderboard = state
        UILibrary:Notify({ Title = "Config Updated", Text = "Notify leaderboard status: " .. (state and "On" or "Off"), Duration = 5 })
        saveConfig()
    end
})
print("Leaderboard Toggle Created:", toggleLeaderboard.Parent and "Parent exists" or "No parent")

-- 卡片：上榜踢出
local leaderboardKickCard = UILibrary:CreateCard(notifyContent)
local toggleLeaderboardKick = UILibrary:CreateToggle(leaderboardKickCard, {
    Text = "Leaderboard Kick",
    DefaultState = config.leaderboardKick,
    Callback = function(state)
        config.leaderboardKick = state
        UILibrary:Notify({ Title = "Config Updated", Text = "Leaderboard kick: " .. (state and "On" or "Off"), Duration = 5 })
        saveConfig()
    end
})
print("Leaderboard Kick Toggle Created:", toggleLeaderboardKick.Parent and "Parent exists" or "No parent")

-- 卡片：通知间隔
local intervalCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
local intervalLabel = UILibrary:CreateLabel(intervalCard, {
    Text = "Notification Interval (Minutes)",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})
local intervalInput = UILibrary:CreateTextBox(intervalCard, {
    PlaceholderText = "Interval",
    Position = UDim2.new(0, 5, 0, 30),
    OnFocusLost = function()
        local num = tonumber(intervalInput.Text)
        if num and num > 0 then
            config.notificationInterval = num
            UILibrary:Notify({ Title = "Config Updated", Text = "Notification interval: " .. num .. " minutes", Duration = 5 })
            saveConfig()
        else
            intervalInput.Text = tostring(config.notificationInterval)
            UILibrary:Notify({ Title = "Config Error", Text = "Please enter a valid number", Duration = 5 })
        end
    end
})
intervalInput.Text = tostring(config.notificationInterval)
print("Interval Input Created:", intervalInput.Parent and "Parent exists" or "No parent")

-- 卡片：目标货币
local targetCurrencyCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
local targetCurrencyToggle
targetCurrencyToggle, _ = UILibrary:CreateToggle(targetCurrencyCard, {
    Text = "Target Currency Kick",
    DefaultState = config.enableTargetKick,
    Callback = function(state)
        if state and config.targetCurrency <= 0 then
            config.enableTargetKick = false
            targetCurrencyToggle[2] = false
            UILibrary:Notify({ Title = "Config Error", Text = "Please set a valid target currency (greater than 0)", Duration = 5 })
            return
        end
        config.enableTargetKick = state
        UILibrary:Notify({ Title = "Config Updated", Text = "Target currency kick: " .. (state and "On" or "Off"), Duration = 5 })
        saveConfig()
    end
})
print("Target Currency Toggle Created:", targetCurrencyToggle.Parent and "Parent exists" or "No parent")
local targetCurrencyLabel = UILibrary:CreateLabel(targetCurrencyCard, {
    Text = "Target Currency",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 30)
})
local targetCurrencyInput = UILibrary:CreateTextBox(targetCurrencyCard, {
    PlaceholderText = "Enter target currency",
    Position = UDim2.new(0, 5, 0, 50),
    OnFocusLost = function()
        local num = tonumber(targetCurrencyInput.Text)
        if num and num > 0 then
            config.targetCurrency = num
            UILibrary:Notify({ Title = "Config Updated", Text = "Target currency: " .. num, Duration = 5 })
            saveConfig()
        else
            targetCurrencyInput.Text = tostring(config.targetCurrency)
            config.targetCurrency = math.max(config.targetCurrency, 0)
            UILibrary:Notify({ Title = "Config Error", Text = "Please enter a valid positive integer", Duration = 5 })
            if config.enableTargetKick then
                config.enableTargetKick = false
                targetCurrencyToggle[2] = false
                UILibrary:Notify({ Title = "Config Updated", Text = "Target currency kick disabled, please set a valid target currency", Duration = 5 })
                saveConfig()
            end
        end
    end
})
targetCurrencyInput.Text = tostring(config.targetCurrency)
print("Target Currency Input Created:", targetCurrencyInput.Parent and "Parent exists" or "No parent")

-- 标签页：关于
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "About"
})

-- 作者信息
local authorInfo = UILibrary:CreateAuthorInfo(aboutContent, {
    Text = "Author: tongblx",
    SocialText = "Discord: Join Server",
    SocialCallback = function()
        pcall(function()
            local link = "https://discord.gg/8MW6eWU8uf"
            if setclipboard then
                setclipboard(link)
            elseif syn and syn.set_clipboard then
                syn.set_clipboard(link)
            elseif clipboard and clipboard.set then
                clipboard.set(link)
            else
                UILibrary:Notify({ Title = "Copy Discord", Text = "Clipboard not supported, please copy manually: " .. link, Duration = 5 })
            end
            UILibrary:Notify({ Title = "Copy Discord", Text = "Discord link copied to clipboard", Duration = 5 })
        end)
    end
})

-- 主循环
local lastSendTime = os.time()
local lastCurrency = initialCurrency
local lastRank = nil
spawn(function()
    while wait(1) do
        local currentTime = os.time()
        local currentCurrency = fetchCurrentCurrency()
        local earnedCurrency = currentCurrency and (currentCurrency - initialCurrency) or 0
        earnedCurrencyLabel.Text = "Earned Currency: " .. tostring(earnedCurrency)

        -- 检查目标货币
        if config.enableTargetKick and currentCurrency and config.targetCurrency > 0 then
            print("Checking Target Currency: Current =", currentCurrency, "Target =", config.targetCurrency)
            if currentCurrency >= config.targetCurrency then
                local payload = {
                    embeds = {{
                        title = "Target Currency Reached",
                        description = "**Game**: " .. gameName .. "\n**User**: " .. username .. "\n**Current Currency**: " .. currentCurrency .. "\n**Target Currency**: " .. config.targetCurrency,
                        color = PRIMARY_COLOR,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "By: tongBlx" }
                    }}
                }
                UILibrary:Notify({ Title = "Target Reached", Text = "Reached target currency " .. config.targetCurrency .. ", exiting game", Duration = 5 })
                dispatchWebhook(payload)
                wait(1) -- 确保Webhook发送
                game:Shutdown()
            end
        end

        -- 定期通知
        if currentTime - lastSendTime >= config.notificationInterval * 60 then
            local payload = {
                embeds = {{
                    title = "Notifier Update",
                    description = "**Game**: " .. gameName .. "\n**User**: " .. username,
                    color = PRIMARY_COLOR,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "By: tongBlx" },
                    fields = {}
                }}
            }

            if config.notifyCash and currentCurrency then
                local currencyChange = currentCurrency - lastCurrency
                table.insert(payload.embeds[1].fields, {
                    name = "Currency Update",
                    value = "Current Currency: " .. currentCurrency .. "\nChange: " .. (currencyChange >= 0 and "+" or "") .. currencyChange,
                    inline = true
                })
                lastCurrency = currentCurrency
            end

            if config.notifyLeaderboard then
                local currentRank = fetchPlayerRank()
                if currentRank then
                    table.insert(payload.embeds[1].fields, {
                        name = "Leaderboard",
                        value = "Current Rank: #" .. currentRank .. (lastRank and "\nChange: " .. (lastRank - currentRank >= 0 and "+" or "") .. (lastRank - currentRank) or ""),
                        inline = true
                    })
                    lastRank = currentRank
                end
            end

            if #payload.embeds[1].fields > 0 then
                dispatchWebhook(payload)
            end
            lastSendTime = currentTime
        end

        -- 上榜踢出
        if config.leaderboardKick then
            local currentRank = fetchPlayerRank()
            if currentRank and currentRank <= 10 then
                local payload = {
                    embeds = {{
                        title = "Leaderboard Notification",
                        description = "**Game**: " .. gameName .. "\n**User**: " .. username .. "\n**Rank**: #" .. currentRank,
                        color = PRIMARY_COLOR,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "By: tongBlx" }
                    }}
                }
                UILibrary:Notify({ Title = "Leaderboard Notification", Text = "Rank #" .. currentRank .. ", exiting game", Duration = 5 })
                dispatchWebhook(payload)
                wait(1) -- 确保Webhook发送
                game:Shutdown()
            end
        end
    end
end)

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    sendWelcomeMessage()
end
