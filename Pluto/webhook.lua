local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

-- 获取当前玩家
local player = Players.LocalPlayer
if not player then
    error("无法获取当前玩家")
end
local userId = player.UserId
local username = player.Name

-- HTTP 请求兼容 Synapse X
local http_request = syn and syn.request or http and http.request or http_request
if not http_request then
    error("当前执行器不支持 HTTP 请求")
end

-- 配置文件
local configFile = "pluto_config.json"

-- 配置表
local config = {
    webhookUrl = "",
    sendCash = false,
    sendLeaderboard = false,
    autoKick = false,
    intervalMinutes = 5
}

-- 自定义输出函数
local function notifyOutput(title, text, isWarn)
    local notification = {
        Title = isWarn and "警告: " .. title or title,
        Text = tostring(text),
        Icon = "",
        Duration = 5
    }
    pcall(function()
        CoreGui:SetCore("SendNotification", notification)
    end)
    if isWarn then
        warn(text)
    else
        print(text)
    end
end

-- 保存配置
local function saveConfig()
    pcall(function()
        writefile(configFile, HttpService:JSONEncode(config))
        notifyOutput("配置保存", "配置已成功保存至 " .. configFile, false)
    end)
end

-- 读取配置
local function loadConfig()
    if isfile(configFile) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(configFile))
        end)
        if success then
            if result.webhookUrl ~= nil then config.webhookUrl = result.webhookUrl end
            if result.sendCash ~= nil then config.sendCash = result.sendCash end
            if result.sendLeaderboard ~= nil then config.sendLeaderboard = result.sendLeaderboard end
            if result.autoKick ~= nil then config.autoKick = result.autoKick end
            if result.intervalMinutes ~= nil and result.intervalMinutes > 0 then
                config.intervalMinutes = result.intervalMinutes
            end
            notifyOutput("配置加载", "已加载保存的配置，自动开启相关功能", false)
        else
            notifyOutput("配置加载", "无法解析配置文件，使用默认配置", true)
            saveConfig()
        end
    else
        notifyOutput("配置加载", "未找到配置文件，保存默认配置", false)
        saveConfig()
    end
end

-- 加载配置
local success, errorMsg = pcall(loadConfig)
if not success then
    notifyOutput("配置加载错误", "加载配置失败: " .. tostring(errorMsg), true)
    saveConfig()
end

-- 获取玩家 Cash
local function getPlayerCash()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local cash = leaderstats:FindFirstChild("Cash")
        if cash then
            return cash.Value
        end
    end
    notifyOutput("获取 Cash", "未找到 leaderstats 或 Cash", true)
    return nil
end

-- 检查玩家是否上榜
local function checkPlayerRank()
    local playerRank = nil
    local success, contentsPath = pcall(function()
        return game:GetService("Workspace"):WaitForChild("Game"):WaitForChild("Leaderboards"):WaitForChild("weekly_money"):WaitForChild("Screen"):WaitForChild("Leaderboard"):WaitForChild("Contents")
    end)
    if not success or not contentsPath then
        notifyOutput("获取排行榜", "无法找到排行榜路径", true)
        return nil
    end

    local rank = 1
    for _, userIdFolder in pairs(contentsPath:GetChildren()) do
        local userIdNum = tonumber(userIdFolder.Name)
        if userIdNum and userIdNum == userId then
            local placement = userIdFolder:FindFirstChild("Placement")
            if placement then
                playerRank = rank
                break
            end
        end
        rank = rank + 1
    end
    return playerRank
end

-- 计算下次发送时间
local function getNextSendTime()
    local currentTime = os.time()
    local intervalSeconds = config.intervalMinutes * 60
    local nextTime = currentTime + intervalSeconds
    return os.date("%Y-%m-%d %H:%M:%S", nextTime)
end

-- 发送 webhook
local function sendWebhook(payload)
    if config.webhookUrl == "" then
        notifyOutput("发送 Webhook", "Webhook URL 未设置", true)
        return false
    end
    local payloadJson = HttpService:JSONEncode(payload)
    local success, res = pcall(function()
        return http_request({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = payloadJson
        })
    end)
    if success then
        if res.StatusCode == 204 or res.code == 204 then
            notifyOutput("发送 Webhook", "发送成功", false)
            return true
        else
            local errorMsg = "发送失败: " .. (res.StatusCode or res.code or "未知") .. " " .. (res.Body or res.data or "")
            notifyOutput("发送 Webhook", errorMsg, true)
            return false
        end
    else
        notifyOutput("发送 Webhook", "请求失败: " .. tostring(res), true)
        return false
    end
end

