local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- 加载通用金额通知模块
local PlutoX
local success, result = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/develop/Pluto/Common/PlutoX-Notifier.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if success and result then
    PlutoX = result
else
    error("[PlutoX] 加载失败！请检查网络连接或链接是否有效：" .. tostring(result))
end

-- 获取当前玩家和游戏信息
local player = Players.LocalPlayer
if not player then
    error("无法获取当前玩家")
end
local userId = player.UserId
local username = player.Name

local gameName = "未知游戏"
do
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if success and info then
        gameName = info.Name
    end
end

_G.PRIMARY_COLOR = 5793266

-- 配置管理
local configFile = "Pluto_X_RT2_config.json"
local defaultConfig = {
    webhookUrl = "",
    notifyCash = false,
    notificationInterval = 30,
    targetAmount = 0,
    enableTargetKick = false,
    lastSavedCurrency = 0,
    baseAmount = 0,
    totalEarningsBase = 0,
    lastNotifyCurrency = 0,
    autoCollectEnabled = false,
}

local configManager = PlutoX.createConfigManager(configFile, HttpService, UILibrary, username, defaultConfig)
local config = configManager:loadConfig()

-- Webhook 管理
local webhookManager = PlutoX.createWebhookManager(config, HttpService, UILibrary, gameName, username)

-- 金额通知管理器
local currencyNotifier = PlutoX.createCurrencyNotifier(config, UILibrary, gameName, username)

-- 掉线检测
local disconnectDetector = PlutoX.createDisconnectDetector(UILibrary, webhookManager)
disconnectDetector:init()

-- 反挂机
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- 游戏特定功能：获取当前金额
local function fetchCurrentCurrency()
    local success, result = pcall(function()
        return player.leaderstats.Cash.Value
    end)
    if success and result then
        return math.floor(result)
    end
    UILibrary:Notify({ Title = "错误", Text = "无法找到金额数据", Duration = 5 })
    return nil
end

-- 初始化
pcall(function()
    currencyNotifier:initTargetAmount(fetchCurrentCurrency, function() configManager:saveConfig() end)
end)

pcall(function()
    currencyNotifier:initCurrency(fetchCurrentCurrency)
end)

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    spawn(function()
        wait(2)
        webhookManager:sendWelcomeMessage()
    end)
end

-- 自动收钱逻辑
local ClientTycoonInput = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ClientTycoonInput")

-- 查找玩家的 Tycoon
local function findPlayerTycoon()
    for _, t in pairs(workspace:WaitForChild("Tycoons"):GetChildren()) do
        if t:FindFirstChild("Player") and t.Player.Value == player then
            return t
        end
    end
    return nil
end

-- 自动收钱协程管理
local autoCollectCoroutine = nil

-- 封装自动收钱函数
local function autoCollectFunction()
    while true do
        if not config.autoCollectEnabled then
            wait(1)
            autoCollectCoroutine = nil
            return
        end

        local tycoon = findPlayerTycoon()
        if not tycoon then
            UILibrary:Notify({
                Title = "自动收钱错误",
                Text = "未找到你的 Tycoon",
                Duration = 5
            })
            warn("未找到你的 Tycoon")
            config.autoCollectEnabled = false
            configManager:saveConfig()
            wait(5)
            autoCollectCoroutine = nil
            return
        end

        local surface = tycoon:WaitForChild("Items"):WaitForChild("OftenFiltered"):WaitForChild("Surface")
        for _, item in pairs(surface:GetChildren()) do
            if item:FindFirstChild("Bill") then
                local args = {
                    tycoon,
                    {
                        name = "CollectBill",
                        model = item
                    }
                }
                ClientTycoonInput:FireServer(unpack(args))
                wait(0.1)
            end
        end
        wait(1)
    end
end

-- 启动自动收钱（如果配置已启用）
if config.autoCollectEnabled then
    autoCollectCoroutine = coroutine.wrap(autoCollectFunction)()
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
    Active = true
})

-- 卡片：常规信息
local generalCard = UILibrary:CreateCard(generalContent, { IsMultiElement = true })
UILibrary:CreateLabel(generalCard, {
    Text = "游戏: " .. gameName,
})
local earnedCurrencyLabel = UILibrary:CreateLabel(generalCard, {
    Text = "已赚金额: 0",
})

-- 卡片：反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
UILibrary:CreateLabel(antiAfkCard, {
    Text = "反挂机已启用",
})

-- 标签页：主要功能
local mainFuncTab, mainFuncContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "主要功能",
})

-- 卡片：自动收钱
local autoCollectCard = UILibrary:CreateCard(mainFuncContent)
local autoCollectToggle = UILibrary:CreateToggle(autoCollectCard, {
    Text = "自动收钱",
    DefaultState = config.autoCollectEnabled,
    Callback = function(state)
        config.autoCollectEnabled = state
        if state then
            if not autoCollectCoroutine then
                autoCollectCoroutine = coroutine.wrap(autoCollectFunction)()
            end
            UILibrary:Notify({
                Title = "配置更新",
                Text = "自动收钱已开启",
                Duration = 5
            })
        else
            autoCollectCoroutine = nil
            UILibrary:Notify({
                Title = "配置更新",
                Text = "自动收钱已关闭",
                Duration = 5
            })
        end
        configManager:saveConfig()
    end
})

-- 标签页：通知设置
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "通知设置"
})

-- 使用通用模块创建 UI 组件
PlutoX.createWebhookCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end, webhookManager)
PlutoX.createCurrencyNotifyCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end)
PlutoX.createIntervalCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end)

local baseAmountCard, baseAmountInput, setTargetAmountLabel, getTargetAmountToggle, setLabelCallback = PlutoX.createBaseAmountCard(
    notifyContent, UILibrary, config, function() configManager:saveConfig() end, fetchCurrentCurrency
)

local targetAmountCard, targetAmountLabel, setTargetAmountToggle2, connectLabelCallback = PlutoX.createTargetAmountCard(
    notifyContent, UILibrary, config, function() configManager:saveConfig() end, fetchCurrentCurrency
)

-- 连接两个组件的回调
setTargetAmountLabel(targetAmountLabel)
setTargetAmountToggle2(getTargetAmountToggle())
-- 立即连接标签，确保设置基准金额时可以更新目标金额显示
if connectLabelCallback then
    connectLabelCallback(setLabelCallback)
end

-- 标签页：关于
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于"
})

PlutoX.createAboutPage(aboutContent, UILibrary)

-- 主循环
local checkInterval = 1

while true do
    local currentCurrency = fetchCurrentCurrency()

    -- 更新已赚金额显示
    local earnedAmount = currencyNotifier:calculateEarned(currentCurrency)
    earnedCurrencyLabel.Text = "已赚金额: " .. PlutoX.formatNumber(earnedAmount)

    -- 检测目标金额
    if currencyNotifier:checkTargetAmount(fetchCurrentCurrency, webhookManager, function() configManager:saveConfig() end) then
        wait(3)
        pcall(function() game:Shutdown() end)
        pcall(function() player:Kick("目标金额已达成，游戏自动退出") end)
        return
    end

    -- 检测掉线
    disconnectDetector:checkAndNotify(currentCurrency)

    -- 检测金额变化
    currencyNotifier:checkCurrencyChange(fetchCurrentCurrency, webhookManager, function() configManager:saveConfig() end)

    wait(checkInterval)
end