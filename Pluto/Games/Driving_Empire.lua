local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lastWebhookUrl = ""
local lastSendTime = os.time()
local lastCurrency = initialCurrency
--调试模式
local DEBUG_MODE = false

-- 调试打印函数
local function debugLog(...)
    if DEBUG_MODE then
        print(...)
    end
end

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
local configFile = "Pluto_X_DE_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notifyLeaderboard = false,
    leaderboardKick = false,
    notificationInterval = 30,
    welcomeSent = false,
    targetCurrency = 0,
    enableTargetKick = false,
    onlineRewardEnabled = false,
}

-- 颜色定义
_G.PRIMARY_COLOR = Color3.fromRGB(40, 38, 89) -- 设置为 #282659

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
local success, currencyValue = pcall(fetchCurrentCurrency)
if success and currencyValue then
    initialCurrency = currencyValue
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

-- 统一获取通知间隔（秒）
local function getNotificationIntervalSeconds()
    return (config.notificationInterval or 5) * 60
end

-- 检查排行榜
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
    if tempPlatform then tempPlatform:Destroy() end
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

function fetchPlayerRank()
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
    local isOnLeaderboard = false
    for _, child in ipairs(contents:GetChildren()) do
        if tonumber(child.Name) == userId or child.Name == username then
            local placement = child:FindFirstChild("Placement")
            isOnLeaderboard = true
            return placement and placement:IsA("IntValue") and placement.Value or rank, true
        end
        rank = rank + 1
    end
    return nil, false
end

-- 下次通知时间
local function getNextNotificationTime()
    local currentTime = os.time()
    local intervalSeconds = config.notificationInterval * 60
    return os.date("%Y-%m-%d %H:%M:%S", currentTime + intervalSeconds)
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

