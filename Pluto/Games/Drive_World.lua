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
local configFile = "Pluto_X_DW_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notifyWins = false,
    notifyMiles = false,
    notifyLevel = false,
    notificationInterval = 30,
    targetAmount = 0,
    enableTargetKick = false,
    lastSavedCurrency = 0,
    baseAmount = 0,
    totalEarningsBase = 0,
    lastNotifyCurrency = 0,
    totalWinsBase = 0,
    lastNotifyWins = 0,
    totalMilesBase = 0,
    lastNotifyMiles = 0,
    totalLevelBase = 0,
    lastNotifyLevel = 0,
    -- 新增目标踢出配置
    targetWins = 0,
    enableTargetWinsKick = false,
    baseWins = 0,
    lastSavedWins = 0,
    targetMiles = 0,
    enableTargetMilesKick = false,
    baseMiles = 0,
    lastSavedMiles = 0,
    targetLevel = 0,
    enableTargetLevelKick = false,
    baseLevel = 0,
    lastSavedLevel = 0,
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
-- 数据获取函数
-- ============================================================================
local initialCurrency = 0
local initialWins = 0
local initialMiles = 0
local initialLevel = 0

-- 获取当前金额
local function fetchCurrentCurrency()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    if LocalPlayer then
        local currencyTextLabel = LocalPlayer.PlayerGui:WaitForChild("MainHUD", 5)
                                            :FindFirstChild("Frame", true)
                                            :FindFirstChild("TopRight", true)
                                            :FindFirstChild("CurrencyCounters", true)
                                            :FindFirstChild("CashCounter", true)
                                            :FindFirstChild("CurrencyAmount", true)
        
        if currencyTextLabel and currencyTextLabel:IsA("TextLabel") then
            local text = currencyTextLabel.Text
            
            local cleanedText = string.gsub(text, "[^0-9%.]", "")
            
            return tonumber(cleanedText)
        end
    end
    return nil
end

-- 获取当前胜利次数
local function fetchCurrentWins()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local wins = leaderstats:FindFirstChild("Wins")
        if wins then
            return wins.Value
        end
    end
    return nil
end

-- 获取当前里程
local function fetchCurrentMiles()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local miles = leaderstats:FindFirstChild("Miles")
        if miles then
            return miles.Value
        end
    end
    return nil
end

-- 获取当前等级
local function fetchCurrentLevel()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local level = leaderstats:FindFirstChild("Level")
        if level then
            return level.Value
        end
    end
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

-- 计算本次金额变化
local function calculateChangeAmount(currentCurrency)
    if not currentCurrency then return 0 end
    if config.lastNotifyCurrency > 0 then
        return currentCurrency - config.lastNotifyCurrency
    else
        return calculateEarnedAmount(currentCurrency)
    end
end

-- 计算胜利次数变化
local function calculateWinsChange(currentWins)
    if not currentWins then return 0 end
    if config.lastNotifyWins > 0 then
        return currentWins - config.lastNotifyWins
    else
        if config.totalWinsBase > 0 then
            return currentWins - config.totalWinsBase
        else
            return currentWins - initialWins
        end
    end
end

-- 计算里程变化
local function calculateMilesChange(currentMiles)
    if not currentMiles then return 0 end
    if config.lastNotifyMiles > 0 then
        return currentMiles - config.lastNotifyMiles
    else
        if config.totalMilesBase > 0 then
            return currentMiles - config.totalMilesBase
        else
            return currentMiles - initialMiles
        end
    end
end

-- 计算等级变化
local function calculateLevelChange(currentLevel)
    if not currentLevel then return 0 end
    if config.lastNotifyLevel > 0 then
        return currentLevel - config.lastNotifyLevel
    else
        if config.totalLevelBase > 0 then
            return currentLevel - config.totalLevelBase
        else
            return currentLevel - initialLevel
        end
    end
end

-- 更新保存的金额
local function updateLastSavedCurrency(currentCurrency)
    if currentCurrency and currentCurrency ~= config.lastSavedCurrency then
        config.lastSavedCurrency = currentCurrency
        saveConfig()
    end
end

-- 更新通知基准
local function updateLastNotifyData(currentCurrency, currentWins, currentMiles, currentLevel)
    if currentCurrency then
        config.lastNotifyCurrency = currentCurrency
    end
    if currentWins then
        config.lastNotifyWins = currentWins
    end
    if currentMiles then
        config.lastNotifyMiles = currentMiles
    end
    if currentLevel then
        config.lastNotifyLevel = currentLevel
    end
    saveConfig()
end

-- 初始化所有数据
do
    local success1, currencyValue = pcall(fetchCurrentCurrency)
    local success2, winsValue = pcall(fetchCurrentWins)
    local success3, milesValue = pcall(fetchCurrentMiles)
    local success4, levelValue = pcall(fetchCurrentLevel)
    
    if success1 and currencyValue then
        initialCurrency = currencyValue
        if config.totalEarningsBase == 0 then
            config.totalEarningsBase = currencyValue
        end
        if config.lastNotifyCurrency == 0 then
            config.lastNotifyCurrency = currencyValue
        end
    end
    
    if success2 and winsValue then
        initialWins = winsValue
        if config.totalWinsBase == 0 then
            config.totalWinsBase = winsValue
        end
        if config.lastNotifyWins == 0 then
            config.lastNotifyWins = winsValue
        end
    end
    
    if success3 and milesValue then
        initialMiles = milesValue
        if config.totalMilesBase == 0 then
            config.totalMilesBase = milesValue
        end
        if config.lastNotifyMiles == 0 then
            config.lastNotifyMiles = milesValue
        end
    end
    
    if success4 and levelValue then
        initialLevel = levelValue
        if config.totalLevelBase == 0 then
            config.totalLevelBase = levelValue
        end
        if config.lastNotifyLevel == 0 then
            config.lastNotifyLevel = levelValue
        end
    end
    
    UILibrary:Notify({ 
        Title = "初始化成功", 
        Text = string.format("Cash: %s | Wins: %s | Miles: %s | Level: %s", 
            tostring(initialCurrency), tostring(initialWins), 
            tostring(initialMiles), tostring(initialLevel)), 
        Duration = 5 
    })
