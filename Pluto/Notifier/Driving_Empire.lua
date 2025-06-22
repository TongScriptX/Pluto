local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")

-- 加载 UI 模块
local uiLibUrl = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/UILibrary.lua"
local success, PlutoXUILibrary = pcall(function()
    return loadstring(game:HttpGet(uiLibUrl))()
end)
if not success then
    error("无法加载 UI 库: " .. tostring(PlutoXUILibrary))
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
    sendCash = false,
    sendLeaderboard = false,
    autoKick = false,
    intervalMinutes = 5
}

-- 颜色定义
local MAIN_COLOR_DECIMAL = 2631705 -- #282659

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
local function getPlayerCash()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local cash = leaderstats:FindFirstChild("Cash")
        if cash then
            return cash.Value
        end
    end
    PlutoXUILibrary:Notify("获取 Cash", "未找到 leaderstats 或 Cash", 5, true)
    return nil
end
local success, cashValue = pcall(getPlayerCash)
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
        PlutoXUILibrary:Notify("配置保存", "配置已保存到 " .. configFile, 5, false)
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
            PlutoXUILibrary:Notify("配置加载", "已加载配置", 5, false)
        else
            PlutoXUILibrary:Notify("配置加载", "无法解析配置文件", 5, true)
            saveConfig()
        end
    else
        saveConfig()
    end
end
pcall(loadConfig)

-- 检查排行榜
local function checkPlayerRank()
    local playerRank = nil
    local success, contentsPath = pcall(function()
        return game:GetService("Workspace"):WaitForChild("Game"):WaitForChild("Leaderboards"):WaitForChild("weekly_money"):WaitForChild("Screen"):WaitForChild("Leaderboard"):WaitForChild("Contents")
    end)
    if not success or not contentsPath then
        PlutoXUILibrary:Notify("获取排行榜", "无法找到排行榜路径", 5, true)
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

-- 下次发送时间
local function getNextSendTime()
    local currentTime = os.time()
    local intervalSeconds = config.intervalMinutes * 60
    return os.date("%Y-%m-%d %H:%M:%S", currentTime + intervalSeconds)
end

-- 发送 Webhook
local function sendWebhook(payload)
    if config.webhookUrl == "" then
        PlutoXUILibrary:Notify("发送 Webhook", "Webhook URL 未设置", 5, true)
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
            PlutoXUILibrary:Notify("发送 Webhook", "发送成功", 5, false)
            return true
        else
            local errorMsg = "发送失败: " .. (res.StatusCode or res.code or "未知") .. " " .. (res.Body or res.data or "")
            PlutoXUILibrary:Notify("发送 Webhook", errorMsg, 5, true)
            return false
        end
    else
        PlutoXUILibrary:Notify("发送 Webhook", "请求失败: " .. tostring(res), 5, true)
        return false
    end
end

-- 欢迎消息
local function sendWelcomeMessage()
    local payload = {
        embeds = {{
            title = "Pluto-X Notifier",
            description = "**欢迎使用 Pluto-X Notifier**\n**游戏**: " .. gameName .. "\n**用户**: " .. username,
            color = MAIN_COLOR_DECIMAL,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "作者: tongblx" }
        }}
    }
    sendWebhook(payload)
end

-- 创建 UI
local mainFrame, screenGui = PlutoXUILibrary:CreateWindow({
    Title = "[Pluto-X Notifier]",
    Size = UDim2.new(0, 300, 0, 360)
})
PlutoXUILibrary:MakeDraggable(mainFrame, { PreventOffScreen = true })

-- 悬浮按钮
local toggleButton = PlutoXUILibrary:CreateButton(screenGui, {
    Text = "≡",
    Size = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(0, 10, 0, 10),
    CornerRadius = 10,
    Callback = function()
        mainFrame.Visible = not mainFrame.Visible
        toggleButton.Text = mainFrame.Visible and "T" or "≡"
    end
})

-- 游戏信息
local gameLabel = PlutoXUILibrary:CreateLabel(mainFrame, {
    Text = "游戏: " .. gameName,
    Position = UDim2.new(0, 10, 0, 35)
})

-- 已赚取金钱
local earnedCashLabel = PlutoXUILibrary:CreateLabel(mainFrame, {
    Text = "已赚取金钱: 0",
    Position = UDim2.new(0, 10, 0, 50)
})
spawn(function()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local cash = leaderstats:FindFirstChild("Cash")
        if cash then
            cash.Changed:Connect(function(newValue)
                earnedCashLabel.Text = "已赚取金钱: " .. (newValue - initialCash)
            end)
            earnedCashLabel.Text = "已赚取金钱: " .. (cash.Value - initialCash)
        end
    end
end)

-- Webhook 输入框
local webhookInput = PlutoXUILibrary:CreateTextBox(mainFrame, {
    PlaceholderText = "输入 Discord Webhook URL",
    Position = UDim2.new(0, 10, 0, 70),
    OnFocusLost = function()
        config.webhookUrl = webhookInput.Text
        PlutoXUILibrary:Notify("配置更新", "Webhook URL 已保存", 5, false)
        saveConfig()
    end
})
webhookInput.Text = config.webhookUrl

