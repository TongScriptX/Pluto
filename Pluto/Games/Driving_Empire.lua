local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")

local DEBUG_MODE = true
local lastSendTime = os.time()
local sendingWelcome = false
_G.PRIMARY_COLOR = 5793266
local isAutoRobActive = false
local isDeliveryInProgress = false

local function debugLog(...)
    if DEBUG_MODE then
        print(...)
    end
end

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

local function formatElapsedTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d小时%02d分%02d秒", hours, minutes, secs)
end

local function teleportCharacterTo(targetCFrame)
    if not player.Character or not player.Character.PrimaryPart then
        warn("[Teleport] 角色或主要部件不存在")
        return false
    end
    
    local vehicles = workspace:FindFirstChild("Vehicles")
    local vehicle = vehicles and vehicles:FindFirstChild(username)
    local seat = vehicle and vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
    
    if seat and vehicle then
        vehicle:PivotTo(targetCFrame)
        debugLog("[Teleport] 使用车辆传送")
    else
        player.Character:SetPrimaryPartCFrame(targetCFrame)
        debugLog("[Teleport] 使用角色传送")
    end
    
    return true
end

local function safePositionUpdate(targetCFrame)
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    if character and character.PrimaryPart then
        character.PrimaryPart.Velocity = Vector3.zero
        character:PivotTo(targetCFrame)
    end
    if localPlayer then
        localPlayer.ReplicationFocus = nil
    end
end

local function waitForCondition(conditionFunc, timeout, checkInterval)
    local t = timeout or 5
    local ci = checkInterval or 0.1
    local startTime = tick()
    
    repeat
        task.wait(ci)
        if conditionFunc() then
            return true
        end
    until tick() - startTime > t
    
    return false
end

local function isAutoRobEnabled()
    return config and config.autoRobATMsEnabled and (isAutoRobActive == true)
end

local function checkAutoRobStatus(context)
    local ctx = context or "未知"
    
    if isDeliveryInProgress then
        return true
    end
    
    if not config.autoRobATMsEnabled then
        debugLog("[AutoRob] [" .. ctx .. "] 检测到功能已关闭，停止操作")
        return false
    end
    return true
end

local UILibrary
local success, result = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
    local source = game:HttpGet(url)
    if not source then
        error("无法获取UILibrary源代码")
    end
    local func = loadstring(source)
    if not func then
        error("无法编译UILibrary源代码")
    end
    return func()
end)

if success and result then
    UILibrary = result
else
    warn("[PlutoUILibrary] 加载失败！请检查网络连接或链接是否有效：" .. tostring(result))
    warn("[PlutoUILibrary] 脚本将继续运行，但UI功能将不可用")
    UILibrary = nil
end

local player = Players.LocalPlayer
if not player then
    error("无法获取当前玩家")
end

local userId = player.UserId
local username = player.Name

local http_request = syn and syn.request or http and http.request or http_request
if not http_request then
    error("此执行器不支持 HTTP 请求")
end

local gameName = "未知游戏"
do
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if success and info then
        gameName = info.Name
    end
end

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
    totalEarningsBase = 0,
    lastNotifyCurrency = 0,
    onlineRewardEnabled = false,
    autoSpawnVehicleEnabled = false,
    autoRobATMsEnabled = false,
    robTargetAmount = 0,
}

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

local initialCurrency = 0

local function fetchCurrentCurrency()
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local currency = leaderstats:FindFirstChild("Cash")
        if currency then
            return currency.Value
        end
    end
    showErrorNotification("获取金额失败", "无法找到排行榜或金额数据")
    return nil
end

local function calculateEarnedAmount(currentCurrency)
    if not currentCurrency then return 0 end
    if config.totalEarningsBase > 0 then
        return currentCurrency - config.totalEarningsBase
    else
        return currentCurrency - initialCurrency
    end
end

local function calculateChangeAmount(currentCurrency)
    if not currentCurrency then return 0 end
    if config.lastNotifyCurrency > 0 then
        return currentCurrency - config.lastNotifyCurrency
    else
        return calculateEarnedAmount(currentCurrency)
    end
end

local function updateConfigField(fieldName, newValue, shouldNotify)
    shouldNotify = shouldNotify ~= false
    
    if config[fieldName] ~= newValue then
        config[fieldName] = newValue
        saveConfig()
        
        if shouldNotify then
            debugLog("[Config] " .. fieldName .. " 已更新: " .. tostring(newValue))
        end
        return true
    end
    return false
end

local function showNotification(title, text, duration)
    local dur = duration or 5
    UILibrary:Notify({
        Title = title,
        Text = text,
        Duration = dur
    })
end

local function showErrorNotification(title, text)
    showNotification("❌ " .. title, text, 5)
end

local function showSuccessNotification(title, text)
    showNotification("✅ " .. title, text, 3)
end

local function updateLastSavedCurrency(currentCurrency)
    if currentCurrency then
        updateConfigField("lastSavedCurrency", currentCurrency, false)
    end
end

local function updateLastNotifyCurrency(currentCurrency)
    if currentCurrency then
        updateConfigField("lastNotifyCurrency", currentCurrency, false)
    end
end

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

-- Webhook

local function getNotificationIntervalSeconds()
    return (config.notificationInterval or 5) * 60
end

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

-- 排行榜功能
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
    teleportCharacterTo(cframe)
end

local function cleanup()
    if tempPlatform and tempPlatform.Parent then
        tempPlatform:Destroy()
        tempPlatform = nil
    end
    if originalCFrame then
        teleportCharacterTo(originalCFrame)
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

-- 自动生成车辆功能
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

