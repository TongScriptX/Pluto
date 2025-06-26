local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- 加载 UI 模块
local UILibrary
local success, result = pcall(function()
    return game.ReplicatedStorage:WaitForChild("PlutoUILibrary", 30)
end)
if success and result then
    success, UILibrary = pcall(function()
        return require(result)
    end)
end
if not success or not UILibrary then
    local errMsg = success and "UI 库为空" or "无法加载 UI 库: " .. tostring(result)
    error("[PlutoUILibrary] " .. errMsg .. ". 请确保 PlutoUILibrary.lua 已正确放置在 ReplicatedStorage 中，名称为 'PlutoUILibrary'。")
end

-- 获取当前玩家
local player = Players.LocalPlayer
if not player then
    error("无法获取当前玩家")
end
local userId = player.UserId
local username = player.Name

-- HTTP 请求配置
local http_request = syn and syn.request or http and http.request or http_request
if not http_request then
    error("此执行器不支持 HTTP 请求")
end

-- 配置文件
local configFile = "Pluto_X_config.json"
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
local gameName = "未知游戏"
local success, info = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
if success and info then
    gameName = info.Name
end

-- 获取初始金额
local initialCurrency = 0
local function fetchCurrentCurrency()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local currency = leaderstats:FindFirstChild("Cash")
        if currency then
            return currency.Value
        end
    end
    UILibrary:Notify({ Title = "错误", Text = "无法找到排行榜或金额数据", Duration = 5 })
    return nil
end
local success, currencyValue = pcall(fetchCurrentCurrency)
if success and currencyValue then
    initialCurrency = currencyValue
    UILibrary:Notify({ Title = "初始化成功", Text = "初始金额: " .. tostring(initialCurrency), Duration = 5 })
end

-- 反挂机
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    UILibrary:Notify({ Title = "反挂机", Text = "检测到闲置，已自动操作", Duration = 3 })
end)

-- 保存配置
local function saveConfig()
    pcall(function()
        writefile(configFile, HttpService:JSONEncode(config))
        UILibrary:Notify({ Title = "配置已保存", Text = "配置文件已保存至 " .. configFile, Duration = 5 })
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
            UILibrary:Notify({ Title = "配置已加载", Text = "配置文件加载成功", Duration = 5 })
        else
            UILibrary:Notify({ Title = "配置错误", Text = "无法解析配置文件", Duration = 5 })
            saveConfig()
        end
    else
        UILibrary:Notify({ Title = "配置提示", Text = "未找到配置文件，创建新文件", Duration = 5 })
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
        UILibrary:Notify({ Title = "排行榜错误", Text = "无法找到排行榜路径", Duration = 5 })
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
                UILibrary:Notify({ Title = "排行榜更新", Text = "当前排名: #" .. rank, Duration = 5 })
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

-- 格式化数字为千位分隔
local function formatNumber(num)
    local formatted = tostring(num)
    local result = ""
    local count = 0
    for i = #formatted, 1, -1 do
        result = formatted:sub(i, i) .. result
        count = count + 1
        if count % 3 == 0 and i > 1 then
            result = "," .. result
        end
    end
    return result
end

-- 发送Webhook
local function dispatchWebhook(payload)
    if config.webhookUrl == "" then
        UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
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
        if res.StatusCode == 204 or res.StatusCode == 200 then
            UILibrary:Notify({ Title = "Webhook", Text = "Webhook 发送成功", Duration = 5 })
            return true
        else
            local errorMsg = "Webhook 失败: " .. (res.StatusCode or "未知") .. " " .. (res.Body or "")
            UILibrary:Notify({ Title = "Webhook 错误", Text = errorMsg, Duration = 5 })
            return false
        end
    else
        UILibrary:Notify({ Title = "Webhook 错误", Text = "请求失败: " .. tostring(res), Duration = 5 })
        return false
    end
end

-- 欢迎消息
local function sendWelcomeMessage()
    if config.welcomeSent then return end
    if config.webhookUrl == "" then
        UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
        return
    end
    local payload = {
        embeds = {{
            title = "欢迎使用Pluto-X",
            description = "**游戏**: " .. gameName .. "\n**用户**: " .. username,
            color = PRIMARY_COLOR,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "作者: tongBlx" }
        }}
    }
    if dispatchWebhook(payload) then
        config.welcomeSent = true
        saveConfig()
    end
