-- ============================================================================
-- Autopilot Simulator 脚本
-- ============================================================================
-- 作者: tongblx
-- 描述: Autopilot Simulator 游戏脚本，包含 autofarm 和金额通知功能
-- ============================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")

-- ============================================================================
-- 加载 UI 模块
-- ============================================================================
local UILibrary
local success, result = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if success and result then
    PlutoX = result
else
    error("[PlutoX] 加载失败！请检查网络连接或链接是否有效：" .. tostring(result))
end

-- ============================================================================
-- 加载通用金额通知模块
-- ============================================================================
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

-- ============================================================================
-- 获取当前玩家和游戏信息
-- ============================================================================
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

-- ============================================================================
-- 配置管理
-- ============================================================================
local configFile = "Pluto_X_APS_config.json"
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
}

local configManager = PlutoX.createConfigManager(configFile, HttpService, UILibrary, username, defaultConfig)
local config = configManager:loadConfig()

-- ============================================================================
-- Webhook 管理
-- ============================================================================
local webhookManager = PlutoX.createWebhookManager(config, HttpService, UILibrary, gameName, username)

-- ============================================================================
-- 金额通知管理器
-- ============================================================================
local currencyNotifier = PlutoX.createCurrencyNotifier(config, UILibrary, gameName, username)

-- ============================================================================
-- 掉线检测
-- ============================================================================
local disconnectDetector = PlutoX.createDisconnectDetector(UILibrary, webhookManager)
disconnectDetector:init()

-- ============================================================================
-- 反挂机
-- ============================================================================
PlutoX.setupAntiAfk(player, UILibrary)

-- ============================================================================
-- 游戏特定功能：获取当前金额
-- ============================================================================
local function fetchCurrentCurrency()
    local success, cashValue = pcall(function()
        local leaderstats = player:WaitForChild("leaderstats", 5)
        if leaderstats then
            local cash = leaderstats:WaitForChild("Cash", 5)
            if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
                return cash.Value
            end
        end
        return nil
    end)
    if success and cashValue then
        return math.floor(cashValue)
    else
        UILibrary:Notify({ Title = "错误", Text = "无法找到金额数据", Duration = 5 })
        return nil
    end
end

-- ============================================================================
-- 初始化
-- ============================================================================
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

-- ============================================================================
-- autofarm 模块
-- ============================================================================
local isFarming = false
local platformFolder = nil
local farmTask = nil

local function stopAutoFarm()
    isFarming = false
    if farmTask then
        task.cancel(farmTask)
        farmTask = nil
    end
    if platformFolder then
        platformFolder:Destroy()
        platformFolder = nil
    end
end

local function startAutoFarm()
    local plr = game:GetService("Players").LocalPlayer
    if not plr then
        warn("[autofarm] LocalPlayer 不存在")
        return
    end
    local username = plr.Name

    local success, carModel = pcall(function()
        return workspace:WaitForChild("Car", 5):WaitForChild(username .. "sCar", 5)
    end)
    if not success or not carModel then
        warn("[autofarm] 未找到玩家车辆:", username .. "sCar")
        UILibrary:Notify({Title="autofarm错误", Text="未找到玩家车辆", Duration=5})
        stopAutoFarm()
        return
    end

    local driveSeat = carModel:FindFirstChild("DriveSeat")
    if not driveSeat then
        warn("[autofarm] 未找到 DriveSeat")
        UILibrary:Notify({Title="autofarm错误", Text="未找到驾驶座位", Duration=5})
        stopAutoFarm()
        return
    end

    local body = carModel:FindFirstChild("Body")
    if not body then
        warn("[autofarm] 未找到 Body")
        UILibrary:Notify({Title="autofarm错误", Text="未找到 Body", Duration=5})
        stopAutoFarm()
        return
    end

    local primaryPart = body:FindFirstChild("#Weight")
    if not primaryPart then
        warn("[autofarm] 未找到 PrimaryPart (#Weight)")
        UILibrary:Notify({Title="autofarm错误", Text="未找到 PrimaryPart (#Weight)", Duration=5})
        stopAutoFarm()
        return
    end
    carModel.PrimaryPart = primaryPart

    platformFolder = Instance.new("Folder", workspace)
    platformFolder.Name = "AutoPlatform"

    local platform = Instance.new("Part", platformFolder)
    platform.Anchored = true
    platform.Size = Vector3.new(100000, 10, 10000)
    platform.BrickColor = BrickColor.new("Dark stone grey")
    platform.Material = Enum.Material.SmoothPlastic
    platform.Position = Vector3.new(
        primaryPart.Position.X + 50000,
        primaryPart.Position.Y + 5,
        primaryPart.Position.Z
    )

    local originPos = Vector3.new(
        primaryPart.Position.X,
        platform.Position.Y + 5000,
        primaryPart.Position.Z
    )
    local speed = 600
    local interval = 0.05
    local distancePerTick = speed * interval
    local currentPosX = originPos.X
    local lastTpTime = tick()

    carModel:PivotTo(CFrame.new(originPos, originPos + Vector3.new(1, 0, 0)))

    isFarming = true
    farmTask = task.spawn(function()
        while isFarming do
            currentPosX = currentPosX + distancePerTick
            local pos = Vector3.new(currentPosX, originPos.Y, originPos.Z)
            carModel:PivotTo(CFrame.new(pos, pos + Vector3.new(1, 0, 0)))

            if carModel.PrimaryPart then
                carModel.PrimaryPart.Velocity = Vector3.zero
                carModel.PrimaryPart.RotVelocity = Vector3.zero
            end

            if tick() - lastTpTime > 5 then
                currentPosX = originPos.X
                carModel:PivotTo(CFrame.new(Vector3.new(currentPosX, originPos.Y, originPos.Z), Vector3.new(currentPosX + 1, originPos.Y, originPos.Z)))
                lastTpTime = tick()
            end

            task.wait(interval)
        end
        if platformFolder then
            platformFolder:Destroy()
            platformFolder = nil
        end
    end)
end

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
local mainFeaturesTab, mainFeaturesContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "主要功能",
})

-- 卡片：autofarm
local autoFarmCard = UILibrary:CreateCard(mainFeaturesContent)

local autoFarmToggle = UILibrary:CreateToggle(autoFarmCard, {
    Text = "autofarm",
    DefaultState = false,
    Callback = function(state)
        if state then
            UILibrary:Notify({Title = "autofarm", Text = "autofarm已启动", Duration = 5})
            startAutoFarm()
        else
            UILibrary:Notify({Title = "autofarm", Text = "autofarm已停止", Duration = 5})
            stopAutoFarm()
        end
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

local baseAmountCard, baseAmountInput, setTargetAmountLabel, getTargetAmountToggle = PlutoX.createBaseAmountCard(
    notifyContent, UILibrary, config, function() configManager:saveConfig() end, fetchCurrentCurrency
)

local targetAmountCard, targetAmountLabel, setTargetAmountToggle2 = PlutoX.createTargetAmountCard(
    notifyContent, UILibrary, config, function() configManager:saveConfig() end, fetchCurrentCurrency
)

-- 连接两个组件的回调
setTargetAmountLabel(targetAmountLabel)
setTargetAmountToggle2(getTargetAmountToggle())

-- 标签页：关于
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于"
})

PlutoX.createAboutPage(aboutContent, UILibrary)

-- ============================================================================
-- 主循环
-- ============================================================================
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