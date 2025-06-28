local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lastWebhookUrl = ""
local lastSendTime = os.time()  -- 初始化为当前时间
local lastCurrency = initialCurrency  -- 初始化为初始金额

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
local configFile = "Pluto_X_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notifyLeaderboard = false,
    leaderboardKick = false,
    notificationInterval = 30,
    welcomeSent = false,
    targetCurrency = 0,
    enableTargetKick = false
}

-- 颜色定义
local PRIMARY_COLOR = 4149685 -- #3F51B5

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
        writefile(configFile, HttpService:JSONEncode(config))
        UILibrary:Notify({ Title = "配置已保存", Text = "配置文件已保存至 " .. configFile, Duration = 5 })
    end)
end

-- 加载配置
local function loadConfig()
    if isfile(configFile) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(configFile))
        end)
        if success then
            for k, v in pairs(result) do
                config[k] = v
            end
            print("[Config] webhookUrl:", config.webhookUrl)
            print("[Config] notifyCash:", config.notifyCash)
            print("[Config] notifyLeaderboard:", config.notifyLeaderboard)
            print("[Config] leaderboardKick:", config.leaderboardKick)
            print("[Config] notificationInterval:", config.notificationInterval)
            UILibrary:Notify({ Title = "配置已加载", Text = "配置文件加载成功", Duration = 5 })
        else
            UILibrary:Notify({ Title = "配置错误", Text = "无法解析配置文件", Duration = 5 })
            saveConfig()
        end
    else
        UILibrary:Notify({ Title = "配置提示", Text = "未找到配置文件，创建新文件", Duration = 5 })
        saveConfig()
    end

    -- 检查 webhookUrl 是否有效且发生变化
    if config.webhookUrl ~= "" and config.webhookUrl ~= lastWebhookUrl then
        config.welcomeSent = false -- 重置 welcomeSent 以触发欢迎消息
        sendWelcomeMessage()
        lastWebhookUrl = config.webhookUrl -- 更新上次 webhook URL
    end
end

pcall(loadConfig)

-- 补充函数：统一获取通知间隔（秒）
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

    print("[Webhook] 正在发送 Webhook 到:", config.webhookUrl)
    print("[Webhook] Payload 内容:", HttpService:JSONEncode(data))

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
print("Webhook 输入框创建:", webhookInput.Parent and "已配置" or "无父对象")

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
print("金额监测开关创建:", toggleCurrency.Parent and "父对象存在" or "无父对象")

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
print("排行榜监测开关创建:", toggleLeaderboard and toggleLeaderboard.Parent and "父对象存在" or "无父对象")

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
print("上榜踢出开关创建:", toggleLeaderboardKick.Parent and "父对象存在" or "无父对象")

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
print("通知间隔输入框创建:", intervalInput.Parent and "父对象存在" or "无父对象")

-- 卡片：目标金额
local targetCurrencyCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })
local targetCurrencyToggle = UILibrary:CreateToggle(targetCurrencyCard, {
    Text = "目标金额踢出",
    DefaultState = false, -- 初始默认关闭，避免直接触发踢出
    Callback = function(state)
        if state and config.webhookUrl == "" then
            UILibrary:Notify({ Title = "Webhook", Error = "请先设置 Webhook 地址", Duration = 5 })
            config.enableTargetCurrency = false
            return nil
        end
        if state and config.targetCurrency <= 0 then
            config.enableTargetCurrency = false
            UILibrary:Notify({ Title = "配置错误", Text = "请设置有效目标金额（大于0）", Duration = 5 })
            return nil
        end
        
        -- 检查当前金额是否已超过目标金额
        local currentCurrency = fetchCurrentCurrency()
        if state and currentCurrency and currentCurrency >= config.targetCurrency then
            config.enableTargetCurrency = false
            UILibrary:Notify({ 
                Title = "配置警告", 
                Text = "当前金额(" .. formatNumber(currentCurrency) .. ")已超过目标金额(" .. formatNumber(config.targetCurrency) .. ")，请调整后再开启", 
                Duration = 5 
            })
            return nil
        end
        
        config.enableTargetCurrency = state
        UILibrary:Notify({ Title = "配置更新", Text = "目标金额踢出: " .. (state and "开启" or "关闭"), Duration = 5 })
        saveConfig()
        return nil
    end
})
print("目标金额开关创建卡片:", targetCurrencyToggle.Parent and "父对象存在" or "无父对象")

local targetCurrencyLabel = UILibrary:CreateLabel(targetCurrencyCard, {
    Text = "目标金额",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 30)
})

