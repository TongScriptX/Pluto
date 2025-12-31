
-- PlutoX-Notifier

local PlutoX = {}

-- Debug 功能
PlutoX.debugEnabled = false

function PlutoX.debug(...)
    if PlutoX.debugEnabled then
        print("[PlutoX-DEBUG]", ...)
    end
end

-- Webhook Footer 配置
PlutoX.footerText = "桐 · TStudioX"

-- 脚本实例管理（防止多个脚本同时运行）
PlutoX.scriptInstances = {}

-- 注册脚本实例
function PlutoX.registerScriptInstance(gameName, username, webhookManager)
    local instanceId = gameName .. ":" .. username
    
    -- 检查是否已存在相同游戏和用户的实例
    if PlutoX.scriptInstances[instanceId] then
        warn("[脚本实例] 检测到相同脚本已在运行: " .. instanceId)
        return false
    end
    
    -- 注册新实例
    PlutoX.scriptInstances[instanceId] = {
        gameName = gameName,
        username = username,
        startTime = os.time()
    }
    return true
end

-- 注销脚本实例
function PlutoX.unregisterScriptInstance(gameName, username)
    local instanceId = gameName .. ":" .. username
    PlutoX.scriptInstances[instanceId] = nil
end

-- 工具函数

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

-- 数据类型注册系统

PlutoX.dataTypes = {}

-- 注册数据类型
-- @param dataType 数据类型定义表
--   - id: 数据类型唯一标识（如 "cash", "wins", "miles", "level"）
--   - name: 显示名称（如 "金额", "胜利次数"）
--   - icon: 图标（如 "💰", "🏆"）
--   - unit: 单位（可选，如 "英里"）
--   - fetchFunc: 获取当前值的函数
--   - calculateAvg: 是否计算平均速度（默认 false）
--   - supportTarget: 是否支持目标检测（默认 false）
--   - formatFunc: 自定义格式化函数（可选，默认使用 formatNumber）
function PlutoX.registerDataType(dataType)
    if not dataType or not dataType.id or not dataType.name then
        error("数据类型必须包含 id 和 name 字段")
    end
    
    PlutoX.dataTypes[dataType.id] = {
        id = dataType.id,
        name = dataType.name,
        icon = dataType.icon or "📊",
        unit = dataType.unit or "",
        fetchFunc = dataType.fetchFunc,
        calculateAvg = dataType.calculateAvg or false,
        supportTarget = dataType.supportTarget or false,
        formatFunc = dataType.formatFunc or PlutoX.formatNumber
    }
    
    return PlutoX.dataTypes[dataType.id]
end

-- 获取数据类型定义
function PlutoX.getDataType(id)
    return PlutoX.dataTypes[id]
end

-- 获取所有注册的数据类型
function PlutoX.getAllDataTypes()
    local types = {}
    for id, typeDef in pairs(PlutoX.dataTypes) do
        table.insert(types, typeDef)
    end
    return types
end

-- 生成数据类型相关的配置项
function PlutoX.generateDataTypeConfigs(dataTypes)
    local configs = {}
    for _, dataType in ipairs(dataTypes) do
        local id = dataType.id
        local keyUpper = id:gsub("^%l", string.upper)
        -- 监测开关
        configs["notify" .. keyUpper] = false
        -- 基准值
        configs["total" .. keyUpper .. "Base"] = 0
        -- 上次通知值
        configs["lastNotify" .. keyUpper] = 0
        
        -- 如果支持目标检测，生成目标相关配置
        if dataType.supportTarget then
            configs["target" .. keyUpper] = 0
            configs["enable" .. keyUpper .. "Kick"] = false
            configs["base" .. keyUpper] = 0
            configs["lastSaved" .. keyUpper] = 0
        end
    end
    return configs
end

-- 配置管理

function PlutoX.createConfigManager(configFile, HttpService, UILibrary, username, defaultConfig)
    local manager = {}
    
    manager.defaultConfig = defaultConfig or {}
    manager.config = {}
    manager.configFile = configFile
    manager.HttpService = HttpService
    manager.UILibrary = UILibrary
    manager.username = username
    
    -- 添加自定义配置项
    function manager:addDefault(key, defaultValue)
        self.defaultConfig[key] = defaultValue
        if self.config[key] == nil then
            self.config[key] = defaultValue
        end
    end
    
    -- 保存配置
    function manager:saveConfig()
        PlutoX.debug("saveConfig 被调用")
        -- 打印调用堆栈
        local stack = debug.traceback("", 2)
        PlutoX.debug("[DEBUG] 调用堆栈:\n" .. stack)
        
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
            PlutoX.debug("配置已写入文件: " .. self.configFile)

            if self.UILibrary then
                self.UILibrary:Notify({
                    Title = "配置已保存",
                    Text = "配置已保存至 " .. self.configFile,
                    Duration = 5,
                })
            end
        end)
    end
    
    -- 加载配置
    function manager:loadConfig()
        for k, v in pairs(self.defaultConfig) do
            self.config[k] = v
        end

        if not isfile(self.configFile) then
            if self.UILibrary then
                self.UILibrary:Notify({
                    Title = "配置提示",
                    Text = "创建新配置文件",
                    Duration = 5,
                })
            end
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
                if self.UILibrary then
                    self.UILibrary:Notify({
                        Title = "配置已加载",
                        Text = "用户配置加载成功",
                        Duration = 5,
                    })
                end
            else
                self:saveConfig()
            end
        else
            self:saveConfig()
        end

        return self.config
    end
    
    return manager
