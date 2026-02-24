
-- PlutoX-Notifier

local PlutoX = {}

-- Debug
PlutoX.debugEnabled = true
PlutoX.logFile = nil
PlutoX.currentLogFile = nil
PlutoX.originalPrint = nil
PlutoX.gameName = nil
PlutoX.username = nil
PlutoX.isInitialized = false

-- 数据上传
PlutoX.uploaderConfig = nil
PlutoX.uploaderHttpService = nil
PlutoX.uploaderDataMonitor = nil
PlutoX.uploader = nil  -- 全局上传器引用

-- 设置游戏信息
function PlutoX.setGameInfo(gameName, username, HttpService)
    PlutoX.gameName = gameName
    PlutoX.username = username
    if HttpService then
        PlutoX.uploaderHttpService = HttpService
    end

    -- 自动初始化调试系统（如果调试模式开启）
    if PlutoX.debugEnabled and not PlutoX.isInitialized then
        PlutoX.initDebugSystem()
    end
end

-- 日志路径
function PlutoX.getLogFilePath()
    local dateStr = os.date("%Y-%m-%d")
    local timeStr = os.date("%H-%M-%S")
    -- 过滤掉emoji和特殊字符，只保留字母、数字、下划线和连字符
    local safeGameName = (PlutoX.gameName or "Unknown"):gsub("[^%w%-_]", "_")
    local safeUsername = (PlutoX.username or "Unknown"):gsub("[^%w%-_]", "_")
    return string.format("PlutoX/debuglog/%s_%s_%s_%s.log", 
        safeGameName, 
        safeUsername, 
        dateStr,
        timeStr)
end

-- 初始化日志
function PlutoX.initDebugSystem()
    if not PlutoX.debugEnabled or PlutoX.isInitialized then
        return
    end
    
    -- 创建 debuglog 文件夹
    if not isfolder("PlutoX") then
        makefolder("PlutoX")
    end
    if not isfolder("PlutoX/debuglog") then
        makefolder("PlutoX/debuglog")
    end
    
    -- 关闭旧文件
    if PlutoX.logFile then
        pcall(function()
            PlutoX.logFile:close()
        end)
        PlutoX.logFile = nil
    end
    
    -- 获取日志文件路径（每次使用新的时间戳）
    local logPath = PlutoX.getLogFilePath()
    PlutoX.currentLogFile = logPath
    
    -- 创建新日志文件
    local success, err = pcall(function()
        local header = string.format("========== 日志开始 [%s] ==========\n", os.date("%Y-%m-%d %H:%M:%S"))
        header = header .. string.format("游戏: %s\n", PlutoX.gameName or "Unknown")
        header = header .. string.format("用户: %s\n", PlutoX.username or "Unknown")
        header = header .. "==========================================\n\n"
        writefile(logPath, header)
    end)
    
    if success then
        PlutoX.isInitialized = true
    else
        warn("[PlutoX-Log] 无法创建日志文件: " .. tostring(err))
        PlutoX.currentLogFile = nil
    end
    
    -- 保存原始 print 和 warn 函数
    if not PlutoX.originalPrint then
        PlutoX.originalPrint = print
        PlutoX.originalWarn = warn
        
        -- 重写 print 函数，将所有输出写入日志
        print = function(...)
            -- 调用原始 print 输出到控制台
            PlutoX.originalPrint(...)
            
            -- 写入日志文件
            if PlutoX.currentLogFile then
                local args = {...}
                local formatted = {}
                for i, arg in ipairs(args) do
                    if type(arg) == "table" then
                        formatted[i] = "{...}"
                    else
                        formatted[i] = tostring(arg)
                    end
                end
                local logMessage = string.format("[%s] %s\n", os.date("%H:%M:%S"), table.concat(formatted, " "))
                PlutoX.writeLog(logMessage)
            end
        end
        
        -- 重写 warn 函数，将警告和错误写入日志
        warn = function(...)
            -- 调用原始 warn 输出到控制台
            PlutoX.originalWarn(...)
            
            -- 写入日志文件
            if PlutoX.currentLogFile then
                local args = {...}
                local formatted = {}
                for i, arg in ipairs(args) do
                    if type(arg) == "table" then
                        formatted[i] = "{...}"
                    else
                        formatted[i] = tostring(arg)
                    end
                end
                local logMessage = string.format("[%s] [WARNING] %s\n", os.date("%H:%M:%S"), table.concat(formatted, " "))
                PlutoX.writeLog(logMessage)
            end
        end
    end
    
    -- 使用 LogService 捕获所有输出
    local LogService = game:GetService("LogService")
    if LogService then
        LogService.MessageOut:Connect(function(message, messageType)
            if not PlutoX.currentLogFile then
                return
            end
            
            local messageTypeStr = "INFO"
            if messageType == Enum.MessageType.MessageWarning then
                messageTypeStr = "WARNING"
            elseif messageType == Enum.MessageType.MessageError then
                messageTypeStr = "ERROR"
            elseif messageType == Enum.MessageType.MessageInfo then
                messageTypeStr = "INFO"
            elseif messageType == Enum.MessageType.MessageOutput then
                messageTypeStr = "OUTPUT"
            end
            
            local logMessage = string.format("[%s] [%s] %s\n", os.date("%H:%M:%S"), messageTypeStr, tostring(message))
            PlutoX.writeLog(logMessage)
        end)
    end
end

-- 写日志
function PlutoX.writeLog(message)
    if not PlutoX.debugEnabled then
        return
    end
    
    -- 使用 Roblox 的 writefile API
    if not PlutoX.currentLogFile then
        return
    end
    
    local success, err = pcall(function()
        -- 读取现有内容并追加
        local existingContent = ""
        if isfile(PlutoX.currentLogFile) then
            existingContent = readfile(PlutoX.currentLogFile)
        end
        writefile(PlutoX.currentLogFile, existingContent .. message)
    end)
    
    if not success then
        warn("[PlutoX-Log] 写入日志失败: " .. tostring(err))
    end
end

function PlutoX.debug(...)
    if not PlutoX.debugEnabled then
        return
    end

    local timestamp = os.date("%H:%M:%S")
    local info = debug.getinfo(2, "Sl")
    local source = info and info.short_src or "unknown"
    local line = info and info.currentline or 0

    -- 格式化输出
    local args = {...}
    local formatted = {}
    for i, arg in ipairs(args) do
        if type(arg) == "table" then
            formatted[i] = "{...}" -- 简化表格输出
        else
            formatted[i] = tostring(arg)
        end
    end

    local logMessage = string.format("[%s][DEBUG][%s:%d] %s\n", timestamp, source, line, table.concat(formatted, " "))

    -- 输出到控制台（通过重写的 print 函数）
    print(logMessage:gsub("\n$", ""))
end

-- 警告输出
function PlutoX.warn(...)
    local timestamp = os.date("%H:%M:%S")
    local info = debug.getinfo(2, "Sl")
    local source = info and info.short_src or "unknown"
    local line = info and info.currentline or 0

    -- 格式化输出
    local args = {...}
    local formatted = {}
    for i, arg in ipairs(args) do
        if type(arg) == "table" then
            formatted[i] = "{...}"
        else
            formatted[i] = tostring(arg)
        end
    end

    local logMessage = string.format("[%s][WARNING][%s:%d] %s\n", timestamp, source, line, table.concat(formatted, " "))

    -- 输出到控制台（通过重写的 print 函数）
    print(logMessage:gsub("\n$", ""))
end

-- Webhook Footer
PlutoX.footerText = "桐 · TStudioX"

-- 脚本实例管理
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

-- 工具

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

-- 格式化时长
function PlutoX.formatElapsedTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d小时%02d分%02d秒", hours, minutes, secs)
end

-- 数据类型注册

PlutoX.dataTypes = {}

-- 注册数据类型 (id, name, icon, fetchFunc, supportTarget等)
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

-- 获取数据类型
function PlutoX.getDataType(id)
    return PlutoX.dataTypes[id]
end

-- 获取所有数据类型
function PlutoX.getAllDataTypes()
    local types = {}
    for id, typeDef in pairs(PlutoX.dataTypes) do
        table.insert(types, typeDef)
    end
    return types
end

