local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local lastWebhookUrl = ""
local lastSendTime = os.time()  -- 初始化为当前时间
local lastCurrency = 0  -- 初始化为初始金额

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
local configFile = "Pluto_X_TC_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notificationInterval = 30,
    welcomeSent = false,
    targetCurrency = 0,
    enableTargetKick = false,
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
local player = game:GetService("Players").LocalPlayer

local function fetchCurrentCurrency()
    local success, currencyValue = pcall(function()
        return player:WaitForChild("Money", 5).Value
    end)
    if success and currencyValue then
        return math.floor(currencyValue)
    end
    UILibrary:Notify({ Title = "错误", Text = "无法获取金额（Money）", Duration = 5 })
    return nil
end

local success, currencyValue = pcall(fetchCurrentCurrency)
if success and currencyValue then
    initialCurrency = currencyValue
    lastCurrency = currencyValue
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

--[[    print("[Webhook] 正在发送 Webhook 到:", config.webhookUrl)
    print("[Webhook] Payload 内容:", HttpService:JSONEncode(data))
    ]]

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
            description = "**游戏**: " .. gameName .. "\n**用户**: " .. username,
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

-- 初始化时校验目标金额
local function initTargetCurrency()
    local current = fetchCurrentCurrency() or 0
    if config.enableTargetKick and config.targetCurrency > 0 and current >= config.targetCurrency then
        UILibrary:Notify({
            Title = "目标金额已达成",
            Text = "当前金额已超过目标，已关闭踢出功能，未执行退出",
            Duration = 5
        })
        config.enableTargetKick = false
        config.targetCurrency = 0
        saveConfig()
    end
end
pcall(initTargetCurrency)

-- Autofarm
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LogService = game:GetService("LogService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local humanoid = Character:WaitForChild("Humanoid")

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

local function main()
    TeamSwitchEvent:FireServer(TEAM_NAME)
    local switched = waitForCondition(function()
        return LocalPlayer.Team and LocalPlayer.Team.Name == TEAM_NAME
    end, 10, 0.2)
    if not switched then
        warn("[Error] 切换团队超时")
        return false
    end

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

    local carName = LocalPlayer.Name .. "'s Car"
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
        return LocalPlayer.Team and LocalPlayer.Team.Name == "Civilian"
    end, 10, 0.2)
    if not backSwitched then
        warn("[Error] 切换回 Civilian 超时")
        return false
    end

    print("[Info] 本轮任务完成，已切回 Civilian。")
    return true
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

-- 标签页：Autofarm
local autofarmTab, autofarmContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "Autofarm"
})

-- 卡片：Autofarm 设置
local autofarmCard = UILibrary:CreateCard(autofarmContent)

local autofarmEnabled = false
local autofarmTask

local function autofarmLoop()
    while autofarmEnabled do
        local success = main()
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

local autofarmToggle = UILibrary:CreateToggle(autofarmCard, {
    Text = "Autofarm",
    DefaultState = false,
    Callback = function(state)
        autofarmEnabled = state
        UILibrary:Notify({ Title = "Autofarm", Text = "Autofarm: " .. (state and "开启" or "关闭"), Duration = 5 })

        if autofarmEnabled then
            if not autofarmTask or autofarmTask.Status ~= Enum.ThreadStatus.Running then
                autofarmTask = task.spawn(autofarmLoop)
            end
        end
    end
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

-- 卡片：目标金额
local targetCurrencyCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

-- 避免程序性开启触发回调误判
local suppressTargetToggleCallback = false

-- 切换开关（统一用 enableTargetKick）
local targetCurrencyToggle = UILibrary:CreateToggle(targetCurrencyCard, {
    Text = "目标金额踢出",
    DefaultState = config.enableTargetKick or false,
    Callback = function(state)
        print("[目标踢出] 状态改变:", state)

        if suppressTargetToggleCallback then
            suppressTargetToggleCallback = false
            return
        end

        if state and config.webhookUrl == "" then
            targetCurrencyToggle:Set(false)
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            return
        end

        if state and (not config.targetCurrency or config.targetCurrency <= 0) then
            targetCurrencyToggle:Set(false)
            UILibrary:Notify({ Title = "配置错误", Text = "请设置有效目标金额（大于0）", Duration = 5 })
            return
        end

        local currentCurrency = fetchCurrentCurrency()
        if state and currentCurrency and currentCurrency >= config.targetCurrency then
            targetCurrencyToggle:Set(false)
            UILibrary:Notify({
                Title = "配置警告",
                Text = string.format("当前金额(%s)已超过目标金额(%s)，请调整后再开启",
                    formatNumber(currentCurrency),
                    formatNumber(config.targetCurrency)
                ),
                Duration = 6
            })
            return
        end

        config.enableTargetKick = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = "目标金额踢出: " .. (state and "开启" or "关闭"),
            Duration = 5
        })
        saveConfig()
    end
})

UILibrary:CreateLabel(targetCurrencyCard, {
    Text = "目标金额",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 30)
})