end

-- Webhook 管理

function PlutoX.createWebhookManager(config, HttpService, UILibrary, gameName, username)
    local manager = {}
    
    manager.config = config
    manager.HttpService = HttpService
    manager.UILibrary = UILibrary
    manager.gameName = gameName
    manager.username = username
    manager.sendingWelcome = false
    
    -- 自动注册脚本实例
    local instanceId = gameName .. ":" .. username
    if not PlutoX.scriptInstances[instanceId] then
        PlutoX.scriptInstances[instanceId] = {
            gameName = gameName,
            username = username,
            startTime = os.time()
        }
    else
        warn("[Webhook] 检测到相同脚本已在运行: " .. instanceId)
    end
    
    -- 发送 Webhook
    function manager:dispatchWebhook(payload)
        -- 检查脚本实例是否仍然有效
        local instanceId = self.gameName .. ":" .. self.username
        if not PlutoX.scriptInstances[instanceId] then
            warn("[Webhook] 脚本实例已失效，停止发送: " .. instanceId)
            return false
        end
        
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
                description = string.format("**游戏**: %s\n**用户**: %s", self.gameName, self.username),
                fields = {
                    {
                        name = "📝 启动信息",
                        value = string.format("**启动时间**: %s", os.date("%Y-%m-%d %H:%M:%S")),
                        inline = false
                    }
                },
                color = _G.PRIMARY_COLOR or 5793266,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "桐 · TStudioX" }
            }}
        }

        local success = self:dispatchWebhook(payload)
        self.sendingWelcome = false

        if success then
            if self.UILibrary then
                self.UILibrary:Notify({
                    Title = "Webhook",
                    Text = "欢迎消息已发送",
                    Duration = 3
                })
            end
        else
            warn("[Webhook] 欢迎消息发送失败")
        end

        return success
    end
    
    -- 发送目标达成通知
    function manager:sendTargetAchieved(currentValue, targetAmount, baseAmount, runTime, dataTypeName)
        return self:dispatchWebhook({
            embeds = {{
                title = "🎯 目标达成",
                description = string.format("**游戏**: %s\n**用户**: %s", self.gameName, self.username),
                fields = {
                    {
                        name = "📊 达成信息",
                        value = string.format(
                            "**数据类型**: %s\n**当前值**: %s\n**目标值**: %s\n**基准值**: %s\n**运行时长**: %s",
                            dataTypeName or "未知",
                            PlutoX.formatNumber(currentValue),
                            PlutoX.formatNumber(targetAmount),
                            PlutoX.formatNumber(baseAmount),
                            PlutoX.formatElapsedTime(runTime)),
                        inline = false
                    }
                },
                color = _G.PRIMARY_COLOR or 5793266,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "桐 · TStudioX" }
            }}
        })
    end
    
    -- 发送掉线通知
    function manager:sendDisconnect(dataTable)
        local dataText = {}
        for id, value in pairs(dataTable) do
            local dataType = PlutoX.getDataType(id)
            if dataType then
                table.insert(dataText, string.format("%s: %s", dataType.icon .. dataType.name, dataType.formatFunc(value)))
            end
        end

        return self:dispatchWebhook({
            embeds = {{
                title = "⚠️ 掉线检测",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前数据**:\n%s\n\n检测到掉线",
                    self.gameName, self.username,
                    table.concat(dataText, " | ")),
                color = 16753920,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "桐 · TStudioX" }
            }}
        })
    end

    -- 发送数据未变化警告
    function manager:sendNoChange(dataTable)
        local dataText = {}
        for id, value in pairs(dataTable) do
            local dataType = PlutoX.getDataType(id)
            if dataType then
                table.insert(dataText, string.format("%s: %s", dataType.icon .. dataType.name, dataType.formatFunc(value)))
            end
        end

        return self:dispatchWebhook({
            embeds = {{
                title = "⚠️ 数据未变化",
                description = string.format(
                    "**游戏**: %s\n**用户**: %s\n**当前数据**:\n%s\n\n连续两次数据无变化",
                    self.gameName, self.username,
                    table.concat(dataText, " | ")),
                color = 16753920,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "桐 · TStudioX" }
            }}
        })
    end
    
    return manager
end

-- 通用数据监测管理器