-- 在线时长奖励功能
local function findRewardsRoot()
    local ok, gui = pcall(function()
        return player:WaitForChild("PlayerGui", 2)
    end)
    if not ok or not gui then
        return nil
    end

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

-- 获取已抢劫金额
local function getRobbedAmount()
    local success, amount = pcall(function()
        local character = workspace:FindFirstChild(player.Name)
        if not character then
            debugLog("[AutoRob] 警告: 无法找到角色对象")
            return 0
        end
        
        local head = character:FindFirstChild("Head")
        if not head then
            debugLog("[AutoRob] 警告: 无法找到角色头部")
            return 0
        end
        
        local billboard = head:FindFirstChild("CharacterBillboard")
        if not billboard then
            debugLog("[AutoRob] 警告: 无法找到角色公告牌")
            return 0
        end
        
        local children = billboard:GetChildren()
        if #children < 4 then
            debugLog("[AutoRob] 警告: 公告牌子元素数量不足，当前数量: " .. #children)
            return 0
        end
        
        local textLabel = children[4]
        if not textLabel then
            debugLog("[AutoRob] 警告: 无法找到第4个子元素")
            return 0
        end
        
        if not textLabel.ContentText then
            debugLog("[AutoRob] 警告: 文本标签ContentText为空")
            return 0
        end
        
        local text = textLabel.ContentText
        local cleanText = text:gsub("[$,]", "")
        local amount = tonumber(cleanText) or 0
        
        return amount
    end)
    
    if success then
        return amount or 0
    else
        warn("[AutoRob] 获取已抢金额失败:", amount)
        return 0
    end
end

local function checkRobberyCompletion(previousAmount)
    local currentAmount = getRobbedAmount()
    local change = currentAmount - (previousAmount or 0)
    
    debugLog("[AutoRob] 金额检测结果:")
    debugLog("  - 之前金额: " .. formatNumber(previousAmount))
    debugLog("  - 当前金额: " .. formatNumber(currentAmount))
    debugLog("  - 变化量: " .. (change >= 0 and "+" or "") .. formatNumber(change))
    
    if change > 0 then
        debugLog("[AutoRob] ✓ 检测到抢劫成功获得金额: +" .. formatNumber(change))
        return true, change
    elseif change < 0 then
        debugLog("[AutoRob] ⚠ 检测到金额减少: " .. formatNumber(change))
        return false, change
    else
        debugLog("[AutoRob] - 金额无变化")
        return false, 0
    end
end

local function checkDropOffPointEnabled()
    local maxRetries = 3
    local dropOffPoint = nil
    
    for attempt = 1, maxRetries do
        dropOffPoint = workspace:FindFirstChild("Game")
            and workspace.Game:FindFirstChild("Jobs")
            and workspace.Game.Jobs:FindFirstChild("CriminalDropOffSpawners")
            and workspace.Game.Jobs.CriminalDropOffSpawners:FindFirstChild("CriminalDropOffSpawnerPermanent")
            and workspace.Game.Jobs.CriminalDropOffSpawners.CriminalDropOffSpawnerPermanent:FindFirstChild("CriminalDropOffPoint")
            and workspace.Game.Jobs.CriminalDropOffSpawners.CriminalDropOffSpawnerPermanent.CriminalDropOffPoint:FindFirstChild("Zone")
            and workspace.Game.Jobs.CriminalDropOffSpawners.CriminalDropOffSpawnerPermanent.CriminalDropOffPoint.Zone:FindFirstChild("BillboardAttachment")
            and workspace.Game.Jobs.CriminalDropOffSpawners.CriminalDropOffSpawnerPermanent.CriminalDropOffPoint.Zone.BillboardAttachment:FindFirstChild("Billboard")
        
        if dropOffPoint then
            break
        end
        
        if attempt < maxRetries then
            task.wait(0.1)
        end
    end
    
    if dropOffPoint then
        local enabled = dropOffPoint.Enabled
        debugLog("[DropOff] 交付点enabled状态: " .. tostring(enabled))
        return enabled
    else
        warn("[DropOff] 无法找到交付点Billboard（已尝试" .. maxRetries .. "次）")
        return false
    end
end

local function forceDeliverRobbedAmount()
    debugLog("[AutoRob] === 开始强制投放流程 ===")
    
    isDeliveryInProgress = true
    
    local collectionService = game:GetService("CollectionService")
    local localPlayer = game.Players.LocalPlayer
    local character = localPlayer.Character
    local dropOffSpawners = workspace.Game.Jobs.CriminalDropOffSpawners
    
    if not dropOffSpawners or not dropOffSpawners.CriminalDropOffSpawnerPermanent then
        warn("[AutoRob] 结束位置未找到!")
        isDeliveryInProgress = false
        return false
    end
    
    debugLog("[AutoRob] 清理背包中的金钱袋...")
    for _, bag in pairs(collectionService:GetTagged("CriminalMoneyBagTool")) do
        pcall(function()
            bag:Destroy()
        end)
        task.wait(0.1)
    end

    local robbedAmount = getRobbedAmount() or 0
    debugLog("[AutoRob] 当前已抢金额: " .. formatNumber(robbedAmount))

    local deliverySuccess = false
    local deliveryAttempts = 0
    local maxDeliveryAttempts = 10
    local initialRobbedAmount = robbedAmount
    local totalDeliveredAmount = 0
    local VirtualInputManager = game:GetService("VirtualInputManager")

    while not deliverySuccess and deliveryAttempts < maxDeliveryAttempts do
        deliveryAttempts = deliveryAttempts + 1
        debugLog("[AutoRob] 强制投放 - 第 " .. deliveryAttempts .. " 次传送尝试")
        
        local dropOffEnabled = checkDropOffPointEnabled()
        if not dropOffEnabled then
            debugLog("[AutoRob] 投放点不可用，等待2秒后重试...")
            task.wait(2)
            
            if not checkDropOffPointEnabled() then
                debugLog("[AutoRob] 投放点仍然不可用，跳过本次尝试")
                task.wait(1)
            else
                if character and character.PrimaryPart then
                    character.PrimaryPart.Velocity = Vector3.zero
                    character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                    debugLog("[AutoRob] 已传送到交付位置")
                end

                debugLog("[AutoRob] 等待角色稳定...")
                task.wait(1)

                debugLog("[AutoRob] 执行跳跃动作触发交付")
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

                debugLog("[AutoRob] 跳跃后立即重置位置防止向前移动")
                task.wait(0.2)
                if character and character.PrimaryPart then
                    character.PrimaryPart.Velocity = Vector3.zero
                    character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                end

                debugLog("[AutoRob] 检测金额是否到账...")
                local checkStart = tick()
                local checkTimeout = 5
                local lastCheckAmount = initialRobbedAmount

                repeat
                    task.wait(0.3)
                    -- 持续保持位置，防止角色向前移动
                    if character and character.PrimaryPart then
                        character.PrimaryPart.Velocity = Vector3.zero
                        character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                    end

                    local currentRobbedAmount = getRobbedAmount() or 0

                    if currentRobbedAmount ~= lastCheckAmount then
                        if currentRobbedAmount < lastCheckAmount then
                            local deliveredAmount = lastCheckAmount - currentRobbedAmount
                            totalDeliveredAmount = totalDeliveredAmount + deliveredAmount
                            debugLog("[AutoRob] ✓ 检测到已抢金额减少: " .. formatNumber(deliveredAmount))
                        end
                        lastCheckAmount = currentRobbedAmount
                    end

                    if currentRobbedAmount == 0 then
                        debugLog("[AutoRob] ✓ 交付成功！已抢金额已清零")
                        deliverySuccess = true
                        break
                    end
                until tick() - checkStart > checkTimeout
                
                if not deliverySuccess then
                    local currentRobbedAmount = getRobbedAmount() or 0
                    if currentRobbedAmount < initialRobbedAmount * 0.5 then
                        debugLog("[AutoRob] 金额显著减少，继续等待...")
                        task.wait(3)
                        currentRobbedAmount = getRobbedAmount()
                        if currentRobbedAmount == 0 then
                            debugLog("[AutoRob] ✓ 交付成功！")
                            deliverySuccess = true
                        end
                    else
                        debugLog("[AutoRob] ✗ 本次传送未成功交付，当前已抢金额: " .. formatNumber(currentRobbedAmount))
                        task.wait(1)
                    end
                end
            end
        else
            if character and character.PrimaryPart then
                character.PrimaryPart.Velocity = Vector3.zero
                character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                debugLog("[AutoRob] 已传送到交付位置")
            end

            debugLog("[AutoRob] 等待角色稳定...")
            task.wait(1)

            debugLog("[AutoRob] 执行跳跃动作触发交付")
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

            debugLog("[AutoRob] 等待跳跃动作完成...")
            task.wait(1.5)

            debugLog("[AutoRob] 保持位置等待交付处理...")
            local holdTime = tick()
            repeat
                task.wait(0.1)
                if character and character.PrimaryPart then
                    character.PrimaryPart.Velocity = Vector3.zero
                    character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                end
            until tick() - holdTime > 2

            debugLog("[AutoRob] 检测金额是否到账...")
            local checkStart = tick()
            local checkTimeout = 5
            local lastCheckAmount = initialRobbedAmount

            repeat
                task.wait(0.5)
                local currentRobbedAmount = getRobbedAmount() or 0

                if currentRobbedAmount ~= lastCheckAmount then
                    if currentRobbedAmount < lastCheckAmount then
                        local deliveredAmount = lastCheckAmount - currentRobbedAmount
                        totalDeliveredAmount = totalDeliveredAmount + deliveredAmount
                        debugLog("[AutoRob] ✓ 检测到已抢金额减少: " .. formatNumber(deliveredAmount))
                    end
                    lastCheckAmount = currentRobbedAmount
                end

                if currentRobbedAmount == 0 then
                    debugLog("[AutoRob] ✓ 交付成功！已抢金额已清零")
                    deliverySuccess = true
                    break
                end
            until tick() - checkStart > checkTimeout
            
            if not deliverySuccess then
                local currentRobbedAmount = getRobbedAmount() or 0
                if currentRobbedAmount < initialRobbedAmount * 0.5 then
                    debugLog("[AutoRob] 金额显著减少，继续等待...")
                    task.wait(3)
                    currentRobbedAmount = getRobbedAmount()
                    if currentRobbedAmount == 0 then
                        debugLog("[AutoRob] ✓ 交付成功！")
                        deliverySuccess = true
                    end
                else
                    debugLog("[AutoRob] ✗ 本次传送未成功交付，当前已抢金额: " .. formatNumber(currentRobbedAmount))
                    task.wait(1)
                end
            end
        end
    end
    
    if deliverySuccess then
        debugLog("[AutoRob] ✓ 强制投放完成，共尝试 " .. deliveryAttempts .. " 次")
    else
        warn("[AutoRob] ✗ 强制投放失败，达到最大尝试次数(" .. maxDeliveryAttempts .. ")")
    end
    
    debugLog("[AutoRob] === 强制投放流程结束 ===")
    debugLog("[AutoRob] 总计投放金额: " .. formatNumber(totalDeliveredAmount))
    
    isDeliveryInProgress = false
    
    return deliverySuccess, deliveryAttempts, totalDeliveredAmount
end

local function checkAndForceDelivery(tempTarget)
    local robbedAmount = getRobbedAmount() or 0
    local targetAmount = tempTarget or config.robTargetAmount or 0

    if targetAmount > 0 and robbedAmount >= targetAmount then
        debugLog("[AutoRob] ⚠ 已抢金额达到或超过目标: " .. formatNumber(robbedAmount) .. " >= " .. formatNumber(targetAmount))

        local dropOffEnabled = checkDropOffPointEnabled()

        if not dropOffEnabled then
            debugLog("[AutoRob] 交付点不可用，继续抢劫...")
            return false, 0, 0
        end

        debugLog("[AutoRob] 交付点可用，执行强制投放...")

        local success, attempts, deliveredAmount = forceDeliverRobbedAmount()

        if success then
            UILibrary:Notify({
                Title = "目标达成",
                Text = string.format("获得 +%s\n尝试次数: %d", formatNumber(deliveredAmount), attempts),
                Duration = 5
            })

            task.wait(2)
            return true
        else
            warn("[AutoRob] 投放失败，自动创建临时目标继续抢劫")
            return false, attempts, 0
        end
    end

    return false
end

-- 增强的投放失败恢复机制
local function enhancedDeliveryFailureRecovery(robbedAmount, originalTarget, tempTargetRef)
    debugLog("[Recovery] === 启动投放失败恢复机制 ===")
    debugLog("[Recovery] 当前已抢金额: " .. formatNumber(robbedAmount))
    debugLog("[Recovery] 原始目标金额: " .. formatNumber(originalTarget))

    local collectionService = game:GetService("CollectionService")
    local moneyBags = collectionService:GetTagged("CriminalMoneyBagTool")
    for _, bag in pairs(moneyBags) do
        pcall(function() bag:Destroy() end)
        task.wait(0.1)
    end

    local player = game.Players.LocalPlayer
    local character = player.Character
    local dropOffSpawners = workspace.Game.Jobs.CriminalDropOffSpawners

    if character and character.PrimaryPart then
        character.PrimaryPart.Velocity = Vector3.zero
        character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 20, 0))
        debugLog("[Recovery] 已传送到安全位置重置状态")
    end

    task.wait(1)

    local currentRobbedAmount = getRobbedAmount() or 0
    debugLog("[Recovery] 重置后已抢金额: " .. formatNumber(currentRobbedAmount))

    if currentRobbedAmount > 0 then
        debugLog("[Recovery] 发现剩余金额，尝试再次投放...")
        local retrySuccess, retryAttempts, retryDelivered = forceDeliverRobbedAmount()

        if retrySuccess then
            debugLog("[Recovery] ✓ 重试投放成功！金额: " .. formatNumber(retryDelivered))
            debugLog("[Recovery] === 投放失败恢复机制结束（成功） ===")
            return true, retryDelivered
        else
            debugLog("[Recovery] ✗ 重试投放仍然失败")
        end
    end

    local newTempTarget = currentRobbedAmount + originalTarget
    tempTargetRef.value = newTempTarget

    debugLog("[Recovery] ✗ 投放失败，继续增加临时目标: " .. formatNumber(newTempTarget))
    debugLog("[Recovery] === 投放失败恢复机制结束（失败，增加临时目标） ===")

    return false, 0