end

-- ============================================================================
-- Webhook 功能
-- ============================================================================

-- 统一获取通知间隔（秒）
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

    if not res then
        print("[Webhook] 执行器返回 nil，假定发送成功")
        return true
    end

    local statusCode = res.StatusCode or res.statusCode or 0
    if statusCode == 204 or statusCode == 200 or statusCode == 0 then
        print("[Webhook] 发送成功，状态码: " .. (statusCode == 0 and "未知(假定成功)" or statusCode))
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

-- 只在金额减少时调整目标金额
local function adjustTargetAmount()
    if config.baseAmount <= 0 or config.targetAmount <= 0 then
        return
    end
    
    local currentCurrency = fetchCurrentCurrency()
    if not currentCurrency then
        return
    end
    
    local currencyDifference = currentCurrency - config.lastSavedCurrency
    
    if currencyDifference < 0 then
        local newTargetAmount = config.targetAmount + currencyDifference
        
        if newTargetAmount > currentCurrency then
            config.targetAmount = newTargetAmount
            UILibrary:Notify({
                Title = "目标金额已调整",
                Text = string.format("检测到金额减少 %s，目标调整至: %s", 
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
                Text = "调整后的目标金额小于当前金额，已禁用目标踢出功能",
                Duration = 5
            })
            saveConfig()
        end
    end
    
    config.lastSavedCurrency = currentCurrency
    saveConfig()
end

-- 只在胜利次数减少时调整目标胜利次数
local function adjustTargetWins()
    if config.baseWins <= 0 or config.targetWins <= 0 then
        return
    end
    
    local currentWins = fetchCurrentWins()
    if not currentWins then
        return
    end
    
    local winsDifference = currentWins - config.lastSavedWins
    
    if winsDifference < 0 then
        local newTargetWins = config.targetWins + winsDifference
        
        if newTargetWins > currentWins then
            config.targetWins = newTargetWins
            UILibrary:Notify({
                Title = "目标胜利次数已调整",
                Text = string.format("检测到胜利次数减少 %s，目标调整至: %s", 
                    formatNumber(math.abs(winsDifference)),
                    formatNumber(config.targetWins)),
                Duration = 5
            })
            saveConfig()
        else
            config.enableTargetWinsKick = false
            config.targetWins = 0
            config.baseWins = 0
            UILibrary:Notify({
                Title = "目标胜利次数已重置",
                Text = "调整后的目标胜利次数小于当前次数，已禁用目标踢出功能",
                Duration = 5
            })
            saveConfig()
        end
    end
    
    config.lastSavedWins = currentWins
    saveConfig()
end

-- 只在里程减少时调整目标里程
local function adjustTargetMiles()
    if config.baseMiles <= 0 or config.targetMiles <= 0 then
        return
    end
    
    local currentMiles = fetchCurrentMiles()
    if not currentMiles then
        return
    end
    
    local milesDifference = currentMiles - config.lastSavedMiles
    
    if milesDifference < 0 then
        local newTargetMiles = config.targetMiles + milesDifference
        
        if newTargetMiles > currentMiles then
            config.targetMiles = newTargetMiles
            UILibrary:Notify({
                Title = "目标里程已调整",
                Text = string.format("检测到里程减少 %s，目标调整至: %s", 
                    formatNumber(math.abs(milesDifference)),
                    formatNumber(config.targetMiles)),
                Duration = 5
            })
            saveConfig()
        else
            config.enableTargetMilesKick = false
            config.targetMiles = 0
            config.baseMiles = 0
            UILibrary:Notify({
                Title = "目标里程已重置",
                Text = "调整后的目标里程小于当前里程，已禁用目标踢出功能",
                Duration = 5
            })
            saveConfig()
        end
    end
    
    config.lastSavedMiles = currentMiles
    saveConfig()
end

-- 只在等级减少时调整目标等级
local function adjustTargetLevel()
    if config.baseLevel <= 0 or config.targetLevel <= 0 then
        return
    end
    
    local currentLevel = fetchCurrentLevel()
    if not currentLevel then
        return
    end
    
    local levelDifference = currentLevel - config.lastSavedLevel
    
    if levelDifference < 0 then
        local newTargetLevel = config.targetLevel + levelDifference
        
        if newTargetLevel > currentLevel then
            config.targetLevel = newTargetLevel
            UILibrary:Notify({
                Title = "目标等级已调整",
                Text = string.format("检测到等级减少 %s，目标调整至: %s", 
                    formatNumber(math.abs(levelDifference)),
                    formatNumber(config.targetLevel)),
                Duration = 5
            })
            saveConfig()
        else
            config.enableTargetLevelKick = false
            config.targetLevel = 0
            config.baseLevel = 0
            UILibrary:Notify({
                Title = "目标等级已重置",
                Text = "调整后的目标等级小于当前等级，已禁用目标踢出功能",
                Duration = 5
            })
            saveConfig()
        end
    end
    
    config.lastSavedLevel = currentLevel
    saveConfig()
end

-- 初始化时校验目标金额
local function initTargetAmount()
    local currentCurrency = fetchCurrentCurrency() or 0
    
    if config.enableTargetKick and config.targetAmount > 0 and currentCurrency >= config.targetAmount then
        UILibrary:Notify({
            Title = "目标金额已达成",
            Text = string.format("当前金额 %s，已超过目标 %s", 
                formatNumber(currentCurrency), formatNumber(config.targetAmount)),
            Duration = 5
        })
        config.enableTargetKick = false
        config.targetAmount = 0
        saveConfig()
    end
end

-- 初始化时校验目标胜利次数
local function initTargetWins()
    local currentWins = fetchCurrentWins() or 0
    
    if config.enableTargetWinsKick and config.targetWins > 0 and currentWins >= config.targetWins then
        UILibrary:Notify({
            Title = "目标胜利次数已达成",
            Text = string.format("当前胜利次数 %s，已超过目标 %s", 
                formatNumber(currentWins), formatNumber(config.targetWins)),
            Duration = 5
        })
        config.enableTargetWinsKick = false
        config.targetWins = 0
        saveConfig()
    end
end

-- 初始化时校验目标里程
local function initTargetMiles()
    local currentMiles = fetchCurrentMiles() or 0
    
    if config.enableTargetMilesKick and config.targetMiles > 0 and currentMiles >= config.targetMiles then
        UILibrary:Notify({
            Title = "目标里程已达成",
            Text = string.format("当前里程 %s，已超过目标 %s", 
                formatNumber(currentMiles), formatNumber(config.targetMiles)),
            Duration = 5
        })
        config.enableTargetMilesKick = false
        config.targetMiles = 0
        saveConfig()
    end
end

-- 初始化时校验目标等级
local function initTargetLevel()
    local currentLevel = fetchCurrentLevel() or 0
    
    if config.enableTargetLevelKick and config.targetLevel > 0 and currentLevel >= config.targetLevel then
        UILibrary:Notify({
            Title = "目标等级已达成",
            Text = string.format("当前等级 %s，已超过目标 %s", 
                formatNumber(currentLevel), formatNumber(config.targetLevel)),
            Duration = 5
        })
        config.enableTargetLevelKick = false
        config.targetLevel = 0
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
                adjustTargetWins()
                adjustTargetMiles()
                adjustTargetLevel()
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
-- 反挂机
-- ============================================================================
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    UILibrary:Notify({ Title = "反挂机", Text = "检测到闲置", Duration = 3 })
end)

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
        warn("[掉线检测] 错误提示：" .. msg)
        disconnected = true
    end
