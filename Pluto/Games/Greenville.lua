-- ============================================================================
-- 反检测模块
-- ============================================================================

-- 禁用 ChildAdded 事件监听,防止游戏检测异常注入
for _, connection in pairs(getconnections(game.ChildAdded)) do
    if connection.Function and type(getfenv(connection.Function).script) ~= "table" then
        connection:Disable()
    end
end

-- 从 LogService 找到日志输出脚本句柄,供后续 hook 使用
local logScriptHandle = nil
for _, connection in pairs(getconnections(game:GetService("LogService").MessageOut)) do
    if connection.Function and not string.find(tostring(getupvalues(connection.Function)[1]), "Console") then
        logScriptHandle = getfenv(connection.Function).script
    end
end

-- Hook task.wait,若调用来自日志脚本则挂起协程(阻止日志输出)
local originalTaskWait = nil
originalTaskWait = hookfunction(task.wait, function(...)
    if not checkcaller() and getfenv(originalTaskWait).script == logScriptHandle then
        return coroutine.yield()  -- 挂起日志脚本的 wait,防止其继续执行
    else
        return originalTaskWait(...)
    end
end)

-- 清理所有与日志脚本相关的函数上值(防止其保存状态)
task.wait(1)
for _, gcObject in pairs(getgc(true)) do
    if type(gcObject) == "function" and getfenv(gcObject).script == logScriptHandle then
        for upvalueIndex, _ in pairs(getupvalues(gcObject)) do
            setupvalue(gcObject, upvalueIndex, nil)  -- 清空 upvalue,破坏其逻辑
        end
        task.wait()
    end
end

-- 篡改元表,拦截 FireServer 调用,阻止"BanMe""Bunny"事件发送
if getrawmetatable ~= nil then
    local gameMetatable = getrawmetatable(game)
    setreadonly(gameMetatable, false)
    local originalNamecall = gameMetatable.__namecall

    gameMetatable.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and (self.Name == "BanMe" or self.Name == "Bunny") then
            return nil  -- 阻止封号/检测事件
        else
            return originalNamecall(self, ...)
        end
    end)
end

-- ============================================================================
-- 服务和基础变量声明
-- ============================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")

-- 全局变量
local lastSendTime = os.time()
local sendingWelcome = false
_G.PRIMARY_COLOR = 5793266

-- ============================================================================
-- 工具函数
-- ============================================================================

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

-- 格式化运行时长
local function formatElapsedTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d小时%02d分%02d秒", hours, minutes, secs)
end

-- ============================================================================
-- UI 库加载
-- ============================================================================
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

-- ============================================================================
-- 玩家和游戏信息
-- ============================================================================
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

-- 获取游戏信息
local gameName = "未知游戏"
do
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if success and info then
        gameName = info.Name
    end
end

-- ============================================================================
-- 配置管理
-- ============================================================================
local configFile = "Pluto_X_GV_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notificationInterval = 30,
    targetAmount = 0,
    enableTargetKick = false,
    lastSavedCurrency = 0,
    baseAmount = 0,
    totalEarningsBase = 0,
    lastNotifyCurrency = 0,
}

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

-- ============================================================================
-- 金额相关函数
-- ============================================================================
local initialCurrency = 0

-- 获取当前金额
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
        -- 移除千位逗号,仅保留一个小数点和数字
        local cleanedText = currencyText:gsub(",", ""):match("[0-9%.]+")
        local currencyValue = tonumber(cleanedText)
        if currencyValue then
            return math.floor(currencyValue) -- 保留整数部分
        end
    end
    UILibrary:Notify({ Title = "错误", Text = "无法找到金额数据", Duration = 5 })
    return nil
end

-- 计算实际赚取金额
local function calculateEarnedAmount(currentCurrency)
    if not currentCurrency then return 0 end
    if config.totalEarningsBase > 0 then
        return currentCurrency - config.totalEarningsBase
    else
        return currentCurrency - initialCurrency
    end
end

-- 计算本次变化
local function calculateChangeAmount(currentCurrency)
    if not currentCurrency then return 0 end
    if config.lastNotifyCurrency > 0 then
        return currentCurrency - config.lastNotifyCurrency
    else
        return calculateEarnedAmount(currentCurrency)
    end
