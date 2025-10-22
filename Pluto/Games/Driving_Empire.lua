-- ============================================================================
-- 服务和基础变量声明
-- ============================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")

-- 调试模式
local DEBUG_MODE = false

-- 全局变量
local lastSendTime = os.time()
local sendingWelcome = false
_G.PRIMARY_COLOR = 5793266

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 调试打印函数
local function debugLog(...)
    if DEBUG_MODE then
        print(...)
    end
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
local configFile = "Pluto_X_DE_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notifyLeaderboard = false,
    leaderboardKick = false,
    notificationInterval = 30,
    targetAmount = 0,
    enableTargetKick = false,
    lastSavedCurrency = 0,
    baseAmount = 0,
    onlineRewardEnabled = false,
    autoSpawnVehicleEnabled = false,
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

    -- 某些执行器返回 nil 但实际发送成功
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
        debugLog("[Webhook] 欢迎消息正在发送中，跳过")
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
        debugLog("[Webhook] 欢迎消息发送成功")
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
-- 排行榜功能
-- ============================================================================
local originalCFrame, tempPlatform

local function tryGetContents(timeout)
    local ok, result = pcall(function()
        local root = workspace:WaitForChild("Game", timeout or 2)
            :WaitForChild("Leaderboards", timeout or 2)
            :WaitForChild("weekly_money", timeout or 2)
            :WaitForChild("Screen", timeout or 2)
            :WaitForChild("Leaderboard", timeout or 2)
        return root:WaitForChild("Contents", timeout or 2)
    end)
    return ok and result or nil
end

local function getSafeTeleportCFrame()
    local board = workspace:FindFirstChild("Game")
        and workspace.Game:FindFirstChild("Leaderboards")
        and workspace.Game.Leaderboards:FindFirstChild("weekly_money")
    if not board then return nil end
    local pivot = board:GetPivot()
    return pivot + Vector3.new(0, 30, 0)
end

local function spawnPlatform(atCFrame)
    tempPlatform = Instance.new("Part", workspace)
    tempPlatform.Name = "TempPlatform"
    tempPlatform.Anchored = true
    tempPlatform.CanCollide = true
    tempPlatform.Transparency = 1
    tempPlatform.Size = Vector3.new(100, 1, 100)
    tempPlatform.CFrame = atCFrame * CFrame.new(0, -5, 0)
end

local function teleportTo(cframe)
    if not originalCFrame and player.Character and player.Character.PrimaryPart then
        originalCFrame = player.Character.PrimaryPart.CFrame
    end
    local vehicles = workspace:FindFirstChild("Vehicles")
    local vehicle = vehicles and vehicles:FindFirstChild(username)
    local seat = vehicle and vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
    if seat and vehicle then
        vehicle:PivotTo(cframe)
    elseif player.Character and player.Character.PrimaryPart then
        player.Character:SetPrimaryPartCFrame(cframe)
    end
end

local function cleanup()
    if tempPlatform and tempPlatform.Parent then
        tempPlatform:Destroy()
        tempPlatform = nil
    end
    if originalCFrame then
        local vehicles = workspace:FindFirstChild("Vehicles")
        local vehicle = vehicles and vehicles:FindFirstChild(username)
        local seat = vehicle and vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
        if seat and vehicle then
            vehicle:PivotTo(originalCFrame)
        elseif player.Character and player.Character.PrimaryPart then
            player.Character:SetPrimaryPartCFrame(originalCFrame)
        end
        originalCFrame = nil
    end
end

local function fetchPlayerRank()
    local contents = tryGetContents(2)
    if not contents then
        local cframe = getSafeTeleportCFrame()
        if not cframe then return nil, false end
        teleportTo(cframe)
        spawnPlatform(cframe)
        wait(2)
        contents = tryGetContents(2)
        cleanup()
    end
    if not contents then return nil, false end

    local rank = 1
    for _, child in ipairs(contents:GetChildren()) do
        if tonumber(child.Name) == userId or child.Name == username then
            local placement = child:FindFirstChild("Placement")
            return placement and placement:IsA("IntValue") and placement.Value or rank, true
        end
        rank = rank + 1
    end
    return nil, false
