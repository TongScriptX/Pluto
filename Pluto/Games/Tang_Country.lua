local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LogService = game:GetService("LogService")
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

-- 初始化调试系统（如果调试模式开启）
if DEBUG_MODE then
    PlutoX.setGameInfo(gameName, username)
    PlutoX.initDebugSystem()
    PlutoX.debug("调试系统已初始化")
end
do
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if success and info then
        gameName = info.Name
    end
end

-- 注册 Cash 数据类型
PlutoX.registerDataType({
    id = "cash",
    name = "金额",
    icon = "💰",
    fetchFunc = function()
        local success, currencyValue = pcall(function()
            return player:WaitForChild("Money", 5).Value
        end)
        if success and currencyValue then
            return math.floor(currencyValue)
        end
        return nil
    end,
    calculateAvg = true,
    supportTarget = true
})

-- 配置管理
local configFile = "PlutoX/Tang_Country_config.json"

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

-- Autofarm 模块
local TEAM_NAME = "Trucker"
local VEHICLE_MODEL_NAME = "2012 Shacman M3000 4X2"
local ROUTE_NAME = "routeA"
local OFFSET_DISTANCE = -20
local HEIGHT_OFFSET_START = 20
local HEIGHT_OFFSET_END = 0
local STEP_COUNT = 20
local STEP_DELAY = 0.1
local MAX_RETRY = 5

local route = Workspace:WaitForChild("TruckingJob"):WaitForChild("Coal"):WaitForChild(ROUTE_NAME)
local spawnedCars = Workspace:WaitForChild("SpawnedCars")

local TeamSwitchEvent = ReplicatedStorage:WaitForChild("Feature_RemoteEvent"):WaitForChild("TeamSwitch")
local ClientRequestCoalTrucks = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("RemoteFunctions"):WaitForChild("ClientRequestCoalTrucks")
local ClientRequestCoalJob = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("RemoteFunctions"):WaitForChild("ClientRequestCoalJob")
local ClientCoalRequester = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("RemoteFunctions"):WaitForChild("ClientCoalRequester")
local ClientRequestEndCoalJob = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("RemoteFunctions"):WaitForChild("ClientRequestEndCoalJob")

local depotPart = Workspace.TruckingJob:WaitForChild("Depot")
local pickupPart = route:WaitForChild("Pickup")
local dropoffPart = route:WaitForChild("Dropoff")

local function waitForCondition(conditionFunc, maxWait, interval)
    maxWait = maxWait or 10
    interval = interval or 0.1
    local waited = 0
    while waited < maxWait do
        local ok, result = pcall(conditionFunc)
        if ok and result then
            return true
        end
        task.wait(interval)
        waited = waited + interval
    end
    return false
end

local function getModelCenter(model)
    if not model then return nil end
    local parts = {}
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("BasePart") then
            table.insert(parts, c)
        end
    end
    if #parts == 0 then return nil end

    local minVec = parts[1].Position
    local maxVec = parts[1].Position
    for _, p in ipairs(parts) do
        local pos = p.Position
        minVec = Vector3.new(
            math.min(minVec.X, pos.X),
            math.min(minVec.Y, pos.Y),
            math.min(minVec.Z, pos.Z)
        )
        maxVec = Vector3.new(
            math.max(maxVec.X, pos.X),
            math.max(maxVec.Y, pos.Y),
            math.max(maxVec.Z, pos.Z)
        )
    end
    return (minVec + maxVec) / 2
end

local function getForwardVector(part)
    local size = part.Size
    local cframe = part.CFrame
    if size.X > size.Z then
        return cframe.RightVector
    else
        return cframe.LookVector
    end
end

local function smoothTeleportVehicle(vehicle, targetPos, forwardVector)
    for attempt = 1, MAX_RETRY do
        if not vehicle.PrimaryPart then
            vehicle.PrimaryPart = vehicle:FindFirstChildWhichIsA("BasePart") or vehicle:FindFirstChild("Body") or vehicle:FindFirstChild("Chassis")
            if not vehicle.PrimaryPart then
                warn("[Error] 车辆无有效主部件，无法传送")
                return false
            end
        end

        local originalPrimary = vehicle.PrimaryPart
        local vehicleCenter = getModelCenter(vehicle)
        if not vehicleCenter then
            warn("[Error] 车辆中心点获取失败，无法传送")
            return false
        end

        local offsetVector = originalPrimary.CFrame:PointToObjectSpace(vehicleCenter)
        local adjustedTargetPos = targetPos - forwardVector * offsetVector.Z
        local startHeight = adjustedTargetPos.Y + HEIGHT_OFFSET_START
        local endHeight = adjustedTargetPos.Y + HEIGHT_OFFSET_END
        local stepHeight = (startHeight - endHeight) / STEP_COUNT

        local yawAngle = math.atan2(forwardVector.Z, forwardVector.X)
        local rotationOnly = CFrame.Angles(0, -yawAngle + math.pi / 2, 0)

        local baseCFrame = CFrame.new(adjustedTargetPos.X, startHeight, adjustedTargetPos.Z) * rotationOnly
        vehicle:SetPrimaryPartCFrame(baseCFrame)

        for i = 1, STEP_COUNT do
            local currentCFrame = vehicle.PrimaryPart.CFrame
            local pos = currentCFrame.Position
            vehicle:SetPrimaryPartCFrame(CFrame.new(pos.X, pos.Y - stepHeight, pos.Z) * rotationOnly)
            task.wait(STEP_DELAY)
        end

        return true
    end
    warn("[Error] 多次尝试传送车辆失败")
    return false
