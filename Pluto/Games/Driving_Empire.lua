-- 服务
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")
local UserInputService = game:GetService("UserInputService")

-- Bypass
local BypassActive = true
local HookInstalled = false
local BlockCount = 0

-- 黑名单
local TargetRemotes = {
    ["StarwatchClientEventIngestor"] = true, ["_network"] = true,
    ["rsp"] = true, ["rps"] = true, ["rsi"] = true, ["rs"] = true, ["rsw"] = true,
    ["ptsstop"] = true, ["ptsstart"] = true, ["SdkTelemetryRemote"] = true,
    ["TeleportInfo"] = true, ["SendLogString"] = true, ["GetClientLogs"] = true,
    ["GetClientFPS"] = true, ["GetClientPing"] = true, ["GetClientMemoryUsage"] = true,
    ["GetClientPerformanceStats"] = true, ["GetClientReport"] = true,
    ["RepBL"] = true, ["UnauthorizedTeleport"] = true, ["ClientDetectedSoftlock"] = true,
    ["loadTime"] = true, ["InformLoadingEventFunnel"] = true, ["InformGeneralEventFunnel"] = true
}

-- 安装钩子
local function InstallEarlyHook()
    if HookInstalled then return end
    
    local success, err = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if BypassActive and (method == "FireServer" or method == "InvokeServer") then
                local remoteName = tostring(self)
                local shouldBlock = false
                
                -- A. 检查黑名单名称
                if TargetRemotes[remoteName] then
                    shouldBlock = true
                end
                
                -- B. 检查动态ID (8位十六进制 + 连字符)
                if not shouldBlock and string.match(remoteName, "^%x%x%x%x%x%x%x%x%-") then
                    shouldBlock = true
                end
                
                -- C. 特定阻断: Location -> Boats
                if not shouldBlock and remoteName == "Location" and args[1] == "Enter" and args[2] == "Boats" then
                    shouldBlock = true
                end

                -- 执行阻断
                if shouldBlock then
                    BlockCount = BlockCount + 1
                    return nil 
                end
            end
            
            return oldNamecall(self, ...)
        end)
    end)
    
    if success then
        HookInstalled = true
        print("[BYPASS] Hook 安装成功")
    else
        warn("[BYPASS] 关键错误: " .. tostring(err))
    end
end

InstallEarlyHook()

-- 监控循环
task.spawn(function()
    while true do
        if BypassActive then
            local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
            if remotesFolder then
                local children = remotesFolder:GetChildren()
                for _, remote in ipairs(children) do
                    local n = remote.Name
                    if string.match(n, "^%x%x%x%x%x%x%x%x%-") and not TargetRemotes[n] then
                        TargetRemotes[n] = true
                    end
                end
            end
        end
        task.wait(2)
    end
end)

_G.PRIMARY_COLOR = 5793266
local lastSendTime = os.time()
local sendingWelcome = false
local isAutoRobActive = false
local isDeliveryInProgress = false

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

-- PlutoX
local plutoSuccess, PlutoX = pcall(function()
    local url = "https://api.959966.xyz/github/raw/TongScriptX/Pluto/refs/heads/develop/Pluto/Common/PlutoX-Notifier.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if not plutoSuccess or not PlutoX then
    error("[PlutoX] 模块加载失败！请检查网络连接或链接是否有效：" .. tostring(PlutoX))
end

-- UI
local UILibrary
local success, result = pcall(function()
    local url
    if PlutoX.debugEnabled then
        url = "https://api.959966.xyz/github/raw/TongScriptX/Pluto/refs/heads/develop/Pluto/UILibrary/PlutoUILibrary.lua"
    else
        url = "https://api.959966.xyz/github/raw/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
    end
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if success and result then
    UILibrary = result
else
    error("[PlutoUILibrary] 加载失败！请检查网络连接或链接是否有效：" .. tostring(result))
end

-- 玩家信息
local player = Players.LocalPlayer
if not player then
    error("无法获取当前玩家")
end

local userId = player.UserId
local username = player.Name

local gameName = "Driving Empire"
do
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if success and info then
        gameName = info.Name
    end
end

-- 游戏信息
PlutoX.setGameInfo(gameName, username, HttpService)

-- 游戏功能
local function teleportCharacterTo(targetCFrame)
    if not player.Character or not player.Character.PrimaryPart then
        PlutoX.warn("[Teleport] 角色或主要部件不存在")
        return false
    end
    
    local vehicles = workspace:FindFirstChild("Vehicles")
    local vehicle = vehicles and vehicles:FindFirstChild(username)
    local seat = vehicle and vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
    
    if seat and vehicle then
        vehicle:PivotTo(targetCFrame)
    else
        player.Character:SetPrimaryPartCFrame(targetCFrame)
    end
    
    return true
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
        return false
    end
    return true
end

-- 数据类型
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
    calculateAvg = true,
    supportTarget = true
})

-- API 排行榜
local function fetchLeaderboardFromAPI()
    if not PlutoX.uploaderHttpService then
        return nil, false
    end
    
    local success, result = pcall(function()
        local apiUrl = "https://api.959966.xyz/api/dashboard/leaderboard"
        local queryParams = string.format("?game_name=%s&username=%s", 
            PlutoX.uploaderHttpService:UrlEncode(gameName), 
            PlutoX.uploaderHttpService:UrlEncode(username))
        
        local response = game:HttpGet(apiUrl .. queryParams, false)
        local responseJson = PlutoX.uploaderHttpService:JSONDecode(response)
        
        if responseJson.success and responseJson.data then
            return responseJson.data, true
        else
            return nil, false
        end
    end)
    
    if success then
        return result, true
    else
        return nil, false
    end
end

-- 查找排名
local function findPlayerRankInLeaderboard(leaderboardData)
    if not leaderboardData or type(leaderboardData) ~= "table" then
        return nil, false
    end
    
    for _, entry in ipairs(leaderboardData) do
        if entry.user_id == userId then
            return entry.rank, true
        end
    end
    
    return nil, false
end

-- 上传排行榜
local function uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
    if not PlutoX.uploaderHttpService then
        return false
    end
    
    if #leaderboardEntries == 0 then
        return false
    end
    
    
    local success, result = pcall(function()
        local uploadUrl = "https://api.959966.xyz/api/dashboard/leaderboard"
        local requestBody = {
            game_user_id = "ee9aecb5-ab12-48c4-83c9-892b49b27e0d",
            game_name = gameName,
            username = username,
            leaderboard_data = leaderboardEntries
        }
        
        local maxRetries = 3
        local retryDelay = 2
        
        for attempt = 1, maxRetries do
            local response = game:HttpPost(uploadUrl, PlutoX.uploaderHttpService:JSONEncode(requestBody), false)
            local responseJson = PlutoX.uploaderHttpService:JSONDecode(response)
            
            if responseJson.success then
                return true
            elseif attempt < maxRetries then
                PlutoX.warn("[排行榜] 上传失败（尝试 " .. attempt .. "/" .. maxRetries .. "），" .. retryDelay .. "秒后重试: " .. tostring(responseJson.error))
                task.wait(retryDelay)
                retryDelay = retryDelay * 2
            else
                PlutoX.warn("[排行榜] 排行榜数据上传失败: " .. tostring(responseJson.error))
                return false
            end
        end
        
        return false
    end)
    
    if success then
        leaderboardConfig.lastUploadTime = tick()
        return result
    else
        PlutoX.warn("[排行榜] 排行榜数据上传出错: " .. tostring(result))
        return false
    end
end

-- 上传排行榜
local function uploadLeaderboardToWebsite(contents)
    if not PlutoX.uploaderHttpService then
        return false
    end
    
    local leaderboardEntries = {}
    
    -- 如果没有传入 contents，尝试从UI获取
    if not contents then
        contents = tryGetContents(2)
        if not contents then
            return false
        end
    end
    
    -- 遍历排行榜，提取所有玩家的数据
    for _, child in ipairs(contents:GetChildren()) do
        local childId = tonumber(child.Name)
        if childId then
            local placement = child:FindFirstChild("Placement")
            local rank = placement and placement:IsA("IntValue") and placement.Value or 0
            table.insert(leaderboardEntries, {
                user_id = childId,
                rank = rank
            })
        end
    end
    
    return uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
end

-- 排行榜配置
local leaderboardConfig = {
    position = Vector3.new(-895.0263671875, 202.07171630859375, -1630.81689453125),
    streamTimeout = 10,
    cacheTime = 300,
    failCacheTime = 30,
    websiteCacheTime = 1800,
    lastFetchTime = 0,
    lastUploadTime = 0,
    cachedRank = nil,
    cachedIsOnLeaderboard = false,
    lastFetchSuccess = false,
    isFetching = false,
    hasFetched = false,
    uploadCooldown = 1800,
    lastAPICheckTime = 0,
    apiCheckInterval = 60,
}

local function tryGetContents(timeout)
    local ok, result = pcall(function()
        
        local Game = workspace:FindFirstChild("Game")
        if not Game then
            return nil
        end
        
        local Leaderboards = Game:FindFirstChild("Leaderboards")
        if not Leaderboards then
            return nil
        end
        
        local LeaderboardsChildren = {}
        for _, child in ipairs(Leaderboards:GetChildren()) do
            table.insert(LeaderboardsChildren, child.Name)
        end
        
        local weekly_money = Leaderboards:FindFirstChild("weekly_money")
        if not weekly_money then
            return nil
        end
        
        local weeklyChildren = weekly_money:GetChildren()
        if #weeklyChildren > 0 then
            local childrenInfo = {}
            for _, child in ipairs(weeklyChildren) do
                local className = child.ClassName or "Unknown"
                table.insert(childrenInfo, child.Name .. "(" .. className .. ")")
            end
        else
        end
        
        local Screen = weekly_money:FindFirstChild("Screen")
        if not Screen then
            return nil
        end
        
        local Leaderboard = Screen:FindFirstChild("Leaderboard")
        if not Leaderboard then
            return nil
        end
        
        local Contents = Leaderboard:FindFirstChild("Contents")
        if not Contents then
            return nil
        end
        
        local childrenCount = #Contents:GetChildren()
        
        -- 输出前5个子元素名称
        local sampleChildren = {}
        for i, child in ipairs(Contents:GetChildren()) do
            if i <= 5 then
                table.insert(sampleChildren, child.Name)
            else
                break
            end
        end
        if #sampleChildren > 0 then
        end
        
        return Contents
    end)
    
    if not ok then
    end
    
    return ok and result or nil
