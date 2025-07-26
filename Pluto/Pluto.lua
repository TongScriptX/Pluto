local env = getgenv()

local function kill(reason)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "注入阻止",
        Text = reason,
        Duration = 10
    })
    return false
end

-- 仅检测 Pluto 是否携带 tongblx 标记
local function checkPlutoInjection()
    if not env.tongblx then
        return false, "不要修改脚本"
    end
    return true
end

local ok, err = checkPlutoInjection()
if not ok then
    kill("非法注入：" .. err)
    return
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