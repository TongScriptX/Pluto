-- LogCapture.lua: 捕获并复制 Roblox 控制台输出
local LogCapture = {}

-- 日志存储
local logs = {}
local startTime = os.time()

-- 重定向 print 和 warn
local oldPrint = print
local oldWarn = warn

print = function(...)
    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end
    local message = table.concat(args, " ")
    table.insert(logs, { type = "print", text = message, timestamp = os.time() })
    oldPrint("[LogCapture] Print:", ...)
end

warn = function(...)
    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end
    local message = table.concat(args, " ")
    table.insert(logs, { type = "warn", text = message, timestamp = os.time() })
    oldWarn("[LogCapture] Warn:", ...)
end

-- 捕获三秒内日志并复制
function LogCapture:CaptureAndCopy()
    oldPrint("[LogCapture] Starting capture for 3 seconds")
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
    local logString = #capturedLogs > 0 and table.concat(capturedLogs, "\n") or "No logs captured"
    
    -- 尝试复制到剪贴板
    local success, err = pcall(function()
        if setclipboard then
            setclipboard(logString)
        else
            error("setclipboard not available")
        end
    end)
    
    if success then
        oldPrint("[LogCapture] Logs copied to clipboard:\n" .. logString)
    else
        oldPrint("[LogCapture] Failed to copy logs to clipboard. Logs:\n" .. logString)
        oldPrint("[LogCapture] Error: " .. tostring(err))
    end
    
    return logString
end

-- 启动捕获
function LogCapture:Start()
    startTime = os.time()
    logs = {}
    oldPrint("[LogCapture] Initialized")
    spawn(function()
        pcall(function()
            self:CaptureAndCopy()
        end)
    end)
end

return LogCapture
