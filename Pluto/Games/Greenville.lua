-- 反检测模块
for _, connection in pairs(getconnections(game.ChildAdded)) do
    if connection.Function and type(getfenv(connection.Function).script) ~= "table" then
        connection:Disable()
    end
end

local logScriptHandle = nil
for _, connection in pairs(getconnections(game:GetService("LogService").MessageOut)) do
    if connection.Function and not string.find(tostring(getupvalues(connection.Function)[1]), "Console") then
        logScriptHandle = getfenv(connection.Function).script
    end
end

local originalTaskWait = nil
originalTaskWait = hookfunction(task.wait, function(...)
    if not checkcaller() and getfenv(originalTaskWait).script == logScriptHandle then
        return coroutine.yield()
    else
        return originalTaskWait(...)
    end
end)

task.wait(1)
for _, gcObject in pairs(getgc(true)) do
    if type(gcObject) == "function" and getfenv(gcObject).script == logScriptHandle then
        for upvalueIndex, _ in pairs(getupvalues(gcObject)) do
            setupvalue(gcObject, upvalueIndex, nil)
        end
        task.wait()
    end
end

if getrawmetatable ~= nil then
    local gameMetatable = getrawmetatable(game)
    setreadonly(gameMetatable, false)
    local originalNamecall = gameMetatable.__namecall

    gameMetatable.__namecall = newcclosure(function(self, ...)
            return nil
        else
            return originalNamecall(self, ...)
        end
    end)
end

-- ============================================================================
-- 服务和变量声明
-- ============================================================================
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

-- ============================================================================
-- PlutoX 模块加载
-- ============================================================================
local success, PlutoX = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/develop/Pluto/Common/PlutoX-Notifier.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if not success or not PlutoX then
    error("[PlutoX] 模块加载失败！请检查网络连接或链接是否有效：" .. tostring(PlutoX))
end

-- ============================================================================
-- 玩家和游戏信息
-- ============================================================================
local player = Players.LocalPlayer
if not player then
    error("无法获取当前玩家")
end

local username = player.Name

local gameName = "Greenville"
do
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if success and info then
        gameName = info.Name
    end
end

-- 初始化调试系统（如果调试模式开启）
if DEBUG_MODE then
    PlutoX.setGameInfo(gameName, username)
    PlutoX.initDebugSystem()
    PlutoX.debug("调试系统已初始化")
end

-- ============================================================================
-- 注册数据类型
-- ============================================================================
PlutoX.registerDataType({
    id = "cash",
    name = "金额",
    icon = "💰",
    fetchFunc = function()
        local success, currencyObj = pcall(function()
            return player.PlayerGui:WaitForChild("UI", 5)
                :WaitForChild("Uni", 5)
                :WaitForChild("Hud", 5)
                :WaitForChild("Money", 5)
                :WaitForChild("Label", 5)
        end)
        if success and currencyObj then
            local currencyText = currencyObj.Text
            local cleanedText = currencyText:gsub(",", ""):match("[0-9%.]+")
            local currencyValue = tonumber(cleanedText)
            if currencyValue then
                return math.floor(currencyValue)
            end
        end
        return nil
    end,
    calculateAvg = true,
    supportTarget = true
})

-- ============================================================================
-- 初始化
-- ============================================================================
local configFile = "PlutoX/Greenville_config.json"

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
local dataMonitor = PlutoX.createDataMonitor(config, UILibrary, webhookManager, dataTypes)

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

-- 常规标签页
local generalTab, generalContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "常规",
    Active = true
})

local generalCard = UILibrary:CreateCard(generalContent, { IsMultiElement = true })
UILibrary:CreateLabel(generalCard, {
    Text = "游戏: " .. webhookManager.gameName,
})

local displayLabels = {}
local updateFunctions = {}

for _, dataType in ipairs(dataTypes) do
    local card, label, updateFunc = dataMonitor:createDisplayLabel(generalCard, dataType)
    displayLabels[dataType.id] = label
    updateFunctions[dataType.id] = updateFunc
end

-- 反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
UILibrary:CreateLabel(antiAfkCard, {
    Text = "安全起见,反挂机未启用",
})

-- 通知设置标签页
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "通知设置"
})

-- 使用通用模块创建 UI 组件
PlutoX.createWebhookCard(notifyContent, UILibrary, configManager.config, function() configManager:saveConfig() end, webhookManager)

-- 监测金额变化
local currencyNotifyCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(currencyNotifyCard, {
    Text = "监测金额变化",
    DefaultState = configManager.config.notifyCash,
    Callback = function(state)
        if state and configManager.config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            configManager.config.notifyCash = false
            return
        end
        configManager.config.notifyCash = state
        UILibrary:Notify({ Title = "配置更新", Text = "金额变化监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        configManager:saveConfig()
    end
})

PlutoX.createIntervalCard(notifyContent, UILibrary, configManager.config, function() configManager:saveConfig() end)

-- ============================================================================
-- 数据类型设置区域
-- ============================================================================
local targetValueLabels = {}

for _, dataType in ipairs(dataTypes) do
    local keyUpper = string.upper(dataType.id:sub(1, 1)) .. dataType.id:sub(2)

    -- 创建分隔标签
    local separatorCard = UILibrary:CreateCard(notifyContent)
    PlutoX.createDataTypeSectionLabel(separatorCard, UILibrary, dataType)

    local baseValueCard, baseValueInput, setTargetValueLabel, getTargetValueToggle, setLabelCallback = PlutoX.createBaseValueCard(
        notifyContent, UILibrary, configManager.config, function() configManager:saveConfig() end,
        function() return dataMonitor:fetchValue(dataType) end,
        keyUpper,
        dataType.icon
    )

    local targetValueCard, targetValueLabel, setTargetValueToggle2 = PlutoX.createTargetValueCardSimple(
        notifyContent, UILibrary, configManager.config, function() configManager:saveConfig() end,
        function() return dataMonitor:fetchValue(dataType) end,
        keyUpper
    )

    setTargetValueLabel(targetValueLabel)
    targetValueLabels[dataType.id] = targetValueLabel
end

-- 统一的重新计算所有目标值按钮
local recalculateCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateButton(recalculateCard, {
    Text = "重新计算所有目标值",
    Callback = function()
        PlutoX.recalculateAllTargetValues(
            configManager.config,
            UILibrary,
            dataMonitor,
            dataTypes,
            function() configManager:saveConfig() end,
            targetValueLabels
        )
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

-- 掉线检测
local disconnected = false
local NetworkClient = game:GetService("NetworkClient")
local GuiService = game:GetService("GuiService")

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

local disconnectDetector = PlutoX.createDisconnectDetector(UILibrary, webhookManager)
disconnectDetector:init()

-- 主循环
local startTime = os.time()
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
        local cashValue = dataMonitor:fetchValue(dataTypes[1])
        disconnectDetector:checkAndNotify(cashValue)

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
            return
        end

        wait(checkInterval)
    end
end)