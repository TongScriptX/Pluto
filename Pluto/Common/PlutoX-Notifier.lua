-- ============================================================================
-- 通用金额通知基础结构
-- ============================================================================
-- 作者: tongblx
-- 描述: 提供通用的金额检测、目标金额踢出、通知间隔管理等功能
--       可被各个游戏脚本引用使用
-- ============================================================================

local PlutoX = {}

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 格式化数字为千位分隔
function PlutoX.formatNumber(num)
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

-- 格式化运行时长
function PlutoX.formatElapsedTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d小时%02d分%02d秒", hours, minutes, secs)
end

-- ============================================================================
-- 配置管理
-- ============================================================================

function PlutoX.createConfigManager(configFile, HttpService, UILibrary, username, defaultConfig)
    local manager = {}
    
    -- 合并默认配置
    manager.defaultConfig = defaultConfig or {
        webhookUrl = "",
        notifyCash = false,
        notificationInterval = 30,
        targetAmount = 0,
        enableTargetKick = false,
        lastSavedCurrency = 0,
        baseAmount = 0,
        totalEarningsBase = 0,
        lastNotifyCurrency = 0,
    }
    
    manager.config = {}
    manager.configFile = configFile
    manager.HttpService = HttpService
    manager.UILibrary = UILibrary
    manager.username = username
    
    -- 保存配置
    function manager:saveConfig()
        pcall(function()
            local allConfigs = {}
            
            if isfile(self.configFile) then
                local ok, content = pcall(function()
                    return self.HttpService:JSONDecode(readfile(self.configFile))
                end)
                if ok and type(content) == "table" then
                    allConfigs = content
                end
            end
            
            allConfigs[self.username] = self.config
            writefile(self.configFile, self.HttpService:JSONEncode(allConfigs))
            
            self.UILibrary and self.UILibrary:Notify({
                Title = "配置已保存",
                Text = "配置已保存至 " .. self.configFile,
                Duration = 5,
            })
        end)
    end
    
    -- 加载配置
    function manager:loadConfig()
        if not isfile(self.configFile) then
            self.UILibrary and self.UILibrary:Notify({
                Title = "配置提示",
                Text = "创建新配置文件",
                Duration = 5,
            })
            self:saveConfig()
            return self.config
        end
        
        local success, result = pcall(function()
            return self.HttpService:JSONDecode(readfile(self.configFile))
        end)
        
        if success and type(result) == "table" then
            local userConfig = result[self.username]
            if userConfig and type(userConfig) == "table" then
                for k, v in pairs(userConfig) do
                    self.config[k] = v
                end
                self.UILibrary and self.UILibrary:Notify({
                    Title = "配置已加载",
                    Text = "用户配置加载成功",
                    Duration = 5,
                })
            else
                self.UILibrary and self.UILibrary:Notify({
                    Title = "配置提示",
                    Text = "使用默认配置",
                    Duration = 5,
                })
                self:saveConfig()
            end
        else
            self.UILibrary and self.UILibrary:Notify({
                Title = "配置错误",
                Text = "无法解析配置文件",
                Duration = 5,
            })
            self:saveConfig()
        end
        
        return self.config
    end
    
    -- 获取配置值
    function manager:get(key, defaultValue)
        local value = self.config[key]
        if value == nil then
            return defaultValue
        end
        return value
    end
    
    -- 设置配置值
    function manager:set(key, value, shouldSave)
        shouldSave = shouldSave ~= false
        
        if self.config[key] ~= value then
            self.config[key] = value
            if shouldSave then
                self:saveConfig()
            end
            return true
        end
        return false
    end
    
    -- 更新多个配置值
    function manager:update(updates, shouldSave)
        shouldSave = shouldSave ~= false
        
        local changed = false
        for key, value in pairs(updates) do
            if self.config[key] ~= value then
                self.config[key] = value
                changed = true
            end
        end
        
        if changed and shouldSave then
            self:saveConfig()
        end
        
        return changed
    end
    
    -- 重置配置
    function manager:reset()
        self.config = {}
        for k, v in pairs(self.defaultConfig) do
            self.config[k] = v
        end
        self:saveConfig()
        
        self.UILibrary and self.UILibrary:Notify({
            Title = "配置已重置",
            Text = "配置已恢复默认值",
            Duration = 5,
        })
        
        return self.config
    end
    
    -- 添加自定义配置项
    function manager:addDefault(key, defaultValue)
        self.defaultConfig[key] = defaultValue
        if self.config[key] == nil then
            self.config[key] = defaultValue
        end
    end
    
    return manager