end


local lastDropOffEnabledStatus = nil

local function monitorDropOffStatusAndUpdateTarget()
    local currentStatus = checkDropOffPointEnabled()
    
    if lastDropOffEnabledStatus == nil then
        lastDropOffEnabledStatus = currentStatus
        debugLog("[DropOff] 初始交付点状态: " .. tostring(currentStatus))
        return false
    end
    
    if not lastDropOffEnabledStatus and currentStatus then
        debugLog("[DropOff] 交付点从不可用变为可用！")
        
        local currentRobbedAmount = getRobbedAmount() or 0
        if currentRobbedAmount > 0 then
            config.robTargetAmount = currentRobbedAmount
            saveConfig()
            
            UILibrary:Notify({
                Title = "目标金额已更新",
                Text = string.format("交付点可用，目标金额更新为: %s", formatNumber(currentRobbedAmount)),
                Duration = 5
            })
            
            debugLog("[DropOff] 目标金额已更新为当前已抢劫金额: " .. formatNumber(currentRobbedAmount))
        end
        
        lastDropOffEnabledStatus = currentStatus
        return true
    end
    
    lastDropOffEnabledStatus = currentStatus
    return false
end

-- Auto Rob ATMs功能
local function performAutoRobATMs()
    if not config.autoRobATMsEnabled then
        debugLog("[AutoRobATMs] 功能未启用")
        return
    end
    
    isAutoRobActive = true
    debugLog("[AutoRobATMs] 自动抢劫已启动，活动状态: " .. tostring(isAutoRobActive))
    
    spawn(function()
        local collectionService = game:GetService("CollectionService")
        local localPlayer = game.Players.LocalPlayer
        local character = localPlayer.Character
        local dropOffSpawners = workspace.Game.Jobs.CriminalDropOffSpawners
        local sessionStartCurrency = fetchCurrentCurrency() or 0
        local originalTargetAmount = config.robTargetAmount
        local tempTargetAmount = nil

        local lastSuccessfulRobbery = tick()
        local noATMFoundCount = 0
        local maxNoATMFoundCount = 5
        local lastATMCount = 0
        
        local knownATMLocations = {}
        local maxKnownLocations = 20

        while config.autoRobATMsEnabled do
            task.wait()
            local success, err = pcall(function()
                local timeSinceLastRobbery = tick() - lastSuccessfulRobbery
                if timeSinceLastRobbery > 120 then
                    warn("[AutoRobATMs] 检测到长时间未成功抢劫（" .. math.floor(timeSinceLastRobbery) .. "秒），执行重置操作")

                    noATMFoundCount = 0
                    getfenv().atmloadercooldown = false
                    localPlayer.ReplicationFocus = nil

                    if character and character.PrimaryPart then
                        character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 10, 0))
                    end

                    local moneyBags = collectionService:GetTagged("CriminalMoneyBagTool")
                    for _, bag in pairs(moneyBags) do
                        pcall(function() bag:Destroy() end)
                    end

                    task.wait(2)
                    lastSuccessfulRobbery = tick()
                    debugLog("[AutoRobATMs] 状态已重置")
                end

                local robbedAmount = getRobbedAmount() or 0
                local targetAmount = tempTargetAmount or config.robTargetAmount or 0

                if targetAmount > 0 and robbedAmount >= targetAmount then
                    debugLog("[AutoRobATMs] 已抢金额达到目标: " .. formatNumber(robbedAmount) .. " >= " .. formatNumber(targetAmount))

                    local dropOffEnabled = checkDropOffPointEnabled()

                    if not dropOffEnabled then
                        debugLog("[AutoRobATMs] 交付点不可用，继续抢劫...")
                        lastSuccessfulRobbery = tick()
                    else
                        debugLog("[AutoRobATMs] 交付点可用，调用强制投放功能...")

                        local deliverySuccess, deliveryAttempts, deliveredAmount = forceDeliverRobbedAmount()

                    if deliverySuccess then
                        if tempTargetAmount then
                            tempTargetAmount = nil
                            debugLog("[AutoRobATMs] 投放成功，临时目标金额已销毁")
                        end

                        UILibrary:Notify({
                            Title = "抢劫完成",
                            Text = string.format("本次获得: +%s\n交付尝试: %d次", formatNumber(deliveredAmount), deliveryAttempts),
                            Duration = 5
                        })
                        task.wait(2)
                        sessionStartCurrency = fetchCurrentCurrency() or 0
                        lastSuccessfulRobbery = tick()
                    else
                        warn("[AutoRobATMs] 投放失败，启动增强恢复机制")

                        local tempTargetRef = { value = tempTargetAmount }
                        local recoverySuccess, recoveredAmount = enhancedDeliveryFailureRecovery(robbedAmount, originalTargetAmount, tempTargetRef)

                        if recoverySuccess then
                            if tempTargetAmount then
                                tempTargetAmount = nil
                                debugLog("[AutoRobATMs] ✓ 投放成功，临时目标已销毁，恢复原设定目标: " .. formatNumber(originalTargetAmount))
                            end
                            
                            UILibrary:Notify({
                                Title = "投放成功",
                                Text = string.format("临时目标完成，恢复原目标\n获得: +%s\n原目标: %s", formatNumber(recoveredAmount), formatNumber(originalTargetAmount)),
                                Duration = 5
                            })
                            task.wait(2)
                            sessionStartCurrency = fetchCurrentCurrency() or 0
                            lastSuccessfulRobbery = tick()
                        else
                            local currentRobbedAmount = getRobbedAmount() or 0
                            tempTargetAmount = currentRobbedAmount + originalTargetAmount
                            debugLog("[AutoRobATMs] ✗ 投放失败，继续增加临时目标: " .. formatNumber(tempTargetAmount))

                            UILibrary:Notify({
                                Title = "临时目标增加",
                                Text = string.format("投放失败，继续增加临时目标\n新目标: %s", formatNumber(tempTargetAmount)),
                                Duration = 3
                            })

                            lastSuccessfulRobbery = tick()
                        end
                    end
                    end
                end

                local function robATM(atm, atmType, foundCountRef)
                    if not config.autoRobATMsEnabled then return false end

                    foundCountRef.count = foundCountRef.count + 1
                    local teleportTime = atmType == "tagged" and 1 or 0.2
                    local atmTypeName = atmType == "tagged" and "ATM" or "nil ATM"

                    debugLog("[AutoRob] 开始抢劫" .. atmTypeName)

                    local teleportStart = tick()
                    repeat
                        task.wait()
                        if character and character.PrimaryPart then
                            character.PrimaryPart.Velocity = Vector3.zero
                            character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                        end
                        localPlayer.ReplicationFocus = nil
                    until tick() - teleportStart > teleportTime or not config.autoRobATMsEnabled

                    if not config.autoRobATMsEnabled then return false end

                    game:GetService("ReplicatedStorage").Remotes.AttemptATMBustStart:InvokeServer(atm)

                    local progressStart = tick()
                    repeat
                        task.wait()
                        if character and character.PrimaryPart then
                            character.PrimaryPart.Velocity = Vector3.zero
                            character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                        end
                        localPlayer.ReplicationFocus = nil
                    until tick() - progressStart > 2.5 or not config.autoRobATMsEnabled

                    if not config.autoRobATMsEnabled then return false end

                    local beforeRobberyAmount = getRobbedAmount() or 0
                    debugLog("[AutoRob] 开始抢劫" .. atmTypeName .. "，当前已抢金额: " .. formatNumber(beforeRobberyAmount))

                    game:GetService("ReplicatedStorage").Remotes.AttemptATMBustComplete:InvokeServer(atm)
                    debugLog("[AutoRob] 已调用" .. atmTypeName .. "的AttemptATMBustComplete，等待抢劫完成...")

                    local cooldownStart = tick()
                    repeat
                        task.wait()
                        if character and character.PrimaryPart then
                            character.PrimaryPart.Velocity = Vector3.zero
                            character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                        end
                    until tick() - cooldownStart > 3 or (character and character:GetAttribute("ATMBustDebounce")) or not config.autoRobATMsEnabled

                    repeat
                        task.wait()
                        if character and character.PrimaryPart then
                            character.PrimaryPart.Velocity = Vector3.zero
                            character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                        end
                    until tick() - cooldownStart > 3 or not (character and character:GetAttribute("ATMBustDebounce") and config.autoRobATMsEnabled)

                    task.wait(0.5)
                    local robberySuccess, amountChange = checkRobberyCompletion(beforeRobberyAmount)

                    -- 无论抢劫成功与否都记录ATM位置
                    local atmLocation = atm.WorldPivot
                    
                    local alreadyRecorded = false
                    for _, loc in ipairs(knownATMLocations) do
                        if (loc.Position - atmLocation.Position).Magnitude < 5 then
                            alreadyRecorded = true
                            break
                        end
                    end
                    
                    if not alreadyRecorded then
                        table.insert(knownATMLocations, 1, atmLocation)
                        if #knownATMLocations > maxKnownLocations then
                            table.remove(knownATMLocations)
                        end
                        debugLog("[AutoRobATMs] 记录新ATM位置，当前记录数: " .. #knownATMLocations)
                    end

                    if robberySuccess then
                        debugLog("[AutoRob] ✓ " .. atmTypeName .. "抢劫成功！获得金额: +" .. formatNumber(amountChange))
                        
                        lastSuccessfulRobbery = tick()
                        noATMFoundCount = 0

                        local shouldStop = checkAndForceDelivery(tempTargetAmount)
                        if shouldStop then
                            debugLog("[AutoRob] 🔄 投放完成，重新开始抢劫循环")
                            sessionStartCurrency = fetchCurrentCurrency()
                            return true
                        end
                    else
                        debugLog("[AutoRob] ⚠ " .. atmTypeName .. "抢劫未获得金额或失败")
                    end

                    return false
                end

                local targetATM = nil
                local foundATMCount = {count = 0}

                local taggedATMs = collectionService:GetTagged("CriminalATM")
                for _, atm in pairs(taggedATMs) do
                    if atm:GetAttribute("State") ~= "Busted" and config.autoRobATMsEnabled then
                        if robATM(atm, "tagged", foundATMCount) then
                            break
                        end
                    end
                end

                for _, obj in pairs(getnilinstances()) do
                    if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and config.autoRobATMsEnabled then
                        if robATM(obj, "nil", foundATMCount) then
                            break
                        end
                    end
                end

                if foundATMCount.count == 0 then
                    noATMFoundCount = noATMFoundCount + 1
                    debugLog("[AutoRobATMs] 未找到可用ATM，计数: " .. noATMFoundCount .. "/" .. maxNoATMFoundCount)

                    if noATMFoundCount >= maxNoATMFoundCount then
                        warn("[AutoRobATMs] 连续" .. maxNoATMFoundCount .. "次未找到ATM，执行重置操作")

                        debugLog("[AutoRobATMs] 重置状态...")
                        getfenv().atmloadercooldown = false
                        localPlayer.ReplicationFocus = nil
                        noATMFoundCount = 0

                        local spawnersFolder = workspace.Game.Jobs.CriminalATMSpawners
                        if spawnersFolder then
                            local spawners = spawnersFolder:GetChildren()
                            debugLog("[AutoRobATMs] 强制刷新" .. #spawners .. "个spawner")
                            for i, spawner in pairs(spawners) do
                                if i == 1 or i == #spawners or i % 5 == 0 then
                                    debugLog("[AutoRobATMs] 聚焦spawner " .. i .. "/" .. #spawners)
                                end
                                localPlayer.ReplicationFocus = spawner
                                task.wait(0.2)
                            end
                        else
                            warn("[AutoRobATMs] 无法找到CriminalATMSpawners文件夹")
                        end

                        -- 搜索流程：中心点 → CriminalArea → 已知ATM位置 → 回到中心点
                        local searchSuccess = false

                        -- 第一步：传送到中心点搜索
                        if character and character.PrimaryPart then
                            debugLog("[AutoRobATMs] 第1步：传送到中心点搜索")
                            character:PivotTo(CFrame.new(0, 50, 0))
                        else
                            warn("[AutoRobATMs] 无法传送，角色或主要部件不存在")
                        end
                        task.wait(1)
                        localPlayer.ReplicationFocus = nil

                        -- 检查中心点是否找到ATM
                        local taggedATMs = collectionService:GetTagged("CriminalATM")
                        for _, atm in pairs(taggedATMs) do
                            if atm:GetAttribute("State") ~= "Busted" and config.autoRobATMsEnabled then
                                searchSuccess = true
                                debugLog("[AutoRobATMs] 中心点找到ATM (tagged)")
                                break
                            end
                        end
                        if not searchSuccess then
                            for _, obj in pairs(getnilinstances()) do
                                if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and config.autoRobATMsEnabled then
                                    searchSuccess = true
                                    debugLog("[AutoRobATMs] 中心点找到ATM (nil)")
                                    break
                                end
                            end
                        end

                        -- 第二步：传送到CriminalArea搜索
                        if not searchSuccess then
                            local criminalArea = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("CriminalArea")
                            if criminalArea then
                                local criminalAreaPosition = criminalArea:GetPivot()
                                if character and character.PrimaryPart then
                                    debugLog("[AutoRobATMs] 第2步：传送到CriminalArea搜索")
                                    character:PivotTo(criminalAreaPosition + Vector3.new(0, 50, 0))
                                end
                                task.wait(1)
                                localPlayer.ReplicationFocus = nil

                                -- 检查CriminalArea是否找到ATM
                                taggedATMs = collectionService:GetTagged("CriminalATM")
                                for _, atm in pairs(taggedATMs) do
                                    if atm:GetAttribute("State") ~= "Busted" and config.autoRobATMsEnabled then
                                        searchSuccess = true
                                        debugLog("[AutoRobATMs] CriminalArea找到ATM (tagged)")
                                        break
                                    end
                                end
                                if not searchSuccess then
                                    for _, obj in pairs(getnilinstances()) do
                                        if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and config.autoRobATMsEnabled then
                                            searchSuccess = true
                                            debugLog("[AutoRobATMs] CriminalArea找到ATM (nil)")
                                            break
                                        end
                                    end
                                end
                            else
                                warn("[AutoRobATMs] 无法找到CriminalArea")
                            end
                        end

                        -- 第三步：依次传送记录的ATM位置搜索
                        if not searchSuccess and #knownATMLocations > 0 then
                            debugLog("[AutoRobATMs] 第3步：依次访问" .. #knownATMLocations .. "个已知ATM位置")
                            
                            for i, location in ipairs(knownATMLocations) do
                                if not config.autoRobATMsEnabled then break end
                                
                                if character and character.PrimaryPart then
                                    character.PrimaryPart.Velocity = Vector3.zero
                                    character:PivotTo(location + Vector3.new(0, 5, 0))
                                    debugLog("[AutoRobATMs] 访问已知ATM位置 " .. i .. "/" .. #knownATMLocations)
                                end
                                
                                task.wait(0.5)
                                
                                taggedATMs = collectionService:GetTagged("CriminalATM")
                                for _, atm in pairs(taggedATMs) do
                                    if atm:GetAttribute("State") ~= "Busted" and config.autoRobATMsEnabled then
                                        searchSuccess = true
                                        debugLog("[AutoRobATMs] 已知位置找到ATM (tagged)")
                                        break
                                    end
                                end
                                if searchSuccess then break end
                                
                                for _, obj in pairs(getnilinstances()) do
                                    if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and config.autoRobATMsEnabled then
                                        searchSuccess = true
                                        debugLog("[AutoRobATMs] 已知位置找到ATM (nil)")
                                        break
                                    end
                                end
                                if searchSuccess then break end
                            end
                        end

                        -- 第四步：回到中心点开始循环
                        if character and character.PrimaryPart then
                            debugLog("[AutoRobATMs] 第4步：回到中心点开始循环")
                            character:PivotTo(CFrame.new(0, 50, 0))
                        else
                            warn("[AutoRobATMs] 无法传送，角色或主要部件不存在")
                        end
                        task.wait(1)
                        localPlayer.ReplicationFocus = nil
                        debugLog("[AutoRobATMs] ATM搜索已重置，准备重新开始")
                    end
                else
                    noATMFoundCount = 0
                end

                if not (getfenv().atmloadercooldown or targetATM) then
                    getfenv().atmloadercooldown = true
                    debugLog("[AutoRobATMs] 启动ATM加载器")
                    UILibrary:Notify({
                        Title = "加载中",
                        Text = "正在加载ATM...",
                        Duration = 3
                    })

                    local spawners = workspace.Game.Jobs.CriminalATMSpawners
                    if not spawners then
                        warn("[AutoRobATMs] 无法找到CriminalATMSpawners")
                    else
                        local spawnerList = spawners:GetChildren()
                        local totalSpawners = #spawnerList
                        debugLog("[AutoRobATMs] 找到spawner数量: " .. totalSpawners)

                        local processedCount = 0
                        local spawnerIterator, spawnerArray, spawnerIndex = pairs(spawnerList)
                        while config.autoRobATMsEnabled do
                            local spawner
                            spawnerIndex, spawner = spawnerIterator(spawnerArray, spawnerIndex)
                            if spawnerIndex == nil then
                                break
                            end
                            processedCount = processedCount + 1
                            if processedCount % 5 == 0 then
                                debugLog("[AutoRobATMs] 已加载 " .. processedCount .. "/" .. totalSpawners .. " 个spawner")
                            end
                            localPlayer.ReplicationFocus = spawner
                            task.wait(1)
                        end
                    end

                    if config.autoRobATMsEnabled then
                        local nilSpawnerCount = 0
                        local nilSpawnerIterator, nilSpawnerArray, nilSpawnerIndex = pairs(getnilinstances())
                        while config.autoRobATMsEnabled do
                            local spawner
                            nilSpawnerIndex, spawner = nilSpawnerIterator(nilSpawnerArray, nilSpawnerIndex)
                            if nilSpawnerIndex == nil then
                                break
                            end
                            if spawner.Name == "CriminalATMSpawner" then
                                nilSpawnerCount = nilSpawnerCount + 1
                                localPlayer.ReplicationFocus = spawner
                                task.wait(1)
                            end
                        end
                        if nilSpawnerCount > 0 then
                            debugLog("[AutoRobATMs] nil instances中找到spawner数量: " .. nilSpawnerCount)
                        end
                    end

                    getfenv().atmloadercooldown = false
                    localPlayer.ReplicationFocus = nil
                    debugLog("[AutoRobATMs] ATM加载器完成")
                end
            end)
            
            if not success then
                warn("AutoRobATMs Error:", err)
                noATMFoundCount = 0
                getfenv().atmloadercooldown = false
                localPlayer.ReplicationFocus = nil
            end
        end
        
        debugLog("[AutoRobATMs] 自动抢劫已停止")
    end)
end

-- 目标金额管理
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
    elseif currencyDifference > 0 then
        debugLog("[目标金额] 金额增加 " .. formatNumber(currencyDifference) .. "，保持目标金额不变: " .. formatNumber(config.targetAmount))
    end
    
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

-- 配置加载
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

-- 反挂机
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    UILibrary:Notify({ Title = "反挂机", Text = "检测到闲置", Duration = 3 })
end)

-- 掉线检测
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

-- 初始化
pcall(initTargetAmount)
pcall(loadConfig)

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

local toggleButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "菜单"
})

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

