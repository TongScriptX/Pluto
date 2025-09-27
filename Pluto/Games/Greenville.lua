local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local lastWebhookUrl = ""
local lastSendTime = os.time()  -- 初始化为当前时间
local lastCurrency = 0  -- 初始化为初始金额
local sessionStartCurrency = 0  -- 本次会话开始时的金额

-- 加载 UI 模块
local UILibrary
local success, result = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if success and result then
    UILibrary = result
else
    error("[PlutoUILibrary] 加载失败！请检查网络连接或链接是否有效：" .. tostring(result))
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
local configFile = "Pluto_X_GV_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notificationInterval = 30,
    welcomeSent = false,
    targetEarnedAmount = 0,  -- 改为赚取金额目标
    enableTargetKick = false,
    lastSessionCurrency = 0,  -- 上次会话保存的金额
    totalEarnedAmount = 0     -- 累计赚取金额
}

-- 颜色定义
_G.PRIMARY_COLOR = 5793266

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
    local success, currencyObj = pcall(function()
        return player.PlayerGui:WaitForChild("UI", 5)
            :WaitForChild("Uni", 5)
            :WaitForChild("Hud", 5)
            :WaitForChild("Money", 5)
            :WaitForChild("Label", 5)
    end)
    if success and currencyObj then
        local currencyText = currencyObj.Text
        -- 移除千位逗号，仅保留一个小数点和数字
        local cleanedText = currencyText:gsub(",", ""):match("[0-9%.]+")
        local currencyValue = tonumber(cleanedText)
        if currencyValue then
            return math.floor(currencyValue) -- 保留整数部分
        end
    end
    UILibrary:Notify({ Title = "错误", Text = "无法找到金额数据", Duration = 5 })
    return nil
end

-- 计算当前赚取金额
local function getCurrentEarnedAmount()
    local currentCurrency = fetchCurrentCurrency()
    if not currentCurrency then return 0 end
    
    -- 计算本次会话赚取 + 历史累计赚取
    local sessionEarned = currentCurrency - sessionStartCurrency
    return config.totalEarnedAmount + sessionEarned
end

-- 保存配置
local function saveConfig()
    pcall(function()
        local allConfigs = {}
        if isfile(configFile) then
            local ok, content = pcall(function()
                return HttpService:JSONDecode(readfile(configFile))
            end)
            if ok and type(content) == "table" then
                allConfigs = content
            end
        end

        allConfigs[username] = config
        writefile(configFile, HttpService:JSONEncode(allConfigs))

        UILibrary:Notify({
            Title = "配置已保存",
            Text = "配置已保存至 " .. configFile,
            Duration = 5,
        })
    end)
end

-- 更新累计赚取金额（在发送webhook时调用）
local function updateTotalEarned()
    local currentCurrency = fetchCurrentCurrency()
    if not currentCurrency then return end
    
    local sessionEarned = currentCurrency - sessionStartCurrency
    config.totalEarnedAmount = config.totalEarnedAmount + sessionEarned
    config.lastSessionCurrency = currentCurrency
    sessionStartCurrency = currentCurrency  -- 重置会话起点
    saveConfig()
end

-- 加载配置
local function loadConfig()
    if isfile(configFile) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(configFile))
        end)

        if success and type(result) == "table" then
            local userConfig = result[username]
            if userConfig and type(userConfig) == "table" then
                for k, v in pairs(userConfig) do
                    config[k] = v
                end
                
                -- 兼容旧版本配置
                if userConfig.targetCurrency and not userConfig.targetEarnedAmount then
                    config.targetEarnedAmount = userConfig.targetCurrency or 0
                    config.targetCurrency = nil  -- 移除旧字段
                end
                
                UILibrary:Notify({
                    Title = "配置已加载",
                    Text = "用户配置加载成功",
                    Duration = 5,
                })
            else
                UILibrary:Notify({
                    Title = "配置提示",
                    Text = "未找到该用户配置，使用默认配置",
                    Duration = 5,
                })
                saveConfig()
            end
        else
            UILibrary:Notify({
                Title = "配置错误",
                Text = "无法解析配置文件",
                Duration = 5,
            })
            saveConfig()
        end
    else
        UILibrary:Notify({
            Title = "配置提示",
            Text = "未找到配置文件，创建新文件",
            Duration = 5,
        })
        saveConfig()
    end

    -- 检查 webhookUrl 是否需要触发欢迎消息
    if config.webhookUrl ~= "" and config.webhookUrl ~= lastWebhookUrl then
        config.welcomeSent = false
        sendWelcomeMessage()
        lastWebhookUrl = config.webhookUrl
    end