end

-- 创建主窗口
local window = UILibrary:CreateUIWindow()
if not window then
    error("无法创建 UI 窗口")
end
local mainFrame = window.MainFrame
local screenGui = window.ScreenGui
local sidebar = window.Sidebar
local titleLabel = window.TitleLabel
local mainPage = window.MainPage

-- 悬浮按钮
local toggleButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "菜单"
})
if not toggleButton then
    error("无法创建悬浮按钮")
end

-- 标签页：常规
local generalTab, generalContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "常规",
    Active = true
})

-- 卡片：常规信息
local generalCard = UILibrary:CreateCard(generalContent, { IsMultiElement = true })
local gameLabel = UILibrary:CreateLabel(generalCard, {
    Text = "游戏: " .. gameName,
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})
local earnedCurrencyLabel = UILibrary:CreateLabel(generalCard, {
    Text = "已赚金额: 0",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 30)
})

-- 卡片：反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
local antiAfkLabel = UILibrary:CreateLabel(antiAfkCard, {
    Text = "反挂机已启用",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})

-- 标签页：通知
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "通知设置"
})

-- 卡片：Webhook 配置
local webhookCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
local webhookLabel = UILibrary:CreateLabel(webhookCard, {
    Text = "Webhook 地址",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})
local webhookInput = UILibrary:CreateTextBox(webhookCard, {
    PlaceholderText = "输入 Webhook 地址",
    Position = UDim2.new(0, 5, 0, 30),
    OnFocusLost = function(text)
        if not text then return end
        local oldUrl = config.webhookUrl
        config.webhookUrl = text
        if config.webhookUrl ~= "" and config.webhookUrl ~= oldUrl then
            sendWelcomeMessage()
        end
        UILibrary:Notify({ Title = "Webhook 更新", Text = "Webhook 地址已保存", Duration = 5 })
        saveConfig()
    end
})
webhookInput.Text = config.webhookUrl
print("Webhook 输入框创建:", webhookInput.Parent and "已配置" or "无父对象")