local targetCurrencyInput = UILibrary:CreateTextBox(targetCurrencyCard, {
    PlaceholderText = "输入目标金额",
    Position = UDim2.new(0, 5, 0, 50),
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")  -- 去除前后空格
        
        -- 空输入处理
        if not text or text == "" then
            -- 如果之前有设置过目标金额，保持原值不变
            if config.targetCurrency > 0 then
                targetCurrencyInput.Text = formatNumber(config.targetCurrency)
                return
            end
            -- 否则设为0并禁用功能
            config.targetCurrency = 0
            config.enableTargetCurrency = false
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
            -- 检查新设置的目标金额是否小于当前金额
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
            UILibrary:Notify({
                Title = "配置更新",
                Text = "目标金额已设为 " .. formatNumber(num),
                Duration = 5
            })
            saveConfig()
        else
            -- 非有效数字
            targetCurrencyInput.Text = tostring(config.targetCurrency > 0 and formatNumber(config.targetCurrency) or "")
            UILibrary:Notify({
                Title = "配置错误",
                Text = "请输入有效的正整数作为目标金额",
                Duration = 5
            })
            -- 若当前启用了目标金额踢出但值无效，自动关闭
            if config.enableTargetCurrency then
                config.enableTargetCurrency = false
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

-- 初始化时检查当前金额与目标金额的关系
local currentCurrency = fetchCurrentCurrency()
if currentCurrency and config.targetCurrency > 0 and currentCurrency >= config.targetCurrency then
    config.enableTargetCurrency = false
    UILibrary:Notify({ 
        Title = "配置提示", 
        Text = "当前金额已超过目标金额，已自动禁用目标金额踢出功能", 
        Duration = 5 
    })
    saveConfig()
end

targetCurrencyInput.Text = tostring(config.targetCurrency > 0 and formatNumber(config.targetCurrency) or "")
print("目标金额输入框创建:", targetCurrencyInput.Parent and "父对象存在" or "无父对象")

-- 标签页：关于
local aboutTab, aboutContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "关于"
})

-- 作者信息  
local authorInfo = UILibrary:CreateAuthorInfo(aboutContent, {  
    Text = "作者: tongblx",  
    SocialText = "加入 Discord 服务器",  
    socialCallback = function()  
        pcall(function()  
            local link = "https://discord.gg/j20v0eWU8u"  
            local success = false  
            if setclipboard then  
                setclipboard(link)  
                success = true  
            elseif syn and syn.set_clipboard then  
                syn.set_clipboard(link)  
                success = true  
            elseif clipboard and clipboard.set then  
                clipboard.set(link)  
                success = true  
            end  

            if success then  
                UILibrary:Notify({ Title = "复制 Discord", Text = "Discord 链接已复制到剪贴板", Duration = 5 })  
            else  
                UILibrary:Notify({ Title = "复制 Discord", Text = "当前环境不支持剪贴板操作，请手动复制: " .. link, Duration = 5 })  
            end  
        end)  
    end  
})

-- 初始化欢迎消息
if config.webhookUrl ~= "" then
    sendWelcomeMessage()
end

--调试模式
local DEBUG_MODE = false

-- 调试打印函数
local function debugLog(...)
    if DEBUG_MODE then
        print(...)
    end
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

    -- 目标金额监测
    if config.enableTargetCurrency and currentCurrency  
       and currentCurrency >= config.targetCurrency  
       and config.targetCurrency > 0 then  
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

    -- 计算距离上次通知的间隔
    local interval = currentTime - lastSendTime  
    debugLog("[Main Loop] 当前时间:", currentTime, "上次发送时间:", lastSendTime, "间隔:", interval, "通知间隔秒数:", getNotificationIntervalSeconds())
    debugLog("[Main Loop] 金额监测:", config.notifyCash, "排行榜监测:", config.notifyLeaderboard, "上榜踢出:", config.leaderboardKick)

    -- 检查是否满足通知条件
    if (config.notifyCash or config.notifyLeaderboard or config.leaderboardKick)  
       and interval >= getNotificationIntervalSeconds() then  
        print("[Main Loop] 发送通知")
        local embed = {  
            title = "Pluto-X",  
            description = string.format("**游戏**: %s\n**用户**: %s", gameName, username),  
            fields = {},  
            color = PRIMARY_COLOR,  
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),  
            footer = { text = "作者: tongblx · Pluto-X" }  
        }  

        local earnedChange = 0  
        if currentCurrency and lastCurrency then  
            earnedChange = currentCurrency - lastCurrency  
        end  

        -- 金额通知
        if config.notifyCash and currentCurrency then
            table.insert(embed.fields, {  
                name = "💰金额通知",  
                value = string.format(  
                    "**当前金额**: %s\n**总变化**:%s%s\n**本次变化**:%s%s",  
                    formatNumber(currentCurrency),  
                    (totalChange >= 0 and "+" or ""), formatNumber(totalChange),  
                    (earnedChange >= 0 and "+" or ""), formatNumber(earnedChange)  
                ),  
                inline = false  
            })  
        end  

        -- 排行榜监测
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

        local webhookSuccess = dispatchWebhook({ embeds = { embed } })  
        if webhookSuccess then  
            lastSendTime = currentTime  
            if config.notifyCash and currentCurrency then  
                lastCurrency = currentCurrency  
            end  
            UILibrary:Notify({  
                Title = "定时通知",  
                Text = "Webhook 已发送，下次时间: " .. getNextNotificationTime(),  
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

    wait(1)  
end