local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local lastWebhookUrl = ""
local lastSendTime = os.time()

-- 调试模式（仅通过代码修改开启/关闭）
local DEBUG_MODE = false

-- 调试输出函数
local function debugPrint(...)
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
local configFile = "Pluto_X_APS_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notificationInterval = 30,
    welcomeSent = false,
    targetAmount = 0,          -- 改为目标金额
    enableTargetKick = false,
    lastSavedCurrency = 0,     -- 基准金额
    baseAmount = 0,            -- 用户输入的基准金额
    totalEarningsBase = 0,     -- 总收益的基准金额
    lastNotifyCurrency = 0,    -- 上次通知时的金额
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

-- 千分位格式化函数
local function formatWithCommas(amount)
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- 获取初始金额
local initialCurrency = 0
local function fetchCurrentCurrency()
    local success, cashValue = pcall(function()
        local leaderstats = player:WaitForChild("leaderstats", 5)
        if leaderstats then
            local cash = leaderstats:WaitForChild("Cash", 5)
            if cash and cash:IsA("IntValue") or cash:IsA("NumberValue") then
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

-- 计算实际赚取金额的函数
local function calculateEarnedAmount(currentCurrency)
    if not currentCurrency then return 0 end
    -- 使用固定的总收益基准
    if config.totalEarningsBase > 0 then
        return currentCurrency - config.totalEarningsBase
    else
        -- 首次运行，使用初始金额
        return currentCurrency - initialCurrency
    end
end

-- 计算本次变化（距上次通知的变化）
local function calculateChangeAmount(currentCurrency)
    if not currentCurrency then return 0 end
    if config.lastNotifyCurrency > 0 then
        return currentCurrency - config.lastNotifyCurrency
    else
        -- 第一次通知，本次变化等于总收益
        return calculateEarnedAmount(currentCurrency)
    end
end

local success, currencyValue = pcall(fetchCurrentCurrency)
if success and currencyValue then
    initialCurrency = currencyValue
    -- 如果是首次运行，设置总收益基准
    if config.totalEarningsBase == 0 then
        config.totalEarningsBase = currencyValue
    end
    -- 如果没有设置过通知基准，也设置为当前金额
    if config.lastNotifyCurrency == 0 then
        config.lastNotifyCurrency = currencyValue
    end
    UILibrary:Notify({ Title = "初始化成功", Text = "当前金额: " .. tostring(initialCurrency), Duration = 5 })
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

-- 修改：调整目标金额的函数
local function adjustTargetAmount()
    if config.baseAmount <= 0 or config.targetAmount <= 0 then
        return
    end
    
    local currentCurrency = fetchCurrentCurrency()
    if not currentCurrency then
        return
    end
    
    local currencyDifference = currentCurrency - config.lastSavedCurrency
    
    if currencyDifference ~= 0 then
        local newTargetAmount = config.targetAmount + currencyDifference
        
        if newTargetAmount > currentCurrency then
            config.targetAmount = newTargetAmount
            UILibrary:Notify({
                Title = "目标金额已调整",
                Text = string.format("根据金额变化调整目标金额至: %s", formatNumber(config.targetAmount)),
                Duration = 5
            })
            saveConfig()
        else
            config.enableTargetKick = false
            config.targetAmount = 0
            UILibrary:Notify({
                Title = "目标金额已重置",
                Text = "调整后的目标金额小于当前金额，已禁用目标踢出功能",
                Duration = 5
            })
            saveConfig()
        end
    end
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
                
                -- 启动时调整目标金额
                adjustTargetAmount()
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

-- 统一获取通知间隔（秒）
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

    debugPrint("[Webhook] 正在发送 Webhook 到:", config.webhookUrl)
    debugPrint("[Webhook] Payload 内容:", HttpService:JSONEncode(data))

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
            debugPrint("[Webhook] 发送成功")
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

-- 修改：初始化时校验目标金额
local function initTargetAmount()
    local currentCurrency = fetchCurrentCurrency() or 0
    
    if config.enableTargetKick and config.targetAmount > 0 and currentCurrency >= config.targetAmount then
        UILibrary:Notify({
            Title = "目标金额已达成",
            Text = string.format("当前金额 %s，已超过目标 %s，已关闭踢出功能", 
                formatNumber(currentCurrency), formatNumber(config.targetAmount)),
            Duration = 5
        })
        config.enableTargetKick = false
        config.targetAmount = 0
        saveConfig()
    end
end

-- 更新金额保存函数
local function updateLastSavedCurrency(currentCurrency)
    if currentCurrency and currentCurrency ~= config.lastSavedCurrency then
        config.lastSavedCurrency = currentCurrency
        saveConfig()
    end
end

-- 更新通知基准金额的函数
local function updateLastNotifyCurrency(currentCurrency)
    if currentCurrency then
        config.lastNotifyCurrency = currentCurrency
        saveConfig()
    end
end

-- 执行加载前先执行初始化
pcall(initTargetAmount)
pcall(loadConfig)

-- autofarm模块封装
local isFarming = false
local platformFolder = nil
local farmTask = nil

local function stopAutoFarm()
    debugPrint("[autofarm] Stop 被调用")
    isFarming = false
    if farmTask then
        task.cancel(farmTask)
        farmTask = nil
        debugPrint("[autofarm] 任务已取消")
    end
    if platformFolder then
        platformFolder:Destroy()
        platformFolder = nil
        debugPrint("[autofarm] 平台已销毁")
    end
end

local function startAutoFarm()
    debugPrint("[autofarm] 尝试启动")
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
    debugPrint("[autofarm] 找到车辆:", carModel.Name)

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
    debugPrint("[autofarm] 设置 PrimaryPart 成功")

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
    debugPrint("[autofarm] 平台创建成功")

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
    debugPrint("[autofarm] 车辆已传送至起始位置")

    isFarming = true
    farmTask = task.spawn(function()
        debugPrint("[autofarm] 循环任务开始")
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
                debugPrint("[autofarm] 重置位置")
            end

            task.wait(interval)
        end
        debugPrint("[autofarm] 循环任务结束")
        if platformFolder then
            platformFolder:Destroy()
            platformFolder = nil
            debugPrint("[autofarm] 平台已销毁")
        end
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
})
local earnedCurrencyLabel = UILibrary:CreateLabel(generalCard, {
    Text = "已赚金额: 0",
})