end

local function parseContents(contents)
    local rank = 1
    local leaderboardList = {}
    local childrenCount = #contents:GetChildren()
    
    
    -- 输出完整榜单（仅在首次检测时输出）
    if not leaderboardConfig.hasFetched then
        for _, child in ipairs(contents:GetChildren()) do
            -- 跳过模板元素
            if tonumber(child.Name) then
                local placement = child:FindFirstChild("Placement")
                local foundRank = placement and placement:IsA("IntValue") and placement.Value or rank
                table.insert(leaderboardList, string.format("#%d: %s", foundRank, child.Name))
                rank = rank + 1
            end
        end
        
        -- 输出榜单列表
        for _, entry in ipairs(leaderboardList) do
        end
    else
        -- 已缓存，只收集数据不输出
        for _, child in ipairs(contents:GetChildren()) do
            if tonumber(child.Name) then
                rank = rank + 1
            end
        end
    end
    
    -- 查找玩家排名
    rank = 1
    local foundEntries = 0
    for _, child in ipairs(contents:GetChildren()) do
        -- 跳过模板元素（只检查数字ID）
        local childId = tonumber(child.Name)
        if childId then
            foundEntries = foundEntries + 1
            if childId == userId then
                local placement = child:FindFirstChild("Placement")
                local foundRank = placement and placement:IsA("IntValue") and placement.Value or rank
                return foundRank, true
            end
            rank = rank + 1
        end
    end
    return nil, false
end

local function fetchPlayerRank()
    local currentTime = tick()
    
    -- 如果正在获取中，返回缓存值（如果有）
    if leaderboardConfig.isFetching then
        return leaderboardConfig.cachedRank, leaderboardConfig.cachedIsOnLeaderboard
    end
    
    -- 首先尝试从API获取排行榜数据（优先使用网站数据）
    if (currentTime - (leaderboardConfig.lastAPICheckTime or 0)) >= leaderboardConfig.apiCheckInterval then
        leaderboardConfig.isFetching = true
        leaderboardConfig.lastAPICheckTime = currentTime
        
        spawn(function()
            local apiData, apiSuccess = fetchLeaderboardFromAPI()
            -- 只有API返回非空数据时才使用API数据
            if apiSuccess and apiData and #apiData > 0 then
                local rank, isOnLeaderboard = findPlayerRankInLeaderboard(apiData)
                leaderboardConfig.cachedRank = rank
                leaderboardConfig.cachedIsOnLeaderboard = isOnLeaderboard
                leaderboardConfig.lastFetchTime = currentTime
                leaderboardConfig.lastFetchSuccess = true
                leaderboardConfig.hasFetched = true
                leaderboardConfig.isFetching = false
                
            else
                -- API没有数据或调用失败，继续从游戏中获取
                -- 临时保存isFetching状态，因为fetchPlayerRankFromGame会修改它
                local wasFetching = leaderboardConfig.isFetching
                leaderboardConfig.isFetching = true
                
                -- 直接从游戏中获取
                local gameRank, gameIsOnLeaderboard = nil, false
                local leaderboardEntries = nil
                
                -- 尝试直接获取
                local contents = tryGetContents(2)
                if contents then
                    gameRank, gameIsOnLeaderboard = parseContents(contents)
                    
                    -- 提取排行榜数据用于上传
                    if apiSuccess and apiData and #apiData == 0 then
                        -- API返回0条数据，需要上传游戏内获取的数据
                        leaderboardEntries = {}
                        local entryRank = 1
                        for _, child in ipairs(contents:GetChildren()) do
                            local childId = tonumber(child.Name)
                            if childId then
                                local placement = child:FindFirstChild("Placement")
                                local rank = placement and placement:IsA("IntValue") and placement.Value or entryRank
                                table.insert(leaderboardEntries, {
                                    user_id = childId,
                                    rank = rank
                                })
                                entryRank = entryRank + 1
                            end
                        end
                        
                        -- 立即上传排行榜数据（API返回0条时）
                        if leaderboardEntries and #leaderboardEntries > 0 then
                            spawn(function()
                                pcall(function()
                                    uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
                                end)
                            end)
                        end
                    end
                else
                    -- 尝试远程加载
                    pcall(function()
                        player:RequestStreamAroundAsync(leaderboardConfig.position, leaderboardConfig.streamTimeout)
                    end)
                    
                    wait(1)
                    contents = tryGetContents(1)
                    if contents then
                        gameRank, gameIsOnLeaderboard = parseContents(contents)
                        
                        -- 提取排行榜数据用于上传（如果 API 返回 0 条数据）
                        if apiSuccess and apiData and #apiData == 0 then
                            leaderboardEntries = {}
                            local entryRank = 1
                            for _, child in ipairs(contents:GetChildren()) do
                                local childId = tonumber(child.Name)
                                if childId then
                                    local placement = child:FindFirstChild("Placement")
                                    local rank = placement and placement:IsA("IntValue") and placement.Value or entryRank
                                    table.insert(leaderboardEntries, {
                                        user_id = childId,
                                        rank = rank
                                    })
                                    entryRank = entryRank + 1
                                end
                            end
                            
                            -- 立即上传排行榜数据（API返回0条时）
                            if leaderboardEntries and #leaderboardEntries > 0 then
                                spawn(function()
                                    pcall(function()
                                        uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
                                    end)
                                end)
                            end
                        end
                    else
                        -- 远程加载也失败，尝试传送玩家到排行榜位置
                        
                        -- 保存玩家当前位置
                        local character = player.Character
                        local originalPosition = nil
                        local originalVehicle = nil
                        
                        if character and character.PrimaryPart then
                            originalPosition = character.PrimaryPart.CFrame
                            
                            -- 检查玩家是否在车辆中
                            local vehicles = workspace:FindFirstChild("Vehicles")
                            if vehicles then
                                originalVehicle = vehicles:FindFirstChild(username)
                            end
                        end
                        
                        if originalPosition then
                            -- 保存速度状态
                            local savedVelocities = {}
                            if originalVehicle then
                                for _, part in ipairs(originalVehicle:GetDescendants()) do
                                    if part:IsA("BasePart") then
                                        savedVelocities[part] = {
                                            velocity = part.Velocity,
                                            rotVelocity = part.RotVelocity
                                        }
                                    end
                                end
                            elseif character and character.PrimaryPart then
                                for _, part in ipairs(character:GetDescendants()) do
                                    if part:IsA("BasePart") then
                                        savedVelocities[part] = {
                                            velocity = part.Velocity,
                                            rotVelocity = part.RotVelocity
                                        }
                                    end
                                end
                            end
                            
                            -- 传送函数
                            local function teleport(position)
                                if originalVehicle then
                                    originalVehicle:PivotTo(position)
                                else
                                    character:PivotTo(position)
                                end
                            end
                            
                            -- 恢复速度函数
                            local function restoreVelocities()
                                for part, state in pairs(savedVelocities) do
                                    if part and part:IsA("BasePart") then
                                        part.Velocity = state.velocity
                                        part.RotVelocity = state.rotVelocity
                                    end
                                end
                            end
                            
                            -- 传送到排行榜位置
                            local targetCFrame = CFrame.new(leaderboardConfig.position)
                            teleport(targetCFrame)
                            
                            -- 等待排行榜 UI 加载
                            task.wait(1)
                            
                            -- 传送前初始化 leaderboardEntries
                            leaderboardEntries = leaderboardEntries or {}
                            
                            contents = tryGetContents(1)
                            if contents then
                                local childrenCount = #contents:GetChildren()
                                gameRank, gameIsOnLeaderboard = parseContents(contents)
                                
                                -- 提取排行榜数据（确保rank为正数）
                                local rankCounter = 1
                                for _, child in ipairs(contents:GetChildren()) do
                                    local childId = tonumber(child.Name)
                                    if childId then
                                        local placement = child:FindFirstChild("Placement")
                                        local rank = placement and placement:IsA("IntValue") and placement.Value or rankCounter
                                        -- 确保rank为正数（rankCounter从1开始）
                                        if rank <= 0 then
                                            rank = rankCounter
                                        end
                                        table.insert(leaderboardEntries, {
                                            user_id = childId,
                                            rank = rank
                                        })
                                        rankCounter = rankCounter + 1
                                    end
                                end
                                
                                -- 立即传送回原位置并恢复速度
                                teleport(originalPosition)
                                restoreVelocities()
                                
                                -- 上传排行榜
                                local shouldUpload = false
                                if apiSuccess and apiData and #apiData == 0 then
                                    -- API返回0条数据，立即上传
                                    shouldUpload = true
                                elseif (tick() - (leaderboardConfig.lastUploadTime or 0)) >= leaderboardConfig.uploadCooldown then
                                    -- 冷却时间已到，允许上传
                                    shouldUpload = true
                                else
                                end
                                
                                if shouldUpload and leaderboardEntries and #leaderboardEntries > 0 then
                                    spawn(function()
                                        pcall(function()
                                            uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
                                        end)
                                    end)
                                end
                            else
                                -- 传送回原位置
                                teleport(originalPosition)
                                restoreVelocities()
                            end
                        else
                        end
                    end
                end
                
                -- 更新缓存
                leaderboardConfig.cachedRank = gameRank
                leaderboardConfig.cachedIsOnLeaderboard = gameIsOnLeaderboard
                leaderboardConfig.lastFetchTime = currentTime
                leaderboardConfig.lastFetchSuccess = (gameRank ~= nil)
                leaderboardConfig.hasFetched = true
                leaderboardConfig.isFetching = false
                
            end
        end)
        
        -- 等待API检查完成（最多1秒）
        local startTime = tick()
        while leaderboardConfig.isFetching and (tick() - startTime) < 1 do
            wait(0.1)
        end
        
        return leaderboardConfig.cachedRank, leaderboardConfig.cachedIsOnLeaderboard
    end
    
    -- API检查间隔内，直接返回缓存值
    return leaderboardConfig.cachedRank, leaderboardConfig.cachedIsOnLeaderboard