end

-- ============================================================================
-- Webhook 管理
-- ============================================================================

function PlutoX.createWebhookManager(config, HttpService, UILibrary, gameName, username)
    local manager = {}
    
    manager.config = config
    manager.HttpService = HttpService
    manager.UILibrary = UILibrary
    manager.gameName = gameName
    manager.username = username
    manager.sendingWelcome = false
    
    -- 发送 Webhook
    function manager:dispatchWebhook(payload)
        if self.config.webhookUrl == "" then
            warn("[Webhook] 未设置 webhookUrl")
            return false
        end
        
        local requestFunc = syn and syn.request or http and http.request or request
        if not requestFunc then
            warn("[Webhook] 无可用请求函数")
            return false
        end
        
        local bodyJson = self.HttpService:JSONEncode({
            content = nil,
            embeds = payload.embeds
        })
        
        local success, res = pcall(function()
            return requestFunc({
                Url = self.config.webhookUrl,
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
    
    -- 发送欢迎消息
    function manager:sendWelcomeMessage()
        if self.config.webhookUrl == "" then
            warn("[Webhook] 欢迎消息: Webhook 地址未设置")
            return false
        end
        
        if self.sendingWelcome then
            return false
        end
        
        self.sendingWelcome = true
        
        local payload = {
            embeds = {{
                title = "欢迎使用Pluto-X",
                description = string.format("**游戏**: %s\n**用户**: %s\n**启动时间**: %s",
                    self.gameName, self.username, os.date("%Y-%m-%d %H:%M:%S")),
                color = _G.PRIMARY_COLOR or 5793266,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }}
        }
        
        local success = self:dispatchWebhook(payload)
        self.sendingWelcome = false
        
        if success then
            self.UILibrary and self.UILibrary:Notify({
                Title = "Webhook",
                Text = "欢迎消息已发送",
                Duration = 3
            })
        else
            warn("[Webhook] 欢迎消息发送失败")
        end
        
        return success
    end
    
    -- 发送金额变化通知
    function manager:sendCurrencyChange(currentCurrency, earnedChange, totalEarned)
        return self:dispatchWebhook({
            embeds = {{
                title = "💰 金额变化通知",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n**本次变化**: %s\n**总收益**: %s",
                    self.gameName, self.username,
                    PlutoX.formatNumber(currentCurrency),
                    PlutoX.formatNumber(earnedChange),
                    PlutoX.formatNumber(totalEarned)),
                color = _G.PRIMARY_COLOR or 5793266,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }}
        })
    end
    
    -- 发送目标达成通知
    function manager:sendTargetAchieved(currentCurrency, targetAmount, baseAmount, runTime)
        return self:dispatchWebhook({
            embeds = {{
                title = "🎯 目标金额达成",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n**目标金额**: %s\n**基准金额**: %s\n**运行时长**: %s",
                    self.gameName, self.username,
                    PlutoX.formatNumber(currentCurrency),
                    PlutoX.formatNumber(targetAmount),
                    PlutoX.formatNumber(baseAmount),
                    PlutoX.formatElapsedTime(runTime)),
                color = _G.PRIMARY_COLOR or 5793266,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }}
        })
    end
    
    -- 发送掉线通知
    function manager:sendDisconnect(currentCurrency)
        return self:dispatchWebhook({
            embeds = {{
                title = "⚠️ 掉线检测",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n检测到掉线",
                    self.gameName, self.username, PlutoX.formatNumber(currentCurrency or 0)),
                color = 16753920,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }}
        })
    end
    
    -- 发送金额未变化警告
    function manager:sendNoChange(currentCurrency)
        return self:dispatchWebhook({
            embeds = {{
                title = "⚠️ 金额未变化",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前金额**: %s\n连续两次金额无变化",
                    self.gameName, self.username, PlutoX.formatNumber(currentCurrency or 0)),
                color = 16753920,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "作者: tongblx · Pluto-X" }
            }}
        })
    end
    
    return manager