-- Webhook 发送（自动适配 Discord 和 企业微信格式）
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

    local url = config.webhookUrl
    local bodyJson = ""
    local isWechat = url:find("qyapi.weixin.qq.com/cgi%-bin/webhook/send")

    if isWechat then
        local e = payload.embeds and payload.embeds[1] or {}

        local title = e.title or "Pluto-X 通知"
        local description = e.description or ""
        local fields = e.fields or {}
        local footer = e.footer and e.footer.text or "Pluto-X"

        -- 清洗 Markdown
        local function clean(text)
            return string.gsub(text or "", "%*%*(.-)%*%*", "%1")
        end

        -- 构造纵向排列内容：每个字段两项 key-value
        local verticalList = {}
        for _, field in ipairs(fields) do
            table.insert(verticalList, {
                keyname = clean(field.name),
                value = ""
            })
            table.insert(verticalList, {
                keyname = clean(field.value),
                value = ""
            })
        end

        -- 微信时间格式（不加 Z）
        local timestampText = ""
        if e.timestamp then
            local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)Z"
            local y, m, d, h, min, s = e.timestamp:match(pattern)
            if y and m and d and h and min and s then
                timestampText = string.format("%s-%s-%s %s:%s:%s", y, m, d, h, min, s)
                table.insert(verticalList, {
                    keyname = "通知时间",
                    value = ""
                })
                table.insert(verticalList, {
                    keyname = timestampText,
                    value = ""
                })
            end
        end

        -- 构造卡片
        local card = {
            msgtype = "template_card",
            template_card = {
                card_type = "text_notice",
                source = {
                    icon_url = "",
                    desc = footer,
                    desc_color = 0
                },
                main_title = {
                    title = clean(title),
                    desc = ""
                },
                sub_title_text = clean(description),
                horizontal_content_list = verticalList,
                jump_list = {},
                card_action = {
                    type = 1,
                    url = "https://example.com"
                }
            }
        }

        bodyJson = HttpService:JSONEncode(card)
    else
        -- Discord 默认
        bodyJson = HttpService:JSONEncode({
            content = nil,
            embeds = payload.embeds
        })
    end

    local success, res = pcall(function()
        return requestFunc({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = bodyJson
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
            color = PRIMARY_COLOR,
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

-- 在线时长奖励领取
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = game.Players.LocalPlayer

-- 在线时长奖励领取函数
local function claimPlaytimeRewards()
    if not config.onlineRewardEnabled then
        debugLog("[PlaytimeRewards] 在线时长奖励功能未启用")
        return
    end

    spawn(function()
        local rewardCheckInterval = 600

        while config.onlineRewardEnabled do
            if not game:IsLoaded() then
                game.Loaded:Wait()
            end

            local gui = player:WaitForChild("PlayerGui", 5)
            local mainHUD = gui and gui:WaitForChild("MainHUD", 5)
            local challenges = mainHUD and mainHUD:WaitForChild("DailyChallenges", 5)
            local rewardsRoot = challenges and challenges.holder.PlaytimeRewards.RewardsList.SmallRewards

            if not rewardsRoot then
                UILibrary:Notify({
                    Title = "领取失败",
                    Text = "无法找到奖励界面",
                    Duration = 5
                })
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
                UILibrary:Notify({
                    Title = "领取失败",
                    Text = "未找到玩家 Stats",
                    Duration = 5
                })
                warn("[PlaytimeRewards] 未找到玩家 Stats")
                task.wait(rewardCheckInterval)
                continue
            end

            local claimedList = {}
            local claimedRaw = statsGui:FindFirstChild("ClaimedPlayTimeRewards")
            if claimedRaw and claimedRaw:IsA("StringValue") then
                local success, parsed = pcall(function()
                    return HttpService:JSONDecode(claimedRaw.Value)
                end)
                if success and typeof(parsed) == "table" then
                    for k, v in pairs(parsed) do
                        claimedList[tonumber(k)] = v
                    end
                else
                    UILibrary:Notify({
                        Title = "领取失败",
                        Text = "ClaimedPlayTimeRewards JSON 解析失败",
                        Duration = 5
                    })
                    warn("[PlaytimeRewards] JSON 解析失败")
                    task.wait(rewardCheckInterval)
                    continue
                end
            else
                warn("[PlaytimeRewards] 未找到 ClaimedPlayTimeRewards")
            end

            local allClaimed = true
            for i = 1, 7 do
                if not claimedList[i] then
                    allClaimed = false
                    break
                end
            end

            if allClaimed then
                UILibrary:Notify({
                    Title = "奖励状态",
                    Text = "所有在线时长奖励已领取，等待重置",
                    Duration = 5
                })
                debugLog("[PlaytimeRewards] 所有奖励已领取，等待重置")
                task.wait(rewardCheckInterval)
                continue
            end

            local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
            local uiInteraction = remotes and remotes:FindFirstChild("UIInteraction")
            local playRewards = remotes and remotes:FindFirstChild("PlayRewards")

            if not uiInteraction or not playRewards then
                UILibrary:Notify({
                    Title = "领取失败",
                    Text = "未找到远程事件 UIInteraction 或 PlayRewards",
                    Duration = 5
                })
                warn("[PlaytimeRewards] 未找到远程事件")
                task.wait(rewardCheckInterval)
                continue
            end

            local success, rewardsConfig = pcall(function()
                return remotes:WaitForChild("GetRemoteConfigPath"):InvokeServer("driving-empire", "PlaytimeRewards")
            end)
            if not success or type(rewardsConfig) ~= "table" then
                warn("[PlaytimeRewards] 获取奖励配置失败")
                rewardsConfig = {}
            end

            local function findReward7()
                for _, child in ipairs(rewardsRoot:GetChildren()) do
                    if tonumber(child.Name) == 7 then
                        return child
                    end
                end
                return nil
            end

            for i = 1, 7 do
                debugLog("----------------------------------------")
                local rewardItem = rewardsRoot:FindFirstChild(tostring(i))
                if i == 7 and not rewardItem then
                    rewardItem = findReward7()
                end

                local amountText = "未知"
                local stateText = "未知"
                local canClaim = false
                local alreadyClaimed = claimedList[i] == true

                if rewardItem then
                    local holder = rewardItem:FindFirstChild("Holder")
                    local amountBtnText = holder and holder:FindFirstChild("Amount")
                    if amountBtnText and amountBtnText:FindFirstChild("ButtonText") then
                        amountText = amountBtnText.ButtonText.Text
                    end

                    local collect = holder and holder:FindFirstChild("Collect")
                    if collect and collect.Visible and not alreadyClaimed then
                        canClaim = true
                    end

                    if alreadyClaimed then
                        stateText = "已领取"
                    elseif canClaim then
                        stateText = "可领取"
                    else
                        stateText = "未达成"
                    end
                else
                    local cfg = rewardsConfig[i]
                    if cfg then
                        amountText = tostring(cfg.Amount or cfg.Name or "未知")
                    end

                    -- 默认奖励7可领取处理逻辑
                    if not alreadyClaimed and i == 7 then
                        canClaim = true
                        stateText = "尝试领取（缺少 GUI）"
                    else
                        stateText = alreadyClaimed and "已领取" or "未达成"
                    end
                end

                debugLog("[PlaytimeRewards] 奖励 " .. i .. " 按钮文字：" .. amountText)
                debugLog("[PlaytimeRewards] 奖励 " .. i .. " 状态：" .. stateText)

                if canClaim then
                    local success, err = pcall(function()
                        uiInteraction:FireServer({action = "PlaytimeRewards", rewardId = i})
                        task.wait(0.2)
                        playRewards:FireServer(i, false)
                        UILibrary:Notify({
                            Title = "奖励领取",
                            Text = "已尝试领取奖励 ID: " .. i .. " (" .. amountText .. ")",
                            Duration = 5
                        })
                        debugLog("[PlaytimeRewards] ✅ 已尝试领取奖励 ID:", i)
                    end)
                    if not success then
                        UILibrary:Notify({
                            Title = "领取失败",
                            Text = "奖励 ID: " .. i .. " 领取出错: " .. tostring(err),
                            Duration = 5
                        })
                        warn("[PlaytimeRewards] 领取奖励 ID:", i, "失败:", err)
                    end
                    task.wait(0.4)
                end
            end

            debugLog("[PlaytimeRewards] 已完成一次领取尝试，下次检查时间: ", os.date("%Y-%m-%d %H:%M:%S", os.time() + rewardCheckInterval))
            task.wait(rewardCheckInterval)
        end

        debugLog("[PlaytimeRewards] 在线时长奖励功能已关闭，停止领取循环")
    end)
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

-- 标签页：主要功能
local mainFeatureTab, mainFeatureContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "主要功能",
    Active = false
})

-- 卡片：在线时长奖励
local onlineRewardCard = UILibrary:CreateCard(mainFeatureContent)

local toggleOnlineReward = UILibrary:CreateToggle(onlineRewardCard, {
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
        debugLog("在线时长奖励开关状态:", state)
    end
})

debugLog("在线时长奖励开关创建:", toggleOnlineReward.Parent and "父对象存在" or "无父对象")
-- 加载配置时若开关为开启状态，自动启动在线奖励领取
if config.onlineRewardEnabled then
    debugLog("[PlaytimeRewards] 配置为开启状态，尝试启动...")
    claimPlaytimeRewards()
end

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
debugLog("Webhook 输入框创建:", webhookInput.Parent and "已配置" or "无父对象")

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
debugLog("金额监测开关创建:", toggleCurrency.Parent and "父对象存在" or "无父对象")

-- 卡片：监测排行榜状态
local leaderboardNotifyCard = UILibrary:CreateCard(notifyContent)
local toggleLeaderboard = UILibrary:CreateToggle(leaderboardNotifyCard, {
    Text = "监测排行榜状态",
    DefaultState = config.notifyLeaderboard,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.notifyLeaderboard = false
            return nil
        end
        config.notifyLeaderboard = state
        UILibrary:Notify({ Title = "配置更新", Text = "排行榜状态监测: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
        return nil
    end
})
debugLog("排行榜监测开关创建:", toggleLeaderboard and toggleLeaderboard.Parent and "父对象存在" or "无父对象")

-- 卡片：上榜踢出
local leaderboardKickCard = UILibrary:CreateCard(notifyContent)
local toggleLeaderboardKick = UILibrary:CreateToggle(leaderboardKickCard, {
    Text = "上榜自动踢出",
    DefaultState = config.leaderboardKick,
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
            config.leaderboardKick = false
            return nil
        end
        config.leaderboardKick = state
        UILibrary:Notify({ Title = "配置更新", Text = "上榜自动踢出: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
        return nil
    end
})
debugLog("上榜踢出开关创建:", toggleLeaderboardKick.Parent and "父对象存在" or "无父对象")

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
debugLog("通知间隔输入框创建:", intervalInput.Parent and "父对象存在" or "无父对象")

-- 卡片：目标金额
local targetCurrencyCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

local suppressTargetToggleCallback = false

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

            if not config.enableTargetKick then
                config.enableTargetKick = true
                suppressTargetToggleCallback = true
                targetCurrencyToggle:Set(true)
                UILibrary:Notify({
                    Title = "已启用目标踢出",
                    Text = "已自动开启目标金额踢出功能",
                    Duration = 5
                })
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
    SocialText = "Discord 服务器链接："
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
local startTime = os.time()

-- 初始化变量
local lastMoveTime = tick()
local lastPosition = nil
local idleThreshold = 300 -- 超过300秒没动算掉线
local checkInterval = 1 -- 每秒检测一次

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- 每帧检测位置变化
game:GetService("RunService").RenderStepped:Connect(function()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        if lastPosition then
            if (hrp.Position - lastPosition).Magnitude > 0.1 then
                lastMoveTime = tick()
            end
        end
        lastPosition = hrp.Position
    end
end)

local function formatElapsedTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d小时%02d分%02d秒", hours, minutes, secs)
end

-- 主循环
while true do
    local currentTime = os.time()
    local currentCurrency = fetchCurrentCurrency()

    local totalChange = 0
    if currentCurrency and initialCurrency then
        totalChange = currentCurrency - initialCurrency
    end
    earnedCurrencyLabel.Text = "已赚金额: " .. formatNumber(totalChange)

    local shouldShutdown = false

    -- 🎯 目标金额监测
    if not webhookDisabled and config.enableTargetKick and currentCurrency
       and currentCurrency >= config.targetCurrency and config.targetCurrency > 0 then

        local payload = {
            embeds = {{
                title = "🎯 目标金额达成",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n**目标金额**: %s",
                    gameName, username,
                    formatNumber(currentCurrency),
                    formatNumber(config.targetCurrency)
                ),
                color = PRIMARY_COLOR,
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
    if tick() - lastMoveTime >= idleThreshold and not webhookDisabled then
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
            Text = "检测到玩家长时间未移动，已停止发送 Webhook",
            Duration = 5
        })
    end

    -- 🕒 通知间隔计算
    local interval = currentTime - lastSendTime
    if not webhookDisabled and (config.notifyCash or config.notifyLeaderboard or config.leaderboardKick)
       and interval >= getNotificationIntervalSeconds() then

        local earnedChange = 0
        if currentCurrency and lastCurrency then
            earnedChange = currentCurrency - lastCurrency
        end

        if currentCurrency == lastCurrency and totalChange == 0 and earnedChange == 0 then
            unchangedCount = unchangedCount + 1
        else
            unchangedCount = 0
        end

        if unchangedCount >= 2 then
            local webhookSuccess = dispatchWebhook({
                embeds = {{
                    title = "⚠️ 金额长时间未变化",
                    description = string.format(
                        "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n检测到连续两次金额变化为 0，可能已断开或数据异常",
                        gameName, username, formatNumber(currentCurrency or 0)),
                    color = 16753920,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "作者: tongblx · Pluto-X" }
                }}
            })

            if webhookSuccess then
                webhookDisabled = true
                lastSendTime = currentTime
                lastCurrency = currentCurrency
                UILibrary:Notify({
                    Title = "连接异常",
                    Text = "检测到金额连续两次未变化，已停止发送 Webhook",
                    Duration = 5
                })
            else
                UILibrary:Notify({
                    Title = "Webhook 发送失败",
                    Text = "连接异常未能发送，请检查设置",
                    Duration = 5
                })
            end
        else
            local nextNotifyTimestamp = currentTime + getNotificationIntervalSeconds()
            local countdownR = string.format("<t:%d:R>", nextNotifyTimestamp)
            local countdownT = string.format("<t:%d:T>", nextNotifyTimestamp)

            local embed = {
                title = "Pluto-X",
                description = string.format("**游戏**: %s\n**用户**: %s", gameName, username),
                fields = {},
                color = PRIMARY_COLOR,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }

            if config.notifyCash and currentCurrency then
                local elapsedTime = currentTime - startTime
                local avgMoney = "0"
                if elapsedTime > 0 then
                    local rawAvg = totalChange / (elapsedTime / 3600)
                    avgMoney = formatNumber(math.floor(rawAvg + 0.5))
                end

                table.insert(embed.fields, {
                    name = "💰金额通知",
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
                    Text = isOnLeaderboard and ("当前排名 " .. status .. "，已上榜") or "当前未上榜",
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

            local webhookSuccess = dispatchWebhook({ embeds = { embed } })
            if webhookSuccess then
                lastSendTime = currentTime
                if config.notifyCash and currentCurrency then
                    lastCurrency = currentCurrency
                end
                UILibrary:Notify({
                    Title = "定时通知",
                    Text = "Webhook 已发送，下次时间: " .. os.date("%Y-%m-%d %H:%M:%S", nextNotifyTimestamp),
                    Duration = 5
                })

                if shouldShutdown then
                    wait(0.5)
                    game:Shutdown()
                    return
                end
            else
                UILibrary:Notify({
                    Title = "Webhook 发送失败",
                    Text = "请检查 Webhook 设置",
                    Duration = 5
                })
            end
        end
    end

    wait(checkInterval)
end