end

-- 游戏排行榜
local function fetchPlayerRankFromGame(currentTime)
    local currentTime = currentTime or tick()
    
    -- 如果已经获取过且缓存未过期，直接返回缓存值
    if leaderboardConfig.hasFetched then
        -- 根据上次获取是否成功决定使用哪个缓存时间
        local cacheTime = leaderboardConfig.lastFetchSuccess and leaderboardConfig.cacheTime or leaderboardConfig.failCacheTime
        if (currentTime - leaderboardConfig.lastFetchTime) < cacheTime then
            -- 移除频繁输出的缓存日志
            return leaderboardConfig.cachedRank, leaderboardConfig.cachedIsOnLeaderboard
        end
    end
    
    -- 开始新获取
    leaderboardConfig.isFetching = true
    
    local contents = tryGetContents(2)
    if contents then
        local rank, isOnLeaderboard = parseContents(contents)
        -- 更新缓存
        leaderboardConfig.cachedRank = rank
        leaderboardConfig.cachedIsOnLeaderboard = isOnLeaderboard
        leaderboardConfig.lastFetchTime = currentTime
        leaderboardConfig.lastFetchSuccess = true
        leaderboardConfig.hasFetched = true
        leaderboardConfig.isFetching = false
        
        -- 上传排行榜
        if (tick() - (leaderboardConfig.lastUploadTime or 0)) >= leaderboardConfig.uploadCooldown then
            spawn(function()
                pcall(function()
                    uploadLeaderboardToWebsite()
                end)
            end)
        else
        end

        return rank, isOnLeaderboard
    end
    
    
    local success, err = pcall(function()
        player:RequestStreamAroundAsync(leaderboardConfig.position, leaderboardConfig.streamTimeout)
    end)
    
    if not success then
        PlutoX.warn("[排行榜] RequestStreamAroundAsync 失败: " .. tostring(err))
        -- 失败时设置较短的缓存时间（30秒），避免频繁重试
        leaderboardConfig.cachedRank = nil
        leaderboardConfig.cachedIsOnLeaderboard = false
        leaderboardConfig.lastFetchTime = currentTime
        leaderboardConfig.lastFetchSuccess = false
        leaderboardConfig.hasFetched = true
        leaderboardConfig.isFetching = false
        return nil, false
    end
    
    
    -- 轮询检测排行榜是否加载完成
    local checkStartTime = tick()
    local maxCheckTime = leaderboardConfig.streamTimeout
    local checkInterval = 0.5
    local pollCount = 0
    
    while (tick() - checkStartTime) < maxCheckTime do
        pollCount = pollCount + 1
        wait(checkInterval)
        local elapsed = tick() - checkStartTime
        
        contents = tryGetContents(1)
        if contents then
            local childrenCount = #contents:GetChildren()
            local rank, isOnLeaderboard = parseContents(contents)
            -- 更新缓存
            leaderboardConfig.cachedRank = rank
            leaderboardConfig.cachedIsOnLeaderboard = isOnLeaderboard
            leaderboardConfig.lastFetchTime = currentTime
            leaderboardConfig.lastFetchSuccess = true
            leaderboardConfig.hasFetched = true
            leaderboardConfig.isFetching = false
            
            -- 上传排行榜
            if (tick() - (leaderboardConfig.lastUploadTime or 0)) >= leaderboardConfig.uploadCooldown then
                spawn(function()
                    pcall(function()
                        uploadLeaderboardToWebsite()
                    end)
                end)
            else
            end
            
            return rank, isOnLeaderboard
        end
    end
    
    
    -- 保存玩家当前位置
    local character = player.Character
    local originalPosition = nil
    local originalVehicle = nil
    
    if character and character.PrimaryPart then
        originalPosition = character.PrimaryPart.CFrame
        
        -- 检查玩家是否在车辆中
        local vehicles = workspace:FindFirstChild("Vehicles")
        if vehicles then
            originalVehicle = vehicles:FindFirstChild(username)
        end
    end
    
    if not originalPosition then
        PlutoX.warn("[排行榜] 无法获取玩家位置，无法传送")
        leaderboardConfig.cachedRank = nil
        leaderboardConfig.cachedIsOnLeaderboard = false
        leaderboardConfig.lastFetchTime = currentTime
        leaderboardConfig.lastFetchSuccess = false
        leaderboardConfig.hasFetched = true
        leaderboardConfig.isFetching = false
        return nil, false
    end
    
    
    -- 保存所有部件的速度状态
    local savedVelocities = {}
    if originalVehicle then
        for _, part in ipairs(originalVehicle:GetDescendants()) do
            if part:IsA("BasePart") then
                savedVelocities[part] = {
                    velocity = part.Velocity,
                    rotVelocity = part.RotVelocity
                }
            end
        end
    elseif character and character.PrimaryPart then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                savedVelocities[part] = {
                    velocity = part.Velocity,
                    rotVelocity = part.RotVelocity
                }
            end
        end
    end
    
    -- 传送函数
    local function teleport(position)
        if originalVehicle then
            originalVehicle:PivotTo(position)
        else
            character:PivotTo(position)
        end
    end
    
    -- 恢复速度函数
    local function restoreVelocities()
        for part, state in pairs(savedVelocities) do
            if part and part:IsA("BasePart") then
                part.Velocity = state.velocity
                part.RotVelocity = state.rotVelocity
            end
        end
    end
    
    -- 传送到排行榜位置
    local targetCFrame = CFrame.new(leaderboardConfig.position)
    teleport(targetCFrame)
    
    -- 等待排行榜 UI 加载
    task.wait(1)
    
    -- 检查排行榜是否加载
    contents = tryGetContents(1)
    if contents then
        local childrenCount = #contents:GetChildren()
        local rank, isOnLeaderboard = parseContents(contents)
        
        -- 立即传送回原位置并恢复速度
        teleport(originalPosition)
        restoreVelocities()
        
-- 上传排行榜
        if (tick() - (leaderboardConfig.lastUploadTime or 0)) >= leaderboardConfig.uploadCooldown then
            spawn(function()
                pcall(function()
                    uploadLeaderboardToWebsite()
                end)
            end)
        else
        end
        
        -- 立即传送回原位置并恢复速度
        teleport(originalPosition)
        restoreVelocities()
        
        -- 设置较短的缓存时间（30秒），避免频繁重试
        leaderboardConfig.cachedRank = nil
        leaderboardConfig.cachedIsOnLeaderboard = false
        leaderboardConfig.lastFetchTime = currentTime
        leaderboardConfig.lastFetchSuccess = false
        leaderboardConfig.hasFetched = true
        leaderboardConfig.isFetching = false
        return nil, false
    end
end

-- 排行榜
PlutoX.registerDataType({
    id = "leaderboard",
    name = "排行榜排名",
    icon = "🏆",
    fetchFunc = function()
        -- 异步获取排行榜数据，避免阻塞主循环
        local result = nil  -- 未上榜时返回 nil
        local completed = false

        spawn(function()
            local rank, isOnLeaderboard = fetchPlayerRank()
            if isOnLeaderboard then
                result = rank
            end
            completed = true
        end)

        -- 等待最多 2 秒，避免长时间阻塞
        local startTime = tick()
        while not completed and (tick() - startTime) < 2 do
            wait(0.1)
        end

        return result
    end,
    calculateAvg = false,
    supportTarget = false,
    formatFunc = function(value)
        if type(value) == "number" then
            return "#" .. tostring(value)
        end
        return value or "未上榜"
    end
})

-- 自动生成
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


-- 在线奖励
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

-- ATM 抢劫
local function getRobbedAmount()
    local success, amount = pcall(function()
        local character = workspace:FindFirstChild(player.Name)
        if not character then return 0 end
        local head = character:FindFirstChild("Head")
        if not head then return 0 end
        local billboard = head:FindFirstChild("CharacterBillboard")
        if not billboard then return 0 end
        
        -- 遍历查找包含金额的 TextLabel（以 $ 开头的内容）
        for _, child in ipairs(billboard:GetChildren()) do
            if child:IsA("TextLabel") and child.ContentText then
                local text = child.ContentText
                if text:find("^%$") or text:find("^%$[%d,]+") then
                    local cleanText = text:gsub("[$,]", "")
                    local num = tonumber(cleanText)
                    if num and num > 0 then
                        return num
                    end
                end
            end
        end
        return 0
    end)
    
    if success then
        return amount or 0
    else
        PlutoX.warn("[AutoRob] 获取已抢金额失败:", amount)
        return 0
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
        return dropOffPoint.Enabled
    else
        return false
    end
end



local function checkRobberyCompletion(previousAmount)
    local currentAmount = getRobbedAmount()
    local change = currentAmount - (previousAmount or 0)
    
    if change > 0 then
        return true, change
    elseif change < 0 then
        return false, change
    else
        return false, 0
    end
end

local function enhancedDeliveryFailureRecovery(robbedAmount, originalTarget, tempTargetRef)
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
    end

    task.wait(1)

    local currentRobbedAmount = getRobbedAmount() or 0

    if currentRobbedAmount > 0 then
        local retrySuccess = sellMoney()

        if retrySuccess then
            return true, retryDelivered
        end
    end

    local newTempTarget = currentRobbedAmount + originalTarget
    tempTargetRef.value = newTempTarget

    return false, 0
end

-- 初始化
local configFile = "PlutoX/Driving_Empire_config.json"

local dataTypes = PlutoX.getAllDataTypes()
local dataTypeConfigs = PlutoX.generateDataTypeConfigs(dataTypes)

local defaultConfig = {
    webhookUrl = "",
    notificationInterval = 30,
    onlineRewardEnabled = false,
    autoSpawnVehicleEnabled = false,
    autoFarmSpeed = 300,
    robTargetAmount = 0,
    notifyCash = false,
    notifyLeaderboard = false,
    leaderboardKick = false,
}