end

-- 更新保存的金额
local function updateLastSavedCurrency(currentCurrency)
    if currentCurrency and currentCurrency ~= config.lastSavedCurrency then
        config.lastSavedCurrency = currentCurrency
        saveConfig()
    end
end

-- 更新通知基准金额
local function updateLastNotifyCurrency(currentCurrency)
    if currentCurrency then
        config.lastNotifyCurrency = currentCurrency
        saveConfig()
    end
end

-- 初始化金额
do
    local success, currencyValue = pcall(fetchCurrentCurrency)
    if success and currencyValue then
        initialCurrency = currencyValue
        if config.totalEarningsBase == 0 then
            config.totalEarningsBase = currencyValue
        end
        if config.lastNotifyCurrency == 0 then
            config.lastNotifyCurrency = currencyValue
        end
        UILibrary:Notify({ Title = "初始化成功", Text = "当前金额: " .. tostring(initialCurrency), Duration = 5 })
    end
end

-- ============================================================================
-- Webhook 功能
-- ============================================================================

-- 统一获取通知间隔(秒)
local function getNotificationIntervalSeconds()
    return (config.notificationInterval or 5) * 60
end

-- Webhook 发送
local function dispatchWebhook(payload)
    if config.webhookUrl == "" then
        warn("[Webhook] 未设置 webhookUrl")
        return false
    end

    local requestFunc = syn and syn.request or http and http.request or request
    if not requestFunc then
        warn("[Webhook] 无可用请求函数")
        return false
    end

    local bodyJson = HttpService:JSONEncode({
        content = nil,
        embeds = payload.embeds
    })

    local success, res = pcall(function()
        return requestFunc({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = bodyJson
        })
    end)

    if not success then
        warn("[Webhook 请求失败] pcall 错误: " .. tostring(res))
        return false
    end

    -- 某些执行器返回 nil 但实际发送成功
    if not res then
        print("[Webhook] 执行器返回 nil,假定发送成功")
        return true
    end

    local statusCode = res.StatusCode or res.statusCode or 0
    if statusCode == 204 or statusCode == 200 or statusCode == 0 then
        print("[Webhook] 发送成功,状态码: " .. (statusCode == 0 and "未知(假定成功)" or statusCode))
        return true
    else
        warn("[Webhook 错误] 状态码: " .. tostring(statusCode))
        return false
    end
end

-- 发送欢迎消息
local function sendWelcomeMessage()
    if config.webhookUrl == "" then
        warn("[Webhook] 欢迎消息: Webhook 地址未设置")
        return false
    end
    
    if sendingWelcome then
        return false
    end
    
    sendingWelcome = true
    
    local payload = {
        embeds = {{
            title = "欢迎使用Pluto-X",
            description = string.format("**游戏**: %s\n**用户**: %s\n**启动时间**: %s", 
                gameName, username, os.date("%Y-%m-%d %H:%M:%S")),
            color = _G.PRIMARY_COLOR,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "作者: tongblx · Pluto-X" }
        }}
    }
    
    local success = dispatchWebhook(payload)
    sendingWelcome = false
    
    if success then
        UILibrary:Notify({
            Title = "Webhook",
            Text = "欢迎消息已发送",
            Duration = 3
        })
    else
        warn("[Webhook] 欢迎消息发送失败")
    end
    
    return success
end

-- ============================================================================
-- 目标金额管理
-- ============================================================================

-- 修改:只在金额减少时调整目标金额
local function adjustTargetAmount()
    if config.baseAmount <= 0 or config.targetAmount <= 0 then
        return
    end
    
    local currentCurrency = fetchCurrentCurrency()
    if not currentCurrency then
        return
    end
    
    local currencyDifference = currentCurrency - config.lastSavedCurrency
    
    -- 只在金额减少时调整
    if currencyDifference < 0 then
        local newTargetAmount = config.targetAmount + currencyDifference
        
        if newTargetAmount > currentCurrency then
            config.targetAmount = newTargetAmount
            UILibrary:Notify({
                Title = "目标金额已调整",
                Text = string.format("检测到金额减少 %s,目标调整至: %s", 
                    formatNumber(math.abs(currencyDifference)),
                    formatNumber(config.targetAmount)),
                Duration = 5
            })
            saveConfig()
        else
            config.enableTargetKick = false
            config.targetAmount = 0
            config.baseAmount = 0
            UILibrary:Notify({
                Title = "目标金额已重置",
                Text = "调整后的目标金额小于当前金额,已禁用目标踢出功能",
                Duration = 5
            })
            saveConfig()
        end
    end
    
    config.lastSavedCurrency = currentCurrency
    saveConfig()