local targetCurrencyInput = UILibrary:CreateTextBox(targetCurrencyCard, {
    PlaceholderText = "输入目标金额",
    Position = UDim2.new(0, 5, 0, 50),
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")
        print("[目标金额] 输入框失焦内容:", text)

        if not text or text == "" then
            if config.targetCurrency > 0 then
                targetCurrencyInput.Text = formatNumber(config.targetCurrency)
                return
            end
            config.targetCurrency = 0
            config.enableTargetKick = false
            targetCurrencyInput.Text = ""
            UILibrary:Notify({
                Title = "目标金额已清除",
                Text = "已取消目标金额踢出功能",
                Duration = 5
            })
            saveConfig()
            return
        end

        local num = tonumber(text)
        if num and num > 0 then
            local currentCurrency = fetchCurrentCurrency()
            if currentCurrency and currentCurrency >= num then
                targetCurrencyInput.Text = tostring(config.targetCurrency > 0 and formatNumber(config.targetCurrency) or "")
                UILibrary:Notify({
                    Title = "设置失败",
                    Text = "目标金额(" .. formatNumber(num) .. ")小于当前金额(" .. formatNumber(currentCurrency) .. ")，请设置更大的目标值",
                    Duration = 5
                })
                return
            end

            config.targetCurrency = num
            targetCurrencyInput.Text = formatNumber(num)

            -- 自动启用踢出功能
            if not config.enableTargetKick then
                config.enableTargetKick = true
                suppressTargetToggleCallback = true
                targetCurrencyToggle:Set(true)
                UILibrary:Notify({
                    Title = "已启用目标踢出",
                    Text = "已自动开启目标金额踢出功能",
                    Duration = 5
                })
                saveConfig()
            end

            UILibrary:Notify({
                Title = "配置更新",
                Text = "目标金额已设为 " .. formatNumber(num),
                Duration = 5
            })
            saveConfig()
        else
            targetCurrencyInput.Text = tostring(config.targetCurrency > 0 and formatNumber(config.targetCurrency) or "")
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数作为目标金额",
                Duration = 5
            })

            if config.enableTargetKick then
                config.enableTargetKick = false
                targetCurrencyToggle:Set(false)
                UILibrary:Notify({
                    Title = "目标踢出已禁用",
                    Text = "请设置有效目标金额后重新启用",
                    Duration = 5
                })
                saveConfig()
            end
        end
    end
})

targetCurrencyInput.Text = tostring(config.targetCurrency > 0 and formatNumber(config.targetCurrency) or "")

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

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    sendWelcomeMessage()
end

local unchangedCount = 0
local webhookDisabled = false

-- 增加初始化锁
local hasInitializedCurrency = false

-- 初始化初始金额
local function initializeCurrency()
    if hasInitializedCurrency then return end
    local success, currencyValue = pcall(fetchCurrentCurrency)
    if success and currencyValue then
        initialCurrency = currencyValue
        lastCurrency = currencyValue
        hasInitializedCurrency = true
        UILibrary:Notify({ Title = "初始化成功", Text = "初始金额: " .. formatNumber(initialCurrency), Duration = 5 })
    else
        UILibrary:Notify({ Title = "初始化失败", Text = "无法获取初始金额", Duration = 5 })
    end
end

-- 初始化调用
initializeCurrency()

-- 运行时间和状态追踪变量
local startTime = os.time()
local lastSendTime = 0
local checkInterval = 1
local lastCurrencyCheckTime = tick()
local lastCurrencyCheckValue = 0

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

    -- 收益统计
    local totalChange = (currentCurrency and initialCurrency) and (currentCurrency - initialCurrency) or 0
    earnedCurrencyLabel.Text = "已赚金额: " .. formatNumber(totalChange)

    -- 🎯 目标金额检测
    if not webhookDisabled and config.enableTargetKick and currentCurrency and config.targetCurrency > 0 and currentCurrency >= config.targetCurrency then
        local payload = {
            embeds = {{
                title = "🎯 目标金额达成",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n**目标金额**: %s",
                    gameName, username,
                    formatNumber(currentCurrency),
                    formatNumber(config.targetCurrency)
                ),
                color = _G.PRIMARY_COLOR,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }}
        }
        UILibrary:Notify({
            Title = "目标达成",
            Text = "已达到目标金额 " .. formatNumber(config.targetCurrency) .. "，即将退出游戏",
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
                    "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n检测到玩家掉线，请查看",
                    gameName, username, formatNumber(currentCurrency or 0)),
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
            local rawAvg = totalChange / (elapsedTime / 3600)
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
                        "**用户名**: %s\n**已运行时间**: %s\n**当前金额**: %s\n**本次变化**: %s%s\n**总计收益**: %s%s\n**平均速度**: %s /小时",
                        username,
                        formatElapsedTime(elapsedTime),
                        formatNumber(currentCurrency),
                        (earnedChange >= 0 and "+" or ""), formatNumber(earnedChange),
                        (totalChange >= 0 and "+" or ""), formatNumber(totalChange),
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