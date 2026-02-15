local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")

_G.PRIMARY_COLOR = 5793266

-- UI 库加载

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

-- PlutoX 模块加载

local PlutoX
local success, result = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/develop/Pluto/Common/PlutoX-Notifier.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if success and result then
    PlutoX = result

-- 启用调试模式（默认关闭，可在代码中设置 DEBUG_MODE = true 启用）
local DEBUG_MODE = false
PlutoX.debugEnabled = DEBUG_MODE
else
    error("[PlutoX] 加载失败！请检查网络连接或链接是否有效：" .. tostring(result))
end

-- 玩家和游戏信息

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

-- 初始化调试系统（如果调试模式开启）
PlutoX.setGameInfo(gameName, username, HttpService)

-- 初始化调试系统（如果调试模式开启）
if DEBUG_MODE then
    PlutoX.initDebugSystem()
    PlutoX.debug("调试系统已初始化")
end

-- 注册数据类型

-- 注册 Cash 数据类型
PlutoX.registerDataType({
    id = "cash",
    name = "金额",
    icon = "💰",
    fetchFunc = function()
        local leaderstats = player:WaitForChild("leaderstats", 5)
        if leaderstats then
            local currency = leaderstats:FindFirstChild("Cash")
            if currency then
                return currency.Value
            end
        end
        return nil
    end,
    calculateAvg = true,  -- 计算平均速度
    supportTarget = true  -- 支持目标检测
})

-- 配置管理

local configFile = "PlutoX/Midnight_Chasers_config.json"

-- 获取所有注册的数据类型
local dataTypes = PlutoX.getAllDataTypes()

-- 生成默认配置（自动包含所有注册的数据类型）
local dataTypeConfigs = PlutoX.generateDataTypeConfigs(dataTypes)

local defaultConfig = {
    webhookUrl = "",
    notificationInterval = 30,
}

-- 合并数据类型配置
for key, value in pairs(dataTypeConfigs) do
    defaultConfig[key] = value
end

local configManager = PlutoX.createConfigManager(configFile, HttpService, UILibrary, username, defaultConfig)
local config = configManager:loadConfig()

-- Webhook 管理

local webhookManager = PlutoX.createWebhookManager(config, HttpService, UILibrary, gameName, username)

-- 数据监测管理器

local dataMonitor = PlutoX.createDataMonitor(config, UILibrary, webhookManager, dataTypes, nil, gameName, username)

-- 掉线检测

local disconnectDetector = PlutoX.createDisconnectDetector(UILibrary, webhookManager)
disconnectDetector:init()

-- 反挂机

player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- 初始化

dataMonitor:init()

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    spawn(function()
        wait(2)
        webhookManager:sendWelcomeMessage()
    end)
end

-- UI 创建

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

-- 标签页：常规
local generalTab, generalContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "常规",
    Icon = "home",
    Active = true
})

-- 卡片：常规信息（动态生成所有数据类型的显示）
local generalCard = UILibrary:CreateCard(generalContent, { IsMultiElement = true })
UILibrary:CreateLabel(generalCard, {
    Text = "游戏: " .. gameName,
})

local displayLabels = {}
local updateFunctions = {}

for _, dataType in ipairs(dataTypes) do
    local card, label, updateFunc = dataMonitor:createDisplayLabel(generalCard, dataType)
    displayLabels[dataType.id] = label
    updateFunctions[dataType.id] = updateFunc
end

-- 卡片：反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
UILibrary:CreateLabel(antiAfkCard, {
    Text = "反挂机已启用",
})

-- 标签页：通知设置
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "通知",
    Icon = "bell"
})

-- 使用通用模块创建 UI 组件
PlutoX.createWebhookCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end, webhookManager)

-- 动态生成所有数据类型的开关
for _, dataType in ipairs(dataTypes) do
    local keyUpper = dataType.id:gsub("^%l", string.upper)
    local card = UILibrary:CreateCard(notifyContent)
    
    UILibrary:CreateToggle(card, {
        Text = string.format("监测%s (%s)", dataType.name, dataType.icon),
        DefaultState = config["notify" .. keyUpper] or false,
        Callback = function(state)
            if state and config.webhookUrl == "" then
                UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
                config["notify" .. keyUpper] = false
                return
            end
            config["notify" .. keyUpper] = state
            UILibrary:Notify({ 
                Title = "配置更新", 
                Text = string.format("%s监测: %s", dataType.name, state and "开启" or "关闭"), 
                Duration = 5 
            })
            configManager:saveConfig()
        end
    })
