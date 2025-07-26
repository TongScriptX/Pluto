getgenv().PlutoLoaded = true

local function kill(reason)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "注入阻止",
        Text = reason,
        Duration = 10
    })
    return false -- 直接返回 false 表示停止后续逻辑
end

local function checkStackForAllowedScripts()
    local fiberUrl = "raw.githubusercontent.com/Aaron999S/FiberHub/main/Main"
    local luaUrl   = "raw.githubusercontent.com/treeofplant/luarmor/main/loader.lua"
    local plutoUrl = "pluto%-x%.vercel%.app"

    local ok, trace = xpcall(function()
        error("trace", 0)
    end, function(err)
        local fullTrace = debug.traceback(err, 2)
        return string.sub(fullTrace, 1, 500)
    end)

    if not ok or not trace then
        return kill("无法获取调用栈，注入停止")
    end

    local fiberFound = trace:find(fiberUrl, 1, true)
    local luaFound   = trace:find(luaUrl, 1, true)
    local plutoFound = trace:find(plutoUrl)

    if not plutoFound then
        return kill("非法注入：不要修改注入脚本，注入停止")
    end

    if fiberFound and luaFound then
        return kill("非法注入：检测到同时加载 Fiber 和 Luarmor，注入停止")
    end

    return true -- 通过检测，继续执行
end

if not checkStackForAllowedScripts() then
    return -- 直接退出，不继续执行后续代码
end

-- Pluto 主体逻辑
local placeId = game.PlaceId

local gameScripts = {
    [3351674303] = "Driving_Empire",
    [891852901]  = "Greenville",
    [11832484500] = "Autopilot_Simulator"
}

local function loadRemoteScript(url)
    local success, res = pcall(function()
        return game:HttpGet(url)
    end)
    if success then
        local func, err = loadstring(res)
        if func then
            func()
        else
            warn("loadstring解析失败：", err)
        end
    else
        warn("HttpGet请求失败：", res)
    end
end

local gameName = gameScripts[placeId]
if gameName then
    local baseUrl = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Games/"
    local scriptUrl = baseUrl .. gameName .. ".lua"
    loadRemoteScript(scriptUrl)
else
    warn("[Pluto-X]: 尚未支持该游戏 PlaceId（" .. placeId .. "），请等待更新")
end