end

local satInSeatFlag = false
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageOutput then
        if string.find(message, "//INSPARE: AC6 Loaded") then
            satInSeatFlag = true
        end
    end
end)

local function sitInDriveSeat(humanoid, seat)
    satInSeatFlag = false

    for attempt = 1, MAX_RETRY do
        humanoid.Sit = false
        task.wait(0.1)

        if not seat.Parent or not seat:IsDescendantOf(Workspace) then
            local ready = waitForCondition(function()
                return seat.Parent and seat:IsDescendantOf(Workspace)
            end, 5, 0.1)
            if not ready then
                warn("[Warn] 驾驶座未准备好，等待超时，重试中")
                task.wait(0.5)
                continue
            end
        end

        local cframeAbove = seat.CFrame * CFrame.new(0, 3, 0)
        local HumanoidRootPart = player.Character:WaitForChild("HumanoidRootPart")
        HumanoidRootPart.CFrame = cframeAbove
        task.wait(0.1)

        humanoid.Sit = true

        local satDown = waitForCondition(function()
            return humanoid.Sit == true or satInSeatFlag
        end, 5, 0.1)

        if satDown then
            print("[Info] 成功坐上驾驶座")
            return true
        else
            warn("[Warn] 坐上驾驶座尝试失败，重试中")
            task.wait(0.3)
        end
    end

    warn("[Error] 多次尝试坐上驾驶座失败")
    return false
end

local function invokeWithRetry(func, ...)
    for attempt = 1, MAX_RETRY do
        local success, result = pcall(func, ...)
        if success then
            return true, result
        else
            warn(string.format("[Warn] 第%d次调用失败，错误：%s", attempt, tostring(result)))
            task.wait(0.5)
        end
    end
    return false, nil
end

local function waitForVehicleSpawn(carName, timeout)
    timeout = timeout or 15
    local vehicle
    local found = false
    local startTime = tick()

    local conn
    local eventFired = Instance.new("BindableEvent")

    conn = spawnedCars.ChildAdded:Connect(function(child)
        if child.Name == carName then
            vehicle = child
            found = true
            eventFired:Fire()
        end
    end)

    if spawnedCars:FindFirstChild(carName) then
        vehicle = spawnedCars[carName]
        found = true
    end

    if not found then
        eventFired.Event:Wait()
    end

    conn:Disconnect()
    if found then return true, vehicle end

    while tick() - startTime < timeout do
        if spawnedCars:FindFirstChild(carName) then
            return true, spawnedCars[carName]
        end
        task.wait(0.3)
    end

    return false, nil
end

local function loadCoal(carName)
    for i = 1, MAX_RETRY do
        local success, err = pcall(function()
            ClientCoalRequester:InvokeServer("LoadCoal")
        end)
        if not success then
            warn("[Warn] 装煤请求失败，重试中:", err)
            task.wait(0.5)
            continue
        end

        local coalLoaded = waitForCondition(function()
            local vehicleCheck = spawnedCars:FindFirstChild(carName)
            if not vehicleCheck then return false end
            local coalPart = vehicleCheck:FindFirstChild("Misc")
                and vehicleCheck.Misc:FindFirstChild("Trailer")
                and vehicleCheck.Misc.Trailer:FindFirstChild("Body")
                and vehicleCheck.Misc.Trailer.Body:FindFirstChild("COAL")
            return coalPart ~= nil
        end, 10, 0.3)

        if coalLoaded then
            print("[Info] 装煤成功")
            return true
        else
            warn("[Warn] 未检测到煤炭，重试中")
        end
    end
    warn("[Error] 装煤多次失败")
    return false
end

local function unloadCoal()
    local success, err = pcall(function()
        ClientCoalRequester:InvokeServer("UnloadCoal")
    end)
    if not success then
        warn("[Warn] 卸煤请求失败:", err)
        return false
    end
    print("[Info] 卸煤请求已发送，无需等待完成")
    return true
end

local autofarmEnabled = false
local autofarmTask