-- 卡片：监测金额变化
local currencyNotifyCard = UILibrary:CreateCard(notifyContent)
local toggleCurrency = UILibrary:CreateToggle(currencyNotifyCard, {
    Text = "监测金额变化",
    DefaultState = config.notifyCash,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.notifyCash = false
            return
        end
        config.notifyCash = state
        UILibrary:Notify({ Title = "配置更新", Text = "金额变化监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
    end
})
print("金额监测开关创建:", toggleCurrency.Parent and "父对象存在" or "无父对象")

-- 卡片：监测排行榜状态
local leaderboardNotifyCard = UILibrary:CreateCard(notifyContent)
local toggleLeaderboard = UILibrary:CreateToggle(leaderboardNotifyCard, {
    Text = "监测排行榜状态",
    DefaultState = config.notifyLeaderboard,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.notifyLeaderboard = false
            return nil
        end
        config.notifyLeaderboard = state
        UILibrary:Notify({ Title = "配置更新", Text = "排行榜状态监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
        return nil
    end
})
print("排行榜监测开关创建:", toggleLeaderboard and toggleLeaderboard.Parent and "父对象存在" or "无父对象")

-- 卡片：上榜踢出
local leaderboardKickCard = UILibrary:CreateCard(notifyContent)
local toggleLeaderboardKick = UILibrary:CreateToggle(leaderboardKickCard, {
    Text = "上榜自动踢出",
    DefaultState = config.leaderboardKick,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.leaderboardKick = false
            return nil
        end
        config.leaderboardKick = state
        UILibrary:Notify({ Title = "配置更新", Text = "上榜自动踢出: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
        return nil
    end
})
print("上榜踢出开关创建:", toggleLeaderboardKick.Parent and "父对象存在" or "无父对象")

-- 卡片：通知间隔
local intervalCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
local intervalLabel = UILibrary:CreateLabel(intervalCard, {
    Text = "通知间隔（分钟）",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})
local intervalInput = UILibrary:CreateTextBox(intervalCard, {
    PlaceholderText = "输入间隔时间",
    Position = UDim2.new(0, 5, 0, 30),
    OnFocusLost = function(text)
        if not text then return end
        local num = tonumber(text)
        if num and num > 0 then
            config.notificationInterval = num
            UILibrary:Notify({ Title = "配置更新", Text = "通知间隔: " .. num .. " 分钟", Duration = 5 })
            saveConfig()
        else
            intervalInput.Text = tostring(config.notificationInterval)
            UILibrary:Notify({ Title = "配置错误", Text = "请输入有效的数字", Duration = 5 })
        end
    end
})
intervalInput.Text = tostring(config.notificationInterval)
print("通知间隔输入框创建:", intervalInput.Parent and "父对象存在" or "无父对象")

-- 卡片：目标金额
local targetCurrencyCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
local targetCurrencyToggle
targetCurrencyToggle, _ = UILibrary:CreateToggle(targetCurrencyCard, {
    Text = "Target Currency Kick",
    DefaultState = config.enableTargetCurrency,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook", Error = "请先设置 Webhook 地址", Duration = 5 })
            config.enableTargetCurrency = false
            targetCurrencyToggle[2] = false
            return nil
        end
        if state and config.targetCurrency <= 0 then
            config.enableTargetCurrency = false
            targetCurrencyToggle[2] = false
            UILibrary:Notify({ Title = "配置错误", Text = "请设置有效目标金额（大于0）", Duration = 5 })
            return nil
        end
        config.enableTargetCurrency = state
        UILibrary:Notify({ Title = "配置更新", Text = "目标金额踢出: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
        return nil
    end
})
print("目标金额开关创建卡片:", targetCurrencyToggle.Parent and "父对象存在" or "无父对象")
local targetCurrencyLabel = UILibrary:CreateLabel(targetCurrencyCard, {
    Text = "目标金额",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 30)
})
local targetCurrencyInput = UILibrary:CreateTextBox(targetCurrencyCard, {
    PlaceholderText = "输入目标金额",
    Position = UDim2.new(0, 5, 0, 50),
    OnFocusLost = function(text)
        if not text then return end
        local num = tonumber(text)
        if num and num > 0 then
            config.targetCurrency = num
            UILibrary:Notify({ Title = "配置更新", Text = "目标金额: " .. formatNumber(num), Duration = 5 })
            saveConfig()
        else
            targetCurrencyInput.Text = tostring(config.targetCurrency)
            config.targetCurrency = math.max(config.targetCurrency, 0)
            UILibrary:Notify({ Title = "配置错误", Text = "请输入有效的正整数", Duration = 5 })
            if config.enableTargetCurrency then
                config.enableTargetCurrency = false
                targetCurrencyToggle[2] = false
                UILibrary:Notify({ Title = "配置更新", Text = "目标金额踢出已禁用，请设置有效目标金额", Duration = 5 })
                saveConfig()
            end
        end
    end
})
targetCurrencyInput.Text = tostring(config.targetCurrency)
print("目标金额输入框创建:", targetCurrencyInput.ParentTarget and "父对象存在" or "TargetCurrencyInput")
-- 标签页：关于

-- 创建关于标签页
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于"
})

-- 作者信息
local authorInfo = UILibrary:CreateAuthorInfo(aboutContent, {
    Text = "作者: tongblx",
    SocialText = "加入 Discord 服务器",
    socialCallback = function()
        pcall(function()
        local link = "https://discord.gg/j20v0eWU8u"
            if setclipboard then
                setclipboard(link)
            elseif syn and syn.set_clipboard then
                syn.set_clipboard(link)
            else
                if clipboard and clipboard.set then
                    clip.setClipboard.set(link)
                end
                UILibrary:Notify({ Title = "复制 Discord", Text = "不支持剪贴板，请手动复制: " .. link, Duration = 5 })
            end
            UILibrary:Notify({ Title = "复制 Discord", Text = "Discord 链接已复制到剪贴板卡", Duration = 5 })
        end)
    end
})

-- 主循环
local lastSendTime = os.time()
local lastSendCurrency = initialCurrency
local lastRank = nil
while true do
    local currentTime = os.time()
    local currentCurrency = fetchCurrentCurrency()
    local earnedCurrency = currentCurrency and (currentCurrency - initialCurrency) or 0
    earnedCurrencyLabel.Text = "已赚金额: " .. formatNumber(earnedCurrency)
    -- 检查目标金额
    if config.enableTargetCurrency and currentCurrency and config.targetCurrency then
        print("检查目标金额: 当前 = " .. currentCurrency .. ", 目标 = " .. config.targetCurrency)
        if currentCurrency >= config.targetCurrency then
            local payload = {
                embeds = {{
                    title = "目标金额达成",
                    description = "**Target Currency: " .. gameName .. "\n**User: " .. username .. "\n**Current Currency**: " .. formatNumber(currentCurrency) .. "\n**Target Currency**: " .. formatNumber(config.targetCurrency),
                    color = PRIMARY_COLOR:Color,                    timestamp = os.date("!%Y-%m-%dT%H:%M:%S:%SZ"),
                    footer = { text = "Author: author" }
                }}
            }
            UILibrary:Notify({ Title = "目标达成", Text = "已达到目标金额 Currency " .. formatNumber(config.targetCurrency) .. "，即将退出游戏", Duration = 5 })
            if dispatchWebhook(payload) then
                wait(0.5) -- 确保Webhook发送
                game:Shutdown()
            end
        end
    end

    -- 定时通知检查
    if current_time - lastSendTime >= config.notificationInterval * 60 then
        local payload = {
            embeds = {
                {
                    title = "Pluto-X",
                    description = "**Game**: " .. gameName .. "\n**User**: " .. username,
                    color = PRIMARY_COLOR,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "Author: tongBlx" },
                    fields = {}
                }
            }
        }
        if config.notifyCash and currentCurrency then
            local currencyChange = currentCurrency - lastCurrency
            table.insert(payload.embeds[1].fields, {
                name = "Currency Update",
                value = "Current Currency: " .. formatNumber(currentCurrency) .. "\nChange: " .. (currencyChange >= 0 and "+" or "") .. formatNumber(currencyChange),
                inline = true
            })
            lastCurrency = currentCurrency
            UILibrary:Notify({ Title = "Currency Update", Text = "Current Currency: " .. formatNumber(currentCurrency), Duration = 5 })
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
        UILibrary:Notify({ Title = "Scheduled Notification", Text = "Scheduled notification sent, next notification at: " .. getNextNotificationTime(), Duration = 5 })
    end

    -- 排行榜踢出检测
    if config.leaderboardKick then
        local currentRank = fetchPlayerRank()
        if currentRank and currentRank <= 10 then
            local payload = {
                embeds = {
                    {
                        title = "Leaderboard Detection",
                        description = "**Game**: " .. gameName .. "\n**User**: " .. username .. "\n**Rank**: #" .. currentRank,
                        color = PRIMARY_COLOR,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%S:%SZ"),
                        footer = { text = "Author: tongBlx" }
                    }
                }
            }
            UILibrary:Notify({ Title = "Leaderboard Detection", Text = "Rank #" .. currentRank .. ", exiting game", Duration = 5 })
            if dispatchWebhook(payload) then
                wait(0.5) -- 确保Webhook发送
                game:Shutdown()
            end
        end
    end
    wait(1)
end

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    sendWelcomeMessage()
end