end

-- 初始化会话起始金额
local function initializeSession()
    local currentCurrency = fetchCurrentCurrency()
    if currentCurrency then
        sessionStartCurrency = currentCurrency
        initialCurrency = currentCurrency  -- 保持兼容性
        lastCurrency = currentCurrency
        
        -- 如果有上次会话数据，计算差异并调整累计赚取
        if config.lastSessionCurrency > 0 then
            local currencyDiff = currentCurrency - config.lastSessionCurrency
            if math.abs(currencyDiff) > 0 then
                UILibrary:Notify({
                    Title = "会话数据同步",
                    Text = string.format("检测到金额变化: %s%s", currencyDiff >= 0 and "+" or "", formatNumber(currencyDiff)),
                    Duration = 5
                })
            end
        end
        
        UILibrary:Notify({ 
            Title = "初始化成功", 
            Text = string.format("当前金额: %s | 累计赚取: %s", 
                formatNumber(currentCurrency), 
                formatNumber(config.totalEarnedAmount)
            ), 
            Duration = 5 
        })
    end
end

-- 执行加载
pcall(loadConfig)

-- 补充函数：统一获取通知间隔（秒）
local function getNotificationIntervalSeconds()
    return (config.notificationInterval or 5) * 60
end

-- 格式化数字为千位分隔
local function formatNumber(num)
    if not num then return "0" end
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

-- 发送 Webhook
local function dispatchWebhook(payload)
    if config.webhookUrl == "" then
        UILibrary:Notify({
            Title = "Webhook 错误",
            Text = "请先设置 Webhook 地址",
            Duration = 5
        })
        warn("[Webhook] 未设置 webhookUrl")
        return false
    end

    local data = {
        content = nil,
        embeds = payload.embeds
    }

    local requestFunc = syn and syn.request or http and http.request or request

    if not requestFunc then
        UILibrary:Notify({
            Title = "Webhook 错误",
            Text = "无法找到可用的请求函数，请使用支持 HTTP 请求的执行器",
            Duration = 5
        })
        warn("[Webhook] 无可用请求函数")
        return false
    end

    print("[Webhook] 正在发送 Webhook 到:", config.webhookUrl)
    print("[Webhook] Payload 内容:", HttpService:JSONEncode(data))

    local success, res = pcall(function()
        return requestFunc({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)

    if success and res then
        if res.StatusCode == 204 or res.StatusCode == 200 then
            UILibrary:Notify({
                Title = "Webhook",
                Text = "Webhook 发送成功",
                Duration = 5
            })
            print("[Webhook] 发送成功")
            -- 发送成功后更新累计数据
            updateTotalEarned()
            return true
        else
            warn("[Webhook 错误] 状态码: " .. tostring(res.StatusCode or "未知") .. ", 返回: " .. (res.Body or "无"))
            UILibrary:Notify({
                Title = "Webhook 错误",
                Text = "状态码: " .. tostring(res.StatusCode or "未知") .. "\n返回信息: " .. (res.Body or "无"),
                Duration = 5
            })
            return false
        end
    else
        warn("[Webhook 请求失败] 错误信息: " .. tostring(res))
        UILibrary:Notify({
            Title = "Webhook 错误",
            Text = "请求失败: " .. tostring(res),
            Duration = 5
        })
        return false
    end
end

-- 欢迎消息
local function sendWelcomeMessage()
    if config.webhookUrl == "" then
        UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
        return
    end
    local payload = {
        embeds = {{
            title = "欢迎使用Pluto-X",
            description = string.format("**游戏**: %s\n**用户**: %s\n**累计赚取**: %s", 
                gameName, username, formatNumber(config.totalEarnedAmount)),
            color = _G.PRIMARY_COLOR,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "作者: tongblx · Pluto-X" }
        }}
    }
    if dispatchWebhook(payload) then
        config.welcomeSent = true
        saveConfig()
    end
end

-- 初始化时校验目标赚取金额
local function initTargetEarned()
    local currentEarned = getCurrentEarnedAmount()
    if config.enableTargetKick and config.targetEarnedAmount > 0 and currentEarned >= config.targetEarnedAmount then
        UILibrary:Notify({
            Title = "目标赚取已达成",
            Text = "当前赚取金额已超过目标，已关闭踢出功能，未执行退出",
            Duration = 5
        })
        config.enableTargetKick = false
        config.targetEarnedAmount = 0
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
    Text = "本次赚取: 0",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 30)
})
local totalEarnedLabel = UILibrary:CreateLabel(generalCard, {
    Text = "累计赚取: " .. formatNumber(config.totalEarnedAmount),
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 55)
})