end

-- 初始化时校验目标金额
local function initTargetAmount()
    local currentCurrency = fetchCurrentCurrency() or 0
    
    if config.enableTargetKick and config.targetAmount > 0 and currentCurrency >= config.targetAmount then
        UILibrary:Notify({
            Title = "目标金额已达成",
            Text = string.format("当前金额 %s,已超过目标 %s", 
                formatNumber(currentCurrency), formatNumber(config.targetAmount)),
            Duration = 5
        })
        config.enableTargetKick = false
        config.targetAmount = 0
        saveConfig()
    end
end

-- ============================================================================
-- 配置加载
-- ============================================================================
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
                UILibrary:Notify({
                    Title = "配置已加载",
                    Text = "用户配置加载成功",
                    Duration = 5,
                })
                adjustTargetAmount()
            else
                UILibrary:Notify({
                    Title = "配置提示",
                    Text = "使用默认配置",
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
            Text = "创建新配置文件",
            Duration = 5,
        })
        saveConfig()
    end
    
    -- 每次运行都发送欢迎消息
    if config.webhookUrl ~= "" then
        spawn(function()
            wait(2)
            sendWelcomeMessage()
        end)
    end
end

-- ============================================================================
-- 掉线检测
-- ============================================================================
local disconnected = false

NetworkClient.ChildRemoved:Connect(function()
    if not disconnected then
        warn("[掉线检测] 网络断开")
        disconnected = true
    end
end)

GuiService.ErrorMessageChanged:Connect(function(msg)
    if msg and msg ~= "" and not disconnected then
        warn("[掉线检测] 错误提示:" .. msg)
        disconnected = true
    end
end)

-- ============================================================================
-- 初始化
-- ============================================================================
pcall(initTargetAmount)
pcall(loadConfig)

-- ============================================================================
-- UI 创建
-- ============================================================================
local window = UILibrary:CreateUIWindow()
if not window then
    error("无法创建 UI 窗口")
end

local mainFrame = window.MainFrame
local screenGui = window.ScreenGui
local sidebar = window.Sidebar
local titleLabel = window.TitleLabel
local mainPage = window.MainPage

local toggleButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "菜单"
})

-- 常规标签页
local generalTab, generalContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "常规",
    Active = true
})

local generalCard = UILibrary:CreateCard(generalContent, { IsMultiElement = true })
UILibrary:CreateLabel(generalCard, {
    Text = "游戏: " .. gameName,
})
local earnedCurrencyLabel = UILibrary:CreateLabel(generalCard, {
    Text = "已赚金额: 0",
})

-- 反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
UILibrary:CreateLabel(antiAfkCard, {
    Text = "安全起见,反挂机未启用",
})

-- 通知设置标签页
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "通知设置"
})

-- Webhook 配置
local webhookCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
UILibrary:CreateLabel(webhookCard, {
    Text = "Webhook 地址",
})

local webhookInput = UILibrary:CreateTextBox(webhookCard, {
    PlaceholderText = "输入 Webhook 地址",
    OnFocusLost = function(text)
        if not text then return end
        
        local oldUrl = config.webhookUrl
        config.webhookUrl = text
        
        if config.webhookUrl ~= "" and config.webhookUrl ~= oldUrl then
            UILibrary:Notify({ 
                Title = "Webhook 更新", 
                Text = "正在发送测试消息...", 
                Duration = 5 
            })
            
            spawn(function()
                wait(0.5)
                sendWelcomeMessage()
            end)
        else
            UILibrary:Notify({ 
                Title = "Webhook 更新", 
                Text = "地址已保存", 
                Duration = 5 
            })
        end
        
        saveConfig()
    end
})
webhookInput.Text = config.webhookUrl