end)

-- ============================================================================
-- 初始化
-- ============================================================================
pcall(initTargetAmount)
pcall(initTargetWins)
pcall(initTargetMiles)
pcall(initTargetLevel)
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

-- 显示数据
local generalCard = UILibrary:CreateCard(generalContent, { IsMultiElement = true })
UILibrary:CreateLabel(generalCard, {
    Text = "游戏: " .. gameName,
})
local earnedCurrencyLabel = UILibrary:CreateLabel(generalCard, {
    Text = "已赚金额: 0",
})
local earnedWinsLabel = UILibrary:CreateLabel(generalCard, {
    Text = "胜利增加: 0",
})
local earnedMilesLabel = UILibrary:CreateLabel(generalCard, {
    Text = "里程增加: 0",
})
local earnedLevelLabel = UILibrary:CreateLabel(generalCard, {
    Text = "等级增加: 0",
})

-- 反挂机卡片
local antiAfkCard = UILibrary:CreateCard(generalContent)
UILibrary:CreateLabel(antiAfkCard, {
    Text = "反挂机已启用",
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

-- 数据监测开关
local cashNotifyCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(cashNotifyCard, {
    Text = "监测金额变化 (Cash)",
    DefaultState = config.notifyCash,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.notifyCash = false
            return
        end
        config.notifyCash = state
        UILibrary:Notify({ Title = "配置更新", Text = "金额监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
    end
})

local winsNotifyCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(winsNotifyCard, {
    Text = "监测胜利次数 (Wins)",
    DefaultState = config.notifyWins,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.notifyWins = false
            return
        end
        config.notifyWins = state
        UILibrary:Notify({ Title = "配置更新", Text = "胜利监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
    end
})

local milesNotifyCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(milesNotifyCard, {
    Text = "监测里程 (Miles)",
    DefaultState = config.notifyMiles,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.notifyMiles = false
            return
        end
        config.notifyMiles = state
        UILibrary:Notify({ Title = "配置更新", Text = "里程监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
    end
})

local levelNotifyCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(levelNotifyCard, {
    Text = "监测等级 (Level)",
    DefaultState = config.notifyLevel,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.notifyLevel = false
            return
        end
        config.notifyLevel = state
        UILibrary:Notify({ Title = "配置更新", Text = "等级监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
    end
})

-- 通知间隔
local intervalCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
UILibrary:CreateLabel(intervalCard, {
    Text = "通知间隔（分钟）",
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
    Text = "基准金额设置 (仅Cash)",
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
                    Text = "当前金额已达目标，踢出功能已关闭",
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
                Text = "当前金额已达目标，踢出功能已关闭",
                Duration = 6
            })
        end
    end
})

-- 目标胜利次数踢出
local targetWinsCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

local suppressTargetWinsToggleCallback = false
local targetWinsToggle
local targetWinsLabel

local baseWinsInput = UILibrary:CreateTextBox(targetWinsCard, {
    PlaceholderText = "输入基准胜利次数",
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")
        
        if not text or text == "" then
            config.baseWins = 0
            config.targetWins = 0
            config.lastSavedWins = 0
            baseWinsInput.Text = ""
            if targetWinsLabel then
                targetWinsLabel.Text = "目标胜利次数: 未设置"
            end
            saveConfig()
            UILibrary:Notify({
                Title = "基准胜利次数已清除",
                Text = "基准胜利次数和目标胜利次数已重置",
                Duration = 5
            })
            return
        end

        local cleanText = text:gsub(",", "")
        local num = tonumber(cleanText)
        
        if num and num > 0 then
            local currentWins = fetchCurrentWins() or 0
            local newTarget = num + currentWins
            
            config.baseWins = num
            config.targetWins = newTarget
            config.lastSavedWins = currentWins
            
            baseWinsInput.Text = formatNumber(num)
            
            if targetWinsLabel then
                targetWinsLabel.Text = "目标胜利次数: " .. formatNumber(newTarget)
            end
            
            saveConfig()
            
            UILibrary:Notify({
                Title = "基准胜利次数已设置",
                Text = string.format("基准: %s\n当前: %s\n目标: %s\n\n后续只在胜利次数减少时调整", 
                    formatNumber(num), 
                    formatNumber(currentWins),
                    formatNumber(newTarget)),
                Duration = 8
            })
            
            if config.enableTargetWinsKick and currentWins >= newTarget then
                suppressTargetWinsToggleCallback = true
                if targetWinsToggle then
                    targetWinsToggle:Set(false)
                end
                config.enableTargetWinsKick = false
                saveConfig()
                UILibrary:Notify({
                    Title = "自动关闭",
                    Text = "当前胜利次数已达目标，踢出功能已关闭",
                    Duration = 6
                })
            end
        else
            baseWinsInput.Text = config.baseWins > 0 and formatNumber(config.baseWins) or ""
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数",
                Duration = 5
            })
        end
    end
})

if config.baseWins > 0 then
    baseWinsInput.Text = formatNumber(config.baseWins)
else
    baseWinsInput.Text = ""
end

targetWinsToggle = UILibrary:CreateToggle(targetWinsCard, {
    Text = "目标胜利次数踢出",
    DefaultState = config.enableTargetWinsKick or false,
    Callback = function(state)
        if suppressTargetWinsToggleCallback then
            suppressTargetWinsToggleCallback = false
            return
        end

        if state and config.webhookUrl == "" then
            targetWinsToggle:Set(false)
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            return
        end

        if state and (not config.targetWins or config.targetWins <= 0) then
            targetWinsToggle:Set(false)
            UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准胜利次数", Duration = 5 })
            return
        end

        local currentWins = fetchCurrentWins()
        if state and currentWins and currentWins >= config.targetWins then
            targetWinsToggle:Set(false)
            UILibrary:Notify({
                Title = "配置警告",
                Text = string.format("当前胜利次数(%s)已超过目标(%s)",
                    formatNumber(currentWins),
                    formatNumber(config.targetWins)),
                Duration = 6
            })
            return
        end

        config.enableTargetWinsKick = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = string.format("目标胜利次数踢出: %s\n目标: %s", 
                (state and "开启" or "关闭"),
                config.targetWins > 0 and formatNumber(config.targetWins) or "未设置"),
            Duration = 5
        })
        saveConfig()
    end
})

targetWinsLabel = UILibrary:CreateLabel(targetWinsCard, {
    Text = "目标胜利次数: " .. (config.targetWins > 0 and formatNumber(config.targetWins) or "未设置"),
})

UILibrary:CreateButton(targetWinsCard, {
    Text = "重新计算目标胜利次数",
    Callback = function()
        if config.baseWins <= 0 then
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请先设置基准胜利次数",
                Duration = 5
            })
            return
        end
        
        local currentWins = fetchCurrentWins() or 0
        local newTarget = config.baseWins + currentWins
        
        if newTarget <= currentWins then
            UILibrary:Notify({
                Title = "计算错误",
                Text = "目标胜利次数不能小于等于当前胜利次数",
                Duration = 6
            })
            return
        end
        
        config.targetWins = newTarget
        config.lastSavedWins = currentWins
        
        if targetWinsLabel then
            targetWinsLabel.Text = "目标胜利次数: " .. formatNumber(newTarget)
        end
        
        saveConfig()
        
        UILibrary:Notify({
            Title = "目标胜利次数已重新计算",
            Text = string.format("基准: %s\n当前: %s\n新目标: %s\n\n后续只在胜利次数减少时调整", 
                formatNumber(config.baseWins),
                formatNumber(currentWins),
                formatNumber(newTarget)),
            Duration = 8
        })
        
        if config.enableTargetWinsKick and currentWins >= newTarget then
            suppressTargetWinsToggleCallback = true
            targetWinsToggle:Set(false)
            config.enableTargetWinsKick = false
            saveConfig()
            UILibrary:Notify({
                Title = "自动关闭",
                Text = "当前胜利次数已达目标，踢出功能已关闭",
                Duration = 6
            })
        end
    end
})

-- 目标里程踢出
local targetMilesCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

local suppressTargetMilesToggleCallback = false
local targetMilesToggle
local targetMilesLabel

local baseMilesInput = UILibrary:CreateTextBox(targetMilesCard, {
    PlaceholderText = "输入基准里程",
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")
        
        if not text or text == "" then
            config.baseMiles = 0
            config.targetMiles = 0
            config.lastSavedMiles = 0
            baseMilesInput.Text = ""
            if targetMilesLabel then
                targetMilesLabel.Text = "目标里程: 未设置"
            end
            saveConfig()
            UILibrary:Notify({
                Title = "基准里程已清除",
                Text = "基准里程和目标里程已重置",
                Duration = 5
            })
            return
        end

        local cleanText = text:gsub(",", "")
        local num = tonumber(cleanText)
        
        if num and num > 0 then
            local currentMiles = fetchCurrentMiles() or 0
            local newTarget = num + currentMiles
            
            config.baseMiles = num
            config.targetMiles = newTarget
            config.lastSavedMiles = currentMiles
            
            baseMilesInput.Text = formatNumber(num)
            
            if targetMilesLabel then
                targetMilesLabel.Text = "目标里程: " .. formatNumber(newTarget)
            end
            
            saveConfig()
            
            UILibrary:Notify({
                Title = "基准里程已设置",
                Text = string.format("基准: %s\n当前: %s\n目标: %s\n\n后续只在里程减少时调整", 
                    formatNumber(num), 
                    formatNumber(currentMiles),
                    formatNumber(newTarget)),
                Duration = 8
            })
            
            if config.enableTargetMilesKick and currentMiles >= newTarget then
                suppressTargetMilesToggleCallback = true
                if targetMilesToggle then
                    targetMilesToggle:Set(false)
                end
                config.enableTargetMilesKick = false
                saveConfig()
                UILibrary:Notify({
                    Title = "自动关闭",
                    Text = "当前里程已达目标，踢出功能已关闭",
                    Duration = 6
                })
            end
        else
            baseMilesInput.Text = config.baseMiles > 0 and formatNumber(config.baseMiles) or ""
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数",
                Duration = 5
            })
        end
    end
})