function PlutoX.createDataMonitor(config, UILibrary, webhookManager, dataTypes)
    local monitor = {}
    
    monitor.config = config
    monitor.UILibrary = UILibrary
    monitor.webhookManager = webhookManager
    monitor.dataTypes = dataTypes or PlutoX.getAllDataTypes()
    
    -- 内部状态
    monitor.lastSendTime = os.time()
    monitor.startTime = os.time()
    monitor.unchangedCount = 0
    monitor.webhookDisabled = false
    monitor.lastValues = {}
    monitor.checkInterval = 1
    
    -- 初始化所有数据类型
    function monitor:init()
        local initInfo = {}
        for _, dataType in ipairs(self.dataTypes) do
            if dataType.fetchFunc then
                local success, value = pcall(dataType.fetchFunc)
                if success and value then
                    local keyUpper = dataType.id:gsub("^%l", string.upper)
                    self.config["total" .. keyUpper .. "Base"] = value
                    self.config["lastNotify" .. keyUpper] = value
                    self.lastValues[dataType.id] = value
                    table.insert(initInfo, string.format("%s: %s", dataType.icon .. dataType.name, dataType.formatFunc(value)))
                end
            end
        end
        
        if #initInfo > 0 and self.UILibrary then
            self.UILibrary:Notify({
                Title = "初始化成功",
                Text = table.concat(initInfo, " | "),
                Duration = 5
            })
        end
    end
    
    -- 获取数据当前值
    function monitor:fetchValue(dataType)
        if dataType.fetchFunc then
            local success, value = pcall(dataType.fetchFunc)
            if success then
                return value
            end
        end
        return nil
    end
    
    -- 计算总变化量
    function monitor:calculateTotalEarned(dataType, currentValue)
        if not currentValue then return 0 end
        
        local keyUpper = dataType.id:gsub("^%l", string.upper)
        local baseValue = self.config["total" .. keyUpper .. "Base"] or 0
        
        if baseValue > 0 then
            return currentValue - baseValue
        end
        return 0
    end
    
    -- 计算本次变化量
    function monitor:calculateChange(dataType, currentValue)
        if not currentValue then return 0 end
        
        local keyUpper = dataType.id:gsub("^%l", string.upper)
        local lastNotifyValue = self.config["lastNotify" .. keyUpper] or 0
        
        if lastNotifyValue > 0 then
            return currentValue - lastNotifyValue
        end
        return self:calculateTotalEarned(dataType, currentValue)
    end
    
    -- 检查是否需要通知
    function monitor:shouldNotify()
        for _, dataType in ipairs(self.dataTypes) do
            local keyUpper = dataType.id:gsub("^%l", string.upper)
            if self.config["notify" .. keyUpper] then
                return true
            end
        end
        return false
    end
    
    -- 收集所有数据
    function monitor:collectData()
        local data = {}
        for _, dataType in ipairs(self.dataTypes) do
            data[dataType.id] = {
                type = dataType,
                current = self:fetchValue(dataType),
                last = self.lastValues[dataType.id],
                totalEarned = nil,
                change = nil,
                avg = nil
            }
            
            if data[dataType.id].current ~= nil then
                data[dataType.id].totalEarned = self:calculateTotalEarned(dataType, data[dataType.id].current)
                data[dataType.id].change = self:calculateChange(dataType, data[dataType.id].current)
            end
        end
        return data
    end
    
    -- 检查是否有任何数据变化
    function monitor:hasAnyChange(data)
        for id, dataInfo in pairs(data) do
            local keyUpper = dataInfo.type.id:gsub("^%l", string.upper)
            if self.config["notify" .. keyUpper] then
                if dataInfo.current ~= dataInfo.last or dataInfo.change ~= 0 then
                    return true
                end
            end
        end
        return false
    end
    
    -- 发送多数据变化通知
    function monitor:sendDataChange(currentTime, interval)
        local data = self:collectData()
        local elapsedTime = currentTime - self.startTime
        
        -- 计算下次通知时间
        local nextNotifyTimestamp = currentTime + (self.config.notificationInterval or 30) * 60
        local countdownR = string.format("<t:%d:R>", nextNotifyTimestamp)
        local countdownT = string.format("<t:%d:T>", nextNotifyTimestamp)
        
        -- 构建 embed fields
        local fields = {}
        
        -- 为每个启用的数据类型创建一个 field
        for id, dataInfo in pairs(data) do
            local dataType = dataInfo.type
            local keyUpper = dataType.id:gsub("^%l", string.upper)
            
            if self.config["notify" .. keyUpper] and dataInfo.current ~= nil then
                -- 计算平均速度
                local avg = "0"
                if dataType.calculateAvg and interval > 0 and dataInfo.change ~= 0 then
                    local rawAvg = dataInfo.change / (interval / 3600)
                    avg = dataType.formatFunc(math.floor(rawAvg + 0.5))
                end
                
                -- 计算预计完成时间（如果有目标值）
                local estimatedTimeText = ""
                if dataType.supportTarget and self.config["target" .. keyUpper] and self.config["target" .. keyUpper] > 0 then
                    local remaining = self.config["target" .. keyUpper] - dataInfo.current
                    if remaining > 0 and avg ~= "0" then
                        -- avg 是每小时的速度，计算需要多少小时
                        local cleanedAvg = avg:gsub(",", "")
                        local avgNum = tonumber(cleanedAvg)
                        if avgNum and avgNum > 0 then
                            local hoursNeeded = remaining / avgNum
                            if hoursNeeded > 0 then
                                local days = math.floor(hoursNeeded / 24)
                                local hours = math.floor((hoursNeeded % 24))
                                local minutes = math.floor((hoursNeeded * 60) % 60)
                                
                                -- 计算完成时间戳
                                local completionTimestamp = currentTime + math.floor(hoursNeeded * 3600)
                                local countdownT = string.format("<t:%d:T>", completionTimestamp)
                                
                                if days > 0 then
                                    estimatedTimeText = string.format("\n**预计完成**: %d天%d小时%d分钟\n**完成时间**: %s", days, hours, minutes, countdownT)
                                elseif hours > 0 then
                                    estimatedTimeText = string.format("\n**预计完成**: %d小时%d分钟\n**完成时间**: %s", hours, minutes, countdownT)
                                else
                                    estimatedTimeText = string.format("\n**预计完成**: 小于一分钟\n**完成时间**: %s", countdownT)
                                end
                            end
                        end
                    end
                end
                
                local fieldText = string.format(
                    "**用户名**: %s\n**运行时长**: %s\n**当前%s**: %s%s\n**本次变化**: %s%s\n**总计变化**: %s%s",
                    self.webhookManager.username,
                    PlutoX.formatElapsedTime(elapsedTime),
                    dataType.name,
                    dataType.formatFunc(dataInfo.current),
                    dataType.unit ~= "" and " " .. dataType.unit or "",
                    (dataInfo.change >= 0 and "+" or ""), dataType.formatFunc(dataInfo.change),
                    (dataInfo.totalEarned >= 0 and "+" or ""), dataType.formatFunc(dataInfo.totalEarned)
                )
                
                if dataType.calculateAvg then
                    fieldText = fieldText .. string.format("\n**平均速度**: %s%s /小时", avg, dataType.unit)
                end
                
                if estimatedTimeText ~= "" then
                    fieldText = fieldText .. estimatedTimeText
                end
                
                table.insert(fields, {
                    name = dataType.icon .. dataType.name .. "通知",
                    value = fieldText,
                    inline = false
                })
            end
        end
        
        -- 添加下次通知
        table.insert(fields, {
            name = "⌛ 下次通知",
            value = string.format("%s(%s)", countdownR, countdownT),
            inline = false
        })
        
        local embed = {
            title = "Pluto-X",
            description = string.format("**游戏**: %s\n**用户**: %s", self.webhookManager.gameName, self.webhookManager.username),
            fields = fields,
            color = _G.PRIMARY_COLOR,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "桐 · TStudioX" }
        }
        
        return self.webhookManager:dispatchWebhook({ embeds = { embed } })
    end
    
    -- 发送掉线通知
    function monitor:sendDisconnect()
        local data = self:collectData()
        local dataTable = {}
        for id, dataInfo in pairs(data) do
            if dataInfo.current ~= nil then
                dataTable[id] = dataInfo.current
            end
        end
        return self.webhookManager:sendDisconnect(dataTable)
    end
    
    -- 发送数据未变化警告
    function monitor:sendNoChange()
        local data = self:collectData()
        local dataTable = {}
        for id, dataInfo in pairs(data) do
            if dataInfo.current ~= nil then
                dataTable[id] = dataInfo.current
            end
        end
        return self.webhookManager:sendNoChange(dataTable)
    end
    
    -- 主检查循环
    function monitor:checkAndNotify(saveConfig)
        if self.webhookDisabled then
            return false
        end
        
        if not self:shouldNotify() then
            return false
        end
        
        local currentTime = os.time()
        local interval = currentTime - self.lastSendTime
        
        if interval < self:getNotificationIntervalSeconds() then
            return false
        end
        
        local data = self:collectData()
        
        -- 检查是否有任何数据变化
        if not self:hasAnyChange(data) then
            self.unchangedCount = self.unchangedCount + 1
        else
            self.unchangedCount = 0
        end
        
        -- 连续无变化警告
        if self.unchangedCount >= 2 then
            self:sendNoChange()
            self.webhookDisabled = true
            self.lastSendTime = currentTime
            
            -- 更新所有数据的上次通知值
            for id, dataInfo in pairs(data) do
                if dataInfo.current ~= nil then
                    local keyUpper = dataInfo.type.id:gsub("^%l", string.upper)
                    self.config["lastNotify" .. keyUpper] = dataInfo.current
                end
            end
            
            if saveConfig then saveConfig() end
            return false
        end
        
        -- 发送数据变化通知
        self:sendDataChange(currentTime, interval)
        self.lastSendTime = currentTime
        
        -- 更新所有数据的上次通知值和最后值
        for id, dataInfo in pairs(data) do
            if dataInfo.current ~= nil then
                local keyUpper = dataInfo.type.id:gsub("^%l", string.upper)
                self.config["lastNotify" .. keyUpper] = dataInfo.current
                self.lastValues[id] = dataInfo.current
            end
        end
        
        if saveConfig then saveConfig() end
        return true
    end
    