-- AutoFarm 默认关闭
local autoFarmEnabled = false

for key, value in pairs(dataTypeConfigs) do
    defaultConfig[key] = value
end

local configManager = PlutoX.createConfigManager(configFile, HttpService, UILibrary, username, defaultConfig)
local config = configManager:loadConfig()

-- 出售
local function sellMoney()
    local player = game.Players.LocalPlayer
    local sellPos1 = Vector3.new(-2520.495849609375, 15.116586685180664, 4035.560791015625)
    local sellPos2 = Vector3.new(-2542.12646484375, 15.116586685180664, 4030.9150390625)
    local currentAmount = getRobbedAmount() or 0
    
    if currentAmount <= 0 then
        return false
    end
    
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char:PivotTo(CFrame.new(sellPos1 + Vector3.new(0, 3, 0)))
    end
    task.wait(0.5)
    
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if human and root then
        human:MoveTo(sellPos2)
        local startT = tick()
        while (root.Position - sellPos2).Magnitude > 3 and tick() - startT < 2 do task.wait(0.1) end
    end
    
    task.wait(2)
    
    local sellStart = tick()
    repeat
        task.wait(0.3)
        currentAmount = getRobbedAmount() or 0
    until currentAmount == 0 or tick() - sellStart > 10
    
    if currentAmount == 0 then
        UILibrary:Notify({ Title = "出售成功", Text = "金额已清零", Duration = 5 })
        return true
    else
        UILibrary:Notify({ Title = "出售未完成", Text = "金额未清零", Duration = 3 })
        return false
    end
end

-- checkAndForceDelivery 函数
local function checkAndForceDelivery(tempTarget)
    local robbedAmount = getRobbedAmount() or 0
    local targetAmount = tempTarget or config.robTargetAmount or 0

    if targetAmount > 0 and robbedAmount >= targetAmount then
        local dropOffEnabled = checkDropOffPointEnabled()

        if not dropOffEnabled then
            return false, 0, 0
        end

        local success = sellMoney()

        if success then
            UILibrary:Notify({
                Title = "目标达成",
                Text = string.format("获得 +%s\n尝试次数: %d", formatNumber(deliveredAmount), attempts),
                Duration = 5
            })

            task.wait(2)
            return true
        else
            return false, attempts, 0
        end
    end

    return false
end

-- monitorDropOffStatusAndUpdateTarget 函数
local lastDropOffEnabledStatus = nil

local function monitorDropOffStatusAndUpdateTarget()
    local currentStatus = checkDropOffPointEnabled()
    
    if lastDropOffEnabledStatus == nil then
        lastDropOffEnabledStatus = currentStatus
        return false
    end
    
    if not lastDropOffEnabledStatus and currentStatus then
        local currentRobbedAmount = getRobbedAmount() or 0
        if currentRobbedAmount > 0 then
            config.robTargetAmount = currentRobbedAmount
            configManager:saveConfig()
            
            UILibrary:Notify({
                Title = "目标金额已更新",
                Text = string.format("交付点可用，目标金额更新为: %s", formatNumber(currentRobbedAmount)),
                Duration = 5
            })
        end
        
        lastDropOffEnabledStatus = currentStatus
        return true
    end
    
    lastDropOffEnabledStatus = currentStatus
    return false
end

local function claimPlaytimeRewards()
    if not config.onlineRewardEnabled then
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
                PlutoX.warn("[PlaytimeRewards] 未找到奖励界面")
                task.wait(rewardCheckInterval)
            else
                local statsGui
                for _, v in ipairs(gui:GetChildren()) do
                    if v:IsA("ScreenGui") and v.Name:find("'s Stats") then
                        statsGui = v
                        break
                    end
                end

                if not statsGui then
                    PlutoX.warn("[PlaytimeRewards] 未找到玩家 Stats")
                    task.wait(rewardCheckInterval)
                else
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
                        task.wait(rewardCheckInterval)
                    else
                        local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
                        local uiInteraction = remotes and remotes:FindFirstChild("UIInteraction")
                        local playRewards = remotes and remotes:FindFirstChild("PlayRewards")

                        if not uiInteraction or not playRewards then
                            PlutoX.warn("[PlaytimeRewards] 未找到远程事件")
                            task.wait(rewardCheckInterval)
                        else
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
                                    end)
                                    task.wait(0.4)
                                end
                            end
                            task.wait(rewardCheckInterval)
                        end
                    end
                end
            end
        end
    end)
end

-- AutoFarm
local isAutoFarmActive = false
local autoFarmOriginalPosition = nil