end

-- ============================================================================
-- 自动生成车辆功能
-- ============================================================================
local performAutoSpawnVehicle

local function fetchVehicleStatsConcurrent(vehicleNames, GetVehicleStats)
    local results = {}
    local threads = {}
    
    for _, vehicleName in ipairs(vehicleNames) do
        local thread = coroutine.create(function()
            local success, result = pcall(function()
                return GetVehicleStats:InvokeServer(vehicleName)
            end)
            
            if success and type(result) == "table" and result.Generic_TopSpeed then
                results[vehicleName] = {
                    name = vehicleName,
                    speed = result.Generic_TopSpeed
                }
            end
        end)
        table.insert(threads, thread)
    end
    
    for _, thread in ipairs(threads) do
        coroutine.resume(thread)
    end
    
    local completed = 0
    local maxWait = 50
    local waitCount = 0
    
    while completed < #threads and waitCount < maxWait do
        completed = 0
        for _, thread in ipairs(threads) do
            if coroutine.status(thread) == "dead" then
                completed = completed + 1
            end
        end
        
        if completed < #threads then
            wait(0.1)
            waitCount = waitCount + 1
        end
    end
    
    return results
end

local function findFastestVehicleFast(vehiclesFolder, GetVehicleStats)
    local ownedVehicles = {}
    local vehicleCount = 0
    
    for _, vehicleValue in pairs(vehiclesFolder:GetChildren()) do
        if vehicleValue:IsA("BoolValue") and vehicleValue.Value == true then
            table.insert(ownedVehicles, vehicleValue.Name)
            vehicleCount = vehicleCount + 1
        end
    end
    
    if #ownedVehicles == 0 then
        return nil, -1, vehicleCount
    end
    
    debugLog("[AutoSpawnVehicle] 找到", vehicleCount, "辆拥有的车辆")
    
    local vehicleData = fetchVehicleStatsConcurrent(ownedVehicles, GetVehicleStats)
    
    local fastestName, fastestSpeed = nil, -1
    for _, data in pairs(vehicleData) do
        if data.speed > fastestSpeed then
            fastestSpeed = data.speed
            fastestName = data.name
        end
    end
    
    return fastestName, fastestSpeed, vehicleCount
end

performAutoSpawnVehicle = function()
    if not config.autoSpawnVehicleEnabled then
        debugLog("[AutoSpawnVehicle] 功能未启用")
        return
    end

    debugLog("[AutoSpawnVehicle] 开始执行车辆生成...")
    local startTime = tick()

    local localPlayer = Players.LocalPlayer
    if not localPlayer or not ReplicatedStorage then
        warn("[AutoSpawnVehicle] 无法获取必要服务")
        return
    end

    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        warn("[AutoSpawnVehicle] 未找到 Remotes 文件夹")
        return
    end

    local GetVehicleStats = remotesFolder:FindFirstChild("GetVehicleStats")
    local VehicleEvent = remotesFolder:FindFirstChild("VehicleEvent")
    if not GetVehicleStats or not VehicleEvent then
        warn("[AutoSpawnVehicle] 未找到必要的远程事件")
        return
    end

    local playerGui = localPlayer.PlayerGui or localPlayer:WaitForChild("PlayerGui", 5)
    if not playerGui then
        warn("[AutoSpawnVehicle] PlayerGui 获取失败")
        return
    end

    local statsPanel = playerGui:FindFirstChild(localPlayer.Name .. "'s Stats")
    if not statsPanel then
        warn("[AutoSpawnVehicle] 未找到玩家 Stats 面板")
        return
    end

    local vehiclesFolder = statsPanel:FindFirstChild("Vehicles")
    if not vehiclesFolder then
        warn("[AutoSpawnVehicle] 未找到 Vehicles 文件夹")
        return
    end

    local fastestName, fastestSpeed, vehicleCount = findFastestVehicleFast(vehiclesFolder, GetVehicleStats)
    local searchTime = tick() - startTime
    
    debugLog("[AutoSpawnVehicle] 搜索完成，耗时:", string.format("%.2f", searchTime), "秒")

    if fastestName and fastestSpeed > 0 then
        local success, err = pcall(function()
            VehicleEvent:FireServer("Spawn", fastestName)
        end)
        
        if success then
            UILibrary:Notify({
                Title = "自动生成",
                Text = string.format("已生成最快车辆: %s (速度: %s) 耗时: %.2fs", 
                    fastestName, tostring(fastestSpeed), searchTime),
                Duration = 5
            })
        else
            warn("[AutoSpawnVehicle] 生成车辆时出错:", err)
        end
    else
        warn("[AutoSpawnVehicle] 未找到有效车辆数据")
    end