-- 目标值调整（通用：适用于任何支持目标检测的数据类型）
    function monitor:adjustTargetValue(saveConfig, dataTypeId)
        if not dataTypeId then
            -- 调整所有数据类型的目标值
            for _, dataType in ipairs(self.dataTypes) do
                if dataType.supportTarget then
                    self:adjustTargetValue(saveConfig, dataType.id)
                end
            end
            return true
        end
        
        local dataType = PlutoX.getDataType(dataTypeId)
        if not dataType or not dataType.supportTarget then
            return false
        end
        
        local keyUpper = dataType.id:gsub("^%l", string.upper)
        local baseValue = self.config["base" .. keyUpper]
        local targetValue = self.config["target" .. keyUpper]
        
        if baseValue <= 0 or targetValue <= 0 then
            return false
        end
        
        local currentValue = self:fetchValue(dataType)
        if not currentValue then
            return false
        end
        
        if currentValue == self.config["lastSaved" .. keyUpper] then
            return false
        end
        
        local valueDifference = currentValue - self.config["lastSaved" .. keyUpper]
        local configChanged = false
        
        PlutoX.debug("[DEBUG] adjustTargetValue: " .. dataType.id .. ", lastSaved=" .. self.config["lastSaved" .. keyUpper] .. ", current=" .. currentValue .. ", diff=" .. valueDifference)
        
        -- 只在值减少时调整
        if valueDifference < 0 then
            local newTargetValue = targetValue + valueDifference
            
            if newTargetValue > currentValue then
                self.config["target" .. keyUpper] = newTargetValue
                if self.UILibrary then
                    self.UILibrary:Notify({
                        Title = "目标值已调整",
                        Text = string.format("检测到%s减少 %s，目标调整至: %s", 
                            dataType.name,
                            dataType.formatFunc(math.abs(valueDifference)),
                            dataType.formatFunc(self.config["target" .. keyUpper])),
                        Duration = 5
                    })
                end
                configChanged = true
            else
                self.config["enable" .. keyUpper .. "Kick"] = false
                self.config["target" .. keyUpper] = 0
                self.config["base" .. keyUpper] = 0
                if self.UILibrary then
                    self.UILibrary:Notify({
                        Title = "目标值已重置",
                        Text = string.format("调整后的%s目标值小于当前值，已禁用目标踢出功能", dataType.name),
                        Duration = 5
                    })
                end
                configChanged = true
            end
        else
            PlutoX.debug("[DEBUG] adjustTargetValue: 值未减少，不调整目标")
        end
        
        -- 更新 lastSaved 值（即使没有变化）
        self.config["lastSaved" .. keyUpper] = currentValue
        
        -- 只在配置变化时保存
        if configChanged and saveConfig then
            PlutoX.debug("[DEBUG] adjustTargetValue: 配置已变化，调用 saveConfig")
            saveConfig()
        else
            PlutoX.debug("[DEBUG] adjustTargetValue: 配置未变化，不保存")
        end
        return true
    end
    
    -- 检查目标是否达成（通用）
    function monitor:checkTargetAchieved(saveConfig, dataTypeId)
        if not dataTypeId then
            -- 检查所有数据类型的目标
            for _, dataType in ipairs(self.dataTypes) do
                if dataType.supportTarget then
                    local achieved = self:checkTargetAchieved(saveConfig, dataType.id)
                    if achieved then
                        return achieved
                    end
                end
            end
            return false
        end
        
        local dataType = PlutoX.getDataType(dataTypeId)
        if not dataType or not dataType.supportTarget then
            return false
        end
        
        local keyUpper = dataType.id:gsub("^%l", string.upper)
        
        if not self.config["enable" .. keyUpper .. "Kick"] then
            return false
        end
        
        local currentValue = self:fetchValue(dataType)
        if not currentValue then
            return false
        end
        
        if currentValue >= self.config["target" .. keyUpper] then
            return {
                dataType = dataType,
                value = currentValue,
                targetValue = self.config["target" .. keyUpper],
                baseValue = self.config["base" .. keyUpper]
            }
        end
        
        return false
    end
    
    -- 获取通知间隔（秒）
    function monitor:getNotificationIntervalSeconds()
        return (self.config.notificationInterval or 5) * 60
    end
    
    -- 创建数据类型开关 UI
    function monitor:createToggleUI(parent, dataType, saveConfig)
        local keyUpper = dataType.id:gsub("^%l", string.upper)
        local card = UILibrary:CreateCard(parent)
        
        UILibrary:CreateToggle(card, {
            Text = string.format("监测%s (%s)", dataType.name, dataType.icon),
            DefaultState = self.config["notify" .. keyUpper] or false,
            Callback = function(state)
                if state and self.config.webhookUrl == "" then
                    UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
                    self.config["notify" .. keyUpper] = false
                    return
                end
                self.config["notify" .. keyUpper] = state
                UILibrary:Notify({ 
                    Title = "配置更新", 
                    Text = string.format("%s监测: %s", dataType.name, state and "开启" or "关闭"), 
                    Duration = 5 
                })
                if saveConfig then saveConfig() end
            end
        })
        
        return card
    end
    
    -- 创建数据类型显示标签 UI
    function monitor:createDisplayLabel(parent, dataType)
        local card = UILibrary:CreateCard(parent)
        local keyUpper = dataType.id:gsub("^%l", string.upper)
        
        local label = UILibrary:CreateLabel(card, {
            Text = string.format("%s增加: 0", dataType.name),
        })
        
        -- 更新标签的函数
        local function updateLabel()
            local current = self:fetchValue(dataType)
            if current ~= nil then
                local totalEarned = self:calculateTotalEarned(dataType, current)
                label.Text = string.format("%s增加: %s%s", 
                    dataType.name, 
                    (totalEarned >= 0 and "+" or ""), 
                    dataType.formatFunc(totalEarned))
            end
        end
        
        return card, label, updateLabel
    end
    
    return monitor
