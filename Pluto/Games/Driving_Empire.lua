-- 服务和变量声明
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")
local UserInputService = game:GetService("UserInputService")

-- ============================================
-- Bypass 反检测系统（默认开启）
-- ============================================
local BypassActive = true
local HookInstalled = false
local BlockCount = 0

-- 目标远程事件黑名单
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

-- 立即安装钩子（Early Hook）
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
        -- 使用 print 因为此时 PlutoX 还未加载（Early Hook）
        print("[BYPASS] Hook 安装成功")
    else
        warn("[BYPASS] 关键错误: " .. tostring(err))
    end
end

InstallEarlyHook()

-- 监控和同步循环
task.spawn(function()
    while true do
        if BypassActive then
            local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
            if remotesFolder then
                local children = remotesFolder:GetChildren()
                for _, remote in ipairs(children) do
                    local n = remote.Name
                    -- 自动添加新的GUID到列表
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

-- PlutoX 模块加载（必须在UILibrary加载之前）
local plutoSuccess, PlutoX = pcall(function()
    local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/develop/Pluto/Common/PlutoX-Notifier.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if not plutoSuccess or not PlutoX then
    error("[PlutoX] 模块加载失败！请检查网络连接或链接是否有效：" .. tostring(PlutoX))
end

-- UI 库加载
local UILibrary
local success, result = pcall(function()
    local url
    if PlutoX.debugEnabled then
        url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/develop/Pluto/UILibrary/PlutoUILibrary.lua"
    else
        url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
    end
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if success and result then
    UILibrary = result
else
    error("[PlutoUILibrary] 加载失败！请检查网络连接或链接是否有效：" .. tostring(result))
end

-- 玩家和游戏信息
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

-- 设置游戏信息（用于数据上传）
PlutoX.setGameInfo(gameName, username, HttpService)

-- 游戏特定功能
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
        PlutoX.debug("[Teleport] 使用车辆传送")
    else
        player.Character:SetPrimaryPartCFrame(targetCFrame)
        PlutoX.debug("[Teleport] 使用角色传送")
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
        PlutoX.debug("[AutoRob] [" .. ctx .. "] 检测到功能已关闭，停止操作")
        return false
    end
    return true
end

-- 注册数据类型
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

-- 从API获取排行榜数据
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
            PlutoX.debug("[排行榜] 从API获取排行榜数据成功，共 " .. #responseJson.data .. " 条")
            return responseJson.data, true
        else
            PlutoX.debug("[排行榜] API返回错误: " .. tostring(responseJson.error))
            return nil, false
        end
    end)
    
    if success then
        return result, true
    else
        PlutoX.debug("[排行榜] API请求失败: " .. tostring(result))
        return nil, false
    end
end

-- 从排行榜数据中查找玩家排名
local function findPlayerRankInLeaderboard(leaderboardData)
    if not leaderboardData or type(leaderboardData) ~= "table" then
        return nil, false
    end
    
    for _, entry in ipairs(leaderboardData) do
        if entry.user_id == userId then
            PlutoX.debug("[排行榜] ✅ 从API数据中找到玩家ID: " .. userId .. ", 排名: #" .. entry.rank)
            return entry.rank, true
        end
    end
    
    PlutoX.debug("[排行榜] ❌ 未在API数据中找到玩家ID: " .. userId)
    return nil, false
end

-- 上传排行榜数据到网站（使用预提取的条目）
local function uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
    if not PlutoX.uploaderHttpService then
        PlutoX.debug("[排行榜] HttpService 不可用，无法上传排行榜数据")
        return false
    end
    
    if #leaderboardEntries == 0 then
        PlutoX.debug("[排行榜] 排行榜为空，取消上传")
        return false
    end
    
    PlutoX.debug("[排行榜] 准备上传 " .. #leaderboardEntries .. " 条排行榜数据到网站")
    
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
                PlutoX.debug("[排行榜] ✅ 排行榜数据上传成功，共 " .. #leaderboardEntries .. " 条")
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

-- 上传排行榜数据到网站
local function uploadLeaderboardToWebsite(contents)
    if not PlutoX.uploaderHttpService then
        PlutoX.debug("[排行榜] HttpService 不可用，无法上传排行榜数据")
        return false
    end
    
    local leaderboardEntries = {}
    
    -- 如果没有传入 contents，尝试从UI获取
    if not contents then
        contents = tryGetContents(2)
        if not contents then
            PlutoX.debug("[排行榜] 无法获取排行榜数据，取消上传")
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
    cacheTime = 300, -- 缓存时间（秒），5分钟
    failCacheTime = 30, -- 失败后的缓存时间（秒），30秒
    websiteCacheTime = 1800, -- 网站缓存时间（秒），30分钟
    lastFetchTime = 0,
    lastUploadTime = 0, -- 上次上传到网站的时间
    cachedRank = nil,
    cachedIsOnLeaderboard = false,
    lastFetchSuccess = false, -- 上次获取是否成功
    isFetching = false, -- 是否正在获取中
    hasFetched = false, -- 是否已经获取过
    uploadCooldown = 1800, -- 上传冷却时间（30分钟）
    lastAPICheckTime = 0, -- 上次API检查时间
    apiCheckInterval = 60, -- API检查间隔（60秒）
}

local function tryGetContents(timeout)
    local ok, result = pcall(function()
        PlutoX.debug("[排行榜] tryGetContents: 开始查找UI元素...")
        
        local Game = workspace:FindFirstChild("Game")
        if not Game then
            PlutoX.debug("[排行榜] tryGetContents: ❌ Game 不存在")
            return nil
        end
        
        local Leaderboards = Game:FindFirstChild("Leaderboards")
        if not Leaderboards then
            PlutoX.debug("[排行榜] tryGetContents: ❌ Leaderboards 不存在")
            return nil
        end
        
        local LeaderboardsChildren = {}
        for _, child in ipairs(Leaderboards:GetChildren()) do
            table.insert(LeaderboardsChildren, child.Name)
        end
        PlutoX.debug("[排行榜] tryGetContents: Leaderboards 子元素: " .. table.concat(LeaderboardsChildren, ", "))
        
        local weekly_money = Leaderboards:FindFirstChild("weekly_money")
        if not weekly_money then
            PlutoX.debug("[排行榜] tryGetContents: ❌ weekly_money 不存在")
            return nil
        end
        
        -- 输出 weekly_money 的所有子元素详情
        local weeklyChildren = weekly_money:GetChildren()
        if #weeklyChildren > 0 then
            local childrenInfo = {}
            for _, child in ipairs(weeklyChildren) do
                local className = child.ClassName or "Unknown"
                table.insert(childrenInfo, child.Name .. "(" .. className .. ")")
            end
            PlutoX.debug("[排行榜] tryGetContents: weekly_money 子元素: " .. table.concat(childrenInfo, ", "))
        else
            PlutoX.debug("[排行榜] tryGetContents: weekly_money 没有子元素")
        end
        
        local Screen = weekly_money:FindFirstChild("Screen")
        if not Screen then
            PlutoX.debug("[排行榜] tryGetContents: ❌ Screen 不存在")
            return nil
        end
        
        local Leaderboard = Screen:FindFirstChild("Leaderboard")
        if not Leaderboard then
            PlutoX.debug("[排行榜] tryGetContents: ❌ Leaderboard 不存在")
            return nil
        end
        
        local Contents = Leaderboard:FindFirstChild("Contents")
        if not Contents then
            PlutoX.debug("[排行榜] tryGetContents: ❌ Contents 不存在")
            return nil
        end
        
        local childrenCount = #Contents:GetChildren()
        PlutoX.debug("[排行榜] tryGetContents: ✅ 找到Contents，子元素数量: " .. childrenCount)
        
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
            PlutoX.debug("[排行榜] tryGetContents: 前5个子元素: " .. table.concat(sampleChildren, ", "))
        end
        
        return Contents
    end)
    
    if not ok then
        PlutoX.debug("[排行榜] tryGetContents: ❌ 发生错误: " .. tostring(result))
    end
    
    return ok and result or nil
end

local function parseContents(contents)
    local rank = 1
    local leaderboardList = {}
    local childrenCount = #contents:GetChildren()
    
    PlutoX.debug("[排行榜] parseContents: Contents子元素数量: " .. childrenCount)
    
    -- 输出完整榜单（仅在首次检测时输出）
    if not leaderboardConfig.hasFetched then
        PlutoX.debug("[排行榜] ========== 完整榜单 ==========")
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
            PlutoX.debug("[排行榜] " .. entry)
        end
        PlutoX.debug("[排行榜] ==========================")
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
                PlutoX.debug("[排行榜] ✅ 找到玩家ID: " .. childId .. ", 排名: #" .. foundRank .. " (扫描了 " .. foundEntries .. " 个有效条目)")
                return foundRank, true
            end
            rank = rank + 1
        end
    end
    PlutoX.debug("[排行榜] ❌ 未在排行榜中找到玩家ID: " .. userId .. " (扫描了 " .. foundEntries .. " 个有效条目)")
    return nil, false
end

local function fetchPlayerRank()
    local currentTime = tick()
    
    -- 如果正在获取中，返回缓存值（如果有）
    if leaderboardConfig.isFetching then
        PlutoX.debug("[排行榜] 正在获取中，返回缓存值")
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
                
                PlutoX.debug("[排行榜] ✅ 使用API数据，排名: " .. (rank or "未上榜"))
            else
                -- API没有数据或调用失败，继续从游戏中获取
                PlutoX.debug("[排行榜] API无数据或获取失败，继续从游戏中获取...")
                -- 临时保存isFetching状态，因为fetchPlayerRankFromGame会修改它
                local wasFetching = leaderboardConfig.isFetching
                leaderboardConfig.isFetching = true
                
                -- 直接从游戏中获取
                local gameRank, gameIsOnLeaderboard = nil, false
                local leaderboardEntries = nil
                
                -- 尝试直接获取
                local contents = tryGetContents(2)
                if contents then
                    PlutoX.debug("[排行榜] ✅ 直接获取成功")
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
                                    PlutoX.debug("[排行榜] API返回0条数据，直接获取成功后立即上传...")
                                    uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
                                    PlutoX.debug("[排行榜] 排行榜数据上传完成")
                                end)
                            end)
                        end
                    end
                else
                    -- 尝试远程加载
                    PlutoX.debug("[排行榜] 直接获取失败，使用远程加载...")
                    pcall(function()
                        player:RequestStreamAroundAsync(leaderboardConfig.position, leaderboardConfig.streamTimeout)
                    end)
                    
                    -- 等待加载
                    wait(1)
                    contents = tryGetContents(1)
                    if contents then
                        PlutoX.debug("[排行榜] ✅ 远程加载成功")
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
                            PlutoX.debug("[排行榜] 远程加载提取到 " .. #leaderboardEntries .. " 条排行榜数据")
                            
                            -- 立即上传排行榜数据（API返回0条时）
                            if leaderboardEntries and #leaderboardEntries > 0 then
                                spawn(function()
                                    pcall(function()
                                        PlutoX.debug("[排行榜] API返回0条数据，远程加载成功后立即上传...")
                                        uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
                                        PlutoX.debug("[排行榜] 排行榜数据上传完成")
                                    end)
                                end)
                            end
                        end
                    else
                        -- 远程加载也失败，尝试传送玩家到排行榜位置
                        PlutoX.debug("[排行榜] 远程加载失败，尝试传送玩家...")
                        
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
                                PlutoX.debug("[排行榜] ✅ 传送后成功获取排行榜，子元素数量: " .. childrenCount)
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
                                PlutoX.debug("[排行榜] 传送后提取到 " .. #leaderboardEntries .. " 条排行榜数据")
                                
                                -- 立即传送回原位置并恢复速度
                                teleport(originalPosition)
                                restoreVelocities()
                                PlutoX.debug("[排行榜] 已传送回原位置并恢复运动状态")
                                
                                -- 上传排行榜数据到网站
                                local shouldUpload = false
                                if apiSuccess and apiData and #apiData == 0 then
                                    -- API返回0条数据，立即上传
                                    shouldUpload = true
                                    PlutoX.debug("[排行榜] API返回0条数据，准备立即上传")
                                elseif (tick() - (leaderboardConfig.lastUploadTime or 0)) >= leaderboardConfig.uploadCooldown then
                                    -- 冷却时间已到，允许上传
                                    shouldUpload = true
                                    PlutoX.debug("[排行榜] 冷却时间已到，准备上传")
                                else
                                    PlutoX.debug("[排行榜] 跳过上传（冷却中，剩余: " .. string.format("%.0f", leaderboardConfig.uploadCooldown - (tick() - (leaderboardConfig.lastUploadTime or 0))) .. "秒）")
                                end
                                
                                if shouldUpload and leaderboardEntries and #leaderboardEntries > 0 then
                                    spawn(function()
                                        pcall(function()
                                            PlutoX.debug("[排行榜] 开始上传排行榜数据到网站...")
                                            uploadLeaderboardToWebsiteWithEntries(leaderboardEntries)
                                            PlutoX.debug("[排行榜] 排行榜数据上传完成")
                                        end)
                                    end)
                                end
                            else
                                -- 传送回原位置
                                teleport(originalPosition)
                                restoreVelocities()
                                PlutoX.debug("[排行榜] 传送后仍无法获取排行榜")
                            end
                        else
                            PlutoX.debug("[排行榜] 无法获取玩家位置，无法传送")
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
                
                PlutoX.debug("[排行榜] 游戏内获取完成，排名: " .. (gameRank or "未上榜"))
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

-- 从游戏中获取排行榜（原有逻辑）
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
    PlutoX.debug("[排行榜] ========== 开始检测排行榜 ==========")
    PlutoX.debug("[排行榜] 玩家: " .. username .. " (ID: " .. userId .. ")")
    
    local contents = tryGetContents(2)
    if contents then
        PlutoX.debug("[排行榜] ✅ 直接获取成功")
        local rank, isOnLeaderboard = parseContents(contents)
        -- 更新缓存
        leaderboardConfig.cachedRank = rank
        leaderboardConfig.cachedIsOnLeaderboard = isOnLeaderboard
        leaderboardConfig.lastFetchTime = currentTime
        leaderboardConfig.lastFetchSuccess = true
        leaderboardConfig.hasFetched = true
        leaderboardConfig.isFetching = false
        
        -- 立即上传排行榜数据到网站
        if (tick() - (leaderboardConfig.lastUploadTime or 0)) >= leaderboardConfig.uploadCooldown then
            spawn(function()
                pcall(function()
                    PlutoX.debug("[排行榜] 开始上传排行榜数据到网站...")
                    uploadLeaderboardToWebsite()
                    PlutoX.debug("[排行榜] 排行榜数据上传完成")
                end)
            end)
        else
            PlutoX.debug("[排行榜] 跳过上传（冷却中，剩余: " .. string.format("%.0f", leaderboardConfig.uploadCooldown - (tick() - (leaderboardConfig.lastUploadTime or 0))) .. "秒）")
        end

        return rank, isOnLeaderboard
    end
    
    PlutoX.debug("[排行榜] 直接获取失败，使用 RequestStreamAroundAsync 远程加载...")
    
    local success, err = pcall(function()
        PlutoX.debug("[排行榜] RequestStreamAroundAsync 调用参数: position=" .. tostring(leaderboardConfig.position) .. ", timeout=" .. leaderboardConfig.streamTimeout)
        player:RequestStreamAroundAsync(leaderboardConfig.position, leaderboardConfig.streamTimeout)
    end)
    
    if not success then
        PlutoX.warn("[排行榜] RequestStreamAroundAsync 失败: " .. tostring(err))
        PlutoX.debug("[排行榜] ========== 远程加载失败 ==========")
        -- 失败时设置较短的缓存时间（30秒），避免频繁重试
        leaderboardConfig.cachedRank = nil
        leaderboardConfig.cachedIsOnLeaderboard = false
        leaderboardConfig.lastFetchTime = currentTime
        leaderboardConfig.lastFetchSuccess = false
        leaderboardConfig.hasFetched = true
        leaderboardConfig.isFetching = false
        return nil, false
    end
    
    PlutoX.debug("[排行榜] ✅ RequestStreamAroundAsync 调用成功，开始轮询检测...")
    
    -- 轮询检测排行榜是否加载完成
    local checkStartTime = tick()
    local maxCheckTime = leaderboardConfig.streamTimeout
    local checkInterval = 0.5
    local pollCount = 0
    
    while (tick() - checkStartTime) < maxCheckTime do
        pollCount = pollCount + 1
        wait(checkInterval)
        local elapsed = tick() - checkStartTime
        PlutoX.debug("[排行榜] 轮询 #" .. pollCount .. " (已等待: " .. string.format("%.1f", elapsed) .. "秒)")
        
        contents = tryGetContents(1)
        if contents then
            local childrenCount = #contents:GetChildren()
            PlutoX.debug("[排行榜] ✅ 远程加载成功 (耗时: " .. string.format("%.1f", elapsed) .. "秒, 轮询次数: " .. pollCount .. "), 子元素数量: " .. childrenCount)
            local rank, isOnLeaderboard = parseContents(contents)
            -- 更新缓存
            leaderboardConfig.cachedRank = rank
            leaderboardConfig.cachedIsOnLeaderboard = isOnLeaderboard
            leaderboardConfig.lastFetchTime = currentTime
            leaderboardConfig.lastFetchSuccess = true
            leaderboardConfig.hasFetched = true
            leaderboardConfig.isFetching = false
            
            -- 立即上传排行榜数据到网站
            if (tick() - (leaderboardConfig.lastUploadTime or 0)) >= leaderboardConfig.uploadCooldown then
                spawn(function()
                    pcall(function()
                        PlutoX.debug("[排行榜] 开始上传排行榜数据到网站...")
                        uploadLeaderboardToWebsite()
                        PlutoX.debug("[排行榜] 排行榜数据上传完成")
                    end)
                end)
            else
                PlutoX.debug("[排行榜] 跳过上传（冷却中，剩余: " .. string.format("%.0f", leaderboardConfig.uploadCooldown - (tick() - (leaderboardConfig.lastUploadTime or 0))) .. "秒）")
            end
            
            return rank, isOnLeaderboard
        end
    end
    
    PlutoX.debug("[排行榜] ========== 远程加载失败 (超时)，尝试传送玩家到排行榜位置 ==========")
    
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
    
    PlutoX.debug("[排行榜] 保存原始位置，准备传送...")
    
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
        PlutoX.debug("[排行榜] 已保存 " .. #savedVelocities .. " 个部件的速度状态")
    elseif character and character.PrimaryPart then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                savedVelocities[part] = {
                    velocity = part.Velocity,
                    rotVelocity = part.RotVelocity
                }
            end
        end
        PlutoX.debug("[排行榜] 已保存角色速度状态")
    end
    
    -- 传送函数
    local function teleport(position)
        if originalVehicle then
            originalVehicle:PivotTo(position)
            PlutoX.debug("[排行榜] 传送车辆")
        else
            character:PivotTo(position)
            PlutoX.debug("[排行榜] 传送角色")
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
        PlutoX.debug("[排行榜] 已恢复速度状态")
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
        PlutoX.debug("[排行榜] ✅ 传送后成功获取排行榜，子元素数量: " .. childrenCount)
        local rank, isOnLeaderboard = parseContents(contents)
        
        -- 立即传送回原位置并恢复速度
        teleport(originalPosition)
        restoreVelocities()
        PlutoX.debug("[排行榜] 已传送回原位置并恢复运动状态")
        
-- 立即上传排行榜数据到网站
        if (tick() - (leaderboardConfig.lastUploadTime or 0)) >= leaderboardConfig.uploadCooldown then
            spawn(function()
                pcall(function()
                    PlutoX.debug("[排行榜] 开始上传排行榜数据到网站...")
                    uploadLeaderboardToWebsite()
                    PlutoX.debug("[排行榜] 排行榜数据上传完成")
                end)
            end)
        else
            PlutoX.debug("[排行榜] 跳过上传（冷却中，剩余: " .. string.format("%.0f", leaderboardConfig.uploadCooldown - (tick() - (leaderboardConfig.lastUploadTime or 0))) .. "秒）")
        end
        
        -- 立即传送回原位置并恢复速度
        teleport(originalPosition)
        restoreVelocities()
        PlutoX.debug("[排行榜] 已传送回原位置并恢复运动状态")
        
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

-- 注册排行榜数据类型
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

-- 自动生成车辆功能
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
    
    PlutoX.debug("[AutoSpawnVehicle] 找到", vehicleCount, "辆拥有的车辆")
    
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

-- ATM 自动抢劫功能
local function getRobbedAmount()
    local success, amount = pcall(function()
        local character = workspace:FindFirstChild(player.Name)
        if not character then
            PlutoX.debug("[AutoRob] 警告: 无法找到角色对象")
            return 0
        end
        
        local head = character:FindFirstChild("Head")
        if not head then
            PlutoX.debug("[AutoRob] 警告: 无法找到角色头部")
            return 0
        end
        
        local billboard = head:FindFirstChild("CharacterBillboard")
        if not billboard then
            PlutoX.debug("[AutoRob] 警告: 无法找到角色公告牌")
            return 0
        end
        
        local children = billboard:GetChildren()
        if #children < 4 then
            PlutoX.debug("[AutoRob] 警告: 公告牌子元素数量不足，当前数量: " .. #children)
            return 0
        end
        
        local textLabel = children[4]
        if not textLabel then
            PlutoX.debug("[AutoRob] 警告: 无法找到第4个子元素")
            return 0
        end
        
        if not textLabel.ContentText then
            PlutoX.debug("[AutoRob] 警告: 文本标签ContentText为空")
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
        local enabled = dropOffPoint.Enabled
        PlutoX.debug("[DropOff] 交付点enabled状态: " .. tostring(enabled))
        return enabled
    else
        PlutoX.warn("[DropOff] 无法找到交付点Billboard（已尝试" .. maxRetries .. "次）")
        return false
    end
end



local function checkRobberyCompletion(previousAmount)
    local currentAmount = getRobbedAmount()
    local change = currentAmount - (previousAmount or 0)
    
    PlutoX.debug("[AutoRob] 金额检测结果:")
    PlutoX.debug("  - 之前金额: " .. formatNumber(previousAmount))
    PlutoX.debug("  - 当前金额: " .. formatNumber(currentAmount))
    PlutoX.debug("  - 变化量: " .. (change >= 0 and "+" or "") .. formatNumber(change))
    
    if change > 0 then
        PlutoX.debug("[AutoRob] ✓ 检测到抢劫成功获得金额: +" .. formatNumber(change))
        return true, change
    elseif change < 0 then
        PlutoX.debug("[AutoRob] ⚠ 检测到金额减少: " .. formatNumber(change))
        return false, change
    else
        PlutoX.debug("[AutoRob] - 金额无变化")
        return false, 0
    end
end

local function enhancedDeliveryFailureRecovery(robbedAmount, originalTarget, tempTargetRef)
    PlutoX.debug("[Recovery] === 启动投放失败恢复机制 ===")
    PlutoX.debug("[Recovery] 当前已抢金额: " .. formatNumber(robbedAmount))
    PlutoX.debug("[Recovery] 原始目标金额: " .. formatNumber(originalTarget))

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
        PlutoX.debug("[Recovery] 已传送到安全位置重置状态")
    end

    task.wait(1)

    local currentRobbedAmount = getRobbedAmount() or 0
    PlutoX.debug("[Recovery] 重置后已抢金额: " .. formatNumber(currentRobbedAmount))

    if currentRobbedAmount > 0 then
        PlutoX.debug("[Recovery] 发现剩余金额，尝试再次投放...")
        local retrySuccess, retryAttempts, retryDelivered = forceDeliverRobbedAmount(false)

        if retrySuccess then
            PlutoX.debug("[Recovery] ✓ 重试投放成功！金额: " .. formatNumber(retryDelivered))
            PlutoX.debug("[Recovery] === 投放失败恢复机制结束（成功） ===")
            return true, retryDelivered
        else
            PlutoX.debug("[Recovery] ✗ 重试投放仍然失败")
        end
    end

    local newTempTarget = currentRobbedAmount + originalTarget
    tempTargetRef.value = newTempTarget

    PlutoX.debug("[Recovery] ✗ 投放失败，继续增加临时目标: " .. formatNumber(newTempTarget))
    PlutoX.debug("[Recovery] === 投放失败恢复机制结束（失败，增加临时目标） ===")

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
    autoFarmEnabled = false,
    autoFarmSpeed = 300,
    robTargetAmount = 0,
    notifyCash = false,
    notifyLeaderboard = false,
    leaderboardKick = false,
}

for key, value in pairs(dataTypeConfigs) do
    defaultConfig[key] = value
end

local configManager = PlutoX.createConfigManager(configFile, HttpService, UILibrary, username, defaultConfig)
local config = configManager:loadConfig()

-- forceDeliverRobbedAmount 函数
local function forceDeliverRobbedAmount(isShutdown)
    PlutoX.debug("[AutoRob] === 开始强制投放流程 ===")
    
    isDeliveryInProgress = true
    
    local collectionService = game:GetService("CollectionService")
    local localPlayer = game.Players.LocalPlayer
    local character = localPlayer.Character
    local dropOffSpawners = workspace.Game.Jobs.CriminalDropOffSpawners
    
    if not dropOffSpawners or not dropOffSpawners.CriminalDropOffSpawnerPermanent then
        PlutoX.warn("[AutoRob] 结束位置未找到!")
        isDeliveryInProgress = false
        return false
    end
    
    local robbedAmount = getRobbedAmount() or 0
    PlutoX.debug("[AutoRob] 当前已抢金额: " .. formatNumber(robbedAmount))
    
    if robbedAmount > 0 then
        PlutoX.debug("[AutoRob] 清理背包中的金钱袋...")
        for _, bag in pairs(collectionService:GetTagged("CriminalMoneyBagTool")) do
            pcall(function()
                bag:Destroy()
            end)
            task.wait(0.1)
        end
    end

    local deliverySuccess = false
    local deliveryAttempts = 0
    local maxDeliveryAttempts = 10
    local initialRobbedAmount = robbedAmount
    local totalDeliveredAmount = 0
    local VirtualInputManager = game:GetService("VirtualInputManager")

    while not deliverySuccess and deliveryAttempts < maxDeliveryAttempts do
        deliveryAttempts = deliveryAttempts + 1
        PlutoX.debug("[AutoRob] 强制投放 - 第 " .. deliveryAttempts .. " 次传送尝试")
        
        local dropOffEnabled = checkDropOffPointEnabled()
        if not dropOffEnabled then
            PlutoX.debug("[AutoRob] 投放点不可用，等待2秒后重试...")
            task.wait(2)
            
            if not checkDropOffPointEnabled() then
                PlutoX.debug("[AutoRob] 投放点仍然不可用，跳过本次尝试")
                task.wait(1)
            else
                if character and character.PrimaryPart then
                    character.PrimaryPart.Velocity = Vector3.zero
                    character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                    PlutoX.debug("[AutoRob] 已传送到交付位置")
                end

                PlutoX.debug("[AutoRob] 等待角色稳定...")
                task.wait(1)

                PlutoX.debug("[AutoRob] 执行跳跃动作触发交付")
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

                PlutoX.debug("[AutoRob] 检测金额是否到账...")
                local checkStart = tick()
                local checkTimeout = 5
                local lastCheckAmount = initialRobbedAmount

                repeat
                    task.wait(0.3)
                    if character and character.PrimaryPart then
                        character.PrimaryPart.Velocity = Vector3.zero
                        character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                    end

                    local currentRobbedAmount = getRobbedAmount() or 0

                    if currentRobbedAmount ~= lastCheckAmount then
                        if currentRobbedAmount < lastCheckAmount then
                            local deliveredAmount = lastCheckAmount - currentRobbedAmount
                            totalDeliveredAmount = totalDeliveredAmount + deliveredAmount
                            PlutoX.debug("[AutoRob] ✓ 检测到已抢金额减少: " .. formatNumber(deliveredAmount))
                        end
                        lastCheckAmount = currentRobbedAmount
                    end

                    if currentRobbedAmount == 0 then
                        PlutoX.debug("[AutoRob] ✓ 交付成功！已抢金额已清零")
                        deliverySuccess = true
                        break
                    end
                until tick() - checkStart > checkTimeout
                
                if not deliverySuccess then
                    local currentRobbedAmount = getRobbedAmount() or 0
                    if currentRobbedAmount < initialRobbedAmount * 0.5 then
                        PlutoX.debug("[AutoRob] 金额显著减少，继续等待...")
                        task.wait(3)
                        currentRobbedAmount = getRobbedAmount()
                        if currentRobbedAmount == 0 then
                            PlutoX.debug("[AutoRob] ✓ 交付成功！")
                            deliverySuccess = true
                        end
                    else
                        PlutoX.debug("[AutoRob] ✗ 本次传送未成功交付，当前已抢金额: " .. formatNumber(currentRobbedAmount))
                        task.wait(1)
                    end
                end
            end
        else
            if character and character.PrimaryPart then
                character.PrimaryPart.Velocity = Vector3.zero
                character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                PlutoX.debug("[AutoRob] 已传送到交付位置")
            end

            PlutoX.debug("[AutoRob] 等待角色稳定...")
            task.wait(1)

            PlutoX.debug("[AutoRob] 执行跳跃动作触发交付")
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

            PlutoX.debug("[AutoRob] 等待跳跃动作完成...")
            task.wait(1.5)

            PlutoX.debug("[AutoRob] 保持位置等待交付处理...")
            local holdTime = tick()
            repeat
                task.wait(0.1)
                if character and character.PrimaryPart then
                    character.PrimaryPart.Velocity = Vector3.zero
                    character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                end
            until tick() - holdTime > 2

            PlutoX.debug("[AutoRob] 检测金额是否到账...")
            local checkStart = tick()
            local checkTimeout = 5

            repeat
                task.wait(0.3)
                if character and character.PrimaryPart then
                    character.PrimaryPart.Velocity = Vector3.zero
                    character:PivotTo(dropOffSpawners.CriminalDropOffSpawnerPermanent.CFrame + Vector3.new(0, 5, 0))
                end

                local currentRobbedAmount = getRobbedAmount() or 0

                if currentRobbedAmount ~= lastCheckAmount then
                    if currentRobbedAmount < lastCheckAmount then
                        local deliveredAmount = lastCheckAmount - currentRobbedAmount
                        totalDeliveredAmount = totalDeliveredAmount + deliveredAmount
                        PlutoX.debug("[AutoRob] ✓ 检测到已抢金额减少: " .. formatNumber(deliveredAmount))
                    end
                    lastCheckAmount = currentRobbedAmount
                end

                if currentRobbedAmount == 0 then
                    PlutoX.debug("[AutoRob] ✓ 交付成功！已抢金额已清零")
                    deliverySuccess = true
                    break
                end
            until tick() - checkStart > checkTimeout
            
            if not deliverySuccess then
                local currentRobbedAmount = getRobbedAmount() or 0
                if currentRobbedAmount < initialRobbedAmount * 0.5 then
                    PlutoX.debug("[AutoRob] 金额显著减少，继续等待...")
                    task.wait(3)
                    currentRobbedAmount = getRobbedAmount()
                    if currentRobbedAmount == 0 then
                        PlutoX.debug("[AutoRob] ✓ 交付成功！")
                        deliverySuccess = true
                    end
                else
                    PlutoX.debug("[AutoRob] ✗ 本次传送未成功交付，当前已抢金额: " .. formatNumber(currentRobbedAmount))
                    task.wait(1)
                end
            end
        end
    end
    
    if deliverySuccess then
        PlutoX.debug("[AutoRob] ✓ 强制投放完成，共尝试 " .. deliveryAttempts .. " 次")
    elseif isShutdown then
        PlutoX.warn("[AutoRob] ✗ 关闭时投放失败，达到最大尝试次数(" .. maxDeliveryAttempts .. ")")
    else
        PlutoX.warn("[AutoRob] ✗ 强制投放失败，达到最大尝试次数(" .. maxDeliveryAttempts .. ")")
    end
    
    PlutoX.debug("[AutoRob] === 强制投放流程结束 ===")
    PlutoX.debug("[AutoRob] 总计投放金额: " .. formatNumber(totalDeliveredAmount))
    
    isDeliveryInProgress = false
    
    return deliverySuccess, deliveryAttempts, initialRobbedAmount
end

-- checkAndForceDelivery 函数
local function checkAndForceDelivery(tempTarget)
    local robbedAmount = getRobbedAmount() or 0
    local targetAmount = tempTarget or config.robTargetAmount or 0

    if targetAmount > 0 and robbedAmount >= targetAmount then
        PlutoX.debug("[AutoRob] ⚠ 已抢金额达到或超过目标: " .. formatNumber(robbedAmount) .. " >= " .. formatNumber(targetAmount))

        local dropOffEnabled = checkDropOffPointEnabled()

        if not dropOffEnabled then
            PlutoX.debug("[AutoRob] 交付点不可用，继续抢劫...")
            return false, 0, 0
        end

        PlutoX.debug("[AutoRob] 交付点可用，执行强制投放...")

        local success, attempts, deliveredAmount = forceDeliverRobbedAmount(false)

        if success then
            UILibrary:Notify({
                Title = "目标达成",
                Text = string.format("获得 +%s\n尝试次数: %d", formatNumber(deliveredAmount), attempts),
                Duration = 5
            })

            task.wait(2)
            return true
        else
            PlutoX.warn("[AutoRob] 投放失败，自动创建临时目标继续抢劫")
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
        PlutoX.debug("[DropOff] 初始交付点状态: " .. tostring(currentStatus))
        return false
    end
    
    if not lastDropOffEnabledStatus and currentStatus then
        PlutoX.debug("[DropOff] 交付点从不可用变为可用！")
        
        local currentRobbedAmount = getRobbedAmount() or 0
        if currentRobbedAmount > 0 then
            config.robTargetAmount = currentRobbedAmount
            configManager:saveConfig()
            
            UILibrary:Notify({
                Title = "目标金额已更新",
                Text = string.format("交付点可用，目标金额更新为: %s", formatNumber(currentRobbedAmount)),
                Duration = 5
            })
            
            PlutoX.debug("[DropOff] 目标金额已更新为当前已抢劫金额: " .. formatNumber(currentRobbedAmount))
        end
        
        lastDropOffEnabledStatus = currentStatus
        return true
    end
    
    lastDropOffEnabledStatus = currentStatus
    return false
end

local function claimPlaytimeRewards()
    if not config.onlineRewardEnabled then
        PlutoX.debug("[PlaytimeRewards] 功能未启用")
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
                        PlutoX.debug("[PlaytimeRewards] 所有奖励已领取")
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
                                        PlutoX.debug("[PlaytimeRewards] 已领取奖励 ID:", i)
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

-- AutoFarm 自动刷金功能
local isAutoFarmActive = false
local autoFarmOriginalPosition = nil

local function performAutoFarm()
    if not config.autoFarmEnabled then
        PlutoX.debug("[AutoFarm] 功能未启用")
        return
    end

    PlutoX.debug("[AutoFarm] 开始执行自动刷金...")
    isAutoFarmActive = true

    -- 移动位置配置（直线移动，只沿 X 轴）
    local startPos = Vector3.new(-18121, 35, -418)
    local endPos = Vector3.new(-18135, 35, -418)  -- Z 保持不变，直线移动
    local moveDuration = 10 -- 移动10秒

    -- 计算移动方向（X轴方向）
    local direction = (endPos - startPos).Unit

    spawn(function()
        while isAutoFarmActive and config.autoFarmEnabled do
            pcall(function()
                local localPlayer = Players.LocalPlayer
                if not localPlayer then return end

                local character = localPlayer.Character
                if not character then return end

                -- 获取玩家车辆
                local vehicles = workspace:FindFirstChild("Vehicles")
                if not vehicles then return end

                local vehicle = vehicles:FindFirstChild(localPlayer.Name)
                if not vehicle then
                    PlutoX.debug("[AutoFarm] 未找到车辆，等待生成...")
                    task.wait(3)
                    return
                end

                -- 保存原始位置
                if not autoFarmOriginalPosition then
                    autoFarmOriginalPosition = CFrame.new(startPos)
                    PlutoX.debug("[AutoFarm] 保存起始位置")
                end

                -- 获取速度配置
                local speed = config.autoFarmSpeed or 300

                -- 计算目标位置：从起点沿着方向移动 (速度 * 10秒) 的距离
                local moveDistance = speed * moveDuration
                local targetPos = startPos + direction * moveDistance

                PlutoX.debug("[AutoFarm] 开始移动，速度: " .. speed .. ", 目标距离: " .. moveDistance)

                -- 使用物理方式移动车辆（不使用 TweenService）
                local RunService = game:GetService("RunService")
                local startTime = tick()
                local moved = false

                -- 车头朝向目标方向（CFrame.lookAt）
                local lookAtPos = targetPos  -- 车头对准目标位置

                while tick() - startTime < moveDuration and isAutoFarmActive do
                    local elapsed = tick() - startTime
                    local progress = elapsed / moveDuration

                    -- 计算当前位置（线性插值）
                    local currentPos = startPos + direction * (moveDistance * progress)

                    -- 设置车辆位置和朝向（车头对准移动方向）
                    local newCFrame = CFrame.lookAt(currentPos, lookAtPos)
                    vehicle:PivotTo(newCFrame)

                    -- 设置车辆速度
                    if vehicle.PrimaryPart then
                        vehicle.PrimaryPart.AssemblyLinearVelocity = direction * speed
                    end

                    -- 给所有部件设置速度（确保车辆整体移动）
                    for _, part in ipairs(vehicle:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.AssemblyLinearVelocity = direction * speed
                        end
                    end

                    RunService.Heartbeat:Wait()
                end

                PlutoX.debug("[AutoFarm] 移动完成，传送回原位置")

                -- 传送回原位置
                if autoFarmOriginalPosition then
                    vehicle:PivotTo(autoFarmOriginalPosition)
                    task.wait(0.5)
                end
            end)

            task.wait(1) -- 循环间隔
        end

        PlutoX.debug("[AutoFarm] 自动刷金已停止")
    end)
end

local function performAutoSpawnVehicle()
    if not config.autoSpawnVehicleEnabled then
        PlutoX.debug("[AutoSpawnVehicle] 功能未启用")
        return
    end

    PlutoX.debug("[AutoSpawnVehicle] 开始执行车辆生成...")
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
    
    PlutoX.debug("[AutoSpawnVehicle] 搜索完成，耗时:", string.format("%.2f", searchTime), "秒")

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

-- Auto Rob ATMs功能
local function performAutoRobATMs()
    isAutoRobActive = true
    PlutoX.debug("[AutoRobATMs] 自动抢劫已启动，活动状态: " .. tostring(isAutoRobActive))
    
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local requestStartJobSession = remotes:WaitForChild("RequestStartJobSession")
    
    local args = {
        "Criminal",
        "jobPad"
    }
    requestStartJobSession:FireServer(unpack(args))
    PlutoX.debug("[AutoRobATMs] 已启动 Criminal Job")
    
    local locationRemote = remotes:WaitForChild("Location")
    
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    
    originalLocationNameCall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if method == "FireServer" and self.Name == "Location" then
            if #args >= 2 and args[1] == "Enter" then
                PlutoX.debug("[AutoRobATMs] 拦截进入区域请求:", args[2])
                return
            end
        end
        
        return originalLocationNameCall(self, ...)
    end)
    
    setreadonly(mt, true)
    
    spawn(function()
        local collectionService = game:GetService("CollectionService")
        local localPlayer = game.Players.LocalPlayer
        local character = localPlayer.Character
        local dropOffSpawners = workspace.Game.Jobs.CriminalDropOffSpawners
        local originalTargetAmount = config.robTargetAmount
        local tempTargetAmount = nil

        local lastSuccessfulRobbery = tick()
        local noATMFoundCount = 0
        local maxNoATMFoundCount = 5

        while isAutoRobActive do
            task.wait()
            local success, err = pcall(function()
                local timeSinceLastRobbery = tick() - lastSuccessfulRobbery
                if timeSinceLastRobbery > 120 then
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
                end

                local robbedAmount = getRobbedAmount() or 0
                local targetAmount = tempTargetAmount or config.robTargetAmount or 0

                if targetAmount > 0 and robbedAmount >= targetAmount then
                    local dropOffEnabled = checkDropOffPointEnabled()

                    if not dropOffEnabled then
                        lastSuccessfulRobbery = tick()
                    else
                        local deliverySuccess, deliveryAttempts, deliveredAmount = forceDeliverRobbedAmount(false)

                        if deliverySuccess then
                            if tempTargetAmount then
                                tempTargetAmount = nil
                            end

                            UILibrary:Notify({
                                Title = "抢劫完成",
                                Text = string.format("本次获得: +%s\n交付尝试: %d次", PlutoX.formatNumber(deliveredAmount), deliveryAttempts),
                                Duration = 5
                            })
                            task.wait(2)
                            lastSuccessfulRobbery = tick()
                        else
                            local tempTargetRef = { value = tempTargetAmount }
                            local recoverySuccess, recoveredAmount = enhancedDeliveryFailureRecovery(robbedAmount, originalTargetAmount, tempTargetRef)

                            if recoverySuccess then
                                if tempTargetAmount then
                                    tempTargetAmount = nil
                                end
                                
                                UILibrary:Notify({
                                    Title = "投放成功",
                                    Text = string.format("临时目标完成，恢复原目标\n获得: +%s\n原目标: %s", PlutoX.formatNumber(recoveredAmount), PlutoX.formatNumber(originalTargetAmount)),
                                    Duration = 5
                                })
                                task.wait(2)
                                lastSuccessfulRobbery = tick()
                            else
                                local currentRobbedAmount = getRobbedAmount() or 0
                                tempTargetAmount = currentRobbedAmount + originalTargetAmount

                                UILibrary:Notify({
                                    Title = "临时目标增加",
                                    Text = string.format("投放失败，继续增加临时目标\n新目标: %s", PlutoX.formatNumber(tempTargetAmount)),
                                    Duration = 3
                                })

                                lastSuccessfulRobbery = tick()
                            end
                        end
                    end
                end

                local function robATM(atm, atmType, foundCountRef)
                    if not isAutoRobActive then return false end

                    foundCountRef.count = foundCountRef.count + 1
                    local teleportTime = atmType == "tagged" and 1 or 0.2
                    local atmTypeName = atmType == "tagged" and "ATM" or "nil ATM"

                    PlutoX.debug("[AutoRob] 开始抢劫" .. atmTypeName)

                    local teleportStart = tick()
                    repeat
                        task.wait()
                        if character and character.PrimaryPart then
                            character.PrimaryPart.Velocity = Vector3.zero
                            character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                        end
                        localPlayer.ReplicationFocus = nil
                    until tick() - teleportStart > teleportTime or not isAutoRobActive

                    if not isAutoRobActive then return false end

                    game:GetService("ReplicatedStorage").Remotes.AttemptATMBustStart:InvokeServer(atm)

                    local progressStart = tick()
                    repeat
                        task.wait()
                        if character and character.PrimaryPart then
                            character.PrimaryPart.Velocity = Vector3.zero
                            character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                        end
                        localPlayer.ReplicationFocus = nil
                    until tick() - progressStart > 2.5 or not isAutoRobActive

                    if not isAutoRobActive then return false end

                    local beforeRobberyAmount = getRobbedAmount() or 0
                    PlutoX.debug("[AutoRob] 开始抢劫" .. atmTypeName .. "，当前已抢金额: " .. formatNumber(beforeRobberyAmount))

                    game:GetService("ReplicatedStorage").Remotes.AttemptATMBustComplete:InvokeServer(atm)
                    PlutoX.debug("[AutoRob] 已调用" .. atmTypeName .. "的AttemptATMBustComplete，等待抢劫完成...")

                    local cooldownStart = tick()
                    repeat
                        task.wait()
                        if character and character.PrimaryPart then
                            character.PrimaryPart.Velocity = Vector3.zero
                            character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                        end
                    until tick() - cooldownStart > 3 or (character and character:GetAttribute("ATMBustDebounce")) or not isAutoRobActive

                    repeat
                        task.wait()
                        if character and character.PrimaryPart then
                            character.PrimaryPart.Velocity = Vector3.zero
                            character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                        end
                    until tick() - cooldownStart > 3 or not (character and character:GetAttribute("ATMBustDebounce") and isAutoRobActive)

                    task.wait(0.5)
                    local robberySuccess, amountChange = checkRobberyCompletion(beforeRobberyAmount)

                    if robberySuccess then
                        PlutoX.debug("[AutoRob] ✓ " .. atmTypeName .. "抢劫成功！获得金额: +" .. formatNumber(amountChange))
                        
                        lastSuccessfulRobbery = tick()
                        noATMFoundCount = 0

                        local shouldStop = checkAndForceDelivery(tempTargetAmount)
                        if shouldStop then
                            PlutoX.debug("[AutoRob] 🔄 投放完成，重新开始抢劫循环")
                            return true
                        end
                    else
                        PlutoX.debug("[AutoRob] ⚠ " .. atmTypeName .. "抢劫未获得金额或失败")
                    end

                    return false
                end

                local foundATMCount = {count = 0}

                local taggedATMs = collectionService:GetTagged("CriminalATM")
                for _, atm in pairs(taggedATMs) do
                    if atm:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                        if robATM(atm, "tagged", foundATMCount) then
                            break
                        end
                    end
                end

                for _, obj in pairs(getnilinstances()) do
                    if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                        if robATM(obj, "nil", foundATMCount) then
                            break
                        end
                    end
                end

                if foundATMCount.count == 0 then
                    noATMFoundCount = noATMFoundCount + 1
                    PlutoX.debug("[AutoRobATMs] 未找到可用ATM，计数: " .. noATMFoundCount .. "/" .. maxNoATMFoundCount)

                    if noATMFoundCount >= maxNoATMFoundCount then
                        PlutoX.warn("[AutoRobATMs] 连续" .. maxNoATMFoundCount .. "次未找到ATM，执行搜索重置")

                        PlutoX.debug("[AutoRobATMs] 重置状态...")
                        getfenv().atmloadercooldown = false
                        localPlayer.ReplicationFocus = nil
                        noATMFoundCount = 0

                        local function searchATMs()
                            local taggedATMs = collectionService:GetTagged("CriminalATM")
                            for _, atm in pairs(taggedATMs) do
                                if atm:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                                    return true
                                end
                            end

                            for _, obj in pairs(getnilinstances()) do
                                if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                                    return true
                                end
                            end

                            return false
                        end

                        local spawnersFolder = workspace.Game.Jobs.CriminalATMSpawners

                        -- 新增：直接传送所有spawner
                        if spawnersFolder then
                            local spawners = spawnersFolder:GetChildren()
                            PlutoX.debug("[AutoRobATMs] 直接传送" .. #spawners .. "个spawner")

                            local originalPosition = character and character.PrimaryPart and character:GetPivot() or CFrame.new(0, 50, 0)
                            local foundATM = false

                            for i, spawner in ipairs(spawners) do
                                if not isAutoRobActive then break end

                                if character and character.PrimaryPart then
                                    character:PivotTo(spawner:GetPivot() + Vector3.new(0, 5, 0))
                                    PlutoX.debug("[AutoRobATMs] 传送到spawner " .. i .. "/" .. #spawners)
                                end
                                
                                task.wait(0.5)
                                localPlayer.ReplicationFocus = nil
                                
                                if searchATMs() then
                                    PlutoX.debug("[AutoRobATMs] spawner " .. i .. " 找到ATM")
                                    noATMFoundCount = 0
                                    foundATM = true
                                    break
                                end
                            end

                            if not foundATM and isAutoRobActive then
                                PlutoX.debug("[AutoRobATMs] 所有spawner未找到ATM，传送到中心点")
                                if character and character.PrimaryPart then
                                    character:PivotTo(CFrame.new(0, 50, 0))
                                end
                                task.wait(1)
                                localPlayer.ReplicationFocus = nil

                                if searchATMs() then
                                    PlutoX.debug("[AutoRobATMs] 中心点找到ATM")
                                    noATMFoundCount = 0
                                else
                                    PlutoX.debug("[AutoRobATMs] 中心点未找到ATM，重新开始spawner循环")
                                end
                            end
                        end

                        -- 原逻辑：后台加载spawner
                        if spawnersFolder then
                            local spawners = spawnersFolder:GetChildren()
                            PlutoX.debug("[AutoRobATMs] 后台加载" .. #spawners .. "个spawner")

                            for i, spawner in pairs(spawners) do
                                if not isAutoRobActive then break end

                                pcall(function()
                                    player:RequestStreamAroundAsync(spawner:GetPivot().Position, 1)
                                end)
                                PlutoX.debug("[AutoRobATMs] 加载spawner " .. i .. "/" .. #spawners)

                                task.wait(0.5)

                                if searchATMs() then
                                    PlutoX.debug("[AutoRobATMs] spawner " .. i .. " 找到ATM")
                                    noATMFoundCount = 0
                                    break
                                end
                            end

                            if not searchATMs() and isAutoRobActive then
                                PlutoX.debug("[AutoRobATMs] 所有spawner未找到ATM，加载中心点")
                                pcall(function()
                                    player:RequestStreamAroundAsync(Vector3.new(0, 50, 0), 1)
                                end)
                                task.wait(1)

                                if searchATMs() then
                                    PlutoX.debug("[AutoRobATMs] 中心点找到ATM")
                                    noATMFoundCount = 0
                                else
                                    PlutoX.debug("[AutoRobATMs] 中心点未找到ATM，重新开始spawner循环")
                                end
                            end
                        end

                        PlutoX.debug("[AutoRobATMs] 原逻辑：强制刷新spawner")
                        if spawnersFolder then
                            local spawners = spawnersFolder:GetChildren()
                            PlutoX.debug("[AutoRobATMs] 强制刷新" .. #spawners .. "个spawner")
                            for i, spawner in pairs(spawners) do
                                if i == 1 or i == #spawners or i % 5 == 0 then
                                    PlutoX.debug("[AutoRobATMs] 聚焦spawner " .. i .. "/" .. #spawners)
                                end
                                localPlayer.ReplicationFocus = spawner
                                task.wait(0.2)
                            end
                        else
                            PlutoX.warn("[AutoRobATMs] 无法找到CriminalATMSpawners文件夹")
                        end

                        local searchSuccess = false
                        if character and character.PrimaryPart then
                            PlutoX.debug("[AutoRobATMs] 第1步：传送到中心点搜索")
                            character:PivotTo(CFrame.new(0, 50, 0))
                        else
                            PlutoX.warn("[AutoRobATMs] 无法传送，角色或主要部件不存在")
                        end
                        task.wait(1)
                        localPlayer.ReplicationFocus = nil

                        
                        local taggedATMs = collectionService:GetTagged("CriminalATM")
                        for _, atm in pairs(taggedATMs) do
                            if atm:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                                searchSuccess = true
                                PlutoX.debug("[AutoRobATMs] 中心点找到ATM (tagged)")
                                break
                            end
                        end
                        if not searchSuccess then
                            for _, obj in pairs(getnilinstances()) do
                                if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                                    searchSuccess = true
                                    PlutoX.debug("[AutoRobATMs] 中心点找到ATM (nil)")
                                    break
                                end
                            end
                        end

                        
                        if not searchSuccess then
                            local criminalArea = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("CriminalArea")
                            if criminalArea then
                                local criminalAreaPosition
                                if criminalArea:IsA("Model") or criminalArea:IsA("BasePart") then
                                    criminalAreaPosition = criminalArea:GetPivot()
                                else
                                
                                    local firstChild = criminalArea:FindFirstChildWhichIsA("BasePart")
                                    if firstChild then
                                        criminalAreaPosition = firstChild.CFrame
                                    else
                                    
                                        criminalAreaPosition = CFrame.new(0, 0, 0)
                                    end
                                end
                                if character and character.PrimaryPart then
                                    PlutoX.debug("[AutoRobATMs] 第2步：传送到CriminalArea搜索")
                                    character:PivotTo(criminalAreaPosition + Vector3.new(0, 50, 0))
                                end
                                task.wait(1)
                                localPlayer.ReplicationFocus = nil

                                
                                taggedATMs = collectionService:GetTagged("CriminalATM")
                                for _, atm in pairs(taggedATMs) do
                                    if atm:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                                        searchSuccess = true
                                        PlutoX.debug("[AutoRobATMs] CriminalArea找到ATM (tagged)")
                                        break
                                    end
                                end
                                if not searchSuccess then
                                    for _, obj in pairs(getnilinstances()) do
                                        if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                                            searchSuccess = true
                                            PlutoX.debug("[AutoRobATMs] CriminalArea找到ATM (nil)")
                                            break
                                        end
                                    end
                                end
                            else
                                PlutoX.warn("[AutoRobATMs] 无法找到CriminalArea")
                            end
                        end

                        
                        if character and character.PrimaryPart then
                            PlutoX.debug("[AutoRobATMs] 第3步：传送所有指定目录下的ATM")
                            
                            -- 搜索所有可能的ATM对象
                            local allATMs = {}
                            
                            -- 添加tagged的ATM
                            local taggedATMs = collectionService:GetTagged("CriminalATM")
                            for _, atm in pairs(taggedATMs) do
                                table.insert(allATMs, atm)
                            end
                            
                            -- 添加nil instances中的ATM
                            for _, obj in pairs(getnilinstances()) do
                                if obj.Name == "CriminalATM" then
                                    table.insert(allATMs, obj)
                                end
                            end
                            
                            PlutoX.debug("[AutoRobATMs] 找到" .. #allATMs .. "个ATM对象")
                            
                            -- 传送到每个ATM位置
                            for i, atm in ipairs(allATMs) do
                                if not isAutoRobActive then break end
                                
                                if character and character.PrimaryPart then
                                    character:PivotTo(atm.WorldPivot + Vector3.new(0, 5, 0))
                                    PlutoX.debug("[AutoRobATMs] 传送到ATM " .. i .. "/" .. #allATMs)
                                    task.wait(0.5)
                                    
                                    -- 检查是否有可用的ATM
                                    local foundAvailableATM = false
                                    local taggedATMsCheck = collectionService:GetTagged("CriminalATM")
                                    for _, checkATM in pairs(taggedATMsCheck) do
                                        if checkATM:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                                            foundAvailableATM = true
                                            PlutoX.debug("[AutoRobATMs] 在ATM " .. i .. " 找到可用ATM")
                                            break
                                        end
                                    end
                                    
                                    if not foundAvailableATM then
                                        for _, obj in pairs(getnilinstances()) do
                                            if obj.Name == "CriminalATM" and obj:GetAttribute("State") ~= "Busted" and isAutoRobActive then
                                                foundAvailableATM = true
                                                PlutoX.debug("[AutoRobATMs] 在ATM " .. i .. " 找到可用ATM (nil)")
                                                break
                                            end
                                        end
                                    end
                                    
                                    if foundAvailableATM then
                                        noATMFoundCount = 0
                                        break
                                    end
                                end
                            end
                        else
                            PlutoX.warn("[AutoRobATMs] 无法传送，角色或主要部件不存在")
                        end
                        task.wait(1)
                        localPlayer.ReplicationFocus = nil
                        PlutoX.debug("[AutoRobATMs] ATM搜索已重置，准备重新开始")
                    end
                else
                    noATMFoundCount = 0
                end

                if not (getfenv().atmloadercooldown or targetATM) then
                    getfenv().atmloadercooldown = true
                    PlutoX.debug("[AutoRobATMs] 启动后台ATM加载器")
                    UILibrary:Notify({
                        Title = "加载中",
                        Text = "正在后台加载ATM...",
                        Duration = 3
                    })

                    spawn(function()
                        local spawners = workspace.Game.Jobs.CriminalATMSpawners
                        if not spawners then
                            PlutoX.warn("[AutoRobATMs] 无法找到CriminalATMSpawners")
                        else
                            local spawnerList = spawners:GetChildren()
                            local totalSpawners = #spawnerList
                            PlutoX.debug("[AutoRobATMs] 后台加载spawner数量: " .. totalSpawners)

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
                                    PlutoX.debug("[AutoRobATMs] 后台已加载 " .. processedCount .. "/" .. totalSpawners .. " 个spawner")
                                end
                                localPlayer.ReplicationFocus = spawner
                                task.wait(0.5)
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
                                    task.wait(0.5)
                                end
                            end
                            if nilSpawnerCount > 0 then
                                PlutoX.debug("[AutoRobATMs] nil instances中找到spawner数量: " .. nilSpawnerCount)
                            end
                        end

                        getfenv().atmloadercooldown = false
                        localPlayer.ReplicationFocus = nil
                        PlutoX.debug("[AutoRobATMs] 后台ATM加载器完成")
                    end)
                end
            end)
            
            if not success then
                PlutoX.warn("AutoRobATMs Error:", err)
                noATMFoundCount = 0
                getfenv().atmloadercooldown = false
                localPlayer.ReplicationFocus = nil
            end
        end
        
        PlutoX.debug("[AutoRobATMs] 自动抢劫已停止")
        
        if originalLocationNameCall then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = originalLocationNameCall
            setreadonly(mt, true)
            originalLocationNameCall = nil
            PlutoX.debug("[AutoRobATMs] 已恢复 Location remote")
        end
    end)
end

local webhookManager = PlutoX.createWebhookManager(config, HttpService, UILibrary, gameName, username, configFile)
local disconnectDetector = PlutoX.createDisconnectDetector(UILibrary, webhookManager)
local dataMonitor = PlutoX.createDataMonitor(config, UILibrary, webhookManager, dataTypes, disconnectDetector)
disconnectDetector:init()

-- 设置数据监测器的发送前回调，用于添加排行榜信息
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

-- 启动游戏特定功能
if config.onlineRewardEnabled then
    spawn(claimPlaytimeRewards)
end

if config.autoSpawnVehicleEnabled then
    spawn(performAutoSpawnVehicle)
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

-- 只为支持目标检测的数据类型创建显示标签
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

-- 游戏功能标签页
local featuresTab, featuresContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "游戏功能"
})

-- 在线奖励
local onlineRewardCard = UILibrary:CreateCard(featuresContent)
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

-- 自动生成车辆
local autoSpawnCard = UILibrary:CreateCard(featuresContent)
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

-- AutoFarm 自动刷金
local autoFarmCard = UILibrary:CreateCard(featuresContent, { IsMultiElement = true })
UILibrary:CreateLabel(autoFarmCard, {
    Text = "Auto Farm (-18121,35,-418 → -18135,35,-444)",
})

-- 速度滑块（使用 UILibrary CreateSlider）
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
    Text = "启用自动刷金",
    DefaultState = config.autoFarmEnabled or false,
    Callback = function(state)
        config.autoFarmEnabled = state
        configManager:saveConfig()
        if state then
            spawn(performAutoFarm)
            UILibrary:Notify({
                Title = "AutoFarm 已启动",
                Text = "速度: " .. (config.autoFarmSpeed or 300) .. ", 移动10秒后返回",
                Duration = 5
            })
        else
            isAutoFarmActive = false
            UILibrary:Notify({
                Title = "AutoFarm 已停止",
                Text = "自动刷金已关闭",
                Duration = 3
            })
        end
    end
})

-- ATM 自动抢劫
local autoRobCard = UILibrary:CreateCard(featuresContent, { IsMultiElement = true })
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
                PlutoX.debug("[UI] 关闭自动抢劫，开始投放已抢金额: " .. formatNumber(currentRobbedAmount))
                spawn(function()
                    forceDeliverRobbedAmount(true)
                end)
            else
                PlutoX.debug("[UI] 关闭自动抢劫，无已抢金额需要投放")
                isDeliveryInProgress = false
            end
            
            PlutoX.debug("[UI] 用户关闭自动抢劫功能，设置状态为非活动")
            
            if originalLocationNameCall then
                local mt = getrawmetatable(game)
                setreadonly(mt, false)
                mt.__namecall = originalLocationNameCall
                setreadonly(mt, true)
                originalLocationNameCall = nil
                PlutoX.debug("[UI] 已恢复 Location remote")
            end
        else
            PlutoX.debug("[UI] 用户开启自动抢劫功能")
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

-- 自动购买标签页
local purchaseTab, purchaseContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "自动购买"
})

-- 通知设置标签页
local notifyTab, notifyContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "通知设置"
})

-- Webhook 配置
PlutoX.createWebhookCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end, webhookManager)

-- 通知间隔
PlutoX.createIntervalCard(notifyContent, UILibrary, config, function() configManager:saveConfig() end)

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

-- 数据类型设置区域
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

-- 车辆数据获取功能
local purchaseFunctions = {}

-- 进入车店
function purchaseFunctions.enterDealership()
    local success, err = pcall(function()
        local locationRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Location")
        locationRemote:FireServer("Enter", "Cars")
        PlutoX.debug("[Purchase] 已进入车店")
        return true
    end)
    
    if not success then
        PlutoX.warn("[Purchase] 进入车店失败:", err)
        return false
    end
    
    return true
end

-- 获取所有车辆数据
function purchaseFunctions.getAllVehicles()
    local vehicles = {}
    
    PlutoX.debug("[Purchase] ========== 开始获取车辆数据 ==========")
    
    local success, err = pcall(function()
        PlutoX.debug("[Purchase] 步骤1: 获取 PlayerGui")
        local playerGui = player:WaitForChild("PlayerGui", 10)
        if not playerGui then
            PlutoX.warn("[Purchase] PlayerGui 获取超时")
            return vehicles
        end
        PlutoX.debug("[Purchase] PlayerGui 获取成功")
        
        task.wait(0.7)
        
        PlutoX.debug("[Purchase] 步骤2: 查找 DealershipHolder")
        local dealershipHolder = playerGui:FindFirstChild("DealershipHolder")
        if not dealershipHolder then
            PlutoX.warn("[Purchase] 未找到 DealershipHolder")
            return vehicles
        end
        PlutoX.debug("[Purchase] DealershipHolder 找到")
        
        task.wait(0.7)
        
        PlutoX.debug("[Purchase] 步骤3: 查找 Dealership")
        local dealership = dealershipHolder:FindFirstChild("Dealership")
        if not dealership then
            PlutoX.warn("[Purchase] 未找到 Dealership")
            return vehicles
        end
        PlutoX.debug("[Purchase] Dealership 找到")
        
        task.wait(0.7)
        
        PlutoX.debug("[Purchase] 步骤4: 查找 Selector")
        local selector = dealership:FindFirstChild("Selector")
        if not selector then
            PlutoX.warn("[Purchase] 未找到 Selector")
            return vehicles
        end
        PlutoX.debug("[Purchase] Selector 找到")
        
        task.wait(0.7)
        
        PlutoX.debug("[Purchase] 步骤5: 查找 View")
        local view = selector:FindFirstChild("View")
        if not view then
            PlutoX.warn("[Purchase] 未找到 View")
            return vehicles
        end
        PlutoX.debug("[Purchase] View 找到")
        
        task.wait(0.7)
        
        PlutoX.debug("[Purchase] 步骤6: 查找 All")
        local allView = view:FindFirstChild("All")
        if not allView then
            PlutoX.warn("[Purchase] 未找到 All")
            return vehicles
        end
        PlutoX.debug("[Purchase] All 找到")
        
        task.wait(0.7)
        
        PlutoX.debug("[Purchase] 步骤7: 查找 Container")
        local container = allView:FindFirstChild("Container")
        if not container then
            PlutoX.warn("[Purchase] 未找到 Container")
            return vehicles
        end
        PlutoX.debug("[Purchase] Container 找到")
        PlutoX.debug("[Purchase] Container 的子元素数量:", #container:GetChildren())
        
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
    
    PlutoX.debug("[Purchase] 获取到", #vehicles, "辆车辆")
    PlutoX.debug("[Purchase] ========== 获取车辆数据完成 ==========")
    
    return vehicles
end

-- 获取当前资金
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

-- 生成随机颜色
function purchaseFunctions.randomColor()
    return Color3.new(math.random(), math.random(), math.random())
end

-- 购买指定车辆
function purchaseFunctions.buyVehicle(frameName)
    PlutoX.debug("[Purchase] ========== 开始购买 ==========")
    PlutoX.debug("[Purchase] 购买名称:", frameName)
    
    local success, result = pcall(function()
        local purchaseRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Purchase")
        PlutoX.debug("[Purchase] 找到Purchase远程事件")
        
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
        
        PlutoX.debug("[Purchase] 购买参数:")
        PlutoX.debug("[Purchase]  - 购买名称:", frameName)
        PlutoX.debug("[Purchase]  - 主颜色:", mainColor)
        PlutoX.debug("[Purchase]  - 次要颜色:", secondaryColor)
        PlutoX.debug("[Purchase]  - 轮毂颜色:", wheelColor)
        
        local purchaseResult = purchaseRemote:InvokeServer(unpack(args))
        PlutoX.debug("[Purchase] 远程调用返回:", type(purchaseResult))
        
        if type(purchaseResult) == "table" then
            PlutoX.debug("[Purchase] 返回的table内容:")
            for k, v in pairs(purchaseResult) do
                PlutoX.debug("[Purchase]   ", k, "=", v)
            end
        else
            PlutoX.debug("[Purchase] 返回值:", purchaseResult)
        end
        
        return purchaseResult
    end)
    
    if success then
        PlutoX.debug("[Purchase] pcall成功，结果:", result)
        PlutoX.debug("[Purchase] ========== 购买完成 ==========")
        return true, result
    else
        PlutoX.warn("[Purchase] pcall失败，错误:", result)
        PlutoX.debug("[Purchase] ========== 购买失败 ==========")
        return false, result
    end
end

-- 记录一键购买的车辆
purchaseFunctions.autoPurchasedVehicles = {}

-- 独立的购买车辆函数
function purchaseFunctions.purchaseVehicle(vehicle)
    PlutoX.debug("[Purchase] ========== 开始购买车辆 ==========")
    PlutoX.debug("[Purchase] 车辆名称:", vehicle.name)
    PlutoX.debug("[Purchase] Frame Name:", vehicle.frameName)
    PlutoX.debug("[Purchase] 车辆价格:", vehicle.price)
    
    -- 检查资金是否足够
    local currentCash = purchaseFunctions.getCurrentCash()
    if currentCash < vehicle.price then
        PlutoX.debug("[Purchase] 资金不足")
        return false, "资金不足"
    end
    
    -- 执行购买
    local success, result = purchaseFunctions.buyVehicle(vehicle.frameName)
    
    if success then
        PlutoX.debug("[Purchase] 购买成功")
        -- 记录购买的车辆
        table.insert(purchaseFunctions.autoPurchasedVehicles, vehicle)
        PlutoX.debug("[Purchase] 已记录购买车辆:", vehicle.name, "当前记录数量:", #purchaseFunctions.autoPurchasedVehicles)
        return true, result
    else
        PlutoX.debug("[Purchase] 购买失败:", result)
        return false, result
    end
end

-- 后悔功能（卖车）
function purchaseFunctions.sellVehicle(vehicle)
    PlutoX.debug("[Sell] ========== 开始卖车 ==========")
    PlutoX.debug("[Sell] 车辆名称:", vehicle.name)
    PlutoX.debug("[Sell] Frame Name:", vehicle.frameName)
    
    local success, err = pcall(function()
        local sellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SellCar")
        PlutoX.debug("[Sell] 找到SellCar远程事件")
        
        local args = {
            vehicle.frameName
        }
        
        PlutoX.debug("[Sell] 卖车参数:", vehicle.frameName)
        sellRemote:FireServer(unpack(args))
        
        return true
    end)
    
    if success then
        PlutoX.debug("[Sell] 卖车成功")
        -- 从记录中移除
        for i, v in ipairs(purchaseFunctions.autoPurchasedVehicles) do
            if v.frameName == vehicle.frameName then
                table.remove(purchaseFunctions.autoPurchasedVehicles, i)
                PlutoX.debug("[Sell] 已从记录中移除:", vehicle.name)
                break
            end
        end
        return true
    else
        PlutoX.warn("[Sell] 卖车失败:", err)
        PlutoX.debug("[Sell] ========== 卖车失败 ==========")
        return false, err
    end
end

-- 后悔所有购买的车辆
function purchaseFunctions.regretAllPurchases()
    PlutoX.debug("[Regret] ========== 开始后悔所有购买 ==========")
    PlutoX.debug("[Regret] 需要后悔的车辆数量:", #purchaseFunctions.autoPurchasedVehicles)
    
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
            PlutoX.debug("[Regret] 已卖出:", vehicle.name, "价格:", vehicle.price)
        else
            PlutoX.debug("[Regret] 卖出失败:", vehicle.name)
        end
        
        task.wait(1)
    end
    
    PlutoX.debug("[Regret] ========== 后悔完成 ==========")
    PlutoX.debug("[Regret] 成功卖出:", soldCount, "辆")
    PlutoX.debug("[Regret] 总退款:", formatNumber(totalRefund))
    
    return true, {
        soldCount = soldCount,
        totalRefund = totalRefund
    }
end

-- 通用自动购买函数
function purchaseFunctions.autoPurchase(options)
    options = options or {}
    local sortAscending = options.sortAscending ~= false  -- 默认按价格从低到高排序
    local maxPurchases = options.maxPurchases or math.huge  -- 最大购买数量
    local onProgress = options.onProgress or function() end  -- 进度回调
    local shouldContinue = options.shouldContinue or function() return true end
    
    PlutoX.debug("[AutoPurchase] ========== 开始自动购买 ==========")
    
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
        PlutoX.debug("[AutoPurchase] 按价格从低到高排序")
    else
        table.sort(vehicles, function(a, b)
            return a.price > b.price
        end)
        PlutoX.debug("[AutoPurchase] 按价格从高到低排序")
    end
    
    local currentCash = purchaseFunctions.getCurrentCash()
    local purchasedCount = 0
    local totalSpent = 0
    
    PlutoX.debug("[AutoPurchase] 当前资金:", formatNumber(currentCash), "车辆数量:", #vehicles)
    
    -- 依次购买
    for _, vehicle in ipairs(vehicles) do
        if purchasedCount >= maxPurchases then
            PlutoX.debug("[AutoPurchase] 达到最大购买数量:", maxPurchases)
            break
        end
        
        if not shouldContinue() then
            PlutoX.debug("[AutoPurchase] 停止条件触发")
            break
        end
        
        if currentCash >= vehicle.price then
            local success, result = purchaseFunctions.purchaseVehicle(vehicle)
            
            if success then
                currentCash = currentCash - vehicle.price
                totalSpent = totalSpent + vehicle.price
                purchasedCount = purchasedCount + 1
                
                PlutoX.debug("[AutoPurchase] 已购买:", vehicle.name, "剩余资金:", formatNumber(currentCash))
                
                -- 调用进度回调
                onProgress({
                    vehicle = vehicle,
                    purchasedCount = purchasedCount,
                    totalSpent = totalSpent,
                    remainingCash = currentCash
                })
                
                task.wait(1)
            else
                PlutoX.debug("[AutoPurchase] 购买失败:", vehicle.name)
            end
        else
            PlutoX.debug("[AutoPurchase] 资金不足，停止购买")
            break
        end
    end
    
    PlutoX.debug("[AutoPurchase] ========== 自动购买完成 ==========")
    PlutoX.debug("[AutoPurchase] 购买数量:", purchasedCount, "总花费:", formatNumber(totalSpent))
    
    return true, {
        purchasedCount = purchasedCount,
        totalSpent = totalSpent,
        remainingCash = currentCash
    }
end

-- 搜索购买UI
local searchCard = UILibrary:CreateCard(purchaseContent, { IsMultiElement = true })
UILibrary:CreateLabel(searchCard, {
    Text = "搜索购买",
})

-- 存储之前创建的UI元素
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
        
        PlutoX.debug("[Purchase] 开始搜索，关键词:", searchText)
        
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
        
        PlutoX.debug("[Purchase] 搜索完成，匹配到", #matchedVehicles, "辆车辆")
        
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
            PlutoX.debug("[Purchase] 创建下拉框失败:", errorMsg)
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
                        PlutoX.debug("[Purchase] 下拉框已被销毁")
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
                        PlutoX.debug("[Purchase] 无法从displayText中提取车辆名称:", selectedDisplayText)
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
                        PlutoX.debug("[Purchase] 未找到选中的车辆数据")
                        UILibrary:Notify({
                            Title = "错误",
                            Text = "未找到选中的车辆",
                            Duration = 5
                        })
                        return
                    end
                    
                    PlutoX.debug("[Purchase] 开始购买:", selectedVehicle.name)
                    local success, result = purchaseFunctions.purchaseVehicle(selectedVehicle)
                    PlutoX.debug("[Purchase] 购买结果:", success, result)
                    
                    if success then
                        PlutoX.debug("[Purchase] 购买成功，开始清理UI")
                        UILibrary:Notify({
                            Title = "购买成功",
                            Text = string.format("已购买: %s\n价格: $%s", selectedVehicle.name, formatNumber(selectedVehicle.price)),
                            Duration = 5
                        })
                        
                        pcall(function()
                            if vehicleDropdown and vehicleDropdown.Parent then
                                PlutoX.debug("[Purchase] 销毁下拉框")
                                vehicleDropdown:Destroy()
                                vehicleDropdown = nil
                            end
                        end)
                        
                        pcall(function()
                            if buyButton and buyButton.Parent then
                                PlutoX.debug("[Purchase] 销毁购买按钮")
                                buyButton:Destroy()
                                buyButton = nil
                            end
                        end)
                        
                        -- 清空搜索框
                        PlutoX.debug("[Purchase] 清空搜索框")
                        if searchInput and searchInput.Parent then
                            searchInput.Text = ""
                        end
                    else
                        PlutoX.debug("[Purchase] 购买失败")
                        UILibrary:Notify({
                            Title = "购买失败",
                            Text = string.format("无法购买: %s", selectedVehicle.name),
                            Duration = 5
                        })
                    end
                end
            })
            
            PlutoX.debug("[Purchase] 购买按钮创建成功")
        end)
        
        -- 存储购买按钮引用
        previousBuyButton = buyButton
        
        if not buyButton then
            PlutoX.debug("[Purchase] 购买按钮创建失败")
            UILibrary:Notify({
                Title = "错误",
                Text = "无法创建购买按钮",
                Duration = 5
            })
            return
        end
    end
})

-- 一键购买功能
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
                    PlutoX.debug("[AutoBuy] 进度:", progress.purchasedCount, "已花费:", formatNumber(progress.totalSpent))
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

-- 关于标签页
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于"
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
                PlutoX.debug("[主循环] 目标达成：所有操作成功完成，已退出游戏")
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

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    spawn(function()
        wait(2)
        webhookManager:sendWelcomeMessage()
    end)
end