local function performAutoFarm()
    if not autoFarmEnabled then return end
    isAutoFarmActive = true
    PlutoX.debug("[AutoFarm] 开始执行 AutoFarm")

    -- 循环刷金位置配置
    local loopPos = Vector3.new(-25453.49, 34.09, -14927.61)
    local moveDuration = 20 -- 移动20秒
    local returnDuration = 20 -- 返回20秒

    -- 获取最近的 Road Marker 及其方向（在 1000 范围内搜索）
    local function getNearestRoadMarker(position, maxDistance)
        maxDistance = maxDistance or 1000
        local roads = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Roads")
        if not roads then return nil end

        local nearestMarker = nil
        local minDistance = math.huge

        for _, roadGroup in ipairs(roads:GetChildren()) do
            for _, marker in ipairs(roadGroup:GetChildren()) do
                if marker:IsA("BasePart") and marker.Name == "Road Marker" then
                    local distance = (marker.Position - position).Magnitude
                    if distance < minDistance and distance <= maxDistance then
                        minDistance = distance
                        nearestMarker = marker
                    end
                end
            end
        end

        return nearestMarker
    end

    -- 从 Marker 获取右向量（道路延伸方向）
    local function getMarkerDirection(marker)
        local components = {marker.CFrame:GetComponents()}
        -- 右向量 (X轴) = (R00, R10, R20) = components[4, 7, 10]
        return Vector3.new(components[4], components[7], components[10]).Unit
    end

    spawn(function()
        while isAutoFarmActive and autoFarmEnabled do
            local success, err = pcall(function()
                local localPlayer = Players.LocalPlayer
                if not localPlayer then return end

                local character = localPlayer.Character
                if not character then return end

                -- 获取玩家车辆
                local vehicles = workspace:FindFirstChild("Vehicles")
                if not vehicles then return end

                local vehicle = vehicles:FindFirstChild(localPlayer.Name)
                if not vehicle then
                    PlutoX.debug("[AutoFarm] 未找到车辆，等待...")
                    return
                end
                
                PlutoX.debug("[AutoFarm] 找到车辆，准备传送")

                -- 寻找最近的 Road Marker
                local nearestMarker = getNearestRoadMarker(loopPos)
                local direction
                local targetPos = loopPos

                if nearestMarker then
                    direction = getMarkerDirection(nearestMarker)
                    targetPos = Vector3.new(loopPos.X, nearestMarker.Position.Y, loopPos.Z)
                    local newCFrame = CFrame.lookAt(targetPos, targetPos + direction)
                    vehicle:PivotTo(newCFrame)
                else
                    direction = Vector3.new(-0.45, 0, -0.89).Unit
                    vehicle:PivotTo(CFrame.lookAt(loopPos, loopPos + direction))
                end

                -- 缓存 BasePart 列表
                local baseParts = {}
                for _, part in ipairs(vehicle:GetDescendants()) do
                    if part:IsA("BasePart") then
                        baseParts[#baseParts + 1] = part
                    end
                end

                -- 设置速度
                for _, part in ipairs(baseParts) do
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end

                local speed = config.autoFarmSpeed or 300
                PlutoX.debug("[AutoFarm] 速度: " .. speed .. ", 移动时间: " .. moveDuration .. "s")

                local RunService = game:GetService("RunService")

                -- 阶段1：向前移动
                local startTime = tick()
                while tick() - startTime < moveDuration and isAutoFarmActive do
                    if not vehicle or not vehicle.Parent then break end

                    local currentPos = vehicle.PrimaryPart and vehicle.PrimaryPart.Position or loopPos
                    vehicle:PivotTo(CFrame.lookAt(currentPos, currentPos + direction))

                    for _, part in ipairs(baseParts) do
                        part.AssemblyLinearVelocity = direction * speed
                        part.AssemblyAngularVelocity = Vector3.zero
                    end

                    RunService.Heartbeat:Wait()
                end

                -- 阶段2：返回
                PlutoX.debug("[AutoFarm] 开始返回")
                local returnDirection = -direction
                local returnStartTime = tick()
                while tick() - returnStartTime < returnDuration and isAutoFarmActive do
                    if not vehicle or not vehicle.Parent then break end

                    local currentPos = vehicle.PrimaryPart and vehicle.PrimaryPart.Position or loopPos
                    vehicle:PivotTo(CFrame.lookAt(currentPos, currentPos + returnDirection))

                    for _, part in ipairs(baseParts) do
                        part.AssemblyLinearVelocity = returnDirection * speed
                        part.AssemblyAngularVelocity = Vector3.zero
                    end

                    RunService.Heartbeat:Wait()
                end

                -- 停止
                if vehicle and vehicle.Parent then
                    for _, part in ipairs(baseParts) do
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                    end
                    PlutoX.debug("[AutoFarm] 一轮完成，继续下一轮...")
                end
            end)
            
            -- 错误处理或等待间隔
            if not success then
                PlutoX.warn("[AutoFarm] 错误: " .. tostring(err))
                task.wait(3)
            else
                task.wait(0.5) -- 每轮间隔，让 GC 有机会清理
            end
        end
    end)
end

local function performAutoSpawnVehicle()
    if not config.autoSpawnVehicleEnabled then
        return
    end

    local startTime = tick()

    local localPlayer = Players.LocalPlayer
    if not localPlayer or not ReplicatedStorage then
        PlutoX.warn("[AutoSpawnVehicle] 无法获取必要服务")
        return
    end

    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        PlutoX.warn("[AutoSpawnVehicle] 未找到 Remotes 文件夹")
        return
    end

    local GetVehicleStats = remotesFolder:FindFirstChild("GetVehicleStats")
    local VehicleEvent = remotesFolder:FindFirstChild("VehicleEvent")
    if not GetVehicleStats or not VehicleEvent then
        PlutoX.warn("[AutoSpawnVehicle] 未找到必要的远程事件")
        return
    end

    local playerGui = localPlayer.PlayerGui or localPlayer:WaitForChild("PlayerGui", 5)
    if not playerGui then
        PlutoX.warn("[AutoSpawnVehicle] PlayerGui 获取失败")
        return
    end

    local statsPanel = playerGui:FindFirstChild(localPlayer.Name .. "'s Stats")
    if not statsPanel then
        PlutoX.warn("[AutoSpawnVehicle] 未找到玩家 Stats 面板")
        return
    end

    local vehiclesFolder = statsPanel:FindFirstChild("Vehicles")
    if not vehiclesFolder then
        PlutoX.warn("[AutoSpawnVehicle] 未找到 Vehicles 文件夹")
        return
    end

    local fastestName, fastestSpeed, vehicleCount = findFastestVehicleFast(vehiclesFolder, GetVehicleStats)
    local searchTime = tick() - startTime
    

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
            PlutoX.warn("[AutoSpawnVehicle] 生成车辆时出错:", err)
        end
    else
        PlutoX.warn("[AutoSpawnVehicle] 未找到有效车辆数据")
    end
end

local originalLocationNameCall = nil

-- Auto Rob ATMs
local function performAutoRobATMs()
    isAutoRobActive = true
    
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    remotes:WaitForChild("RequestStartJobSession"):FireServer("Criminal", "jobPad")
    
    -- 配置
    local platformPositions = {
        Vector3.new(-978.8837890625, -166, 313.3407897949219),
        Vector3.new(-484.3203430175781, -166, -1226.457275390625),
        Vector3.new(220.6251220703125, -166, 137.8120880126953),
        Vector3.new(-94.29008483886719, -166, 2340.5263671875),
        Vector3.new(-866.1265258789062, -166, 3189.411865234375),
        Vector3.new(-2068.16015625, -166, 4206.7861328125),
    }
    local sellPos1 = Vector3.new(-2520.495849609375, 15.116586685180664, 4035.560791015625)
    local sellPos2 = Vector3.new(-2542.12646484375, 15.116586685180664, 4030.9150390625)
    local spawnPos = Vector3.new(-315.4537353515625, 17.595108032226562, -1660.684326171875)
    
    -- 拦截Location
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    originalLocationNameCall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "FireServer" and self.Name == "Location" and #args >= 2 and args[1] == "Enter" then
            return
        end
        return originalLocationNameCall(self, ...)
    end)
    setreadonly(mt, true)
    
    spawn(function()
        local collectionService = game:GetService("CollectionService")
        local localPlayer = game.Players.LocalPlayer
        local noclipConnection = nil
        local noATMCount = 0
        
        local function setNoclip(state)
            if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
            if state then
                noclipConnection = game:GetService("RunService").Stepped:Connect(function()
                    if localPlayer.Character then
                        for _, part in ipairs(localPlayer.Character:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end
                end)
            end
        end
        
        local function setWeight(isHeavy)
            local char = localPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CustomPhysicalProperties = isHeavy and PhysicalProperties.new(100, 0.3, 0.5) or nil
                    end
                end
            end
        end
        
        local function createAllPlatforms()
            for i, pos in ipairs(platformPositions) do
                local platform = Instance.new("Part")
                platform.Name = "DeltaCorePlatform"
                platform.Parent = workspace
                platform.Position = pos
                platform.Size = Vector3.new(50000, 3, 50000)
                platform.Color = Color3.fromRGB(128, 128, 128)
                platform.Anchored = true
            end
        end
        
        local function removeAllPlatforms()
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "DeltaCorePlatform" then 
                    obj:Destroy() 
                end
            end
        end
        
        local function safeTeleport(pos)
            if not isAutoRobActive then return end
            local char = localPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.PrimaryPart.Velocity = Vector3.zero
                char:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
            end
        end
        
        local function smartBust(spawner, atm)
            if not isAutoRobActive then return false end
            
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local beforeAmount = getRobbedAmount() or 0
            local targetPos = atm.WorldPivot + Vector3.new(0, 5, 0)
            
            -- 步骤1：传送到 ATM 并保持位置 1 秒
            local teleportStart = tick()
            repeat
                task.wait()
                if root then 
                    root.AssemblyLinearVelocity = Vector3.zero 
                    char:PivotTo(targetPos)
                end
                localPlayer.ReplicationFocus = nil
            until tick() - teleportStart > 1 or not isAutoRobActive
            
            if not isAutoRobActive then return false end
            
            -- 调用开始抢劫
            game:GetService("ReplicatedStorage").Remotes.AttemptATMBustStart:InvokeServer(atm)
            
            -- 步骤2：保持位置 2.5 秒
            local progressStart = tick()
            repeat
                task.wait()
                if root then 
                    root.AssemblyLinearVelocity = Vector3.zero 
                    char:PivotTo(targetPos)
                end
                localPlayer.ReplicationFocus = nil
            until tick() - progressStart > 2.5 or not isAutoRobActive
            
            if not isAutoRobActive then return false end
            
            -- 步骤3：调用完成抢劫
            game:GetService("ReplicatedStorage").Remotes.AttemptATMBustComplete:InvokeServer(atm)
            
            -- 步骤4：保持位置等待冷却完成（检查 ATMBustDebounce）
            local cooldownStart = tick()
            repeat
                task.wait()
                if root then 
                    root.AssemblyLinearVelocity = Vector3.zero 
                    char:PivotTo(targetPos)
                end
            until tick() - cooldownStart > 3 or char:GetAttribute("ATMBustDebounce") or not isAutoRobActive
            
            repeat
                task.wait()
                if root then 
                    root.AssemblyLinearVelocity = Vector3.zero 
                    char:PivotTo(targetPos)
                end
            until tick() - cooldownStart > 3 or not char:GetAttribute("ATMBustDebounce") or not isAutoRobActive
            
            -- 检测金额变化
            local success = checkRobberyCompletion(beforeAmount)
            
            -- 抢劫后检查是否需要出售
            sellByAmount()
            
            return success
        end
        
        local function sellByAmount()
            if not isAutoRobActive then return false end
            local currentAmount = getRobbedAmount() or 0
            local targetAmount = config.robTargetAmount or 0
            
            -- 调试输出：显示当前金额和目标金额
            if targetAmount > 0 then
                PlutoX.debug("[AutoRob] 当前已抢金额: " .. formatNumber(currentAmount) .. " / 目标: " .. formatNumber(targetAmount))
            end
            
            if targetAmount > 0 and currentAmount >= targetAmount then
                setNoclip(true)
                
                -- 传送到出售点1
                safeTeleport(sellPos1)
                task.wait(0.5)
                
                -- 走到出售点2
                local char = localPlayer.Character
                local human = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if human and root then
                    human:MoveTo(sellPos2)
                    local startT = tick()
                    while (root.Position - sellPos2).Magnitude > 3 and tick() - startT < 2 do task.wait(0.1) end
                end
                
                -- 等待服务器处理出售
                task.wait(2)
                
                -- 等待金额清零
                local sellStart = tick()
                local sellTimeout = 10
                repeat
                    task.wait(0.3)
                    currentAmount = getRobbedAmount() or 0
                until currentAmount == 0 or tick() - sellStart > sellTimeout
                
                if currentAmount == 0 then
                    UILibrary:Notify({ Title = "出售成功", Text = "金额已清零", Duration = 5 })
                    return true
                else
                    UILibrary:Notify({ Title = "出售未完成", Text = "金额未清零，继续抢劫", Duration = 3 })
                    return false
                end
            end
            return false
        end
        
        local function getAvailableATM()
            local spawners = workspace.Game.Jobs.CriminalATMSpawners
            
            for _, spawner in ipairs(spawners:GetChildren()) do
                local atm = spawner:FindFirstChild("CriminalATM")
                if atm then
                    local state = atm:GetAttribute("State")
                    if state == "Normal" then
                        return spawner, atm
                    end
                end
            end
            return nil, nil
        end
        
        local function searchAndRob()
            if not isAutoRobActive then 
                return false 
            end
            
            -- 先检查是否需要出售
            if sellByAmount() then
            end
            
            setNoclip(true)
            
            -- 先尝试直接寻找 ATM（不传送平台）
            local spawner, atm = getAvailableATM()
            if spawner and atm then
                local success = smartBust(spawner, atm)
                if success then
                    -- 抢劫成功后传送到第一个平台
                    safeTeleport(platformPositions[1])
                    return true
                end
            end
            
            -- 如果没找到或抢劫失败，遍历平台
            for i, platformPos in ipairs(platformPositions) do
                if not isAutoRobActive then 
                    break 
                end
                
                safeTeleport(platformPos)
                task.wait(5)
                
                local spawner, atm = getAvailableATM()
                if spawner and atm then
                    local success = smartBust(spawner, atm)
                    if success then
                        return true
                    end
                end
            end
            
            return false
        end

        -- 初始化：创建平台、设置 noclip 和 weight
        removeAllPlatforms()
        createAllPlatforms()
        setNoclip(true)
        setWeight(true)
        
        while isAutoRobActive do
            task.wait()
            local success, err = pcall(function()
                if searchAndRob() then
                    noATMCount = 0
                else
                    noATMCount = noATMCount + 1
                    if noATMCount >= 5 then
                        noATMCount = 0
                        safeTeleport(Vector3.new(0, 50, 0))
                        task.wait(1)
                    end
                end
            end)
            if not success then
                noATMCount = 0
            end
        end
        
        if noclipConnection then noclipConnection:Disconnect() end
        removeAllPlatforms()
        setWeight(false)
        safeTeleport(spawnPos)
        pcall(function() remotes:WaitForChild("RequestEndJobSession"):FireServer("jobPad") end)
        
        if originalLocationNameCall then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = originalLocationNameCall
            setreadonly(mt, true)
            originalLocationNameCall = nil
        end
    end)
end

local webhookManager = PlutoX.createWebhookManager(config, HttpService, UILibrary, gameName, username, configFile)
local disconnectDetector = PlutoX.createDisconnectDetector(UILibrary, webhookManager)
local dataMonitor = PlutoX.createDataMonitor(config, UILibrary, webhookManager, dataTypes, disconnectDetector, gameName, username)
disconnectDetector:init()

-- 排行榜回调
dataMonitor.beforeSendCallback = function(embed)
    if config.notifyLeaderboard or config.leaderboardKick then
        local currentRank, isOnLeaderboard = fetchPlayerRank()
        local status = isOnLeaderboard and ("#" .. currentRank) or "未上榜"
        
        table.insert(embed.fields, {
            name = "🏆 排行榜",
            value = string.format("**当前排名**: %s", status),
            inline = true
        })
        
        return embed
    end
    return embed
end

-- 反挂机
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- 初始化
dataMonitor:init()

-- 游戏功能
if config.onlineRewardEnabled then
    spawn(claimPlaytimeRewards)
end

if config.autoSpawnVehicleEnabled then
    spawn(performAutoSpawnVehicle)
end

-- UI
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

-- 常规
local generalTab, generalContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "常规",
    Icon = "home",
    Active = true
})