-- Auto Rob ATMs
local autoRobATMsCard = UILibrary:CreateCard(mainFeatureContent, { IsMultiElement = true })
UILibrary:CreateLabel(autoRobATMsCard, {
    Text = "Auto Rob ATMs",
})

local robAmountInput = UILibrary:CreateTextBox(autoRobATMsCard, {
    PlaceholderText = "输入单次目标金额",
    OnFocusLost = function(text)
        if not text or text == "" then
            config.robTargetAmount = 0
            robAmountInput.Text = ""
            saveConfig()
            UILibrary:Notify({
                Title = "抢劫金额已清除",
                Text = "单次抢劫目标金额已重置",
                Duration = 5
            })
            return
        end
        
        local cleanText = text:gsub(",", "")
        local num = tonumber(cleanText)
        
        if num and num > 0 then
            config.robTargetAmount = num
            robAmountInput.Text = formatNumber(num)
            saveConfig()
            UILibrary:Notify({
                Title = "抢劫金额已设置",
                Text = "单次目标: " .. formatNumber(num),
                Duration = 5
            })
        else
            robAmountInput.Text = config.robTargetAmount > 0 and formatNumber(config.robTargetAmount) or ""
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数",
                Duration = 5
            })
        end
    end
})

if config.robTargetAmount and config.robTargetAmount > 0 then
    robAmountInput.Text = formatNumber(config.robTargetAmount)