-- 生成数据类型配置
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
        -- 脚本启动时的初始值（用于计算本次运行的总收益）
        configs["sessionStart" .. keyUpper] = 0
        
        -- 如果支持目标检测，生成目标相关配置
        if dataType.supportTarget then
            configs["target" .. keyUpper] = 0
            configs["enable" .. keyUpper .. "Kick"] = false
            configs["base" .. keyUpper] = 0
            configs["lastSaved" .. keyUpper] = 0
            configs["targetStart" .. keyUpper] = 0  -- 目标设置时的金额
        end
    end
    return configs
end

-- 配置

function PlutoX.createConfigManager(configFile, HttpService, UILibrary, username, defaultConfig)
    local manager = {}
    
    manager.defaultConfig = defaultConfig or {}
    manager.config = {}
    manager.configFile = configFile
    manager.HttpService = HttpService
    manager.UILibrary = UILibrary
    manager.username = username
    
    -- 旧配置项到新配置项的映射（根据数据类型动态生成）
    local function getMigrationMap()
        local map = {}
        local dataTypes = PlutoX.getAllDataTypes()
        
        for _, dataType in ipairs(dataTypes) do
            local id = dataType.id
            local keyUpper = id:gsub("^%l", string.upper)
            
            -- 旧格式可能使用的通用名称映射到具体数据类型
            -- 例如：enableTargetKick -> enableCashKick（如果数据类型是 cash）
            -- 或者：enableTargetKick -> enableWinsKick（如果数据类型是 wins）
            
            -- 对于支持目标检测的数据类型，添加通用配置项的映射
            if dataType.supportTarget then
                map["enableTargetKick"] = "enable" .. keyUpper .. "Kick"
                map["targetAmount"] = "target" .. keyUpper
                map["baseAmount"] = "base" .. keyUpper
                map["lastNotifyCurrency"] = "lastNotify" .. keyUpper
                map["lastSavedCurrency"] = "lastSaved" .. keyUpper
                map["totalEarningsBase"] = "total" .. keyUpper .. "Base"
            end
        end
        
        return map
    end
    
    -- 迁移旧配置项
    local function migrateConfig(userConfig)
        local dataTypes = PlutoX.getAllDataTypes()
        local migrated = false
        
        -- 找到主要的数据类型（优先使用 cash）
        local primaryDataType = nil
        for _, dataType in ipairs(dataTypes) do
            if dataType.id == "cash" then
                primaryDataType = dataType
                break
            end
        end
        
        -- 如果没有 cash，使用第一个支持目标检测的数据类型
        if not primaryDataType then
            for _, dataType in ipairs(dataTypes) do
                if dataType.supportTarget then
                    primaryDataType = dataType
                    break
                end
            end
        end
        
        -- 如果找到了主要数据类型，进行迁移
        if primaryDataType then
            local id = primaryDataType.id
            local keyUpper = id:gsub("^%l", string.upper)
            
            -- 旧格式配置项映射
            local oldToNewMap = {
                ["enableTargetKick"] = "enable" .. keyUpper .. "Kick",
                ["targetAmount"] = "target" .. keyUpper,
                ["baseAmount"] = "base" .. keyUpper,
                ["lastNotifyCurrency"] = "lastNotify" .. keyUpper,
                ["lastSavedCurrency"] = "lastSaved" .. keyUpper,
                ["totalEarningsBase"] = "total" .. keyUpper .. "Base"
            }
            
            for oldKey, newKey in pairs(oldToNewMap) do
                if userConfig[oldKey] ~= nil and userConfig[newKey] == nil then
                    userConfig[newKey] = userConfig[oldKey]
                    userConfig[oldKey] = nil
                    migrated = true
                    PlutoX.debug("[Config] 迁移配置项: " .. oldKey .. " -> " .. newKey)
                end
            end
        end
        
        local leaderboardOldKeys = {
            "targetLeaderboard",
            "baseLeaderboard",
            "lastSavedLeaderboard",
            "enableLeaderboardKick"
        }
        
        for _, oldKey in ipairs(leaderboardOldKeys) do
            if userConfig[oldKey] ~= nil then
                userConfig[oldKey] = nil
                migrated = true
                PlutoX.debug("[Config] 删除不再需要的配置项: " .. oldKey)
            end
        end
        
        return migrated
    end
    
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

        -- 配置迁移：检查旧配置文件并迁移到新位置
        local oldConfigFiles = {
            "Pluto_X_APS_config.json",
            "Pluto_X_DW_config.json",
            "Pluto_X_DE_config.json",
            "Pluto_X_GV_config.json",
            "Pluto_X_MC_config.json",
            "Pluto_X_RT2_config.json",
            "Pluto_X_TC_config.json",
            "Pluto_X_VL_config.json"
        }
        
        -- 旧配置到新配置的映射
        local oldToNewConfig = {
            ["Pluto_X_APS_config.json"] = "PlutoX/Autopilot_Simulator_config.json",
            ["Pluto_X_DW_config.json"] = "PlutoX/Drive_World_config.json",
            ["Pluto_X_DE_config.json"] = "PlutoX/Driving_Empire_config.json",
            ["Pluto_X_GV_config.json"] = "PlutoX/Greenville_config.json",
            ["Pluto_X_MC_config.json"] = "PlutoX/Midnight_Chasers_config.json",
            ["Pluto_X_RT2_config.json"] = "PlutoX/Retail_Tycoon_2_config.json",
            ["Pluto_X_TC_config.json"] = "PlutoX/Tang_Country_config.json",
            ["Pluto_X_VL_config.json"] = "PlutoX/Vehicle_Legends_config.json"
        }
        
        -- 检查是否有旧配置文件需要迁移
        for _, oldFile in ipairs(oldConfigFiles) do
            if isfile(oldFile) then
                PlutoX.debug("[Config] 发现旧配置文件: " .. oldFile)
                
                -- 读取旧配置
                local ok, content = pcall(function()
                    return self.HttpService:JSONDecode(readfile(oldFile))
                end)
                
                if ok and type(content) == "table" then
                    -- 迁移所有用户的配置
                    local userCount = 0
                    for username, oldUserConfig in pairs(content) do
                        if type(oldUserConfig) == "table" then
                            userCount = userCount + 1
                            PlutoX.debug("[Config] 迁移用户配置: " .. username)
                            
                            -- 获取对应的新配置文件路径
                            local newConfigFile = oldToNewConfig[oldFile]
                            if not newConfigFile then
                                PlutoX.debug("[Config] 警告: 未找到映射，使用默认路径")
                                newConfigFile = "PlutoX/" .. oldFile:gsub("Pluto_X_", ""):gsub("_config.json", "_config.json")
                            end
                            
                            -- 创建新配置文件夹
                            if not isfolder("PlutoX") then
                                makefolder("PlutoX")
                            end
                            
                            -- 读取或创建新配置文件
                            local allConfigs = {}
                            if isfile(newConfigFile) then
                                local ok2, newContent = pcall(function()
                                    return self.HttpService:JSONDecode(readfile(newConfigFile))
                                end)
                                if ok2 and type(newContent) == "table" then
                                    allConfigs = newContent
                                end
                            end
                            
                            -- 添加迁移的配置
                            allConfigs[username] = oldUserConfig
                            
                            -- 写入新配置文件
                            writefile(newConfigFile, self.HttpService:JSONEncode(allConfigs))
                        end
                    end
                    
                    if userCount > 0 then
                        PlutoX.debug("[Config] 配置迁移完成，共迁移 " .. userCount .. " 个用户配置")
                        
                        -- 删除已迁移的旧配置文件
                        pcall(function()
                            delfile(oldFile)
                            PlutoX.debug("[Config] 已删除旧配置文件: " .. oldFile)
                        end)
                        
                        if self.UILibrary then
                            self.UILibrary:Notify({
                                Title = "配置迁移",
                                Text = string.format("已迁移 %d 个用户配置到新位置", userCount),
                                Duration = 5
                            })
                        end
                    end
                end
            end
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
                -- 迁移旧配置项
                local migrated = migrateConfig(userConfig)
                
                if migrated then
                    -- 如果有迁移，保存新格式
                    result[self.username] = userConfig
                    writefile(self.configFile, self.HttpService:JSONEncode(result))
                    PlutoX.debug("[Config] 配置项已迁移并保存")
                    
                    if self.UILibrary then
                        self.UILibrary:Notify({
                            Title = "配置迁移",
                            Text = "旧配置项已迁移到新格式",
                            Duration = 5,
                        })
                    end
                end
                
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