-- 监测金额变化
local currencyNotifyCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(currencyNotifyCard, {
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

-- 通知间隔
local intervalCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
UILibrary:CreateLabel(intervalCard, {
    Text = "通知间隔(分钟)",
})

local intervalInput = UILibrary:CreateTextBox(intervalCard, {
    PlaceholderText = "输入间隔时间",
    OnFocusLost = function(text)
        if not text then return end
        local num = tonumber(text)
        if num and num > 0 then
            config.notificationInterval = num
            UILibrary:Notify({ Title = "配置更新", Text = "通知间隔: " .. num .. " 分钟", Duration = 5 })
            saveConfig()
        else
            intervalInput.Text = tostring(config.notificationInterval)
            UILibrary:Notify({ Title = "配置错误", Text = "请输入有效数字", Duration = 5 })
        end
    end
})
intervalInput.Text = tostring(config.notificationInterval)

-- 基准金额设置
local baseAmountCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
UILibrary:CreateLabel(baseAmountCard, {
    Text = "基准金额设置",
})

local targetAmountLabel
local suppressTargetToggleCallback = false
local targetAmountToggle

local baseAmountInput = UILibrary:CreateTextBox(baseAmountCard, {
    PlaceholderText = "输入基准金额",
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")
        
        if not text or text == "" then
            config.baseAmount = 0
            config.targetAmount = 0
            config.lastSavedCurrency = 0
            baseAmountInput.Text = ""
            if targetAmountLabel then
                targetAmountLabel.Text = "目标金额: 未设置"
            end
            saveConfig()
            UILibrary:Notify({
                Title = "基准金额已清除",
                Text = "基准金额和目标金额已重置",
                Duration = 5
            })
            return
        end

        local cleanText = text:gsub(",", "")
        local num = tonumber(cleanText)
        
        if num and num > 0 then
            local currentCurrency = fetchCurrentCurrency() or 0
            local newTarget = num + currentCurrency
            
            config.baseAmount = num
            config.targetAmount = newTarget
            config.lastSavedCurrency = currentCurrency
            
            baseAmountInput.Text = formatNumber(num)
            
            if targetAmountLabel then
                targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
            end
            
            saveConfig()
            
            UILibrary:Notify({
                Title = "基准金额已设置",
                Text = string.format("基准: %s\n当前: %s\n目标: %s\n\n后续只在金额减少时调整", 
                    formatNumber(num), 
                    formatNumber(currentCurrency),
                    formatNumber(newTarget)),
                Duration = 8
            })
            
            if config.enableTargetKick and currentCurrency >= newTarget then
                suppressTargetToggleCallback = true
                if targetAmountToggle then
                    targetAmountToggle:Set(false)
                end
                config.enableTargetKick = false
                saveConfig()
                UILibrary:Notify({
                    Title = "自动关闭",
                    Text = "当前金额已达目标,踢出功能已关闭",
                    Duration = 6
                })
            end
        else
            baseAmountInput.Text = config.baseAmount > 0 and formatNumber(config.baseAmount) or ""
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数",
                Duration = 5
            })
        end
    end
})

if config.baseAmount > 0 then
    baseAmountInput.Text = formatNumber(config.baseAmount)
else
    baseAmountInput.Text = ""
end

-- 目标金额踢出
local targetAmountCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

targetAmountToggle = UILibrary:CreateToggle(targetAmountCard, {
    Text = "目标金额踢出",
    DefaultState = config.enableTargetKick or false,
    Callback = function(state)
        if suppressTargetToggleCallback then
            suppressTargetToggleCallback = false
            return
        end

        if state and config.webhookUrl == "" then
            targetAmountToggle:Set(false)
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            return
        end

        if state and (not config.targetAmount or config.targetAmount <= 0) then
            targetAmountToggle:Set(false)
            UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准金额", Duration = 5 })
            return
        end

        local currentCurrency = fetchCurrentCurrency()
        if state and currentCurrency and currentCurrency >= config.targetAmount then
            targetAmountToggle:Set(false)
            UILibrary:Notify({
                Title = "配置警告",
                Text = string.format("当前金额(%s)已超过目标(%s)",
                    formatNumber(currentCurrency),
                    formatNumber(config.targetAmount)),
                Duration = 6
            })
            return
        end

        config.enableTargetKick = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = string.format("目标踢出: %s\n目标: %s", 
                (state and "开启" or "关闭"),
                config.targetAmount > 0 and formatNumber(config.targetAmount) or "未设置"),
            Duration = 5
        })
        saveConfig()
    end
})