end

-- 掉线检测

function PlutoX.createDisconnectDetector(UILibrary, webhookManager)
    local detector = {}
    
    detector.disconnected = false
    detector.notified = false  -- 标记是否已发送通知
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
    function detector:checkAndNotify(currentValue)
        if self.disconnected and not self.notified and self.webhookManager then
            self.notified = true  -- 标记已发送通知
            self.webhookManager:sendDisconnect({ ["cash"] = currentValue })
            if self.UILibrary then
                self.UILibrary:Notify({
                    Title = "掉线检测",
                    Text = "检测到连接异常",
                    Duration = 5
                })
            end
            return true
        end
        return false
    end
    
    -- 重置状态
    function detector:reset()
        self.disconnected = false
        self.notified = false
    end
    
    return detector
end

-- UI 组件创建辅助函数

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
            
            -- 检查值是否与当前配置相同，避免重复处理
            if text == config.webhookUrl then
                return
            end
            
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
    
    return card
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
            
            -- 检查值是否与当前配置相同，避免重复处理
            if num and num == config.notificationInterval then
                return
            end
            
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
    
    return card
end

-- 创建数据类型分隔标签
function PlutoX.createDataTypeSectionLabel(parent, UILibrary, dataType)
    local card = UILibrary:CreateCard(parent)
    UILibrary:CreateLabel(card, {
        Text = string.format("%s %s目标设置", dataType.icon, dataType.name),
    })
    return card
