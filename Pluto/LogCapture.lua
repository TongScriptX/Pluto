-- LogCapture.lua: 捕获并复制 Roblox 控制台输出
local LogCapture = {}

-- 日志存储
local logs = {}
local startTime = os.time()

-- 重定向 print 和 warn
local oldPrint = print
local oldWarn = warn

print = function(...)
    local message = table.concat({...}, " ")
    table.insert(logs, { type = "print", text = message, timestamp = os.time() })
    oldPrint(...)
end

warn = function(...)
    local message = table.concat({...}, " ")
    table.insert(logs, { type = "warn", text = message, timestamp = os.time() })
    oldWarn(...)
end

-- 捕获三秒内日志并复制
function LogCapture:CaptureAndCopy()
    -- 等待 3 秒
    wait(3)
    
    -- 收集三秒内的日志
    local endTime = os.time()
    local capturedLogs = {}
    for _, log in ipairs(logs) do
        if log.timestamp >= startTime and log.timestamp <= endTime then
            table.insert(capturedLogs, string.format("[%s] %s", log.type, log.text))
        end
    end
    
    -- 合并日志
    local logString = table.concat(capturedLogs, "\n")
    
    -- 尝试复制到剪贴板
    local success, err = pcall(function()
        setclipboard(logString)
    end)
    
    if success then
        oldPrint("Logs copied to clipboard:\n" .. logString)
    else
        oldPrint("Failed to copy logs to clipboard (executor may not support setclipboard). Logs:\n" .. logString)
        oldPrint("Error: " .. tostring(err))
    end
    
    return logString
end

-- 启动捕获
function LogCapture:Start()
    startTime = os.time()
    logs = {} -- 重置日志
    spawn(function()
        self:CaptureAndCopy()
    end)
end

return LogCapture