targetAmountLabel = UILibrary:CreateLabel(targetAmountCard, {
    Text = "目标金额: " .. (config.targetAmount > 0 and formatNumber(config.targetAmount) or "未设置"),
})

UILibrary:CreateButton(targetAmountCard, {
    Text = "重新计算目标金额",
    Callback = function()
        if config.baseAmount <= 0 then
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请先设置基准金额",
                Duration = 5
            })
            return
        end
        
        local currentCurrency = fetchCurrentCurrency() or 0
        local newTarget = config.baseAmount + currentCurrency
        
        if newTarget <= currentCurrency then
            UILibrary:Notify({
                Title = "计算错误",
                Text = "目标金额不能小于等于当前金额",
                Duration = 6
            })
            return
        end
        
        config.targetAmount = newTarget
        config.lastSavedCurrency = currentCurrency
        
        if targetAmountLabel then
            targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
        end
        
        saveConfig()
        
        UILibrary:Notify({
            Title = "目标金额已重新计算",
            Text = string.format("基准: %s\n当前: %s\n新目标: %s\n\n后续只在金额减少时调整", 
                formatNumber(config.baseAmount),
                formatNumber(currentCurrency),
                formatNumber(newTarget)),
            Duration = 8
        })
        
        if config.enableTargetKick and currentCurrency >= newTarget then
            suppressTargetToggleCallback = true
            targetAmountToggle:Set(false)
            config.enableTargetKick = false
            saveConfig()
            UILibrary:Notify({
                Title = "自动关闭",
                Text = "当前金额已达目标,踢出功能已关闭",
                Duration = 6
            })
        end
    end
})

-- 关于标签页
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于"
})

UILibrary:CreateAuthorInfo(aboutContent, {
    Text = "作者: tongblx",
    SocialText = "感谢使用"
})

UILibrary:CreateButton(aboutContent, {
    Text = "复制 Discord",
    Callback = function()
        local link = "https://discord.gg/j20v0eWU8u"
        if setclipboard then
            setclipboard(link)
            UILibrary:Notify({
                Title = "已复制",
                Text = "Discord 链接已复制",
                Duration = 2,
            })
        else
            UILibrary:Notify({
                Title = "复制失败",
                Text = "无法访问剪贴板",
                Duration = 2,
            })
        end
    end,
})

-- ============================================================================
-- 主循环
-- ============================================================================
local unchangedCount = 0
local webhookDisabled = false
local startTime = os.time()
local lastCurrency = nil
local checkInterval = 1