end

-- ============================================================================
-- 在线时长奖励功能
-- ============================================================================
local function findRewardsRoot()
    local ok, gui = pcall(function()
        return player:WaitForChild("PlayerGui", 2)
    end)
    if not ok or not gui then
        return nil
    end

    -- 尝试主路径
    do
        local success, result = pcall(function()
            local dailyQuests = gui:FindFirstChild("DailyQuests")
            if dailyQuests then
                local dailyChallenges = dailyQuests:FindFirstChild("DailyChallenges")
                if dailyChallenges and dailyChallenges:FindFirstChild("holder") then
                    local pr = dailyChallenges.holder:FindFirstChild("PlaytimeRewards")
                    if pr and pr:FindFirstChild("RewardsList") then
                        return pr.RewardsList:FindFirstChild("SmallRewards")
                    end
                end
            end
            return nil
        end)
        if success and result then
            return result
        end
    end

    -- 尝试其他路径
    for _, child in ipairs(gui:GetChildren()) do
        if child:IsA("ScreenGui") or child:IsA("Frame") then
            if child.Name:find("PlaytimeRewards") then
                local rl = child:FindFirstChild("RewardsList")
                if rl and rl:FindFirstChild("SmallRewards") then
                    return rl.SmallRewards
                end
            end
            
            local rl2 = child:FindFirstChild("RewardsList", true)
            if rl2 and rl2:FindFirstChild("SmallRewards") then
                return rl2.SmallRewards
            end
        end
    end

    -- 广搜
    for _, child in ipairs(gui:GetDescendants()) do
        if child:IsA("Frame") and child.Name == "SmallRewards" then
            if child.Parent and child.Parent.Name == "RewardsList" then
                return child
            end
        end
    end

    return nil
end

local function claimPlaytimeRewards()
    if not config.onlineRewardEnabled then
        debugLog("[PlaytimeRewards] 功能未启用")
        return
    end

    spawn(function()
        local rewardCheckInterval = 600

        while config.onlineRewardEnabled do
            if not game:IsLoaded() then
                game.Loaded:Wait()
            end

            local gui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 5)
            local rewardsRoot = findRewardsRoot()

            if not rewardsRoot then
                warn("[PlaytimeRewards] 未找到奖励界面")
                task.wait(rewardCheckInterval)
                continue
            end

            local statsGui
            for _, v in ipairs(gui:GetChildren()) do
                if v:IsA("ScreenGui") and v.Name:find("'s Stats") then
                    statsGui = v
                    break
                end
            end

            if not statsGui then
                warn("[PlaytimeRewards] 未找到玩家 Stats")
                task.wait(rewardCheckInterval)
                continue
            end

            local claimedList = {}
            local claimedRaw = statsGui:FindFirstChild("ClaimedPlayTimeRewards")
            if claimedRaw and claimedRaw:IsA("StringValue") then
                local ok, parsed = pcall(function()
                    return HttpService:JSONDecode(claimedRaw.Value)
                end)
                if ok and typeof(parsed) == "table" then
                    for k, v in pairs(parsed) do
                        claimedList[tonumber(k)] = v
                    end
                end
            end

            local allClaimed = true
            for i = 1, 7 do
                if not claimedList[i] then
                    allClaimed = false
                    break
                end
            end

            if allClaimed then
                debugLog("[PlaytimeRewards] 所有奖励已领取")
                task.wait(rewardCheckInterval)
                continue
            end

            local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
            local uiInteraction = remotes and remotes:FindFirstChild("UIInteraction")
            local playRewards = remotes and remotes:FindFirstChild("PlayRewards")

            if not uiInteraction or not playRewards then
                warn("[PlaytimeRewards] 未找到远程事件")
                task.wait(rewardCheckInterval)
                continue
            end

            for i = 1, 7 do
                local rewardItem = rewardsRoot:FindFirstChild(tostring(i))
                local canClaim = false
                local alreadyClaimed = claimedList[i] == true

                if rewardItem then
                    local holder = rewardItem:FindFirstChild("Holder")
                    local collect = holder and holder:FindFirstChild("Collect")
                    if collect and collect.Visible and not alreadyClaimed then
                        canClaim = true
                    end
                end

                if canClaim then
                    pcall(function()
                        uiInteraction:FireServer({action = "PlaytimeRewards", rewardId = i})
                        task.wait(0.2)
                        playRewards:FireServer(i, false)
                        debugLog("[PlaytimeRewards] 已领取奖励 ID:", i)
                    end)
                    task.wait(0.4)
                end
            end

            task.wait(rewardCheckInterval)
        end
    end)