if config.baseMiles > 0 then
    baseMilesInput.Text = formatNumber(config.baseMiles)
else
    baseMilesInput.Text = ""
end

targetMilesToggle = UILibrary:CreateToggle(targetMilesCard, {
    Text = "目标里程踢出",
    DefaultState = config.enableTargetMilesKick or false,
    Callback = function(state)
        if suppressTargetMilesToggleCallback then
            suppressTargetMilesToggleCallback = false
            return
        end

        if state and config.webhookUrl == "" then
            targetMilesToggle:Set(false)
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            return
        end

        if state and (not config.targetMiles or config.targetMiles <= 0) then
            targetMilesToggle:Set(false)
            UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准里程", Duration = 5 })
            return
        end

        local currentMiles = fetchCurrentMiles()
        if state and currentMiles and currentMiles >= config.targetMiles then
            targetMilesToggle:Set(false)
            UILibrary:Notify({
                Title = "配置警告",
                Text = string.format("当前里程(%s)已超过目标(%s)",
                    formatNumber(currentMiles),
                    formatNumber(config.targetMiles)),
                Duration = 6
            })
            return
        end

        config.enableTargetMilesKick = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = string.format("目标里程踢出: %s\n目标: %s", 
                (state and "开启" or "关闭"),
                config.targetMiles > 0 and formatNumber(config.targetMiles) or "未设置"),
            Duration = 5
        })
        saveConfig()
    end
})