end

-- 创建基准值卡片
function PlutoX.createBaseValueCard(parent, UILibrary, config, saveConfig, fetchValue, keyUpper, icon)
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    local labelText = "基准值设置"
    if icon then
        labelText = icon .. " " .. labelText
    end
    
    UILibrary:CreateLabel(card, {
        Text = labelText,
    })
    
    local targetValueLabel
    local suppressTargetToggleCallback = false
    local targetValueToggle
    local callCount = 0  -- Debug: 追踪调用次数
    
    -- 更新目标值标签的函数
    local function updateTargetLabel()
        if targetValueLabel then
            if config["target" .. keyUpper] > 0 then
                targetValueLabel.Text = "目标值: " .. PlutoX.formatNumber(config["target" .. keyUpper])
            else
                targetValueLabel.Text = "目标值: 未设置"
            end
        end
    end
    
    local baseValueInput = UILibrary:CreateTextBox(card, {
        PlaceholderText = "输入基准值",
        OnFocusLost = function(text)
            callCount = callCount + 1
            PlutoX.debug("OnFocusLost 调用 #" .. callCount .. ", keyUpper: " .. keyUpper .. ", text: " .. tostring(text))
            PlutoX.debug("当前 config.base" .. keyUpper .. ": " .. tostring(config["base" .. keyUpper]))
            
            text = text and text:match("^%s*(.-)%s*$")
            
            if not text or text == "" then
                PlutoX.debug("清除基准值")
                config["base" .. keyUpper] = 0
                config["target" .. keyUpper] = 0
                config["lastSaved" .. keyUpper] = 0
                baseValueInput.Text = ""
                updateTargetLabel()
                if saveConfig then saveConfig() end
                UILibrary:Notify({
                    Title = "基准值已清除",
                    Text = "基准值和目标值已重置",
                    Duration = 5
                })
                return
            end

            local cleanText = text:gsub(",", "")
            local num = tonumber(cleanText)
            
            PlutoX.debug("处理输入值: " .. tostring(num))
            
            if num and num > 0 then
                -- 检查值是否与当前配置相同，避免重复处理
                if num == config["base" .. keyUpper] then
                    PlutoX.debug("值与当前配置相同，跳过处理")
                    return
                end
                
                PlutoX.debug("值不同，继续处理")
                local currentValue = fetchValue() or 0
                local newTarget = num + currentValue
                
                PlutoX.debug("当前值: " .. currentValue .. ", 新目标: " .. newTarget)
                
                config["base" .. keyUpper] = num
                config["target" .. keyUpper] = newTarget
                config["lastSaved" .. keyUpper] = currentValue
                
                baseValueInput.Text = PlutoX.formatNumber(num)
                updateTargetLabel()
                
                -- 如果当前值已达目标，关闭踢出功能
                if config["enable" .. keyUpper .. "Kick"] and currentValue >= newTarget then
                    suppressTargetToggleCallback = true
                    if targetValueToggle then
                        targetValueToggle:Set(false)
                    end
                    config["enable" .. keyUpper .. "Kick"] = false
                end
                
                PlutoX.debug("调用 saveConfig")
                if saveConfig then saveConfig() end
                
                UILibrary:Notify({
                    Title = "基准值已设置",
                    Text = string.format("基准: %s\n当前: %s\n目标: %s\n\n后续只在值减少时调整", 
                        PlutoX.formatNumber(num), 
                        PlutoX.formatNumber(currentValue),
                        PlutoX.formatNumber(newTarget)),
                    Duration = 8
                })
                
                if config["enable" .. keyUpper .. "Kick"] and currentValue >= newTarget then
                    UILibrary:Notify({
                        Title = "自动关闭",
                        Text = "当前值已达目标，踢出功能已关闭",
                        Duration = 6
                    })
                end
            else
                baseValueInput.Text = config["base" .. keyUpper] > 0 and PlutoX.formatNumber(config["base" .. keyUpper]) or ""
                UILibrary:Notify({
                    Title = "配置错误",
                    Text = "请输入有效的正整数",
                    Duration = 5
                })
            end
        end
    })

    if config["base" .. keyUpper] > 0 then
        baseValueInput.Text = PlutoX.formatNumber(config["base" .. keyUpper])
    else
        baseValueInput.Text = ""
    end
    
    return card, baseValueInput, function(label) 
        PlutoX.debug("setTargetValueLabel 被调用")
        targetValueLabel = label
        updateTargetLabel()  -- 设置标签后立即更新
    end, function() return targetValueToggle end, function(setLabel) 
        PlutoX.debug("setLabelCallback 被调用")
        if setLabel then 
            setLabel(targetValueLabel)
            updateTargetLabel()  -- 设置回调后立即更新
        end 
    end