end

-- ============================================================================
-- 金额通知管理器
-- ============================================================================

function PlutoX.createCurrencyNotifier(config, UILibrary, gameName, username)
    local notifier = {}
    
    notifier.config = config
    notifier.UILibrary = UILibrary
    notifier.gameName = gameName
    notifier.username = username
    
    -- 内部状态
    notifier.initialCurrency = 0
    notifier.lastSendTime = os.time()
    notifier.unchangedCount = 0
    notifier.webhookDisabled = false
    notifier.startTime = os.time()
    notifier.lastCurrency = nil
    notifier.checkInterval = 1
    
    -- 获取通知间隔（秒）
    function notifier:getNotificationIntervalSeconds()
        return (self.config.notificationInterval or 5) * 60
    end
    
    -- 初始化金额
    function notifier:initCurrency(fetchFunc)
        local success, currencyValue = pcall(fetchFunc)
        if success and currencyValue then
            self.initialCurrency = currencyValue
            
            if self.config.totalEarningsBase == 0 then
                self.config.totalEarningsBase = currencyValue
            end
            
            if self.config.lastNotifyCurrency == 0 then
                self.config.lastNotifyCurrency = currencyValue
            end
            
            self.UILibrary and self.UILibrary:Notify({
                Title = "初始化成功",
                Text = "当前金额: " .. tostring(currencyValue),
                Duration = 5
            })
            
            return currencyValue
        end
        return nil
    end
    
    -- 获取当前金额
    function notifier:fetchCurrency(fetchFunc)
        local success, value = pcall(fetchFunc)
        if success then
            return value
        end
        return nil
    end
    
    -- 计算实际赚取金额
    function notifier:calculateEarned(currentCurrency)
        if not currentCurrency then return 0 end
        
        if self.config.totalEarningsBase > 0 then
            return currentCurrency - self.config.totalEarningsBase
        else
            return currentCurrency - self.initialCurrency
        end
    end
    
    -- 计算本次变化
    function notifier:calculateChange(currentCurrency)
        if not currentCurrency then return 0 end
        
        if self.config.lastNotifyCurrency > 0 then
            return currentCurrency - self.config.lastNotifyCurrency
        else
            return self:calculateEarned(currentCurrency)
        end
    end
    
    -- 更新通知基准金额
    function notifier:updateLastNotifyCurrency(currentCurrency)
        if currentCurrency then
            self.config.lastNotifyCurrency = currentCurrency
            -- 需要外部调用 saveConfig
        end
    end
    
    -- 更新保存的金额
    function notifier:updateLastSavedCurrency(currentCurrency)
        if currentCurrency and currentCurrency ~= self.config.lastSavedCurrency then
            self.config.lastSavedCurrency = currentCurrency
            -- 需要外部调用 saveConfig
        end
    end
    
    -- 调整目标金额（只在金额减少时调整）
    function notifier:adjustTargetAmount(fetchFunc, saveConfig)
        if self.config.baseAmount <= 0 or self.config.targetAmount <= 0 then
            return
        end
        
        local currentCurrency = fetchFunc()
        if not currentCurrency then
            return
        end
        
        local currencyDifference = currentCurrency - self.config.lastSavedCurrency
        
        -- 只在金额减少时调整
        if currencyDifference < 0 then
            local newTargetAmount = self.config.targetAmount + currencyDifference
            
            if newTargetAmount > currentCurrency then
                self.config.targetAmount = newTargetAmount
                self.UILibrary and self.UILibrary:Notify({
                    Title = "目标金额已调整",
                    Text = string.format("检测到金额减少 %s，目标调整至: %s",
                        PlutoX.formatNumber(math.abs(currencyDifference)),
                        PlutoX.formatNumber(self.config.targetAmount)),
                    Duration = 5
                })
                if saveConfig then saveConfig() end
            else
                self.config.enableTargetKick = false
                self.config.targetAmount = 0
                self.config.baseAmount = 0
                self.UILibrary and self.UILibrary:Notify({
                    Title = "目标金额已重置",
                    Text = "调整后的目标金额小于当前金额，已禁用目标踢出功能",
                    Duration = 5
                })
                if saveConfig then saveConfig() end
            end
        end
        
        self.config.lastSavedCurrency = currentCurrency
        if saveConfig then saveConfig() end
    end
    
    -- 初始化时校验目标金额
    function notifier:initTargetAmount(fetchFunc, saveConfig)
        local currentCurrency = fetchFunc() or 0
        
        if self.config.enableTargetKick and self.config.targetAmount > 0 and currentCurrency >= self.config.targetAmount then
            self UILibrary and self UILibrary:Notify({
                Title = "目标金额已达成",
                Text = string.format("当前金额 %s，已超过目标 %s",
                    CommonFramework.formatNumber(currentCurrency), CommonFramework.formatNumber(self.config.targetAmount)),
                Duration = 5
            })
            self.config.enableTargetKick = false
            self.config.targetAmount = 0
            if saveConfig then saveConfig() end
        end
    end
    
    -- 检测目标金额是否达成
    function notifier:checkTargetAmount(fetchFunc, webhookManager, saveConfig)
        if not self.config.enableTargetKick or self.config.targetAmount <= 0 then
            return false
        end
        
        local currentCurrency = fetchFunc()
        if not currentCurrency then
            return false
        end
        
        if currentCurrency >= self.config.targetAmount then
            local currentTime = os.time()
            
            webhookManager:sendTargetAchieved(
                currentCurrency,
                self.config.targetAmount,
                self.config.baseAmount,
                currentTime - self.startTime
            )
            
            self.UILibrary and self.UILibrary:Notify({
                Title = "🎯 目标达成",
                Text = string.format("已达到目标金额 %s，准备退出...", PlutoX.formatNumber(self.config.targetAmount)),
                Duration = 10
            })
            
            if saveConfig then
                self:updateLastSavedCurrency(currentCurrency)
                saveConfig()
            end
            
            self.config.enableTargetKick = false
            if saveConfig then saveConfig() end
            
            return true
        end
        
        return false
    end
    
    -- 检测金额变化并发送通知
    function notifier:checkCurrencyChange(fetchFunc, webhookManager, saveConfig)
        if self.webhookDisabled or not self.config.notifyCash then
            return false
        end
        
        local currentTime = os.time()
        local interval = currentTime - self.lastSendTime
        
        if interval < self:getNotificationIntervalSeconds() then
            return false
        end
        
        local currentCurrency = fetchFunc()
        if not currentCurrency then
            return false
        end
        
        local earnedChange = self:calculateChange(currentCurrency)
        
        -- 检测金额变化
        if currentCurrency == self.lastCurrency and earnedChange == 0 then
            self.unchangedCount = self.unchangedCount + 1
        else
            self.unchangedCount = 0
        end
        
        -- 连续无变化警告
        if self.unchangedCount >= 2 then
            webhookManager:sendNoChange(currentCurrency)
            self.webhookDisabled = true
            self.lastSendTime = currentTime
            self.lastCurrency = currentCurrency
            self:updateLastNotifyCurrency(currentCurrency)
            if saveConfig then saveConfig() end
            return false
        end
        
        -- 发送金额变化通知
        webhookManager:sendCurrencyChange(
            currentCurrency,
            earnedChange,
            self:calculateEarned(currentCurrency)
        )
        
        self.lastSendTime = currentTime
        self.lastCurrency = currentCurrency
        self:updateLastNotifyCurrency(currentCurrency)
        if saveConfig then saveConfig() end
        
        return true
    end
    
    return notifier