-- 卡片：反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
local antiAfkLabel = UILibrary:CreateLabel(antiAfkCard, {
    Text = "安全起见，反挂机未启用",
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

-- 卡片：目标赚取金额
local targetEarnedCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

-- 避免程序性开启触发回调误判
local suppressTargetToggleCallback = false

-- 切换开关（使用 enableTargetKick）
local targetEarnedToggle = UILibrary:CreateToggle(targetEarnedCard, {
    Text = "目标赚取踢出",
    DefaultState = config.enableTargetKick or false,
    Callback = function(state)
        print("[目标踢出] 状态改变:", state)

        if suppressTargetToggleCallback then
            suppressTargetToggleCallback = false
            return
        end

        if state and config.webhookUrl == "" then
            targetEarnedToggle:Set(false)
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            return
        end

        if state and (not config.targetEarnedAmount or config.targetEarnedAmount <= 0) then
            targetEarnedToggle:Set(false)
            UILibrary:Notify({ Title = "配置错误", Text = "请设置有效目标赚取金额（大于0）", Duration = 5 })
            return
        end

        local currentEarned = getCurrentEarnedAmount()
        if state and currentEarned >= config.targetEarnedAmount then
            targetEarnedToggle:Set(false)
            UILibrary:Notify({
                Title = "配置警告",
                Text = string.format("当前赚取金额(%s)已超过目标金额(%s)，请调整后再开启",
                    formatNumber(currentEarned),
                    formatNumber(config.targetEarnedAmount)
                ),
                Duration = 6
            })
            return
        end

        config.enableTargetKick = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = "目标赚取踢出: " .. (state and "开启" or "关闭"),
            Duration = 5
        })
        saveConfig()
    end
})

UILibrary:CreateLabel(targetEarnedCard, {
    Text = "目标赚取金额",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 30)
})