end

-- 创建目标值卡片
function PlutoX.createTargetValueCard(parent, UILibrary, config, saveConfig, fetchValue, keyUpper)
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    local suppressTargetToggleCallback = false
    local targetValueToggle = UILibrary:CreateToggle(card, {
        Text = "目标值踢出",
        DefaultState = config["enable" .. keyUpper .. "Kick"] or false,
        Callback = function(state)
            if suppressTargetToggleCallback then
                suppressTargetToggleCallback = false
                return
            end
            
            -- 检查状态是否与当前配置相同，避免重复处理
            if state == config["enable" .. keyUpper .. "Kick"] then
                return
            end
            
            if state and config.webhookUrl == "" then
                targetValueToggle:Set(false)
                UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
                return
            end
            
            if state and (not config["target" .. keyUpper] or config["target" .. keyUpper] <= 0) then
                targetValueToggle:Set(false)
                UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准值", Duration = 5 })
                return
            end
            
            local currentValue = fetchValue()
            if state and currentValue and currentValue >= config["target" .. keyUpper] then
                targetValueToggle:Set(false)
                UILibrary:Notify({
                    Title = "配置警告",
                    Text = string.format("当前值(%s)已超过目标(%s)",
                        PlutoX.formatNumber(currentValue),
                        PlutoX.formatNumber(config["target" .. keyUpper])),
                    Duration = 6
                })
                return
            end
            
            config["enable" .. keyUpper .. "Kick"] = state
            UILibrary:Notify({
                Title = "配置更新",
                Text = string.format("目标踢出: %s\n目标: %s",
                    (state and "开启" or "关闭"),
                    config["target" .. keyUpper] > 0 and PlutoX.formatNumber(config["target" .. keyUpper]) or "未设置"),
                Duration = 5
            })
            if saveConfig then saveConfig() end
        end
    })
    
    local targetValueLabel = UILibrary:CreateLabel(card, {
        Text = "目标值: " .. (config["target" .. keyUpper] > 0 and PlutoX.formatNumber(config["target" .. keyUpper]) or "未设置"),
    })
    
    UILibrary:CreateButton(card, {
        Text = "重新计算目标值",
        Callback = function()
            if config["base" .. keyUpper] <= 0 then
                UILibrary:Notify({
                    Title = "配置错误",
                    Text = "请先设置基准值",
                    Duration = 5
                })
                return
            end
            
            local currentValue = fetchValue() or 0
            local newTarget = config["base" .. keyUpper] + currentValue
            
            if newTarget <= currentValue then
                UILibrary:Notify({
                    Title = "计算错误",
                    Text = "目标值不能小于等于当前值",
                    Duration = 6
                })
                return
            end
            
            config["target" .. keyUpper] = newTarget
            config["lastSaved" .. keyUpper] = currentValue
            
            targetValueLabel.Text = "目标值: " .. PlutoX.formatNumber(newTarget)
            
            if saveConfig then saveConfig() end
            
            UILibrary:Notify({
                Title = "目标值已重新计算",
                Text = string.format("基准: %s\n当前: %s\n新目标: %s\n\n后续只在值减少时调整",
                    PlutoX.formatNumber(config["base" .. keyUpper]),
                    PlutoX.formatNumber(currentValue),
                    PlutoX.formatNumber(newTarget)),
                Duration = 8
            })
            
            if config["enable" .. keyUpper .. "Kick"] and currentValue >= newTarget then
                suppressTargetToggleCallback = true
                targetValueToggle:Set(false)
                config["enable" .. keyUpper .. "Kick"] = false
                if saveConfig then saveConfig() end
                UILibrary:Notify({
                    Title = "自动关闭",
                    Text = "当前值已达目标，踢出功能已关闭",
                    Duration = 6
                })
            end
        end
    })
    
    return card, targetValueLabel, function(suppress, toggle) suppressTargetToggleCallback = suppress; targetValueToggle = toggle end, function(setLabel) if setLabel then setLabel(targetValueLabel) end end