else
    robAmountInput.Text = ""
end

UILibrary:CreateToggle(autoRobATMsCard, {
    Text = "启用自动抢劫",
    DefaultState = config.autoRobATMsEnabled or false,
    Callback = function(state)
        config.autoRobATMsEnabled = state
        
        if not state then
            -- 关闭功能时设置状态为非活动
            isAutoRobActive = false
            isDeliveryInProgress = false
            debugLog("[UI] 用户关闭自动抢劫功能，设置状态为非活动")
        end
        
        UILibrary:Notify({
            Title = "配置更新",
            Text = "Auto Rob ATMs: " .. (state and "开启" or "关闭"),
            Duration = 5
        })
        saveConfig()
        
        if state then
            spawn(function()
                task.wait(0.5)
                if performAutoRobATMs then
                    pcall(performAutoRobATMs)
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

        local cleanText = text:gsub(",", "")
        local num = tonumber(cleanText)
        
        debugLog("[数字转换] 清理后的文本:", cleanText)
        debugLog("[数字转换] 转换后的数字:", num)
        
        if num and num > 0 then
            local currentCurrency = fetchCurrentCurrency() or 0
            debugLog("[金额获取] 当前游戏金额:", currentCurrency)
            
            local newTarget = num + currentCurrency
            debugLog("[计算] 基准金额:", num)
            debugLog("[计算] 当前金额:", currentCurrency)
            debugLog("[计算] 目标金额:", newTarget)
            
            -- 设置配置
            config.baseAmount = num
            config.targetAmount = newTarget
            config.lastSavedCurrency = currentCurrency
            
            debugLog("[赋值后] config.baseAmount:", config.baseAmount)
            debugLog("[赋值后] config.targetAmount:", config.targetAmount)
            debugLog("[赋值后] config.lastSavedCurrency:", config.lastSavedCurrency)
            
            baseAmountInput.Text = formatNumber(num)
            
            if targetAmountLabel then
                targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
                debugLog("[标签更新] 目标金额标签已更新为:", formatNumber(newTarget))
            end
            
            saveConfig()
            
            debugLog("[保存验证] 保存后 config.baseAmount:", config.baseAmount)
            debugLog("[保存验证] 保存后 config.targetAmount:", config.targetAmount)
            debugLog("[保存验证] 保存后 config.lastSavedCurrency:", config.lastSavedCurrency)
            
            UILibrary:Notify({
                Title = "基准金额已设置",
                Text = string.format("基准金额: %s\n当前金额: %s\n目标金额: %s", 
                    formatNumber(num), 
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
        
        local newTarget = config.baseAmount + currentCurrency
        
        debugLog("[重新计算] 使用基准金额:", config.baseAmount)
        debugLog("[重新计算] 当前游戏金额:", currentCurrency)
        debugLog("[重新计算] 计算的新目标:", newTarget)
        
        if newTarget <= currentCurrency then
            UILibrary:Notify({
                Title = "计算错误",
                Text = string.format("计算后的目标金额(%s)不能小于等于当前金额(%s)", 
                    formatNumber(newTarget), formatNumber(currentCurrency)),
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
        
        debugLog("[重新计算保存后] config.targetAmount:", config.targetAmount)
        debugLog("[重新计算保存后] config.lastSavedCurrency:", config.lastSavedCurrency)
        
        UILibrary:Notify({
            Title = "目标金额已重新计算",
            Text = string.format("基准金额: %s\n当前金额: %s\n新目标金额: %s", 
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

-- 主循环
local unchangedCount = 0
local webhookDisabled = false
local startTime = os.time()
local lastCurrency = nil
local checkInterval = 1

spawn(function()
    while true do
        local currentTime = os.time()
        local currentCurrency = fetchCurrentCurrency()

        local earnedAmount = calculateEarnedAmount(currentCurrency)
        earnedCurrencyLabel.Text = "已赚金额: " .. formatNumber(earnedAmount)

        local shouldShutdown = false

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