spawn(function()
    while true do
        local currentTime = os.time()
        local currentCurrency = fetchCurrentCurrency()

        -- 更新已赚金额显示
        local earnedAmount = calculateEarnedAmount(currentCurrency)
        earnedCurrencyLabel.Text = "已赚金额: " .. formatNumber(earnedAmount)

        local shouldShutdown = false

        -- 目标金额检测
        if config.enableTargetKick and currentCurrency and config.targetAmount > 0 then
            if currentCurrency >= config.targetAmount then
                local payload = {
                    embeds = {{
                        title = "🎯 目标金额达成",
                        description = string.format(
                            "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n**目标金额**: %s\n**基准金额**: %s\n**运行时长**: %s",
                            gameName, username,
                            formatNumber(currentCurrency),
                            formatNumber(config.targetAmount),
                            formatNumber(config.baseAmount),
                            formatElapsedTime(currentTime - startTime)
                        ),
                        color = _G.PRIMARY_COLOR,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "作者: tongblx · Pluto-X" }
                    }}
                }
                
                UILibrary:Notify({
                    Title = "🎯 目标达成",
                    Text = "已达目标金额,准备退出...",
                    Duration = 10
                })
                
                if config.webhookUrl ~= "" and not webhookDisabled then
                    dispatchWebhook(payload)
                end
                
                updateLastSavedCurrency(currentCurrency)
                config.enableTargetKick = false
                saveConfig()
                
                wait(3)
                pcall(function() game:Shutdown() end)
                pcall(function() player:Kick("目标金额已达成") end)
                return
            end
        end

        -- 掉线检测
        if disconnected and not webhookDisabled then
            webhookDisabled = true
            dispatchWebhook({
                embeds = {{
                    title = "⚠️ 掉线检测",
                    description = string.format(
                        "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n检测到掉线",
                        gameName, username, formatNumber(currentCurrency or 0)),
                    color = 16753920,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "作者: tongblx · Pluto-X" }
                }}
            })
            UILibrary:Notify({
                Title = "掉线检测",
                Text = "检测到连接异常",
                Duration = 5
            })
        end

        -- 通知间隔检测
        local interval = currentTime - lastSendTime
        if not webhookDisabled and config.notifyCash
           and interval >= getNotificationIntervalSeconds() then

            local earnedChange = calculateChangeAmount(currentCurrency)

            -- 检测金额变化
            if currentCurrency == lastCurrency and earnedChange == 0 then
                unchangedCount = unchangedCount + 1
            else
                unchangedCount = 0
            end

            if unchangedCount >= 2 then
                dispatchWebhook({
                    embeds = {{
                        title = "⚠️ 金额未变化",
                        description = string.format(
                            "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n连续两次金额无变化",
                            gameName, username, formatNumber(currentCurrency or 0)),
                        color = 16753920,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "作者: tongblx · Pluto-X" }
                    }}
                })

                webhookDisabled = true
                lastSendTime = currentTime
                lastCurrency = currentCurrency
                updateLastNotifyCurrency(currentCurrency)
                updateLastSavedCurrency(currentCurrency)
                
                UILibrary:Notify({
                    Title = "连接异常",
                    Text = "金额长时间未变化",
                    Duration = 5
                })
            else
                local nextNotifyTimestamp = currentTime + getNotificationIntervalSeconds()
                local countdownR = string.format("<t:%d:R>", nextNotifyTimestamp)
                local countdownT = string.format("<t:%d:T>", nextNotifyTimestamp)

                local elapsedTime = currentTime - startTime
                -- 修改:使用本次变化计算平均速度
                local avgMoney = "0"
                if interval > 0 then
                    local rawAvg = earnedChange / (interval / 3600)
                    avgMoney = formatNumber(math.floor(rawAvg + 0.5))
                end

                local embed = {
                    title = "Pluto-X",
                    description = string.format("**游戏**: %s\n**用户**: %s", gameName, username),
                    fields = {
                        {
                            name = "💰金额通知",
                            value = string.format(
                                "**用户名**: %s\n**运行时长**: %s\n**当前金额**: %s\n**本次变化**: %s%s\n**总计收益**: %s%s\n**平均速度**: %s /小时",
                                username,
                                formatElapsedTime(elapsedTime),
                                formatNumber(currentCurrency),
                                (earnedChange >= 0 and "+" or ""), formatNumber(earnedChange),
                                (earnedAmount >= 0 and "+" or ""), formatNumber(earnedAmount),
                                avgMoney
                            ),
                            inline = false
                        },
                        {
                            name = "⌛ 下次通知",
                            value = string.format("%s(%s)", countdownR, countdownT),
                            inline = false
                        }
                    },
                    color = _G.PRIMARY_COLOR,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "作者: tongblx · Pluto-X" }
                }

                dispatchWebhook({ embeds = { embed } })
                
                -- 无论成功与否都更新时间戳
                lastSendTime = currentTime
                lastCurrency = currentCurrency
                updateLastNotifyCurrency(currentCurrency)
                updateLastSavedCurrency(currentCurrency)
                
                UILibrary:Notify({
                    Title = "定时通知",
                    Text = "下次: " .. os.date("%H:%M:%S", nextNotifyTimestamp),
                    Duration = 5
                })
            end
        end

        wait(checkInterval)
    end
end)