local targetEarnedInput = UILibrary:CreateTextBox(targetEarnedCard, {
    PlaceholderText = "输入目标赚取金额",
    Position = UDim2.new(0, 5, 0, 50),
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")
        print("[目标赚取] 输入框失焦内容:", text)

        if not text or text == "" then
            if config.targetEarnedAmount > 0 then
                targetEarnedInput.Text = formatNumber(config.targetEarnedAmount)
                return
            end
            config.targetEarnedAmount = 0
            config.enableTargetKick = false
            targetEarnedInput.Text = ""
            UILibrary:Notify({
                Title = "目标赚取已清除",
                Text = "已取消目标赚取踢出功能",
                Duration = 5
            })
            saveConfig()
            return
        end

        local num = tonumber(text)
        if num and num > 0 then
            local currentEarned = getCurrentEarnedAmount()
            if currentEarned >= num then
                targetEarnedInput.Text = tostring(config.targetEarnedAmount > 0 and formatNumber(config.targetEarnedAmount) or "")
                UILibrary:Notify({
                    Title = "设置失败",
                    Text = "目标赚取金额(" .. formatNumber(num) .. ")小于当前赚取金额(" .. formatNumber(currentEarned) .. ")，请设置更大的目标值",
                    Duration = 5
                })
                return
            end

            config.targetEarnedAmount = num
            targetEarnedInput.Text = formatNumber(num)

            -- 自动启用踢出功能
            if not config.enableTargetKick then
                config.enableTargetKick = true
                suppressTargetToggleCallback = true
                targetEarnedToggle:Set(true)
                UILibrary:Notify({
                    Title = "已启用目标踢出",
                    Text = "已自动开启目标赚取踢出功能",
                    Duration = 5
                })
                saveConfig()
            end

            UILibrary:Notify({
                Title = "配置更新",
                Text = "目标赚取金额已设为 " .. formatNumber(num),
                Duration = 5
            })
            saveConfig()
        else
            targetEarnedInput.Text = tostring(config.targetEarnedAmount > 0 and formatNumber(config.targetEarnedAmount) or "")
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数作为目标赚取金额",
                Duration = 5
            })

            if config.enableTargetKick then
                config.enableTargetKick = false
                targetEarnedToggle:Set(false)
                UILibrary:Notify({
                    Title = "目标踢出已禁用",
                    Text = "请设置有效目标赚取金额后重新启用",
                    Duration = 5
                })
                saveConfig()
            end
        end
    end
})

targetEarnedInput.Text = tostring(config.targetEarnedAmount > 0 and formatNumber(config.targetEarnedAmount) or "")

-- 标签页：关于
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于"
})

-- 作者信息
local authorInfo = UILibrary:CreateAuthorInfo(aboutContent, {
    Text = "作者: tongblx",
    SocialText = "感谢使用"
})

-- 添加一个按钮用于复制 Discord 链接
UILibrary:CreateButton(aboutContent, {
    Text = "复制 Discord",
    Position = UDim2.new(0, 10, 0, 80),
    Size = UDim2.new(0, 160, 0, 30),
    Callback = function()
        local link = "https://discord.gg/j20v0eWU8u"
        if setclipboard and type(link) == "string" then
            setclipboard(link)
            UILibrary:Notify({
                Title = "已复制",
                Text = "Discord 链接已复制到剪贴板",
                Duration = 2,
            })
        else
            UILibrary:Notify({
                Title = "复制失败",
                Text = "无法访问剪贴板功能",
                Duration = 2,
            })
        end
    end,
})

-- 初始化会话
initializeSession()

-- 初始化目标检查
pcall(initTargetEarned)

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    sendWelcomeMessage()
end

local unchangedCount = 0
local webhookDisabled = false

-- 运行时间和状态追踪变量
local startTime = os.time()
local lastSendTime = 0
local lastMoveTime = tick()
local lastPosition = nil
local idleThreshold = 300
local checkInterval = 1

-- 确保角色可用
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- 格式化时间显示
local function formatElapsedTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d小时%02d分%02d秒", hours, minutes, secs)
end

-- 掉线检测
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")

local player = Players.LocalPlayer
local disconnected = false

-- 网络断开（断线、掉线）
NetworkClient.ChildRemoved:Connect(function()
	if not disconnected then
		warn("[掉线检测] 网络断开")
		disconnected = true
	end
end)

-- 错误提示（被踢、封禁等）
GuiService.ErrorMessageChanged:Connect(function(msg)
	if msg and msg ~= "" and not disconnected then
		warn("[掉线检测] 错误提示：" .. msg)
		disconnected = true
	end
end)