end

-- 创建目标值卡片（简化版，不带重新计算按钮）
function PlutoX.createTargetValueCardSimple(parent, UILibrary, config, saveConfig, fetchValue, keyUpper)
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    local suppressTargetToggleCallback = false
    local targetValueToggle = UILibrary:CreateToggle(card, {
        Text = "目标值踢出",
        DefaultState = config["enable" .. keyUpper .. "Kick"] or false,
        Callback = function(state)
            if suppressTargetToggleCallback then
                suppressTargetToggleCallback = false
                return
            end
            
            -- 检查状态是否与当前配置相同，避免重复处理
            if state == config["enable" .. keyUpper .. "Kick"] then
                return
            end
            
            if state and config.webhookUrl == "" then
                targetValueToggle:Set(false)
                UILibrary:Notify({ Title = "Webhook 错误", Text = "请先设置 Webhook 地址", Duration = 5 })
                return
            end
            
            if state and (not config["target" .. keyUpper] or config["target" .. keyUpper] <= 0) then
                targetValueToggle:Set(false)
                UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准值", Duration = 5 })
                return
            end
            
            local currentValue = fetchValue()
            if state and currentValue and currentValue >= config["target" .. keyUpper] then
                targetValueToggle:Set(false)
                UILibrary:Notify({
                    Title = "配置警告",
                    Text = string.format("当前值(%s)已超过目标(%s)",
                        PlutoX.formatNumber(currentValue),
                        PlutoX.formatNumber(config["target" .. keyUpper])),
                    Duration = 6
                })
                return
            end
            
            config["enable" .. keyUpper .. "Kick"] = state
            UILibrary:Notify({
                Title = "配置更新",
                Text = string.format("目标踢出: %s\n目标: %s",
                    (state and "开启" or "关闭"),
                    config["target" .. keyUpper] > 0 and PlutoX.formatNumber(config["target" .. keyUpper]) or "未设置"),
                Duration = 5
            })
            if saveConfig then saveConfig() end
        end
    })
    
    local targetValueLabel = UILibrary:CreateLabel(card, {
        Text = "目标值: " .. (config["target" .. keyUpper] > 0 and PlutoX.formatNumber(config["target" .. keyUpper]) or "未设置"),
    })
    
    return card, targetValueLabel, function(suppress, toggle) suppressTargetToggleCallback = suppress; targetValueToggle = toggle end
end

-- 重新计算所有数据类型的目标值
function PlutoX.recalculateAllTargetValues(config, UILibrary, dataMonitor, dataTypes, saveConfig, getTargetValueLabels)
    local successCount = 0
    local failCount = 0
    local results = {}
    
    for _, dataType in ipairs(dataTypes) do
        if dataType.supportTarget then
            local keyUpper = dataType.id:gsub("^%l", string.upper)
            
            if config["base" .. keyUpper] > 0 then
                local currentValue = dataMonitor:fetchValue(dataType) or 0
                local newTarget = config["base" .. keyUpper] + currentValue
                
                if newTarget > currentValue then
                    config["target" .. keyUpper] = newTarget
                    config["lastSaved" .. keyUpper] = currentValue
                    
                    -- 更新标签显示
                    if getTargetValueLabels and getTargetValueLabels[dataType.id] then
                        getTargetValueLabels[dataType.id].Text = "目标值: " .. PlutoX.formatNumber(newTarget)
                    end
                    
                    successCount = successCount + 1
                    table.insert(results, string.format("%s: %s", dataType.name, PlutoX.formatNumber(newTarget)))
                    
                    -- 如果已达到新目标，关闭踢出功能
                    if config["enable" .. keyUpper .. "Kick"] and currentValue >= newTarget then
                        config["enable" .. keyUpper .. "Kick"] = false
                    end
                else
                    failCount = failCount + 1
                    table.insert(results, string.format("%s: 计算失败（目标值不能小于等于当前值）", dataType.name))
                end
            else
                failCount = failCount + 1
                table.insert(results, string.format("%s: 未设置基准值", dataType.name))
            end
        end
    end
    
    if saveConfig then saveConfig() end
    
    -- 显示结果通知
    if successCount > 0 then
        local resultText = string.format("成功: %d, 失败: %d\n\n", successCount, failCount)
        resultText = resultText .. table.concat(results, "\n")
        
        UILibrary:Notify({
            Title = "目标值已重新计算",
            Text = resultText,
            Duration = 10 + successCount
        })
    else
        UILibrary:Notify({
            Title = "计算失败",
            Text = "没有成功计算任何目标值，请检查基准值设置",
            Duration = 6
        })
    end
end

-- 创建关于页面
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

-- 导出

return PlutoX