-- 创建现代 UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WebhookUI"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

-- 悬浮按钮
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 50, 0, 50)
toggleButton.Position = UDim2.new(0, 10, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
toggleButton.Text = "≡"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.TextSize = 24
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = screenGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = toggleButton

-- 主界面
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 350)
mainFrame.Position = UDim2.new(0, 70, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BackgroundTransparency = 0.2
mainFrame.Visible = false
mainFrame.Parent = screenGui
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = mainFrame

-- 动画
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local function toggleMainFrame(visible)
    if visible then
        toggleButton.Text = "T"
        mainFrame.Visible = true
        TweenService:Create(mainFrame, tweenInfo, { BackgroundTransparency = 0.2, Position = UDim2.new(0, 70, 0, 10) }):Play()
    else
        toggleButton.Text = "≡"
        TweenService:Create(mainFrame, tweenInfo, { BackgroundTransparency = 1, Position = UDim2.new(0, 70, 0, -10) }):Play()
        wait(0.3)
        mainFrame.Visible = false
    end
end

local function createToggle(labelText, configKey, yOffset)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, -20, 0, 30)
    toggleFrame.Position = UDim2.new(0, 10, 0, yOffset)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = mainFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 14
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleFrame

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 50, 0, 24)
    toggle.Position = UDim2.new(0.8, -10, 0, 3)
    toggle.BackgroundColor3 = config[configKey] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    toggle.Text = config[configKey] and "开" or "关"
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.TextSize = 14
    toggle.Font = Enum.Font.SourceSans
    toggle.Parent = toggleFrame
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = toggle

    toggle.MouseButton1Click:Connect(function()
        config[configKey] = not config[configKey]
        toggle.BackgroundColor3 = config[configKey] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        toggle.Text = config[configKey] and "开" or "关"
        notifyOutput("配置更新", labelText .. " 已设置为 " .. (config[configKey] and "开" or "关"), false)
        saveConfig()
    end)
end

local webhookInput = Instance.new("TextBox")
webhookInput.Size = UDim2.new(1, -20, 0, 40)
webhookInput.Position = UDim2.new(0, 10, 0, 10)
webhookInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
webhookInput.TextColor3 = Color3.new(1, 1, 1)
webhookInput.TextSize = 14
webhookInput.Font = Enum.Font.SourceSans
webhookInput.PlaceholderText = "输入 Discord Webhook URL"
webhookInput.Text = config.webhookUrl
webhookInput.TextWrapped = true
webhookInput.TextTruncate = Enum.TextTruncate.None
webhookInput.Parent = mainFrame
local webhookCorner = Instance.new("UICorner")
webhookCorner.CornerRadius = UDim.new(0, 6)
webhookCorner.Parent = webhookInput
webhookInput.FocusLost:Connect(function()
    config.webhookUrl = webhookInput.Text
    notifyOutput("配置更新", "Webhook URL 已保存", false)
    saveConfig()
end)

createToggle("发送金钱", "sendCash", 60)
createToggle("发送排行榜", "sendLeaderboard", 100)
createToggle("上榜自动踢出", "autoKick", 140)

local intervalLabel = Instance.new("TextLabel")
intervalLabel.Size = UDim2.new(0.5, 0, 0, 30)
intervalLabel.Position = UDim2.new(0, 10, 0, 180)
intervalLabel.BackgroundTransparency = 1
intervalLabel.Text = "发送间隔（分钟）："
intervalLabel.TextColor3 = Color3.new(1, 1, 1)
intervalLabel.TextSize = 14
intervalLabel.Font = Enum.Font.SourceSans
intervalLabel.TextXAlignment = Enum.TextXAlignment.Left
intervalLabel.Parent = mainFrame

local intervalInput = Instance.new("TextBox")
intervalInput.Size = UDim2.new(0.4, 0, 0, 24)
intervalInput.Position = UDim2.new(0.55, 0, 0, 183)
intervalInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
intervalInput.TextColor3 = Color3.new(1, 1, 1)
intervalInput.TextSize = 14
intervalInput.Font = Enum.Font.SourceSans
intervalInput.Text = tostring(config.intervalMinutes)
intervalInput.Parent = mainFrame
local intervalCorner = Instance.new("UICorner")
intervalCorner.CornerRadius = UDim.new(0, 6)
intervalCorner.Parent = intervalInput

-- 跟踪最后发送时间
local lastSendTime = os.time()

