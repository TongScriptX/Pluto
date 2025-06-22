local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- 加载 UI 模块
local uiLibUrl = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/UILibrary.lua"
local success, UILibrary = pcall(function()
    return loadstring(game:HttpGet(uiLibUrl))()
end)
if not success then
    error("无法加载 UI 库: " .. tostring(UILibrary))
end

-- 获取当前玩家
local player = Players.LocalPlayer
if not player then
    error("无法获取当前玩家")
end
local userId = player.UserId
local username = player.Name

-- HTTP 请求兼容
local http_request = syn and syn.request or http and http.request or http_request
if not http_request then
    error("当前执行器不支持 HTTP 请求")
end

-- 配置文件
local configFile = "pluto_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notifyLeaderboard = false,
    leaderboardKick = false,
    notificationInterval = 5,
    welcomeSent = false,
    targetCash = 0,
    enableTargetKick = false
}

-- 颜色定义
local MAIN_COLOR_DECIMAL = 4873786 -- #4A4EAA

-- 获取游戏信息
local gameName = "未知游戏"
local success, info = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
if success and info then
    gameName = info.Name
end

-- 获取初始 Cash
local initialCash = 0
local function fetchPlayerCash()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local cash = leaderstats:FindFirstChild("Cash")
        if cash then
            return cash.Value
        end
    end
    UILibrary:Notify({ Title = "错误", Text = "未找到 leaderstats 或 Cash", Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
    return nil
end
local success, cashValue = pcall(fetchPlayerCash)
if success and cashValue then
    initialCash = cashValue
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
        UILibrary:Notify({ Title = "配置保存", Text = "配置已保存到 " .. configFile, Duration = 5, Icon = "rbxassetid://7072706667" })
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
            UILibrary:Notify({ Title = "配置加载", Text = "已加载配置", Duration = 5, Icon = "rbxassetid://7072706667" })
        else
            UILibrary:Notify({ Title = "配置错误", Text = "无法解析配置文件", Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
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
        UILibrary:Notify({ Title = "排行榜错误", Text = "无法找到排行榜路径", Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
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

-- 发送 Webhook
local function dispatchWebhook(payload)
    if config.webhookUrl == "" then
        UILibrary:Notify({ Title = "Webhook 错误", Text = "Webhook URL 未设置", Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
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
            UILibrary:Notify({ Title = "Webhook", Text = "发送成功", Duration = 5, Icon = "rbxassetid://7072706667" })
            return true
        else
            local errorMsg = "发送失败: " .. (res.StatusCode or res.code or "未知") .. " " .. (res.Body or res.data or "")
            UILibrary:Notify({ Title = "Webhook 错误", Text = errorMsg, Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
            return false
        end
    else
        UILibrary:Notify({ Title = "Webhook 错误", Text = "请求失败: " .. tostring(res), Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
        return false
    end
end

-- 欢迎消息
local function sendWelcomeMessage()
    if config.welcomeSent then return end
    local payload = {
        embeds = {{
            title = "欢迎使用 Notifier",
            description = "**游戏**: " .. gameName .. "\n**用户**: " .. username,
            color = MAIN_COLOR_DECIMAL,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "作者: tongblx" }
        }}
    }
    if dispatchWebhook(payload) then
        config.welcomeSent = true
        saveConfig()
    end
end

-- 创建 UI
local mainFrame, screenGui, tabBar, contentFrame = UILibrary:CreateWindow({
    Title = "[Pluto-X Notifier]",
    Size = UDim2.new(0, 300, 0, 360),
    Gradient = true,
    EnableMask = true,
    AutoLayout = true,
    EnableScrolling = true
})
UILibrary:MakeDraggable(mainFrame, { PreventOffScreen = true })

-- 悬浮按钮
local toggleButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "T",
    CloseText = "✕",
    Size = UDim2.new(0, 44, 0, 44),
    CornerRadius = 22,
    BackgroundColor = UILibrary.Background,
    BackgroundTransparency = UILibrary.Transparency,
    TextColor = UILibrary.Text,
    StrokeColor = Color3.fromRGB(255, 255, 255),
    StrokeThickness = 1,
    StrokeTransparency = 0.8,
    EnableAnimation = true,
    EnableDrag = true,
    PreventOffScreen = true
})

-- 标签页：常规
local generalTab, generalContent = UILibrary:CreateTab(tabBar, contentFrame, {
    Text = "常规",
    Active = true,
    AutoLayout = true,
    EnableScrolling = true,
    Icon = "rbxassetid://7072706667"
})

-- 卡片 1：游戏信息 + 已赚取金钱
local infoCard = UILibrary:CreateCard(generalContent, {
    Size = UDim2.new(1, -20, 0, 60),
    AutoLayout = true
})
local gameLabel = UILibrary:CreateLabel(infoCard, {
    Text = "游戏: " .. gameName,
    Size = UDim2.new(1, -10, 0, 20),
    TextSize = 14
})
local earnedCashLabel = UILibrary:CreateLabel(infoCard, {
    Text = "已赚取金钱: 0",
    Size = UDim2.new(1, -10, 0, 20),
    TextSize = 14
})

-- 卡片 2：反挂机状态
local antiAfkCard = UILibrary:CreateCard(generalContent, {
    Size = UDim2.new(1, -20, 0, 30),
    AutoLayout = true
})
local antiAfkLabel = UILibrary:CreateLabel(antiAfkCard, {
    Text = "反挂机已开启",
    Size = UDim2.new(1, -10, 0, 20),
    TextSize = 14
})

-- 标签页：设置
local settingsTab, settingsContent = UILibrary:CreateTab(tabBar, contentFrame, {
    Text = "设置",
    AutoLayout = true,
    EnableScrolling = true,
    Icon = "rbxassetid://7072706667"
})

-- 卡片 3：Webhook 输入框
local webhookCard = UILibrary:CreateCard(settingsContent, {
    Size = UDim2.new(1, -20, 0, 40),
    AutoLayout = true
})
local webhookInput = UILibrary:CreateTextBox(webhookCard, {
    PlaceholderText = "输入 Discord Webhook URL",
    Size = UDim2.new(1, -10, 0, 30),
    OnFocusLost = function()
        local oldUrl = config.webhookUrl
        config.webhookUrl = webhookInput.Text
        if config.webhookUrl ~= "" and config.webhookUrl ~= oldUrl then
            sendWelcomeMessage()
        end
        UILibrary:Notify({ Title = "配置更新", Text = "Webhook URL 已保存", Duration = 5, Icon = "rbxassetid://7072706667" })
        saveConfig()
    end
})
webhookInput.Text = config.webhookUrl

-- 卡片 4：通知金钱变化
local cashNotifyCard = UILibrary:CreateCard(settingsContent, {
    Size = UDim2.new(1, -20, 0, 40),
    AutoLayout = true
})
local toggleCash = UILibrary:CreateToggle(cashNotifyCard, {
    Text = "通知金钱变化",
    DefaultState = config.notifyCash,
    OnText = "✔",
    OffText = "✕",
    Callback = function(state)
        config.notifyCash = state
        UILibrary:Notify({ Title = "配置更新", Text = "通知金钱变化: " .. (state and "开" or "关"), Duration = 5, Icon = "rbxassetid://7072706667" })
        saveConfig()
    end
})

-- 卡片 5：通知排行榜状态
local leaderboardNotifyCard = UILibrary:CreateCard(settingsContent, {
    Size = UDim2.new(1, -20, 0, 40),
    AutoLayout = true
})
local toggleLeaderboard = UILibrary:CreateToggle(leaderboardNotifyCard, {
    Text = "通知排行榜状态",
    DefaultState = config.notifyLeaderboard,
    OnText = "✔",
    OffText = "✕",
    Callback = function(state)
        config.notifyLeaderboard = state
        UILibrary:Notify({ Title = "配置更新", Text = "通知排行榜状态: " .. (state and "开" or "关"), Duration = 5, Icon = "rbxassetid://7072706667" })
        saveConfig()
    end
})

-- 卡片 6：上榜踢出
local leaderboardKickCard = UILibrary:CreateCard(settingsContent, {
    Size = UDim2.new(1, -20, 0, 40),
    AutoLayout = true
})
local toggleLeaderboardKick = UILibrary:CreateToggle(leaderboardKickCard, {
    Text = "上榜踢出",
    DefaultState = config.leaderboardKick,
    OnText = "✔",
    OffText = "✕",
    Callback = function(state)
        config.leaderboardKick = state
        UILibrary:Notify({ Title = "配置更新", Text = "上榜踢出: " .. (state and "开" or "关"), Duration = 5, Icon = "rbxassetid://7072706667" })
        saveConfig()
    end
})

-- 卡片 7：通知间隔
local intervalCard = UILibrary:CreateCard(settingsContent, {
    Size = UDim2.new(1, -20, 0, 40),
    AutoLayout = true
})
local intervalLabel = UILibrary:CreateLabel(intervalCard, {
    Text = "通知间隔（分钟）：",
    Size = UDim2.new(0.5, 0, 0, 30),
    TextSize = 14
})
local intervalInput = UILibrary:CreateTextBox(intervalCard, {
    PlaceholderText = "间隔",
    Size = UDim2.new(0.5, -5, 0, 30),
    OnFocusLost = function()
        local num = tonumber(intervalInput.Text)
        if num and num > 0 then
            config.notificationInterval = num
            UILibrary:Notify({ Title = "配置更新", Text = "通知间隔: " .. num .. " 分钟", Duration = 5, Icon = "rbxassetid://7072706667" })
            saveConfig()
        else
            intervalInput.Text = tostring(config.notificationInterval)
            UILibrary:Notify({ Title = "配置错误", Text = "请输入有效数字", Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
        end
    end
})
intervalInput.Text = tostring(config.notificationInterval)

-- 卡片 8：目标金钱
local targetCashCard = UILibrary:CreateCard(settingsContent, {
    Size = UDim2.new(1, -20, 0, 80),
    AutoLayout = true
})
local targetCashToggle = UILibrary:CreateToggle(targetCashCard, {
    Text = "目标金钱踢出",
    DefaultState = config.enableTargetKick,
    OnText = "✔",
    OffText = "✕",
    Callback = function(state)
        config.enableTargetKick = state
        UILibrary:Notify({ Title = "配置更新", Text = "目标金钱踢出: " .. (state and "开" or "关"), Duration = 5, Icon = "rbxassetid://7072706667" })
        saveConfig()
    end
})
local targetCashLabel = UILibrary:CreateLabel(targetCashCard, {
    Text = "目标金钱：",
    Size = UDim2.new(0.5, 0, 0, 30),
    TextSize = 14
})
local targetCashInput = UILibrary:CreateTextBox(targetCashCard, {
    PlaceholderText = "输入目标金钱",
    Size = UDim2.new(0.5, -5, 0, 30),
    OnFocusLost = function()
        local num = tonumber(targetCashInput.Text)
        if num and num >= 0 then
            config.targetCash = num
            UILibrary:Notify({ Title = "配置更新", Text = "目标金钱: " .. num, Duration = 5, Icon = "rbxassetid://7072706667" })
            saveConfig()
        else
            targetCashInput.Text = tostring(config.targetCash)
            UILibrary:Notify({ Title = "配置错误", Text = "请输入有效数字", Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
        end
    end
})
targetCashInput.Text = tostring(config.targetCash)

-- 标签页：关于
local aboutTab, aboutContent = UILibrary:CreateTab(tabBar, contentFrame, {
    Text = "关于",
    AutoLayout = true,
    EnableScrolling = true,
    Icon = "rbxassetid://7072706667"
})

-- 作者介绍
local authorInfo = UILibrary:CreateAuthorInfo(aboutContent, {
    AuthorText = "作者: tongblx",
    SocialText = "Discord: 加入服务器",
    SocialIcon = "rbxassetid://7072706667",
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
                UILibrary:Notify({ Title = "复制 Discord", Text = "剪贴板功能不受支持，请手动复制: " .. link, Duration = 5, IsWarning = true, Icon = "rbxassetid://7072706667" })
            end
            UILibrary:Notify({ Title = "复制 Discord", Text = "已复制 Discord 链接到剪贴板", Duration = 5, Icon = "rbxassetid://7072706667" })
        end)
    end
})

-- 主循环
local lastSendTime = os.time()
local lastCash = initialCash
local lastRank = nil
spawn(function()
    while wait(1) do
        local currentTime = os.time()
        local currentCash = fetchPlayerCash()
        local earnedCash = currentCash and (currentCash - initialCash) or 0
        earnedCashLabel.Text = "已赚取金钱: " .. tostring(earnedCash)

        -- 检查目标金钱
        if config.enableTargetKick and currentCash and currentCash >= config.targetCash then
            local payload = {
                embeds = {{
                    title = "目标金钱达成",
                    description = "**游戏**: " .. gameName .. "\n**用户**: " .. username .. "\n**当前金钱**: " .. currentCash .. "\n**目标金钱**: " .. config.targetCash,
                    color = MAIN_COLOR_DECIMAL,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "作者: tongblx" }
                }}
            }
            dispatchWebhook(payload)
            game:Shutdown()
        end

        -- 定期通知
        if currentTime - lastSendTime >= config.notificationInterval * 60 then
            local payload = {
                embeds = {{
                    title = "Notifier 更新",
                    description = "**游戏**: " .. gameName .. "\n**用户**: " .. username,
                    color = MAIN_COLOR_DECIMAL,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "作者: tongblx" },
                    fields = {}
                }}
            }

            if config.notifyCash and currentCash then
                local cashChange = currentCash - lastCash
                table.insert(payload.embeds[1].fields, {
                    name = "金钱更新",
                    value = "当前金钱: " .. currentCash .. "\n变化: " .. (cashChange >= 0 and "+" or "") .. cashChange,
                    inline = true
                })
                lastCash = currentCash
            end

            if config.notifyLeaderboard then
                local currentRank = fetchPlayerRank()
                if currentRank then
                    table.insert(payload.embeds[1].fields, {
                        name = "排行榜",
                        value = "当前排名: #" .. currentRank .. (lastRank and "\n变化: " .. (lastRank - currentRank >= 0 and "+" or "") .. (lastRank - currentRank) or ""),
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
                        title = "上榜通知",
                        description = "**游戏**: " .. gameName .. "\n**用户**: " .. username .. "\n**排名**: #" .. currentRank,
                        color = MAIN_COLOR_DECIMAL,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "作者: tongblx" }
                    }}
                }
                dispatchWebhook(payload)
                game:Shutdown()
            end
        end
    end
end)

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    sendWelcomeMessage()
end