end

-- ============================================================================
-- 掉线检测
-- ============================================================================

function PlutoX.createDisconnectDetector(UILibrary, webhookManager)
    local detector = {}
    
    detector.disconnected = false
    detector.UILibrary = UILibrary
    detector.webhookManager = webhookManager
    
    -- 初始化检测
    function detector:init()
        local GuiService = game:GetService("GuiService")
        local NetworkClient = game:GetService("NetworkClient")
        
        NetworkClient.ChildRemoved:Connect(function()
            if not self.disconnected then
                warn("[掉线检测] 网络断开")
                self.disconnected = true
            end
        end)
        
        GuiService.ErrorMessageChanged:Connect(function(msg)
            if msg and msg ~= "" and not self.disconnected then
                warn("[掉线检测] 错误提示：" .. msg)
                self.disconnected = true
            end
        end)
    end
    
    -- 检测掉线并发送通知
    function detector:checkAndNotify(currentCurrency)
        if self.disconnected and self.webhookManager then
            self.webhookManager:sendDisconnect(currentCurrency)
            self.UILibrary and self.UILibrary:Notify({
                Title = "掉线检测",
                Text = "检测到连接异常",
                Duration = 5
            })
            return true
        end
        return false
    end
    
    -- 重置状态
    function detector:reset()
        self.disconnected = false
    end
    
    return detector