-- Webhook

function PlutoX.createWebhookManager(config, HttpService, UILibrary, gameName, username, configFile)
    local manager = {}
    
    -- Discord Webhook 代理（解决国内网络问题）
    local function getProxyWebhookUrl(url)
        if not url or url == "" then return url end
        -- 将 discord.com/api/webhooks 转换为代理 URL
        return url:gsub("https://discord%.com/api/webhooks/", "https://api.959966.xyz/discord/webhook/")
    end
    
    manager.config = config
    manager.HttpService = HttpService
    manager.UILibrary = UILibrary
    manager.gameName = gameName
    manager.username = username
    manager.sendingWelcome = false
    manager.configFile = configFile or "PlutoX/" .. gameName .. "_config.json"
    
    -- 保存上传器需要的参数
    PlutoX.uploaderConfig = config
    PlutoX.uploaderHttpService = HttpService
    PlutoX.uploaderUILibrary = UILibrary
    
    -- 保存配置的方法
    function manager:saveConfig()
        PlutoX.debug("[WebhookManager] saveConfig 被调用")
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
        PlutoX.debug("[WebhookManager] 配置已写入文件: " .. self.configFile)
    end
    
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
    
    -- 发送 Webhook（带超时保护）
    function manager:dispatchWebhook(payload)
        -- 检查脚本实例是否仍然有效
        local instanceId = self.gameName .. ":" .. self.username
        if not PlutoX.scriptInstances[instanceId] then
            warn("[Webhook] 脚本实例已失效，停止发送: " .. instanceId)
            
            -- 发送重复运行警告
            local warningPayload = {
                embeds = {{
                    title = "⚠️ 重复运行检测",
                    description = string.format("**游戏**: %s\n**用户**: %s\n\n检测到脚本重复运行，已停止发送通知", self.gameName, self.username),
                    color = 16753920,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = { text = "桐 · TStudioX" }
                }}
            }
            
            -- 尝试发送警告（忽略结果）
            pcall(function()
                local requestFunc = syn and syn.request or http and http.request or request
                if requestFunc and self.config.webhookUrl ~= "" then
                    local bodyJson = self.HttpService:JSONEncode({
                        content = nil,
                        embeds = warningPayload.embeds
                    })
                    requestFunc({
                        Url = getProxyWebhookUrl(self.config.webhookUrl),
                        Method = "POST",
                        Headers = {
                            ["Content-Type"] = "application/json"
                        },
                        Body = bodyJson
                    })
                end
            end)
            
            return false
        end
        
        if self.config.webhookUrl == "" then
            -- 未设置webhook，返回false让调用方处理
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
        
        -- 使用 spawn 异步发送 webhook，避免阻塞
        local success = false
        local completed = false
        
        spawn(function()
            local reqSuccess, res = pcall(function()
                return requestFunc({
                    Url = getProxyWebhookUrl(self.config.webhookUrl),
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = bodyJson
                })
            end)
            
            if reqSuccess then
                if not res then
                    PlutoX.debug("[Webhook] 执行器返回 nil，假定发送成功")
                else
                    local statusCode = res.StatusCode or res.statusCode or 0
                    if statusCode == 204 or statusCode == 200 or statusCode == 0 then
                        PlutoX.debug("[Webhook] 发送成功，状态码: " .. (statusCode == 0 and "未知(假定成功)" or statusCode))
                    else
                        warn("[Webhook 错误] 状态码: " .. tostring(statusCode))
                    end
                end
            else
                warn("[Webhook 请求失败] pcall 错误: " .. tostring(res))
            end
            
            completed = true
        end)
        
        -- 最多等待 3 秒，超时则认为发送失败但不阻塞
        local startTime = tick()
        while not completed and (tick() - startTime) < 3 do
            wait(0.1)
        end
        
        if not completed then
            warn("[Webhook] 发送超时（3秒），继续执行")
            return false
        end
        
        return true
    end
    
    -- 发送欢迎消息（异步执行，避免阻塞主循环）
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

        -- 异步发送欢迎消息
        spawn(function()
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
        end)

        return true
    end
    
    -- 发送目标达成通知（同步执行，确保所有操作完成）
    function manager:sendTargetAchieved(currentValue, targetAmount, baseAmount, runTime, dataTypeName)
        -- 立即设置退出标志，防止重复调用
        if self.exiting then
            PlutoX.debug("[目标达成] 已经在退出流程中，跳过重复调用")
            return false
        end
        self.exiting = true

        -- 记录每个步骤的结果
        local steps = {
            webhook = { name = "Webhook发送", success = false, message = "" },
            upload = { name = "数据上传", success = false, message = "" },
            config = { name = "配置保存", success = false, message = "" }
        }

        -- 步骤1: 发送Webhook
        if self.config.webhookUrl == "" then
            steps.webhook.success = true
            steps.webhook.message = "未设置webhook，跳过发送"
            PlutoX.debug("[目标达成] " .. steps.webhook.message)
        else
            local maxRetries = 3
            local retryDelay = 2
            for attempt = 1, maxRetries do
                local success = self:dispatchWebhook({
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

                if success then
                    steps.webhook.success = true
                    steps.webhook.message = "发送成功（尝试 " .. attempt .. "/" .. maxRetries .. "）"
                    PlutoX.debug("[目标达成] " .. steps.webhook.message)
                    break
                else
                    steps.webhook.message = "发送失败（尝试 " .. attempt .. "/" .. maxRetries .. "）"
                    warn("[目标达成] " .. steps.webhook.message)
                    if attempt < maxRetries then
                        task.wait(retryDelay)
                    end
                end
            end
        end

        -- 步骤2: 上传数据
        if PlutoX.uploader and PlutoX.uploader.forceUpload then
            PlutoX.debug("[目标达成] 开始上传数据...")
            local uploadSuccess = PlutoX.uploader:forceUpload()
            if uploadSuccess then
                steps.upload.success = true
                steps.upload.message = "上传成功"
                PlutoX.debug("[目标达成] " .. steps.upload.message)
            else
                steps.upload.message = "上传失败"
                warn("[目标达成] " .. steps.upload.message)
            end
        else
            steps.upload.success = true
            steps.upload.message = "未设置上传器，跳过上传"
            PlutoX.debug("[目标达成] " .. steps.upload.message)
        end

        -- 步骤3: 保存配置
        if dataTypeName then
            local keyUpper = dataTypeName:gsub("^%l", string.upper)
            local kickConfigKey = "enable" .. keyUpper .. "Kick"

            -- 关闭目标踢出功能
            if self.config[kickConfigKey] then
                self.config[kickConfigKey] = false
                PlutoX.debug("[目标达成] 已关闭" .. dataTypeName .. "的目标踢出功能")
            end

            -- 清除目标
            self.config["target" .. keyUpper] = 0
            self.config["base" .. keyUpper] = 0
            self.config["lastSaved" .. keyUpper] = 0

            -- 保存配置
            local saveSuccess = pcall(function()
                self:saveConfig()
            end)

            if saveSuccess then
                steps.config.success = true
                steps.config.message = "配置已保存并清除目标值"
                PlutoX.debug("[目标达成] " .. steps.config.message)
            else
                steps.config.message = "配置保存失败"
                warn("[目标达成] " .. steps.config.message)
            end
        else
            steps.config.success = true
            steps.config.message = "未指定数据类型，跳过配置保存"
            PlutoX.debug("[目标达成] " .. steps.config.message)
        end

        -- 汇总所有步骤的结果
        local allSuccess = true
        local logMessage = "[目标达成] 操作完成状态：\n"
        for _, step in pairs(steps) do
            local status = step.success and "✓" or "✗"
            logMessage = logMessage .. string.format("  %s %s: %s\n", status, step.name, step.message)
            if not step.success then
                allSuccess = false
            end
        end

        if allSuccess then
            logMessage = logMessage .. "所有操作成功完成，准备退出游戏..."
            PlutoX.debug(logMessage)
        else
            logMessage = logMessage .. "部分操作失败，但仍将退出游戏..."
            warn(logMessage)
        end

        -- 注销脚本实例
        PlutoX.unregisterScriptInstance(self.gameName, self.username)

        -- 强制退出游戏（多重保障）
        task.wait(0.5)

        -- 方法1: 使用 game:Shutdown()
        local shutdownSuccess = pcall(function()
            game:Shutdown()
        end)

        if not shutdownSuccess then
            warn("[目标达成] game:Shutdown() 失败，尝试其他方法...")

            -- 方法2: 踢出玩家
            local localPlayer = game:GetService("Players").LocalPlayer
            if localPlayer then
                pcall(function()
                    localPlayer:Kick("目标达成，自动退出")
                end)
            end

            -- 方法3: 强制关闭
            task.wait(0.5)
            pcall(function()
                while true do
                    task.wait()
                    error("强制退出")
                end
            end)
        end

        return allSuccess
    end
    
    -- 发送掉线通知
    function manager:sendDisconnect(dataTable)
        local dataText = {}
        
        -- 检查是否有数据
        local hasData = false
        for id, value in pairs(dataTable) do
            if value ~= nil then
                hasData = true
                break
            end
        end
        
        if hasData then
            -- 有数据，正常显示
            for id, value in pairs(dataTable) do
                local dataType = PlutoX.getDataType(id)
                if dataType then
                    local actualValue = value
                    local skipValue = false
                    
                    -- 检查value是否是table对象
                    if type(value) == "table" then
                        -- 处理 dataMonitor:collectData 格式: {current: value, ...}
                        if value.current ~= nil then
                            actualValue = value.current
                        -- 处理其他 table 格式（如排行榜详细信息）
                        -- 如果是 table 但没有 current 字段，尝试找到第一个数字值
                        elseif next(value) ~= nil then
                            for k, v in pairs(value) do
                                if type(v) == "number" then
                                    actualValue = v
                                    break
                                end
                            end
                            -- 如果找不到数字值，跳过这个数据
                            if type(actualValue) == "table" then
                                skipValue = true
                            end
                        else
                            skipValue = true
                        end
                    end
                    
                    -- 如果值有效，格式化显示
                    if not skipValue and actualValue ~= nil then
                        table.insert(dataText, string.format("%s: %s", dataType.icon .. dataType.name, dataType.formatFunc(actualValue)))
                    end
                end
            end
        else
            -- 没有数据，显示无法获取
            table.insert(dataText, "无法获取")
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

-- 数据监测

function PlutoX.createDataMonitor(config, UILibrary, webhookManager, dataTypes, disconnectDetector, gameName, username)
    local monitor = {}

    monitor.config = config
    monitor.UILibrary = UILibrary
    monitor.webhookManager = webhookManager
    monitor.dataTypes = dataTypes or PlutoX.getAllDataTypes()
    monitor.disconnectDetector = disconnectDetector

    -- 保存数据上传器需要的参数（独立于 webhook）
    -- 添加更安全的 nil 检查
    local webhookHttpService = nil
    local webhookGameName = nil
    local webhookUsername = nil

    if webhookManager and type(webhookManager) == "table" then
        webhookHttpService = webhookManager.HttpService
        webhookGameName = webhookManager.gameName
        webhookUsername = webhookManager.username
    end

    monitor.HttpService = PlutoX.uploaderHttpService or webhookHttpService
    -- 优先使用传入的参数，然后是全局变量，最后是 webhook 中的值
    monitor.gameName = gameName or PlutoX.gameName or webhookGameName or "未知游戏"
    monitor.username = username or PlutoX.username or webhookUsername
    
    -- 内部状态
    monitor.lastSendTime = os.time()
    monitor.startTime = os.time()
    monitor.unchangedCount = 0
    monitor.webhookDisabled = false
    monitor.lastValues = {}
    monitor.sessionStartValues = {}
    monitor.checkInterval = 1
    monitor.beforeSendCallback = nil -- 发送前的回调函数
    
    -- 保存上传器引用
    PlutoX.uploaderDataMonitor = monitor
    
    -- 初始化所有数据类型
    function monitor:init()
        local initInfo = {}
        warn("[DataMonitor] 开始初始化数据类型...")
        for _, dataType in ipairs(self.dataTypes) do
            if dataType.fetchFunc then
                local success, value = pcall(dataType.fetchFunc)
                warn("[DataMonitor] fetchFunc " .. dataType.id .. ": success=" .. tostring(success) .. ", value=" .. tostring(value))
                if success and value then
                    local keyUpper = dataType.id:gsub("^%l", string.upper)
                    -- 只有数值类型才设置基准值，避免存储字符串导致比较错误
                    if type(value) == "number" then
                        self.config["total" .. keyUpper .. "Base"] = value
                        self.config["lastNotify" .. keyUpper] = value
                        self.lastValues[dataType.id] = value
                        warn("[DataMonitor] 设置 " .. keyUpper .. "Base=" .. tostring(value))
                        table.insert(initInfo, string.format("%s: %s", dataType.icon .. dataType.name, dataType.formatFunc(value)))
                    else
                        -- 非数值类型（如排行榜的"未上榜"），设置默认值0
                        self.config["total" .. keyUpper .. "Base"] = 0
                        self.config["lastNotify" .. keyUpper] = 0
                        self.lastValues[dataType.id] = value
                        warn("[DataMonitor] " .. dataType.id .. " 返回非数值类型，设置默认值0，当前值: " .. tostring(value))
                        table.insert(initInfo, string.format("%s: %s", dataType.icon .. dataType.name, dataType.formatFunc(value)))
                    end
                else
                    warn("[DataMonitor] fetchFunc " .. dataType.id .. " 失败: " .. tostring(value))
                end
            end
        end
        warn("[DataMonitor] 初始化完成，初始化信息: " .. table.concat(initInfo, " | "))
        
        -- 启动时检查目标踢出功能
        for _, dataType in ipairs(self.dataTypes) do
            if dataType.supportTarget then
                local keyUpper = dataType.id:gsub("^%l", string.upper)
                local kickConfigKey = "enable" .. keyUpper .. "Kick"
                
                -- 从配置文件加载脚本启动时的初始值
                local sessionStartValue = self.config["sessionStart" .. keyUpper] or 0
                if sessionStartValue > 0 then
                    self.sessionStartValues[dataType.id] = sessionStartValue
                    PlutoX.debug("[启动检查] 从配置加载 " .. dataType.name .. " 初始值: " .. tostring(sessionStartValue))
                    
                    -- 初始化 lastSaved 值为 sessionStart，以便启动时可以检测减少
                    self.config["lastSaved" .. keyUpper] = sessionStartValue
                end
                
                -- 启动时调整目标值（检测金额减少并相应调整）
                if self.config["target" .. keyUpper] and self.config["target" .. keyUpper] > 0 then
                    self:adjustTargetValue(function() end, dataType.id)
                end
                
                -- 检查是否开启了目标踢出功能
                if self.config[kickConfigKey] then
                    local currentValue = self:fetchValue(dataType)
                    local targetValue = self.config["target" .. keyUpper]
                    
                    -- 如果当前值已达到或超过目标值，关闭踢出功能
                    if currentValue and targetValue and currentValue >= targetValue then
                        self.config[kickConfigKey] = false
                        PlutoX.debug("[启动检查] " .. dataType.name .. "当前值(" .. PlutoX.formatNumber(currentValue) .. ")已达到目标(" .. PlutoX.formatNumber(targetValue) .. ")，已关闭踢出功能")
                    end
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
            else
            end
        end
        return nil
    end
    
    -- 计算总变化量
    function monitor:calculateTotalEarned(dataType, currentValue)
        if not currentValue then return 0 end
        
        local keyUpper = dataType.id:gsub("^%l", string.upper)
        local baseValue = self.config["total" .. keyUpper .. "Base"] or 0
        
        
        -- 只对数值类型进行计算
        if type(baseValue) ~= "number" or type(currentValue) ~= "number" then
            return 0
        end
        
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
        
        -- 确保 currentValue 是数值类型
        if type(currentValue) ~= "number" then
            return 0
        end
        
        -- 确保 lastNotifyValue 是数值类型后再比较
        if type(lastNotifyValue) == "number" and lastNotifyValue > 0 then
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
        for idx, dataType in ipairs(self.dataTypes) do
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
    
    -- 发送多数据变化通知（接收已收集的数据，避免重复获取）
    function monitor:sendDataChange(currentTime, interval, data)
        -- 如果没有传入数据，则收集数据（保持向后兼容）
        if not data then
            data = self:collectData()
        end
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
            
            -- 跳过排行榜数据类型的完整通知（简单排名信息通过 beforeSendCallback 添加）
            if dataType.id == "leaderboard" then
                continue
            end
            
            if self.config["notify" .. keyUpper] and dataInfo.current ~= nil then
                -- 计算平均速度（时间加权平均：总变化量/总时间）
                local avg = "0"
                if dataType.calculateAvg and elapsedTime > 0 and dataInfo.totalEarned ~= 0 then
                    local rawAvg = dataInfo.totalEarned / (elapsedTime / 3600)
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
                                local countdownT = string.format("<t:%d:f>", completionTimestamp)
                                
                                if days > 0 then
                                    estimatedTimeText = string.format("\n**预计完成**: %d天%d小时%d分钟\n**完成时间**: %s", days, hours, minutes, countdownT)
                                elseif hours > 0 or minutes > 0 then
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
        
        -- 调用发送前回调，允许修改 embed
        if self.beforeSendCallback then
            local success, modifiedEmbed = pcall(self.beforeSendCallback, embed)
            if success and modifiedEmbed then
                embed = modifiedEmbed
            end
        end
        
        return self.webhookManager:dispatchWebhook({ embeds = { embed } })
    end
    
    -- 发送掉线通知（接收已收集的数据，避免重复获取）
    function monitor:sendDisconnect(data)
        -- 如果没有传入数据，则收集数据（保持向后兼容）
        if not data then
            data = self:collectData()
        end
        local dataTable = {}
        for id, dataInfo in pairs(data) do
            if dataInfo.current ~= nil then
                dataTable[id] = dataInfo.current
            end
        end
        return self.webhookManager:sendDisconnect(dataTable)
    end
    
    -- 发送数据未变化警告（接收已收集的数据，避免重复获取）
    function monitor:sendNoChange(data)
        -- 如果没有传入数据，则收集数据（保持向后兼容）
        if not data then
            data = self:collectData()
        end
        local dataTable = {}
        for id, dataInfo in pairs(data) do
            -- 跳过排行榜数据
            if dataInfo.type.id ~= "leaderboard" and dataInfo.current ~= nil then
                dataTable[id] = dataInfo.current
            end
        end
        return self.webhookManager:sendNoChange(dataTable)
    end
    
    -- 主检查循环（接收已收集的数据，避免重复获取）
    function monitor:checkAndNotify(saveConfig, disconnectDetector, collectedData)
        -- 检查是否掉线，如果掉线则停止发送通知
        if disconnectDetector and disconnectDetector.shouldStopNotification and disconnectDetector:shouldStopNotification() then
            PlutoX.debug("[checkAndNotify] 检测到掉线，停止发送通知")
            return false
        end
        
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
        
        -- 使用已收集的数据，避免重复获取
        local data = collectedData or self:collectData()
        
        -- 检查是否有任何数据变化
        if not self:hasAnyChange(data) then
            self.unchangedCount = self.unchangedCount + 1
            PlutoX.debug("[checkAndNotify] 数据无变化，unchangedCount:", self.unchangedCount)
        else
            self.unchangedCount = 0
            self.webhookDisabled = false -- 数据有变化时重置禁用标志
            PlutoX.debug("[checkAndNotify] 数据有变化，重置unchangedCount和webhookDisabled")
        end
        
        -- 连续无变化警告（传递已收集的数据，避免重复获取）
        if self.unchangedCount >= 2 then
            PlutoX.debug("[checkAndNotify] 连续2次无变化，发送警告并禁用webhook")
            self:sendNoChange(data)
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
        
        -- 发送数据变化通知（传递已收集的数据，避免重复获取）
        PlutoX.debug("[checkAndNotify] 发送数据变化通知")
        self:sendDataChange(currentTime, interval, data)
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
    
-- 目标值调整
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
        -- 使用 targetStart（设置目标时的金额）作为参考点
        local targetStart = self.config["targetStart" .. keyUpper] or 0
        if targetStart <= 0 then
            targetStart = self.config["lastSaved" .. keyUpper] or currentValue
        end
        
        -- 计算与设置目标时的差异（只有真正减少才调整）
        local valueDifference = currentValue - targetStart
        
        -- 只在值减少时调整
        if valueDifference < 0 then
            local newTargetValue = targetValue + valueDifference
            
            if newTargetValue > currentValue then
                self.config["target" .. keyUpper] = newTargetValue
                self.config["targetStart" .. keyUpper] = currentValue  -- 更新起点，为下次调整做准备
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
            -- 值未减少，不调整目标
        end
        
        -- 更新 lastSaved 值（即使没有变化）
        self.config["lastSaved" .. keyUpper] = currentValue
        
        -- 只在配置变化时保存
        if configChanged and saveConfig then
            saveConfig()
            configChanged = false  -- 重置标志，避免重复保存
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
        
        local targetValue = self.config["target" .. keyUpper] or 0
        
        if currentValue >= targetValue then
            PlutoX.debug("[目标检测] " .. dataType.id .. ": 已达成目标！当前=" .. PlutoX.formatNumber(currentValue) .. ", 目标=" .. PlutoX.formatNumber(targetValue))
            return {
                dataType = dataType,
                value = currentValue,
                targetValue = targetValue,
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
    
    -- 自动创建并启动数据上传器（完全独立运行）
    -- 创建局部变量以在 spawn 中保持引用
    local monitorRef = monitor
    local disconnectDetectorRef = monitor.disconnectDetector
    spawn(function()
        wait(2) -- 延迟启动，确保初始化完成
        if monitorRef.HttpService and monitorRef.gameName and monitorRef.username then
            local uploader = PlutoX.createDataUploader(
                monitorRef.config,
                monitorRef.HttpService,
                monitorRef.gameName,
                monitorRef.username,
                monitorRef,
                disconnectDetectorRef
            )
        else
        end
    end)
    
    return monitor
end

-- 掉线检测

function PlutoX.createDisconnectDetector(UILibrary, webhookManager, fetchFuncs)
    local detector = {}
    
    detector.disconnected = false
    detector.notified = false  -- 标记是否已发送通知
    detector.UILibrary = UILibrary
    detector.webhookManager = webhookManager
    detector.stopNotification = false  -- 标记是否停止发送通知
    detector.fetchFuncs = fetchFuncs or {}  -- 数据获取函数列表
    
    -- 初始化检测
    function detector:init()
        local GuiService = game:GetService("GuiService")
        local NetworkClient = game:GetService("NetworkClient")
        
        NetworkClient.ChildRemoved:Connect(function()
            if not self.disconnected then
                warn("[掉线检测] 网络断开")
                self.disconnected = true
                self.stopNotification = true  -- 掉线后停止发送通知
            end
        end)
        
        GuiService.ErrorMessageChanged:Connect(function(msg)
            if msg and msg ~= "" and not self.disconnected then
                warn("[掉线检测] 错误提示：" .. msg)
                self.disconnected = true
                self.stopNotification = true  -- 掉线后停止发送通知
            end
        end)
    end
    
    -- 获取所有数据
    function detector:collectData()
        local data = {}
        for id, fetchFunc in pairs(self.fetchFuncs) do
            if fetchFunc then
                local success, value = pcall(fetchFunc)
                if success and value ~= nil then
                    data[id] = value
                end
            end
        end
        return data
    end
    
    -- 检测掉线并发送通知（接收已收集的数据，避免在掉线时阻塞）
    function detector:checkAndNotify(cachedData)
        if self.disconnected and not self.notified and self.webhookManager then
            self.notified = true  -- 标记已发送通知
            
            -- 使用已缓存的数据，避免在掉线时重新获取
            local data = cachedData or {}
            
            -- 如果没有缓存数据，尝试获取（带超时保护）
            if not cachedData or next(cachedData) == nil then
                data = self:collectData()
            end
            
            -- 发送掉线通知
            self.webhookManager:sendDisconnect(data)
            
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
    
    -- 检查是否应该停止通知
    function detector:shouldStopNotification()
        return self.stopNotification
    end
    
    -- 重置状态
    function detector:reset()
        self.disconnected = false
        self.notified = false
        self.stopNotification = false
    end
    
    return detector
end

-- UI 组件

-- Webhook 卡片
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

-- 通知间隔卡片
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

-- 数据类型分隔
function PlutoX.createDataTypeSectionLabel(parent, UILibrary, dataType)
    local card = UILibrary:CreateCard(parent)
    UILibrary:CreateLabel(card, {
        Text = string.format("%s %s目标设置", dataType.icon, dataType.name),
    })
    return card
end

-- 基准值卡片
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

            -- 支持带单位的数字（k/K, m/M, b/B）
            local num = UILibrary.parseNumberWithUnit(text)
            
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
                config["targetStart" .. keyUpper] = currentValue  -- 记录设置目标时的金额，用于后续调整计算
                
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

-- 目标值卡片
function PlutoX.createTargetValueCard(parent, UILibrary, config, saveConfig, fetchValue, keyUpper)
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    local suppressTargetToggleCallback = false
    local targetValueToggle = UILibrary:CreateToggle(card, {
        Text = "目标值踢出",
        DefaultState = config["enable" .. keyUpper .. "Kick"] or false,
        Callback = function(state)
            -- 包裹整个回调函数，捕获所有错误
            local success, err = pcall(function()
                if suppressTargetToggleCallback then
                    suppressTargetToggleCallback = false
                    return
                end
                
                -- 检查状态是否与当前配置相同，避免重复处理
                if state == config["enable" .. keyUpper .. "Kick"] then
                    return
                end

                -- 移除对webhook的强制要求，即使没有webhook也可以开启目标踢出
                -- 注意：没有webhook时，目标达成时无法发送webhook通知，但仍然会退出游戏

                if state and (not config["target" .. keyUpper] or config["target" .. keyUpper] <= 0) then
                    targetValueToggle:Set(false)
                    UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准值", Duration = 5 })
                    return
                end

                local fetchSuccess, currentValue = pcall(fetchValue)
                if not fetchSuccess then
                    currentValue = nil
                end

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
            end)

            if not success then
                warn("[目标踢出] 回调函数出错: " .. tostring(err))
            end
        end
    })
    
    local targetValueLabel = UILibrary:CreateLabel(card, {
        Text = "目标值: " .. (config["target" .. keyUpper] > 0 and PlutoX.formatNumber(config["target" .. keyUpper]) or "未设置"),
    })
    
    UILibrary:CreateButton(card, {
        Text = "重新计算目标值",
        Icon = "refresh-cw",
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
            config["targetStart" .. keyUpper] = currentValue  -- 保存目标设置时的金额
            
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

-- 目标值卡片
function PlutoX.createTargetValueCardSimple(parent, UILibrary, config, saveConfig, fetchValue, keyUpper)
    local card = UILibrary:CreateCard(parent, { IsMultiElement = true })
    
    local suppressTargetToggleCallback = false
    local targetValueToggle = UILibrary:CreateToggle(card, {
        Text = "目标值踢出",
        DefaultState = config["enable" .. keyUpper .. "Kick"] or false,
        Callback = function(state)
            -- 包裹整个回调函数，捕获所有错误
            local success, err = pcall(function()
                if suppressTargetToggleCallback then
                    suppressTargetToggleCallback = false
                    return
                end
                
                -- 检查状态是否与当前配置相同，避免重复处理
                if state == config["enable" .. keyUpper .. "Kick"] then
                    return
                end

                -- 移除对webhook的强制要求，即使没有webhook也可以开启目标踢出
                -- 注意：没有webhook时，目标达成时无法发送webhook通知，但仍然会退出游戏

                if state and (not config["target" .. keyUpper] or config["target" .. keyUpper] <= 0) then
                    if targetValueToggle then
                        targetValueToggle:Set(false)
                    end
                    UILibrary:Notify({ Title = "配置错误", Text = "请先设置基准值", Duration = 5 })
                    return
                end

                local fetchSuccess, currentValue = pcall(fetchValue)
                if not fetchSuccess then
                    currentValue = nil
                end

                if state and currentValue and currentValue >= config["target" .. keyUpper] then
                    if targetValueToggle then
                        targetValueToggle:Set(false)
                    end
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
            end)

            if not success then
                warn("[目标踢出] 回调函数出错: " .. tostring(err))
            end
        end
    })
    
    
    local targetValueLabel = UILibrary:CreateLabel(card, {
        Text = "目标值: " .. (config["target" .. keyUpper] > 0 and PlutoX.formatNumber(config["target" .. keyUpper]) or "未设置"),
    })
    
    return card, targetValueLabel, function(suppress, toggle) suppressTargetToggleCallback = suppress; targetValueToggle = toggle end
end

-- 重新计算目标值
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
                    config["targetStart" .. keyUpper] = currentValue  -- 保存目标设置时的金额
                    
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

-- 数据上传管理

function PlutoX.createDataUploader(config, HttpService, gameName, username, dataMonitor, disconnectDetector)
    local uploader = {}
    
    uploader.config = config
    uploader.HttpService = HttpService
    uploader.gameName = gameName
    uploader.username = username
    uploader.dataMonitor = dataMonitor
    uploader.disconnectDetector = disconnectDetector
    uploader.lastUploadTime = os.time() -- 初始化为当前时间，避免第一次上传时的时间差过大
    uploader.hasInitialized = false -- 标记是否已初始化（保存sessionStartValues）
    uploader.uploadInterval = 5 * 60 -- 5 分钟
    uploader.enabled = true
    uploader.uploadUrl = "https://api.959966.xyz/api/dashboard/upload"
    uploader.sessionStartTime = os.time() -- 会话开始时间
    uploader.isUploading = false -- 防止重复上传的标志
    -- 从全局变量读取 game_user_id（由 loader 设置）
    uploader.gameUserId = _G.PLUTO_GAME_USER_ID or nil
    -- 保存会话开始时每个数据类型的初始值（用于计算本次运行获取的金额）
    uploader.sessionStartValues = {}
    -- 重试机制
    uploader.retryCount = 0
    uploader.maxRetries = 3 -- 最大重试次数
    uploader.retryDelay = 30 -- 初始重试延迟（秒）
    uploader.lastRetryTime = 0
    uploader.isRetrying = false
    
    -- 发送数据上传请求
    function uploader:uploadData()
        
        if not self.enabled then
            return false
        end
        
        -- 防止重复上传
        if self.isUploading then
            return false
        end
        
        -- 检查是否到达上传间隔
        local currentTime = os.time()
        local timeSinceLastUpload = currentTime - self.lastUploadTime
        
        if timeSinceLastUpload < self.uploadInterval then
            return false
        end
        
        -- 标记为正在上传
        self.isUploading = true
        
        
        -- 收集所有数据
        local data = self.dataMonitor:collectData()
        if not data or next(data) == nil then
            self.isUploading = false -- 重置上传标志
            return false
        end

        -- 第一次上传时保存初始值到配置文件
        if not self.hasInitialized then
            for id, dataInfo in pairs(data) do
                if dataInfo.current ~= nil and dataInfo.type.id ~= "leaderboard" then
                    local keyUpper = dataInfo.type.id:gsub("^%l", string.upper)
                    -- 保存脚本启动时的初始值
                    self.sessionStartValues[id] = dataInfo.current
                    self.config["sessionStart" .. keyUpper] = dataInfo.current
                end
            end
            -- 保存配置
            if self.saveConfig then
                self.saveConfig()
            end
            self.hasInitialized = true
        end

        -- 计算实际有数据的数据类型数量
        local validDataCount = 0
        for id, dataInfo in pairs(data) do
            -- 排行榜数据即使current为nil也是有效的（表示未上榜）
            if dataInfo.current ~= nil or dataInfo.type.id == "leaderboard" then
                validDataCount = validDataCount + 1
            end
        end

        -- 构建数据对象（JSONB 格式）
        local dataObject = {}
        local elapsedTime = currentTime - self.sessionStartTime

        for id, dataInfo in pairs(data) do
            -- 排行榜数据特殊处理：即使current为nil也要包含（表示未上榜）
            -- 其他数据类型只在current不为nil时包含
            if dataInfo.current ~= nil or dataInfo.type.id == "leaderboard" then
                local dataType = dataInfo.type
                local keyUpper = dataType.id:gsub("^%l", string.upper)
                local notifyEnabled = self.config["notify" .. keyUpper]


                -- 排行榜数据特殊处理：总是上传（即使未上榜），用于记录状态
                if dataType.id == "leaderboard" then
                    -- 判断是否在榜上：current 不为 nil 且不是 "未上榜" 才表示在榜上
                    local isOnLeaderboard = dataInfo.current ~= nil and dataInfo.current ~= "未上榜"
                    dataObject[id] = {
                        current = dataInfo.current,  -- nil或"未上榜"表示未上榜
                        is_on_leaderboard = isOnLeaderboard,
                        notify_enabled = notifyEnabled
                    }
                elseif dataInfo.current ~= nil then
                    -- 获取目标值和基准值（来自配置文件）
                    local targetValue = self.config["target" .. keyUpper] or 0
                    local baseValue = self.config["base" .. keyUpper] or 0

                    -- 计算总赚取金额
                    local totalEarned = 0
                    local kickEnabled = self.config["enable" .. keyUpper .. "Kick"] or false
                    if targetValue > 0 and kickEnabled then
                        -- 目标踢出功能开启，显示目标设置以来的收入
                        local targetStartValue = self.config["targetStart" .. keyUpper] or 0
                        if targetStartValue > 0 then
                            totalEarned = dataInfo.current - targetStartValue
                            if totalEarned < 0 then
                                totalEarned = 0
                            end
                        end
                    else
                        -- 目标踢出功能未开启，显示本次运行的收入
                        local sessionStartValue = self.config["sessionStart" .. keyUpper] or 0
                        if sessionStartValue > 0 then
                            totalEarned = dataInfo.current - sessionStartValue
                            if totalEarned < 0 then
                                totalEarned = 0
                            end
                        end
                    end

                    -- 计算本次运行获取的金额（用于计算平均速度）
                    local sessionEarned = 0
                    if self.sessionStartValues[id] then
                        sessionEarned = dataInfo.current - self.sessionStartValues[id]
                    end

                    -- 计算平均速度（每小时）- 使用本次运行获取的金额
                    local avgPerHour = 0
                    if dataType.calculateAvg and elapsedTime > 0 and sessionEarned ~= 0 then
                        avgPerHour = math.floor(sessionEarned / (elapsedTime / 3600) + 0.5)
                    end

                    -- 计算预计完成时间
                    local estimatedCompletion = nil
                    if dataType.supportTarget and targetValue > 0 and avgPerHour > 0 then
                        local remaining = targetValue - dataInfo.current
                        if remaining > 0 then
                            local hoursNeeded = remaining / avgPerHour
                            local completionTimestamp = currentTime + math.floor(hoursNeeded * 3600)

                            estimatedCompletion = {
                                days = math.floor(hoursNeeded / 24),
                                hours = math.floor((hoursNeeded % 24)),
                                minutes = math.floor((hoursNeeded * 60) % 60),
                                timestamp = completionTimestamp
                            }
                        end
                    end

                    -- 检查目标是否完成
                    local targetCompleted = false
                    if dataType.supportTarget and targetValue > 0 then
                        targetCompleted = dataInfo.current >= targetValue
                    end

                    dataObject[id] = {
                        current = dataInfo.current,
                        change = dataInfo.change or 0,
                        total_earned = totalEarned,
                        avg_per_hour = avgPerHour,
                        session_start = self.sessionStartTime,
                        estimated_completion = estimatedCompletion,
                        target_value = targetValue,
                        base_value = baseValue,
                        target_completed = targetCompleted,
                        notify_enabled = notifyEnabled
                    }
                end
            end
        end
        
        -- 输出最终上传的数据类型
        local dataTypesList = {}
        for id, _ in pairs(dataObject) do
            table.insert(dataTypesList, id)
        end
        
        if next(dataObject) == nil then
            self.isUploading = false -- 重置上传标志
            return false
        end
        
        -- 构建上传数据
        -- 获取掉线状态
        local disconnectStatus = false
        if self.disconnectDetector and self.disconnectDetector.disconnected then
            disconnectStatus = true
        end

        local uploadData = {
            game_user_id = self.gameUserId,
            game_name = self.gameName,
            username = self.username,
            is_active = self.enabled,
            data = dataObject,
            session_start = os.date("!%Y-%m-%dT%H:%M:%SZ", self.sessionStartTime),
            elapsed_time = elapsedTime,
            disconnect_status = disconnectStatus
        }
        
        -- 发送上传请求
        local requestFunc = syn and syn.request or http and http.request or request
        if not requestFunc then
            self.isUploading = false -- 重置上传标志
            return false
        end
        
        
        -- 异步上传
        -- 创建局部变量以在 spawn 中保持引用
        local uploaderRef = self
        local uploadUrlRef = self.uploadUrl
        local httpServiceRef = self.HttpService
        local currentTimeRef = currentTime
        
        -- 执行上传的内部函数
        local function performUpload()
            local reqSuccess, res = pcall(function()
                return requestFunc({
                    Url = uploadUrlRef,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = httpServiceRef:JSONEncode(uploadData)
                })
            end)


            if reqSuccess then
                local statusCode = res.StatusCode or res.statusCode or 0
                if statusCode == 200 or statusCode == 201 then
                    uploaderRef.lastUploadTime = currentTimeRef
                    uploaderRef.retryCount = 0 -- 重置重试计数
                    uploaderRef.isRetrying = false
                else
                    -- 处理非 200/201 状态码
                    uploaderRef:handleUploadFailure("状态码: " .. statusCode)
                end
            else
                -- 处理网络错误
                uploaderRef:handleUploadFailure(tostring(res))
            end

            -- 无论成功失败，都重置上传标志
            uploaderRef.isUploading = false
        end
        
        -- 检查是否需要重试
        if self.retryCount > 0 and self.retryCount < self.maxRetries then
            -- 计算重试延迟（指数退避）
            local retryDelay = self.retryDelay * math.pow(2, self.retryCount - 1)
            spawn(function()
                wait(retryDelay)
                performUpload()
            end)
        else
            -- 直接上传
            performUpload()
        end
        
        return true
    end
    
    -- 处理上传失败
    function uploader:handleUploadFailure(errorMsg)
        self.retryCount = self.retryCount + 1
        
        if self.retryCount >= self.maxRetries then
            -- 达到最大重试次数，延长下次上传间隔
            self.lastUploadTime = os.time() - self.uploadInterval + self.retryDelay * 4 -- 延长4倍重试延迟
            self.retryCount = 0 -- 重置计数器
            self.isUploading = false -- 重置上传标志
        else
            -- 还可以重试，等待后重试
            local retryDelay = self.retryDelay * math.pow(2, self.retryCount - 1)
            spawn(function()
                wait(retryDelay)
                self.isUploading = false -- 重置上传标志，允许重试
                self:uploadData()
            end)
        end
    end
    
    -- 启动上传定时器
    function uploader:start()
        -- 立即上传一次初始数据（使用forceUpload跳过时间间隔检查）
        self:forceUpload()
        
        -- 每 5 分钟上传一次
        -- 创建局部变量以在 spawn 中保持引用
        local uploaderRef = self
        spawn(function()
            while uploaderRef.enabled do
                wait(60) -- 每分钟检查一次
                uploaderRef:uploadData()
            end
        end)
        
    end
    
    -- 停止上传
    function uploader:stop()
        self.enabled = false
        
        -- 最后上传一次，设置 is_active 为 false
        local currentTime = os.time()
        local data = self.dataMonitor:collectData()
        
        if data and next(data) then
            local dataObject = {}
            local elapsedTime = currentTime - self.sessionStartTime
            
            for id, dataInfo in pairs(data) do
                if dataInfo.current ~= nil then
                    local dataType = dataInfo.type
                    local avgPerHour = 0
                    if dataType.calculateAvg and elapsedTime > 0 and dataInfo.totalEarned ~= 0 then
                        avgPerHour = math.floor(dataInfo.totalEarned / (elapsedTime / 3600) + 0.5)
                    end
                    
                    dataObject[id] = {
                        current = dataInfo.current,
                        change = dataInfo.change or 0,
                        total_earned = dataInfo.totalEarned or 0,
                        avg_per_hour = avgPerHour,
                        session_start = self.sessionStartTime,
                        estimated_completion = nil
                    }
                end
            end
            
            if next(dataObject) then
                local uploadData = {
                    game_name = self.gameName,
                    username = self.username,
                    is_active = false,
                    data = dataObject,
                    session_start = os.date("!%Y-%m-%dT%H:%M:%SZ", self.sessionStartTime),
                    elapsed_time = elapsedTime
                }
                
                -- 创建局部变量以在 spawn 中保持引用
                local uploaderRef = self
                spawn(function()
                    pcall(function()
                        local requestFunc = syn and syn.request or http and http.request or request
                        if requestFunc then
                            requestFunc({
                                Url = uploaderRef.uploadUrl,
                                Method = "POST",
                                Headers = {
                                    ["Content-Type"] = "application/json"
                                },
                                Body = uploaderRef.HttpService:JSONEncode(uploadData)
                            })
                        end
                    end)
                end)
            end
        end
        
    end
    
    -- 手动触发上传（跳过时间间隔检查）
    function uploader:forceUpload()
        -- 检查HttpService是否存在
        if not self.HttpService then
            PlutoX.warn("[DataUploader] forceUpload: HttpService为nil，无法上传数据")
            self.isUploading = false
            return false
        end

        -- 使用pcall包装整个函数，确保错误时重置isUploading
        local success, result = pcall(function()
            -- 临时保存当前时间，用于后续更新
            local currentTime = os.time()

            -- 标记为正在上传
            self.isUploading = true


            -- 收集所有数据
            local data = self.dataMonitor:collectData()
            if not data or next(data) == nil then
                self.isUploading = false
                return false
            end

        -- 第一次上传时保存初始值到配置文件
        if not self.hasInitialized then
            for id, dataInfo in pairs(data) do
                if dataInfo.current ~= nil and dataInfo.type.id ~= "leaderboard" then
                    local keyUpper = dataInfo.type.id:gsub("^%l", string.upper)
                    self.sessionStartValues[id] = dataInfo.current
                    self.config["sessionStart" .. keyUpper] = dataInfo.current
                end
            end
            if self.saveConfig then
                self.saveConfig()
            end
            self.hasInitialized = true
        end

        -- 计算实际有数据的数据类型数量
        local validDataCount = 0
        for id, dataInfo in pairs(data) do
            if dataInfo.current ~= nil or dataInfo.type.id == "leaderboard" then
                validDataCount = validDataCount + 1
            end
        end

        -- 构建数据对象（JSONB 格式）
        local dataObject = {}
        local elapsedTime = currentTime - self.sessionStartTime

        for id, dataInfo in pairs(data) do
            if dataInfo.current ~= nil or dataInfo.type.id == "leaderboard" then
                local dataType = dataInfo.type
                local keyUpper = dataType.id:gsub("^%l", string.upper)
                local notifyEnabled = self.config["notify" .. keyUpper]


                if dataType.id == "leaderboard" then
                    -- 判断是否在榜上：current 不为 nil 且不是 "未上榜" 才表示在榜上
                    local isOnLeaderboard = dataInfo.current ~= nil and dataInfo.current ~= "未上榜"
                    dataObject[id] = {
                        current = dataInfo.current,
                        is_on_leaderboard = isOnLeaderboard,
                        notify_enabled = notifyEnabled
                    }
                elseif dataInfo.current ~= nil then
                    local targetValue = self.config["target" .. keyUpper] or 0
                    local baseValue = self.config["base" .. keyUpper] or 0
                    local initial_value = self.config["sessionStart" .. keyUpper] or dataInfo.current

                    -- 检查目标是否完成
                    local targetCompleted = false
                    if dataType.supportTarget and targetValue > 0 then
                        targetCompleted = dataInfo.current >= targetValue
                    end

                    -- 调试：记录目标值
                    if targetValue > 0 then
                        PlutoX.warn("[DataUploader] forceUpload: " .. id .. " 目标值=" .. tostring(targetValue) .. ", 当前值=" .. tostring(dataInfo.current) .. ", 目标完成=" .. tostring(targetCompleted))
                    else
                    end

                    dataObject[id] = {
                        current = dataInfo.current,
                        target_value = targetValue,
                        base_value = baseValue,
                        session_start = self.sessionStartTime,  -- 使用会话开始时间戳
                        initial_value = initial_value,  -- 游戏数据初始值
                        gained = dataInfo.current - initial_value,
                        elapsed_time = elapsedTime,
                        target_completed = targetCompleted,  -- 目标完成状态
                        notify_enabled = notifyEnabled
                    }
                end
            end
        end

        if next(dataObject) == nil then
            self.isUploading = false
            return false
        end

        -- 获取数据类型的键（内联实现，避免调用self:getKeys）
        local keys = {}
        for k, v in pairs(dataObject) do
            table.insert(keys, k)
        end

        -- 构建 HTTP 请求
        local requestBody = {
            game_user_id = self.gameUserId,
            game_name = self.gameName,
            username = self.username,
            data = dataObject,
            elapsed_time = elapsedTime
        }


        -- 发送 HTTP 请求
        local reqSuccess, response = pcall(function()
            return self.HttpService:RequestAsync({
                Url = self.uploadUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = self.HttpService:JSONEncode(requestBody)
            })
        end)


            if reqSuccess then
                local statusCode = response.Success and response.StatusCode or response.StatusCode
                local responseBody = response.Body


                if statusCode == 200 or statusCode == 201 then

                    -- 更新最后上传时间
                    self.lastUploadTime = currentTime
                    self.retryCount = 0

                    -- 重置isUploading标志
                    self.isUploading = false

                    return true
                else
                    self.isUploading = false
                    return false
                end
            else
                self.isUploading = false
                return false
            end
        end)

        -- 如果出错，确保重置isUploading标志
        if not success then
            PlutoX.warn("[DataUploader] forceUpload: 发生错误: " .. tostring(result))
            self.isUploading = false
            return false
        end

        return result
    end

    -- 辅助函数：获取表的所有键
    function uploader:getKeys(tbl)
        local keys = {}
        for k, v in pairs(tbl) do
            table.insert(keys, k)
        end
        return keys
    end
    
    -- 自动启动上传
    uploader:start()
    
    -- 保存全局引用
    PlutoX.uploader = uploader
    
    return uploader
end

-- 关于页面
function PlutoX.createAboutPage(parent, UILibrary)
    UILibrary:CreateAuthorInfo(parent, {
        Text = "作者: tongblx",
        SocialText = "感谢使用"
    })
    
    UILibrary:CreateButton(parent, {
        Text = "复制 Discord",
        Icon = "external-link",
        Callback = function()
            local link = "https://discord.gg/6G2UfBgEZJ"
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
    
    -- 复制 UUID 按钮
    UILibrary:CreateButton(parent, {
        Text = "复制 UUID",
        Icon = "copy",
        Callback = function()
            PlutoX.debug("[AboutPage] 点击复制 UUID 按钮")
            local gameUserId = _G.PLUTO_GAME_USER_ID
            PlutoX.debug("[AboutPage] _G.PLUTO_GAME_USER_ID = " .. tostring(gameUserId))
            
            if gameUserId then
                PlutoX.debug("[AboutPage] UUID 存在: " .. gameUserId)
                if setclipboard then
                    setclipboard(gameUserId)
                    PlutoX.debug("[AboutPage] UUID 已复制到剪贴板")
                    UILibrary:Notify({
                        Title = "已复制",
                        Text = "UUID 已复制",
                        Duration = 2,
                    })
                else
                    PlutoX.debug("[AboutPage] setclipboard 函数不可用")
                    UILibrary:Notify({
                        Title = "复制失败",
                        Text = "无法访问剪贴板",
                        Duration = 2,
                    })
                end
            else
                PlutoX.debug("[AboutPage] UUID 不存在")
                UILibrary:Notify({
                    Title = "未找到 UUID",
                    Text = "请重新加载脚本",
                    Duration = 2,
                })
            end
        end,
    })
end

-- 导出

return PlutoX