end

-- ============================================================================
-- 目标金额管理
-- ============================================================================
local function adjustTargetAmount()
    if config.baseAmount <= 0 or config.targetAmount <= 0 then
        return
    end
    
    local currentCurrency = fetchCurrentCurrency()
    if not currentCurrency then
        return
    end
    
    -- 计算当前金额与上次保存金额的差异
    local currencyDifference = currentCurrency - config.lastSavedCurrency
    
    -- 关键修改：只在金额减少时调整目标金额
    if currencyDifference < 0 then
        -- 金额减少了，相应调整目标金额
        local newTargetAmount = config.targetAmount + currencyDifference
        
        -- 确保目标金额仍然大于当前金额
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
            -- 如果调整后的目标金额小于等于当前金额，则禁用目标踢出功能
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
    elseif currencyDifference > 0 then
        -- 金额增加了，不调整目标金额，只更新保存的金额
        debugLog("[目标金额] 金额增加 " .. formatNumber(currencyDifference) .. "，保持目标金额不变: " .. formatNumber(config.targetAmount))
    end
    
    -- 无论如何都更新 lastSavedCurrency
    config.lastSavedCurrency = currentCurrency
    saveConfig()
end

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

    -- 自动生成车辆
    if config.autoSpawnVehicleEnabled then
        spawn(function()
            if not game:IsLoaded() then
                game.Loaded:Wait()
            end
            task.wait(5)
            
            if performAutoSpawnVehicle then
                pcall(performAutoSpawnVehicle)
            end
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

local antiAfkCard = UILibrary:CreateCard(generalContent)
UILibrary:CreateLabel(antiAfkCard, {
    Text = "反挂机已启用",
})

-- 主要功能标签页
local mainFeatureTab, mainFeatureContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "主要功能",
    Active = false
})

-- 在线时长奖励
local onlineRewardCard = UILibrary:CreateCard(mainFeatureContent)
UILibrary:CreateToggle(onlineRewardCard, {
    Text = "在线时长奖励",
    DefaultState = config.onlineRewardEnabled,
    Callback = function(state)
        config.onlineRewardEnabled = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = "在线时长奖励: " .. (state and "开启" or "关闭"),
            Duration = 5
        })
        saveConfig()
        if state then
            claimPlaytimeRewards()
        end
    end
})

-- 如果配置为开启，自动启动
if config.onlineRewardEnabled then
    claimPlaytimeRewards()
end

-- 自动生成车辆
local autoSpawnVehicleCard = UILibrary:CreateCard(mainFeatureContent)
UILibrary:CreateToggle(autoSpawnVehicleCard, {
    Text = "自动生成车辆",
    DefaultState = config.autoSpawnVehicleEnabled,
    Callback = function(state)
        config.autoSpawnVehicleEnabled = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = "自动生成车辆: " .. (state and "开启" or "关闭"),
            Duration = 5
        })
        saveConfig()
        
        if state then
            spawn(function()
                task.wait(0.5)
                if performAutoSpawnVehicle then
                    pcall(performAutoSpawnVehicle)
                end
            end)
        end
    end
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