end

-- ============================================================================
-- 反挂机
-- ============================================================================

function PlutoX.setupAntiAfk(player, UILibrary)
    local VirtualUser = game:GetService("VirtualUser")
    
    player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        UILibrary and UILibrary:Notify({ Title = "反挂机", Text = "检测到闲置，已自动操作", Duration = 3 })
    end)
end

-- ============================================================================
-- UI 组件创建辅助函数
-- ============================================================================

-- 创建 Webhook 配置卡片
function PlutoX.createWebhookCard(parent, UILibrary, config, saveConfig, webhookManager)
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    UILibrary:CreateLabel(card, {
        Text = "Webhook 地址",
    })
    
    local webhookInput = UILibrary:CreateTextBox(card, {
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
                    webhookManager:sendWelcomeMessage()
                end)
            else
                UILibrary:Notify({
                    Title = "Webhook 更新",
                    Text = "地址已保存",
                    Duration = 5
                })
            end
            
            if saveConfig then saveConfig() end
        end
    })
    webhookInput.Text = config.webhookUrl
    
    return card, webhookInput
end

-- 创建金额监测开关卡片
function PlutoX.createCurrencyNotifyCard(parent, UILibrary, config, saveConfig)
    local card = UILibrary:CreateCard(parent)
    
    local toggle = UILibrary:CreateToggle(card, {
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
            if saveConfig then saveConfig() end
        end
    })
    
    return card, toggle
end

-- 创建通知间隔卡片
function PlutoX.createIntervalCard(parent, UILibrary, config, saveConfig)
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    UILibrary:CreateLabel(card, {
        Text = "通知间隔（分钟）",
    })
    
    local intervalInput = UILibrary:CreateTextBox(card, {
        PlaceholderText = "输入间隔时间",
        OnFocusLost = function(text)
            if not text then return end
            local num = tonumber(text)
            if num and num > 0 then
                config.notificationInterval = num
                UILibrary:Notify({ Title = "配置更新", Text = "通知间隔: " .. num .. " 分钟", Duration = 5 })
                if saveConfig then saveConfig() end
            else
                intervalInput.Text = tostring(config.notificationInterval)
                UILibrary:Notify({ Title = "配置错误", Text = "请输入有效数字", Duration = 5 })
            end
        end
    })
    intervalInput.Text = tostring(config.notificationInterval)
    
    return card, intervalInput
end