intervalInput.FocusLost:Connect(function()
    local num = tonumber(intervalInput.Text)
    if num and num > 0 then
        config.intervalMinutes = num
        notifyOutput("配置更新", "发送间隔已设置为 " .. num .. " 分钟", false)
        saveConfig()
        lastSendTime = os.time()
    else
        intervalInput.Text = tostring(config.intervalMinutes)
        notifyOutput("配置错误", "请输入有效数字", true)
    end
end)

-- 作者信息
local authorLabel = Instance.new("TextLabel")
authorLabel.Size = UDim2.new(1, -20, 0, 30)
authorLabel.Position = UDim2.new(0, 10, 0, 310)
authorLabel.BackgroundTransparency = 1
authorLabel.Text = "作者: tongblx"
authorLabel.TextColor3 = Color3.new(1, 1, 1)
authorLabel.TextSize = 14
authorLabel.Font = Enum.Font.SourceSans
authorLabel.TextXAlignment = Enum.TextXAlignment.Left
authorLabel.Parent = mainFrame

local discordLabel = Instance.new("TextButton")
discordLabel.Size = UDim2.new(1, -20, 0, 30)
discordLabel.Position = UDim2.new(0, 10, 0, 340)
discordLabel.BackgroundTransparency = 1
discordLabel.Text = "Discord: https://discord.gg/8MW6eWU8uf"
discordLabel.TextColor3 = Color3.fromRGB(114, 137, 218)
discordLabel.TextSize = 14
discordLabel.Font = Enum.Font.SourceSans
discordLabel.TextXAlignment = Enum.TextXAlignment.Left
discordLabel.Parent = mainFrame
discordLabel.MouseButton1Click:Connect(function()
    pcall(function()
        setclipboard("https://discord.gg/8MW6eWU8uf")
        notifyOutput("复制 Discord", "已复制 Discord 链接到剪贴板", false)
    end)
end)

-- 拖动悬浮按钮
local dragging
toggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        local startPos = input.Position
        local startGuiPos = toggleButton.Position
        local connection
        connection = UserInputService.InputChanged:Connect(function(inputChanged)
            if inputChanged.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                local delta = inputChanged.Position - startPos
                toggleButton.Position = UDim2.new(
                    startGuiPos.X.Scale, startGuiPos.X.Offset + delta.X,
                    startGuiPos.Y.Scale, startGuiPos.Y.Offset + delta.Y
                )
                mainFrame.Position = UDim2.new(
                    startGuiPos.X.Scale, startGuiPos.X.Offset + delta.X + 60,
                    startGuiPos.Y.Scale, startGuiPos.Y.Offset + delta.Y
                )
            end
        end)
        input.InputEnded:Connect(function()
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
                connection:Disconnect()
            end
        end)
    end
end)

-- 切换 UI 显示
toggleButton.MouseButton1Click:Connect(function()
    toggleMainFrame(not mainFrame.Visible)
end)

-- 定时发送和检测
spawn(function()
    while true do
        if config.sendCash or config.sendLeaderboard or config.autoKick then
            local currentTime = os.time()
            local intervalSeconds = config.intervalMinutes * 60
            if currentTime - lastSendTime >= intervalSeconds then
                local payload = { embeds = {} }
                local cashValue = getPlayerCash()
                local playerRank = checkPlayerRank()

                -- 合并 Cash 和排行榜嵌入
                if config.sendCash or config.sendLeaderboard then
                    local embed = {
                        title = "玩家 " .. username .. " 的数据",
                        color = 16711680,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "用户: " .. username .. " | 作者: tongblx" },
                        fields = {}
                    }
                    if config.sendCash and cashValue then
                        table.insert(embed.fields, {
                            name = "金钱",
                            value = "Cash: " .. cashValue,
                            inline = true
                        })
                    end
                    if config.sendLeaderboard then
                        table.insert(embed.fields, {
                            name = "排行榜状态",
                            value = playerRank and "已上榜，排名: " .. playerRank or "未上榜",
                            inline = true
                        })
                        notifyOutput("排行榜", playerRank and "已上榜，排名: " .. playerRank or "未上榜", false)
                    end
                    table.insert(embed.fields, {
                        name = "下次发送",
                        value = getNextSendTime(),
                        inline = true
                    })
                    table.insert(embed.fields, {
                        name = "Discord",
                        value = "[加入服务器](https://discord.gg/8MW6eWU8uf)",
                        inline = true
                    })
                    table.insert(payload.embeds, embed)
                end

                if #payload.embeds > 0 then
                    sendWebhook(payload)
                end

                if config.autoKick and playerRank then
                    notifyOutput("自动踢出", "因上榜触发 game:Shutdown()", false)
                    game:Shutdown()
                end

                lastSendTime = currentTime
            end
        end
        wait(1)
    end
end)