local generalCard = UILibrary:CreateCard(generalContent, { IsMultiElement = true })
UILibrary:CreateLabel(generalCard, {
    Text = "游戏: " .. webhookManager.gameName,
})

local displayLabels = {}
local updateFunctions = {}

-- 数据类型标签
for _, dataType in ipairs(dataTypes) do
    if dataType.supportTarget then
        local card, label, updateFunc = dataMonitor:createDisplayLabel(generalCard, dataType)
        displayLabels[dataType.id] = label
        updateFunctions[dataType.id] = updateFunc
    end
end

-- 反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
UILibrary:CreateLabel(antiAfkCard, {
    Text = "反挂机已启用",
})

-- 游戏功能
local featuresTab, featuresContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "功能",
    Icon = "gamepad"
})

-- 子标签页
local featuresSubTabs = UILibrary:CreateSubTabs(featuresContent, {
    Items = {
        "辅助功能",
        "autofarm"
    },
    DefaultActive = 1,
    OnSwitch = function(index, name)
    end
})

-- 辅助功能
local utilityContent = featuresSubTabs.GetContent(1)

-- 在线奖励
local onlineRewardCard = UILibrary:CreateCard(utilityContent)
UILibrary:CreateToggle(onlineRewardCard, {
    Text = "在线时长奖励",
    DefaultState = config.onlineRewardEnabled or false,
    Callback = function(state)
        config.onlineRewardEnabled = state
        configManager:saveConfig()
        if state then
            spawn(claimPlaytimeRewards)
        end
    end
})

-- 自动生成
local autoSpawnCard = UILibrary:CreateCard(utilityContent)
UILibrary:CreateToggle(autoSpawnCard, {
    Text = "自动生成车辆",
    DefaultState = config.autoSpawnVehicleEnabled or false,
    Callback = function(state)
        config.autoSpawnVehicleEnabled = state
        configManager:saveConfig()
        if state then
            spawn(performAutoSpawnVehicle)
        end
    end
})

-- autofarm
local autofarmContent = featuresSubTabs.GetContent(2)

-- AutoFarm
local autoFarmCard = UILibrary:CreateCard(autofarmContent, { IsMultiElement = true })
UILibrary:CreateLabel(autoFarmCard, {
    Text = "Auto Farm",
})

-- 速度滑块
UILibrary:CreateSlider(autoFarmCard, {
    Text = "速度",
    Min = 0,
    Max = 700,
    Default = config.autoFarmSpeed or 300,
    Suffix = "",
    Callback = function(value)
        config.autoFarmSpeed = value
        configManager:saveConfig()
    end
})

-- AutoFarm 开关
UILibrary:CreateToggle(autoFarmCard, {
    Text = "启用autofarm",
    DefaultState = autoFarmEnabled,
    Callback = function(state)
        autoFarmEnabled = state
        -- 不保存到配置文件
        if state then
            spawn(performAutoFarm)
            UILibrary:Notify({
                Title = "AutoFarm 已启动",
                Text = "速度: " .. (config.autoFarmSpeed or 300),
                Duration = 5
            })
        else
            isAutoFarmActive = false
            UILibrary:Notify({
                Title = "AutoFarm 已停止",
                Text = "autofarm已关闭",
                Duration = 3
            })
        end
    end
})

-- ATM 抢劫
local autoRobCard = UILibrary:CreateCard(autofarmContent, { IsMultiElement = true })
UILibrary:CreateLabel(autoRobCard, {
    Text = "Auto Rob ATMs",
})

local robAmountInput = UILibrary:CreateTextBox(autoRobCard, {
    PlaceholderText = "输入单次目标金额",
    OnFocusLost = function(text)
        if not text or text == "" then
            config.robTargetAmount = 0
            robAmountInput.Text = ""
            configManager:saveConfig()
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
            configManager:saveConfig()
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

UILibrary:CreateToggle(autoRobCard, {
    Text = "启用自动抢劫",
    DefaultState = false,
    Callback = function(state)
        if not state then
            isAutoRobActive = false
            
            local currentRobbedAmount = getRobbedAmount() or 0
            if currentRobbedAmount > 0 then
                spawn(function()
                    sellMoney()
                end)
            else
                isDeliveryInProgress = false
            end
            
            
            if originalLocationNameCall then
                local mt = getrawmetatable(game)
                setreadonly(mt, false)
                mt.__namecall = originalLocationNameCall
                setreadonly(mt, true)
                originalLocationNameCall = nil
            end
        else
            spawn(function()
                task.wait(0.5)
                if performAutoRobATMs then
                    pcall(performAutoRobATMs)
                end
            end)
        end
        
        UILibrary:Notify({
            Title = "配置更新",
            Text = "Auto Rob ATMs: " .. (state and "开启" or "关闭"),
            Duration = 5
        })
    end
})

-- 自动购买
local purchaseTab, purchaseContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "购买",
    Icon = "shopping-cart"
})

-- 通知
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "通知",
    Icon = "bell"
})

-- Webhook
PlutoX.createWebhookCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end, webhookManager)

-- 通知间隔
PlutoX.createIntervalCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end)

-- 监测金额
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
        configManager:saveConfig()
    end
})

-- 排行榜检测
local leaderboardCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(leaderboardCard, {
    Text = "排行榜检测",
    DefaultState = config.notifyLeaderboard,
    Callback = function(state)
        config.notifyLeaderboard = state
        UILibrary:Notify({ Title = "配置更新", Text = "排行榜检测: " .. (state and "开启" or "关闭"), Duration = 5 })
        configManager:saveConfig()
    end
})

-- 排行榜踢出
local leaderboardKickCard = UILibrary:CreateCard(notifyContent)
UILibrary:CreateToggle(leaderboardKickCard, {
    Text = "排行榜踢出",
    DefaultState = config.leaderboardKick,
    Callback = function(state)
        config.leaderboardKick = state
        UILibrary:Notify({ Title = "配置更新", Text = "排行榜踢出: " .. (state and "开启" or "关闭"), Duration = 5 })
        configManager:saveConfig()
    end
})

-- 数据类型设置
local targetValueLabels = {}

for _, dataType in ipairs(dataTypes) do
    local keyUpper = string.upper(dataType.id:sub(1, 1)) .. dataType.id:sub(2)

    if dataType.supportTarget then
        local separatorCard = UILibrary:CreateCard(notifyContent)
        PlutoX.createDataTypeSectionLabel(separatorCard, UILibrary, dataType)

        local baseValueCard, baseValueInput, setTargetValueLabel, getTargetValueToggle, setLabelCallback = PlutoX.createBaseValueCard(
            notifyContent, UILibrary, config, function() configManager:saveConfig() end,
            function() return dataMonitor:fetchValue(dataType) end,
            keyUpper,
            dataType.icon
        )

        local targetValueCard, targetValueLabel, setTargetValueToggle2 = PlutoX.createTargetValueCardSimple(
            notifyContent, UILibrary, config, function() configManager:saveConfig() end,
            function() return dataMonitor:fetchValue(dataType) end,
            keyUpper
        )

        setTargetValueLabel(targetValueLabel)
        targetValueLabels[dataType.id] = targetValueLabel
    end
end

-- 重新计算目标值
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

-- 车辆数据
local purchaseFunctions = {}

-- 进入车店
function purchaseFunctions.enterDealership()
    local success, err = pcall(function()
        local locationRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Location")
        locationRemote:FireServer("Enter", "Cars")
        return true
    end)
    
    if not success then
        PlutoX.warn("[Purchase] 进入车店失败:", err)
        return false
    end
    
    return true
end