-- 创建基准金额设置卡片
function PlutoX.createBaseAmountCard(parent, UILibrary, config, saveConfig, fetchCurrency, formatNumber)
    formatNumber = formatNumber or PlutoX.formatNumber
    
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    UILibrary:CreateLabel(card, {
        Text = "基准金额设置",
    })
    
    local targetAmountLabel
    local suppressTargetToggleCallback = false
    local targetAmountToggle
    
    local baseAmountInput = UILibrary:CreateTextBox(card, {
        PlaceholderText = "输入基准金额",
        OnFocusLost = function(text)
            text = text and text:match("^%s*(.-)%s*$")
            
            if not text or text == "" then
                config.baseAmount = 0
                config.targetAmount = 0
                config.lastSavedCurrency = 0
                baseAmountInput.Text = ""
                if targetAmountLabel then
                    targetAmountLabel.Text = "目标金额: 未设置"
                end
                if saveConfig then saveConfig() end
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
                local currentCurrency = fetchCurrency() or 0
                local newTarget = num + currentCurrency
                
                config.baseAmount = num
                config.targetAmount = newTarget
                config.lastSavedCurrency = currentCurrency
                
                baseAmountInput.Text = formatNumber(num)
                
                if targetAmountLabel then
                    targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
                end
                
                if saveConfig then saveConfig() end
                
                UILibrary:Notify({
                    Title = "基准金额已设置",
                    Text = string.format("基准: %s\n当前: %s\n目标: %s\n\n后续只在金额减少时调整",
                        formatNumber(num),
                        formatNumber(currentCurrency),
                        formatNumber(newTarget)),
                    Duration = 8
                })
                
                if config.enableTargetKick and currentCurrency >= newTarget then
                    suppressTargetToggleCallback = true
                    if targetAmountToggle then
                        targetAmountToggle:Set(false)
                    end
                    config.enableTargetKick = false
                    if saveConfig then saveConfig() end
                    UILibrary:Notify({
                        Title = "自动关闭",
                        Text = "当前金额已达目标，踢出功能已关闭",
                        Duration = 6
                    })
                end
            else
                baseAmountInput.Text = config.baseAmount > 0 and formatNumber(config.baseAmount) or ""
                UILibrary:Notify({
                    Title = "配置错误",
                    Text = "请输入有效的正整数",
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
    
    return card, baseAmountInput, function(label, toggle)
        targetAmountLabel = label
        targetAmountToggle = toggle
    end, function()
        return suppressTargetToggleCallback, targetAmountToggle
    end
end

-- 创建目标金额踢出卡片
function PlutoX.createTargetAmountCard(parent, UILibrary, config, saveConfig, fetchCurrency, formatNumber)
    formatNumber = formatNumber or PlutoX.formatNumber
    
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    local targetAmountLabel
    local suppressTargetToggleCallback = false
    local targetAmountToggle
    
    targetAmountToggle = UILibrary:CreateToggle(card, {
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
            
            local currentCurrency = fetchCurrency()
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
            if saveConfig then saveConfig() end
        end
    })
    
    targetAmountLabel = UILibrary:CreateLabel(card, {
        Text = "目标金额: " .. (config.targetAmount > 0 and formatNumber(config.targetAmount) or "未设置"),
    })
    
    UILibrary:CreateButton(card, {
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
            
            local currentCurrency = fetchCurrency() or 0
            local newTarget = config.baseAmount + currentCurrency
            
            if newTarget <= currentCurrency then
                UILibrary:Notify({
                    Title = "计算错误",
                    Text = "目标金额不能小于等于当前金额",
                    Duration = 6
                })
                return
            end
            
            config.targetAmount = newTarget
            config.lastSavedCurrency = currentCurrency
            
            targetAmountLabel.Text = "目标金额: " .. formatNumber(newTarget)
            
            if saveConfig then saveConfig() end
            
            UILibrary:Notify({
                Title = "目标金额已重新计算",
                Text = string.format("基准: %s\n当前: %s\n新目标: %s\n\n后续只在金额减少时调整",
                    formatNumber(config.baseAmount),
                    formatNumber(currentCurrency),
                    formatNumber(newTarget)),
                Duration = 8
            })
            
            if config.enableTargetKick and currentCurrency >= newTarget then
                suppressTargetToggleCallback = true
                targetAmountToggle:Set(false)
                config.enableTargetKick = false
                if saveConfig then saveConfig() end
                UILibrary:Notify({
                    Title = "自动关闭",
                    Text = "当前金额已达目标，踢出功能已关闭",
                    Duration = 6
                })
            end
        end
    })
    
    return card, targetAmountLabel, function(suppress, toggle)
        suppressTargetToggleCallback = suppress
        targetAmountToggle = toggle
    end
end

-- ============================================================================
-- 关于页面辅助函数
-- ============================================================================

function PlutoX.createAboutPage(parent, UILibrary)
    UILibrary:CreateAuthorInfo(parent, {
        Text = "作者: tongblx",
        SocialText = "感谢使用"
    })
    
    UILibrary:CreateButton(parent, {
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
end

-- ============================================================================
-- 导出
-- ============================================================================

return PlutoX