-- 开关
local toggleCash = PlutoXUILibrary:CreateToggle(mainFrame, {
    Text = "发送金钱",
    Position = UDim2.new(0, 10, 0, 110),
    DefaultState = config.sendCash,
    Callback = function(state)
        config.sendCash = state
        PlutoXUILibrary:Notify("配置更新", "发送金钱: " .. (state and "开" or "关"), 5, false)
        saveConfig()
        if state then sendWelcomeMessage() end
    end
})
local toggleLeaderboard = PlutoXUILibrary:CreateToggle(mainFrame, {
    Text = "发送排行榜",
    Position = UDim2.new(0, 100, 0, 110),
    DefaultState = config.sendLeaderboard,
    Callback = function(state)
        config.sendLeaderboard = state
        PlutoXUILibrary:Notify("配置更新", "发送排行榜: " .. (state and "开" or "关"), 5, false)
        saveConfig()
        if state then sendWelcomeMessage() end
    end
})
local toggleAutoKick = PlutoXUILibrary:CreateToggle(mainFrame, {
    Text = "自动踢出",
    Position = UDim2.new(0, 190, 0, 110),
    DefaultState = config.autoKick,
    Callback = function(state)
        config.autoKick = state
        PlutoXUILibrary:Notify("配置更新", "自动踢出: " .. (state and "开" or "关"), 5, false)
        saveConfig()
        if state then sendWelcomeMessage() end
    end
})

-- 发送间隔
local intervalLabel = PlutoXUILibrary:CreateLabel(mainFrame, {
    Text = "发送间隔（分钟）：",
    Size = UDim2.new(0.5, 0, 0, 25),
    Position = UDim2.new(0, 10, 0, 140)
})
local intervalInput = PlutoXUILibrary:CreateTextBox(mainFrame, {
    PlaceholderText = "间隔",
    Size = UDim2.new(0.4, 0, 0, 20),
    Position = UDim2.new(0.55, 0, 0, 142.5),
    OnFocusLost = function()
        local num = tonumber(intervalInput.Text)
        if num and num > 0 then
            config.intervalMinutes = num
            PlutoXUILibrary:Notify("配置更新", "发送间隔: " .. num .. " 分钟", 5, false)
            saveConfig()
            lastSendTime = os.time()
        else
            intervalInput.Text = tostring(config.intervalMinutes)
            PlutoXUILibrary:Notify("配置错误", "请输入有效数字", 5, true)
        end
    end
})
intervalInput.Text = tostring(config.intervalMinutes)

-- 反挂机状态
local antiAfkLabel = PlutoXUILibrary:CreateLabel(mainFrame, {
    Text = "反挂机已开启",
    Size = UDim2.new(1, -20, 0, 15),
    Position = UDim2.new(0, 10, 0, 170)
})

-- 作者介绍模块
local authorInfo = PlutoXUILibrary:CreateAuthorInfo(mainFrame, {
    AuthorName = "作者: tongblx",
    SocialText = "Discord: 加入服务器",
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
                PlutoXUILibrary:Notify("复制 Discord", "剪贴板功能不受支持，请手动复制: " .. link, 5, true)
                return
            end
            PlutoXUILibrary:Notify("复制 Discord", "已复制链接", 5, false)
        end)
    end,
    Size = UDim2.new(1, -20, 0, 30),
    Position = UDim2.new(0, 10, 0, 300)
})

-- 定时发送
local lastSendTime = os.time()
spawn(function()
    while true do
        if config.sendCash or config.sendLeaderboard or config.autoKick then
            local currentTime = os.time()
            local intervalSeconds = config.intervalMinutes * 60
            if currentTime - lastSendTime >= intervalSeconds then
                local payload = { embeds = {} }
                local cashValue = getPlayerCash()
                local playerRank = checkPlayerRank()

                if config.sendCash or config.sendLeaderboard then
                    local embed = {
                        title = "Pluto-X Notifier",
                        color = MAIN_COLOR_DECIMAL,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "用户: " .. username .. " | 作者: tongblx" },
                        fields = {
                            { name = "**游戏**", value = gameName, inline = true },
                        }
                    }
                    if config.sendCash and cashValue then
                        table.insert(embed.fields, {
                            name = "**金钱**",
                            value = "Cash: " .. cashValue,
                            inline = true
                        })
                        table.insert(embed.fields, {
                            name = "**已赚取**",
                            value = "Earned: " .. (cashValue - initialCash),
                            inline = true
                        })
                    end
                    if config.sendLeaderboard then
                        table.insert(embed.fields, {
                            name = "**排行榜状态**",
                            value = playerRank and "已上榜，排名: " .. playerRank or "未上榜",
                            inline = true
                        })
                        PlutoXUILibrary:Notify("排行榜", playerRank and "已上榜，排名: " .. playerRank or "未上榜", 5, false)
                    end
                    table.insert(embed.fields, {
                        name = "**下次发送**",
                        value = getNextSendTime(),
                        inline = true
                    })
                    table.insert(embed.fields, {
                        name = "**Discord**",
                        value = "[加入服务器](https://discord.gg/8MW6eWU8uf)",
                        inline = true
                    })
                    table.insert(payload.embeds, embed)
                end

                if #payload.embeds > 0 then
                    sendWebhook(payload)
                end

                if config.autoKick and playerRank then
                    PlutoXUILibrary:Notify("自动踢出", "因上榜触发 game:Shutdown()", 5, false)
                    game:Shutdown()
                end

                lastSendTime = currentTime
            end
        end
        wait(1)
    end
end)