targetMilesLabel = UILibrary:CreateLabel(targetMilesCard, {
    Text = "目标里程: " .. (config.targetMiles > 0 and formatNumber(config.targetMiles) or "未设置"),
})

UILibrary:CreateButton(targetMilesCard, {
    Text = "重新计算目标里程",
    Callback = function()
        if config.baseMiles <= 0 then
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请先设置基准里程",
                Duration = 5
            })
            return
        end
        
        local currentMiles = fetchCurrentMiles() or 0
        local newTarget = config.baseMiles + currentMiles
        
        if newTarget <= currentMiles then
            UILibrary:Notify({
                Title = "计算错误",
                Text = "目标里程不能小于等于当前里程",
                Duration = 6
            })
            return
        end
        
        config.targetMiles = newTarget
        config.lastSavedMiles = currentMiles
        
        if targetMilesLabel then
            targetMilesLabel.Text = "目标里程: " .. formatNumber(newTarget)
        end
        
        saveConfig()
        
        UILibrary:Notify({
            Title = "目标里程已重新计算",
            Text = string.format("基准: %s\n当前: %s\n新目标: %s\n\n后续只在里程减少时调整", 
                formatNumber(config.baseMiles),
                formatNumber(currentMiles),
                formatNumber(newTarget)),
            Duration = 8
        })
        
        if config.enableTargetMilesKick and currentMiles >= newTarget then
            suppressTargetMilesToggleCallback = true
            targetMilesToggle:Set(false)
            config.enableTargetMilesKick = false
            saveConfig()
            UILibrary:Notify({
                Title = "自动关闭",
                Text = "当前里程已达目标，踢出功能已关闭",
                Duration = 6
            })
        end
    end
})

-- 目标等级踢出
local targetLevelCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

local suppressTargetLevelToggleCallback = false
local targetLevelToggle
local targetLevelLabel

