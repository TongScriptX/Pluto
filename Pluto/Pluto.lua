local env = getgenv()

local function kill(reason)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "注入阻止",
        Text = reason,
        Duration = 10
    })
    return false
end

-- 只允许 PlutoInjected 为 true，且注入脚本纯净（即环境中仅有 PlutoInjected 且无其他字段）
local function checkPlutoInjection()
    if env.PlutoInjected ~= true then
        return false, "PlutoInjected 标记缺失"
    end

    local count = 0
    for k, v in pairs(env) do
        count = count + 1
        if k ~= "PlutoInjected" then
            return false, "Pluto 注入时只允许存在 PlutoInjected 标记"
        end
    end

    return true
end

local function checkFiberLuarmorInjection()
    local fiber = env.FiberInjected == true
    local luarmor = env.LuarmorInjected == true
    if fiber and luarmor then
        return false, "禁止同时加载 Fiber 和 Luarmor"
    end
    return true
end

-- 主逻辑检测
local ok, err = checkPlutoInjection()
if not ok then
    kill("非法 Pluto 注入：" .. err)
    return
end

local ok2, err2 = checkFiberLuarmorInjection()
if not ok2 then
    kill("非法注入：" .. err2)
    return
end

-- 允许 Pluto + Fiber，或 Pluto + Luarmor，或 单独 Pluto 注入
-- 但禁止 Fiber + Luarmor 同时注入

-- 下面是你原本 Pluto 主脚本逻辑
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