local function autofarmLoop()
    while autofarmEnabled do
        local success = pcall(function()
            TeamSwitchEvent:FireServer(TEAM_NAME)
            local switched = waitForCondition(function()
                return player.Team and player.Team.Name == TEAM_NAME
            end, 10, 0.2)
            if not switched then
                warn("[Error] 切换团队超时")
                return false
            end

            local character = player.Character or player.CharacterAdded:Wait()
            local HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
            HumanoidRootPart.CFrame = depotPart.CFrame + Vector3.new(0, 5, 0)
            task.wait(0.3)

            local success, ret = invokeWithRetry(function()
                return ClientRequestCoalTrucks:InvokeServer()
            end)
            if not success then
                warn("[Error] 接任务失败")
                return false
            end

            local success2, vehicle = invokeWithRetry(function()
                return ClientRequestCoalJob:InvokeServer(route, VEHICLE_MODEL_NAME)
            end)
            if not success2 or not vehicle then
                warn("[Error] 生成车辆失败")
                return false
            end

            local carName = player.Name .. "'s Car"
            local vehicleAppeared, spawnedVehicle = waitForVehicleSpawn(carName, 15)
            if not vehicleAppeared then
                warn("[Error] 等待车辆生成超时")
                return false
            end
            vehicle = spawnedVehicle

            local driveSeat
            local driveSeatReady = waitForCondition(function()
                driveSeat = vehicle:FindFirstChild("DriveSeat")
                return driveSeat ~= nil
            end, 10, 0.2)
            if not driveSeatReady then
                warn("[Error] 未找到驾驶座")
                return false
            end

            local humanoid = character:WaitForChild("Humanoid")
            if not sitInDriveSeat(humanoid, driveSeat) then
                return false
            end

            local pickupForward = getForwardVector(pickupPart)
            local pickupPos = pickupPart.Position
            local offsetTargetPos = pickupPos + pickupForward * OFFSET_DISTANCE
            if not smoothTeleportVehicle(vehicle, offsetTargetPos, pickupForward) then
                warn("[Error] 传送车辆到装煤点失败")
                return false
            end

            if not loadCoal(carName) then
                return false
            end

            local dropoffForward = getForwardVector(dropoffPart)
            local dropoffPos = dropoffPart.Position
            local offsetDropoffPos = dropoffPos + dropoffForward * OFFSET_DISTANCE

            if not smoothTeleportVehicle(vehicle, offsetDropoffPos, dropoffForward) then
                warn("[Error] 传送车辆到卸煤点失败")
                return false
            end

            unloadCoal()

            TeamSwitchEvent:FireServer("Civilian")
            local backSwitched = waitForCondition(function()
                return player.Team and player.Team.Name == "Civilian"
            end, 10, 0.2)
            if not backSwitched then
                warn("[Error] 切换回 Civilian 超时")
                return false
            end

            print("[Info] 本轮任务完成，已切回 Civilian。")
            return true
        end)
        
        if not success then
            warn("[Warn] 本轮任务失败，5 秒后重试")
            task.wait(5)
        else
            print("[Info] 等待 3 秒开始下一轮任务")
            task.wait(3)
        end
    end
    print("[Info] Autofarm 已停止")
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

-- 标签页：主要功能
local mainFeaturesTab, mainFeaturesContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "主要功能",
})

-- 卡片：Autofarm
local autoFarmCard = UILibrary:CreateCard(mainFeaturesContent)

local autofarmToggle = UILibrary:CreateToggle(autoFarmCard, {
    Text = "Autofarm",
    DefaultState = false,
    Callback = function(state)
        autofarmEnabled = state
        UILibrary:Notify({Title = "Autofarm", Text = "Autofarm: " .. (state and "开启" or "关闭"), Duration = 5})

        if autofarmEnabled then
            if not autofarmTask or autofarmTask.Status ~= Enum.ThreadStatus.Running then
                autofarmTask = task.spawn(autofarmLoop)
            end
        end
    end
})

-- 标签页：通知设置
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "通知设置"
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
        
        -- 创建分隔标签
        local separatorCard = UILibrary:CreateCard(notifyContent)
        PlutoX.createDataTypeSectionLabel(separatorCard, UILibrary, dataType)
        
        local baseValueCard, baseValueInput, setTargetValueLabel, getTargetValueToggle, setLabelCallback = PlutoX.createBaseValueCard(
            notifyContent, UILibrary, config, function() configManager:saveConfig() end, 
            function() return dataMonitor:fetchValue(dataType) end,
            keyUpper,  -- 传递数据类型的 keyUpper
            dataType.icon  -- 传递图标
        )
        
        local targetValueCard, targetValueLabel, setTargetValueToggle2 = PlutoX.createTargetValueCardSimple(
            notifyContent, UILibrary, config, function() configManager:saveConfig() end,
            function() return dataMonitor:fetchValue(dataType) end,
            keyUpper  -- 传递数据类型的 keyUpper
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
    Text = "关于"
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