local baseLevelInput = UILibrary:CreateTextBox(targetLevelCard, {
    PlaceholderText = "输入基准等级",
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")
        
        if not text or text == "" then
            config.baseLevel = 0
            config.targetLevel = 0
            config.lastSavedLevel = 0
            baseLevelInput.Text = ""
            if targetLevelLabel then
                targetLevelLabel.Text = "目标等级: 未设置"
            end
            saveConfig()
            UILibrary:Notify({
                Title = "基准等级已清除",
                Text = "基准等级和目标等级已重置",
                Duration = 5
            })
            return
        end

        local cleanText = text:gsub(",", "")
        local num = tonumber(cleanText)
        
        if num and num > 0 then
            local currentLevel = fetchCurrentLevel() or 0
            local newTarget = num + currentLevel
            
            config.baseLevel = num
            config.targetLevel = newTarget
            config.lastSavedLevel = currentLevel
            
            baseLevelInput.Text = formatNumber(num)
            
            if targetLevelLabel then
                targetLevelLabel.Text = "目标等级: " .. formatNumber(newTarget)
            end
            
            saveConfig()
            
            UILibrary:Notify({
                Title = "基准等级已设置",
                Text = string.format("基准: %s\n当前: %s\n目标: %s\n\n后续只在等级减少时调整", 
                    formatNumber(num), 
                    formatNumber(currentLevel),
                    formatNumber(newTarget)),
                Duration = 8
            })
            
            if config.enableTargetLevelKick and currentLevel >= newTarget then
                suppressTargetLevelToggleCallback = true
                if targetLevelToggle then
                    targetLevelToggle:Set(false)
                end
                config.enableTargetLevelKick = false
                saveConfig()
                UILibrary:Notify({
                    Title = "自动关闭",
                    Text = "当前等级已达目标，踢出功能已关闭",
                    Duration = 6
                })
            end
        else
            baseLevelInput.Text = config.baseLevel > 0 and formatNumber(config.baseLevel) or ""
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数",
                Duration = 5
            })
        end
    end
})

if config.baseLevel > 0 then
    baseLevelInput.Text = formatNumber(config.baseLevel)
else
    baseLevelInput.Text = ""
end

targetLevelToggle = UILibrary:CreateToggle(targetLevelCard, {
    Text = "目标等级踢出",
    DefaultState = config.enableTargetLevelKick or false,
    Callback = function(state)
        if suppressTargetLevelToggleCallback then
            suppressTargetLevelToggleCallback = false
            return
        end

        if state and config.webhookUrl == "" then
            targetLevelToggle:Set(false)
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            return
        end

        if state and (not config.targetLevel or config.targetLevel <= 0) then
            targetLevelToggle:Set(false)
            UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准等级", Duration = 5 })
            return
        end

        local currentLevel = fetchCurrentLevel()
        if state and currentLevel and currentLevel >= config.targetLevel then
            targetLevelToggle:Set(false)
            UILibrary:Notify({
                Title = "配置警告",
                Text = string.format("当前等级(%s)已超过目标(%s)",
                    formatNumber(currentLevel),
                    formatNumber(config.targetLevel)),
                Duration = 6
            })
            return
        end

        config.enableTargetLevelKick = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = string.format("目标等级踢出: %s\n目标: %s", 
                (state and "开启" or "关闭"),
                config.targetLevel > 0 and formatNumber(config.targetLevel) or "未设置"),
            Duration = 5
        })
        saveConfig()
    end
})

targetLevelLabel = UILibrary:CreateLabel(targetLevelCard, {
    Text = "目标等级: " .. (config.targetLevel > 0 and formatNumber(config.targetLevel) or "未设置"),
})