end

PlutoX.createIntervalCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end)

-- 目标值功能（为每个支持目标的数据类型创建独立的目标设置）
local targetValueLabels = {}  -- 保存所有目标值标签引用

for _, dataType in ipairs(dataTypes) do
    if dataType.supportTarget then
        local keyUpper = dataType.id:gsub("^%l", string.upper)
        
        -- 创建分隔标签（使用模块函数，自动添加图标）
        PlutoX.createDataTypeSectionLabel(notifyContent, UILibrary, dataType)
        
        local baseValueCard, baseValueInput, setTargetValueLabel, getTargetValueToggle, setLabelCallback = PlutoX.createBaseValueCard(
            notifyContent, UILibrary, config, function() configManager:saveConfig() end, 
            function() return dataMonitor:fetchValue(dataType) end,
            keyUpper,
            dataType.icon  -- 传递图标
        )
        
        local targetValueCard, targetValueLabel, setTargetValueToggle2 = PlutoX.createTargetValueCardSimple(
            notifyContent, UILibrary, config, function() configManager:saveConfig() end,
            function() return dataMonitor:fetchValue(dataType) end,
            keyUpper
        )
        
        setTargetValueLabel(targetValueLabel)
        targetValueLabels[dataType.id] = targetValueLabel  -- 保存标签引用
    end
end

-- 统一的重新计算所有目标值按钮
local recalculateCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateButton(recalculateCard, {
    Text = "重新计算所有目标值",
    Callback = function()
        PlutoX.recalculateAllTargetValues(
            config,
            UILibrary,
            dataMonitor,
            dataTypes,
            function() configManager:saveConfig() end,
            targetValueLabels
        )
    end
})

-- 标签页：关于
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于",
    Icon = "info"
})

PlutoX.createAboutPage(aboutContent, UILibrary)

-- 主循环

local checkInterval = 1

spawn(function()
    while true do
        -- 更新所有数据类型的显示
        for id, updateFunc in pairs(updateFunctions) do
            pcall(updateFunc)
        end
        
        -- 检查并发送通知
        dataMonitor:checkAndNotify(function() configManager:saveConfig() end)
        
        -- 掉线检测
        local cashType = dataTypes[1]  -- 假设第一个数据类型是 Cash
        if cashType then
            local currentCash = dataMonitor:fetchValue(cashType)
            disconnectDetector:checkAndNotify(currentCash)
        end
        
        -- 目标值调整（为每个支持目标的数据类型独立调整）
        for _, dataType in ipairs(dataTypes) do
            if dataType.supportTarget then
                local keyUpper = dataType.id:gsub("^%l", string.upper)
                if config["base" .. keyUpper] > 0 and config["target" .. keyUpper] > 0 then
                    pcall(function() dataMonitor:adjustTargetValue(function() configManager:saveConfig() end, dataType.id) end)
                end
            end
        end
        
        -- 目标值达成检测（检查所有数据类型的目标）
        local achieved = dataMonitor:checkTargetAchieved(function() configManager:saveConfig() end)
        if achieved then
            webhookManager:sendTargetAchieved(
                achieved.value,
                achieved.targetValue,
                achieved.baseValue,
                os.time() - dataMonitor.startTime,
                achieved.dataType.name
            )
            
            UILibrary:Notify({
                Title = "🎯 目标达成",
                Text = string.format("%s目标已达成，准备退出...", achieved.dataType.name),
                Duration = 10
            })
            
            local keyUpper = achieved.dataType.id:gsub("^%l", string.upper)
            config["lastSaved" .. keyUpper] = achieved.value
            config["enable" .. keyUpper .. "Kick"] = false
            configManager:saveConfig()
            
            wait(3)
            pcall(function() game:Shutdown() end)
            pcall(function() player:Kick(string.format("%s目标值已达成", achieved.dataType.name)) end)
            return
        end
        
        wait(checkInterval)
    end
end)