-- 监测排行榜状态
local leaderboardNotifyCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(leaderboardNotifyCard, {
    Text = "监测排行榜状态",
    DefaultState = config.notifyLeaderboard,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.notifyLeaderboard = false
            return
        end
        config.notifyLeaderboard = state
        UILibrary:Notify({ Title = "配置更新", Text = "排行榜监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
    end
})

-- 上榜踢出
local leaderboardKickCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(leaderboardKickCard, {
    Text = "上榜自动踢出",
    DefaultState = config.leaderboardKick,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.leaderboardKick = false
            return
        end
        config.leaderboardKick = state
        UILibrary:Notify({ Title = "配置更新", Text = "上榜踢出: " .. (state and "开启" or "关闭"), Duration = 5 })
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
    Text = "基准金额设置",
})

local targetAmountLabel
local suppressTargetToggleCallback = false
local targetAmountToggle

local baseAmountInput = UILibrary:CreateTextBox(baseAmountCard, {
    PlaceholderText = "输入基准金额",
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")
        
        debugLog("[输入处理] 原始输入文本:", text or "nil")
        
        if not text or text == "" then
            -- 清空时重置所有相关配置
            config.baseAmount = 0
            config.targetAmount = 0
            config.lastSavedCurrency = 0
            baseAmountInput.Text = ""
            if targetAmountLabel then
                targetAmountLabel.Text = "目标金额: 未设置"
            end
            
            saveConfig()
            debugLog("[清空后] 所有金额配置已重置")
            
            UILibrary:Notify({
                Title = "基准金额已清除",
                Text = "基准金额和目标金额已重置",
                Duration = 5
            })
            return
        end

        -- 移除千位分隔符并转换为数字
        local cleanText = text:gsub(",", "")
        local num = tonumber(cleanText)
        
        debugLog("[数字转换] 清理后的文本:", cleanText)
        debugLog("[数字转换] 转换后的数字:", num)
        
        if num and num > 0 then
            local currentCurrency = fetchCurrentCurrency() or 0
            debugLog("[金额获取] 当前游戏金额:", currentCurrency)
            
            -- 关键修改：计算目标金额 = 基准金额 + 当前金额
            local newTarget = num + currentCurrency
            debugLog("[计算] 基准金额:", num)
            debugLog("[计算] 当前金额:", currentCurrency)
            debugLog("[计算] 目标金额:", newTarget)
            
            -- 设置配置
            config.baseAmount = num
            config.targetAmount = newTarget
            config.lastSavedCurrency = currentCurrency  -- 重要：记录当前金额作为基准
            
            debugLog("[赋值后] config.baseAmount:", config.baseAmount)
            debugLog("[赋值后] config.targetAmount:", config.targetAmount)
            debugLog("[赋值后] config.lastSavedCurrency:", config.lastSavedCurrency)
            
            -- 格式化显示输入框
            baseAmountInput.Text = formatNumber(num)
            
            -- 动态更新目标金额标签
            if targetAmountLabel then
                targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
                debugLog("[标签更新] 目标金额标签已更新为:", formatNumber(newTarget))
            end
            
            -- 保存配置
            saveConfig()
            
            -- 验证保存是否成功
            debugLog("[保存验证] 保存后 config.baseAmount:", config.baseAmount)
            debugLog("[保存验证] 保存后 config.targetAmount:", config.targetAmount)
            debugLog("[保存验证] 保存后 config.lastSavedCurrency:", config.lastSavedCurrency)
            
            -- 显示详细的更新通知
            UILibrary:Notify({
                Title = "基准金额已设置",
                Text = string.format("基准金额: %s\n当前金额: %s\n目标金额: %s\n\n后续只在金额减少时调整目标", 
                    formatNumber(num), 
                    formatNumber(currentCurrency),
                    formatNumber(newTarget)),
                Duration = 8
            })
            
            -- 如果目标踢出开关是开启的，检查是否需要关闭
            if config.enableTargetKick and currentCurrency >= newTarget then
                suppressTargetToggleCallback = true
                targetAmountToggle:Set(false)
                config.enableTargetKick = false
                saveConfig()
                UILibrary:Notify({
                    Title = "自动关闭",
                    Text = string.format("当前金额(%s)已达到目标(%s)，目标金额踢出功能已自动关闭",
                        formatNumber(currentCurrency),
                        formatNumber(newTarget)),
                    Duration = 6
                })
            end
        else
            baseAmountInput.Text = config.baseAmount > 0 and formatNumber(config.baseAmount) or ""
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数作为基准金额",
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
        
        -- 关键修改：重新计算 = 基准金额 + 当前金额
        local newTarget = config.baseAmount + currentCurrency
        
        debugLog("[重新计算] 使用基准金额:", config.baseAmount)
        debugLog("[重新计算] 当前游戏金额:", currentCurrency)
        debugLog("[重新计算] 计算的新目标:", newTarget)
        
        -- 检查目标金额是否合理
        if newTarget <= currentCurrency then
            UILibrary:Notify({
                Title = "计算错误",
                Text = string.format("计算后的目标金额(%s)不能小于等于当前金额(%s)", 
                    formatNumber(newTarget), formatNumber(currentCurrency)),
                Duration = 6
            })
            return
        end
        
        -- 更新配置
        config.targetAmount = newTarget
        config.lastSavedCurrency = currentCurrency  -- 重要：更新基准点
        
        -- 更新显示
        if targetAmountLabel then
            targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
        end
        
        -- 保存配置
        saveConfig()
        
        debugLog("[重新计算保存后] config.targetAmount:", config.targetAmount)
        debugLog("[重新计算保存后] config.lastSavedCurrency:", config.lastSavedCurrency)
        
        UILibrary:Notify({
            Title = "目标金额已重新计算",
            Text = string.format("基准金额: %s\n当前金额: %s\n新目标金额: %s\n\n后续只在金额减少时调整", 
                formatNumber(config.baseAmount),
                formatNumber(currentCurrency),
                formatNumber(newTarget)),
            Duration = 8
        })
        
        -- 如果目标踢出开关是开启的，检查是否需要关闭
        if config.enableTargetKick and currentCurrency >= newTarget then
            suppressTargetToggleCallback = true
            targetAmountToggle:Set(false)
            config.enableTargetKick = false
            saveConfig()
            UILibrary:Notify({
                Title = "自动关闭",
                Text = string.format("当前金额(%s)已达到目标(%s)，目标金额踢出功能已自动关闭",
                    formatNumber(currentCurrency),
                    formatNumber(newTarget)),
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
        if not webhookDisabled and (config.notifyCash or config.notifyLeaderboard or config.leaderboardKick)
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

                local embed = {
                    title = "Pluto-X",
                    description = string.format("**游戏**: %s\n**用户**: %s", gameName, username),
                    fields = {},
                    color = _G.PRIMARY_COLOR,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "作者: tongblx · Pluto-X" }
                }

                if config.notifyCash and currentCurrency then
                    local elapsedTime = currentTime - startTime
                    local avgMoney = "0"
                    if elapsedTime > 0 then
                        local rawAvg = earnedChange / (interval / 3600)
                        avgMoney = formatNumber(math.floor(rawAvg + 0.5))
                    end

                    table.insert(embed.fields, {
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
                    })
                end

                if config.notifyLeaderboard or config.leaderboardKick then
                    local currentRank, isOnLeaderboard = fetchPlayerRank()
                    local status = isOnLeaderboard and ("#" .. (currentRank or "未知")) or "未上榜"
                    table.insert(embed.fields, {
                        name = "🏆 排行榜",
                        value = string.format("**当前排名**: %s", status),
                        inline = true
                    })

                    UILibrary:Notify({
                        Title = "排行榜检测",
                        Text = isOnLeaderboard and ("排名 " .. status) or "未上榜",
                        Duration = 5
                    })

                    if isOnLeaderboard and config.leaderboardKick then
                        shouldShutdown = true
                    end
                end

                table.insert(embed.fields, {
                    name = "⌛ 下次通知",
                    value = string.format("%s（%s）", countdownR, countdownT),
                    inline = false
                })

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

                if shouldShutdown then
                    updateLastSavedCurrency(currentCurrency)
                    wait(0.5)
                    game:Shutdown()
                    return
                end
            end
        end

        wait(checkInterval)
    end
end)