UILibrary:CreateButton(targetLevelCard, {
    Text = "重新计算目标等级",
    Callback = function()
        if config.baseLevel <= 0 then
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请先设置基准等级",
                Duration = 5
            })
            return
        end
        
        local currentLevel = fetchCurrentLevel() or 0
        local newTarget = config.baseLevel + currentLevel
        
        if newTarget <= currentLevel then
            UILibrary:Notify({
                Title = "计算错误",
                Text = "目标等级不能小于等于当前等级",
                Duration = 6
            })
            return
        end
        
        config.targetLevel = newTarget
        config.lastSavedLevel = currentLevel
        
        if targetLevelLabel then
            targetLevelLabel.Text = "目标等级: " .. formatNumber(newTarget)
        end
        
        saveConfig()
        
        UILibrary:Notify({
            Title = "目标等级已重新计算",
            Text = string.format("基准: %s\n当前: %s\n新目标: %s\n\n后续只在等级减少时调整", 
                formatNumber(config.baseLevel),
                formatNumber(currentLevel),
                formatNumber(newTarget)),
            Duration = 8
        })
        
        if config.enableTargetLevelKick and currentLevel >= newTarget then
            suppressTargetLevelToggleCallback = true
            targetLevelToggle:Set(false)
            config.enableTargetLevelKick = false
            saveConfig()
            UILibrary:Notify({
                Title = "自动关闭",
                Text = "当前等级已达目标，踢出功能已关闭",
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
local lastWins = nil
local lastMiles = nil
local lastLevel = nil
local checkInterval = 1

spawn(function()
    while true do
        local currentTime = os.time()
        
        -- 获取所有数据
        local currentCurrency = fetchCurrentCurrency()
        local currentWins = fetchCurrentWins()
        local currentMiles = fetchCurrentMiles()
        local currentLevel = fetchCurrentLevel()

        -- 调整目标值（只在数值减少时）
        adjustTargetAmount()
        adjustTargetWins()
        adjustTargetMiles()
        adjustTargetLevel()

        -- 更新显示（所有数据）
        local earnedAmount = calculateEarnedAmount(currentCurrency)
        local earnedWins = currentWins and (config.totalWinsBase > 0 and (currentWins - config.totalWinsBase) or (currentWins - initialWins)) or 0
        local earnedMiles = currentMiles and (config.totalMilesBase > 0 and (currentMiles - config.totalMilesBase) or (currentMiles - initialMiles)) or 0
        local earnedLevel = currentLevel and (config.totalLevelBase > 0 and (currentLevel - config.totalLevelBase) or (currentLevel - initialLevel)) or 0
        
        earnedCurrencyLabel.Text = "已赚金额: " .. formatNumber(earnedAmount)
        earnedWinsLabel.Text = "胜利增加: " .. formatNumber(earnedWins)
        earnedMilesLabel.Text = "里程增加: " .. formatNumber(earnedMiles)
        earnedLevelLabel.Text = "等级增加: " .. formatNumber(earnedLevel)

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
                    Text = "已达目标金额，准备退出...",
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
        
        -- 目标胜利次数检测
        if config.enableTargetWinsKick and currentWins and config.targetWins > 0 then
            if currentWins >= config.targetWins then
                local payload = {
                    embeds = {{
                        title = "🏆 目标胜利次数达成",
                        description = string.format(
                            "**游戏**: %s\n**用户**: %s\n**当前胜利次数**: %s\n**目标胜利次数**: %s\n**基准胜利次数**: %s\n**运行时长**: %s",
                            gameName, username,
                            formatNumber(currentWins),
                            formatNumber(config.targetWins),
                            formatNumber(config.baseWins),
                            formatElapsedTime(currentTime - startTime)
                        ),
                        color = _G.PRIMARY_COLOR,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "作者: tongblx · Pluto-X" }
                    }}
                }

                UILibrary:Notify({
                    Title = "🏆 目标达成",
                    Text = "已达目标胜利次数，准备退出...",
                    Duration = 10
                })
                
                if config.webhookUrl ~= "" and not webhookDisabled then
                    dispatchWebhook(payload)
                end
                
                config.lastSavedWins = currentWins
                config.enableTargetWinsKick = false
                saveConfig()
                
                wait(3)
                pcall(function() game:Shutdown() end)
                pcall(function() player:Kick("目标胜利次数已达成") end)
                return
            end
        end
        
        -- 目标里程检测
        if config.enableTargetMilesKick and currentMiles and config.targetMiles > 0 then
            if currentMiles >= config.targetMiles then
                local payload = {
                    embeds = {{
                        title = "🚗 目标里程达成",
                        description = string.format(
                            "**游戏**: %s\n**用户**: %s\n**当前里程**: %s\n**目标里程**: %s\n**基准里程**: %s\n**运行时长**: %s",
                            gameName, username,
                            formatNumber(currentMiles),
                            formatNumber(config.targetMiles),
                            formatNumber(config.baseMiles),
                            formatElapsedTime(currentTime - startTime)
                        ),
                        color = _G.PRIMARY_COLOR,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "作者: tongblx · Pluto-X" }
                    }}
                }

                UILibrary:Notify({
                    Title = "🚗 目标达成",
                    Text = "已达目标里程，准备退出...",
                    Duration = 10
                })
                
                if config.webhookUrl ~= "" and not webhookDisabled then
                    dispatchWebhook(payload)
                end
                
                config.lastSavedMiles = currentMiles
                config.enableTargetMilesKick = false
                saveConfig()
                
                wait(3)
                pcall(function() game:Shutdown() end)
                pcall(function() player:Kick("目标里程已达成") end)
                return
            end
        end
        
        -- 目标等级检测
        if config.enableTargetLevelKick and currentLevel and config.targetLevel > 0 then
            if currentLevel >= config.targetLevel then
                local payload = {
                    embeds = {{
                        title = "⭐ 目标等级达成",
                        description = string.format(
                            "**游戏**: %s\n**用户**: %s\n**当前等级**: %s\n**目标等级**: %s\n**基准等级**: %s\n**运行时长**: %s",
                            gameName, username,
                            formatNumber(currentLevel),
                            formatNumber(config.targetLevel),
                            formatNumber(config.baseLevel),
                            formatElapsedTime(currentTime - startTime)
                        ),
                        color = _G.PRIMARY_COLOR,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "作者: tongblx · Pluto-X" }
                    }}
                }

                UILibrary:Notify({
                    Title = "⭐ 目标达成",
                    Text = "已达目标等级，准备退出...",
                    Duration = 10
                })
                
                if config.webhookUrl ~= "" and not webhookDisabled then
                    dispatchWebhook(payload)
                end
                
                config.lastSavedLevel = currentLevel
                config.enableTargetLevelKick = false
                saveConfig()
                
                wait(3)
                pcall(function() game:Shutdown() end)
                pcall(function() player:Kick("目标等级已达成") end)
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
                        "**游戏**: %s\n**用户**: %s\n**当前数据**:\nCash: %s | Wins: %s | Miles: %s | Level: %s\n\n检测到掉线",
                        gameName, username, 
                        formatNumber(currentCurrency or 0),
                        formatNumber(currentWins or 0),
                        formatNumber(currentMiles or 0),
                        formatNumber(currentLevel or 0)),
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
        if not webhookDisabled and (config.notifyCash or config.notifyWins or config.notifyMiles or config.notifyLevel)
           and interval >= getNotificationIntervalSeconds() then

            -- 计算所有变化
            local cashChange = calculateChangeAmount(currentCurrency)
            local winsChange = calculateWinsChange(currentWins)
            local milesChange = calculateMilesChange(currentMiles)
            local levelChange = calculateLevelChange(currentLevel)

            -- 检测是否有任何数据变化
            local hasChange = false
            if config.notifyCash and (currentCurrency ~= lastCurrency or cashChange ~= 0) then
                hasChange = true
            end
            if config.notifyWins and (currentWins ~= lastWins or winsChange ~= 0) then
                hasChange = true
            end
            if config.notifyMiles and (currentMiles ~= lastMiles or milesChange ~= 0) then
                hasChange = true
            end
            if config.notifyLevel and (currentLevel ~= lastLevel or levelChange ~= 0) then
                hasChange = true
            end

            if not hasChange then
                unchangedCount = unchangedCount + 1
            else
                unchangedCount = 0
            end

            if unchangedCount >= 2 then
                dispatchWebhook({
                    embeds = {{
                        title = "⚠️ 数据未变化",
                        description = string.format(
                            "**游戏**: %s\n**用户**: %s\n**当前数据**:\nCash: %s | Wins: %s | Miles: %s | Level: %s\n\n连续两次数据无变化",
                            gameName, username,
                            formatNumber(currentCurrency or 0),
                            formatNumber(currentWins or 0),
                            formatNumber(currentMiles or 0),
                            formatNumber(currentLevel or 0)),
                        color = 16753920,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        footer = { text = "作者: tongblx · Pluto-X" }
                    }}
                })

                webhookDisabled = true
                lastSendTime = currentTime
                lastCurrency = currentCurrency
                lastWins = currentWins
                lastMiles = currentMiles
                lastLevel = currentLevel
                updateLastNotifyData(currentCurrency, currentWins, currentMiles, currentLevel)
                updateLastSavedCurrency(currentCurrency)
                
                UILibrary:Notify({
                    Title = "连接异常",
                    Text = "数据长时间未变化",
                    Duration = 5
                })
            else
                local nextNotifyTimestamp = currentTime + getNotificationIntervalSeconds()
                local countdownR = string.format("<t:%d:R>", nextNotifyTimestamp)
                local countdownT = string.format("<t:%d:T>", nextNotifyTimestamp)

                local elapsedTime = currentTime - startTime
                
                -- 计算平均速度（使用本次变化）
                local avgCash = "0"
                if interval > 0 and config.notifyCash then
                    local rawAvg = cashChange / (interval / 3600)
                    avgCash = formatNumber(math.floor(rawAvg + 0.5))
                end

                -- 构建 embed fields
                local fields = {}
                
                -- Cash 通知
                if config.notifyCash and currentCurrency then
                    table.insert(fields, {
                        name = "💰 金额 (Cash)",
                        value = string.format(
                            "**当前**: %s\n**本次变化**: %s%s\n**总计收益**: %s%s\n**平均速度**: %s /小时",
                            formatNumber(currentCurrency),
                            (cashChange >= 0 and "+" or ""), formatNumber(cashChange),
                            (earnedAmount >= 0 and "+" or ""), formatNumber(earnedAmount),
                            avgCash
                        ),
                        inline = true
                    })
                end
                
                -- Wins 通知
                if config.notifyWins and currentWins then
                    table.insert(fields, {
                        name = "🏆 胜利 (Wins)",
                        value = string.format(
                            "**当前**: %s\n**本次变化**: %s%s\n**总计增加**: %s%s",
                            formatNumber(currentWins),
                            (winsChange >= 0 and "+" or ""), formatNumber(winsChange),
                            (earnedWins >= 0 and "+" or ""), formatNumber(earnedWins)
                        ),
                        inline = true
                    })
                end
                
                -- Miles 通知
                if config.notifyMiles and currentMiles then
                    table.insert(fields, {
                        name = "🚗 里程 (Miles)",
                        value = string.format(
                            "**当前**: %s\n**本次变化**: %s%s\n**总计增加**: %s%s",
                            formatNumber(currentMiles),
                            (milesChange >= 0 and "+" or ""), formatNumber(milesChange),
                            (earnedMiles >= 0 and "+" or ""), formatNumber(earnedMiles)
                        ),
                        inline = true
                    })
                end
                
                -- Level 通知
                if config.notifyLevel and currentLevel then
                    table.insert(fields, {
                        name = "⭐ 等级 (Level)",
                        value = string.format(
                            "**当前**: %s\n**本次变化**: %s%s\n**总计增加**: %s%s",
                            formatNumber(currentLevel),
                            (levelChange >= 0 and "+" or ""), formatNumber(levelChange),
                            (earnedLevel >= 0 and "+" or ""), formatNumber(earnedLevel)
                        ),
                        inline = true
                    })
                end
                
                -- 添加运行时间和下次通知
                table.insert(fields, {
                    name = "⏱️ 运行信息",
                    value = string.format(
                        "**用户**: %s\n**运行时长**: %s\n**下次通知**: %s（%s）",
                        username,
                        formatElapsedTime(elapsedTime),
                        countdownR, countdownT
                    ),
                    inline = false
                })

                local embed = {
                    title = "Pluto-X",
                    description = string.format("**游戏**: %s", gameName),
                    fields = fields,
                    color = _G.PRIMARY_COLOR,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "作者: tongblx · Pluto-X" }
                }

                dispatchWebhook({ embeds = { embed } })
                
                -- 无论成功与否都更新时间戳
                lastSendTime = currentTime
                lastCurrency = currentCurrency
                lastWins = currentWins
                lastMiles = currentMiles
                lastLevel = currentLevel
                updateLastNotifyData(currentCurrency, currentWins, currentMiles, currentLevel)
                updateLastSavedCurrency(currentCurrency)
                config.lastSavedWins = currentWins
                config.lastSavedMiles = currentMiles
                config.lastSavedLevel = currentLevel
                saveConfig()
                config.lastSavedWins = currentWins
                config.lastSavedMiles = currentMiles
                config.lastSavedLevel = currentLevel
                saveConfig()
                
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