-- 🌀 主循环开始
while true do
    local currentTime = os.time()
    local currentCurrency = fetchCurrentCurrency()
    local currentEarned = getCurrentEarnedAmount()

    -- 收益统计更新
    local sessionEarned = currentCurrency and sessionStartCurrency and (currentCurrency - sessionStartCurrency) or 0
    earnedCurrencyLabel.Text = "本次赚取: " .. formatNumber(sessionEarned)
    totalEarnedLabel.Text = "累计赚取: " .. formatNumber(config.totalEarnedAmount + sessionEarned)

    -- 🎯 目标赚取金额检测
    if not webhookDisabled and config.enableTargetKick and config.targetEarnedAmount > 0 and currentEarned >= config.targetEarnedAmount then
        local payload = {
            embeds = {{
                title = "🎯 目标赚取达成",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前赚取**: %s\n**目标赚取**: %s",
                    gameName, username,
                    formatNumber(currentEarned),
                    formatNumber(config.targetEarnedAmount)
                ),
                color = _G.PRIMARY_COLOR,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }}
        }
        UILibrary:Notify({
            Title = "目标达成",
            Text = "已达到目标赚取金额 " .. formatNumber(config.targetEarnedAmount) .. "，即将退出游戏",
            Duration = 5
        })
        if dispatchWebhook(payload) then
            wait(0.5)
            game:Shutdown()
            return
        end
    end

    -- ⚠️ 掉线检测
    if disconnected and not webhookDisabled then
        webhookDisabled = true
        dispatchWebhook({
            embeds = {{
                title = "⚠️ 掉线检测",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n**当前赚取**: %s\n检测到玩家掉线，请查看",
                    gameName, username, formatNumber(currentCurrency or 0), formatNumber(currentEarned)),
                color = 16753920,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }}
        })
        UILibrary:Notify({
            Title = "掉线检测",
            Text = "检测到玩家连接异常，已停止发送 Webhook",
            Duration = 5
        })
    end

    -- 💰 金额变化通知逻辑
    local interval = currentTime - lastSendTime
    if config.notifyCash and currentCurrency and interval >= getNotificationIntervalSeconds() and not webhookDisabled then
        local earnedChange = currentCurrency - (lastCurrency or currentCurrency)
        local elapsedTime = currentTime - startTime
        local avgMoney = "0"
        if elapsedTime > 0 then
            local rawAvg = sessionEarned / (elapsedTime / 3600)
            avgMoney = formatNumber(math.floor(rawAvg + 0.5))
        end

        local nextNotifyTimestamp = currentTime + getNotificationIntervalSeconds()
        local countdownR = string.format("<t:%d:R>", nextNotifyTimestamp)
        local countdownT = string.format("<t:%d:T>", nextNotifyTimestamp)

        local embed = {
            title = "Pluto-X",
            description = string.format("**游戏**: %s\n**用户**: %s", gameName, username),
            fields = {
                {
                    name = "💰 金额通知",
                    value = string.format(
                        "**用户名**: %s\n**已运行时间**: %s\n**当前金额**: %s\n**本次变化**: %s%s\n**本次赚取**: %s%s\n**累计赚取**: %s%s\n**平均速度**: %s /小时",
                        username,
                        formatElapsedTime(elapsedTime),
                        formatNumber(currentCurrency),
                        (earnedChange >= 0 and "+" or ""), formatNumber(earnedChange),
                        (sessionEarned >= 0 and "+" or ""), formatNumber(sessionEarned),
                        (currentEarned >= 0 and "+" or ""), formatNumber(currentEarned),
                        avgMoney
                    ),
                    inline = false
                },
                {
                    name = "⌛ 下次通知",
                    value = string.format("%s（%s）", countdownR, countdownT),
                    inline = false
                }
            },
            color = _G.PRIMARY_COLOR,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "作者: tongblx · Pluto-X" }
        }

        local webhookSuccess = dispatchWebhook({ embeds = { embed } })
        if webhookSuccess then
            lastSendTime = currentTime
            lastCurrency = currentCurrency
            UILibrary:Notify({
                Title = "定时通知",
                Text = "Webhook 已发送，下次时间: " .. os.date("%Y-%m-%d %H:%M:%S", nextNotifyTimestamp),
                Duration = 5
            })
        else
            UILibrary:Notify({
                Title = "Webhook 发送失败",
                Text = "请检查 Webhook 设置",
                Duration = 5
            })
        end
    end

    wait(checkInterval)
end