getgenv().PlutoLoaded = true

local function kill(reason)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "注入阻止",
        Text = reason,
        Duration = 10
    })
    while true do end
end

local function checkStackForAllowedScripts()
    local fiberUrl = "raw.githubusercontent.com/Aaron999S/FiberHub/main/Main"
    local luaUrl   = "raw.githubusercontent.com/treeofplant/luarmor/main/loader.lua"
    local plutoUrl = "pluto%-x%.vercel%.app"

    local ok, trace = xpcall(function()
        error("trace", 0)
    end, function(err)
        return debug.traceback(err, 2)
    end)

    if not ok or not trace then
        kill("无法获取调用栈")
    end

    local fiberFound = trace:find(fiberUrl, 1, true)
    local luaFound   = trace:find(luaUrl, 1, true)
    local plutoFound = trace:find(plutoUrl)

    if not plutoFound then
        kill("非法注入：不要修改注入脚本")
    end

    if fiberFound and luaFound then
        kill("非法注入：检测到同时加载 Fiber 和 Luarmor")
    end
end

checkStackForAllowedScripts()

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