-- 车辆数据
function purchaseFunctions.getAllVehicles()
    local vehicles = {}
    
    
    local success, err = pcall(function()
        local playerGui = player:WaitForChild("PlayerGui", 10)
        if not playerGui then
            PlutoX.warn("[Purchase] PlayerGui 获取超时")
            return vehicles
        end
        
        task.wait(0.7)
        
        local dealershipHolder = playerGui:FindFirstChild("DealershipHolder")
        if not dealershipHolder then
            PlutoX.warn("[Purchase] 未找到 DealershipHolder")
            return vehicles
        end
        
        task.wait(0.7)
        
        local dealership = dealershipHolder:FindFirstChild("Dealership")
        if not dealership then
            PlutoX.warn("[Purchase] 未找到 Dealership")
            return vehicles
        end
        
        task.wait(0.7)
        
        local selector = dealership:FindFirstChild("Selector")
        if not selector then
            PlutoX.warn("[Purchase] 未找到 Selector")
            return vehicles
        end
        
        task.wait(0.7)
        
        local view = selector:FindFirstChild("View")
        if not view then
            PlutoX.warn("[Purchase] 未找到 View")
            return vehicles
        end
        
        task.wait(0.7)
        
        local allView = view:FindFirstChild("All")
        if not allView then
            PlutoX.warn("[Purchase] 未找到 All")
            return vehicles
        end
        
        task.wait(0.7)
        
        local container = allView:FindFirstChild("Container")
        if not container then
            PlutoX.warn("[Purchase] 未找到 Container")
            return vehicles
        end
        
        task.wait(1)
        
        local allChildren = container:GetChildren()
        local totalChildren = #allChildren
        
        for i, vehicleFrame in ipairs(allChildren) do
            if i % 10 == 0 then
                task.wait()
            end
            
            if vehicleFrame:IsA("Frame") or vehicleFrame:IsA("ImageButton") then
                local vehicleName = nil
                local price = nil
                
                for _, child in ipairs(vehicleFrame:GetChildren()) do
                    if child.Name == "VehicleName" and child:IsA("TextLabel") then
                        vehicleName = child.Text
                    elseif child.Name == "Price" and child:IsA("TextLabel") then
                        local priceText = child.Text
                        local cleanPrice = priceText:gsub("[$,]", "")
                        price = tonumber(cleanPrice)
                    end
                end
                
                if vehicleName and price then
                    table.insert(vehicles, {
                        name = vehicleName,
                        price = price,
                        frame = vehicleFrame,
                        frameName = vehicleFrame.Name
                    })
                end
            end
        end
    end)
    
    if not success then
        PlutoX.warn("[Purchase] 获取车辆数据失败:", err)
    end
    
    
    return vehicles
end

-- 当前资金
function purchaseFunctions.getCurrentCash()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local cash = leaderstats:FindFirstChild("Cash")
        if cash then
            return cash.Value
        end
    end
    return 0
end

-- 随机颜色
function purchaseFunctions.randomColor()
    return Color3.new(math.random(), math.random(), math.random())
end

-- 购买车辆
function purchaseFunctions.buyVehicle(frameName)
    
    local success, result = pcall(function()
        local purchaseRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Purchase")
        
        -- 随机颜色配置
        local mainColor = purchaseFunctions.randomColor()
        local secondaryColor = purchaseFunctions.randomColor()
        local wheelColor = purchaseFunctions.randomColor()
        
        local args = {
            {
                frameName,
                mainColor, -- 主颜色（随机）
                secondaryColor, -- 次要颜色（随机）
                wheelColor  -- 轮毂颜色（随机）
            }
        }
        
        
        local purchaseResult = purchaseRemote:InvokeServer(unpack(args))
        
        if type(purchaseResult) == "table" then
            for k, v in pairs(purchaseResult) do
            end
        else
        end
        
        return purchaseResult
    end)
    
    if success then
        return true, result
    else
        PlutoX.warn("[Purchase] pcall失败，错误:", result)
        return false, result
    end
end

-- 记录购买
purchaseFunctions.autoPurchasedVehicles = {}

-- 购买车辆
function purchaseFunctions.purchaseVehicle(vehicle)
    
    -- 检查资金是否足够
    local currentCash = purchaseFunctions.getCurrentCash()
    if currentCash < vehicle.price then
        return false, "资金不足"
    end
    
    -- 执行购买
    local success, result = purchaseFunctions.buyVehicle(vehicle.frameName)
    
    if success then
        -- 记录购买的车辆
        table.insert(purchaseFunctions.autoPurchasedVehicles, vehicle)
        return true, result
    else
        return false, result
    end
end

-- 后悔卖车
function purchaseFunctions.sellVehicle(vehicle)
    
    local success, err = pcall(function()
        local sellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SellCar")
        
        local args = {
            vehicle.frameName
        }
        
        sellRemote:FireServer(unpack(args))
        
        return true
    end)
    
    if success then
        -- 从记录中移除
        for i, v in ipairs(purchaseFunctions.autoPurchasedVehicles) do
            if v.frameName == vehicle.frameName then
                table.remove(purchaseFunctions.autoPurchasedVehicles, i)
                break
            end
        end
        return true
    else
        PlutoX.warn("[Sell] 卖车失败:", err)
        return false, err
    end
end

-- 后悔所有
function purchaseFunctions.regretAllPurchases()
    
    -- 创建副本，避免在遍历时修改原表
    local vehiclesToSell = {}
    for i, vehicle in ipairs(purchaseFunctions.autoPurchasedVehicles) do
        table.insert(vehiclesToSell, vehicle)
    end
    
    local soldCount = 0
    local totalRefund = 0
    
    for i, vehicle in ipairs(vehiclesToSell) do
        local success = purchaseFunctions.sellVehicle(vehicle)
        if success then
            soldCount = soldCount + 1
            totalRefund = totalRefund + vehicle.price
        else
        end
        
        task.wait(1)
    end
    
    
    return true, {
        soldCount = soldCount,
        totalRefund = totalRefund
    }
end

-- 自动购买
function purchaseFunctions.autoPurchase(options)
    options = options or {}
    local sortAscending = options.sortAscending ~= false  -- 默认按价格从低到高排序
    local maxPurchases = options.maxPurchases or math.huge  -- 最大购买数量
    local onProgress = options.onProgress or function() end  -- 进度回调
    local shouldContinue = options.shouldContinue or function() return true end
    
    
    -- 进入车店
    if not purchaseFunctions.enterDealership() then
        return false, "无法进入车店"
    end
    
    task.wait(1)
    
    -- 获取所有车辆
    local vehicles = purchaseFunctions.getAllVehicles()
    
    if #vehicles == 0 then
        return false, "未找到任何车辆"
    end
    
    -- 排序
    if sortAscending then
        table.sort(vehicles, function(a, b)
            return a.price < b.price
        end)
    else
        table.sort(vehicles, function(a, b)
            return a.price > b.price
        end)
    end
    
    local currentCash = purchaseFunctions.getCurrentCash()
    local purchasedCount = 0
    local totalSpent = 0
    
    
    -- 依次购买
    for _, vehicle in ipairs(vehicles) do
        if purchasedCount >= maxPurchases then
            break
        end
        
        if not shouldContinue() then
            break
        end
        
        if currentCash >= vehicle.price then
            local success, result = purchaseFunctions.purchaseVehicle(vehicle)
            
            if success then
                currentCash = currentCash - vehicle.price
                totalSpent = totalSpent + vehicle.price
                purchasedCount = purchasedCount + 1
                
                
                -- 调用进度回调
                onProgress({
                    vehicle = vehicle,
                    purchasedCount = purchasedCount,
                    totalSpent = totalSpent,
                    remainingCash = currentCash
                })
                
                task.wait(1)
            else
            end
        else
            break
        end
    end
    
    
    return true, {
        purchasedCount = purchasedCount,
        totalSpent = totalSpent,
        remainingCash = currentCash
    }
end

-- 搜索购买
local searchCard = UILibrary:CreateCard(purchaseContent, { IsMultiElement = true })
UILibrary:CreateLabel(searchCard, {
    Text = "搜索购买",
})

-- 存储 UI
local previousDropdown = nil
local previousBuyButton = nil

local searchResultsFrame = Instance.new("ScrollingFrame")
searchResultsFrame.Name = "SearchResults"
searchResultsFrame.Size = UDim2.new(1, -16, 0, 200)
searchResultsFrame.Position = UDim2.new(0, 8, 0, 80)
searchResultsFrame.BackgroundColor3 = UILibrary.THEME.SecondaryBackground or UILibrary.DEFAULT_THEME.SecondaryBackground
searchResultsFrame.BackgroundTransparency = 0.3
searchResultsFrame.BorderSizePixel = 0
searchResultsFrame.ScrollBarThickness = 6
searchResultsFrame.ScrollBarImageColor3 = UILibrary.THEME.Primary or UILibrary.DEFAULT_THEME.Primary
searchResultsFrame.Parent = searchCard
searchResultsFrame.Visible = false

local searchResultsLayout = Instance.new("UIListLayout")
searchResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
searchResultsLayout.Padding = UDim.new(0, 4)
searchResultsLayout.Parent = searchResultsFrame

local searchResultsPadding = Instance.new("UIPadding")
searchResultsPadding.PaddingLeft = UDim.new(0, 4)
searchResultsPadding.PaddingRight = UDim.new(0, 4)
searchResultsPadding.PaddingTop = UDim.new(0, 4)
searchResultsPadding.PaddingBottom = UDim.new(0, 4)
searchResultsPadding.Parent = searchResultsFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, UILibrary.UI_STYLES.CornerRadius)
corner.Parent = searchResultsFrame