-- 卡片：反挂机
local antiAfkCard = UILibrary:CreateCard(generalContent)
local antiAfkLabel = UILibrary:CreateLabel(antiAfkCard, {
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
        debugPrint("[autofarm] Toggle 状态切换为:", state)
        if state then
            UILibrary:Notify({Title = "autofarm", Text = "autofarm已启动", Duration = 5})
            startAutoFarm()
        else
            UILibrary:Notify({Title = "autofarm", Text = "autofarm已停止", Duration = 5})
            stopAutoFarm()
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
})
local webhookInput = UILibrary:CreateTextBox(webhookCard, {
    PlaceholderText = "输入 Webhook 地址",
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
            UILibrary:Notify({ Title = "配置错误", Text = "请输入有效的数字", Duration = 5 })
        end
    end
})
intervalInput.Text = tostring(config.notificationInterval)

-- 基准金额设置卡片
local baseAmountCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

UILibrary:CreateLabel(baseAmountCard, {
    Text = "基准金额设置",
})

-- 先创建目标金额标签变量
local targetAmountLabel

-- 避免程序性开启触发回调误判
local suppressTargetToggleCallback = false

local baseAmountInput = UILibrary:CreateTextBox(baseAmountCard, {
    PlaceholderText = "输入基准金额",
    OnFocusLost = function(text)
        text = text and text:match("^%s*(.-)%s*$")
        
        if not text or text == "" then
            config.baseAmount = 0
            config.targetAmount = 0
            baseAmountInput.Text = ""
            if targetAmountLabel then
                targetAmountLabel.Text = "目标金额: 未设置"
            end
            
            saveConfig()
            
            UILibrary:Notify({
                Title = "基准金额已清除",
                Text = "基准金额和目标金额已重置",
                Duration = 5
            })
            return
        end

        local cleanText = text:gsub(",", "")
        local num = tonumber(cleanText)
        
        if num and num > 0 then
            local currentCurrency = fetchCurrentCurrency() or 0
            
            local newTarget = num + currentCurrency
            
            config.baseAmount = num
            config.targetAmount = newTarget
            
            baseAmountInput.Text = formatNumber(num)
            
            if targetAmountLabel then
                targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
            end
            
            saveConfig()
            
            UILibrary:Notify({
                Title = "基准金额已设置",
                Text = string.format("基准金额: %s\n当前金额: %s\n新目标金额: %s", 
                    formatNumber(num), 
                    formatNumber(currentCurrency),
                    formatNumber(newTarget)),
                Duration = 7
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
            baseAmountInput.Text = tostring(config.baseAmount > 0 and formatNumber(config.baseAmount) or "")
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

-- 目标金额踢出卡片
local targetAmountCard = UILibrary:CreateCard(notifyContent, { IsMultiElement = true })

local targetAmountToggle = UILibrary:CreateToggle(targetAmountCard, {
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
            UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准金额以生成目标金额", Duration = 5 })
            return
        end

        local currentCurrency = fetchCurrentCurrency()
        if state and currentCurrency and currentCurrency >= config.targetAmount then
            targetAmountToggle:Set(false)
            UILibrary:Notify({
                Title = "配置警告",
                Text = string.format("当前金额(%s)已超过目标(%s)，请重新设置基准金额",
                    formatNumber(currentCurrency),
                    formatNumber(config.targetAmount)
                ),
                Duration = 6
            })
            return
        end

        config.enableTargetKick = state
        UILibrary:Notify({
            Title = "配置更新",
            Text = string.format("目标金额踢出: %s\n目标金额: %s", 
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

-- 重新计算目标金额的按钮
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
        
        if newTarget <= currentCurrency then
            UILibrary:Notify({
                Title = "计算错误",
                Text = string.format("计算后的目标金额(%s)不能小于等于当前金额(%s)，请检查基准金额设置", 
                    formatNumber(newTarget), formatNumber(currentCurrency)),
                Duration = 6
            })
            return
        end
        
        config.targetAmount = newTarget
        
        if targetAmountLabel then
            targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
        end
        
        saveConfig()
        
        UILibrary:Notify({
            Title = "目标金额已重新计算",
            Text = string.format("基准金额: %s\n当前金额: %s\n新目标金额: %s", 
                formatNumber(config.baseAmount),
                formatNumber(currentCurrency),
                formatNumber(newTarget)),
            Duration = 7
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
local lastCurrency = nil
local checkInterval = 1

-- 掉线检测
local GuiService = game:GetService("GuiService")
local NetworkClient = game:GetService("NetworkClient")
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

-- 格式化时间显示
local function formatElapsedTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d小时%02d分%02d秒", hours, minutes, secs)
end

-- 🌀 主循环开始
while true do
    local currentTime = os.time()
    local currentCurrency = fetchCurrentCurrency()

    -- 计算从启动到现在的总收益（使用固定基准）
    local earnedAmount = calculateEarnedAmount(currentCurrency)
    earnedCurrencyLabel.Text = "已赚金额: " .. formatNumber(earnedAmount)

    local shouldShutdown = false

    -- 🎯 目标金额监测
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
                Text = string.format("已达到目标金额 %s，准备退出游戏...", formatNumber(config.targetAmount)),
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
            pcall(function() player:Kick("目标金额已达成，游戏自动退出") end)
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

    -- 🕒 通知间隔计算
    local interval = currentTime - lastSendTime
    if not webhookDisabled and config.notifyCash
       and interval >= getNotificationIntervalSeconds() then

        -- 计算本次变化（距上次通知的变化）
        local earnedChange = calculateChangeAmount(currentCurrency)

        -- 检测金额是否变化
        if currentCurrency == lastCurrency and earnedChange == 0 then
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
                updateLastNotifyCurrency(currentCurrency)  -- 更新通知基准
                updateLastSavedCurrency(currentCurrency)
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

            local elapsedTime = currentTime - startTime
            local avgMoney = "0"
            if elapsedTime > 0 then
                -- 使用总收益计算平均速度
                local rawAvg = earnedAmount / (elapsedTime / 3600)
                avgMoney = formatNumber(math.floor(rawAvg + 0.5))
            end

            local embed = {
                title = "Pluto-X",
                description = string.format("**游戏**: %s\n**用户**: %s", gameName, username),
                fields = {
                    {
                        name = "💰金额通知",
                        value = string.format(
                            "**用户名**: %s\n**已运行时间**: %s\n**当前金额**: %s\n**本次变化**: %s%s\n**总计收益**: %s%s\n**平均速度**: %s /小时",
                            username,
                            formatElapsedTime(elapsedTime),
                            formatNumber(currentCurrency),
                            (earnedChange >= 0 and "+" or ""), formatNumber(earnedChange),  -- 本次变化
                            (earnedAmount >= 0 and "+" or ""), formatNumber(earnedAmount),  -- 总计收益
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
                updateLastNotifyCurrency(currentCurrency)  -- 关键：更新通知基准金额
                updateLastSavedCurrency(currentCurrency)
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
    end

    wait(checkInterval)
end