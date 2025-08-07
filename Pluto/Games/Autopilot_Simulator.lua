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
local configFile = "Pluto_X_AS_config.json"
local config = {
    webhookUrl = "",
    notifyCash = false,
    notificationInterval = 30,
    welcomeSent = false,
    targetCurrency = 0,
    enableTargetKick = false
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
local player = game.Players.LocalPlayer

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

local success, currencyValue = pcall(fetchCurrentCurrency)
if success and currencyValue then
    initialCurrency = currencyValue
    lastCurrency = currencyValue
    local formattedCurrency = formatWithCommas(currencyValue)
    UILibrary:Notify({ Title = "初始化成功", Text = "初始金额: " .. formattedCurrency, Duration = 5 })
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

-- autofarm模块封装
-- autofarm完整脚本（含调试输出）
local isFarming = false
local platformFolder = nil
local farmTask = nil

local function stopAutoFarm()
    print("[autofarm] Stop 被调用")
    isFarming = false
    if farmTask then
        task.cancel(farmTask)
        farmTask = nil
        print("[autofarm] 任务已取消")
    end
    if platformFolder then
        platformFolder:Destroy()
        platformFolder = nil
        print("[autofarm] 平台已销毁")
    end
end

local function startAutoFarm()
    print("[autofarm] 尝试启动")
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
    print("[autofarm] 找到车辆:", carModel.Name)

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
    print("[autofarm] 设置 PrimaryPart 成功")

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
    print("[autofarm] 平台创建成功")

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
    print("[autofarm] 车辆已传送至起始位置")

    isFarming = true
    farmTask = task.spawn(function()
        print("[autofarm] 循环任务开始")
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
                print("[autofarm] 重置位置")
            end

            task.wait(interval)
        end
        print("[autofarm] 循环任务结束")
        if platformFolder then
            platformFolder:Destroy()
            platformFolder = nil
            print("[autofarm] 平台已销毁")
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
local mainFeaturesTab, mainFeaturesContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "主要功能",
})

-- 卡片：autofarm
local autoFarmCard = UILibrary:CreateCard(mainFeaturesContent, { IsMultiElement = true })
UILibrary:CreateLabel(autoFarmCard, {
    Text = "autofarm",
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0, 5, 0, 5)
})

-- Toggle 控件绑定逻辑
local autoFarmToggle = UILibrary:CreateToggle(autoFarmCard, {
    Text = "autofarm",
    DefaultState = false,
    Position = UDim2.new(0, 5, 0, 30),
    Callback = function(state)
        print("[autofarm] Toggle 状态切换为:", state)
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
local lastMoveTime = tick()
local lastPosition = nil
local idleThreshold = 300
local checkInterval = 1

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