local searchInput = UILibrary:CreateTextBox(searchCard, {
    PlaceholderText = "输入车辆名称关键词",
    OnFocusLost = function(text)
        local searchText = text:lower()
        
        if searchText == "" then
            return
        end
        
        
        -- 销毁之前创建的UI元素
        pcall(function()
            if previousDropdown and previousDropdown.Parent then
                previousDropdown:Destroy()
            end
        end)
        
        pcall(function()
            if previousBuyButton and previousBuyButton.Parent then
                previousBuyButton:Destroy()
            end
        end)
        
        previousDropdown = nil
        previousBuyButton = nil
        
        -- 进入车店并获取车辆数据
        if not purchaseFunctions.enterDealership() then
            UILibrary:Notify({
                Title = "错误",
                Text = "无法进入车店",
                Duration = 5
            })
            return
        end
        
        task.wait(1)
        
        local vehicles = purchaseFunctions.getAllVehicles()
        
        local matchedVehicles = {}
        
        -- 搜索匹配的车辆
        for _, vehicle in ipairs(vehicles) do
            local vehicleNameLower = vehicle.name:lower()
            if vehicleNameLower:find(searchText) then
                table.insert(matchedVehicles, {
                    name = vehicle.name,
                    price = vehicle.price,
                    frameName = vehicle.frameName,
                    displayText = vehicle.name .. " - $" .. formatNumber(vehicle.price)
                })
            end
        end
        
        
        if #matchedVehicles == 0 then
            UILibrary:Notify({
                Title = "搜索结果",
                Text = string.format("未找到匹配的车辆\n关键词: %s\n可用车辆: %d", text, #vehicles),
                Duration = 5
            })
            return
        end
        
        -- 创建车辆下拉框
        local vehicleDropdown = nil
        local buyButton = nil
        
        local success, errorMsg = pcall(function()
            -- 提取显示文本列表
            local displayOptions = {}
            for _, v in ipairs(matchedVehicles) do
                table.insert(displayOptions, v.displayText)
            end
            
            vehicleDropdown = UILibrary:CreateDropdown(searchCard, {
                Text = "选择车辆",
                DefaultOption = displayOptions[1],
                Options = displayOptions,
                Callback = function(selectedDisplayText)
                    local selectedVehicleName = selectedDisplayText:match("^(.-) %-")
                end
            })
        end)
        
        if not success then
            UILibrary:Notify({
                Title = "错误",
                Text = "创建下拉框失败: " .. tostring(errorMsg),
                Duration = 10
            })
            return
        end
        
        if not vehicleDropdown then
            UILibrary:Notify({
                Title = "错误",
                Text = "无法创建下拉框",
                Duration = 5
            })
            return
        end
        
        -- 存储下拉框引用
        previousDropdown = vehicleDropdown
        
        -- 创建购买按钮
        pcall(function()
            buyButton = UILibrary:CreateButton(searchCard, {
                Text = "购买选中车辆",
                Callback = function()
                    if not vehicleDropdown or not vehicleDropdown.Parent then
                        return
                    end
                    
                    local dropdownButton = vehicleDropdown:FindFirstChild("DropdownButton")
                    if not dropdownButton then
                        UILibrary:Notify({
                            Title = "错误",
                            Text = "请先选择车辆",
                            Duration = 3
                        })
                        return
                    end
                    
                    local selectedDisplayText = dropdownButton.Text
                    local selectedVehicleName = selectedDisplayText:match("^(.-) %-")
                    
                    if not selectedVehicleName then
                        UILibrary:Notify({
                            Title = "错误",
                            Text = "无法解析车辆名称",
                            Duration = 3
                        })
                        return
                    end
                    
                    -- 查找车辆
                    local selectedVehicle = nil
                    for _, vehicle in ipairs(matchedVehicles) do
                        if vehicle.name == selectedVehicleName then
                            selectedVehicle = vehicle
                            break
                        end
                    end
                    
                    if not selectedVehicle then
                        UILibrary:Notify({
                            Title = "错误",
                            Text = "未找到选中的车辆",
                            Duration = 5
                        })
                        return
                    end
                    
                    local success, result = purchaseFunctions.purchaseVehicle(selectedVehicle)
                    
                    if success then
                        UILibrary:Notify({
                            Title = "购买成功",
                            Text = string.format("已购买: %s\n价格: $%s", selectedVehicle.name, formatNumber(selectedVehicle.price)),
                            Duration = 5
                        })
                        
                        pcall(function()
                            if vehicleDropdown and vehicleDropdown.Parent then
                                vehicleDropdown:Destroy()
                                vehicleDropdown = nil
                            end
                        end)
                        
                        pcall(function()
                            if buyButton and buyButton.Parent then
                                buyButton:Destroy()
                                buyButton = nil
                            end
                        end)
                        
                        -- 清空搜索框
                        if searchInput and searchInput.Parent then
                            searchInput.Text = ""
                        end
                    else
                        UILibrary:Notify({
                            Title = "购买失败",
                            Text = string.format("无法购买: %s", selectedVehicle.name),
                            Duration = 5
                        })
                    end
                end
            })
            
        end)
        
        -- 存储购买按钮引用
        previousBuyButton = buyButton
        
        if not buyButton then
            UILibrary:Notify({
                Title = "错误",
                Text = "无法创建购买按钮",
                Duration = 5
            })
            return
        end
    end
})

-- 一键购买
local autoBuyCard = UILibrary:CreateCard(purchaseContent, { IsMultiElement = true })
UILibrary:CreateLabel(autoBuyCard, {
    Text = "一键购买",
})

local autoBuyStatus = false

local startAutoBuyButton = UILibrary:CreateButton(autoBuyCard, {
    Text = "开始一键购买",
    Callback = function()
        if autoBuyStatus then
            UILibrary:Notify({
                Title = "提示",
                Text = "一键购买已在运行中",
                Duration = 3
            })
            return
        end
        
        autoBuyStatus = true
        
        spawn(function()
            local success, result = purchaseFunctions.autoPurchase({
                sortAscending = true,
                shouldContinue = function()
                    return autoBuyStatus
                end,
                onProgress = function(progress)
                end
            })
            
            autoBuyStatus = false
            
            if success then
                UILibrary:Notify({
                    Title = "一键购买完成",
                    Text = string.format(
                        "购买数量: %d\n总花费: $%s\n剩余资金: $%s",
                        result.purchasedCount,
                        formatNumber(result.totalSpent),
                        formatNumber(result.remainingCash)
                    ),
                    Duration = 5
                })
            else
                UILibrary:Notify({
                    Title = "一键购买失败",
                    Text = result,
                    Duration = 5
                })
            end
        end)
    end
})

local stopAutoBuyButton = UILibrary:CreateButton(autoBuyCard, {
    Text = "停止一键购买",
    Callback = function()
        if autoBuyStatus then
            autoBuyStatus = false
            UILibrary:Notify({
                Title = "提示",
                Text = "一键购买已停止",
                Duration = 3
            })
        else
            UILibrary:Notify({
                Title = "提示",
                Text = "一键购买未在运行",
                Duration = 3
            })
        end
    end
})

-- 后悔按钮
local regretButton = UILibrary:CreateButton(autoBuyCard, {
    Text = "后悔所有购买",
    Callback = function()
        if #purchaseFunctions.autoPurchasedVehicles == 0 then
            UILibrary:Notify({
                Title = "提示",
                Text = "没有可后悔的车辆",
                Duration = 3
            })
            return
        end
        
        UILibrary:Notify({
            Title = "确认",
            Text = string.format("确定要卖出 %d 辆车吗？", #purchaseFunctions.autoPurchasedVehicles),
            Duration = 5
        })
        
        spawn(function()
            local success, result = purchaseFunctions.regretAllPurchases()
            
            if success then
                UILibrary:Notify({
                    Title = "后悔完成",
                    Text = string.format(
                        "成功卖出: %d 辆\n总退款: $%s",
                        result.soldCount,
                        formatNumber(result.totalRefund)
                    ),
                    Duration = 5
                })
            else
                UILibrary:Notify({
                    Title = "后悔失败",
                    Text = result,
                    Duration = 5
                })
            end
        end)
    end
})

-- 关于
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于",
    Icon = "info"
})

PlutoX.createAboutPage(aboutContent, UILibrary)

-- 主循环
local checkInterval = 1
local lastRobbedAmount = 0
local lastSendTime = os.time()
local shouldExit = false -- 标记是否应该退出主循环

spawn(function()
    while not shouldExit do
        local currentTime = os.time()

        -- 更新所有数据类型的显示
        for id, updateFunc in pairs(updateFunctions) do
            pcall(updateFunc)
        end

        -- 收集数据（只收集一次，用于多个地方使用）
        local collectedData = dataMonitor:collectData()

        -- 检查并发送通知（传入已收集的数据）
        dataMonitor:checkAndNotify(function() configManager:saveConfig() end, disconnectDetector, collectedData)

        -- 掉线检测（传入已收集的数据，避免在掉线时重新获取）
        disconnectDetector:checkAndNotify(collectedData)

        -- 目标值调整
        for _, dataType in ipairs(dataTypes) do
            if dataType.supportTarget then
                local keyUpper = dataType.id:gsub("^%l", string.upper)
                if config["base" .. keyUpper] > 0 and config["target" .. keyUpper] > 0 then
                    pcall(function() dataMonitor:adjustTargetValue(function() configManager:saveConfig() end, dataType.id) end)
                end
            end
        end

        -- 目标值达成检测
        local achieved = dataMonitor:checkTargetAchieved(function() configManager:saveConfig() end)
        if achieved then
            -- 标记应该退出
            shouldExit = true

            -- 目标达成，发送通知（同步执行，等待所有操作完成）
            local allSuccess = webhookManager:sendTargetAchieved(
                achieved.value,
                achieved.targetValue,
                achieved.baseValue,
                os.time() - dataMonitor.startTime,
                achieved.dataType.name
            )

            -- 输出最终结果
            if allSuccess then
            else
                PlutoX.warn("[主循环] 目标达成：部分操作失败，但已退出游戏")
            end

            -- 退出主循环（sendTargetAchieved已包含游戏退出逻辑）
            break
        end

        -- 排行榜踢出检测（异步执行，避免阻塞主循环）
        if config.leaderboardKick and (currentTime - lastSendTime) >= (config.notificationInterval or 30) then
            spawn(function()
                local currentRank, isOnLeaderboard = fetchPlayerRank()
                
                if isOnLeaderboard then
                    PlutoX.warn("[排行榜踢出] 已上榜，准备上传数据并踢出...")
                    
                    -- 强制上传数据，确保 is_on_leaderboard 被保存到服务器
                    if PlutoX.uploader and PlutoX.uploader.forceUpload then
                        PlutoX.warn("[排行榜踢出] 正在上传数据...")
                        local uploadSuccess = PlutoX.uploader:forceUpload()
                        PlutoX.warn("[排行榜踢出] 数据上传结果: " .. tostring(uploadSuccess))
                        wait(2) -- 等待数据上传完成
                    else
                        PlutoX.warn("[排行榜踢出] 上传器未初始化，直接踢出")
                    end
                    
                    webhookManager:dispatchWebhook({
                        embeds = {{
                            title = "🏆 排行榜踢出",
                            description = string.format(
                                "**游戏**: %s\n**用户**: %s\n**当前排名**: #%s\n检测到已上榜，已踢出",
                                gameName, username, currentRank),
                            color = 16753920,
                            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                            footer = { text = "桐 · TStudioX" }
                        }}
                    })
                    
                    wait(0.5)
                    game:Shutdown()
                end
            end)
        end

        wait(checkInterval)
    end
end)

-- 欢迎消息
if config.webhookUrl ~= "" then
    spawn(function()
        wait(2)
        webhookManager:sendWelcomeMessage()
    end)
end